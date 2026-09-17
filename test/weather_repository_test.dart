import 'package:flutter_test/flutter_test.dart';
import 'package:agrinova/data/repositories/weather_repository.dart';
import 'package:agrinova/data/datasources/weather_service.dart';
import 'package:agrinova/data/datasources/location_service.dart';
import 'package:agrinova/core/services/cache_service.dart';

class MockWeatherService extends WeatherService {
  bool shouldThrow = false;

  @override
  Future<Map<String, dynamic>> fetchCurrentWeather(
      {required double lat, required double lon}) async {
    if (shouldThrow) {
      throw Exception('Network error');
    }
    return {
      'coord': {'lat': lat, 'lon': lon},
      'main': {'temp': 30.0, 'humidity': 80},
      'weather': [{'id': 800, 'main': 'Clear', 'description': 'Cerah', 'icon': '01d'}],
      'name': 'Bandung',
    };
  }

  @override
  Future<Map<String, dynamic>> fetchForecast(
      {required double lat, required double lon}) async {
    if (shouldThrow) {
      throw Exception('Network error');
    }
    return {
      'list': [
        {
          'dt': 1600000000,
          'main': {'temp': 29.0},
          'weather': [{'id': 800, 'main': 'Clear', 'description': 'Cerah', 'icon': '01d'}],
        }
      ]
    };
  }
}

class MockLocationService extends LocationService {}

class MockCacheService extends CacheService {
  MockCacheService() : super.forTesting();

  Map<String, dynamic>? cachedWeather;
  List<dynamic>? cachedForecast;
  bool isOffline = false;

  @override
  bool getOfflineMode() => isOffline;

  @override
  Map<String, dynamic>? getCachedCurrentWeather() => cachedWeather;

  @override
  List<dynamic>? getCachedForecast() => cachedForecast;

  @override
  Map<String, double>? getCachedCoordinates() => {'latitude': -6.9175, 'longitude': 107.6191};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WeatherRepository Tests', () {
    late WeatherRepository repository;
    late MockWeatherService mockWeatherService;
    late MockLocationService mockLocationService;
    late MockCacheService mockCacheService;

    setUp(() {
      mockWeatherService = MockWeatherService();
      mockLocationService = MockLocationService();
      mockCacheService = MockCacheService();
      repository = WeatherRepository(
        weatherService: mockWeatherService,
        locationService: mockLocationService,
        cacheService: mockCacheService,
      );
    });

    test('fetchCurrentWeather returns API data on success', () async {
      final result = await repository.fetchCurrentWeather(lat: -6.9, lon: 107.6);
      expect(result['name'], 'Bandung');
      expect(result['main']['temp'], 30.0);
    });

    test('fetchCurrentWeather falls back to cache when API fails and cache exists', () async {
      mockWeatherService.shouldThrow = true;
      mockCacheService.cachedWeather = {
        'main': {'temp': 26.0},
        'weather': [{'id': 801, 'main': 'Clouds', 'description': 'Berawan', 'icon': '02d'}],
        'name': 'Cached City',
      };

      final result = await repository.fetchCurrentWeather(lat: -6.9, lon: 107.6);
      expect(result['name'], 'Cached City');
      expect(result['main']['temp'], 26.0);
    });

    test('fetchCurrentWeather falls back to dummy when API fails and cache is empty', () async {
      mockWeatherService.shouldThrow = true;
      mockCacheService.cachedWeather = null;

      final result = await repository.fetchCurrentWeather(lat: -6.9, lon: 107.6);
      expect(result['name'], 'Lokasi Anda');
      expect(result.containsKey('main'), true);
      expect(result.containsKey('weather'), true);
    });

    test('fetchForecast returns forecast list on success', () async {
      final result = await repository.fetchForecast(lat: -6.9, lon: 107.6);
      expect(result.length, 1);
      expect(result.first['main']['temp'], 29.0);
    });

    test('fetchForecast falls back to dummy when API fails', () async {
      mockWeatherService.shouldThrow = true;
      mockCacheService.cachedForecast = null;

      final result = await repository.fetchForecast(lat: -6.9, lon: 107.6);
      expect(result.isNotEmpty, true);
      expect(result.first.containsKey('dt'), true);
      expect(result.first.containsKey('main'), true);
    });
  });
}
