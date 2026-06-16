import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:get_it/get_it.dart';
import 'package:whoxa/core/api/api_client.dart';
import 'package:whoxa/utils/preference_key/preference_key.dart';
import 'package:whoxa/utils/preference_key/sharedpref_key.dart';
import 'package:whoxa/utils/logger.dart';

class StealthProvider with ChangeNotifier {
  final ConsoleAppLogger _logger = ConsoleAppLogger.forModule('StealthProvider');

  static const String _stealthPinKey = "STEALTH_PIN_CODE";
  static const String _trialStartDateKey = "STEALTH_TRIAL_START_DATE";
  static const String _isSubscribedKey = "STEALTH_IS_SUBSCRIBED";
  static const String _newsCacheKey = "STEALTH_NEWS_CACHE";
  static const String _newsCacheTimeKey = "STEALTH_NEWS_CACHE_TIME";

  bool _isUnlocked = false;
  bool _hasPinSet = false;
  bool _isLoadingNews = false;
  List<dynamic> _newsArticles = [];
  String? _newsError;
  bool _isSubscribed = false;
  bool _isTrialActive = false;
  int _trialDaysRemaining = 0;

  bool get isUnlocked => _isUnlocked;
  bool get hasPinSet => _hasPinSet;
  bool get isLoadingNews => _isLoadingNews;
  List<dynamic> get newsArticles => _newsArticles;
  String? get newsError => _newsError;
  bool get isSubscribed => _isSubscribed;
  bool get isTrialActive => _isTrialActive;
  int get trialDaysRemaining => _trialDaysRemaining;

  StealthProvider() {
    _init();
  }

  Future<void> _init() async {
    try {
      final pin = await SecurePrefs.getString(_stealthPinKey);
      _hasPinSet = pin != null && pin.isNotEmpty;
      _logger.i("Stealth Layer initialized: hasPinSet = $_hasPinSet");
      await checkSubscriptionStatus();
      await _loadCachedNews();
    } catch (e) {
      _logger.e("Error loading Stealth PIN code", e);
    }
    notifyListeners();
  }

  void lock() {
    _isUnlocked = false;
    _logger.i("Stealth Layer: Locked secure chat layer");
    notifyListeners();
  }

  void unlock() {
    _isUnlocked = true;
    _logger.i("Stealth Layer: Unlocked secure chat layer");
    notifyListeners();
  }

  Future<bool> verifyPin(String pin) async {
    try {
      final savedPin = await SecurePrefs.getString(_stealthPinKey);
      if (savedPin == pin) {
        unlock();
        return true;
      }
    } catch (e) {
      _logger.e("Error verifying PIN code", e);
    }
    return false;
  }

  Future<void> setPin(String pin) async {
    try {
      await SecurePrefs.setString(_stealthPinKey, pin);
      _hasPinSet = true;
      unlock();
      _logger.i("Stealth Layer: New PIN set successfully");
    } catch (e) {
      _logger.e("Error saving new PIN code", e);
    }
    notifyListeners();
  }

  Future<void> clearPin() async {
    try {
      await SecurePrefs.remove(_stealthPinKey);
      _hasPinSet = false;
      lock();
      _logger.i("Stealth Layer: PIN cleared");
    } catch (e) {
      _logger.e("Error clearing PIN code", e);
    }
    notifyListeners();
  }

  // Check subscription / 3-day trial
  Future<bool> checkSubscriptionStatus() async {
    // Asynchronously trigger sync with backend in background
    unawaited(syncSubscriptionWithBackend());

    try {
      // Check if subscribed
      final isSubscribedVal = await SecurePrefs.getBool(_isSubscribedKey);
      if (isSubscribedVal) {
        _isSubscribed = true;
        _isTrialActive = false;
        _trialDaysRemaining = 0;
        _logger.i("Stealth Layer: Active subscription found");
        notifyListeners();
        return true;
      }

      // Check trial
      String? trialStartStr = await SecurePrefs.getString(_trialStartDateKey);
      if (trialStartStr == null || trialStartStr.isEmpty) {
        // Initialize trial start date to now
        final nowStr = DateTime.now().toIso8601String();
        await SecurePrefs.setString(_trialStartDateKey, nowStr);
        _logger.i("Stealth Layer: Initialized 3-day trial starting at $nowStr");
        _isSubscribed = false;
        _isTrialActive = true;
        _trialDaysRemaining = 3;
        notifyListeners();
        return true; // Trial is active since we just started it
      }

      final trialStart = DateTime.parse(trialStartStr);
      final daysElapsed = DateTime.now().difference(trialStart).inDays;
      if (daysElapsed < 3) {
        _isSubscribed = false;
        _isTrialActive = true;
        _trialDaysRemaining = 3 - daysElapsed;
        _logger.i("Stealth Layer: Trial is active (Day ${daysElapsed + 1}/3)");
        notifyListeners();
        return true;
      }

      _isSubscribed = false;
      _isTrialActive = false;
      _trialDaysRemaining = 0;
      _logger.w("Stealth Layer: Trial expired");
    } catch (e) {
      _logger.e("Error checking subscription status", e);
    }
    notifyListeners();
    return false;
  }

