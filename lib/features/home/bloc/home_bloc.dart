import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';

import 'package:agrinova/data/repositories/weather_repository.dart';
import 'package:agrinova/core/services/cache_service.dart';
import 'package:agrinova/utils/weather_utils.dart';

part 'home_event.dart';
part 'home_state.dart';

/// BLoC untuk mengelola state Home Screen
/// Menangani: loading data cuaca, caching, lokasi GPS, dan rekomendasi tanaman
class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final WeatherRepository _weatherRepository;
  final CacheService _cacheService;

  HomeBloc({
    required WeatherRepository weatherRepository,
    required CacheService cacheService,
  })  : _weatherRepository = weatherRepository,
        _cacheService = cacheService,
        super(HomeInitial()) {
    on<LoadHomeData>(_onLoadHomeData);
    on<RefreshHomeData>(_onRefreshHomeData);
  }

  /// Handle event LoadHomeData - dipanggil saat aplikasi mulai
  Future<void> _onLoadHomeData(
    LoadHomeData event,
    Emitter<HomeState> emit,
  ) async {
    emit(const HomeLoading());

    // Check if offline mode is enabled
    final offlineMode = _cacheService.getOfflineMode();

    // Load dari cache dulu agar tampilan tidak kosong
    final cachedState = _loadFromCache();
    if (cachedState != null) {
      emit(cachedState.copyWith(isOnline: !offlineMode));
    }

    // Jika offline mode aktif, hanya gunakan cache
    if (offlineMode) {
      if (cachedState == null) {
        emit(const HomeError(
            message: 'Tidak ada data tersimpan. Hubungkan ke internet.'));
      }
      return;
    }

    // Fetch data baru dari internet
    await _checkLocationPermissionAndFetch(emit, cachedState);
  }

  /// Handle event RefreshHomeData - dipanggil saat pull-to-refresh
  Future<void> _onRefreshHomeData(
    RefreshHomeData event,
    Emitter<HomeState> emit,
  ) async {
    // Jika state sekarang adalah HomeLoaded, gunakan sebagai base
    final currentState = state;

    // Check offline mode
    final offlineMode = _cacheService.getOfflineMode();
    if (offlineMode) {
      // Tetap di state sekarang, tidak bisa refresh saat offline
      return;
    }

    if (currentState is HomeLoaded) {
      emit(const HomeLoading(isRefreshing: true));
    } else {
      emit(const HomeLoading());
    }

    await _checkLocationPermissionAndFetch(
      emit,
      currentState is HomeLoaded ? currentState : null,
    );
  }

  /// Load data dari cache via repository
  HomeLoaded? _loadFromCache() {
    try {
      final cachedWeather = _cacheService.getCachedCurrentWeather();
      final cachedForecast = _cacheService.getCachedForecast();
      final cachedLocation = _weatherRepository.getCachedLocation();
      final cachedShortLocation = _weatherRepository.getCachedShortLocation();
      final cacheTime = _weatherRepository.getCacheTime();

      if (cachedWeather != null) {
        final alertMessage = _generateRecommendation(cachedWeather);

        return HomeLoaded(
          currentWeather: cachedWeather,
          forecastList: cachedForecast ?? [],
          detailedLocation: cachedLocation,
          shortLocation: cachedShortLocation,
          lastSyncTime: cacheTime,
          isOnline: false,
          alertMessage: alertMessage,
        );
      }
    } catch (e) {
      debugPrint("Error loading cache: $e");
    }
    return null;
  }

  /// Check location permission dan fetch data
  Future<void> _checkLocationPermissionAndFetch(
    Emitter<HomeState> emit,
    HomeLoaded? fallbackState,
  ) async {
    // Skip if offline mode is enabled
    final offlineMode = _cacheService.getOfflineMode();
    if (offlineMode) {
      if (fallbackState != null) {
        emit(fallbackState.copyWith(isOnline: false));
      } else {
        emit(const HomeError(
            message: 'Mode offline aktif. Tidak ada data tersimpan.'));
      }
      return;
    }

    try {
      // Add timeout to prevent hanging on startup
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled()
          .timeout(const Duration(seconds: 5), onTimeout: () => false);

      if (!serviceEnabled) {
        debugPrint("Location service disabled or timed out");
        await _fetchData(emit, fallbackState);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission()
          .timeout(const Duration(seconds: 5),
              onTimeout: () => LocationPermission.denied);

      if (permission == LocationPermission.denied) {
        // Only wait 15 seconds for user response
        permission = await Geolocator.requestPermission().timeout(
            const Duration(seconds: 15),
            onTimeout: () => LocationPermission.denied);

        if (permission == LocationPermission.denied) {
          debugPrint("Location permission denied");
          await _fetchData(emit, fallbackState);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint("Location permission denied forever");
        await _fetchData(emit, fallbackState);
        return;
      }

      // Gunakan akurasi Low agar lebih cepat mengunci lokasi
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 10),
      );

      await _fetchData(
        emit,
        fallbackState,
        lat: position.latitude,
        lon: position.longitude,
      );
    } catch (e) {
      debugPrint("Location error or timeout: $e");
      // Check offline mode again before fallback fetch
      if (!_cacheService.getOfflineMode()) {
        await _fetchData(emit, fallbackState);
      } else {
        if (fallbackState != null) {
          emit(fallbackState.copyWith(isOnline: false));
        } else {
          emit(const HomeError(message: 'Gagal mendapatkan lokasi.'));
        }
      }
    }
  }

  /// Fetch data cuaca dari Repository
  Future<void> _fetchData(
    Emitter<HomeState> emit,
    HomeLoaded? fallbackState, {
    double? lat,
    double? lon,
  }) async {
    try {
      // Fetch weather data via Repository
      final current =
          await _weatherRepository.fetchCurrentWeather(lat: lat, lon: lon);
      final forecastList =
          await _weatherRepository.fetchForecast(lat: lat, lon: lon);

      // Fetch location via Repository
      String? locationStr;
      String? shortLocationStr;
      if (lat != null && lon != null) {
        final locationMap = await _weatherRepository.fetchDetailedLocation(lat, lon);
        locationStr = locationMap['full'];
        shortLocationStr = locationMap['short'];
      }

      // Save to cache via Repository — hanya jika data benar-benar dari API,
      // bukan dari dummy fallback. Dummy data di-persist akan menyebabkan
      // crash berulang karena schema tidak lengkap.
      final isRealApiData = current.containsKey('coord') || current.containsKey('sys');
      if (isRealApiData) {
        await _weatherRepository.saveWeatherToCache(
          currentWeather: current,
          forecastList: forecastList,
        );
      }

      // Generate rekomendasi tanaman
      final alertMessage = _generateRecommendation(current);

      emit(HomeLoaded(
        currentWeather: current,
        forecastList: forecastList,
        detailedLocation: locationStr ?? _weatherRepository.getCachedLocation(),
        shortLocation: shortLocationStr ?? _weatherRepository.getCachedShortLocation(),
        lastSyncTime: DateTime.now(),
        isOnline: true,
        alertMessage: alertMessage,
        isRealTimeGps: lat != null && lon != null,
      ));
    } catch (e) {
      debugPrint("Fetch data error: $e");
      // Jika error tapi sudah ada fallback state, gunakan itu
      if (fallbackState != null) {
        emit(fallbackState.copyWith(isOnline: false));
      } else {
        // Coba load dari cache sebagai last resort
        final cachedState = _loadFromCache();
        if (cachedState != null) {
          emit(cachedState.copyWith(isOnline: false));
        } else {
          emit(const HomeError(
            message: 'Gagal memuat data. Periksa koneksi internet.',
          ));
        }
      }
    }
  }

  /// Generate rekomendasi tanaman berdasarkan kondisi cuaca
  String? _generateRecommendation(Map<String, dynamic>? current) {
    if (current == null || current['weather'] == null) return null;

    final List<dynamic> weatherList = current['weather'];
    if (weatherList.isEmpty) return null;

    final conditionId = weatherList[0]['id'];
    if (conditionId is! int) return null;

    final temp = (current['main']?['temp'] as num?)?.round();
    if (temp != null) {
      WeatherUtils.updateTemperature(temp);
    }

    return WeatherUtils.getRecommendation(conditionId);
  }
}
