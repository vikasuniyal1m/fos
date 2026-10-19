import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';
import 'package:fruitsofspirit/routes/routes.dart';
import 'package:fruitsofspirit/controllers/notifications_controller.dart';
import 'package:fruitsofspirit/controllers/profile_controller.dart';
import '../utils/app_theme.dart';

/// Standard App Bar Widget
/// Reusable app bar matching home page design with customizable right-side icons
class StandardAppBar extends StatelessWidget implements PreferredSizeWidget {
  final List<Widget>? rightActions; // Custom right-side action icons
  final VoidCallback? onLogoTap; // Optional logo tap handler
  final bool showBackButton; // Show back button instead of logos

  const StandardAppBar({
    Key? key,
    this.rightActions,
    this.onLogoTap,
    this.showBackButton = false,
  }) : super(key: key);

  @override
  Size get preferredSize => Size.fromHeight(
        ResponsiveHelper.statusBarHeight() + ResponsiveHelper.scaledToolbarHeight(),
      );

  @override
  Widget build(BuildContext context) {
    final barHeight = ResponsiveHelper.appBarHeight(context);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: ResponsiveHelper.dim(context, mobile: 4, tablet: 8),
            offset: Offset(
              0,
              ResponsiveHelper.dim(context, mobile: 2, tablet: 4),
            ),
          ),
        ],
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.withOpacity(0.15),
            width: ResponsiveHelper.dim(context, mobile: 0.5, tablet: 1),
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: barHeight,
          child: Padding(
            padding: ResponsiveHelper.padding(
              context,
              horizontal: ResponsiveHelper.spacing(context, 16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: ResponsiveHelper.isDesktop(context) ? 4 : 3,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _buildLogos(context, showBackButton: showBackButton),
                  ),
                ),
                SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                rightActions != null
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: rightActions!,
                      )
                    : _buildDefaultRightActions(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build Logos (foslogo.jpg + logoname.png) - Always show on all pages
  Widget _buildLogos(BuildContext context, {bool showBackButton = false}) {
    final isTablet = ResponsiveHelper.isTablet(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Back Button (if needed) - Show before logos
        if (showBackButton) ...[
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 30)),
              child: Container(
                width: ResponsiveHelper.appBarActionSize(context),
                height: ResponsiveHelper.appBarActionSize(context),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.8),
                    width: ResponsiveHelper.dim(context, mobile: 2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      blurRadius: ResponsiveHelper.dim(context, mobile: 6),
                      offset: Offset(0, ResponsiveHelper.dim(context, mobile: 3)),
                      spreadRadius: ResponsiveHelper.dim(context, mobile: 1),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: AppTheme.iconscolor,
                  size: ResponsiveHelper.iconSize(context, mobile: 20, tablet: 24, desktop: 28),
                ),
              ),
            ),
          ),
          SizedBox(width: ResponsiveHelper.spacing(context, 10)),
        ],
        // First Logo - foslogo.jpg
        GestureDetector(
          onTap: showBackButton
              ? () {
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                }
              : (onLogoTap ?? () {
                  // Optional: Scroll to top or refresh on logo tap
                }),
          child: Image.asset(
            'assets/foslogo.jpg',
            height: ResponsiveHelper.dim(context, mobile: 56, tablet: 72, desktop: 80),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const SizedBox.shrink();
            },
          ),
        ),
        SizedBox(width: ResponsiveHelper.spacing(context, isTablet ? 12 : 10)),
        // Second Logo - logoname.png
        Flexible(
          child: GestureDetector(
            onTap: showBackButton
                ? () {
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  }
                : (onLogoTap ?? () {
                    // Optional: Scroll to top or refresh on logo tap
                  }),
            child: Image.asset(
              'assets/logoname.png',
              height: ResponsiveHelper.dim(context, mobile: 44, tablet: 56, desktop: 64),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ],
    );
  }



  /// Build Default Right Actions (Search, Notifications, Profile - Home Page Style)
  Widget _buildDefaultRightActions(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Search Icon
        _buildActionIcon(
          context,
          icon: Icons.search_rounded,
          onTap: () => Get.toNamed(Routes.SEARCH),
        ),
        SizedBox(width: ResponsiveHelper.spacing(context, 10)),
        Obx(() {
          final count = Get.isRegistered<NotificationsController>()
              ? Get.find<NotificationsController>().unreadCount.value
              : 0;
          return _buildActionIcon(
            context,
            icon: Icons.notifications_rounded,
            onTap: () => NotificationsController.prepareAndOpen(),
            badgeCount: count,
          );
        }),
        SizedBox(width: ResponsiveHelper.spacing(context, 10)),
        // Profile Icon
        _buildActionIcon(
          context,
          icon: Icons.person_rounded,
          onTap: () => _handleProfileNavigation(context),
        ),
      ],
    );
  }

  /// Open profile instantly — Hive cache first, silent API sync in background.
  void _handleProfileNavigation(BuildContext context) {
    if (Get.isRegistered<ProfileController>()) {
      final profileController = Get.find<ProfileController>();
      profileController.bootstrapProfile();
      unawaited(profileController.prepareProfile());
    }
    Get.toNamed(Routes.PROFILE);
  }

  Widget _buildUnreadBadge(BuildContext context, int badgeCount) {
    if (badgeCount <= 0) return const SizedBox.shrink();
    final label = badgeCount > 9 ? '9+' : '$badgeCount';
    return Positioned(
      top: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: ResponsiveHelper.dim(context, mobile: 4),
          vertical: ResponsiveHelper.dim(context, mobile: 2),
        ),
        constraints: BoxConstraints(
          minWidth: ResponsiveHelper.dim(context, mobile: 16),
          minHeight: ResponsiveHelper.dim(context, mobile: 16),
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF4CAF50),
          borderRadius: BorderRadius.circular(ResponsiveHelper.dim(context, mobile: 10)),
          border: Border.all(
            color: Colors.white,
            width: ResponsiveHelper.dim(context, mobile: 2),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: ResponsiveHelper.fontSize(context, mobile: 9),
            fontWeight: FontWeight.bold,
            height: 1,
          ),
        ),
      ),
    );
  }

  /// Build Action Icon with White Background (Home Page Style)
  Widget _buildActionIcon(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onTap,
    bool showBadge = false,
    int badgeCount = 0,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 30)),
        splashColor: Colors.grey.withOpacity(0.1),
        highlightColor: Colors.grey.withOpacity(0.05),
        child: Container(
          width: ResponsiveHelper.appBarActionSize(context),
          height: ResponsiveHelper.appBarActionSize(context),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withOpacity(0.8),
              width: ResponsiveHelper.dim(context, mobile: 2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                blurRadius: ResponsiveHelper.dim(context, mobile: 6),
                offset: Offset(0, ResponsiveHelper.dim(context, mobile: 3)),
                spreadRadius: ResponsiveHelper.dim(context, mobile: 1),
              ),
            ],
          ),
          child: badgeCount > 0 || showBadge
              ? Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Center(
                      child: Icon(
                        icon,
                        color: AppTheme.iconscolor,
                        size: ResponsiveHelper.iconSize(
                          context,
                          mobile: 20,
                          tablet: 24,
                          desktop: 28,
                        ),
                      ),
                    ),
                    if (badgeCount > 0)
                      _buildUnreadBadge(context, badgeCount)
                    else if (showBadge)
                      _buildUnreadBadge(context, 1),
                  ],
                )
              : Icon(
                  icon,
                  color: AppTheme.iconscolor,
                  size: ResponsiveHelper.iconSize(
                    context,
                    mobile: 20,
                    tablet: 24,
                    desktop: 28,
                  ),
                ),
        ),
      ),
    );
  }

  /// Static method to build action icon with white background (for use in other screens)
  static Widget buildActionIcon(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onTap,
    bool showBadge = false,
    int badgeCount = 0,
    Color? iconColor,
  }) {
    final color = iconColor ?? AppTheme.iconscolor;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 30)),
        splashColor: Colors.grey.withOpacity(0.1),
        highlightColor: Colors.grey.withOpacity(0.05),
        child: Container(
          width: ResponsiveHelper.appBarActionSize(context),
          height: ResponsiveHelper.appBarActionSize(context),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withOpacity(0.8),
              width: ResponsiveHelper.dim(context, mobile: 2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                blurRadius: ResponsiveHelper.dim(context, mobile: 6),
                offset: Offset(0, ResponsiveHelper.dim(context, mobile: 3)),
                spreadRadius: ResponsiveHelper.dim(context, mobile: 1),
              ),
            ],
          ),
          child: badgeCount > 0 || showBadge
              ? Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Center(
                      child: Icon(
                        icon,
                        color: color,
                        size: ResponsiveHelper.iconSize(
                          context,
                          mobile: 20,
                          tablet: 24,
                          desktop: 28,
                        ),
                      ),
                    ),
                    if (badgeCount > 0)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: ResponsiveHelper.dim(context, mobile: 4),
                            vertical: ResponsiveHelper.dim(context, mobile: 2),
                          ),
                          constraints: BoxConstraints(
                            minWidth: ResponsiveHelper.dim(context, mobile: 16),
                            minHeight: ResponsiveHelper.dim(context, mobile: 16),
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50),
                            borderRadius: BorderRadius.circular(
                              ResponsiveHelper.dim(context, mobile: 10),
                            ),
                            border: Border.all(
                              color: Colors.white,
                              width: ResponsiveHelper.dim(context, mobile: 2),
                            ),
                          ),
                          child: Text(
                            badgeCount > 9 ? '9+' : '$badgeCount',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: ResponsiveHelper.fontSize(context, mobile: 9),
                              fontWeight: FontWeight.bold,
                              height: 1,
                            ),
                          ),
                        ),
                      )
                    else if (showBadge)
                      Positioned(
                        top: ResponsiveHelper.dim(context, mobile: 2.5),
                        right: ResponsiveHelper.dim(context, mobile: 2.5),
                        child: Container(
                          width: ResponsiveHelper.dim(context, mobile: 10),
                          height: ResponsiveHelper.dim(context, mobile: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: ResponsiveHelper.dim(context, mobile: 2),
                            ),
                          ),
                        ),
                      ),
                  ],
                )
              : Icon(
                  icon,
                  color: color,
                  size: ResponsiveHelper.iconSize(
                    context,
                    mobile: 20,
                    tablet: 24,
                    desktop: 28,
                  ),
                ),
        ),
      ),
    );
  }
}
