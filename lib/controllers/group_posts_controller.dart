import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/services/hive_cache_service.dart';
import 'package:fruitsofspirit/services/group_posts_service.dart';
import 'package:fruitsofspirit/services/comments_service.dart';
import 'package:fruitsofspirit/services/user_storage.dart';
import 'package:fruitsofspirit/services/emojis_service.dart';
import 'package:fruitsofspirit/services/content_moderation_service.dart';
import 'package:fruitsofspirit/routes/app_pages.dart';

import '../controllers/home_controller.dart';

/// Group Posts Controller
/// Manages group posts, reactions, and comments
class GroupPostsController extends GetxController {
  // Observable variables
  var isLoading = false.obs;
  var message = ''.obs;
  
  // Data
  var posts = <Map<String, dynamic>>[].obs;
  var selectedPost = <String, dynamic>{}.obs;
  var postComments = <Map<String, dynamic>>[].obs;
  var availableEmojis = <Map<String, dynamic>>[].obs;
  var userId = 0.obs;
  var userRole = ''.obs;
  var userStatus = ''.obs;
  
  // Pagination
  var currentPage = 0.obs;
  final int itemsPerPage = 20;
  var hasMore = true.obs;
  
  // Current group
  var currentGroupId = 0.obs;
  
  // Fruit filter
  var selectedFruit = ''.obs;

  int _loadGeneration = 0;
  DateTime? _lastSyncedAt;
  static const Duration _minSyncInterval = Duration(minutes: 2);
  Completer<void>? _activeLoadCompleter;
  var _isLoading = false;
  var _allPosts = <Map<String, dynamic>>[];

  static String _postsHiveKey(int groupId) => 'group_posts_$groupId';
  static String _postCommentsHiveKey(int postId) => 'group_post_comments_$postId';

  /// Seed posts for a group from home feed cache.
  void seedFromHomeIfEmpty(int groupId, List<Map<String, dynamic>> homePosts) {
    if (posts.isNotEmpty || homePosts.isEmpty) return;
    final forGroup = homePosts.where((post) {
      final id = post['group_id'];
      if (id is int) return id == groupId;
      if (id is String) return int.tryParse(id) == groupId;
      return false;
    }).toList();
    if (forGroup.isEmpty) return;
    _allPosts = List<Map<String, dynamic>>.from(forGroup);
    currentGroupId.value = groupId;
    _applyPostsFilter();
  }

  void bootstrapGroupPosts(int groupId) {
    if (currentGroupId.value == groupId && posts.isNotEmpty) return;

    final cached = HiveCacheService.getCachedList(_postsHiveKey(groupId));
    if (cached.isNotEmpty) {
      _allPosts = List<Map<String, dynamic>>.from(cached);
      currentGroupId.value = groupId;
      _applyPostsFilter();
      return;
    }

    if (posts.isEmpty) {
      try {
        if (Get.isRegistered<HomeController>()) {
          seedFromHomeIfEmpty(
            groupId,
            Get.find<HomeController>().groupPosts.toList(),
          );
        }
      } catch (_) {}
    }
  }

  @override
  void onInit() {
    super.onInit();
    _loadUserId();
    _loadEmojis();
  }
  
  /// Set fruit filter — client-side only (no API).
  void setFruitFilter(String fruitName) {
    if (selectedFruit.value == fruitName) return;
    selectedFruit.value = fruitName;
    _applyPostsFilter();
  }

  /// Clear fruit filter — client-side only.
  void clearFruitFilter() {
    if (selectedFruit.value.isEmpty) return;
    selectedFruit.value = '';
    _applyPostsFilter();
  }

  /// Load user ID and role from storage
  Future<void> _loadUserId() async {
    final id = await UserStorage.getUserId();
    if (id != null) {
      userId.value = id;
    }
    
    // Load user role and status
    final user = await UserStorage.getUser();
    if (user != null) {
      userRole.value = user['role'] as String? ?? 'User';
      userStatus.value = user['status'] as String? ?? 'Active';
    }
  }

  /// Load available emojis for reactions
  Future<void> _loadEmojis() async {
    try {
      final emojis = await EmojisService.getEmojis(
        status: 'Active',
        sortBy: 'image_url',
        order: 'ASC',
      );
      availableEmojis.value = emojis;
    } catch (e) {
      print('Error loading emojis: $e');
      availableEmojis.value = [];
    }
  }

