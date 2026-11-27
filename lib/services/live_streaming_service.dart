import '../config/api_config.dart';
import 'api_service.dart';
import 'hive_cache_service.dart';
import 'user_storage.dart';

/// Live Streaming Service
/// Handles interactions with the live streaming backend API.
class LiveStreamingService {
  static const String _liveVideosCacheKey = 'home_live_videos';
  /// Generates a Stream Video token for the current user.
  static Future<Map<String, dynamic>> generateToken() async {
    try {
      final userId = await UserStorage.getUserId();
      if (userId == null) {
        throw ApiException('User not logged in.');
      }

      final response = await ApiService.post(
        ApiConfig.liveStreamingToken,
        body: {'user_id': userId},
      );

      if (response['success'] == true && response['data'] != null) {
        return response['data'];
      } else {
        throw ApiException(response['message'] ?? 'Failed to generate live streaming token.');
      }
    } catch (e) {
      print('Error generating live streaming token: $e');
      rethrow;
    }
  }

  /// Creates a new live stream.
  static Future<Map<String, dynamic>> createStream({
    required String title,
    String? description,
    String? category,
    String? thumbnailUrl,
  }) async {
    try {
      final userId = await UserStorage.getUserId();
      if (userId == null) {
        throw ApiException('User not logged in.');
      }

      final response = await ApiService.post(
        ApiConfig.liveStreamingCreate,
        body: {
          'user_id': userId,
          'title': title,
          'description': description,
          'category': category,
          'thumbnail_url': thumbnailUrl,
        },
      );

      if (response['success'] == true && response['data'] != null) {
        return response['data'];
      } else {
        throw ApiException(response['message'] ?? 'Failed to create live stream.');
      }
    } catch (e) {
      print('Error creating live stream: $e');
      rethrow;
    }
  }

  /// Retrieves a live stream by its ID.
  static Future<Map<String, dynamic>> getStream(String streamId) async {
    try {
      final userId = await UserStorage.getUserId();
      if (userId == null) {
        throw ApiException('User not logged in.');
      }

      final response = await ApiService.get(
        '${ApiConfig.liveStreamingGet}?stream_id=$streamId&user_id=$userId',
      );

      if (response['success'] == true && response['data'] != null) {
        return response['data'];
      } else {
        throw ApiException(response['message'] ?? 'Failed to retrieve live stream.');
      }
    } catch (e) {
      print('Error retrieving live stream: $e');
      rethrow;
    }
  }

  /// Stops a live stream by its ID.
  static Future<Map<String, dynamic>> stopStream(String streamId) async {
    try {
      final userId = await UserStorage.getUserId();
      if (userId == null) {
        throw ApiException('User not logged in.');
      }

      final response = await ApiService.postJson(
        ApiConfig.liveStreamingStop,
        body: {
          'user_id': userId,
          'stream_id': streamId,
        },
      );

      // Clear live video cache so we don't show ended/un-updated streams from cache
      await HiveCacheService.clearKey(_liveVideosCacheKey);

      if (response['success'] == true) {
        final data = response['data'];
        if (data is Map<String, dynamic>) {
          return data;
        }
        return <String, dynamic>{};
      } else {
        throw ApiException(
          response['message'] ?? response['error'] ?? 'Failed to stop live stream.',
        );
      }
    } catch (e) {
      if (e is ApiException && e.statusCode == 404) {
        // Stream already ended or not found on server; treat as success so host can leave.
        // Clear live video cache even if 404, to ensure it's removed from local display.
        await HiveCacheService.clearKey(_liveVideosCacheKey);
        return <String, dynamic>{};
      }
      print('Error stopping live stream: $e');
      rethrow;
    }
  }

  /// Fetches Agora RTC token from PHP (keys stay on backend). Use for joinChannel.
  /// [channelName] Agora channel name (e.g. stream_id or "live_userId_timestamp").
  /// [role] 1 = publisher (host), 2 = subscriber (audience).
  static Future<Map<String, dynamic>> getAgoraToken({
    required String channelName,
    required int role,
    int tokenExpireSeconds = 3600,
  }) async {
    try {
      final userId = await UserStorage.getUserId();
      if (userId == null) {
        throw ApiException('User not logged in.');
      }

      final response = await ApiService.postJson(
        ApiConfig.liveStreamingAgoraToken,
        body: {
          'channel_name': channelName,
          'user_id': userId.toString(),
          'role': role,
          'token_expire': tokenExpireSeconds,
        },
      );

      if (response['success'] == true &&
          response['token'] != null &&
          response['app_id'] != null) {
        return {
          'token': response['token'],
          'app_id': response['app_id'],
          'channel_name': response['channel_name'] ?? channelName,
          'expire_seconds': response['expire_seconds'] ?? tokenExpireSeconds,
        };
      }
      // Check if stream has ended
      if (response['stream_status'] != null && response['stream_status'] != 'live') {
        throw ApiException('This live stream has ended.');
      }
      throw ApiException(
          response['message'] ?? 'Failed to get Agora token.');
    } catch (e) {
      print('Error getting Agora token: $e');
      rethrow;
    }
  }

