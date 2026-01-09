import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/controllers/notifications_controller.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';
import 'package:fruitsofspirit/routes/routes.dart';
import 'package:fruitsofspirit/widgets/standard_app_bar.dart';
import 'package:fruitsofspirit/utils/app_theme.dart';

/// Notifications Screen
class NotificationsScreen extends GetView<NotificationsController> {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Ensure controller is initialized
    final controller = Get.put(NotificationsController());
    
    // Load notifications if not already loaded
    if (controller.notifications.isEmpty && !controller.isLoading.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.loadNotifications(refresh: true);
      });
    }
    return Scaffold(
      backgroundColor: AppTheme.themeColor, // Match other pages - beige background
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(
          ResponsiveHelper.safeHeight(
            context,
            mobile: 70,
            tablet: 120,
            desktop: 100,
          ),
        ),
        child: Obx(() => StandardAppBar(
          showBackButton: false,
          rightActions: [
            StandardAppBar.buildActionIcon(
              context,
              icon: Icons.access_time,
              onTap: () => Get.toNamed(Routes.PRAYER_REMINDERS),
            ),
            SizedBox(
              width: ResponsiveHelper.spacing(
                context,
                ResponsiveHelper.isMobile(context) ? 10 : 12,
              ),
            ),
            StandardAppBar.buildActionIcon(
              context,
              icon: controller.showOnlyUnread.value
                  ? Icons.filter_list
                  : Icons.filter_list_off,
              onTap: () => controller.toggleUnreadFilter(),
            ),
          ],
        )),
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.notifications.isEmpty) {
          return Center(
            child: CircularProgressIndicator(
              color: AppTheme.iconscolor,
            ),
          );
        }

        if (controller.notifications.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.notifications_none_outlined,
                  size: ResponsiveHelper.iconSize(context, mobile: 64),
                  color: Colors.grey,
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                Text(
                  'No notifications',
                  style: ResponsiveHelper.textStyle(
                    context,
                    fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => controller.refresh(),
          color: AppTheme.iconscolor,
          child: ListView.builder(
            padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 16)),
            itemCount: controller.notifications.length,
            itemBuilder: (context, index) {
              final notification = controller.notifications[index];
              return _buildNotificationCard(context, notification, controller);
            },
          ),
        );
      }),
    );
  }

  Widget _buildNotificationCard(
      BuildContext context, Map<String, dynamic> notification, NotificationsController controller) {
    final isRead = notification['is_read'] == 1 || notification['is_read'] == true;
    
    return Card(
      margin: EdgeInsets.only(bottom: ResponsiveHelper.spacing(context, 12)),
      elevation: isRead ? 1 : 2,
      color: isRead ? Colors.white : AppTheme.accentColor.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          ResponsiveHelper.borderRadius(context, mobile: 12),
        ),
      ),
      child: InkWell(
        onTap: () {
          controller.markAsRead(notification['id'] as int?);
        },
        borderRadius: BorderRadius.circular(
          ResponsiveHelper.borderRadius(context, mobile: 12),
        ),
        child: Padding(
          padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 16)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 8)),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor,
                  borderRadius: BorderRadius.circular(
                    ResponsiveHelper.borderRadius(context, mobile: 8),
                  ),
                ),
                child: Icon(
                  _getNotificationIcon(notification['type'] as String? ?? ''),
                  color: AppTheme.iconscolor,
                  size: ResponsiveHelper.iconSize(context, mobile: 24),
                ),
              ),
              SizedBox(width: ResponsiveHelper.spacing(context, 12)),
              
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification['title'] as String? ?? 'Notification',
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
                        fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(context, 4)),
                    Text(
                      notification['message'] as String? ?? '',
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (notification['created_at'] != null)
                      Padding(
                        padding: EdgeInsets.only(top: ResponsiveHelper.spacing(context, 4)),
                        child: Text(
                          notification['created_at'] as String,
                          style: ResponsiveHelper.textStyle(
                            context,
                            fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                            color: Colors.grey,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              
              // Unread Indicator
              if (!isRead)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppTheme.iconscolor,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getNotificationIcon(String type) {
    switch (type.toLowerCase()) {
      case 'prayer':
        return Icons.favorite;
      case 'prayer_reminder':
        return Icons.access_time;
      case 'blog':
        return Icons.article;
      case 'video':
        return Icons.video_library;
      case 'comment':
        return Icons.comment;
      case 'like':
        return Icons.favorite;
      case 'follow':
        return Icons.person_add;
      default:
        return Icons.notifications;
    }
  }
}

