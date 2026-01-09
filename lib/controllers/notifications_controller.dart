import 'package:get/get.dart';
import 'package:fruitsofspirit/services/notifications_service.dart';
import 'package:fruitsofspirit/services/user_storage.dart';
import 'package:fruitsofspirit/services/api_service.dart';

/// Notifications Controller
/// Manages user notifications
class NotificationsController extends GetxController {
  // Observable variables
  var isLoading = false.obs;
  var message = ''.obs;
  
  // Data
  var notifications = <Map<String, dynamic>>[].obs;
  var unreadCount = 0.obs;
  var userId = 0.obs;

  // Filters
  var showOnlyUnread = false.obs;
  var currentPage = 0.obs;
  final int itemsPerPage = 50;

  @override
  void onInit() {
    super.onInit();
    _loadUserId();
  }

  @override
  void onReady() {
    super.onReady();
    loadNotifications();
    loadUnreadCount();
  }

  @override
  void onClose() {
    // Cleanup if needed
    super.onClose();
  }

  /// Load user ID from storage
  Future<void> _loadUserId() async {
    final id = await UserStorage.getUserId();
    if (id != null) {
      userId.value = id;
    }
  }

  /// Load notifications
  Future<void> loadNotifications({bool refresh = false}) async {
    if (userId.value == 0) {
      await _loadUserId();
    }

    if (userId.value == 0) {
      notifications.value = [];
      return;
    }

    if (refresh) {
      currentPage.value = 0;
    }

    isLoading.value = true;
    message.value = '';

    try {
      final notificationsList = await NotificationsService.getNotifications(
        userId: userId.value,
        isRead: showOnlyUnread.value ? 0 : null,
        limit: itemsPerPage,
        offset: currentPage.value * itemsPerPage,
      );

      if (refresh || currentPage.value == 0) {
        notifications.value = notificationsList;
      } else {
        notifications.addAll(notificationsList);
      }
    } catch (e) {
      message.value = 'Error loading notifications: ${e.toString().replaceAll('Exception: ', '')}';
      print('Error loading notifications: $e');
      if (refresh || currentPage.value == 0) {
        notifications.value = [];
      }
    } finally {
      isLoading.value = false;
    }
  }

  /// Load more notifications (pagination)
  Future<void> loadMore() async {
    if (isLoading.value) return;

    currentPage.value++;
    await loadNotifications();
  }

  /// Load unread count
  Future<void> loadUnreadCount() async {
    if (userId.value == 0) {
      await _loadUserId();
    }

    if (userId.value == 0) {
      unreadCount.value = 0;
      return;
    }

    try {
      final count = await NotificationsService.getUnreadCount(userId.value);
      unreadCount.value = count;
    } catch (e) {
      print('Error loading unread count: $e');
      unreadCount.value = 0;
    }
  }

  /// Mark notification as read
  Future<bool> markAsRead(int? notificationId) async {
    if (userId.value == 0) {
      await _loadUserId();
    }

    if (userId.value == 0) {
      message.value = 'Please login first';
      return false;
    }

    try {
      await NotificationsService.markAsRead(
        userId: userId.value,
        notificationId: notificationId,
      );
      
      // Reload notifications and unread count
      await Future.wait([
        loadNotifications(refresh: true),
        loadUnreadCount(),
      ]);
      
      return true;
    } catch (e) {
      message.value = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      print('Error marking notification as read: $e');
      return false;
    }
  }

  /// Toggle unread filter
  void toggleUnreadFilter() {
    showOnlyUnread.value = !showOnlyUnread.value;
    loadNotifications(refresh: true);
  }

  /// Refresh data
  Future<void> refresh() async {
    await Future.wait([
      loadNotifications(refresh: true),
      loadUnreadCount(),
    ]);
  }
}

