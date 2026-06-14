import 'dart:ui';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/dependency_injection.dart';
import 'package:whoxa/featuers/auth/services/onesignal_service.dart';
import 'package:whoxa/featuers/language_method/provider/language_provider.dart';
import 'package:whoxa/featuers/project-config/provider/config_provider.dart';
import 'package:whoxa/provider_list.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_routes.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/utils/preference_key/preference_key.dart';
import 'package:whoxa/utils/logger.dart';
import 'package:whoxa/utils/preference_key/sharedpref_key.dart';
import 'package:whoxa/widgets/app_version.dart';
import 'package:whoxa/core/app_life_cycle.dart';
import 'package:whoxa/core/navigation_helper.dart';
import 'package:get_it/get_it.dart';
import 'package:whoxa/widgets/global.dart';

final ConsoleAppLogger logger = ConsoleAppLogger();

/// Main entry point for the application
/// Sets up dependencies, initializes services, and runs the app
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Firebase init (for Analytics only)
    if (!kIsWeb) {
      await Firebase.initializeApp();
      logger.i('Firebase initialized successfully');

      // Initialize Firebase Analytics
      FirebaseAnalytics analytics = FirebaseAnalytics.instance;
      await analytics.setAnalyticsCollectionEnabled(true);
      logger.i('Firebase Analytics initialized successfully');
    } else {
      logger.i('Web platform detected: skipping Firebase initialization');
    }

    // App version num fetch
    await getAppVersion();

    // ✅ Note: First run detection is now handled natively in iOS AppDelegate
    // The native iOS code will clear FlutterSecureStorage on first run automatically

    // Initialize secure storage (this will be empty if first run)
    await SecureStorageKeys().loadUserFromPrefs();
    // ✅ CRITICAL FIX: Load boolean values including isDemo, isPhoneAuthEnabled, isEmailAuthEnabled
    await SecureStorageKeys().loadeBoolValuePrefes();
    isLightModeGlobal =
        await SecurePrefs.getBoolLighDark(SecureStorageKeys.isLightMode);
    debugPrint("isLightModeGlobal:$isLightModeGlobal");
    debugPrint("isDemo loaded on app start:$isDemo");

    // Setup dependencies (includes project config)
    await setupDependencies();
    logger.i('Dependencies setup completed');

    // ✅ DON'T initialize OneSignal here - let splash screen handle it
    // This is because we need the dynamic App ID from project config
    logger.i('OneSignal will be initialized after project config is loaded');
    logger.i('Call notifications will be handled immediately in splash screen');

    logger.i('App initialization completed successfully');
  } catch (e) {
    logger.e('Error initializing application', e);
  }

  // Run the app with MultiProvider for state management
  runApp(MultiProvider(providers: appProviders, child: const MyApp()));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // ✅ Setup OneSignal handlers when app widget is ready
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _setupOneSignalWhenReady();
      // ✅ REMOVED: Call notification handling moved to splash screen for better coordination
      // This prevents race conditions between splash navigation and call navigation
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// ✅ Setup OneSignal when project config becomes available
  Future<void> _setupOneSignalWhenReady() async {
    try {
      logger.i('🔍 Checking for project configuration...');

      // Get project config provider
      final configProvider = GetIt.instance<ProjectConfigProvider>();

      // Wait for config to be loaded (with timeout)
      int attempts = 0;
      const maxAttempts = 30; // 15 seconds total

      while (!configProvider.hasValidConfig && attempts < maxAttempts) {
        await Future.delayed(Duration(milliseconds: 500));
        attempts++;

        if (attempts % 10 == 0) {
          logger.i('Still waiting for project config... (${attempts * 0.5}s)');
        }
      }

      if (configProvider.hasValidConfig) {
        final oneSignalAppId = configProvider.oneSignalAppId;
        if (oneSignalAppId.isNotEmpty) {
          logger.i(
            '🚀 Setting up OneSignal with dynamic App ID: $oneSignalAppId',
          );
          await OneSignalService().initializeWithConfig(oneSignalAppId);

          // Ensure handlers are setup
          await OneSignalService().emergencySetupHandlers(oneSignalAppId);

          logger.i('✅ OneSignal setup completed with dynamic App ID');
        } else {
          logger.w('⚠️ OneSignal App ID is empty in project config');
          await _fallbackOneSignalSetup();
        }
      } else {
        logger.w('⚠️ Project config not available, using fallback');
        await _fallbackOneSignalSetup();
      }
    } catch (e) {
      logger.e('❌ Error setting up OneSignal with dynamic config: $e');
      await _fallbackOneSignalSetup();
    }
  }

  /// ✅ Fallback OneSignal setup with hardcoded App ID (from your logs)
  Future<void> _fallbackOneSignalSetup() async {
    try {
      // Use the App ID from your logs as fallback
      const String fallbackAppId = "b174e31b-a337-4235-a42f-ecfd379498d6";

      logger.i('🔧 Using fallback OneSignal App ID: $fallbackAppId');
      await OneSignalService().initializeWithConfig(fallbackAppId);
      await OneSignalService().emergencySetupHandlers(fallbackAppId);

      logger.i('✅ OneSignal fallback setup completed');
    } catch (e) {
      logger.e('❌ Error in OneSignal fallback setup: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Update app foreground state for OneSignal
    switch (state) {
      case AppLifecycleState.resumed:
        OneSignalService().setAppForegroundState(true);
        logger.d('📱 App resumed - foreground: true');
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        OneSignalService().setAppForegroundState(false);
        logger.d('🏠 App paused/inactive - foreground: false');
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Lock orientation to portrait mode
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    final lang = Provider.of<LanguageProvider>(context);
    AppString.initStrings(lang); // ✅ initialize all strings with provider

    return AppLifecycleManager(
      child: MaterialApp(
        navigatorKey:
            NavigationHelper.navigatorKey, // ✅ Critical for navigation
        debugShowCheckedModeBanner: false,

        title: 'Whoxa',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: AppColors.white),
          useMaterial3: true,
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: CupertinoPageTransitionsBuilder(),
              TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            },
          ),
          // Modern scroll behavior
          scrollbarTheme: const ScrollbarThemeData(
            thumbVisibility: WidgetStatePropertyAll(false),
          ),
          // Improved text scaling
          textTheme: const TextTheme().apply(
            fontFamily: AppTypography.fontFamily.poppins,
          ),
        ),
        // Improved scroll behavior for web/desktop
        scrollBehavior: const MaterialScrollBehavior().copyWith(
          dragDevices: {
            PointerDeviceKind.mouse,
            PointerDeviceKind.touch,
            PointerDeviceKind.stylus,
            PointerDeviceKind.unknown,
          },
        ),
        // Accessibility
        shortcuts: WidgetsApp.defaultShortcuts,
        actions: WidgetsApp.defaultActions,
        onGenerateRoute: AppRoutes.generateRoute,
        initialRoute: AppRoutes.splash,
        // Performance optimizations
        builder: (context, child) {
          return Consumer<LanguageProvider>(
            builder: (context, languageProvider, _) {
              return Directionality(
                textDirection:
                    userTextDirection == 'rtl'
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: MediaQuery.of(context).textScaler.clamp(
                      minScaleFactor: 0.8,
                      maxScaleFactor: 1.3,
                    ),
                  ),
                  child: GestureDetector(
                    onTap: () {
                      // Dismiss keyboard when tapping anywhere on screen (iOS specific behavior)
                      FocusScope.of(context).unfocus();
                    },
                    child: child!,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
