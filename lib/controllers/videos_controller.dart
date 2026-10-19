import 'dart:async';
import 'dart:io';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:fruitsofspirit/services/videos_service.dart';
import 'package:fruitsofspirit/services/image_preload_service.dart';
import 'package:fruitsofspirit/services/comments_service.dart';
import 'package:fruitsofspirit/services/user_storage.dart';
import 'package:fruitsofspirit/services/api_service.dart';
import 'package:fruitsofspirit/services/emojis_service.dart';
import 'package:fruitsofspirit/services/advanced_service.dart';
import 'package:fruitsofspirit/services/content_moderation_service.dart';
import 'package:fruitsofspirit/routes/app_pages.dart';
import 'package:fruitsofspirit/routes/routes.dart';
import 'package:fruitsofspirit/services/hive_cache_service.dart';
import 'package:fruitsofspirit/services/payment_gate.dart';
import 'package:fruitsofspirit/controllers/home_controller.dart';

/// Videos Controller
/// Manages videos data and operations
class VideosController extends GetxController {
  // Observable variables
  var isLoading = false.obs;
  var isDetailsSilentSyncing = false.obs;
  var message = ''.obs;
  
  // Data
  var videos = <Map<String, dynamic>>[].obs;
  var liveVideos = <Map<String, dynamic>>[].obs;
  var selectedVideo = <String, dynamic>{}.obs;
  var videoComments = <Map<String, dynamic>>[].obs;
  var videoEmojiReactions = <String, List<Map<String, dynamic>>>{}.obs; // emoji -> list of users who reacted
  var availableEmojis = <Map<String, dynamic>>[].obs;
  var quickEmojis = <Map<String, dynamic>>[].obs; // Top 6 emojis for quick reactions
  var userId = 0.obs;

  // Filters
  var selectedFruitTag = ''.obs;
  var currentPage = 0.obs;
  final int itemsPerPage = 20;
  
  // Performance: Store all videos for instant client-side filtering
  var _allVideos = <Map<String, dynamic>>[];
  
  // Performance: Track if data is already loaded to prevent unnecessary reloads
  var _isDataLoaded = false;
  var _isLoading = false;
  int _loadGeneration = 0;
  DateTime? _lastSyncedAt;
  static const Duration _minSyncInterval = Duration(minutes: 2);
  static const Duration _detailsMinSyncInterval = Duration(minutes: 2);
  static const String _videosListHiveKey = 'videos_list';
  Completer<void>? _activeLoadCompleter;
  DateTime? _detailsLastSyncedAt;
  int _detailsLoadGeneration = 0;
  int? preparedDetailVideoId;
  final Set<int> _deletedCommentIds = {};

  @override
  void onInit() {
    super.onInit();
    _loadUserId();
    loadFromHiveIfEmpty();
  }

  @override
  void onReady() {
    super.onReady();
    _seedFromHomeIfRegistered();
    loadFromHiveIfEmpty();
    if (_allVideos.isNotEmpty) {
      _applyClientSideFilter();
    }
    unawaited(loadVideos(refresh: true, silent: true, includePending: true));
    unawaited(loadLiveVideos());
  }

  void _seedFromHomeIfRegistered() {
    if (!Get.isRegistered<HomeController>()) return;
    final home = Get.find<HomeController>();
    seedFromHomeIfEmpty(
      homeVideos: home.videos.toList(),
      homeLiveVideos: home.liveVideos.toList(),
    );
  }

  /// Seed videos from home cache for instant open.
  void seedFromHomeIfEmpty({
    List<Map<String, dynamic>>? homeVideos,
    List<Map<String, dynamic>>? homeLiveVideos,
  }) {
    if (_allVideos.isEmpty && homeVideos != null && homeVideos.isNotEmpty) {
      _allVideos = List<Map<String, dynamic>>.from(homeVideos);
      _isDataLoaded = true;
      _applyClientSideFilter();
    }
    if (liveVideos.isEmpty && homeLiveVideos != null && homeLiveVideos.isNotEmpty) {
      liveVideos.value = List<Map<String, dynamic>>.from(homeLiveVideos);
    }
    if (_allVideos.isNotEmpty) {
      _preloadVideoThumbnails(_allVideos);
    }
  }

  void loadFromHiveIfEmpty() {
    if (_allVideos.isNotEmpty) return;
    var cached = HiveCacheService.getCachedList(_videosListHiveKey);
    if (cached.isEmpty) {
      cached = HiveCacheService.getCachedList('home_videos');
    }
    if (cached.isEmpty) return;
    _allVideos = List<Map<String, dynamic>>.from(cached);
    _isDataLoaded = true;
    _applyClientSideFilter();
  }

