import '../config/api_config.dart';
import 'api_service.dart';
import 'report_service.dart';

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
    // Use the unified report service instead of the comments-specific endpoint
    // This ensures consistent reporting behavior across all content types
    final success = await ReportService.reportContent(
      contentType: 'comment',
      contentId: commentId,
      reason: reason ?? 'General concern',
      description: '',
    );

    if (success) {
      // Return commentId as a placeholder since the unified service doesn't return an ID
      return commentId;
    } else {
      throw ApiException('Failed to report comment');
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

  // edit feature: Edit Comment
  /// Edit Comment (15-minute window)
  ///
  /// Parameters:
  /// - userId: User ID
  /// - commentId: Comment ID
  /// - postType: Type of post ('prayer', 'blog', 'video', 'gallery', 'story')
  /// - postId: Post ID
  /// - content: New comment content
  /// 
  /// Edit an existing comment
  static Future<Map<String, dynamic>> editComment({
    required int userId,
    required int commentId,
    required String postType,
    required int postId,
    required String content,
  }) async {
    try {
      // COMPREHENSIVE FRONTEND DEBUG
      print('🔍 FRONTEND EDIT DEBUG - START ANALYSIS'); // debug
      print('🔍 COMMENT ID $commentId FRONTEND ANALYSIS'); // debug
      
      // Get current timezone offset
      final now = DateTime.now();
      final offset = now.timeZoneOffset;
      final offsetHours = offset.inHours;
      final offsetMinutes = offset.inMinutes % 60;
      final timezoneOffset = '${offsetHours >= 0 ? '+' : '-'}${offsetHours.abs().toString().padLeft(2, '0')}:${offsetMinutes.abs().toString().padLeft(2, '0')}';
      
      print('🔍 Current device time: ${now.toString()}'); // debug
      print('🔍 Current device timezone: ${now.timeZoneName}'); // debug
      print('🔍 Timezone offset: $timezoneOffset'); // debug
      print('🔍 Edit Comment Request: userId=$userId, commentId=$commentId, postType=$postType'); // debug
      print('🔍 Comment content: "$content"'); // debug
      print('🔍 FRONTEND DEBUG - END ANALYSIS'); // debug

      print('📤 Edit Comment Request: userId=$userId, commentId=$commentId, postType=$postType'); // edit feature

      final body = { // edit feature
        'user_id': userId, // edit feature
        'comment_id': commentId, // edit feature
        'post_type': postType, // edit feature
        'post_id': postId, // edit feature
        'content': content, // edit feature
        'timezone_offset': timezoneOffset, // edit feature
      }; // edit feature

      final response = await ApiService.post( // edit feature
        '${ApiConfig.comments}?action=edit', // edit feature
        body: body, // edit feature
      ); // edit feature

      if (response['success'] == true && response['data'] != null) { // edit feature
        print('✅ Comment edited successfully'); // edit feature
        return response['data'] as Map<String, dynamic>; // edit feature
      } else { // edit feature
        // DETAILED ERROR ANALYSIS WITH BACKEND DEBUG INFO
        print('❌ EDIT FAILED - DETAILED ANALYSIS'); // debug
        print('❌ Error message: ${response['message']}'); // debug
        print('❌ Current device time: ${now.toString()}'); // debug
        print('❌ Device timezone: ${now.timeZoneName}'); // debug
        print('❌ Sent timezone offset: $timezoneOffset'); // debug
        print('❌ Comment ID: $commentId'); // debug
        print('❌ WHY EDIT FAILED: Backend rejected edit request'); // debug
        
        // Show backend debug info if available
        if (response['data'] != null) {
          print('❌ BACKEND DEBUG INFO:'); // debug
          final debugData = response['data'] as Map<String, dynamic>;
          print('   - Created at: ${debugData['created_at']}'); // debug
          print('   - Created at (fixed): ${debugData['created_at_fixed']}'); // debug
          print('   - Current UTC: ${debugData['current_utc']}'); // debug
          print('   - Minutes difference: ${debugData['minutes_diff']}'); // debug
          print('   - Days: ${debugData['days']}, Hours: ${debugData['hours']}, Minutes: ${debugData['minutes']}'); // debug
          print('   - Time ago: ${debugData['time_ago']}'); // debug
          print('   - Backend timezone offset: ${debugData['timezone_offset']}'); // debug
          print('   - Logic used: ${debugData['logic_used']}'); // debug
          print('❌ BACKEND ANALYSIS: Comment is ${debugData['time_ago']} (${debugData['minutes_diff']} minutes old) - using same logic as edit button'); // debug
        } else {
          print('❌ POSSIBLE REASONS:'); // debug
          print('   1. Comment is older than 15 minutes (backend calculation)'); // debug
          print('   2. Backend timezone calculation mismatch'); // debug
          print('   3. Backend not receiving timezone_offset correctly'); // debug
          print('   4. Comment creation time in database is too old'); // debug
        }
        print('❌ FRONTEND ANALYSIS COMPLETE'); // debug
        
        throw ApiException(response['message'] ?? 'Failed to edit comment'); // edit feature
      } // edit feature
    } catch (e) { // edit feature
      print('❌ Edit comment error: $e'); // debug
      print('❌ ERROR TYPE: Network/API failure'); // debug
      throw ApiException('Failed to edit comment: $e'); // edit feature
    } // edit feature
  } // edit feature
}

