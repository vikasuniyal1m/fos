import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Hive Cache Service — single on-device cache for feed/list data.
/// SharedPreferences is only used once to migrate legacy `cache_*` keys.
class HiveCacheService {
  static const String _boxName = 'app_cache';
  static const String _legacyPrefix = 'cache_';
  static const int _defaultExpiryHours = 24;

  static Box? _box;
  static bool _isInitialized = false;

  /// Initialize Hive cache box and migrate legacy SharedPreferences cache.
  static Future<void> init() async {
    if (_isInitialized) return;

    try {
      _box = await Hive.openBox(_boxName);
      _isInitialized = true;
      await migrateLegacySharedPreferencesCache();
      print('✅ Hive cache initialized');
    } catch (e) {
      print('⚠️ Error initializing Hive cache: $e');
      try {
        _box = Hive.box(_boxName);
        _isInitialized = true;
      } catch (e2) {
        print('⚠️ Error getting Hive box: $e2');
        _box = await Hive.openBox(_boxName);
        _isInitialized = true;
      }
    }
  }

  static Box _getBox() {
    if (!_isInitialized || _box == null) {
      throw Exception('HiveCacheService not initialized. Call init() first.');
    }
    return _box!;
  }

  static int maxItemsForKey(String key) {
    switch (key) {
      case 'home_emojis':
      case 'fruit_screen_all_variants':
        return 80;
      case 'fruit_screen_emojis':
        return 40;
      case 'home_live_videos':
        return 10;
      case 'church_nearby_places':
        return 80;
      case 'gallery_list':
      case 'home_gallery_photos':
        return 40;
      default:
        return 25;
    }
  }

  static List<Map<String, dynamic>> _trimList(
    List<Map<String, dynamic>> data, {
    required String key,
    int? maxItems,
  }) {
    final limit = maxItems ?? maxItemsForKey(key);
    if (data.length <= limit) {
      return List<Map<String, dynamic>>.from(data);
    }
    return data.sublist(0, limit);
  }

  /// One-time migration: move old SharedPreferences list cache into Hive, then delete prefs copy.
  static Future<void> migrateLegacySharedPreferencesCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final legacyKeys =
          prefs.getKeys().where((k) => k.startsWith(_legacyPrefix)).toList();
      if (legacyKeys.isEmpty) return;

      final box = _getBox();
      var migrated = 0;

      for (final prefsKey in legacyKeys) {
        final hiveKey = prefsKey.substring(_legacyPrefix.length);
        if (box.get(hiveKey) != null) {
          await prefs.remove(prefsKey);
          continue;
        }

        final raw = prefs.getString(prefsKey);
        if (raw == null || raw.isEmpty) {
          await prefs.remove(prefsKey);
          continue;
        }

        await box.put(hiveKey, raw);
        await prefs.remove(prefsKey);
        migrated++;
      }

      if (migrated > 0) {
        print('✅ Migrated $migrated legacy cache keys from SharedPreferences → Hive');
      }
    } catch (e) {
      print('⚠️ Legacy cache migration skipped: $e');
    }
  }

  /// Cache data with expiry
  static Future<void> cacheData(
    String key,
    dynamic data, {
    int expiryHours = _defaultExpiryHours,
  }) async {
    try {
      final box = _getBox();
      final cacheData = {
        'data': data,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'expiry': expiryHours * 60 * 60 * 1000,
      };
      await box.put(key, jsonEncode(cacheData));
    } catch (e) {
      print('⚠️ Error caching data: $e');
    }
  }

  /// Get cached data if not expired
  static dynamic getCachedData(String key) {
    try {
      final box = _getBox();
      final cached = box.get(key);

      if (cached == null) return null;

      final cacheData = jsonDecode(cached as String) as Map<String, dynamic>;
      final timestamp = cacheData['timestamp'] as int;
      final expiry = cacheData['expiry'] as int;
      final now = DateTime.now().millisecondsSinceEpoch;

      if (now - timestamp > expiry) {
        box.delete(key);
        return null;
      }

      return cacheData['data'];
    } catch (e) {
      print('⚠️ Error getting cached data: $e');
      return null;
    }
  }

  /// Cache list data (trimmed to save storage)
  static Future<void> cacheList(
    String key,
    List<Map<String, dynamic>> data, {
    int expiryHours = _defaultExpiryHours,
    int? maxItems,
  }) async {
    final trimmed = _trimList(data, key: key, maxItems: maxItems);
    await cacheData(key, {'list': trimmed}, expiryHours: expiryHours);
  }

  /// Get cached list
  static List<Map<String, dynamic>> getCachedList(String key) {
    final cached = getCachedData(key);
    if (cached == null) return [];

    try {
      if (cached is Map && cached.containsKey('list')) {
        return List<Map<String, dynamic>>.from(cached['list'] as List);
      }
      return [];
    } catch (e) {
      print('⚠️ Error parsing cached list: $e');
      return [];
    }
  }

  /// Cache map data
  static Future<void> cacheMap(
    String key,
    Map<String, dynamic> data, {
    int expiryHours = _defaultExpiryHours,
  }) async {
    await cacheData(key, data, expiryHours: expiryHours);
  }

  /// Get cached map
  static Map<String, dynamic> getCachedMap(String key) {
    final cached = getCachedData(key);
    if (cached is Map<String, dynamic>) {
      return Map<String, dynamic>.from(cached);
    }
    return {};
  }

  /// Clear all cache
  static Future<void> clearAll() async {
    try {
      final box = _getBox();
      await box.clear();
      print('🗑️ All Hive cache cleared');
    } catch (e) {
      print('⚠️ Error clearing cache: $e');
    }
  }

  /// Clear specific key
  static Future<void> clearKey(String key) async {
    try {
      final box = _getBox();
      await box.delete(key);
    } catch (e) {
      print('⚠️ Error clearing cache key: $e');
    }
  }
}