  int? _videoIdFromMap(Map<String, dynamic> map) {
    final id = map['id'];
    if (id is int) return id;
    if (id is String) return int.tryParse(id);
    return null;
  }

  String _videoDetailHiveKey(int videoId) => 'video_detail_$videoId';

  void bootstrapVideoDetail(int videoId) {
    if (videoId <= 0) return;

    final currentId = _videoIdFromMap(selectedVideo);
    if (currentId != null && currentId != videoId) {
      videoComments.clear();
      videoEmojiReactions.clear();
      _deletedCommentIds.clear();
    }

    loadVideoDetailFromHive(videoId);
    if (_videoIdFromMap(selectedVideo) != videoId || selectedVideo.isEmpty) {
      if (Get.isRegistered<HomeController>()) {
        final home = Get.find<HomeController>();
        seedVideoDetailFromHome(
          [
            ...home.videos,
            ...home.liveVideos,
          ],
          videoId,
        );
      }
      if (_videoIdFromMap(selectedVideo) != videoId || selectedVideo.isEmpty) {
        seedVideoDetailFromList(videoId);
      }
    }
    preparedDetailVideoId = videoId;
  }

  void loadVideoDetailFromHive(int videoId) {
    final cached = HiveCacheService.getCachedMap(_videoDetailHiveKey(videoId));
    if (cached.isEmpty) return;

    if (cached['video'] is Map) {
      selectedVideo.value =
          Map<String, dynamic>.from(cached['video'] as Map<String, dynamic>);
    } else {
      selectedVideo.value = Map<String, dynamic>.from(cached);
    }

    if (cached['comments'] is List && videoComments.isEmpty) {
      videoComments.value = (cached['comments'] as List)
          .whereType<Map>()
          .map((c) => Map<String, dynamic>.from(c))
          .where((c) => !_isCommentDeleted(c))
          .map(_filterDeletedFromTree)
          .toList();
    }

    if (cached['emoji_reactions'] is Map && videoEmojiReactions.isEmpty) {
      final reactions = <String, List<Map<String, dynamic>>>{};
      (cached['emoji_reactions'] as Map).forEach((key, value) {
        if (value is List) {
          reactions['$key'] = value
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      });
      if (reactions.isNotEmpty) {
        videoEmojiReactions.value = reactions;
      }
    }
  }

  Future<void> _cacheVideoDetailSnapshot(int videoId) async {
    if (selectedVideo.isEmpty) return;
    await HiveCacheService.cacheMap(
      _videoDetailHiveKey(videoId),
      {
        'video': Map<String, dynamic>.from(selectedVideo),
        'comments': videoComments.toList(),
        'emoji_reactions': videoEmojiReactions.map(
          (key, value) => MapEntry(key, List<Map<String, dynamic>>.from(value)),
        ),
      },
      expiryHours: 24,
    );
  }

  void seedVideoDetailFromList(int videoId) {
    if (_videoIdFromMap(selectedVideo) == videoId && selectedVideo.isNotEmpty) {
      return;
    }

    Map<String, dynamic>? found;
    for (final video in _allVideos) {
      if (_videoIdFromMap(video) == videoId) {
        found = video;
        break;
      }
    }
    if (found == null) {
      for (final video in videos) {
        if (_videoIdFromMap(video) == videoId) {
          found = video;
          break;
        }
      }
    }
    if (found == null) {
      for (final video in liveVideos) {
        if (_videoIdFromMap(video) == videoId) {
          found = video;
          break;
        }
      }
    }

    if (found != null) {
      selectedVideo.value = Map<String, dynamic>.from(found);
    }
  }

  void seedVideoDetailFromHome(
    List<Map<String, dynamic>> homeVideos,
    int videoId,
  ) {
    if (_videoIdFromMap(selectedVideo) == videoId && selectedVideo.isNotEmpty) {
      return;
    }
    for (final video in homeVideos) {
      if (_videoIdFromMap(video) == videoId) {
        selectedVideo.value = Map<String, dynamic>.from(video);
        return;
      }
    }
  }

  Future<void> prepareVideoDetails(int videoId) async {
    if (videoId <= 0) return;

    bootstrapVideoDetail(videoId);

    final hasPreview =
        _videoIdFromMap(selectedVideo) == videoId && selectedVideo.isNotEmpty;
    unawaited(loadQuickEmojis());
    unawaited(loadAvailableEmojis());
    unawaited(loadVideoComments(videoId));

    if (!hasPreview) {
      unawaited(loadVideoDetails(videoId, silent: false));
    } else {
      unawaited(loadVideoDetails(videoId, silent: true));
    }
  }

  bool _videoDetailNeedsUpdate(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) {
    const keys = [
      'updated_at',
      'view_count',
      'comment_count',
      'title',
      'description',
      'file_path',
      'status',
      'thumbnail',
      'thumbnail_url',
    ];
    for (final key in keys) {
      if (local[key] != remote[key]) return true;
    }
    return false;
  }

  void _mergeVideoFields(Map<String, dynamic> remote) {
    var changed = false;
    for (final entry in remote.entries) {
      if (selectedVideo[entry.key] != entry.value) {
        selectedVideo[entry.key] = entry.value;
        changed = true;
      }
    }
    if (changed) {
      selectedVideo.refresh();
    }
  }

  Future<void> _cacheVideosList() async {
    if (_allVideos.isEmpty) return;
    final snapshot = List<Map<String, dynamic>>.from(_allVideos);
    await HiveCacheService.cacheList(
      _videosListHiveKey,
      snapshot,
      expiryHours: 24,
    );
    final homeSlice = snapshot.take(5).toList();
    if (homeSlice.isNotEmpty) {
      await HiveCacheService.cacheList(
        'home_videos',
        homeSlice,
        expiryHours: 24,
      );
    }
  }

  /// Set initial data from cache
  void setInitialData(List<Map<String, dynamic>> data) {
    if (data.isNotEmpty) {
      _allVideos = List<Map<String, dynamic>>.from(data);
      _isDataLoaded = true;
      _applyClientSideFilter();
    }
  }

  /// Load user ID from storage
  Future<void> _loadUserId() async {
    final id = await UserStorage.getUserId();
    if (id != null) {
      userId.value = id;
    }
  }

  /// Load videos
  Future<void> loadVideos({
    bool refresh = false,
    bool includePending = false,
    bool silent = false,
  }) async {
    if (_isLoading) {
      if (_activeLoadCompleter != null) {
        await _activeLoadCompleter!.future;
      }
      if (_allVideos.isNotEmpty) {
        _applyClientSideFilter();
      }
      return;
    }

    if (_isDataLoaded && !refresh && _allVideos.isNotEmpty) {
      _applyClientSideFilter();
      return;
    }

    if (silent &&
        _lastSyncedAt != null &&
        DateTime.now().difference(_lastSyncedAt!) < _minSyncInterval) {
      if (_allVideos.isNotEmpty) {
        _applyClientSideFilter();
      }
      return;
    }

    final generation = silent ? _loadGeneration : ++_loadGeneration;
    _activeLoadCompleter = Completer<void>();

    if (refresh) {
      currentPage.value = 0;
      _isDataLoaded = false;
    }

    _isLoading = true;
    if (!silent) {
      isLoading.value = true;
    }
    message.value = '';

    try {
      if (userId.value == 0) {
        await _loadUserId();
      }

      final approvedVideos = await VideosService.getVideos(
        status: 'Approved',
        fruitTag: null,
        currentUserId: userId.value > 0 ? userId.value : null,
        limit: itemsPerPage,
        offset: currentPage.value * itemsPerPage,
      );

      if (generation != _loadGeneration) {
        return;
      }

      List<Map<String, dynamic>> allVideos = List.from(approvedVideos);

      if (userId.value > 0 && (includePending || refresh || currentPage.value == 0)) {
        try {
          final pendingVideos = await VideosService.getVideos(
            status: 'Pending',
            userId: userId.value,
            fruitTag: null,
            limit: 10,
            offset: 0,
          );
          allVideos.insertAll(0, pendingVideos);
        } catch (e) {
          print('Error loading pending videos: $e');
        }
      }

      if (!silent && generation != _loadGeneration) {
        return;
      }

      if (refresh || currentPage.value == 0) {
        final hasChanged = !_videoListsEqual(_allVideos, allVideos);
        if (hasChanged || _allVideos.isEmpty) {
          _allVideos = List<Map<String, dynamic>>.from(allVideos);
          _applyClientSideFilter();
        }
      } else {
        _allVideos.addAll(allVideos);
        _applyClientSideFilter();
      }

      videos.refresh();
      _isDataLoaded = true;
      _lastSyncedAt = DateTime.now();
      unawaited(_cacheVideosList());
      _preloadVideoThumbnails(_allVideos);
    } catch (e) {
      if (!silent) {
        message.value = 'Error loading videos: ${e.toString().replaceAll('Exception: ', '')}';
      }
      print('Error loading videos: $e');
      if (!silent && (refresh || currentPage.value == 0) && _allVideos.isEmpty) {
        videos.value = [];
        _isDataLoaded = false;
      } else if (_allVideos.isNotEmpty) {
        _applyClientSideFilter();
      }
    } finally {
      _isLoading = false;
      _activeLoadCompleter?.complete();
      _activeLoadCompleter = null;
      if (!silent) {
        isLoading.value = false;
      }
    }
  }

  void _preloadVideoThumbnails(List<Map<String, dynamic>> items) {
    final urls = <String>[];
    for (final video in items) {
      final url = VideosService.getThumbnailUrl(video);
      if (url != null && url.isNotEmpty) {
        urls.add(url);
      }
      if (urls.length >= 16) break;
    }
    if (urls.isNotEmpty) {
      unawaited(ImagePreloadService().preloadImages(urls, priorityLimit: 6));
    }
  }

  bool _videoListsEqual(
    List<Map<String, dynamic>> previous,
    List<Map<String, dynamic>> next,
  ) {
    if (identical(previous, next)) return true;
    if (previous.length != next.length) return false;

    for (var i = 0; i < previous.length; i++) {
      final prev = previous[i];
      final curr = next[i];
      if (prev['id'] != curr['id']) return false;
      if (prev['updated_at'] != curr['updated_at']) return false;
      if (prev['status'] != curr['status']) return false;
      if (prev['view_count'] != curr['view_count']) return false;
      if (prev['comment_count'] != curr['comment_count']) return false;
    }
    return true;
  }

  /// Load live videos
  Future<void> loadLiveVideos() async {
    try {
      final liveList = await VideosService.getLiveVideos(status: 'Live');
      liveVideos.value = liveList;
    } catch (e) {
      print('Error loading live videos: $e');
      liveVideos.value = [];
    }
  }

  /// Load more videos (pagination)
  Future<void> loadMore() async {
    if (isLoading.value) return;

    currentPage.value++;
    await loadVideos();
  }

  /// Load single video with comments (silent = no blocking spinner if preview exists).
  Future<void> loadVideoDetails(
    int videoId, {
    bool silent = false,
    bool force = false,
  }) async {
    if (silent &&
        !force &&
        _detailsLastSyncedAt != null &&
        _videoIdFromMap(selectedVideo) == videoId &&
        DateTime.now().difference(_detailsLastSyncedAt!) < _detailsMinSyncInterval) {
      return;
    }

    final generation = silent ? _detailsLoadGeneration : ++_detailsLoadGeneration;
    final hadPreview =
        _videoIdFromMap(selectedVideo) == videoId && selectedVideo.isNotEmpty;

    if (!silent && !hadPreview) {
      isLoading.value = true;
    } else if (silent && hadPreview) {
      isDetailsSilentSyncing.value = true;
    }
    message.value = '';

    try {
      if (userId.value == 0) {
        await _loadUserId();
      }

      final video = await VideosService.getVideoDetails(
        videoId,
        currentUserId: userId.value > 0 ? userId.value : null,
      );

      if (generation != _detailsLoadGeneration) {
        return;
      }

      if (silent &&
          hadPreview &&
          !force &&
          !_videoDetailNeedsUpdate(selectedVideo, video)) {
        _detailsLastSyncedAt = DateTime.now();
        unawaited(loadVideoComments(videoId));
        return;
      }

      if (silent && hadPreview) {
        _mergeVideoFields(video);
      } else {
        selectedVideo.value = video;
      }

      _detailsLastSyncedAt = DateTime.now();
      unawaited(_cacheVideoDetailSnapshot(videoId));

      unawaited(loadVideoComments(videoId));
      unawaited(loadAvailableEmojis());
      unawaited(loadQuickEmojis());
    } catch (e) {
      if (!silent || !hadPreview) {
        message.value =
            'Error loading video: ${e.toString().replaceAll('Exception: ', '')}';
      }
      print('Error loading video details: $e');
    } finally {
      isLoading.value = false;
      isDetailsSilentSyncing.value = false;
    }
  }

  /// Load video comments
  Future<void> loadVideoComments(int videoId) async {
    if (userId.value == 0) {
      await _loadUserId();
    }
    
    try {
      final comments = await CommentsService.getComments(
        postType: 'video',
        postId: videoId,
        userId: userId.value > 0 ? userId.value : null,
      );
      
      // Separate emoji reactions from text comments
      final textComments = <Map<String, dynamic>>[];
      final emojiReactions = <String, List<Map<String, dynamic>>>{};
      
      print('🔄 Loading video comments for video_id: $videoId');
      print('📥 Received ${comments.length} comments from API');
      print('📥 Raw comments data:');
      for (var i = 0; i < comments.length && i < 5; i++) {
        final comment = comments[i];
        print('   Comment ${i + 1}: id=${comment['id']}, content="${comment['content']}", user=${comment['user_name']}, parent=${comment['parent_comment_id']}');
      }
      
      for (var comment in comments) {
        final content = comment['content'] as String? ?? '';
        final trimmed = content.trim();
        final parentId = comment['parent_comment_id'];

        // Skip replies (they should be in replies array)
        if (parentId != null && parentId != 0) {
          continue;
        }

        if (_isCommentDeleted(comment)) {
          continue;
        }
        
        // Check if content is an emoji reaction
        // Can be: emoji character (😊), emoji code (joy_01), image URL, or emoji ID
        bool isEmojiReaction = false;
        String? emojiKey;
        
        // Strategy 1: Check if it's an emoji character (length <= 4)
        if (trimmed.length <= 4 && _isEmoji(trimmed)) {
          isEmojiReaction = true;
          emojiKey = trimmed;
          print('✅ Found emoji reaction (character): $emojiKey');
        }
        // Strategy 2: Check if it's an emoji code (like "joy_01", "kindness_peach_01")
        else if (trimmed.contains('_') && (trimmed.contains('joy') || trimmed.contains('peace') || 
                 trimmed.contains('love') || trimmed.contains('patience') || trimmed.contains('kindness') ||
                 trimmed.contains('goodness') || trimmed.contains('faithfulness') || trimmed.contains('gentleness') ||
                 trimmed.contains('meekness') || trimmed.contains('self') || trimmed.contains('control'))) {
          isEmojiReaction = true;
          emojiKey = trimmed;
          print('✅ Found emoji reaction (code): $emojiKey');
        }
        // Strategy 3: Check if it's an image URL (contains "uploads/emojis" or "emojis/")
        else if (trimmed.contains('uploads/emojis/') || trimmed.contains('emojis/') || 
                 trimmed.contains('.png') || trimmed.contains('.jpg')) {
          isEmojiReaction = true;
          emojiKey = trimmed;
          print('✅ Found emoji reaction (image URL): $emojiKey');
        }
        // Strategy 4: Check if it's a numeric ID (emoji_id)
        else if (trimmed.isNotEmpty && trimmed.length <= 10 && int.tryParse(trimmed) != null) {
          isEmojiReaction = true;
          emojiKey = trimmed;
          print('✅ Found emoji reaction (ID): $emojiKey');
        }
        
        if (isEmojiReaction && emojiKey != null) {
          if (!emojiReactions.containsKey(emojiKey)) {
            emojiReactions[emojiKey] = [];
          }
          emojiReactions[emojiKey]!.add({
            'user_id': comment['user_id'],
            'user_name': comment['user_name'] ?? 'Anonymous',
            'profile_photo': comment['profile_photo'],
            'created_at': comment['created_at'],
          });
        }

        textComments.add(_filterDeletedFromTree(comment));
      }

      videoComments.value = textComments;
      videoEmojiReactions.value = emojiReactions;
      _deletedCommentIds.removeWhere((id) => !_commentExistsInList(textComments, id));
      unawaited(_cacheVideoDetailSnapshot(videoId));
    } catch (e) {
      print('Error loading video comments: $e');
      if (videoComments.isEmpty) {
        videoComments.value = [];
        videoEmojiReactions.value = {};
      }
    }
  }

  /// Check if string is an emoji
  bool _isEmoji(String text) {
    if (text.isEmpty) return false;
    final trimmed = text.trim();
    
    // Check length - emojis are usually 1-4 characters (including variation selectors)
    if (trimmed.length > 4) return false;
    
    // Check if it contains only emoji characters (no letters, numbers, or punctuation)
    final emojiRegex = RegExp(
      r'[\u{1F300}-\u{1F9FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]|[\u{1F600}-\u{1F64F}]|[\u{1F680}-\u{1F6FF}]|[\u{1F1E0}-\u{1F1FF}]|[\u{2764}\u{FE0F}]|[\u{2728}]|[\u{2B50}]',
      unicode: true,
    );
    
    // Check if it's ONLY emoji characters (no other text)
    final hasEmoji = emojiRegex.hasMatch(trimmed);
    final hasOnlyEmoji = trimmed.runes.every((rune) {
      final char = String.fromCharCode(rune);
      // Allow emoji, variation selectors (FE0F), and zero-width joiner (200D)
      return emojiRegex.hasMatch(char) || 
             rune == 0xFE0F || // Variation selector
             rune == 0x200D;    // Zero-width joiner
    });
    
    return hasEmoji && hasOnlyEmoji;
  }

  /// Load available emojis
  /// Loads all emojis from database so reactions can be mapped correctly
  Future<void> loadAvailableEmojis() async {
    if (availableEmojis.isNotEmpty) return;
    try {
      final emojis = await EmojisService.getEmojis(
        status: 'Active',
        sortBy: 'image_url',
        order: 'ASC',
      );
      availableEmojis.value = emojis;
    } catch (e) {
      print('❌ Error loading emojis: $e');
      availableEmojis.value = [];
    }
  }

  /// Load quick emojis (top 6 by usage)
  Future<void> loadQuickEmojis() async {
    if (quickEmojis.isNotEmpty) return;
    try {
      final emojis = await EmojisService.getQuickEmojis();
      quickEmojis.value = emojis;
    } catch (e) {
      print('Error loading quick emojis: $e');
      quickEmojis.value = [];
    }
  }

  /// Add emoji reaction to video
  Future<bool> addEmojiReaction(int videoId, String emoji) async {
    if (userId.value == 0) {
      await _loadUserId();
    }

    if (userId.value == 0) {
      message.value = 'Please login first';
      return false;
    }

    try {
      await EmojisService.useEmoji(
        userId: userId.value,
        emoji: emoji,
        postType: 'video',
        postId: videoId,
      );
      
      // Update local emoji reactions count
      // This line should not exist - reactions are loaded from comments API
      // videoEmojiReactions are now loaded from loadVideoComments()
      
      unawaited(loadVideoComments(videoId));
      
      return true;
    } catch (e) {
      message.value = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      print('Error adding emoji reaction: $e');
      return false;
    }
  }

  /// Share video
  Future<bool> shareVideo(int videoId) async {
    if (userId.value == 0) {
      await _loadUserId();
    }

    if (userId.value == 0) {
      message.value = 'Please login first';
      return false;
    }

    try {
      final shareLink = await AdvancedService.shareContent(
        userId: userId.value,
        contentType: 'video',
        contentId: videoId,
      );
      
      message.value = 'Video shared successfully';
      return true;
    } catch (e) {
      message.value = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      print('Error sharing video: $e');
      return false;
    }
  }

  /// Upload video
  Future<bool> uploadVideo({
    required File videoFile,
    File? thumbnailFile,
    String? fruitTag,
    String? title,
    String? description,
    String? category,
  }) async {
    if (userId.value == 0) {
      await _loadUserId();
    }

    if (userId.value == 0) {
      message.value = 'Please login first';
      return false;
    }

    // Check for inappropriate content in title or description
    if (title != null && title.isNotEmpty) {
      final titleCheck = ContentModerationService.checkContent(title);
      if (!titleCheck['isClean']) {
        message.value = 'Title: ${titleCheck['message']}';
        _showModerationSnackbar(titleCheck['message']);
        return false;
      }
    }
    
    if (description != null && description.isNotEmpty) {
      final descCheck = ContentModerationService.checkContent(description);
      if (!descCheck['isClean']) {
        message.value = 'Description: ${descCheck['message']}';
        _showModerationSnackbar(descCheck['message']);
        return false;
      }
    }

    isLoading.value = true;
    message.value = 'Uploading video...';

    print('📤 VideosController.uploadVideo: Preparing upload...');
    await _loadUserId();
    print('📤 VideosController.uploadVideo: Using userId: ${userId.value}');

    if (userId.value == 0) {
      message.value = 'Please login first';
      isLoading.value = false;
      return false;
    }

    try {
      await VideosService.uploadVideo(
        userId: userId.value,
        videoFile: videoFile,
        thumbnailFile: thumbnailFile,
        fruitTag: fruitTag,
        title: title,
        description: description,
        category: category,
      );
      
      message.value = 'Video uploaded successfully. Waiting for admin approval.';
      
      // Reload videos including pending ones so user can see their upload
      // Use a small delay to ensure database is updated
      await Future.delayed(const Duration(milliseconds: 500));
      await loadVideos(refresh: true, includePending: true);
      
      // Force UI refresh to ensure new video appears
      videos.refresh();
      
      return true;
    } catch (e) {
      message.value = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      print('Error uploading video: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Add comment to video
  Future<bool> addComment(int videoId, String content, {int? parentCommentId}) async {
    if (userId.value == 0) {
      await _loadUserId();
    }

    if (userId.value == 0) {
      message.value = 'Please login first';
      return false;
    }

    // Check for inappropriate content in comment
    final moderationCheck = ContentModerationService.checkContent(content);
    if (!moderationCheck['isClean']) {
      message.value = moderationCheck['message'];
      _showModerationSnackbar(moderationCheck['message']);
      return false;
    }

    try {
      await CommentsService.addComment(
        userId: userId.value,
        postType: 'video',
        postId: videoId,
        content: content,
        parentCommentId: parentCommentId,
      );
      
      // Reload comments
      await loadVideoComments(videoId);
      
      // Force UI refresh for comments
      videoComments.refresh();
      videoEmojiReactions.refresh();
      
      return true;
    } catch (e) {
      message.value = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      print('Error adding comment: $e');
      return false;
    }
  }

  int _commentIdFromMap(Map<String, dynamic> comment) {
    final id = comment['id'];
    if (id is int) return id;
    return int.tryParse('$id') ?? 0;
  }

  bool _isCommentDeleted(Map<String, dynamic> comment) {
    final id = _commentIdFromMap(comment);
    if (_deletedCommentIds.contains(id)) return true;
    final deleted = comment['is_deleted'];
    return deleted == 1 || deleted == true || deleted == '1';
  }

  bool _commentExistsInList(List<Map<String, dynamic>> items, int commentId) {
    for (final comment in items) {
      if (_commentIdFromMap(comment) == commentId) return true;
      final replies = comment['replies'];
      if (replies is List && replies.isNotEmpty) {
        final nested = replies
            .whereType<Map>()
            .map((r) => Map<String, dynamic>.from(r))
            .toList();
        if (_commentExistsInList(nested, commentId)) return true;
      }
    }
    return false;
  }

  Map<String, dynamic> _filterDeletedFromTree(Map<String, dynamic> comment) {
    final copy = Map<String, dynamic>.from(comment);
    final replies = copy['replies'];
    if (replies is List && replies.isNotEmpty) {
      final filtered = replies
          .whereType<Map>()
          .map((r) => Map<String, dynamic>.from(r))
          .where((r) => !_isCommentDeleted(r))
          .map(_filterDeletedFromTree)
          .toList();
      copy['replies'] = filtered;
      copy['reply_count'] = filtered.length;
    }
    return copy;
  }

  void _removeCommentLocally(int commentId) {
    if (commentId <= 0) return;

    videoComments.removeWhere((c) => _commentIdFromMap(c) == commentId);

    final updated = <Map<String, dynamic>>[];
    for (final comment in videoComments) {
      final copy = Map<String, dynamic>.from(comment);
      final replies = copy['replies'];
      if (replies is List && replies.isNotEmpty) {
        copy['replies'] = replies
            .whereType<Map>()
            .map((r) => Map<String, dynamic>.from(r))
            .where((r) => _commentIdFromMap(r) != commentId)
            .toList();
      }
      updated.add(copy);
    }
    videoComments.value = updated;
  }

  Future<void> _deleteCommentOnServer(int videoId, int commentId) async {
    try {
      await CommentsService.deleteComment(
        userId: userId.value,
        commentId: commentId,
        postType: 'video',
      );
      await _cacheVideoDetailSnapshot(videoId);
    } catch (e) {
      _deletedCommentIds.remove(commentId);
      message.value = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      await loadVideoComments(videoId);
      videoComments.refresh();
    }
  }

  /// Delete comment with instant UI update.
  Future<bool> deleteVideoComment(int videoId, int commentId) async {
    if (userId.value == 0) {
      await _loadUserId();
    }
    if (userId.value == 0) {
      message.value = 'Please login first';
      return false;
    }
    if (commentId <= 0) return false;

    _deletedCommentIds.add(commentId);
    _removeCommentLocally(commentId);
    videoComments.refresh();
    unawaited(_cacheVideoDetailSnapshot(videoId));
    unawaited(_deleteCommentOnServer(videoId, commentId));
    return true;
  }

  /// Toggle comment like
  Future<Map<String, dynamic>?> toggleCommentLike(int commentId) async {
    if (userId.value == 0) {
      await _loadUserId();
    }

    if (userId.value == 0) {
      message.value = 'Please login first';
      return null;
    }

    try {
      final result = await CommentsService.toggleCommentLike(
        userId: userId.value,
        commentId: commentId,
      );
      return result;
    } catch (e) {
      message.value = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      print('Error toggling comment like: $e');
      return null;
    }
  }

  /// Report comment
  Future<bool> reportComment(int commentId, {String? reason}) async {
    if (userId.value == 0) {
      await _loadUserId();
    }

    if (userId.value == 0) {
      message.value = 'Please login first';
      return false;
    }

    try {
      await CommentsService.reportComment(
        userId: userId.value,
        commentId: commentId,
        reason: reason,
      );
      return true;
    } catch (e) {
      message.value = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      print('Error reporting comment: $e');
      return false;
    }
  }

  /// Apply client-side filter instantly (no API call)
  void _applyClientSideFilter() {
    if (_allVideos.isEmpty) {
      videos.value = [];
      videos.refresh();
      return;
    }
    
    if (selectedFruitTag.value.isEmpty) {
      // Show all videos - create new list instance
      videos.value = List<Map<String, dynamic>>.from(_allVideos);
    } else {
      // Filter by fruit tag client-side - create new list instance
      videos.value = List<Map<String, dynamic>>.from(_allVideos.where((video) {
        final videoFruitTag = video['fruit_tag'] as String? ?? '';
        return videoFruitTag.toLowerCase() == selectedFruitTag.value.toLowerCase();
      }).toList());
    }
    // Force UI refresh
    videos.refresh();
  }

  /// Filter by fruit tag - Instant client-side filtering only (no API call if data exists)
  void filterByFruitTag(String fruitTag) {
    // Performance: Only filter if fruit tag is actually changing
    if (selectedFruitTag.value != fruitTag) {
      selectedFruitTag.value = fruitTag;
      
      // If "All" is selected and we have cached data, show all instantly
      if (fruitTag.isEmpty && _allVideos.isNotEmpty) {
        _applyClientSideFilter();
        return;
      }
      
      // If specific fruit tag selected and we have cached data, filter instantly
      if (_allVideos.isNotEmpty) {
        _applyClientSideFilter();
        return;
      }
      
      // Only load from API if no cached data exists
      if (_allVideos.isEmpty) {
        _isDataLoaded = false;
        loadVideos(refresh: true);
      }
    }
  }

  /// Clear filter - Instant client-side filtering only (no API call if data exists)
  void clearFilter() {
    // Performance: Only clear if filter is actually set
    if (selectedFruitTag.value.isNotEmpty) {
      selectedFruitTag.value = '';
      
      // Show all videos instantly from cached data (no API call)
      if (_allVideos.isNotEmpty) {
        _applyClientSideFilter();
        return;
      }
      
      // Only load from API if no cached data exists
      if (_allVideos.isEmpty) {
        _isDataLoaded = false;
        loadVideos(refresh: true, includePending: true);
      }
    }
  }

  /// Refresh data
  Future<void> refresh() async {
    await Future.wait([
      loadVideos(refresh: true),
      loadLiveVideos(),
    ]);
  }
  
  /// Show moderation snackbar
  void _showModerationSnackbar(String message) {
    final ctx = Get.context;
    if (ctx != null) {
      ScaffoldMessenger.of(ctx).hideCurrentSnackBar();
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Icon(Icons.security_rounded, color: Color(0xFFC79211)),
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Community Guidelines', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    Text(message, style: const TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF5D4037),
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  static int _parseVideoId(dynamic videoId) {
    if (videoId is int) return videoId;
    return int.tryParse('$videoId') ?? 0;
  }

  /// Pre-warm cache then open video detail (use from any screen).
  static Future<void> openVideoDetail(dynamic videoId) async {
    final id = _parseVideoId(videoId);
    if (id <= 0) return;

    final VideosController controller;
    if (Get.isRegistered<VideosController>()) {
      controller = Get.find<VideosController>();
    } else {
      controller = Get.put(VideosController(), permanent: true);
    }

    controller.bootstrapVideoDetail(id);
    final thumb = VideosService.getThumbnailUrl(controller.selectedVideo);
    if (thumb != null && thumb.isNotEmpty) {
      unawaited(ImagePreloadService().preloadImages([thumb], priorityLimit: 1));
    }
    unawaited(controller.prepareVideoDetails(id));
    await PaymentGate.navigateToFeature(Routes.VIDEO_DETAILS, arguments: id);
  }

  @override
  void onClose() {
    videos.clear();
    _allVideos.clear();
    liveVideos.clear();
    videoComments.clear();
    videoEmojiReactions.clear();
    _isDataLoaded = false;
    super.onClose();
  }
}
