import 'dart:async';
import 'dart:io';
import 'package:fruitsofspirit/services/emojis_service.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:fruitsofspirit/services/blogs_service.dart';
import 'package:fruitsofspirit/services/comments_service.dart';
import 'package:fruitsofspirit/services/hive_cache_service.dart';
import 'package:fruitsofspirit/services/user_storage.dart';
import 'package:fruitsofspirit/services/emojis_service.dart';
import 'package:fruitsofspirit/services/content_moderation_service.dart';
import 'package:fruitsofspirit/services/profile_service.dart';
import 'package:fruitsofspirit/routes/app_pages.dart';

import '../controllers/home_controller.dart';
import '../services/emojis_service.dart';

/// Blogs Controller
/// Manages blogs data and operations
class BlogsController extends GetxController {
  // Observable variables
  var isLoading = false.obs;
  var isDetailsSilentSyncing = false.obs;
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
  var userName = ''.obs;
  var userProfilePhoto = RxnString();
  var userStatus = ''.obs; // User status: Active, Inactive, Pending
  var isBloggerRequestPending = false.obs;

  // Filters
  var selectedCategory = ''.obs;
  var selectedLanguage = ''.obs;
  var filterUserId = 0.obs; // Filter by specific user ID (0 = all users)
  var currentPage = 0.obs;
  var hasMore = true.obs;
  static const int itemsPerPage = 20;
  
  // Performance: Store all blogs for instant client-side filtering
  var _allBlogs = <Map<String, dynamic>>[];
  
  // Performance: Track if data is already loaded to prevent unnecessary reloads
  var _isDataLoaded = false;
  var _isLoading = false;
  int _loadGeneration = 0;
  int _detailsLoadGeneration = 0;
  DateTime? _lastSyncedAt;
  final Map<int, DateTime> _detailsSyncedAtByBlogId = {};
  static const Duration _minSyncInterval = Duration(minutes: 2);
  static const Duration _detailsMinSyncInterval = Duration(minutes: 2);
  static const String _blogsListHiveKey = 'blogs_list';
  int? preparedDetailBlogId;
  Completer<void>? _activeLoadCompleter;
  final Set<int> _deletedCommentIds = {};

  @override
  void onInit() {
    super.onInit();
    _loadUserData();
    bootstrapBlogs();
  }

  @override
  void onReady() {
    super.onReady();
    if (_allBlogs.isNotEmpty) {
      _applyClientSideFilter();
      unawaited(loadBlogs(refresh: true, silent: true));
      return;
    }

    if (filterUserId.value == 0 && !_isLoading) {
      unawaited(loadBlogs(refresh: false));
    }
  }

  /// Hive → home seed → instant list (feeling pattern).
  void bootstrapBlogs() {
    loadFromHiveIfEmpty();
    if (_allBlogs.isNotEmpty) return;

    try {
      if (Get.isRegistered<HomeController>()) {
        seedFromHomeIfEmpty(Get.find<HomeController>().blogs.toList());
      }
    } catch (_) {}
  }

  /// Load user data from storage
  Future<void> _loadUserData() async {
    final user = await UserStorage.getUser();
    if (user != null) {
      final id = user['id'];
      final parsed = id is int ? id : int.tryParse(id?.toString() ?? '');
      if (parsed != null && parsed > 0) {
        userId.value = parsed;
      }
      userRole.value = user['role'] as String? ?? 'User';
      userName.value = user['name'] as String? ?? '';
      userProfilePhoto.value = user['profile_photo'] as String?;
      userStatus.value = user['status'] as String? ?? 'Active';
      // Also update isBloggerRequestPending from local storage data
      isBloggerRequestPending.value = userRole.value == 'Blogger' && 
                                      (userStatus.value == 'Inactive' || userStatus.value == 'Pending');
    }
  }

  /// Refresh user data from server to get latest role and status
  Future<void> refreshUserData() async {
    if (userId.value == 0) {
      await _loadUserData();
    }

    if (userId.value == 0) {
      return;
    }

    try {
      // First, get locally stored user data (which might contain PendingBlogger status)
      final localUserData = await UserStorage.getUser();

      // Get fresh profile data from server
      final serverProfileData = await ProfileService.getProfile(userId.value);

      // Merge local data with server data, prioritizing server data unless local is PendingBlogger
      Map<String, dynamic> mergedUserData = {};
      if (localUserData != null) {
        mergedUserData.addAll(localUserData);
      }
      if (serverProfileData != null) {
        mergedUserData.addAll(serverProfileData);
      }

      // If local role was PendingBlogger and server hasn't explicitly changed it, keep local
      if (localUserData?['role'] == 'PendingBlogger' && serverProfileData?['role'] != 'Blogger' && serverProfileData?['role'] != 'User') {
        mergedUserData['role'] = 'PendingBlogger';
        mergedUserData['status'] = 'Pending';
      }

      // Update local storage with the merged data
      await UserStorage.updateUser(mergedUserData);

      // Update observable values for UI
      userRole.value = mergedUserData['role'] as String? ?? 'User';
      userStatus.value = mergedUserData['status'] as String? ?? 'Active';

      // Update isBloggerRequestPending based on current role and status
      isBloggerRequestPending.value = (userRole.value == 'Blogger' &&
                                      (userStatus.value == 'Inactive' || userStatus.value == 'Pending')) ||
                                      userRole.value == 'PendingBlogger';

      // print('✅ User data refreshed: Role=${userRole.value}, Status=${userStatus.value}, IsBloggerRequestPending=${isBloggerRequestPending.value}');
    } catch (e) {
      print('⚠️ Failed to refresh user data: $e');
      // Fall back to local storage if server call fails
      await _loadUserData();
    }
  }

