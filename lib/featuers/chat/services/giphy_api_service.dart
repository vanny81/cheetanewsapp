import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:whoxa/utils/logger.dart';

/// Lightweight data model representing a GIF or Sticker from Giphy.
class GiphyMedia {
  final String id;
  final String url; // Full-size URL (original)
  final String previewUrl; // Grid preview URL (fixed_height_small)
  final String type; // 'gif' or 'sticker'

  const GiphyMedia({
    required this.id,
    required this.url,
    required this.previewUrl,
    required this.type,
  });

  factory GiphyMedia.fromJson(Map<String, dynamic> json, String type) {
    final images = json['images'] as Map<String, dynamic>?;

    String url = '';
    String previewUrl = '';

    if (images != null) {
      // For full-size: try original → fixed_height → downsized
      url = images['original']?['url'] as String? ??
          images['fixed_height']?['url'] as String? ??
          images['downsized']?['url'] as String? ??
          '';

      // For preview: try fixed_height_small → fixed_width_small → preview_gif
      previewUrl = images['fixed_height_small']?['url'] as String? ??
          images['fixed_width_small']?['url'] as String? ??
          images['preview_gif']?['url'] as String? ??
          url; // Fallback to full-size
    }

    return GiphyMedia(
      id: json['id'] as String? ?? '',
      url: url,
      previewUrl: previewUrl,
      type: type,
    );
  }
}

/// Cached search result with TTL
class _CachedResult {
  final List<GiphyMedia> data;
  final DateTime cachedAt;

  _CachedResult(this.data, this.cachedAt);

  bool isExpired(Duration ttl) =>
      DateTime.now().difference(cachedAt) > ttl;
}

/// Singleton service for Giphy REST API with built-in caching and rate limiting.
///
/// Designed to work within the 100 API calls/hour rate limit by:
/// 1. Caching trending results for 10 minutes
/// 2. Caching search results for 5 minutes
/// 3. Tracking call count with a rolling 1-hour window
/// 4. Handling 429 responses gracefully
class GiphyApiService {
  static final GiphyApiService _instance = GiphyApiService._internal();

  factory GiphyApiService() => _instance;

  GiphyApiService._internal();

  // ═══════════════════════════════════════════════════════════════════════════
  // CONFIGURATION
  // ═══════════════════════════════════════════════════════════════════════════

  static const String _apiKey = 'Hq5ougk40ZXykuAXxQhka8YcRO5ovTYd';
  static const String _baseUrl = 'https://api.giphy.com/v1';
  static const int _maxCallsPerHour = 100;
  static const int _warningThreshold = 90;
  static const int _defaultLimit = 25;

  // Cache TTLs
  static const Duration _trendingCacheTtl = Duration(minutes: 10);
  static const Duration _searchCacheTtl = Duration(minutes: 5);
  static const Duration _rateLimitCooldown = Duration(seconds: 60);

  final _logger = ConsoleAppLogger.forModule('GiphyApiService');

  // ═══════════════════════════════════════════════════════════════════════════
  // RATE LIMITING STATE
  // ═══════════════════════════════════════════════════════════════════════════

  final List<DateTime> _callTimestamps = [];
  bool _isRateLimited = false;
  DateTime? _rateLimitedUntil;

  // ═══════════════════════════════════════════════════════════════════════════
  // CACHE STATE
  // ═══════════════════════════════════════════════════════════════════════════

  _CachedResult? _cachedTrendingGifs;
  _CachedResult? _cachedTrendingStickers;
  final Map<String, _CachedResult> _searchCache = {};

  // ═══════════════════════════════════════════════════════════════════════════
  // PUBLIC API
  // ═══════════════════════════════════════════════════════════════════════════

  /// Whether the service is currently rate limited.
  bool get isRateLimited {
    if (_isRateLimited && _rateLimitedUntil != null) {
      if (DateTime.now().isAfter(_rateLimitedUntil!)) {
        _isRateLimited = false;
        _rateLimitedUntil = null;
        return false;
      }
      return true;
    }
    return false;
  }

  /// Whether we're approaching the hourly limit.
  bool get isApproachingLimit {
    _pruneOldTimestamps();
    return _callTimestamps.length >= _warningThreshold;
  }

  /// Number of remaining API calls in the current hour window.
  int get remainingCalls {
    _pruneOldTimestamps();
    return (_maxCallsPerHour - _callTimestamps.length).clamp(0, _maxCallsPerHour);
  }

  /// Fetch trending GIFs. Returns cached data if available and fresh.
  Future<List<GiphyMedia>> getTrendingGifs({int limit = _defaultLimit}) async {
    // Check cache first
    if (_cachedTrendingGifs != null &&
        !_cachedTrendingGifs!.isExpired(_trendingCacheTtl)) {
      _logger.d('Using cached trending GIFs (${_cachedTrendingGifs!.data.length} items)');
      return _cachedTrendingGifs!.data;
    }

    // Check rate limit
    if (isRateLimited) {
      _logger.w('Rate limited — returning cached trending GIFs if available');
      return _cachedTrendingGifs?.data ?? [];
    }

    try {
      final url = '$_baseUrl/gifs/trending?api_key=$_apiKey&limit=$limit&rating=g';
      final results = await _makeRequest(url, 'gif');

      // Cache the results
      _cachedTrendingGifs = _CachedResult(results, DateTime.now());
      _logger.i('Fetched and cached ${results.length} trending GIFs');
      return results;
    } catch (e) {
      _logger.e('Error fetching trending GIFs: $e');
      // Return cached data on error
      return _cachedTrendingGifs?.data ?? [];
    }
  }

