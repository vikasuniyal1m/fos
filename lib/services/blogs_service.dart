import 'dart:io';
import '../config/api_config.dart';
import 'api_service.dart';

/// Blogs Service
/// Handles blogs listing, creation, comments, and likes
class BlogsService {
  /// Get Blogs
  /// 
  /// Parameters:
  /// - status: Filter by status (default: 'Approved')
  /// - category: Filter by category
  /// - language: Filter by language
  /// - userId: Filter by user ID
  /// - isFeatured: Filter featured blogs (0 or 1)
  /// - isTrending: Filter trending blogs (0 or 1)
  /// - limit: Number of results (default: 20)
  /// - offset: Pagination offset (default: 0)
  /// 
  /// Returns: List of blogs
  static Future<List<Map<String, dynamic>>> getBlogs({
    String status = 'Approved',
    String? category,
    String? language,
    int? userId,
    int? isFeatured,
    int? isTrending,
    int? currentUserId,
    int limit = 20,
    int offset = 0,
  }) async {
    final queryParams = <String, String>{
      'status': status,
      'limit': limit.toString(),
      'offset': offset.toString(),
    };

    if (category != null) queryParams['category'] = category;
    if (language != null) queryParams['language'] = language;
    if (userId != null) queryParams['user_id'] = userId.toString();
    if (isFeatured != null) queryParams['is_featured'] = isFeatured.toString();
    if (isTrending != null) queryParams['is_trending'] = isTrending.toString();
    if (currentUserId != null) queryParams['current_user_id'] = currentUserId.toString();

    final response = await ApiService.get(
      ApiConfig.blogs,
      queryParameters: queryParams,
    );

    if (response['success'] == true && response['data'] != null) {
      return List<Map<String, dynamic>>.from(response['data']);
    } else {
      throw ApiException(response['message'] ?? 'Failed to fetch blogs');
    }
  }

  /// Get Single Blog with Comments and Likes
  /// 
  /// Parameters:
  /// - blogId: Blog ID
  /// 
  /// Returns: Blog with comments and likes
  static Future<Map<String, dynamic>> getBlogDetails(int blogId, {int? currentUserId}) async {
    final queryParams = {'id': blogId.toString()};
    if (currentUserId != null) {
      queryParams['current_user_id'] = currentUserId.toString();
    }
    
    final response = await ApiService.get(
      ApiConfig.blogs,
      queryParameters: queryParams,
    );

    if (response['success'] == true && response['data'] != null) {
      return response['data'] as Map<String, dynamic>;
    } else {
      throw ApiException(response['message'] ?? 'Failed to fetch blog details');
    }
  }

  /// Create Blog (Bloggers Only)
  /// 
  /// Parameters:
  /// - userId: User ID (must be Blogger role)
  /// - title: Blog title
  /// - body: Blog content
  /// - category: Blog category
  /// - language: Blog language (default: 'en')
  /// - image: Blog image file (optional)
  /// 
  /// Returns: Created blog ID
  static Future<int> createBlog({
    required int userId,
    required String title,
    required String body,
    required String category,
    String language = 'en',
    File? image,
  }) async {
    final fields = <String, String>{
      'user_id': userId.toString(),
      'title': title,
      'body': body,
      'category': category,
      'language': language,
    };

    final files = <String, File>{};
    if (image != null) {
      files['image'] = image;
    }

    final response = await ApiService.postMultipart(
      ApiConfig.blogs,
      fields: fields,
      files: files.isNotEmpty ? files : null,
    );

    if (response['success'] == true && response['data'] != null) {
      return response['data']['id'] as int;
    } else {
      throw ApiException(response['message'] ?? 'Failed to create blog');
    }
  }

  /// Request to Become a Blogger
  /// 
  /// Parameters:
  /// - userId: User ID requesting blogger access
  /// 
  /// Returns: Success status
  static Future<bool> requestBloggerAccess({required int userId}) async {
    final response = await ApiService.post(
      ApiConfig.blogs,
      body: {
        'action': 'request-blogger',
        'user_id': userId.toString(),
      },
    );

    if (response['success'] == true) {
      return true;
    } else {
      throw ApiException(response['message'] ?? 'Failed to send request');
    }
  }
}

