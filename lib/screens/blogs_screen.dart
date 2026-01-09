import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/controllers/blogs_controller.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';
import 'package:fruitsofspirit/utils/app_theme.dart';
import 'package:fruitsofspirit/routes/routes.dart';
import 'package:fruitsofspirit/widgets/standard_app_bar.dart';

/// Blogs Screen
/// Displays list of approved blogs
class BlogsScreen extends GetView<BlogsController> {
  const BlogsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Professional responsive design for tablets/iPads
    final isTabletDevice = ResponsiveHelper.isTablet(context);
    final double? maxContentWidthValue = isTabletDevice 
        // ? (ResponsiveHelper.isLargeTablet(context) ? 1200.0 : 840.0)
            ? ResponsiveHelper.maxContentWidth(context)
        : null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = Get.arguments;
      final fromProfile = args is Map && args['fromProfile'] == true;
      final dynamic rawUserId = args is Map ? args['filterUserId'] : null;
      final int? filterUserId = rawUserId is int
          ? rawUserId
          : rawUserId is String
              ? int.tryParse(rawUserId)
              : null;

      if (fromProfile && filterUserId != null && filterUserId > 0) {
        if (controller.filterUserId.value != filterUserId) {
          controller.filterUserId.value = filterUserId;
          controller.loadBlogs(refresh: true);
        }
        return;
      }

      if (controller.filterUserId.value != 0) {
        controller.filterUserId.value = 0;
        controller.loadBlogs(refresh: true);
      }
    });
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5DC),
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
          rightActions: controller.userRole.value == 'Blogger'
              ? [
                  StandardAppBar.buildActionIcon(
                    context,
                    icon: Icons.add_rounded,
                    onTap: () => Get.toNamed(Routes.CREATE_BLOG),
                  ),
                ]
              : null,
        )),
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.blogs.isEmpty) {
          return Center(
            child: CircularProgressIndicator(
              color: const Color(0xFF8B4513),
            ),
          );
        }

        if (controller.blogs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 24)),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.article_outlined,
                    size: ResponsiveHelper.iconSize(context, mobile: 64),
                    color: AppTheme.textSecondary,
                  ),
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, 24)),
                Text(
                  'No blogs available yet',
                  style: AppTheme.heading3(context).copyWith(
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, 8)),
                Text(
                  'Check back later for inspiring content',
                  style: AppTheme.bodyMedium(context).copyWith(
                    color: AppTheme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => controller.refresh(),
          color: const Color(0xFF8B4513),
          child: Center(
            child: ResponsiveHelper.constrainedContent(
              context: context,
              maxWidth: maxContentWidthValue,
              child: ListView.builder(
            padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 16)),
            itemCount: controller.blogs.length,
            itemBuilder: (context, index) {
              final blog = controller.blogs[index];
              return _buildBlogCard(context, blog, controller);
            },
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildBlogCard(BuildContext context, Map<String, dynamic> blog, BlogsController controller) {
    final baseUrl = 'https://fruitofthespirit.templateforwebsites.com/';
    final imageUrl = blog['image'] != null ? baseUrl + (blog['image'] as String) : null;
    
    return Container(
      margin: EdgeInsets.only(bottom: ResponsiveHelper.spacing(context, 16)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            spreadRadius: 2,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Get.toNamed(
            Routes.BLOG_DETAILS,
            arguments: blog['id'],
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
          splashColor: AppTheme.primaryColor.withOpacity(0.1),
          highlightColor: AppTheme.primaryColor.withOpacity(0.05),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Blog Image
            if (imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppTheme.radiusLG),
                ),
                child: Stack(
                  children: [
                    Image.network(
                      imageUrl,
                      height: ResponsiveHelper.imageHeight(context, mobile: 220),
                      width: double.infinity,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          height: ResponsiveHelper.imageHeight(context, mobile: 220),
                          color: Colors.grey.shade100,
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                  : null,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: ResponsiveHelper.imageHeight(context, mobile: 220),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppTheme.accentColor, Colors.white],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Icon(
                            Icons.image_not_supported,
                            size: ResponsiveHelper.iconSize(context, mobile: 48),
                            color: AppTheme.textSecondary,
                          ),
                        );
                      },
                    ),
                    // Gradient overlay for better text readability
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.3),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            // Blog Content
            Padding(
              padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 20)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    blog['title'] as String? ?? 'Untitled',
                    style: AppTheme.heading3(context).copyWith(
                      fontSize: ResponsiveHelper.fontSize(context, mobile: 18),
                      color: AppTheme.primaryColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(context, 12)),
                  
                  // Body Preview
                  Text(
                    blog['body'] as String? ?? '',
                    style: AppTheme.bodyMedium(context).copyWith(
                      color: AppTheme.textPrimary,
                      height: 1.6,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(context, 12)),
                  
                  // Category & Language
                  Wrap(
                    spacing: ResponsiveHelper.spacing(context, 8),
                    runSpacing: ResponsiveHelper.spacing(context, 8),
                    children: [
                      if (blog['category'] != null)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: ResponsiveHelper.spacing(context, 12),
                            vertical: ResponsiveHelper.spacing(context, 6),
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.secondaryColor,
                            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                            border: Border.all(
                              color: AppTheme.primaryColor.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            blog['category'] as String,
                            style: AppTheme.bodySmall(context).copyWith(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (blog['language'] != null)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: ResponsiveHelper.spacing(context, 12),
                            vertical: ResponsiveHelper.spacing(context, 6),
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                          ),
                          child: Text(
                            blog['language'] as String,
                            style: AppTheme.bodySmall(context).copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                  
                  // User Info & Stats
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppTheme.primaryColor.withOpacity(0.2),
                                  width: 2,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: ResponsiveHelper.borderRadius(context, mobile: 18),
                                backgroundColor: AppTheme.accentColor,
                                backgroundImage: blog['profile_photo'] != null
                                    ? NetworkImage(
                                        (blog['profile_photo'] as String).startsWith('http://') || 
                                        (blog['profile_photo'] as String).startsWith('https://')
                                          ? blog['profile_photo'] as String
                                          : 'https://fruitofthespirit.templateforwebsites.com/${blog['profile_photo']}'
                                      )
                                    : null,
                                child: blog['profile_photo'] == null
                                    ? Icon(
                                        Icons.person,
                                        size: ResponsiveHelper.iconSize(context, mobile: 20),
                                        color: AppTheme.primaryColor,
                                      )
                                    : null,
                              ),
                            ),
                            SizedBox(width: ResponsiveHelper.spacing(context, 10)),
                            Expanded(
                              child: Text(
                                blog['user_name'] as String? ?? 'Anonymous',
                                style: AppTheme.bodySmall(context).copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          _buildStatIcon(
                            context,
                            Icons.favorite_outline,
                            '${blog['like_count'] ?? 0}',
                          ),
                          SizedBox(width: ResponsiveHelper.spacing(context, 16)),
                          _buildStatIcon(
                            context,
                            Icons.comment_outlined,
                            '${blog['comment_count'] ?? 0}',
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    )
    );
  }

  Widget _buildStatIcon(BuildContext context, IconData icon, String count) {
    return Row(
      children: [
        Icon(
          icon,
          size: ResponsiveHelper.iconSize(context, mobile: 18),
          color: AppTheme.textSecondary,
        ),
        SizedBox(width: ResponsiveHelper.spacing(context, 6)),
        Text(
          count,
          style: AppTheme.bodySmall(context).copyWith(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
