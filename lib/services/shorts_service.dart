import 'dart:io';
import '../config/api_config.dart';
import 'api_service.dart';

/// Shorts Service — standalone API client for the Shorts module
class ShortsService {
  static String get mediaBaseUrl =>
      ApiConfig.baseUrl.replaceFirst('/api', '');

  static String resolveMediaUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return '$mediaBaseUrl/$cleanPath';
  }

  static String? getVideoUrl(Map<String, dynamic> short) {
    final url = short['video_url_full']?.toString() ??
        resolveMediaUrl(short['video_url']?.toString());
    return url.isNotEmpty ? url : null;
  }

  static String? getThumbnailUrl(Map<String, dynamic> short) {
    final url = short['thumbnail_url_full']?.toString() ??
        resolveMediaUrl(short['thumbnail_url']?.toString());
    return url.isNotEmpty ? url : null;
  }

  static int shortId(Map<String, dynamic> short) {
    final id = short['id'];
    if (id is int) return id;
    return int.tryParse(id?.toString() ?? '') ?? 0;
  }

  static Future<List<Map<String, dynamic>>> getShorts({
    String status = 'Approved',
    int? userId,
    int? currentUserId,
    int limit = 20,
    int? cursor,
  }) async {
    final queryParams = <String, String>{
      'status': status,
      'limit': limit.toString(),
    };
    if (userId != null) queryParams['user_id'] = userId.toString();
    if (currentUserId != null) {
      queryParams['current_user_id'] = currentUserId.toString();
    }
    if (cursor != null) queryParams['cursor'] = cursor.toString();

    final response = await ApiService.get(
      ApiConfig.shorts,
      queryParameters: queryParams,
    );

    if (response['success'] == true && response['data'] != null) {
      final data = response['data'];
      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      }
      if (data is Map && data['items'] != null) {
        return List<Map<String, dynamic>>.from(data['items']);
      }
    }
    throw ApiException(response['message'] ?? 'Failed to fetch shorts');
  }

  static Future<Map<String, dynamic>> getShortDetails(
    int shortId, {
    int? currentUserId,
  }) async {
    final queryParams = {'id': shortId.toString()};
    if (currentUserId != null) {
      queryParams['current_user_id'] = currentUserId.toString();
    }
    final response = await ApiService.get(
      ApiConfig.shorts,
      queryParameters: queryParams,
    );
    if (response['success'] == true && response['data'] != null) {
      return Map<String, dynamic>.from(response['data']);
    }
    throw ApiException(response['message'] ?? 'Failed to fetch short');
  }

  static Future<Map<String, dynamic>> uploadShort({
    required int userId,
    required File videoFile,
    File? thumbnailFile,
    String? title,
    String? description,
    int duration = 0,
  }) async {
    final fields = <String, String>{
      'user_id': userId.toString(),
      'action': 'upload',
    };
    if (title != null) fields['title'] = title;
    if (description != null) fields['description'] = description;
    if (duration > 0) fields['duration'] = duration.toString();

    final files = <String, File>{'video': videoFile};
    if (thumbnailFile != null) files['thumbnail'] = thumbnailFile;

    final response = await ApiService.postMultipart(
      ApiConfig.shorts,
      fields: fields,
      files: files,
    );

    if (response['success'] == true && response['data'] != null) {
      return Map<String, dynamic>.from(response['data']);
    }
    throw ApiException(response['message'] ?? 'Failed to upload short');
  }

  static Future<Map<String, dynamic>> toggleLike({
    required int shortId,
    required int userId,
  }) async {
    final response = await ApiService.post(ApiConfig.shorts, body: {
      'action': 'like',
      'short_id': shortId.toString(),
      'user_id': userId.toString(),
    });
    if (response['success'] == true) {
      return Map<String, dynamic>.from(response['data'] ?? {});
    }
    throw ApiException(response['message'] ?? 'Like failed');
  }

  static Future<Map<String, dynamic>> toggleSave({
    required int shortId,
    required int userId,
  }) async {
    final response = await ApiService.post(ApiConfig.shorts, body: {
      'action': 'save',
      'short_id': shortId.toString(),
      'user_id': userId.toString(),
    });
    if (response['success'] == true) {
      return Map<String, dynamic>.from(response['data'] ?? {});
    }
    throw ApiException(response['message'] ?? 'Save failed');
  }

  static Future<Map<String, dynamic>> trackShare({
    required int shortId,
    required int userId,
    String shareType = 'native',
  }) async {
    final response = await ApiService.post(ApiConfig.shorts, body: {
      'action': 'share',
      'short_id': shortId.toString(),
      'user_id': userId.toString(),
      'share_type': shareType,
    });
    if (response['success'] == true) {
      return Map<String, dynamic>.from(response['data'] ?? {});
    }
    throw ApiException(response['message'] ?? 'Share tracking failed');
  }

  static Future<void> trackView({
    required int shortId,
    required int userId,
  }) async {
    await ApiService.post(ApiConfig.shorts, body: {
      'action': 'view',
      'short_id': shortId.toString(),
      'user_id': userId.toString(),
    });
  }

  static Future<void> reportShort({
    required int shortId,
    required int userId,
    required String reason,
    String? description,
  }) async {
    final response = await ApiService.post(ApiConfig.shorts, body: {
      'action': 'report',
      'short_id': shortId.toString(),
      'user_id': userId.toString(),
      'reason': reason,
      if (description != null) 'description': description,
    });
    if (response['success'] != true) {
      throw ApiException(response['message'] ?? 'Report failed');
    }
  }

  static Future<void> deleteShort({
    required int shortId,
    required int userId,
  }) async {
    final response = await ApiService.post(ApiConfig.shorts, body: {
      'action': 'delete',
      'short_id': shortId.toString(),
      'user_id': userId.toString(),
    });
    if (response['success'] != true) {
      throw ApiException(response['message'] ?? 'Delete failed');
    }
  }

  static const List<String> commentDisplayKeys = [
    'id',
    'user_id',
    'user_name',
    'profile_photo',
    'comment',
    'created_at',
    'parent_comment_id',
    'replies',
  ];

  static Map<String, dynamic> slimComment(Map<String, dynamic> raw) {
    final normalized = normalizeComment(raw);
    return {
      for (final key in commentDisplayKeys)
        if (normalized[key] != null) key: normalized[key],
    };
  }

  static List<Map<String, dynamic>> slimComments(List<Map<String, dynamic>> items) {
    return items.map((item) => slimComment(item)).toList();
  }

  static Map<String, dynamic> normalizeComment(Map<String, dynamic> raw) {
    final map = Map<String, dynamic>.from(raw);
    final fromAlias = map['user_name']?.toString().trim() ?? '';
    final fromName = map['name']?.toString().trim() ?? '';
    if (fromAlias.isNotEmpty && fromAlias != 'User') {
      map['user_name'] = fromAlias;
    } else if (fromName.isNotEmpty) {
      map['user_name'] = fromName;
    } else {
      map['user_name'] = 'User';
    }
    final text = map['comment']?.toString() ?? map['content']?.toString() ?? '';
    map['comment'] = text;
    map['content'] = text;
    final replies = map['replies'];
    if (replies is List) {
      map['replies'] = replies
          .whereType<Map>()
          .map((item) => normalizeComment(Map<String, dynamic>.from(item)))
          .toList();
    } else {
      map['replies'] = <Map<String, dynamic>>[];
    }
    return map;
  }

  static Future<List<Map<String, dynamic>>> getComments(int shortId) async {
    final response = await ApiService.get(
      ApiConfig.shorts,
      queryParameters: {'action': 'comments', 'short_id': shortId.toString()},
    );
    if (response['success'] == true && response['data'] != null) {
      return List<Map<String, dynamic>>.from(response['data'])
          .map((item) => normalizeComment(Map<String, dynamic>.from(item as Map)))
          .toList();
    }
    throw ApiException(response['message'] ?? 'Failed to load comments');
  }

  static Future<Map<String, dynamic>> addComment({
    required int shortId,
    required int userId,
    required String comment,
    int? parentCommentId,
  }) async {
    final body = <String, String>{
      'action': 'comments',
      'short_id': shortId.toString(),
      'user_id': userId.toString(),
      'comment': comment,
    };
    if (parentCommentId != null && parentCommentId > 0) {
      body['parent_comment_id'] = parentCommentId.toString();
    }
    final response = await ApiService.post(ApiConfig.shorts, body: body);
    if (response['success'] == true) {
      final data = Map<String, dynamic>.from(response['data'] ?? {});
      final commentRaw = data['comment'];
      if (commentRaw is Map) {
        data['comment'] = normalizeComment(Map<String, dynamic>.from(commentRaw));
      }
      return data;
    }
    throw ApiException(response['message'] ?? 'Failed to add comment');
  }

  static Future<void> deleteComment({
    required int commentId,
    required int userId,
  }) async {
    final response = await ApiService.post(ApiConfig.shorts, body: {
      'action': 'delete-comment',
      'comment_id': commentId.toString(),
      'user_id': userId.toString(),
    });
    if (response['success'] != true) {
      throw ApiException(response['message'] ?? 'Failed to delete comment');
    }
  }

  static Future<Map<String, dynamic>> editComment({
    required int commentId,
    required int userId,
    required String comment,
  }) async {
    final response = await ApiService.post(ApiConfig.shorts, body: {
      'action': 'edit-comment',
      'comment_id': commentId.toString(),
      'user_id': userId.toString(),
      'comment': comment,
    });
    if (response['success'] == true) {
      final data = Map<String, dynamic>.from(response['data'] ?? {});
      final commentRaw = data['comment'];
      if (commentRaw is Map) {
        data['comment'] = normalizeComment(Map<String, dynamic>.from(commentRaw));
      }
      return data;
    }
    throw ApiException(response['message'] ?? 'Failed to edit comment');
  }

  static Future<void> reportComment({
    required int commentId,
    required int userId,
    String? reason,
    String? description,
  }) async {
    final response = await ApiService.post(ApiConfig.shorts, body: {
      'action': 'report-comment',
      'comment_id': commentId.toString(),
      'user_id': userId.toString(),
      'reason': reason?.trim().isNotEmpty == true ? reason!.trim() : 'General concern',
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
    });
    if (response['success'] != true) {
      throw ApiException(response['message'] ?? 'Failed to report comment');
    }
  }

  static Future<void> addCommentReaction({
    required int commentId,
    required int userId,
    required String emoji,
  }) async {
    await ApiService.post(ApiConfig.shorts, body: {
      'action': 'comment-reaction',
      'comment_id': commentId.toString(),
      'user_id': userId.toString(),
      'emoji': emoji,
    });
  }

  static Future<List<Map<String, dynamic>>> getSavedShorts({
    required int userId,
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await ApiService.get(
      ApiConfig.shorts,
      queryParameters: {
        'action': 'saved',
        'user_id': userId.toString(),
        'limit': limit.toString(),
        'offset': offset.toString(),
      },
    );
    if (response['success'] == true && response['data'] != null) {
      return List<Map<String, dynamic>>.from(response['data']);
    }
    throw ApiException(response['message'] ?? 'Failed to load saved shorts');
  }

  static Future<Map<String, dynamic>> getCounts(List<int> shortIds) async {
    if (shortIds.isEmpty) return {};
    final response = await ApiService.get(
      ApiConfig.shorts,
      queryParameters: {
        'action': 'counts',
        'ids': shortIds.join(','),
      },
    );
    if (response['success'] == true && response['data'] != null) {
      return Map<String, dynamic>.from(response['data']);
    }
    return {};
  }

  static String formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}
