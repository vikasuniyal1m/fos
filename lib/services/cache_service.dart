import 'package:fruitsofspirit/services/hive_cache_service.dart';

/// Cache facade — all list/map feed data lives in [HiveCacheService] only.
/// SharedPreferences is reserved for auth flags and user settings (see UserStorage).
class CacheService {
  static const int _defaultExpiryHours = 24;

  static Future<void> cacheData(
    String key,
    Map<String, dynamic> data, {
    int expiryHours = _defaultExpiryHours,
  }) async {
    await HiveCacheService.cacheData(key, data, expiryHours: expiryHours);
  }

  static Future<Map<String, dynamic>?> getCachedData(String key) async {
    final cached = HiveCacheService.getCachedData(key);
    if (cached is Map<String, dynamic>) {
      return Map<String, dynamic>.from(cached);
    }
    return null;
  }

  static Future<void> cacheList(
    String key,
    List<Map<String, dynamic>> data, {
    int expiryHours = _defaultExpiryHours,
    int? maxItems,
  }) async {
    await HiveCacheService.cacheList(
      key,
      data,
      expiryHours: expiryHours,
      maxItems: maxItems,
    );
  }

  static Future<List<Map<String, dynamic>>> getCachedList(String key) async {
    return HiveCacheService.getCachedList(key);
  }

  static Future<void> cacheMap(
    String key,
    Map<String, dynamic> data, {
    int expiryHours = _defaultExpiryHours,
  }) async {
    await HiveCacheService.cacheMap(key, data, expiryHours: expiryHours);
  }

  static Future<Map<String, dynamic>> getCachedMap(String key) async {
    return HiveCacheService.getCachedMap(key);
  }

  static Future<void> clearCache(String key) async {
    await HiveCacheService.clearKey(key);
  }

  static Future<void> clearAllCache() async {
    await HiveCacheService.clearAll();
  }

  static Future<bool> isCached(String key) async {
    return HiveCacheService.getCachedData(key) != null;
  }
}
