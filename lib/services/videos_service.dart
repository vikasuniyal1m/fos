import 'dart:io';
import '../config/api_config.dart';
import 'api_service.dart';

/// Videos Service
/// Handles video listing, uploading, and live videos
class VideosService {
  /// Get Videos
  /// 
  /// Parameters:
  /// - status: Filter by status (default: 'Approved')
  /// - fruitTag: Filter by fruit tag
  /// - userId: Filter by user ID
  /// - limit: Number of results (default: 20)
  /// - offset: Pagination offset (default: 0)
  /// 
  /// Returns: List of videos
  static Future<List<Map<String, dynamic>>> getVideos({
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
    if (currentUserId != null) queryParams['current_user_id'] = currentUserId.toString();

    final response = await ApiService.get(
      ApiConfig.videos,
      queryParameters: queryParams,
    );

    if (response['success'] == true && response['data'] != null) {
      return List<Map<String, dynamic>>.from(response['data']);
    } else {
      throw ApiException(response['message'] ?? 'Failed to fetch videos');
    }
  }

  /// Get Single Video with Comments
  /// 
  /// Parameters:
  /// - videoId: Video ID
  /// 
  /// Returns: Video with comments
  static Future<Map<String, dynamic>> getVideoDetails(int videoId, {int? currentUserId}) async {
    final queryParams = {'id': videoId.toString()};
    if (currentUserId != null) {
      queryParams['current_user_id'] = currentUserId.toString();
    }
    
    final response = await ApiService.get(
      ApiConfig.videos,
      queryParameters: queryParams,
    );

    if (response['success'] == true && response['data'] != null) {
      return response['data'] as Map<String, dynamic>;
    } else {
      throw ApiException(response['message'] ?? 'Failed to fetch video details');
    }
  }

  /// Upload Video
  /// 
  /// Parameters:
  /// - userId: User ID
  /// - videoFile: Video file to upload
  /// - thumbnailFile: Thumbnail file (optional, will be generated if not provided)
  /// - fruitTag: Tag video with fruit (optional)
  /// - title: Video title (optional)
  /// 
  /// Returns: Uploaded video ID and file path
  static Future<Map<String, dynamic>> uploadVideo({
    required int userId,
    required File videoFile,
    File? thumbnailFile,
    String? fruitTag,
    String? title,
    String? description,
    String? category,
  }) async {
    final fields = <String, String>{
      'user_id': userId.toString(),
    };

    if (fruitTag != null) fields['fruit_tag'] = fruitTag;
    if (title != null && title.isNotEmpty) fields['title'] = title;
    if (description != null && description.isNotEmpty) fields['description'] = description;
    if (category != null && category.isNotEmpty) fields['category'] = category;

    print('📤 VideosService.uploadVideo: Fields: $fields');
    try {
      final files = <String, File>{'video': videoFile};
      if (thumbnailFile != null) {
        final thumbnailExists = await thumbnailFile.exists();
        print('📤 Thumbnail file check: exists=$thumbnailExists, path=${thumbnailFile.path}');
        if (thumbnailExists) {
          final thumbnailSize = await thumbnailFile.length();
          print('📤 Adding thumbnail to upload: ${thumbnailFile.path} (${thumbnailSize} bytes)');
          files['thumbnail'] = thumbnailFile;
        } else {
          print('⚠️ Thumbnail file does not exist, skipping upload');
        }
      } else {
        print('⚠️ No thumbnail file provided');
      }
      
      print('📤 Uploading ${files.length} file(s): ${files.keys.join(", ")}');
      final response = await ApiService.postMultipart(
        ApiConfig.videos,
        fields: fields,
        files: files,
      );

      print('📤 Video upload response: ${response['success']}, message: ${response['message']}');

      if (response['success'] == true && response['data'] != null) {
        return response['data'] as Map<String, dynamic>;
      } else {
        final errorMsg = response['message'] ?? 'Failed to upload video';
        print('❌ Video upload failed: $errorMsg');
        throw ApiException(errorMsg);
      }
    } catch (e) {
      print('❌ Video upload exception: $e');
      rethrow;
    }
  }

  /// Get Live Videos
  /// 
  /// Parameters:
  /// - status: Filter by status (default: 'Live')
  /// 
  /// Returns: List of live videos
  static Future<List<Map<String, dynamic>>> getLiveVideos({
    String status = 'Live',
  }) async {
    final response = await ApiService.get(
      '${ApiConfig.videos}?action=live',
      queryParameters: {'status': status},
    );

    if (response['success'] == true && response['data'] != null) {
      return List<Map<String, dynamic>>.from(response['data']);
    } else {
      throw ApiException(response['message'] ?? 'Failed to fetch live videos');
    }
  }

  // edit feature: Edit Video (15-minute window)
  /// Edit Video (15-minute window)
  ///
  /// Parameters:
  /// - userId: User ID (must be the video owner)
  /// - videoId: Video ID to edit
  /// - title: New title (optional)
  /// - description: New description (optional)
  /// - category: New category (optional)
  ///
  /// Returns: Success status
  static Future<Map<String, dynamic>> editVideo({ // edit feature
    required int userId, // edit feature
    required int videoId, // edit feature
    String? title, // edit feature
    String? description, // edit feature
    String? category, // edit feature
  }) async { // edit feature
    final body = <String, String>{ // edit feature
      'action': 'edit', // edit feature
      'user_id': userId.toString(), // edit feature
      'video_id': videoId.toString(), // edit feature
    }; // edit feature

    if (title != null) body['title'] = title; // edit feature
    if (description != null) body['description'] = description; // edit feature
    if (category != null) body['category'] = category; // edit feature

    final response = await ApiService.post( // edit feature
      ApiConfig.videos, // edit feature
      body: body, // edit feature
    ); // edit feature

    if (response['success'] == true) { // edit feature
      return response; // edit feature
    } else { // edit feature
      throw ApiException(response['message'] ?? 'Failed to edit video'); // edit feature
    } // edit feature
  } // edit feature
}

