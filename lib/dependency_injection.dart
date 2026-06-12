// =============================================================================
// FILE 1: Updated dependency_injection.dart
// =============================================================================

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:whoxa/core/api/api_client.dart';
import 'package:whoxa/core/network/network_listner.dart';
import 'package:whoxa/core/services/local_notification_service.dart';
import 'package:whoxa/core/services/call_audio_manager.dart';
import 'package:whoxa/featuers/story/data/story_upload_repo.dart';
import 'package:whoxa/featuers/auth/data/repositories/login_repository.dart';
import 'package:whoxa/featuers/auth/provider/auth_provider.dart';
import 'package:whoxa/featuers/auth/services/onesignal_service.dart';

import 'package:whoxa/featuers/chat/group/data/repository/group_repository.dart';
import 'package:whoxa/featuers/chat/group/provider/group_provider.dart';
import 'package:whoxa/featuers/chat/provider/chat_provider.dart';
import 'package:whoxa/featuers/chat/provider/archive_chat_provider.dart';
import 'package:whoxa/featuers/chat/repository/chat_repository.dart';
import 'package:whoxa/featuers/home/provider/home_provider.dart';

import 'package:whoxa/featuers/language_method/data/repository/language_repo.dart';
import 'package:whoxa/featuers/language_method/provider/language_provider.dart';
import 'package:whoxa/featuers/onboarding/Provider/onboarding_provider.dart';
import 'package:whoxa/featuers/call/call_provider.dart';
import 'package:whoxa/featuers/profile/data/repository/profile_status_repo.dart';
import 'package:whoxa/featuers/profile/provider/profile_provider.dart';
import 'package:whoxa/featuers/project-config/data/config_repo.dart';
import 'package:whoxa/featuers/project-config/provider/config_provider.dart';
import 'package:whoxa/featuers/provider/theme_provider.dart';
import 'package:whoxa/featuers/story/provider/story_provider.dart';
import 'package:whoxa/featuers/call/call_manager.dart';
import 'package:whoxa/featuers/call/web_rtc_service.dart';
import 'package:whoxa/featuers/contacts/provider/contact_provider.dart';
import 'package:whoxa/featuers/contacts/data/repository/contact_repo.dart';
import 'package:whoxa/featuers/provider/tabbar_provider.dart';
import 'package:whoxa/featuers/report/data/repositories/report_repository.dart';
import 'package:whoxa/featuers/call/call_history/repositories/call_history_repository.dart';
import 'package:whoxa/featuers/call/call_history/providers/call_history_provider.dart';
import 'package:whoxa/featuers/report/provider/report_provider.dart';
import 'package:whoxa/utils/network_info.dart';
import 'package:whoxa/utils/preference_key/preference_key.dart';
import 'package:whoxa/utils/preference_key/sharedpref_key.dart';
import 'package:whoxa/utils/logger.dart';
import 'core/services/socket/socket_event_controller.dart';
import 'core/services/socket/socket_service.dart';
import 'core/services/socket/socket_manager.dart';

final GetIt getIt = GetIt.instance;

