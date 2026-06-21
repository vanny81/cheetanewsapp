// ignore_for_file: use_build_context_synchronously, avoid_print, deprecated_member_use

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/featuers/provider/theme_provider.dart';
import 'package:whoxa/featuers/story/data/model/get_all_story_model.dart';
import 'package:whoxa/featuers/story/provider/story_provider.dart';
import 'package:whoxa/featuers/story/screens/story_upload.dart';
import 'package:whoxa/featuers/story/screens/story_view.dart';
import 'package:whoxa/featuers/story/screens/trimmer_view.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_routes.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/widgets/cusotm_blur_appbar.dart';
import 'package:whoxa/widgets/custom_bottomsheet.dart';
import 'package:whoxa/widgets/global.dart';
import 'package:whoxa/featuers/chat/services/contact_name_service.dart';
import 'package:whoxa/featuers/project-config/provider/config_provider.dart';
import 'package:status_view/status_view.dart';
// import 'package:whoxa/featuers/story/data/model/get_all_story_model.dart';

class StoryList extends StatefulWidget {
  const StoryList({super.key});

  @override
  State<StoryList> createState() => _StoryListState();
}

class _StoryListState extends State<StoryList> with TickerProviderStateMixin {
  late Future<void> storyProvider;

  // Tab controller for different media types
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    debugPrint("authToken:$authToken");
    debugPrint("userProfile:$userProfile");
    _tabController = TabController(length: 2, vsync: this);
    Future.microtask(() {
      storyProvider =
          Provider.of<StoryProvider>(context, listen: false).getAllStories();
    });
  }

  // Helper method to get display name using ContactNameService
  String _getDisplayName(dynamic storyUser) {
    final configProvider = Provider.of<ProjectConfigProvider>(
      context,
      listen: false,
    );

    // 🎯 FIXED: Use getDisplayNameStable for consistent priority behavior
    return ContactNameService.instance.getDisplayNameStable(
      userId: storyUser.userId,
      configProvider: configProvider,
      contextFullName: storyUser.fullName, // Pass the full name from story user
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return Scaffold(
          backgroundColor: AppThemeManage.appTheme.scaffoldBackColor,
          appBar: AppBar(
            elevation: 0,
            scrolledUnderElevation: 0,
            automaticallyImplyLeading: false,
            backgroundColor: AppColors.transparent,
            systemOverlayStyle: systemUI(),
            // flexibleSpace: flexibleSpace(),
            title: Text(
              AppString.storyStrings.status,
              style: AppTypography.h2(context).copyWith(
                fontWeight: FontWeight.w600,
                fontFamily: AppTypography.fontFamily.poppinsBold,
              ),
            ),
          ),
          body: Consumer<StoryProvider>(
            builder: (context, storyProvider, _) {
              if (storyProvider.isGetStory && !storyProvider.hasLoadedOnce) {
                return Center(child: commonLoading());
              }
              if (storyProvider.errorMessage != null &&
                  !storyProvider.hasLoadedOnce) {
                return Center(
                  child:
                      storyProvider.isInternetIssue
                          ? SvgPicture.asset(AppAssets.svgIcons.internet)
                          : Text(
                            storyProvider.errorMessage!,
                            textAlign: TextAlign.center,
                            style: AppTypography.buttonText(context).copyWith(
                              color: AppColors.textColor.textErrorColor1,
                            ),
                          ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: SizeConfig.height(1)),
                  //*********************************************************/
                  //**************** My Status *****************************//
                  //*********************************************************/
                  myStatusView(context, storyProvider),
                  Divider(
                    color: AppThemeManage.appTheme.borderColor,
                    height: 1,
                    thickness: 1.5,
                  ),
                  //*********************************************************/
                  //**************** Recent Updates Status *****************//
                  //*********************************************************/
                  TabBar(
                    controller: _tabController,
                    indicatorColor: AppColors.appPriSecColor.primaryColor,
                    indicatorWeight: 1,
                    indicator: UnderlineTabIndicator(
                      borderSide: BorderSide(
                        width: 1.5,
                        color: AppColors.appPriSecColor.primaryColor,
                      ),
                    ),
                    dividerColor: AppThemeManage.appTheme.borderColor,
                    labelColor: AppColors.textColor.textBlackColor,
                    unselectedLabelColor: AppColors.textColor.textGreyColor,
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SvgPicture.asset(
                              AppAssets.bottomNavIcons.status,
                              height: 16,
                              color: AppColors.textColor.textDarkGray,
                            ),
                            SizedBox(width: 5),
                            Text(
                              AppString.storyStrings.recentUpdates,
                              style: AppTypography.innerText12Mediu(context),
                            ),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SvgPicture.asset(
                              AppAssets.bottomNavIcons.status,
                              height: 16,
                              color: AppColors.textColor.textDarkGray,
                            ),
                            SizedBox(width: 5),
                            Text(
                              AppString.storyStrings.viewedStatus,
                              style: AppTypography.innerText12Mediu(context),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // Recent Updates Content
                        recentUpdates(context, storyProvider),

                        // Viewed Status Content
                        viewedStatus(context, storyProvider),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget myStatusView(BuildContext context, StoryProvider storyProvider) {
    onTapFunction() async {
      await storyProvider.getImageFromGallery1(context);

      final selectedFile = storyProvider.selectedMediaFile;
      final selectedType = storyProvider.selectedMediaType;
      // final trimmer = storyProvider.trimmer;

      if (selectedFile != null) {
        if (selectedType == 'image') {
          Navigator.pushNamed(context, AppRoutes.storyUpload).then((_) {
            // storyProvider.getAllStories();
            storyProvider.notify();
          });
        } else if (selectedType == 'video') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => TrimmerView(selectedFile)),
          ).then((_) {
            storyProvider.getAllStories();
            storyProvider.notify();
          });
        }
      }
    }

    return ListTile(
      leading: Stack(
        children: [
          InkWell(
            onTap: () {
              onTapFunction();
            },
            child: Container(
              height: SizeConfig.sizedBoxHeight(50),
              width: SizeConfig.sizedBoxWidth(50),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.bgColor.bg4Color,
                border: Border.all(color: AppThemeManage.appTheme.borderColor),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(50),
                child: Image.network(
                  userProfile,
                  errorBuilder: (context, error, stackTrace) {
                    return Image.network(
                      "https://wallpapershome.com/images/pages/pic_h/16101.jpg",
                      fit: BoxFit.cover,
                    );
                  },
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 2,
            right: 2,
            child: Container(
              height: SizeConfig.sizedBoxHeight(12),
              width: SizeConfig.sizedBoxWidth(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.appPriSecColor.secondaryColor,
              ),
              child: Center(
                child: SvgPicture.asset(
                  AppAssets.ibadahGroupIcons.addSvg,
                  color: AppThemeManage.appTheme.bg4BlackColor,
                  height: SizeConfig.sizedBoxHeight(8),
                ),
              ),
            ),
          ),
        ],
      ),
      title: InkWell(
        onTap: () {
          onTapFunction();
        },
        child: Text(
          "$firstName $lastName",
          style: AppTypography.innerText14(context),
        ),
      ),
      subtitle: InkWell(
        child: Text(
          AppString.storyStrings.tapToAddYourStory,
          style: AppTypography.innerText12Mediu(
            context,
          ).copyWith(color: AppColors.textColor.textGreyColor),
        ),
      ),

      trailing:
          storyProvider.getMyStories.isEmpty
              ? SizedBox.shrink()
              : InkWell(
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.myStoryView).then((_) {
                    storyProvider.getAllStories();
                    storyProvider.notify();
                  });
                },
                child: SvgPicture.asset(
                  AppAssets.eyeStory,
                  color: AppThemeManage.appTheme.darkWhiteColor,
                  height: SizeConfig.sizedBoxHeight(24),
                ),
              ),
    );
  }

  Widget recentUpdates(BuildContext context, StoryProvider storyProvider) {
    List<RecentStories> otherUserStories =
        storyProvider.getRecentStoryList
            .where((story) => story.userId.toString() != userID)
            .toList();
    return otherUserStories.isEmpty
        ? _buildEmptyState(
          icon: AppAssets.emptyDataIcons.emptystatus2,
          title: AppString.emptyDataString.noStatusFound,
          subtitle: AppString.emptyDataString.youdonthaveanystatustoshow,
        )
        : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: SizeConfig.height(1)),
            ListView.separated(
              itemCount: otherUserStories.length,
              scrollDirection: Axis.vertical,
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: NeverScrollableScrollPhysics(),
              separatorBuilder: (context, index) {
                return Divider(color: AppThemeManage.appTheme.borderColor);
              },
              itemBuilder: (context, index) {
                var getStory = otherUserStories[index];
                // var getStory = storyProvider.getAllStoryList[index];

                return statusDesign(
                  context,
                  index,
                  storyProvider,
                  _getDisplayName(otherUserStories[index]),
                  otherUserStories[index].profilePic!,
                  getStory.stories!.length,
                  getStory.viewedCount ?? 0,
                  getStory.createdAt!,
                  true,
                  otherUserStories,
                  [],
                );
              },
            ),
          ],
        );
  }

  Widget viewedStatus(BuildContext context, StoryProvider storyProvider) {
    List<ViewedStories> otherUserStories =
        storyProvider.getViewedStoryList
            .where((story) => story.userId.toString() != userID)
            .toList();
    return otherUserStories.isEmpty
        ? _buildEmptyState(
          icon: AppAssets.emptyDataIcons.emptystatus2,
          title: AppString.emptyDataString.noStatusFound,
          subtitle: AppString.emptyDataString.youdonthaveanystatustoshow,
        )
        : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: SizeConfig.height(1)),
            ListView.separated(
              itemCount: otherUserStories.length,
              scrollDirection: Axis.vertical,
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: NeverScrollableScrollPhysics(),
              separatorBuilder: (context, index) {
                return Divider(color: AppThemeManage.appTheme.borderColor);
              },
              itemBuilder: (context, index) {
                var getStory = otherUserStories[index];
                // var getStory = storyProvider.getAllStoryList[index];

                return statusDesign(
                  context,
                  index,
                  storyProvider,
                  _getDisplayName(otherUserStories[index]),
                  otherUserStories[index].profilePic!,
                  getStory.stories!.length,
                  getStory.viewedCount ?? 0,
                  getStory.createdAt!,
                  false,
                  [],
                  otherUserStories,
                );
              },
            ),
          ],
        );
  }

  Widget statusDesign(
    BuildContext context,
    int index,
    StoryProvider storyProvider,
    String name,
    String profile,
    int totalStories,
    int seenStories,
    String date,
    bool isRecentStoryView,
    List<RecentStories> recentStoryList,
    List<ViewedStories> viewedStoryList,
  ) {
    return ListTile(
      dense: true,
      contentPadding: SizeConfig.getPaddingSymmetric(
        vertical: 0,
        horizontal: 20,
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => StoriesView(
                  isMyStory: false,
                  recentStories: recentStoryList,
                  viewedStories: viewedStoryList,
                  initialIndex: index,
                  isRecentStoryView: isRecentStoryView,
                ),
          ),
        ).then((_) {
          setState(() {});
        });
      },
      leading: StatusView(
        radius: 25,
        spacing: 10,
        strokeWidth: 1,
        indexOfSeenStatus: seenStories,
        numberOfStatus: totalStories,
        padding: 5,
        centerImageUrl:
            profile, //"https://wallpapershome.com/images/pages/pic_h/16101.jpg",
        seenColor: Colors.grey.shade400,
        unSeenColor: AppThemeManage.appTheme.blackPrimary,
      ),
      title: Text(name, style: AppTypography.innerText14(context)),
      subtitle: Text(
        formatStoryDate(date),
        style: AppTypography.smallText(
          context,
        ).copyWith(color: AppColors.textColor.textGreyColor),
      ),
    );
  }

  Widget titleText(BuildContext context, {required String title}) {
    return Padding(
      padding: SizeConfig.getPaddingSymmetric(horizontal: 20),
      child: Text(
        title,
        style: AppTypography.h4(context).copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }

  Future bottomSheetDesigin(BuildContext context, StoryProvider storyProvider) {
    return bottomSheetGobal(
      context,
      insetPadding: SizeConfig.getPaddingOnly(left: 40, right: 40, bottom: 10),
      bottomsheetHeight: SizeConfig.sizedBoxHeight(150),
      title: AppString.settingStrigs.profilePhoto,
      child: Column(
        children: [
          SizedBox(height: SizeConfig.height(3)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              bottomContainer(
                context,
                title: AppString.settingStrigs.camera,
                img: AppAssets.svgIcons.camera,
                onTap: () {
                  Navigator.pop(context);
                  getImageFromCamera(storyProvider);
                },
              ),
              SizedBox(width: SizeConfig.width(10)),
              bottomContainer(
                context,
                title: AppString.settingStrigs.gellery,
                img: AppAssets.svgIcons.gellery,
                onTap: () async {
                  Navigator.pop(context); // Close the bottom sheet first

                  await storyProvider.getImageFromGallery1(context);

                  final selectedFile = storyProvider.selectedMediaFile;
                  final selectedType = storyProvider.selectedMediaType;
                  // final trimmer = storyProvider.trimmer;

                  if (selectedFile != null) {
                    if (selectedType == 'image') {
                      Navigator.pushNamed(context, AppRoutes.storyUpload);
                    } else if (selectedType == 'video') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TrimmerView(selectedFile),
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget bottomContainer(
    BuildContext context, {
    required String title,
    required String img,
    required Function() onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.opacityColor.opacitySecColor,
            ),
            child: Padding(
              padding: SizeConfig.getPadding(12),
              child: Center(child: SvgPicture.asset(img, height: 22)),
            ),
          ),
          SizedBox(height: SizeConfig.height(1)),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.captionText(context),
          ),
        ],
      ),
    );
  }

  final picker = ImagePicker();
  Future getImageFromCamera(StoryProvider storyProvider) async {
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      storyProvider.selectedMediaFile = File(pickedFile.path);
      storyProvider.selectedMediaType = "image";
      storyProvider.notify();
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => StoryUpload()),
      );
    } else {
      debugPrint('No image selected.');
    }
  }

  Widget _buildEmptyState({
    required String icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        children: [
          SizedBox(height: SizeConfig.height(25)),
          SvgPicture.asset(
            icon,
            height: SizeConfig.sizedBoxHeight(64),
            color: AppColors.appPriSecColor.secondaryColor,
          ),
          SizedBox(height: 16),
          Text(title, style: AppTypography.h3(context)),
          SizedBox(height: 5),
          Text(
            subtitle,
            style: AppTypography.innerText12Mediu(
              context,
            ).copyWith(color: AppColors.textColor.textGreyColor),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
