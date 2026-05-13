import 'dart:io';
import '../config/api_config.dart';
import 'api_service.dart';

/// Gallery Service
/// Handles photo listing and uploading
class GalleryService {
  /// Get Gallery Photos
  ///
  /// Parameters:
  /// - status: Filter by status (default: 'Approved')
  /// - fruitTag: Filter by fruit tag
  /// - userId: Filter by user ID
  /// - currentUserId: Current logged-in user ID (for like status)
  /// - limit: Number of results (default: 20)
  /// - offset: Pagination offset (default: 0)
  ///
  /// Returns: List of photos
  static Future<List<Map<String, dynamic>>> getPhotos({
    String status = 'Approved',
    String? fruitTag,
    int? userId,
    int? currentUserId,
    int limit = 20,
    int offset = 0,
  }) async {
    final queryParams = <String, String>{
      'status': status,
      'limit': limit.toString(),
      'offset': offset.toString(),
    };

    if (fruitTag != null) queryParams['fruit_tag'] = fruitTag;
    if (userId != null) queryParams['user_id'] = userId.toString();
    if (currentUserId != null && currentUserId > 0) {
      queryParams['current_user_id'] = currentUserId.toString();
    }

    final response = await ApiService.get(
      ApiConfig.gallery,
      queryParameters: queryParams,
    );

    if (response['success'] == true && response['data'] != null) {
      return List<Map<String, dynamic>>.from(response['data']);
    } else {
      throw ApiException(response['message'] ?? 'Failed to fetch photos');
    }
  }

  /// Get Single Photo with Comments
  ///
  /// Parameters:
  /// - photoId: Photo ID
  /// - currentUserId: Current logged-in user ID (optional, for like status)
  ///
  /// Returns: Photo with comments
  static Future<Map<String, dynamic>> getPhotoDetails(int photoId, {int? currentUserId}) async {
    final queryParams = <String, String>{
      'id': photoId.toString(),
    };

    if (currentUserId != null && currentUserId > 0) {
      queryParams['current_user_id'] = currentUserId.toString();
    }

    final response = await ApiService.get(
      ApiConfig.gallery,
      queryParameters: queryParams,
    );

    if (response['success'] == true && response['data'] != null) {
      return response['data'] as Map<String, dynamic>;
    } else {
      throw ApiException(response['message'] ?? 'Failed to fetch photo details');
    }
  }

  /// Upload Photo
  ///
  /// Parameters:
  /// - userId: User ID
  /// - photoFile: Photo file to upload
  /// - fruitTag: Tag photo with fruit (optional)
  /// - testimony: Story/testimony behind the photo (optional)
  /// - feelingTags: Comma-separated feeling tags (optional)
  /// - hashtags: Comma-separated hashtags (optional)
  /// - allowComments: Whether to allow comments (default: true)
  ///
  /// Returns: Uploaded photo ID and file path
  static Future<Map<String, dynamic>> uploadPhoto({
    required int userId,
    required File photoFile,
    String? fruitTag,
    String? testimony,
    String? feelingTags,
    String? hashtags,
    bool allowComments = true,
  }) async {
    final fields = <String, String>{
      'user_id': userId.toString(),
      'allow_comments': allowComments ? '1' : '0',
    };

    if (fruitTag != null && fruitTag.isNotEmpty) fields['fruit_tag'] = fruitTag;
    if (testimony != null && testimony.isNotEmpty) fields['testimony'] = testimony;
    if (feelingTags != null && feelingTags.isNotEmpty) fields['feeling_tags'] = feelingTags;
    if (hashtags != null && hashtags.isNotEmpty) fields['hashtags'] = hashtags;

    final response = await ApiService.postMultipart(
      ApiConfig.gallery,
      fields: fields,
      files: {'photo': photoFile},
    );

    if (response['success'] == true && response['data'] != null) {
      return response['data'] as Map<String, dynamic>;
    } else {
      throw ApiException(response['message'] ?? 'Failed to upload photo');
    }
  }

  /// Toggle Like/Unlike Photo
  ///
  /// Parameters:
  /// - userId: User ID
  /// - photoId: Photo ID
  ///
  /// Returns: Map with 'liked' (bool) and 'like_count' (int)
  static Future<Map<String, dynamic>> toggleLike({
    required int userId,
    required int photoId,
  }) async {
    // Check if already liked by getting photo details first
    final photoDetails = await getPhotoDetails(photoId);
    final isLiked = photoDetails['is_liked'] == true || photoDetails['is_liked'] == 1;

    final action = isLiked ? 'unlike' : 'like';

    final response = await ApiService.post(
      ApiConfig.gallery,
      body: {
        'action': action,
        'user_id': userId.toString(),
        'media_id': photoId.toString(),
      },
    );

    if (response['success'] == true && response['data'] != null) {
      return response['data'] as Map<String, dynamic>;
    } else {
      throw ApiException(response['message'] ?? 'Failed to toggle like');
    }
  }