/// ✅ UPDATED: Setup application-wide dependencies with new call system
Future<void> setupDependencies() async {
  final logger = ConsoleAppLogger();
  logger.i('Setting up dependencies');

  try {
    // ═══════════════════════════════════════════════════════════════════════════
    // CORE SERVICES
    // ═══════════════════════════════════════════════════════════════════════════

    getIt.registerLazySingleton<Dio>(() => Dio());
    getIt.registerLazySingleton<Connectivity>(() => Connectivity());
    getIt.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl(getIt()));

    // Project Configuration dependencies
    getIt.registerLazySingleton(() => ProjectConfigRepository(getIt()));
    getIt.registerLazySingleton(() => ProjectConfigProvider(getIt()));

    // Network Listener
    getIt.registerLazySingleton<NetworkListener>(() => NetworkListener());
    await getIt<NetworkListener>().initialize();
    logger.i('NetworkListener initialized');

    // Storage
    final storage = FlutterSecureStorage(
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.unlocked,
        synchronizable: false,
      ),
    );
    getIt.registerLazySingleton<SecurePrefs>(() => SecurePrefs(storage));

    // API Client
    getIt.registerLazySingleton(() => ApiClient(getIt(), getIt()));

    // ═══════════════════════════════════════════════════════════════════════════
    // SOCKET SERVICES (SINGLETONS) - UPDATED FOR NEW CALL SYSTEM
    // ═══════════════════════════════════════════════════════════════════════════

    // 1. Register SocketService as singleton
    getIt.registerLazySingleton<SocketService>(() => SocketService());
    logger.i('SocketService registered');

    // 2. Register SocketEvents
    getIt.registerLazySingleton<SocketEvents>(() => SocketEvents());
    logger.i('SocketEvents registered');

    // 3. Register SocketEventController (manages chat events) - without ArchiveChatProvider initially
    getIt.registerLazySingleton<SocketEventController>(
      () =>
          SocketEventController(getIt<SocketService>(), getIt<SocketEvents>()),
    );
    logger.i('SocketEventController registered');

    // 4. ✅ NEW: Register opus_call CallManager
    getIt.registerLazySingleton<CallManager>(() => CallManager.instance);
    logger.i('CallManager registered');

    // 5. ✅ NEW: Register opus_call WebRTCService
    getIt.registerLazySingleton<WebRTCService>(() => WebRTCService.instance);
    logger.i('WebRTCService registered');

    // 6. ✅ NEW: Register opus_call CallProvider
    getIt.registerLazySingleton<CallProvider>(() => CallProvider());
    logger.i('opus_call CallProvider registered');

    // 7. Register SocketManager (handles initialization)
    getIt.registerLazySingleton<SocketManager>(() => SocketManager());
    logger.i('SocketManager registered');

    // ═══════════════════════════════════════════════════════════════════════════
    // NOTIFICATION SERVICES
    // ═══════════════════════════════════════════════════════════════════════════

    getIt.registerLazySingleton(() => CallNotificationService());
    getIt.registerLazySingleton(() => OneSignalService());
    logger.i('Notification services registered');

    // ═══════════════════════════════════════════════════════════════════════════
    // REPOSITORIES
    // ═══════════════════════════════════════════════════════════════════════════

    getIt.registerLazySingleton(() => LoginRepository(getIt<ApiClient>()));
    getIt.registerLazySingleton(
      () => ProfileStatusRepository(getIt<ApiClient>()),
    );
    if (!getIt.isRegistered<ContactRepo>()) {
      getIt.registerLazySingleton(() => ContactRepo(getIt()));
    }
    getIt.registerLazySingleton(() => StoryUploadRepo(getIt<ApiClient>()));
    getIt.registerLazySingleton(() => ChatRepository(getIt()));
    getIt.registerLazySingleton(() => GroupRepo(getIt()));
    getIt.registerLazySingleton(() => ReportRepository(getIt<ApiClient>()));
    getIt.registerLazySingleton(
      () => CallHistoryRepository(getIt<ApiClient>()),
    );
    getIt.registerLazySingleton(() => LanguageRepository(getIt<ApiClient>()));
    logger.i('Repositories registered');

    // ═══════════════════════════════════════════════════════════════════════════
    // CORE PROVIDERS (FACTORY)
    // ═══════════════════════════════════════════════════════════════════════════

    getIt.registerFactory(() => AuthProvider(getIt<LoginRepository>()));
    getIt.registerFactory(
      () => ProfileProvider(getIt<ProfileStatusRepository>()),
    );
    getIt.registerFactory(() => ContactListProvider(getIt<ContactRepo>()));
    getIt.registerFactory(() => TabbarProvider());
    logger.i('Core providers registered');

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE PROVIDERS (FACTORY)
    // ═══════════════════════════════════════════════════════════════════════════

    getIt.registerFactory(() => HomeProvider());
    getIt.registerFactory(() => OnboardingProvider());
    getIt.registerFactory(() => StoryProvider(getIt<StoryUploadRepo>()));
    getIt.registerFactory(() => GroupProvider(getIt<GroupRepo>()));
    getIt.registerFactory(() => ReportProvider(getIt<ReportRepository>()));
    getIt.registerFactory(() => ThemeProvider());
    getIt.registerFactory(
      () => CallHistoryProvider(getIt<CallHistoryRepository>()),
    );
    getIt.registerFactory(() => LanguageProvider(getIt<LanguageRepository>()));
    logger.i('Feature providers registered');

    // ═══════════════════════════════════════════════════════════════════════════
    // SOCKET-DEPENDENT PROVIDERS (FACTORY)
    // ═══════════════════════════════════════════════════════════════════════════

    // Chat Provider - Uses SocketEventController
    getIt.registerFactory(
      () => ChatProvider(
        getIt<ApiClient>(),
        getIt<SocketEventController>(),
        getIt<ChatRepository>(),
      ),
    );

    // ✅ CRITICAL FIX: Register ArchiveChatProvider as singleton and link it to SocketEventController IMMEDIATELY
    final archiveChatProvider = ArchiveChatProvider(getIt<SocketService>());
    getIt.registerSingleton<ArchiveChatProvider>(archiveChatProvider);

    // Link ArchiveChatProvider to SocketEventController immediately during setup
    getIt<SocketEventController>().setArchiveChatProvider(archiveChatProvider);
    logger.i(
      'ArchiveChatProvider created, registered, and linked to SocketEventController',
    );

    logger.i('Socket-dependent providers registered');

    // ═══════════════════════════════════════════════════════════════════════════
    // PROJECT CONFIGURATION INITIALIZATION
    // ═══════════════════════════════════════════════════════════════════════════

    // Initialize project configuration
    try {
      final projectConfigProvider = getIt<ProjectConfigProvider>();
      await projectConfigProvider.initializeProjectConfig();

      if (projectConfigProvider.hasValidConfig) {
        logger.i('Project configuration loaded successfully');
        logger.i('App Name: ${projectConfigProvider.appName}');
        logger.i('Phone Auth: ${projectConfigProvider.isPhoneAuthEnabled}');
        logger.i('Email Auth: ${projectConfigProvider.isEmailAuthEnabled}');
      } else {
        logger.w('Project configuration failed to load, using defaults');
      }
    } catch (e) {
      logger.e('Failed to initialize project configuration during setup', e);
      // App will continue with default configuration
    }

    logger.i('✅ All dependencies registered successfully');

    // ═══════════════════════════════════════════════════════════════════════════
    // AUTO-INITIALIZE FOR ALREADY LOGGED-IN USERS
    // ═══════════════════════════════════════════════════════════════════════════

    // Check if user is already logged in and auto-initialize socket services
    await _autoInitializeSocketForLoggedInUser();
  } catch (e) {
    logger.e('❌ Error setting up dependencies', e);
    logger.e(e.toString());
    if (e is Error) {
      logger.e(e.stackTrace.toString());
    }
    rethrow;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SOCKET INITIALIZATION METHODS - UPDATED
// ═══════════════════════════════════════════════════════════════════════════

/// ✅ UPDATED: Call this AFTER user login to initialize socket connections
Future<void> initializeSocketAfterLogin() async {
  final logger = ConsoleAppLogger();
  logger.i('🔌 Initializing socket connections after login');

  try {
    // 1. Initialize socket manager - this will handle the entire socket flow
    await getIt<SocketManager>().initializeSocket();
    logger.i('✅ SocketManager initialized successfully');

    // 2. ✅ UPDATED: Initialize opus_call CallManager
    final callManager = getIt<CallManager>();
    callManager.initialize();
    logger.i('✅ CallManager initialized');

    // 3. Verify socket connection before proceeding
    final socketService = getIt<SocketService>();
    if (socketService.isConnected) {
      logger.i('✅ Socket connection verified - all services ready');
    } else {
      logger.w(
        '⚠️ Socket connection not established - some features may not work',
      );
    }

    logger.i('✅ Socket connections and call service initialized successfully');
  } catch (e) {
    logger.e('❌ Error initializing socket connections after login', e);
    rethrow;
  }
}

/// ✅ UPDATED: Call this AFTER user logout to cleanup socket connections
Future<void> cleanupSocketAfterLogout() async {
  final logger = ConsoleAppLogger();
  logger.i('🧹 Cleaning up socket connections after logout');

  try {
    // 0. ✅ CRITICAL: Clean up audio session FIRST to prevent iOS audio session errors
    try {
      await _cleanupAudioSession();
      logger.i('✅ Audio session cleanup completed');
    } catch (e) {
      logger.w('⚠️ Error during audio session cleanup: $e');
    }

    // 1. ✅ CRITICAL: Dispose OneSignal event listeners FIRST to prevent iOS crashes
    try {
      final oneSignalService = OneSignalService();
      oneSignalService.dispose();
      logger.i('✅ OneSignal service disposed');
    } catch (e) {
      logger.w('⚠️ Error disposing OneSignal service: $e');
    }

    // 2. ✅ UPDATED: Reset opus_call system
    try {
      final callManager = getIt<CallManager>();
      await callManager.forceReset();
      logger.i('✅ CallManager cleanup completed');
    } catch (e) {
      logger.w('⚠️ Error cleaning up CallManager: $e');
    }

    // 2. ✅ FIXED: Force complete socket cleanup with proper reset
    try {
      // First reset the socket event controller
      final socketEventController = getIt<SocketEventController>();
      if (socketEventController.isInitialized) {
        socketEventController.reset();
        logger.i('✅ SocketEventController reset completed');
      }

      // Then reset the socket manager (this will reset the SocketService internally)
      getIt<SocketManager>().reset();
      logger.i('✅ SocketManager reset completed');

      // Add a small delay to ensure all cleanup operations complete
      await Future.delayed(Duration(milliseconds: 500));

      logger.i(
        '✅ All socket services reset - singletons are now in clean state',
      );
    } catch (e) {
      logger.w('⚠️ Error during socket cleanup: $e');
    }

    logger.i('✅ Socket connections and call service cleaned up successfully');
  } catch (e) {
    logger.e('❌ Error cleaning up socket connections after logout', e);
    // Don't rethrow here - logout should continue even if cleanup fails
  }
}

/// ✅ CRITICAL: Clean up audio session to prevent iOS audio session errors during logout
Future<void> _cleanupAudioSession() async {
  final logger = ConsoleAppLogger();

  try {
    logger.i('🎵 Starting audio session cleanup...');

    // Get CallAudioManager instance
    final callAudioManager = CallAudioManager.instance;

    // Force emergency stop all audio
    await callAudioManager.emergencyStopAudio();

    // Clean up and dispose the audio manager
    await callAudioManager.dispose();

    logger.i('🎵 CallAudioManager cleanup completed');
  } catch (e) {
    logger.e('❌ Error during audio session cleanup: $e');
    // Don't rethrow - logout should continue even if audio cleanup fails
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// UTILITY METHODS - UPDATED
// ═══════════════════════════════════════════════════════════════════════════

/// ✅ UPDATED: Check if socket services are properly initialized
bool areSocketServicesReady() {
  try {
    final socketService = getIt<SocketService>();
    final socketEventController = getIt<SocketEventController>();
    final callManager = getIt<CallManager>();

    return socketService.isConnected &&
        socketEventController.isInitialized &&
        callManager.isInitialized; // CallManager readiness check
  } catch (e) {
    final logger = ConsoleAppLogger();
    logger.e('Error checking socket services readiness: $e');
    return false;
  }
}

/// ✅ UPDATED: Get debug info for all socket services
Map<String, dynamic> getSocketServicesDebugInfo() {
  try {
    final socketService = getIt<SocketService>();
    final socketEventController = getIt<SocketEventController>();
    final callManager = getIt<CallManager>();
    final opusCallProvider = getIt<CallProvider>();

    return {
      'socketService': {'isConnected': socketService.isConnected},
      'socketEventController': {
        'isInitialized': socketEventController.isInitialized,
        'isConnected': socketEventController.isConnected,
      },
      'callManager': {
        'isInitialized': callManager.isInitialized,
        'state': callManager.state.name,
        'participantCount': callManager.participants.length,
      },
      'opusCallProvider': {
        'callState': opusCallProvider.callState.name,
        'isInCall': opusCallProvider.isInCall,
        'participantCount': opusCallProvider.participants.length,
      },
      'allServicesReady': areSocketServicesReady(),
    };
  } catch (e) {
    return {'error': e.toString(), 'allServicesReady': false};
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PRIVATE HELPER METHODS
// ═══════════════════════════════════════════════════════════════════════════

/// Check if user is logged in and auto-initialize socket services
Future<void> _autoInitializeSocketForLoggedInUser() async {
  final logger = ConsoleAppLogger();

  try {
    // Check if user is already logged in
    final isLoggedIn = await _isUserLoggedIn();

    if (isLoggedIn) {
      logger.i(
        '🔄 User already logged in, auto-initializing socket services...',
      );

      // Add a small delay to ensure all dependencies are fully registered
      await Future.delayed(Duration(milliseconds: 100));

      // Initialize socket services for already logged-in user
      await initializeSocketAfterLogin();

      logger.i('✅ Socket services auto-initialized for logged-in user');
    } else {
      logger.i(
        '📱 User not logged in, socket services will be initialized after login',
      );
    }
  } catch (e) {
    logger.e('❌ Error during auto-initialization check: $e');
    // Don't rethrow - app should continue even if auto-init fails
  }
}

/// Check if user is currently logged in
Future<bool> _isUserLoggedIn() async {
  try {
    // Check for authentication token
    final token = await SecurePrefs.getString(SecureStorageKeys.TOKEN);

    final isLoggedIn = token != null && token.isNotEmpty;

    final logger = ConsoleAppLogger();
    logger.d(
      'Login check - Token exists: ${token != null}, Result: $isLoggedIn',
    );

    return isLoggedIn;
  } catch (e) {
    final logger = ConsoleAppLogger();
    logger.e('Error checking login status: $e');
    return false;
  }
}

/// Force initialize socket services (for debugging/manual trigger)
Future<void> forceInitializeSocketServices() async {
  final logger = ConsoleAppLogger();
  logger.i('🔧 Force initializing socket services...');

  try {
    await initializeSocketAfterLogin();
    logger.i('✅ Socket services force-initialized successfully');
  } catch (e) {
    logger.e('❌ Error force-initializing socket services: $e');
    rethrow;
  }
}
