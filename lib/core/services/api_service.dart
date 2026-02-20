import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:smart_pulchowk/core/models/book_listing.dart';
import 'package:smart_pulchowk/core/models/chat.dart';
import 'package:smart_pulchowk/core/models/classroom.dart';
import 'package:smart_pulchowk/core/models/lost_found.dart';
import 'package:smart_pulchowk/core/models/notification.dart';
import 'package:smart_pulchowk/core/models/notice.dart';
import 'package:smart_pulchowk/core/models/event.dart';
import 'package:smart_pulchowk/core/models/club.dart';
import 'package:smart_pulchowk/core/models/trust.dart';
import 'package:smart_pulchowk/core/models/admin.dart';
import 'package:smart_pulchowk/core/services/auth_service.dart';
import 'package:smart_pulchowk/core/services/storage_service.dart';
import 'package:smart_pulchowk/core/constants/app_constants.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;

/// Result class for API operations.
class ApiResult<T> {
  final bool success;
  final T? data;
  final String? error;

  ApiResult({required this.success, this.data, this.error});

  factory ApiResult.success(T data) => ApiResult(success: true, data: data);
  factory ApiResult.failure(String error) =>
      ApiResult(success: false, error: error);
}

/// In-memory cache entry with timestamp.
class _CacheEntry<T> {
  final T data;
  final DateTime timestamp;
  final Duration ttl;

  _CacheEntry(this.data, this.ttl) : timestamp = DateTime.now();

  bool get isExpired => DateTime.now().difference(timestamp) > ttl;
}

/// Centralized networking service for interacting with the backend.
class ApiService {
  final http.Client _client = http.Client();

  // ── In-Memory Cache ───────────────────────────────────────────────────────
  static final Map<String, _CacheEntry> _cache = {};

  /// Get cached data if not expired.
  static T? getCached<T>(String key) {
    final entry = _cache[key];
    if (entry != null && !entry.isExpired) return entry.data as T;
    return null;
  }

  /// Store data in in-memory cache with a TTL.
  static void _setCache<T>(String key, T data, Duration ttl) {
    _cache[key] = _CacheEntry<T>(data, ttl);
  }

  static Future<void> _invalidateCache(String key) async {
    _cache.remove(key);
    await StorageService.deleteCache(key);
  }

  /// Wipe all caches (memory and Hive). Used on logout.
  static Future<void> clearCache() async {
    _cache.clear();
    await StorageService.clearCache();
  }

  static Future<void> _invalidateCachePrefix(String prefix) async {
    _cache.removeWhere((k, _) => k.startsWith(prefix));
    await StorageService.deleteCacheByPrefix(prefix);
  }

  /// Clear all marketplace caches.
  static void invalidateMarketplaceCache() => _invalidateCachePrefix('mkt_');

  /// Clear events caches.
  static void invalidateEventsCache() => _invalidateCachePrefix('events_');

  /// 3-tier cached fetch: in-memory → network (+persist) → Hive fallback.
  ///
  /// [key] - cache key for both in-memory and Hive.
  /// [fetcher] - async function that returns raw JSON data from the API.
  /// [parser] - converts raw JSON to the desired type T.
  /// [ttl] - time-to-live for in-memory cache.
  static Future<T?> _cachedFetch<T>({
    required String key,
    required Future<dynamic> Function() fetcher,
    required T Function(dynamic json) parser,
    required Duration ttl,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      // 1. In-memory cache hit
      final memCached = getCached<T>(key);
      if (memCached != null) {
        debugPrint('Cache Memory HIT: $key');
        return memCached;
      }

      // 2. Persistent (Hive) cache hit - if not expired
      try {
        final persisted = StorageService.readCache(key);
        if (persisted != null) {
          final timestamp = StorageService.getCacheTimestamp(key);
          final now = DateTime.now();
          final isFresh = timestamp != null && now.difference(timestamp) < ttl;

          if (isFresh) {
            debugPrint('Cache Hive HIT (FRESH): $key');
            final rawJson = jsonDecode(persisted as String);
            final result = parser(rawJson);
            // Warm in-memory cache
            _setCache(key, result, ttl);
            return result;
          }
          debugPrint('Cache Hive STALE: $key (timestamp: $timestamp)');
        }
      } catch (e) {
        debugPrint('Hive read error for $key: $e');
      }
    } else {
      debugPrint('Cache BYPASS (Force Refresh): $key');
    }

    // 3. Try network fetch
    debugPrint('Cache MISS/REFRESH: Fetching from network: $key');
    try {
      final rawJson = await fetcher();
      if (rawJson != null) {
        final result = parser(rawJson);
        _setCache(key, result, ttl);
        // Persist raw JSON to Hive with current timestamp
        StorageService.writeCache(key, jsonEncode(rawJson));
        return result;
      }
    } catch (e) {
      debugPrint('Network fetch failed for $key: $e');
    }

    // 4. Hive fallback (even if stale) as last resort
    if (!forceRefresh) {
      try {
        final persisted = StorageService.readCache(key);
        if (persisted != null) {
          debugPrint('Cache Hive FALLBACK (STALE): $key');
          final rawJson = jsonDecode(persisted as String);
          final result = parser(rawJson);
          // Warm in-memory cache briefly
          _setCache(key, result, const Duration(minutes: 1));
          return result;
        }
      } catch (e) {
        debugPrint('Hive fallback failed for $key: $e');
      }
    }

    return null;
  }

  // ── Auth & Session ────────────────────────────────────────────────────────

  /// Sync user details with the backend database.
  Future<String?> syncUser({
    required String authStudentId,
    required String email,
    required String name,
    required String firebaseIdToken,
    String? image,
    String? fcmToken,
  }) async {
    try {
      final response = await _post(
        AppConstants.syncUser,
        body: {
          'authStudentId': authStudentId,
          'email': email,
          'name': name,
          'image': image,
          'fcmToken': fcmToken,
        },
        headers: {'Authorization': 'Bearer $firebaseIdToken'},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final userData = responseData['data']?['user'];
        return userData?['id']?.toString();
      }
      debugPrint(
        'Sync failed: Status ${response.statusCode}, Body: ${response.body}',
      );
      return null;
    } catch (e) {
      debugPrint('Error syncing user: $e');
      return null;
    }
  }

  /// Clear FCM token on logout.
  Future<void> clearFcmToken(String? firebaseIdToken) async {
    if (firebaseIdToken == null) return;
    try {
      await _post(
        AppConstants.clearFcmToken,
        headers: {'Authorization': 'Bearer $firebaseIdToken'},
      );
    } catch (e) {
      debugPrint('Error clearing FCM token: $e');
    }
  }

  /// Update FCM token for a user.
  Future<void> updateFcmToken({
    required String fcmToken,
    required String firebaseIdToken,
  }) async {
    try {
      await _post(
        AppConstants.updateFcmToken,
        body: {'fcmToken': fcmToken},
        headers: {'Authorization': 'Bearer $firebaseIdToken'},
      );
    } catch (e) {
      debugPrint('Error updating FCM token: $e');
    }
  }

  /// Fetch the current user role from the backend.
  Future<String> getUserRole() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return 'guest';

    try {
      final token = await currentUser.getIdToken();
      final response = await _get(
        AppConstants.userProfile,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final role = responseData['data']?['user']?['role'];
        if (role != null) return role.toString();
      }
    } catch (e) {
      debugPrint('Error fetching user role: $e');
    }

