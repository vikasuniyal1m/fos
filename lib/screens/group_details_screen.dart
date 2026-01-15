import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/controllers/groups_controller.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';
import 'package:fruitsofspirit/routes/routes.dart';
import 'package:fruitsofspirit/widgets/cached_image.dart';
import 'package:fruitsofspirit/widgets/standard_app_bar.dart';
import 'package:fruitsofspirit/config/image_config.dart';
import 'package:fruitsofspirit/services/jingle_service.dart';
import 'package:fruitsofspirit/utils/app_theme.dart';

/// Group Details Screen
/// Shows single group with members
class GroupDetailsScreen extends GetView<GroupsController> {
  final int? groupId;
  const GroupDetailsScreen({Key? key, this.groupId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final int? currentGroupId = groupId ?? Get.arguments as int?;
    final int effectiveGroupId = currentGroupId ?? 0;
    
    // Only load if group is not already loaded
    if (effectiveGroupId > 0 && (controller.selectedGroup.isEmpty || controller.selectedGroup['id'] != effectiveGroupId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // Only load if not already loaded
        if (controller.userGroups.isEmpty) {
          await controller.loadUserGroups();
        }
        if (controller.selectedGroup.isEmpty || controller.selectedGroup['id'] != effectiveGroupId) {
          await controller.loadGroupDetails(effectiveGroupId);
        }
      });
    }

    return Scaffold(
      backgroundColor: AppTheme.themeColor, // Match other pages - beige background
      appBar: StandardAppBar(
        showBackButton: true,
        rightActions: [], // No icons as requested
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.selectedGroup.isEmpty) {
          return Center(
            child: CircularProgressIndicator(
              color: AppTheme.iconscolor,
            ),
          );
        }

        if (controller.selectedGroup.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: ResponsiveHelper.iconSize(context, mobile: 64),
                  color: Colors.grey,
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                Text(
                  'Group not found',
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

        final group = controller.selectedGroup;
        final isMember = controller.isMember(effectiveGroupId);
        final baseUrl = 'https://fruitofthespirit.templateforwebsites.com/';
        String? imageUrl;
        if (group['group_image'] != null && group['group_image'].toString().isNotEmpty) {
          final imgPath = group['group_image'].toString();
          if (!imgPath.startsWith('http')) {
            imageUrl = baseUrl + (imgPath.startsWith('/') ? imgPath.substring(1) : imgPath);
          } else {
            imageUrl = imgPath;
          }
        }
        final category = group['category'] as String? ?? 'General';
        final memberCount = controller.groupMembers.length;

        return SingleChildScrollView(
          padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Group Image - Full width, proper aspect ratio
              if (imageUrl != null && imageUrl.isNotEmpty)
                Center( // Center the image
                  child: Container( // New Container for white background
                    width: double.infinity, // Make it full width
                    height: ResponsiveHelper.imageHeight(context, mobile: 200, tablet: 250, desktop: 300), // Add a fixed height
                    color: Colors.white, // White background
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)), // Rounded corners
                      child: CachedImage(
                        imageUrl: imageUrl,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.contain,
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
                            size: ResponsiveHelper.iconSize(context, mobile: 60, tablet: 70, desktop: 80),
                            color: AppTheme.iconscolor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              SizedBox(height: ResponsiveHelper.spacing(context, 20)),
              
              // Group Name and Category Row
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
                            fontSize: ResponsiveHelper.fontSize(context, mobile: 22, tablet: 24, desktop: 26),
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                              fontSize: ResponsiveHelper.fontSize(context, mobile: 12, tablet: 13, desktop: 14),
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
                        size: ResponsiveHelper.iconSize(context, mobile: 18, tablet: 20, desktop: 22),
                        color: AppTheme.textSecondary,
                      ),
                      SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                      Text(
                        '$memberCount',
                        style: ResponsiveHelper.textStyle(
                          context,
                          fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: ResponsiveHelper.spacing(context, 16)),
              
              // Description
              if (group['description'] != null && group['description'].toString().isNotEmpty)
                Text(
                  group['description'] as String,
                  style: ResponsiveHelper.textStyle(
                    context,
                    fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                    color: AppTheme.textPrimary,
                  ).copyWith(height: 1.6),
                ),
              SizedBox(height: ResponsiveHelper.spacing(context, 24)),
              
              // Join/Leave Button
              SizedBox(
                width: double.infinity,
                height: ResponsiveHelper.buttonHeight(context, mobile: 52),
                child: ElevatedButton(
                  onPressed: controller.isLoading.value
                      ? null
                      : () async {
                          // Show confirmation dialog for leave action
                          if (isMember) {
                            final confirm = await Get.dialog<bool>(
                              AlertDialog(
                                title: const Text('Leave Group'),
                                content: const Text('Are you sure you want to leave this group?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Get.back(result: false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Get.back(result: true),
                                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                                    child: const Text('Leave'),
                                  ),
                                ],
                              ),
                            );
                            
                            if (confirm != true) {
                              return;
                            }
                          }
                          
                          final success = isMember
                              ? await controller.leaveGroup(effectiveGroupId)
                              : await controller.joinGroup(effectiveGroupId);
                          
                          if (success) {
                            // Show success message (or info message if already member)
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              final messageText = controller.message.value.isNotEmpty 
                                  ? controller.message.value 
                                  : (isMember ? 'Left group successfully' : 'Joined group successfully');
                              
                              // Check if it's an "already member" message
                              final isInfoMessage = messageText.toLowerCase().contains('already a member');
                              
                              Get.snackbar(
                                isInfoMessage ? 'Info' : 'Success',
                                messageText,
                                backgroundColor: isInfoMessage ? Colors.blue : Colors.green,
                                colorText: Colors.white,
                                duration: const Duration(seconds: 2),
                                margin: const EdgeInsets.all(16),
                              );
                            });
                            
                            // UI will auto-update via GetX observables - no manual refresh needed
                          } else {
                            // Show error message
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              Get.snackbar(
                                'Error',
                                controller.message.value.isNotEmpty 
                                    ? controller.message.value 
                                    : 'Action failed. Please try again.',
                                backgroundColor: Colors.red,
                                colorText: Colors.white,
                                duration: const Duration(seconds: 3),
                                margin: const EdgeInsets.all(16),
                              );
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isMember ? AppTheme.errorColor : AppTheme.iconscolor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                    ),
                  ),
                  child: controller.isLoading.value
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          isMember ? 'Leave Group' : 'Join Group',
                          style: ResponsiveHelper.textStyle(
                            context,
                            fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 17, desktop: 18),
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              SizedBox(height: ResponsiveHelper.spacing(context, 12)),
              
              // Group Chat Button (only for members)
              if (isMember)
                SizedBox(
                  width: double.infinity,
                  height: ResponsiveHelper.buttonHeight(context, mobile: 52),
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      // Get category and play jingle before navigation
                      final group = controller.selectedGroup;
                      final category = group['category'] as String? ?? '';
                      
                      if (category.isNotEmpty) {
                        final jingleService = JingleService();
                        // Start jingle first (non-blocking)
                        jingleService.startJingle(category);
                      }
                      
                      // Navigate to chat
                      Get.toNamed(Routes.GROUP_CHAT, arguments: effectiveGroupId);
                    },
                    icon: Icon(
                      Icons.chat_bubble_outline,
                      color: Colors.white,
                      size: ResponsiveHelper.iconSize(context, mobile: 20, tablet: 22, desktop: 24),
                    ),
                    label: Text(
                      'Group Chat / Community',
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 17, desktop: 18),
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.iconscolor,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                      ),
                    ),
                  ),
                ),
              SizedBox(height: ResponsiveHelper.spacing(context, 24)),
              
              // Members Section
              Text(
                'Members ($memberCount)',
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: ResponsiveHelper.fontSize(context, mobile: 18, tablet: 20, desktop: 22),
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              SizedBox(height: ResponsiveHelper.spacing(context, 12)),
              
              if (controller.groupMembers.isEmpty)
                Container(
                  padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 20)),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        spreadRadius: 0,
                        blurRadius: 8,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      'No members yet',
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                )
              else
                ...controller.groupMembers.map((member) => _buildMemberCard(context, member)),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildMemberCard(BuildContext context, Map<String, dynamic> member) {
    final baseUrl = 'https://fruitofthespirit.templateforwebsites.com/';
    String? profilePhoto;
    if (member['profile_photo'] != null && member['profile_photo'].toString().isNotEmpty) {
      final photoPath = member['profile_photo'].toString();
      if (!photoPath.startsWith('http')) {
        // Check if already a full URL (http/https)
        if (photoPath.startsWith('http://') || photoPath.startsWith('https://')) {
          profilePhoto = photoPath; // Use as-is if already a full URL
        } else {
          profilePhoto = baseUrl + (photoPath.startsWith('/') ? photoPath.substring(1) : photoPath);
        }
      } else {
        profilePhoto = photoPath;
      }
    }
    
    return Container(
      margin: EdgeInsets.only(bottom: ResponsiveHelper.spacing(context, 12)),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
        border: Border.all(
          color: Colors.grey[200]!.withOpacity(0.5),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 0,
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.transparent,
            backgroundImage: profilePhoto != null ? NetworkImage(profilePhoto) : null,
            child: profilePhoto == null
                ? Icon(
                    Icons.person_rounded,
                    size: 24,
                    color: AppTheme.iconscolor,
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member['name'] as String? ?? 'Anonymous',
                  style: ResponsiveHelper.textStyle(
                    context,
                    fontSize: ResponsiveHelper.fontSize(context, mobile: 15, tablet: 16, desktop: 17),
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (member['role'] != null && member['role'].toString().isNotEmpty)
                  Text(
                    member['role'] as String,
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: ResponsiveHelper.fontSize(context, mobile: 12, tablet: 13, desktop: 14),
                      color: AppTheme.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
