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

/// Gallery Controller
/// Manages gallery photos data and operations
class GalleryController extends GetxController {
  // Observable variables
  var isLoading = false.obs;
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

  @override
  void onInit() {
    super.onInit();
    _loadUserId();
    // Don't reset filter here - it might be set before navigation
    // Filter will be reset by home screen navigation if needed
  }

  @override
  void onReady() {
    super.onReady();
    // Only load if filter is not set (normal navigation)
    // If filter is set, it means we're coming from profile, so loadPhotos will be called after navigation
    if (filterUserId.value == 0) {
      loadPhotos();
    }
    // Load emojis for reactions
    loadAvailableEmojis();
    loadQuickEmojis();
  }

  /// Load user ID from storage
  Future<void> _loadUserId() async {
    final id = await UserStorage.getUserId();
    if (id != null) {
      userId.value = id;
    }
  }

  /// Load photos
  Future<void> loadPhotos({bool refresh = false}) async {
    if (filterUserId.value > 0) {
      refresh = true;
    }
    //COMMENT THIS

    if (refresh) {
      currentPage.value = 0;
      _isDataLoaded = false; // Reset loaded flag on refresh
    }

    isLoading.value = true;
    message.value = '';

    try {
      // Performance: Always load ALL photos (no fruit tag filter) to populate cache
      // Then apply client-side filtering for instant updates
      final photosList = await GalleryService.getPhotos(
        status: filterUserId.value > 0 ? 'Pending,Approved' : 'Approved',        fruitTag: null, // Always load all photos for cache
        userId: filterUserId.value > 0 ? filterUserId.value : null,
        currentUserId: userId.value > 0 ? userId.value : null,
        limit: itemsPerPage,
        offset: currentPage.value * itemsPerPage,
      );

      if (refresh || currentPage.value == 0) {
        // Performance: Store ALL photos in cache (no filters)
        _allPhotos = List<Map<String, dynamic>>.from(photosList);
        // Apply current filter to display
        _applyClientSideFilter();
      } else {
        // Performance: Add to all photos cache
        _allPhotos.addAll(photosList);
        // Apply current filter to display
        _applyClientSideFilter();
      }
      
      // Force UI refresh to ensure changes are visible
      photos.refresh();
      
      // Performance: Mark as loaded
      _isDataLoaded = true;
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
      if (refresh || currentPage.value == 0) {
        photos.value = [];
      }
    } finally {
      isLoading.value = false;
    }
  }

  /// Load more photos (pagination)
  Future<void> loadMore() async {


    if (isLoading.value) return;

    currentPage.value++;
    await loadPhotos();
  }

