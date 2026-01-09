import '../config/api_config.dart';
import 'api_service.dart';

/// Live Streaming Service
/// Handles live video streaming functionality
class LiveStreamingService {
  /// Create Live Stream
  /// 
  /// Parameters:
  /// - userId: User ID
  /// - title: Stream title
  /// - description: Stream description (optional)
  /// - fruitTag: Tag with fruit (optional)
  /// 
  /// Returns: Stream details with stream key and URLs
  static Future<Map<String, dynamic>> createLiveStream({
    required int userId,
    required String title,
    String? description,
    String? fruitTag,
  }) async {
    final body = <String, dynamic>{
      'user_id': userId.toString(),
      'title': title,
    };

    if (description != null) body['description'] = description;
    if (fruitTag != null) body['fruit_tag'] = fruitTag;

    final response = await ApiService.post(
      '${ApiConfig.videos}?action=live',
      body: body,
    );

    if (response['success'] == true && response['data'] != null) {
      return response['data'] as Map<String, dynamic>;
    } else {
      throw ApiException(response['message'] ?? 'Failed to create live stream');
    }
  }

  /// Get Live Stream Details
  /// 
  /// Parameters:
  /// - streamId: Live stream ID
  /// 
  /// Returns: Stream details with streaming URLs
  static Future<Map<String, dynamic>> getLiveStreamDetails(int streamId) async {
    final response = await ApiService.get(
      '${ApiConfig.videos}?action=live&id=$streamId',
    );

    if (response['success'] == true && response['data'] != null) {
      return response['data'] as Map<String, dynamic>;
    } else {
      throw ApiException(response['message'] ?? 'Failed to fetch live stream');
    }
  }

  /// Get All Live Streams
  /// 
  /// Parameters:
  /// - status: Filter by status (default: 'Live')
  /// 
  /// Returns: List of live streams
  static Future<List<Map<String, dynamic>>> getLiveStreams({
    String status = 'Live',
  }) async {
    final response = await ApiService.get(
      '${ApiConfig.videos}?action=live',
      queryParameters: {'status': status},
    );

    if (response['success'] == true && response['data'] != null) {
      return List<Map<String, dynamic>>.from(response['data']);
    } else {
      throw ApiException(response['message'] ?? 'Failed to fetch live streams');
    }
  }

  /// Update Live Stream Status
  /// 
  /// Parameters:
  /// - streamId: Live stream ID
  /// - status: New status ('Live', 'Ended', 'Blocked')
  /// 
  /// Returns: Updated stream details
  static Future<Map<String, dynamic>> updateStreamStatus({
    required int streamId,
    required String status,
  }) async {
    final body = <String, dynamic>{
      'stream_id': streamId.toString(),
      'status': status,
    };

    // Use POST with _method=PUT for compatibility
    body['_method'] = 'PUT';
    final response = await ApiService.post(
      '${ApiConfig.videos}?action=live',
      body: body,
    );

    if (response['success'] == true && response['data'] != null) {
      return response['data'] as Map<String, dynamic>;
    } else {
      throw ApiException(response['message'] ?? 'Failed to update stream status');
    }
  }

  /// Get Stream URL for Player
  /// 
  /// Returns the best available streaming URL (HLS preferred, fallback to RTMP)
  static String? getStreamUrl(Map<String, dynamic> stream) {
    // Prefer HLS for better compatibility
    if (stream['hls_url'] != null && stream['hls_url'].toString().isNotEmpty) {
      return stream['hls_url'] as String;
    }
    
    // Fallback to RTMP
    if (stream['rtmp_url'] != null && stream['rtmp_url'].toString().isNotEmpty) {
      return stream['rtmp_url'] as String;
    }
    
    // Fallback to stream_url if available
    if (stream['stream_url'] != null && stream['stream_url'].toString().isNotEmpty) {
      return stream['stream_url'] as String;
    }
    
    return null;
  }
}

