import 'package:flutter/material.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/packages/read_more/read_more_text.dart';
import 'package:whoxa/utils/packages/story/src/controller/flutter_story_controller.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';

class MessageBoxView extends StatelessWidget {
  const MessageBoxView({
    super.key,
    required this.controller,
    required this.msgController,
    required this.storycaption,
    required this.childSendBtn,
  });

  final FlutterStoryController controller;
  final TextEditingController msgController;
  final String storycaption;
  final Widget childSendBtn;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        color: AppColors.black,
        height: SizeConfig.height(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              ReadMoreText(
                storycaption,
                trimLines: 2,
                trimMode: TrimMode.Line,
                trimExpandedText: "Read less",
                trimCollapsedText: "Read more",
                moreStyle: AppTypography.innerText12Mediu(
                  context,
                ).copyWith(color: AppColors.appPriSecColor.primaryColor),
                lessStyle: AppTypography.innerText12Mediu(
                  context,
                ).copyWith(color: AppColors.appPriSecColor.primaryColor),
                style: AppTypography.innerText12Mediu(
                  context,
                ).copyWith(color: AppColors.white),
              ),
              SizedBox(height: SizeConfig.height(1)),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.strokeColor.c1A1919,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      child: TextFormField(
                        controller: msgController,
                        onTap: () {
                          controller.pause();
                        },
                        onTapOutside: (event) {
                          controller.play();
                          FocusScope.of(context).unfocus();
                        },
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          fontFamily: AppTypography.fontFamily.poppins,
                          color: AppColors.textColor.textWhiteColor,
                        ),
                        decoration: InputDecoration(
                          hintText: AppString.storyStrings.typeReply,
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  childSendBtn,
                ],
              ),
              SizedBox(height: SizeConfig.height(1)),
            ],
          ),
        ),
      ),
    );
  }
}
