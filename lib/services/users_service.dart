import '../config/api_config.dart';
import 'api_service.dart';

/// Users Service
/// Handles user search and listing for tagging
class UsersService {
  /// Get Users
  /// 
  /// Parameters:
  /// - search: Search query (name, email, phone)
  /// - status: Filter by status (default: 'Active')
  /// - limit: Number of results (default: 50)
  /// - offset: Pagination offset (default: 0)
  /// 
  /// Returns: List of users
  static Future<List<Map<String, dynamic>>> getUsers({
    String? search,
    String status = 'Active',
    int limit = 50,
    int offset = 0,
  }) async {
    final queryParams = <String, String>{
      'status': status,
      'limit': limit.toString(),
      'offset': offset.toString(),
    };

    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }

    final response = await ApiService.get(
      ApiConfig.users,
      queryParameters: queryParams,
    );

    if (response['success'] == true && response['data'] != null) {
      return List<Map<String, dynamic>>.from(response['data']);
    } else {
      throw ApiException(response['message'] ?? 'Failed to fetch users');
    }
  }
}

