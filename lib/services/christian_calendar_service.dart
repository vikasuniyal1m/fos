import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

/// Christian Calendar Service
/// Fetches liturgical events and civil holidays from the backend
class ChristianCalendarService {
  /// Fetch upcoming Christian and secular events
  /// 
  /// [limit] - Number of events to fetch (default: 80)
  /// Returns list of upcoming events with dates
  static Future<List<Map<String, dynamic>>> getUpcomingEvents({int limit = 80}) async {
    try {
      print('📅 API Call: ${ApiConfig.christianCalender}?upcoming=1&limit=$limit');
      final response = await http.get(
        Uri.parse('${ApiConfig.christianCalender}?upcoming=1&limit=$limit'),
        headers: ApiConfig.headers,
      ).timeout(ApiConfig.timeout);

      print('📅 API Status: ${response.statusCode}');
      print('📅 API Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('📅 Parsed Data: $data');
        if (data['success'] == true) {
          final events = List<Map<String, dynamic>>.from(data['data'] ?? []);
          print('📅 Events Count: ${events.length}');
          return events;
        }
      }
      return [];
    } catch (e) {
      print('❌ Error fetching upcoming events: $e');
      return [];
    }
  }

  /// Fetch events for a specific month
  /// 
  /// [year] - Year (e.g., 2026)
  /// [month] - Month (1-12)
  /// Returns map of day number to list of events
  static Future<Map<int, List<Map<String, dynamic>>>> getMonthEvents(int year, int month) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.christianCalender}?y=$year&m=$month'),
        headers: ApiConfig.headers,
      ).timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final Map<int, List<Map<String, dynamic>>> result = {};
          final monthData = data['data'] as Map<String, dynamic>;
          
          monthData.forEach((dayStr, events) {
            final day = int.tryParse(dayStr) ?? 0;
            if (day > 0 && events is List) {
              result[day] = List<Map<String, dynamic>>.from(
                events.map((e) => Map<String, dynamic>.from(e)),
              );
            }
          });
          
          return result;
        }
      }
      return {};
    } catch (e) {
      print('Error fetching month events: $e');
      return {};
    }
  }

  /// Fetch all events for a year
  /// 
  /// [year] - Year (e.g., 2026)
  /// Returns map of date (YYYY-MM-DD) to list of events
  static Future<Map<String, List<Map<String, dynamic>>>> getYearEvents(int year) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.christianCalender}?y=$year'),
        headers: ApiConfig.headers,
      ).timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final Map<String, List<Map<String, dynamic>>> result = {};
          final yearData = data['data'] as Map<String, dynamic>;
          
          yearData.forEach((date, events) {
            if (events is List) {
              result[date] = List<Map<String, dynamic>>.from(
                events.map((e) => Map<String, dynamic>.from(e)),
              );
            }
          });
          
          return result;
        }
      }
      return {};
    } catch (e) {
      print('Error fetching year events: $e');
      return {};
    }
  }

  /// Check if a specific date has events
  /// 
  /// [date] - Date in format YYYY-MM-DD
  static Future<List<Map<String, dynamic>>> getEventsForDate(String date) async {
    try {
      print('📅 Getting events for date: $date');
      final parts = date.split('-');
      if (parts.length != 3) return [];
      
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final day = int.parse(parts[2]);
      print('📅 Year: $year, Month: $month, Day: $day');

      final monthEvents = await getMonthEvents(year, month);
      print('📅 Month events keys: ${monthEvents.keys}');
      print('📅 Events for day $day: ${monthEvents[day]}');

      final events = monthEvents[day] ?? [];
      print('📅 Final events count: ${events.length}');
      return events;
    } catch (e) {
      print('❌ Error fetching events for date: $e');
      return [];
    }
  }

  /// Get event category icon
  static String getEventIcon(String category, String title) {
    print('📅 Icon Request - Category: $category, Title: $title');

    if (category == 'christian') {
      // Different icons for different Christian events
      if (title.toLowerCase().contains('easter')) return '🌸';
      if (title.toLowerCase().contains('christmas')) return '🎁';
      if (title.toLowerCase().contains('mary') || title.toLowerCase().contains('mother')) return '💒';
      if (title.toLowerCase().contains('saint') || title.toLowerCase().contains('st.')) return '⭐';
      if (title.toLowerCase().contains('pentecost')) return '🌟';
      if (title.toLowerCase().contains('advent')) return '🕯️';
      if (title.toLowerCase().contains('ash')) return '🌱';
      if (title.toLowerCase().contains('cross') || title.toLowerCase().contains('good friday')) return '✨';
      if (title.toLowerCase().contains('trinity')) return '🔱';
      if (title.toLowerCase().contains('corpus')) return '🍞';
      if (title.toLowerCase().contains('sacred')) return '💜';
      print('📅 Icon: 🙏 (default christian)');
      return '🙏';
    } else {
      // Different icons for different secular events
      if (title.toLowerCase().contains('new year')) return '🎊';
      if (title.toLowerCase().contains('valentine')) return '💕';
      if (title.toLowerCase().contains('halloween')) return '👻';
      if (title.toLowerCase().contains('thanksgiving')) return '🍂';
      if (title.toLowerCase().contains('independence') || title.toLowerCase().contains('july 4')) return '🗽';
      if (title.toLowerCase().contains('labor')) return '🛠️';
      if (title.toLowerCase().contains('memorial')) return '🎗️';
      if (title.toLowerCase().contains('mother')) return '💐';
      if (title.toLowerCase().contains('father')) return '🎩';
      if (title.toLowerCase().contains('earth')) return '🌎';
      if (title.toLowerCase().contains('women')) return '👩';
      if (title.toLowerCase().contains('president')) return '🏛️';
      print('📅 Icon: 🎈 (default secular)');
      return '🎈';
    }
  }

  /// Get event category color
  static int getEventColor(String category, String title) {
    if (category == 'christian') {
      // Different colors for different Christian events
      if (title.toLowerCase().contains('easter')) return 0xFF81C784; // Green
      if (title.toLowerCase().contains('christmas')) return 0xFFEF5350; // Red
      if (title.toLowerCase().contains('mary') || title.toLowerCase().contains('mother')) return 0xFF64B5F6; // Blue
      if (title.toLowerCase().contains('pentecost')) return 0xFFFFB74D; // Orange
      if (title.toLowerCase().contains('advent')) return 0xFF9575CD; // Purple
      return 0xFFE57373; // Default red
    } else {
      // Different colors for different secular events
      if (title.toLowerCase().contains('new year')) return 0xFF4FC3F7; // Cyan
      if (title.toLowerCase().contains('valentine')) return 0xFFE91E63; // Pink
      if (title.toLowerCase().contains('halloween')) return 0xFFFF7043; // Orange
      if (title.toLowerCase().contains('thanksgiving')) return 0xFFFFB74D; // Gold
      if (title.toLowerCase().contains('independence') || title.toLowerCase().contains('july 4')) return 0xFF42A5F5; // Blue
      return 0xFFFFB74D; // Default gold
    }
  }

  /// Test function to call API and print response
  static Future<void> testCalendarAPI() async {
    print('=== Testing Christian Calendar API ===');
    
    try {
      final baseUrl = 'http://admin.fosmessenger.com/api';
      
      // Test 1: Call upcoming events API
      print('\n1. Testing upcoming events API...');
      final upcomingUrl = '$baseUrl/christian-calender.php?upcoming=1&limit=10';
      print('URL: $upcomingUrl');
      
      final upcomingResponse = await http.get(
        Uri.parse(upcomingUrl),
        headers: {'Accept': 'application/json'},
      ).timeout(ApiConfig.timeout);
      
      print('Status Code: ${upcomingResponse.statusCode}');
      print('Response Body: ${upcomingResponse.body}');
      
      // Test 2: Call current month API
      print('\n2. Testing current month API...');
      final now = DateTime.now();
      final monthUrl = '$baseUrl/christian-calender.php?y=${now.year}&m=${now.month}';
      print('URL: $monthUrl');
      
      final monthResponse = await http.get(
        Uri.parse(monthUrl),
        headers: {'Accept': 'application/json'},
      ).timeout(ApiConfig.timeout);
      
      print('Status Code: ${monthResponse.statusCode}');
      print('Response Body: ${monthResponse.body}');
      
      // Test 3: Call year events API
      print('\n3. Testing year events API...');
      final yearUrl = '$baseUrl/christian-calender.php?y=${now.year}';
      print('URL: $yearUrl');
      
      final yearResponse = await http.get(
        Uri.parse(yearUrl),
        headers: {'Accept': 'application/json'},
      ).timeout(ApiConfig.timeout);
      
      print('Status Code: ${yearResponse.statusCode}');
      print('Response Body: ${yearResponse.body}');
      
      print('\n=== API Test Complete ===');
    } catch (e) {
      print('Error testing calendar API: $e');
    }
  }
}
