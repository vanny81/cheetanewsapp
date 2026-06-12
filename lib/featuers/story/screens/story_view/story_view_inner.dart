import 'dart:developer';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/featuers/chat/provider/chat_provider.dart';
import 'package:whoxa/featuers/provider/theme_provider.dart';
import 'package:whoxa/featuers/story/data/model/model.dart';
import 'package:whoxa/featuers/story/provider/story_provider.dart';
import 'package:whoxa/featuers/story/screens/story_view/message_box_view.dart';
import 'package:whoxa/featuers/story/screens/story_view/my_story_viewed_list.dart';
import 'package:whoxa/featuers/story/screens/story_view/profile_view.dart';
import 'package:whoxa/screens/new_tabbar.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/enums.dart';
import 'package:whoxa/utils/logger.dart';
import 'package:whoxa/utils/packages/story/src/controller/flutter_story_controller.dart';
import 'package:whoxa/utils/packages/story/src/models/story_view_indicator_config.dart';
import 'package:whoxa/utils/packages/story/src/story_presenter/story_view.dart';
import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/widgets/custom_bottomsheet.dart';
import 'package:whoxa/widgets/global.dart';

class MyStoryView extends StatefulWidget {
  const MyStoryView({
    super.key,
    required this.storyModel,
    required this.pageController,
    required this.currentIndex,
    required this.totalUsers,
    required this.isMyStory,
    this.onComplete,
  });

  final List<StoryModel> storyModel;
  final PageController pageController;
  final int currentIndex;
  final int totalUsers;
  final bool isMyStory;
  final VoidCallback? onComplete;

  @override
  State<MyStoryView> createState() => _MyStoryViewState();
}

class _MyStoryViewState extends State<MyStoryView> {
  late FlutterStoryController controller;
  TextEditingController msgControllerl = TextEditingController();
  final ConsoleAppLogger _logger = ConsoleAppLogger();
  ChatProvider? _chatProvider;
  int currentStoryIndex = 0;
  // ignore: unused_field
  String? _storyCaption;
  String? _storyTime; // 👈 keep time in state
  String? _storyID;

  @override
  void initState() {
    debugPrint("currentIndex:${widget.currentIndex}");
    controller = FlutterStoryController();
    msgControllerl = TextEditingController();
    if (widget.storyModel[widget.currentIndex].stories.isNotEmpty) {
      final firstStory = widget.storyModel[widget.currentIndex].stories[0];
      if (firstStory is CustomStoryItem) {
        _storyTime = firstStory.storyTime;
        _storyCaption = firstStory.storyCaption;
        _storyID = firstStory.storyId;
      }
    }

    super.initState();
  }

  @override
  void dispose() {
    msgControllerl.dispose();
    super.dispose();
  }

  int _currentStoryIndex = 0;

