import 'dart:async';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:fruitsofspirit/services/fruit_service.dart';
import 'package:fruitsofspirit/services/prayers_service.dart';
import 'package:fruitsofspirit/services/blogs_service.dart';
import 'package:fruitsofspirit/services/videos_service.dart';
import 'package:fruitsofspirit/services/gallery_service.dart';
import 'package:fruitsofspirit/services/groups_service.dart';
import 'package:fruitsofspirit/config/group_posts_config.dart';
import 'package:fruitsofspirit/services/group_posts_service.dart';
import 'package:fruitsofspirit/services/emojis_service.dart';
import 'package:fruitsofspirit/services/stories_service.dart';
import 'package:fruitsofspirit/services/shorts_service.dart';
import 'package:fruitsofspirit/services/user_storage.dart';
import 'package:fruitsofspirit/services/api_service.dart';
import 'package:fruitsofspirit/services/image_preload_service.dart';
import 'package:fruitsofspirit/services/data_loading_service.dart';
import 'package:fruitsofspirit/services/hive_cache_service.dart';
import 'package:fruitsofspirit/config/image_config.dart';
import 'package:fruitsofspirit/services/intro_service.dart';
import 'package:fruitsofspirit/services/live_streaming_service.dart';
import 'package:fruitsofspirit/controllers/notifications_controller.dart';

class HomeController extends GetxController {
  // ScrollController for smooth scrolling
  final ScrollController scrollController = ScrollController();

  // Observable variables for UI state
  var isLoading = false.obs;
  var isInitialLoading = true.obs; // New flag for initial load
  var message = ''.obs;

  // Data from database
  var fruit = <Map<String, dynamic>>[].obs;
  var prayers = <Map<String, dynamic>>[].obs;
  var blogs = <Map<String, dynamic>>[].obs;
  var videos = <Map<String, dynamic>>[].obs;
  var liveVideos = <Map<String, dynamic>>[].obs;
  var galleryPhotos = <Map<String, dynamic>>[].obs;
  var stories = <Map<String, dynamic>>[].obs; // Stories from stories table
  var communityShorts = <Map<String, dynamic>>[].obs;
  var myShorts = <Map<String, dynamic>>[].obs;

  /// Home carousel — user ke grace moments pehle, phir community.
  List<Map<String, dynamic>> get graceMomentsForHome {
    final seen = <String>{};
    final merged = <Map<String, dynamic>>[];
    for (final s in myShorts) {
      final id = ShortsService.shortId(s);
      if (id <= 0 || !seen.add('$id')) continue;
      merged.add(s);
    }
    for (final s in communityShorts) {
      final id = ShortsService.shortId(s);
      if (id <= 0 || !seen.add('$id')) continue;
      merged.add(s);
    }
    return merged;
  }
  var groups = <Map<String, dynamic>>[].obs;
  var groupPosts = <Map<String, dynamic>>[].obs;
  var emojis = <Map<String, dynamic>>[].obs; // Main fruits only (for carousel)
  var allEmojis = <Map<String, dynamic>>[].obs; // All emojis (main fruits, opposites, emotions)
  var oppositeEmojis = <Map<String, dynamic>>[].obs; // Opposites only
  var emotionEmojis = <Map<String, dynamic>>[].obs; // Spiritual emotions only
  var userId = 0.obs;
  var userFeeling = Rxn<Map<String, dynamic>>(); // Current user's feeling (null if not recorded)
  var userName = ''.obs; // Current user's name
  
  // Performance: Track if data is already loaded to prevent unnecessary reloads
  var _isDataLoaded = false;
  var _isLoading = false;
  
  // Performance: Track if emojis are already loaded
  var _isEmojisLoaded = false;
  var _isLoadingEmojis = false;

  static const String _userFeelingHiveKey = 'user_feeling';
  static const String _homeBlogsHiveKey = 'home_blogs';
  static const String _homeGroupsHiveKey = 'home_groups';
  static const String _homeGroupPostsHiveKey = 'home_group_posts';
  static const Duration _feelingMinSyncInterval = Duration(minutes: 2);
  static const Duration _blogsMinSyncInterval = Duration(minutes: 2);
  static const Duration _groupsMinSyncInterval = Duration(minutes: 2);
  DateTime? _feelingLastSyncedAt;
  DateTime? _blogsLastSyncedAt;
  DateTime? _groupsLastSyncedAt;
  DateTime? _groupPostsLastSyncedAt;
  DateTime? _videosLastSyncedAt;
  DateTime? _liveVideosLastSyncedAt;
  var _isFeelingSyncing = false;
  var _isBlogsSyncing = false;
  var _isGroupsSyncing = false;
  var _isGroupPostsSyncing = false;
  var _isVideosSyncing = false;
  var _isLiveVideosSyncing = false;
  var _isCommunityShortsSyncing = false;
  DateTime? _communityShortsLastSyncedAt;
  static const Duration _communityShortsMinSyncInterval = Duration(minutes: 2);
  static const Duration _videosMinSyncInterval = Duration(minutes: 2);

  // Intro overlay state
  var showIntroOverlay = false.obs;

  @override
  void onInit() {
    super.onInit();
    _loadUserId();
    _initializeData();
    NotificationsController.warmUnreadCount();
  }

  @override
  void onReady() {
    super.onReady();
    checkIntro(); // Call checkIntro when the controller is ready
  }

  void checkIntro() async {
    // If already showing or already checked in this session, don't do it again
    if (showIntroOverlay.value) return;

    // Wait for a small delay to ensure home screen is rendered
    await Future.delayed(const Duration(milliseconds: 1000));

    // Show intro overlay if not skipped permanently
    if (IntroService.shouldShowIntroOverlay()) {
      print('🎬 Showing Intro Overlay on Home Page');
      showIntroOverlay.value = true;
    } else {
      print('🎬 Intro Overlay skipped (already marked as skip)');
    }
  }

  void closeIntroOverlay() {
    showIntroOverlay.value = false;
  }

  Future<void> _loadUserId() async {
    final id = await UserStorage.getUserId();
    if (id != null) {
      userId.value = id;
      // Load user data to get username
      final userData = await UserStorage.getUser();
      if (userData != null) {
        userName.value = userData['name'] ?? userData['user_name'] ?? '';
      }
      // Load user's latest feeling (cache first, API silent sync)
      unawaited(loadUserFeeling());
    }
  }

  /// Load user feeling — cache/Hive first, then silent API sync (Prayer pattern).
  Future<void> loadUserFeeling({bool silent = false}) async {
    if (userId.value <= 0) {
      final id = await UserStorage.getUserId();
      if (id != null) userId.value = id;
    }
    if (userId.value <= 0) {
      userFeeling.value = null;
      return;
    }

    if (!silent) {
      await _loadFeelingFromCache();
    }

    if (silent &&
        _feelingLastSyncedAt != null &&
        DateTime.now().difference(_feelingLastSyncedAt!) < _feelingMinSyncInterval) {
      return;
    }

    if (_isFeelingSyncing) return;
    _isFeelingSyncing = true;
    try {
      await _syncFeelingFromApi();
    } finally {
      _isFeelingSyncing = false;
    }
  }