    return 'student'; // Fallback
  }

  /// Force refresh the user role from the backend.
  Future<void> refreshUserRole() async {
    await _invalidateCache(AppConstants.userRoleKey);
    await getUserRole();
  }

  /// Get the database user ID from local storage.
  Future<String?> getDbUserId() async {
    return await StorageService.readSecure(AppConstants.dbUserIdKey);
  }

  /// Get current user's student profile (for faculty-based notifications etc.)
  Future<StudentProfile?> getStudentProfile() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return null;

      final token = await currentUser.getIdToken();
      final response = await _get(
        AppConstants.studentProfile,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        if (responseData['data']?['success'] == true &&
            responseData['data']?['profile'] != null) {
          return StudentProfile.fromJson(
            responseData['data']['profile'] as Map<String, dynamic>,
          );
        }
      }
    } catch (e) {
      debugPrint('Error fetching student profile: $e');
    }
    return null;
  }

  // ── Generic Request Helpers ───────────────────────────────────────────────

  Future<http.Response> _get(
    String path, {
    Map<String, String>? headers,
    Map<String, String>? queryParams,
  }) async {
    var url = Uri.parse('${AppConstants.fullApiUrl}$path');
    if (queryParams != null && queryParams.isNotEmpty) {
      url = url.replace(queryParameters: queryParams);
    }
    final combinedHeaders = await _getHeaders(headers);
    return await _client.get(url, headers: combinedHeaders);
  }

  Future<http.Response> _post(
    String path, {
    dynamic body,
    Map<String, String>? headers,
  }) async {
    final url = Uri.parse('${AppConstants.fullApiUrl}$path');
    final combinedHeaders = await _getHeaders(headers);
    return await _client.post(
      url,
      headers: combinedHeaders,
      body: body != null ? jsonEncode(body) : null,
    );
  }

  Future<http.Response> _put(
    String path, {
    dynamic body,
    Map<String, String>? headers,
  }) async {
    final url = Uri.parse('${AppConstants.fullApiUrl}$path');
    final combinedHeaders = await _getHeaders(headers);
    return await _client.put(
      url,
      headers: combinedHeaders,
      body: body != null ? jsonEncode(body) : null,
    );
  }

  Future<http.Response> _delete(
    String path, {
    dynamic body,
    Map<String, String>? headers,
  }) async {
    final url = Uri.parse('${AppConstants.fullApiUrl}$path');
    final combinedHeaders = await _getHeaders(headers);
    return await _client.delete(
      url,
      headers: combinedHeaders,
      body: body != null ? jsonEncode(body) : null,
    );
  }

  Future<http.Response> _patch(
    String path, {
    dynamic body,
    Map<String, String>? headers,
  }) async {
    final url = Uri.parse('${AppConstants.fullApiUrl}$path');
    final combinedHeaders = await _getHeaders(headers);
    return await _client.patch(
      url,
      headers: combinedHeaders,
      body: body != null ? jsonEncode(body) : null,
    );
  }

  Future<Map<String, String>> _getHeaders(Map<String, String>? extra) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (extra != null) headers.addAll(extra);
    return headers;
  }

  /// Process image URLs to handle Google Drive and Cloudinary optimizations.
  static String? processImageUrl(
    String? url, {
    int? width,
    bool optimizeCloudinary = true,
  }) {
    if (url == null || url.isEmpty) return null;
    final normalizedUrl = url.trim();

    // Handle Google Drive links
    if (normalizedUrl.contains('drive.google.com')) {
      final regExp = RegExp(r'\/file\/d\/([^\/]+)\/');
      final match = regExp.firstMatch(normalizedUrl);
      if (match != null && match.groupCount >= 1) {
        final fileId = match.group(1);
        return 'https://docs.google.com/uc?export=download&id=$fileId';
      }
    }

    // Handle relative paths returned by backend (e.g., /uploads/.. or uploads/..)
    if (normalizedUrl.startsWith('/')) {
      return '${AppConstants.baseUrl}$normalizedUrl';
    }
    final parsed = Uri.tryParse(normalizedUrl);
    if (parsed != null &&
        !parsed.hasScheme &&
        parsed.host.isEmpty &&
        !normalizedUrl.startsWith('data:')) {
      return '${AppConstants.baseUrl}/${normalizedUrl.replaceFirst(RegExp(r'^/+'), '')}';
    }

    // Handle Cloudinary optimizations
    if (optimizeCloudinary &&
        normalizedUrl.contains('cloudinary.com') &&
        normalizedUrl.contains('/upload/')) {
      final transform =
          'f_auto,q_auto${width != null ? ',w_$width,c_limit' : ''}';
      return normalizedUrl.replaceFirst('/upload/', '/upload/$transform/');
    }

    return normalizedUrl;
  }

  /// Whether a URL belongs to a social media CDN that might have restricted access or headers.
  static bool isSocialMediaDomain(String? url) {
    if (url == null || url.isEmpty) return false;
    final socialDomains = [
      'fbcdn.net',
      'akamaihd.net',
      'instagram.com',
      'twimg.com',
      'googleusercontent.com',
    ];
    return socialDomains.any((domain) => url.toLowerCase().contains(domain));
  }

  /// Get auth headers with Firebase ID token attached.
  Future<Map<String, String>> _getAuthHeaders() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return {};
    final token = await currentUser.getIdToken();
    return {'Authorization': 'Bearer $token'};
  }

  /// Make an authenticated GET request.
  Future<http.Response> _authGet(
    String path, {
    Map<String, String>? queryParams,
  }) async {
    return _get(
      path,
      headers: await _getAuthHeaders(),
      queryParams: queryParams,
    );
  }

  /// Make an authenticated POST request.
  Future<http.Response> _authPost(String path, {dynamic body}) async {
    return _post(path, body: body, headers: await _getAuthHeaders());
  }

  /// Make an authenticated PUT request.
  Future<http.Response> _authPut(String path, {dynamic body}) async {
    return _put(path, body: body, headers: await _getAuthHeaders());
  }

  /// Make an authenticated DELETE request.
  Future<http.Response> _authDelete(String path, {dynamic body}) async {
    return _delete(path, body: body, headers: await _getAuthHeaders());
  }

  /// Make an authenticated PATCH request.
  Future<http.Response> _authPatch(String path, {dynamic body}) async {
    return _patch(path, body: body, headers: await _getAuthHeaders());
  }

  // ── Book Marketplace ─────────────────────────────────────────────────────

  /// Get paginated book listings with optional filters.
  Future<BookListingsResponse?> getBookListings({
    BookFilters? filters,
    bool forceRefresh = false,
  }) async {
    // Cache only the default first-page request (no search/filters)
    final isDefaultRequest =
        filters == null ||
        (filters.page == 1 &&
            filters.search == null &&
            filters.categoryId == null &&
            filters.condition == null &&
            filters.sellerId == null &&
            filters.sortBy == 'newest');

    if (isDefaultRequest) {
      return _cachedFetch<BookListingsResponse>(
        key: AppConstants.cacheBookListings,
        ttl: AppConstants.cacheExpiry,
        forceRefresh: forceRefresh,
        fetcher: () async {
          final queryParams =
              filters?.toQueryParams() ?? {'page': '1', 'limit': '12'};
          final response = await _authGet(
            AppConstants.books,
            queryParams: queryParams,
          );
          if (response.statusCode == 200) {
            final json = jsonDecode(response.body);
            if (json['success'] == true && json['data'] != null) {
              return json['data'];
            }
          }
          return null;
        },
        parser: (data) =>
            BookListingsResponse.fromJson(data as Map<String, dynamic>),
      );
    }

    // Non-default requests: no caching
    try {
      final queryParams = filters.toQueryParams();
      final response = await _authGet(
        AppConstants.books,
        queryParams: queryParams,
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] != null) {
          return BookListingsResponse.fromJson(
            json['data'] as Map<String, dynamic>,
          );
        }
      }
    } catch (e) {
      debugPrint('Error fetching book listings: $e');
    }
    return null;
  }

  /// Get a single book listing by ID.
  Future<BookListing?> getBookListingById(
    int id, {
    bool forceRefresh = false,
  }) async {
    return _cachedFetch<BookListing>(
      key: '${AppConstants.cacheBookDetail}$id',
      ttl: AppConstants.cacheExpiry,
      forceRefresh: forceRefresh,
      fetcher: () async {
        final response = await _authGet('/books/listings/$id');
        if (response.statusCode == 200) {
          final json = jsonDecode(response.body);
          if (json['success'] == true && json['data'] != null) {
            return json['data'];
          }
        }
        return null;
      },
      parser: (data) => BookListing.fromJson(data as Map<String, dynamic>),
    );
  }

  /// Create a new book listing.
  Future<Map<String, dynamic>> createBookListing({
    required String title,
    required String author,
    required String condition,
    required String price,
    String? isbn,
    String? edition,
    String? publisher,
    int? publicationYear,
    String? description,
    String? courseCode,
    String? buyerContactInfo,
    int? categoryId,
  }) async {
    try {
      final response = await _authPost(
        AppConstants.books,
        body: {
          'title': title,
          'author': author,
          'condition': condition,
          'price': price,
          'isbn': isbn,
          'edition': edition,
          'publisher': publisher,
          'publicationYear': publicationYear,
          'description': description,
          'courseCode': courseCode,
          'buyerContactInfo': buyerContactInfo,
          'categoryId': categoryId,
        }..removeWhere((k, v) => v == null),
      );

      final json = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        _invalidateCache(AppConstants.cacheMyListings);
        _invalidateCache(AppConstants.cacheBookListings);
        return {
          'success': json['success'] == true,
          'data': json['data'] != null
              ? BookListing.fromJson(json['data'] as Map<String, dynamic>)
              : null,
          'message': json['message'],
        };
      }
      return {
        'success': false,
        'message': json['message'] ?? 'Failed to create listing',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Update an existing book listing.
  Future<Map<String, dynamic>> updateBookListing(
    int id,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _authPut('/books/listings/$id', body: data);
      final json = jsonDecode(response.body);
      if (json['success'] == true) {
        _invalidateCache(AppConstants.cacheMyListings);
        _invalidateCache(AppConstants.cacheBookListings);
        _invalidateCache('${AppConstants.cacheBookDetail}$id');
      }
      return {
        'success': json['success'] == true,
        'data': json['data'] != null
            ? BookListing.fromJson(json['data'] as Map<String, dynamic>)
            : null,
        'message': json['message'],
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Delete a book listing.
  Future<Map<String, dynamic>> deleteBookListing(int id) async {
    try {
      final response = await _authDelete('/books/listings/$id');
      final json = jsonDecode(response.body);
      if (json['success'] == true) {
        _invalidateCache(AppConstants.cacheMyListings);
        _invalidateCache(AppConstants.cacheBookListings);
        _invalidateCache('${AppConstants.cacheBookDetail}$id');
      }
      return {'success': json['success'] == true, 'message': json['message']};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Get the current user's book listings.
  Future<List<BookListing>> getMyBookListings({
    bool forceRefresh = false,
  }) async {
    return await _cachedFetch<List<BookListing>>(
          key: AppConstants.cacheMyListings,
          ttl: AppConstants.cacheExpiry,
          forceRefresh: forceRefresh,
          fetcher: () async {
            final response = await _authGet('/books/my-listings');
            if (response.statusCode == 200) {
              final json = jsonDecode(response.body);
              if (json['success'] == true && json['data'] != null) {
                return json['data'];
              }
            }
            return null;
          },
          parser: (data) => (data as List)
              .map((e) => BookListing.fromJson(e as Map<String, dynamic>))
              .toList(),
        ) ??
        [];
  }

  /// Mark a book as sold.
  Future<Map<String, dynamic>> markBookAsSold(int id) async {
    try {
      final response = await _authPut('/books/listings/$id/mark-sold');
      final json = jsonDecode(response.body);
      if (json['success'] == true) {
        _invalidateCache(AppConstants.cacheMyListings);
        _invalidateCache(AppConstants.cacheBookListings);
        _invalidateCache('${AppConstants.cacheBookDetail}$id');
      }
      return {'success': json['success'] == true, 'message': json['message']};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Upload a book image using multipart request.
  Future<Map<String, dynamic>> uploadBookImage(
    int listingId,
    String filePath,
  ) async {
    try {
      final authHeaders = await _getAuthHeaders();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(
          '${AppConstants.fullApiUrl}/books/listings/$listingId/images',
        ),
      );
      request.headers.addAll(authHeaders);
      request.files.add(await http.MultipartFile.fromPath('image', filePath));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final json = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (json['success'] == true) {
          _invalidateCache('${AppConstants.cacheBookDetail}$listingId');
        }
        return {
          'success': json['success'] == true,
          'data': json['data'] != null
              ? BookImage.fromJson(json['data'] as Map<String, dynamic>)
              : null,
        };
      }
      return {'success': false, 'message': json['message'] ?? 'Upload failed'};
    } catch (e) {
      return {'success': false, 'message': 'Upload error: $e'};
    }
  }

  /// Delete a book image.
  Future<Map<String, dynamic>> deleteBookImage(
    int listingId,
    int imageId,
  ) async {
    try {
      final response = await _authDelete(
        '/books/listings/$listingId/images/$imageId',
      );
      final json = jsonDecode(response.body);
      return {'success': json['success'] == true, 'message': json['message']};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Get book categories.
  Future<List<BookCategory>> getBookCategories({
    bool forceRefresh = false,
  }) async {
    return await _cachedFetch<List<BookCategory>>(
          key: AppConstants.cacheBookCategories,
          ttl: AppConstants.longCacheExpiry,
          forceRefresh: forceRefresh,
          fetcher: () async {
            final response = await _get(AppConstants.bookCategories);
            if (response.statusCode == 200) {
              final json = jsonDecode(response.body);
              if (json['success'] == true && json['data'] != null) {
                return json['data'];
              }
            }
            return null;
          },
          parser: (data) => (data as List)
              .map((e) => BookCategory.fromJson(e as Map<String, dynamic>))
              .toList(),
        ) ??
        [];
  }

  // ── Saved Books ──────────────────────────────────────────────────────────

  /// Get the user's saved books.
  Future<List<SavedBook>> getSavedBooks({bool forceRefresh = false}) async {
    return await _cachedFetch<List<SavedBook>>(
          key: AppConstants.cacheSavedBooks,
          ttl: AppConstants.cacheExpiry,
          forceRefresh: forceRefresh,
          fetcher: () async {
            final response = await _authGet(AppConstants.savedBooks);
            if (response.statusCode == 200) {
              final json = jsonDecode(response.body);
              if (json['success'] == true && json['data'] != null) {
                return json['data'];
              }
            }
            return null;
          },
          parser: (data) => (data as List)
              .map((e) => SavedBook.fromJson(e as Map<String, dynamic>))
              .toList(),
        ) ??
        [];
  }

  /// Save a book listing.
  Future<Map<String, dynamic>> saveBook(int listingId) async {
    try {
      // Backend controller SaveBook requires listingId in body
      final response = await _authPost(
        '/books/listings/$listingId/save',
        body: {'listingId': listingId},
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _invalidateCache(AppConstants.cacheSavedBooks);
        _invalidateCache(AppConstants.cacheBookListings);
        _invalidateCache('${AppConstants.cacheBookDetail}$listingId');
        final json = jsonDecode(response.body);
        return {'success': json['success'] == true, 'message': json['message']};
      }

      return {
        'success': false,
        'message': 'Failed to save book (${response.statusCode})',
      };
    } catch (e) {
      debugPrint('Error in saveBook: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Unsave a book listing.
  Future<Map<String, dynamic>> unsaveBook(int listingId) async {
    try {
      // Backend controller UnsaveBook uses the ID in the URL
      final response = await _authDelete('/books/listings/$listingId/save');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _invalidateCache(AppConstants.cacheSavedBooks);
        _invalidateCache(AppConstants.cacheBookListings);
        _invalidateCache('${AppConstants.cacheBookDetail}$listingId');
        return {'success': true, 'message': 'Removed from saved'};
      }

      return {
        'success': false,
        'message': 'Failed to unsave book (${response.statusCode})',
      };
    } catch (e) {
      debugPrint('Error in unsaveBook: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // ── Purchase Requests ────────────────────────────────────────────────────

  /// Create a purchase request for a listing.
  Future<Map<String, dynamic>> createPurchaseRequest(
    int listingId,
    String? message,
  ) async {
    try {
      final response = await _authPost(
        '/books/listings/$listingId/request',
        body: {'message': message},
      );
      final json = jsonDecode(response.body);
      if (json['success'] == true) {
        _invalidateCache(AppConstants.cacheMyRequests);
        _invalidateCache(AppConstants.cacheIncomingRequests);
      }
      return {
        'success': json['success'] == true,
        'message': json['message'],
        'data': json['data'],
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Get purchase requests for a specific listing (seller's view).
  Future<List<BookPurchaseRequest>> getListingRequests(int listingId) async {
    try {
      final response = await _authGet('/books/listings/$listingId/requests');
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] != null) {
          return (json['data'] as List)
              .map(
                (e) => BookPurchaseRequest.fromJson(e as Map<String, dynamic>),
              )
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Error fetching listing requests: $e');
    }
    return [];
  }

  /// Get seller contact info for a specific listing (buyer's view, after acceptance).
  Future<Map<String, dynamic>> getSellerContactInfo(int listingId) async {
    try {
      final response = await _authGet(
        '/books/listings/$listingId/contact-info',
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return {
          'success': json['success'] == true,
          'message': json['message'],
          'data': json['data'],
        };
      }
      final errorJson = jsonDecode(response.body);
      return {
        'success': false,
        'message':
            errorJson['message'] ??
            'Failed to fetch contact info (${response.statusCode})',
      };
    } catch (e) {
      debugPrint('Error fetching seller contact info: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Get current user's outgoing purchase requests.
  Future<List<BookPurchaseRequest>> getMyPurchaseRequests({
    bool forceRefresh = false,
  }) async {
    return await _cachedFetch<List<BookPurchaseRequest>>(
          key: AppConstants.cacheMyRequests,
          ttl: AppConstants.cacheExpiry,
          forceRefresh: forceRefresh,
          fetcher: () async {
            final response = await _authGet(AppConstants.myPurchaseRequests);
            if (response.statusCode == 200) {
              final json = jsonDecode(response.body);
              if (json['success'] == true && json['data'] != null) {
                return json['data'];
              }
            }
            return null;
          },
          parser: (data) => (data as List)
              .map(
                (e) => BookPurchaseRequest.fromJson(e as Map<String, dynamic>),
              )
              .toList(),
        ) ??
        [];
  }

  /// Get all incoming purchase requests for current user's listings.
  Future<List<BookPurchaseRequest>> getIncomingPurchaseRequests({
    bool forceRefresh = false,
  }) async {
    return await _cachedFetch<List<BookPurchaseRequest>>(
          key: AppConstants.cacheIncomingRequests,
          ttl: AppConstants.cacheExpiry,
          forceRefresh: forceRefresh,
          fetcher: () async {
            final response = await _authGet('/books/requests/incoming');
            if (response.statusCode == 200) {
              final json = jsonDecode(response.body);
              if (json['success'] == true && json['data'] != null) {
                return json['data'];
              }
            }
            return null;
          },
          parser: (data) => (data as List)
              .map(
                (e) => BookPurchaseRequest.fromJson(e as Map<String, dynamic>),
              )
              .toList(),
        ) ??
        [];
  }

  /// Get status of user's request for a specific listing.
  Future<BookPurchaseRequest?> getPurchaseRequestStatus(
    int listingId, {
    bool forceRefresh = false,
  }) async {
    return _cachedFetch<BookPurchaseRequest>(
      key: '${AppConstants.cacheRequestStatus}$listingId',
      ttl: const Duration(
        seconds: 30,
      ), // Short TTL: status changes are time-sensitive
      forceRefresh: forceRefresh,
      fetcher: () async {
        final response = await _authGet(
          '/books/listings/$listingId/request-status',
        );
        if (response.statusCode == 200) {
          final json = jsonDecode(response.body);
          if (json['success'] == true && json['data'] != null) {
            return json['data'];
          }
        }
        return null;
      },
      parser: (data) =>
          BookPurchaseRequest.fromJson(data as Map<String, dynamic>),
    );
  }

  /// Respond to a purchase request (accept/reject).
  Future<Map<String, dynamic>> respondToPurchaseRequest(
    int requestId,
    bool accept, {
    int? listingId,
  }) async {
    try {
      final response = await _authPut(
        '/books/requests/$requestId/respond',
        body: {'accept': accept},
      );
      final json = jsonDecode(response.body);
      if (json['success'] == true) {
        _invalidateCache(AppConstants.cacheIncomingRequests);
        _invalidateCache(AppConstants.cacheMyRequests);
        _invalidateCache('notifications_list'); // New
        if (listingId != null) {
          _invalidateCache('${AppConstants.cacheBookDetail}$listingId');
          _invalidateCache('${AppConstants.cacheRequestStatus}$listingId');
        }
      }
      return {'success': json['success'] == true, 'message': json['message']};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Cancel a purchase request.
  Future<Map<String, dynamic>> cancelPurchaseRequest(int requestId) async {
    try {
      final response = await _authDelete('/books/requests/$requestId');
      final json = jsonDecode(response.body);
      if (json['success'] == true) {
        _invalidateCache(AppConstants.cacheMyRequests);
        _invalidateCache(AppConstants.cacheIncomingRequests);
      }
      return {'success': json['success'] == true, 'message': json['message']};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Permanently delete a purchase request from history.
  Future<Map<String, dynamic>> deletePurchaseRequest(int requestId) async {
    try {
      final response = await _authDelete('/books/requests/$requestId/delete');
      final json = jsonDecode(response.body);
      if (json['success'] == true) {
        _invalidateCache(AppConstants.cacheMyRequests);
        _invalidateCache(AppConstants.cacheIncomingRequests);
      }
      return {'success': json['success'] == true, 'message': json['message']};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Bulk delete purchase requests.
  Future<Map<String, dynamic>> deleteMultiplePurchaseRequests(
    List<int> requestIds,
  ) async {
    try {
      final response = await _authDelete(
        '/books/requests/bulk-delete',
        body: {'requestIds': requestIds},
      );
      final json = jsonDecode(response.body);
      if (json['success'] == true) {
        _invalidateCache(AppConstants.cacheMyRequests);
        _invalidateCache(AppConstants.cacheIncomingRequests);
      }
      return {
        'success': json['success'] == true,
        'message': json['message'],
        'deletedCount': json['deletedCount'],
      };
    } catch (e) {
      debugPrint('Error in deleteMultiplePurchaseRequests: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // ── Trust & Safety ────────────────────────────────────────────────────────

  /// Get a seller's reputation data.
  Future<SellerReputation?> getSellerReputation(String sellerId) async {
    return _cachedFetch<SellerReputation>(
      key: '${AppConstants.cacheSellerReputation}$sellerId',
      ttl: AppConstants.cacheExpiry,
      fetcher: () async {
        final response = await _authGet(
          '/books/trust/sellers/$sellerId/reputation',
        );
        if (response.statusCode == 200) {
          final json = jsonDecode(response.body);
          if (json['success'] == true && json['data'] != null) {
            return json['data'];
          }
        }
        return null;
      },
      parser: (data) => SellerReputation.fromJson(data as Map<String, dynamic>),
    );
  }

  /// Rate a seller for a specific listing.
  Future<Map<String, dynamic>> rateSeller({
    required String sellerId,
    required int listingId,
    required int rating,
    String? review,
  }) async {
    try {
      final response = await _authPost(
        '/books/trust/sellers/$sellerId/rate',
        body: {'listingId': listingId, 'rating': rating, 'review': review}
          ..removeWhere((k, v) => v == null),
      );
      final json = jsonDecode(response.body);
      if (json['success'] == true) {
        _invalidateCache('${AppConstants.cacheSellerReputation}$sellerId');
      }
      return json;
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Block a user in the marketplace.
  Future<Map<String, dynamic>> blockMarketplaceUser(
    String userId, {
    String? reason,
  }) async {
    try {
      final response = await _authPost(
        '/books/trust/users/$userId/block',
        body: {'reason': reason},
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Unblock a user in the marketplace.
  Future<Map<String, dynamic>> unblockMarketplaceUser(String userId) async {
    try {
      final response = await _authDelete('/books/trust/users/$userId/block');
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Get the current user's blocked users list.
  Future<List<BlockedUser>> getBlockedMarketplaceUsers() async {
    try {
      final response = await _authGet(AppConstants.trustBlockedUsers);
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] != null) {
          return (json['data'] as List)
              .map((e) => BlockedUser.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Error fetching blocked users: $e');
    }
    return [];
  }

  /// Create a marketplace report (flag a listing or user).
  Future<Map<String, dynamic>> createMarketplaceReport({
    required String reportedUserId,
    int? listingId,
    required String category,
    required String description,
  }) async {
    try {
      final response = await _authPost(
        AppConstants.trustReports,
        body: {
          'reportedUserId': reportedUserId,
          'listingId': listingId,
          'category': category,
          'description': description,
        }..removeWhere((k, v) => v == null),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Get current user's marketplace reports.
  Future<List<MarketplaceReport>> getMyMarketplaceReports() async {
    try {
      final response = await _authGet(AppConstants.trustMyReports);
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] != null) {
          return (json['data'] as List)
              .map((e) => MarketplaceReport.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Error fetching my reports: $e');
    }
    return [];
  }

  // ── Chat & Messaging ─────────────────────────────────────────────────────

  /// Get all active conversations for the current user.
  Future<List<Conversation>> getConversations() async {
    return await _cachedFetch<List<Conversation>>(
          key: AppConstants.cacheConversations,
          ttl: AppConstants.shortCacheExpiry,
          fetcher: () async {
            final response = await _authGet('/chat/conversations');
            if (response.statusCode == 200) {
              final json = jsonDecode(response.body);
              if (json['success'] == true && json['data'] != null) {
                return json['data'];
              }
            }
            return null;
          },
          parser: (data) => (data as List)
              .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
              .toList(),
        ) ??
        [];
  }

  /// Get message history for a specific conversation.
  Future<List<ChatMessage>> getMessages(
    int conversationId, {
    bool forceRefresh = false,
  }) async {
    return await _cachedFetch<List<ChatMessage>>(
          key: '${AppConstants.cacheMessages}$conversationId',
          ttl: const Duration(seconds: 30), // Reduced TTL for chat
          forceRefresh: forceRefresh,
          fetcher: () async {
            final response = await _authGet(
              '/chat/conversations/$conversationId/messages',
            );
            if (response.statusCode == 200) {
              final json = jsonDecode(response.body);
              if (json['success'] == true && json['data'] != null) {
                return json['data'];
              }
            }
            return null;
          },
          parser: (data) => (data as List)
              .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
              .toList(),
        ) ??
        [];
  }

  /// Send a new message.
  Future<Map<String, dynamic>> sendMessage({
    int? conversationId,
    int? listingId,
    String? receiverId,
    required String content,
  }) async {
    try {
      final path = conversationId != null
          ? '/chat/conversations/$conversationId/messages'
          : '/chat/send';

      final body = {
        'content': content,
        'listingId': listingId,
        'receiverId': receiverId,
      }..removeWhere((k, v) => v == null);

      final response = await _authPost(path, body: body);
      final result = jsonDecode(response.body);
      if (result['success'] == true) {
        _invalidateCache(AppConstants.cacheConversations);
        if (conversationId != null) {
          _invalidateCache('${AppConstants.cacheMessages}$conversationId');
        }
      }
      return result;
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Delete a conversation.
  Future<Map<String, dynamic>> deleteConversation(int conversationId) async {
    try {
      final response = await _authDelete('/chat/conversations/$conversationId');
      final result = jsonDecode(response.body);
      if (result['success'] == true) {
        _invalidateCache(AppConstants.cacheConversations);
        _invalidateCache('${AppConstants.cacheMessages}$conversationId');
      }
      return result;
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // ── Notification Endpoints ──────────────────────────────────────────────

  /// Get paginated in-app notifications.
  Future<List<InAppNotification>> getNotifications({
    int limit = 20,
    int offset = 0,
    bool forceRefresh = false,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    final result = await ApiService._cachedFetch<List<InAppNotification>>(
      key: 'notifications_list_${uid}_${limit}_$offset',
      ttl: const Duration(minutes: 5),
      forceRefresh: forceRefresh,
      fetcher: () async {
        final response = await _authGet(
          '/notifications?limit=$limit&offset=$offset',
        );
        if (response.statusCode == 200) {
          final json = jsonDecode(response.body);
          if (json['success'] == true && json['data'] != null) {
            return json['data'];
          }
        }
        return null;
      },
      parser: (data) => (data as List)
          .map((e) => InAppNotification.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
    return result ?? [];
  }

  Future<bool> markNotificationRead(int id) async {
    try {
      final response = await _authPatch('/notifications/$id/read');
      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          _invalidateCachePrefix('notifications_');
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('Error marking notification read: $e');
      return false;
    }
  }

  Future<bool> deleteNotification(int id) async {
    try {
      final response = await _authDelete('/notifications/$id');
      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          _invalidateCachePrefix('notifications_');
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting notification: $e');
      return false;
    }
  }

  /// Mark all notifications as read.
  Future<bool> markAllNotificationsRead() async {
    try {
      var response = await _authPost('/notifications/mark-all-read');

      // Fallback: If POST returns 404/405, try PUT as a safety measure for different environments
      if (response.statusCode == 404 || response.statusCode == 405) {
        response = await _authPut('/notifications/mark-all-read');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          _invalidateCachePrefix('notifications_');
          return true;
        }
      }
      debugPrint(
        'Failed to mark all read: Status ${response.statusCode}, Body: ${response.body}',
      );
      return false;
    } catch (e) {
      debugPrint('Error marking all notifications read: $e');
      return false;
    }
  }

  // ── Classroom Endpoints ──────────────────────────────────────────────────

  /// Get list of all faculties.
  Future<List<Faculty>> getFaculties({bool forceRefresh = false}) async {
    return await _cachedFetch<List<Faculty>>(
          key: AppConstants.cacheClassroomFaculties,
          ttl: AppConstants.longCacheExpiry,
          forceRefresh: forceRefresh,
          fetcher: () async {
            final response = await _authGet(AppConstants.classroomFaculties);
            if (response.statusCode == 200) {
              final json = jsonDecode(response.body);
              if (json['success'] == true && json['faculties'] != null) {
                return json['faculties'];
              }
            }
            return null;
          },
          parser: (data) => (data as List)
              .map((e) => Faculty.fromJson(e as Map<String, dynamic>))
              .toList(),
        ) ??
        [];
  }

  /// Get subjects for a faculty and optional semester.
  Future<List<Subject>> getSubjectsByFaculty(
    int facultyId, {
    int? semester,
    bool forceRefresh = false,
  }) async {
    final queryParams = {'facultyId': facultyId.toString()};
    if (semester != null) queryParams['semester'] = semester.toString();

    return await _cachedFetch<List<Subject>>(
          key:
              '${AppConstants.cacheClassroomSubjectDetails}${facultyId}_$semester',
          ttl: AppConstants.cacheExpiry,
          forceRefresh: forceRefresh,
          fetcher: () async {
            final response = await _authGet(
              AppConstants.classroomSubjects,
              queryParams: queryParams,
            );
            if (response.statusCode == 200) {
              final json = jsonDecode(response.body);
              if (json['success'] == true && json['subjects'] != null) {
                return json['subjects'];
              }
            }
            return null;
          },
          parser: (data) => (data as List)
              .map((e) => Subject.fromJson(e as Map<String, dynamic>))
              .toList(),
        ) ??
        [];
  }

  /// Get my current subjects (based on profile).
  Future<Map<String, dynamic>> getMyClassroomSubjects({
    bool forceRefresh = false,
  }) async {
    return await _cachedFetch<Map<String, dynamic>>(
          key: AppConstants.cacheClassroomMySubjects,
          ttl: AppConstants.cacheExpiry,
          forceRefresh: forceRefresh,
          fetcher: () async {
            final response = await _authGet(AppConstants.classroomMySubjects);
            if (response.statusCode == 200) {
              final json = jsonDecode(response.body);
              if (json['success'] == true) {
                return json;
              }
            }
            return null;
          },
          parser: (data) => data as Map<String, dynamic>,
        ) ??
        {'success': false, 'message': 'Failed to fetch subjects'};
  }

  /// Update or create student profile.
  Future<Map<String, dynamic>> upsertStudentProfile({
    required int facultyId,
    int? currentSemester,
    DateTime? semesterStartDate,
    bool? autoAdvance,
  }) async {
    try {
      final body = {
        'facultyId': facultyId,
        'currentSemester': currentSemester,
        'semesterStartDate': semesterStartDate?.toIso8601String(),
        'autoAdvance': autoAdvance,
      }..removeWhere((k, v) => v == null);

      final response = await _authPost('/classroom/me', body: body);
      final json = jsonDecode(response.body);
      if (json['success'] == true) {
        _invalidateCache(AppConstants.cacheClassroomMySubjects);
      }
      return json;
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Submit an assignment.
  Future<Map<String, dynamic>> submitAssignment(
    int assignmentId,
    PlatformFile file, {
    String? comment,
  }) async {
    try {
      final url = Uri.parse(
        '${AppConstants.fullApiUrl}/classroom/assignments/$assignmentId/submissions',
      );
      final request = http.MultipartRequest('POST', url);

      request.headers.addAll(await _getAuthHeaders());

      if (comment != null) {
        request.fields['comment'] = comment;
      }

      if (kIsWeb) {
        if (file.bytes == null) {
          return {'success': false, 'message': 'File bytes are null'};
        }
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            file.bytes!,
            filename: file.name,
            contentType: MediaType(
              file.extension == 'pdf' ? 'application' : 'image',
              file.extension == 'pdf'
                  ? 'pdf'
                  : (file.extension ?? 'octet-stream'),
            ),
          ),
        );
      } else {
        if (file.path == null) {
          return {'success': false, 'message': 'File path is null'};
        }
        request.files.add(
          await http.MultipartFile.fromPath(
            'file',
            file.path!,
            contentType: MediaType(
              file.extension == 'pdf' ? 'application' : 'image',
              file.extension == 'pdf'
                  ? 'pdf'
                  : (file.extension ?? 'octet-stream'),
            ),
          ),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      final result = jsonDecode(response.body);
      if (result['success'] == true) {
        _invalidateCache(AppConstants.cacheClassroomMySubjects);
      }
      return result;
    } catch (e) {
      debugPrint('Error submitting assignment: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // ── Teacher Classroom Endpoints ──────────────────────────────────────────

  /// Get teacher's subjects with their assignments.
  Future<List<Subject>> getTeacherSubjects({bool forceRefresh = false}) async {
    return await _cachedFetch<List<Subject>>(
          key: 'cls_teacher_subjects',
          ttl: AppConstants.cacheExpiry,
          forceRefresh: forceRefresh,
          fetcher: () async {
            final response = await _authGet('/classroom/teacher/subjects');
            if (response.statusCode == 200) {
              final json = jsonDecode(response.body);
              if (json['success'] == true && json['subjects'] != null) {
                return json['subjects'];
              }
            }
            return null;
          },
          parser: (data) => (data as List)
              .map((e) => Subject.fromJson(e as Map<String, dynamic>))
              .toList(),
        ) ??
        [];
  }

  /// Add a subject to the teacher's teaching list.
  Future<Map<String, dynamic>> addTeacherSubject(int subjectId) async {
    try {
      final response = await _authPost(
        '/classroom/teacher/subjects',
        body: {'subjectId': subjectId},
      );
      final json = jsonDecode(response.body);
      if (json['success'] == true) {
        _invalidateCache('cls_teacher_subjects');
      }
      return {'success': json['success'] == true, 'message': json['message']};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Create a new assignment for a subject.
  Future<Map<String, dynamic>> createAssignment({
    required int subjectId,
    required String title,
    String? description,
    required String type, // 'classwork' or 'homework'
    DateTime? dueAt,
  }) async {
    try {
      final body = {
        'subjectId': subjectId,
        'title': title,
        'description': description,
        'type': type,
        'dueAt': dueAt?.toIso8601String(),
      }..removeWhere((k, v) => v == null);

      final response = await _authPost(
        AppConstants.classroomAssignments,
        body: body,
      );
      final json = jsonDecode(response.body);
      if (json['success'] == true) {
        _invalidateCache('cls_teacher_subjects');
        _invalidateCache(AppConstants.cacheClassroomMySubjects);
      }
      return {'success': json['success'] == true, 'message': json['message']};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Get all submissions for an assignment (teacher view).
  Future<List<TeacherSubmission>> getAssignmentSubmissions(
    int assignmentId, {
    bool forceRefresh = false,
  }) async {
    return await _cachedFetch<List<TeacherSubmission>>(
          key: 'cls_submissions_$assignmentId',
          ttl: const Duration(minutes: 2), // Frequent updates needed
          forceRefresh: forceRefresh,
          fetcher: () async {
            final response = await _authGet(
              '/classroom/assignments/$assignmentId/submissions',
            );
            if (response.statusCode == 200) {
              final json = jsonDecode(response.body);
              if (json['success'] == true && json['submissions'] != null) {
                return json['submissions'];
              }
            }
            return null;
          },
          parser: (data) => (data as List)
              .map((e) => TeacherSubmission.fromJson(e as Map<String, dynamic>))
              .toList(),
        ) ??
        [];
  }

  /// Get all assignments published by the teacher.
  Future<List<Assignment>> getTeacherAssignments({
    bool forceRefresh = false,
  }) async {
    return await _cachedFetch<List<Assignment>>(
          key: 'cls_teacher_all_assignments',
          ttl: AppConstants.cacheExpiry,
          forceRefresh: forceRefresh,
          fetcher: () async {
            // First, try getting them from subjects (most common case)
            final subjects = await getTeacherSubjects(
              forceRefresh: forceRefresh,
            );
            final nested = subjects
                .expand((s) => s.assignments ?? <Assignment>[])
                .toList();

            // If we found assignments nested, return them as raw maps for the parser/cache
            if (nested.isNotEmpty) {
              return nested.map((a) => a.toJson()).toList();
            }

            // Fallback: Try a direct assignments endpoint if nested fetch failed
            final response = await _authGet(AppConstants.classroomAssignments);
            if (response.statusCode == 200) {
              final json = jsonDecode(response.body);
              if (json['success'] == true && json['assignments'] != null) {
                return json['assignments'];
              }
            }
            return null;
          },
          parser: (data) => (data as List)
              .map((e) => Assignment.fromJson(e as Map<String, dynamic>))
              .toList(),
        ) ??
        [];
  }

  /// Get all notices (with optional filtering and pagination)
  Future<List<Notice>> getNotices({
    String? category,
    String? level,
    String? search,
    int? limit,
    int? offset,
    bool forceRefresh = false,
  }) async {
    final queryParams = <String, String>{};
    if (category != null) queryParams['category'] = category;
    if (level != null) queryParams['level'] = level;
    if (search != null) queryParams['search'] = search;
    if (limit != null) queryParams['limit'] = limit.toString();
    if (offset != null) queryParams['offset'] = offset.toString();

    final queryString = queryParams.isNotEmpty
        ? '?${Uri(queryParameters: queryParams).query}'
        : '';

    return await _cachedFetch<List<Notice>>(
          key: '${AppConstants.cacheNoticesList}$queryString',
          ttl: AppConstants.cacheExpiry,
          forceRefresh: forceRefresh,
          fetcher: () async {
            final response = await _authGet(
              '${AppConstants.notices}$queryString',
            );
            if (response.statusCode == 200) {
              final json = jsonDecode(response.body);
              if (json['success'] == true && json['data'] != null) {
                return json['data'];
              }
            }
            return null;
          },
          parser: (data) => (data as List)
              .map((e) => Notice.fromJson(e as Map<String, dynamic>))
              .toList(),
        ) ??
        [];
  }

  /// Get notice stats
  Future<NoticeStats?> getNoticeStats({bool forceRefresh = false}) async {
    return await _cachedFetch<NoticeStats>(
      key: AppConstants.cacheNoticeStats,
      ttl: AppConstants.longCacheExpiry,
      forceRefresh: forceRefresh,
      fetcher: () async {
        final response = await _authGet(AppConstants.noticeStats);
        if (response.statusCode == 200) {
          final json = jsonDecode(response.body);
          if (json['success'] == true && json['data'] != null) {
            return json['data'];
          }
        }
        return null;
      },
      parser: (data) => NoticeStats.fromJson(data as Map<String, dynamic>),
    );
  }

  /// Create a new notice
  Future<ApiResult> createNotice(Map<String, dynamic> data) async {
    final response = await _authPost(AppConstants.notices, body: data);
    if (response.statusCode == 200 || response.statusCode == 201) {
      _invalidateCachePrefix(AppConstants.cacheNoticesList);
      _invalidateCache(AppConstants.cacheNoticeStats);
      return ApiResult(success: true);
    }
    try {
      return ApiResult(
        success: false,
        error:
            jsonDecode(response.body)['message'] ??
            'Failed to create notice (${response.statusCode})',
      );
    } catch (e) {
      return ApiResult(
        success: false,
        error: 'Failed to create notice (Status ${response.statusCode})',
      );
    }
  }

  /// Update an existing notice
  Future<ApiResult> updateNotice(int id, Map<String, dynamic> data) async {
    final response = await _authPut('${AppConstants.notices}/$id', body: data);
    if (response.statusCode == 200) {
      _invalidateCachePrefix(AppConstants.cacheNoticesList);
      _invalidateCache(AppConstants.cacheNoticeStats);
      return ApiResult(success: true);
    }
    try {
      return ApiResult(
        success: false,
        error:
            jsonDecode(response.body)['message'] ??
            'Failed to update notice (${response.statusCode})',
      );
    } catch (e) {
      return ApiResult(
        success: false,
        error: 'Failed to update notice (Status ${response.statusCode})',
      );
    }
  }

  /// Delete a notice
  Future<ApiResult> deleteNotice(int id) async {
    final response = await _authDelete('${AppConstants.notices}/$id');
    if (response.statusCode == 200) {
      _invalidateCachePrefix(AppConstants.cacheNoticesList);
      _invalidateCache(AppConstants.cacheNoticeStats);
      return ApiResult(success: true);
    }
    try {
      return ApiResult(
        success: false,
        error:
            jsonDecode(response.body)['message'] ??
            'Failed to delete notice (${response.statusCode})',
      );
    } catch (e) {
      return ApiResult(
        success: false,
        error: 'Failed to delete notice (Status ${response.statusCode})',
      );
    }
  }

  /// Upload a notice attachment
  Future<ApiResult<String>> uploadNoticeAttachment(String filePath) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConstants.fullApiUrl}${AppConstants.notices}/upload'),
      );

      final authHeaders = await _getAuthHeaders();
      request.headers.addAll(authHeaders);

      final extension = filePath.split('.').last.toLowerCase();
      String mimeType = 'application/octet-stream';
      if (extension == 'pdf') {
        mimeType = 'application/pdf';
      } else if (['jpg', 'jpeg'].contains(extension)) {
        mimeType = 'image/jpeg';
      } else if (extension == 'png') {
        mimeType = 'image/png';
      } else if (extension == 'webp') {
        mimeType = 'image/webp';
      }

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          filePath,
          contentType: MediaType.parse(mimeType),
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final json = jsonDecode(response.body);
          if (json['success'] == true && json['data'] != null) {
            // Backend returns { success: true, data: { url: "...", name: "..." } }
            final url = json['data']['url'] as String;
            return ApiResult.success(url);
          }
        } catch (e) {
          return ApiResult.failure('Server returned invalid data format');
        }
      }

      // Handle non-JSON errors (like HTML 404s) gracefully
      try {
        final errorMsg =
            jsonDecode(response.body)['message'] ??
            'Failed to upload attachment (${response.statusCode})';
        return ApiResult.failure(errorMsg);
      } catch (e) {
        return ApiResult.failure(
          'Upload failed with status ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error uploading notice attachment: $e');
      return ApiResult.failure('Network or File Error');
    }
  }

  // ── Campus Events ────────────────────────────────────────────────────────

  /// Get all events from the backend.
  Future<List<ClubEvent>> getAllEvents({bool forceRefresh = false}) async {
    return await _cachedFetch<List<ClubEvent>>(
          key: AppConstants.cacheEventsList,
          ttl: AppConstants.cacheExpiry,
          forceRefresh: forceRefresh,
          fetcher: () async {
            final response = await _authGet(AppConstants.eventsAll);
            if (response.statusCode == 200) {
              final json = jsonDecode(response.body);
              if (json['data'] != null && json['data']['allEvents'] != null) {
                return json['data']['allEvents'];
              }
            }
            return null;
          },
          parser: (data) => (data as List)
              .map((e) => ClubEvent.fromJson(e as Map<String, dynamic>))
              .toList(),
        ) ??
        [];
  }

  /// Get cached events synchronously for UI instant load.
  List<ClubEvent>? getCachedEvents() {
    try {
      final persisted = StorageService.readCache(AppConstants.cacheEventsList);
      if (persisted != null) {
        final rawJson = jsonDecode(persisted as String);
        return (rawJson as List)
            .map((e) => ClubEvent.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('Error getting cached events: $e');
    }
    return getCached<List<ClubEvent>>(AppConstants.cacheEventsList);
  }

  /// Get upcoming events from the backend.
  Future<List<ClubEvent>> getUpcomingEvents({bool forceRefresh = false}) async {
    return await _cachedFetch<List<ClubEvent>>(
          key: AppConstants.cacheEventsUpcoming,
          ttl: AppConstants.cacheExpiry,
          forceRefresh: forceRefresh,
          fetcher: () async {
            final response = await _authGet(AppConstants.eventsUpcoming);
            if (response.statusCode == 200) {
              final json = jsonDecode(response.body);
              if (json['data'] != null &&
                  json['data']['upcomingEvents'] != null) {
                return json['data']['upcomingEvents'];
              }
            }
            return null;
          },
          parser: (data) => (data as List)
              .map((e) => ClubEvent.fromJson(e as Map<String, dynamic>))
              .toList(),
        ) ??
        [];
  }

  /// Register student for an event.
  Future<Map<String, dynamic>> registerForEvent(int eventId) async {
    try {
      final response = await _authPost(
        AppConstants.eventsRegister,
        body: {'eventId': eventId},
      );
      final json = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        _invalidateCache(AppConstants.cacheEventsEnrollment);
        return {'success': true, 'data': json['data']};
      }
      return {
        'success': false,
        'message': json['message'] ?? 'Failed to register',
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Cancel event registration.
  Future<Map<String, dynamic>> cancelEventRegistration(int eventId) async {
    try {
      final response = await _authPost(
        AppConstants.eventsCancelRegistration,
        body: {'eventId': eventId},
      );
      final json = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        _invalidateCache(AppConstants.cacheEventsEnrollment);
        return {'success': true, 'data': json['data']};
      }
      return {
        'success': false,
        'message': json['message'] ?? 'Failed to cancel',
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Get current student's active event registrations (enrollment).
  Future<List<EventRegistration>> getStudentEnrollment({
    bool forceRefresh = false,
  }) async {
    return await _cachedFetch<List<EventRegistration>>(
          key: AppConstants.cacheEventsEnrollment,
          ttl: AppConstants.cacheExpiry,
          forceRefresh: forceRefresh,
          fetcher: () async {
            final dbUserId = await getDbUserId();
            final response = await _authPost(
              AppConstants.eventsEnrollment,
              body: {'authStudentId': dbUserId},
            );
            if (response.statusCode == 200) {
              final json = jsonDecode(response.body);
              if (json['data'] != null &&
                  json['data']['registrations'] != null) {
                return json['data']['registrations'];
              }
            }
            return null;
          },
          parser: (data) => (data as List)
              .map((e) => EventRegistration.fromJson(e as Map<String, dynamic>))
              .toList(),
        ) ??
        [];
  }

  /// Get cached enrollment synchronously for UI instant load.
  List<EventRegistration>? getCachedEnrollment() {
    try {
      final persisted = StorageService.readCache(
        AppConstants.cacheEventsEnrollment,
      );
      if (persisted != null) {
        final rawJson = jsonDecode(persisted as String);
        return (rawJson as List)
            .map((e) => EventRegistration.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('Error getting cached enrollment: $e');
    }
    return getCached<List<EventRegistration>>(
      AppConstants.cacheEventsEnrollment,
    );
  }

  Future<List<Club>> getClubs({bool forceRefresh = false}) async {
    return await _cachedFetch<List<Club>>(
          key: AppConstants.cacheClubsList,
          ttl: AppConstants.cacheExpiry,
          forceRefresh: forceRefresh,
          fetcher: () async {
            final response = await _authGet(AppConstants.clubs);
            if (response.statusCode == 200) {
              final json = jsonDecode(response.body);
              if (json['data'] != null &&
                  json['data']['success'] == true &&
                  json['data']['existingClub'] != null) {
                return json['data']['existingClub'];
              }
            }
            return null;
          },
          parser: (data) => (data as List)
              .map((e) => Club.fromJson(e as Map<String, dynamic>))
              .toList(),
        ) ??
        [];
  }

  /// Get a single club by ID.
  Future<Club?> getClub(int id, {bool forceRefresh = false}) async {
    return await _cachedFetch<Club>(
      key: 'club_$id',
      ttl: AppConstants.cacheExpiry,
      forceRefresh: forceRefresh,
      fetcher: () async {
        final response = await _authGet('${AppConstants.clubs}/$id');
        if (response.statusCode == 200) {
          final json = jsonDecode(response.body);
          if (json['data'] != null &&
              json['data']['success'] == true &&
              json['data']['clubData'] != null) {
            return json['data']['clubData'];
          }
        }
        return null;
      },
      parser: (data) => Club.fromJson(data as Map<String, dynamic>),
    );
  }

  /// Get club profile details.
  Future<ClubProfile?> getClubProfile(
    int id, {
    bool forceRefresh = false,
  }) async {
    return await _cachedFetch<ClubProfile>(
      key: '${AppConstants.cacheClubProfile}$id',
      ttl: AppConstants.longCacheExpiry,
      forceRefresh: forceRefresh,
      fetcher: () async {
        final response = await _authGet('${AppConstants.clubProfile}/$id');
        if (response.statusCode == 200) {
          final json = jsonDecode(response.body);
          if (json['success'] == true && json['profile'] != null) {
            return json['profile'];
          }
        }
        return null;
      },
      parser: (data) => ClubProfile.fromJson(data as Map<String, dynamic>),
    );
  }

  /// Get cached club profile synchronously.
  ClubProfile? getCachedClubProfile(int id) {
    final key = '${AppConstants.cacheClubProfile}$id';
    final mem = getCached<ClubProfile>(key);
    if (mem != null) return mem;

    try {
      final persisted = StorageService.readCache(key);
      if (persisted != null) {
        final rawJson = jsonDecode(persisted as String);
        return ClubProfile.fromJson(rawJson as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }

  /// Get events for a specific club.
  Future<List<ClubEvent>> getClubEvents(
    int id, {
    bool forceRefresh = false,
  }) async {
    return await _cachedFetch<List<ClubEvent>>(
          key: '${AppConstants.cacheClubEvents}$id',
          ttl: AppConstants.cacheExpiry,
          forceRefresh: forceRefresh,
          fetcher: () async {
            final response = await _authGet('${AppConstants.clubEvents}/$id');
            if (response.statusCode == 200) {
              final json = jsonDecode(response.body);
              if (json['data'] != null &&
                  json['data']['success'] == true &&
                  json['data']['clubEvents'] != null) {
                return json['data']['clubEvents'];
              }
            }
            return null;
          },
          parser: (data) => (data as List)
              .map((e) => ClubEvent.fromJson(e as Map<String, dynamic>))
              .toList(),
        ) ??
        [];
  }

  /// Get cached club events synchronously.
  List<ClubEvent>? getCachedClubEvents(int id) {
    final key = '${AppConstants.cacheClubEvents}$id';
    final mem = getCached<List<ClubEvent>>(key);
    if (mem != null) return mem;

    try {
      final persisted = StorageService.readCache(key);
      if (persisted != null) {
        final rawJson = jsonDecode(persisted as String);
        return (rawJson as List)
            .map((e) => ClubEvent.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return null;
  }

  // ── Club & Event Admin Mutations ───────────────────────────────────────────

  /// Create a new club (Global Admin only).
  Future<Map<String, dynamic>> createClub(Map<String, dynamic> data) async {
    try {
      final response = await _authPost(AppConstants.createNewClub, body: data);
      final json = jsonDecode(response.body);
      if (json['data']?['success'] == true) {
        _invalidateCache(AppConstants.cacheClubsList);
      }
      return json;
    } catch (e) {
      debugPrint('Error in createClub: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Create a new club profile.
  Future<Map<String, dynamic>> createClubProfile(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _authPost(AppConstants.clubProfile, body: data);
      final json = jsonDecode(response.body);
      if (json['success'] == true) {
        final clubId = data['clubId'];
        if (clubId != null) {
          _invalidateCache('${AppConstants.cacheClubProfile}$clubId');
          _invalidateCache('club_$clubId');
        }
      }
      return json;
    } catch (e) {
      debugPrint('Error in createClubProfile: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Update club profile.
  Future<Map<String, dynamic>> updateClubProfile(
    int clubId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _authPut(
        '${AppConstants.clubProfile}/$clubId',
        body: data,
      );
      final json = jsonDecode(response.body);
      if (json['success'] == true) {
        _invalidateCache(AppConstants.cacheClubsList);
        _invalidateCache('${AppConstants.cacheClubProfile}$clubId');
        _invalidateCache('club_$clubId');
      }
      return json;
    } catch (e) {
      debugPrint('Error in updateClubProfile: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Create a new event for a club.
  Future<Map<String, dynamic>> createEvent(Map<String, dynamic> data) async {
    try {
      final response = await _authPost(AppConstants.createEvent, body: data);
      final json = jsonDecode(response.body);
      // Backend usually returns { data: { success: true, ... } } or similar
      if (json['data']?['success'] == true || json['success'] == true) {
        _invalidateCache(AppConstants.cacheEventsList);
        _invalidateCache(AppConstants.cacheEventsUpcoming);
        if (data['clubId'] != null) {
          _invalidateCache('${AppConstants.cacheClubEvents}${data['clubId']}');
        }
      }
      return json;
    } catch (e) {
      debugPrint('Error in createEvent: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Create extra details for an event.
  Future<Map<String, dynamic>> createExtraEventDetails(
    int eventId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _authPost(
        '${AppConstants.eventDetails}/create-event-details',
        body: {'eventId': eventId, ...data},
      );
      return jsonDecode(response.body);
    } catch (e) {
      debugPrint('Error in createExtraEventDetails: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Update extra details for an event.
  Future<Map<String, dynamic>> updateExtraEventDetails(
    int eventId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _authPut(
        '${AppConstants.eventDetails}/update-eventdetail',
        body: {'eventId': eventId, ...data},
      );
      return jsonDecode(response.body);
    } catch (e) {
      debugPrint('Error in updateExtraEventDetails: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Check if the current user is an admin of a specific club
  /// (owner OR club-level admin in the clubAdmins table).
  Future<bool> getIsAdminForClub(int clubId) async {
    try {
      final dbUserId = await StorageService.readSecure(
        AppConstants.dbUserIdKey,
      );
      if (dbUserId == null) return false;

      final response = await _authGet('/events/club/admins/$clubId');
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        // Backend returns { success, admins: [{ id, name, email, image }] } directly
        if (json is Map && json['admins'] is List) {
          final admins = json['admins'] as List;
          return admins.any((a) => a['id']?.toString() == dbUserId);
        }
        // Some backends return a flat list
        if (json is List) {
          return json.any((a) => a['id']?.toString() == dbUserId);
        }
      }
      return false;
    } catch (e) {
      debugPrint('Error in getIsAdminForClub: $e');
      return false;
    }
  }

  /// Get the list of registered students for an event (admin only).
  Future<List<RegisteredStudent>> getRegisteredStudents(int eventId) async {
    try {
      final response = await _authPost(
        '/events/registered-student',
        body: {'eventId': eventId},
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final data = json['data'];
        if (data is Map && data['registrations'] is List) {
          return (data['registrations'] as List)
              .map((e) => RegisteredStudent.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error in getRegisteredStudents: $e');
      return [];
    }
  }

  /// Download and open the exported student list (CSV or PDF).
  Future<Map<String, dynamic>> downloadAndOpenExport(
    int eventId,
    String format,
  ) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }
      final token = await currentUser.getIdToken();
      final uri = Uri.parse(
        '${AppConstants.fullApiUrl}/events/$eventId/export-students?format=$format',
      );
      final response = await _client.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final ext = format == 'pdf' ? 'pdf' : 'csv';
        final tempDir = await getTemporaryDirectory();
        final file = File(
          '${tempDir.path}/event_${eventId}_registrations.$ext',
        );
        await file.writeAsBytes(response.bodyBytes);
        final xFile = XFile(file.path);
        await SharePlus.instance.share(
          ShareParams(
            files: [xFile],
            text: 'Event Registrations (Event #$eventId)',
          ),
        );
        return {'success': true};
      }
      return {
        'success': false,
        'message': 'Export failed (status ${response.statusCode})',
      };
    } catch (e) {
      debugPrint('Error in downloadAndOpenExport: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Download and open the exported assignment submissions list (CSV or PDF).
  Future<Map<String, dynamic>> downloadAndOpenAssignmentExport(
    int assignmentId,
    String format,
  ) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }
      final token = await currentUser.getIdToken();
      final uri = Uri.parse(
        '${AppConstants.fullApiUrl}/classroom/assignments/$assignmentId/export-submissions?format=$format',
      );
      final response = await _client.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final ext = format == 'pdf' ? 'pdf' : 'csv';
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/submissions_$assignmentId.$ext');
        await file.writeAsBytes(response.bodyBytes);
        final xFile = XFile(file.path);
        await SharePlus.instance.share(
          ShareParams(
            files: [xFile],
            text: 'Assignment Submissions (ID: $assignmentId)',
          ),
        );
        return {'success': true};
      }
      return {
        'success': false,
        'message': 'Export failed (status ${response.statusCode})',
      };
    } catch (e) {
      debugPrint('Error in downloadAndOpenAssignmentExport: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Get extra details for an event.
  Future<Map<String, dynamic>> getExtraEventDetails(int eventId) async {
    try {
      final response = await _authGet('${AppConstants.eventDetails}/$eventId');
      return jsonDecode(response.body);
    } catch (e) {
      debugPrint('Error in getExtraEventDetails: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Upload an event banner image.
  Future<Map<String, dynamic>> uploadEventBanner(
    int eventId,
    String? filePath, {
    String? imageUrl,
  }) async {
    try {
      if (filePath != null) {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('${AppConstants.fullApiUrl}/events/$eventId/upload-banner'),
        );

        final authHeaders = await _getAuthHeaders();
        request.headers.addAll(authHeaders);

        request.files.add(
          await http.MultipartFile.fromPath(
            'banner',
            filePath,
            contentType: MediaType(
              'image',
              path.extension(filePath).substring(1),
            ),
          ),
        );

        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);
        final json = jsonDecode(response.body);
        if (json['success'] == true) {
          _invalidateCache(AppConstants.cacheEventsList);
          _invalidateCache('event_$eventId');
        }
        return json;
      } else if (imageUrl != null) {
        final response = await _authPost(
          '/events/$eventId/upload-banner',
          body: {'imageUrl': imageUrl},
        );
        final json = jsonDecode(response.body);
        if (json['success'] == true) {
          _invalidateCache('event_$eventId');
        }
        return json;
      }
      return {'success': false, 'message': 'No file or URL provided'};
    } catch (e) {
      debugPrint('Error in uploadEventBanner: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Update an existing event.
  Future<Map<String, dynamic>> updateEvent(
    int eventId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _authPut('/events/$eventId', body: data);
      final json = jsonDecode(response.body);
      if (json['data']?['success'] == true || json['success'] == true) {
        _invalidateCache(AppConstants.cacheEventsList);
        _invalidateCache(AppConstants.cacheEventsUpcoming);
        _invalidateCache('event_$eventId');
        // If we have club ID, invalidating its events list would be good too
      }
      return json;
    } catch (e) {
      debugPrint('Error in updateEvent: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Delete an event.
  Future<Map<String, dynamic>> deleteEvent(int eventId) async {
    try {
      final response = await _authDelete('/events/$eventId');
      final json = jsonDecode(response.body);
      if (json['data']?['success'] == true || json['success'] == true) {
        _invalidateCache(AppConstants.cacheEventsList);
        _invalidateCache(AppConstants.cacheEventsUpcoming);
        _invalidateCache('event_$eventId');
      }
      return json;
    } catch (e) {
      debugPrint('Error in deleteEvent: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Upload club logo
  Future<ApiResult<String>> uploadClubLogo(int clubId, String filePath) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConstants.fullApiUrl}/clubs/$clubId/upload-logo'),
      );

      final authHeaders = await _getAuthHeaders();
      request.headers.addAll(authHeaders);

      final extension = filePath.split('.').last.toLowerCase();
      String mimeType = 'image/jpeg';
      if (extension == 'png') {
        mimeType = 'image/png';
      } else if (extension == 'webp') {
        mimeType = 'image/webp';
      }

      request.files.add(
        await http.MultipartFile.fromPath(
          'logo',
          filePath,
          contentType: MediaType.parse(mimeType),
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data']?['url'] != null) {
          return ApiResult.success(json['data']['url'] as String);
        }
      }

      return ApiResult.failure(
        'Upload failed: ${response.statusCode}\n${response.body}',
      );
    } catch (e) {
      debugPrint('Error in uploadClubLogo: $e');
      return ApiResult.failure('Upload failed: $e');
    }
  }

  // ── Lost & Found ─────────────────────────────────────────────────────────

  /// Get list of lost and found items.
  Future<List<LostFoundItem>> getLostFoundItems({
    String? itemType,
    String? category,
    String? q,
    bool forceRefresh = false,
  }) async {
    final queryParams = <String, String>{};
    if (itemType != null) queryParams['itemType'] = itemType;
    if (category != null) queryParams['category'] = category;
    if (q != null) queryParams['q'] = q;

    final queryString = queryParams.isNotEmpty
        ? '?${Uri(queryParameters: queryParams).query}'
        : '';

    return await _cachedFetch<List<LostFoundItem>>(
          key: '${AppConstants.cacheLostFoundList}$queryString',
          ttl: AppConstants.cacheExpiry,
          forceRefresh: forceRefresh,
          fetcher: () async {
            final response = await _authGet(
              '${AppConstants.lostFound}$queryString',
            );
            debugPrint(
              'LostFound API Response: ${response.statusCode} - ${response.body}',
            );
            if (response.statusCode == 200) {
              final json = jsonDecode(response.body);
              if (json['success'] == true && json['data'] != null) {
                // Return items list if nested in 'items' key
                if (json['data'] is Map && json['data']['items'] != null) {
                  return json['data']['items'];
                }
                // Fallback for direct list
                return json['data'];
              }
            }
            return null;
          },
          parser: (data) {
            if (data is! List) return <LostFoundItem>[];
            return data
                .map((e) => LostFoundItem.fromJson(e as Map<String, dynamic>))
                .toList();
          },
        ) ??
        [];
  }

  /// Get a single lost and found item details.
  Future<LostFoundItem?> getLostFoundItem(
    int id, {
    bool forceRefresh = false,
  }) async {
    return await _cachedFetch<LostFoundItem>(
      key: '${AppConstants.cacheLostFoundDetail}$id',
      ttl: AppConstants.cacheExpiry,
      forceRefresh: forceRefresh,
      fetcher: () async {
        final response = await _authGet('${AppConstants.lostFound}/$id');
        if (response.statusCode == 200) {
          final json = jsonDecode(response.body);
          if (json['success'] == true && json['data'] != null) {
            return json['data'];
          }
        }
        return null;
      },
      parser: (data) => LostFoundItem.fromJson(data as Map<String, dynamic>),
    );
  }

  /// Create a new lost and found item.
  Future<ApiResult<LostFoundItem>> createLostFoundItem(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _authPost(AppConstants.lostFound, body: data);
      final json = jsonDecode(response.body);
      if (json['success'] == true && json['data'] != null) {
        _invalidateCachePrefix(AppConstants.cacheLostFoundList);
        _invalidateCache(AppConstants.cacheMyLostFoundItems);
        return ApiResult.success(
          LostFoundItem.fromJson(json['data'] as Map<String, dynamic>),
        );
      }
      return ApiResult.failure(json['message'] ?? 'Failed to create item');
    } catch (e) {
      return ApiResult.failure('Error: $e');
    }
  }

  /// Update an existing lost and found item.
  Future<ApiResult<LostFoundItem>> updateLostFoundItem(
    int id,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _authPut(
        '${AppConstants.lostFound}/$id',
        body: data,
      );
      final json = jsonDecode(response.body);
      if (json['success'] == true && json['data'] != null) {
        _invalidateCachePrefix(AppConstants.cacheLostFoundList);
        _invalidateCache(AppConstants.cacheMyLostFoundItems);
        _invalidateCache('${AppConstants.cacheLostFoundDetail}$id');
        return ApiResult.success(
          LostFoundItem.fromJson(json['data'] as Map<String, dynamic>),
        );
      }
      return ApiResult.failure(json['message'] ?? 'Failed to update item');
    } catch (e) {
      return ApiResult.failure('Error: $e');
    }
  }

  /// Delete a lost and found item.
  Future<ApiResult> deleteLostFoundItem(int id) async {
    try {
      final response = await _authDelete('${AppConstants.lostFound}/$id');
      final json = jsonDecode(response.body);
      if (json['success'] == true) {
        _invalidateCachePrefix(AppConstants.cacheLostFoundList);
        _invalidateCache(AppConstants.cacheMyLostFoundItems);
        _invalidateCache('${AppConstants.cacheLostFoundDetail}$id');
        return ApiResult(success: true);
      }
      return ApiResult.failure(json['message'] ?? 'Failed to delete item');
    } catch (e) {
      return ApiResult.failure('Error: $e');
    }
  }

  /// Get my lost and found items.
  Future<List<LostFoundItem>> getMyLostFoundItems({
    bool forceRefresh = false,
  }) async {
    return await _cachedFetch<List<LostFoundItem>>(
          key: AppConstants.cacheMyLostFoundItems,
          ttl: AppConstants.cacheExpiry,
          forceRefresh: forceRefresh,
          fetcher: () async {
            final response = await _authGet(AppConstants.myLostFoundItems);
            if (response.statusCode == 200) {
              final json = jsonDecode(response.body);
              if (json['success'] == true && json['data'] != null) {
                return json['data'];
              }
            }
            return null;
          },
          parser: (data) => (data as List)
              .map((e) => LostFoundItem.fromJson(e as Map<String, dynamic>))
              .toList(),
        ) ??
        [];
  }

  /// Create a claim for a found/lost item.
  Future<ApiResult<LostFoundClaim>> createLostFoundClaim({
    required int itemId,
    required String message,
  }) async {
    try {
      final response = await _authPost(
        '${AppConstants.lostFound}/$itemId/claims',
        body: {'message': message},
      );
      final json = jsonDecode(response.body);
      if (json['success'] == true && json['data'] != null) {
        _invalidateCache(AppConstants.cacheMyLostFoundClaims);
        _invalidateCache('${AppConstants.cacheLostFoundDetail}$itemId');
        _invalidateCache('lost_found_item_claims_$itemId');
        return ApiResult.success(
          LostFoundClaim.fromJson(json['data'] as Map<String, dynamic>),
        );
      }
      return ApiResult.failure(json['message'] ?? 'Failed to create claim');
    } catch (e) {
      return ApiResult.failure('Error: $e');
    }
  }

  /// Update claim status (admin/owner action).
  Future<ApiResult> updateLostFoundClaimStatus({
    required int itemId,
    required int claimId,
    required String status,
  }) async {
    try {
      final response = await _authPut(
        '${AppConstants.lostFound}/$itemId/claims/$claimId',
        body: {'status': status},
      );
      final json = jsonDecode(response.body);
      if (json['success'] == true) {
        _invalidateCache('${AppConstants.cacheLostFoundDetail}$itemId');
        _invalidateCache('lost_found_item_claims_$itemId');
        return ApiResult(success: true);
      }
      return ApiResult.failure(json['message'] ?? 'Failed to update claim');
    } catch (e) {
      return ApiResult.failure('Error: $e');
    }
  }

  /// Get my lost/found claims.
  Future<List<LostFoundClaim>> getMyLostFoundClaims({
    bool forceRefresh = false,
  }) async {
    return await _cachedFetch<List<LostFoundClaim>>(
          key: AppConstants.cacheMyLostFoundClaims,
          ttl: AppConstants.cacheExpiry,
          forceRefresh: forceRefresh,
          fetcher: () async {
            final response = await _authGet(AppConstants.myLostFoundClaims);
            if (response.statusCode == 200) {
              final json = jsonDecode(response.body);
              if (json['success'] == true && json['data'] != null) {
                return json['data'];
              }
            }
            return null;
          },
          parser: (data) => (data as List)
              .map((e) => LostFoundClaim.fromJson(e as Map<String, dynamic>))
              .toList(),
        ) ??
        [];
  }

  /// Get claims for a specific item (owner only).
  Future<List<LostFoundClaim>> getLostFoundItemClaims(
    int itemId, {
    bool forceRefresh = false,
  }) async {
    return await _cachedFetch<List<LostFoundClaim>>(
          key: 'lost_found_item_claims_$itemId',
          ttl: AppConstants.cacheExpiry,
          forceRefresh: forceRefresh,
          fetcher: () async {
            final response = await _authGet(
              '${AppConstants.lostFound}/$itemId/claims',
            );
            if (response.statusCode == 200) {
              final json = jsonDecode(response.body);
              if (json['success'] == true && json['data'] != null) {
                return json['data'];
              }
            }
            return null;
          },
          parser: (data) => (data as List)
              .map((e) => LostFoundClaim.fromJson(e as Map<String, dynamic>))
              .toList(),
        ) ??
        [];
  }

  /// Update item status (owner only).
  Future<ApiResult> updateLostFoundItemStatus(
    int itemId,
    LostFoundStatus status,
  ) async {
    try {
      final response = await _authPut(
        '${AppConstants.lostFound}/$itemId/status',
        body: {'status': status.name},
      );
      final json = jsonDecode(response.body);
      if (json['success'] == true) {
        _invalidateCachePrefix(AppConstants.cacheLostFoundList);
        _invalidateCache(AppConstants.cacheMyLostFoundItems);
        _invalidateCache('${AppConstants.cacheLostFoundDetail}$itemId');
        return ApiResult(success: true);
      }
      return ApiResult.failure(json['message'] ?? 'Failed to update status');
    } catch (e) {
      return ApiResult.failure('Error: $e');
    }
  }

  /// Upload image for a lost/found item.
  Future<ApiResult> uploadLostFoundImage(int itemId, File imageFile) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(
          '${AppConstants.fullApiUrl}${AppConstants.lostFound}/$itemId/images',
        ),
      );

      final idToken = await AuthService.currentUser?.getIdToken();
      if (idToken != null) {
        request.headers['Authorization'] = 'Bearer $idToken';
      }

      request.files.add(
        await http.MultipartFile.fromPath('image', imageFile.path),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      final json = jsonDecode(response.body);
      if (json['success'] == true) {
        _invalidateCachePrefix(AppConstants.cacheLostFoundList);
        _invalidateCache(AppConstants.cacheMyLostFoundItems);
        _invalidateCache('${AppConstants.cacheLostFoundDetail}$itemId');
        return ApiResult(success: true);
      }
      return ApiResult.failure(json['message'] ?? 'Failed to upload image');
    } catch (e) {
      return ApiResult.failure('Error: $e');
    }
  }

  // ── Admin Services ────────────────────────────────────────────────────────

  /// Get system-wide overview statistics.
  Future<AdminDashboardStats?> getAdminOverview({
    bool forceRefresh = false,
  }) async {
    return _cachedFetch<AdminDashboardStats>(
      key: AppConstants.cacheAdminOverview,
      ttl: AppConstants.cacheExpiry,
      forceRefresh: forceRefresh,
      fetcher: () async {
        final response = await _authGet(AppConstants.adminOverview);
        if (response.statusCode == 200) {
          final json = jsonDecode(response.body);
          if (json['success'] == true && json['data'] != null) {
            return json['data'];
          }
        }
        return null;
      },
      parser: (data) =>
          AdminDashboardStats.fromJson(data as Map<String, dynamic>),
    );
  }

  /// List all users with optional filtering (Admin only).
  Future<List<AdminUser>> getAdminUsers({
    String? search,
    String? role,
    int? limit,
    bool forceRefresh = false,
  }) async {
    // Cache only the default request (no search/filters)
    final isDefault = search == null && role == null && limit == null;

    if (isDefault) {
      return await _cachedFetch<List<AdminUser>>(
            key: AppConstants.cacheAdminUsers,
            ttl: AppConstants.cacheExpiry,
            forceRefresh: forceRefresh,
            fetcher: () async {
              final response = await _authGet(AppConstants.adminUsers);
              if (response.statusCode == 200) {
                final json = jsonDecode(response.body);
                if (json['success'] == true && json['data'] != null) {
                  return json['data'];
                }
              }
              return null;
            },
            parser: (data) => (data as List)
                .map((e) => AdminUser.fromJson(e as Map<String, dynamic>))
                .toList(),
          ) ??
          [];
    }

    try {
      final queryParams = {
        if (search != null) 'search': search,
        if (role != null) 'role': role,
        if (limit != null) 'limit': limit.toString(),
      };
      final response = await _authGet(
        AppConstants.adminUsers,
        queryParams: queryParams,
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] != null) {
          final List data = json['data'];
          return data
              .map((e) => AdminUser.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Error getAdminUsers: $e');
    }
    return [];
  }

  /// Update a user's role (Admin only).
  Future<ApiResult> updateAdminUserRole(String userId, String role) async {
    try {
      final response = await _authPut(
        '/admin/users/$userId/role',
        body: {'role': role},
      );
      final json = jsonDecode(response.body);
      if (json['success'] == true) {
        _invalidateCache(AppConstants.cacheAdminOverview);
        _invalidateCache(AppConstants.cacheAdminUsers);
        return ApiResult(success: true);
      }
      return ApiResult.failure(json['message'] ?? 'Failed to update role');
    } catch (e) {
      return ApiResult.failure('Error: $e');
    }
  }

  /// Toggle seller verification for a user (Admin only).
  Future<ApiResult> toggleSellerVerification(
    String userId,
    bool verified,
  ) async {
    try {
      final response = await _authPut(
        '/admin/users/$userId/verify-seller',
        body: {'verified': verified},
      );
      final json = jsonDecode(response.body);
      if (json['success'] == true) {
        _invalidateCache(AppConstants.cacheAdminOverview);
        _invalidateCache(AppConstants.cacheAdminUsers);
        return ApiResult(success: true);
      }
      return ApiResult.failure(
        json['message'] ?? 'Failed to update verification',
      );
    } catch (e) {
      return ApiResult.failure('Error: $e');
    }
  }

  /// Get moderation reports (Admin only).
  Future<List<MarketplaceReport>> getModerationReports({
    String? status,
    bool forceRefresh = false,
  }) async {
    // Cache only the default request (all reports)
    final isDefault = status == null;

    if (isDefault) {
      return await _cachedFetch<List<MarketplaceReport>>(
            key: AppConstants.cacheAdminReports,
            ttl: AppConstants.cacheExpiry,
            forceRefresh: forceRefresh,
            fetcher: () async {
              final response = await _authGet(AppConstants.adminReports);
              if (response.statusCode == 200) {
                final json = jsonDecode(response.body);
                if (json['success'] == true && json['data'] != null) {
                  return json['data'];
                }
              }
              return null;
            },
            parser: (data) => (data as List)
                .map(
                  (e) => MarketplaceReport.fromJson(e as Map<String, dynamic>),
                )
                .toList(),
          ) ??
          [];
    }

    try {
      final queryParams = {'status': status};
      final response = await _authGet(
        AppConstants.adminReports,
        queryParams: queryParams,
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] != null) {
          final List data = json['data'];
          return data
              .map((e) => MarketplaceReport.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Error getModerationReports: $e');
    }
    return [];
  }

  /// Update moderation report status (Admin only).
  Future<ApiResult> updateModerationReport(
    int reportId, {
    required String status,
    String? resolutionNotes,
  }) async {
    try {
      final response = await _authPut(
        '/admin/reports/$reportId',
        body: {'status': status, 'resolutionNotes': resolutionNotes},
      );
      final json = jsonDecode(response.body);
      if (json['success'] == true) {
        _invalidateCache(AppConstants.cacheAdminOverview);
        _invalidateCache(AppConstants.cacheAdminReports);
        return ApiResult(success: true);
      }
      return ApiResult.failure(json['message'] ?? 'Failed to update report');
    } catch (e) {
      return ApiResult.failure('Error: $e');
    }
  }

  /// Get all seller ratings (Admin only).
  Future<List<SellerRating>> getAdminRatings() async {
    try {
      final response = await _authGet(AppConstants.adminRatings);
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] != null) {
          final List data = json['data'];
          return data
              .map((e) => SellerRating.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Error getAdminRatings: $e');
    }
    return [];
  }

  /// Get all platform blocks (Admin only).
  Future<List<BlockedUser>> getAdminBlocks({bool forceRefresh = false}) async {
    return await _cachedFetch<List<BlockedUser>>(
          key: AppConstants.cacheAdminBlocks,
          ttl: AppConstants.cacheExpiry,
          forceRefresh: forceRefresh,
          fetcher: () async {
            final response = await _authGet(AppConstants.adminBlocks);
            if (response.statusCode == 200) {
              final json = jsonDecode(response.body);
              if (json['success'] == true && json['data'] != null) {
                return json['data'];
              }
            }
            return null;
          },
          parser: (data) => (data as List)
              .map((e) => BlockedUser.fromJson(e as Map<String, dynamic>))
              .toList(),
        ) ??
        [];
  }

  /// Unblock a user globally (Admin only).
  Future<ApiResult> unblockUserByAdmin(int blockId) async {
    try {
      final response = await _authDelete('/admin/blocks/$blockId');
      final json = jsonDecode(response.body);
      if (json['success'] == true) {
        _invalidateCache(AppConstants.cacheAdminOverview);
        _invalidateCache(AppConstants.cacheAdminBlocks);
        return ApiResult(success: true);
      }
      return ApiResult.failure(json['message'] ?? 'Failed to unblock user');
    } catch (e) {
      return ApiResult.failure('Error: $e');
    }
  }

  /// Publish a system-wide announcement (Admin only).
  Future<ApiResult> publishSystemAnnouncement({
    required String title,
    required String body,
    String? audience,
  }) async {
    try {
      final response = await _authPost(
        AppConstants.adminAnnouncements,
        body: {'title': title, 'body': body, 'audience': audience},
      );
      final json = jsonDecode(response.body);
      if (json['success'] == true) {
        return ApiResult(success: true);
      }
      return ApiResult.failure(
        json['message'] ?? 'Failed to publish announcement',
      );
    } catch (e) {
      return ApiResult.failure('Error: $e');
    }
  }
}
