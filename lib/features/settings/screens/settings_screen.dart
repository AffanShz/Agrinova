import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:agrinova/core/constants/colors.dart';
import 'package:agrinova/core/services/cache_service.dart';
import 'package:agrinova/features/settings/screens/profile_screen.dart';
import 'package:agrinova/logic/app_lifecycle/app_bloc.dart';

import 'package:agrinova/features/settings/screens/notification_settings_screen.dart';
import 'package:agrinova/features/settings/screens/help_support_screen.dart';
import 'package:agrinova/features/settings/screens/about_app_screen.dart';
import 'package:agrinova/features/premium/screens/purchase_premium_screen.dart';
import 'package:agrinova/widgets/app_toast.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:intl/intl.dart' as intl_pkg;
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'package:agrinova/core/services/app_logger.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final CacheService _cacheService = CacheService();
  StreamSubscription<Map<String, String?>>? _profileSubscription;
  StreamSubscription<Map<String, dynamic>>? _subscriptionSubscription;
  bool _offlineMode = false;
  String _userName = '';
  String? _userImagePath;
  bool _isPremiumActive = false;
  String _planName = 'Gratis';
  DateTime? _expiryDate;

  @override
  void initState() {
    super.initState();
    _loadOfflineMode();
    _loadSubscription();
    _listenToProfileChanges();
    _listenToSubscriptionChanges();
  }

  void _listenToProfileChanges() {
    _profileSubscription = _cacheService.profileUpdateStream.listen((profile) {
      if (mounted) {
        setState(() {
          _userName = profile['name']?.isNotEmpty == true
              ? profile['name']!
              : 'profile.default_name'.tr();
          _userImagePath = profile['imagePath'];
        });
      }
    });
  }

  void _listenToSubscriptionChanges() {
    _subscriptionSubscription =
        _cacheService.subscriptionUpdateStream.listen((sub) {
      if (mounted) {
        setState(() {
          _isPremiumActive = sub['isActive'] as bool;
          _planName = sub['planName'] as String;
          _expiryDate = sub['expiryDate'] as DateTime?;
        });
      }
    });
  }

  void _loadSubscription() {
    final sub = _cacheService.getSubscriptionDetails();
    setState(() {
      _isPremiumActive = sub['isActive'] as bool;
      _planName = sub['planName'] as String;
      _expiryDate = sub['expiryDate'] as DateTime?;
    });
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    _subscriptionSubscription?.cancel();
    super.dispose();
  }

  void _loadOfflineMode() {
    setState(() {
      _offlineMode = _cacheService.getUserPrefOfflineMode();
      final profile = _cacheService.getUserProfile();
      _userName = profile['name']?.isNotEmpty == true
          ? profile['name']!
          : 'profile.default_name'.tr();
      _userImagePath = profile['imagePath'];
    });
  }

  Future<void> _toggleOfflineMode(bool value) async {
    await _cacheService.setOfflineMode(value);
    if (!mounted) return;
    setState(() {
      _offlineMode = value;
    });

    AppToast.show(
      context,
      message: value
          ? 'settings.offline_active'.tr()
          : 'settings.online_active'.tr(),
      type: value ? ToastType.warning : ToastType.success,
      icon: value ? Icons.cloud_off : Icons.cloud_done,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          'settings.title'.tr(),
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Profile Section
              _buildProfileSection(),
              const SizedBox(height: 16),

              // Premium Promo Banner Card
              _buildPremiumBanner(),
              const SizedBox(height: 20),

              // AKUN Section
              _buildSectionTitle('settings.account_section'.tr()),
              const SizedBox(height: 8),
              _buildSettingsCard([
                _buildSettingsTile(
                  icon: Icons.person_outline,
                  title: 'settings.profile'.tr(),
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const ProfileScreen()),
                    );
                    if (result == true) {
                      _loadOfflineMode();
                    }
                  },
                ),
                _buildDivider(),
                _buildSettingsTile(
                  icon: _isPremiumActive
                      ? Icons.verified_rounded
                      : Icons.workspace_premium_outlined,
                  iconColor: _isPremiumActive
                      ? AppColors.primaryGreen
                      : const Color(0xFFE65100),
                  title: 'Paket & Langganan',
                  subtitle: _isPremiumActive
                      ? 'Member PRO ($_planName)'
                      : 'Akun Gratis',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PurchasePremiumScreen(),
                      ),
                    );
                  },
                ),
              ]),
              const SizedBox(height: 24),

              // PREFERENSI Section
              _buildSectionTitle('settings.preferences_section'.tr()),
              const SizedBox(height: 8),
              _buildSettingsCard([
                _buildSettingsTile(
                  icon: Icons.notifications_outlined,
                  title: 'settings.notification_menu'.tr(),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const NotificationSettingsScreen(),
                      ),
                    );
                  },
                ),
                _buildDivider(),
                _buildSettingsTile(
                  icon: Icons.language_outlined,
                  title: 'settings.language'.tr(),
                  subtitle: context.locale.languageCode == 'id'
                      ? 'Indonesia'
                      : 'English',
                  onTap: () {
                    _showLanguageModal(context);
                  },
                ),
                _buildDivider(),
                _buildSettingsTileWithSwitch(
                  icon: Icons.cloud_off_outlined,
                  title: 'settings.offline_mode'.tr(),
                  value: _offlineMode,
                  onChanged: _toggleOfflineMode,
                ),
              ]),
              const SizedBox(height: 24),

              // TENTANG Section
              _buildSectionTitle('settings.about_section'.tr()),
              const SizedBox(height: 8),
              _buildSettingsCard([
                _buildSettingsTile(
                  icon: null,
                  title: 'settings.help'.tr(),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HelpSupportScreen(),
                      ),
                    );
                  },
                ),
                _buildDivider(),
                _buildSettingsTile(
                  icon: null,
                  title: 'Kebijakan Privasi & Ketentuan',
                  onTap: () async {
                    final uri = Uri.parse('https://sites.google.com/view/agrinova-privacy/home');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                ),
                _buildDivider(),
                _buildSettingsTile(
                  icon: null,
                  title: 'settings.about'.tr(),
                  subtitle: 'v1.0.0',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AboutAppScreen(),
                      ),
                    );
                  },
                ),
              ]),
              const SizedBox(height: 24),

              // KELUAR Section
              _buildSettingsCard([
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: Text(
                    'settings.logout'.tr(),
                    style: const TextStyle(color: Colors.red),
                  ),
                  onTap: () async {
                    try {
                      await Supabase.instance.client.auth.signOut();
                      await CacheService().clearAllCache();
                    } catch (e) {
                      AppLogger().debug('Agrinova', 'Sign out error: $e');
                    }
                    if (context.mounted) {
                      context.read<AppBloc>().add(AppLoggedOut());
                    }
                  },
                ),
              ]),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSection() {
    ImageProvider? imageProvider;
    if (_userImagePath != null && _userImagePath!.isNotEmpty && File(_userImagePath!).existsSync()) {
      imageProvider = FileImage(File(_userImagePath!));
    }

    return Row(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: AppColors.primaryGreen,
          backgroundImage: imageProvider,
          onBackgroundImageError: imageProvider != null
              ? (exception, stackTrace) {
                  AppLogger().debug('Agrinova', "Settings Profile Image Error: $exception");
                }
              : null,
          child: imageProvider == null
              ? const Icon(Icons.person, color: Colors.white, size: 32)
              : null,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      _userName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _isPremiumActive
                          ? const Color(0xFFFFF8E1)
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _isPremiumActive
                            ? const Color(0xFFFFB300)
                            : Colors.grey[300]!,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isPremiumActive
                              ? Icons.workspace_premium_rounded
                              : Icons.eco_outlined,
                          size: 12,
                          color: _isPremiumActive
                              ? const Color(0xFFE65100)
                              : Colors.grey[600],
                        ),
                        const SizedBox(width: 3),
                        Text(
                          _isPremiumActive ? 'PRO' : 'Gratis',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _isPremiumActive
                                ? const Color(0xFFE65100)
                                : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _isPremiumActive
                    ? 'Status: Member PRO Aktif'
                    : 'Status: Akun Gratis',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: _isPremiumActive ? FontWeight.w500 : FontWeight.normal,
                  color: _isPremiumActive ? AppColors.darkGreen : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumBanner() {
    if (_isPremiumActive) {
      final expiryFormatted = _expiryDate != null
          ? intl_pkg.DateFormat('d MMM yyyy, HH:mm:ss').format(_expiryDate!)
          : 'Tanpa Batas Waktu';

      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F3813),
              Color(0xFF1B5E20),
              Color(0xFF2E7D32),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFD700), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1B5E20).withAlpha(80),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PurchasePremiumScreen(),
                ),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700).withAlpha(40),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFFD700), width: 1),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_rounded, color: Color(0xFFFFD700), size: 14),
                            SizedBox(width: 4),
                            Text(
                              'STATUS: PRO AKTIF',
                              style: TextStyle(
                                color: Color(0xFFFFD700),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.white70,
                        size: 14,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Paket $_planName ✨',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Fitur Chatbot & Upload Foto AI tanpa batas aktif sampai $expiryFormatted.',
                    style: TextStyle(
                      color: Colors.white.withAlpha(220),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Kelola / Perpanjang Paket',
                          style: TextStyle(
                            color: Color(0xFF1B5E20),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.chevron_right_rounded, color: Color(0xFF1B5E20), size: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0D3E14),
            Color(0xFF1B5E20),
            Color(0xFF2E7D32),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B5E20).withAlpha(60),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PurchasePremiumScreen(),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700).withAlpha(40),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFFD700), width: 1),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFD700), size: 14),
                          SizedBox(width: 4),
                          Text(
                            'PRO MEMBERSHIP',
                            style: TextStyle(
                              color: Color(0xFFFFD700),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white70,
                      size: 14,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Konsultasi AI Tanpa Batas 🌾',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Upload gambar hama & daun sepuasnya tanpa batas limit 3x harian.',
                  style: TextStyle(
                    color: Colors.white.withAlpha(220),
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Mulai Dari Rp 23.000/bln',
                        style: TextStyle(
                          color: Color(0xFF1B5E20),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.chevron_right_rounded, color: Color(0xFF1B5E20), size: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey[600],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingsTile({
    IconData? icon,
    Color? iconColor,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                color: iconColor ?? Colors.grey[700],
                size: 24,
              ),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTileWithSwitch({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.grey[700],
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.primaryGreen,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.grey[300],
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 16,
      endIndent: 16,
      color: Colors.grey.shade200,
    );
  }

  void _showLanguageModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'settings.language'.tr(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Text('🇮🇩', style: TextStyle(fontSize: 24)),
                title: const Text('Indonesia'),
                trailing: context.locale.languageCode == 'id'
                    ? const Icon(Icons.check, color: AppColors.primaryGreen)
                    : null,
                onTap: () {
                  context.setLocale(const Locale('id'));
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Text('🇺🇸', style: TextStyle(fontSize: 24)),
                title: const Text('English'),
                trailing: context.locale.languageCode == 'en'
                    ? const Icon(Icons.check, color: AppColors.primaryGreen)
                    : null,
                onTap: () {
                  context.setLocale(const Locale('en'));
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