  @override
  Widget build(BuildContext context) {
    final storyViewIndicatorConfig = StoryViewIndicatorConfig(
      height: 2,
      activeColor: Colors.white,
      backgroundCompletedColor: Colors.white,
      backgroundDisabledColor: Colors.white.withValues(alpha: 0.5),
      horizontalGap: 1,
      borderRadius: 1.5,
    );

    return Consumer2<StoryProvider, ChatProvider>(
      builder: (context, storyProvider, chatProvider, _) {
        final isLoading = chatProvider.isSendingMessage;
        return FlutterStoryPresenter(
          flutterStoryController: controller,
          items: widget.storyModel[widget.currentIndex].stories,
          storyViewIndicatorConfig: storyViewIndicatorConfig,
          initialIndex: 0,
          // onStoryChanged: (index) async {
          // _currentStoryIndex = index + 1;
          //   debugPrint("_currentStoryIndex:$_currentStoryIndex");
          //   WidgetsBinding.instance.addPostFrameCallback((_) async {
          //     if (!widget.isMyStory) {
          //       log("→→→→TO_USER_STORY_SEEN:");
          //       final story =
          //           widget
          //               .storyModel[widget.currentIndex]
          //               .stories[_currentStoryIndex - 1];

          //       if (story is CustomStoryItem) {
          //         debugPrint("Story_seen: $index");
          //         debugPrint("Story_ID: ${story.storyId}");
          //         setState(() {
          //           _storyCaption = story.storyCaption;
          //           _storyTime = story.storyTime; // 👈 update state here
          //           _storyID = story.storyId;
          //         });
          //         debugPrint("StoryTimeToUser:$_storyTime");
          //         storyProvider.notify(); // safe now
          //         await storyProvider.viewStory(storyID: story.storyId);
          //         storyProvider.notify(); // safe now
          //       }
          //     } else {
          //       log("→→→→MY_STORY_SEEN:");
          //       final story =
          //           widget
          //               .storyModel[widget.currentIndex]
          //               .stories[_currentStoryIndex - 1];
          //       storyProvider.storyID = story.storyID.toString();

          //       if (story is CustomStoryItem) {
          //         debugPrint("Story_ID2: ${story.storyId}");
          //         setState(() {
          //           _storyCaption = story.storyCaption;
          //           _storyTime = story.storyTime; // 👈 update state here
          //           _storyID = story.storyId;
          //         });
          //         debugPrint("StoryTimeMy:$_storyTime");
          //         storyProvider.notify(); // safe now
          //         await storyProvider.getViewedList(storyID: story.storyId);
          //         storyProvider.notify(); // safe now
          //       }
          //     }
          //   });
          // },
          onStoryChanged: (index) async {
            _currentStoryIndex = index;
            debugPrint("_currentStoryIndex:$_currentStoryIndex");

            WidgetsBinding.instance.addPostFrameCallback((_) async {
              final stories = widget.storyModel[widget.currentIndex].stories;

              if (_currentStoryIndex < 0 ||
                  _currentStoryIndex >= stories.length) {
                debugPrint("⚠ Invalid story index: $_currentStoryIndex");
                return;
              }

              final story = stories[_currentStoryIndex];

              if (!widget.isMyStory) {
                log("→→→→TO_USER_STORY_SEEN:");

                if (story is CustomStoryItem) {
                  debugPrint("Story_seen: $index");
                  debugPrint("Story_ID: ${story.storyId}");

                  setState(() {
                    _storyCaption = story.storyCaption;
                    _storyTime = story.storyTime;
                    _storyID = story.storyId;
                    storyID = _storyID;
                  });

                  debugPrint("StoryTimeToUser: $_storyTime");
                  storyProvider.notify();
                  await storyProvider.viewStory(storyID: story.storyId);
                  storyProvider.notify();
                }
              } else {
                log("→→→→MY_STORY_SEEN:");
                storyProvider.storyID = story.storyID.toString();

                if (story is CustomStoryItem) {
                  debugPrint("Story_ID2: ${story.storyId}");

                  setState(() {
                    _storyCaption = story.storyCaption;
                    _storyTime = story.storyTime;
                    _storyID = story.storyId;
                    storyID = _storyID;
                  });

                  debugPrint("StoryTimeMy: $_storyTime");
                  storyProvider.notify();
                  await storyProvider.getViewedList(storyID: story.storyId);
                  storyProvider.notify();
                }
              }
            });
          },
          onPreviousCompleted: () async {
            debugPrint(
              "✅ onPreviousCompleted fired for user: ${widget.currentIndex}",
            );
            await widget.pageController.previousPage(
              duration: const Duration(milliseconds: 500),
              curve: Curves.decelerate,
            );
          },
          onCompleted: () async {
            controller.pause();
            debugPrint("😀:${widget.currentIndex}");
            debugPrint("😀:${widget.totalUsers}");
            debugPrint("😀Story complete at index: ${widget.currentIndex}");
            widget.onComplete?.call(); // 👈 notify parent
            if (widget.currentIndex == widget.totalUsers - 1) {
              // Last story of the last user
              Navigator.pop(context);
              await storyProvider.getAllStories();
            } else {
              // Go to next
              debugPrint("NEXT STORY TAPPED");
              await widget.pageController.nextPage(
                duration: const Duration(milliseconds: 500),
                curve: Curves.decelerate,
              );
            }
          },
          footerWidget:
              widget.isMyStory
                  ? MyStoryViewList(
                    controller: controller,
                    storycaption: stroyCaption,
                  )
                  : MessageBoxView(
                    controller: controller,
                    msgController: msgControllerl,
                    storycaption: stroyCaption,
                    childSendBtn: InkWell(
                      onTap: () {
                        if (mounted &&
                            !isLoading &&
                            msgControllerl.text.trim().isNotEmpty) {
                          _sendTextMessage(
                            toUserID:
                                widget.storyModel[widget.currentIndex].userID,
                          );
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: AppColors.gradientColor.gradientColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Padding(
                          padding: SizeConfig.getPaddingSymmetric(
                            horizontal: 13,
                            vertical: 11,
                          ),
                          child:
                              isLoading
                                  ? SizedBox(
                                    height: SizeConfig.sizedBoxHeight(25),
                                    width: SizeConfig.sizedBoxWidth(25),
                                    child: commonLoading2(),
                                  )
                                  : Image.asset(
                                    AppAssets.send,
                                    height: SizeConfig.sizedBoxHeight(24),
                                    width: SizeConfig.sizedBoxWidth(24),
                                    color: AppColors.black,
                                  ),
                        ),
                      ),
                    ),
                  ),
          headerWidget: ProfileView(
            userName: widget.storyModel[widget.currentIndex].userName,
            userProfile: widget.storyModel[widget.currentIndex].userProfile,
            fName: widget.storyModel[widget.currentIndex].fName,
            lName: widget.storyModel[widget.currentIndex].lName,
            isMyStory: widget.isMyStory,
            storyTime: _storyTime ?? "",
            onPauseRequested: () {
              controller.pause();
              if (widget.isMyStory) {
                final story =
                    widget
                        .storyModel[widget.currentIndex]
                        .stories[_currentStoryIndex];

                if (story is CustomStoryItem) {
                  debugPrint("Story_ID_REMOVE: ${story.storyId}");
                  deleteDialo(
                    context,
                    storyProvider: storyProvider,
                    storyId: story.storyId,
                    index: widget.currentIndex,
                  );
                }
              }
            },
          ),
        );
      },
    );
  }

  Future deleteDialo(
    BuildContext context, {
    required StoryProvider storyProvider,
    required String storyId,
    required int index,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: const Color.fromRGBO(0, 0, 0, 0.57),
      builder:
          (_) => Dialog(
            alignment: Alignment.bottomCenter,
            elevation: 0,
            insetPadding: EdgeInsets.only(left: 10, right: 10, bottom: 10),
            backgroundColor: AppColors.transparent,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 3.8, sigmaY: 3.8),
              child: InkWell(
                onTap: () async {
                  Navigator.pop(context);
                  controller.pause();
                  await deleteStoryDialog(
                    context,
                    storyProvider: storyProvider,
                    storyid: storyId,
                    index: index,
                  );
                },
                child: Consumer<ThemeProvider>(
                  builder: (context, themeProvider, _) {
                    return Container(
                      decoration: BoxDecoration(
                        color: AppThemeManage.appTheme.darkGreyColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      height: SizeConfig.sizedBoxHeight(60),
                      width: SizeConfig.screenWidth,
                      child: Row(
                        children: [
                          SizedBox(width: SizeConfig.width(5)),
                          SvgPicture.asset(
                            AppAssets.trash,
                            colorFilter: ColorFilter.mode(AppThemeManage.appTheme.darkWhiteColor, BlendMode.srcIn),
                            height: SizeConfig.sizedBoxHeight(20),
                          ),
                          SizedBox(width: SizeConfig.width(2)),
                          Text(
                            AppString.delete,
                            style: AppTypography.h4(context),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
    );
  }

  Future deleteStoryDialog(
    BuildContext parentContext, {
    required StoryProvider storyProvider,
    required String storyid,
    required int index,
  }) {
    return bottomSheetGobalWithoutTitle(
      parentContext,
      isCrossIconHide: false,
      bottomsheetHeight: SizeConfig.height(22),
      insetPadding: SizeConfig.getPaddingSymmetric(
        horizontal: 10,
      ).copyWith(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: SizeConfig.height(3.5)),
          Padding(
            padding: SizeConfig.getPaddingSymmetric(horizontal: 30),
            child: Text(
              AppString.storyStrings.areYouSureYouWantTo,
              textAlign: TextAlign.start,
              style: AppTypography.innerText16(parentContext),
            ),
          ),
          SizedBox(height: SizeConfig.height(3)),
          Padding(
            padding: SizeConfig.getPaddingOnly(left: 30, right: 60),
            child: Text(
              AppString.storyStrings.areYouSureYouWantToDelet,
              textAlign: TextAlign.start,
              style: AppTypography.captionText(
                parentContext,
              ).copyWith(color: AppColors.textColor.textGreyColor),
            ),
          ),
          SizedBox(height: SizeConfig.height(3)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              SizedBox(
                height: SizeConfig.height(5),
                width: SizeConfig.width(35),
                child: customBorderBtn(
                  parentContext,
                  onTap: () {
                    controller.play();
                    Navigator.pop(parentContext);
                  },
                  title: AppString.cancel,
                ),
              ),
              SizedBox(
                height: SizeConfig.height(5),
                width: SizeConfig.width(35),
                child: customBtn2(
                  parentContext,
                  onTap: () async {
                    final success = await storyProvider.removeStoryApi(
                      storyid: storyid,
                    );
                    if (!parentContext.mounted) return;
                    if (success) {
                      final currentStories =
                          storyProvider.myStory[widget.currentIndex].stories;

                      setState(() {
                        // remove the story
                        currentStories.removeWhere(
                          (story) =>
                              story is CustomStoryItem &&
                              story.storyId == storyid,
                        );

                        if (currentStories.isEmpty) {
                          // no stories left for this user
                          storyProvider.myStory.removeAt(widget.currentIndex);

                          if (storyProvider.myStory.isEmpty) {
                            debugPrint("story_Remove_0");
                            // Navigator.pop(parentContext);
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (context) => NewTabbarScreen(),
                              ),
                              (Route<dynamic> route) => false,
                            );
                            return;
                          }

                          // ✅ Case 2: Removed last story (index now out of range)
                          if (index >= storyProvider.myStory.length) {
                            debugPrint("story_Remove_1");
                            Navigator.pop(parentContext);
                            return;
                          }
                        }
                      });

                      // refresh UI
                      storyProvider.notify();

                      // ✅ Only pop if story list still valid
                      if (index < storyProvider.myStory.length &&
                          storyProvider.myStory[index].stories.isNotEmpty) {
                        if (_currentStoryIndex >= currentStories.length) {
                          _currentStoryIndex = currentStories.length - 1;
                        }

                        debugPrint(
                          "story_Remove_2 -> showing story index $_currentStoryIndex",
                        );
                        // Navigator.pop(context); // close current story view
                        if (!mounted) return;
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => NewTabbarScreen(),
                          ),
                          (Route<dynamic> route) => false,
                        );
                      }
                    } else {
                      snackbarNew(
                        parentContext,
                        msg: storyProvider.errorMessage.toString(),
                      );
                    }
                  },
                  child:
                      storyProvider.isRemove
                          ? SizedBox(
                            height: SizeConfig.sizedBoxHeight(25),
                            width: SizeConfig.sizedBoxWidth(25),
                            child: CircularProgressIndicator(
                              strokeWidth: 1,
                              color: AppColors.black,
                            ),
                          )
                          : Text(
                            AppString.settingStrigs.delete,
                            style: AppTypography.buttonText(context).copyWith(
                              color: AppColors.textColor.textBlackColor,
                            ),
                          ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _sendTextMessage({required String toUserID}) {
    if (!mounted || msgControllerl.text.trim().isEmpty) return;

    final chatProvider =
        _chatProvider ?? Provider.of<ChatProvider>(context, listen: false);
    final chatId = 0;

    _logger.d(
      "Sending message to ${chatId == 0 ? 'new user' : 'existing chat'}: $toUserID",
    );
    chatProvider.storyid = storyID;
    chatProvider
        .sendMessage(
          userId: int.parse(toUserID),
          msgControllerl.text.trim(),
          messageType: MessageType.StoryReply,
        )
        .then((success) {
          if (mounted) {
            if (success) {
              msgControllerl.clear();
              _sendTypingEvent(false, toUserID);
              snackbarNew(context, msg: "Your reply has been sent");
              Navigator.pop(context);
            } else {
              // Check if there's an API error message to show
              final apiError = chatProvider.apiErrorMessage;
              if (apiError != null && apiError.isNotEmpty) {
                snackbarNew(context, msg: apiError);
                chatProvider.clearApiErrorMessage();
              }
            }
          }
        });
  }

  void _sendTypingEvent(bool isTyping, touserid) {
    if (!mounted) return;

    final chatProvider =
        _chatProvider ?? Provider.of<ChatProvider>(context, listen: false);

    final currentChatId = chatProvider.currentChatData.chatId ?? 0;

    _logger.d(
      "Sending typing event - ChatId: $currentChatId, UserId: $touserid, IsTyping: $isTyping",
    );

    chatProvider.sendTypingStatus(currentChatId, isTyping);
  }
}
