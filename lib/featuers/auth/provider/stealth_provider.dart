import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:whoxa/utils/preference_key/sharedpref_key.dart';
import 'package:whoxa/utils/logger.dart';

class StealthProvider with ChangeNotifier {
  final ConsoleAppLogger _logger = ConsoleAppLogger.forModule('StealthProvider');

  static const String _stealthPinKey = "STEALTH_PIN_CODE";
  static const String _trialStartDateKey = "STEALTH_TRIAL_START_DATE";
  static const String _isSubscribedKey = "STEALTH_IS_SUBSCRIBED";

  bool _isUnlocked = false;
  bool _hasPinSet = false;
  bool _isLoadingNews = false;
  List<dynamic> _newsArticles = [];
  String? _newsError;

  bool get isUnlocked => _isUnlocked;
  bool get hasPinSet => _hasPinSet;
  bool get isLoadingNews => _isLoadingNews;
  List<dynamic> get newsArticles => _newsArticles;
  String? get newsError => _newsError;

  StealthProvider() {
    _init();
  }

  Future<void> _init() async {
    try {
      final pin = await SecurePrefs.getString(_stealthPinKey);
      _hasPinSet = pin != null && pin.isNotEmpty;
      _logger.i("Stealth Layer initialized: hasPinSet = $_hasPinSet");
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
    try {
      // Check if subscribed
      final isSubscribed = await SecurePrefs.getBool(_isSubscribedKey);
      if (isSubscribed) {
        _logger.i("Stealth Layer: Active subscription found");
        return true;
      }

      // Check trial
      String? trialStartStr = await SecurePrefs.getString(_trialStartDateKey);
      if (trialStartStr == null || trialStartStr.isEmpty) {
        // Initialize trial start date to now
        final nowStr = DateTime.now().toIso8601String();
        await SecurePrefs.setString(_trialStartDateKey, nowStr);
        _logger.i("Stealth Layer: Initialized 3-day trial starting at $nowStr");
        return true; // Trial is active since we just started it
      }

      final trialStart = DateTime.parse(trialStartStr);
      final daysElapsed = DateTime.now().difference(trialStart).inDays;
      if (daysElapsed < 3) {
        _logger.i("Stealth Layer: Trial is active (Day ${daysElapsed + 1}/3)");
        return true;
      }

      _logger.w("Stealth Layer: Trial expired");
    } catch (e) {
      _logger.e("Error checking subscription status", e);
    }
    return false;
  }

  Future<void> setSubscriptionActive(bool active) async {
    try {
      await SecurePrefs.setBool(_isSubscribedKey, active);
      _logger.i("Stealth Layer: Subscription status updated to $active");
    } catch (e) {
      _logger.e("Error updating subscription status", e);
    }
    notifyListeners();
  }

  // Fetch CNN news articles from free clone API saurav.tech
  Future<void> fetchNews() async {
    if (_isLoadingNews) return;
    _isLoadingNews = true;
    _newsError = null;
    notifyListeners();

    try {
      _logger.i("Stealth Layer: Fetching camouflage news feed");
      final response = await http.get(
        Uri.parse("https://saurav.tech/NewsAPI/everything/cnn.json"),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null && data['articles'] != null) {
          _newsArticles = data['articles'];
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
