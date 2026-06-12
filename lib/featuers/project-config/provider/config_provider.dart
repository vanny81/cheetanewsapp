// *****************************************************************************************
// * Filename: project_config_provider.dart                                                *
// * Developer: Deval Joshi                                    *
// * Date: 25 June 25                             *
// * Description: Provider for managing project configuration state                        *
// *****************************************************************************************

import 'package:flutter/foundation.dart';
import 'package:whoxa/core/error/app_error.dart';
import 'package:whoxa/featuers/notification/model/mark_read_model.dart';
import 'package:whoxa/featuers/notification/model/notification_model.dart';
import 'package:whoxa/featuers/project-config/data/config_model.dart';
import 'package:whoxa/featuers/project-config/data/config_repo.dart';

import 'package:whoxa/utils/logger.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';

class ProjectConfigProvider with ChangeNotifier {
  final ProjectConfigRepository _repository;
  final ConsoleAppLogger _logger = ConsoleAppLogger();

  ProjectConfigProvider(this._repository);

  // Private variables
  ProjectConfig? _projectConfig;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _errorMessage;
  bool _hasError = false;

  NotificationListModel? _notificationListModel;
  MarkReadNotifiModel? _markReadNotifiModel;
  bool _isNotification = false;
  bool _isReadNotifi = false;
  bool isInternetIssue = false;

  // Getters
  ProjectConfig? get projectConfig => _projectConfig;
  ProjectConfigData? get configData => _projectConfig?.data;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get errorMessage => _errorMessage;
  bool get hasError => _hasError;
  bool get hasValidConfig => _projectConfig != null && _projectConfig!.status;
  bool get isNotification => _isNotification;
  bool get isReadNotifi => _isReadNotifi;
  MarkReadNotifiModel? get markReadNotifiModel => _markReadNotifiModel;
  NotificationListModel? get notificationListModel => _notificationListModel;
  Data? get notificaitonData => _notificationListModel?.data;

  // Configuration getters for easy access
  String get appName => configData?.appName ?? 'Rabtah Saj';
  String get appPrimaryColor => configData?.appPrimaryColor ?? '#006400';
  String get appSecondaryColor => configData?.appSecondaryColor ?? '#0AC00A';
  bool get isPhoneAuthEnabled => configData?.phoneAuthentication ?? true;
  bool get isEmailAuthEnabled => configData?.emailAuthentication ?? true;
  int get maxGroupMembers => configData?.maximumMembersInGroup ?? 10;
  bool get showAllContacts => configData?.showAllContacts ?? true;
  bool get showPhoneContacts => configData?.showPhoneContacts ?? true;
  String get oneSignalAppId => configData?.oneSignalAppId ?? '';
  String get oneSignalApiKey => configData?.oneSignalApiKey ?? '';
  String get appLogoLight => configData?.appLogoLight ?? '';
  String get appLogoDark => configData?.appLogoDark ?? '';
  String get privacyPolicy => configData?.privacyPolicy ?? '';
  String get termsAndConditions => configData?.termsAndConditions ?? '';

  // New getters for the flow configuration
  bool get userNameFlow => configData?.userNameFlow ?? true;
  bool get contactFlow => configData?.contactFlow ?? true;

  // Debug method to log all config values
  void debugLogConfigValues() {
    debugPrint('🔧 ===== PROJECT CONFIG DEBUG =====');
    debugPrint('📱 App Name: $appName');
    debugPrint('🎨 Primary Color: $appPrimaryColor');
    debugPrint('📞 Phone Auth: $isPhoneAuthEnabled');
    debugPrint('📧 Email Auth: $isEmailAuthEnabled');
    debugPrint('👥 Show All Contacts: $showAllContacts');
    debugPrint('📱 Show Phone Contacts: $showPhoneContacts');
    debugPrint('👤 User Name Flow: $userNameFlow');
    debugPrint('📞 Contact Flow: $contactFlow');
    debugPrint('✅ Has Valid Config: $hasValidConfig');
    debugPrint('🔄 Is Loading: $isLoading');
    debugPrint('❌ Has Error: $hasError');
    if (hasError) {
      debugPrint('🚨 Error Message: $errorMessage');
    }
    debugPrint('🔧 ===== END CONFIG DEBUG =====');
  }

  String get appText => configData?.appText ?? '';
  String get copyrightText => configData?.copyrightText ?? '';

