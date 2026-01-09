import 'dart:io';
import 'package:get/get.dart';
import 'package:fruitsofspirit/services/videos_service.dart';
import 'package:fruitsofspirit/services/comments_service.dart';
import 'package:fruitsofspirit/services/user_storage.dart';
import 'package:fruitsofspirit/services/api_service.dart';
import 'package:fruitsofspirit/services/emojis_service.dart';
import 'package:fruitsofspirit/services/advanced_service.dart';

/// Videos Controller
/// Manages videos data and operations
class VideosController extends GetxController {
  // Observable variables
  var isLoading = false.obs;
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

  @override
  void onInit() {
    super.onInit();
    _loadUserId();
  }

  @override
  void onReady() {
    super.onReady();
    // Load videos including pending ones for the current user
    loadVideos(includePending: true);
    loadLiveVideos();
  }

  /// Load user ID from storage
  Future<void> _loadUserId() async {
    final id = await UserStorage.getUserId();
    if (id != null) {
      userId.value = id;
    }
  }

  /// Load videos
  Future<void> loadVideos({bool refresh = false, bool includePending = false}) async {
    if (refresh) {
      currentPage.value = 0;
    }

    isLoading.value = true;
    message.value = '';

    try {
      // Performance: Always load ALL videos (no fruit tag filter) to populate cache
      // Then apply client-side filtering for instant updates
      final approvedVideos = await VideosService.getVideos(
        status: 'Approved',
        fruitTag: null, // Always load all videos for cache
        limit: itemsPerPage,
        offset: currentPage.value * itemsPerPage,
      );

      // If user wants to see their pending videos, load them too
      List<Map<String, dynamic>> allVideos = List.from(approvedVideos);
      
      if (includePending && userId.value > 0) {
        try {
          final pendingVideos = await VideosService.getVideos(
            status: 'Pending',
            userId: userId.value,
            fruitTag: null, // Always load all videos for cache
            limit: 10,
            offset: 0,
          );
          // Add pending videos at the beginning
          allVideos.insertAll(0, pendingVideos);
        } catch (e) {
          print('Error loading pending videos: $e');
        }
      }

      if (refresh || currentPage.value == 0) {
        // Performance: Store ALL videos in cache (no filters)
        _allVideos = List<Map<String, dynamic>>.from(allVideos);
        // Apply current filter to display
        _applyClientSideFilter();
      } else {
        // Performance: Add to all videos cache
        _allVideos.addAll(allVideos);
        // Apply current filter to display
        _applyClientSideFilter();
      }
      
      // Force UI refresh to ensure changes are visible
      videos.refresh();
      
      // Performance: Mark as loaded
      _isDataLoaded = true;
    } catch (e) {
      message.value = 'Error loading videos: ${e.toString().replaceAll('Exception: ', '')}';
      print('Error loading videos: $e');
      if (refresh || currentPage.value == 0) {
        videos.value = [];
      }
    } finally {
      isLoading.value = false;
    }
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

  /// Load single video with comments
  Future<void> loadVideoDetails(int videoId) async {
    isLoading.value = true;
    message.value = '';

    try {
      final video = await VideosService.getVideoDetails(videoId);
      selectedVideo.value = video;
      
      // Load comments and emojis
      await Future.wait([
        loadVideoComments(videoId),
        loadAvailableEmojis(),
      ]);
    } catch (e) {
      message.value = 'Error loading video: ${e.toString().replaceAll('Exception: ', '')}';
      print('Error loading video details: $e');
    } finally {
      isLoading.value = false;
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
        final commentId = comment['id'];
        
        // Skip replies (they should be in replies array)
        if (parentId != null && parentId != 0) {
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
          // It's an emoji reaction - store user information
          if (!emojiReactions.containsKey(emojiKey)) {
            emojiReactions[emojiKey] = [];
          }
          // Add user info for this reaction
          emojiReactions[emojiKey]!.add({
            'user_id': comment['user_id'],
            'user_name': comment['user_name'] ?? 'Anonymous',
            'profile_photo': comment['profile_photo'],
            'created_at': comment['created_at'],
          });
          print('✅ Added emoji reaction: $emojiKey by ${comment['user_name']} (total: ${emojiReactions[emojiKey]!.length})');
        } else {
          // It's a text comment - only add top-level comments
          if (parentId == null || parentId == 0) {
            textComments.add(comment);
          }
        }
      }
      
      print('📊 Loaded ${emojiReactions.length} emoji reaction types and ${textComments.length} top-level comments');
      for (var emoji in emojiReactions.keys) {
        print('   - $emoji: ${emojiReactions[emoji]!.length} reactions');
      }
      
      videoComments.value = textComments;
      videoEmojiReactions.value = emojiReactions;
    } catch (e) {
      print('Error loading video comments: $e');
      videoComments.value = [];
      videoEmojiReactions.value = {};
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
    try {
      print('🔄 Loading all available emojis from database for reactions mapping...');
      final emojis = await EmojisService.getEmojis(
        status: 'Active',
        sortBy: 'image_url',
        order: 'ASC',
      );
      availableEmojis.value = emojis;
      print('✅ Loaded ${emojis.length} available emojis');
      if (emojis.isNotEmpty) {
        print('📋 Sample emojis:');
        for (var i = 0; i < (emojis.length > 10 ? 10 : emojis.length); i++) {
          print('   ${i + 1}. ${emojis[i]['name']} - emoji_char: "${emojis[i]['emoji_char']}" - code: ${emojis[i]['code']} - image: ${emojis[i]['image_url']}');
        }
        // Group by name to show all variants
        final grouped = <String, List<Map<String, dynamic>>>{};
        for (var emoji in emojis) {
          final name = emoji['name'] as String? ?? 'Unknown';
          if (!grouped.containsKey(name)) {
            grouped[name] = [];
          }
          grouped[name]!.add(emoji);
        }
        print('📊 Emojis grouped by name:');
        grouped.forEach((name, emojiList) {
          print('   $name: ${emojiList.length} variants');
        });
      } else {
        print('⚠️ WARNING: No emojis loaded! Check API endpoint and database.');
      }
    } catch (e) {
      print('❌ Error loading emojis: $e');
      availableEmojis.value = [];
    }
  }

  /// Load quick emojis (top 6 by usage)
  Future<void> loadQuickEmojis() async {
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
      
      // Reload comments to get updated counts
      await loadVideoComments(videoId);
      
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

    isLoading.value = true;
    message.value = 'Uploading video...';

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
}

