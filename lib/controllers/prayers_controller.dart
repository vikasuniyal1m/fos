import 'dart:async';

import 'package:fruitsofspirit/utils/fruit_emoji_helper.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:fruitsofspirit/services/hive_cache_service.dart';
import 'package:fruitsofspirit/services/prayers_service.dart';
import 'package:fruitsofspirit/services/comments_service.dart';
import 'package:fruitsofspirit/services/user_storage.dart';
import 'package:fruitsofspirit/services/api_service.dart';
import 'package:fruitsofspirit/services/emojis_service.dart';
import 'package:fruitsofspirit/services/advanced_service.dart';
import 'package:fruitsofspirit/services/content_moderation_service.dart';
import 'package:fruitsofspirit/routes/app_pages.dart';
import 'package:share_plus/share_plus.dart';

/// Prayers Controller
/// Manages prayer requests data and operations
class PrayersController extends GetxController {
  // Observable variables
  var isLoading = false.obs;
  var isDetailsSilentSyncing = false.obs;
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
  int _loadGeneration = 0;
  int _detailsLoadGeneration = 0;
  DateTime? _lastSyncedAt;
  DateTime? _detailsLastSyncedAt;
  static const Duration _minSyncInterval = Duration(minutes: 2);
  static const Duration _detailsMinSyncInterval = Duration(minutes: 2);
  Completer<void>? _activeLoadCompleter;
  final Set<int> _deletedCommentIds = {};

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
    if (_allPrayers.isNotEmpty) {
      _applyClientSideFilter();
      if (filterUserId.value == 0) {
        unawaited(loadPrayers(refresh: true, silent: true));
      }
      return;
    }

