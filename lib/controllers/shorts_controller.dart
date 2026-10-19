import 'dart:async';
import 'dart:io';
import 'package:get/get.dart';
import 'package:fruitsofspirit/services/shorts_service.dart';
import 'package:fruitsofspirit/services/user_storage.dart';
import 'package:fruitsofspirit/services/hive_cache_service.dart';
import 'package:fruitsofspirit/services/api_service.dart';
import 'package:fruitsofspirit/services/short_video_preload_service.dart';
import 'package:fruitsofspirit/controllers/home_controller.dart';
import 'package:fruitsofspirit/controllers/profile_controller.dart';
import 'package:fruitsofspirit/services/sticker_service.dart';
import 'package:fruitsofspirit/utils/sticker_emoji_helper.dart';

/// Shorts Controller — isolated state for Shorts module
class ShortsController extends GetxController {
  var isLoading = false.obs;
  var isSilentSyncing = false.obs;
  var isUploading = false.obs;
  var message = ''.obs;
  var shorts = <Map<String, dynamic>>[].obs;
  var communityShorts = <Map<String, dynamic>>[].obs;
  var myShorts = <Map<String, dynamic>>[].obs;
  var savedShorts = <Map<String, dynamic>>[].obs;
  var comments = <Map<String, dynamic>>[].obs;
  var commentsSyncing = false.obs;
  var userId = 0.obs;
  var hasMore = true.obs;
  int? _nextCursor;
  Timer? _pollTimer;
  static const String _hiveKey = 'shorts_feed';
  static const String _communityHiveKey = 'shorts_community';
  static const String _homeShortsHiveKey = 'home_shorts';
  static const String _myHiveKey = 'shorts_my';
  static const Duration _pollInterval = Duration(seconds: 8);
  static const Duration _minSyncInterval = Duration(minutes: 2);
  static const int maxShortDurationSeconds = 30;
  var feedMode = 'community'.obs;
  DateTime? _lastSyncedAt;
  int _loadGeneration = 0;
  var _isLoading = false;
  int? _commentsShortId;
  bool _commentsLoading = false;
  int _commentsLoadGeneration = 0;
  int _commentsPosting = 0;
  final Map<int, List<Map<String, dynamic>>> _commentsCache = {};
  final Map<int, DateTime> _commentsSyncedAt = {};
  static const int _commentsCacheLimit = 8;

  @override
  void onInit() {
    super.onInit();
    _loadUserId();
    _loadFromHive();
  }

  @override
  void onClose() {
    _pollTimer?.cancel();
    super.onClose();
  }

  Future<void> _loadUserId() async {
    userId.value = await UserStorage.getUserId() ?? 0;
  }

  Future<void> ensureUserId() async {
    if (userId.value <= 0) await _loadUserId();
  }

  static String _commentsHiveKey(int shortId) => 'short_comments_$shortId';

  void _loadFromHive() {
    final communityCached = HiveCacheService.getCachedList(_communityHiveKey);
    if (communityCached.isNotEmpty) {
      communityShorts.value = List<Map<String, dynamic>>.from(communityCached);
      if (feedMode.value == 'community' && shorts.isEmpty) {
        shorts.value = List<Map<String, dynamic>>.from(communityCached);
      }
    }
    final myCached = HiveCacheService.getCachedList(_myHiveKey);
    if (myCached.isNotEmpty) {
      myShorts.value = List<Map<String, dynamic>>.from(myCached);
    }
  }

  void bootstrapFeedCache(String mode) {
    if (mode == 'mine') {
      final cached = HiveCacheService.getCachedList(_myHiveKey);
      if (cached.isNotEmpty) {
        myShorts.value = List<Map<String, dynamic>>.from(cached);
        shorts.value = List<Map<String, dynamic>>.from(cached);
      }
      return;
    }

    final cached = HiveCacheService.getCachedList(_communityHiveKey);
    if (cached.isNotEmpty) {
      communityShorts.value = List<Map<String, dynamic>>.from(cached);
      shorts.value = List<Map<String, dynamic>>.from(cached);
      return;
    }

    final homeCached = HiveCacheService.getCachedList(_homeShortsHiveKey);
    if (homeCached.isNotEmpty) {
      communityShorts.value = List<Map<String, dynamic>>.from(homeCached);
      shorts.value = List<Map<String, dynamic>>.from(homeCached);
    }
  }