  Future<void> _loadFeelingFromCache() async {
    try {
      final hiveFeeling = HiveCacheService.getCachedData(_userFeelingHiveKey);
      if (hiveFeeling is Map) {
        userFeeling.value =
            _enrichFeeling(Map<String, dynamic>.from(hiveFeeling));
        return;
      }
    } catch (_) {}

    final localFeeling = await UserStorage.getUserFeeling();
    if (localFeeling != null) {
      userFeeling.value = _enrichFeeling(localFeeling);
    }
  }

  Future<void> _syncFeelingFromApi() async {
    try {
      final feeling =
          await EmojisService.getUserLatestFeeling(userId: userId.value);
      if (feeling == null) return;

      final enriched = _enrichFeeling(Map<String, dynamic>.from(feeling));
      final current = userFeeling.value;
      if (current != null && _isLocalFeelingNewer(current, enriched)) {
        return;
      }

      userFeeling.value = enriched;
      await _cacheFeeling(enriched);
      _feelingLastSyncedAt = DateTime.now();
    } catch (_) {}
  }

  bool _isLocalFeelingNewer(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) {
    final localAt = local['updated_at'] as String?;
    final remoteAt = remote['updated_at'] as String?;
    if (localAt == null) return false;
    if (remoteAt == null) return true;
    try {
      return DateTime.parse(localAt).isAfter(DateTime.parse(remoteAt));
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic> _enrichFeeling(Map<String, dynamic> feeling) {
    final copy = Map<String, dynamic>.from(feeling);
    final details = copy['emoji_details'];
    if (details is Map && details.isNotEmpty) {
      return copy;
    }

    final emoji = copy['emoji']?.toString() ?? '';
    final found = _findEmojiDetailsForValue(emoji);
    if (found != null) {
      copy['emoji_details'] = Map<String, dynamic>.from(found);
    }
    return copy;
  }

  Map<String, dynamic>? _findEmojiDetailsForValue(
    String emoji, {
    Map<String, dynamic>? hint,
  }) {
    if (hint != null && hint.isNotEmpty) {
      return hint;
    }
    if (emoji.isEmpty) return null;

    final allLists = [
      ...emojis,
      ...allEmojis,
      ...oppositeEmojis,
      ...emotionEmojis,
    ];
    final emojiId = int.tryParse(emoji);

    for (final item in allLists) {
      if (emojiId != null && item['id'] == emojiId) {
        return Map<String, dynamic>.from(item);
      }
      final code = item['code']?.toString() ?? '';
      final emojiChar = item['emoji_char']?.toString() ?? '';
      final imageUrl = item['image_url']?.toString() ?? '';
      final id = item['id']?.toString() ?? '';
      if (emoji == code ||
          emoji == emojiChar ||
          emoji == imageUrl ||
          emoji == id) {
        return Map<String, dynamic>.from(item);
      }
    }
    return null;
  }

  Future<void> _cacheFeeling(Map<String, dynamic> feeling) async {
    await UserStorage.saveUserFeeling(feeling);
    await HiveCacheService.cacheData(
      _userFeelingHiveKey,
      feeling,
      expiryHours: 24,
    );
  }

  /// Optimistic feeling update — UI + cache first, API in background.
  Future<void> updateUserFeeling(
    String emoji, {
    Map<String, dynamic>? emojiData,
  }) async {
    if (userId.value <= 0) {
      final id = await UserStorage.getUserId();
      if (id != null) {
        userId.value = id;
      } else {
        return;
      }
    }

    final emojiDetails = _findEmojiDetailsForValue(emoji, hint: emojiData);
    final now = DateTime.now().toIso8601String();
    final optimistic = <String, dynamic>{
      'emoji': emoji,
      'user_id': userId.value,
      'created_at': now,
      'updated_at': now,
      if (emojiDetails != null)
        'emoji_details': Map<String, dynamic>.from(emojiDetails),
    };

    userFeeling.value = Map<String, dynamic>.from(optimistic);
    unawaited(_cacheFeeling(optimistic));
    unawaited(_postFeelingToServer(emoji));
  }

  Future<void> _postFeelingToServer(String emoji) async {
    try {
      await EmojisService.useEmoji(userId: userId.value, emoji: emoji);
      _feelingLastSyncedAt = DateTime.now();
    } catch (e) {
      print('Feeling API sync failed: $e');
    }
  }

  /// Set initial data from cache or external service
  void setInitialData(Map<String, dynamic> data) {
    if (data.isEmpty) return;

    print('🏠 HomeController: Setting initial data from external source...');

    if (data['fruits'] != null && (data['fruits'] as List).isNotEmpty) {
      fruit.value = List<Map<String, dynamic>>.from(data['fruits']);
    }
    if (data['prayers'] != null && (data['prayers'] as List).isNotEmpty) {
      prayers.value = List<Map<String, dynamic>>.from(data['prayers']);
    }
    if (data['blogs'] != null && (data['blogs'] as List).isNotEmpty) {
      blogs.value = List<Map<String, dynamic>>.from(data['blogs']);
    }
    if (data['videos'] != null && (data['videos'] as List).isNotEmpty) {
      videos.value = List<Map<String, dynamic>>.from(data['videos']);
    }
    if (data['communityShorts'] != null && (data['communityShorts'] as List).isNotEmpty) {
      communityShorts.value = List<Map<String, dynamic>>.from(data['communityShorts']);
    }
    if (data['liveVideos'] != null && (data['liveVideos'] as List).isNotEmpty) {
      liveVideos.value = List<Map<String, dynamic>>.from(data['liveVideos']);
    }
    if (data['galleryPhotos'] != null && (data['galleryPhotos'] as List).isNotEmpty) {
      galleryPhotos.value = List<Map<String, dynamic>>.from(data['galleryPhotos']);
    }
    if (data['stories'] != null && (data['stories'] as List).isNotEmpty) {
      stories.value = List<Map<String, dynamic>>.from(data['stories']);
    }
    if (data['groups'] != null && (data['groups'] as List).isNotEmpty) {
      groups.value = List<Map<String, dynamic>>.from(data['groups']);
    }
    if (data['emojis'] != null && (data['emojis'] as List).isNotEmpty) {
      final emojisList = List<Map<String, dynamic>>.from(data['emojis']);
      
      // Categorize emojis
      final mainFruitList = <Map<String, dynamic>>[];
      final allEmojisList = <Map<String, dynamic>>[];
      final oppositeEmojisList = <Map<String, dynamic>>[];
      final emotionEmojisList = <Map<String, dynamic>>[];
      
      for (var emoji in emojisList) {
        final category = emoji['category'] as String? ?? '';
        final name = (emoji['name'] as String? ?? '').toLowerCase();
        allEmojisList.add(emoji);
        
        final fruitNames = ['goodness', 'joy', 'kindness', 'peace', 'patience', 'faithfulness', 'gentleness', 'meekness', 'self-control', 'self control', 'love'];
        final hasFruitName = fruitNames.any((fruit) => name.contains(fruit));
        
        if (category.toLowerCase().contains('fruit') || category == 'Fruits' || (category.isEmpty && hasFruitName)) {
          mainFruitList.add(emoji);
        } else if (category.toLowerCase().contains('opposite')) {
          oppositeEmojisList.add(emoji);
        } else if (category.toLowerCase().contains('emotion')) {
          emotionEmojisList.add(emoji);
        }
      }
      
      emojis.value = mainFruitList;
      allEmojis.value = allEmojisList;
      oppositeEmojis.value = oppositeEmojisList;
      emotionEmojis.value = emotionEmojisList;
      _isEmojisLoaded = true;
    }

    // Mark data as loaded to prevent redundant loads
    _isDataLoaded = true;

    // If we have some data, we can stop initial loading
    if (_hasAnyHomeCache()) {
      isInitialLoading.value = false;
      print('✅ HomeController: Initial loading finished (data populated via setInitialData)');
    }
    
    // Refresh UI
    fruit.refresh();
    prayers.refresh();
    blogs.refresh();
    communityShorts.refresh();

    unawaited(loadCommunityShorts(silent: communityShorts.isNotEmpty));
  }

  /// Initialize data: load from cache first (instant), then refresh in background
  Future<void> _initializeData() async {
    // If data already loaded externally (e.g. from SplashScreen via setInitialData), skip
    if (_isDataLoaded && _hasAnyHomeCache()) {
      isInitialLoading.value = false;
      print('🏠 HomeController: Data already loaded externally, skipping _initializeData');
      return;
    }

    isInitialLoading.value = true;
    message.value = '';

    try {
      // First, load from cache for INSTANT display (no loading indicator)
      await _loadFromCache();

      // If cache has data, hide loading immediately
      if (_hasAnyHomeCache()) {
        isInitialLoading.value = false;
        print('✅ Data loaded from cache - showing instantly');
        
        // Then load fresh data from API in background (silent update)
        loadHomeData().then((_) {
          print('✅ Background data refresh completed');
        }).catchError((e) {
          print('⚠️ Background refresh error: $e');
          return null;
        });
      } else {
        // If NO cache, we MUST wait for the API to show something
        print('🔄 No cache found, waiting for initial data load...');
        await loadHomeData(showLoading: false);
        isInitialLoading.value = false;
        print('✅ Initial data load completed');
      }
    } catch (e) {
      message.value = 'Error loading data: ${e.toString()}';
      print('Error initializing home data: $e');
      isInitialLoading.value = false;
    }
  }

  /// Load data from cache (Hive - fast and persistent)
  Future<void> _loadFromCache() async {
    try {
      // Use Hive cache for faster access
      final cachedFruit = HiveCacheService.getCachedList('home_fruit');
      final cachedPrayers = HiveCacheService.getCachedList('home_prayers');
      final cachedBlogs = HiveCacheService.getCachedList('home_blogs');
      final cachedVideos = HiveCacheService.getCachedList('home_videos');
      final cachedShorts = HiveCacheService.getCachedList('home_shorts');
      final cachedLiveVideos = HiveCacheService.getCachedList('home_live_videos');
      final cachedGalleryPhotos = HiveCacheService.getCachedList('home_gallery_photos');
      final cachedStories = HiveCacheService.getCachedList('home_stories');
      final cachedGroups = HiveCacheService.getCachedList('home_groups');
      final cachedGroupPosts = HiveCacheService.getCachedList('home_group_posts');
      final cachedEmojis = HiveCacheService.getCachedList('home_emojis');
      
      if (cachedFruit.isNotEmpty) {
        fruit.value = cachedFruit;
      }
      if (cachedPrayers.isNotEmpty) {
        prayers.value = cachedPrayers;
      }
      if (cachedBlogs.isNotEmpty) {
        blogs.value = cachedBlogs;
      }
      if (cachedVideos.isNotEmpty) {
        videos.value = cachedVideos;
      }
      if (cachedShorts.isNotEmpty) {
        communityShorts.value = cachedShorts;
      }
      final cachedMyShorts = HiveCacheService.getCachedList('shorts_my');
      if (cachedMyShorts.isNotEmpty) {
        myShorts.value = List<Map<String, dynamic>>.from(cachedMyShorts);
      }
      if (cachedLiveVideos.isNotEmpty) {
        // Filter cached data to only show live streams (exclude ended)
        final onlyLive = cachedLiveVideos.where((s) {
          final status = (s['status'] ?? '').toString().toLowerCase();
          return status == 'live';
        }).toList();
        liveVideos.value = onlyLive;
      }
      if (cachedGalleryPhotos.isNotEmpty) {
        galleryPhotos.value = cachedGalleryPhotos
            .where((p) {
              final id = p['id'];
              if (id is int && id <= 0) return false;
              final path = p['file_path']?.toString() ?? '';
              return !path.contains('Frame.png') && !path.contains('Vector.png');
            })
            .map((p) => Map<String, dynamic>.from(p))
            .toList();
      }
      if (cachedStories.isNotEmpty) {
        stories.value = cachedStories;
      }
      if (cachedGroups.isNotEmpty) {
        groups.value = cachedGroups;
      }
      if (cachedGroupPosts.isNotEmpty) {
        groupPosts.value = cachedGroupPosts;
      }
      if (cachedEmojis.isNotEmpty) {
        emojis.value = cachedEmojis;
      }
      
      print('✅ Loaded ${fruit.length} fruit, ${prayers.length} prayers, ${blogs.length} blogs from Hive cache');
    } catch (e) {
      print('⚠️ Error loading from Hive cache: $e');
      // Fallback to old cache service
      try {
      final cachedData = await DataLoadingService.getCachedHomeData();
      if (cachedData['fruit']?.isNotEmpty == true) {
        fruit.value = cachedData['fruit'] as List<Map<String, dynamic>>;
      }
      if (cachedData['prayers']?.isNotEmpty == true) {
        prayers.value = cachedData['prayers'] as List<Map<String, dynamic>>;
      }
      if (cachedData['blogs']?.isNotEmpty == true) {
        blogs.value = cachedData['blogs'] as List<Map<String, dynamic>>;
      }
      if (cachedData['videos']?.isNotEmpty == true) {
        videos.value = cachedData['videos'] as List<Map<String, dynamic>>;
      }
      if (cachedData['communityShorts']?.isNotEmpty == true) {
        communityShorts.value = cachedData['communityShorts'] as List<Map<String, dynamic>>;
      }
      if (cachedData['liveVideos']?.isNotEmpty == true) {
        liveVideos.value = cachedData['liveVideos'] as List<Map<String, dynamic>>;
      }
      if (cachedData['galleryPhotos']?.isNotEmpty == true) {
        galleryPhotos.value = cachedData['galleryPhotos'] as List<Map<String, dynamic>>;
      }
      if (cachedData['stories']?.isNotEmpty == true) {
        stories.value = cachedData['stories'] as List<Map<String, dynamic>>;
      }
      if (cachedData['groups']?.isNotEmpty == true) {
        groups.value = cachedData['groups'] as List<Map<String, dynamic>>;
      }
      if (cachedData['emojis']?.isNotEmpty == true) {
        emojis.value = cachedData['emojis'] as List<Map<String, dynamic>>;
      }
        print('✅ Loaded data from fallback cache');
      } catch (e2) {
        print('⚠️ Error loading from fallback cache: $e2');
      }
    }
  }

  /// Load all home page data from database
  Future<void> loadHomeData({bool showLoading = false}) async {
    if (showLoading) {
    isLoading.value = true;
    message.value = 'Refreshing...';
    }

    try {
      await Future.wait([
        loadFruit(),
        loadPrayers(),
        loadBlogs(silent: blogs.isNotEmpty),
        loadVideos(silent: videos.isNotEmpty),
        loadLiveVideos(silent: liveVideos.isNotEmpty),
        loadCommunityShorts(silent: communityShorts.isNotEmpty),
        loadGalleryPhotos(silent: galleryPhotos.isNotEmpty),
        loadStories(),
        loadGroups(silent: groups.isNotEmpty),
        if (GroupPostsConfig.enabled)
          loadGroupPosts(silent: groupPosts.isNotEmpty),
        loadEmojis(),
      ]);


      // Cache the loaded data
      await _cacheAllData();

      if (showLoading) {
      message.value = 'Data loaded successfully!';
      }
      
      // Preload critical images in background (non-blocking)
      _preloadCriticalImages();
      // Preload remaining images in background
      _preloadBackgroundImages();
    } catch (e) {
      if (showLoading) {
      message.value = 'Error loading data: ${e.toString()}';
      }
      print('Error loading home data: $e');
    } finally {
      if (showLoading) {
      isLoading.value = false;
      }
    }
  }

  /// Cache all current data (Hive only — trimmed lists, no duplicate prefs storage)
  Future<void> _cacheAllData() async {
    try {
      await Future.wait([
        HiveCacheService.cacheList('home_fruit', List<Map<String, dynamic>>.from(fruit)),
        HiveCacheService.cacheList('home_prayers', List<Map<String, dynamic>>.from(prayers)),
        HiveCacheService.cacheList('home_blogs', List<Map<String, dynamic>>.from(blogs)),
        HiveCacheService.cacheList('home_videos', List<Map<String, dynamic>>.from(videos)),
        HiveCacheService.cacheList('home_shorts', List<Map<String, dynamic>>.from(communityShorts)),
        HiveCacheService.cacheList('home_live_videos', List<Map<String, dynamic>>.from(liveVideos)),
        HiveCacheService.cacheList('home_gallery_photos', List<Map<String, dynamic>>.from(galleryPhotos)),
        HiveCacheService.cacheList('home_stories', List<Map<String, dynamic>>.from(stories)),
        HiveCacheService.cacheList('home_groups', List<Map<String, dynamic>>.from(groups)),
        HiveCacheService.cacheList('home_group_posts', List<Map<String, dynamic>>.from(groupPosts)),
        HiveCacheService.cacheList('home_emojis', List<Map<String, dynamic>>.from(emojis)),
      ]);
      print('💾 All home data cached (Hive)');
    } catch (e) {
      print('⚠️ Error caching data: $e');
    }
  }

  /// Preload critical images that are immediately visible
  void _preloadCriticalImages() {
    final preloadService = ImagePreloadService();
    final criticalUrls = <String>[];
    
    // Preload notification icon (always visible in app bar)
    criticalUrls.add(ImageConfig.notification);
    
    // Preload first 3 gallery photos (likely visible)
    if (galleryPhotos.isNotEmpty) {
      for (int i = 0; i < 3 && i < galleryPhotos.length; i++) {
        final photo = galleryPhotos[i];
        if (photo['file_path'] != null) {
          criticalUrls.add('http://admin.fosmessenger.com/${photo['file_path']}');
        }
      }
    }
    
    // Preload first 2 blogs (likely visible)
    if (blogs.isNotEmpty) {
      for (int i = 0; i < 2 && i < blogs.length; i++) {
        final blog = blogs[i];
        if (blog['image_url'] != null) {
          criticalUrls.add('http://admin.fosmessenger.com/${blog['image_url']}');
        }
      }
    }
    
    // Preload first 2 videos (likely visible)
    if (videos.isNotEmpty) {
      for (int i = 0; i < 2 && i < videos.length; i++) {
        final video = videos[i];
        if (video['file_path'] != null) {
          criticalUrls.add('http://admin.fosmessenger.com/${video['file_path']}');
        }
      }
    }
    
    // Load critical images with high priority
    preloadService.preloadImages(criticalUrls, priorityLimit: criticalUrls.length);
  }

  /// Preload remaining images in background
  void _preloadBackgroundImages() {
    final preloadService = ImagePreloadService();
    
    // Preload remaining gallery photos
    if (galleryPhotos.length > 3) {
      preloadService.preloadImagesFromData(
        galleryPhotos.skip(3).toList(),
        imageFields: ['file_path'],
        priorityLimit: 0, // All background
      );
    }
    
    // Preload remaining blogs
    if (blogs.length > 2) {
      preloadService.preloadImagesFromData(
        blogs.skip(2).toList(),
        imageFields: ['image_url'],
        priorityLimit: 0,
      );
    }
    
    // Preload remaining videos
    if (videos.length > 2) {
      preloadService.preloadImagesFromData(
        videos.skip(2).toList(),
        imageFields: ['file_path'],
        priorityLimit: 0,
      );
    }
    
    // Preload prayers profile photos (background)
    preloadService.preloadImagesFromData(
      prayers,
      imageFields: ['profile_photo'],
      priorityLimit: 0,
    );
    
    // Preload groups images (background)
    preloadService.preloadImagesFromData(
      groups,
      imageFields: ['image_url', 'file_path'],
      priorityLimit: 0,
    );
  }

  /// Load all 9 Fruit of the Spirit from database
  Future<void> loadFruit() async {
    try {
      print('🔄 Loading fruit from API...');
      final fruitList = await FruitService.getAllFruit();
      print('✅ Loaded ${fruitList.length} fruit from database');
      for (var i = 0; i < fruitList.length; i++) {
        print('   ${i + 1}. ID: ${fruitList[i]['id']}, Name: ${fruitList[i]['name']}');
      }
      fruit.value = fruitList;
      print('✅ Fruit assigned to controller: ${fruit.length}');
    } catch (e) {
      print('❌ Error loading fruit: $e');
      // Keep existing data if available, don't clear on error
      if (fruit.isEmpty) {
      fruit.value = [];
      }
    }
  }

  /// Load latest approved prayer requests from database
  Future<void> loadPrayers() async {
    try {
      final prayersList = await PrayersService.getPrayers(
        status: 'Approved',
        currentUserId: userId.value > 0 ? userId.value : null,
        limit: 50, // Increased limit to show more prayers
      );
      prayers.value = prayersList;
      print('✅ Loaded ${prayersList.length} prayers from database');
    } catch (e) {
      print('Error loading prayers: $e');
      if (prayers.isEmpty) {
      prayers.value = [];
      }
    }
  }

  /// Load latest approved blogs — Hive first, silent background sync (feeling pattern).
  Future<void> loadBlogs({bool silent = false}) async {
    if (silent &&
        _blogsLastSyncedAt != null &&
        DateTime.now().difference(_blogsLastSyncedAt!) < _blogsMinSyncInterval) {
      return;
    }
    if (_isBlogsSyncing) return;
    _isBlogsSyncing = true;

    try {
      final blogsList = await BlogsService.getBlogs(
        status: 'Approved',
        currentUserId: userId.value > 0 ? userId.value : null,
        limit: 5,
      );

      if (blogs.isEmpty) {
        blogs.value = blogsList;
      } else if (silent) {
        _mergeHomeBlogs(blogsList);
      } else if (!_homeBlogListsEqual(blogs.toList(), blogsList)) {
        blogs.value = blogsList;
      }

      _blogsLastSyncedAt = DateTime.now();
      if (blogs.isNotEmpty) {
        final snapshot = List<Map<String, dynamic>>.from(blogs);
        unawaited(
          HiveCacheService.cacheList(
            _homeBlogsHiveKey,
            snapshot,
            expiryHours: 24,
          ),
        );
        unawaited(
          HiveCacheService.cacheList(
            'blogs_list',
            snapshot,
            expiryHours: 24,
          ),
        );
      }
    } catch (e) {
      print('Error loading blogs: $e');
      if (blogs.isEmpty) {
        blogs.value = [];
      }
    } finally {
      _isBlogsSyncing = false;
    }
  }

  bool _homeBlogListsEqual(
    List<Map<String, dynamic>> previous,
    List<Map<String, dynamic>> next,
  ) {
    if (previous.length != next.length) return false;
    for (var i = 0; i < previous.length; i++) {
      final prev = previous[i];
      final curr = next[i];
      if (prev['id'] != curr['id']) return false;
      if (prev['updated_at'] != curr['updated_at']) return false;
      if (prev['like_count'] != curr['like_count']) return false;
      if (prev['comment_count'] != curr['comment_count']) return false;
      if (prev['title'] != curr['title']) return false;
    }
    return true;
  }

  void _mergeHomeBlogs(List<Map<String, dynamic>> incoming) {
    if (incoming.isEmpty) return;

    final current = blogs.toList();
    if (current.isEmpty) {
      blogs.value = incoming;
      return;
    }

    final indexById = <int, int>{};
    for (var i = 0; i < current.length; i++) {
      final id = current[i]['id'];
      final parsed = id is int ? id : int.tryParse(id?.toString() ?? '');
      if (parsed != null) indexById[parsed] = i;
    }

    var changed = false;
    for (final remote in incoming) {
      final id = remote['id'];
      final parsed = id is int ? id : int.tryParse(id?.toString() ?? '');
      if (parsed == null) continue;

      final idx = indexById[parsed];
      if (idx != null) {
        final local = current[idx];
        if (local['updated_at'] != remote['updated_at'] ||
            local['like_count'] != remote['like_count'] ||
            local['comment_count'] != remote['comment_count'] ||
            local['title'] != remote['title'] ||
            local['image'] != remote['image'] ||
            local['image_url'] != remote['image_url']) {
          current[idx] = {...local, ...remote};
          changed = true;
        }
      } else {
        current.insert(0, Map<String, dynamic>.from(remote));
        changed = true;
      }
    }

    if (changed) {
      blogs.value = current;
    }
  }

  bool _hasAnyHomeCache() {
    return fruit.isNotEmpty ||
        prayers.isNotEmpty ||
        blogs.isNotEmpty ||
        videos.isNotEmpty ||
        communityShorts.isNotEmpty ||
        myShorts.isNotEmpty ||
        liveVideos.isNotEmpty ||
        groups.isNotEmpty ||
        galleryPhotos.isNotEmpty;
  }

  /// Load latest approved videos — silent merge when cache exists.
  Future<void> loadVideos({bool silent = false}) async {
    if (silent &&
        _videosLastSyncedAt != null &&
        DateTime.now().difference(_videosLastSyncedAt!) < _videosMinSyncInterval) {
      return;
    }
    if (_isVideosSyncing) return;
    _isVideosSyncing = true;

    try {
      final approvedVideos = await VideosService.getVideos(
        status: 'Approved',
        currentUserId: userId.value > 0 ? userId.value : null,
        limit: 5,
      );

      List<Map<String, dynamic>> allVideos = List.from(approvedVideos);

      if (userId.value > 0) {
        try {
          final pendingVideos = await VideosService.getVideos(
            status: 'Pending',
            userId: userId.value,
            limit: 10,
          );
          allVideos.insertAll(0, pendingVideos);
        } catch (e) {
          print('Error loading pending videos: $e');
        }
      }

      if (videos.isEmpty) {
        videos.value = allVideos;
      } else if (silent) {
        _mergeHomeVideos(allVideos);
      } else if (!_homeVideoListsEqual(videos.toList(), allVideos)) {
        videos.value = allVideos;
      }

      _videosLastSyncedAt = DateTime.now();
      if (videos.isNotEmpty) {
        unawaited(
          HiveCacheService.cacheList(
            'home_videos',
            List<Map<String, dynamic>>.from(videos),
            expiryHours: 24,
          ),
        );
      }
    } catch (e) {
      print('Error loading videos: $e');
      if (videos.isEmpty) {
        videos.value = [];
      }
    } finally {
      _isVideosSyncing = false;
    }
  }

  Future<void> loadCommunityShorts({bool silent = false}) async {
    if (silent &&
        _communityShortsLastSyncedAt != null &&
        DateTime.now().difference(_communityShortsLastSyncedAt!) <
            _communityShortsMinSyncInterval) {
      return;
    }
    if (_isCommunityShortsSyncing) return;
    _isCommunityShortsSyncing = true;

    try {
      await _loadUserId();
      final uid = userId.value;

      final communityFuture = ShortsService.getShorts(
        currentUserId: uid > 0 ? uid : null,
        limit: 15,
      );
      final mineFuture = uid > 0
          ? ShortsService.getShorts(
              status: 'Approved,Pending',
              userId: uid,
              currentUserId: uid,
              limit: 15,
            )
          : Future<List<Map<String, dynamic>>>.value([]);

      final results = await Future.wait([communityFuture, mineFuture]);
      final items = results[0];
      final mine = results[1];

      myShorts.value = List<Map<String, dynamic>>.from(mine);
      if (mine.isNotEmpty) {
        unawaited(
          HiveCacheService.cacheList(
            'shorts_my',
            List<Map<String, dynamic>>.from(mine),
            expiryHours: 24,
          ),
        );
      }

      final filtered = items.where((short) {
        final ownerId = int.tryParse(short['user_id']?.toString() ?? '0') ?? 0;
        return uid <= 0 || ownerId != uid;
      }).toList();

      communityShorts.value = filtered;

      _communityShortsLastSyncedAt = DateTime.now();
      if (communityShorts.isNotEmpty) {
        unawaited(
          HiveCacheService.cacheList(
            'home_shorts',
            List<Map<String, dynamic>>.from(communityShorts),
            expiryHours: 24,
          ),
        );
        unawaited(
          HiveCacheService.cacheList(
            'shorts_community',
            List<Map<String, dynamic>>.from(communityShorts),
            expiryHours: 24,
          ),
        );
      }
    } catch (e) {
      print('Error loading community shorts: $e');
      if (communityShorts.isEmpty) {
        communityShorts.value = [];
      }
    } finally {
      _isCommunityShortsSyncing = false;
    }
  }

  bool _homeVideoListsEqual(
    List<Map<String, dynamic>> previous,
    List<Map<String, dynamic>> next,
  ) {
    if (previous.length != next.length) return false;
    for (var i = 0; i < previous.length; i++) {
      if (previous[i]['id'] != next[i]['id']) return false;
      if (previous[i]['updated_at'] != next[i]['updated_at']) return false;
      if (previous[i]['view_count'] != next[i]['view_count']) return false;
    }
    return true;
  }

  void _mergeHomeVideos(List<Map<String, dynamic>> remote) {
    final current = List<Map<String, dynamic>>.from(videos);
    var changed = false;

    for (final item in remote) {
      final id = item['id'];
      final idx = current.indexWhere((v) => v['id'] == id);
      if (idx >= 0) {
        final local = current[idx];
        if (local['updated_at'] != item['updated_at'] ||
            local['view_count'] != item['view_count'] ||
            local['title'] != item['title'] ||
            local['file_path'] != item['file_path'] ||
            local['status'] != item['status']) {
          current[idx] = {...local, ...item};
          changed = true;
        }
      } else {
        current.insert(0, Map<String, dynamic>.from(item));
        changed = true;
      }
    }

    if (changed) {
      videos.value = current;
    }
  }

  /// Load live videos — keep cache visible until fresh data arrives.
  Future<void> loadLiveVideos({bool silent = false}) async {
    if (silent &&
        _liveVideosLastSyncedAt != null &&
        DateTime.now().difference(_liveVideosLastSyncedAt!) < _videosMinSyncInterval) {
      return;
    }
    if (_isLiveVideosSyncing) return;
    _isLiveVideosSyncing = true;

    try {
      final liveList = await LiveStreamingService.getAllLiveStreams();
      final onlyLive = liveList.where((s) {
        final status = (s['status'] ?? '').toString().toLowerCase();
        return status == 'live';
      }).toList();

      if (liveVideos.isEmpty || !silent) {
        liveVideos.value = onlyLive;
      } else if (!_homeVideoListsEqual(liveVideos.toList(), onlyLive)) {
        liveVideos.value = onlyLive;
      }

      _liveVideosLastSyncedAt = DateTime.now();
      if (liveVideos.isNotEmpty) {
        unawaited(
          HiveCacheService.cacheList(
            'home_live_videos',
            List<Map<String, dynamic>>.from(liveVideos),
            expiryHours: 24,
          ),
        );
      }
    } catch (e) {
      print('Error loading live videos: $e');
      if (liveVideos.isEmpty) {
        liveVideos.value = [];
      }
    } finally {
      _isLiveVideosSyncing = false;
    }
  }

  /// Load latest approved stories from database
  Future<void> loadStories() async {
    try {
      final storiesList = await StoriesService.getStories(
        status: 'Approved',
        currentUserId: userId.value > 0 ? userId.value : null,
        limit: 100, // Load all approved stories
      );
      stories.value = storiesList;
      print('📖 Stories Loaded: ${storiesList.length}');
      for (var story in storiesList) {
        print('   - Story: ${story['title']}');
      }
    } catch (e) {
      print('Error loading stories: $e');
      if (stories.isEmpty) {
        stories.value = [];
      }
    }
  }

  /// Load latest approved gallery photos from database (real API data only).
  Future<void> loadGalleryPhotos({bool silent = false}) async {
    try {
      final photosList = await GalleryService.getPhotos(
        status: 'Approved',
        currentUserId: userId.value > 0 ? userId.value : null,
        limit: 12,
      );

      if (galleryPhotos.isEmpty || !silent) {
        galleryPhotos.value = photosList;
      } else {
        _mergeHomeGalleryPhotos(photosList);
      }

      if (galleryPhotos.isNotEmpty) {
        unawaited(
          HiveCacheService.cacheList(
            'home_gallery_photos',
            List<Map<String, dynamic>>.from(galleryPhotos),
            expiryHours: 24,
          ),
        );
      }
      print('✅ Gallery photos loaded: ${galleryPhotos.length}');
    } catch (e) {
      print('Error loading gallery photos: $e');
      if (galleryPhotos.isEmpty) {
        galleryPhotos.value = [];
      }
    }
  }

  void _mergeHomeGalleryPhotos(List<Map<String, dynamic>> remote) {
    final current = List<Map<String, dynamic>>.from(galleryPhotos);
    var changed = false;

    for (final item in remote) {
      final id = item['id'];
      final idx = current.indexWhere((p) => p['id'] == id);
      if (idx >= 0) {
        if (current[idx]['updated_at'] != item['updated_at'] ||
            current[idx]['file_path'] != item['file_path'] ||
            current[idx]['thumbnail_path'] != item['thumbnail_path']) {
          current[idx] = {...current[idx], ...item};
          changed = true;
        }
      } else {
        current.add(Map<String, dynamic>.from(item));
        changed = true;
      }
    }

    if (changed) {
      galleryPhotos.value = current;
    }
  }

  /// Load active groups — Hive first, silent background sync.
  Future<void> loadGroups({bool silent = false}) async {
    if (silent &&
        _groupsLastSyncedAt != null &&
        DateTime.now().difference(_groupsLastSyncedAt!) < _groupsMinSyncInterval) {
      return;
    }
    if (_isGroupsSyncing) return;
    _isGroupsSyncing = true;

    try {
      final groupsList = await GroupsService.getGroups(
        status: 'Active',
        limit: 6,
      );

      if (groups.isEmpty) {
        groups.value = groupsList;
      } else if (silent) {
        _mergeHomeGroups(groupsList);
      } else if (!_homeGroupsListsEqual(groups.toList(), groupsList)) {
        groups.value = groupsList;
      }

      _groupsLastSyncedAt = DateTime.now();
      if (groups.isNotEmpty) {
        final snapshot = List<Map<String, dynamic>>.from(groups);
        unawaited(
          HiveCacheService.cacheList(
            _homeGroupsHiveKey,
            snapshot,
            expiryHours: 24,
          ),
        );
      }
    } catch (e) {
      print('Error loading groups: $e');
      if (groups.isEmpty) {
        groups.value = [];
      }
    } finally {
      _isGroupsSyncing = false;
    }
  }

  bool _homeGroupsListsEqual(
    List<Map<String, dynamic>> previous,
    List<Map<String, dynamic>> next,
  ) {
    if (previous.length != next.length) return false;
    for (var i = 0; i < previous.length; i++) {
      final prev = previous[i];
      final curr = next[i];
      if (prev['id'] != curr['id']) return false;
      if (prev['updated_at'] != curr['updated_at']) return false;
      if (prev['member_count'] != curr['member_count']) return false;
      if (prev['name'] != curr['name']) return false;
    }
    return true;
  }

  void _mergeHomeGroups(List<Map<String, dynamic>> incoming) {
    if (incoming.isEmpty) return;

    final current = groups.toList();
    if (current.isEmpty) {
      groups.value = incoming;
      return;
    }

    final indexById = <int, int>{};
    for (var i = 0; i < current.length; i++) {
      final id = current[i]['id'];
      final parsed = id is int ? id : int.tryParse(id?.toString() ?? '');
      if (parsed != null) indexById[parsed] = i;
    }

    var changed = false;
    for (final remote in incoming) {
      final id = remote['id'];
      final parsed = id is int ? id : int.tryParse(id?.toString() ?? '');
      if (parsed == null) continue;

      final idx = indexById[parsed];
      if (idx != null) {
        final local = current[idx];
        if (local['updated_at'] != remote['updated_at'] ||
            local['member_count'] != remote['member_count'] ||
            local['name'] != remote['name']) {
          current[idx] = {...local, ...remote};
          changed = true;
        }
      } else {
        current.insert(0, remote);
        changed = true;
      }
    }

    if (changed) {
      groups.value = current;
    }
  }

  /// Load recent group posts — Hive first, silent background sync.
  Future<void> loadGroupPosts({bool silent = false}) async {
    if (!GroupPostsConfig.enabled) {
      groupPosts.value = [];
      return;
    }
    if (userId.value <= 0) {
      groupPosts.value = [];
      return;
    }

    if (silent &&
        _groupPostsLastSyncedAt != null &&
        DateTime.now().difference(_groupPostsLastSyncedAt!) < _groupsMinSyncInterval) {
      return;
    }
    if (_isGroupPostsSyncing) return;
    _isGroupPostsSyncing = true;

    try {
      final posts = await GroupPostsService.getGroupPostsFeed(
        userId: userId.value,
        limit: 10,
      );

      if (groupPosts.isEmpty) {
        groupPosts.value = posts;
      } else if (silent) {
        _mergeHomeGroupPosts(posts);
      } else if (!_homeGroupPostsListsEqual(groupPosts.toList(), posts)) {
        groupPosts.value = posts;
      }

      _groupPostsLastSyncedAt = DateTime.now();
      if (groupPosts.isNotEmpty) {
        unawaited(
          HiveCacheService.cacheList(
            _homeGroupPostsHiveKey,
            List<Map<String, dynamic>>.from(groupPosts),
            expiryHours: 24,
          ),
        );
      }
    } catch (e) {
      print('Error loading group posts: $e');
      if (groupPosts.isEmpty) {
        groupPosts.value = [];
      }
    } finally {
      _isGroupPostsSyncing = false;
    }
  }

  bool _homeGroupPostsListsEqual(
    List<Map<String, dynamic>> previous,
    List<Map<String, dynamic>> next,
  ) {
    if (previous.length != next.length) return false;
    for (var i = 0; i < previous.length; i++) {
      final prev = previous[i];
      final curr = next[i];
      if (prev['id'] != curr['id']) return false;
      if (prev['updated_at'] != curr['updated_at']) return false;
      if (prev['comment_count'] != curr['comment_count']) return false;
      if (prev['reaction_count'] != curr['reaction_count']) return false;
    }
    return true;
  }

  void _mergeHomeGroupPosts(List<Map<String, dynamic>> incoming) {
    if (incoming.isEmpty) return;

    final current = groupPosts.toList();
    if (current.isEmpty) {
      groupPosts.value = incoming;
      return;
    }

    final indexById = <int, int>{};
    for (var i = 0; i < current.length; i++) {
      final id = current[i]['id'];
      final parsed = id is int ? id : int.tryParse(id?.toString() ?? '');
      if (parsed != null) indexById[parsed] = i;
    }

    var changed = false;
    for (final remote in incoming) {
      final id = remote['id'];
      final parsed = id is int ? id : int.tryParse(id?.toString() ?? '');
      if (parsed == null) continue;

      final idx = indexById[parsed];
      if (idx != null) {
        final local = current[idx];
        if (local['updated_at'] != remote['updated_at'] ||
            local['comment_count'] != remote['comment_count'] ||
            local['reaction_count'] != remote['reaction_count']) {
          current[idx] = {...local, ...remote};
          changed = true;
        }
      } else {
        current.insert(0, remote);
        changed = true;
      }
    }

    if (changed) {
      groupPosts.value = current;
    }
  }

  /// Load emojis from database
  /// Loads all emoji images from emojis table in database
  Future<void> loadEmojis({bool refresh = false}) async {
    // Performance: Skip if already loading
    if (_isLoadingEmojis && !refresh) {
      print('⚠️ Emojis already loading, skipping...');
      return;
    }

    // Performance: Skip if data already loaded and not refreshing
    if (_isEmojisLoaded && !refresh && emojis.isNotEmpty) {
      print('✅ Emojis already loaded (${emojis.length} items), skipping reload...');
      return;
    }
    
    _isLoadingEmojis = true;
    
    try {
      print('🔄 Loading all emojis from database...');
      
      // Load all emojis from database
      var emojisList = await EmojisService.getEmojis(
        status: 'Active',
        sortBy: 'image_url',
        order: 'ASC',
      );
      print('✅ Loaded ${emojisList.length} emojis from database');
      
      // Group emojis by category
      final mainFruitList = <Map<String, dynamic>>[];
      final allEmojisList = <Map<String, dynamic>>[];
      final oppositeEmojisList = <Map<String, dynamic>>[];
      final emotionEmojisList = <Map<String, dynamic>>[];
      
      for (var emoji in emojisList) {
        final category = emoji['category'] as String? ?? '';
        final name = (emoji['name'] as String? ?? '').toLowerCase();
        
        // Add to all emojis list
        allEmojisList.add(emoji);
        
        // List of fruit names to check
        final fruitNames = [
          'goodness', 'joy', 'kindness', 'peace', 'patience', 
          'faithfulness', 'gentleness', 'meekness', 'self-control', 'self control', 'love'
        ];
        
        // Check if name contains any fruit name
        final hasFruitName = fruitNames.any((fruit) => name.contains(fruit));
        
        // Categorize emojis - check both category and name
        if (category.toLowerCase().contains('fruit') || 
            category == 'Fruit' || 
            (category.isEmpty && hasFruitName)) {
          mainFruitList.add(emoji);
        } else if (category.toLowerCase().contains('opposite')) {
          oppositeEmojisList.add(emoji);
        } else if (category.toLowerCase().contains('emotion')) {
          emotionEmojisList.add(emoji);
        } else if (category.isEmpty) {
          // Default to main fruit if category is empty and name suggests it's a fruit
          if (hasFruitName) {
            mainFruitList.add(emoji);
          } else {
            // Unknown category - add to all emojis but not to specific categories
            // This prevents empty categories from breaking the UI
          }
        }
      }
      
      print('📊 Emojis from database:');
      print('   Total emojis: ${emojisList.length}');
      print('   Main fruit: ${mainFruitList.length}');
      print('   Opposite emojis: ${oppositeEmojisList.length}');
      print('   Emotion emojis: ${emotionEmojisList.length}');
      
      // Store all emojis
      emojis.value = mainFruitList; // Main fruit for carousel
      allEmojis.value = allEmojisList; // All emojis for reference
      oppositeEmojis.value = oppositeEmojisList; // Opposite emojis
      emotionEmojis.value = emotionEmojisList; // Emotion emojis

      if (mainFruitList.isNotEmpty) {
        unawaited(HiveCacheService.cacheList(
          'fruit_screen_emojis',
          mainFruitList,
        ));
        unawaited(HiveCacheService.cacheList(
          'fruit_screen_all_variants',
          allEmojisList,
        ));
      }
      
      // Performance: Mark as loaded
      _isEmojisLoaded = true;
    } catch (e, stackTrace) {
      print('❌ Error loading emojis: $e');
      print('❌ Error details: ${e.toString()}');
      print('❌ Stack trace: $stackTrace');
      // Don't clear emojis if they were already loaded (keep cached data)
      if (emojis.isEmpty) {
        emojis.value = [];
        allEmojis.value = [];
        _isEmojisLoaded = false;
      }
      // Re-throw to let UI handle it
      rethrow;
    } finally {
      _isLoadingEmojis = false;
    }
  }

  /// Create temporary fruit emojis from uploads/emojis folder
  /// This is a fallback when database doesn't have fruit emojis yet
  List<Map<String, dynamic>> _createTemporaryFruitEmojis() {
    final baseUrl = 'http://admin.fosmessenger.com/';
    final emojisBaseUrl = '${baseUrl}uploads/emojis/';

    // Map of spiritual fruit to physical fruit images from uploads/emojis folder
    // NOTE: This method is not currently used - fruit are loaded from database via loadEmojis()
    // All file names should come from database, not hardcoded here
    // IMPORTANT: Only show ONE variant per fruit in carousel to avoid confusion
    // User should see one unique image per fruit, not 3 variants of the same fruit
    final fruitMappings = <Map<String, String>>[];

    // Love - Strawberry (using images/Strawberry.png as fallback since strawberry not in emojis folder)
    fruitMappings.add({
      'name': 'Love',
      'emoji_char': '❤️',
      'code': 'love_01',
      'image': '${baseUrl}uploads/images/Strawberry.png',
      'description': 'The strawberry is the fruit of love. Love\'s compatible physical fruit is as sweet as the spiritual fruit. Strawberries, not only look like a fruity heart-shaped valentine, they are filled with unusual phytonutrients that love to promote your health.',
    });

    // Joy - Pineapple (from emojis folder - using first available variant)
    fruitMappings.add({
      'name': 'Joy',
      'emoji_char': '😊',
      'code': 'joy_01',
      'image': '${emojisBaseUrl}Kindness_peach_128%20(1).png', // Using available emoji from folder
      'description': 'The pineapple is the fruit of joy. Joy\'s compatible physical fruit is as sweet as the spiritual fruit. Pineapples are filled with unusual phytonutrients that promote your health.',
    });

    // Peace - Watermelon (from emojis folder)
    fruitMappings.add({
      'name': 'Peace',
      'emoji_char': '☮️',
      'code': 'peace_01',
      'image': '${emojisBaseUrl}Meekness_grapes_128%20(1).png', // Using available emoji from folder
      'description': 'The watermelon is the fruit of peace. Peace\'s compatible physical fruit is as sweet as the spiritual fruit. Watermelons are filled with unusual phytonutrients that promote your health.',
    });

    // Patience - Lemon (from emojis folder - actual file exists)
    fruitMappings.add({
      'name': 'Patience',
      'emoji_char': '⏳',
      'code': 'patience_01',
      'image': '${emojisBaseUrl}Patience_lemon_128%20(1).png', // URL encode space and parentheses
      'description': 'The lemon is the fruit of patience. Patience\'s compatible physical fruit is as sweet as the spiritual fruit. Lemons are filled with unusual phytonutrients that promote your health.',
    });

    // Kindness - Peach (from emojis folder - actual file exists)
    fruitMappings.add({
      'name': 'Kindness',
      'emoji_char': '🤗',
      'code': 'kindness_01',
      'image': '${emojisBaseUrl}Kindness_peach_128%20(1).png', // URL encode space and parentheses
      'description': 'The peach is the fruit of kindness. Kindness\'s compatible physical fruit is as sweet as the spiritual fruit. Peaches are filled with unusual phytonutrients that promote your health.',
    });

    // Goodness - Load from database (no hardcoded file names)
    // NOTE: This method is not currently used - fruits are loaded from database via loadEmojis()
    // fruitMappings.add({
    //   'name': 'Goodness',
    //   'emoji_char': '✨',
    //   'code': 'goodness_01',
    //   'image': '${emojisBaseUrl}Goodness_banana_128%20(1).png', // REMOVED: Hardcoded file name
    //   'description': 'The banana is the fruit of goodness. Goodness\'s compatible physical fruit is as sweet as the spiritual fruit. Bananas are filled with unusual phytonutrients that promote your health.',
    // });

    // Faithfulness - Cherry (not available, using goodness banana as fallback)
    fruitMappings.add({
      'name': 'Faithfulness',
      'emoji_char': '🙏',
      'code': 'faithfulness_01',
      'image': '${emojisBaseUrl}Goodness_banana_128%20(1).png', // Using available emoji from folder
      'description': 'The cherry is the fruit of faithfulness. Faithfulness\'s compatible physical fruit is as sweet as the spiritual fruit. Cherries are filled with unusual phytonutrients that promote your health.',
    });

    // Meekness/Gentleness - Grapes (from emojis folder - actual file exists)
    fruitMappings.add({
      'name': 'Meekness',
      'emoji_char': '🕊️',
      'code': 'meekness_01',
      'image': '${emojisBaseUrl}Meekness_grapes_128%20(1).png', // URL encode space and parentheses
      'description': 'The grape is the fruit of meekness. Meekness\'s compatible physical fruit is as sweet as the spiritual fruit. Grapes are filled with unusual phytonutrients that promote your health.',
    });

    // Self-Control - Apple (not in emojis folder, using patience lemon as fallback)
    fruitMappings.add({
      'name': 'Self-Control',
      'emoji_char': '🎯',
      'code': 'self_control_01',
      'image': '${emojisBaseUrl}Patience_lemon_128%20(1).png', // Using available emoji from folder
      'description': 'The apple is the fruit of self-control. Self-control\'s compatible physical fruit is as sweet as the spiritual fruit. Apples are filled with unusual phytonutrients that promote your health.',
    });

    print('🍎 Created ${fruitMappings.length} unique fruit emojis (one per fruit):');
    for (var i = 0; i < fruitMappings.length; i++) {
      print('   ${i + 1}. ${fruitMappings[i]['name']} - ${fruitMappings[i]['code']} - ${fruitMappings[i]['image']}');
    }

    // Convert to emoji format
    return fruitMappings.map((fruit) {
      return {
        'id': fruitMappings.indexOf(fruit) + 1, // Temporary ID starting from 1
        'name': fruit['name']!,
        'emoji_char': fruit['emoji_char']!,
        'code': fruit['code']!,
        'image_url': fruit['image']!,
        'description': fruit['description'] ?? '${fruit['name']} - Fruit of the Spirit',
        'category': 'Fruit of Spirit',
        'usage_count': 0,
        'status': 'Active',
        'created_at': DateTime.now().toIso8601String(),
      };
    }).toList();
  }

  /// Pull-to-refresh only — keeps cache visible, silent merge when possible.
  Future<void> refreshData() async {
    await loadHomeData(showLoading: false);
  }

  /// Reset internal load flags when user logs out (lists cleared elsewhere).
  void resetSessionState() {
    _isDataLoaded = false;
    _isEmojisLoaded = false;
    _isLoading = false;
    _isLoadingEmojis = false;
  }

  /// Scroll to top smoothly
  void scrollToTop() {
    try {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    } catch (e) {
      // Ignore errors if controller is disposed or not attached
      // This can happen if the widget is disposed while animation is running
    }
  }

  @override
  void onClose() {
    try {
      // Safely dispose scrollController
      // During hot reload, scroll animations may still be active
      // Check if controller is attached before disposing
      if (scrollController.hasClients) {
        try {
          // Try to jump to current position to stop any ongoing animations
          final position = scrollController.position;
          if (position.hasPixels) {
            // This might help stop ongoing animations
            scrollController.jumpTo(position.pixels);
          }
        } catch (_) {
          // Ignore if position is not accessible
        }
      }
      scrollController.dispose();
      
      // Clear large data lists to reclaim memory
      fruit.clear();
      prayers.clear();
      blogs.clear();
      videos.clear();
      galleryPhotos.clear();
      stories.clear();
      groups.clear();
      emojis.clear();
      allEmojis.clear();
      _isDataLoaded = false;
    } catch (e) {
      // Ignore errors during disposal
      // This can happen during hot reload when scroll animation is active
      // The controller might already be disposed or in an invalid state
      // These errors are harmless and won't affect app functionality
    }
    super.onClose();
  }
}
