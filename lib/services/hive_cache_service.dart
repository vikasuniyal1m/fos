import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

/// Hive Cache Service
/// Fast, persistent caching using Hive
class HiveCacheService {
  static const String _boxName = 'app_cache';
  static const int _defaultExpiryHours = 24;
  
  static Box? _box;
  static bool _isInitialized = false;

  /// Initialize Hive cache box
  static Future<void> init() async {
    if (_isInitialized) return;
    
    try {
      _box = await Hive.openBox(_boxName);
      _isInitialized = true;
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

  /// Cache data with expiry
  static Future<void> cacheData(String key, dynamic data, {int expiryHours = _defaultExpiryHours}) async {
    try {
      final box = _getBox();
      final cacheData = {
        'data': data,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'expiry': expiryHours * 60 * 60 * 1000, // Convert to milliseconds
      };
      await box.put(key, jsonEncode(cacheData));
      print('💾 Cached data: $key');
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
        // Expired, remove it
        box.delete(key);
        return null;
      }
      
      return cacheData['data'];
    } catch (e) {
      print('⚠️ Error getting cached data: $e');
      return null;
    }
  }

  /// Cache list data
  static Future<void> cacheList(String key, List<Map<String, dynamic>> data, {int expiryHours = _defaultExpiryHours}) async {
    await cacheData(key, {'list': data}, expiryHours: expiryHours);
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

  /// Clear all cache
  static Future<void> clearAll() async {
    try {
      final box = _getBox();
      await box.clear();
      print('🗑️ All cache cleared');
    } catch (e) {
      print('⚠️ Error clearing cache: $e');
    }
  }

  /// Clear specific key
  static Future<void> clearKey(String key) async {
    try {
      final box = _getBox();
      await box.delete(key);
      print('🗑️ Cleared cache key: $key');
    } catch (e) {
      print('⚠️ Error clearing cache key: $e');
    }
  }
}

