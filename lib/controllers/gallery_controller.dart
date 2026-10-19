import 'dart:async';
import 'dart:io';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:fruitsofspirit/services/gallery_service.dart';
import 'package:fruitsofspirit/services/comments_service.dart';
import 'package:fruitsofspirit/services/user_storage.dart';
import 'package:fruitsofspirit/services/api_service.dart';
import 'package:fruitsofspirit/services/emojis_service.dart';
import 'package:fruitsofspirit/services/content_moderation_service.dart';
import 'package:fruitsofspirit/routes/app_pages.dart';
import 'package:fruitsofspirit/routes/routes.dart';
import 'package:fruitsofspirit/services/fruit_service.dart';
import 'package:fruitsofspirit/services/hive_cache_service.dart';
import 'package:fruitsofspirit/services/payment_gate.dart';
import 'package:fruitsofspirit/controllers/home_controller.dart';
import 'package:fruitsofspirit/utils/image_helper.dart';

/// Gallery Controller
/// Manages gallery photos data and operations
class GalleryController extends GetxController {
  // Observable variables
  var isLoading = false.obs;
  var isDetailsSilentSyncing = false.obs;
  var message = ''.obs;
  
  // Data
  var photos = <Map<String, dynamic>>[].obs;
  var selectedPhoto = <String, dynamic>{}.obs;
  var photoComments = <Map<String, dynamic>>[].obs;
  var userId = 0.obs;
  
  // Emoji Reactions (same as prayers_controller)
  var photoEmojiReactions = <String, List<Map<String, dynamic>>>{}.obs;
  var availableEmojis = <Map<String, dynamic>>[].obs;
  var quickEmojis = <Map<String, dynamic>>[].obs; // Top 6 emojis for quick reactions

  // Filters
  var selectedFruitTag = ''.obs;
  var filterUserId = 0.obs; // Filter by specific user ID (0 = all users)
  var currentPage = 0.obs;
  final int itemsPerPage = 20;
  
  // Performance: Store all photos for instant client-side filtering
  var _allPhotos = <Map<String, dynamic>>[];
  
  // Performance: Track if data is already loaded to prevent unnecessary reloads
  var _isDataLoaded = false;
  var _isLoading = false;
  int _loadGeneration = 0;
  DateTime? _lastSyncedAt;
  static const Duration _minSyncInterval = Duration(minutes: 2);
  static const Duration _detailsMinSyncInterval = Duration(minutes: 2);
  static const String _galleryListHiveKey = 'gallery_list';
  Completer<void>? _activeLoadCompleter;
  DateTime? _detailsLastSyncedAt;
  int _detailsLoadGeneration = 0;
  int? preparedDetailPhotoId;
  final Set<int> _deletedCommentIds = {};
  final Set<int> _deletedPhotoIds = {};

  @override
  void onInit() {
    super.onInit();
    _loadUserId();
    loadFromHiveIfEmpty();
    // Don't reset filter here - it might be set before navigation
    // Filter will be reset by home screen navigation if needed
  }

  @override
  void onReady() {
    super.onReady();
    _seedFromHomeIfRegistered();
    loadFromHiveIfEmpty();
    if (_allPhotos.isNotEmpty) {
      _applyClientSideFilter();
    }
    if (filterUserId.value == 0) {
      unawaited(loadPhotos(refresh: true, silent: true));
    }
    loadAvailableEmojis();
    loadQuickEmojis();
  }

  void _seedFromHomeIfRegistered() {
    if (!Get.isRegistered<HomeController>()) return;
    seedFromHomeIfEmpty(Get.find<HomeController>().galleryPhotos.toList());
  }

  /// Load user ID from storage
  Future<void> _loadUserId() async {
    final id = await UserStorage.getUserId();
    if (id != null) {
      userId.value = id;
    }
  }

  Future<void> _ensureUserId() async {
    if (userId.value == 0) {
      await _loadUserId();
    }
  }

  void loadFromHiveIfEmpty() {
    if (_allPhotos.isNotEmpty) return;
    var cached = HiveCacheService.getCachedList(_galleryListHiveKey);
    if (cached.isEmpty) {
      cached = HiveCacheService.getCachedList('home_gallery_photos');
    }
    final real = cached.where(ImageHelper.isRealGalleryPhoto).toList();
    if (real.isEmpty) return;
    _allPhotos = List<Map<String, dynamic>>.from(real);
    _isDataLoaded = true;
    _applyClientSideFilter();
  }

  void bootstrapGallery() {
    loadFromHiveIfEmpty();
  }

  List<Map<String, dynamic>> _filterSeedPhotos(
    List<Map<String, dynamic>> source,
  ) {
    return source
        .where(ImageHelper.isRealGalleryPhoto)
        .where((photo) {
          final status = (photo['status'] ?? 'Approved').toString().toLowerCase();
          return status == 'approved';
        })
        .map((p) => Map<String, dynamic>.from(p))
        .toList();
  }

  /// Seed gallery from home cache for instant open.
  void seedFromHomeIfEmpty(List<Map<String, dynamic>> homePhotos) {
    if (_allPhotos.isNotEmpty || homePhotos.isEmpty) return;
    final real = _filterSeedPhotos(homePhotos);
    if (real.isEmpty) return;
    _allPhotos = real;
    _isDataLoaded = true;
    _applyClientSideFilter();
  }

  int? _photoIdFromMap(Map<String, dynamic> map) {
    final id = map['id'];
    if (id is int) return id;
    if (id is String) return int.tryParse(id);
    return null;
  }

  String _photoDetailHiveKey(int photoId) => 'photo_detail_$photoId';

  void bootstrapPhotoDetail(int photoId) {
    if (photoId <= 0) return;

    final currentId = _photoIdFromMap(selectedPhoto);
    if (currentId != null && currentId != photoId) {
      photoComments.clear();
      photoEmojiReactions.clear();
      _deletedCommentIds.clear();
    }

    loadPhotoDetailFromHive(photoId);
    if (_photoIdFromMap(selectedPhoto) != photoId || selectedPhoto.isEmpty) {
      if (Get.isRegistered<HomeController>()) {
        seedPhotoDetailFromHome(
          Get.find<HomeController>().galleryPhotos.toList(),
          photoId,
        );
      }
      if (_photoIdFromMap(selectedPhoto) != photoId || selectedPhoto.isEmpty) {
        seedPhotoDetailFromList(photoId);
      }
    }
    preparedDetailPhotoId = photoId;
  }

