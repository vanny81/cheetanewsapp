import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/material.dart';
import 'package:whoxa/featuers/chat/services/giphy_api_service.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';

/// A bottom panel widget with three tabs: Emoji, GIF, and Sticker.
///
/// Designed to replace the soft keyboard when the emoji icon is tapped.
/// - Emoji tab: inserts emoji text into the [textController]
/// - GIF tab: calls [onGifSelected] with the selected GIF URL
/// - Sticker tab: calls [onStickerSelected] with the selected sticker URL
class EmojiGifStickerPanel extends StatefulWidget {
  final TextEditingController textController;
  final Function(String url) onGifSelected;
  final Function(String url) onStickerSelected;
  final int initialTab; // 0 = emoji, 1 = gif, 2 = sticker

  const EmojiGifStickerPanel({
    super.key,
    required this.textController,
    required this.onGifSelected,
    required this.onStickerSelected,
    this.initialTab = 0,
  });

  @override
  State<EmojiGifStickerPanel> createState() => _EmojiGifStickerPanelState();
}

class _EmojiGifStickerPanelState extends State<EmojiGifStickerPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: AppThemeManage.appTheme.darkGreyColor,
        border: Border(
          top: BorderSide(
            color: AppThemeManage.appTheme.borderColor,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        children: [
          // Tab bar
          Container(
            decoration: BoxDecoration(
              color: AppThemeManage.appTheme.darkGreyColor,
              border: Border(
                bottom: BorderSide(
                  color: AppThemeManage.appTheme.borderColor,
                  width: 0.5,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.appPriSecColor.primaryColor,
              indicatorWeight: 2.5,
              labelColor: AppColors.appPriSecColor.primaryColor,
              unselectedLabelColor: AppThemeManage.appTheme.textGreyblackGrey,
              labelStyle: AppTypography.innerText14(context).copyWith(
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: AppTypography.innerText14(context).copyWith(
                fontWeight: FontWeight.w400,
              ),
              tabs: const [
                Tab(
                  icon: Icon(Icons.emoji_emotions_outlined, size: 20),
                  text: 'Emoji',
                  height: 48,
                ),
                Tab(
                  icon: Icon(Icons.gif_box_outlined, size: 20),
                  text: 'GIF',
                  height: 48,
                ),
                Tab(
                  icon: Icon(Icons.sticky_note_2_outlined, size: 20),
                  text: 'Sticker',
                  height: 48,
                ),
              ],
            ),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Emoji tab
                _EmojiTab(textController: widget.textController),

                // GIF tab
                _GiphyGridTab(
                  type: 'gif',
                  onMediaSelected: widget.onGifSelected,
                ),

                // Sticker tab
                _GiphyGridTab(
                  type: 'sticker',
                  onMediaSelected: widget.onStickerSelected,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// EMOJI TAB
// ═══════════════════════════════════════════════════════════════════════════

class _EmojiTab extends StatelessWidget {
  final TextEditingController textController;

  const _EmojiTab({required this.textController});

  @override
  Widget build(BuildContext context) {
    return EmojiPicker(
      textEditingController: textController,
      onEmojiSelected: (category, emoji) {
        // emoji_picker_flutter handles insertion into textController automatically
      },
      config: Config(
        height: 220,
        checkPlatformCompatibility: true,
        emojiViewConfig: EmojiViewConfig(
          columns: 8,
          emojiSizeMax: 28 * (foundation.defaultTargetPlatform == TargetPlatform.iOS ? 1.2 : 1.0),
          backgroundColor: AppThemeManage.appTheme.darkGreyColor,
          noRecents: Text(
            'No recent emojis',
            style: TextStyle(
              fontSize: 16,
              color: AppThemeManage.appTheme.textGreyblackGrey,
            ),
          ),
        ),
        skinToneConfig: const SkinToneConfig(
          enabled: true,
          indicatorColor: Colors.grey,
        ),
        categoryViewConfig: CategoryViewConfig(
          indicatorColor: AppColors.appPriSecColor.primaryColor,
          iconColorSelected: AppColors.appPriSecColor.primaryColor,
          iconColor: AppThemeManage.appTheme.textGreyblackGrey,
          backgroundColor: AppThemeManage.appTheme.darkGreyColor,
          categoryIcons: const CategoryIcons(),
        ),
        bottomActionBarConfig: const BottomActionBarConfig(
          enabled: false, // We have our own text input
        ),
        searchViewConfig: SearchViewConfig(
          backgroundColor: AppThemeManage.appTheme.darkGreyColor,
          buttonIconColor: AppThemeManage.appTheme.textGreyblackGrey,
          hintText: 'Search emoji...',
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// GIF / STICKER TAB (shared implementation)
// ═══════════════════════════════════════════════════════════════════════════

class _GiphyGridTab extends StatefulWidget {
  final String type; // 'gif' or 'sticker'
  final Function(String url) onMediaSelected;

  const _GiphyGridTab({
    required this.type,
    required this.onMediaSelected,
  });

  @override
  State<_GiphyGridTab> createState() => _GiphyGridTabState();
}

class _GiphyGridTabState extends State<_GiphyGridTab>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  final GiphyApiService _giphyService = GiphyApiService();

  List<GiphyMedia> _mediaItems = [];
  bool _isLoading = true;
  String _errorMessage = '';
  Timer? _debounceTimer;

  @override
  bool get wantKeepAlive => true; // Preserve tab state when switching

  @override
  void initState() {
    super.initState();
    _loadTrending();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTrending() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final results = widget.type == 'gif'
        ? await _giphyService.getTrendingGifs()
        : await _giphyService.getTrendingStickers();

    if (!mounted) return;
    setState(() {
      _mediaItems = results;
      _isLoading = false;
      if (results.isEmpty && _giphyService.isRateLimited) {
        _errorMessage = 'GIFs are temporarily unavailable.\nPlease try again shortly.';
      }
    });
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final results = widget.type == 'gif'
        ? await _giphyService.searchGifs(query)
        : await _giphyService.searchStickers(query);

    if (!mounted) return;
    setState(() {
      _mediaItems = results;
      _isLoading = false;
      if (results.isEmpty && query.isNotEmpty && !_giphyService.isRateLimited) {
        _errorMessage = 'No ${widget.type}s found for "$query"';
      } else if (_giphyService.isRateLimited) {
        _errorMessage = 'Search is temporarily unavailable.\nPlease try again shortly.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: SizedBox(
            height: 38,
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: AppTypography.smallText(context).copyWith(
                color: AppThemeManage.appTheme.darkWhiteColor,
                fontSize: 13,
              ),
              decoration: InputDecoration(
                hintText: 'Search ${widget.type}s...',
                hintStyle: AppTypography.smallText(context).copyWith(
                  color: AppThemeManage.appTheme.textGreyblackGrey,
                  fontSize: 13,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  size: 18,
                  color: AppThemeManage.appTheme.textGreyblackGrey,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          _loadTrending();
                        },
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: AppThemeManage.appTheme.textGreyblackGrey,
                        ),
                      )
                    : null,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                filled: true,
                fillColor: AppThemeManage.appTheme.borderColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
              textInputAction: TextInputAction.search,
            ),
          ),
        ),

        // Rate limit warning banner
        if (_giphyService.isApproachingLimit && !_giphyService.isRateLimited)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            color: Colors.orange.withValues(alpha: 0.15),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 14, color: Colors.orange),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${_giphyService.remainingCalls} searches remaining this hour',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Content area
        Expanded(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    color: AppColors.appPriSecColor.primaryColor,
                    strokeWidth: 2,
                  ),
                )
              : _errorMessage.isNotEmpty && _mediaItems.isEmpty
                  ? _buildErrorState()
                  : _buildGrid(),
        ),

        // Giphy attribution
        Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            'Powered by GIPHY',
            style: TextStyle(
              fontSize: 10,
              color: AppThemeManage.appTheme.textGreyblackGrey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _giphyService.isRateLimited
                  ? Icons.timer_outlined
                  : Icons.search_off,
              size: 40,
              color: AppThemeManage.appTheme.textGreyblackGrey,
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppThemeManage.appTheme.textGreyblackGrey,
              ),
            ),
            if (_giphyService.isRateLimited) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _loadTrending,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry', style: TextStyle(fontSize: 13)),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.appPriSecColor.primaryColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(6),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.0,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: _mediaItems.length,
      itemBuilder: (context, index) {
        final media = _mediaItems[index];
        return GestureDetector(
          onTap: () => widget.onMediaSelected(media.url),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              decoration: BoxDecoration(
                color: AppThemeManage.appTheme.borderColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: CachedNetworkImage(
                imageUrl: media.previewUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: AppColors.appPriSecColor.primaryColor,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Center(
                  child: Icon(
                    widget.type == 'gif'
                        ? Icons.gif_box_outlined
                        : Icons.sticky_note_2_outlined,
                    size: 32,
                    color: AppThemeManage.appTheme.textGreyblackGrey,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