  /// Cache-first open — same pattern as prayers/notifications.
  Future<void> prepareCommunityFeed({
    List<Map<String, dynamic>>? seed,
    int startIndex = 0,
  }) async {
    feedMode.value = 'community';
    bootstrapFeedCache('community');

    if (seed != null && seed.isNotEmpty) {
      useCommunityFeed(seed: seed);
    } else {
      useCommunityFeed();
      if (Get.isRegistered<HomeController>()) {
        seedCommunityFromHome(Get.find<HomeController>().graceMomentsForHome);
      }
    }

    if (shorts.isEmpty) {
      await loadCommunityShorts(refresh: true, silent: false);
    } else {
      unawaited(loadCommunityShorts(refresh: true, silent: true));
      ShortVideoPreloadService.instance.warmCacheForShorts(
        shorts.toList(),
        focusIndex: startIndex.clamp(0, shorts.length - 1),
      );
    }
  }

  Future<void> prepareMyFeed({
    List<Map<String, dynamic>>? seed,
    int startIndex = 0,
  }) async {
    feedMode.value = 'mine';
    bootstrapFeedCache('mine');

    if (seed != null && seed.isNotEmpty) {
      useMyFeed(seed: seed);
    } else {
      useMyFeed();
    }

    if (shorts.isEmpty) {
      await loadMyShorts(refresh: true, silent: false);
    } else {
      unawaited(loadMyShorts(refresh: true, silent: true));
      ShortVideoPreloadService.instance.warmCacheForShorts(
        shorts.toList(),
        focusIndex: startIndex.clamp(0, shorts.length - 1),
      );
    }
  }