  /// Initialize project configuration
  /// This should be called once during app startup
  Future<bool> initializeProjectConfig() async {
    if (_isInitialized && hasValidConfig) {
      _logger.i('Project configuration already initialized');
      return true;
    }

    _logger.i('Initializing project configuration');
    _setLoading(true);
    _clearError();

    try {
      await _fetchConfiguration();
      _isInitialized = true;
      _logger.i('Project configuration initialized successfully');
      return true;
    } catch (e) {
      _logger.e('Failed to initialize project configuration', e);
      await _handleConfigurationError(e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Refresh configuration data
  Future<void> refreshConfiguration() async {
    _logger.i('Refreshing project configuration');
    _setLoading(true);
    _clearError();

    try {
      await _fetchConfiguration();
      _logger.i('Project configuration refreshed successfully');
    } catch (e) {
      _logger.e('Failed to refresh project configuration', e);
      await _handleConfigurationError(e);
    } finally {
      _setLoading(false);
    }
  }

  /// Private method to fetch configuration from repository
  Future<void> _fetchConfiguration() async {
    try {
      final config = await _repository.getProjectConfiguration();
      _projectConfig = config;
      _logger.i('Configuration fetched and stored successfully');
      _logger.d('App Name: ${config.data.appName}');
      notifyListeners();
    } catch (e) {
      _logger.e('Error in _fetchConfiguration', e);
      rethrow;
    }
  }

  List<Records>? notificationList;
  final List<Records> _notificationList = [];
  Future<void> fetchNotificationList() async {
    try {
      _isNotification = true;
      _errorMessage = null;
      isInternetIssue = false;
      notifyListeners();

      final notification = await _repository.getNotificationListRepo();
      _notificationListModel = notification;

      notificationList ??= []; // Initialize if null
      notificationList!.clear();
      _notificationList.clear(); // Clear old data

      if (_notificationListModel?.status == true &&
          _notificationListModel?.data?.records != null) {
        // int? myUserId = int.tryParse(userID); // Convert String to int
        final allRecords = _notificationListModel!.data!.records!;

        notificationList!.addAll(allRecords);
        _notificationList.addAll(allRecords); // ✅ add full list
        marReadNitifiApi();
      } else {
        _errorMessage = _notificationListModel?.message ?? 'Unknown error';
      }
    } on AppError catch (e) {
      final data = extractErrorData(e);
      _errorMessage = data?['message'] ?? 'Unknown error';
      isInternetIssue = _errorMessage!.contains(AppString.connectionError);
    } catch (e) {
      _errorMessage = 'Unexpected error occurred';
      _logger.e("Error in Notification fetch: $e");
    } finally {
      _isNotification = false;
      notifyListeners();
    }
  }

  Map<String, List<Records>> get groupedNotification {
    Map<String, List<Records>> grouped = {};

    for (var notifi in _notificationList) {
      DateTime notifiDate = DateTime.parse(notifi.createdAt!);
      DateTime now = DateTime.now();
      String dateKey;

      if (notifiDate.year == now.year &&
          notifiDate.month == now.month &&
          notifiDate.day == now.day) {
        dateKey = 'Today';
      } else if (notifiDate.year == now.year &&
          notifiDate.month == now.month &&
          notifiDate.day == now.day - 1) {
        dateKey = 'Yesterday';
      } else {
        dateKey = '${notifiDate.day}/${notifiDate.month}/${notifiDate.year}';
      }

      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(notifi);
    }

    return grouped;
  }

  Future<void> marReadNitifiApi() async {
    try {
      _isReadNotifi = true;
      _errorMessage = null;
      notifyListeners();

      final markNotification = await _repository.marReadNotifiRepo();
      _markReadNotifiModel = markNotification;

      if (_markReadNotifiModel?.status == true) {
        _logger.d(_markReadNotifiModel!.message!);
      } else {
        _errorMessage = _markReadNotifiModel?.message ?? "Unknown error";
      }
    } on AppError catch (e) {
      final data = extractErrorData(e);
      _errorMessage = data?['message'] ?? 'Unknown error';
    } catch (e) {
      _errorMessage = 'Unexpected error occurred';
      _logger.e("Error in Notification Mark Read: $e");
    } finally {
      _isReadNotifi = false;
      notifyListeners();
    }
  }

  /// Handle configuration errors by loading default config
  Future<void> _handleConfigurationError(dynamic error) async {
    _setError(error.toString());

    // Load default configuration to ensure app can still run
    try {
      _projectConfig = _repository.getDefaultConfiguration();
      _logger.w('Loaded default configuration due to error');
      notifyListeners();
    } catch (e) {
      _logger.e('Failed to load even default configuration', e);
    }
  }

  /// Set loading state
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  /// Set error state
  void _setError(String error) {
    _errorMessage = error;
    _hasError = true;
    notifyListeners();
  }

  /// Clear error state
  void _clearError() {
    _errorMessage = null;
    _hasError = false;
    notifyListeners();
  }

  /// Check if specific features are enabled
  bool isFeatureEnabled(String feature) {
    switch (feature.toLowerCase()) {
      case 'phone_auth':
        return isPhoneAuthEnabled;
      case 'email_auth':
        return isEmailAuthEnabled;
      case 'show_all_contacts':
        return showAllContacts;
      case 'show_phone_contacts':
        return showPhoneContacts;
      default:
        return false;
    }
  }

  /// Get configuration value by key
  dynamic getConfigValue(String key) {
    if (!hasValidConfig) return null;

    switch (key) {
      case 'app_name':
        return appName;
      case 'app_primary_color':
        return appPrimaryColor;
      case 'app_secondary_color':
        return appSecondaryColor;
      case 'max_group_members':
        return maxGroupMembers;
      case 'one_signal_app_id':
        return oneSignalAppId;
      case 'one_signal_api_key':
        return oneSignalApiKey;
      default:
        return null;
    }
  }

  /// Reset the provider state
  void reset() {
    _projectConfig = null;
    _isLoading = false;
    _isInitialized = false;
    _errorMessage = null;
    _hasError = false;
    notifyListeners();
    _logger.i('Project configuration provider reset');
  }

  @override
  void dispose() {
    reset();
    super.dispose();
  }
}
