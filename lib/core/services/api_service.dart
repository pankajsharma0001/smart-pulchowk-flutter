import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:smart_pulchowk/core/constants/app_constants.dart';
import 'package:smart_pulchowk/core/models/book_listing.dart';
import 'package:smart_pulchowk/core/models/chat.dart';
import 'package:smart_pulchowk/core/models/classroom.dart';
import 'package:smart_pulchowk/core/models/notification.dart';
import 'package:smart_pulchowk/core/models/trust.dart';
import 'package:smart_pulchowk/core/services/storage_service.dart';
import 'package:flutter/foundation.dart';

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

  /// Invalidate a specific cache key (both in-memory and Hive).
  static void _invalidateCache(String key) {
    _cache.remove(key);
    StorageService.deleteCache(key);
  }

  /// Invalidate all cache keys matching a prefix (both in-memory and Hive).
  static void _invalidateCachePrefix(String prefix) {
    _cache.removeWhere((k, _) => k.startsWith(prefix));
    StorageService.deleteCacheByPrefix(prefix);
  }

  /// Clear all marketplace caches.
  static void invalidateMarketplaceCache() => _invalidateCachePrefix('mkt_');

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
    // Currently getUserRole already hits the backend,
    // but this could implement local caching in the future.
    await getUserRole();
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
      body: jsonEncode(body),
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

  Future<Map<String, String>> _getHeaders(Map<String, String>? extra) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (extra != null) headers.addAll(extra);
    return headers;
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
          if (isbn != null) 'isbn': isbn,
          if (edition != null) 'edition': edition,
          if (publisher != null) 'publisher': publisher,
          if (publicationYear != null) 'publicationYear': publicationYear,
          if (description != null) 'description': description,
          if (courseCode != null) 'courseCode': courseCode,
          if (buyerContactInfo != null) 'buyerContactInfo': buyerContactInfo,
          if (categoryId != null) 'categoryId': categoryId,
        },
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
        body: {
          'listingId': listingId,
          'rating': rating,
          if (review != null) 'review': review,
        },
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
          if (listingId != null) 'listingId': listingId,
          'category': category,
          'description': description,
        },
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
        if (listingId != null) 'listingId': listingId,
        if (receiverId != null) 'receiverId': receiverId,
      };

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
    bool forceRefresh = false,
  }) async {
    final result = await ApiService._cachedFetch<List<InAppNotification>>(
      key: 'notifications_list',
      ttl: const Duration(minutes: 5),
      forceRefresh: forceRefresh,
      fetcher: () async {
        final response = await _authGet('/notifications');
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

  /// Mark a specific notification as read.
  Future<bool> markNotificationRead(int id) async {
    try {
      final response = await _authPut('/notifications/$id/read');
      final result = jsonDecode(response.body);
      if (result['success'] == true) {
        _invalidateCache('notifications_list');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error marking notification read: $e');
      return false;
    }
  }

  /// Mark all notifications as read.
  Future<bool> markAllNotificationsRead() async {
    try {
      final response = await _authPost('/notifications/mark-all-read');
      final result = jsonDecode(response.body);
      if (result['success'] == true) {
        _invalidateCache('notifications_list');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error marking all notifications read: $e');
      return false;
    }
  }
}
