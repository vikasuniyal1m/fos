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
    return Scaffold(
      backgroundColor: AppTheme.themeColor,
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
          showBackButton: true,
          rightActions: [
            if (controller.unreadCount.value > 0)
              StandardAppBar.buildActionIcon(
                context,
                icon: Icons.done_all,
                onTap: () => controller.markAllAsRead(),
              ),
            if (controller.unreadCount.value > 0)
              SizedBox(width: ResponsiveHelper.spacing(context, 8)),
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
      body: Column(
        children: [
          Obx(() => controller.isSilentSyncing.value
              ? const LinearProgressIndicator(
                  minHeight: 2,
                  color: Color(0xFF8B4513),
                  backgroundColor: Colors.transparent,
                )
              : const SizedBox.shrink()),
          Expanded(
            child: Obx(() {
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
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    Map<String, dynamic> notification,
    NotificationsController controller,
  ) {
    final isRead = notification['is_read'] == 1 || notification['is_read'] == true;
    final type = (notification['type'] as String? ?? '').toLowerCase();
    final actor = NotificationsController.actorLabel(notification);
    final timeLabel = NotificationsController.formatRelativeTime(
      notification['created_at'] as String?,
    );

    return Container(
      margin: EdgeInsets.only(bottom: ResponsiveHelper.spacing(context, 10)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          ResponsiveHelper.borderRadius(context, mobile: 14),
        ),
        border: Border.all(
          color: isRead ? Colors.grey.shade200 : AppTheme.iconscolor.withOpacity(0.35),
          width: isRead ? 1 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isRead ? 0.03 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => controller.handleNotificationTap(notification),
          borderRadius: BorderRadius.circular(
            ResponsiveHelper.borderRadius(context, mobile: 14),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: isRead ? Colors.transparent : AppTheme.iconscolor,
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 14)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 10)),
                          decoration: BoxDecoration(
                            color: AppTheme.accentColor.withOpacity(0.45),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _getNotificationIcon(type),
                            color: AppTheme.iconscolor,
                            size: ResponsiveHelper.iconSize(context, mobile: 22),
                          ),
                        ),
                        SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      notification['title'] as String? ?? 'Notification',
                                      style: ResponsiveHelper.textStyle(
                                        context,
                                        fontSize: ResponsiveHelper.fontSize(context, mobile: 15),
                                        fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                  ),
                                  if (!isRead)
                                    Container(
                                      width: 8,
                                      height: 8,
                                      margin: const EdgeInsets.only(left: 6),
                                      decoration: BoxDecoration(
                                        color: AppTheme.iconscolor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                              if (actor != null) ...[
                                SizedBox(height: ResponsiveHelper.spacing(context, 2)),
                                Text(
                                  actor,
                                  style: ResponsiveHelper.textStyle(
                                    context,
                                    fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                                    color: AppTheme.iconscolor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              SizedBox(height: ResponsiveHelper.spacing(context, 4)),
                              Text(
                                notification['message'] as String? ?? '',
                                style: ResponsiveHelper.textStyle(
                                  context,
                                  fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                                  color: Colors.black87,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (timeLabel.isNotEmpty)
                                Padding(
                                  padding: EdgeInsets.only(top: ResponsiveHelper.spacing(context, 6)),
                                  child: Text(
                                    timeLabel,
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
                        Icon(
                          Icons.chevron_right,
                          color: Colors.grey.shade400,
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getNotificationIcon(String type) {
    switch (type.toLowerCase()) {
      case 'prayer':
      case 'prayer_shared':
      case 'prayer_tagged_user':
      case 'prayer_tagged_group':
        return Icons.volunteer_activism;
      case 'prayer_reminder':
        return Icons.access_time;
      case 'live_stream_started':
        return Icons.videocam;
      case 'post_commented':
      case 'comment':
        return Icons.chat_bubble_outline;
      case 'comment_reply':
        return Icons.reply;
      case 'comment_liked':
      case 'post_liked':
      case 'like':
        return Icons.favorite_border;
      case 'group_message':
        return Icons.groups;
      case 'user_followed':
      case 'follow':
        return Icons.person_add_alt_1;
      case 'blog':
        return Icons.article_outlined;
      case 'video':
        return Icons.play_circle_outline;
      case 'short':
      case 'shorts':
        return Icons.play_circle_fill;
      case 'gallery':
      case 'photo':
        return Icons.photo_outlined;
      case 'story':
      case 'testimony':
        return Icons.auto_stories_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }
}
