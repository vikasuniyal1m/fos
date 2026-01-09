import 'dart:convert';
import '../config/api_config.dart';
import 'api_service.dart';

/// Prayer Reminders Service
/// Handles prayer time reminder settings
class PrayerRemindersService {
  /// Get Prayer Reminder Settings
  /// 
  /// Parameters:
  /// - userId: User ID
  /// 
  /// Returns: Reminder settings (times and enabled status)
  static Future<Map<String, dynamic>> getReminderSettings({
    required int userId,
  }) async {
    final response = await ApiService.get(
      '${ApiConfig.baseUrl}/prayer_reminders.php?action=get',
      queryParameters: {'user_id': userId.toString()},
    );

    if (response['success'] == true && response['data'] != null) {
      return response['data'] as Map<String, dynamic>;
    } else {
      throw ApiException(response['message'] ?? 'Failed to fetch reminder settings');
    }
  }

  /// Set Prayer Reminder Times
  /// 
  /// Parameters:
  /// - userId: User ID
  /// - reminderTimes: List of times in HH:MM format (e.g., ["06:00", "12:00", "18:00"])
  /// - enabled: Whether reminders are enabled (default: true)
  /// 
  /// Returns: Updated reminder settings
  static Future<Map<String, dynamic>> setReminderTimes({
    required int userId,
    required List<String> reminderTimes,
    bool enabled = true,
  }) async {
    // Convert list to JSON string for PHP
    final reminderTimesJson = jsonEncode(reminderTimes);
    
    final body = <String, dynamic>{
      'user_id': userId.toString(),
      'reminder_times': reminderTimesJson,
      'enabled': enabled ? '1' : '0',
    };

    final response = await ApiService.post(
      '${ApiConfig.baseUrl}/prayer_reminders.php?action=set',
      body: body,
    );

    if (response['success'] == true && response['data'] != null) {
      return response['data'] as Map<String, dynamic>;
    } else {
      throw ApiException(response['message'] ?? 'Failed to set reminder times');
    }
  }
}

