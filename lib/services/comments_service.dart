import '../config/api_config.dart';
import 'api_service.dart';

/// Comments Service
/// Handles comments on blogs, prayers, videos, gallery
class CommentsService {
  /// Get Comments
  /// 
  /// Parameters:
  /// - postType: Type of post ('prayer', 'blog', 'video', 'gallery', 'story')
  /// - postId: Post ID
  /// - userId: Current user ID (optional, for checking likes)
  /// 
  /// Returns: List of comments with nested replies
  static Future<List<Map<String, dynamic>>> getComments({
    required String postType,
    required int postId,
    int? userId,
  }) async {
    final queryParams = {
      'post_type': postType,
      'post_id': postId.toString(),
    };
    
    if (userId != null && userId > 0) {
      queryParams['user_id'] = userId.toString();
    }
    
    final response = await ApiService.get(
      ApiConfig.comments,
      queryParameters: queryParams,
    );

    if (response['success'] == true && response['data'] != null) {
      return List<Map<String, dynamic>>.from(response['data']);
    } else {
      throw ApiException(response['message'] ?? 'Failed to fetch comments');
    }
  }

  /// Add Comment
  /// 
  /// Parameters:
  /// - userId: User ID
  /// - postType: Type of post ('prayer', 'blog', 'video', 'gallery', 'story')
  /// - postId: Post ID
  /// - content: Comment content
  /// - parentCommentId: Parent comment ID for replies (optional)
  /// 
  /// Returns: Created comment ID
  static Future<int> addComment({
    required int userId,
    required String postType,
    required int postId,
    required String content,
    int? parentCommentId,
  }) async {
    final body = {
      'user_id': userId.toString(),
      'post_type': postType,
      'post_id': postId.toString(),
      'content': content,
    };
    
    if (parentCommentId != null && parentCommentId > 0) {
      body['parent_comment_id'] = parentCommentId.toString();
      print('📤 Adding REPLY with parent_comment_id=$parentCommentId');
    } else {
      print('📤 Adding TOP-LEVEL COMMENT (no parent)');
    }
    
    print('📤 Comment Request Details: userId=$userId, postType=$postType, postId=$postId, content=${content.substring(0, content.length > 50 ? 50 : content.length)}...');
    
    final response = await ApiService.post(
      ApiConfig.comments,
      body: body,
    );

    if (response['success'] == true && response['data'] != null) {
      final commentId = response['data']['id'] as int;
      final isReply = response['data']['is_reply'] == true;
      print('✅ ${isReply ? "Reply" : "Comment"} created: ID=$commentId');
      print('📊 📋 TABLE: comments - Entry saved successfully!');
      print('📊 📋 SQL Query would be: INSERT INTO comments (user_id, post_type, post_id, content, parent_comment_id) VALUES ($userId, "$postType", $postId, "${content.substring(0, content.length > 50 ? 50 : content.length)}...", ${parentCommentId ?? "NULL"})');
      return commentId;
    } else {
      print('❌ Database Status: Entry NOT saved to comments table');
      print('📊 📋 TABLE: comments - Save FAILED');
      throw ApiException(response['message'] ?? 'Failed to add comment');
    }
  }
  
  /// Like/Unlike Comment
  /// 
  /// Parameters:
  /// - userId: User ID
  /// - commentId: Comment ID
  /// 
  /// Returns: Map with 'liked' (bool) and 'like_count' (int)
  static Future<Map<String, dynamic>> toggleCommentLike({
    required int userId,
    required int commentId,
  }) async {
    final response = await ApiService.post(
      '${ApiConfig.comments}?action=like-comment',
      body: {
        'user_id': userId.toString(),
        'comment_id': commentId.toString(),
      },
    );

    if (response['success'] == true && response['data'] != null) {
      return response['data'] as Map<String, dynamic>;
    } else {
      throw ApiException(response['message'] ?? 'Failed to toggle comment like');
    }
  }
  
  /// Report Comment
  /// 
  /// Parameters:
  /// - userId: User ID
  /// - commentId: Comment ID
  /// - reason: Reason for reporting (optional)
  /// 
  /// Returns: Report ID
  static Future<int> reportComment({
    required int userId,
    required int commentId,
    String? reason,
  }) async {
    final body = {
      'user_id': userId.toString(),
      'comment_id': commentId.toString(),
    };
    
    if (reason != null && reason.isNotEmpty) {
      body['reason'] = reason;
    }
    
    final response = await ApiService.post(
      '${ApiConfig.comments}?action=report',
      body: body,
    );

    if (response['success'] == true && response['data'] != null) {
      return response['data']['id'] as int;
    } else {
      throw ApiException(response['message'] ?? 'Failed to report comment');
    }
  }

  /// Like/Unlike Blog
  /// 
  /// Parameters:
  /// - userId: User ID
  /// - blogId: Blog ID
  /// 
  /// Returns: Like status (true if liked, false if unliked)
  static Future<bool> toggleBlogLike({
    required int userId,
    required int blogId,
  }) async {
    final response = await ApiService.post(
      '${ApiConfig.comments}?action=like',
      body: {
        'user_id': userId.toString(),
        'blog_id': blogId.toString(),
      },
    );

    if (response['success'] == true && response['data'] != null) {
      return response['data']['liked'] as bool;
    } else {
      throw ApiException(response['message'] ?? 'Failed to toggle like');
    }
  }
}

