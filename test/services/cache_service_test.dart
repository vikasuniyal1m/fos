import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fruitsofspirit/services/cache_service.dart';
import '../helpers/test_setup.dart';

void main() {
  setUpAll(() async {
    // Initialize Flutter binding and SharedPreferences mock
    await setupTestEnvironment();
  });

  setUp(() async {
    // Clear cache before each test
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  });
  
  group('CacheService', () {
    test('should cache and retrieve data', () async {
      const key = 'test_key';
      final testData = {'name': 'Test', 'value': 123};

      await CacheService.cacheData(key, testData);
      final retrieved = await CacheService.getCachedData(key);

      expect(retrieved, isNotNull);
      expect(retrieved!['name'], equals('Test'));
      expect(retrieved['value'], equals(123));
    });

    test('should return null for expired cache', () async {
      const key = 'expired_key';
      final testData = {'name': 'Test'};

      // Cache with 0 hours expiry (immediately expired)
      await CacheService.cacheData(key, testData, expiryHours: 0);
      
      // Wait a bit
      await Future.delayed(const Duration(milliseconds: 100));
      
      final retrieved = await CacheService.getCachedData(key);
      expect(retrieved, isNull);
    });

    test('should cache and retrieve list data', () async {
      const key = 'list_key';
      final testList = [
        {'id': 1, 'name': 'Item 1'},
        {'id': 2, 'name': 'Item 2'},
      ];

      await CacheService.cacheList(key, testList);
      final retrieved = await CacheService.getCachedList(key);

      expect(retrieved.length, equals(2));
      expect(retrieved[0]['name'], equals('Item 1'));
    });

    test('should clear specific cache', () async {
      const key = 'clear_key';
      final testData = {'name': 'Test'};

      await CacheService.cacheData(key, testData);
      await CacheService.clearCache(key);

      final retrieved = await CacheService.getCachedData(key);
      expect(retrieved, isNull);
    });

    test('should check if data is cached', () async {
      const key = 'check_key';
      final testData = {'name': 'Test'};

      expect(await CacheService.isCached(key), isFalse);

      await CacheService.cacheData(key, testData);
      expect(await CacheService.isCached(key), isTrue);
    });
  });
}

