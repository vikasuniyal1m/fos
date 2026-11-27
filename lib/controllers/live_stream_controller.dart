import 'dart:async';
import 'package:get/get.dart';
import 'package:flutter/material.dart'; // For SnackBar
import 'package:fruitsofspirit/services/live_streaming_service.dart';
import 'package:fruitsofspirit/services/user_storage.dart';
import 'package:fruitsofspirit/services/hive_cache_service.dart';
import 'package:fruitsofspirit/routes/app_pages.dart'; // Assuming you'll need this for navigation
import 'package:fruitsofspirit/utils/app_theme.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';

/// Live Stream Controller
/// Manages live streaming data and operations
class LiveStreamController extends GetxController {
  // Observable variables for UI state and data
  var isLoading = false.obs;
  var isRefreshing = false.obs;
  var hasInitialLoad = false.obs;
  var message = ''.obs;
  var liveStreamToken = ''.obs;
  var currentStream = <String, dynamic>{}.obs; // Details of the user's active stream
  var allLiveStreams = <Map<String, dynamic>>[].obs; // List of all active streams
  var userId = 0.obs;

  Timer? _refreshTimer;
  DateTime? _lastSyncedAt;
  static const Duration _minSyncInterval = Duration(seconds: 8);
  static const String _liveStreamsHiveKey = 'live_streams_list';

  @override
  void onInit() {
    super.onInit();
    _loadUserId();
    bootstrapLive();
  }

  @override
  void onReady() {
    super.onReady();
    getAllLiveStreams(silent: hasInitialLoad.value);
    _startAutoRefresh();
  }

