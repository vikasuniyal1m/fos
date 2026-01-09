import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/services/group_posts_service.dart';
import 'package:fruitsofspirit/services/comments_service.dart';
import 'package:fruitsofspirit/services/user_storage.dart';
import 'package:fruitsofspirit/services/emojis_service.dart';

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

  @override
  void onInit() {
    super.onInit();
    _loadUserId();
    _loadEmojis();
  }
  
  /// Set fruit filter and clear old data
  void setFruitFilter(String fruitName) {
    selectedFruit.value = fruitName;
    posts.value = []; // Clear old data
    currentPage.value = 0;
    hasMore.value = true;
  }
  
  /// Clear fruit filter
  void clearFruitFilter() {
    selectedFruit.value = '';
    posts.value = []; // Clear old data
    currentPage.value = 0;
    hasMore.value = true;
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

  /// Load Group Posts
  Future<void> loadGroupPosts(int groupId, {bool refresh = false}) async {
    if (refresh) {
      currentPage.value = 0;
      hasMore.value = true;
    }

    if (!hasMore.value && !refresh) return;

    isLoading.value = true;
    message.value = '';
    currentGroupId.value = groupId;

    try {
      final postsList = await GroupPostsService.getGroupPosts(
        groupId: groupId,
        userId: userId.value > 0 ? userId.value : null,
        limit: itemsPerPage,
        offset: currentPage.value * itemsPerPage,
      );

      // Filter by selected fruit if set
      var filteredPosts = postsList;
      if (selectedFruit.value.isNotEmpty) {
        final fruitNameLower = selectedFruit.value.toLowerCase();
        filteredPosts = postsList.where((post) {
          // Check if post content contains fruit name
          final content = (post['content'] as String? ?? '').toLowerCase();
          if (content.contains(fruitNameLower)) {
            return true;
          }
          
          // Check if post has reactions with this fruit emoji
          final reactions = post['reactions'] as List? ?? [];
          for (var reaction in reactions) {
            final emojiCode = (reaction['emoji_code'] as String? ?? '').toLowerCase();
            final emojiChar = (reaction['emoji_char'] as String? ?? '').toLowerCase();
            if (emojiCode.contains(fruitNameLower) || 
                emojiChar.contains(fruitNameLower) ||
                _isFruitEmoji(emojiChar, fruitNameLower)) {
              return true;
            }
          }
          
          return false;
        }).toList();
      }

      if (refresh || currentPage.value == 0) {
        posts.value = filteredPosts;
      } else {
        posts.addAll(filteredPosts);
      }

      if (postsList.length < itemsPerPage) {
        hasMore.value = false;
      } else {
        currentPage.value++;
      }
    } catch (e) {
      message.value = 'Error loading posts: ${e.toString().replaceAll('Exception: ', '')}';
      print('Error loading group posts: $e');
      if (refresh || currentPage.value == 0) {
        posts.value = [];
      }
    } finally {
      isLoading.value = false;
    }
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
      // Verify post exists before reacting
      final postIndex = posts.indexWhere((p) => p['id'] == postId);
      if (postIndex == -1) {
        message.value = 'Post not found';
        print('❌ Post not found: $postId');
        return false;
      }

      final result = await GroupPostsService.reactToPost(
        userId: userId.value,
        postId: postId,
        emojiCode: emojiCode,
      );
      
      // Update post in list
      if (postIndex != -1) {
        posts[postIndex]['reactions'] = result['reactions'] ?? [];
        posts[postIndex]['user_reaction'] = result['reacted'] == true ? emojiCode : null;
        
        // Calculate total reaction count
        int totalCount = 0;
        if (result['reactions'] != null) {
          for (var reaction in result['reactions']) {
            totalCount += (reaction['count'] as int? ?? 0);
          }
        }
        posts[postIndex]['reaction_count'] = totalCount;
      }
      
      return true;
    } catch (e) {
      final errorMsg = e.toString().replaceAll('Exception: ', '');
      message.value = 'Error: $errorMsg';
      print('❌ Error reacting to post: $e');
      // Don't show snackbar for 404 errors - they're handled gracefully
      if (!errorMsg.contains('404') && !errorMsg.contains('not found')) {
        Get.snackbar(
          'Error',
          errorMsg,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
      return false;
    }
  }

  /// Load Comments for Post
  Future<void> loadPostComments(int postId) async {
    if (userId.value == 0) {
      await _loadUserId();
    }

    try {
      final comments = await CommentsService.getComments(
        postType: 'group_post',
        postId: postId,
        userId: userId.value > 0 ? userId.value : null,
      );
      postComments.value = comments;
    } catch (e) {
      print('Error loading post comments: $e');
      postComments.value = [];
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

    try {
      await CommentsService.addComment(
        userId: userId.value,
        postType: 'group_post',
        postId: postId,
        content: content,
        parentCommentId: parentCommentId,
      );
      
      // Reload comments
      await loadPostComments(postId);
      
      // Update comment count in post
      final postIndex = posts.indexWhere((p) => p['id'] == postId);
      if (postIndex != -1) {
        final currentCount = posts[postIndex]['comment_count'] as int? ?? 0;
        posts[postIndex]['comment_count'] = currentCount + 1;
      }
      
      return true;
    } catch (e) {
      message.value = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      print('Error adding comment: $e');
      return false;
    }
  }

  /// Refresh Posts
  Future<void> refresh() async {
    await loadGroupPosts(currentGroupId.value, refresh: true);
  }
}

