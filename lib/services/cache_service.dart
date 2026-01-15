import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Cache Service
/// Handles offline data caching
class CacheService {
  static const String _prefix = 'cache_';
  static const int _defaultExpiryHours = 24;

  /// Cache data with expiry
  static Future<void> cacheData(String key, Map<String, dynamic> data, {int expiryHours = _defaultExpiryHours}) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheData = {
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'expiry': expiryHours * 60 * 60 * 1000, // Convert to milliseconds
    };
    await prefs.setString('$_prefix$key', jsonEncode(cacheData));
  }

  /// Get cached data if not expired
  static Future<Map<String, dynamic>?> getCachedData(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('$_prefix$key');
    
    if (cached == null) return null;
    
    try {
      final cacheData = jsonDecode(cached) as Map<String, dynamic>;
      final timestamp = cacheData['timestamp'] as int;
      final expiry = cacheData['expiry'] as int;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      if (now - timestamp > expiry) {
        // Expired, remove it
        await prefs.remove('$_prefix$key');
        return null;
      }
      
      return cacheData['data'] as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  /// Cache list data
  static Future<void> cacheList(String key, List<Map<String, dynamic>> data, {int expiryHours = _defaultExpiryHours}) async {
    await cacheData(key, {'list': data}, expiryHours: expiryHours);
  }

  /// Get cached list
  static Future<List<Map<String, dynamic>>> getCachedList(String key) async {
    final cached = await getCachedData(key);
    if (cached == null) return [];
    
    try {
      return (cached['list'] as List).map((e) => e as Map<String, dynamic>).toList();
    } catch (e) {
      return [];
    }
  }

  /// Cache map data
  static Future<void> cacheMap(String key, Map<String, dynamic> data, {int expiryHours = _defaultExpiryHours}) async {
    await cacheData(key, data, expiryHours: expiryHours);
  }

  /// Get cached map
  static Future<Map<String, dynamic>> getCachedMap(String key) async {
    final cached = await getCachedData(key);
    return cached ?? {};
  }

  /// Clear specific cache
  static Future<void> clearCache(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$key');
  }

  /// Clear all cache
  static Future<void> clearAllCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith(_prefix));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  /// Check if data is cached
  static Future<bool> isCached(String key) async {
    final cached = await getCachedData(key);
    return cached != null;
  }
}

