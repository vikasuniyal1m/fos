import 'dart:io';
import 'package:get/get.dart';
import 'package:fruitsofspirit/services/blogs_service.dart';
import 'package:fruitsofspirit/services/comments_service.dart';
import 'package:fruitsofspirit/services/user_storage.dart';
import 'package:fruitsofspirit/services/emojis_service.dart';

/// Blogs Controller
/// Manages blogs data and operations
class BlogsController extends GetxController {
  // Observable variables
  var isLoading = false.obs;
  var message = ''.obs;
  
  // Data
  var blogs = <Map<String, dynamic>>[].obs;
  var selectedBlog = <String, dynamic>{}.obs;
  var blogComments = <Map<String, dynamic>>[].obs;
  var blogEmojiReactions = <String, List<Map<String, dynamic>>>{}.obs; // emoji -> list of users who reacted
  var availableEmojis = <Map<String, dynamic>>[].obs;
  var quickEmojis = <Map<String, dynamic>>[].obs; // Top 6 emojis for quick reactions
  var userId = 0.obs;
  var userRole = ''.obs;
  var userStatus = ''.obs; // User status: Active, Inactive, Pending

  // Filters
  var selectedCategory = ''.obs;
  var selectedLanguage = ''.obs;
  var filterUserId = 0.obs; // Filter by specific user ID (0 = all users)
  var currentPage = 0.obs;
  final int itemsPerPage = 20;
  
  // Performance: Store all blogs for instant client-side filtering
  var _allBlogs = <Map<String, dynamic>>[];
  
  // Performance: Track if data is already loaded to prevent unnecessary reloads
  var _isDataLoaded = false;
  var _isLoading = false;

  @override
  void onInit() {
    super.onInit();
    _loadUserData();
    // Don't reset filter here - it might be set before navigation
    // Filter will be reset by home screen navigation if needed
  }

  @override
  void onReady() {
    super.onReady();
    // Performance: Only load if data is not already loaded and filter is not set
    // If filter is set, it means we're coming from profile, so loadBlogs will be called after navigation
    // Don't reload if data already exists
    if (!_isDataLoaded && filterUserId.value == 0 && !_isLoading && blogs.isEmpty && _allBlogs.isEmpty) {
      loadBlogs();
    } else if (_allBlogs.isNotEmpty) {
      // Apply filter from cached data if available
      _applyClientSideFilter();
    }
  }

  /// Load user data from storage
  Future<void> _loadUserData() async {
    final user = await UserStorage.getUser();
    if (user != null) {
      userId.value = user['id'] as int;
      userRole.value = user['role'] as String? ?? 'User';
      userStatus.value = user['status'] as String? ?? 'Active';
    }
  }

  /// Load blogs
  Future<void> loadBlogs({bool refresh = false}) async {
    // Performance: Skip if already loading

    if (filterUserId.value > 0) {
      refresh = true;
    }

    if (_isLoading && !refresh) {
      return;
    }
    
    // Performance: Skip if data already loaded and not explicitly refreshing
    if (_isDataLoaded && !refresh && blogs.isNotEmpty && _allBlogs.isNotEmpty) {
      // Apply current filter from cache
      _applyClientSideFilter();
      return;
    }
    
    if (refresh) {
      currentPage.value = 0;
      _isDataLoaded = false;
    }

    _isLoading = true;
    isLoading.value = true;
    message.value = '';

    try {
      // Performance: Always load ALL blogs (no filters) to populate cache
      // Then apply client-side filtering for instant updates
      final blogsList = await BlogsService.getBlogs(
        status: filterUserId.value > 0 ? 'Pending,Approved' : 'Approved',        category: null, // Always load all blogs for cache
        language: null, // Always load all blogs for cache
        userId: filterUserId.value > 0 ? filterUserId.value : null,
        limit: itemsPerPage,
        offset: currentPage.value * itemsPerPage,
      );

      if (refresh || currentPage.value == 0) {
        // Performance: Store ALL blogs in cache (no filters)
        _allBlogs = List<Map<String, dynamic>>.from(blogsList);
        // Apply current filter to display
        _applyClientSideFilter();
      } else {
        // Performance: Add to all blogs cache
        _allBlogs.addAll(blogsList);
        // Apply current filter to display
        _applyClientSideFilter();
      }
      
      // Performance: Mark as loaded
      _isDataLoaded = true;
    } catch (e) {
      message.value = 'Error loading blogs: ${e.toString().replaceAll('Exception: ', '')}';
      print('Error loading blogs: $e');
      if (refresh || currentPage.value == 0) {
        blogs.value = [];
        _isDataLoaded = false;
      }
    } finally {
      _isLoading = false;
      isLoading.value = false;
    }
  }

