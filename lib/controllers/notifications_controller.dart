import 'dart:async';

import 'package:get/get.dart';
import 'package:fruitsofspirit/routes/routes.dart';
import 'package:fruitsofspirit/services/hive_cache_service.dart';
import 'package:fruitsofspirit/services/notifications_service.dart';
import 'package:fruitsofspirit/services/notification_router.dart';
import 'package:fruitsofspirit/services/user_storage.dart';

/// Notifications — Hive cache + silent background sync.
class NotificationsController extends GetxController {
  var isLoading = false.obs;
  var isSilentSyncing = false.obs;
  var message = ''.obs;

  var notifications = <Map<String, dynamic>>[].obs;
  var unreadCount = 0.obs;
  var userId = 0.obs;

  var showOnlyUnread = false.obs;
  var currentPage = 0.obs;
  final int itemsPerPage = 50;

  int _loadGeneration = 0;
  DateTime? _lastSyncedAt;
  static const Duration _minSyncInterval = Duration(minutes: 2);
  static const Duration _realtimePollInterval = Duration(seconds: 12);
  static const Duration _realtimeMinSyncInterval = Duration(seconds: 10);
  Timer? _realtimeTimer;
  Completer<void>? _activeLoadCompleter;
  var _isLoading = false;

  String get _hiveCacheKey => 'notifications_user_${userId.value}';

  @override
  void onClose() {
    stopRealtimeSync();
    super.onClose();
  }

  @override
  void onReady() {
    super.onReady();
    unawaited(_initNotifications());
    startRealtimeSync();
  }

  @override
  void onInit() {
    super.onInit();
    _loadUserId();
  }

  Future<void> _initNotifications() async {
    if (userId.value == 0) {
      await _loadUserId();
    }
    loadFromHiveIfEmpty();
    unawaited(loadUnreadCount());
    if (notifications.isNotEmpty) {
      unawaited(loadNotifications(refresh: true, silent: true));
    }
  }

  /// Badge + background sync — call from home startup.
  static void warmUnreadCount() {
    final controller = Get.isRegistered<NotificationsController>()
        ? Get.find<NotificationsController>()
        : Get.put(NotificationsController());
    controller.loadFromHiveIfEmpty();
    unawaited(controller.loadUnreadCount());
    unawaited(controller.loadNotifications(refresh: true, silent: true));
    controller.startRealtimeSync();
  }

  void startRealtimeSync() {
    _realtimeTimer?.cancel();
    _realtimeTimer = Timer.periodic(_realtimePollInterval, (_) {
      unawaited(_pollRealtime());
    });
  }

  void stopRealtimeSync() {
    _realtimeTimer?.cancel();
    _realtimeTimer = null;
  }

  Future<void> _pollRealtime() async {
    if (userId.value == 0) {
      await _loadUserId();
    }
    if (userId.value == 0) return;

    await loadUnreadCount();

    if (_lastSyncedAt != null &&
        DateTime.now().difference(_lastSyncedAt!) < _realtimeMinSyncInterval) {
      return;
    }
    await loadNotifications(refresh: true, silent: true);
  }

  Future<void> _loadUserId() async {
    final id = await UserStorage.getUserId();
    if (id != null) {
      userId.value = id;
    }
  }

  void loadFromHiveIfEmpty() {
    if (notifications.isNotEmpty || userId.value == 0) return;
    final cached = HiveCacheService.getCachedList(_hiveCacheKey);
    if (cached.isNotEmpty) {
      notifications.value = List<Map<String, dynamic>>.from(cached);
    }
  }

  Future<void> _cacheNotifications() async {
    if (userId.value == 0 || notifications.isEmpty) return;
    await HiveCacheService.cacheList(
      _hiveCacheKey,
      notifications.map((e) => Map<String, dynamic>.from(e)).toList(),
      maxItems: 50,
    );
  }

  int _notificationId(Map<String, dynamic> notification) {
    final id = notification['id'];
    if (id is int) return id;
    if (id is String) return int.tryParse(id) ?? 0;
    return 0;
  }

  bool _isRead(Map<String, dynamic> notification) {
    final read = notification['is_read'];
    return read == 1 || read == true || read == '1';
  }

  Future<void> loadNotifications({
    bool refresh = false,
    bool silent = false,
  }) async {
    if (_isLoading) {
      if (_activeLoadCompleter != null) {
        await _activeLoadCompleter!.future;
      }
      return;
    }

    if (userId.value == 0) {
      await _loadUserId();
    }

    if (userId.value == 0) {
      notifications.value = [];
      return;
    }

    if (!refresh && notifications.isNotEmpty) {
      return;
    }

    if (silent &&
        _lastSyncedAt != null &&
        DateTime.now().difference(_lastSyncedAt!) < _minSyncInterval) {
      return;
    }

    final generation = silent ? _loadGeneration : ++_loadGeneration;
    _activeLoadCompleter = Completer<void>();

    if (refresh) {
      currentPage.value = 0;
    }

    _isLoading = true;
    if (silent) {
      isSilentSyncing.value = true;
    } else if (notifications.isEmpty) {
      isLoading.value = true;
    } else {
      isSilentSyncing.value = true;
    }
    message.value = '';

    try {
      final notificationsList = await NotificationsService.getNotifications(
        userId: userId.value,
        isRead: showOnlyUnread.value ? 0 : null,
        limit: itemsPerPage,
        offset: currentPage.value * itemsPerPage,
      );

      if (generation != _loadGeneration) {
        return;
      }

      if (refresh || currentPage.value == 0) {
        notifications.value = notificationsList;
      } else {
        notifications.addAll(notificationsList);
      }

      _lastSyncedAt = DateTime.now();
      if (!showOnlyUnread.value) {
        unawaited(_cacheNotifications());
      }
    } catch (e) {
      if (!silent) {
        message.value =
            'Error loading notifications: ${e.toString().replaceAll('Exception: ', '')}';
      }
    } finally {
      _isLoading = false;
      isLoading.value = false;
      isSilentSyncing.value = false;
      _activeLoadCompleter?.complete();
      _activeLoadCompleter = null;
    }
  }

