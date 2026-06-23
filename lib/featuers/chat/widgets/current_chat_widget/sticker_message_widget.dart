import 'package:flutter/material.dart';
import 'package:whoxa/featuers/chat/widgets/current_chat_widget/base_message_widget.dart';
import 'package:whoxa/featuers/chat/widgets/current_chat_widget/chat_related_widget.dart';
import 'package:whoxa/featuers/chat/widgets/current_chat_widget/delete_message_widget.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_direction_manage.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';

/// Renders a sticker message in the chat.
///
/// Unlike [GifMessageWidget], stickers render with:
/// - No "GIF" badge overlay
/// - No bubble background — stickers float directly on the chat background
/// - Slightly larger display area for visual prominence
class StickerMessageWidget extends BaseMessageWidget {
  final VoidCallback? onTap;
  final bool isStarred;
  final Function(int)? onReplyTap;
  final bool isForPinned;
  final bool openedFromStarred;

  const StickerMessageWidget({
    super.key,
    required super.chat,
    required super.currentUserId,
    this.onTap,
    this.isStarred = false,
    this.onReplyTap,
    required this.isForPinned,
    this.openedFromStarred = false,
  });

  @override
  Widget build(BuildContext context) {
    final isSender = chat.senderId.toString() == currentUserId;
    final stickerUrl = chat.messageContent ?? '';
    final hasParentMessage = chat.parentMessage != null;

    // Safety check: if message is deleted, don't render sticker
    if (chat.messageContent == 'This message was deleted.' ||
        chat.messageContent == 'This message was deleted' ||
        chat.deletedForEveryone == true) {
      return DeletedMessageWidget(chat: chat, currentUserId: currentUserId);
    }

    return Align(
      alignment:
          isForPinned
              ? Alignment.centerLeft
              : isSender
              ? openedFromStarred
                  ? Alignment.centerLeft
                  : AppDirectionality.appDirectionAlign.alignmentEnd
              : AppDirectionality.appDirectionAlign.alignmentLeftRight,
      child: Column(
        crossAxisAlignment:
            openedFromStarred
                ? CrossAxisAlignment.start
                : isSender
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
        children: [
          Container(
            width: SizeConfig.screenWidth * 0.45,
            // No background color — stickers float on chat background
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                // Show parent message if this is a reply
                if (hasParentMessage) ...[
                  isForPinned
                      ? SizedBox.shrink()
                      : _buildParentMessagePreview(context, isSender),
                  isForPinned ? SizedBox.shrink() : SizedBox(height: 3),
                ],

                // Sticker image — no clip, no border, no badge
                GestureDetector(
                  onTap: onTap,
                  child: Container(
                    width: SizeConfig.screenWidth * 0.4,
                    height: SizeConfig.height(18),
                    padding: const EdgeInsets.all(4),
                    child: stickerUrl.isNotEmpty
                        ? Image.network(
                            stickerUrl,
                            fit: BoxFit.contain,
                            loadingBuilder:
                                (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value:
                                      loadingProgress.expectedTotalBytes !=
                                              null
                                          ? loadingProgress
                                                  .cumulativeBytesLoaded /
                                              loadingProgress
                                                  .expectedTotalBytes!
                                          : null,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(
                                    AppColors
                                        .appPriSecColor.primaryColor,
                                  ),
                                  strokeWidth: 2,
                                ),
                              );
                            },
                            errorBuilder:
                                (context, error, stackTrace) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.sticky_note_2_outlined,
                                      size: 36,
                                      color: AppColors
                                          .textColor.textGreyColor,
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      'Sticker failed to load',
                                      style: TextStyle(
                                        color: AppColors
                                            .textColor.textGreyColor,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          )
                        : Center(
                            child: Column(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.sticky_note_2_outlined,
                                  size: 36,
                                  color:
                                      AppColors.textColor.textGreyColor,
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Sticker',
                                  style: TextStyle(
                                    color: AppColors
                                        .textColor.textGreyColor,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
          isForPinned
              ? SizedBox.shrink()
              : SizedBox(height: SizeConfig.height(1)),
          (isForPinned || openedFromStarred)
              ? SizedBox.shrink()
              : ChatRelatedWidget.buildMetadataRow(
                context: context,
                chat: chat,
                isStarred: isStarred,
                isSentByMe: isSender,
              ),
          (isForPinned || openedFromStarred)
              ? SizedBox.shrink()
              : SizedBox(height: SizeConfig.height(2)),
        ],
      ),
    );
  }

  /// Build parent message preview with tap functionality
  Widget _buildParentMessagePreview(BuildContext context, bool isSentByMe) {
    final parentMessage = chat.parentMessage!;
    final parentContent = parentMessage['message_content'] ?? 'Message';
    final parentType = parentMessage['message_type'] ?? 'text';
    final parentThumbnail = parentMessage['message_thumbnail'];
    final parentMessageId = parentMessage['message_id'];

    return GestureDetector(
      onTap: () {
        if (onReplyTap != null && parentMessageId != null) {
          onReplyTap!(parentMessageId as int);
        }
      },
      child: Container(
        constraints: BoxConstraints(maxWidth: SizeConfig.width(70)),
        padding: SizeConfig.getPaddingSymmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: AppThemeManage.appTheme.bg488DarkGrey,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  ChatRelatedWidget.getSenderName(
                      parentMessage, currentUserId),
                  style: AppTypography.captionText(context).copyWith(
                    color: AppColors.appPriSecColor.primaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            SizedBox(height: 6),
            _buildParentMessageContent(
              context,
              parentType,
              parentContent,
              parentThumbnail,
              isSentByMe,
            ),
          ],
        ),
      ),
    );
  }

  /// Build parent message content based on type
  Widget _buildParentMessageContent(
    BuildContext context,
    String messageType,
    String content,
    String? thumbnail,
    bool isSentByMe,
  ) {
    if (content == 'This message was deleted.' ||
        content == 'This message was deleted' ||
        content.isEmpty) {
      return ChatRelatedWidget.buildTextPreview(
        context: context,
        content: 'This message was deleted.',
        isSentByMe: isSentByMe,
      );
    }

    switch (messageType.toLowerCase()) {
      case 'image':
        return ChatRelatedWidget.buildImagePreview(
          context: context,
          imageUrl: content,
          isSentByMe: isSentByMe,
        );
      case 'gif':
        return ChatRelatedWidget.buildGifPreview(
          context: context,
          imageUrl: content,
          isSentByMe: isSentByMe,
        );
      case 'sticker':
        return ChatRelatedWidget.buildGifPreview(
          context: context,
          imageUrl: content,
          isSentByMe: isSentByMe,
        );
      case 'video':
        return ChatRelatedWidget.buildVideoPreview(
          context: context,
          videoUrl: content,
          thumbnailUrl: thumbnail,
          isSentByMe: isSentByMe,
        );
      case 'document':
      case 'doc':
      case 'pdf':
        return ChatRelatedWidget.buildDocumentPreview(context, isSentByMe);
      case 'location':
        return ChatRelatedWidget.buildLocationPreview(context, isSentByMe);
      case 'contact':
        return ChatRelatedWidget.buildContactPreview(context, isSentByMe);
      case 'link':
        return ChatRelatedWidget.buildLinkPreview(
          context: context,
          content: content,
          isSentByMe: isSentByMe,
        );
      case 'text':
      default:
        return ChatRelatedWidget.buildTextPreview(
          context: context,
          content: content,
          isSentByMe: isSentByMe,
        );
    }
  }
}
