import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';
import 'package:fruitsofspirit/routes/routes.dart';
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
        ResponsiveHelper.safeHeight(
          Get.context!,
          mobile: 70,
          tablet: 120,
          desktop: 100,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: ResponsiveHelper.isMobile(context) ? 4 : 8,
            offset: Offset(0, ResponsiveHelper.isMobile(context) ? 2 : 4),
          ),
        ],
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.withOpacity(0.15),
            width: ResponsiveHelper.isMobile(context) ? 0.5 : 1,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: ResponsiveHelper.padding(
            context,
            horizontal: ResponsiveHelper.isMobile(context)
                ? ResponsiveHelper.spacing(context, 16)
                : ResponsiveHelper.isTablet(context)
                    ? ResponsiveHelper.spacing(context, 20)
                    : ResponsiveHelper.spacing(context, 24),
            vertical: ResponsiveHelper.isMobile(context)
                ? ResponsiveHelper.spacing(context, 10)
                : ResponsiveHelper.isTablet(context)
                    ? ResponsiveHelper.spacing(context, 12)
                    : ResponsiveHelper.spacing(context, 14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left Side - Logos in Row (foslogo.jpg + logoname.png) - Always show logos
              Expanded(
                flex: ResponsiveHelper.isDesktop(context) ? 4 : 3,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _buildLogos(context, showBackButton: showBackButton),
                ),
              ),
              SizedBox(
                width: ResponsiveHelper.isMobile(context)
                    ? 12.0
                    : ResponsiveHelper.isTablet(context)
                        ? 16.0
                        : 20.0,
              ),
              // Right Side - Action Icons (from parameter or default home page icons)
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
    );
  }

  /// Build Logos (foslogo.jpg + logoname.png) - Always show on all pages
  Widget _buildLogos(BuildContext context, {bool showBackButton = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Back Button (if needed) - Show before logos
        if (showBackButton) ...[
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Get.back(),
              borderRadius: BorderRadius.circular(30),
              child: Container(
                width: ResponsiveHelper.isMobile(context)
                    ? 40.0
                    : ResponsiveHelper.isTablet(context)
                        ? 44.0
                        : 48.0,
                height: ResponsiveHelper.isMobile(context)
                    ? 40.0
                    : ResponsiveHelper.isTablet(context)
                        ? 44.0
                        : 48.0,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.8),
                    width: 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: AppTheme.iconscolor,
                  size: ResponsiveHelper.isMobile(context)
                      ? 20.0
                      : ResponsiveHelper.isTablet(context)
                          ? 22.0
                          : 24.0,
                ),
              ),
            ),
          ),
          SizedBox(
            width: ResponsiveHelper.spacing(
              context,
              ResponsiveHelper.isMobile(context) ? 10 : 12,
            ),
          ),
        ],
        // First Logo - foslogo.jpg
        GestureDetector(
          onTap: showBackButton
              ? () => Get.back()
              : (onLogoTap ?? () {
                  // Optional: Scroll to top or refresh on logo tap
                }),
          child: Image.asset(
            'assets/foslogo.jpg',
            height: ResponsiveHelper.isMobile(context)
                ? 60.0
                : ResponsiveHelper.isTablet(context)
                    ? 70.0
                    : 80.0,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const SizedBox.shrink();
            },
          ),
        ),
        SizedBox(
          width: ResponsiveHelper.spacing(
            context,
            ResponsiveHelper.isMobile(context) ? 10 : 14,
          ),
        ),
        // Second Logo - logoname.png
        Flexible(
          child: GestureDetector(
            onTap: showBackButton
                ? () => Get.back()
                : (onLogoTap ?? () {
                    // Optional: Scroll to top or refresh on logo tap
                  }),
            child: Image.asset(
              'assets/logoname.png',
              height: ResponsiveHelper.isMobile(context)
                  ? 50.0
                  : ResponsiveHelper.isTablet(context)
                      ? 60.0
                      : 70.0,
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

  /// Build Back Button
  Widget _buildBackButton(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Get.back(),
        borderRadius: BorderRadius.circular(30),
        child: Container(
          width: ResponsiveHelper.isMobile(context)
              ? 40.0
              : ResponsiveHelper.isTablet(context)
                  ? 44.0
                  : 48.0,
          height: ResponsiveHelper.isMobile(context)
              ? 40.0
              : ResponsiveHelper.isTablet(context)
                  ? 44.0
                  : 48.0,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withOpacity(0.8),
              width: 2.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                blurRadius: 6,
                offset: const Offset(0, 3),
                spreadRadius: 1,
              ),
            ],
          ),
          child: Icon(
            Icons.arrow_back_rounded,
            color: AppTheme.iconscolor,
            size: ResponsiveHelper.isMobile(context)
                ? 20.0
                : ResponsiveHelper.isTablet(context)
                    ? 22.0
                    : 24.0,
          ),
        ),
      ),
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
        SizedBox(
          width: ResponsiveHelper.spacing(
            context,
            ResponsiveHelper.isMobile(context) ? 10 : 12,
          ),
        ),
        // Notification Icon
        _buildActionIcon(
          context,
          icon: Icons.notifications_rounded,
          onTap: () => Get.toNamed(Routes.NOTIFICATIONS),
          showBadge: true,
        ),
        SizedBox(
          width: ResponsiveHelper.spacing(
            context,
            ResponsiveHelper.isMobile(context) ? 10 : 12,
          ),
        ),
        // Profile Icon
        _buildActionIcon(
          context,
          icon: Icons.person_rounded,
          onTap: () => Get.toNamed(Routes.PROFILE),
        ),
      ],
    );
  }

  /// Build Action Icon with White Background (Home Page Style)
  Widget _buildActionIcon(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onTap,
    bool showBadge = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        splashColor: Colors.grey.withOpacity(0.1),
        highlightColor: Colors.grey.withOpacity(0.05),
        child: Container(
          width: ResponsiveHelper.isMobile(context)
              ? 40.0
              : ResponsiveHelper.isTablet(context)
                  ? 52.0
                  : 56.0,
          height: ResponsiveHelper.isMobile(context)
              ? 40.0
              : ResponsiveHelper.isTablet(context)
                  ? 52.0
                  : 56.0,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withOpacity(0.8),
              width: 2.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                blurRadius: 6,
                offset: const Offset(0, 3),
                spreadRadius: 1,
              ),
            ],
          ),
          child: showBadge
              ? Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Center(
                      child: Icon(
                        icon,
                        color: AppTheme.iconscolor,
                        size: ResponsiveHelper.isMobile(context)
                            ? 20.0
                            : ResponsiveHelper.isTablet(context)
                                ? 26.0
                                : 28.0,
                      ),
                    ),
                    // Notification Badge
                    Positioned(
                      top: ResponsiveHelper.isMobile(context) ? 2.5 : 3.0,
                      right: ResponsiveHelper.isMobile(context) ? 2.5 : 3.0,
                      child: Container(
                        width: ResponsiveHelper.isMobile(context)
                            ? 10.0
                            : ResponsiveHelper.isTablet(context)
                                ? 12.0
                                : 14.0,
                        height: ResponsiveHelper.isMobile(context)
                            ? 10.0
                            : ResponsiveHelper.isTablet(context)
                                ? 12.0
                                : 14.0,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF4CAF50),
                              Color(0xFF45A049),
                            ],
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4CAF50).withOpacity(0.5),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : Icon(
                  icon,
                  color: AppTheme.iconscolor,
                  size: ResponsiveHelper.isMobile(context)
                      ? 20.0
                      : ResponsiveHelper.isTablet(context)
                          ? 26.0
                          : 28.0,
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
    Color? iconColor,
  }) {
    final color = iconColor ?? AppTheme.iconscolor;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        splashColor: Colors.grey.withOpacity(0.1),
        highlightColor: Colors.grey.withOpacity(0.05),
        child: Container(
          width: ResponsiveHelper.isMobile(context)
              ? 40.0
              : ResponsiveHelper.isTablet(context)
                  ? 52.0
                  : 56.0,
          height: ResponsiveHelper.isMobile(context)
              ? 40.0
              : ResponsiveHelper.isTablet(context)
                  ? 52.0
                  : 56.0,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withOpacity(0.8),
              width: 2.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                blurRadius: 6,
                offset: const Offset(0, 3),
                spreadRadius: 1,
              ),
            ],
          ),
          child: showBadge
              ? Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Center(
                      child: Icon(
                        icon,
                        color: color,
                        size: ResponsiveHelper.isMobile(context)
                            ? 20.0
                            : ResponsiveHelper.isTablet(context)
                                ? 26.0
                                : 28.0,
                      ),
                    ),
                    // Notification Badge
                    Positioned(
                      top: ResponsiveHelper.isMobile(context) ? 2.5 : 3.0,
                      right: ResponsiveHelper.isMobile(context) ? 2.5 : 3.0,
                      child: Container(
                        width: ResponsiveHelper.isMobile(context)
                            ? 10.0
                            : ResponsiveHelper.isTablet(context)
                                ? 12.0
                                : 14.0,
                        height: ResponsiveHelper.isMobile(context)
                            ? 10.0
                            : ResponsiveHelper.isTablet(context)
                                ? 12.0
                                : 14.0,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF4CAF50),
                              Color(0xFF45A049),
                            ],
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4CAF50).withOpacity(0.5),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : Icon(
                  icon,
                  color: color,
                  size: ResponsiveHelper.isMobile(context)
                      ? 20.0
                      : ResponsiveHelper.isTablet(context)
                          ? 26.0
                          : 28.0,
                ),
        ),
      ),
    );
  }
}

