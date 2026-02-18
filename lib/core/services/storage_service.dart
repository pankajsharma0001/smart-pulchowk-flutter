import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_pulchowk/core/constants/app_constants.dart';

/// Centralized storage service for secure and cached data.
class StorageService {
  StorageService._();

  static const _secureStorage = FlutterSecureStorage();
  static late Box _cacheBox;

  /// Initialize Hive and open common boxes.
  static Future<void> init() async {
    await Hive.initFlutter();
    _cacheBox = await Hive.openBox(AppConstants.apiCacheBox);
  }

  // ── Secure Storage ────────────────────────────────────────────────────────

  static Future<void> writeSecure(String key, String value) async {
    await _secureStorage.write(key: key, value: value);
  }

  static Future<String?> readSecure(String key) async {
    return await _secureStorage.read(key: key);
  }

  static Future<void> deleteSecure(String key) async {
    await _secureStorage.delete(key: key);
  }

  static Future<void> clearAllSecure() async {
    await _secureStorage.deleteAll();
  }

  // ── Hive Cache ────────────────────────────────────────────────────────────

  static Future<void> writeCache(String key, dynamic value) async {
    final entry = {
      'data': value,
      'timestamp': DateTime.now().toIso8601String(),
    };
    await _cacheBox.put(key, entry);
  }

  static dynamic readCache(String key) {
    final entry = _cacheBox.get(key);
    if (entry is Map) {
      return entry['data'];
    }
    return entry;
  }

  /// Get the timestamp of a cached entry.
  static DateTime? getCacheTimestamp(String key) {
    final entry = _cacheBox.get(key);
    if (entry is Map && entry['timestamp'] != null) {
      return DateTime.tryParse(entry['timestamp'] as String);
    }
    return null;
  }

  static Future<void> deleteCache(String key) async {
    await _cacheBox.delete(key);
  }

  /// Delete all cache entries whose keys start with [prefix].
  static Future<void> deleteCacheByPrefix(String prefix) async {
    final keysToDelete = _cacheBox.keys
        .where((k) => k.toString().startsWith(prefix))
        .toList();
    for (final key in keysToDelete) {
      await _cacheBox.delete(key);
    }
  }

  static Future<void> clearCache() async {
    await _cacheBox.clear();
  }
}
