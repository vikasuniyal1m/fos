import '../config/api_config.dart';
import 'api_service.dart';
import 'user_storage.dart';

/// Search Service
/// Handles full-text search across all content types
class SearchService {
  /// Search All Content
  /// 
  /// Parameters:
  /// - query: Search query
  /// - type: Content type ('all', 'blogs', 'prayers', 'videos', 'photos', 'stories')
  /// - fruitTag: Filter by fruit tag (optional)
  /// - limit: Number of results per type (default: 20)
  /// - offset: Pagination offset (default: 0)
  /// 
  /// Returns: Search results grouped by content type
  static Future<Map<String, dynamic>> search({
    String query = '',
    String type = 'all',
    String? fruitTag,
    int limit = 20,
    int offset = 0,
  }) async {
    final queryParams = <String, String>{
      'type': type,
      'limit': limit.toString(),
      'offset': offset.toString(),
    };

    // Add query only if not empty
    if (query.isNotEmpty) {
      queryParams['q'] = query;
    }

    if (fruitTag != null) queryParams['fruit_tag'] = fruitTag;
    
    // Add user_id for authentication
    final userId = await UserStorage.getUserId();
    if (userId != null) {
      queryParams['user_id'] = userId.toString();
    }

    print('🔍 Searching with query: "$query", type: "$type"');
    print('🔍 API URL: ${ApiConfig.search}');
    print('🔍 Query params: $queryParams');
    
    try {
      final response = await ApiService.get(
        ApiConfig.search,
        queryParameters: queryParams,
      );

      print('🔍 Search API Response received');
      print('🔍 Response success: ${response['success']}');
      print('🔍 Response message: ${response['message']}');
      print('🔍 Full response keys: ${response.keys}');
      print('🔍 Full response: $response');
      
      if (response['success'] == true && response['data'] != null) {
        final data = response['data'] as Map<String, dynamic>;
        print('🔍 Search data keys: ${data.keys}');
        print('🔍 Search data type: ${data.runtimeType}');
        print('🔍 Search data: $data');
        
        // Check if results exists
        if (data['results'] != null) {
          final results = data['results'] as Map<String, dynamic>;
          print('🔍 Search results keys: ${results.keys}');
          print('🔍 Blogs count: ${(results['blogs'] as List?)?.length ?? 0}');
          print('🔍 Prayers count: ${(results['prayers'] as List?)?.length ?? 0}');
          print('🔍 Videos count: ${(results['videos'] as List?)?.length ?? 0}');
          print('🔍 Photos count: ${(results['photos'] as List?)?.length ?? 0}');
          print('🔍 Stories count: ${(results['stories'] as List?)?.length ?? 0}');
        } else {
          print('⚠️ Results key is null, initializing empty results');
          data['results'] = {
            'blogs': [],
            'prayers': [],
            'videos': [],
            'photos': [],
            'stories': [],
          };
        }
        
        return data;
      } else {
        final errorMsg = response['message'] ?? 'Search failed';
        print('❌ Search failed: $errorMsg');
        print('❌ Response success: ${response['success']}');
        print('❌ Response data: ${response['data']}');
        print('❌ Full response: $response');
        throw ApiException(errorMsg);
      }
    } catch (e, stackTrace) {
      print('❌ Exception in SearchService.search: $e');
      print('❌ Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Search Blogs
  static Future<List<Map<String, dynamic>>> searchBlogs({
    required String query,
    String? fruitTag,
    int limit = 20,
    int offset = 0,
  }) async {
    final results = await search(
      query: query,
      type: 'blogs',
      fruitTag: fruitTag,
      limit: limit,
      offset: offset,
    );
    return List<Map<String, dynamic>>.from(results['results']['blogs'] ?? []);
  }

  /// Search Prayers
  static Future<List<Map<String, dynamic>>> searchPrayers({
    required String query,
    String? fruitTag,
    int limit = 20,
    int offset = 0,
  }) async {
    final results = await search(
      query: query,
      type: 'prayers',
      fruitTag: fruitTag,
      limit: limit,
      offset: offset,
    );
    return List<Map<String, dynamic>>.from(results['results']['prayers'] ?? []);
  }

  /// Search Videos
  static Future<List<Map<String, dynamic>>> searchVideos({
    required String query,
    String? fruitTag,
    int limit = 20,
    int offset = 0,
  }) async {
    final results = await search(
      query: query,
      type: 'videos',
      fruitTag: fruitTag,
      limit: limit,
      offset: offset,
    );
    return List<Map<String, dynamic>>.from(results['results']['videos'] ?? []);
  }

  /// Search Photos
  static Future<List<Map<String, dynamic>>> searchPhotos({
    required String query,
    String? fruitTag,
    int limit = 20,
    int offset = 0,
  }) async {
    final results = await search(
      query: query,
      type: 'photos',
      fruitTag: fruitTag,
      limit: limit,
      offset: offset,
    );
    return List<Map<String, dynamic>>.from(results['results']['photos'] ?? []);
  }

  /// Search Stories
  static Future<List<Map<String, dynamic>>> searchStories({
    required String query,
    String? fruitTag,
    int limit = 20,
    int offset = 0,
  }) async {
    final results = await search(
      query: query,
      type: 'stories',
      fruitTag: fruitTag,
      limit: limit,
      offset: offset,
    );
    return List<Map<String, dynamic>>.from(results['results']['stories'] ?? []);
  }
}

