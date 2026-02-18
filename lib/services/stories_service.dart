import 'dart:io';
import '../config/api_config.dart';
import 'api_service.dart';

/// Stories/Testimonies Service
/// Handles stories listing, creation, and details
class StoriesService {
  /// Get Stories
  /// 
  /// Parameters:
  /// - status: Filter by status (default: 'Approved')
  /// - fruitTag: Filter by fruit tag
  /// - userId: Filter by user ID
  /// - category: Filter by category (testimony, spiritual, encouragement, etc.)
  /// - limit: Number of results (default: 20)
  /// - offset: Pagination offset (default: 0)
  /// 
  /// Returns: List of stories
  static Future<List<Map<String, dynamic>>> getStories({
    String status = 'Approved',
    String? fruitTag,
    int? userId,
    String? category,
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
    if (category != null) queryParams['category'] = category;
    if (currentUserId != null) queryParams['current_user_id'] = currentUserId.toString();

    final response = await ApiService.get(
      ApiConfig.stories,
      queryParameters: queryParams,
    );

    if (response['success'] == true && response['data'] != null) {
      return List<Map<String, dynamic>>.from(response['data']);
    } else {
      throw ApiException(response['message'] ?? 'Failed to fetch stories');
    }
  }

  /// Get Single Story with Comments
  /// 
  /// Parameters:
  /// - storyId: Story ID
  /// 
  /// Returns: Story with comments
  static Future<Map<String, dynamic>> getStoryDetails(int storyId, {int? currentUserId}) async {
    final queryParams = {'id': storyId.toString()};
    if (currentUserId != null) {
      queryParams['current_user_id'] = currentUserId.toString();
    }
    
    final response = await ApiService.get(
      ApiConfig.stories,
      queryParameters: queryParams,
    );

    if (response['success'] == true && response['data'] != null) {
      return response['data'] as Map<String, dynamic>;
    } else {
      throw ApiException(response['message'] ?? 'Failed to fetch story details');
    }
  }

  /// Create Story
  /// 
  /// Parameters:
  /// - userId: User ID
  /// - title: Story title
  /// - content: Story content
  /// - fruitTag: Tag with fruit (optional)
  /// - category: Story category (default: 'testimony')
  /// - image: Story image file (optional)
  /// 
  /// Returns: Created story ID
  static Future<int> createStory({
    required int userId,
    required String title,
    required String content,
    String? fruitTag,
    String category = 'testimony',
    File? image,
  }) async {
    final fields = <String, String>{
      'user_id': userId.toString(),
      'title': title,
      'content': content,
      'category': category,
    };

    if (fruitTag != null) fields['fruit_tag'] = fruitTag;

    final files = <String, File>{};
    if (image != null) {
      files['image'] = image;
    }

    final response = await ApiService.postMultipart(
      ApiConfig.stories,
      fields: fields,
      files: files.isNotEmpty ? files : null,
    );

    if (response['success'] == true && response['data'] != null) {
      return response['data']['id'] as int;
    } else {
      throw ApiException(response['message'] ?? 'Failed to create story');
    }
  }
}

