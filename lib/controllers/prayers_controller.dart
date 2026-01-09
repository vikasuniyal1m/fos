import 'package:get/get.dart';
import 'package:fruitsofspirit/services/prayers_service.dart';
import 'package:fruitsofspirit/services/comments_service.dart';
import 'package:fruitsofspirit/services/user_storage.dart';
import 'package:fruitsofspirit/services/api_service.dart';
import 'package:fruitsofspirit/services/emojis_service.dart';
import 'package:fruitsofspirit/services/advanced_service.dart';
import 'package:share_plus/share_plus.dart';

/// Prayers Controller
/// Manages prayer requests data and operations
class PrayersController extends GetxController {
  // Observable variables
  var isLoading = false.obs;
  var message = ''.obs;
  
  // Data
  var prayers = <Map<String, dynamic>>[].obs;
  var selectedPrayer = <String, dynamic>{}.obs;
  var prayerComments = <Map<String, dynamic>>[].obs;
  var prayerEmojiReactions = <String, List<Map<String, dynamic>>>{}.obs; // emoji -> list of users who reacted
  var availableEmojis = <Map<String, dynamic>>[].obs;
  var quickEmojis = <Map<String, dynamic>>[].obs; // Top 6 emojis for quick reactions
  var userId = 0.obs;

  // Filters
  var selectedCategory = ''.obs;
  var filterUserId = 0.obs; // Filter by specific user ID (0 = all users)
  var currentPage = 0.obs;
  final int itemsPerPage = 20;
  
