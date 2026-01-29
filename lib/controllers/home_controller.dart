import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:fruitsofspirit/services/fruits_service.dart';
import 'package:fruitsofspirit/services/prayers_service.dart';
import 'package:fruitsofspirit/services/blogs_service.dart';
import 'package:fruitsofspirit/services/videos_service.dart';
import 'package:fruitsofspirit/services/gallery_service.dart';
import 'package:fruitsofspirit/services/groups_service.dart';
import 'package:fruitsofspirit/services/emojis_service.dart';
import 'package:fruitsofspirit/services/stories_service.dart';
import 'package:fruitsofspirit/services/user_storage.dart';
import 'package:fruitsofspirit/services/api_service.dart';
import 'package:fruitsofspirit/services/image_preload_service.dart';
import 'package:fruitsofspirit/services/data_loading_service.dart';
import 'package:fruitsofspirit/services/cache_service.dart';
import 'package:fruitsofspirit/services/hive_cache_service.dart';
import 'package:fruitsofspirit/config/image_config.dart';
import 'package:fruitsofspirit/services/intro_service.dart';

class HomeController extends GetxController {
  // ScrollController for smooth scrolling
  final ScrollController scrollController = ScrollController();

  // Observable variables for UI state
  var isLoading = false.obs;
  var isInitialLoading = true.obs; // New flag for initial load
  var message = ''.obs;

  // Data from database
  var fruits = <Map<String, dynamic>>[].obs;
  var prayers = <Map<String, dynamic>>[].obs;
  var blogs = <Map<String, dynamic>>[].obs;
  var videos = <Map<String, dynamic>>[].obs;
  var liveVideos = <Map<String, dynamic>>[].obs;
  var galleryPhotos = <Map<String, dynamic>>[].obs;
  var stories = <Map<String, dynamic>>[].obs; // Stories from stories table
  var groups = <Map<String, dynamic>>[].obs;
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

  // Intro overlay state
  var showIntroOverlay = false.obs;