  void loadPhotoDetailFromHive(int photoId) {
    final cached = HiveCacheService.getCachedMap(_photoDetailHiveKey(photoId));
    if (cached.isEmpty) return;

    if (cached['photo'] is Map) {
      selectedPhoto.value =
          Map<String, dynamic>.from(cached['photo'] as Map<String, dynamic>);
    } else {
      selectedPhoto.value = Map<String, dynamic>.from(cached);
    }

    if (cached['comments'] is List && photoComments.isEmpty) {
      photoComments.value = (cached['comments'] as List)
          .whereType<Map>()
          .map((c) => Map<String, dynamic>.from(c))
          .where((c) => !_isCommentDeleted(c))
          .map(_filterDeletedFromTree)
          .toList();
    }

    if (cached['emoji_reactions'] is Map && photoEmojiReactions.isEmpty) {
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
        photoEmojiReactions.value = reactions;
      }
    }
  }

  Future<void> _cachePhotoDetailSnapshot(int photoId) async {
    if (selectedPhoto.isEmpty) return;
    await HiveCacheService.cacheMap(
      _photoDetailHiveKey(photoId),
      {
        'photo': Map<String, dynamic>.from(selectedPhoto),
        'comments': photoComments.toList(),
        'emoji_reactions': photoEmojiReactions.map(
          (key, value) =>
              MapEntry(key, List<Map<String, dynamic>>.from(value)),
        ),
      },
      expiryHours: 24,
    );
  }

  void seedPhotoDetailFromList(int photoId) {
    if (_photoIdFromMap(selectedPhoto) == photoId && selectedPhoto.isNotEmpty) {
      return;
    }

    Map<String, dynamic>? found;
    for (final photo in _allPhotos) {
      if (_photoIdFromMap(photo) == photoId) {
        found = photo;
        break;
      }
    }
    if (found == null) {
      for (final photo in photos) {
        if (_photoIdFromMap(photo) == photoId) {
          found = photo;
          break;
        }
      }
    }

    if (found != null) {
      selectedPhoto.value = Map<String, dynamic>.from(found);
    }
  }

  void seedPhotoDetailFromHome(
    List<Map<String, dynamic>> homePhotos,
    int photoId,
  ) {
    if (_photoIdFromMap(selectedPhoto) == photoId && selectedPhoto.isNotEmpty) {
      return;
    }
    for (final photo in homePhotos) {
      if (_photoIdFromMap(photo) == photoId) {
        selectedPhoto.value = Map<String, dynamic>.from(photo);
        return;
      }
    }
  }

  Future<void> preparePhotoDetails(int photoId) async {
    if (photoId <= 0) return;

    bootstrapPhotoDetail(photoId);

    final hasPreview =
        _photoIdFromMap(selectedPhoto) == photoId && selectedPhoto.isNotEmpty;
    unawaited(loadQuickEmojis());
    unawaited(loadAvailableEmojis());
    unawaited(loadPhotoComments(photoId, silent: true));

    if (!hasPreview) {
      unawaited(loadPhotoDetails(photoId, silent: false));
    } else {
      unawaited(loadPhotoDetails(photoId, silent: true));
    }
  }

  bool _photoDetailNeedsUpdate(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) {
    const keys = [
      'updated_at',
      'like_count',
      'comment_count',
      'testimony',
      'file_path',
      'status',
      'user_name',
    ];
    for (final key in keys) {
      if (local[key] != remote[key]) return true;
    }
    return false;
  }

  void _mergePhotoFields(Map<String, dynamic> remote) {
    var changed = false;
    for (final entry in remote.entries) {
      if (selectedPhoto[entry.key] != entry.value) {
        selectedPhoto[entry.key] = entry.value;
        changed = true;
      }
    }
    if (changed) {
      selectedPhoto.refresh();
    }
  }

  Future<void> _cacheGalleryList() async {
    if (_allPhotos.isEmpty) return;
    final approved = _allPhotos
        .where((p) =>
            (p['status'] ?? 'Approved').toString().toLowerCase() == 'approved')
        .toList();
    final snapshot = List<Map<String, dynamic>>.from(
      approved.isNotEmpty ? approved : _allPhotos,
    );
    await HiveCacheService.cacheList(
      _galleryListHiveKey,
      snapshot,
      expiryHours: 24,
    );
    final homeSlice = snapshot.take(12).toList();
    if (homeSlice.isNotEmpty) {
      await HiveCacheService.cacheList(
        'home_gallery_photos',
        homeSlice,
        expiryHours: 24,
      );
    }
  }

  List<Map<String, dynamic>> _mergeApprovedAndPending(
    List<Map<String, dynamic>> approved,
    List<Map<String, dynamic>> pending,
  ) {
    final merged = <Map<String, dynamic>>[];
    final seenIds = <dynamic>{};

    for (final photo in approved) {
      final id = photo['id'];
      if (id == null || seenIds.contains(id)) continue;
      seenIds.add(id);
      merged.add(photo);
    }

    for (final photo in pending) {
      final id = photo['id'];
      if (id == null || seenIds.contains(id)) continue;
      seenIds.add(id);
      merged.add(photo);
    }

    return merged;
  }

  bool _shouldIncludePendingPhotos() {
    return filterUserId.value == 0 && userId.value > 0;
  }

  /// Load photos
  Future<void> loadPhotos({bool refresh = false, bool silent = false}) async {
    if (filterUserId.value > 0) {
      refresh = true;
    }

    await _ensureUserId();

    if (_isLoading) {
      if (_activeLoadCompleter != null) {
        await _activeLoadCompleter!.future;
      }
      if (_allPhotos.isNotEmpty) {
        _applyClientSideFilter();
      }
      return;
    }

    if (_isDataLoaded && !refresh && _allPhotos.isNotEmpty) {
      _applyClientSideFilter();
      return;
    }

    if (silent &&
        _lastSyncedAt != null &&
        DateTime.now().difference(_lastSyncedAt!) < _minSyncInterval) {
      if (_allPhotos.isNotEmpty) {
        _applyClientSideFilter();
      }
      return;
    }

    final generation = silent ? _loadGeneration : ++_loadGeneration;
    _activeLoadCompleter = Completer<void>();

    if (refresh) {
      currentPage.value = 0;
      if (!silent) {
        _isDataLoaded = false;
        photos.clear();
      }
    }

    _isLoading = true;
    if (!silent) {
      isLoading.value = true;
    }
    message.value = '';

    try {
      // Performance: Always load ALL photos (no fruit tag filter) to populate cache
      // Then apply client-side filtering for instant updates
      final photosList = await GalleryService.getPhotos(
        status: 'Approved', // Only approved photos from main call
        fruitTag: null, // Always load all photos for cache
        userId: filterUserId.value > 0 ? filterUserId.value : null,
        currentUserId: userId.value > 0 ? userId.value : null,
        limit: filterUserId.value > 0 ? itemsPerPage : 40,
        offset: currentPage.value * itemsPerPage,
      );

      if (generation != _loadGeneration) {
        return;
      }

      if (refresh || currentPage.value == 0) {
        var pendingPhotos = <Map<String, dynamic>>[];

        if (_shouldIncludePendingPhotos()) {
          try {
            pendingPhotos = await GalleryService.getPhotos(
              status: 'Pending',
              fruitTag: null,
              userId: userId.value,
              currentUserId: userId.value,
              limit: 10,
              offset: 0,
            );
          } catch (e) {
            print('Error loading pending photos: $e');
          }
        }

        if (!silent && generation != _loadGeneration) {
          return;
        }

        final mergedPhotos = _mergeApprovedAndPending(photosList, pendingPhotos);
        _allPhotos = mergedPhotos.where((p) {
          final id = _photoIdFromMap(p);
          return id == null || !_deletedPhotoIds.contains(id);
        }).toList();
        _applyClientSideFilter();
      } else {
        _allPhotos.addAll(
          photosList.where((p) {
            final id = _photoIdFromMap(p);
            return id == null || !_deletedPhotoIds.contains(id);
          }),
        );
        // Apply current filter to display
        _applyClientSideFilter();
      }
      
      // Force UI refresh to ensure changes are visible
      photos.refresh();
      
      _isDataLoaded = true;
      _lastSyncedAt = DateTime.now();
      unawaited(_cacheGalleryList());
    } catch (e) {
      String errorMessage = e.toString().replaceAll('Exception: ', '');
      if (errorMessage.contains('No internet') || errorMessage.contains('NetworkException')) {
        message.value = 'No internet connection. Please check your network and try again.';
      } else if (errorMessage.contains('timeout') || errorMessage.contains('Timeout')) {
        message.value = 'Request timeout. Please try again.';
      } else {
        message.value = 'Error loading photos: ${errorMessage.length > 50 ? errorMessage.substring(0, 50) + '...' : errorMessage}';
      }
      print('Error loading photos: $e');
      if (!silent && (refresh || currentPage.value == 0) && _allPhotos.isEmpty) {
        photos.value = [];
      } else if (_allPhotos.isNotEmpty) {
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

  /// Load more photos (pagination)
  Future<void> loadMore() async {


    if (isLoading.value) return;

    currentPage.value++;
    await loadPhotos();
  }

  /// Load single photo with comments (silent = no blocking spinner if preview exists).
  Future<void> loadPhotoDetails(
    int photoId, {
    bool silent = false,
    bool force = false,
  }) async {
    if (silent &&
        !force &&
        _detailsLastSyncedAt != null &&
        _photoIdFromMap(selectedPhoto) == photoId &&
        DateTime.now().difference(_detailsLastSyncedAt!) < _detailsMinSyncInterval) {
      return;
    }

    final generation = silent ? _detailsLoadGeneration : ++_detailsLoadGeneration;
    final hadPreview =
        _photoIdFromMap(selectedPhoto) == photoId && selectedPhoto.isNotEmpty;

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

      final photo = await GalleryService.getPhotoDetails(
        photoId,
        currentUserId: userId.value > 0 ? userId.value : null,
      );

      if (generation != _detailsLoadGeneration) {
        return;
      }

      if (silent &&
          hadPreview &&
          !force &&
          !_photoDetailNeedsUpdate(selectedPhoto, photo)) {
        _detailsLastSyncedAt = DateTime.now();
        unawaited(loadPhotoComments(photoId, silent: true));
        return;
      }

      if (silent && hadPreview) {
        _mergePhotoFields(photo);
      } else {
        selectedPhoto.value = photo;
      }

      _detailsLastSyncedAt = DateTime.now();
      unawaited(_cachePhotoDetailSnapshot(photoId));

      if (photo['comments'] != null && (photo['comments'] as List).isNotEmpty) {
        await _processComments(
          List<Map<String, dynamic>>.from(photo['comments']),
        );
      } else {
        unawaited(loadPhotoComments(photoId, silent: silent));
      }
    } catch (e) {
      if (!silent || !hadPreview) {
        message.value =
            'Error loading photo: ${e.toString().replaceAll('Exception: ', '')}';
      }
      print('Error loading photo details: $e');
    } finally {
      isLoading.value = false;
      isDetailsSilentSyncing.value = false;
    }
  }

  /// Load photo comments (fast path: gallery API, fallback comments API).
  Future<void> loadPhotoComments(int photoId, {bool silent = false}) async {
    if (userId.value == 0) {
      await _loadUserId();
    }

    try {
      final comments = await _fetchPhotoComments(photoId);
      await _processComments(comments);
      if (silent) {
        unawaited(_loadEmojiReactionsFromUsage(photoId));
      } else {
        await _loadEmojiReactionsFromUsage(photoId);
      }
      unawaited(_cachePhotoDetailSnapshot(photoId));
      _deletedCommentIds.removeWhere(
        (id) => !_commentExistsInList(photoComments, id),
      );
    } catch (e) {
      print('Error loading photo comments: $e');
      if (!silent && photoComments.isEmpty) {
        photoComments.value = [];
      }
    }
  }

  Future<List<Map<String, dynamic>>> _fetchPhotoComments(int photoId) async {
    try {
      final rawComments = await GalleryService.getComments(
        photoId: photoId,
        userId: userId.value > 0 ? userId.value : null,
      );
      final validComments = rawComments
          .where(
            (item) =>
                item.containsKey('content') && !item.containsKey('type'),
          )
          .toList();
      if (validComments.isNotEmpty || rawComments.isEmpty) {
        return validComments;
      }
    } catch (_) {}

    return CommentsService.getComments(
      postType: 'gallery',
      postId: photoId,
      userId: userId.value > 0 ? userId.value : null,
    );
  }

  /// Load emoji reactions from emoji_usage table and merge with comments
  /// This is needed because backend might save emoji to emoji_usage but not create comments
  /// IMPORTANT: On reload, this should REPLACE existing reactions, not merge
  Future<void> _loadEmojiReactionsFromUsage(int photoId) async {
    try {
      print('🍎 GALLERY EMOJI: 🔄 Loading emoji reactions from emoji_usage table...');
      print('📊 📋 TABLE: emoji_usage - Fetching reactions from database');
      
      // Try both 'photo' and 'gallery' post types
      List<Map<String, dynamic>> reactions = [];
      
      try {
        reactions = await EmojisService.getEmojiReactions(
          postType: 'photo',
          postId: photoId,
        );
        print('🍎 GALLERY EMOJI: ✅ Loaded ${reactions.length} reactions with post_type="photo" from emoji_usage table');
      } catch (e) {
        print('🍎 GALLERY EMOJI: ⚠️ Failed to load with post_type="photo": $e');
        try {
          reactions = await EmojisService.getEmojiReactions(
            postType: 'gallery',
            postId: photoId,
          );
          print('🍎 GALLERY EMOJI: ✅ Loaded ${reactions.length} reactions with post_type="gallery" from emoji_usage table');
        } catch (e2) {
          print('🍎 GALLERY EMOJI: ⚠️ Failed to load with post_type="gallery": $e2');
          print('🍎 GALLERY EMOJI: ⚠️ API might not support getEmojiReactions endpoint yet');
        }
      }
      
      if (reactions.isNotEmpty) {
        print('🍎 GALLERY EMOJI: 📊 Processing ${reactions.length} items from emoji_usage table...');
        
        // Check if API returned reactions or emoji list
        // Reactions should have: emoji, user_id, user_name, profile_photo, created_at
        // Emoji list has: id, name, image_url, usage_count, etc.
        final firstItem = reactions.first;
        final hasReactionFields = firstItem.containsKey('emoji') || firstItem.containsKey('user_id');
        final hasEmojiFields = firstItem.containsKey('id') && firstItem.containsKey('name') && firstItem.containsKey('image_url');
        
        print('🍎 GALLERY EMOJI: 🔍 Checking response structure...');
        print('🍎 GALLERY EMOJI:   - Has reaction fields (emoji/user_id): $hasReactionFields');
        print('🍎 GALLERY EMOJI:   - Has emoji fields (id/name/image_url): $hasEmojiFields');
        print('🍎 GALLERY EMOJI:   - First item keys: ${firstItem.keys.toList()}');
        print('🍎 GALLERY EMOJI:   - First item: $firstItem');
        
        if (!hasReactionFields && hasEmojiFields) {
          print('🍎 GALLERY EMOJI: ⚠️ API returned emoji LIST instead of reactions!');
          print('🍎 GALLERY EMOJI: ⚠️ Backend API endpoint get_reactions is not working correctly');
          print('🍎 GALLERY EMOJI: ⚠️ This means backend needs to fix the get_reactions endpoint');
          print('🍎 GALLERY EMOJI: ⚠️ Expected: reactions with emoji, user_id, user_name, etc.');
          print('🍎 GALLERY EMOJI: ⚠️ Got: emoji list with id, name, image_url, etc.');
          // Don't process emoji list as reactions
          return;
        }
        
        // IMPORTANT: Create NEW reactions map from table data (don't merge with existing)
        // This ensures we show what's actually in the database, not local state
        final tableReactions = <String, List<Map<String, dynamic>>>{};
        
        // Process each reaction from table
        for (var reaction in reactions) {
          // Try multiple field names for emoji value
          final emoji = reaction['emoji'] as String? ?? 
                       reaction['emoji_value'] as String? ?? 
                       reaction['image_url'] as String? ?? 
                       '';
          final emojiKey = emoji.trim();
          
          if (emojiKey.isNotEmpty) {
            // Initialize if not exists
            if (!tableReactions.containsKey(emojiKey)) {
              tableReactions[emojiKey] = [];
              print('🍎 GALLERY EMOJI: ✅ Created new emoji reaction entry for key: "$emojiKey"');
            }
            
            // Add user info (avoid duplicates)
            final userId = reaction['user_id'];
            if (userId != null) {
              final existingUser = tableReactions[emojiKey]!.any((u) => u['user_id'] == userId);
              
              if (!existingUser) {
                tableReactions[emojiKey]!.add({
                  'user_id': userId,
                  'user_name': reaction['user_name'] ?? reaction['name'] ?? 'Anonymous',
                  'profile_photo': reaction['profile_photo'] ?? reaction['profile_image'],
                  'created_at': reaction['created_at'] ?? reaction['timestamp'],
                });
                print('🍎 GALLERY EMOJI: ✅ Added emoji reaction from emoji_usage table: "$emojiKey" by ${reaction['user_name'] ?? reaction['name'] ?? 'Anonymous'} (total: ${tableReactions[emojiKey]!.length})');
              }
            }
          }
        }
        
        // IMPORTANT: REPLACE existing reactions with table data (not merge)
        // This ensures reload shows what's actually in database
        photoEmojiReactions.value = Map<String, List<Map<String, dynamic>>>.from(tableReactions);
        print('🍎 GALLERY EMOJI: ✅ Loaded ${tableReactions.length} emoji reaction types from emoji_usage table');
        for (var key in photoEmojiReactions.keys) {
          print('🍎 GALLERY EMOJI:   - Key: "$key" (${photoEmojiReactions[key]!.length} users)');
        }
      } else {
        print('🍎 GALLERY EMOJI: ⚠️ No reactions found in emoji_usage table for photo_id=$photoId');
        // Clear reactions if none found in table
        photoEmojiReactions.value = <String, List<Map<String, dynamic>>>{};
      }
    } catch (e) {
      print('🍎 GALLERY EMOJI: ❌ Error loading emoji reactions from usage: $e');
      // On error, clear reactions to ensure we don't show stale data
      photoEmojiReactions.value = <String, List<Map<String, dynamic>>>{};
    }
  }

  /// Process comments list - separate emoji reactions from text comments
  /// EXACTLY same logic as prayers_controller
  Future<void> _processComments(List<Map<String, dynamic>> comments) async {
    // Separate emoji reactions from text comments (EXACTLY same as prayers_controller)
    final textComments = <Map<String, dynamic>>[];
    final emojiReactions = <String, List<Map<String, dynamic>>>{};
    
    print('🔄 Processing ${comments.length} comments to separate emoji reactions...');
    
    // Debug: Log all comment contents first
    for (var i = 0; i < comments.length; i++) {
      final comment = comments[i];
      final content = comment['content'] as String? ?? '';
      final commentId = comment['id'];
      print('🍎 GALLERY EMOJI: 📋 Comment ${i + 1}: id=$commentId, content="${content.length > 100 ? content.substring(0, 100) + '...' : content}"');
    }
    
    for (var comment in comments) {
      if (_isCommentDeleted(comment)) {
        continue;
      }

      final content = comment['content'] as String? ?? '';
      final trimmed = content.trim();
      final parentId = comment['parent_comment_id'];
      final commentId = comment['id'];
      
      // Debug: Check if this is a reply (same as prayers)
      if (parentId != null && parentId != 0) {
        print('🔗 Found reply in main list: comment_id=$commentId, parent_comment_id=$parentId');
        print('   ⚠️ WARNING: This reply should NOT be in the main comments list!');
        print('   ⚠️ Backend should only return top-level comments with replies in replies array');
        // Skip this - it's a reply that should be in parent's replies array
        continue;
      }
      
      // Check if content is an emoji reaction
      // EXACTLY same logic as prayers_controller
      // Can be: emoji character (😊), emoji code (joy_01), image URL, or emoji ID
      bool isEmojiReaction = false;
      String? emojiKey;
      
      print('🍎 GALLERY EMOJI: 🔍 Processing comment content: "$trimmed"');
      
      // Strategy 1: Check if it's an emoji character (length <= 4) - SAME AS PRAYERS
      if (trimmed.length <= 4 && _isEmoji(trimmed)) {
        isEmojiReaction = true;
        emojiKey = trimmed;
        print('🍎 GALLERY EMOJI: ✅ Found emoji reaction (character): $emojiKey');
      }
      // Strategy 2: Check if it's an emoji code (like "joy_01", "kindness_peach_01") - SAME AS PRAYERS
      else if (trimmed.contains('_') && (trimmed.contains('joy') || trimmed.contains('peace') || 
               trimmed.contains('love') || trimmed.contains('patience') || trimmed.contains('kindness') ||
               trimmed.contains('goodness') || trimmed.contains('faithfulness') || trimmed.contains('gentleness') ||
               trimmed.contains('meekness') || trimmed.contains('self') || trimmed.contains('control'))) {
        isEmojiReaction = true;
        emojiKey = trimmed;
        print('🍎 GALLERY EMOJI: ✅ Found emoji reaction (code): $emojiKey');
      }
      // Strategy 3: Check if it's an image URL (contains "uploads/emojis" or "emojis/") - SAME AS PRAYERS
      else if (trimmed.contains('uploads/emojis/') || trimmed.contains('emojis/') || 
               trimmed.contains('.png') || trimmed.contains('.jpg') ||
               trimmed.contains('https://') || trimmed.contains('http://')) {
        isEmojiReaction = true;
        // Use the full URL as key (including URL encoding like %20) for exact matching
        // This ensures we match exactly what the backend returns
        emojiKey = trimmed;
        print('🍎 GALLERY EMOJI: ✅ Found emoji reaction (image URL): $emojiKey');
        print('🍎 GALLERY EMOJI:   - URL length: ${emojiKey.length}');
        print('🍎 GALLERY EMOJI:   - Contains uploads/emojis: ${emojiKey.contains('uploads/emojis/')}');
      }
      // Strategy 4: Check if it's a numeric ID (emoji_id) - SAME AS PRAYERS
      else if (trimmed.isNotEmpty && trimmed.length <= 10 && int.tryParse(trimmed) != null) {
        isEmojiReaction = true;
        emojiKey = trimmed;
        print('🍎 GALLERY EMOJI: ✅ Found emoji reaction (ID): $emojiKey');
      }
      // Strategy 5: Check if it's a fruit name (like "Joy", "Peace", "Patience")
      else {
        final fruitNames = ['joy', 'peace', 'love', 'patience', 'kindness', 'goodness', 
                           'faithfulness', 'gentleness', 'meekness', 'self-control', 'self control'];
        final trimmedLower = trimmed.toLowerCase();
        if (fruitNames.any((fruit) => trimmedLower == fruit || trimmedLower.contains(fruit))) {
          isEmojiReaction = true;
          emojiKey = trimmed;
          print('🍎 GALLERY EMOJI: ✅ Found emoji reaction (fruit name): $emojiKey');
        }
      }
      
      // FIX: Add ALL top-level comments to textComments (including emoji comments)
      // Emoji reactions and emoji comments are both stored in comments table
      // The UI (FruitEmojiHelper.buildCommentText) will render emoji URLs as images
      if (parentId == null || parentId == 0) {
        // Check if replies array exists and log it
        final replies = comment['replies'];
        final replyCount = replies != null ? (replies as List).length : 0;
        print('📝 Found top-level comment: id=$commentId, replies=$replyCount, content="${trimmed.substring(0, trimmed.length > 30 ? 30 : trimmed.length)}..."');
        if (replyCount > 0) {
          print('   ✅ Replies found in replies array:');
          for (var i = 0; i < (replies as List).length; i++) {
            final reply = (replies as List)[i];
            print('      - Reply ${i + 1}: id=${reply['id']}, content=${(reply['content'] as String? ?? '').substring(0, (reply['content'] as String? ?? '').length > 30 ? 30 : (reply['content'] as String? ?? '').length)}...');
          }
        }
        
        // ✅ ADD TO COMMENTS LIST (including emoji comments)
        textComments.add(comment);
        print('✅ Added to photoComments: id=$commentId, isEmoji=$isEmojiReaction');
        
        // Also track emoji reactions separately for the reactions bar (if it's an emoji)
        if (isEmojiReaction && emojiKey != null) {
          if (!emojiReactions.containsKey(emojiKey)) {
            emojiReactions[emojiKey] = [];
            print('🍎 GALLERY EMOJI: ✅ Created new emoji reaction entry for key: "$emojiKey"');
          }
          emojiReactions[emojiKey]!.add({
            'user_id': comment['user_id'],
            'user_name': comment['user_name'] ?? 'Anonymous',
            'profile_photo': comment['profile_photo'],
            'created_at': comment['created_at'],
          });
          print('🍎 GALLERY EMOJI: ✅ Also added to emojiReactions: "$emojiKey" by ${comment['user_name']}');
        }
      } else {
        print('⏭️ Skipping reply (will be shown in parent comment): id=$commentId, parent=$parentId');
      }
    }
    
    print('📊 Loaded ${emojiReactions.length} emoji reaction types and ${textComments.length} top-level comments');
    for (var emoji in emojiReactions.keys) {
      print('   - $emoji: ${emojiReactions[emoji]!.length} reactions');
    }
    
      // Sort comments by created_at in increasing order (oldest first)
      textComments.sort((a, b) {
        final aTime = a['created_at'] as String? ?? '';
        final bTime = b['created_at'] as String? ?? '';
        try {
          final aDate = DateTime.parse(aTime.contains('T') ? aTime : '${aTime}T00:00:00Z');
          final bDate = DateTime.parse(bTime.contains('T') ? bTime : '${bTime}T00:00:00Z');
          return aDate.compareTo(bDate);
        } catch (e) {
          return aTime.compareTo(bTime);
        }
      });
      
      // Update reactive variables - EXACTLY LIKE PRAYERS
      photoComments.value = textComments
          .where((c) => !_isCommentDeleted(c))
          .map(_filterDeletedFromTree)
          .toList();
      photoComments.refresh();
      
      print('🍎 GALLERY EMOJI: 📊 Processing complete:');
      print('🍎 GALLERY EMOJI:   - Text comments: ${textComments.length}');
      print('🍎 GALLERY EMOJI:   - Emoji reactions: ${emojiReactions.length}');
      print('🍎 GALLERY EMOJI:   - Emoji reaction keys: ${emojiReactions.keys.toList()}');
      
      // Merge with existing reactions (from optimistic updates or emoji_usage)
      // IMPORTANT: Preserve ALL existing reactions, don't overwrite!
      final existingReactions = Map<String, List<Map<String, dynamic>>>.from(photoEmojiReactions);
      
      print('🍎 GALLERY EMOJI: 🔄 Merging reactions:');
      print('🍎 GALLERY EMOJI:   - Existing reactions count: ${existingReactions.length}');
      print('🍎 GALLERY EMOJI:   - New reactions from comments: ${emojiReactions.length}');
      
      // Merge emoji reactions from comments with existing reactions
      for (var emojiKey in emojiReactions.keys) {
        if (!existingReactions.containsKey(emojiKey)) {
          existingReactions[emojiKey] = [];
          print('🍎 GALLERY EMOJI:   ✅ Added new emoji key: "$emojiKey"');
        } else {
          print('🍎 GALLERY EMOJI:   ✅ Merging into existing key: "$emojiKey"');
        }
        // Add users from comments, avoiding duplicates
        for (var user in emojiReactions[emojiKey]!) {
          final userId = user['user_id'];
          final existingUser = existingReactions[emojiKey]!.any((u) => u['user_id'] == userId);
          if (!existingUser) {
            existingReactions[emojiKey]!.add(user);
            print('🍎 GALLERY EMOJI:     ✅ Added user: ${user['user_name']}');
          } else {
            print('🍎 GALLERY EMOJI:     ⏭️ Skipped duplicate user: ${user['user_name']}');
          }
        }
      }
      
      // IMPORTANT: Preserve ALL existing reactions that are NOT in comments
      // This ensures optimistic updates and emoji_usage reactions are not lost
      for (var existingKey in existingReactions.keys) {
        if (!emojiReactions.containsKey(existingKey)) {
          print('🍎 GALLERY EMOJI:   ✅ Preserved existing reaction key: "$existingKey" (${existingReactions[existingKey]!.length} users)');
        }
      }
      
      // Force a new map instance to ensure GetX detects the change
      photoEmojiReactions.value = Map<String, List<Map<String, dynamic>>>.from(existingReactions);
      
      print('🍎 GALLERY EMOJI: ✅ photoEmojiReactions.value updated. Final count: ${photoEmojiReactions.length}');
      if (photoEmojiReactions.isNotEmpty) {
        for (var key in photoEmojiReactions.keys) {
          print('🍎 GALLERY EMOJI:   - Key: "$key" (${photoEmojiReactions[key]!.length} users)');
        }
      } else {
        print('🍎 GALLERY EMOJI: ⚠️ WARNING: photoEmojiReactions is EMPTY after processing!');
        print('🍎 GALLERY EMOJI: 💡 This might mean:');
        print('🍎 GALLERY EMOJI:   1. Backend is not creating comments for emoji reactions');
        print('🍎 GALLERY EMOJI:   2. Backend get_reactions endpoint is not working');
        print('🍎 GALLERY EMOJI:   3. Optimistic update should still show the emoji in UI');
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
      return emojiRegex.hasMatch(char) || 
             rune == 0xFE0F || 
             rune == 0x200D;
    });
    
    return hasEmoji && hasOnlyEmoji;
  }

  /// Upload photo
  Future<bool> uploadPhoto({
    required File photoFile,
    String? fruitTag,
    String? testimony,
    String? feelingTags,
    String? hashtags,
    bool allowComments = true,
  }) async {
    if (userId.value == 0) {
      await _loadUserId();
    }

    if (userId.value == 0) {
      message.value = 'Please login first';
      return false;
    }

    // Check for inappropriate content
    if (testimony != null && testimony.isNotEmpty) {
      final check = ContentModerationService.checkContent(testimony);
      if (!check['isClean']) {
        message.value = 'Testimony: ${check['message']}';
        _showModerationSnackbar(check['message']);
        return false;
      }
    }

    if (feelingTags != null && feelingTags.isNotEmpty) {
      final check = ContentModerationService.checkContent(feelingTags);
      if (!check['isClean']) {
        message.value = 'Feeling Tags: ${check['message']}';
        _showModerationSnackbar(check['message']);
        return false;
      }
    }

    if (hashtags != null && hashtags.isNotEmpty) {
      final check = ContentModerationService.checkContent(hashtags);
      if (!check['isClean']) {
        message.value = 'Hashtags: ${check['message']}';
        _showModerationSnackbar(check['message']);
        return false;
      }
    }

    isLoading.value = true;
    message.value = 'Uploading photo...';

    try {
      await GalleryService.uploadPhoto(
        userId: userId.value,
        photoFile: photoFile,
        fruitTag: fruitTag,
        testimony: testimony,
        feelingTags: feelingTags,
        hashtags: hashtags,
        allowComments: allowComments,
      );
      
      message.value = 'Photo uploaded successfully. Waiting for admin approval.';
      
      // Reload photos
      await loadPhotos(refresh: true);
      
      return true;
    } catch (e) {
      message.value = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      print('Error uploading photo: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
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
      for (final existing in photoComments) {
        if (_commentIdFromMap(existing) == parentCommentId) {
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
      photoComments.value = updated;
      return;
    }

    photoComments.add(comment);
  }

  void _replaceTempCommentId(int tempId, int realId) {
    final updated = <Map<String, dynamic>>[];
    for (final comment in photoComments) {
      final copy = Map<String, dynamic>.from(comment);
      if (_commentIdFromMap(copy) == tempId) {
        copy['id'] = realId;
      }
      final replies = copy['replies'];
      if (replies is List && replies.isNotEmpty) {
        copy['replies'] = replies
            .whereType<Map>()
            .map((r) {
              final reply = Map<String, dynamic>.from(r);
              if (_commentIdFromMap(reply) == tempId) {
                reply['id'] = realId;
              }
              return reply;
            })
            .toList();
      }
      updated.add(copy);
    }
    photoComments.value = updated;
  }

  Future<int> _submitPhotoCommentToServer({
    required int photoId,
    required String content,
    int? parentCommentId,
  }) async {
    try {
      return await GalleryService.addComment(
        userId: userId.value,
        photoId: photoId,
        content: content,
        parentCommentId: parentCommentId,
      );
    } catch (_) {
      return CommentsService.addComment(
        userId: userId.value,
        postType: 'gallery',
        postId: photoId,
        content: content,
        parentCommentId: parentCommentId,
      );
    }
  }

  Future<void> _submitCommentToServer({
    required int photoId,
    required String content,
    required int tempId,
    int? parentCommentId,
  }) async {
    try {
      final commentId = await _submitPhotoCommentToServer(
        photoId: photoId,
        content: content,
        parentCommentId: parentCommentId,
      );
      if (commentId > 0) {
        _replaceTempCommentId(tempId, commentId);
        photoComments.refresh();
      }
      unawaited(_cachePhotoDetailSnapshot(photoId));
      unawaited(loadPhotoComments(photoId, silent: true));
    } catch (e) {
      _removeCommentLocally(tempId);
      photoComments.refresh();
      message.value = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
    }
  }

  /// Add comment to photo (optimistic — shows instantly in thread).
  Future<bool> addComment(int photoId, String content, {int? parentCommentId}) async {
    if (userId.value == 0) {
      await _loadUserId();
    }

    if (userId.value == 0) {
      message.value = 'Please login first';
      return false;
    }

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
    photoComments.refresh();
    unawaited(
      _submitCommentToServer(
        photoId: photoId,
        content: content,
        tempId: tempId,
        parentCommentId: parentCommentId,
      ),
    );
    return true;
  }

  /// Toggle comment like
  Future<bool> toggleCommentLike(int commentId) async {
    if (userId.value == 0) {
      await _loadUserId();
    }

    if (userId.value == 0) {
      message.value = 'Please login first';
      return false;
    }

    try {
      await CommentsService.toggleCommentLike(
        userId: userId.value,
        commentId: commentId,
      );
      
      final photoId = selectedPhoto['id'] as int?;
      if (photoId != null && photoId > 0) {
        await loadPhotoComments(photoId, silent: true);
        photoComments.refresh();
        photoEmojiReactions.refresh();
      }
      
      return true;
    } catch (e) {
      message.value = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      print('Error toggling comment like: $e');
      return false;
    }
  }

  /// Report comment
  Future<bool> reportComment(int commentId, String reason) async {
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

  /// Set initial data from cache
  void setInitialData(List<Map<String, dynamic>> data) {
    if (data.isNotEmpty) {
      _allPhotos = List<Map<String, dynamic>>.from(data);
      _isDataLoaded = true;
      _applyClientSideFilter();
    }
  }

  /// Apply client-side filter instantly (no API call)
  void _applyClientSideFilter() {
    if (_allPhotos.isEmpty) {
      photos.value = [];
      photos.refresh();
      return;
    }

    var filtered = _allPhotos
        .where((photo) {
          final id = _photoIdFromMap(photo);
          return id == null || !_deletedPhotoIds.contains(id);
        })
        .map((p) => Map<String, dynamic>.from(p))
        .toList();

    if (filterUserId.value > 0) {
      filtered = filtered
          .where((photo) => photo['user_id']?.toString() == filterUserId.value.toString())
          .toList();
    }

    if (selectedFruitTag.value.isNotEmpty) {
      filtered = filtered.where((photo) {
        final photoFruitTag = photo['fruit_tag'] as String? ?? '';
        return photoFruitTag.toLowerCase() == selectedFruitTag.value.toLowerCase();
      }).toList();
    }

    photos.value = filtered;
    photos.refresh();
  }

  /// Filter by fruit tag - Instant client-side filtering only (no API call if data exists)
  void filterByFruitTag(String fruitTag) {
    // Performance: Only filter if fruit tag is actually changing
    if (selectedFruitTag.value != fruitTag) {
      selectedFruitTag.value = fruitTag;
      
      // If "All" is selected and we have cached data, show all instantly
      if (fruitTag.isEmpty && _allPhotos.isNotEmpty) {
        _applyClientSideFilter();
        return;
      }
      
      // If specific fruit tag selected and we have cached data, filter instantly
      if (_allPhotos.isNotEmpty) {
        _applyClientSideFilter();
        return;
      }
      
      // Only load from API if no cached data exists
      if (_allPhotos.isEmpty) {
        _isDataLoaded = false;
        loadPhotos(refresh: true);
      }
    }
  }

  /// Clear filter - Instant client-side filtering only (no API call if data exists)
  void clearFilter() {
    // Performance: Only clear if filter is actually set
    if (selectedFruitTag.value.isNotEmpty) {
      selectedFruitTag.value = '';
      
      // Show all photos instantly from cached data (no API call)
      if (_allPhotos.isNotEmpty) {
        _applyClientSideFilter();
        return;
      }
      
      // Only load from API if no cached data exists
      if (_allPhotos.isEmpty) {
        _isDataLoaded = false;
        loadPhotos(refresh: true);
      }
    }
  }

  /// Refresh data
  Future<void> refresh() async {
    await loadPhotos(refresh: true);
  }

  /// Toggle like on photo
  Future<bool> toggleLike(int photoId) async {
    if (userId.value == 0) {
      await _loadUserId();
    }

    if (userId.value == 0) {
      message.value = 'Please login first';
      return false;
    }

    try {
      final response = await GalleryService.toggleLike(
        userId: userId.value,
        photoId: photoId,
      );

      final liked = response['liked'] == true;
      if (_photoIdFromMap(selectedPhoto) == photoId) {
        selectedPhoto['is_liked'] = liked;
        final rawCount = selectedPhoto['like_count'];
        var count = rawCount is int ? rawCount : int.tryParse('$rawCount') ?? 0;
        if (response['like_count'] != null) {
          count = response['like_count'] is int
              ? response['like_count'] as int
              : int.tryParse('${response['like_count']}') ?? count;
        } else {
          count = liked ? count + 1 : (count > 0 ? count - 1 : 0);
        }
        selectedPhoto['like_count'] = count;
        selectedPhoto.refresh();
        unawaited(_cachePhotoDetailSnapshot(photoId));
      }
      unawaited(loadPhotos(refresh: true, silent: true));

      return liked;
    } catch (e) {
      message.value = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      print('Error toggling like: $e');
      return false;
    }
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
    } catch (e) {
      print('Error loading emojis: $e');
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

  Future<void> _toggleEmojiReactionLocally(String emoji) async {
    final user = await UserStorage.getUser();
    final key = emoji.trim();
    final reactions =
        Map<String, List<Map<String, dynamic>>>.from(photoEmojiReactions);
    final list = reactions.putIfAbsent(key, () => []);
    final idx = list.indexWhere((u) => u['user_id'] == userId.value);
    if (idx >= 0) {
      list.removeAt(idx);
      if (list.isEmpty) reactions.remove(key);
    } else {
      list.add({
        'user_id': userId.value,
        'user_name': user?['name'] ?? 'You',
        'profile_photo': user?['profile_photo'],
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    }
    photoEmojiReactions.value = reactions;
    photoEmojiReactions.refresh();
  }

  /// Add/Remove emoji reaction to photo (TOGGLE) — instant UI, background sync.
  Future<bool> addEmojiReaction(int photoId, String emoji) async {
    if (userId.value == 0) {
      await _loadUserId();
    }

    if (userId.value == 0) {
      message.value = 'Please login first';
      return false;
    }

    await _toggleEmojiReactionLocally(emoji);

    try {
      try {
        await EmojisService.useEmoji(
          userId: userId.value,
          emoji: emoji,
          postType: 'photo',
          postId: photoId,
        );
      } catch (_) {
        await EmojisService.useEmoji(
          userId: userId.value,
          emoji: emoji,
          postType: 'gallery',
          postId: photoId,
        );
      }

      unawaited(_cachePhotoDetailSnapshot(photoId));
      unawaited(loadPhotoComments(photoId, silent: true));
      return true;
    } catch (e) {
      await _toggleEmojiReactionLocally(emoji);
      message.value = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      return false;
    }
  }

  
  /// Show moderation snackbar
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

    photoComments.removeWhere((c) => _commentIdFromMap(c) == commentId);

    final updated = <Map<String, dynamic>>[];
    for (final comment in photoComments) {
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
    photoComments.value = updated;
  }

  Future<void> _deleteCommentOnServer(int photoId, int commentId) async {
    try {
      try {
        await GalleryService.deleteComment(
          userId: userId.value,
          commentId: commentId,
        );
      } catch (_) {
        await CommentsService.deleteComment(
          userId: userId.value,
          commentId: commentId,
          postType: 'gallery',
        );
      }
      await _cachePhotoDetailSnapshot(photoId);
    } catch (e) {
      _deletedCommentIds.remove(commentId);
      message.value = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      await loadPhotoComments(photoId, silent: true);
      photoComments.refresh();
    }
  }

  void _removePhotoLocally(int photoId) {
    _deletedPhotoIds.add(photoId);
    _allPhotos.removeWhere((p) => _photoIdFromMap(p) == photoId);
    photos.removeWhere((p) => _photoIdFromMap(p) == photoId);
    photos.refresh();
    if (_photoIdFromMap(selectedPhoto) == photoId) {
      selectedPhoto.clear();
      photoComments.clear();
      photoEmojiReactions.clear();
    }
    unawaited(HiveCacheService.clearKey(_photoDetailHiveKey(photoId)));
    unawaited(_cacheGalleryList());
    _syncHomeGalleryAfterDelete(photoId);
  }

  void _syncHomeGalleryAfterDelete(int photoId) {
    if (!Get.isRegistered<HomeController>()) return;
    try {
      final home = Get.find<HomeController>();
      home.galleryPhotos.removeWhere((p) => _photoIdFromMap(p) == photoId);
      home.galleryPhotos.refresh();
      unawaited(
        HiveCacheService.cacheList(
          'home_gallery_photos',
          List<Map<String, dynamic>>.from(home.galleryPhotos),
          expiryHours: 24,
        ),
      );
    } catch (_) {}
  }

  Future<void> _deletePhotoOnServer(int photoId) async {
    try {
      await GalleryService.deletePhoto(
        userId: userId.value,
        mediaId: photoId,
      );
      _deletedPhotoIds.remove(photoId);
      unawaited(loadPhotos(refresh: true, silent: true));
    } catch (e) {
      _deletedPhotoIds.remove(photoId);
      message.value = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      unawaited(loadPhotos(refresh: true, silent: true));
    }
  }

  /// Delete photo — remove locally first, sync server in background.
  Future<bool> deletePhoto(int photoId) async {
    if (userId.value == 0) {
      await _loadUserId();
    }
    if (userId.value == 0) {
      message.value = 'Please login first';
      return false;
    }
    if (photoId <= 0) return false;

    _removePhotoLocally(photoId);
    unawaited(_deletePhotoOnServer(photoId));
    return true;
  }

  /// Delete comment with instant UI update.
  Future<bool> deletePhotoComment(int photoId, int commentId) async {
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
    photoComments.refresh();
    unawaited(_cachePhotoDetailSnapshot(photoId));
    unawaited(_deleteCommentOnServer(photoId, commentId));
    return true;
  }

  static int _parsePhotoId(dynamic photoId) {
    if (photoId is int) return photoId;
    return int.tryParse('$photoId') ?? 0;
  }

  /// Pre-warm cache then open photo detail (use from any screen).
  static Future<void> openPhotoDetail(
    dynamic photoId, {
    Map<String, dynamic>? previewPhoto,
  }) async {
    final id = _parsePhotoId(photoId);
    if (id <= 0) return;

    final GalleryController controller;
    if (Get.isRegistered<GalleryController>()) {
      controller = Get.find<GalleryController>();
    } else {
      controller = Get.put(GalleryController(), permanent: true);
    }

    if (previewPhoto != null) {
      controller.selectedPhoto.value =
          Map<String, dynamic>.from(previewPhoto);
    }
    controller.bootstrapPhotoDetail(id);
    unawaited(controller.preparePhotoDetails(id));
    await PaymentGate.navigateToFeature(Routes.PHOTO_DETAILS, arguments: id);
  }

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
