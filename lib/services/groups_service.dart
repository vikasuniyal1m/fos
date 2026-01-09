import 'dart:io';
import '../config/api_config.dart';
import 'api_service.dart';

/// Groups Service
/// Handles groups listing, creation, joining, and leaving
class GroupsService {
  /// Get Groups
  /// 
  /// Parameters:
  /// - status: Filter by status (default: 'Active')
  /// - category: Filter by category
  /// - userId: Get groups user is member of
  /// - limit: Number of results (default: 20)
  /// - offset: Pagination offset (default: 0)
  /// 
  /// Returns: List of groups
  static Future<List<Map<String, dynamic>>> getGroups({
    String status = 'Active',
    String? category,
    int? userId,
    int limit = 20,
    int offset = 0,
  }) async {
    final queryParams = <String, String>{
      'status': status,
      'limit': limit.toString(),
      'offset': offset.toString(),
    };

    if (category != null) queryParams['category'] = category;
    if (userId != null) queryParams['user_id'] = userId.toString();

    final response = await ApiService.get(
      ApiConfig.groups,
      queryParameters: queryParams,
    );

    if (response['success'] == true && response['data'] != null) {
      return List<Map<String, dynamic>>.from(response['data']);
    } else {
      throw ApiException(response['message'] ?? 'Failed to fetch groups');
    }
  }

  /// Get Single Group Details
  /// 
  /// Parameters:
  /// - groupId: Group ID
  /// 
  /// Returns: Group details with member count
  static Future<Map<String, dynamic>> getGroupDetails(int groupId) async {
    final response = await ApiService.get(
      ApiConfig.groups,
      queryParameters: {'id': groupId.toString()},
    );

    if (response['success'] == true && response['data'] != null) {
      return response['data'] as Map<String, dynamic>;
    } else {
      throw ApiException(response['message'] ?? 'Failed to fetch group details');
    }
  }

  /// Create Group
  /// 
  /// Parameters:
  /// - userId: User ID (creator)
  /// - name: Group name
  /// - description: Group description (optional)
  /// - category: Group category (default: 'Prayer')
  /// - groupImage: Group image file (optional)
  /// 
  /// Returns: Created group ID
  static Future<int> createGroup({
    required int userId,
    required String name,
    String? description,
    String category = 'Prayer',
    File? groupImage,
  }) async {
    // Validate name is not empty
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ApiException('Group name is required');
    }
    
    final fields = <String, String>{
      'user_id': userId.toString(),
      'name': trimmedName, // Ensure trimmed and not empty
      'category': category,
    };

    if (description != null && description.trim().isNotEmpty) {
      fields['description'] = description.trim();
    }
    
    print('📤 Creating group with fields: $fields');
    print('📤 Group name value: "$trimmedName" (length: ${trimmedName.length})');
    print('📤 All field keys: ${fields.keys.toList()}');

    final files = <String, File>{};
    if (groupImage != null) {
      files['group_image'] = groupImage;
    }

    final response = await ApiService.postMultipart(
      ApiConfig.groups,
      fields: fields,
      files: files.isNotEmpty ? files : null,
    );

    if (response['success'] == true && response['data'] != null) {
      return response['data']['id'] as int;
    } else {
      throw ApiException(response['message'] ?? 'Failed to create group');
    }
  }

  /// Join Group
  /// 
  /// Parameters:
  /// - userId: User ID
  /// - groupId: Group ID
  /// 
  /// Returns: Success message
  static Future<String> joinGroup({
    required int userId,
    required int groupId,
  }) async {
    final response = await ApiService.post(
      '${ApiConfig.groups}?action=join',
      body: {
        'user_id': userId.toString(),
        'group_id': groupId.toString(),
      },
    );

    if (response['success'] == true) {
      return response['message'] ?? 'Joined group successfully';
    } else {
      throw ApiException(response['message'] ?? 'Failed to join group');
    }
  }

  /// Leave Group
  /// 
  /// Parameters:
  /// - userId: User ID
  /// - groupId: Group ID
  /// 
  /// Returns: Success message
  static Future<String> leaveGroup({
    required int userId,
    required int groupId,
  }) async {
    final response = await ApiService.post(
      '${ApiConfig.groups}?action=leave',
      body: {
        'user_id': userId.toString(),
        'group_id': groupId.toString(),
      },
    );

    if (response['success'] == true) {
      return response['message'] ?? 'Left group successfully';
    } else {
      throw ApiException(response['message'] ?? 'Failed to leave group');
    }
  }

  /// Get Group Members
  /// 
  /// Parameters:
  /// - groupId: Group ID
  /// 
  /// Returns: List of group members
  static Future<List<Map<String, dynamic>>> getGroupMembers(int groupId) async {
    final response = await ApiService.get(
      '${ApiConfig.groups}?action=members',
      queryParameters: {'group_id': groupId.toString()},
    );

    if (response['success'] == true && response['data'] != null) {
      return List<Map<String, dynamic>>.from(response['data']);
    } else {
      throw ApiException(response['message'] ?? 'Failed to fetch group members');
    }
  }
}

