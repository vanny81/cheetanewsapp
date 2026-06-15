import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:whoxa/featuers/auth/data/models/user_name_check_model.dart'
    as usernamecheck;
import 'package:whoxa/featuers/chat/data/models/chat_media_model.dart' as media;
import 'package:whoxa/featuers/chat/data/models/link_model.dart';
import 'package:whoxa/featuers/chat/provider/chat_provider.dart';
import 'package:whoxa/featuers/chat/repository/chat_repository.dart';
import 'package:whoxa/featuers/language_method/provider/language_provider.dart';
import 'package:whoxa/featuers/call/call_model.dart';
import 'package:whoxa/featuers/call/call_ui.dart';
import 'package:whoxa/featuers/profile/provider/profile_provider.dart';
import 'package:whoxa/featuers/provider/theme_provider.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_routes.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/widgets/custom_bottomsheet.dart';
import 'package:whoxa/widgets/global.dart';
import 'package:whoxa/featuers/report/widgets/report_user_dialog.dart';

class UserProfileViewBusiness extends StatefulWidget {
  final int userId;
  final int? chatId;
  final bool blockFlag;
  final String? chatName;

  const UserProfileViewBusiness({
    super.key,
    required this.userId,
    this.chatId,
    this.blockFlag = false,
    this.chatName,
  });

  @override
  State<UserProfileViewBusiness> createState() =>
      _UserProfileViewBusinessState();
}

class _UserProfileViewBusinessState extends State<UserProfileViewBusiness> {
  usernamecheck.UserNameCheckModel? _userProfile;
  bool _isLoading = true;
  // ignore: unused_field
  bool _isMediaLoading = false;
  String? _errorMessage;
  bool _blockStatusChanged = false;
  String? _cachedBlockScenario;
  // ignore: unused_field
  bool _isCurrentUserProfile = false;

  final ChatRepository _chatRepository = GetIt.instance<ChatRepository>();

  final bool _isClearingChat = false;

  final List<media.Records> _allMedia = [];
  List<media.Records> _images = [];
  List<media.Records> _videos = [];
  List<media.Records> _documents = [];
  List<media.Records> _links = [];
  late Future<Metadata> metadataFuture;

  // ignore: unused_field
  List<MediaSection> _sections = [];

  @override
  void initState() {
    super.initState();
    _initializeProfile();
    _performBackgroundBlockSync();
  }

  Future<void> _initializeProfile() async {
    await _checkIfCurrentUserProfile();
    await _loadUserProfile();

    // Only load media if chatId is provided
    if (widget.chatId != null) {
      _loadAllMedia();
    }
  }

  Future<void> _checkIfCurrentUserProfile() async {
    try {
      // For now, assume this is not current user profile since business users
      // typically view other business profiles
      _isCurrentUserProfile = false;
    } catch (e) {
      _isCurrentUserProfile = false;
    }
  }

  void _performBackgroundBlockSync() {
    Future.delayed(Duration(milliseconds: 1000), () async {
      if (mounted) {
        final chatProvider = Provider.of<ChatProvider>(context, listen: false);
        await chatProvider.syncBlockStatusOnForeground();
      }
    });
  }

