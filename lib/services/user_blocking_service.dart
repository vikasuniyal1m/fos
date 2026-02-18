import '../config/api_config.dart';
import 'auth_service.dart';
import 'api_service.dart';
import 'user_storage.dart';

/// User Blocking Service
/// Handles blocking and unblocking users
class UserBlockingService {
  /// Block a user
  static Future<bool> blockUser(int blockedUserId, {String? reason}) async {
    final user = await UserStorage.getUser();
    if (user == null) throw Exception('User not logged in');

    final response = await ApiService.post(
      ApiConfig.blockUser,
      body: {
        'action': 'block',
        'user_id': user['id'].toString(),
        'blocked_user_id': blockedUserId.toString(),
        'reason': reason ?? '',
      },
    );

    if (response['success'] == true) {
      return true;
    } else {
      throw ApiException(response['message'] ?? 'Failed to block user');
    }
  }

  /// Unblock a user
  static Future<bool> unblockUser(int blockedUserId) async {
    final user = await UserStorage.getUser();
    if (user == null) throw Exception('User not logged in');

    final response = await ApiService.post(
      ApiConfig.blockUser,
      body: {
        'action': 'unblock',
        'user_id': user['id'].toString(),
        'blocked_user_id': blockedUserId.toString(),
      },
    );

    if (response['success'] == true) {
      return true;
    } else {
      throw ApiException(response['message'] ?? 'Failed to unblock user');
    }
  }

  /// Get list of blocked users
  static Future<List<Map<String, dynamic>>> getBlockedUsers() async {
    final user = await UserStorage.getUser();
    if (user == null) throw Exception('User not logged in');

    final response = await ApiService.get(
      '${ApiConfig.blockUser}?user_id=${user['id']}&action=list',
    );

    if (response['success'] == true && response['data'] != null) {
      return List<Map<String, dynamic>>.from(response['data']);
    } else {
      return [];
    }
  }
}
