import '../config/api_config.dart';
import 'api_service.dart';

/// Advanced Features Service
/// Handles: Report content, Block user, Follow/Unfollow, Share content, Save/Bookmark
class AdvancedService {
  /// Report Content
  /// 
  /// Parameters:
  /// - userId: User ID
  /// - contentType: Content type ('blog', 'prayer', 'video', 'photo', 'story')
  /// - contentId: Content ID
  /// - reason: Report reason (optional)
  /// - description: Report description (optional)
  /// 
  /// Returns: Success message
  static Future<String> reportContent({
    required int userId,
    required String contentType,
    required int contentId,
    String? reason,
    String? description,
  }) async {
    final body = <String, dynamic>{
      'user_id': userId.toString(),
      'content_type': contentType,
      'content_id': contentId.toString(),
    };

    if (reason != null) body['reason'] = reason;
    if (description != null) body['description'] = description;

    final response = await ApiService.post(
      '${ApiConfig.advanced}?action=report',
      body: body,
    );

    if (response['success'] == true) {
      return response['message'] ?? 'Content reported successfully';
    } else {
      throw ApiException(response['message'] ?? 'Failed to report content');
    }
  }

  /// Block User
  /// 
  /// Parameters:
  /// - userId: User ID
  /// - blockedUserId: User ID to block
  /// 
  /// Returns: Success message
  static Future<String> blockUser({
    required int userId,
    required int blockedUserId,
  }) async {
    final response = await ApiService.post(
      '${ApiConfig.advanced}?action=block',
      body: {
        'user_id': userId.toString(),
        'blocked_user_id': blockedUserId.toString(),
      },
    );

    if (response['success'] == true) {
      return response['message'] ?? 'User blocked successfully';
    } else {
      throw ApiException(response['message'] ?? 'Failed to block user');
    }
  }

  /// Unblock User
  /// 
  /// Parameters:
  /// - userId: User ID
  /// - blockedUserId: User ID to unblock
  /// 
  /// Returns: Success message
  static Future<String> unblockUser({
    required int userId,
    required int blockedUserId,
  }) async {
    final response = await ApiService.post(
      '${ApiConfig.advanced}?action=unblock',
      body: {
        'user_id': userId.toString(),
        'blocked_user_id': blockedUserId.toString(),
      },
    );

    if (response['success'] == true) {
      return response['message'] ?? 'User unblocked successfully';
    } else {
      throw ApiException(response['message'] ?? 'Failed to unblock user');
    }
  }

  /// Follow User
  /// 
  /// Parameters:
  /// - userId: User ID
  /// - followUserId: User ID to follow
  /// 
  /// Returns: Success message
  static Future<String> followUser({
    required int userId,
    required int followUserId,
  }) async {
    final response = await ApiService.post(
      '${ApiConfig.advanced}?action=follow',
      body: {
        'user_id': userId.toString(),
        'follow_user_id': followUserId.toString(),
      },
    );

    if (response['success'] == true) {
      return response['message'] ?? 'User followed successfully';
    } else {
      throw ApiException(response['message'] ?? 'Failed to follow user');
    }
  }

  /// Unfollow User
  /// 
  /// Parameters:
  /// - userId: User ID
  /// - followUserId: User ID to unfollow
  /// 
  /// Returns: Success message
  static Future<String> unfollowUser({
    required int userId,
    required int followUserId,
  }) async {
    final response = await ApiService.post(
      '${ApiConfig.advanced}?action=unfollow',
      body: {
        'user_id': userId.toString(),
        'follow_user_id': followUserId.toString(),
      },
    );

    if (response['success'] == true) {
      return response['message'] ?? 'User unfollowed successfully';
    } else {
      throw ApiException(response['message'] ?? 'Failed to unfollow user');
    }
  }

  /// Share Content
  /// 
  /// Parameters:
  /// - userId: User ID
  /// - contentType: Content type
  /// - contentId: Content ID
  /// - platform: Platform name (optional: 'facebook', 'twitter', 'whatsapp', etc.)
  /// 
  /// Returns: Share link
  static Future<String> shareContent({
    required int userId,
    required String contentType,
    required int contentId,
    String? platform,
  }) async {
    final body = <String, dynamic>{
      'user_id': userId.toString(),
      'content_type': contentType,
      'content_id': contentId.toString(),
    };

    if (platform != null) body['platform'] = platform;

    final response = await ApiService.post(
      '${ApiConfig.advanced}?action=share',
      body: body,
    );

    if (response['success'] == true && response['data'] != null) {
      return response['data']['share_link'] as String;
    } else {
      throw ApiException(response['message'] ?? 'Failed to share content');
    }
  }

  /// Save Content
  /// 
  /// Parameters:
  /// - userId: User ID
  /// - contentType: Content type
  /// - contentId: Content ID
  /// 
  /// Returns: Success message
  static Future<String> saveContent({
    required int userId,
    required String contentType,
    required int contentId,
  }) async {
    final response = await ApiService.post(
      '${ApiConfig.advanced}?action=save',
      body: {
        'user_id': userId.toString(),
        'content_type': contentType,
        'content_id': contentId.toString(),
      },
    );

    if (response['success'] == true) {
      return response['message'] ?? 'Content saved successfully';
    } else {
      throw ApiException(response['message'] ?? 'Failed to save content');
    }
  }

  /// Unsave Content
  /// 
  /// Parameters:
  /// - userId: User ID
  /// - contentType: Content type
  /// - contentId: Content ID
  /// 
  /// Returns: Success message
  static Future<String> unsaveContent({
    required int userId,
    required String contentType,
    required int contentId,
  }) async {
    final response = await ApiService.post(
      '${ApiConfig.advanced}?action=unsave',
      body: {
        'user_id': userId.toString(),
        'content_type': contentType,
        'content_id': contentId.toString(),
      },
    );

    if (response['success'] == true) {
      return response['message'] ?? 'Content unsaved successfully';
    } else {
      throw ApiException(response['message'] ?? 'Failed to unsave content');
    }
  }

  /// Get Saved Content
  /// 
  /// Parameters:
  /// - userId: User ID
  /// - contentType: Content type filter ('all' for all types)
  /// - limit: Number of results (default: 20)
  /// - offset: Pagination offset (default: 0)
  /// 
  /// Returns: List of saved content
  static Future<List<Map<String, dynamic>>> getSavedContent({
    required int userId,
    String contentType = 'all',
    int limit = 20,
    int offset = 0,
  }) async {
    final queryParams = <String, String>{
      'action': 'saved',
      'user_id': userId.toString(),
      'content_type': contentType,
      'limit': limit.toString(),
      'offset': offset.toString(),
    };

    final response = await ApiService.get(
      ApiConfig.advanced,
      queryParameters: queryParams,
    );

    if (response['success'] == true && response['data'] != null) {
      return List<Map<String, dynamic>>.from(response['data']);
    } else {
      throw ApiException(response['message'] ?? 'Failed to fetch saved content');
    }
  }
}

