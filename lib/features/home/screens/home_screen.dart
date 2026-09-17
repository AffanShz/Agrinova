import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:agrinova/core/constants/colors.dart';
import 'package:agrinova/features/home/bloc/home_bloc.dart';
import 'package:agrinova/features/home/widgets/forecast_list.dart';
import 'package:agrinova/features/home/widgets/quick_access.dart';
import 'package:agrinova/features/home/widgets/tips_list.dart';
import 'package:agrinova/features/home/widgets/weather_alert.dart';
import 'package:agrinova/widgets/custom_app_bar.dart';
import 'package:agrinova/features/home/widgets/home_weather_card.dart';
import 'package:agrinova/widgets/section_header.dart';
import 'package:agrinova/features/weather/screens/weather_detail_screen.dart';
import 'package:agrinova/core/services/notification_service.dart';
import 'package:agrinova/features/home/widgets/home_skeleton.dart';
import 'package:agrinova/features/chatbot/screens/chatbot_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:agrinova/widgets/app_toast.dart';

class HomeScreen extends StatefulWidget {
  final Function(int)? onTabChange;
  const HomeScreen({super.key, this.onTabChange});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _hasShownNotification = false;
  bool _hasShownOfflineSnackbar = false;
  HomeLoaded? _lastLoadedState;

  @override
  void initState() {
    super.initState();
    // Request notification permissions
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        NotificationService().requestPermissions();
      }
    });
  }

  void _openChatbot(BuildContext context, HomeLoaded state) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatbotScreen(
          currentWeather: state.currentWeather,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: BlocBuilder<HomeBloc, HomeState>(
        builder: (context, state) {
          if (state is! HomeLoaded) return const SizedBox.shrink();
          return FloatingActionButton(
            heroTag: 'homeChatbotFab',
            onPressed: () => _openChatbot(context, state),
            backgroundColor: AppColors.primaryGreen,
            tooltip: 'Asisten Tani',
            child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
          );
        },
      ),
      body: SafeArea(
        child: BlocConsumer<HomeBloc, HomeState>(
          listener: (context, state) {
            // Handle side effects: notifications dan snackbar
            if (state is HomeLoaded && state.alertMessage != null) {
              // Tampilkan notifikasi hanya sekali
              if (!_hasShownNotification) {
                NotificationService().showNotification(
                  id: 101,
                  title: 'Info Tanaman',
                  body: state.alertMessage!,
                );
                _hasShownNotification = true;
              }
            }

            // Tampilkan toast saat error
            if (state is HomeError) {
              AppToast.show(
                context,
                message: state.message,
                type: ToastType.error,
              );
            }

            // Tampilkan toast saat offline — hanya sekali per sesi offline
            if (state is HomeLoaded && !state.isOnline && !_hasShownOfflineSnackbar) {
              _hasShownOfflineSnackbar = true;
              AppToast.show(
                context,
                message: 'home.cache_message'.tr(),
                type: ToastType.warning,
                icon: Icons.wifi_off,
              );
            }
            if (state is HomeLoaded && state.isOnline) {
              _hasShownOfflineSnackbar = false;
            }
          },
          builder: (context, state) {
            // State: Initial atau Loading (tanpa data sebelumnya)
            if (state is HomeInitial ||
                (state is HomeLoading && !state.isRefreshing)) {
              return const HomeSkeleton();
            }

            // State: Error (tanpa data fallback)
            if (state is HomeError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.signal_wifi_off,
                          size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(state.message, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          context.read<HomeBloc>().add(LoadHomeData());
                        },
                        child: Text('common.retry'.tr()),
                      ),
                    ],
                  ),
                ),
              );
            }

            // State: Loading saat refresh — tetap tampilkan konten terakhir
            if (state is HomeLoading && state.isRefreshing) {
              if (_lastLoadedState != null) {
                return _buildContent(context, _lastLoadedState!);
              }
              return const HomeSkeleton();
            }

            // State: Loaded (dengan data)
            if (state is HomeLoaded) {
              _lastLoadedState = state;
              return _buildContent(context, state);
            }

            // Fallback
            return const HomeSkeleton();
          },
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, HomeLoaded state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: RefreshIndicator(
        onRefresh: () async {
          context.read<HomeBloc>().add(RefreshHomeData());
          // Tunggu sampai state bukan loading lagi
          await context.read<HomeBloc>().stream
              .firstWhere((s) => s is! HomeLoading)
              .timeout(const Duration(seconds: 15), onTimeout: () => state);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              CustomAppBar(
                lastSyncTime: state.lastSyncTime,
                isOnline: state.isOnline,
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const WeatherDetailScreen(),
                    ),
                  );
                },
                child: HomeWeatherCard(
                  currentWeather: state.currentWeather,
                  shortLocation: state.shortLocation,
                  isRealTimeGps: state.isRealTimeGps,
                  onRefresh: () {
                    context.read<HomeBloc>().add(RefreshHomeData());
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Widget Alert (Rekomendasi Tanaman)
              if (state.alertMessage != null) ...[
                WeatherAlert(message: state.alertMessage!),
                const SizedBox(height: 20),
              ],

              SectionHeader(
                title: 'home.weather_label'.tr(),
                onActionTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const WeatherDetailScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              ForecastList(forecastData: state.forecastList),

              const SizedBox(height: 20),

              SectionHeader(
                title: 'home.menu_tips'.tr(),
                onActionTap: () {
                  if (widget.onTabChange != null) {
                    widget.onTabChange!(2); // Switch to Tips tab (index 2)
                  }
                },
              ),
              const SizedBox(height: 16),
              const TipsList(),
              const SizedBox(height: 20),
              const QuickAccess(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