  /// Registers that an Agora live has started (broadcaster went live). So get_all_streams shows it for viewers.
  /// Returns true on success; throws [ApiException] on failure.
  static Future<bool> startAgoraLive({
    required String channelName,
    required String title,
    String description = '',
  }) async {
    final userId = await UserStorage.getUserId();
    if (userId == null) {
      throw ApiException('User not logged in.');
    }

    final response = await ApiService.postJson(
      ApiConfig.liveStreamingAgoraStartLive,
      body: {
        'stream_id': channelName,
        'channel_name': channelName,
        'user_id': userId.toString(),
        'title': title,
        'description': description,
      },
    );

    if (response['success'] == true) {
      return true;
    }
    throw ApiException(
      response['message'] ?? 'Failed to register live stream.',
    );
  }

  /// Add a live comment (host or viewer). Saved on server so everyone can see via getLiveComments.
  static Future<Map<String, dynamic>?> addLiveComment({
    required String channelName,
    required String userName,
    required String text,
    bool isEmoji = false,
  }) async {
    try {
      final userId = await UserStorage.getUserId();
      if (userId == null) return null;

      final response = await ApiService.postJson(
        ApiConfig.liveStreamingAddComment,
        body: {
          'channel_name': channelName,
          'user_id': userId,
          'user_name': userName,
          'text': text,
          'is_emoji': isEmoji,
        },
      );

      if (response['success'] == true && response['comment'] != null) {
        return Map<String, dynamic>.from(response['comment']);
      }
      return null;
    } catch (e) {
      print('Error adding live comment: $e');
      return null;
    }
  }

  /// Fetch recent comments for a channel. Used by host and viewers (poll every 2–3 sec).
  static Future<List<Map<String, dynamic>>> getLiveComments(String channelName, {int limit = 80}) async {
    try {
      final response = await ApiService.get(
        '${ApiConfig.liveStreamingGetComments}?channel_name=${Uri.encodeComponent(channelName)}&limit=$limit',
      );
      if (response['success'] == true && response['data'] != null) {
        return List<Map<String, dynamic>>.from(response['data']);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Fetches all active live streams. Returns empty list on 404 (endpoint missing) or error.
  static Future<List<Map<String, dynamic>>> getAllLiveStreams() async {
    try {
      final response = await ApiService.get(ApiConfig.liveStreamingGetAll);

      if (response['success'] == true && response['data'] != null) {
        return List<Map<String, dynamic>>.from(response['data']);
      } else {
        throw ApiException(response['message'] ?? 'Failed to fetch all live streams.');
      }
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        return [];
      }
      print('Error fetching all live streams: $e');
      rethrow;
    } catch (e) {
      print('Error fetching all live streams: $e');
      rethrow;
    }
  }

  /// Fetch viewer_count from DB for a live stream (host + viewers).
  static Future<int> fetchViewerCount(String streamId) async {
    try {
      final userId = await UserStorage.getUserId();
      if (userId == null) return 0;

      final response = await ApiService.get(
        '${ApiConfig.liveStreamingGet}?stream_id=${Uri.encodeComponent(streamId)}&user_id=$userId',
      );
      if (response['success'] == true && response['data'] != null) {
        final count = response['data']['viewer_count'];
        if (count is num) return count.toInt();
      }
    } catch (e) {
      print('Error fetching viewer count: $e');
    }
    return 0;
  }

  /// Increment viewer count when a viewer joins a stream
  static Future<bool> incrementViewerCount(String streamId) async {
    try {
      final response = await ApiService.postJson(
        ApiConfig.liveStreamingIncrementViewer,
        body: {'stream_id': streamId},
      );
      return response['success'] == true;
    } catch (e) {
      print('Error incrementing viewer count: $e');
      return false;
    }
  }

  /// Decrement viewer count when a viewer leaves a stream
  static Future<bool> decrementViewerCount(String streamId) async {
    try {
      final response = await ApiService.postJson(
        ApiConfig.liveStreamingDecrementViewer,
        body: {'stream_id': streamId},
      );
      return response['success'] == true;
    } catch (e) {
      print('Error decrementing viewer count: $e');
      return false;
    }
  }
}
