import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/core/api/api_endpoint.dart';
import 'package:whoxa/featuers/auth/provider/auth_provider.dart';
import 'package:whoxa/featuers/chat/provider/chat_provider.dart';
import 'package:whoxa/featuers/language_method/provider/language_provider.dart';
import 'package:whoxa/featuers/language_method/screen/lang_popup.dart';
import 'package:whoxa/featuers/provider/theme_provider.dart';
import 'package:whoxa/screens/settings/terms_policy.dart';
import 'package:whoxa/screens/settings/theme_color_picker.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_direction_manage.dart';
import 'package:whoxa/utils/preference_key/constant/app_routes.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/utils/theme_switch.dart';
import 'package:whoxa/widgets/cusotm_blur_appbar.dart';
import 'package:whoxa/widgets/custom_bottomsheet.dart';
import 'package:whoxa/widgets/global.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
// ✅ COMMENTED OUT: Unused imports for test widgets
// import 'package:whoxa/core/services/call_notification_manager.dart';
// import 'package:whoxa/featuers/opus_call/test_layout_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);
    log("userProfile:$userProfile");
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUI(),
      child: Consumer2<ThemeProvider, LanguageProvider>(
        builder: (context, themeProvider, langProvider, _) {
          return Scaffold(
            extendBody: true,
            backgroundColor: AppThemeManage.appTheme.scaffoldBackColor,
            body: SingleChildScrollView(
              child: Column(
                children: [
                  //✅ Top profile layout
                  profileWidget(
                    context,
                    isBackArrow: false,
                    image: userProfile,
                    title: AppString.settingStrigs.settings,
                  ),
                  SizedBox(height: SizeConfig.height(5)),
                  //✅ Navigate to profile screen
                  containerDesgin(
                    context,
                    onTap: () {
                      Navigator.pushNamed(context, AppRoutes.profile);
                      debugPrint(userProfile);
                      debugPrint(
                        "${ApiEndpoints.socketUrl}/uploads/not-found-images/profile-image.png",
                      );
                    },
                    img: AppAssets.settingsIcosn.profile,
                    title: AppString.settingStrigs.profile,
                    count: "",
                    isCount: false,
                  ),
                  // containerDesgin(
                  //   context,
                  //   onTap: () {
                  //     Navigator.push(
                  //       context,
                  //       (MaterialPageRoute(
                  //         builder: (context) => MyWidgetLang(),
                  //       )),
                  //     );
                  //   },
                  //   img: AppAssets.settingsIcosn.profile,
                  //   title: "rofile",
                  //   count: "",
                  //   isCount: false,
                  // ),
                  SizedBox(height: SizeConfig.height(2)),
                  //✅ Navigate to Bio screen
                  containerDesgin(
                    context,
                    onTap: () {
                      Navigator.pushNamed(context, AppRoutes.bio).then((_) {
                        bio;
                      });
                    },
                    img: AppAssets.settingsIcosn.about,
                    title: AppString.settingStrigs.about,
                    count: "",
                    isCount: false,
                  ),
                  SizedBox(height: SizeConfig.height(2)),
                  //✅ Navigate to starred message screen
                  Consumer<ChatProvider>(
                    builder: (context, chatProvider, _) {
                      return containerDesgin(
                        context,
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            AppRoutes.starredMessages,
                          );
                        },
                        img: AppAssets.settingsIcosn.star,
                        title: AppString.settingStrigs.starredMessages,
                        count: chatProvider.starredCount.toString(),
                        isCount: true,
                      );
                    },
                  ),
                  SizedBox(height: SizeConfig.height(2)),
                  //✅ Naivgate to block list screen
                  Consumer<ChatProvider>(
                    builder: (context, chatProvider, _) {
                      return containerDesgin(
                        context,
                        onTap: () {
                          Navigator.pushNamed(context, AppRoutes.block);
                        },
                        img: AppAssets.settingsIcosn.profiledelete,
                        title: AppString.settingStrigs.blockContacts,
                        count: chatProvider.blocklistCount.toString(),
                        isCount: true,
                      );
                    },
                  ),
                  SizedBox(height: SizeConfig.height(2)),
                  //✅ bottom sheet open for language select
                  containerDesgin(
                    context,
                    onTap: () {
                      appLanguagePopup(context);
                    },
                    img: AppAssets.settingsIcosn.appLangIcon,
                    title: AppString.settingStrigs.appLanguage,
                    count: "0",
                    isCount: false,
                  ),
                  SizedBox(height: SizeConfig.height(2)),
                  // Dark / Light Mode Switch
                  darkLightModeWidget(),

                  SizedBox(height: SizeConfig.height(2)),
                  // Theme Color Selection
                  themeColorSelectionWidget(context),

                  // 🧪 DEBUG TEST: Call notification test (only in debug mode)
                  ...debugCallNotificationButton(context),

                  // SizedBox(height: SizeConfig.height(2)),
                  // containerDesgin(
                  //   context,
                  //   onTap: () {
                  //     Navigator.pushNamed(context, AppRoutes.subscription);
                  //   },
                  //   img: AppAssets.settingsIcosn.dollar,
                  //   title: AppString.settingStrigs.subscription,
                  //   count: "",
                  //   isCount: false,
                  // ),
                  // SizedBox(height: SizeConfig.height(2)),
                  // containerDesgin(
                  //   context,
                  //   onTap: () {},
                  //   img: AppAssets.settingsIcosn.feedback,
                  //   title: AppString.settingStrigs.feedback,
                  //   count: "",
                  //   isCount: false,
                  // ),
                  SizedBox(height: SizeConfig.height(2)),
                  //✅ Navigate to Terms & conditions screen
                  containerDesgin(
                    context,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => PrivacyWebView(
                                title: AppString.settingStrigs.termsConditions,
                                htmlContent: termsConditionText,
                              ),
                        ),
                      );
                    },
                    img: AppAssets.settingsIcosn.terms,
                    title: AppString.settingStrigs.termsConditions,
                    count: "",
                    isCount: false,
                  ),
                  SizedBox(height: SizeConfig.height(2)),
                  //✅ Navigate to Privacy policy scrren
                  containerDesgin(
                    context,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => PrivacyWebView(
                                title: AppString.settingStrigs.privacyPolicy,
                                htmlContent: privacyPoicyText,
                              ),
                        ),
                      );
                    },
                    img: AppAssets.settingsIcosn.policy,
                    title: AppString.settingStrigs.privacyPolicy,
                    count: "",
                    isCount: false,
                  ),
                  // SizedBox(height: SizeConfig.height(2)),
                  // containerDesgin(
                  //   context,
                  //   onTap: () {
                  //     debugPrint("authToken:$authToken");
                  //     Navigator.pushNamed(context, AppRoutes.story);
                  //   },
                  //   img: AppAssets.settingsIcosn.policy,
                  //   title: "Status",
                  //   count: "",
                  //   isCount: false,
                  // ),
                  SizedBox(height: SizeConfig.height(2)),
                  // ✅ App Version show
                  Padding(
                    padding: SizeConfig.getPaddingSymmetric(horizontal: 22),
                    child: Container(
                      height: SizeConfig.sizedBoxHeight(46),
                      decoration: BoxDecoration(
                        color: AppThemeManage.appTheme.darkGreyColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppThemeManage.appTheme.borderColor,
                        ),
                      ),
                      child: Padding(
                        padding: SizeConfig.getPaddingSymmetric(horizontal: 15),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                SvgPicture.asset(
                                  AppAssets.settingsIcosn.policy,
                                  height: SizeConfig.safeHeight(2.7),
                                  colorFilter: ColorFilter.mode(AppThemeManage.appTheme.darkWhiteColor, BlendMode.srcIn),
                                ),

                                SizedBox(width: SizeConfig.width(2)),
                                Text(
                                  AppString.appVersion,
                                  style: AppTypography.innerText12Mediu(
                                    context,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              appVersion,
                              style: AppTypography.inputPlaceholderSmall(
                                context,
                              ).copyWith(
                                fontFamily: AppTypography.fontFamily.poppins,
                                color: AppColors.textColor.textGreyColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: SizeConfig.height(2)),
                  // Logout method
                  Consumer<AuthProvider>(
                    builder: (context, authProvider, _) {
                      return Padding(
                        padding: SizeConfig.getPaddingSymmetric(horizontal: 20),
                        child: InkWell(
                          onTap:
                              authProvider.isLogout
                                  ? null
                                  : () {
                                    logoutDeleteDialog(
                                      context,
                                      title: AppString.settingStrigs.logout,
                                    );
                                  },
                          child: Container(
                            height: SizeConfig.sizedBoxHeight(46),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: AppThemeManage.appTheme.darkGreyColor,
                              border: Border.all(
                                color: AppThemeManage.appTheme.borderColor,
                              ),
                            ),
                            child: Padding(
                              padding: SizeConfig.getPaddingSymmetric(
                                horizontal: 15,
                              ),
                              child: Row(
                                children: [
                                  authProvider.isLogout
                                      ? SizedBox(
                                        height: SizeConfig.sizedBoxHeight(20),
                                        width: SizeConfig.sizedBoxHeight(20),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                AppColors
                                                    .textColor
                                                    .textErrorColor1,
                                              ),
                                        ),
                                      )
                                      : SvgPicture.asset(
                                        AppAssets.settingsIcosn.logout,
                                        height: SizeConfig.sizedBoxHeight(20),
                                      ),
                                  SizedBox(width: SizeConfig.width(2)),
                                  Text(
                                    authProvider.isLogout
                                        ? "Logging out..."
                                        : AppString.settingStrigs.logout,
                                    style: AppTypography.innerText12Mediu(
                                      context,
                                    ).copyWith(
                                      fontSize: SizeConfig.getFontSize(13),
                                      color:
                                          AppColors.textColor.textErrorColor1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: SizeConfig.height(4)),
                  Consumer<AuthProvider>(
                    builder: (context, authProvider, _) {
                      return Padding(
                        padding: SizeConfig.getPaddingSymmetric(horizontal: 60),
                        child: customBtn2(
                          context,
                          onTap:
                              authProvider.isDeleteAcc
                                  ? null
                                  : () {
                                    // ✅ Check if user is demo account
                                    if (isDemo) {
                                      snackbarNew(
                                        context,
                                        msg: "Demo accounts cannot delete their account",
                                      );
                                      return;
                                    }

                                    logoutDeleteDialog(
                                      context,
                                      title:
                                          AppString.settingStrigs.deleteAccount,
                                    );
                                  },
                          child:
                              authProvider.isDeleteAcc
                                  ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                ThemeColorPalette.getTextColor(
                                                  AppColors
                                                      .appPriSecColor
                                                      .primaryColor,
                                                ),
                                              ),
                                        ),
                                      ),
                                      SizedBox(width: 10),
                                      Text(
                                        "${AppString.deleting}...",
                                        style: AppTypography.buttonText12(
                                          context,
                                        ).copyWith(
                                          fontSize: SizeConfig.getFontSize(14),
                                          color: ThemeColorPalette.getTextColor(
                                            AppColors
                                                .appPriSecColor
                                                .primaryColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                  : Text(
                                    AppString.settingStrigs.deleteAccount,
                                    style: AppTypography.buttonText12(
                                      context,
                                    ).copyWith(
                                      fontSize: SizeConfig.getFontSize(14),
                                      color: ThemeColorPalette.getTextColor(
                                        AppColors.appPriSecColor.primaryColor,
                                      ), //AppColors.textColor.textBlackColor,
                                    ),
                                  ),
                        ),
                      );
                    },
                  ),
                  SizedBox(
                    height:
                        SizeConfig.sizedBoxHeight(30) +
                        MediaQuery.of(context).padding.bottom,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

Widget containerDesgin(
  BuildContext context, {
  required Function() onTap,
  required String img,
  required String title,
  required String count,
  required bool isCount,
}) {
  return Padding(
    padding: SizeConfig.getPaddingSymmetric(horizontal: 22),
    child: InkWell(
      onTap: onTap,
      child: Container(
        height: SizeConfig.sizedBoxHeight(46),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: AppThemeManage.appTheme.darkGreyColor,
          border: Border.all(color: AppThemeManage.appTheme.borderColor),
        ),
        child: Padding(
          padding: SizeConfig.getPaddingSymmetric(horizontal: 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  SvgPicture.asset(
                    img,
                    height: SizeConfig.safeHeight(2.7),
                    colorFilter: ColorFilter.mode(AppThemeManage.appTheme.darkWhiteColor, BlendMode.srcIn),
                  ),

                  SizedBox(width: SizeConfig.width(2)),
                  Text(title, style: AppTypography.innerText12Mediu(context)),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  isCount
                      ? Text(
                        count,
                        style: AppTypography.inputPlaceholderSmall(
                          context,
                        ).copyWith(
                          fontFamily: AppTypography.fontFamily.poppins,
                          color: AppColors.textColor.textGreyColor,
                        ),
                      )
                      : SizedBox.shrink(),
                  isCount
                      ? SizedBox(height: SizeConfig.height(1))
                      : SizedBox.shrink(),
                  SvgPicture.asset(
                    AppDirectionality.appDirectionIcon.arrow,
                    height: SizeConfig.safeHeight(3),
                    colorFilter: ColorFilter.mode(AppThemeManage.appTheme.darkWhiteColor, BlendMode.srcIn),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget darkLightModeWidget() {
  return Padding(
    padding: SizeConfig.getPaddingSymmetric(horizontal: 22),
    child: Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return Container(
          height: SizeConfig.sizedBoxHeight(46),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: AppThemeManage.appTheme.darkGreyColor,
            border: Border.all(color: AppThemeManage.appTheme.borderColor),
          ),
          child: Padding(
            padding: SizeConfig.getPaddingSymmetric(horizontal: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      transitionBuilder: (child, animation) {
                        return RotationTransition(
                          turns: animation,
                          child: FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                        );
                      },
                      child: SvgPicture.asset(
                        AppThemeManage.appTheme.appDarkLightIcon,
                        key: ValueKey<bool>(
                          themeProvider.isLightMode,
                        ), // important!
                        height: SizeConfig.safeHeight(2.7),
                      ),
                    ),

                    SizedBox(width: SizeConfig.width(2)),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        AppThemeManage.appTheme.lightDarkText,
                        key: ValueKey<bool>(themeProvider.isLightMode),
                        style: AppTypography.innerText12Mediu(context),
                      ),
                    ),
                  ],
                ),
                CustomSwitch(
                  value: isLightModeGlobal,
                  onChanged: (bool value) {
                    themeProvider.toggleThemeMode(value);
                  },
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

Widget themeColorSelectionWidget(BuildContext context) {
  return Padding(
    padding: SizeConfig.getPaddingSymmetric(horizontal: 22),
    child: Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ThemeColorPicker()),
            );
          },
          child: Container(
            height: SizeConfig.sizedBoxHeight(46),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: AppThemeManage.appTheme.darkGreyColor,
              border: Border.all(color: AppThemeManage.appTheme.borderColor),
            ),
            child: Padding(
              padding: SizeConfig.getPaddingSymmetric(horizontal: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      // Color palette icon
                      Container(
                        height: SizeConfig.safeHeight(2.7),
                        width: SizeConfig.safeHeight(2.7),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.appPriSecColor.primaryColor,
                          border: Border.all(
                            color: AppThemeManage.appTheme.darkWhiteColor,
                            width: 1.5,
                          ),
                        ),
                      ),
                      SizedBox(width: SizeConfig.width(2)),
                      Text(
                        AppString.settingStrigs.chatcolor, //"Chat color",
                        style: AppTypography.innerText12Mediu(context),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (themeProvider.hasCustomTheme)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: SizeConfig.width(2),
                            vertical: SizeConfig.height(0.5),
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.appPriSecColor.primaryColor
                                .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "Custom",
                            style: AppTypography.inputPlaceholderSmall(
                              context,
                            ).copyWith(
                              fontFamily: AppTypography.fontFamily.poppins,
                              fontSize: SizeConfig.getFontSize(10),
                              color: AppColors.appPriSecColor.primaryColor,
                            ),
                          ),
                        ),
                      SizedBox(width: SizeConfig.width(2)),
                      SvgPicture.asset(
                        AppDirectionality.appDirectionIcon.arrow,
                        height: SizeConfig.safeHeight(3),
                        colorFilter: ColorFilter.mode(
                          AppThemeManage.appTheme.darkWhiteColor,
                          BlendMode.srcIn,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

// Updated logoutDeleteDialog function in your settings_screen.dart

Future logoutDeleteDialog(BuildContext context, {required String title}) {
  return bottomSheetGobalWithoutTitle(
    context,
    bottomsheetHeight: SizeConfig.height(25),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: SizeConfig.height(3)),
        Padding(
          padding: SizeConfig.getPaddingSymmetric(horizontal: 30),
          child: Text(
            title == AppString.settingStrigs.logout
                ? AppString.settingStrigs.logoutAsk1
                : AppString.settingStrigs.deleteAsk1,
            textAlign: TextAlign.start,
            style: AppTypography.captionText(context).copyWith(
              fontSize: SizeConfig.getFontSize(15),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(height: SizeConfig.height(2)),
        Padding(
          padding: SizeConfig.getPaddingSymmetric(horizontal: 30),
          child: Text(
            title == AppString.settingStrigs.logout
                ? AppString.settingStrigs.logoutAsk
                : AppString.settingStrigs.deleteAsk,
            textAlign: TextAlign.start,
            style: AppTypography.captionText(context).copyWith(
              color: AppColors.textColor.textGreyColor,
              fontSize: SizeConfig.getFontSize(13),
            ),
          ),
        ),
        title == AppString.settingStrigs.logout
            ? SizedBox(height: SizeConfig.height(4))
            : SizedBox(height: SizeConfig.height(3)),
        Consumer<AuthProvider>(
          builder: (context, authProvider, _) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                SizedBox(
                  height: SizeConfig.height(5),
                  width: SizeConfig.width(35),
                  child: customBorderBtn(
                    context,
                    onTap: () {
                      Navigator.pop(context);
                    },
                    title: AppString.cancel,
                  ),
                ),
                authProvider.isDeleteAcc || authProvider.isLogout
                    ? Container(
                      height: SizeConfig.sizedBoxHeight(35),
                      width: SizeConfig.sizedBoxWidth(35),
                      decoration: BoxDecoration(),
                      child: commonLoading(),
                    )
                    : SizedBox(
                      height: SizeConfig.height(5),
                      width: SizeConfig.width(35),
                      child: customBtn2(
                        context,
                        onTap: () async {
                          if (title == AppString.settingStrigs.logout) {
                            // LOGOUT FLOW - Updated with socket cleanup
                            try {
                              // Handle logout with proper socket cleanup
                              await authProvider.handleLogout(context);

                              // Small delay for cleanup to complete
                              await Future.delayed(
                                const Duration(milliseconds: 500),
                              );

                              if (!context.mounted) return;

                              // Navigate to login screen
                              Navigator.pushNamedAndRemoveUntil(
                                context,
                                AppRoutes.login,
                                (Route<dynamic> route) => false,
                              );
                            } catch (e) {
                              // If logout fails, still navigate but show error
                              if (!context.mounted) return;
                              snackbarNew(
                                context,
                                msg: 'Logout completed with warnings',
                              );
                              Navigator.pushNamedAndRemoveUntil(
                                context,
                                AppRoutes.login,
                                (Route<dynamic> route) => false,
                              );
                            }
                          } else {
                            // ACCOUNT DELETION FLOW - Updated with socket cleanup
                            try {
                              final success = await authProvider
                                  .handleAccountDeletion(context);

                              if (!context.mounted) return;

                              if (success) {
                                final msg =
                                    authProvider.errorMessage?.toString() ??
                                    'Account deleted successfully';
                                snackbarNew(context, msg: msg);

                                // Small delay to show the message
                                await Future.delayed(
                                  const Duration(seconds: 1),
                                );

                                if (!context.mounted) return;

                                // Navigate to login screen
                                Navigator.pushNamedAndRemoveUntil(
                                  context,
                                  AppRoutes.login,
                                  (Route<dynamic> route) => false,
                                );
                              } else {
                                final msg =
                                    authProvider.errorMessage?.toString() ??
                                    'Failed to delete account';
                                Navigator.pop(context);
                                snackbarNew(context, msg: msg);
                              }
                            } catch (e) {
                              if (!context.mounted) return;
                              Navigator.pop(context);
                              snackbarNew(
                                context,
                                msg: 'Error occurred during account deletion',
                              );
                            }
                          }
                        },
                        child: Text(
                          title == AppString.settingStrigs.logout
                              ? AppString.settingStrigs.logout
                              : AppString.settingStrigs.delete,
                          style: AppTypography.h5(context).copyWith(
                            fontWeight: FontWeight.w600,
                            color: ThemeColorPalette.getTextColor(
                              AppColors.appPriSecColor.primaryColor,
                            ), //AppColors.textColor.textBlackColor,
                          ),
                        ),
                      ),
                    ),
              ],
            );
          },
        ),
      ],
    ),
  );
}

Future appLanguagePopup(BuildContext context) {
  return bottomSheetGobal(
    context,
    bottomsheetHeight: SizeConfig.sizedBoxHeight(305),
    title: AppString.settingStrigs.appLanguage,
    child: LanguagePopUp(),
  );
}

/// 🧪 DEBUG TEST: Returns debug buttons only in debug mode
List<Widget> debugCallNotificationButton(BuildContext context) {
  List<Widget> widgets = [];

  // Only add the test buttons in debug mode
  // ✅ COMMENTED OUT: Test widgets hidden from settings screen
  /*
  assert(() {
    widgets.addAll([
      SizedBox(height: SizeConfig.height(2)),
      containerDesgin(
        context,
        onTap: () async {
          try {
            // Show confirmation dialog first
            final shouldTest = await showDialog<bool>(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: Text('🧪 Test Call Notification'),
                  content: Text(
                    'This will test the call ringtone based on your device sound profile:\n\n'
                    '• Silent mode: No sound/vibration\n'
                    '• Vibrate mode: Vibration only\n'
                    '• Normal mode: Custom ringtone + vibration\n\n'
                    'Test will auto-stop after 10 seconds.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text('Test Now'),
                    ),
                  ],
                );
              },
            );

            if (shouldTest == true) {
              // Trigger the test
              await CallNotificationManager.instance.testCallNotification();

              // Show success message
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '🧪 Call notification test started! Check logs for details.',
                    ),
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            }
          } catch (e) {
            // Show error message
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('🧪 Test failed: $e'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 3),
                ),
              );
            }
          }
        },
        img: AppAssets.settingsIcosn.feedback, // Using feedback icon for test
        title: "🧪 Test Call Notification (Debug)",
        count: "",
        isCount: false,
      ),
      SizedBox(height: SizeConfig.height(2)),
      containerDesgin(
        context,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => TestLayoutScreen()),
          );
        },
        img:
            AppAssets
                .settingsIcosn
                .profile, // Using profile icon for layout test
        title: "🧪 Test Video Call Layout (Debug)",
        count: "",
        isCount: false,
      ),
    ]);
    return true;
  }());
  */

  return widgets;
}
