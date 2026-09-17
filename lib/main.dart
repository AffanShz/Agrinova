import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:easy_localization/easy_localization.dart';

// Core Services
import 'package:agrinova/core/services/cache_service.dart';
import 'package:agrinova/core/services/notification_service.dart';
import 'package:agrinova/core/services/secure_local_storage.dart';

import 'package:agrinova/core/services/background_service.dart';
import 'package:agrinova/core/services/connectivity_service.dart';

// Datasources
import 'package:agrinova/data/datasources/weather_service.dart';
import 'package:agrinova/data/datasources/location_service.dart';
import 'package:agrinova/data/datasources/pest_services.dart';
import 'package:agrinova/data/datasources/tips_services.dart';
import 'package:agrinova/data/datasources/planting_schedule_service.dart';
import 'package:agrinova/data/datasources/chatbot_service.dart';
import 'package:agrinova/data/repositories/chatbot_repository.dart';
import 'package:agrinova/core/constants/env_config.dart';
import 'package:agrinova/core/services/app_logger.dart';

// Repositories
import 'package:agrinova/data/repositories/auth_repository.dart';
import 'package:agrinova/data/repositories/weather_repository.dart';
import 'package:agrinova/data/repositories/pest_repository.dart';
import 'package:agrinova/data/repositories/tips_repository.dart';
import 'package:agrinova/data/repositories/calendar_repository.dart';
import 'package:agrinova/data/repositories/history_repository.dart';
import 'package:agrinova/data/repositories/drug_repository.dart';

// Global BLoC
import 'package:agrinova/logic/app_lifecycle/app_bloc.dart';
import 'package:agrinova/logic/app_lifecycle/app_lifecycle_observer.dart';

// UI
import 'package:agrinova/features/onboarding/screens/onboarding_screen.dart';
import 'package:agrinova/features/auth/screens/login_screen.dart';
import 'package:agrinova/widgets/main_screen.dart';
import 'package:agrinova/widgets/app_toast.dart';

bool appStartedOffline = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLogger.initCrashReporting();
  await EasyLocalization.ensureInitialized();

  assert(EnvConfig.validateHttpsUrls(), 'Security Warning: All base URLs must use HTTPS scheme');

  await CacheService.init();
  await NotificationService().init();

  // Inisialisasi Background Service (hanya untuk mobile platforms)
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await BackgroundService().init();
  }
  // ConnectivityService di-init secara async agar tidak blocking startup
  ConnectivityService().init();

  await initializeDateFormatting('id_ID', null);

  try {
    await Supabase.initialize(
      url: EnvConfig.supabaseUrl,
      publishableKey: EnvConfig.supabaseAnonKey,
      // Simpan session (JWT + refresh token) di secure storage,
      // bukan plaintext SharedPreferences.
      authOptions: FlutterAuthClientOptions(
        localStorage: SecureLocalStorage(),
      ),
    ).timeout(const Duration(seconds: 10));
    appStartedOffline = false;
  } on TimeoutException {
    debugPrint('Supabase initialization timeout - continuing offline');
    appStartedOffline = true;
    CacheService().setConnected(false);
  } catch (e) {
    debugPrint('Supabase initialization error: $e - continuing offline');
    appStartedOffline = true;
    CacheService().setConnected(false);
  }

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('id'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('id'),
      startLocale: const Locale('id'),
      child: const MainApp(),
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    final cacheService = CacheService();
    final weatherService = WeatherService();
    final locationService = LocationService();
    final pestService = PestService();
    final tipsService = TipsService();
    final scheduleService = PlantingScheduleService();

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<WeatherRepository>(
          create: (_) => WeatherRepository(
            weatherService: weatherService,
            locationService: locationService,
            cacheService: cacheService,
          ),
        ),
        RepositoryProvider<PestRepository>(
          create: (_) => PestRepository(
            pestService: pestService,
            cacheService: cacheService,
          ),
        ),
        RepositoryProvider<TipsRepository>(
          create: (_) => TipsRepository(
            tipsService: tipsService,
            cacheService: cacheService,
          ),
        ),
        RepositoryProvider<CalendarRepository>(
          create: (_) => CalendarRepository(
            scheduleService: scheduleService,
          ),
        ),
        RepositoryProvider<HistoryRepository>(
          create: (_) => HistoryRepository(
            pestService: pestService,
            cacheService: cacheService,
          ),
        ),
        RepositoryProvider<DrugRepository>(
          create: (_) => DrugRepository(
            cacheService: cacheService,
          ),
        ),
        RepositoryProvider<ChatbotRepository>(
          create: (_) => ChatbotRepository(
            chatbotService: ChatbotService(
              apiKey: EnvConfig.geminiApiKey,
            ),
            cacheService: cacheService,
          ),
        ),
        RepositoryProvider<AuthRepository>(
          create: (_) => AuthRepository(),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AppBloc>(
            create: (context) => AppBloc(
              cacheService: cacheService,
            )..add(AppStarted()),
          ),
        ],
        child: AppLifecycleObserver(
          child: MaterialApp(
            title: 'AgriNova',
            debugShowCheckedModeBanner: false,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
              scaffoldBackgroundColor: const Color(0xFFF8F9FA),
              useMaterial3: true,
            ),
            home: BlocBuilder<AppBloc, AppState>(
              builder: (context, state) {
                if (state is AppLoading) {
                  return const Scaffold(
                    body: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (state is AppOnboarding) {
                  return const OnboardingScreen();
                }

                if (state is AppLogin) {
                  return const LoginScreen();
                }

                if (state is AppError) {
                  return Scaffold(
                    body: Center(
                      child: Text(state.message.isNotEmpty
                          ? state.message
                          : 'Terjadi kesalahan, silakan restart aplikasi.'),
                    ),
                  );
                }

                return BlocListener<AppBloc, AppState>(
                  listener: (context, state) {
                    if (state is AppReady && !state.isConnected) {
                      AppToast.show(
                        context,
                        message: 'Tidak ada koneksi internet. Menggunakan data tersimpan.',
                        type: ToastType.warning,
                        icon: Icons.wifi_off,
                      );
                    }
                  },
                  child: const MainScreen(),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