    if (filterUserId.value == 0 && !_isLoading) {
      loadPrayers(refresh: false);
    }
  }

  /// Seed prayers from home cache for instant open.
  void seedFromHomeIfEmpty(List<Map<String, dynamic>> homePrayers) {
    if (_allPrayers.isNotEmpty || homePrayers.isEmpty) return;
    _allPrayers = List<Map<String, dynamic>>.from(homePrayers);
    _isDataLoaded = true;
    _applyClientSideFilter();
  }

  /// Load user ID from storage
  Future<void> _loadUserId() async {
    final id = await UserStorage.getUserId();
    if (id != null) {
      userId.value = id;
    }
  }

  /// Load prayers
  Future<void> loadPrayers({bool refresh = false, bool silent = false}) async {
    if (filterUserId.value > 0) {
      refresh = true;
    }

    if (_isLoading) {
      if (_activeLoadCompleter != null) {
        await _activeLoadCompleter!.future;
      }
      if (_allPrayers.isNotEmpty) {
        _applyClientSideFilter();
      }
      return;
    }

    if (_isDataLoaded && !refresh && _allPrayers.isNotEmpty) {
      _applyClientSideFilter();
      return;
    }

    if (silent &&
        _lastSyncedAt != null &&
        DateTime.now().difference(_lastSyncedAt!) < _minSyncInterval) {
      if (_allPrayers.isNotEmpty) {
        _applyClientSideFilter();
      }
      return;
    }

    final generation = silent ? _loadGeneration : ++_loadGeneration;
    _activeLoadCompleter = Completer<void>();

    if (refresh) {
      currentPage.value = 0;
      _isDataLoaded = false;
    }

    _isLoading = true;
    if (!silent) {
      isLoading.value = true;
    }
    message.value = '';

    try {
      if (userId.value == 0) {
        await _loadUserId();
      }
      // Performance: Always load ALL prayers (no category filter) to populate cache
      // Then apply client-side filtering for instant updates
      final approvedPrayers = await PrayersService.getPrayers(
        status: 'Approved',
        category: null, // Always load all prayers for cache
        userId: filterUserId.value > 0 ? filterUserId.value : null,
        currentUserId: userId.value > 0 ? userId.value : null,
        limit: itemsPerPage,
        offset: currentPage.value * itemsPerPage,
      );

      if (generation != _loadGeneration) {
        return;
      }

      // If user wants to see their pending prayers, load them too
      List<Map<String, dynamic>> allPrayers = List.from(approvedPrayers);

      // Always include pending prayers if a user is logged in (only for current user)
      if (userId.value > 0 && filterUserId.value == 0) {
        try {
          final pendingPrayers = await PrayersService.getPrayers(
            status: 'Pending',
            userId: userId.value,
            category: null, // Always load all prayers for cache
            limit: 10,
            offset: 0,
          );
          // Add pending prayers at the beginning
          allPrayers.insertAll(0, pendingPrayers);
          print('🙏 Pending Prayers Loaded: ${pendingPrayers.length}');
        } catch (e) {
          print('Error loading pending prayers: $e');
        }

        // Load prayers shared with current user
        try {
          final sharedPrayers = await PrayersService.getPrayers(
            status: 'Approved',
            category: null,
            limit: 20,
            offset: 0,
            currentUserId: userId.value > 0 ? userId.value : null,
          );

          // Filter to only include prayers where current user is in shared_with
          final prayersSharedWithMe = sharedPrayers.where((prayer) {
            final sharedWith = prayer['shared_with'] as String? ?? '';
            if (sharedWith.isEmpty) return false;
            final sharedUserIds = sharedWith.split(',').map((id) => int.tryParse(id.trim()) ?? 0).toList();
            return sharedUserIds.contains(userId.value);
          }).toList();

          if (prayersSharedWithMe.isNotEmpty) {
            // Add shared prayers at the beginning after pending prayers
            allPrayers.insertAll(0, prayersSharedWithMe);
            print('🙏 Prayers Shared with Me Loaded: ${prayersSharedWithMe.length}');
          }
        } catch (e) {
          print('Error loading shared prayers: $e');
        }
      }

      print('🙏 Total Prayers Loaded: ${allPrayers.length} (Approved: ${approvedPrayers.length})');
      for (var prayer in allPrayers) {
        final status = prayer['status'] ?? 'Unknown';
        print('   - Prayer: ${prayer['id']} (Status: $status)');
      }

      if (!silent && generation != _loadGeneration) {
        return;
      }

      if (refresh || currentPage.value == 0) {
        final hasChanged = !_prayerListsEqual(_allPrayers, allPrayers);
        if (hasChanged || _allPrayers.isEmpty) {
          _allPrayers = List<Map<String, dynamic>>.from(allPrayers);
          _applyClientSideFilter();
        }
      } else {
        _allPrayers.addAll(allPrayers);
        _applyClientSideFilter();
      }

      _isDataLoaded = true;
      _lastSyncedAt = DateTime.now();
    } catch (e) {
      if (!silent) {
        message.value = 'Error loading prayers: ${e.toString().replaceAll('Exception: ', '')}';
      }
      print('Error loading prayers: $e');
      if (!silent && (refresh || currentPage.value == 0) && _allPrayers.isEmpty) {
        prayers.value = [];
        _isDataLoaded = false;
      } else if (_allPrayers.isNotEmpty) {
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

  bool _prayerListsEqual(
    List<Map<String, dynamic>> previous,
    List<Map<String, dynamic>> next,
  ) {
    if (identical(previous, next)) return true;
    if (previous.length != next.length) return false;

    for (var i = 0; i < previous.length; i++) {
      final prev = previous[i];
      final curr = next[i];
      if (prev['id'] != curr['id']) return false;
      if (prev['updated_at'] != curr['updated_at']) return false;
      if (prev['response_count'] != curr['response_count']) return false;
      if (prev['comment_count'] != curr['comment_count']) return false;
      if (prev['status'] != curr['status']) return false;
    }
    return true;
  }

  /// Load more prayers (pagination)
  Future<void> loadMore() async {
    if (isLoading.value) return;

    currentPage.value++;
    await loadPrayers();
  }

  int? _prayerIdFromMap(Map<String, dynamic> prayer) {
    final id = prayer['id'];
    if (id is int) return id;
    return int.tryParse(id?.toString() ?? '');
  }

  String _prayerDetailHiveKey(int prayerId) => 'prayer_detail_$prayerId';

  /// Show list/Hive data immediately before opening detail screen.
  void seedPrayerDetailFromList(int prayerId) {
    if (_prayerIdFromMap(selectedPrayer) == prayerId && selectedPrayer.isNotEmpty) {
      return;
    }

    Map<String, dynamic>? found;
    for (final prayer in _allPrayers) {
      if (_prayerIdFromMap(prayer) == prayerId) {
        found = prayer;
        break;
      }
    }
    if (found == null) {
      for (final prayer in prayers) {
        if (_prayerIdFromMap(prayer) == prayerId) {
          found = prayer;
          break;
        }
      }
    }

    if (found != null) {
      selectedPrayer.value = Map<String, dynamic>.from(found);
    }
  }

  void loadPrayerDetailFromHive(int prayerId) {
    if (_prayerIdFromMap(selectedPrayer) == prayerId && selectedPrayer.isNotEmpty) {
      return;
    }
    final cached = HiveCacheService.getCachedData(_prayerDetailHiveKey(prayerId));
    if (cached is Map && cached['prayer'] is Map) {
      selectedPrayer.value =
          Map<String, dynamic>.from(cached['prayer'] as Map<String, dynamic>);
    }
  }

  Future<void> _cachePrayerDetail(int prayerId) async {
    if (selectedPrayer.isEmpty) return;
    await HiveCacheService.cacheData(
      _prayerDetailHiveKey(prayerId),
      {
        'prayer': Map<String, dynamic>.from(selectedPrayer),
        'cached_at': DateTime.now().millisecondsSinceEpoch,
      },
      expiryHours: 24,
    );
  }

  /// Cache/list seed first, then silent API sync when preview exists.
  Future<void> preparePrayerDetails(int prayerId) async {
    if (prayerId <= 0) return;

    seedPrayerDetailFromList(prayerId);
    loadPrayerDetailFromHive(prayerId);

    final hasPreview =
        _prayerIdFromMap(selectedPrayer) == prayerId && selectedPrayer.isNotEmpty;
    if (!hasPreview) {
      await loadPrayerDetails(prayerId, silent: false);
    } else {
      unawaited(loadPrayerDetails(prayerId, silent: true));
    }
  }

  /// Load single prayer with comments (silent = no blocking spinner if preview exists).
  Future<void> loadPrayerDetails(
    int prayerId, {
    bool silent = false,
    bool force = false,
  }) async {
    if (silent &&
        !force &&
        _detailsLastSyncedAt != null &&
        _prayerIdFromMap(selectedPrayer) == prayerId &&
        DateTime.now().difference(_detailsLastSyncedAt!) < _detailsMinSyncInterval) {
      return;
    }

    final generation = silent ? _detailsLoadGeneration : ++_detailsLoadGeneration;
    final hadPreview =
        _prayerIdFromMap(selectedPrayer) == prayerId && selectedPrayer.isNotEmpty;

    if (!silent && !hadPreview) {
      isLoading.value = true;
    } else {
      isDetailsSilentSyncing.value = true;
    }
    message.value = '';

    try {
      if (userId.value == 0) {
        await _loadUserId();
      }

      final prayer = await PrayersService.getPrayerDetails(
        prayerId,
        currentUserId: userId.value > 0 ? userId.value : null,
      );

      if (generation != _detailsLoadGeneration) {
        return;
      }

      selectedPrayer.value = prayer;

      await Future.wait([
        loadAvailableEmojis(),
        loadQuickEmojis(),
        loadPrayerComments(prayerId),
      ]);

      if (generation != _detailsLoadGeneration) {
        return;
      }

      _detailsLastSyncedAt = DateTime.now();
      unawaited(_cachePrayerDetail(prayerId));
    } catch (e) {
      if (!silent || !hadPreview) {
        message.value =
            'Error loading prayer: ${e.toString().replaceAll('Exception: ', '')}';
      }
      print('Error loading prayer details: $e');
    } finally {
      isLoading.value = false;
      isDetailsSilentSyncing.value = false;
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
        if (_isCommentDeleted(comment)) continue;

        // Handle both 'content' and 'comment' fields for backward compatibility
        final content = (comment['content'] as String? ?? comment['comment'] as String? ?? '').trim();
        final trimmed = content;
        final parentId = _normalizeParentId(comment['parent_comment_id']);
        final commentId = _commentId(comment);
        
        // Debug: Check if this is a reply
        if (parentId != null) {
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
        // Strategy 5: Check if it's a fruit keyword using Helper
        else if (FruitEmojiHelper.isFruit(trimmed)) {
          isEmojiReaction = true;
          emojiKey = trimmed;
          print('✅ Found emoji reaction (fruit keyword): $emojiKey');
        }

        // FIX: Add ALL top-level comments to textComments (including emoji comments)
        // Emoji reactions and emoji comments are both stored in comments table
        // The UI (FruitEmojiHelper.buildCommentText) will render emoji URLs as images
        if (parentId == null) {
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
          
          textComments.add(_filterDeletedFromTree(comment));
          print('✅ Added to prayerComments: id=$commentId, isEmoji=$isEmojiReaction');
          
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
        } else {
          print('⏭️ Skipping reply (will be shown in parent comment): id=$commentId, parent=$parentId');
        }
      }
      
      print('📊 Loaded ${emojiReactions.length} emoji reaction types and ${textComments.length} top-level comments');
      for (var emoji in emojiReactions.keys) {
        print('   - $emoji: ${emojiReactions[emoji]!.length} reactions');
      }
      
      prayerComments.value = textComments;
      prayerEmojiReactions.value = emojiReactions;
      _deletedCommentIds.removeWhere((id) => !_commentExistsInList(textComments, id));
    } catch (e) {
      print('❌ Error loading prayer comments: $e');
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
    for (final comment in prayerComments) {
      if (_commentId(comment) == commentId) continue;
      updated.add(_stripCommentFromTree(comment, commentId));
    }
    prayerComments.value = updated;
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
      for (final existing in prayerComments) {
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
      prayerComments.value = updated;
      return;
    }

    prayerComments.add(comment);
  }

  void _replaceTempCommentId(int tempId, int realId) {
    final updated = <Map<String, dynamic>>[];
    for (final comment in prayerComments) {
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
    prayerComments.value = updated;
  }

  Future<void> _deleteCommentOnServer(int prayerId, int commentId) async {
    try {
      await CommentsService.deleteComment(
        userId: userId.value,
        commentId: commentId,
        postType: 'prayer',
      );
    } catch (e) {
      _deletedCommentIds.remove(commentId);
      message.value = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      unawaited(loadPrayerComments(prayerId));
    }
  }

  /// Delete a prayer comment with instant UI update.
  Future<bool> deletePrayerComment(int prayerId, int commentId) async {
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
    prayerComments.refresh();
    unawaited(_deleteCommentOnServer(prayerId, commentId));
    return true;
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
    if (availableEmojis.isNotEmpty) return;
    try {
      final emojis = await EmojisService.getEmojis(
        status: 'Active',
        sortBy: 'image_url',
        order: 'ASC',
      );
      availableEmojis.value = emojis;
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
      
      unawaited(loadPrayerComments(prayerId));
      
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

  Future<void> _insertCreatedPrayerLocally({
    required int id,
    required String category,
    required String content,
    String? prayerFor,
    bool isAnonymous = false,
  }) async {
    final user = await UserStorage.getUser();
    final prayer = <String, dynamic>{
      'id': id,
      'category': category,
      'content': content,
      'prayer_for': prayerFor ?? 'Me',
      'status': 'Pending',
      'is_anonymous': isAnonymous ? 1 : 0,
      'user_id': userId.value,
      'user_name': isAnonymous ? 'Anonymous' : (user?['name'] ?? 'You'),
      'profile_photo': isAnonymous ? null : user?['profile_photo'],
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'response_count': 0,
      'comment_count': 0,
    };
    _allPrayers.removeWhere((p) => _prayerIdFromMap(p) == id);
    _allPrayers.insert(0, prayer);
    _isDataLoaded = true;
    _applyClientSideFilter();
  }

  void _removePrayerLocally(int prayerId) {
    _allPrayers.removeWhere((p) => _prayerIdFromMap(p) == prayerId);
    prayers.removeWhere((p) => _prayerIdFromMap(p) == prayerId);
    prayers.refresh();
    if (_prayerIdFromMap(selectedPrayer) == prayerId) {
      selectedPrayer.clear();
    }
    unawaited(HiveCacheService.clearKey(_prayerDetailHiveKey(prayerId)));
  }

  /// Delete prayer — API first, remove locally, sync list in background.
  Future<bool> deletePrayer(int prayerId) async {
    if (userId.value == 0) {
      await _loadUserId();
    }

    if (userId.value == 0) {
      message.value = 'Please login first';
      return false;
    }

    try {
      await PrayersService.deletePrayer(
        userId: userId.value,
        prayerId: prayerId,
      );
      _removePrayerLocally(prayerId);
      unawaited(loadPrayers(refresh: true, silent: true));
      return true;
    } catch (e) {
      message.value = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      print('Error deleting prayer: $e');
      return false;
    }
  }

  /// Create prayer request — no blocking full-list reload after submit.
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

    final moderationCheck = ContentModerationService.checkContent(content);
    if (!moderationCheck['isClean']) {
      message.value = moderationCheck['message'];
      return false;
    }

    message.value = '';

    try {
      final newId = await PrayersService.createPrayerRequest(
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

      await _insertCreatedPrayerLocally(
        id: newId,
        category: category,
        content: content,
        prayerFor: prayerFor,
        isAnonymous: isAnonymous,
      );

      message.value = 'Prayer request submitted. Waiting for admin approval.';
      unawaited(loadPrayers(refresh: true, silent: true));
      return true;
    } catch (e) {
      message.value = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      print('Error creating prayer: $e');
      return false;
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
    prayerComments.refresh();
    unawaited(
      _submitCommentToServer(
        prayerId: prayerId,
        content: content,
        parentCommentId: parentCommentId,
        tempId: tempId,
      ),
    );
    return true;
  }

  Future<void> _submitCommentToServer({
    required int prayerId,
    required String content,
    required int tempId,
    int? parentCommentId,
  }) async {
    try {
      final commentId = await CommentsService.addComment(
        userId: userId.value,
        postType: 'prayer',
        postId: prayerId,
        content: content,
        parentCommentId: parentCommentId,
      );
      if (commentId > 0) {
        _replaceTempCommentId(tempId, commentId);
        prayerComments.refresh();
      }
      unawaited(loadPrayerComments(prayerId));
    } catch (e) {
      _removeCommentLocally(tempId);
      prayerComments.refresh();
      message.value = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
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
      
      for (var i = 0; i < prayerComments.length; i++) {
        if (_commentId(prayerComments[i]) == commentId) {
          prayerComments[i]['is_liked'] = result['liked'] == true ? 1 : 0;
          prayerComments[i]['like_count'] = result['like_count'] ?? 0;
          prayerComments.refresh();
          return true;
        }
      }

      for (var i = 0; i < prayerComments.length; i++) {
        final comment = prayerComments[i];
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
          prayerComments[i] = Map<String, dynamic>.from(comment)
            ..['replies'] = updatedReplies;
          prayerComments.refresh();
          return true;
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

  /// Set initial data from cache
  void setInitialData(List<Map<String, dynamic>> data) {
    if (data.isNotEmpty) {
      _allPrayers = List<Map<String, dynamic>>.from(data);
      _isDataLoaded = true;
      _applyClientSideFilter();
    }
  }

  void reapplyFilter() {
    _applyClientSideFilter();
  }

  /// Apply client-side filter instantly (no API call)
  void _applyClientSideFilter() {
    if (_allPrayers.isEmpty) {
      prayers.value = [];
      prayers.refresh();
      return;
    }

    var filtered = List<Map<String, dynamic>>.from(_allPrayers);

    if (filterUserId.value > 0) {
      filtered = filtered
          .where(
            (prayer) =>
                prayer['user_id']?.toString() == filterUserId.value.toString(),
          )
          .toList();
    }

    if (selectedCategory.value.isNotEmpty) {
      filtered = filtered.where((prayer) {
        final prayerCategory = prayer['category'] as String? ??
            prayer['type'] as String? ??
            prayer['prayer_type'] as String? ??
            '';
        return prayerCategory.toLowerCase() ==
            selectedCategory.value.toLowerCase();
      }).toList();
    }

    prayers.value = filtered;
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

  
  /// Show moderation snackbar - This method is called from UI, so context will be passed from there
  /// Note: This method should be called from UI layer with proper context
  void _showModerationSnackbar(String message) {
    // This method is now just a placeholder - moderation messages will be shown through the UI layer's _showCustomSnackbar
    this.message.value = message;
  }

  @override
  void onClose() {
    prayers.clear();
    _allPrayers.clear();
    prayerComments.clear();
    prayerEmojiReactions.clear();
    _isDataLoaded = false;
    super.onClose();
  }
}