  @override
  void onClose() {
    _refreshTimer?.cancel();
    super.onClose();
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      getAllLiveStreams(silent: true);
    });
  }

  void bootstrapLive() {
    final cached = HiveCacheService.getCachedList(_liveStreamsHiveKey);
    if (cached.isEmpty) return;
    _applyStreamsList(cached);
    hasInitialLoad.value = true;
  }

  Future<void> prepareLive() async {
    bootstrapLive();
    unawaited(getAllLiveStreams(silent: hasInitialLoad.value));
  }

  void _applyStreamsList(List<Map<String, dynamic>> streams) {
    final onlyLive = streams.where((s) {
      final status = (s['status'] ?? '').toString().toLowerCase();
      return status.isEmpty || status == 'live';
    }).toList();

    final ownLive = onlyLive.where((s) {
      final streamUserId = (s['user_id'] ?? '').toString();
      return streamUserId == userId.value.toString();
    }).toList();
    currentStream.value = ownLive.isNotEmpty
        ? Map<String, dynamic>.from(ownLive.first)
        : <String, dynamic>{};

    allLiveStreams.value = onlyLive
        .where((s) => (s['user_id'] ?? '').toString() != userId.value.toString())
        .map((s) => Map<String, dynamic>.from(s))
        .toList();
  }

  /// Load user ID from storage
  Future<void> _loadUserId() async {
    final id = await UserStorage.getUserId();
    if (id != null) {
      userId.value = id;
    }
  }

  /// Generate a live streaming token for the current user
  Future<bool> generateLiveStreamToken() async {
    isLoading.value = true;
    message.value = '';
    try {
      if (userId.value == 0) {
        await _loadUserId();
        if (userId.value == 0) {
          message.value = 'Please login first to generate a token.';
          _showCustomSnackbar('Error', message.value);
          return false;
        }
      }

      final response = await LiveStreamingService.generateToken();
      if (response['token'] != null) {
        liveStreamToken.value = response['token'];
        message.value = 'Live stream token generated successfully.';
        _showCustomSnackbar('Success', message.value);
        return true;
      } else {
        message.value = response['message'] ?? 'Failed to generate live stream token.';
        _showCustomSnackbar('Error', message.value);
        return false;
      }
    } catch (e) {
      message.value = 'Error generating token: ${e.toString()}';
      _showCustomSnackbar('Error', message.value);
      print('Error generating live stream token: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Create a new live stream
  Future<bool> createLiveStream({
    required String title,
    String? description,
    String? category,
  }) async {
    isLoading.value = true;
    message.value = '';
    try {
      if (userId.value == 0) {
        await _loadUserId();
        if (userId.value == 0) {
          message.value = 'Please login first to create a stream.';
          _showCustomSnackbar('Error', message.value);
          return false;
        }
      }

      final response = await LiveStreamingService.createStream(
        title: title,
        description: description,
        category: category,
      );
      if (response['stream_id'] != null) {
        currentStream.value = response;
        message.value = 'Live stream created successfully.';
        _showCustomSnackbar('Success', message.value);
        // Optionally navigate to the live stream screen
        // Get.toNamed(Routes.LIVE_STREAM_SCREEN, arguments: response['stream_id']);
        return true;
      } else {
        message.value = response['message'] ?? 'Failed to create live stream.';
        _showCustomSnackbar('Error', message.value);
        return false;
      }
    } catch (e) {
      message.value = 'Error creating stream: ${e.toString()}';
      _showCustomSnackbar('Error', message.value);
      print('Error creating live stream: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Get details of a specific live stream
  Future<bool> getLiveStreamDetails(String streamId) async {
    isLoading.value = true;
    message.value = '';
    try {
      if (userId.value == 0) {
        await _loadUserId();
        if (userId.value == 0) {
          message.value = 'Please login first to view stream details.';
          _showCustomSnackbar('Error', message.value);
          return false;
        }
      }

      final response = await LiveStreamingService.getStream(streamId);
      if (response['stream_id'] != null) {
        currentStream.value = response;
        message.value = 'Live stream details loaded successfully.';
        return true;
      } else {
        message.value = response['message'] ?? 'Failed to load live stream details.';
        _showCustomSnackbar('Error', message.value);
        return false;
      }
    } catch (e) {
      message.value = 'Error getting stream details: ${e.toString()}';
      _showCustomSnackbar('Error', message.value);
      print('Error getting live stream details: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Stop an active live stream
  Future<bool> stopLiveStream(String streamId) async {
    isLoading.value = true;
    message.value = '';
    try {
      if (userId.value == 0) {
        await _loadUserId();
        if (userId.value == 0) {
          message.value = 'Please login first to stop a stream.';
          _showCustomSnackbar('Error', message.value);
          return false;
        }
      }

      await LiveStreamingService.stopStream(streamId);
      currentStream.value = {};
      message.value = 'Live stream stopped successfully.';
      _showCustomSnackbar('Success', message.value);
      getAllLiveStreams(silent: true);
      return true;
    } catch (e) {
      message.value = 'Error stopping stream: ${e.toString()}';
      _showCustomSnackbar('Error', message.value);
      print('Error stopping live stream: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Clear live-video cache so stale/ended streams don't show on home or here.
  static const String _liveVideosCacheKey = 'home_live_videos';

  /// Get all active live streams (who is live now — for viewers to tap and watch).
  Future<void> getAllLiveStreams({bool silent = false, bool force = false}) async {
    if (silent &&
        !force &&
        _lastSyncedAt != null &&
        DateTime.now().difference(_lastSyncedAt!) < _minSyncInterval) {
      return;
    }
    if (!silent && !hasInitialLoad.value) {
      isLoading.value = true;
    } else if (!silent) {
      isRefreshing.value = true;
    }
    message.value = '';
    try {
      if (userId.value == 0) {
        await _loadUserId();
      }

      final response = await LiveStreamingService.getAllLiveStreams();
      final onlyLive = response.where((s) {
        final status = (s['status'] ?? '').toString().toLowerCase();
        return status == 'live';
      }).map((s) => Map<String, dynamic>.from(s)).toList();

      _applyStreamsList(onlyLive);
      hasInitialLoad.value = true;
      _lastSyncedAt = DateTime.now();
      await HiveCacheService.cacheList(_liveStreamsHiveKey, onlyLive);
      await HiveCacheService.cacheList(_liveVideosCacheKey, onlyLive);
      message.value = 'All live streams loaded successfully.';
    } catch (e) {
      if (!hasInitialLoad.value) {
        allLiveStreams.value = [];
      }
      message.value = 'Could not load live list. Pull down to refresh.';
      print('Error loading all live streams: $e');
    } finally {
      isLoading.value = false;
      isRefreshing.value = false;
    }
  }

  /// Helper to show a custom SnackBar message. Only shows when an Overlay context is available.
  void _showCustomSnackbar(String title, String message, {bool isModeration = false, SnackBarAction? action}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Use overlay context so snackbar has an Overlay ancestor (avoids "No Overlay widget found")
      final context = Get.overlayContext ?? Get.context;
      if (context == null) return;
      try {
        if (Get.overlayContext != null) {
          Get.snackbar(
            title,
            message,
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: isModeration
                ? Colors.red[900]
                : (title == 'Error' ? Colors.red.withOpacity(0.9) : AppTheme.iconscolor),
            colorText: Colors.white,
            margin: EdgeInsets.all(ResponsiveHelper.spacing(context, 16)),
            duration: Duration(seconds: isModeration ? 5 : 3),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$title: $message'),
              backgroundColor: title == 'Error' ? Colors.red : AppTheme.iconscolor,
              duration: Duration(seconds: isModeration ? 5 : 3),
            ),
          );
        }
      } catch (_) {
        // No Overlay/Scaffold in tree; skip snackbar to avoid crash
      }
    });
  }
}
