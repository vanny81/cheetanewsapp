import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/core/api/api_endpoint.dart';
import 'package:whoxa/core/navigation_helper.dart';
import 'package:whoxa/featuers/auth/provider/auth_provider.dart';
import 'package:whoxa/featuers/auth/services/onesignal_service.dart';
import 'package:whoxa/featuers/language_method/provider/language_provider.dart';
import 'package:whoxa/featuers/project-config/provider/config_provider.dart';
import 'package:whoxa/featuers/provider/tabbar_provider.dart';
import 'package:whoxa/core/services/cold_start_handler.dart';
import 'package:whoxa/featuers/provider/theme_provider.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
import 'package:whoxa/utils/preference_key/constant/app_routes.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/utils/preference_key/preference_key.dart';
import 'package:whoxa/utils/preference_key/sharedpref_key.dart';
import 'package:whoxa/widgets/cusotm_blur_appbar.dart';
import 'package:whoxa/widgets/global.dart';
import 'package:whoxa/utils/logger.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  AnimationController? animationController;
  Animation<double>? animation;
  Timer? _splashTimer;
  final ConsoleAppLogger _logger = ConsoleAppLogger();

  // ✅ Track initialization status
  bool _projectConfigLoaded = false;
  bool _oneSignalInitialized = false;

  // ✅ CRITICAL: Add call navigation state tracking
  bool _isNavigatingToCall = false;
  bool _shouldSkipSplashNavigation = false;

  @override
  void initState() {
    super.initState();
    debugPrint("Welcome to splash");
    _logger.i("Splash screen initialized");

    _initializeAnimation();
    _initializeAppInBackground();
  }

  void _initializeAnimation() {
    animationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    );
    animation = CurvedAnimation(
      parent: animationController!,
      curve: Curves.easeOut,
    );

    animation!.addListener(() => setState(() {}));
    animationController!.forward();
  }

  void _initializeAppInBackground() async {
    // Start background initialization
    String? token = authToken;
    if (token.isEmpty) {
      await _initializeProjectConfigAndOneSignal();
    } else {
      // User is logged in, initialize immediately
      await _initializeProjectConfigAndOneSignal();
    }

    // ✅ CRITICAL: Check for pending call notifications FIRST
    await _handlePendingCallNotification();

    // ✅ Only set timer if not navigating to call
    if (!_shouldSkipSplashNavigation && mounted) {
      _splashTimer = Timer(Duration(seconds: 3), () {
        if (mounted && !_isNavigatingToCall) {
          navigationPage();
        }
      });
    } else if (mounted) {
      // If we're re-entering splash after a call, navigate immediately
      _splashTimer = Timer(Duration(seconds: 1), () {
        if (mounted && !_isNavigatingToCall) {
          navigationPage();
        }
      });
    }
  }

  /// ✅ IMPROVED: Initialize project configuration AND OneSignal together
  Future<void> _initializeProjectConfigAndOneSignal() async {
    try {
      _logger.i(
        '🚀 Starting project configuration and OneSignal initialization',
      );
      final configProvider = Provider.of<ProjectConfigProvider>(
        context,
        listen: false,
      );

      final langProvider = Provider.of<LanguageProvider>(
        context,
        listen: false,
      );

      // Initialize project config
      final success = await configProvider.initializeProjectConfig();

      if (success && configProvider.hasValidConfig) {
        langProvider.fetchLangData();
        _projectConfigLoaded = true;
        _logger.i('✅ Project configuration loaded successfully');
        _logger.i('📋 App Name: ${configProvider.appName}');
        _logger.d('📱 Phone Auth: ${configProvider.isPhoneAuthEnabled}');
        _logger.d('📧 Email Auth: ${configProvider.isEmailAuthEnabled}');
        _logger.d('👥 Max Group Members: ${configProvider.maxGroupMembers}');

        // ✅ CRITICAL: Initialize OneSignal with dynamic App ID
        final oneSignalAppId = configProvider.oneSignalAppId;
        if (oneSignalAppId.isNotEmpty) {
          _logger.i(
            '🔔 Initializing OneSignal with dynamic App ID: $oneSignalAppId',
          );

          try {
            // Initialize OneSignal with config
            await OneSignalService().initializeWithConfig(oneSignalAppId);

            // ✅ IMPORTANT: Ensure handlers are setup immediately
            await OneSignalService().emergencySetupHandlers(oneSignalAppId);

            // Try to get player ID
            final playerId = await OneSignalService().getPlayerIdAsync();
            if (playerId != null) {
              _logger.i('🆔 OneSignal Player ID obtained: $playerId');
            } else {
              _logger.w('⚠️ OneSignal Player ID not available yet');
            }

            _oneSignalInitialized = true;
            _logger.i('✅ OneSignal initialization completed successfully');
          } catch (e) {
            _logger.e('❌ Error initializing OneSignal with dynamic App ID', e);
            await _initializeOneSignalWithFallback();
          }
        } else {
          _logger.w('⚠️ OneSignal App ID not found in project config');
          await _initializeOneSignalWithFallback();
        }
      } else {
        _logger.w('⚠️ Project configuration failed to load, using defaults');
        await _initializeOneSignalWithFallback();
      }
    } catch (e) {
      _logger.e('❌ Error in project config and OneSignal initialization', e);
      await _initializeOneSignalWithFallback();
    }
  }

  /// ✅ Fallback OneSignal initialization with hardcoded App ID
  Future<void> _initializeOneSignalWithFallback() async {
    try {
      // Use the App ID from your logs as fallback
      const String fallbackAppId = "b174e31b-a337-4235-a42f-ecfd379498d6";

      _logger.i('🔧 Using fallback OneSignal App ID: $fallbackAppId');
      await OneSignalService().initializeWithConfig(fallbackAppId);
      await OneSignalService().emergencySetupHandlers(fallbackAppId);

      _oneSignalInitialized = true;
      _logger.i('✅ OneSignal fallback initialization completed');
    } catch (e) {
      _logger.e('❌ Error in OneSignal fallback initialization', e);
    }
  }

  void navigationPage() async {
    if (!mounted) return;

    // ✅ CRITICAL: Skip navigation if already navigating to call or should skip
    if (_isNavigatingToCall || _shouldSkipSplashNavigation) {
      _logger.i('🚫 Skipping splash navigation - call screen priority active');
      SplashNavigationTracker.markSkipped();
      return;
    }

    _logger.i('🧭 Starting navigation logic');
    _logger.i(
      '📊 Initialization status: Config=$_projectConfigLoaded, OneSignal=$_oneSignalInitialized',
    );

    // Small delay to ensure safe context usage
    await Future.delayed(Duration(milliseconds: 100));

    if (!mounted) return;

    //this is check because navigation for call is handled from NavigationHelper
    // when app is start using navigateToIncomingCallFromData from NavigationHelper is handle call in forground
    if (!NavigationHelper.getIsNavigatingCall) {
      // ✅ FIXED: Get the route asynchronously to handle SecurePrefs call
      String route = await _handleCurrentScreen();

      // ✅ Check if widget is still mounted before navigation
      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        route,
        (Route<dynamic> route) => false,
      );
    }
  }

  /// ✅ CRITICAL: Handle pending call notifications immediately after splash initialization
  Future<void> _handlePendingCallNotification() async {
    try {
      final coldStartHandler = ColdStartHandler();

      // Check if there's a pending call notification
      if (coldStartHandler.hasPendingCallData) {
        _logger.i(
          '📞 PRIORITY: Pending call notification detected - handling immediately',
        );

        _isNavigatingToCall = true;
        _shouldSkipSplashNavigation = true;

        // Cancel any existing timer
        _splashTimer?.cancel();

        // Wait a bit for splash UI to be ready
        await Future.delayed(Duration(milliseconds: 2000));

        if (!mounted) return;

        // Handle the call notification
        await coldStartHandler.handlePendingNotification();

        _logger.i('✅ Call notification handled - splash navigation disabled');
        return;
      }

      _logger.d('ℹ️ No pending call notifications');
    } catch (e) {
      _logger.e('❌ Error handling pending call notification: $e');
      // Reset states on error
      _isNavigatingToCall = false;
      _shouldSkipSplashNavigation = false;
    }
  }

  /// ✅ CRITICAL: Cancel splash timer when navigating to call
  void cancelSplashTimer([String? reason]) {
    if (_splashTimer?.isActive == true) {
      _splashTimer?.cancel();
      _logger.i('⏰ Splash timer cancelled${reason != null ? ': $reason' : ''}');
    }
  }

  @override
  void dispose() {
    animationController?.dispose();
    _splashTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUI(),
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return Scaffold(
            backgroundColor: AppThemeManage.appTheme.scaffoldBackColor,
            body: Center(
              child: Stack(
                children: [
                  SvgPicture.asset(AppAssets.splashLine),
                  Column(
                    children: [
                      // SizedBox(height: SizeConfig.height(40)),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Use static logo (no dynamic loading)
                            Center(
                              child: AppThemeManage.appTheme.appDarkLightLogo,
                            ),

                            // Row(
                            //   mainAxisAlignment: MainAxisAlignment.center,
                            //   children: [
                            //     isLightModeGlobal
                            //         ? appDynamicLogo(
                            //           height: SizeConfig.sizedBoxHeight(55),
                            //         )
                            //         : appDynamicLogoDark(
                            //           height: SizeConfig.sizedBoxHeight(55),
                            //         ),
                            //     SizedBox(width: SizeConfig.width(2)),
                            //     Text(
                            //       appName,
                            //       style: TextStyle(
                            //         color: AppColors.themeBoolColor.textColor,
                            //         fontWeight: FontWeight.w600,
                            //         fontSize: SizeConfig.getFontSize(30),
                            //         fontFamily:
                            //             AppTypography.fontFamily.jostSemiBold,
                            //       ),
                            //     ),
                            //   ],
                            // ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<String> _handleCurrentScreen() async {
    // ✅ CRITICAL FIX: Native iOS approach handles first run detection in AppDelegate
    // iOS will clear FlutterSecureStorage automatically on first run after uninstall
    bool hasCompletedOnboarding = await SecurePrefs.getBool(
      SecureStorageKeys.PERMISSION,
    );
    String token = authToken;
    bool hasAnyUserData =
        userName.isNotEmpty || userID.isNotEmpty || token.isNotEmpty;

    // 🔍 DEBUG: Log navigation decision factors
    _logger.i("🧭 Navigation Debug:");
    _logger.i(
      "  hasCompletedOnboarding (SecurePrefs): $hasCompletedOnboarding",
    );
    _logger.i("  permission (global variable): $permission");
    _logger.i("  authToken: '${token.isEmpty ? 'EMPTY' : 'PRESENT'}'");
    _logger.i("  userName: '${userName.isEmpty ? 'EMPTY' : userName}'");
    _logger.i(
      "  userProfile: '${userProfile.isEmpty ? 'EMPTY' : userProfile}'",
    );
    _logger.i("  hasAnyUserData: $hasAnyUserData");

    // ✅ CRITICAL FIX: Simplified logic - if no onboarding completion or no user data, go to onboarding
    // The native iOS approach handles data clearing for fresh installs
    if (!hasCompletedOnboarding || !hasAnyUserData) {
      _logger.i(
        "🎯 Going to: ONBOARDING (No completed onboarding or no user data)",
      );
      return AppRoutes.onboarding;
    }

    // If token not available then navigate to signin method
    if (token.isEmpty) {
      _logger.i("🎯 Going to: LOGIN (no token)");
      return AppRoutes.login;
    }

    // Check user info completion - CRITICAL: Check firstName (mandatory field)
    String? firstName =
        await SecurePrefs.getString(SecureStorageKeys.FIRST_NAME) ?? "";
    String username = userName;

    _logger.i("🔍 Splash firstName from SecureStorage: '$firstName'");
    _logger.i("🔍 Splash userName: '$username'");

    // CRITICAL: Check firstName first - this is the mandatory field for profile completion
    if (firstName.isEmpty) {
      _logger.i(
        "🎯 Going to: ADD_INFO (firstName is empty - profile incomplete)",
      );
      Future.microtask(() {
        if (mounted) {
          Provider.of<AuthProvider>(context, listen: false).initializeData();
        }
      });
      return AppRoutes.addinfo;
    }

    // Secondary check: username
    if (username.isEmpty) {
      _logger.i("🎯 Going to: ADD_INFO (no username)");
      Future.microtask(() {
        if (mounted) {
          Provider.of<AuthProvider>(context, listen: false).initializeData();
        }
      });
      return AppRoutes.addinfo;
    }

    // ✅ ANDROID FIX: Read userProfile directly from secure storage to ensure fresh data
    // Don't rely on global variable which might not be updated on app restart
    String? userprofile =
        await SecurePrefs.getString(SecureStorageKeys.USER_PROFILE) ?? "";
    _logger.i("🔍 Splash userProfile from SecureStorage: '$userprofile'");
    _logger.i("🔍 Splash userProfile global variable: '$userProfile'");

    // ✅ Update global variable to ensure consistency
    userProfile = userprofile;

    if (userprofile.isEmpty) {
      // Before going to avatar, check if firstName is still empty (user might have incomplete profile)
      if (firstName.isEmpty) {
        _logger.i(
          "🎯 Going to: ADD_INFO (empty profile but firstName also empty - profile incomplete)",
        );
        Future.microtask(() {
          if (mounted) {
            Provider.of<AuthProvider>(context, listen: false).initializeData();
          }
        });
        return AppRoutes.addinfo;
      }

      _logger.i(
        "🎯 Going to: AVATAR_PROFILE (empty profile from secure storage)",
      );
      Future.microtask(() {
        if (mounted) {
          Provider.of<AuthProvider>(
            context,
            listen: false,
          ).loadAvatars(isSelected: true);
        }
      });
      return AppRoutes.avatarProfile;
    } else if (userprofile ==
        "${ApiEndpoints.socketUrl}/uploads/not-found-images/profile-image.png") {
      // Before going to avatar, check if firstName is still empty (user might have incomplete profile)
      if (firstName.isEmpty) {
        _logger.i(
          "🎯 Going to: ADD_INFO (default profile but firstName also empty - profile incomplete)",
        );
        Future.microtask(() {
          if (mounted) {
            Provider.of<AuthProvider>(context, listen: false).initializeData();
          }
        });
        return AppRoutes.addinfo;
      }

      _logger.i(
        "🎯 Going to: AVATAR_PROFILE (default profile image from secure storage)",
      );
      Future.microtask(() {
        if (mounted) {
          Provider.of<AuthProvider>(
            context,
            listen: false,
          ).loadAvatars(isSelected: true);
        }
      });
      return AppRoutes.avatarProfile;
    }

    // All checks passed, go to main app
    _logger.i("🎯 Going to: TABBAR (all checks passed)");
    Future.microtask(() {
      if (mounted) {
        Provider.of<AuthProvider>(context, listen: false).initializeData();
        Provider.of<TabbarProvider>(context, listen: false).navigateToIndex(0);
      }
    });

    return AppRoutes.tabbar;
  }
}

// this is check for call screen redirection and again go to the tabbar
class SplashNavigationTracker {
  static bool wasSkipped = false;
  static bool cameFromNotificationTap = false;

  /// Reset the tracker after call navigation is complete
  static void reset() {
    wasSkipped = false;
    cameFromNotificationTap = false;
  }

  /// Mark splash as skipped for call navigation
  static void markSkipped() {
    wasSkipped = true;
  }

  /// Mark that user came from notification tap
  static void markCameFromNotification() {
    cameFromNotificationTap = true;
  }
}
