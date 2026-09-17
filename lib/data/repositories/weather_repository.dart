import 'package:flutter/foundation.dart';
import 'package:agrinova/data/datasources/weather_service.dart';
import 'package:agrinova/data/datasources/location_service.dart';
import 'package:agrinova/core/services/cache_service.dart';

/// Repository untuk mengelola data Cuaca
/// Abstraksi antara BLoC dan datasource (API/Cache)
class WeatherRepository {
  final WeatherService _weatherService;
  final LocationService _locationService;
  final CacheService _cacheService;

  WeatherRepository({
    required WeatherService weatherService,
    required LocationService locationService,
    required CacheService cacheService,
  })  : _weatherService = weatherService,
        _locationService = locationService,
        _cacheService = cacheService;

  /// Dummy data cuaca saat ini untuk fallback — struktur mengikuti OpenWeatherMap API
  static Map<String, dynamic> _buildDummyCurrentWeather() => {
    'main': {
      'temp': 28.5,
      'feels_like': 30.2,
      'temp_min': 25.0,
      'temp_max': 31.0,
      'pressure': 1013,
      'humidity': 72,
    },
    'weather': [
      {
        'id': 803,
        'main': 'Clouds',
        'description': 'Berawan',
        'icon': '04d',
      }
    ],
    'clouds': {'all': 60},
    'wind': {
      'speed': 3.5,
      'deg': 230,
    },
    'visibility': 9000,
    'dt': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    'name': 'Lokasi Anda',
  };

  /// Dummy forecast cuaca untuk fallback — dibangun fresh setiap dipanggil.
  /// Schema harus persis mengikuti OpenWeatherMap 5-day/3-hour forecast API
  /// agar konsumen (forecast_list, hourly_forecast_widget, weather_detail_screen)
  /// tidak crash saat membaca item['main']['temp'] & item['weather'][0]['icon'].
  static List<dynamic> _buildDummyForecast() {
    final now = DateTime.now();
    return [
      {
        'dt': now.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
        'main': {'temp': 28.0, 'temp_min': 27.0, 'temp_max': 29.0, 'humidity': 70, 'pressure': 1013},
        'weather': [{'id': 803, 'main': 'Clouds', 'description': 'Berawan', 'icon': '04d'}],
        'pop': 0.0,
        'wind': {'speed': 3.0, 'deg': 200},
        'dt_txt': now.add(const Duration(hours: 1)).toIso8601String(),
      },
      {
        'dt': now.add(const Duration(hours: 7)).millisecondsSinceEpoch ~/ 1000,
        'main': {'temp': 27.5, 'temp_min': 26.0, 'temp_max': 28.5, 'humidity': 75, 'pressure': 1012},
        'weather': [{'id': 500, 'main': 'Rain', 'description': 'Hujan ringan', 'icon': '10d'}],
        'pop': 0.3,
        'wind': {'speed': 4.0, 'deg': 210},
        'dt_txt': now.add(const Duration(hours: 7)).toIso8601String(),
      },
      {
        'dt': now.add(const Duration(hours: 13)).millisecondsSinceEpoch ~/ 1000,
        'main': {'temp': 25.0, 'temp_min': 24.0, 'temp_max': 26.0, 'humidity': 85, 'pressure': 1011},
        'weather': [{'id': 501, 'main': 'Rain', 'description': 'Hujan', 'icon': '10n'}],
        'pop': 0.8,
        'wind': {'speed': 5.0, 'deg': 220},
        'dt_txt': now.add(const Duration(hours: 13)).toIso8601String(),
      },
      {
        'dt': now.add(const Duration(hours: 19)).millisecondsSinceEpoch ~/ 1000,
        'main': {'temp': 24.5, 'temp_min': 23.5, 'temp_max': 25.5, 'humidity': 72, 'pressure': 1012},
        'weather': [{'id': 802, 'main': 'Clouds', 'description': 'Berawan', 'icon': '03n'}],
        'pop': 0.2,
        'wind': {'speed': 3.5, 'deg': 230},
        'dt_txt': now.add(const Duration(hours: 19)).toIso8601String(),
      },
    ];
  }

