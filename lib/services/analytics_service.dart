import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fruitsofspirit/services/api_service.dart';
import 'package:fruitsofspirit/config/api_config.dart';

/// Analytics Service
/// Tracks user engagement and app usage
class AnalyticsService {
  static const String _eventsKey = 'analytics_events';
  static const int _maxPendingEvents = 100;

  /// Track Event
  static Future<void> trackEvent(String eventName, {Map<String, dynamic>? parameters}) async {
    try {
      final event = {
        'event_name': eventName,
        'parameters': parameters ?? {},
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Save to local storage
      await _saveEvent(event);

      // Try to send immediately (non-blocking)
      _sendEvent(event).catchError((e) {
        print('Analytics send error: $e');
      });
    } catch (e) {
      print('Analytics track error: $e');
    }
  }

  /// Track Screen View
  static Future<void> trackScreenView(String screenName) async {
    await trackEvent('screen_view', parameters: {'screen_name': screenName});
  }

  /// Track User Action
  static Future<void> trackAction(String action, {String? target, Map<String, dynamic>? extra}) async {
    await trackEvent('user_action', parameters: {
      'action': action,
      if (target != null) 'target': target,
      if (extra != null) ...extra,
    });
  }

  /// Track Content Interaction
  static Future<void> trackContentInteraction(String contentType, String contentId, String interaction) async {
    await trackEvent('content_interaction', parameters: {
      'content_type': contentType,
      'content_id': contentId,
      'interaction': interaction,
    });
  }

  /// Track Search
  static Future<void> trackSearch(String query, {String? type, int? resultCount}) async {
    await trackEvent('search', parameters: {
      'query': query,
      if (type != null) 'type': type,
      if (resultCount != null) 'result_count': resultCount,
    });
  }

  /// Track Share
  static Future<void> trackShare(String contentType, String contentId, String shareMethod) async {
    await trackEvent('share', parameters: {
      'content_type': contentType,
      'content_id': contentId,
      'share_method': shareMethod,
    });
  }

  /// Save event to local storage
  static Future<void> _saveEvent(Map<String, dynamic> event) async {
    final prefs = await SharedPreferences.getInstance();
    final eventsJson = prefs.getString(_eventsKey);
    List<Map<String, dynamic>> events = [];

    if (eventsJson != null) {
      try {
        final decoded = jsonDecode(eventsJson) as List;
        events = decoded.map((e) => e as Map<String, dynamic>).toList();
      } catch (e) {
        events = [];
      }
    }

    events.add(event);

    // Limit pending events
    if (events.length > _maxPendingEvents) {
      events = events.sublist(events.length - _maxPendingEvents);
    }

    await prefs.setString(_eventsKey, jsonEncode(events));
  }

  /// Send event to server
  static Future<void> _sendEvent(Map<String, dynamic> event) async {
    try {
      // Send to analytics API endpoint
      await ApiService.post(
        '${ApiConfig.analytics}?action=track',
        body: event,
      );
    } catch (e) {
      // Event is already saved locally, will retry later
      print('Failed to send analytics event: $e');
    }
  }

  /// Send all pending events
  static Future<void> sendPendingEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final eventsJson = prefs.getString(_eventsKey);

      if (eventsJson == null || eventsJson.isEmpty) return;

      final decoded = jsonDecode(eventsJson) as List;
      final events = decoded.map((e) => e as Map<String, dynamic>).toList();

      if (events.isEmpty) return;

      // Send all events
      await ApiService.post(
        '${ApiConfig.analytics}?action=batch',
        body: {'events': events},
      );

      // Clear sent events
      await prefs.remove(_eventsKey);
    } catch (e) {
      print('Failed to send pending analytics events: $e');
    }
  }

  /// Clear all pending events
  static Future<void> clearPendingEvents() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_eventsKey);
  }
}