  Future<void> loadGroupPosts(
    int groupId, {
    bool refresh = false,
    bool silent = false,
    bool force = false,
  }) async {
    if (_isLoading) {
      if (_activeLoadCompleter != null) {
        await _activeLoadCompleter!.future;
      }
      return;
    }

    bootstrapGroupPosts(groupId);

    if (silent &&
        !force &&
        currentGroupId.value == groupId &&
        posts.isNotEmpty &&
        _lastSyncedAt != null &&
        DateTime.now().difference(_lastSyncedAt!) < _minSyncInterval) {
      return;
    }

    if (refresh) {
      currentPage.value = 0;
      hasMore.value = true;
    }

    if (!hasMore.value && !refresh) return;

    final generation = silent ? _loadGeneration : ++_loadGeneration;
    _activeLoadCompleter = Completer<void>();
    _isLoading = true;
    if (!silent && posts.isEmpty) {
      isLoading.value = true;
    }
    message.value = '';
    currentGroupId.value = groupId;

    try {
      final postsList = await GroupPostsService.getGroupPosts(
        groupId: groupId,
        userId: userId.value > 0 ? userId.value : null,
        limit: itemsPerPage,
        offset: currentPage.value * itemsPerPage,
      );

      if (generation != _loadGeneration) {
        return;
      }

      if (refresh || currentPage.value == 0) {
        if (_allPosts.isEmpty) {
          _allPosts = List<Map<String, dynamic>>.from(postsList);
        } else if (silent) {
          _mergePostsPage(postsList);
        } else if (!_postsListsEqual(_allPosts, postsList)) {
          _allPosts = List<Map<String, dynamic>>.from(postsList);
        }
      } else {
        final existingIds = _allPosts.map(_postIdFromMap).toSet();
        for (final post in postsList) {
          final id = _postIdFromMap(post);
          if (id != null && !existingIds.contains(id)) {
            _allPosts.add(post);
          }
        }
      }

      _applyPostsFilter();

      if (postsList.length < itemsPerPage) {
        hasMore.value = false;
      } else {
        currentPage.value++;
      }
      _lastSyncedAt = DateTime.now();
      unawaited(_cacheGroupPosts(groupId));
    } catch (e) {
      if (!silent) {
        message.value =
            'Error loading posts: ${e.toString().replaceAll('Exception: ', '')}';
      }
      print('Error loading group posts: $e');
      if ((refresh || currentPage.value == 0) && posts.isEmpty) {
        posts.value = [];
      }
    } finally {
      _isLoading = false;
      if (!silent) {
        isLoading.value = false;
      }
      _activeLoadCompleter?.complete();
      _activeLoadCompleter = null;
    }
  }

  int? _postIdFromMap(Map<String, dynamic> post) {
    final id = post['id'];
    if (id is int) return id;
    return int.tryParse(id?.toString() ?? '');
  }

  Map<String, dynamic>? findPostById(int postId) {
    for (final post in _allPosts) {
      if (_postIdFromMap(post) == postId) {
        return post;
      }
    }
    for (final post in posts) {
      if (_postIdFromMap(post) == postId) {
        return post;
      }
    }
    return null;
  }

  void _updatePostInLists(int postId, void Function(Map<String, dynamic>) update) {
    for (var i = 0; i < _allPosts.length; i++) {
      if (_postIdFromMap(_allPosts[i]) == postId) {
        update(_allPosts[i]);
      }
    }
    for (var i = 0; i < posts.length; i++) {
      if (_postIdFromMap(posts[i]) == postId) {
        update(posts[i]);
      }
    }
    if (_postIdFromMap(selectedPost) == postId) {
      update(selectedPost);
      selectedPost.refresh();
    }
  }

  bool _postsListsEqual(
    List<Map<String, dynamic>> previous,
    List<Map<String, dynamic>> next,
  ) {
    if (previous.length != next.length) return false;
    for (var i = 0; i < previous.length; i++) {
      if (!_postItemEqual(previous[i], next[i])) return false;
    }
    return true;
  }

  bool _postItemEqual(Map<String, dynamic> a, Map<String, dynamic> b) {
    return a['id'] == b['id'] &&
        a['updated_at'] == b['updated_at'] &&
        a['comment_count'] == b['comment_count'] &&
        a['reaction_count'] == b['reaction_count'] &&
        a['content'] == b['content'];
  }

