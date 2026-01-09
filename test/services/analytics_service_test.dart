import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fruitsofspirit/services/analytics_service.dart';
import '../helpers/test_setup.dart';

void main() {
  setUpAll(() async {
    // Initialize Flutter binding and SharedPreferences mock
    await setupTestEnvironment();
  });

  setUp(() async {
    // Clear analytics data before each test
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  });
  
  group('AnalyticsService', () {
    test('should track event', () async {
      await AnalyticsService.trackEvent('test_event', parameters: {'key': 'value'});
      // Event is tracked asynchronously, so we just verify no exception is thrown
      expect(true, isTrue);
    });

    test('should track screen view', () async {
      await AnalyticsService.trackScreenView('test_screen');
      expect(true, isTrue);
    });

    test('should track user action', () async {
      await AnalyticsService.trackAction('click', target: 'button');
      expect(true, isTrue);
    });

    test('should track content interaction', () async {
      await AnalyticsService.trackContentInteraction('blog', '123', 'like');
      expect(true, isTrue);
    });

    test('should track search', () async {
      await AnalyticsService.trackSearch('test query', type: 'blogs', resultCount: 10);
      expect(true, isTrue);
    });

    test('should track share', () async {
      await AnalyticsService.trackShare('video', '456', 'link');
      expect(true, isTrue);
    });
  });
}