  /// Load blogs — same cache-first / silent-sync pattern as prayers.
  Future<void> loadBlogs({
    bool refresh = false,
    bool silent = false,
    bool paginate = false,
  }) async {
    if (filterUserId.value > 0) {
      refresh = true;
    }

    if (_isLoading) {
      if (_activeLoadCompleter != null) {
        await _activeLoadCompleter!.future;
      }
      if (_allBlogs.isNotEmpty) {
        _applyClientSideFilter();
      }
      return;
    }

    if (!paginate && _isDataLoaded && !refresh && _allBlogs.isNotEmpty) {
      _applyClientSideFilter();
      return;
    }

    if (silent &&
        _lastSyncedAt != null &&
        DateTime.now().difference(_lastSyncedAt!) < _minSyncInterval) {
      if (_allBlogs.isNotEmpty) {
        _applyClientSideFilter();
      }
      return;
    }

    final generation = silent ? _loadGeneration : ++_loadGeneration;
    _activeLoadCompleter = Completer<void>();

    if (refresh) {
      currentPage.value = 0;
      _isDataLoaded = false;
      hasMore.value = true;
    }

    _isLoading = true;
    if (!silent) {
      isLoading.value = true;
    }
    message.value = '';

    try {
      if (userId.value == 0) {
        await _loadUserData();
      }

      String statusFilter;
      if (filterUserId.value > 0) {
        statusFilter = 'Pending,Approved';
      } else if (userId.value > 0 && (userRole.value == 'Admin' || userRole.value == 'admin')) {
        statusFilter = 'Pending,Approved,Rejected,Inactive';
      } else if (userId.value > 0 && (userRole.value == 'PendingBlogger' || isBloggerRequestPending.value)) {
        statusFilter = 'Pending,Approved';
      } else {
        statusFilter = 'Approved';
      }

      final blogsList = await BlogsService.getBlogs(
        status: statusFilter,
        language: null,
        userId: filterUserId.value > 0 ? filterUserId.value : null,
        currentUserId: userId.value > 0 ? userId.value : null,
        limit: itemsPerPage,
        offset: currentPage.value * itemsPerPage,
      );

      if (generation != _loadGeneration) {
        return;
      }

      if (!silent && generation != _loadGeneration) {
        return;
      }

      if (refresh || currentPage.value == 0) {
        if (_allBlogs.isEmpty) {
          _allBlogs = List<Map<String, dynamic>>.from(blogsList);
          _applyClientSideFilter();
        } else if (silent) {
          _mergeBlogListPage(blogsList);
        } else {
          final hasChanged = !_blogListsEqual(_allBlogs, blogsList);
          if (hasChanged) {
            _allBlogs = List<Map<String, dynamic>>.from(blogsList);
            _applyClientSideFilter();
          }
        }
      } else {
        final existingIds = _allBlogs.map(_blogIdFromMap).toSet();
        for (final blog in blogsList) {
          final id = _blogIdFromMap(blog);
          if (id != null && !existingIds.contains(id)) {
            _allBlogs.add(blog);
          }
        }
        _applyClientSideFilter();
      }

      hasMore.value = blogsList.length >= itemsPerPage;
      _isDataLoaded = true;
      _lastSyncedAt = DateTime.now();
      unawaited(_cacheBlogsList());
    } catch (e) {
      if (!silent) {
        message.value = 'Error loading blogs: ${e.toString().replaceAll('Exception: ', '')}';
      }
      print('❌ [BlogsController] Error loading blogs: $e');
      if (!silent && (refresh || currentPage.value == 0) && _allBlogs.isEmpty) {
        blogs.value = [];
        _isDataLoaded = false;
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

  bool _blogListsEqual(
    List<Map<String, dynamic>> previous,
    List<Map<String, dynamic>> next,
  ) {
    if (identical(previous, next)) return true;
    if (previous.length != next.length) return false;

    for (var i = 0; i < previous.length; i++) {
      if (!_blogItemEqual(previous[i], next[i])) return false;
    }
    return true;
  }

  bool _blogItemEqual(
    Map<String, dynamic> previous,
    Map<String, dynamic> next,
  ) {
    return previous['id'] == next['id'] &&
        previous['updated_at'] == next['updated_at'] &&
        previous['like_count'] == next['like_count'] &&
        previous['comment_count'] == next['comment_count'] &&
        previous['status'] == next['status'] &&
        previous['title'] == next['title'] &&
        previous['image'] == next['image'] &&
        previous['image_url'] == next['image_url'];
  }

  void _mergeBlogListPage(List<Map<String, dynamic>> incoming) {
    if (incoming.isEmpty) return;

    if (_allBlogs.isEmpty) {
      _allBlogs = List<Map<String, dynamic>>.from(incoming);
      _applyClientSideFilter();
      return;
    }

    final indexById = <int, int>{};
    for (var i = 0; i < _allBlogs.length; i++) {
      final id = _blogIdFromMap(_allBlogs[i]);
      if (id != null) indexById[id] = i;
    }

    var changed = false;
    for (final remote in incoming) {
      final id = _blogIdFromMap(remote);
      if (id == null) continue;

      final idx = indexById[id];
      if (idx != null) {
        if (!_blogItemEqual(_allBlogs[idx], remote)) {
          _allBlogs[idx] = {..._allBlogs[idx], ...remote};
          changed = true;
        }
      } else if (currentPage.value == 0) {
        _allBlogs.insert(0, Map<String, dynamic>.from(remote));
        changed = true;
      }
    }

    if (changed) {
      _applyClientSideFilter();
    }
  }

  /// Load more blogs (pagination)
  Future<void> loadMore() async {
    if (_isLoading || !hasMore.value) return;

    currentPage.value++;
    await loadBlogs(paginate: true);
  }

  int? _blogIdFromMap(Map<String, dynamic> blog) {
    final id = blog['id'];
    if (id is int) return id;
    return int.tryParse(id?.toString() ?? '');
  }

  String _blogDetailHiveKey(int blogId) => 'blog_detail_$blogId';

  void seedFromHomeIfEmpty(List<Map<String, dynamic>> homeBlogs) {
    if (_allBlogs.isNotEmpty || homeBlogs.isEmpty) return;
    _allBlogs = List<Map<String, dynamic>>.from(homeBlogs);
    _isDataLoaded = true;
    _applyClientSideFilter();
  }

  void loadFromHiveIfEmpty() {
    if (_allBlogs.isNotEmpty) return;
    final cached = HiveCacheService.getCachedList(_blogsListHiveKey);
    if (cached.isNotEmpty) {
      _allBlogs = List<Map<String, dynamic>>.from(cached);
      _isDataLoaded = true;
      _applyClientSideFilter();
      return;
    }
    final homeCached = HiveCacheService.getCachedList('home_blogs');
    if (homeCached.isNotEmpty) {
      seedFromHomeIfEmpty(homeCached);
    }
  }

  Future<void> _cacheBlogsList() async {
    if (_allBlogs.isEmpty) return;
    final snapshot = List<Map<String, dynamic>>.from(_allBlogs);
    await HiveCacheService.cacheList(
      _blogsListHiveKey,
      snapshot,
      expiryHours: 24,
    );
    final homeSlice = snapshot.take(5).toList();
    if (homeSlice.isNotEmpty) {
      await HiveCacheService.cacheList(
        'home_blogs',
        homeSlice,
        expiryHours: 24,
      );
    }
  }

  void _invalidateBlogDetailSync(int blogId) {
    _detailsSyncedAtByBlogId.remove(blogId);
  }

  void bootstrapBlogDetail(int blogId) {
    if (blogId <= 0) return;

    final currentId = _blogIdFromMap(selectedBlog);
    if (currentId != null && currentId != blogId) {
      blogComments.clear();
      blogEmojiReactions.clear();
    }

    loadBlogDetailFromHive(blogId);
    if (_blogIdFromMap(selectedBlog) != blogId || selectedBlog.isEmpty) {
      seedBlogDetailFromList(blogId);
    }
    preparedDetailBlogId = blogId;
  }

  void seedBlogDetailFromList(int blogId) {
    if (_blogIdFromMap(selectedBlog) == blogId && selectedBlog.isNotEmpty) {
      return;
    }

    Map<String, dynamic>? found;
    for (final blog in _allBlogs) {
      if (_blogIdFromMap(blog) == blogId) {
        found = blog;
        break;
      }
    }
    if (found == null) {
      for (final blog in blogs) {
        if (_blogIdFromMap(blog) == blogId) {
          found = blog;
          break;
        }
      }
    }

    if (found != null) {
      selectedBlog.value = Map<String, dynamic>.from(found);
    }
  }

  void loadBlogDetailFromHive(int blogId) {
    final cached = HiveCacheService.getCachedData(_blogDetailHiveKey(blogId));
    if (cached is! Map) return;

    if (cached['blog'] is Map) {
      selectedBlog.value =
          Map<String, dynamic>.from(cached['blog'] as Map<String, dynamic>);
    }
    if (cached['comments'] is List) {
      final comments = (cached['comments'] as List)
          .whereType<Map>()
          .map((c) => Map<String, dynamic>.from(c))
          .toList();
      if (comments.isNotEmpty) {
        blogComments.value = comments;
      }
    }
    if (cached['emoji_reactions'] is Map) {
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
        blogEmojiReactions.value = reactions;
      }
    }
  }

  Future<void> _cacheBlogDetail(int blogId) async {
    if (selectedBlog.isEmpty) return;
    await HiveCacheService.cacheData(
      _blogDetailHiveKey(blogId),
      {
        'blog': Map<String, dynamic>.from(selectedBlog),
        'comments': blogComments
            .map((c) => Map<String, dynamic>.from(c))
            .toList(),
        'emoji_reactions': blogEmojiReactions.map(
          (key, value) => MapEntry(
            key,
            value.map((e) => Map<String, dynamic>.from(e)).toList(),
          ),
        ),
        'cached_at': DateTime.now().millisecondsSinceEpoch,
      },
      expiryHours: 24,
    );
  }

  bool _blogDetailNeedsUpdate(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) {
    const keys = [
      'updated_at',
      'like_count',
      'comment_count',
      'title',
      'body',
      'content',
      'image',
      'image_url',
      'cover_image',
      'status',
      'category',
    ];
    for (final key in keys) {
      if (local[key] != remote[key]) return true;
    }
    return false;
  }

  void _mergeBlogFields(Map<String, dynamic> remote) {
    var changed = false;
    for (final entry in remote.entries) {
      if (selectedBlog[entry.key] != entry.value) {
        selectedBlog[entry.key] = entry.value;
        changed = true;
      }
    }
    if (changed) {
      selectedBlog.refresh();
    }
  }

  String _commentsFingerprint(List<Map<String, dynamic>> comments) {
    final ids = <int>[];
    void walk(List<Map<String, dynamic>> list) {
      for (final comment in list) {
        ids.add(_commentId(comment));
        final replies = comment['replies'];
        if (replies is List) {
          walk(
            replies
                .whereType<Map>()
                .map((r) => Map<String, dynamic>.from(r))
                .toList(),
          );
        }
      }
    }

    walk(comments);
    ids.sort();
    return ids.join(',');
  }

  Future<void> prepareBlogDetails(int blogId) async {
    if (blogId <= 0) return;

    bootstrapBlogDetail(blogId);

    final hasPreview =
        _blogIdFromMap(selectedBlog) == blogId && selectedBlog.isNotEmpty;
    if (!hasPreview) {
      await loadBlogDetails(blogId, silent: false);
    } else {
      unawaited(loadBlogDetails(blogId, silent: true));
    }
  }

  Future<void> loadBlogDetails(
    int blogId, {
    bool silent = false,
    bool force = false,
  }) async {
    if (silent && !force) {
      final lastSync = _detailsSyncedAtByBlogId[blogId];
      if (lastSync != null &&
          DateTime.now().difference(lastSync) < _detailsMinSyncInterval) {
        return;
      }
    }

    final generation = silent ? _detailsLoadGeneration : ++_detailsLoadGeneration;
    final hadPreview =
        _blogIdFromMap(selectedBlog) == blogId && selectedBlog.isNotEmpty;

    if (!silent && !hadPreview) {
      isLoading.value = true;
    }
    message.value = '';

    try {
      if (userId.value == 0) {
        await _loadUserData();
      }

      final blog = await BlogsService.getBlogDetails(
        blogId,
        currentUserId: userId.value > 0 ? userId.value : null,
      );

      if (generation != _detailsLoadGeneration) {
        return;
      }

      if (silent &&
          hadPreview &&
          !force &&
          !_blogDetailNeedsUpdate(selectedBlog, blog)) {
        _detailsSyncedAtByBlogId[blogId] = DateTime.now();
        return;
      }

      if (silent && hadPreview) {
        _mergeBlogFields(blog);
      } else {
        selectedBlog.value = blog;
      }

      final tasks = <Future<void>>[];
      if (availableEmojis.isEmpty) {
        tasks.add(loadAvailableEmojis());
      }
      if (quickEmojis.isEmpty) {
        tasks.add(loadQuickEmojis());
      }

      final remoteCommentCount =
          int.tryParse('${blog['comment_count'] ?? 0}') ?? 0;
      if (force ||
          blogComments.isEmpty ||
          blogComments.length != remoteCommentCount) {
        tasks.add(loadBlogComments(blogId, silent: silent));
      }

      if (tasks.isNotEmpty) {
        await Future.wait(tasks);
      }

      if (generation != _detailsLoadGeneration) {
        return;
      }

      _detailsSyncedAtByBlogId[blogId] = DateTime.now();
      unawaited(_cacheBlogDetail(blogId));
      _syncBlogInLists(blogId);
    } catch (e) {
      if (!silent || !hadPreview) {
        message.value =
            'Error loading blog: ${e.toString().replaceAll('Exception: ', '')}';
      }
      print('Error loading blog details: $e');
    } finally {
      isLoading.value = false;
      isDetailsSilentSyncing.value = false;
    }
  }

  void _syncBlogInLists(int blogId) {
    if (selectedBlog.isEmpty) return;
    final snapshot = Map<String, dynamic>.from(selectedBlog);

    for (var i = 0; i < _allBlogs.length; i++) {
      if (_blogIdFromMap(_allBlogs[i]) == blogId) {
        _allBlogs[i] = {..._allBlogs[i], ...snapshot};
        break;
      }
    }

    for (var i = 0; i < blogs.length; i++) {
      if (_blogIdFromMap(blogs[i]) == blogId) {
        blogs[i] = {...blogs[i], ...snapshot};
        break;
      }
    }
    blogs.refresh();
    unawaited(_cacheBlogsList());
  }

  /// Load blog comments (with emoji reactions parsing)
  Future<void> loadBlogComments(int blogId, {bool silent = false}) async {
    print('⏱️ [BlogsController] Starting loadBlogComments for blogId: $blogId');
    final startTime = DateTime.now();
    
    try {
      final commentsFetchStartTime = DateTime.now();
      final comments = await CommentsService.getComments(
        postType: 'blog',
        postId: blogId,
        userId: userId.value > 0 ? userId.value : null,
      );

      final commentsFetchEndTime = DateTime.now();
      print('⏱️ [BlogsController] CommentsService.getComments took: ${commentsFetchEndTime.difference(commentsFetchStartTime).inMilliseconds}ms');
      
      
      // Parse emoji reactions from comments (same logic as prayers)
      final emojiParsingStartTime = DateTime.now();
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
        // Strategy 4: Check if it's an image URL - BUT only if it's NOT a full HTTP URL
        // Full HTTP URLs should be treated as text comments (will be rendered as images by buildCommentText)
        else if ((trimmed.contains('uploads/emojis/') || trimmed.contains('emojis/')) &&
                 !trimmed.startsWith('http')) {
          isEmojiReaction = true;
          emojiKey = trimmed;
          print('✅ Found emoji reaction (relative image path): $emojiKey');
        }
        
        // FIX: Add ALL top-level comments to textComments (including emoji comments)
        // Emoji reactions and emoji comments are both stored in comments table
        // The UI (FruitEmojiHelper.buildCommentText) will render emoji URLs as images
        final parentId = _normalizeParentId(comment['parent_comment_id']);
        if (parentId == null) {
          if (_isCommentDeleted(comment)) continue;
          textComments.add(_filterDeletedFromTree(comment));
          print('✅ Added to blogComments: id=${comment['id']}, isEmoji=$isEmojiReaction, content="${trimmed.substring(0, trimmed.length > 30 ? 30 : trimmed.length)}..."');
          
          // Also track emoji reactions separately for the reactions bar (if it's an emoji)
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
            print('✅ Also added to emojiReactions: $emojiKey by ${comment['user_name']}');
          }
        }
      }
      final emojiParsingEndTime = DateTime.now();
      print('⏱️ [BlogsController] Emoji parsing took: ${emojiParsingEndTime.difference(emojiParsingStartTime).inMilliseconds}ms');

      final newFingerprint = _commentsFingerprint(textComments);
      final currentFingerprint = _commentsFingerprint(blogComments);
      if (silent &&
          blogComments.isNotEmpty &&
          newFingerprint == currentFingerprint) {
        return;
      }

      blogComments.value = textComments;
      blogEmojiReactions.value = emojiReactions;
      _deletedCommentIds.removeWhere((id) => !_commentExistsInList(textComments, id));
      print('✅ Loaded ${textComments.length} total comments (including ${emojiReactions.length} emoji types)');
    } catch (e) {
      print('❌ Error loading blog comments: $e');
      blogComments.value = [];
      blogEmojiReactions.value = <String, List<Map<String, dynamic>>>{};
    } finally {
      final endTime = DateTime.now();
      print('⏱️ [BlogsController] loadBlogComments finished in: ${endTime.difference(startTime).inMilliseconds}ms');
    }
  }
  
