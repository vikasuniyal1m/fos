import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/controllers/groups_controller.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';
import 'package:fruitsofspirit/routes/routes.dart';
import 'package:fruitsofspirit/widgets/cached_image.dart';
import 'package:fruitsofspirit/widgets/standard_app_bar.dart';
import 'package:fruitsofspirit/config/image_config.dart';
import 'package:fruitsofspirit/services/jingle_service.dart';
import '../utils/app_theme.dart';

/// Groups Screen
/// Displays list of groups
class GroupsScreen extends GetView<GroupsController> {
  const GroupsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Professional responsive design for tablets/iPads
    final isTabletDevice = ResponsiveHelper.isTablet(context);
    final double? maxContentWidthValue = isTabletDevice 
        ? (ResponsiveHelper.isLargeTablet(context) ? 1200.0 : 840.0)
        : null;
    
    return Scaffold(
      backgroundColor: AppTheme.themeColor, // Match other pages - beige background
      appBar: StandardAppBar(
        showBackButton: true,
        rightActions: [
          StandardAppBar.buildActionIcon(
            context,
            icon: Icons.add_rounded,
            onTap: () => Get.toNamed(Routes.CREATE_GROUP),
          ),
        ],
      ),
      body: Column(
        children: [
          // Category Filter
          Container(
            color: Colors.white, // White background for filter section
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveHelper.spacing(context, 16),
              vertical: ResponsiveHelper.spacing(context, 8),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(context, 'All', '', controller),
                  SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                  _buildFilterChip(context, 'Love', 'Love', controller),
                  SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                  _buildFilterChip(context, 'Joy', 'Joy', controller),
                  SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                  _buildFilterChip(context, 'Peace', 'Peace', controller),
                  SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                  _buildFilterChip(context, 'Patience', 'Patience', controller),
                  SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                  _buildFilterChip(context, 'Kindness', 'Kindness', controller),
                  SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                  _buildFilterChip(context, 'Goodness', 'Goodness', controller),
                  SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                  _buildFilterChip(context, 'Faithfulness', 'Faithfulness', controller),
                  SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                  _buildFilterChip(context, 'Gentleness', 'Gentleness', controller),
                  SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                  _buildFilterChip(context, 'Self-Control', 'Self-Control', controller),
                ],
              ),
            ),
          ),
          