  /// Load single photo with comments
  Future<void> loadPhotoDetails(int photoId) async {
    isLoading.value = true;
    message.value = '';

    try {
      // Ensure userId is loaded
      if (userId.value == 0) {
        await _loadUserId();
      }
      
      // IMPORTANT: Clear existing reactions when loading fresh data (on reload)
      // This ensures we load from table, not from local state
      print('🔄 Clearing existing emoji reactions to load fresh from table...');
      photoEmojiReactions.value = <String, List<Map<String, dynamic>>>{};
      photoComments.value = [];
      
      // Pass currentUserId to get accurate like status
      final photo = await GalleryService.getPhotoDetails(
        photoId,
        currentUserId: userId.value > 0 ? userId.value : null,
      );
      selectedPhoto.value = photo;
      
      // Check if photo details already contains comments
      if (photo['comments'] != null && (photo['comments'] as List).isNotEmpty) {
        print('✅ Found comments in photo details response: ${(photo['comments'] as List).length} comments');
        // Process comments from photo details
        await _processComments(List<Map<String, dynamic>>.from(photo['comments']));
      } else {
        // Try to load comments from API
        await loadPhotoComments(photoId);
      }
    } catch (e) {
      message.value = 'Error loading photo: ${e.toString().replaceAll('Exception: ', '')}';
      print('Error loading photo details: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Load photo comments
  Future<void> loadPhotoComments(int photoId) async {
    if (userId.value == 0) {
      await _loadUserId();
    }
    
    try {
      print('🔄 Loading photo comments for photo_id: $photoId');
      // Try multiple approaches (in order of most likely to work):
      // 1. Try gallery API directly with action='get-comments' (MOST LIKELY TO WORK)
      // 2. Try getting comments from photo details response
      // 3. Try comments API with 'photo' post_type
      // 4. Try comments API with 'gallery' post_type
      
      List<Map<String, dynamic>> comments = [];
      
      // Method 1: Try gallery API directly FIRST (most likely to work)
      try {
        print('🔄 Method 1: Trying gallery API directly with action="get-comments"...');
        print('📊 📋 TABLE: gallery_comments - Fetching from this table via gallery.php?action=get-comments');
        final rawComments = await GalleryService.getComments(
          photoId: photoId,
          userId: userId.value > 0 ? userId.value : null,
        );
        
        // Validate that we got actual comments, not photo data
        // Photo data has 'type' field, comments have 'content' field
        final validComments = <Map<String, dynamic>>[];
        for (var item in rawComments) {
          // Check if it's a comment (has 'content' field) or photo data (has 'type' field)
          if (item.containsKey('content') && !item.containsKey('type')) {
            // It's a comment
            validComments.add(item);
          } else if (item.containsKey('type') && item['type'] == 'photo') {
            // It's photo data, not a comment - skip it
            print('⚠️ Skipping photo data (not a comment): id=${item['id']}');
            continue;
          } else {
            // Unknown format, but has content - treat as comment
            if (item.containsKey('content')) {
              validComments.add(item);
            }
          }
        }
        
        if (validComments.isEmpty && rawComments.isNotEmpty) {
          // Gallery API returned photo data instead of comments - this is expected, try next method
          print('⚠️ Gallery API returned ${rawComments.length} items but none are valid comments (detected photo data)');
          print('   This is expected - gallery API endpoint may not support comments yet.');
          print('   Automatically trying next method (comments API)...');
          // Throw error to trigger next method, but with clear message
          throw ApiException('Gallery API returned photo data instead of comments');
        } else if (validComments.isEmpty) {
          // No comments found, but that's okay - return empty list
          comments = [];
          print('✅ Gallery API returned empty comments list (no comments yet)');
        } else {
          comments = validComments;
          print('✅ Success with gallery API (direct): ${comments.length} valid comments (filtered from ${rawComments.length} items)');
          print('📊 📋 TABLE: gallery_comments - Data fetched successfully from this table');
        }
      } catch (e) {
        // If gallery API fails or returns wrong data, try comments API
        // This is expected behavior - gallery API may not support comments endpoint
        if (e.toString().contains('photo data instead of comments')) {
          print('⚠️ Method 1 (gallery-api-direct) returned wrong data type - this is expected, trying next method...');
        } else {
          print('❌ Method 1 (gallery-api-direct) failed: ${e.toString()}');
        }
        
        // Method 2: Try getting comments from photo details
        try {
          print('🔄 Method 2: Trying to get comments from photo details...');
          final photoDetails = await GalleryService.getPhotoDetails(photoId);
          if (photoDetails['comments'] != null) {
            comments = List<Map<String, dynamic>>.from(photoDetails['comments']);
            print('✅ Success with photo details: ${comments.length} comments');
          } else {
            print('⚠️ Photo details does not contain comments array');
            comments = [];
          }
        } catch (e2) {
          print('❌ Method 2 (photo-details) failed: ${e2.toString()}');
          
          // Method 3: Try comments API with 'photo'
          try {
            print('🔄 Method 3: Trying comments API with post_type="photo"...');
            print('📊 📋 TABLE: comments - Fetching from this table via comments.php?post_type=photo&post_id=$photoId');
            comments = await CommentsService.getComments(
              postType: 'photo',
              postId: photoId,
              userId: userId.value > 0 ? userId.value : null,
            );
            print('✅ Success with comments API (post_type="photo"): ${comments.length} comments');
            print('📊 📋 TABLE: comments - Data fetched successfully from this table (post_type="photo")');
          } catch (e3) {
            print('❌ Method 3 (comments-api-photo) failed: ${e3.toString()}');
            
            // Method 4: Try comments API with 'gallery'
            try {
              print('🔄 Method 4: Trying comments API with post_type="gallery"...');
              print('📊 📋 TABLE: comments - Fetching from this table via comments.php?post_type=gallery&post_id=$photoId');
              comments = await CommentsService.getComments(
                postType: 'gallery',
                postId: photoId,
                userId: userId.value > 0 ? userId.value : null,
              );
              print('✅ Success with comments API (post_type="gallery"): ${comments.length} comments');
              print('📊 📋 TABLE: comments - Data fetched successfully from this table (post_type="gallery")');
            } catch (e4) {
              print('❌ Method 4 (comments-api-gallery) failed: ${e4.toString()}');
              // Return empty list - all methods failed
              comments = [];
            }
          }
        }
      }
      
      print('📥 Received ${comments.length} comments from API');
      
      // Debug: Log all raw comments before processing - CRITICAL FOR DEBUGGING
      print('🍎 GALLERY EMOJI: 📋 Raw comments from API (before processing):');
      for (var i = 0; i < comments.length; i++) {
        final comment = comments[i];
        final content = comment['content'] as String? ?? '';
        final commentId = comment['id'];
        final userId = comment['user_id'];
        print('🍎 GALLERY EMOJI:   Comment ${i + 1}: id=$commentId, user_id=$userId, content="${content.length > 150 ? content.substring(0, 150) + '...' : content}"');
        if (content.contains('uploads/emojis/') || content.contains('emojis/') || content.contains('.png') || content.contains('https://')) {
          print('🍎 GALLERY EMOJI:   ⚠️ THIS COMMENT LOOKS LIKE AN EMOJI REACTION!');
        }
      }
      
      // Debug: Print all comments to see what we got
      if (comments.isNotEmpty) {
        print('📋 All comments received:');
        for (var i = 0; i < comments.length && i < 10; i++) {
          final comment = comments[i];
          final content = comment['content'] as String? ?? '';
          print('   Comment ${i + 1}: id=${comment['id']}, content="${content.substring(0, content.length > 30 ? 30 : content.length)}", post_type=${comment['post_type']}, post_id=${comment['post_id']}');
        }
        if (comments.length > 10) {
          print('   ... and ${comments.length - 10} more comments');
        }
      } else {
        print('⚠️ No comments received from any API method');
      }
      
      // Process comments (separate emoji reactions from text comments)
      print('📊 📋 PROCESSING: Separating emoji reactions from text comments...');
      print('📊 📋 SOURCE: Comments from ${comments.isNotEmpty ? (comments[0].containsKey('photo_id') ? 'gallery_comments' : 'comments') : 'unknown'} table');
      await _processComments(comments);
      
      // ALWAYS load emoji reactions from emoji_usage table and merge
      // This is needed because backend might save emoji to emoji_usage but not create comments
      // Even if reactions found in comments, we still need to check emoji_usage table
      // because saved emojis might be in emoji_usage table, not in comments
      print('🍎 GALLERY EMOJI: 🔄 ALWAYS checking emoji_usage table (even if comments have reactions)...');
      print('📊 📋 TABLE: emoji_usage - Will fetch from this table and merge with comments');
      print('🍎 GALLERY EMOJI: 📊 Current reactions before emoji_usage fetch: ${photoEmojiReactions.length}');
      await _loadEmojiReactionsFromUsage(photoId);
      print('🍎 GALLERY EMOJI: 📊 Final reactions after emoji_usage merge: ${photoEmojiReactions.length}');
    } catch (e) {
      print('❌ Error loading photo comments: $e');
      print('⚠️ Preserving existing reactions instead of clearing them');
      // Don't clear photoEmojiReactions - preserve existing data
      // Only clear comments if needed
      photoComments.value = [];
      // photoEmojiReactions.value = <String, List<Map<String, dynamic>>>{}; // DON'T CLEAR - preserve existing reactions
      print('📊 📋 Preserved ${photoEmojiReactions.length} existing emoji reactions');
    }
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
      
      if (isEmojiReaction && emojiKey != null) {
        // It's an emoji reaction - store user information
        if (!emojiReactions.containsKey(emojiKey)) {
          emojiReactions[emojiKey] = [];
          print('🍎 GALLERY EMOJI: ✅ Created new emoji reaction entry for key: "$emojiKey"');
        }
        // Add user info for this reaction
        emojiReactions[emojiKey]!.add({
          'user_id': comment['user_id'],
          'user_name': comment['user_name'] ?? 'Anonymous',
          'profile_photo': comment['profile_photo'],
          'created_at': comment['created_at'],
        });
        print('🍎 GALLERY EMOJI: ✅ Added emoji reaction: "$emojiKey" by ${comment['user_name']} (total: ${emojiReactions[emojiKey]!.length})');
      } else {
        // It's a text comment - add to text comments list
        // Only add top-level comments (replies are nested in 'replies' array) - SAME AS PRAYERS
        if (parentId == null || parentId == 0) {
          // Check if replies array exists and log it
          final replies = comment['replies'];
          final replyCount = replies != null ? (replies as List).length : 0;
          print('📝 Found top-level comment: id=$commentId, replies=$replyCount');
          if (replyCount > 0) {
            print('   ✅ Replies found in replies array:');
            for (var i = 0; i < (replies as List).length; i++) {
              final reply = (replies as List)[i];
              print('      - Reply ${i + 1}: id=${reply['id']}, content=${(reply['content'] as String? ?? '').substring(0, (reply['content'] as String? ?? '').length > 30 ? 30 : (reply['content'] as String? ?? '').length)}...');
            }
          } else {
            print('   ⚠️ No replies in replies array (might be empty or null)');
          }
          textComments.add(comment);
        } else {
          print('⏭️ Skipping reply (will be shown in parent comment): id=$commentId, parent=$parentId');
        }
      }
    }
    
    print('📊 Loaded ${emojiReactions.length} emoji reaction types and ${textComments.length} top-level comments');
    for (var emoji in emojiReactions.keys) {
      print('   - $emoji: ${emojiReactions[emoji]!.length} reactions');
    }
    
      // Update reactive variables - EXACTLY LIKE PRAYERS
      // Create new list instance and force UI refresh
      photoComments.value = List<Map<String, dynamic>>.from(textComments);
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

  /// Add comment to photo
  Future<bool> addComment(int photoId, String content, {int? parentCommentId}) async {
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
      final isReply = parentCommentId != null && parentCommentId > 0;
      print('📝 Adding ${isReply ? "REPLY" : "COMMENT"}: photoId=$photoId, parentCommentId=$parentCommentId, content=${content.substring(0, content.length > 20 ? 20 : content.length)}...');
      
      // Try multiple approaches (in order of most likely to work):
      // 1. Try gallery API directly with action='add-comment' (NEW - uses gallery_comments table)
      // 2. Try comments API with 'photo' post_type (FALLBACK)
      // 3. Try comments API with 'gallery' post_type (FALLBACK)
      
      int commentId;
      String? usedMethod;
      String? lastError;
      
      // Method 1: Try gallery API directly FIRST (NEW - uses gallery_comments table)
      try {
        print('🔄 Method 1: Trying gallery API directly with action="add-comment"...');
        commentId = await GalleryService.addComment(
          userId: userId.value,
          photoId: photoId,
          content: content,
          parentCommentId: parentCommentId,
        );
        usedMethod = 'gallery-api-direct';
        print('✅ Success with gallery API (direct - uses gallery_comments table)');
      } catch (e) {
        lastError = e.toString();
        print('❌ Method 1 (gallery-api-direct) failed: $lastError');
        
        // Method 2: Try comments API with 'photo' (FALLBACK)
        try {
          print('🔄 Method 2: Trying comments API with post_type="photo"...');
          commentId = await CommentsService.addComment(
            userId: userId.value,
            postType: 'photo',
            postId: photoId,
            content: content,
            parentCommentId: parentCommentId,
          );
          usedMethod = 'comments-api-photo';
          print('✅ Success with comments API (post_type="photo")');
        } catch (e2) {
          lastError = e2.toString();
          print('❌ Method 2 (comments-api-photo) failed: $lastError');
          
          // Method 3: Try comments API with 'gallery' (FALLBACK)
          try {
            print('🔄 Method 3: Trying comments API with post_type="gallery"...');
            commentId = await CommentsService.addComment(
              userId: userId.value,
              postType: 'gallery',
              postId: photoId,
              content: content,
              parentCommentId: parentCommentId,
            );
            usedMethod = 'comments-api-gallery';
            print('✅ Success with comments API (post_type="gallery")');
          } catch (e3) {
            lastError = e3.toString();
            print('❌ Method 3 (comments-api-gallery) failed: $lastError');
            
            // All methods failed - show user-friendly error
            final errorMsg = lastError.contains('Invalid post_type') 
                ? 'Comments are not yet supported for photos. The backend needs to add support for photo comments.'
                : lastError.contains('not found')
                    ? 'Gallery comments are not yet configured. Please contact support.'
                    : 'Unable to add comment. Please try again later.';
            
            print('❌ All methods failed. Backend needs to add support for photo comments.');
            print('   Method 1 (gallery-api-direct): ${e.toString()}');
            print('   Method 2 (comments-api-photo): ${e2.toString()}');
            print('   Method 3 (comments-api-gallery): ${e3.toString()}');
            
            message.value = errorMsg;
            throw ApiException(errorMsg);
          }
        }
      }
      
      print('✅ ${isReply ? "Reply" : "Comment"} added successfully (ID: $commentId), reloading comments...');
      
      // Reload comments to get updated structure with nested replies
      await loadPhotoComments(photoId);
      
      // Debug: Check if reply was added to parent
      if (isReply) {
        for (var comment in photoComments) {
          if (comment['id'] == parentCommentId) {
            final replies = comment['replies'] as List?;
            print('🔍 Parent comment ${parentCommentId} now has ${replies?.length ?? 0} replies');
            if (replies != null) {
              for (var reply in replies) {
                print('  - Reply ID: ${reply['id']}, content: ${(reply['content'] as String? ?? '').substring(0, (reply['content'] as String? ?? '').length > 30 ? 30 : (reply['content'] as String? ?? '').length)}...');
              }
            }
            break;
          }
        }
      }
      
      print('✅ Comments reloaded: ${photoComments.length} top-level comments');
      
      return true;
    } catch (e) {
      message.value = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      print('Error adding comment: $e');
      return false;
    }
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
      
      // Reload comments to get updated like status
      final photoId = selectedPhoto['id'] as int?;
      if (photoId != null && photoId > 0) {
        await loadPhotoComments(photoId);
        // Force UI refresh for comments
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
    
    if (selectedFruitTag.value.isEmpty) {
      // Show all photos - create new list instance
      photos.value = List<Map<String, dynamic>>.from(_allPhotos);
    } else {
      // Filter by fruit tag client-side - create new list instance
      photos.value = List<Map<String, dynamic>>.from(_allPhotos.where((photo) {
        final photoFruitTag = photo['fruit_tag'] as String? ?? '';
        return photoFruitTag.toLowerCase() == selectedFruitTag.value.toLowerCase();
      }).toList());
    }
    // Force UI refresh
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
      
      // Reload photos to get updated like count
      await loadPhotos(refresh: true);
      
      return response['liked'] == true;
    } catch (e) {
      message.value = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      print('Error toggling like: $e');
      return false;
    }
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
    } catch (e) {
      print('Error loading emojis: $e');
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

  /// Add/Remove emoji reaction to photo (TOGGLE)
  /// If user already reacted, removes it. Otherwise, adds it.
  Future<bool> addEmojiReaction(int photoId, String emoji) async {
    if (userId.value == 0) {
      await _loadUserId();
    }

    if (userId.value == 0) {
      message.value = 'Please login first';
      return false;
    }

    try {
      // Try 'photo' first (same as prayers uses 'prayer')
      String result;
      try {
        print('🍎 GALLERY EMOJI: 📤 Saving emoji with post_type="photo" (like prayers uses "prayer")...');
        print('📊 📋 SAVE TO TABLE: emoji_usage - Saving here');
        result = await EmojisService.useEmoji(
          userId: userId.value,
          emoji: emoji,
          postType: 'photo',
          postId: photoId,
        );
        print('📊 📋 SAVE TO TABLE: emoji_usage - ✅ SAVED SUCCESSFULLY! (post_type="photo")');
      } catch (e) {
        // Fallback: Try with 'gallery' post_type
        print('🍎 GALLERY EMOJI: ⚠️ Failed with post_type="photo": $e');
        print('🍎 GALLERY EMOJI: 📤 Trying with post_type="gallery"...');
        print('📊 📋 SAVE TO TABLE: emoji_usage - Attempting with post_type="gallery"');
        result = await EmojisService.useEmoji(
          userId: userId.value,
          emoji: emoji,
          postType: 'gallery',
          postId: photoId,
        );
        print('📊 📋 SAVE TO TABLE: emoji_usage - ✅ SAVED SUCCESSFULLY! (post_type="gallery")');
      }
      
      // Reload comments to get updated reactions with user info (this will update photoEmojiReactions)
      // EXACTLY like prayers does
      await loadPhotoComments(photoId);
      
      // Force UI refresh for reactions
      photoEmojiReactions.refresh();
      photoComments.refresh();
      
      // Check if reaction was removed or added
      if (result.contains('removed')) {
        print('✅ Emoji reaction removed (toggled off): $emoji');
      } else {
        print('✅ Emoji reaction added (toggled on): $emoji');
      }
      print('📊 Current reactions: ${photoEmojiReactions.length} emoji types');
      for (var emojiKey in photoEmojiReactions.keys) {
        print('   - $emojiKey: ${photoEmojiReactions[emojiKey]!.length} users');
      }
      
      return true;
    } catch (e) {
      message.value = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      print('Error toggling emoji reaction: $e');
      return false;
    }
  }

  
  /// Show moderation snackbar
  void _showModerationSnackbar(String message) {
    Get.snackbar(
      'Community Guidelines',
      message,
      backgroundColor: const Color(0xFF5D4037),
      colorText: Colors.white,
      icon: const Icon(Icons.security_rounded, color: Color(0xFFC79211)),
      mainButton: TextButton(
        onPressed: () => Get.toNamed('/terms'), // Using string route if constant not imported
        child: const Text('VIEW TERMS', style: TextStyle(color: Color(0xFFC79211))),
      ),
    );
  }
}

