// ignore_for_file: deprecated_member_use, depend_on_referenced_packages, unnecessary_underscores

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:light_compressor/light_compressor.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:whoxa/core/error/app_error.dart';
import 'package:whoxa/featuers/story/data/story_upload_repo.dart';
import 'package:whoxa/featuers/story/data/model/get_all_story_model.dart';
import 'package:whoxa/featuers/story/data/model/model.dart';
import 'package:whoxa/featuers/story/data/model/viewed_user_list_model.dart';
import 'package:whoxa/utils/logger.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:whoxa/utils/packages/story/src/models/story_view_image_config.dart';
import 'package:whoxa/utils/packages/story/src/models/story_view_video_config.dart';
import 'package:whoxa/utils/packages/story/src/utils/story_utils.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:video_trimmer/video_trimmer.dart';
import 'package:whoxa/widgets/global.dart';

class StoryProvider extends ChangeNotifier {
  final ConsoleAppLogger _logger = ConsoleAppLogger();

  final TextEditingController typeMessageCtrl = TextEditingController();

  File? image;
  final picker = ImagePicker();

  void notify() {
    notifyListeners();
  }

  // List<CameraDescription> cameras = [];
  // late CameraController cameraController;
  // bool isRecording = false;
  // bool isVideoMode = false;

  // Future<void> initCamera() async {
  //   cameras = await availableCameras();
  //   cameraController = CameraController(cameras[0], ResolutionPreset.high);
  //   await cameraController.initialize();
  //   notify();
  // }

  // Future<void> capturePhoto() async {
  //   final image = await cameraController.takePicture();
  //   _logger.i("Image saved at: ${image.path}");
  //   // Show preview or upload
  // }

  // Future<void> handleVideo() async {
  //   if (isRecording) {
  //     final file = await cameraController.stopVideoRecording();
  //     isRecording = false;
  //     notify();
  //     stopTimer();
  //     _logger.i("Video saved at: ${file.path}");
  //   } else {
  //     await cameraController.prepareForVideoRecording();
  //     await cameraController.startVideoRecording();
  //     isRecording = false;
  //     recordDuration = 0;
  //     notify();
  //     startTimer();
  //   }
  // }

  // Timer? _timer;
  // int recordDuration = 0;

  // void startTimer() {
  //   _timer = Timer.periodic(Duration(seconds: 1), (_) {
  //     recordDuration++;
  //     notify();
  //   });
  // }

  // void stopTimer() {
  //   _timer?.cancel();
  // }

  // String formatDuration(int seconds) {
  //   final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
  //   final secs = (seconds % 60).toString().padLeft(2, '0');
  //   return '$minutes:$secs';
  // }