  @override
  void onInit() {
    super.onInit();
    _loadUserId();
    _initializeData();
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
      // Load user's latest feeling
      await loadUserFeeling();
    }
  }

  /// Load user's latest feeling - First from local storage (instant), then from API (sync)
  Future<void> loadUserFeeling({bool fromApiOnly = false}) async {
    print('🍎 FRUIT ISSUE: loadUserFeeling called - fromApiOnly=$fromApiOnly, userId=${userId.value}');
    if (userId.value <= 0) {
      userFeeling.value = null;
      print('🍎 FRUIT ISSUE: ⚠️ Cannot load feeling: userId is ${userId.value}');
      return;
    }
    
    // STEP 1: Load from local storage FIRST for instant UI update
    if (!fromApiOnly) {
      try {
        final localFeeling = await UserStorage.getUserFeeling();
        if (localFeeling != null) {
          // Create new Map to ensure GetX detects change
          userFeeling.value = Map<String, dynamic>.from(localFeeling);
          print('🍎 FRUIT ISSUE: ✅ Loaded user feeling from LOCAL STORAGE (instant): emoji=${localFeeling['emoji']}');
          print('🍎 FRUIT ISSUE: ✅ Local storage emoji_details: ${localFeeling['emoji_details']?['name'] ?? 'null'}');
          print('🍎 FRUIT ISSUE: ✅ UI should update instantly from local storage');
          // Force refresh to ensure UI updates
          userFeeling.refresh();
        } else {
          print('🍎 FRUIT ISSUE: ⚠️ No feeling found in local storage');
        }
      } catch (e) {
        print('🍎 FRUIT ISSUE: ⚠️ Error loading feeling from local storage: $e');
      }
    } else {
      print('🍎 FRUIT ISSUE: ⚠️ Skipping local storage load (fromApiOnly=true)');
    }
    
    // STEP 2: Load from API in background to sync with server
    try {
      print('🍎 FRUIT ISSUE: 🔄 Loading user feeling from API for userId: ${userId.value}');
      final feeling = await EmojisService.getUserLatestFeeling(userId: userId.value);
      print('🍎 FRUIT ISSUE: 📥 API Response received: ${feeling != null ? "has data" : "null"}');
      
      if (feeling != null) {
        // IMPORTANT: If emoji is an ID (number), find emoji details from emoji lists
        final emojiValue = feeling['emoji'];
        Map<String, dynamic>? emojiDetails = feeling['emoji_details'] as Map<String, dynamic>?;
        
        print('🍎 FRUIT ISSUE: 📊 API returned feeling data:');
        print('🍎 FRUIT ISSUE:   - API emoji value: $emojiValue');
        print('🍎 FRUIT ISSUE:   - API emoji_details: ${emojiDetails?['name'] ?? 'null'}');
        print('🍎 FRUIT ISSUE:   - API emoji_details ID: ${emojiDetails?['id'] ?? 'null'}');
        
        // Check if emoji is an ID (number) and emoji_details is missing or old
        if (emojiValue != null) {
          final emojiStr = emojiValue.toString();
          final emojiId = int.tryParse(emojiStr);
          print('🍎 FRUIT ISSUE: 🔍 Parsed emoji value: $emojiStr (is ID: ${emojiId != null})');
          
          // If emoji is an ID and we need to find details
          if (emojiId != null && (emojiDetails == null || emojiDetails.isEmpty)) {
            print('🔍 Emoji is an ID ($emojiId), searching for emoji details in emoji lists...');
            
            // Search in all emoji lists by ID
            final allEmojisList = [
              ...emojis,
              ...allEmojis,
              ...oppositeEmojis,
              ...emotionEmojis,
            ];
            
            for (var emojiItem in allEmojisList) {
              final id = emojiItem['id'] as int?;
              if (id == emojiId) {
                emojiDetails = emojiItem;
                print('✅ Found emoji details by ID: ${emojiItem['name']}');
                break;
              }
            }
          }
          
          // If still no details found, try to find by code/name match
          if (emojiDetails == null || emojiDetails.isEmpty) {
            print('🔍 Searching for emoji details by value: $emojiStr');
            final allEmojisList = [
              ...emojis,
              ...allEmojis,
              ...oppositeEmojis,
              ...emotionEmojis,
            ];
            
            for (var emojiItem in allEmojisList) {
              final code = emojiItem['code'] as String? ?? '';
              final emojiChar = emojiItem['emoji_char'] as String? ?? '';
              final imageUrl = emojiItem['image_url'] as String? ?? '';
              final id = emojiItem['id']?.toString() ?? '';
              
              if (code == emojiStr || 
                  emojiChar == emojiStr || 
                  imageUrl == emojiStr ||
                  id == emojiStr ||
                  code.toLowerCase() == emojiStr.toLowerCase()) {
                emojiDetails = emojiItem;
                print('✅ Found emoji details by match: ${emojiItem['name']}');
                break;
              }
            }
          }
        }
        
        // IMPORTANT: Check if we already have correct data in local storage
        // Don't overwrite if local storage has more recent/correct data
        final currentFeeling = userFeeling.value;
        final currentEmoji = currentFeeling?['emoji']?.toString() ?? '';
        final apiEmoji = emojiValue?.toString() ?? '';
        final currentEmojiDetails = currentFeeling?['emoji_details'] as Map<String, dynamic>?;
        
        print('🍎 FRUIT ISSUE: 📊 API Load Check - Comparing Local vs API:');
        print('🍎 FRUIT ISSUE:   - Current emoji (local): $currentEmoji');
        print('🍎 FRUIT ISSUE:   - Current emoji_details (local): ${currentEmojiDetails?['name'] ?? 'null'}');
        print('🍎 FRUIT ISSUE:   - Current emoji_details ID (local): ${currentEmojiDetails?['id'] ?? 'null'}');
        print('🍎 FRUIT ISSUE:   - API emoji: $apiEmoji');
        print('🍎 FRUIT ISSUE:   - API emoji_details: ${emojiDetails?['name'] ?? 'null'}');
        print('🍎 FRUIT ISSUE:   - API emoji_details ID: ${emojiDetails?['id'] ?? 'null'}');
        
        // Update feeling with found emoji_details
        final updatedFeeling = Map<String, dynamic>.from(feeling);
        if (emojiDetails != null && emojiDetails.isNotEmpty) {
          updatedFeeling['emoji_details'] = emojiDetails;
          print('✅ Found emoji_details from API: ${emojiDetails['name']}');
        } else {
          print('⚠️ Could not find emoji_details for emoji: $emojiValue');
        }
        
        // CRITICAL: Check if API emoji is an ID and matches current emoji_details ID
        final apiEmojiId = int.tryParse(apiEmoji);
        final currentEmojiDetailsId = currentEmojiDetails?['id'] as int?;
        final apiEmojiDetailsId = emojiDetails?['id'] as int?;
        
        // Check timestamps to see which is newer
        final currentUpdatedAt = currentFeeling?['updated_at'] as String?;
        final apiUpdatedAt = feeling['updated_at'] as String?;
        final currentCreatedAt = currentFeeling?['created_at'] as String?;
        final apiCreatedAt = feeling['created_at'] as String?;

        print('🍎 FRUIT ISSUE: 🔍 ID Comparison:');
        print('🍎 FRUIT ISSUE:   - apiEmojiId: $apiEmojiId');
        print('🍎 FRUIT ISSUE:   - currentEmojiDetailsId: $currentEmojiDetailsId');
        print('🍎 FRUIT ISSUE:   - apiEmojiDetailsId: $apiEmojiDetailsId');
        print('🍎 FRUIT ISSUE:   - currentUpdatedAt: $currentUpdatedAt');
        print('🍎 FRUIT ISSUE:   - apiUpdatedAt: $apiUpdatedAt');
        
        // Check if they represent the same emoji (by ID match)
        final isSameEmoji = (apiEmojiId != null && currentEmojiDetailsId != null && apiEmojiId == currentEmojiDetailsId) ||
                           (apiEmojiDetailsId != null && currentEmojiDetailsId != null && apiEmojiDetailsId == currentEmojiDetailsId) ||
                           (currentEmoji == apiEmoji) ||
                           (currentEmoji.isNotEmpty && apiEmoji.isNotEmpty && 
                            (currentEmoji.contains(apiEmoji) || apiEmoji.contains(currentEmoji)));
        
        // Check if local storage is newer (has updated_at timestamp)
        bool isLocalNewer = false;
        if (currentUpdatedAt != null && apiUpdatedAt != null) {
          try {
            final currentTime = DateTime.parse(currentUpdatedAt);
            final apiTime = DateTime.parse(apiUpdatedAt);
            isLocalNewer = currentTime.isAfter(apiTime);
            print('🍎 FRUIT ISSUE: 🔍 Timestamp comparison: local is newer = $isLocalNewer');
          } catch (e) {
            print('🍎 FRUIT ISSUE: ⚠️ Error parsing timestamps: $e');
          }
        } else if (currentUpdatedAt != null && apiUpdatedAt == null) {
          // Local has updated_at but API doesn't - local is likely newer
          isLocalNewer = true;
          print('🍎 FRUIT ISSUE: 🔍 Local has updated_at but API doesn\'t - assuming local is newer');
        }
        
        print('🍎 FRUIT ISSUE: 🔍 isSameEmoji check: $isSameEmoji');
        print('🍎 FRUIT ISSUE:   - apiEmojiId == currentEmojiDetailsId: ${apiEmojiId != null && currentEmojiDetailsId != null && apiEmojiId == currentEmojiDetailsId}');
        print('🍎 FRUIT ISSUE:   - apiEmojiDetailsId == currentEmojiDetailsId: ${apiEmojiDetailsId != null && currentEmojiDetailsId != null && apiEmojiDetailsId == currentEmojiDetailsId}');
        print('🍎 FRUIT ISSUE:   - currentEmoji == apiEmoji: ${currentEmoji == apiEmoji}');
        print('🍎 FRUIT ISSUE:   - isLocalNewer: $isLocalNewer');
        
        // CRITICAL: If current feeling has emoji_details and it's the same emoji,
        // keep the current emoji_details (it's more accurate and has the correct code)
        if (currentEmojiDetails != null && 
            currentEmoji.isNotEmpty && 
            isSameEmoji) {
          print('🍎 FRUIT ISSUE: ✅ Keeping current emoji_details (more accurate): ${currentEmojiDetails['name']}');
          updatedFeeling['emoji_details'] = currentEmojiDetails;
          // Also update emoji to match current if API returned ID
          if (apiEmoji != currentEmoji && currentEmoji.isNotEmpty) {
            updatedFeeling['emoji'] = currentEmoji;
            print('🍎 FRUIT ISSUE: ✅ Using current emoji value ($currentEmoji) instead of API value ($apiEmoji)');
          }
        } else {
          print('🍎 FRUIT ISSUE: ⚠️ NOT keeping current emoji_details - currentEmojiDetails is null or isSameEmoji is false');
        }
        
        // CRITICAL FIX: Don't overwrite if:
        // 1. Local storage has emoji_details with a different ID (user selected a different fruit)
        // 2. Local storage is newer (has updated_at timestamp that's more recent)
        // 3. Local storage has complete emoji_details but API doesn't match
        final isDifferentFruit = currentEmojiDetailsId != null && 
                                 apiEmojiDetailsId != null && 
                                 currentEmojiDetailsId != apiEmojiDetailsId;
        
        final shouldPreserveLocal = isLocalNewer || 
                                    (isDifferentFruit && currentEmojiDetails != null) ||
                                    (currentEmojiDetails != null && !isSameEmoji && currentEmoji.isNotEmpty);
        
        print('🍎 FRUIT ISSUE: 🔍 shouldPreserveLocal check:');
        print('🍎 FRUIT ISSUE:   - isDifferentFruit: $isDifferentFruit');
        print('🍎 FRUIT ISSUE:   - shouldPreserveLocal: $shouldPreserveLocal');
        
        // Only update if:
        // 1. We don't have current feeling, OR
        // 2. Emoji actually changed AND local is not newer AND they're the same emoji, OR
        // 3. Current feeling doesn't have emoji_details (but API does) AND local is not newer
        // IMPORTANT: Don't overwrite if local storage is newer or has different fruit
        final shouldUpdate = !shouldPreserveLocal && (
                            currentFeeling == null || 
                            (isSameEmoji && !isLocalNewer && currentEmojiDetails == null && emojiDetails != null) ||
                            (isSameEmoji && !isLocalNewer && currentEmoji.isEmpty && apiEmoji.isNotEmpty)
                            );
        
        print('🍎 FRUIT ISSUE: 🔍 shouldUpdate decision:');
        print('🍎 FRUIT ISSUE:   - shouldPreserveLocal: $shouldPreserveLocal');
        print('🍎 FRUIT ISSUE:   - currentFeeling == null: ${currentFeeling == null}');
        print('🍎 FRUIT ISSUE:   - FINAL shouldUpdate: $shouldUpdate');
        
        if (shouldUpdate) {
          print('🍎 FRUIT ISSUE: ⚠️⚠️⚠️ OVERWRITING LOCAL STORAGE WITH API DATA ⚠️⚠️⚠️');
          print('🍎 FRUIT ISSUE:   - OLD local emoji: $currentEmoji');
          print('🍎 FRUIT ISSUE:   - OLD local emoji_details: ${currentEmojiDetails?['name'] ?? 'null'}');
          print('🍎 FRUIT ISSUE:   - NEW API emoji: ${updatedFeeling['emoji']}');
          print('🍎 FRUIT ISSUE:   - NEW API emoji_details: ${updatedFeeling['emoji_details']?['name'] ?? 'null'}');
          
          // Update UI with API data - Create new Map to ensure GetX detects change
          userFeeling.value = updatedFeeling;
          // Also save to local storage for next time
          await UserStorage.saveUserFeeling(updatedFeeling);
          print('🍎 FRUIT ISSUE: ✅ Loaded user feeling from API: emoji=${updatedFeeling['emoji']}, emoji_details=${updatedFeeling['emoji_details']?['name']}');
          print('🍎 FRUIT ISSUE: ✅ Saved to local storage for instant access next time');
          // Force refresh to ensure UI updates
          userFeeling.refresh();
        } else {
          print('🍎 FRUIT ISSUE: ✅ PRESERVING LOCAL STORAGE - not overwriting with API data');
          print('🍎 FRUIT ISSUE: ✅ Keeping current emoji: $currentEmoji with details: ${currentEmojiDetails?['name']}');
          print('🍎 FRUIT ISSUE: ⚠️ API returned emoji: $apiEmoji (ignoring because local is newer/different)');
        }
      } else {
        print('⚠️ No feeling found for user in API');
        // Don't clear local storage if API returns null - keep the local one
        if (fromApiOnly) {
          userFeeling.value = null;
        }
      }
    } catch (e) {
      print('⚠️ Error loading user feeling from API: $e');
      // Keep local storage value if API fails
      if (fromApiOnly) {
        userFeeling.value = null;
      }
    }
  }

  /// Update user feeling after recording - Optimized for instant UI update
  /// [emoji] - The emoji identifier (code, emoji_char, or image_url)
  /// [emojiData] - Optional emoji data for instant display (if available)
  Future<void> updateUserFeeling(String emoji, {Map<String, dynamic>? emojiData}) async {
    print('🍎 FRUIT ISSUE: updateUserFeeling called - emoji=$emoji, emojiData=${emojiData?['name'] ?? 'null'}');
    if (userId.value <= 0) {
      final id = await UserStorage.getUserId();
      if (id != null) {
        userId.value = id;
      } else {
        print('🍎 FRUIT ISSUE: ⚠️ Cannot update feeling: userId is still ${userId.value}');
        return;
      }
    }
    
    print('🍎 FRUIT ISSUE: 🔄 Updating user feeling with emoji: $emoji');
    
    // INSTANT UI UPDATE: Optimistically update the feeling immediately
    // This makes the UI update instantly while API processes in background
    try {
      // Try to find emoji details for instant display
      Map<String, dynamic>? emojiDetails;
      
      // Use provided emojiData if available (from variant selection)
      if (emojiData != null) {
        emojiDetails = emojiData;
        print('✅ Using provided emoji data for instant display: ${emojiData['name']}');
      } else {
        // Search in all emoji lists for matching emoji
        final allEmojisList = [
          ...emojis,
          ...allEmojis,
          ...oppositeEmojis,
          ...emotionEmojis,
        ];
        
        // Try to find emoji by ID first (if emoji is a number)
        final emojiId = int.tryParse(emoji);
        if (emojiId != null) {
          // Search by ID
          for (var emojiItem in allEmojisList) {
            final id = emojiItem['id'] as int?;
            if (id == emojiId) {
              emojiDetails = emojiItem;
              print('✅ Found emoji details by ID: ${emojiItem['name']}');
              break;
            }
          }
        }
        
        // If not found by ID, try by code, emoji_char, or image_url
        if (emojiDetails == null) {
          for (var emojiItem in allEmojisList) {
            final code = emojiItem['code'] as String? ?? '';
            final emojiChar = emojiItem['emoji_char'] as String? ?? '';
            final imageUrl = emojiItem['image_url'] as String? ?? '';
            final id = emojiItem['id']?.toString() ?? '';
            
            if (code == emoji || 
                emojiChar == emoji || 
                imageUrl == emoji ||
                id == emoji ||
                code.toLowerCase() == emoji.toLowerCase() ||
                emoji.contains(code) || 
                emoji.contains(imageUrl)) {
              emojiDetails = emojiItem;
              print('✅ Found emoji details for instant display: ${emojiItem['name']}');
              break;
            }
          }
        }
      }
      
      // Create optimistic feeling data for instant UI update
      // CRITICAL: Always create a completely new object with new timestamp to ensure GetX detects change
      // Even if emoji is the same, the new timestamp ensures GetX sees it as a different object
      final now = DateTime.now().toIso8601String();
      final optimisticFeeling = <String, dynamic>{
        'emoji': emoji,
        'user_id': userId.value,
        'created_at': now,
        'updated_at': now, // Add updated_at to ensure uniqueness and force GetX to detect change
      };
      
      // Add emoji details if found for instant display
      if (emojiDetails != null) {
        optimisticFeeling['emoji_details'] = Map<String, dynamic>.from(emojiDetails);
        print('✅ Added emoji_details to optimistic feeling: ${emojiDetails['name']}, image_url: ${emojiDetails['image_url']}');
      } else {
        print('⚠️ No emoji details found for instant display');
      }
      
      // STEP 1: Save to LOCAL STORAGE FIRST for instant persistence
      // IMPORTANT: Always save with complete emoji_details to ensure correct display
      await UserStorage.saveUserFeeling(optimisticFeeling);
      print('🍎 FRUIT ISSUE: ✅ Saved feeling to LOCAL STORAGE for instant access');
      print('🍎 FRUIT ISSUE: ✅ Saved emoji: ${optimisticFeeling['emoji']}');
      print('🍎 FRUIT ISSUE: ✅ Saved emoji_details: ${optimisticFeeling['emoji_details']?['name'] ?? 'null'}');
      print('🍎 FRUIT ISSUE: ✅ Saved emoji_details ID: ${optimisticFeeling['emoji_details']?['id'] ?? 'null'}');
      print('🍎 FRUIT ISSUE: ✅ Saved timestamp: ${optimisticFeeling['updated_at']}');

      // STEP 2: Update UI instantly - this should trigger Obx rebuild
      // IMPORTANT: Set to null first, then set new value to force GetX to detect change
      // This ensures UI updates even if emoji code is the same but details changed
      print('🍎 FRUIT ISSUE: 🔄 Updating UI - setting userFeeling.value to null first');
      userFeeling.value = null;
      print('🍎 FRUIT ISSUE: 🔄 Step 2.1: userFeeling set to null (rebuild triggered)');
      
      await Future.delayed(const Duration(milliseconds: 50)); // Slightly longer delay
      
      userFeeling.value = Map<String, dynamic>.from(optimisticFeeling);
      print('🍎 FRUIT ISSUE: ✅ Step 2.2: userFeeling updated with value: ${userFeeling.value?['emoji']}');
      userFeeling.refresh(); // Force another refresh
      
      print('🍎 FRUIT ISSUE: ✅ User feeling updated instantly in UI with emoji: $emoji');
      print('🍎 FRUIT ISSUE: ✅ userFeeling.value emoji: ${userFeeling.value?['emoji']}');
      print('🍎 FRUIT ISSUE: ✅ userFeeling.value emoji_details: ${userFeeling.value?['emoji_details']?['name'] ?? 'null'}');
      print('🍎 FRUIT ISSUE: ✅ userFeeling.value emoji_details ID: ${userFeeling.value?['emoji_details']?['id'] ?? 'null'}');
      print('🍎 FRUIT ISSUE: ✅ userFeeling.value has emoji_details: ${userFeeling.value?['emoji_details'] != null}');
      print('🍎 FRUIT ISSUE: ✅ New timestamp: ${optimisticFeeling['updated_at']}');

      // Force UI refresh multiple times to ensure update
      userFeeling.refresh();
      await Future.delayed(const Duration(milliseconds: 50));
      userFeeling.refresh();
      print('✅ Forced UI refresh multiple times');

      // Note: Backend update should be done BEFORE calling this function
      // This function just updates UI optimistically
      // The caller should reload from API after backend update
    } catch (e) {
      print('⚠️ Error updating user feeling: $e');
      // Fallback: try to load from API
      try {
        await Future.delayed(const Duration(milliseconds: 1000));
        await loadUserFeeling();
      } catch (retryError) {
        print('⚠️ Error updating user feeling on retry: $retryError');
      }
    }
  }

  /// Set initial data from cache or external service
  void setInitialData(Map<String, dynamic> data) {
    if (data.isEmpty) return;

    print('🏠 HomeController: Setting initial data from external source...');

    if (data['fruits'] != null && (data['fruits'] as List).isNotEmpty) {
      fruits.value = List<Map<String, dynamic>>.from(data['fruits']);
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
      final mainFruitsList = <Map<String, dynamic>>[];
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
          mainFruitsList.add(emoji);
        } else if (category.toLowerCase().contains('opposite')) {
          oppositeEmojisList.add(emoji);
        } else if (category.toLowerCase().contains('emotion')) {
          emotionEmojisList.add(emoji);
        }
      }
      
      emojis.value = mainFruitsList;
      allEmojis.value = allEmojisList;
      oppositeEmojis.value = oppositeEmojisList;
      emotionEmojis.value = emotionEmojisList;
      _isEmojisLoaded = true;
    }

    // Mark data as loaded to prevent redundant loads
    _isDataLoaded = true;

    // If we have some data, we can stop initial loading
    if (fruits.isNotEmpty || prayers.isNotEmpty || blogs.isNotEmpty) {
      isInitialLoading.value = false;
      print('✅ HomeController: Initial loading finished (data populated via setInitialData)');
    }
    
    // Refresh UI
    fruits.refresh();
    prayers.refresh();
    blogs.refresh();
  }

  /// Initialize data: load from cache first (instant), then refresh in background
  Future<void> _initializeData() async {
    // If data already loaded externally (e.g. from SplashScreen via setInitialData), skip
    if (_isDataLoaded && (fruits.isNotEmpty || prayers.isNotEmpty)) {
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
      if (fruits.isNotEmpty || prayers.isNotEmpty || blogs.isNotEmpty) {
        isInitialLoading.value = false;
        print('✅ Data loaded from cache - showing instantly');
        
        // Then load fresh data from API in background (silent update)
        loadHomeData().then((_) {
          print('✅ Background data refresh completed');
        }).catchError((e) {
          print('⚠️ Background refresh error: $e');
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
      final cachedFruits = HiveCacheService.getCachedList('home_fruits');
      final cachedPrayers = HiveCacheService.getCachedList('home_prayers');
      final cachedBlogs = HiveCacheService.getCachedList('home_blogs');
      final cachedVideos = HiveCacheService.getCachedList('home_videos');
      final cachedLiveVideos = HiveCacheService.getCachedList('home_live_videos');
      final cachedGalleryPhotos = HiveCacheService.getCachedList('home_gallery_photos');
      final cachedStories = HiveCacheService.getCachedList('home_stories');
      final cachedGroups = HiveCacheService.getCachedList('home_groups');
      final cachedEmojis = HiveCacheService.getCachedList('home_emojis');
      
      if (cachedFruits.isNotEmpty) {
        fruits.value = cachedFruits;
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
      if (cachedLiveVideos.isNotEmpty) {
        liveVideos.value = cachedLiveVideos;
      }
      if (cachedGalleryPhotos.isNotEmpty) {
        galleryPhotos.value = cachedGalleryPhotos;
      }
      if (cachedStories.isNotEmpty) {
        stories.value = cachedStories;
      }
      if (cachedGroups.isNotEmpty) {
        groups.value = cachedGroups;
      }
      if (cachedEmojis.isNotEmpty) {
        emojis.value = cachedEmojis;
      }
      
      print('✅ Loaded ${fruits.length} fruits, ${prayers.length} prayers, ${blogs.length} blogs from Hive cache');
    } catch (e) {
      print('⚠️ Error loading from Hive cache: $e');
      // Fallback to old cache service
      try {
      final cachedData = await DataLoadingService.getCachedHomeData();
      if (cachedData['fruits']?.isNotEmpty == true) {
        fruits.value = cachedData['fruits'] as List<Map<String, dynamic>>;
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
      // Load all data sequentially instead of parallel to prevent overloading slow servers
      await loadFruits();
      await loadPrayers();
      await loadBlogs();
      await loadVideos();
      await loadLiveVideos();
      await loadGalleryPhotos();
      await loadStories();
      await loadGroups();
      await loadEmojis();


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

  /// Cache all current data (using Hive for fast persistence)
  Future<void> _cacheAllData() async {
    try {
      // Use Hive cache for better performance (synchronous, fast)
      HiveCacheService.cacheList('home_fruits', fruits);
      HiveCacheService.cacheList('home_prayers', prayers);
      HiveCacheService.cacheList('home_blogs', blogs);
      HiveCacheService.cacheList('home_videos', videos);
      HiveCacheService.cacheList('home_live_videos', liveVideos);
      HiveCacheService.cacheList('home_gallery_photos', galleryPhotos);
      HiveCacheService.cacheList('home_stories', stories);
      HiveCacheService.cacheList('home_groups', groups);
      HiveCacheService.cacheList('home_emojis', emojis);
      
      // Also cache in old service for compatibility (async)
      await CacheService.cacheList('home_fruits', fruits);
      await CacheService.cacheList('home_prayers', prayers);
      await CacheService.cacheList('home_blogs', blogs);
      await CacheService.cacheList('home_videos', videos);
      await CacheService.cacheList('home_live_videos', liveVideos);
      await CacheService.cacheList('home_gallery_photos', galleryPhotos);
      await CacheService.cacheList('home_stories', stories);
      await CacheService.cacheList('home_groups', groups);
      await CacheService.cacheList('home_emojis', emojis);

      print('💾 All data cached successfully (Hive + SharedPreferences)');
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
          criticalUrls.add('https://fruitofthespirit.templateforwebsites.com/${photo['file_path']}');
        }
      }
    }
    
    // Preload first 2 blogs (likely visible)
    if (blogs.isNotEmpty) {
      for (int i = 0; i < 2 && i < blogs.length; i++) {
        final blog = blogs[i];
        if (blog['image_url'] != null) {
          criticalUrls.add('https://fruitofthespirit.templateforwebsites.com/${blog['image_url']}');
        }
      }
    }
    
    // Preload first 2 videos (likely visible)
    if (videos.isNotEmpty) {
      for (int i = 0; i < 2 && i < videos.length; i++) {
        final video = videos[i];
        if (video['file_path'] != null) {
          criticalUrls.add('https://fruitofthespirit.templateforwebsites.com/${video['file_path']}');
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

  /// Load all 9 Fruits of the Spirit from database
  Future<void> loadFruits() async {
    try {
      print('🔄 Loading fruits from API...');
      final fruitsList = await FruitsService.getAllFruits();
      print('✅ Loaded ${fruitsList.length} fruits from database');
      for (var i = 0; i < fruitsList.length; i++) {
        print('   ${i + 1}. ID: ${fruitsList[i]['id']}, Name: ${fruitsList[i]['name']}');
      }
      fruits.value = fruitsList;
      print('✅ Fruits assigned to controller: ${fruits.length}');
    } catch (e) {
      print('❌ Error loading fruits: $e');
      // Keep existing data if available, don't clear on error
      if (fruits.isEmpty) {
      fruits.value = [];
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

  /// Load latest approved blogs from database
  Future<void> loadBlogs() async {
    try {
      final blogsList = await BlogsService.getBlogs(
        status: 'Approved',
        currentUserId: userId.value > 0 ? userId.value : null,
        limit: 5,
      );
      blogs.value = blogsList;
    } catch (e) {
      print('Error loading blogs: $e');
      if (blogs.isEmpty) {
      blogs.value = [];
      }
    }
  }

  /// Load latest approved videos from database
  /// Also includes pending videos for the current user
  Future<void> loadVideos() async {
    try {
      // Load approved videos
      final approvedVideos = await VideosService.getVideos(
        status: 'Approved',
        currentUserId: userId.value > 0 ? userId.value : null,
        limit: 5,
      );
      
      // Load pending videos for current user if logged in
      List<Map<String, dynamic>> allVideos = List.from(approvedVideos);

      if (userId.value > 0) {
        try {
          final pendingVideos = await VideosService.getVideos(
            status: 'Pending',
            userId: userId.value,
            limit: 10,
          );
          // Add pending videos at the beginning
          allVideos.insertAll(0, pendingVideos);
          print('📹 Pending Videos Loaded: ${pendingVideos.length}');
        } catch (e) {
          print('Error loading pending videos: $e');
        }
      }
      
      videos.value = allVideos;
      print('📹 Total Videos Loaded: ${allVideos.length} (Approved: ${approvedVideos.length})');
      for (var video in allVideos) {
        final status = video['status'] ?? 'Unknown';
        print('   - Video: ${video['file_path']} (Status: $status)');
      }
    } catch (e) {
      print('Error loading videos: $e');
      if (videos.isEmpty) {
        videos.value = [];
      }
    }
  }

  /// Load live videos from database
  Future<void> loadLiveVideos() async {
    try {
      final liveList = await VideosService.getLiveVideos();
      liveVideos.value = liveList;
      print('🔴 Live Videos Loaded: ${liveList.length}');
      for (var video in liveList) {
        print('   - Live Video: ${video['file_path']}');
      }
    } catch (e) {
      print('Error loading live videos: $e');
      if (liveVideos.isEmpty) {
      liveVideos.value = [];
      }
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

  /// Load latest approved gallery photos from database
  Future<void> loadGalleryPhotos() async {
    // Always include static images (Frame.png, Vector.png, Vectorser.png)
    // These are directly in uploads/ folder, not uploads/images/
    final staticImages = [
      {
        'id': -1,
        'file_path': 'uploads/Frame.png',
        'fruit_tag': 'Love',
        'testimony': 'Frame of love and kindness',
        'user_name': 'Community',
      },
      {
        'id': -2,
        'file_path': 'uploads/Vector.png',
        'fruit_tag': 'Joy',
        'testimony': 'Vector of joy and peace',
        'user_name': 'Community',
      },
      {
        'id': -3,
        'file_path': 'uploads/prayer_group.jpg',
        'fruit_tag': 'Peace',
        'testimony': 'Vector of peace and harmony',
        'user_name': 'Community',
      },
    ];
    
    try {
      final photosList = await GalleryService.getPhotos(
        status: 'Approved',
        currentUserId: userId.value > 0 ? userId.value : null,
        limit: 6,
      );
      
      print('📸 Gallery Photos Loaded:');
      print('   Static images: ${staticImages.length}');
      print('   API photos: ${photosList.length}');
      for (var img in staticImages) {
        print('   - Static: ${img['file_path']}');
      }
      for (var img in photosList) {
        print('   - API: ${img['file_path']}');
      }

      // Merge API photos with static images (static images first)
      galleryPhotos.value = [...staticImages, ...photosList];
      print('✅ Total gallery photos: ${galleryPhotos.length}');
    } catch (e) {
      print('Error loading gallery photos: $e');
      // On error, show static images
      galleryPhotos.value = [
        {
          'id': -1,
          'file_path': 'uploads/Frame.png',
          'fruit_tag': 'Love',
          'testimony': 'Frame of love and kindness',
          'user_name': 'Community',
        },
        {
          'id': -2,
          'file_path': 'uploads/Vector.png',
          'fruit_tag': 'Joy',
          'testimony': 'Vector of joy and peace',
          'user_name': 'Community',
        },
        {
          'id': -3,
          'file_path': 'uploads/prayer_group.jpg',
          'fruit_tag': 'Peace',
          'testimony': 'Vector of peace and harmony',
          'user_name': 'Community',
        },
      ];
    }
  }

  /// Load active groups from database
  Future<void> loadGroups() async {
    try {
      final groupsList = await GroupsService.getGroups(
        status: 'Active',
        limit: 6,
      );
      groups.value = groupsList;
    } catch (e) {
      print('Error loading groups: $e');
      if (groups.isEmpty) {
      groups.value = [];
      }
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
      final mainFruitsList = <Map<String, dynamic>>[];
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
            category == 'Fruits' || 
            (category.isEmpty && hasFruitName)) {
          mainFruitsList.add(emoji);
        } else if (category.toLowerCase().contains('opposite')) {
          oppositeEmojisList.add(emoji);
        } else if (category.toLowerCase().contains('emotion')) {
          emotionEmojisList.add(emoji);
        } else if (category.isEmpty) {
          // Default to main fruits if category is empty and name suggests it's a fruit
          if (hasFruitName) {
            mainFruitsList.add(emoji);
          } else {
            // Unknown category - add to all emojis but not to specific categories
            // This prevents empty categories from breaking the UI
          }
        }
      }
      
      print('📊 Emojis from database:');
      print('   Total emojis: ${emojisList.length}');
      print('   Main fruits: ${mainFruitsList.length}');
      print('   Opposite emojis: ${oppositeEmojisList.length}');
      print('   Emotion emojis: ${emotionEmojisList.length}');
      
      // Store all emojis
      emojis.value = mainFruitsList; // Main fruits for carousel
      allEmojis.value = allEmojisList; // All emojis for reference
      oppositeEmojis.value = oppositeEmojisList; // Opposite emojis
      emotionEmojis.value = emotionEmojisList; // Emotion emojis
      
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
    final baseUrl = 'https://fruitofthespirit.templateforwebsites.com/';
    final emojisBaseUrl = '${baseUrl}uploads/emojis/';
    
    // Map of spiritual fruits to physical fruit images from uploads/emojis folder
    // NOTE: This method is not currently used - fruits are loaded from database via loadEmojis()
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

  /// Refresh all data
  Future<void> refreshData() async {
    await loadHomeData();
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
    } catch (e) {
      // Ignore errors during disposal
      // This can happen during hot reload when scroll animation is active
      // The controller might already be disposed or in an invalid state
      // These errors are harmless and won't affect app functionality
    }
    super.onClose();
  }
}