  void _mergePostsPage(List<Map<String, dynamic>> incoming) {
    if (incoming.isEmpty) return;
    final indexById = <int, int>{};
    for (var i = 0; i < _allPosts.length; i++) {
      final id = _postIdFromMap(_allPosts[i]);
      if (id != null) indexById[id] = i;
    }

    var changed = false;
    for (final remote in incoming) {
      final id = _postIdFromMap(remote);
      if (id == null) continue;
      final idx = indexById[id];
      if (idx != null) {
        if (!_postItemEqual(_allPosts[idx], remote)) {
          _allPosts[idx] = {..._allPosts[idx], ...remote};
          changed = true;
        }
      } else if (currentPage.value == 0) {
        _allPosts.insert(0, Map<String, dynamic>.from(remote));
        changed = true;
      }
    }

    if (changed) {
      _applyPostsFilter();
    }
  }

  void _applyPostsFilter() {
    if (_allPosts.isEmpty) {
      posts.value = [];
      return;
    }

    if (selectedFruit.value.isEmpty) {
      posts.value = List<Map<String, dynamic>>.from(_allPosts);
      return;
    }

    final fruitNameLower = selectedFruit.value.toLowerCase();
    posts.value = _allPosts.where((post) {
      final content = (post['content'] as String? ?? '').toLowerCase();
      if (content.contains(fruitNameLower)) {
        return true;
      }

      final reactions = post['reactions'] as List? ?? [];
      for (var reaction in reactions) {
        final emojiCode =
            (reaction['emoji_code'] as String? ?? '').toLowerCase();
        final emojiChar =
            (reaction['emoji_char'] as String? ?? '').toLowerCase();
        if (emojiCode.contains(fruitNameLower) ||
            emojiChar.contains(fruitNameLower) ||
            _isFruitEmoji(emojiChar, fruitNameLower)) {
          return true;
        }
      }
      return false;
    }).toList();
  }

  Future<void> _cacheGroupPosts(int groupId) async {
    if (_allPosts.isEmpty) return;
    await HiveCacheService.cacheList(
      _postsHiveKey(groupId),
      List<Map<String, dynamic>>.from(_allPosts),
      expiryHours: 24,
    );
  }
  
  /// Check if emoji matches fruit name
  bool _isFruitEmoji(String emojiChar, String fruitName) {
    final fruitEmojiMap = {
      'love': ['❤', '❤️'],
      'joy': ['😊', '👏'],
      'peace': ['☮', '☮️'],
      'patience': ['⏳'],
      'kindness': ['🤗'],
      'goodness': ['✨', '⭐'],
      'faithfulness': ['🙏'],
      'meekness': ['🕊', '🕊️'],
      'self-control': ['🎯'],
      'self control': ['🎯'],
    };
    
    final emojis = fruitEmojiMap[fruitName] ?? [];
    return emojis.any((emoji) => emojiChar.contains(emoji.toLowerCase()));
  }

  /// Load More Posts
  Future<void> loadMore() async {
    if (isLoading.value || !hasMore.value) return;
    await loadGroupPosts(currentGroupId.value);
  }