  Future getImageFromGallery() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      image = File(pickedFile.path);
      notify();
    } else {
      debugPrint('No image selected.');
    }
  }

  File? selectedMediaFile;
  String? selectedMediaType; // 'image' or 'video'

  void setPickedMedia(File file, String type) {
    selectedMediaFile = file;
    selectedMediaType = type;
    notifyListeners();
  }

  final Trimmer trimmer = Trimmer();

  List compressedVideos = [];
  File? video;
  String? filePath;
  Future<void> getImageFromGallery1(BuildContext context) async {
    FilePickerResult? pickedFile = await FilePicker.pickFiles(
      type: FileType.custom,
      allowMultiple: false,
      allowedExtensions: [
        'jpg', 'jpeg', 'png', 'webp', 'gif', // images
        'mp4', 'mov', 'avi', 'hevc', 'h.264', 'mkv', // videos
      ],
    );

    if (pickedFile != null) {
      File selectedFile = File(pickedFile.files.single.path!);
      String ext = pickedFile.files.single.extension?.toLowerCase() ?? '';
      int sizeInBytes = selectedFile.lengthSync();

      // Check if it's an image
      if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) {
        if (sizeInBytes > 10 * 1024 * 1024) {
          if (!context.mounted) return;
          snackbarNew(context, msg: "Image size should be less than 10MB");
          return;
        }

        // Compress image
        final dir = await getTemporaryDirectory();
        final targetPath =
            "${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg";

        final compressedImage = await FlutterImageCompress.compressAndGetFile(
          selectedFile.path,
          targetPath,
          quality: 50,
        );

        if (compressedImage != null) {
          _logger.i("Image compressed path: ${compressedImage.path}");
          setPickedMedia(File(compressedImage.path), 'image');
        }
      }
      // Check if it's a video
      else if (['mp4', 'mov', 'avi', 'hevc', 'h.264', 'mkv'].contains(ext)) {
        if (sizeInBytes > 200 * 1024 * 1024) {
          if (!context.mounted) return;
          snackbarNew(context, msg: "Video size should be less than 100MB");
          return;
        }

        _logger.i("Video selected: ${selectedFile.path}");
        filePath = selectedFile.path;
        video = selectedFile;

        /// 👉 Show loader before compression
        if (!context.mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => Center(child: commonLoading()),
        );

        /// 👈 Close loader after compression
        if (!context.mounted) return;
        Navigator.pop(context);

        setPickedMedia(selectedFile, 'video');
      }
      // Unsupported type
      else {
        if (!context.mounted) return;
        snackbarNew(context, msg: "Unsupported file type selected");
      }
    }
  }

  String compressedVideoPath = '';

  Future<void> compressVideo(dynamic file) async {
    if (video == null || file == null) {
      _logger.e("Video or filePath is null — skipping compression");
      return;
    }

    int fileSizeInBytes = video!.lengthSync();
    double fileSizeInMB = fileSizeInBytes / (1024 * 1024);
    _logger.i('Original File Size: $fileSizeInMB MB');

    if (fileSizeInMB > 50.0) {
      final lightCompressor = LightCompressor();
      final Result response = await lightCompressor.compressVideo(
        path: file!,
        videoQuality: VideoQuality.very_high,
        isMinBitrateCheckEnabled: false,
        video: Video(videoName: path.basename(file!)),
        android: AndroidConfig(isSharedStorage: false, saveAt: SaveAt.Movies),
        ios: IOSConfig(saveInGallery: false),
      );

      if (response is OnSuccess) {
        compressedVideoPath = response.destinationPath;
        _logger.i("😀Video compressed to: $compressedVideoPath");
      } else if (response is OnFailure) {
        _logger.e("😀Compression failed: ${response.message}");
        compressedVideoPath = video!.absolute.path;
      } else if (response is OnCancelled) {
        _logger.w("😀Compression cancelled");
        compressedVideoPath = video!.absolute.path;
      }
    } else {
      // No compression needed
      compressedVideoPath = video!.absolute.path;
      _logger.i("Video under 50MB — using original path: $compressedVideoPath");
    }

    notifyListeners();
  }

  void snackbarNew(BuildContext context, {required String msg}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String storyID = '';

  //*********************************************************************** */
  //******************************* STORY UPLOAD ****************************/
  //*********************************************************************** */
  final StoryUploadRepo storyUploadRepo;

  StoryProvider(this.storyUploadRepo);

  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<bool> storyUploadApi(
    String storyType,
    File storyFile,
    String? caption, {
    String? thumbnailPath,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notify();

      final result = await storyUploadRepo.stroyUploadRepo(
        storyType,
        storyFile,
        caption,
        thumbnailPath,
      );

      if (result.status == true) {
        _isLoading = false;
        _errorMessage = result.message;
        notify();
        return true;
      } else {
        _isLoading = false;
        _errorMessage = result.message;
        notify();
        return false;
      }
    } on AppError catch (e) {
      _isLoading = false;
      _errorMessage = e.message;
      notify();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      _logger.i('Error loading features: $e');
      notify();
      return false;
    } finally {
      _isLoading = false;
      notify();
    }
  }

  //************************************************************************************/
  //************************************** GET ALL STORIES *****************************/
  //************************************************************************************/

  bool _isGetStory = false;
  bool get isGetStory => _isGetStory;
  bool hasLoadedOnce = false;
  bool isInternetIssue = false;
  int userWiseStoryCount = 0;
  List<RecentStories> getRecentStoryList = [];
  List<ViewedStories> getViewedStoryList = [];
  List<MyStories> getMyStories = [];
  List<StoryModel> recentStory = [];
  List<StoryModel> viewedStory = [];
  List<StoryModel> myStory = [];

  Future<void> getAllStories() async {
    if (!hasLoadedOnce) {
      _isGetStory = true;
    }
    _errorMessage = null;
    isInternetIssue = false;
    hasLoadedOnce = false;
    notify();

    try {
      final result = await storyUploadRepo.getAllStoriesRepo();
      getRecentStoryList.clear();
      getViewedStoryList.clear();
      getMyStories.clear();
      myStory.clear();
      if (result.status == true) {
        getMyStories.addAll(result.data!.myStories!);
        getRecentStoryList.addAll(result.data!.recentStories!);
        getViewedStoryList.addAll(result.data!.viewedStories!);

        // ✅ Build StoryModel again after new fetch
        myStory.add(
          StoryModel(
            userID: userID,
            userName: "$firstName $lastName",
            userProfile: userProfile,
            fName: firstName,
            lName: lastName,
            stories:
                getMyStories.map((e) {
                  if (e.storyType == "image") {
                    return CustomStoryItem(
                      storyId: e.storyId.toString(),
                      url: e.media,
                      userID: userID,
                      storyCaption: e.caption.toString(),
                      storyTime: e.updatedAt.toString(),
                      storyItemType: StoryItemType.image,
                      duration: const Duration(seconds: 10),
                      imageConfig: StoryViewImageConfig(
                        fit: BoxFit.contain,
                        progressIndicatorBuilder:
                            (_, __, _) => Center(child: commonLoading()),
                      ),
                    );
                  } else {
                    return CustomStoryItem(
                      storyId: e.storyId.toString(),
                      url: e.media,
                      userID: userID,
                      storyCaption: e.caption.toString(),
                      storyTime: e.updatedAt.toString(),
                      storyItemType: StoryItemType.video,
                      videoConfig: StoryViewVideoConfig(
                        cacheVideo: true,
                        fit: BoxFit.none,
                        useVideoAspectRatio: true,
                        loadingWidget: Center(child: commonLoading()),
                      ),
                    );
                  }
                }).toList(),
          ),
        );

        hasLoadedOnce = true;
        _isGetStory = false;
        notify();
      } else {
        _errorMessage = result.message.toString();
        getRecentStoryList.clear();
        getViewedStoryList.clear();
        getMyStories.clear();
        _isGetStory = false;
        notify();
      }
    } on AppError catch (e) {
      getRecentStoryList.clear();
      getViewedStoryList.clear();
      getMyStories.clear();
      _isGetStory = false;
      final data = extractErrorData(e);
      _errorMessage = data?['message'] ?? 'Unknown error';
      isInternetIssue = errorMessage!.contains(AppString.connectionError);
      notify();
    } catch (e) {
      getRecentStoryList.clear();
      getViewedStoryList.clear();
      getMyStories.clear();
      _errorMessage = 'Unexpected error occurred';
      isInternetIssue = false;
      _logger.i('Error loading features: $e');
      notify();
    } finally {
      _isGetStory = false;
      notify();
    }
  }

  //************************************************************************************/
  //************************************** VIEWED STORIES *****************************/
  //************************************************************************************/
  bool _isViewd = false;
  bool get isViewed => _isViewd;

  Future<void> viewStory({required String storyID}) async {
    try {
      _isViewd = false;
      // notify();

      final result = await storyUploadRepo.viewedStoryRepo(storyID: storyID);

      if (result.status == true) {
        _logger.i(result.message!);
        for (var i = 0; i < getRecentStoryList.length; i++) {
          for (var j = 0; j < getRecentStoryList[i].stories!.length; j++) {
            if (getRecentStoryList[i].stories![j].storyId.toString() ==
                storyID) {
              getRecentStoryList[i].viewedCount =
                  (getRecentStoryList[i].viewedCount ?? 0) + 1;
            }
          }
        }
        _isViewd = false;
        // notify();
      } else {
        _isViewd = false;
        _errorMessage = result.message.toString();
        _logger.i(_errorMessage.toString());
        // notify();
      }
    } on AppError catch (e) {
      _isViewd = false;
      final data = extractErrorData(e);
      _errorMessage = data?['message'] ?? 'Unknown error';
      _logger.i(_errorMessage.toString());
      // notify();
    } catch (e) {
      _errorMessage = e.toString();
      _logger.i(_errorMessage.toString());
      _isViewd = false;
      // notify();
    }
  }

  //************************************************************************************/
  //************************************** VIEWED STORIES *****************************/
  //************************************************************************************/
  bool _isRemove = false;
  bool get isRemove => _isRemove;

  Future<bool> removeStoryApi({required String storyid}) async {
    try {
      _isRemove = true;
      _errorMessage = null;

      final result = await storyUploadRepo.removeStoryRepo(storyId: storyid);

      if (result.status == true) {
        for (var i = 0; i < getRecentStoryList.length; i++) {
          getRecentStoryList[i].stories?.removeWhere(
            (story) => story.storyId.toString() == storyid,
          );
        }
        for (var i = 0; i < getViewedStoryList.length; i++) {
          getViewedStoryList[i].stories?.removeWhere(
            (story) => story.storyId.toString() == storyid,
          );
        }
        _logger.i(result.message!);
        _isRemove = false;
        return true;
      } else {
        _isRemove = false;
        _errorMessage = result.message.toString();
        _logger.i(_errorMessage.toString());
        return false;
      }
    } on AppError catch (e) {
      _isRemove = false;
      final data = extractErrorData(e);
      _errorMessage = data?['message'] ?? 'Unknown error';
      _logger.i(_errorMessage.toString());
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _logger.i(_errorMessage.toString());
      _isRemove = false;
      return false;
    }
  }

  //************************************************************************************/
  //************************************** VIEWED STORY USER LIST **********************/
  //************************************************************************************/
  bool _isViewedStory = false;
  bool get isViewedStory => _isViewedStory;
  List<Views> viewedUserList = [];

  Future<void> getViewedList({required String storyID}) async {
    _isViewedStory = true;
    _errorMessage = null;
    isInternetIssue = false;

    try {
      final result = await storyUploadRepo.viewedUserRepo(storyID: storyID);
      viewedUserList.clear();

      if (result.status == true) {
        viewedUserList.addAll(result.data!.views!);
        _isViewedStory = false;
      } else {
        viewedUserList.clear();
        _errorMessage = result.message;
        _isViewedStory = false;
      }
    } on AppError catch (e) {
      _isViewedStory = false;
      final data = extractErrorData(e);
      _errorMessage = data?['message'] ?? 'Unknown error';
      isInternetIssue = errorMessage!.contains(AppString.connectionError);
    } catch (e) {
      _isViewedStory = false;
      _logger.i('Error loading features: $e');
      isInternetIssue = false;
    }
  }
}