  void startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _syncCounts());
  }

  void stopPolling() {
    _pollTimer?.cancel();
  }

  Future<void> _syncCounts() async {
    if (shorts.isEmpty) return;
    try {
      final ids = shorts.map((s) => ShortsService.shortId(s)).where((id) => id > 0).toList();
      if (ids.isEmpty) return;
      final counts = await ShortsService.getCounts(ids);
      for (var i = 0; i < shorts.length; i++) {
        final id = ShortsService.shortId(shorts[i]).toString();
        if (counts.containsKey(id)) {
          final c = counts[id] as Map<String, dynamic>;
          shorts[i] = Map<String, dynamic>.from(shorts[i])
            ..['total_likes'] = c['total_likes']
            ..['total_comments'] = c['total_comments']
            ..['total_shares'] = c['total_shares']
            ..['total_saves'] = c['total_saves'];
        }
      }
      shorts.refresh();
    } catch (_) {}
  }

  Future<void> loadShorts({bool refresh = false}) async {
    await loadCommunityShorts(refresh: refresh);
  }

  void useCommunityFeed({List<Map<String, dynamic>>? seed}) {
    feedMode.value = 'community';
    if (seed != null && seed.isNotEmpty) {
      communityShorts.value = List<Map<String, dynamic>>.from(seed);
      shorts.value = List<Map<String, dynamic>>.from(seed);
    } else {
      shorts.value = List<Map<String, dynamic>>.from(communityShorts);
    }
  }

  void useMyFeed({List<Map<String, dynamic>>? seed}) {
    feedMode.value = 'mine';
    if (seed != null && seed.isNotEmpty) {
      myShorts.value = List<Map<String, dynamic>>.from(seed);
      shorts.value = List<Map<String, dynamic>>.from(seed);
    } else {
      shorts.value = List<Map<String, dynamic>>.from(myShorts);
    }
  }

  void useSavedFeed({List<Map<String, dynamic>>? seed}) {
    feedMode.value = 'saved';
    if (seed != null && seed.isNotEmpty) {
      savedShorts.value = List<Map<String, dynamic>>.from(seed);
      shorts.value = List<Map<String, dynamic>>.from(seed);
    } else {
      shorts.value = List<Map<String, dynamic>>.from(savedShorts);
    }
  }

  Future<void> loadCommunityShorts({bool refresh = false, bool silent = false}) async {
    if (_isLoading && !refresh) return;

    if (silent &&
        _lastSyncedAt != null &&
        DateTime.now().difference(_lastSyncedAt!) < _minSyncInterval) {
      return;
    }

    if (refresh) {
      _nextCursor = null;
      hasMore.value = true;
    }
    if (!hasMore.value && !refresh) return;

    final generation = silent ? _loadGeneration : ++_loadGeneration;
    _isLoading = true;
    if (silent) {
      isSilentSyncing.value = true;
    } else if (shorts.isEmpty) {
      isLoading.value = true;
    } else {
      isSilentSyncing.value = true;
    }

    try {
      await _loadUserId();
      final items = await ShortsService.getShorts(
        currentUserId: userId.value > 0 ? userId.value : null,
        limit: 20,
        cursor: refresh ? null : _nextCursor,
      );

      if (generation != _loadGeneration) return;

      final filtered = items.where((short) {
        final ownerId = int.tryParse(short['user_id']?.toString() ?? '0') ?? 0;
        return userId.value <= 0 || ownerId != userId.value;
      }).toList();

      if (refresh) {
        communityShorts.value = filtered;
      } else {
        communityShorts.addAll(filtered);
      }
      if (feedMode.value == 'community') {
        if (refresh) {
          shorts.value = filtered;
        } else {
          shorts.addAll(filtered);
        }
      }
      if (items.isNotEmpty) {
        _nextCursor = ShortsService.shortId(items.last);
      }
      hasMore.value = items.length >= 20;
      _lastSyncedAt = DateTime.now();
      final snapshot = communityShorts.toList();
      unawaited(HiveCacheService.cacheList(_communityHiveKey, snapshot));
      unawaited(HiveCacheService.cacheList(_homeShortsHiveKey, snapshot, expiryHours: 24));
      ShortVideoPreloadService.instance.warmCacheForShorts(shorts.toList());
    } catch (e) {
      if (!silent) {
        message.value = e is ApiException ? e.message : 'Failed to load grace moments';
      }
    } finally {
      _isLoading = false;
      isLoading.value = false;
      isSilentSyncing.value = false;
    }
  }

  Future<void> loadMyShorts({bool refresh = false, bool silent = false}) async {
    if (_isLoading && !refresh) return;

    if (silent &&
        _lastSyncedAt != null &&
        DateTime.now().difference(_lastSyncedAt!) < _minSyncInterval) {
      return;
    }

    _isLoading = true;
    if (silent) {
      isSilentSyncing.value = true;
    } else if (shorts.isEmpty) {
      isLoading.value = true;
    } else {
      isSilentSyncing.value = true;
    }

    try {
      await _loadUserId();
      if (userId.value <= 0) {
        myShorts.clear();
        return;
      }
      final items = await ShortsService.getShorts(
        status: 'Approved,Pending',
        userId: userId.value,
        currentUserId: userId.value,
        limit: 50,
      );
      myShorts.value = items;
      if (feedMode.value == 'mine') {
        shorts.value = items;
      }
      unawaited(HiveCacheService.cacheList(_myHiveKey, items));
      ShortVideoPreloadService.instance.warmCacheForShorts(items);
      _lastSyncedAt = DateTime.now();
    } catch (e) {
      if (!silent) {
        message.value = e is ApiException ? e.message : 'Failed to load your grace moments';
      }
    } finally {
      _isLoading = false;
      isLoading.value = false;
      isSilentSyncing.value = false;
    }
  }

  void seedCommunityFromHome(List<Map<String, dynamic>> homeShorts) {
    if (homeShorts.isEmpty) return;
    communityShorts.value = List<Map<String, dynamic>>.from(homeShorts);
    if (feedMode.value == 'community' && shorts.isEmpty) {
      shorts.value = List<Map<String, dynamic>>.from(homeShorts);
    }
  }

  void updateShortAt(int index, Map<String, dynamic> updates) {
    if (index < 0 || index >= shorts.length) return;
    shorts[index] = Map<String, dynamic>.from(shorts[index])..addAll(updates);
    shorts.refresh();
  }

  Future<void> toggleLike(int index) async {
    if (index < 0 || index >= shorts.length || userId.value <= 0) return;
    final short = shorts[index];
    final id = ShortsService.shortId(short);
    final wasLiked = short['is_liked'] == true;
    final currentLikes = int.tryParse(short['total_likes']?.toString() ?? '0') ?? 0;

    updateShortAt(index, {
      'is_liked': !wasLiked,
      'total_likes': wasLiked ? (currentLikes - 1).clamp(0, 999999999) : currentLikes + 1,
    });

    try {
      final result = await ShortsService.toggleLike(shortId: id, userId: userId.value);
      updateShortAt(index, {
        'is_liked': result['is_liked'] ?? !wasLiked,
        'total_likes': result['total_likes'] ?? currentLikes,
      });
    } catch (e) {
      updateShortAt(index, {
        'is_liked': wasLiked,
        'total_likes': currentLikes,
      });
    }
  }

  Future<void> toggleSave(int index) async {
    if (index < 0 || index >= shorts.length || userId.value <= 0) return;
    final short = shorts[index];
    final id = ShortsService.shortId(short);
    final wasSaved = short['is_saved'] == true;
    final currentSaves = int.tryParse(short['total_saves']?.toString() ?? '0') ?? 0;

    updateShortAt(index, {
      'is_saved': !wasSaved,
      'total_saves': wasSaved ? (currentSaves - 1).clamp(0, 999999999) : currentSaves + 1,
    });

    try {
      final result = await ShortsService.toggleSave(shortId: id, userId: userId.value);
      updateShortAt(index, {
        'is_saved': result['is_saved'] ?? !wasSaved,
        'total_saves': result['total_saves'] ?? currentSaves,
      });
    } catch (e) {
      updateShortAt(index, {
        'is_saved': wasSaved,
        'total_saves': currentSaves,
      });
    }
  }

  Future<void> trackShare(int index, {String shareType = 'native'}) async {
    if (index < 0 || index >= shorts.length) return;
    final short = shorts[index];
    final id = ShortsService.shortId(short);
    final currentShares = int.tryParse(short['total_shares']?.toString() ?? '0') ?? 0;
    updateShortAt(index, {'total_shares': currentShares + 1});
    try {
      final result = await ShortsService.trackShare(
        shortId: id,
        userId: userId.value,
        shareType: shareType,
      );
      updateShortAt(index, {'total_shares': result['total_shares'] ?? currentShares + 1});
    } catch (_) {}
  }

  Future<void> recordView(int index) async {
    if (index < 0 || index >= shorts.length || userId.value <= 0) return;
    final id = ShortsService.shortId(shorts[index]);
    unawaited(ShortsService.trackView(shortId: id, userId: userId.value));
  }

  int _commentIndexById(dynamic id) {
    final target = id?.toString();
    if (target == null) return -1;
    return comments.indexWhere((c) => c['id']?.toString() == target);
  }

  List<Map<String, dynamic>> _collectPendingFromTree(List<Map<String, dynamic>> roots) {
    final pending = <Map<String, dynamic>>[];
    void walk(List<Map<String, dynamic>> nodes) {
      for (final node in nodes) {
        if (node['_pending'] == true) {
          pending.add(Map<String, dynamic>.from(node));
        }
        final replies = node['replies'];
        if (replies is List) {
          walk(
            replies
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList(),
          );
        }
      }
    }
    walk(roots);
    return pending;
  }

  List<Map<String, dynamic>> _insertCommentInTree(
    List<Map<String, dynamic>> roots,
    Map<String, dynamic> item, {
    int? parentCommentId,
  }) {
    if (parentCommentId == null || parentCommentId <= 0) {
      return [...roots, item];
    }
    return roots.map((root) {
      final copy = Map<String, dynamic>.from(root);
      final id = int.tryParse(copy['id']?.toString() ?? '0') ?? 0;
      if (id == parentCommentId) {
        final replies = List<Map<String, dynamic>>.from(copy['replies'] ?? []);
        replies.add(item);
        copy['replies'] = replies;
        return copy;
      }
      final replies = copy['replies'];
      if (replies is List && replies.isNotEmpty) {
        copy['replies'] = _insertCommentInTree(
          replies
              .whereType<Map>()
              .map((r) => Map<String, dynamic>.from(r))
              .toList(),
          item,
          parentCommentId: parentCommentId,
        );
      }
      return copy;
    }).toList();
  }

  List<Map<String, dynamic>> _removeCommentFromTree(
    List<Map<String, dynamic>> roots,
    dynamic targetId,
  ) {
    final target = targetId?.toString();
    final result = <Map<String, dynamic>>[];
    for (final node in roots) {
      final copy = Map<String, dynamic>.from(node);
      if (copy['id']?.toString() == target) continue;
      final replies = copy['replies'];
      if (replies is List && replies.isNotEmpty) {
        copy['replies'] = _removeCommentFromTree(
          replies
              .whereType<Map>()
              .map((r) => Map<String, dynamic>.from(r))
              .toList(),
          targetId,
        );
      }
      result.add(copy);
    }
    return result;
  }

  List<Map<String, dynamic>> _replaceCommentInTree(
    List<Map<String, dynamic>> roots,
    dynamic targetId,
    Map<String, dynamic> replacement,
  ) {
    final target = targetId?.toString();
    return roots.map((node) {
      final copy = Map<String, dynamic>.from(node);
      if (copy['id']?.toString() == target) {
        replacement['replies'] = copy['replies'] ?? [];
        return Map<String, dynamic>.from(replacement);
      }
      final replies = copy['replies'];
      if (replies is List && replies.isNotEmpty) {
        copy['replies'] = _replaceCommentInTree(
          replies
              .whereType<Map>()
              .map((r) => Map<String, dynamic>.from(r))
              .toList(),
          targetId,
          replacement,
        );
      }
      return copy;
    }).toList();
  }

  Map<String, dynamic>? _findPendingInTree(
    List<Map<String, dynamic>> roots,
    dynamic targetId,
  ) {
    final target = targetId?.toString();
    for (final node in roots) {
      if (node['id']?.toString() == target) return node;
      final replies = node['replies'];
      if (replies is List) {
        final found = _findPendingInTree(
          replies
              .whereType<Map>()
              .map((r) => Map<String, dynamic>.from(r))
              .toList(),
          targetId,
        );
        if (found != null) return found;
      }
    }
    return null;
  }

  void _attachStickerPreview(Map<String, dynamic> row, String text) {
    if (!StickerEmojiHelper.isStickerEmoji(text)) return;
    final stickerId = StickerEmojiHelper.extractStickerId(text);
    if (stickerId == null) return;
    final sticker = StickerService.getStickerByIdSync(stickerId);
    if (sticker == null) return;
    if (sticker.imageUrl.isNotEmpty) {
      row['sticker_image_url'] = sticker.imageUrl;
    }
    if (sticker.localPath != null && sticker.localPath!.isNotEmpty) {
      row['sticker_local_path'] = sticker.localPath;
    }
  }

  void _rememberComments(int shortId, List<Map<String, dynamic>> items) {
    _commentsCache[shortId] = List<Map<String, dynamic>>.from(items);
    _commentsSyncedAt[shortId] = DateTime.now();
    while (_commentsCache.length > _commentsCacheLimit) {
      final oldest = _commentsSyncedAt.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      final dropId = oldest.first.key;
      _commentsCache.remove(dropId);
      _commentsSyncedAt.remove(dropId);
    }
    unawaited(
      HiveCacheService.cacheList(
        _commentsHiveKey(shortId),
        List<Map<String, dynamic>>.from(items),
        expiryHours: 24,
      ),
    );
  }

  /// Memory + Hive — instant list before API (group posts pattern).
  void bootstrapComments(int shortId) {
    if (_commentsShortId == shortId && comments.isNotEmpty) return;

    _commentsShortId = shortId;
    final mem = _commentsCache[shortId];
    if (mem != null && mem.isNotEmpty) {
      comments.assignAll(mem);
      comments.refresh();
      return;
    }

    final hive = HiveCacheService.getCachedList(_commentsHiveKey(shortId));
    if (hive.isNotEmpty) {
      final snapshot = List<Map<String, dynamic>>.from(hive);
      _commentsCache[shortId] = snapshot;
      comments.assignAll(snapshot);
      comments.refresh();
      return;
    }

    comments.clear();
  }

  void prefetchComments(int shortId) {
    bootstrapComments(shortId);
    final gen = ++_commentsLoadGeneration;
    unawaited(_syncComments(shortId, gen));
  }

  /// Cache first, API in background — do not await in UI.
  void openComments(int shortId, {int commentCount = 0}) {
    _commentsShortId = shortId;
    final gen = ++_commentsLoadGeneration;
    bootstrapComments(shortId);
    unawaited(_syncComments(shortId, gen));
  }

  Future<void> _syncComments(int shortId, int generation) async {
    await ensureUserId();
    if (generation != _commentsLoadGeneration) return;
    final silent = comments.isNotEmpty;
    await loadComments(shortId, silent: silent, generation: generation);
  }

  Future<void> loadComments(
    int shortId, {
    bool silent = false,
    int? generation,
  }) async {
    final gen = generation ?? ++_commentsLoadGeneration;
    _commentsLoading = true;
    commentsSyncing.value = true;
    try {
      await ensureUserId();
      if (gen != _commentsLoadGeneration) return;

      final localUser = await _localUserMeta();
      final items = await ShortsService.getComments(shortId);
      if (gen != _commentsLoadGeneration) return;

      final pending = _collectPendingFromTree(comments.toList());

      _commentsShortId = shortId;
      var merged = items
          .map((raw) => _enrichCommentTree(Map<String, dynamic>.from(raw), localUser: localUser))
          .toList();
      for (final p in pending) {
        final parentId = int.tryParse(p['parent_comment_id']?.toString() ?? '0') ?? 0;
        merged = _insertCommentInTree(
          merged,
          p,
          parentCommentId: parentId > 0 ? parentId : null,
        );
      }
      _rememberComments(shortId, merged);
      comments.assignAll(merged);
      comments.refresh();
    } catch (e) {
      if (!silent) message.value = 'Failed to load comments';
    } finally {
      if (gen == _commentsLoadGeneration) {
        _commentsLoading = false;
        commentsSyncing.value = false;
      }
    }
  }

  Future<Map<String, dynamic>> _localUserMeta() async {
    final user = await UserStorage.getUser();
    if (user != null && (user['name']?.toString().trim().isNotEmpty == true)) {
      return user;
    }
    if (Get.isRegistered<ProfileController>()) {
      final profile = Get.find<ProfileController>().profile;
      final name = profile['name']?.toString().trim() ?? '';
      if (name.isNotEmpty) {
        return {
          ...?user,
          'id': profile['id'] ?? user?['id'],
          'name': name,
          'profile_photo': profile['profile_photo'] ?? user?['profile_photo'],
        };
      }
    }
    return user ?? {};
  }

  String _resolveCommentUserName(
    Map<String, dynamic> comment,
    Map<String, dynamic> localUser,
  ) {
    final raw = comment['user_name']?.toString().trim() ??
        comment['name']?.toString().trim() ??
        '';
    if (raw.isNotEmpty && raw != 'User') return raw;

    final commentUserId = int.tryParse(comment['user_id']?.toString() ?? '0') ?? 0;
    final myId = userId.value > 0
        ? userId.value
        : int.tryParse(localUser['id']?.toString() ?? '0') ?? 0;
    if (commentUserId > 0 && commentUserId == myId) {
      final localName = localUser['name']?.toString().trim() ??
          localUser['user_name']?.toString().trim() ??
          '';
      if (localName.isNotEmpty) return localName;
    }
    return raw.isNotEmpty ? raw : 'User';
  }

  Map<String, dynamic> _enrichComment(
    Map<String, dynamic> raw, {
    Map<String, dynamic>? pending,
    Map<String, dynamic>? localUser,
  }) {
    final enriched = ShortsService.normalizeComment(Map<String, dynamic>.from(raw));
    final meta = localUser ?? {};
    if (pending != null) {
      final pendingName = pending['user_name']?.toString().trim() ?? '';
      if (_isWeakCommentName(enriched['user_name']) &&
          pendingName.isNotEmpty &&
          pendingName != 'User') {
        enriched['user_name'] = pendingName;
      }
      final pendingPhoto = pending['profile_photo']?.toString() ?? '';
      if ((enriched['profile_photo']?.toString() ?? '').isEmpty && pendingPhoto.isNotEmpty) {
        enriched['profile_photo'] = pendingPhoto;
      }
    }
    enriched['user_name'] = _resolveCommentUserName(enriched, meta);

    final savedText = enriched['comment']?.toString().trim() ?? '';
    final pendingText = pending?['comment']?.toString().trim() ?? '';
    if (savedText.isEmpty && pendingText.isNotEmpty) {
      enriched['comment'] = pendingText;
      enriched['content'] = pendingText;
    }
    if (pending != null) {
      final previewUrl = pending['sticker_image_url']?.toString();
      final previewPath = pending['sticker_local_path']?.toString();
      if ((enriched['sticker_image_url']?.toString() ?? '').isEmpty &&
          previewUrl != null &&
          previewUrl.isNotEmpty) {
        enriched['sticker_image_url'] = previewUrl;
      }
      if ((enriched['sticker_local_path']?.toString() ?? '').isEmpty &&
          previewPath != null &&
          previewPath.isNotEmpty) {
        enriched['sticker_local_path'] = previewPath;
      }
    }
    _attachStickerPreview(enriched, enriched['comment']?.toString() ?? '');
    enriched.remove('_pending');
    return enriched;
  }

  Map<String, dynamic> _enrichCommentTree(
    Map<String, dynamic> raw, {
    Map<String, dynamic>? localUser,
  }) {
    final enriched = _enrichComment(raw, localUser: localUser);
    final replies = enriched['replies'];
    if (replies is List && replies.isNotEmpty) {
      enriched['replies'] = replies
          .whereType<Map>()
          .map(
            (reply) => _enrichCommentTree(
              Map<String, dynamic>.from(reply),
              localUser: localUser,
            ),
          )
          .toList();
    }
    return enriched;
  }

  bool _isWeakCommentName(dynamic name) {
    final value = name?.toString().trim() ?? '';
    return value.isEmpty || value == 'User';
  }

  Future<Map<String, dynamic>> _optimisticCommentRow(
    String text,
    Map<String, dynamic> localUser, {
    int? parentCommentId,
  }) async {
    final row = <String, dynamic>{
      '_pending': true,
      'id': -DateTime.now().millisecondsSinceEpoch,
      'user_id': userId.value > 0 ? userId.value : localUser['id'],
      'profile_photo': localUser['profile_photo'],
      'comment': text,
      'content': text,
      'replies': <Map<String, dynamic>>[],
      if (parentCommentId != null && parentCommentId > 0)
        'parent_comment_id': parentCommentId,
    };
    row['user_name'] = _resolveCommentUserName(row, localUser);
    _attachStickerPreview(row, text);
    return ShortsService.normalizeComment(row);
  }

  Future<bool> addComment(
    int shortId,
    String text,
    int feedIndex, {
    int? parentCommentId,
  }) async {
    if (text.trim().isEmpty) return false;

    final trimmed = text.trim();
    if (userId.value <= 0) {
      await _loadUserId();
    }
    if (userId.value <= 0) return false;

    _commentsLoadGeneration++;
    _commentsPosting++;
    final localUser = await _localUserMeta();
    final pending = await _optimisticCommentRow(
      trimmed,
      localUser,
      parentCommentId: parentCommentId,
    );
    final pendingId = pending['id'];
    _commentsShortId = shortId;
    comments.assignAll(
      _insertCommentInTree(
        comments.toList(),
        pending,
        parentCommentId: parentCommentId,
      ),
    );
    comments.refresh();

    try {
      final result = await ShortsService.addComment(
        shortId: shortId,
        userId: userId.value,
        comment: trimmed,
        parentCommentId: parentCommentId,
      );
      final savedRaw = result['comment'];
      if (savedRaw is Map) {
        final pendingRow =
            _findPendingInTree(comments.toList(), pendingId) ?? pending;
        final saved = _enrichComment(
          Map<String, dynamic>.from(savedRaw),
          pending: Map<String, dynamic>.from(pendingRow),
          localUser: localUser,
        );
        saved['replies'] = pendingRow['replies'] ?? [];
        comments.assignAll(
          _replaceCommentInTree(comments.toList(), pendingId, saved),
        );
        comments.refresh();
        _rememberComments(shortId, comments.toList());
      } else {
        final pendingRow = _findPendingInTree(comments.toList(), pendingId);
        if (pendingRow != null) {
          final row = Map<String, dynamic>.from(pendingRow);
          row.remove('_pending');
          comments.assignAll(
            _replaceCommentInTree(comments.toList(), pendingId, row),
          );
          comments.refresh();
          _rememberComments(shortId, comments.toList());
        }
      }
      if (feedIndex >= 0 && feedIndex < shorts.length) {
        updateShortAt(feedIndex, {
          'total_comments': result['total_comments'] ??
              ((int.tryParse(shorts[feedIndex]['total_comments']?.toString() ?? '0') ?? 0) + 1),
        });
      }
      return true;
    } catch (e) {
      comments.assignAll(_removeCommentFromTree(comments.toList(), pendingId));
      comments.refresh();
      message.value = e is ApiException ? e.message : 'Failed to post comment';
      return false;
    } finally {
      _commentsPosting--;
    }
  }

  Future<bool> deleteComment(int shortId, int commentId, {int feedIndex = -1}) async {
    if (userId.value <= 0) await _loadUserId();
    if (userId.value <= 0) return false;

    try {
      await ShortsService.deleteComment(
        commentId: commentId,
        userId: userId.value,
      );
      comments.assignAll(_removeCommentFromTree(comments.toList(), commentId));
      comments.refresh();
      _rememberComments(shortId, comments.toList());

      if (feedIndex >= 0 && feedIndex < shorts.length) {
        final current =
            int.tryParse(shorts[feedIndex]['total_comments']?.toString() ?? '0') ?? 0;
        updateShortAt(feedIndex, {'total_comments': current > 0 ? current - 1 : 0});
      }
      return true;
    } catch (e) {
      message.value = e is ApiException ? e.message : 'Failed to delete comment';
      return false;
    }
  }

  Future<bool> editComment(int shortId, int commentId, String text) async {
    if (text.trim().isEmpty) return false;
    if (userId.value <= 0) await _loadUserId();
    if (userId.value <= 0) return false;

    try {
      final localUser = await _localUserMeta();
      final result = await ShortsService.editComment(
        commentId: commentId,
        userId: userId.value,
        comment: text.trim(),
      );
      final savedRaw = result['comment'];
      if (savedRaw is! Map) return false;

      final index = _commentIndexById(commentId);
      final saved = _enrichComment(
        Map<String, dynamic>.from(savedRaw),
        localUser: localUser,
      );
      _attachStickerPreview(saved, saved['comment']?.toString() ?? '');

      if (index >= 0) {
        comments[index] = saved;
      } else {
        comments.assignAll([...comments, saved]);
      }
      comments.refresh();
      _rememberComments(shortId, comments.toList());
      return true;
    } catch (e) {
      message.value = e is ApiException ? e.message : 'Failed to edit comment';
      return false;
    }
  }

  Future<bool> reportComment(int commentId, {String? reason}) async {
    if (userId.value <= 0) await _loadUserId();
    if (userId.value <= 0) return false;

    try {
      await ShortsService.reportComment(
        commentId: commentId,
        userId: userId.value,
        reason: reason,
      );
      return true;
    } catch (e) {
      message.value = e is ApiException ? e.message : 'Failed to report comment';
      return false;
    }
  }

  Future<bool> uploadShort({
    required File videoFile,
    File? thumbnailFile,
    String? title,
    String? description,
    int duration = 0,
  }) async {
    if (duration > maxShortDurationSeconds) {
      message.value = 'Grace moments must be ${maxShortDurationSeconds} seconds or less.';
      return false;
    }
    isUploading.value = true;
    try {
      await _loadUserId();
      if (userId.value <= 0) throw ApiException('Please log in');
      await ShortsService.uploadShort(
        userId: userId.value,
        videoFile: videoFile,
        thumbnailFile: thumbnailFile,
        title: title,
        description: description,
        duration: duration,
      );
      message.value = 'Grace moment uploaded! Pending approval.';
      unawaited(loadMyShorts(refresh: true));
      return true;
    } catch (e) {
      message.value = e is ApiException ? e.message : 'Upload failed';
      return false;
    } finally {
      isUploading.value = false;
    }
  }

  Future<void> loadSavedShorts({bool silent = false}) async {
    if (!silent) isLoading.value = true;
    try {
      await _loadUserId();
      savedShorts.value = await ShortsService.getSavedShorts(userId: userId.value);
      if (feedMode.value == 'saved') {
        shorts.value = List<Map<String, dynamic>>.from(savedShorts);
      }
    } catch (e) {
      if (!silent) message.value = 'Failed to load saved grace moments';
    } finally {
      if (!silent) isLoading.value = false;
    }
  }

  Future<bool> deleteOwnShort(int shortId, int index) async {
    try {
      await ShortsService.deleteShort(shortId: shortId, userId: userId.value);
      if (index >= 0 && index < shorts.length) {
        shorts.removeAt(index);
      }
      return true;
    } catch (e) {
      message.value = e is ApiException ? e.message : 'Delete failed';
      return false;
    }
  }

  Future<void> reportShort(int shortId, String reason, {String? description}) async {
    await ShortsService.reportShort(
      shortId: shortId,
      userId: userId.value,
      reason: reason,
      description: description,
    );
  }
}