  /// Create Post
  Future<bool> createPost({
    required int groupId,
    required String content,
    String postType = 'text',
    File? image,
    String? eventDate,
  }) async {
    if (userId.value == 0) {
      await _loadUserId();
    }

    if (userId.value == 0) {
      message.value = 'Please login first';
      return false;
    }

    // Check for inappropriate content in post
    if (postType == 'text' && content.isNotEmpty) {
      final moderationCheck = ContentModerationService.checkContent(content);
      if (!moderationCheck['isClean']) {
        message.value = moderationCheck['message'];
        _showModerationSnackbar(moderationCheck['message']);
        return false;
      }
    }

    isLoading.value = true;
    message.value = 'Creating post...';

    try {
      final post = await GroupPostsService.createGroupPost(
        userId: userId.value,
        groupId: groupId,
        content: content,
        postType: postType,
        image: image,
        eventDate: eventDate,
      );
      
      message.value = 'Post created successfully';
      
      // Add to top of list
      posts.insert(0, post);
      _allPosts.insert(0, post);
      _applyPostsFilter();
      unawaited(_cacheGroupPosts(groupId));
      
      return true;
    } catch (e) {
      message.value = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      print('Error creating post: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// React to Post
  Future<bool> reactToPost(int postId, String emojiCode) async {
    if (userId.value == 0) {
      await _loadUserId();
    }

    if (userId.value == 0) {
      message.value = 'Please login first';
      return false;
    }

    try {
      if (findPostById(postId) == null) {
        message.value = 'Post not found';
        print('❌ Post not found: $postId');
        return false;
      }

      final result = await GroupPostsService.reactToPost(
        userId: userId.value,
        postId: postId,
        emojiCode: emojiCode,
      );

      int totalCount = 0;
      if (result['reactions'] != null) {
        for (var reaction in result['reactions']) {
          totalCount += (reaction['count'] as int? ?? 0);
        }
      }

      _updatePostInLists(postId, (post) {
        post['reactions'] = result['reactions'] ?? [];
        post['user_reaction'] = result['reacted'] == true ? emojiCode : null;
        post['reaction_count'] = totalCount;
      });
      unawaited(_cacheGroupPosts(currentGroupId.value));
      
      return true;
    } catch (e) {
      final errorMsg = e.toString().replaceAll('Exception: ', '');
      message.value = 'Error: $errorMsg';
      print('❌ Error reacting to post: $e');
      // Don't show snackbar for 404 errors - they're handled gracefully
      if (!errorMsg.contains('404') && !errorMsg.contains('not found')) {
        final ctx = Get.context;
        if (ctx != null) {
          ScaffoldMessenger.of(ctx).hideCurrentSnackBar();
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Error', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  Text(errorMsg, style: const TextStyle(color: Colors.white)),
                ],
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      }
      return false;
    }
  }

  void bootstrapPostComments(int postId) {
    if (postComments.isNotEmpty) return;
    final cached = HiveCacheService.getCachedList(_postCommentsHiveKey(postId));
    if (cached.isNotEmpty) {
      postComments.value = List<Map<String, dynamic>>.from(cached);
    }
  }

  /// Load Comments for Post — Hive first, silent API.
  Future<void> loadPostComments(int postId, {bool silent = false}) async {
    if (userId.value == 0) {
      await _loadUserId();
    }

    bootstrapPostComments(postId);

    try {
      final comments = await CommentsService.getComments(
        postType: 'group_post',
        postId: postId,
        userId: userId.value > 0 ? userId.value : null,
      );
      if (comments.isEmpty && postComments.isNotEmpty && silent) {
        return;
      }
      postComments.value = comments;
      unawaited(
        HiveCacheService.cacheList(
          _postCommentsHiveKey(postId),
          List<Map<String, dynamic>>.from(comments),
          expiryHours: 24,
        ),
      );
    } catch (e) {
      print('Error loading post comments: $e');
      if (!silent || postComments.isEmpty) {
        postComments.value = [];
      }
    }
  }

  /// Add Comment to Post
  Future<bool> addComment(int postId, String content, {int? parentCommentId}) async {
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
        postType: 'group_post',
        postId: postId,
        content: content,
        parentCommentId: parentCommentId,
      );
      
      await loadPostComments(postId, silent: postComments.isNotEmpty);

      _updatePostInLists(postId, (post) {
        final currentCount = post['comment_count'] as int? ?? 0;
        post['comment_count'] = currentCount + 1;
      });
      unawaited(_cacheGroupPosts(currentGroupId.value));
      
      return true;
    } catch (e) {
      message.value = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      print('Error adding comment: $e');
      return false;
    }
  }

  /// Refresh Posts
  Future<void> refresh() async {
    await loadGroupPosts(currentGroupId.value, refresh: true, force: true);
  }

  /// Delete own group post
  Future<void> deletePost(int postId) async {
    if (userId.value == 0) {
      await _loadUserId();
    }
    if (userId.value == 0) {
      throw Exception('Please login first');
    }

    await GroupPostsService.deleteGroupPost(
      userId: userId.value,
      postId: postId,
    );

    _allPosts.removeWhere((post) => _postIdFromMap(post) == postId);
    _applyPostsFilter();
    if (_postIdFromMap(selectedPost) == postId) {
      selectedPost.value = {};
      postComments.value = [];
    }
    unawaited(_cacheGroupPosts(currentGroupId.value));
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
}
