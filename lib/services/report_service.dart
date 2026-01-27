import '../config/api_config.dart';
import 'auth_service.dart';
import 'api_service.dart';
import 'user_storage.dart';

/// Report Service
/// Handles reporting content for moderation
class ReportService {
  /// Report inappropriate content
  /// 
  /// [contentType]: 'prayer', 'comment', 'blog', 'photo', 'video', 'group_post', 'group_chat'
  /// [contentId]: ID of the content
  /// [reason]: Reason for reporting
  /// [description]: Optional details
  static Future<bool> reportContent({
    required String contentType,
    required int contentId,
    required String reason,
    String? description,
  }) async {
    final user = await UserStorage.getUser();
    if (user == null) throw Exception('User not logged in');

    final response = await ApiService.post(
      '${ApiConfig.advanced}?action=report',
      body: {
        'user_id': user['id'].toString(),
        'content_type': contentType,
        'content_id': contentId.toString(),
        'reason': reason,
        'description': description ?? '',
      },
    );

    if (response['success'] == true) {
      return true;
    } else {
      throw ApiException(response['message'] ?? 'Failed to report content');
    }
  }
}