  /// Load more blogs (pagination)
  Future<void> loadMore() async {
    if (isLoading.value) return;

    currentPage.value++;
    await loadBlogs();
  }

  /// Load single blog with comments
  Future<void> loadBlogDetails(int blogId) async {
    isLoading.value = true;
    message.value = '';

    try {
      final blog = await BlogsService.getBlogDetails(blogId);
      selectedBlog.value = blog;
      
      // Load emojis and comments
      await Future.wait([
        loadAvailableEmojis(),
        loadQuickEmojis(),
        loadBlogComments(blogId),
      ]);
    } catch (e) {
      message.value = 'Error loading blog: ${e.toString().replaceAll('Exception: ', '')}';
      print('Error loading blog details: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Load blog comments (with emoji reactions parsing)
  Future<void> loadBlogComments(int blogId) async {
    try {
      final comments = await CommentsService.getComments(
        postType: 'blog',
        postId: blogId,
        userId: userId.value > 0 ? userId.value : null,
      );
      
      // Parse emoji reactions from comments (same logic as prayers)
      final emojiReactions = <String, List<Map<String, dynamic>>>{};
      final textComments = <Map<String, dynamic>>[];
      
      for (var comment in comments) {
        // blog_comments table uses 'comment' field, not 'content'
        // Also check 'content' field for backward compatibility
        final content = (comment['comment'] as String? ?? comment['content'] as String? ?? '').trim();
        final trimmed = content;
        
        // Debug: Log comment content to see what we're parsing
        if (trimmed.isNotEmpty && trimmed.length <= 20) {
          print('🔍 Blog comment content: "$trimmed" (length: ${trimmed.length})');
        }
        
        // Check if this is an emoji reaction (same logic as prayers)
        bool isEmojiReaction = false;
        String? emojiKey;
        
        // Strategy 1: Check if it's a numeric ID (emoji_id) - MOST COMMON for blog reactions
        // PHP stores emoji_id as string in content field
        if (trimmed.isNotEmpty && trimmed.length <= 10 && int.tryParse(trimmed) != null) {
          isEmojiReaction = true;
          emojiKey = trimmed;
          print('✅ Found emoji reaction (numeric ID): $emojiKey');
        }
        // Strategy 2: Check if it's a single emoji character
        else if (trimmed.length <= 4 && _isEmoji(trimmed)) {
          isEmojiReaction = true;
          emojiKey = trimmed;
          print('✅ Found emoji reaction (emoji char): $emojiKey');
        }
        // Strategy 3: Check if it's an emoji code (like "joy_01", "kindness_peach_01")
        else if (trimmed.contains('_') && (
          trimmed.contains('joy') || trimmed.contains('peace') || 
          trimmed.contains('love') || trimmed.contains('patience') || 
          trimmed.contains('kindness') || trimmed.contains('goodness') || 
          trimmed.contains('faithfulness') || trimmed.contains('gentleness') ||
          trimmed.contains('meekness') || trimmed.contains('self') || 
          trimmed.contains('control')
        )) {
          isEmojiReaction = true;
          emojiKey = trimmed;
          print('✅ Found emoji reaction (code): $emojiKey');
        }
        // Strategy 4: Check if it's an image URL
        else if (trimmed.contains('uploads/emojis/') || trimmed.contains('emojis/') || 
                 trimmed.contains('.png') || trimmed.contains('.jpg')) {
          isEmojiReaction = true;
          emojiKey = trimmed;
          print('✅ Found emoji reaction (image URL): $emojiKey');
        }
        
        if (isEmojiReaction && emojiKey != null) {
          // It's an emoji reaction
          if (!emojiReactions.containsKey(emojiKey)) {
            emojiReactions[emojiKey] = [];
          }
          emojiReactions[emojiKey]!.add({
            'user_id': comment['user_id'],
            'user_name': comment['user_name'] ?? 'Anonymous',
            'profile_photo': comment['profile_photo'],
            'created_at': comment['created_at'],
          });
        } else {
          // It's a text comment
          final parentId = comment['parent_comment_id'];
          if (parentId == null || parentId == 0) {
            textComments.add(comment);
          }
        }
      }
      
      blogComments.value = textComments;
      blogEmojiReactions.value = emojiReactions;
      print('✅ Loaded ${textComments.length} text comments and ${emojiReactions.length} emoji reaction types');
    } catch (e) {
      print('❌ Error loading blog comments: $e');
      blogComments.value = [];
      blogEmojiReactions.value = <String, List<Map<String, dynamic>>>{};
    }
  }
  
  /// Check if string is an emoji
  bool _isEmoji(String text) {
    if (text.isEmpty) return false;
    final trimmed = text.trim();
    if (trimmed.length > 4) return false;
    final emojiRegex = RegExp(
      r'[\u{1F300}-\u{1F9FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]|[\u{1F600}-\u{1F64F}]|[\u{1F680}-\u{1F6FF}]|[\u{1F1E0}-\u{1F1FF}]|[\u{2764}\u{FE0F}]|[\u{2728}]|[\u{2B50}]',
      unicode: true,
    );
    final hasEmoji = emojiRegex.hasMatch(trimmed);
    final hasOnlyEmoji = trimmed.runes.every((rune) {
      final char = String.fromCharCode(rune);
      return emojiRegex.hasMatch(char) || rune == 0xFE0F || rune == 0x200D;
    });
    return hasEmoji && hasOnlyEmoji;
  }
  
  /// Load available emojis
  Future<void> loadAvailableEmojis() async {
    try {
      final emojis = await EmojisService.getEmojis(
        status: 'Active',
        sortBy: 'image_url',
        order: 'ASC',
      );
      availableEmojis.value = emojis;
      print('✅ Loaded ${emojis.length} available emojis for blogs');
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
  
  /// Add/Remove emoji reaction to blog (TOGGLE)
  Future<bool> addEmojiReaction(int blogId, String emoji) async {
    if (userId.value == 0) {
      await _loadUserData();
    }
    if (userId.value == 0) {
      message.value = 'Please login first';
      return false;
    }
    try {
      await EmojisService.useEmoji(
        userId: userId.value,
        emoji: emoji,
        postType: 'blog',
        postId: blogId,
      );
      await loadBlogComments(blogId);
      return true;
    } catch (e) {
      message.value = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      print('Error toggling emoji reaction: $e');
      return false;
    }
  }

  /// Create blog (Bloggers only)
  Future<bool> createBlog({
    required String title,
    required String body,
    required String category,
    String language = 'en',
    File? image,
  }) async {
    if (userId.value == 0) {
      await _loadUserData();
    }

    if (userId.value == 0) {
      message.value = 'Please login first';
      return false;
    }

    if (userRole.value != 'Blogger') {
      message.value = 'Only bloggers can create blogs';
      return false;
    }

    isLoading.value = true;
    message.value = 'Creating blog...';

    try {
      await BlogsService.createBlog(
        userId: userId.value,
        title: title,
        body: body,
        category: category,
        language: language,
        image: image,
      );
      
      message.value = 'Blog created successfully. Waiting for admin approval.';
      
      // Reload blogs
      await loadBlogs(refresh: true);
      
      return true;
    } catch (e) {
      message.value = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      print('Error creating blog: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Add comment to blog
  Future<bool> addComment(int blogId, String content, {int? parentCommentId}) async {
    if (userId.value == 0) {
      await _loadUserData();
    }

    if (userId.value == 0) {
      message.value = 'Please login first';
      return false;
    }

    try {
      await CommentsService.addComment(
        userId: userId.value,
        postType: 'blog',
        postId: blogId,
        content: content,
        parentCommentId: parentCommentId,
      );
      
      // Reload comments
      await loadBlogComments(blogId);
      
      return true;
    } catch (e) {
      message.value = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      print('Error adding comment: $e');
      return false;
    }
  }

  /// Like/Unlike blog
  Future<bool> toggleLike(int blogId) async {
    if (userId.value == 0) {
      await _loadUserData();
    }

    if (userId.value == 0) {
      message.value = 'Please login first';
      return false;
    }

    try {
      final liked = await CommentsService.toggleBlogLike(
        userId: userId.value,
        blogId: blogId,
      );
      
      // Reload blog details to get updated like count
      await loadBlogDetails(blogId);
      
      return liked;
    } catch (e) {
      message.value = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      print('Error toggling like: $e');
      return false;
    }
  }

  /// Apply client-side filter instantly (no API call)
  void _applyClientSideFilter() {
    if (_allBlogs.isEmpty) return;
    
    var filtered = List<Map<String, dynamic>>.from(_allBlogs);
    
    // Filter by category
    if (selectedCategory.value.isNotEmpty) {
      filtered = filtered.where((blog) {
        final blogCategory = blog['category'] as String? ?? '';
        return blogCategory.toLowerCase() == selectedCategory.value.toLowerCase();
      }).toList();
    }
    
    // Filter by language
    if (selectedLanguage.value.isNotEmpty) {
      filtered = filtered.where((blog) {
        final blogLanguage = blog['language'] as String? ?? 'en';
        return blogLanguage.toLowerCase() == selectedLanguage.value.toLowerCase();
      }).toList();
    }
    
    blogs.value = filtered;
  }

  /// Filter by category - Instant client-side filtering only (no API call if data exists)
  void filterByCategory(String category) {
    // Performance: Only filter if category is actually changing
    if (selectedCategory.value != category) {
      selectedCategory.value = category;
      
      // If "All" is selected and we have cached data, show all instantly
      if (category.isEmpty && _allBlogs.isNotEmpty) {
        _applyClientSideFilter();
        return;
      }
      
      // If specific category selected and we have cached data, filter instantly
      if (_allBlogs.isNotEmpty) {
        _applyClientSideFilter();
        return;
      }
      
      // Only load from API if no cached data exists
      if (_allBlogs.isEmpty) {
        _isDataLoaded = false;
        loadBlogs(refresh: true);
      }
    }
  }

  /// Filter by language - Instant client-side filtering only (no API call if data exists)
  void filterByLanguage(String language) {
    // Performance: Only filter if language is actually changing
    if (selectedLanguage.value != language) {
      selectedLanguage.value = language;
      
      // If "All" is selected and we have cached data, show all instantly
      if (language.isEmpty && _allBlogs.isNotEmpty) {
        _applyClientSideFilter();
        return;
      }
      
      // If specific language selected and we have cached data, filter instantly
      if (_allBlogs.isNotEmpty) {
        _applyClientSideFilter();
        return;
      }
      
      // Only load from API if no cached data exists
      if (_allBlogs.isEmpty) {
        _isDataLoaded = false;
        loadBlogs(refresh: true);
      }
    }
  }

  /// Clear filters - Instant client-side filtering only (no API call if data exists)
  void clearFilters() {
    // Performance: Only clear if filters are actually set
    if (selectedCategory.value.isNotEmpty || selectedLanguage.value.isNotEmpty) {
      selectedCategory.value = '';
      selectedLanguage.value = '';
      
      // Show all blogs instantly from cached data (no API call)
      if (_allBlogs.isNotEmpty) {
        _applyClientSideFilter();
        return;
      }
      
      // Only load from API if no cached data exists
      if (_allBlogs.isEmpty) {
        _isDataLoaded = false;
        loadBlogs(refresh: true);
      }
    }
  }

  /// Refresh data - Only refresh if explicitly called (pull to refresh)
  Future<void> refresh() async {
    // Force refresh only when user explicitly pulls to refresh
    _isDataLoaded = false;
    await loadBlogs(refresh: true);
  }

  /// Request to become a blogger
  Future<bool> requestBloggerAccess() async {
    if (userId.value == 0) {
      await _loadUserData();
    }

    if (userId.value == 0) {
      message.value = 'Please login first';
      return false;
    }

    if (userRole.value == 'Blogger') {
      message.value = 'You are already a blogger';
      return false;
    }

    isLoading.value = true;
    message.value = 'Sending request...';

    try {
      await BlogsService.requestBloggerAccess(userId: userId.value);
      message.value = 'Request sent successfully. Admin will review your request.';
      
      // Reload user data to check if role changed
      await _loadUserData();
      
      return true;
    } catch (e) {
      message.value = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      print('Error requesting blogger access: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }
}

