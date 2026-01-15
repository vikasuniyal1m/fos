import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/controllers/prayers_controller.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';
import 'package:fruitsofspirit/utils/auto_translate_helper.dart';
import 'package:fruitsofspirit/routes/routes.dart';
import 'package:fruitsofspirit/widgets/cached_image.dart';
import 'package:fruitsofspirit/widgets/standard_app_bar.dart';
import 'package:fruitsofspirit/config/image_config.dart';
import 'package:fruitsofspirit/widgets/app_bottom_navigation_bar.dart';
import 'package:fruitsofspirit/utils/app_theme.dart';

/// Prayer Requests Screen
/// Modern, user-friendly design with attractive UI
class PrayerRequestsScreen extends GetView<PrayersController> {
  const PrayerRequestsScreen({Key? key}) : super(key: key);

  /// Get ImageProvider for profile photo (handles both network and assets)
  ImageProvider? _getImageProvider(String? photoUrl) {
    if (photoUrl == null || photoUrl.isEmpty) {
      return null;
    }
    
    if (photoUrl.startsWith('assets/') || photoUrl.startsWith('assets/images/')) {
      return AssetImage(photoUrl);
    }
    
    if (photoUrl.startsWith('http://') || photoUrl.startsWith('https://')) {
      return NetworkImage(photoUrl);
    }
    
    if (photoUrl.startsWith('file://')) {
      return null;
    }
    
    return NetworkImage('https://fruitofthespirit.templateforwebsites.com/$photoUrl');
  }

