import 'dart:io';
import '../config/api_config.dart';
import 'api_service.dart';

/// Group Chat Service
/// Handles real-time chat messages (WhatsApp style)
class GroupChatService {
  /// Get Chat Messages
  /// 
  /// Parameters:
  /// - groupId: Group ID
  /// - userId: Current user ID
  /// - limit: Number of messages (default: 50)
  /// - offset: Pagination offset (default: 0)
  /// - lastMessageId: Last message ID for pagination (optional)
  /// 
  /// Returns: List of chat messages
  static Future<List<Map<String, dynamic>>> getChatMessages({
    required int groupId,
    required int userId,
    int limit = 50,
    int offset = 0,
    int? lastMessageId,
    bool syncNew = false, // If true, fetch messages after lastMessageId (for syncing)
  }) async {
    final queryParams = <String, String>{
      'group_id': groupId.toString(),
      'user_id': userId.toString(),
      'limit': limit.toString(),
      'offset': offset.toString(),
    };

    if (syncNew && lastMessageId != null && lastMessageId > 0) {
      // For syncing new messages, use after_id parameter
      queryParams['after_id'] = lastMessageId.toString();
    } else if (lastMessageId != null && lastMessageId > 0) {
      // For pagination (older messages), use last_message_id
      queryParams['last_message_id'] = lastMessageId.toString();
    }

    // Include action=messages in query parameters
    final allQueryParams = <String, String>{
      'action': 'messages',
      ...queryParams,
    };
    
    try {
      // Add timestamp to prevent caching - always fetch fresh from database
      final cacheBustParams = <String, String>{
        ...allQueryParams,
        '_t': DateTime.now().millisecondsSinceEpoch.toString(),
      };
      
      final response = await ApiService.get(
        ApiConfig.groups,
        queryParameters: cacheBustParams,
      );

      if (response['success'] == true) {
        if (response['data'] == null) {
          return [];
        }
        
        final messagesList = List<Map<String, dynamic>>.from(response['data']);
        
        // Verify this is MESSAGE data, not GROUP data
        if (messagesList.isNotEmpty) {
          final firstItem = messagesList.first;
          
          // Check if response contains group data instead of message data
          if (firstItem.containsKey('name') && firstItem.containsKey('category') && !firstItem.containsKey('message')) {
            return [];
          }
        }
        
        return messagesList;
      } else {
        final errorMsg = response['message'] ?? 'Failed to fetch chat messages';
        throw ApiException(errorMsg);
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Send Chat Message
  /// 
  /// Parameters:
  /// - userId: User ID
  /// - groupId: Group ID
  /// - message: Message text
  /// - messageType: Type of message ('text', 'image', 'file')
  /// - file: Optional file to send
  /// 
  /// Returns: Sent message data
  static Future<Map<String, dynamic>> sendMessage({
    required int userId,
    required int groupId,
    required String message,
    String messageType = 'text',
    File? file,
  }) async {
    final endpoint = '${ApiConfig.groups}?action=messages';
    
    final fields = <String, String>{
      'action': 'messages',
      'user_id': userId.toString(),
      'group_id': groupId.toString(),
      'message': message,
      'message_type': messageType,
    };

    final files = <String, File>{};
    if (file != null) {
      files['file'] = file;
    }

    try {
      final response = await ApiService.postMultipart(
        endpoint,
        fields: fields,
        files: files.isNotEmpty ? files : null,
      );

      if (response['success'] == true && response['data'] != null) {
        return response['data'] as Map<String, dynamic>;
      } else {
        final errorMsg = response['message'] ?? 'Failed to send message';
        throw ApiException(errorMsg);
      }
    } catch (e) {
      rethrow;
    }
  }
}

