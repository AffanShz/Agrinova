import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:agrinova/data/repositories/weather_repository.dart';
import 'package:agrinova/core/services/cache_service.dart';
import 'package:agrinova/features/weather/widgets/weather_widgets.dart';

class WeatherDetailScreen extends StatefulWidget {
  const WeatherDetailScreen({super.key});

  @override
  State<WeatherDetailScreen> createState() => _WeatherDetailScreenState();
}

class _WeatherDetailScreenState extends State<WeatherDetailScreen> {
  late final WeatherRepository _weatherRepository;
  bool _isRepositoryInitialized = false;

  bool isLoading = true;
  String errorMessage = "";
  Map<String, dynamic>? currentWeather;
  List<dynamic> forecastList = [];
  String? detailedLocation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isRepositoryInitialized) {
      _weatherRepository = context.read<WeatherRepository>();
      _loadData();
      _isRepositoryInitialized = true;
    }
  }

  @override
  void initState() {
    super.initState();
  }

  Future<void> _loadData() async {
    final offlineMode = CacheService().getOfflineMode();
    if (offlineMode) {
      _loadFromCache();
      return;
    }

    _loadFromCache();
    await _fetchWeatherData();
  }

  void _loadFromCache() {
    final cachedWeather = CacheService().getCachedCurrentWeather();
    final cachedForecast = CacheService().getCachedForecast();
    final cachedLocation = CacheService().getCachedDetailedLocation();

    if (cachedWeather != null && mounted) {
      setState(() {
        currentWeather = cachedWeather;
        forecastList = cachedForecast ?? [];
        detailedLocation = cachedLocation;
        isLoading = false;
      });
    }
  }

  Future<void> _fetchWeatherData() async {
    if (currentWeather == null && mounted) {
      setState(() {
        isLoading = true;
        errorMessage = "";
      });
    }

    try {
      double? lat;
      double? lon;

      final cachedCoords = CacheService().getCachedCoordinates();
      if (cachedCoords != null) {
        lat = cachedCoords['latitude'];
        lon = cachedCoords['longitude'];
      }

      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled()
            .timeout(const Duration(seconds: 5), onTimeout: () => false);

        if (serviceEnabled) {
          LocationPermission permission = await Geolocator.checkPermission()
              .timeout(const Duration(seconds: 5),
                  onTimeout: () => LocationPermission.denied);

          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission().timeout(
                const Duration(seconds: 15),
                onTimeout: () => LocationPermission.denied);
          }

          if (permission == LocationPermission.whileInUse ||
              permission == LocationPermission.always) {
            Position position = await Geolocator.getCurrentPosition(
                desiredAccuracy: LocationAccuracy.low,
                timeLimit: const Duration(seconds: 10));
            lat = position.latitude;
            lon = position.longitude;
          }
        }
      } catch (e) {
        debugPrint("Location error in WeatherDetail: $e");
      }

      final current =
          await _weatherRepository.fetchCurrentWeather(lat: lat, lon: lon);
      final forecast =
          await _weatherRepository.fetchForecast(lat: lat, lon: lon);

      String? locationStr;
      if (lat != null && lon != null) {
        final locResult = await _weatherRepository.fetchDetailedLocation(lat, lon);
        locationStr = locResult['full'];
      }

      if (mounted) {
        setState(() {
          currentWeather = current;
          forecastList = forecast;
          detailedLocation =
              locationStr ?? _weatherRepository.getCachedLocation();
          isLoading = false;
          errorMessage = "";
        });
      }
    } catch (e) {
      debugPrint("Weather fetch error: $e");
      if (currentWeather == null && mounted) {
        setState(() {
          errorMessage = "weather.load_error".tr();
          isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _getDailyForecast() {
    Map<String, Map<String, dynamic>> dailyData = {};
    final now = DateTime.now();
    final todayKey = DateFormat('yyyy-MM-dd').format(now);

    // 1. Add today from currentWeather data (if available)
    if (currentWeather != null) {
      final main = currentWeather!['main'];
      final weather = currentWeather!['weather'][0];
      dailyData[todayKey] = {
        'date': now,
        'minTemp': (main['temp_min'] as num?)?.toDouble() ??
            (main['temp'] as num).toDouble(),
        'maxTemp': (main['temp_max'] as num?)?.toDouble() ??
            (main['temp'] as num).toDouble(),
        'weatherMain': weather['main'],
        'icon': weather['icon'],
        'pop':
            0.0, // Current weather doesn't have pop, will be updated from forecast
      };
    }

    // 2. Process forecast data
    for (var item in forecastList) {
      DateTime date = DateTime.parse(item['dt_txt']);
      String dayKey = DateFormat('yyyy-MM-dd').format(date);

      double temp = (item['main']['temp'] as num).toDouble();
      double pop = (item['pop'] as num?)?.toDouble() ?? 0;
      String weatherMain = item['weather'][0]['main'];
      String icon = item['weather'][0]['icon'];

      if (!dailyData.containsKey(dayKey)) {
        dailyData[dayKey] = {
          'date': date,
          'minTemp': temp,
          'maxTemp': temp,
          'weatherMain': weatherMain,
          'icon': icon,
          'pop': pop,
        };
      } else {
        // Update min/max temps
        if (temp < dailyData[dayKey]!['minTemp']) {
          dailyData[dayKey]!['minTemp'] = temp;
        }
        if (temp > dailyData[dayKey]!['maxTemp']) {
          dailyData[dayKey]!['maxTemp'] = temp;
        }
        // Update pop to max value
        if (pop > (dailyData[dayKey]!['pop'] as double)) {
          dailyData[dayKey]!['pop'] = pop;
        }
        // Use midday weather for icon
        if (date.hour >= 11 && date.hour <= 14) {
          dailyData[dayKey]!['weatherMain'] = weatherMain;
          dailyData[dayKey]!['icon'] = icon;
        }
      }
    }

    // 3. Sort by date and take 7 days
    final sortedDays = dailyData.entries.toList()
      ..sort((a, b) =>
          (a.value['date'] as DateTime).compareTo(b.value['date'] as DateTime));

    return sortedDays.map((e) => e.value).take(7).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('weather.detail_title'.tr()),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (!CacheService().getOfflineMode()) {
                _fetchWeatherData();
              }
            },
          ),
        ],
      ),
      body: isLoading && currentWeather == null
          ? const Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty && currentWeather == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(errorMessage, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: Text('common.retry'.tr()),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    if (!CacheService().getOfflineMode()) {
                      await _fetchWeatherData();
                    }
                  },
                  child: _buildContent(),
                ),
    );
  }

  Widget _buildContent() {
    if (currentWeather == null) return const SizedBox();

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Main Weather Card (extracted widget)
            MainWeatherCard(
              currentWeather: currentWeather!,
              detailedLocation: detailedLocation,
            ),
            const SizedBox(height: 24),
            // Hourly Forecast Section
            HourlyForecastWidget(hourlyForecast: forecastList),
            // Daily Forecast Section
            DailyForecastWidget(dailyData: _getDailyForecast()),
          ],
        ),
      ),
    );
  }
}