  /// Search GIFs by query. Returns cached results if available.
  Future<List<GiphyMedia>> searchGifs(String query, {int limit = _defaultLimit}) async {
    if (query.trim().isEmpty) return getTrendingGifs(limit: limit);

    final cacheKey = 'gif:${query.toLowerCase().trim()}';

    // Check search cache
    final cached = _searchCache[cacheKey];
    if (cached != null && !cached.isExpired(_searchCacheTtl)) {
      _logger.d('Using cached search results for "$query"');
      return cached.data;
    }

    // Check rate limit
    if (isRateLimited) {
      _logger.w('Rate limited — returning cached search results if available');
      return cached?.data ?? _cachedTrendingGifs?.data ?? [];
    }

    try {
      final encodedQuery = Uri.encodeComponent(query.trim());
      final url =
          '$_baseUrl/gifs/search?api_key=$_apiKey&q=$encodedQuery&limit=$limit&rating=g';
      final results = await _makeRequest(url, 'gif');

      // Cache the results
      _searchCache[cacheKey] = _CachedResult(results, DateTime.now());
      _logger.i('Fetched and cached ${results.length} GIFs for "$query"');
      return results;
    } catch (e) {
      _logger.e('Error searching GIFs for "$query": $e');
      return cached?.data ?? [];
    }
  }

  /// Fetch trending stickers. Returns cached data if available and fresh.
  Future<List<GiphyMedia>> getTrendingStickers({int limit = _defaultLimit}) async {
    // Check cache first
    if (_cachedTrendingStickers != null &&
        !_cachedTrendingStickers!.isExpired(_trendingCacheTtl)) {
      _logger.d(
          'Using cached trending stickers (${_cachedTrendingStickers!.data.length} items)');
      return _cachedTrendingStickers!.data;
    }

    // Check rate limit
    if (isRateLimited) {
      _logger.w('Rate limited — returning cached trending stickers if available');
      return _cachedTrendingStickers?.data ?? [];
    }

    try {
      final url =
          '$_baseUrl/stickers/trending?api_key=$_apiKey&limit=$limit&rating=g';
      final results = await _makeRequest(url, 'sticker');

      // Cache the results
      _cachedTrendingStickers = _CachedResult(results, DateTime.now());
      _logger.i('Fetched and cached ${results.length} trending stickers');
      return results;
    } catch (e) {
      _logger.e('Error fetching trending stickers: $e');
      return _cachedTrendingStickers?.data ?? [];
    }
  }

  /// Search stickers by query. Returns cached results if available.
  Future<List<GiphyMedia>> searchStickers(String query,
      {int limit = _defaultLimit}) async {
    if (query.trim().isEmpty) return getTrendingStickers(limit: limit);

    final cacheKey = 'sticker:${query.toLowerCase().trim()}';

    // Check search cache
    final cached = _searchCache[cacheKey];
    if (cached != null && !cached.isExpired(_searchCacheTtl)) {
      _logger.d('Using cached sticker search results for "$query"');
      return cached.data;
    }

    // Check rate limit
    if (isRateLimited) {
      _logger.w('Rate limited — returning cached sticker search results if available');
      return cached?.data ?? _cachedTrendingStickers?.data ?? [];
    }

    try {
      final encodedQuery = Uri.encodeComponent(query.trim());
      final url =
          '$_baseUrl/stickers/search?api_key=$_apiKey&q=$encodedQuery&limit=$limit&rating=g';
      final results = await _makeRequest(url, 'sticker');

      // Cache the results
      _searchCache[cacheKey] = _CachedResult(results, DateTime.now());
      _logger.i('Fetched and cached ${results.length} stickers for "$query"');
      return results;
    } catch (e) {
      _logger.e('Error searching stickers for "$query": $e');
      return cached?.data ?? [];
    }
  }

  /// Clear all caches (useful for testing or manual refresh).
  void clearCache() {
    _cachedTrendingGifs = null;
    _cachedTrendingStickers = null;
    _searchCache.clear();
    _logger.d('All Giphy caches cleared');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PRIVATE HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Make an HTTP request to the Giphy API with rate limit tracking.
  Future<List<GiphyMedia>> _makeRequest(String url, String mediaType) async {
    // Pre-flight rate limit check
    _pruneOldTimestamps();
    if (_callTimestamps.length >= _maxCallsPerHour) {
      _logger.w('Hourly API call limit reached ($_maxCallsPerHour). Blocking request.');
      _setRateLimited();
      return [];
    }

    // Record this call
    _callTimestamps.add(DateTime.now());
    _logger.d(
        'Giphy API call #${_callTimestamps.length}/$_maxCallsPerHour this hour');

    try {
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Giphy API request timed out');
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> items = data['data'] ?? [];

        return items
            .map((item) =>
                GiphyMedia.fromJson(item as Map<String, dynamic>, mediaType))
            .where((media) => media.url.isNotEmpty && media.previewUrl.isNotEmpty)
            .toList();
      } else if (response.statusCode == 429) {
        // Rate limited by Giphy
        _logger.w('Giphy API returned 429 — rate limited');
        _setRateLimited();
        return [];
      } else {
        _logger.e('Giphy API error: ${response.statusCode} ${response.body}');
        return [];
      }
    } on TimeoutException {
      _logger.e('Giphy API request timed out');
      return [];
    } catch (e) {
      _logger.e('Giphy API network error: $e');
      return [];
    }
  }

  /// Remove timestamps older than 1 hour from the tracking list.
  void _pruneOldTimestamps() {
    final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));
    _callTimestamps.removeWhere((ts) => ts.isBefore(oneHourAgo));
  }

  /// Set the service as rate limited with a cooldown timer.
  void _setRateLimited() {
    _isRateLimited = true;
    _rateLimitedUntil = DateTime.now().add(_rateLimitCooldown);
    _logger.w(
        'Rate limit activated. Cooldown until: $_rateLimitedUntil');
  }
}