  Future<void> _loadUserProfile() async {
    try {
      // Use find-user API for both current user and peer profiles
      final profileProvider = Provider.of<ProfileProvider>(
        context,
        listen: false,
      );
      final profile = await profileProvider.getPeerUserProfile(widget.userId);
      _userProfile = profile;

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load profile: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadAllMedia() async {
    setState(() {
      _isMediaLoading = true;
    });

    try {
      debugPrint(
        'Loading media with chatId: ${widget.chatId}, userId: ${widget.userId}',
      );

      final results = await Future.wait([
        _chatRepository.getChatMedia(chatId: widget.chatId!, type: 'media'),
        _chatRepository.getChatMedia(chatId: widget.chatId!, type: 'doc'),
        _chatRepository.getChatMedia(chatId: widget.chatId!, type: 'link'),
      ]);

      final mediaResponse = results[0];
      final docResponse = results[1];
      final linkResponse = results[2];

      // Debug: Check API responses
      debugPrint('UserProfileViewBusiness DEBUG:');
      debugPrint(
        'Media response: ${mediaResponse?.data?.records.length ?? 0} records',
      );
      debugPrint(
        'Doc response: ${docResponse?.data?.records.length ?? 0} records',
      );
      debugPrint(
        'Link response: ${linkResponse?.data?.records.length ?? 0} records',
      );

      setState(() {
        final mediaRecords = mediaResponse?.data?.records ?? [];
        _images = mediaRecords.where((m) => m.isImage || m.isGif).toList();
        _videos = mediaRecords.where((m) => m.isVideo).toList();
        _documents = docResponse?.data?.records ?? [];
        _links = linkResponse?.data?.records ?? [];

        debugPrint(
          'Processed: ${_images.length} images, ${_videos.length} videos, ${_documents.length} docs, ${_links.length} links',
        );

        _sections = [
          if (_images.isNotEmpty || _videos.isNotEmpty)
            MediaSection(title: "Media", items: [..._images, ..._videos]),
          if (_documents.isNotEmpty)
            MediaSection(title: "Documents", items: _documents),
          if (_links.isNotEmpty) MediaSection(title: "Links", items: _links),
        ];

        _isMediaLoading = false;
      });
    } catch (e) {
      setState(() {
        _isMediaLoading = false;
      });
      // Handle error gracefully - media section will show empty state
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingScreen();
    }

    if (_errorMessage != null || _userProfile == null) {
      return _buildErrorScreen();
    }

    final userRecord =
        _userProfile!.data?.records?.isNotEmpty == true
            ? _userProfile!.data!.records!.first
            : null;
    if (userRecord == null) {
      return _buildErrorScreen();
    }

    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _blockStatusChanged);
        return false;
      },
      child: Consumer2<ThemeProvider, LanguageProvider>(
        builder: (context, themeProvider, languageProvider, _) {
          return Scaffold(
            backgroundColor: AppThemeManage.appTheme.scaffoldBackColor,
            body: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    SingleChildScrollView(
                      child: Column(
                        children: [
                          // Business Header with Cover Image
                          _buildBusinessHeader(userRecord),

                          // Business Info Section
                          Transform.translate(
                            offset: Offset(
                              0,
                              -SizeConfig.height(5),
                            ), // Pull up slightly to overlap cover
                            child: _buildBusinessInfoCard(context, userRecord),
                          ),

                          // Catalog Section
                          _buildCatalogSection(),

                          SizedBox(height: SizeConfig.height(2)),

                          // Business Hours & Status
                          _buildBusinessHoursSection(userRecord),

                          SizedBox(height: SizeConfig.height(2)),

                          // Business Category & Description
                          _buildBusinessInfoSection(userRecord),

                          SizedBox(height: SizeConfig.height(2)),

                          // Business Account & Starred Messages
                          _buildBusinessAccountSection(userRecord),

                          SizedBox(height: SizeConfig.height(2)),

                          // Contact Information
                          _buildContactSection(userRecord),

                          SizedBox(height: SizeConfig.height(2)),

                          // Location with Map
                          _buildLocationSection(userRecord),

                          SizedBox(height: SizeConfig.height(2)),

                          // Office Profile Social Links
                          _buildSocialLinksSection(userRecord),

                          SizedBox(height: SizeConfig.height(2)),

                          // Media Links and Docs (only show if chat exists and is valid)
                          if (widget.chatId != null && widget.chatId! > 0)
                            _buildMediaLinksDocs(_allMedia),

                          SizedBox(height: SizeConfig.height(2)),

                          // Block/Report Business Actions
                          _buildBlockReportSection(userRecord),

                          SizedBox(height: SizeConfig.height(2)),
                        ],
                      ),
                    ),

                    if (_isClearingChat) _buildClearChatLoadingOverlay(),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildBusinessHeader(usernamecheck.Records userRecord) {
    return SizedBox(
      height: SizeConfig.height(25),
      child: Stack(
        children: [
          // Cover Image
          Positioned.fill(
            child:
                userRecord.bannerImage?.isNotEmpty == true
                    ? CachedNetworkImage(
                      imageUrl: userRecord.bannerImage!,
                      fit: BoxFit.cover,
                      errorWidget:
                          (context, url, error) => Container(
                            color: AppColors.appPriSecColor.primaryColor,
                          ),
                    )
                    : Container(color: AppColors.appPriSecColor.primaryColor),
          ),

          // Back button
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context, _blockStatusChanged),
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessHoursSection(usernamecheck.Records userRecord) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 15),
      child: Column(
        children: [
          // Business Hours Card
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  offset: Offset(0, 0),
                  blurRadius: 10,
                  spreadRadius: 0,
                  color: AppColors.shadowColor.c000000.withValues(alpha: 0.07),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Business Hours Header
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.appPriSecColor.primaryColor.withValues(
                          alpha: 0.1,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.access_time,
                        size: 16,
                        color: AppColors.appPriSecColor.primaryColor,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Business hours",
                        style: AppTypography.innerText14(context).copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppThemeManage.appTheme.textColor,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: AppColors.textColor.textDarkGray,
                    ),
                  ],
                ),

                SizedBox(height: 16),

                // Business Hours Content
                _buildBusinessHoursContent(userRecord),
              ],
            ),
          ),

          SizedBox(height: 8),

          // Business Category
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  offset: Offset(0, 0),
                  blurRadius: 10,
                  spreadRadius: 0,
                  color: AppColors.shadowColor.c000000.withValues(alpha: 0.07),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.appPriSecColor.primaryColor.withValues(
                      alpha: 0.1,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.category,
                    size: 16,
                    color: AppColors.appPriSecColor.primaryColor,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Business Category",
                        style: AppTypography.innerText14(context).copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppThemeManage.appTheme.textColor,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        _getBusinessCategory(userRecord),
                        style: AppTypography.innerText12Ragu(
                          context,
                        ).copyWith(color: AppColors.textColor.textDarkGray),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessHoursContent(usernamecheck.Records userRecord) {
    // Case 1: Appointments Only
    if (userRecord.byAppointmentsOnly == true ||
        userRecord.appointmentsOnly == true) {
      return Row(
        children: [
          Icon(
            Icons.event_available,
            size: 16,
            color: AppColors.appPriSecColor.primaryColor,
          ),
          SizedBox(width: 8),
          Text(
            "Appointments Only",
            style: AppTypography.innerText14(context).copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.appPriSecColor.primaryColor,
            ),
          ),
        ],
      );
    }

    // Case 2: Always Open
    if (userRecord.alwaysOpen == true) {
      return Column(children: _buildDaysOnly(userRecord.businessHours));
    }

    // Case 3: Normal Business Hours
    return Column(
      children: _buildBusinessHoursWithTimes(userRecord.businessHours),
    );
  }

  List<Widget> _buildDaysOnly(Map<String, dynamic>? businessHours) {
    final days = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];
    final dayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    List<Widget> widgets = [];

    for (int i = 0; i < days.length; i++) {
      final day = days[i];
      final dayName = dayNames[i];
      final isOpen = businessHours?.containsKey(day) == true;

      widgets.add(
        Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dayName,
                style: AppTypography.innerText12Ragu(
                  context,
                ).copyWith(color: AppThemeManage.appTheme.textColor),
              ),
              Text(
                isOpen ? "Open" : "Closed",
                style: AppTypography.innerText12Ragu(context).copyWith(
                  color: isOpen ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return widgets;
  }

  List<Widget> _buildBusinessHoursWithTimes(
    Map<String, dynamic>? businessHours,
  ) {
    final days = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];
    final dayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    List<Widget> widgets = [];

    for (int i = 0; i < days.length; i++) {
      final day = days[i];
      final dayName = dayNames[i];
      final hours = businessHours?[day] as String?;

      widgets.add(
        Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dayName,
                style: AppTypography.innerText12Ragu(
                  context,
                ).copyWith(color: AppThemeManage.appTheme.textColor),
              ),
              Text(
                _formatBusinessHours(hours),
                style: AppTypography.innerText12Ragu(context).copyWith(
                  color: _getBusinessHoursColor(hours),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return widgets;
  }

  String _formatBusinessHours(String? hours) {
    if (hours == null || hours.isEmpty) {
      return "Closed";
    }

    // Convert "10:00to22:00" to "10:00 am to 10:00 pm"
    if (hours.contains('to')) {
      final parts = hours.split('to');
      if (parts.length == 2) {
        final startTime = _formatTime(parts[0].trim());
        final endTime = _formatTime(parts[1].trim());
        return "$startTime to $endTime";
      }
    }

    return hours;
  }

  String _formatTime(String time) {
    try {
      // Parse "10:00" format
      final parts = time.split(':');
      if (parts.length == 2) {
        final hour = int.parse(parts[0]);
        final minute = parts[1];

        if (hour == 0) {
          return "12:$minute am";
        } else if (hour < 12) {
          return "$hour:$minute am";
        } else if (hour == 12) {
          return "12:$minute pm";
        } else {
          return "${hour - 12}:$minute pm";
        }
      }
    } catch (e) {
      // Return original if parsing fails
    }

    return time;
  }

  Color _getBusinessHoursColor(String? hours) {
    if (hours == null || hours.isEmpty || hours.toLowerCase() == 'closed') {
      return Colors.red;
    }
    return AppThemeManage.appTheme.textColor;
  }

  String _getBusinessCategory(usernamecheck.Records userRecord) {
    // Try to get category from the API response
    if (userRecord.categories != null &&
        userRecord.categories!['name'] != null) {
      return userRecord.categories!['name'] as String;
    }
    return "Business"; // Default fallback
  }

  String _formatJoinDate(String? createdAt) {
    if (createdAt == null || createdAt.isEmpty) {
      return "Joined recently";
    }

    try {
      final DateTime joinDate = DateTime.parse(createdAt);
      final List<String> months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];

      final String month = months[joinDate.month - 1];
      final String year = joinDate.year.toString();

      return "Joined in $month $year";
    } catch (e) {
      return "Joined recently";
    }
  }

  Widget _buildBusinessInfoSection(usernamecheck.Records userRecord) {
    final description = userRecord.description ?? "Available";
    final bool shouldShowReadMore = _shouldShowReadMore(description);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 15),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              offset: Offset(0, 0),
              blurRadius: 10,
              spreadRadius: 0,
              color: AppColors.shadowColor.c000000.withValues(alpha: 0.07),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Description Section Header
            Text(
              "Description",
              style: AppTypography.innerText16(context).copyWith(
                fontWeight: FontWeight.w600,
                color: AppThemeManage.appTheme.textColor,
              ),
            ),

            SizedBox(height: 8),

            // Description Content
            Text(
              description,
              style: AppTypography.innerText12Ragu(
                context,
              ).copyWith(color: AppColors.textColor.textDarkGray, height: 1.4),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // Read More Button (only show if text is longer than 2 lines)
            if (shouldShowReadMore) ...[
              SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  // Read More functionality - can expand description
                  _showFullDescription(context, description);
                },
                child: Text(
                  "Read More",
                  style: AppTypography.innerText12Ragu(context).copyWith(
                    color: AppColors.appPriSecColor.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],

            if (userRecord.bio?.isNotEmpty == true) ...[
              SizedBox(height: 16),
              // Bio Section (busy text with date)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    userRecord.bio ?? "Busy",
                    style: AppTypography.innerText14(context).copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppThemeManage.appTheme.textColor,
                    ),
                  ),
                  Text(
                    "May 23, 2024", // Can be dynamic based on userRecord data
                    style: AppTypography.innerText12Ragu(
                      context,
                    ).copyWith(color: AppColors.textColor.textDarkGray),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessAccountSection(usernamecheck.Records userRecord) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 15),
      child: Column(
        children: [
          // Business Account
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  offset: Offset(0, 0),
                  blurRadius: 10,
                  spreadRadius: 0,
                  color: AppColors.shadowColor.c000000.withValues(alpha: 0.07),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.appPriSecColor.primaryColor.withValues(
                      alpha: 0.1,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.business,
                    size: 16,
                    color: AppColors.appPriSecColor.primaryColor,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Business Account",
                        style: AppTypography.innerText14(context).copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppThemeManage.appTheme.textColor,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        "This account uses CheetaNews Business - ${_formatJoinDate(userRecord.createdAt)}",
                        style: AppTypography.innerText12Ragu(
                          context,
                        ).copyWith(color: AppColors.textColor.textDarkGray),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: AppColors.textColor.textDarkGray,
                ),
              ],
            ),
          ),

          // Only show starred messages if chat exists and is valid
          if (widget.chatId != null && widget.chatId! > 0) ...[
            SizedBox(height: 8),

            // Starred Message
            GestureDetector(
              onTap: () {
                // Navigate to StarredMessagesScreen for this specific chat
                Navigator.pushNamed(
                  context,
                  AppRoutes.starredMessages,
                  arguments: {
                    'chatId': widget.chatId,
                    'chatName': widget.chatName,
                  },
                );
              },
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      offset: Offset(0, 0),
                      blurRadius: 10,
                      spreadRadius: 0,
                      color: AppColors.shadowColor.c000000.withValues(
                        alpha: 0.07,
                      ),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.appPriSecColor.primaryColor.withValues(
                          alpha: 0.1,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.star,
                        size: 16,
                        color: AppColors.appPriSecColor.primaryColor,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Starred Message",
                        style: AppTypography.innerText14(context).copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppThemeManage.appTheme.textColor,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: AppColors.textColor.textDarkGray,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContactSection(usernamecheck.Records userRecord) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 15),
      child: Column(
        children: [
          if (userRecord.email?.isNotEmpty == true)
            GestureDetector(
              onTap: () => _launchEmail(userRecord.email!),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      offset: Offset(0, 0),
                      blurRadius: 10,
                      spreadRadius: 0,
                      color: AppColors.shadowColor.c000000.withValues(
                        alpha: 0.07,
                      ),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.appPriSecColor.primaryColor.withValues(
                          alpha: 0.1,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.email,
                        size: 16,
                        color: AppColors.appPriSecColor.primaryColor,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        userRecord.email!,
                        style: AppTypography.innerText14(context).copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppThemeManage.appTheme.textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (userRecord.email?.isNotEmpty == true &&
              userRecord.website?.isNotEmpty == true)
            SizedBox(height: 8),
          if (userRecord.website?.isNotEmpty == true)
            GestureDetector(
              onTap: () => _launchWebsite(userRecord.website!),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      offset: Offset(0, 0),
                      blurRadius: 10,
                      spreadRadius: 0,
                      color: AppColors.shadowColor.c000000.withValues(
                        alpha: 0.07,
                      ),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.appPriSecColor.primaryColor.withValues(
                          alpha: 0.1,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.language,
                        color: AppColors.appPriSecColor.primaryColor,
                        size: 16,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        userRecord.website!,
                        style: AppTypography.innerText14(context).copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppThemeManage.appTheme.textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLocationSection(usernamecheck.Records userRecord) {
    if (userRecord.location?.isEmpty == true) return SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 15),
      child: GestureDetector(
        onTap: () => _launchMaps(userRecord),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                offset: Offset(0, 0),
                blurRadius: 10,
                spreadRadius: 0,
                color: AppColors.shadowColor.c000000.withValues(alpha: 0.07),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Location Header inside card
              Padding(
                padding: SizeConfig.getPaddingSymmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Location",
                      style: AppTypography.innerText16(context).copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppThemeManage.appTheme.textColor,
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: AppColors.textColor.textDarkGray,
                    ),
                  ],
                ),
              ),

              // Map Container
              SizedBox(
                width: double.infinity,
                height: 140,
                child: ClipRRect(
                  borderRadius: BorderRadius.zero,
                  child: _buildMapWidget(userRecord),
                ),
              ),

              // Location Address at bottom
              Padding(
                padding: SizeConfig.getPaddingSymmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.appPriSecColor.primaryColor.withValues(
                          alpha: 0.1,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.location_on,
                        size: 16,
                        color: AppColors.appPriSecColor.primaryColor,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        userRecord.location ?? "",
                        style: AppTypography.innerText14(context).copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppThemeManage.appTheme.textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapWidget(usernamecheck.Records userRecord) {
    final lat = userRecord.latitude;
    final lng = userRecord.longitude;

    // Check if coordinates are available
    if (lat != null && lng != null) {
      final LatLng businessLocation = LatLng(lat, lng);

      return Padding(
        padding: SizeConfig.getPadding(10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 150,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: businessLocation,
                zoom: 15.0,
              ),
              markers: {
                Marker(
                  markerId: MarkerId('business_location'),
                  position: businessLocation,
                  infoWindow: InfoWindow(
                    title: userRecord.fullName ?? 'Business Location',
                    snippet: userRecord.location ?? 'Business Address',
                  ),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueRed,
                  ),
                ),
              },
              mapType: MapType.normal,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              compassEnabled: false,
              mapToolbarEnabled: false,
              tiltGesturesEnabled: false,
              rotateGesturesEnabled: false,
              scrollGesturesEnabled: true,
              zoomGesturesEnabled: true,
              onMapCreated: (GoogleMapController controller) {
                // Map created callback
              },
            ),
          ),
        ),
      );
    } else {
      return _buildMapNotAvailable();
    }
  }

  Widget _buildMapNotAvailable() {
    return Container(
      color: Colors.grey[300],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined, size: 40, color: Colors.grey[600]),
            SizedBox(height: 8),
            Text(
              "Map not available",
              style: AppTypography.innerText12Ragu(
                context,
              ).copyWith(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCatalogSection() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 15),
      child: container(
        context,
        radius: 10,
        boxShadow: [
          BoxShadow(
            offset: Offset(0, 0),
            blurRadius: 10,
            spreadRadius: 0,
            color: AppColors.shadowColor.c000000.withValues(alpha: 0.07),
          ),
        ],
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Catalogue",
                    style: AppTypography.innerText16(
                      context,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                  GestureDetector(
                    onTap: () {
                      // Static for now - See all functionality
                    },
                    child: Row(
                      children: [
                        Text(
                          "See all",
                          style: AppTypography.innerText12Ragu(
                            context,
                          ).copyWith(color: AppColors.textColor.textDarkGray),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 12,
                          color: AppColors.textColor.textDarkGray,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Catalog placeholder
            SizedBox(
              height: 120,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    "No catalog items available",
                    style: AppTypography.innerText12Ragu(
                      context,
                    ).copyWith(color: AppColors.textColor.textDarkGray),
                  ),
                ),
              ),
            ),
            SizedBox(height: 15),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialLinksSection(usernamecheck.Records userRecord) {
    final socialLinks = _getSocialLinks(userRecord);

    if (socialLinks.isEmpty) {
      return SizedBox.shrink(); // Don't show section if no social links
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 15),
      child: Column(
        children: [
          for (int i = 0; i < socialLinks.length; i++) ...[
            GestureDetector(
              onTap: () => _launchUrl(socialLinks[i]['url']!),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      offset: Offset(0, 0),
                      blurRadius: 10,
                      spreadRadius: 0,
                      color: AppColors.shadowColor.c000000.withValues(
                        alpha: 0.07,
                      ),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: socialLinks[i]['color'].withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        socialLinks[i]['icon'],
                        size: 16,
                        color: socialLinks[i]['color'],
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            socialLinks[i]['name']!,
                            style: AppTypography.innerText14(context).copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppThemeManage.appTheme.textColor,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            socialLinks[i]['url']!,
                            style: AppTypography.innerText12Ragu(
                              context,
                            ).copyWith(color: AppColors.textColor.textDarkGray),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (i < socialLinks.length - 1) SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getSocialLinks(usernamecheck.Records userRecord) {
    List<Map<String, dynamic>> links = [];

    if (userRecord.facebookLink?.isNotEmpty == true) {
      links.add({
        'name': 'Facebook',
        'url': userRecord.facebookLink!,
        'icon': Icons.facebook,
        'color': Color(0xFF1877F2), // Facebook blue
      });
    }

    if (userRecord.youtubeLink?.isNotEmpty == true) {
      links.add({
        'name': 'YouTube',
        'url': userRecord.youtubeLink!,
        'icon': Icons.play_circle_filled,
        'color': Color(0xFFFF0000), // YouTube red
      });
    }

    if (userRecord.linkedinLink?.isNotEmpty == true) {
      links.add({
        'name': 'LinkedIn',
        'url': userRecord.linkedinLink!,
        'icon': Icons.business,
        'color': Color(0xFF0A66C2), // LinkedIn blue
      });
    }

    if (userRecord.vkLink?.isNotEmpty == true) {
      links.add({
        'name': 'VK',
        'url': userRecord.vkLink!,
        'icon': Icons.group,
        'color': Color(0xFF0077FF), // VK blue
      });
    }

    return links;
  }

  Widget _buildBlockReportSection(usernamecheck.Records userRecord) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        // Get cached state first, then provider state for real-time updates
        String blockScenario = _cachedBlockScenario ?? 'none';
        if (_blockStatusChanged) {
          // Use provider state for real-time updates after initial load
          blockScenario = chatProvider.getBlockScenario(
            widget.chatId,
            widget.userId,
          );
          // Update cache when provider state changes
          _cachedBlockScenario = blockScenario;
        }

        // Show unblock if current user has blocked the other user (either alone or mutual)
        final showUnblockOption =
            blockScenario == 'user_blocked_other' ||
            blockScenario == 'mutual_block';

        return LayoutBuilder(
          builder: (context, constraints) {
            double screenWidth = MediaQuery.of(context).size.width;

            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth < 360 ? 10 : 15,
              ),
              child: container(
                context,
                radius: screenWidth < 360 ? 8 : 10,
                boxShadow: [
                  BoxShadow(
                    offset: Offset(0, 0),
                    blurRadius: screenWidth < 360 ? 8 : 10,
                    spreadRadius: 0,
                    color: AppColors.shadowColor.c000000.withValues(
                      alpha: 0.07,
                    ),
                  ),
                ],
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.all(screenWidth < 360 ? 15 : 20),
                      child: rowIconWithRedText(
                        context: context,
                        color: AppColors.appPriSecColor.secondaryRed,
                        onTap: () {
                          _showEnhancedBlockDialog(
                            chatProvider,
                            showUnblockOption,
                            userRecord,
                          );
                        },
                        svgImage: AppAssets.groupProfielIcons.userBock,
                        title:
                            "${showUnblockOption ? AppString.geoupProfileString.unBlock : AppString.geoupProfileString.block} ${userRecord.fullName ?? 'Business'}",
                      ),
                    ),
                    Container(
                      height: 1,
                      width: SizeConfig.screenWidth,
                      color: AppThemeManage.appTheme.borderColor,
                    ),
                    Padding(
                      padding: EdgeInsets.all(screenWidth < 360 ? 15 : 20),
                      child: rowIconWithRedText(
                        context: context,
                        color: AppColors.appPriSecColor.secondaryRed,
                        onTap: () {
                          final displayName = userRecord.fullName ?? 'Business';
                          showReportUserDialog(
                            context,
                            userId: widget.userId,
                            userName: displayName,
                          );
                        },
                        svgImage: AppAssets.svgIcons.report,
                        title:
                            "${AppString.geoupProfileString.report} ${userRecord.fullName ?? 'Business'}",
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Media, Links and Docs section with consistent styling
  Widget _buildMediaLinksDocs(List<media.Records> mediaList) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 15),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              offset: Offset(0, 0),
              blurRadius: 10,
              spreadRadius: 0,
              color: AppColors.shadowColor.c000000.withValues(alpha: 0.07),
            ),
          ],
        ),
        child: Column(
          children: [
            SizedBox(height: SizeConfig.height(2)),
            InkWell(
              onTap: () {
                Navigator.pushNamed(
                  context,
                  AppRoutes.chatMedia,
                  arguments: {
                    'chatId': widget.chatId,
                    'chatName': widget.chatName,
                  },
                );
              },
              child: Padding(
                padding: SizeConfig.getPaddingSymmetric(horizontal: 15),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppString.geoupProfileString.mediaLinkandDocs,
                      style: AppTypography.innerText12Mediu(context).copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppThemeManage.appTheme.chatMediaText,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          (_images.length +
                                  _videos.length +
                                  _documents.length +
                                  _links.length)
                              .toString(),
                          style: AppTypography.innerText12Mediu(
                            context,
                          ).copyWith(
                            color: AppThemeManage.appTheme.chatMediaText,
                          ),
                        ),
                        SizedBox(width: SizeConfig.width(3)),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 10,
                          color: AppThemeManage.appTheme.chatMediaText,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: SizeConfig.height(2)),
            SizedBox(
              height: SizeConfig.sizedBoxHeight(90),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.folder_open,
                      size: 48,
                      color: AppColors.textColor.textGreyColor,
                    ),
                    SizedBox(height: 16),
                    Text(
                      AppString.noMediainThisCategory,
                      style: AppTypography.mediumText(
                        context,
                      ).copyWith(color: AppColors.textColor.textGreyColor),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: SizeConfig.height(2)),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _blockStatusChanged);
        return false;
      },
      child: Scaffold(
        backgroundColor: AppThemeManage.appTheme.scaffoldBackColor,
        body: Column(
          children: [
            Container(
              height: SizeConfig.height(25),
              color: AppColors.appPriSecColor.primaryColor,
              child: Stack(
                children: [
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 16,
                    left: 16,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context, _blockStatusChanged),
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: SizeConfig.height(30)),
            Center(child: commonLoading()),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _blockStatusChanged);
        return false;
      },
      child: Scaffold(
        backgroundColor: AppThemeManage.appTheme.scaffoldBackColor,
        body: Column(
          children: [
            Container(
              height: SizeConfig.height(25),
              color: AppColors.appPriSecColor.primaryColor,
              child: Stack(
                children: [
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 16,
                    left: 16,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context, _blockStatusChanged),
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: SizeConfig.height(20)),
            Center(
              child: Padding(
                padding: SizeConfig.getPaddingSymmetric(horizontal: 30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: AppColors.textColor.textErrorColor1,
                    ),
                    SizedBox(height: SizeConfig.height(2)),
                    Text(
                      _errorMessage ?? 'Business profile not found',
                      style: AppTypography.h5(context),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: SizeConfig.height(3)),
                    customBtn(
                      context,
                      title: "Retry",
                      onTap: () {
                        setState(() {
                          _isLoading = true;
                          _errorMessage = null;
                        });
                        _loadUserProfile();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClearChatLoadingOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.appPriSecColor.primaryColor,
                ),
              ),
              SizedBox(height: SizeConfig.height(2)),
              Text(
                'Clearing chat...',
                style: AppTypography.innerText16(
                  context,
                ).copyWith(color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to check if Read More should be shown
  bool _shouldShowReadMore(String text) {
    // Estimate if text would take more than 2 lines
    // This is a rough estimation based on character count and typical line length
    const int averageCharsPerLine =
        45; // Approximate characters per line on mobile
    const int maxLines = 2;
    return text.length > (averageCharsPerLine * maxLines);
  }

  // Helper method to show full description in a dialog
  void _showFullDescription(BuildContext context, String description) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            "Description",
            style: AppTypography.innerText16(context).copyWith(
              fontWeight: FontWeight.w600,
              color: AppThemeManage.appTheme.textColor,
            ),
          ),
          content: SingleChildScrollView(
            child: Text(
              description,
              style: AppTypography.innerText12Ragu(
                context,
              ).copyWith(color: AppColors.textColor.textDarkGray, height: 1.4),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                "Close",
                style: TextStyle(
                  color: AppColors.appPriSecColor.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Enhanced block dialog with consistent display names
  void _showEnhancedBlockDialog(
    ChatProvider chatProvider,
    bool isCurrentlyBlocked,
    usernamecheck.Records userRecord,
  ) {
    // Get consistent display name for dialog
    final displayName = userRecord.fullName ?? 'Business';

    bottomSheetGobalWithoutTitle(
      context,
      bottomsheetHeight: SizeConfig.safeHeight(28),
      borderRadius: BorderRadius.circular(20),
      alignment: Alignment.bottomCenter,
      isCrossIconHide: true,
      child: Padding(
        padding: SizeConfig.getPaddingSymmetric(horizontal: 25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: SizeConfig.height(2)),
            Text(
              "${isCurrentlyBlocked ? AppString.homeScreenString.areYouSureUnblock : AppString.homeScreenString.areYouSureBlock} $displayName?",
              textAlign: TextAlign.start,
              style: AppTypography.captionText(context).copyWith(
                fontSize: SizeConfig.getFontSize(15),
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: SizeConfig.height(1.5)),
            Text(
              isCurrentlyBlocked
                  ? '${AppString.homeScreenString.areYouSureUnblock} $displayName?'
                  : '${AppString.homeScreenString.areYouSureBlock} $displayName?',
              textAlign: TextAlign.start,
              style: AppTypography.captionText(context).copyWith(
                color: AppColors.textColor.textGreyColor,
                fontSize: SizeConfig.getFontSize(13),
              ),
            ),
            SizedBox(height: SizeConfig.height(3)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                SizedBox(
                  height: SizeConfig.height(5),
                  width: SizeConfig.width(35),
                  child: customBtn2(
                    context,
                    onTap: () async {
                      Navigator.pop(context);

                      // Call the block/unblock API
                      final success = await chatProvider.blockUnblockUser(
                        widget.userId,
                        widget.chatId ?? 0,
                      );

                      if (mounted) {
                        if (success) {
                          // Mark that block status changed and update cached state based on provider
                          setState(() {
                            _blockStatusChanged = true;
                            // Get the actual current state from provider after API call
                            _cachedBlockScenario = chatProvider
                                .getBlockScenario(widget.chatId, widget.userId);
                          });

                          // Only refresh blocked users list, don't refresh chat list immediately
                          // to preserve the instant UI updates made by blockUnblockUser
                          await chatProvider.refreshBlockStatus();

                          // Safely show snackbar
                          try {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isCurrentlyBlocked
                                      ? '$displayName ${AppString.blockUserStrings.hasBeenUnblocked}'
                                      : '$displayName ${AppString.blockUserStrings.hasBeenBlocked}',
                                ),
                                backgroundColor:
                                    isCurrentlyBlocked
                                        ? Colors.green
                                        : Colors.orange,
                              ),
                            );
                          } catch (e) {
                            // If context is deactivated, just log the success
                            debugPrint(
                              'UserProfileViewBusiness: Block/unblock successful but cannot show snackbar - context deactivated',
                            );
                          }
                        } else {
                          // Safely show error snackbar
                          try {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${AppString.blockUserStrings.failedto} ${isCurrentlyBlocked ? AppString.blockUserStrings.unblockS : AppString.blockUserStrings.blockS} $displayName. ${AppString.pleaseTryAgain}',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          } catch (e) {
                            // If context is deactivated, just log the error
                            debugPrint(
                              'UserProfileViewBusiness: Block/unblock failed but cannot show snackbar - context deactivated',
                            );
                          }
                        }
                      }
                    },
                    child: Text(
                      isCurrentlyBlocked
                          ? AppString.homeScreenString.unblock
                          : AppString.homeScreenString.block,
                      style: AppTypography.h5(context).copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textColor.textBlackColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods for launching URLs
  Future<void> _launchEmail(String email) async {
    final Uri emailUri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not launch email app'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _launchWebsite(String website) async {
    String url = website;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }

    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not launch website'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _launchMaps(usernamecheck.Records userRecord) async {
    final lat = userRecord.latitude;
    final lng = userRecord.longitude;
    final address = userRecord.location;

    Uri? mapUri;

    // Try to use coordinates if available
    if (lat != null && lng != null) {
      mapUri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
      );
    }
    // Fall back to address search
    else if (address?.isNotEmpty == true) {
      final encodedAddress = Uri.encodeComponent(address!);
      mapUri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$encodedAddress',
      );
    }

    if (mapUri != null && await canLaunchUrl(mapUri)) {
      await launchUrl(mapUri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open maps'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _launchUrl(String url) async {
    String finalUrl = url;
    if (!finalUrl.startsWith('http://') && !finalUrl.startsWith('https://')) {
      finalUrl = 'https://$finalUrl';
    }

    final Uri uri = Uri.parse(finalUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open URL'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Business Info methods
  Widget _buildBusinessInfoCard(
    BuildContext context,
    usernamecheck.Records userRecord,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: SizeConfig.width(5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Business Logo - will be half on cover, half on card
          _buildBusinessLogo(userRecord),

          SizedBox(height: SizeConfig.height(1.5)),

          // Business Name and Info
          _buildBusinessDetails(context, userRecord),

          SizedBox(height: SizeConfig.height(2.5)),

          // Action Buttons Row
          Container(child: _buildActionButtons(context, userRecord)),
        ],
      ),
    );
  }

  Widget _buildBusinessLogo(usernamecheck.Records userRecord) {
    return Container(
      height: 100,
      width: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child:
            userRecord.profilePic?.isNotEmpty == true
                ? CachedNetworkImage(
                  imageUrl: userRecord.profilePic!,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) {
                    return _buildDefaultLogo(userRecord);
                  },
                )
                : _buildDefaultLogo(userRecord),
      ),
    );
  }

  Widget _buildDefaultLogo(usernamecheck.Records userRecord) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.appPriSecColor.primaryColor,
      ),
      child: Center(
        child: Text(
          userRecord.fullName?.isNotEmpty == true
              ? userRecord.fullName![0].toUpperCase()
              : 'B',
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildBusinessDetails(
    BuildContext context,
    usernamecheck.Records userRecord,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Business Name
        Text(
          userRecord.fullName ?? 'Business Name',
          style: AppTypography.h4(context).copyWith(
            fontWeight: FontWeight.w600,
            color: AppThemeManage.appTheme.textColor,
          ),
          textAlign: TextAlign.center,
        ),

        SizedBox(height: 4),

        // Verification Badge and Phone
        if (userRecord.mobileNum?.isNotEmpty == true)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (userRecord.profileVerificationStatus == true) ...[
                Icon(Icons.verified, size: 16, color: Colors.blue),
                SizedBox(width: 4),
              ],
              Text(
                "${userRecord.countryCode ?? ''}${userRecord.mobileNum}",
                style: AppTypography.innerText12Ragu(
                  context,
                ).copyWith(color: AppColors.textColor.textDarkGray),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    usernamecheck.Records userRecord,
  ) {
    // Show call and search buttons for business profiles
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Audio Call Button
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: SizeConfig.width(2)),
            child: rowAudioVideoSearchContainer(
              context: context,
              onTap: () {
                if (widget.chatId != null) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder:
                          (_) => CallScreen(
                            chatId: widget.chatId!,
                            chatName: widget.chatName!,
                            callType: CallType.audio,
                            isIncoming: false,
                          ),
                      fullscreenDialog: true,
                    ),
                  );
                }
              },
              title: "Audio Call",
              svgImage: AppAssets.bottomNavIcons.call1,
            ),
          ),
        ),

        // Video Call Button
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: SizeConfig.width(2)),
            child: rowAudioVideoSearchContainer(
              context: context,
              onTap: () {
                if (widget.chatId != null) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder:
                          (_) => CallScreen(
                            chatId: widget.chatId!,
                            chatName: widget.chatName!,
                            callType: CallType.video,
                            isIncoming: false,
                          ),
                      fullscreenDialog: true,
                    ),
                  );
                }
              },
              title: "Video Call",
              svgImage: AppAssets.chatMsgTypeIcon.videoMsg,
            ),
          ),
        ),

        // Search Button
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: SizeConfig.width(2)),
            child: rowAudioVideoSearchContainer(
              context: context,
              onTap: () {
                Navigator.pop(context, "search");
              },
              title: "Search",
              svgImage: AppAssets.homeIcons.search,
            ),
          ),
        ),
      ],
    );
  }
}

class MediaSection {
  final String title;
  final List<media.Records> items;

  MediaSection({required this.title, required this.items});
}
