// lib/core/services/notification_scheduler.dart

import 'package:flutter/foundation.dart';
import 'package:agrinova/core/services/notification_service.dart';
import 'package:agrinova/core/services/cache_service.dart';
import 'package:agrinova/data/models/notification_settings.dart';
import 'package:agrinova/utils/weather_utils.dart';
import 'package:agrinova/core/services/app_logger.dart';

/// Service untuk mengatur semua jadwal dan logic notifikasi cerdas
class NotificationScheduler {
  static final NotificationScheduler _instance =
      NotificationScheduler._internal();
  factory NotificationScheduler() => _instance;
  NotificationScheduler._internal();

  final NotificationService _notificationService = NotificationService();
  final CacheService _cacheService = CacheService();

  // Notification IDs (90000+ for system alerts to avoid collision with calendar IDs 100000+)
  static const int _morningBriefingId = 90000;
  static const int _heavyRainAlertId = 90001;
  static const int _strongWindAlertId = 90002;
  static const int _thunderstormAlertId = 90003;
  static const int _smartWateringId = 90004;
  static const int _pestWarningId = 90005;

  /// Get current notification settings
  NotificationSettings getSettings() {
    return _cacheService.getNotificationSettings();
  }

  /// Save notification settings
  Future<void> saveSettings(NotificationSettings settings) async {
    await _cacheService.saveNotificationSettings(settings);
  }

  /// Schedule morning briefing notification
  Future<void> scheduleMorningBriefing() async {
    final settings = getSettings();
    if (!settings.morningBriefingEnabled) return;

    // Calculate next morning briefing time
    final now = DateTime.now();
    var scheduledDate = DateTime(
      now.year,
      now.month,
      now.day,
      settings.morningBriefingHour,
      settings.morningBriefingMinute,
    );

    // If time has passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    // Get cached weather data for the briefing
    final weatherData = _cacheService.getCachedCurrentWeather();
    final forecast = _cacheService.getCachedForecast();

    String weatherDesc = 'Tidak ada data cuaca';
    String recommendation = 'Buka aplikasi untuk melihat cuaca terkini';
    double tempMin = 0;
    double tempMax = 0;

    if (weatherData != null) {
      final description = weatherData['weather']?[0]?['description'] ?? '';
      weatherDesc = WeatherUtils.translateWeather(description);
      tempMin = (weatherData['main']?['temp_min'] ?? 0).toDouble();
      tempMax = (weatherData['main']?['temp_max'] ?? 0).toDouble();

      final conditionId = weatherData['weather']?[0]?['id'] ?? 800;
      recommendation = WeatherUtils.getRecommendation(conditionId) ??
          'Selamat beraktivitas!';
    }

    // Check for rain in forecast
    bool willRain = false;
    if (forecast != null && forecast.isNotEmpty) {
      for (var item in forecast.take(8)) {
        // Check next 24 hours
        final id = item['weather']?[0]?['id'] ?? 800;
        if (id >= 200 && id < 700) {
          willRain = true;
          break;
        }
      }
    }

    final briefingBody = willRain
        ? '🌧️ $weatherDesc (${tempMin.round()}-${tempMax.round()}°C)\n⚠️ Diprediksi hujan hari ini!\n💡 $recommendation'
        : '☀️ $weatherDesc (${tempMin.round()}-${tempMax.round()}°C)\n💡 $recommendation';

    await _notificationService.scheduleNotification(
      id: _morningBriefingId,
      title: '🌤️ Selamat Pagi, Pak Tani!',
      body: briefingBody,
      scheduledDate: scheduledDate,
    );

    if (kDebugMode) {
      AppLogger().debug('Agrinova', 'Morning briefing scheduled for: $scheduledDate');
    }
  }

  /// Cancel morning briefing
  Future<void> cancelMorningBriefing() async {
    await _notificationService.cancelNotification(_morningBriefingId);
  }

  bool _isAlertOnCooldown(String alertType, {int cooldownHours = 3}) {
    final lastTime = _cacheService.getCachedData<int>('last_alert_$alertType');
    if (lastTime == null) return false;
    final elapsed = DateTime.now().millisecondsSinceEpoch - lastTime;
    return elapsed < (cooldownHours * 3600 * 1000);
  }

  void _recordAlertTime(String alertType) {
    _cacheService.saveCachedData('last_alert_$alertType', DateTime.now().millisecondsSinceEpoch);
  }

  /// Check weather conditions and trigger alerts if necessary
  Future<void> checkWeatherAlerts(Map<String, dynamic> weatherData) async {
    final settings = getSettings();
    if (settings.isQuietTime()) return;

    final conditionId = weatherData['weather']?[0]?['id'] ?? 800;
    final windSpeed = (weatherData['wind']?['speed'] ?? 0).toDouble();
    final cityName = weatherData['name'] ?? 'Lokasi Anda';

    // Heavy Rain Alert (500-531)
    if (settings.heavyRainAlertEnabled &&
        conditionId >= 500 &&
        conditionId < 532 &&
        !_isAlertOnCooldown('heavy_rain')) {
      final severity = conditionId >= 502 ? 'DERAS' : 'RINGAN';
      await _notificationService.showNotification(
        id: _heavyRainAlertId,
        title: '🌧️ PERINGATAN HUJAN $severity!',
        body:
            'Hujan terdeteksi di $cityName.\n💡 Segera lindungi tanaman dan siapkan drainase!',
        payload: 'rain_alert',
      );
      _recordAlertTime('heavy_rain');
    }

    // Thunderstorm Alert (200-232)
    if (settings.thunderstormAlertEnabled &&
        conditionId >= 200 &&
        conditionId < 233 &&
        !_isAlertOnCooldown('thunderstorm')) {
      await _notificationService.showNotification(
        id: _thunderstormAlertId,
        title: '⛈️ PERINGATAN PETIR!',
        body:
            'Hujan petir di $cityName.\n💡 Hindari kegiatan di luar ruangan dan tempat terbuka!',
        payload: 'thunderstorm_alert',
      );
      _recordAlertTime('thunderstorm');
    }

    // Strong Wind Alert (wind speed > 10 m/s)
    if (settings.strongWindAlertEnabled &&
        windSpeed > 10 &&
        !_isAlertOnCooldown('strong_wind')) {
      await _notificationService.showNotification(
        id: _strongWindAlertId,
        title: '💨 PERINGATAN ANGIN KENCANG!',
        body:
            'Angin ${windSpeed.toStringAsFixed(1)} m/s di $cityName.\n💡 Amankan tanaman dan peralatan!',
        payload: 'wind_alert',
      );
      _recordAlertTime('strong_wind');
    }
  }

