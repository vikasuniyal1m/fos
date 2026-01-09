import 'dart:io';
import '../config/api_config.dart';
import 'api_service.dart';

/// Group Posts Service
/// Handles group posts, reactions, and community interactions
class GroupPostsService {
  /// Get Group Posts
  /// 
  /// Parameters:
  /// - groupId: Group ID
  /// - userId: Current user ID (optional, for checking reactions)
  /// - limit: Number of results (default: 20)
  /// - offset: Pagination offset (default: 0)
  /// 
  /// Returns: List of group posts with reactions and comment counts
  static Future<List<Map<String, dynamic>>> getGroupPosts({
    required int groupId,
    int? userId,
    int limit = 20,
    int offset = 0,
  }) async {
    final queryParams = <String, String>{
      'group_id': groupId.toString(),
      'limit': limit.toString(),
      'offset': offset.toString(),
    };

    if (userId != null && userId > 0) {
      queryParams['user_id'] = userId.toString();
    }

    final response = await ApiService.get(
      '${ApiConfig.groups}?action=posts',
      queryParameters: queryParams,
    );

    if (response['success'] == true && response['data'] != null) {
      return List<Map<String, dynamic>>.from(response['data']);
    } else {
      throw ApiException(response['message'] ?? 'Failed to fetch group posts');
    }
  }

  /// Create Group Post
  /// 
  /// Parameters:
  /// - userId: User ID
  /// - groupId: Group ID
  /// - content: Post content
  /// - postType: Type of post ('text', 'prayer', 'event', 'update')
  /// - image: Optional image file
  /// - eventDate: Optional event date (for event posts)
  /// 
  /// Returns: Created post data
  static Future<Map<String, dynamic>> createGroupPost({
    required int userId,
    required int groupId,
    required String content,
    String postType = 'text',
    File? image,
    String? eventDate,
  }) async {
    final fields = <String, String>{
      'user_id': userId.toString(),
      'group_id': groupId.toString(),
      'content': content,
      'post_type': postType,
    };

    if (eventDate != null && eventDate.isNotEmpty) {
      fields['event_date'] = eventDate;
    }

    final files = <String, File>{};
    if (image != null) {
      files['image'] = image;
    }

    final response = await ApiService.postMultipart(
      '${ApiConfig.groups}?action=posts',
      fields: fields,
      files: files.isNotEmpty ? files : null,
    );

    if (response['success'] == true && response['data'] != null) {
      return response['data'] as Map<String, dynamic>;
    } else {
      throw ApiException(response['message'] ?? 'Failed to create post');
    }
  }

  /// React to Post
  /// 
  /// Parameters:
  /// - userId: User ID
  /// - postId: Post ID
  /// - emojiCode: Emoji code (e.g., 'love', 'prayer', 'joy')
  /// 
  /// Returns: Reaction status and updated reactions
  static Future<Map<String, dynamic>> reactToPost({
    required int userId,
    required int postId,
    required String emojiCode,
  }) async {
    final response = await ApiService.post(
      '${ApiConfig.groups}?action=react',
      body: {
        'user_id': userId.toString(),
        'post_id': postId.toString(),
        'emoji_code': emojiCode,
      },
    );

    if (response['success'] == true && response['data'] != null) {
      return response['data'] as Map<String, dynamic>;
    } else {
      throw ApiException(response['message'] ?? 'Failed to react to post');
    }
  }

  /// Get Post Reactions
  /// 
  /// Parameters:
  /// - postId: Post ID
  /// 
  /// Returns: List of reactions with user info
  static Future<List<Map<String, dynamic>>> getPostReactions(int postId) async {
    final response = await ApiService.get(
      '${ApiConfig.groups}?action=reactions',
      queryParameters: {'post_id': postId.toString()},
    );

    if (response['success'] == true && response['data'] != null) {
      return List<Map<String, dynamic>>.from(response['data']);
    } else {
      throw ApiException(response['message'] ?? 'Failed to fetch reactions');
    }
  }
}