  /// Fetch cuaca saat ini
  /// Fallback: cache → dummy data lokal
  Future<Map<String, dynamic>> fetchCurrentWeather({
    double? lat,
    double? lon,
  }) async {
    // Cek offline mode
    final offlineMode = _cacheService.getOfflineMode();

    // Resolve coordinates: provided -> cache -> fallback (Jakarta)
    double resolvedLat = lat ?? _cacheService.getCachedCoordinates()?['latitude'] ?? -6.2088;
    double resolvedLon = lon ?? _cacheService.getCachedCoordinates()?['longitude'] ?? 106.8456;

    // Load dari cache dulu
    final cachedWeather = _cacheService.getCachedCurrentWeather();
    if (cachedWeather != null) {
      debugPrint('WeatherRepository: Loaded weather from cache');

      if (offlineMode) {
        return cachedWeather;
      }
    }

    // Fetch dari API
    try {
      final weather =
          await _weatherService.fetchCurrentWeather(lat: resolvedLat, lon: resolvedLon);
      return weather;
    } catch (e) {
      debugPrint('WeatherRepository: API error - $e');

      // Fallback ke cache jika API gagal
      if (cachedWeather != null) {
        return cachedWeather;
      }

      // Fallback terakhir: gunakan dummy data lokal
      debugPrint('WeatherRepository: Using dummy weather data as fallback');
      return _buildDummyCurrentWeather();
    }
  }

  /// Fetch forecast cuaca
  /// Fallback: cache → dummy data lokal
  Future<List<dynamic>> fetchForecast({
    double? lat,
    double? lon,
  }) async {
    // Cek offline mode
    final offlineMode = _cacheService.getOfflineMode();

    // Resolve coordinates
    double resolvedLat = lat ?? _cacheService.getCachedCoordinates()?['latitude'] ?? -6.2088;
    double resolvedLon = lon ?? _cacheService.getCachedCoordinates()?['longitude'] ?? 106.8456;

    // Load dari cache dulu
    final cachedForecast = _cacheService.getCachedForecast();
    if (cachedForecast != null) {
      debugPrint('WeatherRepository: Loaded forecast from cache');

      if (offlineMode) {
        return cachedForecast;
      }
    }

    // Fetch dari API
    try {
      final forecast = await _weatherService.fetchForecast(lat: resolvedLat, lon: resolvedLon);
      return forecast['list'] ?? [];
    } catch (e) {
      debugPrint('WeatherRepository: API error - $e');

      // Fallback ke cache jika API gagal
      if (cachedForecast != null) {
        return cachedForecast;
      }

      // Fallback terakhir: gunakan dummy forecast lokal
      debugPrint('WeatherRepository: Using dummy forecast data as fallback');
      return _buildDummyForecast();
    }
  }

  /// Fetch lokasi detail
  Future<Map<String, String?>> fetchDetailedLocation(double lat, double lon) async {
    try {
      final locationData = await _locationService.getDetailedLocation(lat, lon);
      final locationStr = locationData['full'];
      final shortStr = locationData['short'];

      // Save ke cache
      if (locationStr != null && locationStr.isNotEmpty) {
        await _cacheService.saveLocationData(
          locationStr,
          shortStr ?? locationStr,
          lat,
          lon,
        );
      }

      return {
        'full': locationStr,
        'short': shortStr?.isNotEmpty == true ? shortStr : locationStr,
      };
    } catch (e) {
      debugPrint('WeatherRepository: Location error - $e');
      // Fallback ke cached location atau dummy
      final cachedFull = _cacheService.getCachedDetailedLocation() ?? 'Jakarta, Indonesia';
      final cachedShort = _cacheService.getCachedShortLocation() ?? cachedFull;
      return {
        'full': cachedFull,
        'short': cachedShort,
      };
    }
  }

  /// Simpan data cuaca ke cache
  Future<void> saveWeatherToCache({
    required Map<String, dynamic> currentWeather,
    required List<dynamic> forecastList,
  }) async {
    await _cacheService.saveWeatherData(
      currentWeather: currentWeather,
      forecastList: forecastList,
    );
  }

  /// Get cached location
  String? getCachedLocation() {
    return _cacheService.getCachedDetailedLocation();
  }

  /// Get cached short location
  String? getCachedShortLocation() {
    return _cacheService.getCachedShortLocation() ?? _cacheService.getCachedDetailedLocation();
  }

  /// Get cache time
  DateTime? getCacheTime() {
    return _cacheService.getWeatherCacheTime();
  }
}