  bool _isCommentDeleted(Map<String, dynamic> comment) {
    final id = _commentId(comment);
    if (_deletedCommentIds.contains(id)) return true;
    final deleted = comment['is_deleted'];
    return deleted == 1 || deleted == true || deleted == '1';
  }

  bool _commentExistsInList(List<Map<String, dynamic>> comments, int commentId) {
    for (final comment in comments) {
      if (_commentId(comment) == commentId) return true;
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

  int _commentId(Map<String, dynamic> comment) {
    final id = comment['id'];
    if (id is int) return id;
    if (id is String) return int.tryParse(id) ?? 0;
    return 0;
  }

  int? _normalizeParentId(dynamic parentId) {
    if (parentId == null || parentId == '' || parentId == false) return null;
    if (parentId is int) return parentId == 0 ? null : parentId;
    if (parentId is String) {
      final parsed = int.tryParse(parentId);
      return parsed == null || parsed == 0 ? null : parsed;
    }
    return null;
  }

  Map<String, dynamic> _stripCommentFromTree(
    Map<String, dynamic> comment,
    int targetId,
  ) {
    final copy = Map<String, dynamic>.from(comment);
    final replies = copy['replies'];
    if (replies is List && replies.isNotEmpty) {
      final filtered = replies
          .whereType<Map>()
          .map((r) => Map<String, dynamic>.from(r))
          .where((r) => _commentId(r) != targetId)
          .map((r) => _stripCommentFromTree(r, targetId))
          .toList();
      copy['replies'] = filtered;
      copy['reply_count'] = filtered.length;
    }
    return copy;
  }

  void _removeCommentLocally(int commentId) {
    final updated = <Map<String, dynamic>>[];
    for (final comment in blogComments) {
      if (_commentId(comment) == commentId) continue;
      updated.add(_stripCommentFromTree(comment, commentId));
    }
    blogComments.value = updated;
  }

  void _insertCommentLocally({
    required String content,
    required int tempId,
    String? userName,
    String? profilePhoto,
    int? parentCommentId,
  }) {
    final comment = <String, dynamic>{
      'id': tempId,
      'comment': content,
      'content': content,
      'user_id': userId.value,
      'user_name': userName ?? 'You',
      'profile_photo': profilePhoto,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'parent_comment_id': parentCommentId ?? 0,
      'replies': <Map<String, dynamic>>[],
      'reply_count': 0,
      'like_count': 0,
      'is_liked': 0,
    };

    if (parentCommentId != null && parentCommentId > 0) {
      final updated = <Map<String, dynamic>>[];
      for (final existing in blogComments) {
        if (_commentId(existing) == parentCommentId) {
          final parent = Map<String, dynamic>.from(existing);
          final replies = List<Map<String, dynamic>>.from(
            (parent['replies'] as List?)
                    ?.whereType<Map>()
                    .map((r) => Map<String, dynamic>.from(r)) ??
                [],
          );
          replies.add(comment);
          parent['replies'] = replies;
          parent['reply_count'] = replies.length;
          updated.add(parent);
        } else {
          updated.add(existing);
        }
      }
      blogComments.value = updated;
      return;
    }

    blogComments.add(comment);
  }

  void _replaceTempCommentId(int tempId, int realId) {
    final updated = <Map<String, dynamic>>[];
    for (final comment in blogComments) {
      final copy = Map<String, dynamic>.from(comment);
      if (_commentId(copy) == tempId) {
        copy['id'] = realId;
      }
      final replies = copy['replies'];
      if (replies is List && replies.isNotEmpty) {
        copy['replies'] = replies
            .whereType<Map>()
            .map((r) {
              final reply = Map<String, dynamic>.from(r);
              if (_commentId(reply) == tempId) {
                reply['id'] = realId;
              }
              return reply;
            })
            .toList();
      }
      updated.add(copy);
    }
    blogComments.value = updated;
  }

  Future<void> _deleteCommentOnServer(int blogId, int commentId) async {
    try {
      await CommentsService.deleteComment(
        userId: userId.value,
        commentId: commentId,
        postType: 'blog',
      );
    } catch (e) {
      _deletedCommentIds.remove(commentId);
      message.value = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      unawaited(loadBlogComments(blogId));
    }
  }

  void _removeBlogLocally(int blogId) {
    _allBlogs.removeWhere((b) => _blogIdFromMap(b) == blogId);
    blogs.removeWhere((b) => _blogIdFromMap(b) == blogId);
    blogs.refresh();
    if (_blogIdFromMap(selectedBlog) == blogId) {
      selectedBlog.clear();
    }
    unawaited(HiveCacheService.clearKey(_blogDetailHiveKey(blogId)));
    unawaited(_cacheBlogsList());
    _syncHomeBlogsAfterDelete(blogId);
  }

  void _syncHomeBlogsAfterDelete(int blogId) {
    if (!Get.isRegistered<HomeController>()) return;
    try {
      final home = Get.find<HomeController>();
      home.blogs.removeWhere((b) => _blogIdFromMap(b) == blogId);
      home.blogs.refresh();
      unawaited(
        HiveCacheService.cacheList(
          'home_blogs',
          List<Map<String, dynamic>>.from(home.blogs),
          expiryHours: 24,
        ),
      );
    } catch (_) {}
  }

  Future<void> _deleteBlogOnServer(int blogId) async {
    try {
      await BlogsService.deleteBlog(
        userId: userId.value,
        blogId: blogId,
      );
      unawaited(loadBlogs(refresh: true, silent: true));
    } catch (e) {
      message.value = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      unawaited(loadBlogs(refresh: true, silent: true));
    }
  }

  /// Delete blog — remove locally first, sync server in background.
  Future<bool> deleteBlog(int blogId) async {
    if (userId.value == 0) {
      await _loadUserData();
    }
    if (userId.value == 0) {
      message.value = 'Please login first';
      return false;
    }
    if (blogId <= 0) return false;

    _removeBlogLocally(blogId);
    unawaited(_deleteBlogOnServer(blogId));
    return true;
  }

  Future<bool> deleteBlogComment(int blogId, int commentId) async {
    if (userId.value == 0) {
      await _loadUserData();
    }
    if (userId.value == 0) {
      message.value = 'Please login first';
      return false;
    }
    if (commentId <= 0) return false;

    _deletedCommentIds.add(commentId);
    _removeCommentLocally(commentId);
    blogComments.refresh();
    unawaited(_deleteCommentOnServer(blogId, commentId));
    return true;
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
    if (availableEmojis.isNotEmpty) return;
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
    if (quickEmojis.isNotEmpty) return;
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
      unawaited(loadBlogComments(blogId));
      return true;
    } catch (e) {
      message.value = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      print('Error toggling emoji reaction: $e');
      return false;
    }
  }

  void _insertCreatedBlogLocally({
    required int id,
    required String title,
    required String body,
    required String category,
    required String language,
    String? userName,
    String? profilePhoto,
  }) {
    final blog = <String, dynamic>{
      'id': id,
      'title': title,
      'body': body,
      'category': category,
      'language': language,
      'status': 'Pending',
      'user_id': userId.value,
      'user_name': userName ?? 'You',
      'user_role': userRole.value,
      'profile_photo': profilePhoto,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'like_count': 0,
      'comment_count': 0,
    };
    _allBlogs.removeWhere((b) => _blogIdFromMap(b) == id);
    _allBlogs.insert(0, blog);
    _isDataLoaded = true;
    _applyClientSideFilter();
    unawaited(_cacheBlogsList());
  }

  /// Create blog (Bloggers only)
  Future<bool> createBlog({
    required String title,
    required String body,
    required String category,
    String language = 'en',
    File? media,
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

    // Check for inappropriate content
    if (title.isNotEmpty) {
      final titleCheck = ContentModerationService.checkContent(title);
      if (!titleCheck['isClean']) {
        message.value = 'Title: ${titleCheck['message']}';
        _showModerationSnackbar(titleCheck['message']);
        return false;
      }
    }

    if (body.isNotEmpty) {
      final bodyCheck = ContentModerationService.checkContent(body);
      if (!bodyCheck['isClean']) {
        message.value = 'Body: ${bodyCheck['message']}';
        _showModerationSnackbar(bodyCheck['message']);
        return false;
      }
    }

    message.value = '';

    try {
      final newId = await BlogsService.createBlog(
        userId: userId.value,
        title: title,
        body: body,
        category: category,
        language: language,
        media: media,
      );

      _insertCreatedBlogLocally(
        id: newId,
        title: title,
        body: body,
        category: category,
        language: language,
        userName: userName.value.isNotEmpty ? userName.value : null,
        profilePhoto: userProfilePhoto.value,
      );

      message.value = 'Blog created successfully. Waiting for admin approval.';
      unawaited(loadBlogs(refresh: true, silent: true));
      return true;
    } catch (e) {
      message.value = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      print('Error creating blog: $e');
      return false;
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

    // Check for inappropriate content in comment
    final moderationCheck = ContentModerationService.checkContent(content);
    if (!moderationCheck['isClean']) {
      message.value = moderationCheck['message'];
      _showModerationSnackbar(moderationCheck['message']);
      return false;
    }

    final tempId = -DateTime.now().millisecondsSinceEpoch;
    final user = await UserStorage.getUser();
    _insertCommentLocally(
      content: content,
      tempId: tempId,
      userName: user?['name'] as String?,
      profilePhoto: user?['profile_photo'] as String?,
      parentCommentId: parentCommentId,
    );
    blogComments.refresh();
    unawaited(
      _submitCommentToServer(
        blogId: blogId,
        content: content,
        parentCommentId: parentCommentId,
        tempId: tempId,
      ),
    );
    return true;
  }

  Future<void> _submitCommentToServer({
    required int blogId,
    required String content,
    required int tempId,
    int? parentCommentId,
  }) async {
    try {
      final commentId = await CommentsService.addComment(
        userId: userId.value,
        postType: 'blog',
        postId: blogId,
        content: content,
        parentCommentId: parentCommentId,
      );
      if (commentId > 0) {
        _replaceTempCommentId(tempId, commentId);
        blogComments.refresh();
      }
      _invalidateBlogDetailSync(blogId);
      unawaited(loadBlogComments(blogId));
    } catch (e) {
      _removeCommentLocally(tempId);
      blogComments.refresh();
      message.value = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
    }
  }

  Future<bool> toggleCommentLike(int commentId) async {
    if (userId.value == 0) {
      await _loadUserData();
    }

    if (userId.value == 0) {
      message.value = 'Please login first';
      return false;
    }

    try {
      final result = await CommentsService.toggleCommentLike(
        userId: userId.value,
        commentId: commentId,
      );

      for (var i = 0; i < blogComments.length; i++) {
        if (_commentId(blogComments[i]) == commentId) {
          blogComments[i]['is_liked'] = result['liked'] == true ? 1 : 0;
          blogComments[i]['like_count'] = result['like_count'] ?? 0;
          blogComments.refresh();
          return true;
        }
      }

      for (var i = 0; i < blogComments.length; i++) {
        final comment = blogComments[i];
        final replies = comment['replies'];
        if (replies is! List) continue;
        final updatedReplies = List<Map<String, dynamic>>.from(
          replies.whereType<Map>().map((r) => Map<String, dynamic>.from(r)),
        );
        var changed = false;
        for (var j = 0; j < updatedReplies.length; j++) {
          if (_commentId(updatedReplies[j]) == commentId) {
            updatedReplies[j]['is_liked'] = result['liked'] == true ? 1 : 0;
            updatedReplies[j]['like_count'] = result['like_count'] ?? 0;
            changed = true;
            break;
          }
        }
        if (changed) {
          blogComments[i] = Map<String, dynamic>.from(comment)
            ..['replies'] = updatedReplies;
          blogComments.refresh();
          return true;
        }
      }

      return true;
    } catch (e) {
      message.value = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      print('Error toggling comment like: $e');
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
      final wasLiked = selectedBlog['is_liked'] == true ||
          selectedBlog['is_liked'] == 1;
      final currentCount =
          int.tryParse((selectedBlog['like_count'] ?? 0).toString()) ?? 0;

      final liked = await CommentsService.toggleBlogLike(
        userId: userId.value,
        blogId: blogId,
      );

      if (_blogIdFromMap(selectedBlog) == blogId) {
        selectedBlog['is_liked'] = liked ? 1 : 0;
        if (liked && !wasLiked) {
          selectedBlog['like_count'] = currentCount + 1;
        } else if (!liked && wasLiked && currentCount > 0) {
          selectedBlog['like_count'] = currentCount - 1;
        }
        selectedBlog.refresh();
      }

      _syncBlogInLists(blogId);
      unawaited(_cacheBlogDetail(blogId));
      unawaited(_cacheBlogsList());
      return liked;
    } catch (e) {
      message.value = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      print('Error toggling like: $e');
      return false;
    }
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

    isLoading.value = true;
    message.value = '';

    try {
      final success = await BlogsService.requestBloggerAccess(userId: userId.value);
      if (success) {
          message.value = 'Your blogger request has been sent. Admin will review your request.';
          isBloggerRequestPending.value = true; // Set to true on successful request

          // Locally update user role and status to reflect pending request
          userRole.value = 'PendingBlogger';
          userStatus.value = 'Pending';

          // Persist this updated state to UserStorage
          await UserStorage.updateUser({'role': 'PendingBlogger', 'status': 'Pending'});

          // No immediate refreshUserData() call here to avoid resetting state prematurely
          // The onInit() will handle server refresh on next page load
        } else {
        message.value = 'Failed to send blogger request. Please try again.';
      }
      return success;
    } catch (e) {
      message.value = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      print('Error requesting blogger access: $e');
      return false;
    } finally {
      isLoading.value = false;
      // isBloggerRequestPending.value = false; // This should be handled by refreshUserData
    }
  }

  /// Set initial data from cache
  void setInitialData(List<Map<String, dynamic>> data) {
    if (data.isNotEmpty) {
      print('📦 [BlogsController] Loading from CACHED blogs:');
      print('📦 Total cached blogs: ${data.length}');
      
      // Count blogs by role
      int adminCount = 0;
      int bloggerCount = 0;
      int userCount = 0;
      int otherCount = 0;
      int noRoleCount = 0;
      
      for (int i = 0; i < data.length; i++) {
        final blog = data[i];
        final role = blog['user_role'] ?? 'NO ROLE FIELD';
        final name = blog['user_name'] ?? 'Anonymous';
        final title = blog['title'] ?? 'No Title';
        final status = blog['status'] ?? 'Unknown';
        
        print('📦 Cached Blog #${i+1}:');
        print('   - Title: $title');
        print('   - Author: $name');
        print('   - Role: $role');
        print('   - Status: $status');
        
        // Count by role
        if (role == 'Admin' || role == 'admin') {
          adminCount++;
        } else if (role == 'Blogger') {
          bloggerCount++;
        } else if (role == 'User') {
          userCount++;
        } else if (role == 'NO ROLE FIELD') {
          noRoleCount++;
        } else {
          otherCount++;
        }
      }
      
      print('📦 [BlogsController] === CACHED ROLE WISE COUNT ===');
      print('📦 Admin Blogs: $adminCount');
      print('📦 Blogger Blogs: $bloggerCount');
      print('📦 User Blogs: $userCount');
      print('📦 No Role Field (old cache): $noRoleCount');
      print('📦 Other/Unknown: $otherCount');
      print('📦 [BlogsController] ==============================');
      
      _allBlogs = List<Map<String, dynamic>>.from(data);
      _isDataLoaded = true;
      _applyClientSideFilter();
    }
  }

  /// Re-apply current filters instantly (no API).
  void reapplyFilter() {
    _applyClientSideFilter();
  }

  /// Apply client-side filter instantly (no API call)
  void _applyClientSideFilter() {
    if (_allBlogs.isEmpty) return;
    
    var filtered = List<Map<String, dynamic>>.from(_allBlogs);

    filtered = filtered.where((blog) {
      final status = (blog['status'] as String? ?? 'Approved').toLowerCase();
      return status != 'deleted';
    }).toList();
    
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
    
    // Filter by user (pending blogger profile view)
    if (filterUserId.value > 0) {
      filtered = filtered.where((blog) {
        final uid = blog['user_id'];
        return uid != null && uid.toString() == filterUserId.value.toString();
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



  
  /// Show moderation snackbar
  void _showModerationSnackbar(String message) {
    final ctx = Get.context;
    if (ctx != null) {
      ScaffoldMessenger.of(ctx).hideCurrentSnackBar();
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.security_rounded, color: Color(0xFFC79211), size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Community Guidelines',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(message, style: const TextStyle(color: Colors.white)),
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

  @override
  void onClose() {
    blogs.clear();
    _allBlogs.clear();
    blogComments.clear();
    blogEmojiReactions.clear();
    _isDataLoaded = false;
    super.onClose();
  }
}
