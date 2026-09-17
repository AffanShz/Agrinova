import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:agrinova/data/models/notification_settings.dart';

import 'package:agrinova/data/models/chat_session.dart';
import 'package:agrinova/core/services/app_logger.dart';

/// Service for caching API data locally using Hive
/// Supports offline-first approach: load cache first, then fetch API
class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  @visibleForTesting
  CacheService.forTesting();

  // Profile update stream
  final _profileUpdateController =
      StreamController<Map<String, String?>>.broadcast();
  Stream<Map<String, String?>> get profileUpdateStream =>
      _profileUpdateController.stream;

  // Subscription update stream
  final _subscriptionUpdateController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get subscriptionUpdateStream =>
      _subscriptionUpdateController.stream;

  // Box names
  static const String _weatherBoxName = 'weatherCache';
  static const String _tipsBoxName = 'tipsCache';
  static const String _pestsBoxName = 'pestsCache';
  static const String _drugsBoxName = 'drugsCache';
  static const String _locationBoxName = 'locationCache';
  static const String _settingsBoxName = 'settingsCache';
  static const String _notificationHistoryBoxName = 'notificationHistory';
  static const String _chatSessionsBoxName = 'chatSessionsCache';

  /// Initialize Hive and open all boxes with encryption
  /// Call this in main() before runApp()
  static Future<void> init() async {
    await Hive.initFlutter();

    final encryptionKey = await _getEncryptionKey();

    await Hive.openBox(_weatherBoxName,
        encryptionCipher: HiveAesCipher(encryptionKey));
    await Hive.openBox(_tipsBoxName,
        encryptionCipher: HiveAesCipher(encryptionKey));
    await Hive.openBox(_pestsBoxName,
        encryptionCipher: HiveAesCipher(encryptionKey));
    await Hive.openBox(_drugsBoxName,
        encryptionCipher: HiveAesCipher(encryptionKey));
    await Hive.openBox(_locationBoxName,
        encryptionCipher: HiveAesCipher(encryptionKey));
    await Hive.openBox(_settingsBoxName,
        encryptionCipher: HiveAesCipher(encryptionKey));
    await Hive.openBox(_plantingScheduleBoxName,
        encryptionCipher: HiveAesCipher(encryptionKey));
    await Hive.openBox(_notificationHistoryBoxName,
        encryptionCipher: HiveAesCipher(encryptionKey));
    await Hive.openBox(_chatSessionsBoxName,
        encryptionCipher: HiveAesCipher(encryptionKey));
  }

  static Future<List<int>> _getEncryptionKey() async {
    const secureStorage = FlutterSecureStorage();
    const keyName = 'hive_encryption_key';
    final keyString = await secureStorage.read(key: keyName);

    if (keyString == null) {
      final key = Hive.generateSecureKey();
      await secureStorage.write(
        key: keyName,
        value: base64UrlEncode(key),
      );
      return key;
    } else {
      return base64Url.decode(keyString);
    }
  }

  static const String _plantingScheduleBoxName = 'plantingSchedule';

  // ==================== SETTINGS & ONBOARDING ====================

  /// Check if it's the first time the app is run
  bool isFirstTime() {
    return _settingsBox.get('isFirstTime', defaultValue: true) as bool;
  }

  /// Set first time flag
  Future<void> setFirstTime(bool value) async {
    await _settingsBox.put('isFirstTime', value);
  }

  // ==================== WEATHER CACHE ====================

  Box get _weatherBox => Hive.box(_weatherBoxName);

  /// Save current weather and forecast to cache
  Future<void> saveWeatherData({
    required Map<String, dynamic> currentWeather,
    required List<dynamic> forecastList,
  }) async {
    await _weatherBox.put('currentWeather', currentWeather);
    await _weatherBox.put('forecastList', forecastList);
    await _weatherBox.put('lastUpdated', DateTime.now().toIso8601String());
  }

  /// Get cached current weather
  Map<String, dynamic>? getCachedCurrentWeather() {
    final data = _weatherBox.get('currentWeather');
    if (data != null) {
      return Map<String, dynamic>.from(data);
    }
    return null;
  }

  /// Get cached forecast list
  List<dynamic>? getCachedForecast() {
    final data = _weatherBox.get('forecastList');
    if (data != null) {
      return List<dynamic>.from(data);
    }
    return null;
  }

  /// Get weather cache timestamp
  DateTime? getWeatherCacheTime() {
    final timestamp = _weatherBox.get('lastUpdated');
    if (timestamp != null) {
      return DateTime.parse(timestamp);
    }
    return null;
  }

  /// Check if weather cache is stale (older than specified minutes)
  bool isWeatherCacheStale({int maxAgeMinutes = 30}) {
    final cacheTime = getWeatherCacheTime();
    if (cacheTime == null) return true;
    return DateTime.now().difference(cacheTime).inMinutes > maxAgeMinutes;
  }

  // ==================== TIPS CACHE ====================

  Box get _tipsBox => Hive.box(_tipsBoxName);

  /// Save tips list to cache
  Future<void> saveTipsData(List<Map<String, dynamic>> tips) async {
    await _tipsBox.put('tips', tips);
    await _tipsBox.put('lastUpdated', DateTime.now().toIso8601String());
  }

  /// Get cached tips list
  List<Map<String, dynamic>>? getCachedTips() {
    return _safeListOfMap(_tipsBox.get('tips'));
  }

  /// Get tips cache timestamp
  DateTime? getTipsCacheTime() {
    final timestamp = _tipsBox.get('lastUpdated');
    if (timestamp != null) {
      return DateTime.parse(timestamp);
    }
    return null;
  }

  // ==================== LOCATION CACHE ====================

  Box get _locationBox => Hive.box(_locationBoxName);

  /// Save detailed location to cache
  Future<void> saveLocationData(
      String detailedLocation, String shortLocation, double lat, double lon) async {
    await _locationBox.put('detailedLocation', detailedLocation);
    await _locationBox.put('shortLocation', shortLocation);
    await _locationBox.put('latitude', lat);
    await _locationBox.put('longitude', lon);
    await _locationBox.put('lastUpdated', DateTime.now().toIso8601String());
  }

  /// Get cached detailed location
  String? getCachedDetailedLocation() {
    return _locationBox.get('detailedLocation');
  }
  
  /// Get cached short location
  String? getCachedShortLocation() {
    return _locationBox.get('shortLocation');
  }

  /// Get cached coordinates
  Map<String, double>? getCachedCoordinates() {
    final lat = _locationBox.get('latitude');
    final lon = _locationBox.get('longitude');
    if (lat != null && lon != null) {
      return {'latitude': lat, 'longitude': lon};
    }
    return null;
  }

  // ==================== PESTS CACHE ====================

  Box get _pestsBox => Hive.box(_pestsBoxName);

  /// Save pests list to cache
  Future<void> savePestsData(List<Map<String, dynamic>> pests) async {
    await _pestsBox.put('pests', pests);
    await _pestsBox.put('pestsLastUpdated', DateTime.now().toIso8601String());
  }

  /// Get cached pests list
  List<Map<String, dynamic>>? getCachedPests() {
    return _safeListOfMap(_pestsBox.get('pests')) ?? _safeListOfMap(_tipsBox.get('pests'));
  }

  // ==================== DRUGS CACHE ====================

  Box get _drugsBox => Hive.box(_drugsBoxName);

  /// Save drugs list to cache
  Future<void> saveDrugsData(List<Map<String, dynamic>> drugs) async {
    await _drugsBox.put('drugs', drugs);
    await _drugsBox.put('drugsLastUpdated', DateTime.now().toIso8601String());
  }

  /// Get cached drugs list
  List<Map<String, dynamic>>? getCachedDrugs() {
    return _safeListOfMap(_drugsBox.get('drugs')) ?? _safeListOfMap(_tipsBox.get('drugs'));
  }

  /// Safe-convert nilai Hive ke List<Map<String, dynamic>>.
  /// Return null jika tipe tidak sesuai (data korup/legacy) sehingga
  /// pemanggil bisa fallback ke API tanpa crash.
  static List<Map<String, dynamic>>? _safeListOfMap(dynamic data) {
    if (data is! List) return null;
    final result = <Map<String, dynamic>>[];
    for (final item in data) {
      if (item is! Map) return null;
      try {
        result.add(Map<String, dynamic>.from(item));
      } catch (_) {
        return null;
      }
    }
    return result;
  }

  // ==================== UTILITY ====================

  /// Clear all cached data EXCEPT subscription/premium data (preserved per-user)
  Future<void> clearAllCache() async {
    await _weatherBox.clear();
    await _tipsBox.clear();
    await _pestsBox.clear();
    await _drugsBox.clear();
    await _locationBox.clear();
    await Hive.box(_plantingScheduleBoxName).clear();
    await _notificationHistoryBox.clear();
    await _chatSessionsBox.clear();
    // Hapus semua settings KECUALI subscription keys (sub_*) yang terikat per user
    await _clearSettingsExceptSubscription();
  }

  /// Hapus settings box tapi pertahankan semua kunci sub_{userId}_* dan global_premium*
  Future<void> _clearSettingsExceptSubscription() async {
    final keysToKeep = _settingsBox.keys
        .where((k) =>
            k.toString().startsWith('sub_') ||
            k.toString().startsWith('global_premium') ||
            k.toString() == 'global_isPremiumActive')
        .toList();
    final preserved = <dynamic, dynamic>{};
    for (final k in keysToKeep) {
      preserved[k] = _settingsBox.get(k);
    }
    await _settingsBox.clear();
    for (final entry in preserved.entries) {
      await _settingsBox.put(entry.key, entry.value);
    }
  }

  /// Restore subscription dari Supabase user metadata ke Hive saat login.
  /// Dipanggil setelah user berhasil login agar status PRO yang tersimpan
  /// di server (Supabase) disinkronkan kembali ke Hive lokal.
  Future<void> restoreSubscriptionOnLogin() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Cek apakah Hive sudah punya data untuk user ini
      final activeKey = _getUserSubKey('isPremiumActive');
      final expiryKey = _getUserSubKey('premiumExpiryDate');
      final planKey = _getUserSubKey('premiumPlanName');

      final hiveHasData = _settingsBox.containsKey(activeKey);

      // Ambil data dari Supabase user metadata
      final meta = user.userMetadata ?? {};
      final serverIsPremium = meta['is_premium'] as bool? ?? false;
      final serverPlan = meta['premium_plan'] as String?;
      final serverExpiry = meta['premium_expiry'] as String?;

      final serverExpiryDate =
          serverExpiry != null ? DateTime.tryParse(serverExpiry) : null;

      if (serverIsPremium &&
          serverExpiryDate != null &&
          serverExpiryDate.isAfter(DateTime.now())) {
        // Server adalah sumber kebenaran saat subscription masih aktif.
        // Ini juga memperbaiki state Hive false/stale setelah login ulang.
        await _settingsBox.put(activeKey, true);
        await _settingsBox.put(expiryKey, serverExpiryDate.toIso8601String());
        if (serverPlan != null) await _settingsBox.put(planKey, serverPlan);
        _scheduleExpiryTimer(serverExpiryDate);
      } else if (!hiveHasData && serverIsPremium && serverExpiry != null) {
        // Hive kosong dan langganan server sudah kedaluwarsa.
        await _settingsBox.put(activeKey, false);
      } else if (hiveHasData) {
        // Hive sudah ada data — jadwalkan timer ulang kalau masih aktif
        final expiryStr = _settingsBox.get(expiryKey) as String?;
        if (expiryStr != null) {
          final expiryDate = DateTime.tryParse(expiryStr);
          if (expiryDate != null && expiryDate.isAfter(DateTime.now())) {
            _scheduleExpiryTimer(expiryDate);
          } else {
            await _settingsBox.put(activeKey, false);
          }
        }
      }

      _subscriptionUpdateController.add(getSubscriptionDetails());
    } catch (e) {
      debugPrint('[CacheService] restoreSubscriptionOnLogin error: $e');
    }
  }

  Box get _settingsBox => Hive.box(_settingsBoxName);

  /// Generic helper to get cached data from settings box
  T? getCachedData<T>(String key) {
    return _settingsBox.get(key) as T?;
  }

  /// Generic helper to save cached data to settings box
  Future<void> saveCachedData(String key, dynamic value) async {
    await _settingsBox.put(key, value);
  }

  /// Set offline mode preference (toggle manual oleh user)
  Future<void> setOfflineMode(bool value) async {
    await _settingsBox.put('offlineMode', value);
  }

  /// Get offline mode preference user (default: false = online)
  bool getUserPrefOfflineMode() {
    final v = _settingsBox.get('offlineMode');
    return v is bool ? v : false;
  }

  /// Catat status koneksi sistem (ditulis oleh ConnectivityService)
  Future<void> setConnected(bool value) async {
    await _settingsBox.put('connected', value);
  }

  /// Status koneksi sistem (default: true hingga ConnectivityService menulis status)
  bool isConnected() {
    final v = _settingsBox.get('connected');
    return v is bool ? v : true;
  }

  /// Offline efektif: preferensi user ATAU tidak ada koneksi internet
  bool getOfflineMode() {
    return getUserPrefOfflineMode() || !isConnected();
  }

  /// Save user profile
  Future<void> saveUserProfile({String? name, String? imagePath}) async {
    if (name != null) await _settingsBox.put('userName', name);
    if (imagePath != null) await _settingsBox.put('userImage', imagePath);

    // Broadcast update
    _profileUpdateController.add(getUserProfile());
  }

  /// Get user profile
  Map<String, String?> getUserProfile() {
    try {
      AppLogger().debug('Agrinova', "CacheService: Getting user profile...");
      final name = _settingsBox.get('userName', defaultValue: 'Pak Tani');
      final image = _settingsBox.get('userImage');

      final result = {
        'name': name?.toString() ?? 'Pak Tani',
        'imagePath': image?.toString()
      };
      AppLogger().debug('Agrinova', "CacheService: Profile found: $result");
      return result;
    } catch (e) {
      AppLogger().debug('Agrinova', 'CacheService: Error getting user profile: $e');
      return {'name': 'Pak Tani', 'imagePath': null};
    }
  }

  // ==================== SUBSCRIPTION & PREMIUM ====================

  Timer? _subscriptionExpiryTimer;

  String _getUserSubKey(String key) {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null && user.id.isNotEmpty) {
        return 'sub_${user.id}_$key';
      }
    } catch (_) {}
    return 'sub_guest_$key';
  }

  void _scheduleExpiryTimer(DateTime expiryDate) {
    _subscriptionExpiryTimer?.cancel();
    final remaining = expiryDate.difference(DateTime.now());
    if (remaining.isNegative) {
      _handleSubscriptionExpired();
      return;
    }

    _subscriptionExpiryTimer = Timer(remaining, () {
      _handleSubscriptionExpired();
    });
  }

  void _handleSubscriptionExpired() {
    final activeKey = _getUserSubKey('isPremiumActive');
    _settingsBox.put(activeKey, false);
    _subscriptionExpiryTimer?.cancel();
    _subscriptionExpiryTimer = null;
    _subscriptionUpdateController.add(getSubscriptionDetails());
  }

  /// Cek apakah status premium sedang aktif
  bool isPremiumActive() {
    try {
      final activeKey = _getUserSubKey('isPremiumActive');
      final expiryKey = _getUserSubKey('premiumExpiryDate');

      final isActive = _settingsBox.get(activeKey, defaultValue: false) as bool;
      if (!isActive) return false;

      final expiryStr = _settingsBox.get(expiryKey) as String?;
      if (expiryStr != null) {
        final expiryDate = DateTime.parse(expiryStr);
        if (DateTime.now().isAfter(expiryDate)) {
          _settingsBox.put(activeKey, false);
          _subscriptionExpiryTimer?.cancel();
          _subscriptionExpiryTimer = null;
          return false;
        } else {
          // Jadwalkan timer otomatis jika belum aktif
          if (_subscriptionExpiryTimer == null ||
              !_subscriptionExpiryTimer!.isActive) {
            _scheduleExpiryTimer(expiryDate);
          }
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Batas jawaban chatbot untuk akun gratis dalam satu hari.
  static const int freeChatLimit = 3;

  /// Penanda periode kuota chat gratis, dalam format 'YYYY-MM-DD'.
  ///
  /// Kuota gratis berlaku per hari kalender, mengikuti waktu lokal perangkat.
  /// Alih-alih memakai timer yang bisa terlewat saat app tidak berjalan,
  /// periode disimpan bersama counter lalu dibandingkan setiap kali dibaca.
  String _currentQuotaPeriod() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  /// Jumlah jawaban chatbot yang sudah terpakai pada periode berjalan.
  ///
  /// Sengaja tidak menulis apa pun supaya tetap sinkron dipanggil dari UI.
  /// Penulisan periode baru dilakukan [incrementFreeChatCount] saat chat
  /// pertama di hari berikutnya.
  int _effectiveFreeChatCount() {
    final countKey = _getUserSubKey('freeChatCount');
    final periodKey = _getUserSubKey('freeChatPeriod');
    final storedPeriod = _settingsBox.get(periodKey) as String?;

    if (storedPeriod != _currentQuotaPeriod()) return 0;
    return _settingsBox.get(countKey, defaultValue: 0) as int;
  }

  /// Tengah malam berikutnya, saat kuota gratis terisi ulang.
  ///
  /// DateTime menormalkan tanggal yang melewati akhir bulan, jadi menambah
  /// satu hari tetap benar pada 31 Desember maupun 28 Februari.
  DateTime _nextQuotaReset() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + 1);
  }

  /// Ambil detail status langganan spesifik untuk akun yang sedang login
  Map<String, dynamic> getSubscriptionDetails() {
    final active = isPremiumActive();
    final planKey = _getUserSubKey('premiumPlanName');
    final expiryKey = _getUserSubKey('premiumExpiryDate');

    final planName =
        _settingsBox.get(planKey, defaultValue: 'Gratis') as String;
    final expiryStr = _settingsBox.get(expiryKey) as String?;
    final chatCount = _effectiveFreeChatCount();

    return {
      'isActive': active,
      'planName': active ? planName : 'Gratis',
      'expiryDate': expiryStr != null ? DateTime.tryParse(expiryStr) : null,
      'freeChatLimit': freeChatLimit,
      'freeChatUsed': chatCount,
      'remainingFreeChats': (freeChatLimit - chatCount).clamp(0, freeChatLimit),
      'freeChatResetDate': _nextQuotaReset(),
    };
  }

  Future<void> setSubscription({
    required bool isActive,
    String? planName,
    DateTime? expiryDate,
  }) async {
    final activeKey = _getUserSubKey('isPremiumActive');
    final planKey = _getUserSubKey('premiumPlanName');
    final expiryKey = _getUserSubKey('premiumExpiryDate');

    await _settingsBox.put(activeKey, isActive);
    await _settingsBox.put('global_isPremiumActive', isActive);

    if (planName != null) {
      await _settingsBox.put(planKey, planName);
      await _settingsBox.put('global_premiumPlanName', planName);
    }
    if (expiryDate != null) {
      await _settingsBox.put(expiryKey, expiryDate.toIso8601String());
      await _settingsBox.put(
          'global_premiumExpiryDate', expiryDate.toIso8601String());
      _scheduleExpiryTimer(expiryDate);
    } else if (!isActive) {
      await _settingsBox.delete(expiryKey);
      await _settingsBox.delete('global_premiumExpiryDate');
      _subscriptionExpiryTimer?.cancel();
      _subscriptionExpiryTimer = null;
    }

    _subscriptionUpdateController.add(getSubscriptionDetails());
  }

  Future<void> syncSubscriptionFromServer() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Panggil RPC server-side yang juga otomatis mengecek & membatalkan
      // jika waktu sudah lewat masa 30 hari
      final response = await Supabase.instance.client
          .rpc('get_or_sync_user_subscription');

      if (response != null && response is Map) {
        final isActive = response['is_active'] as bool? ?? false;
        final planName = response['plan_name'] as String?;
        final expiresAtStr = response['expires_at'] as String?;
        final expiresAt = expiresAtStr != null ? DateTime.tryParse(expiresAtStr) : null;

        if (isActive && expiresAt != null && expiresAt.isAfter(DateTime.now())) {
          await setSubscription(
            isActive: true,
            planName: planName,
            expiryDate: expiresAt,
          );
        } else {
          await setSubscription(isActive: false);
        }
      }
    } catch (e) {
      debugPrint('[CacheService] syncSubscriptionFromServer error: $e');
    }
  }

  Future<int> incrementFreeChatCount() async {
    final countKey = _getUserSubKey('freeChatCount');
    final periodKey = _getUserSubKey('freeChatPeriod');

    final next = _effectiveFreeChatCount() + 1;
    await _settingsBox.put(countKey, next);
    await _settingsBox.put(periodKey, _currentQuotaPeriod());

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await Supabase.instance.client
            .rpc('increment_daily_chat_quota', params: {'p_daily_limit': 3});
      }
    } catch (e) {
      debugPrint('[CacheService] sync increment_daily_chat_quota error: $e');
    }

    _subscriptionUpdateController.add(getSubscriptionDetails());
    return next;
  }

  Future<void> refundFreeChatCount() async {
    final countKey = _getUserSubKey('freeChatCount');
    final current = _effectiveFreeChatCount();
    if (current <= 0) return;

    await _settingsBox.put(countKey, current - 1);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await Supabase.instance.client.rpc('refund_daily_chat_quota');
      }
    } catch (e) {
      debugPrint('[CacheService] sync refund_daily_chat_quota error: $e');
    }

    _subscriptionUpdateController.add(getSubscriptionDetails());
  }

  /// Reset counter chat gratis sebelum periodenya habis
  Future<void> resetFreeChatCount() async {
    final countKey = _getUserSubKey('freeChatCount');
    final periodKey = _getUserSubKey('freeChatPeriod');

    await _settingsBox.put(countKey, 0);
    await _settingsBox.put(periodKey, _currentQuotaPeriod());

    _subscriptionUpdateController.add(getSubscriptionDetails());
  }

  // ==================== NOTIFICATION SETTINGS ====================

  /// Save notification settings
  Future<void> saveNotificationSettings(NotificationSettings settings) async {
    await _settingsBox.put('notificationSettings', settings.toJson());
  }

  /// Get notification settings (returns default if not set)
  NotificationSettings getNotificationSettings() {
    final data = _settingsBox.get('notificationSettings');
    if (data != null) {
      return NotificationSettings.fromJson(Map<String, dynamic>.from(data));
    }
    return const NotificationSettings();
  }

  /// Get last rain date for smart watering feature
  DateTime? getLastRainDate() {
    final timestamp = _settingsBox.get('lastRainDate');
    if (timestamp != null) {
      return DateTime.parse(timestamp);
    }
    return null;
  }

  /// Set last rain date
  Future<void> setLastRainDate(DateTime date) async {
    await _settingsBox.put('lastRainDate', date.toIso8601String());
  }

  // ==================== NOTIFICATION HISTORY ====================

  Box get _notificationHistoryBox => Hive.box(_notificationHistoryBoxName);

  /// Save a new notification to history
  Future<void> saveNotification(Map<String, dynamic> notification) async {
    // Gunakan timestamp sebagai key untuk sorting mudah
    await _notificationHistoryBox.add(notification);
  }

  /// Get all history, sorted by newest first
  /// Riwayat notifikasi yang sudah tayang, terbaru lebih dulu.
  ///
  /// Box ini menyimpan dua macam entri. Notifikasi yang sudah berbunyi, dan
  /// pengingat yang baru dijadwalkan. Yang kedua menyimpan waktu jatuh
  /// temponya di masa depan, sehingga ikut mengacak urutan dan menampilkan
  /// "13 jam lagi" di tengah daftar riwayat.
  ///
  /// Layar ini adalah riwayat, jadi entri yang waktunya belum tiba disaring.
  /// Ia tidak dihapus, hanya belum ditampilkan, dan akan muncul dengan
  /// sendirinya begitu waktunya lewat.
  ///
  /// Sisanya diurutkan menurun berdasarkan 'timestamp', yaitu waktu yang juga
  /// tampil di layar, supaya urutan yang terlihat cocok dengan angka yang
  /// terbaca. 'createdAt' dipakai hanya sebagai pemecah seri.
  List<Map<String, dynamic>> getNotificationHistory() {
    final now = DateTime.now();

    final entries = _notificationHistoryBox.values
        .toList()
        .asMap()
        .entries
        .map((e) => (seq: e.key, data: Map<String, dynamic>.from(e.value)))
        .where((e) {
      final t = DateTime.tryParse(e.data['timestamp'] ?? '');
      return t != null && !t.isAfter(now);
    }).toList();

    entries.sort((a, b) {
      final tA = DateTime.parse(a.data['timestamp']);
      final tB = DateTime.parse(b.data['timestamp']);
      final byTime = tB.compareTo(tA);
      if (byTime != 0) return byTime;

      final cA = DateTime.tryParse(a.data['createdAt'] ?? '');
      final cB = DateTime.tryParse(b.data['createdAt'] ?? '');
      if (cA != null && cB != null) return cB.compareTo(cA);

      return b.seq.compareTo(a.seq);
    });

    return entries.map((e) => e.data).toList();
  }

  /// Remove semua history dengan ID tertentu
  Future<void> removeNotification(int id) async {
    final history = _notificationHistoryBox.values.toList();
    for (int i = history.length - 1; i >= 0; i--) {
      if (history[i]['id'] == id) {
        await _notificationHistoryBox.deleteAt(i);
      }
    }
  }

  /// Clear all history
  Future<void> clearNotificationHistory() async {
    await _notificationHistoryBox.clear();
  }

  // ==================== RAW DATA (generic key-value) ====================

  /// Save arbitrary raw string data by key (used for generic caching like history)
  Future<void> saveRawData(String key, String value) async {
    await _settingsBox.put(key, value);
  }

  /// Get arbitrary raw string data by key
  String? getRawData(String key) {
    final v = _settingsBox.get(key);
    return v?.toString();
  }

  // ==================== CHAT SESSIONS ====================

  Box get _chatSessionsBox => Hive.box(_chatSessionsBoxName);

  /// Save or update a chat session
  Future<void> saveChatSession(ChatSession session) async {
    await _chatSessionsBox.put(session.id, session.toJson());
  }

  /// Get all chat sessions, sorted by newest updated first
  List<ChatSession> getChatSessions() {
    final values = _chatSessionsBox.values.toList();
    final List<ChatSession> sessions = [];

    for (final item in values) {
      if (item is Map) {
        try {
          sessions.add(ChatSession.fromJson(Map<String, dynamic>.from(item)));
        } catch (e) {
          debugPrint('CacheService: Error parsing chat session: $e');
        }
      }
    }

    sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sessions;
  }

  /// Get a single chat session by ID
  ChatSession? getChatSession(String id) {
    final data = _chatSessionsBox.get(id);
    if (data != null && data is Map) {
      try {
        return ChatSession.fromJson(Map<String, dynamic>.from(data));
      } catch (e) {
        debugPrint('CacheService: Error parsing chat session $id: $e');
      }
    }
    return null;
  }

  /// Delete a chat session by ID
  Future<void> deleteChatSession(String id) async {
    await _chatSessionsBox.delete(id);
  }

  /// Clear all chat sessions
  Future<void> clearAllChatSessions() async {
    await _chatSessionsBox.clear();
  }

  /// Save last active chat session ID
  Future<void> setLastActiveChatSessionId(String? id) async {
    if (id == null) {
      await _settingsBox.delete('lastActiveChatSessionId');
    } else {
      await _settingsBox.put('lastActiveChatSessionId', id);
    }
  }

  /// Get last active chat session ID
  String? getLastActiveChatSessionId() {
    return _settingsBox.get('lastActiveChatSessionId') as String?;
  }
}