  Future<void> syncSubscriptionWithBackend() async {
    try {
      final token = await SecurePrefs.getString(SecureStorageKeys.TOKEN) ?? '';
      if (token.isEmpty) {
        _logger.d("User not logged in, skipping backend subscription sync");
        return;
      }

      final apiClient = GetIt.instance<ApiClient>();
      final response = await apiClient.request("/payment/status");

      if (response != null && response['success'] == true) {
        final data = response['data'];
        final isSubscribedVal = data['is_subscribed'] == true;
        final isTrialActiveVal = data['is_trial_active'] == true;
        final trialStart = data['trial_start_date']?.toString();

        await SecurePrefs.setBool(_isSubscribedKey, isSubscribedVal);
        if (trialStart != null) {
          await SecurePrefs.setString(_trialStartDateKey, trialStart);
        }
        
        _isSubscribed = isSubscribedVal;
        _isTrialActive = isTrialActiveVal;
        
        if (isTrialActiveVal && trialStart != null) {
          try {
            final trialStartDate = DateTime.parse(trialStart);
            final daysElapsed = DateTime.now().difference(trialStartDate).inDays;
            final remaining = 3 - daysElapsed;
            _trialDaysRemaining = remaining < 0 ? 0 : remaining;
          } catch (_) {
            _trialDaysRemaining = 0;
          }
        } else {
          _trialDaysRemaining = 0;
        }
        
        _logger.i("Stealth Layer: Subscription synced from backend: isSubscribed=$_isSubscribed, isTrialActive=$_isTrialActive");
        notifyListeners();
      }
    } catch (e) {
      _logger.e("Error syncing subscription status with backend", e);
    }
  }

  Future<void> setSubscriptionActive(bool active) async {
    try {
      await SecurePrefs.setBool(_isSubscribedKey, active);
      _isSubscribed = active;
      if (active) {
        _isTrialActive = false;
        _trialDaysRemaining = 0;
      }
      _logger.i("Stealth Layer: Subscription status updated to $active");
    } catch (e) {
      _logger.e("Error updating subscription status", e);
    }
    notifyListeners();
  }

  Future<void> _loadCachedNews() async {
    try {
      final cacheJson = await SecurePrefs.getString(_newsCacheKey);
      if (cacheJson != null && cacheJson.isNotEmpty) {
        final List<dynamic> cached = jsonDecode(cacheJson);
        _newsArticles = cached;
        _logger.i("Loaded ${_newsArticles.length} news articles from cache");
      }
    } catch (e) {
      _logger.e("Error loading cached news", e);
    }
  }

  // Fetch South Africa news articles from CurrentsAPI with caching
  Future<void> fetchNews({bool forceRefresh = false}) async {
    if (_isLoadingNews) return;

    if (!forceRefresh && _newsArticles.isNotEmpty) {
      final cacheTimeStr = await SecurePrefs.getString(_newsCacheTimeKey);
      if (cacheTimeStr != null && cacheTimeStr.isNotEmpty) {
        try {
          final cacheTime = DateTime.parse(cacheTimeStr);
          final difference = DateTime.now().difference(cacheTime);
          if (difference.inMinutes < 15) {
            _logger.i("Stealth Layer: Using fresh cached news (age: ${difference.inMinutes}m)");
            return;
          }
        } catch (_) {}
      }
    }

    _isLoadingNews = true;
    _newsError = null;
    notifyListeners();

    try {
      _logger.i("Stealth Layer: Fetching camouflage news feed from CurrentsAPI");
      final response = await http.get(
        Uri.parse("https://api.currentsapi.services/v1/search?keywords=South%20Africa&language=en"),
        headers: {
          'Authorization': '4e-fBdUmxbTmrezyenOnVA2w-D9SmtJgspRYAgpK4xzgVBRO',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null && data['news'] != null) {
          final List<dynamic> rawArticles = data['news'];
          _newsArticles = rawArticles.map((item) {
            return {
              'title': item['title'],
              'description': item['description'],
              'urlToImage': item['image'],
              'source': {
                'name': (item['author'] != null && item['author'].toString().trim().isNotEmpty)
                    ? item['author']
                    : 'Currents'
              },
              'publishedAt': item['published'],
              'url': item['url'],
            };
          }).toList();

          await SecurePrefs.setString(_newsCacheKey, jsonEncode(_newsArticles));
          await SecurePrefs.setString(_newsCacheTimeKey, DateTime.now().toIso8601String());
          _logger.i("Stealth Layer: Fetched ${_newsArticles.length} news articles");
        } else {
          _newsError = "Invalid news data structure";
        }
      } else {
        _newsError = "Failed to load news: ${response.statusCode}";
      }
    } catch (e) {
      _newsError = "Error loading news: $e";
      _logger.e("Error fetching news: $e");
    } finally {
      _isLoadingNews = false;
      notifyListeners();
    }
  }
}