  /// Format time ago
  String _getTimeAgo(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '';
    
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays > 365) {
        final years = (difference.inDays / 365).floor();
        return '$years ${years == 1 ? 'year' : 'years'} ago';
      } else if (difference.inDays > 30) {
        final months = (difference.inDays / 30).floor();
        return '$months ${months == 1 ? 'month' : 'months'} ago';
      } else if (difference.inDays > 0) {
        return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return '';
    }
  }

  /// Get prayer type color (using AppTheme colors)
  Color _getPrayerTypeColor(String? category) {
    switch (category) {
      case 'Healing':
        return AppTheme.successColor; // Green
      case 'Peace & Anxiety':
        return const Color(0xFF2196F3); // Blue
      case 'Work & Provision':
        return AppTheme.iconscolor; // Orange
      case 'Relationships':
        return const Color(0xFFE91E63); // Pink
      case 'Guidance':
        return const Color(0xFF9C27B0); // Purple
      default:
        return AppTheme.primaryColor; // Brown
    }
  }

  @override
  Widget build(BuildContext context) {
    // Professional responsive design for tablets/iPads
    final isTabletDevice = ResponsiveHelper.isTablet(context);
    final double? maxContentWidthValue = isTabletDevice 
        ? (ResponsiveHelper.isLargeTablet(context) ? 1200.0 : 840.0)
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
          controller.loadPrayers(refresh: true);
        }
        return;
      }

      if (controller.filterUserId.value != 0) {
        controller.filterUserId.value = 0;
        controller.loadPrayers(refresh: true);
      }
    });
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: StandardAppBar(
        showBackButton: false,
        rightActions: [
          StandardAppBar.buildActionIcon(
            context,
            icon: Icons.add_rounded,
            onTap: () => Get.toNamed(Routes.CREATE_PRAYER),
          ),
        ],
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Search and Filter Section
          Container(
            color: Colors.white,
            padding: ResponsiveHelper.padding(
              context,
              all: ResponsiveHelper.isMobile(context) ? 14 : 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Category Filter Chips - Each chip has its own Obx, no need for outer Obx
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(context, 'All', '', controller, Icons.all_inclusive),
                      SizedBox(width: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 6 : 8)),
                      _buildFilterChip(context, 'Healing', 'Healing', controller, Icons.healing),
                      SizedBox(width: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 6 : 8)),
                      _buildFilterChip(context, 'Peace', 'Peace & Anxiety', controller, Icons.self_improvement),
                      SizedBox(width: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 6 : 8)),
                      _buildFilterChip(context, 'Work', 'Work & Provision', controller, Icons.work),
                      SizedBox(width: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 6 : 8)),
                      _buildFilterChip(context, 'Relationships', 'Relationships', controller, Icons.favorite),
                      SizedBox(width: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 6 : 8)),
                      _buildFilterChip(context, 'Guidance', 'Guidance', controller, Icons.lightbulb),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Prayer List
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value && controller.prayers.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        color: AppTheme.iconscolor,
                      ),
                      SizedBox(height: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 14 : 16)),
                      Text(
                        'Loading prayers...',
                        style: TextStyle(
                          fontSize: ResponsiveHelper.fontSize(context, mobile: 13, tablet: 14, desktop: 15),
                          color: AppTheme.iconscolor,
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (controller.prayers.isEmpty) {
                return _buildEmptyState(context);
              }

              return RefreshIndicator(
                onRefresh: () async {
                  // Performance: Only refresh when user explicitly pulls to refresh
                  await controller.refresh();
                },
                color: AppTheme.iconscolor,
                child: Center(
                  child: ResponsiveHelper.constrainedContent(
                    context: context,
                    maxWidth: maxContentWidthValue,
                    child: ListView.builder(
                  padding: ResponsiveHelper.padding(
                    context,
                    all: ResponsiveHelper.isMobile(context) ? 14 : 16,
                  ),
                  itemCount: controller.prayers.length,
                  itemBuilder: (context, index) {
                    final prayer = controller.prayers[index];
                    return _buildPrayerCard(context, prayer, controller);
                  },
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: ResponsiveHelper.padding(
              context,
              all: ResponsiveHelper.isMobile(context) ? 20 : 24,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(
              Icons.favorite_outline,
              size: ResponsiveHelper.iconSize(context, mobile: 56, tablet: 64, desktop: 72),
              color: Colors.grey[400],
            ),
          ),
          SizedBox(height: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 20 : 24)),
          Text(
            'No Prayer Requests Yet',
            style: ResponsiveHelper.textStyle(
              context,
              fontSize: ResponsiveHelper.fontSize(context, mobile: 18, tablet: 20, desktop: 22),
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          SizedBox(height: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 6 : 8)),
          Text(
            'Be the first to share your prayer request',
            style: ResponsiveHelper.textStyle(
              context,
              fontSize: ResponsiveHelper.fontSize(context, mobile: 13, tablet: 14, desktop: 15),
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 24 : 32)),
          ElevatedButton(
            onPressed: () => Get.toNamed(Routes.CREATE_PRAYER),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.iconscolor,
              padding: ResponsiveHelper.padding(
                context,
                horizontal: ResponsiveHelper.isMobile(context) ? 24 : 32,
                vertical: ResponsiveHelper.isMobile(context) ? 14 : 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
              ),
              elevation: 2,
            ),
            child: Text(
              'Create Prayer Request',
              style: ResponsiveHelper.textStyle(
                context,
                fontSize: ResponsiveHelper.fontSize(context, mobile: 15, tablet: 16, desktop: 17),
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(BuildContext context, String label, String category, PrayersController controller, IconData icon) {
    // Performance: Use Obx to make it reactive to filter changes
    return Obx(() {
      final isSelected = controller.selectedCategory.value == category;
      return FilterChip(
        avatar: Icon(
          icon,
          size: ResponsiveHelper.iconSize(context, mobile: 14, tablet: 16, desktop: 18),
          color: isSelected ? Colors.white : AppTheme.iconscolor,
        ),
        label: Text(
          label,
          style: ResponsiveHelper.textStyle(
            context,
            fontSize: ResponsiveHelper.fontSize(context, mobile: 12, tablet: 13, desktop: 14),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppTheme.textPrimary,
          ),
        ),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) {
            // Performance: Only filter if category is actually changing
            if (controller.selectedCategory.value != category) {
              controller.filterByCategory(category);
            }
          } else {
            // Performance: Only clear if filter is actually set
            if (controller.selectedCategory.value.isNotEmpty) {
              controller.clearFilter();
            }
          }
        },
        selectedColor: AppTheme.iconscolor,
        checkmarkColor: Colors.white,
        backgroundColor: Colors.grey[100],
        padding: ResponsiveHelper.padding(
          context,
          horizontal: ResponsiveHelper.isMobile(context) ? 10 : 12,
          vertical: ResponsiveHelper.isMobile(context) ? 6 : 8,
        ),
        side: BorderSide(
          color: isSelected ? AppTheme.iconscolor : Colors.grey[300]!,
          width: isSelected ? 2 : 1,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 20)),
        ),
      );
    });
  }

  Widget _buildPrayerCard(BuildContext context, Map<String, dynamic> prayer, PrayersController controller) {
    final isAnonymous = prayer['is_anonymous'] == 1 || prayer['is_anonymous'] == true;
    final userName = isAnonymous ? 'Anonymous' : (prayer['user_name'] ?? prayer['name'] ?? 'Anonymous');
    String? profilePhotoUrl;
    if (!isAnonymous && prayer['profile_photo'] != null && prayer['profile_photo'].toString().isNotEmpty) {
      final photoPath = prayer['profile_photo'].toString();
      // Check if already a full URL (http/https)
      if (photoPath.startsWith('http://') || photoPath.startsWith('https://')) {
        profilePhotoUrl = photoPath; // Use as-is if already a full URL
      } else if (!photoPath.startsWith('assets/') && !photoPath.startsWith('file://') && !photoPath.startsWith('assets/images/')) {
        profilePhotoUrl = 'https://fruitofthespirit.templateforwebsites.com/$photoPath';
      }
    }
    final prayerContent = AutoTranslateHelper.getTranslatedTextSync(
      text: prayer['content'] ?? '',
      sourceLanguage: prayer['language'] as String?,
    );
    final responseCount = int.tryParse((prayer['response_count'] ?? 0).toString()) ?? 0;
    final commentCount = int.tryParse((prayer['comment_count'] ?? 0).toString()) ?? 0;
    // Get prayer type - check multiple fields
    final category = prayer['category'] as String? ?? prayer['type'] as String? ?? prayer['prayer_type'] as String? ?? 'Prayer Request';
    
    return InkWell(
      onTap: () => Get.toNamed(Routes.PRAYER_DETAILS, arguments: prayer['id']),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: ResponsiveHelper.safeMargin(
          context,
          horizontal: 0,
          vertical: ResponsiveHelper.isMobile(context) ? 6 : 8,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              spreadRadius: 0,
              blurRadius: 8,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header - Profile + Name + Subtitle (Exact match home page)
            Padding(
              padding: ResponsiveHelper.padding(
                context,
                all: ResponsiveHelper.isMobile(context) ? 14 : 16,
              ),
              child: Row(
                children: [
                  // Profile Picture - Responsive size with CachedImage (same as home page)
                  profilePhotoUrl != null && !isAnonymous
                      ? ClipOval(
                          child: CachedImage(
                            imageUrl: profilePhotoUrl,
                            width: ResponsiveHelper.isMobile(context) ? 44 : ResponsiveHelper.isTablet(context) ? 48 : 52,
                            height: ResponsiveHelper.isMobile(context) ? 44 : ResponsiveHelper.isTablet(context) ? 48 : 52,
                            fit: BoxFit.cover,
                            errorWidget: CircleAvatar(
                              radius: ResponsiveHelper.isMobile(context) ? 22 : ResponsiveHelper.isTablet(context) ? 24 : 26,
                              backgroundColor: Colors.grey[300]!,
                              child: Icon(
                                Icons.person_rounded,
                                size: ResponsiveHelper.isMobile(context) ? 22 : ResponsiveHelper.isTablet(context) ? 24 : 26,
                                color: AppTheme.iconscolor,
                              ),
                            ),
                          ),
                        )
                      : CircleAvatar(
                          radius: ResponsiveHelper.isMobile(context) ? 22 : ResponsiveHelper.isTablet(context) ? 24 : 26,
                          backgroundColor: Colors.grey[300]!,
                          child: Icon(
                            Icons.person_rounded,
                            size: ResponsiveHelper.isMobile(context) ? 22 : ResponsiveHelper.isTablet(context) ? 24 : 26,
                            color: isAnonymous ? Colors.grey[600] : Colors.white,
                          ),
                        ),
                  SizedBox(width: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 10 : 12)),
                  // Name and Subtitle - Responsive (same as home page)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          userName,
                          style: ResponsiveHelper.textStyle(
                            context,
                            fontSize: ResponsiveHelper.fontSize(context, mobile: 15, tablet: 16, desktop: 17),
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        SizedBox(height: ResponsiveHelper.spacing(context, 2)),
                        Text(
                          category,
                          style: ResponsiveHelper.textStyle(
                            context,
                            fontSize: ResponsiveHelper.fontSize(context, mobile: 13, tablet: 14, desktop: 15),
                            color: AppTheme.iconscolor,
                            fontWeight: FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Content - Full content displayed (same as home page)
            Padding(
              padding: ResponsiveHelper.padding(
                context,
                horizontal: ResponsiveHelper.isMobile(context) ? 14 : 16,
                vertical: 0,
              ),
              child: Text(
                prayerContent,
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                  color: Colors.black87,
                  height: 1.5,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 12 : 14)),
            // Bottom Actions - Left: Prayed count, Right: Comments count (Exact match home page)
            Padding(
              padding: ResponsiveHelper.padding(
                context,
                horizontal: ResponsiveHelper.isMobile(context) ? 14 : 16,
                vertical: ResponsiveHelper.isMobile(context) ? 10 : 12,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left: Prayed count with icon - Only show if > 0 (Exact match)
                  if (responseCount > 0)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.favorite,
                          size: ResponsiveHelper.iconSize(context, mobile: 18, tablet: 20, desktop: 22),
                          color: AppTheme.iconscolor,
                        ),
                        SizedBox(width: ResponsiveHelper.spacing(context, 6)),
                        Text(
                          '$responseCount prayed',
                          style: ResponsiveHelper.textStyle(
                            context,
                            fontSize: ResponsiveHelper.fontSize(context, mobile: 13, tablet: 14, desktop: 15),
                            color: AppTheme.iconscolor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  // Right: Comments count with icon - Only show if > 0 (Exact match)
                  if (commentCount > 0)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.comment_outlined,
                          size: ResponsiveHelper.iconSize(context, mobile: 18, tablet: 20, desktop: 22),
                          color: AppTheme.iconscolor,
                        ),
                        SizedBox(width: ResponsiveHelper.spacing(context, 6)),
                        Text(
                          '$commentCount Comments',
                          style: ResponsiveHelper.textStyle(
                            context,
                            fontSize: ResponsiveHelper.fontSize(context, mobile: 13, tablet: 14, desktop: 15),
                            color: AppTheme.iconscolor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