  Future<void> loadMore() async {
    if (_isLoading) return;
    currentPage.value++;
    await loadNotifications(refresh: true);
  }

  Future<void> loadUnreadCount() async {
    if (userId.value == 0) {
      await _loadUserId();
    }

    if (userId.value == 0) {
      unreadCount.value = 0;
      return;
    }

    try {
      unreadCount.value =
          await NotificationsService.getUnreadCount(userId.value);
    } catch (e) {
      unreadCount.value = 0;
    }
  }

  void _markReadLocally(int? notificationId) {
    if (notificationId != null) {
      final index = notifications.indexWhere(
        (n) => _notificationId(n) == notificationId,
      );
      if (index >= 0 && !_isRead(notifications[index])) {
        notifications[index] = {
          ...Map<String, dynamic>.from(notifications[index]),
          'is_read': 1,
        };
        if (unreadCount.value > 0) {
          unreadCount.value--;
        }
        notifications.refresh();
        unawaited(_cacheNotifications());
      }
      return;
    }

    var changed = false;
    final updated = notifications.map((n) {
      if (!_isRead(n)) {
        changed = true;
        return {
          ...Map<String, dynamic>.from(n),
          'is_read': 1,
        };
      }
      return n;
    }).toList();
    if (changed) {
      notifications.value = updated;
      unreadCount.value = 0;
      unawaited(_cacheNotifications());
    }
  }

  Future<void> _markAsReadOnServer(int? notificationId) async {
    try {
      await NotificationsService.markAsRead(
        userId: userId.value,
        notificationId: notificationId,
      );
      unawaited(loadUnreadCount());
      unawaited(loadNotifications(refresh: true, silent: true));
    } catch (e) {
      message.value = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      unawaited(loadNotifications(refresh: true, silent: true));
      unawaited(loadUnreadCount());
    }
  }

  Future<void> markAllAsRead() async {
    await markAsRead(null);
  }

  Future<void> handleNotificationTap(Map<String, dynamic> notification) async {
    final notificationId = _notificationId(notification);
    if (notificationId > 0) {
      unawaited(markAsRead(notificationId));
    }

    final opened = await NotificationRouter.openNotification(notification);
    if (!opened) {
      message.value = 'This notification has no linked content yet.';
    }
  }

  static String formatRelativeTime(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw);
      final local = dt.toLocal();
      final diff = DateTime.now().difference(local);
      if (diff.inSeconds < 45) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${local.day}/${local.month}/${local.year}';
    } catch (_) {
      return raw;
    }
  }

  static String? actorLabel(Map<String, dynamic> notification) {
    final data = NotificationRouter.parsePayload(notification);
    final actor = data['sender_name'] ??
        data['user_name'] ??
        data['actor_name'] ??
        data['broadcaster_name'];
    if (actor == null) return null;
    final text = actor.toString().trim();
    return text.isEmpty ? null : text;
  }

  Future<bool> markAsRead(int? notificationId) async {
    if (userId.value == 0) {
      await _loadUserId();
    }

    if (userId.value == 0) {
      message.value = 'Please login first';
      return false;
    }

    _markReadLocally(notificationId);
    unawaited(_markAsReadOnServer(notificationId));
    return true;
  }

  void toggleUnreadFilter() {
    showOnlyUnread.value = !showOnlyUnread.value;
    loadNotifications(refresh: true);
  }

  Future<void> refresh() async {
    await Future.wait([
      loadNotifications(refresh: true),
      loadUnreadCount(),
    ]);
  }

  /// Instant open from app bar — cache first, sync in background.
  static Future<void> prepareAndOpen() async {
    final controller = Get.isRegistered<NotificationsController>()
        ? Get.find<NotificationsController>()
        : Get.put(NotificationsController());

    if (controller.userId.value == 0) {
      await controller._loadUserId();
    }
    controller.loadFromHiveIfEmpty();

    if (controller.notifications.isEmpty) {
      await controller.loadNotifications(refresh: false);
    } else {
      unawaited(controller.loadNotifications(refresh: true, silent: true));
    }
    unawaited(controller.loadUnreadCount());
    controller.startRealtimeSync();

    await Get.toNamed(Routes.NOTIFICATIONS);
  }
}