          // Groups List
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value && controller.groups.isEmpty) {
                return Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.iconscolor,
                  ),
                );
              }

              if (controller.groups.isEmpty) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 24)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.group_outlined,
                          size: ResponsiveHelper.iconSize(context, mobile: 80),
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: ResponsiveHelper.spacing(context, 24)),
                        Text(
                          'No groups available',
                          style: ResponsiveHelper.textStyle(
                            context,
                            fontSize: ResponsiveHelper.fontSize(context, mobile: 20),
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                        SizedBox(height: ResponsiveHelper.spacing(context, 8)),
                        Text(
                          'Be the first to create a group and start building your community!',
                          textAlign: TextAlign.center,
                          style: ResponsiveHelper.textStyle(
                            context,
                            fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: ResponsiveHelper.spacing(context, 32)),
                        ElevatedButton.icon(
                          onPressed: () => Get.toNamed(Routes.CREATE_GROUP),
                          icon: const Icon(Icons.add_circle_outline, color: Colors.white, size: 24),
                          label: Text(
                            'Create Your First Group',
                            style: ResponsiveHelper.textStyle(
                              context,
                              fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.iconscolor,
                            padding: EdgeInsets.symmetric(
                              horizontal: ResponsiveHelper.spacing(context, 32),
                              vertical: ResponsiveHelper.spacing(context, 16),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                ResponsiveHelper.borderRadius(context, mobile: 12),
                              ),
                            ),
                            elevation: 4,
                          ),
                        ),
                        SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                        TextButton.icon(
                          onPressed: () => controller.refresh(),
                          icon: Icon(
                            Icons.refresh,
                            size: ResponsiveHelper.iconSize(context, mobile: 18),
                            color: AppTheme.iconscolor,
                          ),
                          label: Text(
                            'Refresh',
                            style: ResponsiveHelper.textStyle(
                              context,
                              fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                              color: AppTheme.iconscolor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () => controller.refresh(),
                color: AppTheme.iconscolor,
                child: Center(
                  child: ResponsiveHelper.constrainedContent(
                    context: context,
                    maxWidth: maxContentWidthValue,
                    child: ListView.builder(
                  padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 16)),
                  itemCount: controller.groups.length,
                  itemBuilder: (context, index) {
                    final group = controller.groups[index];
                    return _buildGroupCard(context, group, controller);
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

  Widget _buildFilterChip(BuildContext context, String label, String category, GroupsController controller) {
    final isSelected = controller.selectedCategory.value == category;
    return FilterChip(
      avatar: Icon(
        isSelected ? Icons.check_circle : Icons.circle_outlined,
        size: ResponsiveHelper.iconSize(context, mobile: 14, tablet: 16, desktop: 18),
        color: isSelected ? Colors.white : AppTheme.iconscolor,
      ),
      label: Text(
        label,
        style: TextStyle(
          fontSize: ResponsiveHelper.fontSize(context, mobile: 13),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.white : AppTheme.textPrimary,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          controller.filterByCategory(category);
        } else {
          controller.clearFilter();
        }
      },
      selectedColor: AppTheme.iconscolor,
      checkmarkColor: Colors.white,
      backgroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      side: BorderSide(
        color: isSelected ? AppTheme.iconscolor : Colors.grey[300]!,
        width: isSelected ? 2 : 1,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }

  Widget _buildGroupCard(BuildContext context, Map<String, dynamic> group, GroupsController controller) {
    final baseUrl = 'https://fruitofthespirit.templateforwebsites.com/';
    String? imageUrl;
    if (group['group_image'] != null && group['group_image'].toString().isNotEmpty) {
      final imagePath = group['group_image'].toString();
      if (!imagePath.startsWith('http')) {
        imageUrl = baseUrl + (imagePath.startsWith('/') ? imagePath.substring(1) : imagePath);
      } else {
        imageUrl = imagePath;
      }
    }
    final isMember = controller.isMember(group['id'] as int);
    final memberCount = int.tryParse((group['member_count'] ?? 0).toString()) ?? 0;
    final category = group['category'] as String? ?? 'General';
    final description = group['description'] as String? ?? '';
    
    return Container(
      margin: EdgeInsets.only(bottom: ResponsiveHelper.spacing(context, 16)),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group Image - Full width, proper aspect ratio
          if (imageUrl != null && imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: SizedBox( // Use SizedBox to give a fixed height
                height: MediaQuery.of(context).size.height * 0.2, // Use a percentage of screen height
                width: double.infinity,
                child: CachedImage(
                  imageUrl: imageUrl,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.contain, // Change to contain to show full image
                  errorWidget: Container(
                    width: double.infinity,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.themeColor,
                          AppTheme.iconscolor.withOpacity(0.3),
                        ],
                      ),
                    ),
                    child: Icon(
                      Icons.group_rounded,
                      size: ResponsiveHelper.iconSize(context, mobile: 50, tablet: 60, desktop: 70),
                      color: AppTheme.iconscolor,
                    ),
                  ),
                ),
              ),
            ),
          
          // Group Info - Compact
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name and Category Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group['name'] as String? ?? 'Untitled Group',
                            style: ResponsiveHelper.textStyle(
                              context,
                              fontSize: ResponsiveHelper.fontSize(context, mobile: 15, tablet: 16, desktop: 17),
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 5 : 6)),
                          // Category Badge
                          Container(
                            padding: ResponsiveHelper.padding(
                              context,
                              horizontal: ResponsiveHelper.isMobile(context) ? 8 : 10,
                              vertical: ResponsiveHelper.isMobile(context) ? 3 : 4,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.iconscolor,
                                  AppTheme.iconscolor.withOpacity(0.8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                            ),
                            child: Text(
                              category,
                              style: ResponsiveHelper.textStyle(
                                context,
                                fontSize: ResponsiveHelper.fontSize(context, mobile: 10, tablet: 11, desktop: 12),
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Member Count
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: ResponsiveHelper.iconSize(context, mobile: 14, tablet: 16, desktop: 18),
                          color: Colors.grey[600],
                        ),
                        SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                        Text(
                          '$memberCount',
                          style: ResponsiveHelper.textStyle(
                            context,
                            fontSize: ResponsiveHelper.fontSize(context, mobile: 12, tablet: 13, desktop: 14),
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                // Description
                if (description.isNotEmpty) ...[
                  SizedBox(height: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 8 : 10)),
                  Text(
                    description,
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: ResponsiveHelper.fontSize(context, mobile: 12, tablet: 13, desktop: 14),
                      color: Colors.black87,
                    ).copyWith(height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                
                SizedBox(height: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 12 : 14)),
                
                // Action Buttons
                Row(
                  children: [
                    // Join/Chat Button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          if (!isMember) {
                            final success = await controller.joinGroup(group['id'] as int);
                            if (success) {
                              // Show success message
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                Get.snackbar(
                                  'Success',
                                  controller.message.value.isNotEmpty 
                                      ? controller.message.value 
                                      : 'Joined group successfully',
                                  backgroundColor: Colors.green,
                                  colorText: Colors.white,
                                  snackPosition: SnackPosition.BOTTOM,
                                  duration: const Duration(seconds: 2),
                                  margin: const EdgeInsets.all(16),
                                );
                              });
                              controller.refresh();
                            } else {
                              // Show error message
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                Get.snackbar(
                                  'Error',
                                  controller.message.value.isNotEmpty 
                                      ? controller.message.value 
                                      : 'Failed to join group. Please try again.',
                                  backgroundColor: Colors.red,
                                  colorText: Colors.white,
                                  snackPosition: SnackPosition.BOTTOM,
                                  duration: const Duration(seconds: 3),
                                  margin: const EdgeInsets.all(16),
                                );
                              });
                            }
                          } else {
                              // Show loading indicator
                              Get.dialog(
                                const Center(
                                  child: CircularProgressIndicator(),
                                ),
                                barrierDismissible: false,
                              );

                              // Load group details
                              await controller.loadGroupDetails(group['id'] as int);
                              
                              // Dismiss loading indicator
                              Get.back(); // Dismiss the dialog

                              if (controller.selectedGroup.value != null) {
                                // Get category and play jingle before navigation
                                final category = group['category'] as String? ?? '';
                                print('🔊 Group category: $category');
                                if (category.isNotEmpty) {
                                  final jingleService = JingleService();
                                  // Pre-load the jingle specifically for this category
                                  jingleService.startJingle(category);
                                }
                                // Navigation to Group Details
                                Get.toNamed(Routes.GROUP_CHAT, arguments: group['id']);
                              } else {
                                // Show error if group details failed to load
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  Get.snackbar(
                                    'Error',
                                    controller.message.value.isNotEmpty 
                                        ? controller.message.value 
                                        : 'Failed to load group details. Please try again.',
                                    backgroundColor: Colors.red,
                                    colorText: Colors.white,
                                    snackPosition: SnackPosition.BOTTOM,
                                    duration: const Duration(seconds: 3),
                                    margin: const EdgeInsets.all(16),
                                  );
                                });
                              }
                          }
                        },
                        icon: Icon(
                          isMember ? Icons.chat_bubble_outline : Icons.person_add,
                          size: ResponsiveHelper.iconSize(context, mobile: 14, tablet: 16, desktop: 18),
                          color: Colors.white,
                        ),
                        label: Text(
                          isMember ? 'Chat' : 'Join',
                          style: ResponsiveHelper.textStyle(
                            context,
                            fontSize: ResponsiveHelper.fontSize(context, mobile: 12, tablet: 13, desktop: 14),
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isMember ? AppTheme.iconscolor : AppTheme.successColor,
                          padding: ResponsiveHelper.padding(
                            context,
                            vertical: ResponsiveHelper.isMobile(context) ? 8 : 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                    SizedBox(width: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 8 : 10)),
                    // Details Button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          // Show loading indicator
                          Get.dialog(
                            const Center(
                              child: CircularProgressIndicator(),
                            ),
                            barrierDismissible: false,
                          );

                          try {
                            // Load group details
                            await controller.loadGroupDetails(group['id'] as int);
                            // Dismiss loading indicator
                            Get.back();
                            // Navigate to details page
                            Get.toNamed(
                              Routes.GROUP_DETAILS,
                              arguments: group['id'],
                            );
                          } catch (e) {
                            // Dismiss loading indicator
                            Get.back();
                            // Show error message
                            Get.snackbar(
                              'Error',
                              'Failed to load group details: ${e.toString().replaceAll('Exception: ', '')}',
                              backgroundColor: Colors.red,
                              colorText: Colors.white,
                              snackPosition: SnackPosition.BOTTOM,
                              duration: const Duration(seconds: 3),
                              margin: const EdgeInsets.all(16),
                            );
                          }
                        },
                        icon: Icon(
                          Icons.info_outline,
                          size: ResponsiveHelper.iconSize(context, mobile: 14, tablet: 16, desktop: 18),
                          color: AppTheme.iconscolor,
                        ),
                        label: Text(
                          'Details',
                          style: ResponsiveHelper.textStyle(
                            context,
                            fontSize: ResponsiveHelper.fontSize(context, mobile: 12, tablet: 13, desktop: 14),
                            fontWeight: FontWeight.bold,
                            color: AppTheme.iconscolor,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppTheme.iconscolor, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