  /// Add Comment to Photo (Alternative method through gallery API)
  ///
  /// Parameters:
  /// - userId: User ID
  /// - photoId: Photo ID
  /// - content: Comment content
  /// - parentCommentId: Parent comment ID for replies (optional)
  ///
  /// Returns: Created comment ID
  static Future<int> addComment({
    required int userId,
    required int photoId,
    required String content,
    int? parentCommentId,
  }) async {
    final body = <String, String>{
      'action': 'add-comment',
      'user_id': userId.toString(),
      'photo_id': photoId.toString(),
      'content': content,
    };

    if (parentCommentId != null && parentCommentId > 0) {
      body['parent_comment_id'] = parentCommentId.toString();
    }

    final response = await ApiService.post(
      ApiConfig.gallery,
      body: body,
    );

    if (response['success'] == true && response['data'] != null) {
      final commentId = response['data']['id'] as int? ??
                       (response['data'] as Map<String, dynamic>)['comment_id'] as int? ?? 0;
      print('✅ Comment added successfully: ID=$commentId');
      print('📊 📋 TABLE: gallery_comments - Entry saved successfully!');
      print('📊 📋 SQL Query would be: INSERT INTO gallery_comments (user_id, photo_id, content, parent_comment_id) VALUES ($userId, $photoId, "${content.substring(0, content.length > 50 ? 50 : content.length)}...", ${parentCommentId ?? "NULL"})');
      return commentId;
    } else {
      print('❌ Database Status: Entry NOT saved to gallery_comments table');
      print('📊 📋 TABLE: gallery_comments - Save FAILED');
      throw ApiException(response['message'] ?? 'Failed to add comment');
    }
  }

  /// Get Comments for Photo (Alternative method through gallery API)
  ///
  /// Parameters:
  /// - photoId: Photo ID
  /// - userId: Current user ID (optional, for checking likes)
  ///
  /// Returns: List of comments with nested replies
  static Future<List<Map<String, dynamic>>> getComments({
    required int photoId,
    int? userId,
  }) async {
    final queryParams = <String, String>{
      'action': 'get-comments',
      'photo_id': photoId.toString(),
    };

    if (userId != null && userId > 0) {
      queryParams['user_id'] = userId.toString();
    }

    final response = await ApiService.get(
      ApiConfig.gallery,
      queryParameters: queryParams,
    );

    if (response['success'] == true && response['data'] != null) {
      return List<Map<String, dynamic>>.from(response['data']);
    } else {
      throw ApiException(response['message'] ?? 'Failed to fetch comments');
    }
  }

  // edit feature: Edit Photo (15-minute window)
  /// Edit Photo (15-minute window)
  ///
  /// Parameters:
  /// - userId: User ID (must be the photo owner)
  /// - mediaId: Photo ID to edit
  /// - title: New title (optional)
  /// - description: New description (optional)
  /// - category: New category (optional)
  ///
  /// Returns: Success status
  static Future<Map<String, dynamic>> editPhoto({ // edit feature
    required int userId, // edit feature
    required int mediaId, // edit feature
    String? title, // edit feature
    String? description, // edit feature
    String? category, // edit feature
  }) async { // edit feature
    final body = <String, String>{ // edit feature
      'action': 'edit', // edit feature
      'user_id': userId.toString(), // edit feature
      'media_id': mediaId.toString(), // edit feature
    }; // edit feature

    if (title != null) body['title'] = title; // edit feature
    if (description != null) body['description'] = description; // edit feature
    if (category != null) body['category'] = category; // edit feature

    final response = await ApiService.post( // edit feature
      ApiConfig.gallery, // edit feature
      body: body, // edit feature
    ); // edit feature

    if (response['success'] == true) { // edit feature
      return response; // edit feature
    } else { // edit feature
      throw ApiException(response['message'] ?? 'Failed to edit photo'); // edit feature
    } // edit feature
  } // edit feature

  /// Edit Comment (15-minute window)
  ///
  /// Parameters:
  /// - userId: User ID (must be the comment owner)
  /// - commentId: Comment ID to edit
  /// - content: New comment content
  /// - photoId: Photo ID the comment belongs to
  ///
  /// Returns: Success status
  static Future<Map<String, dynamic>> editComment({
    required int userId,
    required int commentId,
    required String content,
    required int photoId,
  }) async {
    final body = <String, String>{
      'action': 'edit-comment',
      'user_id': userId.toString(),
      'comment_id': commentId.toString(),
      'content': content,
      'photo_id': photoId.toString(),
    };

    final response = await ApiService.post(
      ApiConfig.gallery,
      body: body,
    );

    if (response['success'] == true) {
      return response;
    } else {
      throw ApiException(response['message'] ?? 'Failed to edit comment');
    }
  }
}