  /// Check if watering is needed based on rain history
  Future<void> checkWateringNeeds() async {
    final settings = getSettings();
    if (!settings.smartWateringEnabled) return;
    if (settings.isQuietTime()) return;

    final lastRainDate = _cacheService.getLastRainDate();
    if (lastRainDate == null) return;

    final daysSinceRain = DateTime.now().difference(lastRainDate).inDays;

    // Alert if no rain for 2+ days
    if (daysSinceRain >= 2) {
      await _notificationService.showNotification(
        id: _smartWateringId,
        title: '💧 Pengingat Penyiraman',
        body:
            'Sudah $daysSinceRain hari tidak hujan.\n💡 Periksa kelembaban tanah dan siram jika diperlukan!',
        payload: 'watering_reminder',
      );
    }
  }

  /// Update last rain date when rain is detected
  Future<void> updateRainStatus(Map<String, dynamic> weatherData) async {
    final conditionId = weatherData['weather']?[0]?['id'] ?? 800;

    // Rain conditions: 200-622 (thunderstorm, drizzle, rain, snow)
    if (conditionId >= 200 && conditionId < 700) {
      await _cacheService.setLastRainDate(DateTime.now());
    }
  }

  /// Check pest risk based on weather conditions
  Future<void> checkPestRisk(Map<String, dynamic> weatherData) async {
    final settings = getSettings();
    if (!settings.pestWarningEnabled) return;
    if (settings.isQuietTime()) return;

    final humidity = (weatherData['main']?['humidity'] ?? 0).toInt();
    final temp = (weatherData['main']?['temp'] ?? 0).toDouble();
    final conditionId = weatherData['weather']?[0]?['id'] ?? 800;

    String? pestType;
    String? recommendation;

    // High humidity + warm = fungal diseases risk
    if (humidity > 80 && temp > 25) {
      pestType = 'Jamur & Penyakit Tanaman';
      recommendation =
          'Kelembaban tinggi meningkatkan risiko jamur.\n💡 Periksa daun dan siapkan fungisida!';
    }
    // After rain = caterpillar risk
    else if (conditionId >= 500 && conditionId < 600) {
      pestType = 'Ulat & Hama Setelah Hujan';
      recommendation =
          'Setelah hujan, ulat sering menyerang.\n💡 Periksa bagian bawah daun!';
    }
    // Hot & dry = wereng/planthopper risk
    else if (temp > 32 && humidity < 60) {
      pestType = 'Wereng & Hama Kering';
      recommendation =
          'Cuaca panas-kering meningkatkan risiko wereng.\n💡 Periksa batang padi!';
    }

    if (pestType != null && recommendation != null) {
      await _notificationService.showNotification(
        id: _pestWarningId,
        title: '🐛 Waspada $pestType!',
        body: recommendation,
        payload: 'pest_warning',
      );
    }
  }

  /// Schedule calendar-based reminders for a planting schedule
  Future<void> scheduleCalendarReminders({
    required int scheduleId,
    required String plantName,
    required DateTime scheduledDateTime,
  }) async {
    final settings = getSettings();
    final notif = _notificationService;

    // 1 day before
    if (settings.reminder1DayBefore) {
      final reminderTime = scheduledDateTime.subtract(const Duration(days: 1));
      if (reminderTime.isAfter(DateTime.now())) {
        await notif.scheduleNotification(
          id: 100000 + scheduleId * 10 + 0,
          title: '📅 Pengingat Besok',
          body: 'Besok: $plantName',
          scheduledDate: reminderTime,
        );
      }
    }

    // 1 hour before
    if (settings.reminder1HourBefore) {
      final reminderTime = scheduledDateTime.subtract(const Duration(hours: 1));
      if (reminderTime.isAfter(DateTime.now())) {
        await notif.scheduleNotification(
          id: 100000 + scheduleId * 10 + 1,
          title: '⏰ 1 Jam Lagi!',
          body: '$plantName dalam 1 jam',
          scheduledDate: reminderTime,
        );
      }
    }

    // At scheduled time
    if (settings.reminderAtTime) {
      if (scheduledDateTime.isAfter(DateTime.now())) {
        await notif.scheduleNotification(
          id: 100000 + scheduleId * 10 + 2,
          title: '🌱 Waktunya Kegiatan!',
          body: 'Sekarang: $plantName',
          scheduledDate: scheduledDateTime,
        );
      }
    }
  }

  /// Cancel all calendar reminders for a schedule
  Future<void> cancelCalendarReminders(int scheduleId) async {
    await _notificationService.cancelNotification(100000 + scheduleId * 10 + 0);
    await _notificationService.cancelNotification(100000 + scheduleId * 10 + 1);
    await _notificationService.cancelNotification(100000 + scheduleId * 10 + 2);
  }
}
