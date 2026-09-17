import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:agrinova/core/services/cache_service.dart';
import 'package:agrinova/core/services/app_logger.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final CacheService _cacheService = CacheService();

  // Stream controller to broadcast offline status to UI
  final _offlineStatusController = StreamController<bool>.broadcast();
  Stream<bool> get offlineStatusStream => _offlineStatusController.stream;

  // Subscription to connectivity changes
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  Future<void> init() async {
    // Check initial status without awaiting to block app startup
    _connectivity.checkConnectivity().then((result) {
      _updateStatus(result);
    });

    // Listen for changes
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      _updateStatus(results);
    });
  }

  void _updateStatus(List<ConnectivityResult> results) {
    // If any result is not none, we are connected (conceptually)
    // But usually we check if it contains mobile or wifi
    bool isConnected = results.any((r) =>
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.ethernet);

    // If completely none, definitely offline
    if (results.contains(ConnectivityResult.none) && results.length == 1) {
      isConnected = false;
    }

    bool isOffline = !isConnected;

    if (kDebugMode) {
      AppLogger().debug('Agrinova', 'Connectivity changed: $results -> Offline: $isOffline');
    }

    // Catat status koneksi sistem (terpisah dari preferensi offline user)
    _cacheService.setConnected(isConnected);

    // Notify UI listeners
    _offlineStatusController.add(isOffline);
  }

  void dispose() {
    _subscription?.cancel();
    _offlineStatusController.close();
  }
}
