import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:agrinova/core/constants/colors.dart';

// Screens
import 'package:agrinova/features/home/screens/home_screen.dart';
import 'package:agrinova/features/calendar/screens/calendar_screen.dart';
import 'package:agrinova/features/tips/screens/tips_screen.dart';
import 'package:agrinova/features/settings/screens/settings_screen.dart';
import 'package:agrinova/features/scanner/screens/scanner_screen.dart';

// BLoCs
import 'package:agrinova/features/home/bloc/home_bloc.dart';
import 'package:agrinova/features/calendar/bloc/calendar_bloc.dart';
import 'package:agrinova/features/tips/bloc/tips_bloc.dart';

// Repositories
import 'package:agrinova/data/repositories/weather_repository.dart';
import 'package:agrinova/data/repositories/calendar_repository.dart';
import 'package:agrinova/data/repositories/tips_repository.dart';

// Services
import 'package:agrinova/core/services/cache_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
    final isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => _onItemTapped(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSelected ? activeIcon : icon,
            color: isSelected ? AppColors.primaryGreen : Colors.grey,
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isSelected ? AppColors.primaryGreen : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          // Home Screen dengan BlocProvider
          BlocProvider(
            create: (context) => HomeBloc(
              weatherRepository: context.read<WeatherRepository>(),
              cacheService: CacheService(),
            )..add(LoadHomeData()),
            child: HomeScreen(
              onTabChange: _onItemTapped,
            ),
          ),

          // Calendar Screen dengan BlocProvider
          BlocProvider(
            create: (context) => CalendarBloc(
              calendarRepository: context.read<CalendarRepository>(),
            )..add(LoadSchedules()),
            child: const CalendarScreen(),
          ),

          // Tips Screen dengan BlocProvider
          BlocProvider(
            create: (context) => TipsBloc(
              tipsRepository: context.read<TipsRepository>(),
            )..add(LoadTips()),
            child: const TipsScreen(),
          ),

          // Settings Screen
          const SettingsScreen(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'mainScannerFab',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ScannerScreen()),
          );
        },
        backgroundColor: AppColors.primaryGreen,
        shape: const CircleBorder(),
        child: const Icon(Icons.camera_alt, color: Colors.white, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        padding: const EdgeInsets.symmetric(vertical: 8),
        height: 70,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, Icons.home_outlined, Icons.home, 'home.nav_home'.tr()),
            _buildNavItem(1, Icons.calendar_today_outlined, Icons.calendar_today, 'home.nav_calendar'.tr()),
            const SizedBox(width: 48), // Space for FAB
            _buildNavItem(2, Icons.lightbulb_outline, Icons.lightbulb, 'home.nav_tips'.tr()),
            _buildNavItem(3, Icons.settings_outlined, Icons.settings, 'home.nav_settings'.tr()),
          ],
        ),
      ),
    );
  }
}
