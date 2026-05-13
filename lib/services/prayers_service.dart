import '../config/api_config.dart';
import 'api_service.dart';

/// Prayer Requests Service
/// Handles prayer requests listing, creation, and responses
class PrayersService {
  /// Get Prayer Requests
  /// 
  /// Parameters:
  /// - status: Filter by status (default: 'Approved')
  /// - category: Filter by category
  /// - userId: Filter by user ID
  /// - limit: Number of results (default: 20)
  /// - offset: Pagination offset (default: 0)
  /// 
  /// Returns: List of prayer requests
  static Future<List<Map<String, dynamic>>> getPrayers({
    String status = 'Approved',
    String? category,
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

    if (category != null) {
      queryParams['category'] = category;
    }
    if (userId != null) {
      queryParams['user_id'] = userId.toString();
    }
    if (currentUserId != null) {
      queryParams['current_user_id'] = currentUserId.toString();
    }

    final response = await ApiService.get(
      ApiConfig.prayers,
      queryParameters: queryParams,
    );

    if (response['success'] == true && response['data'] != null) {
      return List<Map<String, dynamic>>.from(response['data']);
    } else {
      throw ApiException(response['message'] ?? 'Failed to fetch prayers');
    }
  }

  /// Get Single Prayer Request with Responses
  /// 
  /// Parameters:
  /// - prayerId: Prayer request ID
  /// 
  /// Returns: Prayer request with responses
  static Future<Map<String, dynamic>> getPrayerDetails(int prayerId, {int? currentUserId}) async {
    final queryParams = {'id': prayerId.toString()};
    if (currentUserId != null) {
      queryParams['current_user_id'] = currentUserId.toString();
    }
    
    final response = await ApiService.get(
      ApiConfig.prayers,
      queryParameters: queryParams,
    );

    if (response['success'] == true && response['data'] != null) {
      return response['data'] as Map<String, dynamic>;
    } else {
      throw ApiException(response['message'] ?? 'Failed to fetch prayer details');
    }
  }

  /// Create Prayer Request
  /// 
  /// Parameters:
  /// - userId: User ID
  /// - category: Prayer category (e.g., 'Healing', 'Health', 'Family')
  /// - content: Prayer request content
  /// - prayerFor: Who is this for? ('Me', 'Someone else', 'Group')
  /// - allowEncouragement: Allow emoji reactions (default: true)
  /// - isAnonymous: Hide user name (default: false)
  /// - sharedWithUserIds: List of user IDs to share with
  /// - taggedUserId: User ID when prayerFor is 'Someone else'
  /// - taggedGroupId: Group ID when prayerFor is 'Group'
  /// 
  /// Returns: Created prayer request ID
  static Future<int> createPrayerRequest({
    required int userId,
    required String category,
    required String content,
    String? prayerFor,
    bool allowEncouragement = true,
    bool isAnonymous = false,
    List<int>? sharedWithUserIds,
    int? taggedUserId,
    int? taggedGroupId,
  }) async {
    final body = {
      'user_id': userId.toString(),
      'category': category,
      'content': content,
    };
    
    if (prayerFor != null) {
      body['prayer_for'] = prayerFor;
    }
    
    body['allow_encouragement'] = allowEncouragement ? '1' : '0';
    body['is_anonymous'] = isAnonymous ? '1' : '0';
    
    if (sharedWithUserIds != null && sharedWithUserIds.isNotEmpty) {
      body['shared_with'] = sharedWithUserIds.join(',');
    }
    
    if (taggedUserId != null) {
      body['tagged_user_id'] = taggedUserId.toString();
    }
    
    if (taggedGroupId != null) {
      body['tagged_group_id'] = taggedGroupId.toString();
    }
    
    final response = await ApiService.post(
      ApiConfig.prayers,
      body: body,
    );

    if (response['success'] == true && response['data'] != null) {
      return response['data']['id'] as int;
    } else {
      throw ApiException(response['message'] ?? 'Failed to create prayer request');
    }
  }

  // edit feature: Edit Prayer Request (15-minute window)
  /// Edit Prayer Request (15-minute window)
  ///
  /// Parameters:
  /// - userId: User ID (must be the prayer owner)
  /// - prayerId: Prayer ID to edit
  /// - content: New prayer content (optional)
  /// - category: New category (optional)
  ///
  /// Returns: Success status
  static Future<Map<String, dynamic>> editPrayer({ // edit feature
    required int userId, // edit feature
    required int prayerId, // edit feature
    String? content, // edit feature
    String? category, // edit feature
  }) async { // edit feature
    final body = <String, String>{ // edit feature
      'action': 'edit', // edit feature
      'user_id': userId.toString(), // edit feature
      'prayer_id': prayerId.toString(), // edit feature
    }; // edit feature

    if (content != null) body['content'] = content; // edit feature
    if (category != null) body['category'] = category; // edit feature

    final response = await ApiService.post( // edit feature
      ApiConfig.prayers, // edit feature
      body: body, // edit feature
    ); // edit feature

    if (response['success'] == true) { // edit feature
      return response; // edit feature
    } else { // edit feature
      throw ApiException(response['message'] ?? 'Failed to edit prayer'); // edit feature
    } // edit feature
  } // edit feature
}

