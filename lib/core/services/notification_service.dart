import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:agrinova/core/services/cache_service.dart';
import 'package:agrinova/core/services/app_logger.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      tz_data.initializeTimeZones();

      final String timeZoneName = _detectLocalTimeZone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));

      AppLogger().debug('Agrinova', "Timezone set: $timeZoneName");

      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/launcher_icon');

      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
        requestSoundPermission: true,
        requestBadgePermission: true,
        requestAlertPermission: true,
      );

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (details) {
          AppLogger().debug('Agrinova', 'Notification payload: ${details.payload}');
        },
      );

      _isInitialized = true;
    } catch (e) {
      AppLogger().debug('Agrinova', "Init failed: $e");
    }
  }

  String _detectLocalTimeZone() {
    try {
      final int offsetMs = DateTime.now().timeZoneOffset.inMilliseconds;
      final int nowMs = DateTime.now().millisecondsSinceEpoch;
      String? bestMatch;

      for (final loc in tz.timeZoneDatabase.locations.values) {
        if (loc.timeZone(nowMs).offset == offsetMs) {
          bestMatch = loc.name;
          if (bestMatch.startsWith('Asia/Jakarta') ||
              bestMatch.startsWith('Asia/Makassar') ||
              bestMatch.startsWith('Asia/Jayapura')) {
            return bestMatch;
          }
        }
      }

      if (bestMatch != null) return bestMatch;

      final int hourOffset = DateTime.now().timeZoneOffset.inHours;
      switch (hourOffset) {
        case 7:
          return 'Asia/Jakarta';
        case 8:
          return 'Asia/Makassar';
        case 9:
          return 'Asia/Jayapura';
        default:
          return 'Asia/Jakarta';
      }
    } catch (e) {
      return 'Asia/Jakarta';
    }
  }

  Future<void> requestPermissions() async {
    try {
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      final platform =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (platform != null) {
        await platform.requestExactAlarmsPermission();
      }
    } catch (e) {
      AppLogger().debug('Agrinova', "Permission request failed: $e");
    }
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'channel_agrinova_alert_v2',
        'Peringatan Cuaca',
        channelDescription: 'Notifikasi darurat untuk petani',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'Peringatan',
        color: Color(0xFFD32F2F),
      );

      const NotificationDetails platformDetails =
          NotificationDetails(android: androidDetails);

      await _notificationsPlugin.show(
        id,
        title,
        body,
        platformDetails,
        payload: payload,
      );

      // Save to history, dedupe per ID agar tidak menumpuk saat alert
      // dire-schedule atau re-fire.
      await CacheService().removeNotification(id);
      await CacheService().saveNotification({
        'id': id,
        'title': title,
        'body': body,
        'timestamp': DateTime.now().toIso8601String(),
        'createdAt': DateTime.now().toIso8601String(),
        'payload': payload,
        'isRead': false,
      });
    } catch (e) {
      AppLogger().debug('Agrinova', "Show notification failed: $e");
    }
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    try {
      // Ensure notification service is initialized before scheduling
      if (!_isInitialized) {
        await init();
        if (!_isInitialized) {
          throw Exception('NotificationService failed to initialize');
        }
      }

      if (kDebugMode) {
        AppLogger().debug('Agrinova', '🔔 scheduleNotification called:');
        AppLogger().debug('Agrinova', '   ID: $id');
        AppLogger().debug('Agrinova', '   Title: $title');
        AppLogger().debug('Agrinova', '   Scheduled: $scheduledDate');
      }

      final tz.TZDateTime tzScheduledDate =
          tz.TZDateTime.from(scheduledDate, tz.local);
      tz.TZDateTime finalScheduledDate = tzScheduledDate;
      final now = tz.TZDateTime.now(tz.local);

      if (kDebugMode) {
        AppLogger().debug('Agrinova', '   TZ Scheduled: $tzScheduledDate');
        AppLogger().debug('Agrinova', '   TZ Now: $now');
      }

      if (finalScheduledDate.isBefore(now)) {
        if (now.difference(finalScheduledDate).inMinutes < 5) {
          // Jika kurang dari 5 menit yang lalu, tampilkan sekarang
          finalScheduledDate = now.add(const Duration(seconds: 5));
          if (kDebugMode) {
            AppLogger().debug('Agrinova', '   ⚡ Adjusted to: $finalScheduledDate (was in past <5min)');
          }
        } else {
          if (kDebugMode) {
            AppLogger().debug('Agrinova', 
                '   ❌ SKIPPED: Time already passed by ${now.difference(finalScheduledDate).inMinutes} minutes');
          }
          return;
        }
      }

      if (kDebugMode) {
        AppLogger().debug('Agrinova', '   📅 Final scheduled time: $finalScheduledDate');
      }

      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        finalScheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'channel_jadwal_tanam_v2',
            'Jadwal Tanam Petani',
            channelDescription: 'Pengingat aktivitas pertanian penting',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/launcher_icon',
            playSound: true,
            enableVibration: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );

      // Save to history (with future timestamp), dedupe per ID agar tidak
      // menumpuk saat jadwal yang sama dire-schedule (mis. briefing harian).
      await CacheService().removeNotification(id);
      await CacheService().saveNotification({
        'id': id,
        'title': title,
        'body': body,
        'timestamp': finalScheduledDate.toIso8601String(),
        // Kapan entri ini dicatat, bukan kapan ia berbunyi. 'timestamp' sebuah
        // jadwal menunjuk masa depan, jadi ia tidak bisa dipakai mengurutkan
        // mana yang paling baru masuk ke riwayat.
        'createdAt': DateTime.now().toIso8601String(),
        'payload': 'scheduled',
        'isRead': false,
      });
    } catch (e) {
      AppLogger().debug('Agrinova', "❌ Schedule failed for ID $id: $e");
    }
  }

  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
    await CacheService().removeNotification(id);
    AppLogger().debug('Agrinova', '🗑️ Notification $id cancelled');
  }

  /// Get list of all pending (scheduled) notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notificationsPlugin.pendingNotificationRequests();
  }

  /// Print all pending notifications for debugging
  Future<void> printPendingNotifications() async {
    final pending = await getPendingNotifications();
    if (kDebugMode) {
      AppLogger().debug('Agrinova', '📋 Pending Notifications: ${pending.length}');
      for (var n in pending) {
        AppLogger().debug('Agrinova', '   ID: ${n.id}, Title: ${n.title}');
      }
    }
  }

  /// Show a test notification immediately (for debugging)
  Future<void> showTestNotification() async {
    await showNotification(
      id: 9999,
      title: '🧪 Test Notifikasi',
      body: 'Jika Anda melihat ini, notifikasi berfungsi dengan baik!',
      payload: 'test',
    );
  }
}
