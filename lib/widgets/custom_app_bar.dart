import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:agrinova/core/constants/colors.dart';
import 'package:agrinova/core/services/cache_service.dart';
import 'package:agrinova/features/notifications/screens/notification_history_screen.dart';
import 'package:agrinova/features/premium/screens/purchase_premium_screen.dart';
import 'package:agrinova/core/services/app_logger.dart';

class CustomAppBar extends StatefulWidget {
  final DateTime? lastSyncTime;
  final bool isOnline;

  const CustomAppBar({
    super.key,
    this.lastSyncTime,
    this.isOnline = true,
  });

  @override
  State<CustomAppBar> createState() => _CustomAppBarState();
}

class _CustomAppBarState extends State<CustomAppBar> {
  final CacheService _cacheService = CacheService();
  StreamSubscription<Map<String, String?>>? _profileSubscription;
  StreamSubscription<Map<String, dynamic>>? _subscriptionSubscription;
  String _userName = 'Pak Tani';
  String? _userImagePath;
  bool _isPremiumActive = false;
  String _planName = 'Gratis';

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadSubscription();

    _profileSubscription = _cacheService.profileUpdateStream.listen((profile) {
      if (mounted) {
        setState(() {
          _userName = profile['name'] ?? 'profile.default_name'.tr();
          _userImagePath = profile['imagePath'];
        });
      }
    });

    _subscriptionSubscription =
        _cacheService.subscriptionUpdateStream.listen((sub) {
      if (mounted) {
        setState(() {
          _isPremiumActive = sub['isActive'] as bool;
          _planName = sub['planName'] as String;
        });
      }
    });
  }

  void _loadProfile() {
    final profile = _cacheService.getUserProfile();
    setState(() {
      _userName = profile['name'] ?? 'profile.default_name'.tr();
      _userImagePath = profile['imagePath'];
    });
  }

  void _loadSubscription() {
    final sub = _cacheService.getSubscriptionDetails();
    setState(() {
      _isPremiumActive = sub['isActive'] as bool;
      _planName = sub['planName'] as String;
    });
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    _subscriptionSubscription?.cancel();
    super.dispose();
  }

  String _formatLastSync() {
    if (widget.lastSyncTime == null) return 'home.sync_not_synced'.tr();

    final now = DateTime.now();
    final diff = now.difference(widget.lastSyncTime!);

    if (diff.inMinutes < 1) {
      return 'home.sync_just_now'.tr();
    } else if (diff.inMinutes < 60) {
      return 'home.sync_min_ago'.tr(args: [diff.inMinutes.toString()]);
    } else if (diff.inHours < 24) {
      return 'home.sync_hour_ago'.tr(args: [diff.inHours.toString()]);
    } else {
      return 'home.sync_day_ago'.tr(args: [diff.inDays.toString()]);
    }
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? imageProvider;
    if (_userImagePath != null &&
        _userImagePath!.isNotEmpty &&
        File(_userImagePath!).existsSync()) {
      imageProvider = FileImage(File(_userImagePath!));
    }

    return Column(
      children: [
        // Profile Row
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.primaryGreen,
                      backgroundImage: imageProvider,
                      onBackgroundImageError: imageProvider != null
                          ? (exception, stackTrace) {
                              if (kDebugMode) {
                                AppLogger().debug('Agrinova', "AppBar Profile Image Error: $exception");
                              }
                            }
                          : null,
                      child: imageProvider == null
                          ? const Icon(Icons.person,
                              color: Colors.white, size: 28)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Status PRO cukup ditandai sekali. Tombol di kanan
                          // sudah menampilkan 'PRO Aktif'/'Upgrade PRO', jadi
                          // chip di sebelah nama hanya mengulang hal yang sama
                          // sambil memakan lebar yang dibutuhkan nama user.
                          Text(
                            _userName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isPremiumActive
                                ? 'Paket $_planName'
                                : 'app_name'.tr(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: _isPremiumActive
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                              color: _isPremiumActive
                                  ? AppColors.darkGreen
                                  : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  // PRO Status / Upgrade Button
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PurchasePremiumScreen(),
                        ),
                      );
                    },
                    child: MediaQuery.withClampedTextScaling(
                      maxScaleFactor: 1.1,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          gradient: _isPremiumActive
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFF1B5E20),
                                    Color(0xFF2E7D32)
                                  ],
                                )
                              : const LinearGradient(
                                  colors: [
                                    Color(0xFFFFB300),
                                    Color(0xFFFF8F00)
                                  ],
                                ),
                          borderRadius: BorderRadius.circular(20),
                          border: _isPremiumActive
                              ? Border.all(
                                  color: const Color(0xFFFFD700), width: 1)
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: _isPremiumActive
                                  ? Colors.green.withAlpha(50)
                                  : Colors.orange.withAlpha(60),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isPremiumActive
                                  ? Icons.verified_rounded
                                  : Icons.workspace_premium_rounded,
                              size: 14,
                              color: _isPremiumActive
                                  ? const Color(0xFFFFD700)
                                  : Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _isPremiumActive ? 'PRO Aktif' : 'Upgrade PRO',
                              style: TextStyle(
                                color: _isPremiumActive
                                    ? const Color(0xFFFFD700)
                                    : Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const NotificationHistoryScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.notifications_outlined, size: 24),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Sync Status Bar
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isOnline
                ? AppColors.primaryGreen
                : AppColors.primaryGreen.withAlpha(200),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.isOnline ? Icons.cloud_done : Icons.cloud_off,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  widget.isOnline
                      ? 'home.sync_online'.tr(args: [_formatLastSync()])
                      : 'home.sync_offline'.tr(args: [_formatLastSync()]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