  // Performance: Store all prayers for instant client-side filtering
  var _allPrayers = <Map<String, dynamic>>[];
  
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
    // Performance: Only load if data is not already loaded and filter is not set
    // If filter is set, it means we're coming from profile, so loadPrayers will be called after navigation
    // Don't reload if data already exists
    if (!_isDataLoaded && filterUserId.value == 0 && !_isLoading && prayers.isEmpty && _allPrayers.isEmpty) {
      loadPrayers();
    } else if (_allPrayers.isNotEmpty) {
      // Apply filter from cached data if available
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

  /// Load prayers
  Future<void> loadPrayers({bool refresh = false}) async {

    if (filterUserId.value > 0) {
      refresh = true;
    }

    // Performance: Skip if already loading
    if (_isLoading && !refresh) {
      return;
    }
    
    // Performance: Skip if data already loaded and not explicitly refreshing
    if (_isDataLoaded && !refresh && prayers.isNotEmpty && _allPrayers.isNotEmpty) {
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
      // Performance: Always load ALL prayers (no category filter) to populate cache
      // Then apply client-side filtering for instant updates
      final prayersList = await PrayersService.getPrayers(
        status: filterUserId.value > 0 ? 'Pending,Approved' : 'Approved',        category: null, // Always load all prayers for cache
        userId: filterUserId.value > 0 ? filterUserId.value : null,
        limit: itemsPerPage,
        offset: currentPage.value * itemsPerPage,
      );

      if (refresh || currentPage.value == 0) {
        // Performance: Store ALL prayers in cache (no category filter)
        _allPrayers = List<Map<String, dynamic>>.from(prayersList);
        // Apply current filter to display
        _applyClientSideFilter();
      } else {
        // Performance: Add to all prayers cache
        _allPrayers.addAll(prayersList);
        // Apply current filter to display
        _applyClientSideFilter();
      }
      
      // Performance: Mark as loaded
      _isDataLoaded = true;
    } catch (e) {
      message.value = 'Error loading prayers: ${e.toString().replaceAll('Exception: ', '')}';
      print('Error loading prayers: $e');
      if (refresh || currentPage.value == 0) {
        prayers.value = [];
        _isDataLoaded = false;
      }
    } finally {
      _isLoading = false;
      isLoading.value = false;
    }
  }

  /// Load more prayers (pagination)
  Future<void> loadMore() async {
    if (isLoading.value) return;

    currentPage.value++;
    await loadPrayers();
  }

  /// Load single prayer with comments
  Future<void> loadPrayerDetails(int prayerId) async {
    isLoading.value = true;
    message.value = '';

    try {
      final prayer = await PrayersService.getPrayerDetails(prayerId);
      selectedPrayer.value = prayer;
      
      // Load comments
      await loadPrayerComments(prayerId);
    } catch (e) {
      message.value = 'Error loading prayer: ${e.toString().replaceAll('Exception: ', '')}';
      print('Error loading prayer details: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Load prayer comments
  Future<void> loadPrayerComments(int prayerId) async {
    try {
      print('🔄 Loading prayer comments for prayer_id: $prayerId');
      final comments = await CommentsService.getComments(
        postType: 'prayer',
        postId: prayerId,
        userId: userId.value > 0 ? userId.value : null,
      );
      
      print('📥 Received ${comments.length} comments from API');
      print('📥 Raw comments data:');
      for (var i = 0; i < comments.length && i < 5; i++) {
        final comment = comments[i];
        print('   Comment ${i + 1}: id=${comment['id']}, content="${comment['content']}", user=${comment['user_name']}, parent=${comment['parent_comment_id']}');
      }
      
      // Separate emoji reactions from text comments
      final textComments = <Map<String, dynamic>>[];
      final emojiReactions = <String, List<Map<String, dynamic>>>{};
      
      for (var comment in comments) {
        final content = comment['content'] as String? ?? '';
        final trimmed = content.trim();
        final parentId = comment['parent_comment_id'];
        final commentId = comment['id'];
        
        // Debug: Check if this is a reply
        if (parentId != null && parentId != 0) {
          print('🔗 Found reply in main list: comment_id=$commentId, parent_comment_id=$parentId');
          print('   ⚠️ WARNING: This reply should NOT be in the main comments list!');
          print('   ⚠️ Backend should only return top-level comments with replies in replies array');
          // Skip this - it's a reply that should be in parent's replies array
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
          // It's a text comment - add to text comments list
          // Only add top-level comments (replies are nested in 'replies' array)
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
      
      prayerComments.value = textComments;
      prayerEmojiReactions.value = emojiReactions;
    } catch (e) {
      print('❌ Error loading prayer comments: $e');
      prayerComments.value = [];
      prayerEmojiReactions.value = <String, List<Map<String, dynamic>>>{};
    }
  }

  /// Check if string is an emoji
  bool _isEmoji(String text) {
    if (text.isEmpty) return false;
    final trimmed = text.trim();
    
    // Check length - emojis are usually 1-4 characters (including variation selectors)
    if (trimmed.length > 4) return false;
    
    // Check if it contains only emoji characters (no letters, numbers, or punctuation)
    // More comprehensive emoji regex
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

  /// Add/Remove emoji reaction to prayer (TOGGLE)
  /// If user already reacted, removes it. Otherwise, adds it.
  Future<bool> addEmojiReaction(int prayerId, String emoji) async {
    if (userId.value == 0) {
      await _loadUserId();
    }

    if (userId.value == 0) {
      message.value = 'Please login first';
      return false;
    }

    try {
      final result = await EmojisService.useEmoji(
        userId: userId.value,
        emoji: emoji,
        postType: 'prayer',
        postId: prayerId,
      );
      
      // Reload comments to get updated reactions with user info (this will update prayerEmojiReactions)
      await loadPrayerComments(prayerId);
      
      // Check if reaction was removed or added
      if (result.contains('removed')) {
        print('✅ Emoji reaction removed (toggled off): $emoji');
      } else {
        print('✅ Emoji reaction added (toggled on): $emoji');
      }
      print('📊 Current reactions: ${prayerEmojiReactions.length} emoji types');
      for (var emojiKey in prayerEmojiReactions.keys) {
        print('   - $emojiKey: ${prayerEmojiReactions[emojiKey]!.length} users');
      }
      
      return true;
    } catch (e) {
      message.value = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      print('Error toggling emoji reaction: $e');
      return false;
    }
  }

  /// Create prayer request
  Future<bool> createPrayer({
    required String category,
    required String content,
    String? prayerFor,
    bool allowEncouragement = true,
    bool isAnonymous = false,
    List<int>? sharedWithUserIds,
    int? taggedUserId,
    int? taggedGroupId,
  }) async {
    if (userId.value == 0) {
      await _loadUserId();
    }

    if (userId.value == 0) {
      message.value = 'Please login first';
      return false;
    }

    isLoading.value = true;
    message.value = '';

    try {
      await PrayersService.createPrayerRequest(
        userId: userId.value,
        category: category,
        content: content,
        prayerFor: prayerFor,
        allowEncouragement: allowEncouragement,
        isAnonymous: isAnonymous,
        sharedWithUserIds: sharedWithUserIds,
        taggedUserId: taggedUserId,
        taggedGroupId: taggedGroupId,
      );
      
      message.value = 'Prayer request submitted. Waiting for admin approval.';
      
      // Reload prayers and force UI refresh
      await loadPrayers(refresh: true);
      
      // Force UI refresh to ensure new prayer appears
      prayers.refresh();
      
      return true;
    } catch (e) {
      message.value = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      print('Error creating prayer: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Add comment to prayer
  Future<bool> addComment(int prayerId, String content, {int? parentCommentId}) async {
    if (userId.value == 0) {
      await _loadUserId();
    }

    if (userId.value == 0) {
      message.value = 'Please login first';
      return false;
    }

    try {
      final isReply = parentCommentId != null && parentCommentId > 0;
      print('📝 Adding ${isReply ? "REPLY" : "COMMENT"}: prayerId=$prayerId, parentCommentId=$parentCommentId, content=${content.substring(0, content.length > 20 ? 20 : content.length)}...');
      
      final commentId = await CommentsService.addComment(
        userId: userId.value,
        postType: 'prayer',
        postId: prayerId,
        content: content,
        parentCommentId: parentCommentId,
      );
      
      print('✅ ${isReply ? "Reply" : "Comment"} added successfully (ID: $commentId), reloading comments...');
      
      // Reload comments to get updated structure with nested replies
      await loadPrayerComments(prayerId);
      
      // Force UI refresh for comments
      prayerComments.refresh();
      prayerEmojiReactions.refresh();
      
      // Debug: Check if reply was added to parent
      if (isReply) {
        for (var comment in prayerComments) {
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
      
      print('✅ Comments reloaded: ${prayerComments.length} top-level comments, ${prayerEmojiReactions.length} emoji reactions');
      
      return true;
    } catch (e) {
      message.value = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      print('❌ Error adding comment: $e');
      return false;
    }
  }
  
  /// Like/Unlike Comment
  Future<bool> toggleCommentLike(int commentId) async {
    if (userId.value == 0) {
      await _loadUserId();
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
      
      // Update comment in list
      for (var i = 0; i < prayerComments.length; i++) {
        if (prayerComments[i]['id'] == commentId) {
          prayerComments[i]['is_liked'] = result['liked'] == true ? 1 : 0;
          prayerComments[i]['like_count'] = result['like_count'] ?? 0;
          break;
        }
      }
      
      // Also update in replies
      for (var comment in prayerComments) {
        if (comment['replies'] != null) {
          final replies = List<Map<String, dynamic>>.from(comment['replies']);
          for (var i = 0; i < replies.length; i++) {
            if (replies[i]['id'] == commentId) {
              replies[i]['is_liked'] = result['liked'] == true ? 1 : 0;
              replies[i]['like_count'] = result['like_count'] ?? 0;
              comment['replies'] = replies;
              break;
            }
          }
        }
      }
      
      return true;
    } catch (e) {
      message.value = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      print('❌ Error toggling comment like: $e');
      return false;
    }
  }
  
  /// Report Comment
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
      print('❌ Error reporting comment: $e');
      return false;
    }
  }

  /// Apply client-side filter instantly (no API call)
  void _applyClientSideFilter() {
    if (_allPrayers.isEmpty) {
      prayers.value = [];
      prayers.refresh();
      return;
    }
    
    if (selectedCategory.value.isEmpty) {
      // Show all prayers - create new list instance
      prayers.value = List<Map<String, dynamic>>.from(_allPrayers);
    } else {
      // Filter by category client-side - create new list instance
      prayers.value = List<Map<String, dynamic>>.from(_allPrayers.where((prayer) {
        final prayerCategory = prayer['category'] as String? ?? 
                               prayer['type'] as String? ?? 
                               prayer['prayer_type'] as String? ?? '';
        return prayerCategory.toLowerCase() == selectedCategory.value.toLowerCase();
      }).toList());
    }
    // Force UI refresh
    prayers.refresh();
  }

  /// Filter by category - Instant client-side filtering only (no API call if data exists)
  void filterByCategory(String category) {
    // Performance: Only filter if category is actually changing
    if (selectedCategory.value != category) {
      selectedCategory.value = category;
      
      // If "All" is selected, always show all from cache or reload if needed
      if (category.isEmpty) {
        if (_allPrayers.isNotEmpty) {
          // Show all prayers from cache instantly
          _applyClientSideFilter();
        } else {
          // No cache, load all prayers
          _isDataLoaded = false;
          loadPrayers(refresh: true);
        }
        return;
      }
      
      // If specific category selected and we have cached data, filter instantly
      if (_allPrayers.isNotEmpty) {
        _applyClientSideFilter();
        return;
      }
      
      // Only load from API if no cached data exists
      if (_allPrayers.isEmpty) {
        _isDataLoaded = false;
        loadPrayers(refresh: true);
      }
    }
  }

  /// Clear filter - Instant client-side filtering only (no API call if data exists)
  void clearFilter() {
    // Performance: Only clear if filter is actually set
    if (selectedCategory.value.isNotEmpty) {
      selectedCategory.value = '';
      
      // Performance: Show all prayers instantly from cached data (no API call)
      if (_allPrayers.isNotEmpty) {
        _applyClientSideFilter();
        // Don't refresh from API - use cached data only
        return;
      }
      
      // Only load from API if no cached data exists
      if (_allPrayers.isEmpty) {
        _isDataLoaded = false;
        loadPrayers(refresh: true);
      }
    }
  }

  /// Refresh data - Only refresh if explicitly called (pull to refresh)
  Future<void> refresh() async {
    // Force refresh only when user explicitly pulls to refresh
    _isDataLoaded = false;
    await loadPrayers(refresh: true);
  }

  /// Share prayer request
  Future<bool> sharePrayer(int prayerId) async {
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
        contentType: 'prayer',
        contentId: prayerId,
      );
      
      await Share.share(
        'Check out this prayer request: $shareLink',
        subject: 'Prayer Request',
      );
      
      message.value = 'Prayer request shared successfully';
      return true;
    } catch (e) {
      message.value = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      print('Error sharing prayer: $e');
      return false;
    }
  }

  /// Save prayer request
  Future<bool> savePrayer(int prayerId) async {
    if (userId.value == 0) {
      await _loadUserId();
    }

    if (userId.value == 0) {
      message.value = 'Please login first';
      return false;
    }

    try {
      await AdvancedService.saveContent(
        userId: userId.value,
        contentType: 'prayer',
        contentId: prayerId,
      );
      
      message.value = 'Prayer request saved';
      return true;
    } catch (e) {
      message.value = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      print('Error saving prayer: $e');
      return false;
    }
  }

  /// Report prayer request
  Future<bool> reportPrayer(int prayerId, {String? reason, String? description}) async {
    if (userId.value == 0) {
      await _loadUserId();
    }

    if (userId.value == 0) {
      message.value = 'Please login first';
      return false;
    }

    try {
      await AdvancedService.reportContent(
        userId: userId.value,
        contentType: 'prayer',
        contentId: prayerId,
        reason: reason,
        description: description,
      );
      
      message.value = 'Prayer request reported. Thank you for keeping our community safe.';
      return true;
    } catch (e) {
      message.value = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      print('Error reporting prayer: $e');
      return false;
    }
  }

  /// Block user
  Future<bool> blockUser(int blockedUserId) async {
    if (userId.value == 0) {
      await _loadUserId();
    }

    if (userId.value == 0) {
      message.value = 'Please login first';
      return false;
    }

    try {
      await AdvancedService.blockUser(
        userId: userId.value,
        blockedUserId: blockedUserId,
      );
      
      message.value = 'User blocked successfully';
      return true;
    } catch (e) {
      message.value = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      print('Error blocking user: $e');
      return false;
    }
  }

  /// Follow user
  Future<bool> followUser(int followUserId) async {
    if (userId.value == 0) {
      await _loadUserId();
    }

    if (userId.value == 0) {
      message.value = 'Please login first';
      return false;
    }

    try {
      await AdvancedService.followUser(
        userId: userId.value,
        followUserId: followUserId,
      );
      
      message.value = 'User followed successfully';
      return true;
    } catch (e) {
      message.value = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      print('Error following user: $e');
      return false;
    }
  }
}

