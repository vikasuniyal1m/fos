import '../config/api_config.dart';
import 'api_service.dart';

/// Notifications Service
/// Handles user notifications
class NotificationsService {
  /// Get Notifications
  /// 
  /// Parameters:
  /// - userId: User ID
  /// - isRead: Filter by read status (0 = unread, 1 = read, null = all)
  /// - limit: Number of results (default: 50)
  /// - offset: Pagination offset (default: 0)
  /// 
  /// Returns: List of notifications
  static Future<List<Map<String, dynamic>>> getNotifications({
    required int userId,
    int? isRead,
    int limit = 50,
    int offset = 0,
  }) async {
    final queryParams = <String, String>{
      'user_id': userId.toString(),
      'limit': limit.toString(),
      'offset': offset.toString(),
    };

    if (isRead != null) {
      queryParams['is_read'] = isRead.toString();
    }

    final response = await ApiService.get(
      ApiConfig.notifications,
      queryParameters: queryParams,
    );

    if (response['success'] == true && response['data'] != null) {
      return List<Map<String, dynamic>>.from(response['data']);
    } else {
      throw ApiException(response['message'] ?? 'Failed to fetch notifications');
    }
  }

  /// Mark Notification as Read
  /// 
  /// Parameters:
  /// - userId: User ID
  /// - notificationId: Notification ID (optional, if not provided marks all as read)
  /// 
  /// Returns: Success message
  static Future<String> markAsRead({
    required int userId,
    int? notificationId,
  }) async {
    final body = <String, dynamic>{
      'user_id': userId.toString(),
    };

    if (notificationId != null) {
      body['notification_id'] = notificationId.toString();
    }

    final response = await ApiService.post(
      '${ApiConfig.notifications}?action=read',
      body: body,
    );

    if (response['success'] == true) {
      return response['message'] ?? 'Notification marked as read';
    } else {
      throw ApiException(response['message'] ?? 'Failed to mark notification as read');
    }
  }

  /// Get Unread Count
  /// 
  /// Parameters:
  /// - userId: User ID
  /// 
  /// Returns: Unread notification count
  static Future<int> getUnreadCount(int userId) async {
    final response = await ApiService.get(
      '${ApiConfig.notifications}?action=unread-count',
      queryParameters: {'user_id': userId.toString()},
    );

    if (response['success'] == true && response['data'] != null) {
      return response['data']['unread_count'] as int;
    } else {
      throw ApiException(response['message'] ?? 'Failed to fetch unread count');
    }
  }
}

