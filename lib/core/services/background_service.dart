import 'package:workmanager/workmanager.dart';
import 'package:agrinova/core/services/notification_scheduler.dart';
import 'package:agrinova/core/services/cache_service.dart';
import 'package:agrinova/core/services/notification_service.dart';
import 'package:agrinova/data/datasources/weather_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/widgets.dart';
import 'package:agrinova/core/services/app_logger.dart';

// Task names
const String weatherCheckTask = "checkWeatherCondition";

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    
    AppLogger().debug('Agrinova', "🔄 Background Task Started: $task");

    if (task == weatherCheckTask) {
      try {
        // Secrets sudah di-inject saat compile time via String.fromEnvironment,
        // sehingga tersedia di semua isolate tanpa perlu load file.

        await CacheService.init();
        await NotificationService().init();

        // Get current position directly
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        final weatherService = WeatherService();
        final weatherData = await weatherService.fetchCurrentWeather(
            lat: position.latitude, lon: position.longitude);

        final scheduler = NotificationScheduler();

        // Check for alerts based on new weather data
        await scheduler.checkWeatherAlerts(weatherData);
        await scheduler.updateRainStatus(weatherData);
        await scheduler.checkPestRisk(weatherData);

        // Ensure morning briefing is scheduled for next day with latest data
        await scheduler.scheduleMorningBriefing();
      } catch (e) {
        AppLogger().debug('Agrinova', "❌ Background Task Failed: $e");
        return Future.value(false);
      }
    }

    return Future.value(true);
  });
}

class BackgroundService {
  static final BackgroundService _instance = BackgroundService._internal();
  factory BackgroundService() => _instance;
  BackgroundService._internal();

  Future<void> init() async {
    await Workmanager().initialize(
      callbackDispatcher,
      // isInDebugMode removed as it is deprecated
    );

    // Register periodic task (every 1 hour)
    await Workmanager().registerPeriodicTask(
      "weather_periodic_check",
      weatherCheckTask,
      frequency: const Duration(hours: 1),
      constraints: Constraints(
        networkType: NetworkType.connected, // Only run when connected
      ),
      existingWorkPolicy: ExistingWorkPolicy.keep,
    );

    AppLogger().debug('Agrinova', "✅ Background Service Initialized");
  }
}
