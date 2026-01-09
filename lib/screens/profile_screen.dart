import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:fruitsofspirit/controllers/profile_controller.dart';
import 'package:fruitsofspirit/controllers/prayers_controller.dart';
import 'package:fruitsofspirit/controllers/blogs_controller.dart';
import 'package:fruitsofspirit/controllers/gallery_controller.dart';
import 'package:fruitsofspirit/routes/routes.dart';
import 'package:fruitsofspirit/utils/localization_helper.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';
import 'package:fruitsofspirit/services/user_storage.dart';
import 'package:fruitsofspirit/services/cache_service.dart';
import 'package:fruitsofspirit/widgets/standard_app_bar.dart';
import 'package:fruitsofspirit/utils/app_theme.dart';
import 'package:fruitsofspirit/utils/permission_manager.dart';
import 'package:easy_localization/easy_localization.dart';

/// Profile Screen
/// Displays user profile information with professional UI
class ProfileScreen extends GetView<ProfileController> {
  const ProfileScreen({Key? key}) : super(key: key);

  /// Get ImageProvider for profile photo (handles both network and assets)
  ImageProvider? _getImageProvider(String? photoUrl) {
    if (photoUrl == null || photoUrl.isEmpty) {
      return null;
    }
    
    // Check if it's a local asset path
    if (photoUrl.startsWith('assets/') || photoUrl.startsWith('assets/images/')) {
      return AssetImage(photoUrl);
    }
    
    // Check if it's already a full URL
    if (photoUrl.startsWith('http://') || photoUrl.startsWith('https://')) {
      return NetworkImage(photoUrl);
    }
    
    // Check if it's a file:// URL (invalid)
    if (photoUrl.startsWith('file://')) {
      return null;
    }
    
    // If it's a relative path, construct full URL
    return NetworkImage('https://fruitofthespirit.templateforwebsites.com/$photoUrl');
  }

  @override
  Widget build(BuildContext context) {
    // Professional responsive design for tablets/iPads
    final isTabletDevice = ResponsiveHelper.isTablet(context);
    final double? maxContentWidthValue = isTabletDevice 
        ? (ResponsiveHelper.isLargeTablet(context) ? 1200.0 : 840.0)
        : null;
    
    return Scaffold(
      backgroundColor: AppTheme.themeColor,
      appBar: StandardAppBar(
        showBackButton: false,
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.profile.isEmpty) {
          return Center(
            child: CircularProgressIndicator(
              color: Colors.black,
            ),
          );
        }

        if (controller.profile.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person_outline,
                  size: ResponsiveHelper.iconSize(context, mobile: 64),
                  color: Colors.grey,
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                Text(
                  LocalizationHelper.tr('no_profile_data'),
                  style: ResponsiveHelper.textStyle(
                    context,
                    fontSize: ResponsiveHelper.fontSize(context, mobile: 15, tablet: 16, desktop: 17),
                    color: Colors.grey,
                  ),
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                ElevatedButton(
                  onPressed: () => controller.refresh(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.iconscolor,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(LocalizationHelper.tr('retry')),
                ),
              ],
            ),
          );
        }

        final profile = controller.profile;
        final stats = profile['stats'] as Map<String, dynamic>? ?? {};
        final fruits = profile['fruits'] as List<dynamic>? ?? [];
        final baseUrl = 'https://fruitofthespirit.templateforwebsites.com/';
        final profilePhoto = profile['profile_photo'] != null
            ? ((profile['profile_photo'] as String).startsWith('http://') || (profile['profile_photo'] as String).startsWith('https://'))
                ? (profile['profile_photo'] as String)
                : baseUrl + (profile['profile_photo'] as String)
            : null;

        return RefreshIndicator(
          onRefresh: () => controller.refresh(),
                  color: AppTheme.iconscolor,
          child: Center(
            child: ResponsiveHelper.constrainedContent(
              context: context,
              maxWidth: maxContentWidthValue,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                // Header Section with Profile Picture
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppTheme.iconscolor,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(ResponsiveHelper.borderRadius(context, mobile: 30)),
                      bottomRight: Radius.circular(ResponsiveHelper.borderRadius(context, mobile: 30)),
                    ),
                  ),
                  padding: ResponsiveHelper.padding(
                    context,
                    top: ResponsiveHelper.isMobile(context) ? 16 : 20,
                    bottom: ResponsiveHelper.isMobile(context) ? 70 : 80,
                    left: ResponsiveHelper.isMobile(context) ? 14 : 16,
                    right: ResponsiveHelper.isMobile(context) ? 14 : 16,
                  ),
                  child: Column(
                    children: [
                      // Profile Picture with white border - Clickable to change photo
                      GestureDetector(
                        onTap: () => _showChangePhotoDialog(context, controller, profilePhoto),
                        child: Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: ResponsiveHelper.isMobile(context) ? 3 : 4,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: ResponsiveHelper.isMobile(context) ? 50 : ResponsiveHelper.isTablet(context) ? 55 : 60,
                                backgroundColor: AppTheme.accentColor,
                                backgroundImage: profilePhoto != null
                                    ? _getImageProvider(profilePhoto)
                                    : null,
                                child: profilePhoto == null
                                    ? Icon(
                                        Icons.person,
                                        size: ResponsiveHelper.isMobile(context) ? 50 : ResponsiveHelper.isTablet(context) ? 55 : 60,
                                        color: AppTheme.iconscolor,
                                      )
                                    : null,
                              ),
                            ),
                            // Camera icon overlay
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 6)),
                                decoration: BoxDecoration(
                                  color: AppTheme.iconscolor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  Icons.camera_alt,
                                  size: ResponsiveHelper.iconSize(context, mobile: 18, tablet: 20, desktop: 22),
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                      // Name
                      Text(
                        profile['name'] as String? ?? 'Anonymous',
                        style: ResponsiveHelper.textStyle(
                          context,
                          fontSize: ResponsiveHelper.fontSize(context, mobile: 22, tablet: 24, desktop: 26),
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 6 : 8)),
                      // Email
                      if (profile['email'] != null)
                        Text(
                          profile['email'] as String,
                          style: ResponsiveHelper.textStyle(
                            context,
                            fontSize: ResponsiveHelper.fontSize(context, mobile: 13, tablet: 14, desktop: 15),
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                
                // Content Section
                Container(
                  width: double.infinity,
                  padding: ResponsiveHelper.padding(
                    context,
                    horizontal: ResponsiveHelper.isMobile(context) ? 14 : 16,
                    top: ResponsiveHelper.isMobile(context) ? 16 : 20,
                  ),
                  child: Column(
                    children: [
                        // Stats Cards
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                context,
                                'Prayers',
                                '${stats['prayers'] ?? 0}',
                                Icons.favorite,
                                Colors.red,
                                onTap: () {
                                  final currentUserId = controller.userId.value;
                                  if (currentUserId > 0) {
                                    Get.toNamed(
                                      Routes.PRAYER_REQUESTS,
                                      arguments: {
                                        'fromProfile': true,
                                        'filterUserId': currentUserId,
                                      },
                                    );
                                    return;
                                  }

                                  Get.toNamed(Routes.PRAYER_REQUESTS);
                                },
                              ),
                            ),
                            SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                            Expanded(
                              child: _buildStatCard(
                                context,
                                'Blogs',
                                '${stats['blogs'] ?? 0}',
                                Icons.article,
                                Colors.blue,
                                onTap: () {
                                  final currentUserId = controller.userId.value;
                                  if (currentUserId > 0) {
                                    Get.toNamed(
                                      Routes.BLOGS,
                                      arguments: {
                                        'fromProfile': true,
                                        'filterUserId': currentUserId,
                                      },
                                    );
                                    return;
                                  }

                                  Get.toNamed(Routes.BLOGS);
                                },
                              ),
                            ),
                            SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                            Expanded(
                              child: _buildStatCard(
                                context,
                                'Media',
                                '${stats['media'] ?? 0}',
                                Icons.photo_library,
                                Colors.purple,
                                onTap: () {
                                  final currentUserId = controller.userId.value;
                                  if (currentUserId > 0) {
                                    Get.toNamed(
                                      Routes.GALLERY,
                                      arguments: {
                                        'fromProfile': true,
                                        'filterUserId': currentUserId,
                                      },
                                    );
                                    return;
                                  }

                                  Get.toNamed(Routes.GALLERY);
                                },
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: ResponsiveHelper.spacing(context, 24)),
                        
                        // Personal Information Card
                        _buildInfoCard(
                          context,
                          'Personal Information',
                          [
                            _buildInfoRow(
                              context,
                              Icons.person,
                              'Full Name',
                              profile['name'] as String? ?? 'Not provided',
                            ),
                            if (profile['email'] != null)
                              _buildInfoRow(
                                context,
                                Icons.email,
                                'Email',
                                profile['email'] as String,
                              ),
                            if (profile['phone'] != null)
                              _buildInfoRow(
                                context,
                                Icons.phone,
                                'Phone',
                                profile['phone'] as String,
                              ),
                            if (profile['fruit_category'] != null)
                              _buildInfoRow(
                                context,
                                Icons.apple,
                                'Primary Fruit',
                                profile['fruit_category'] as String,
                              ),
                          ],
                        ),
                        SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                        
                        // Selected Fruits Card
                        if (fruits.isNotEmpty)
                          _buildFruitsCard(context, fruits),
                        
                        SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                        
                        // Settings Card
                        _buildSettingsCard(context),
                        
                        SizedBox(height: ResponsiveHelper.spacing(context, 24)),
                      ],
                    ),
                  ),


            ]
                ),
          ),
        )
          )
        );

      }),
    );
  }

  Widget _buildStatCard(BuildContext context, String label, String value, IconData icon, Color color, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
      child: Container(
        padding: ResponsiveHelper.padding(
          context,
          all: ResponsiveHelper.isMobile(context) ? 14 : 16,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: ResponsiveHelper.padding(
                context,
                all: ResponsiveHelper.isMobile(context) ? 10 : 12,
              ),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: ResponsiveHelper.iconSize(context, mobile: 22, tablet: 24, desktop: 26),
              ),
            ),
                SizedBox(height: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 10 : 12)),
            Text(
              value,
              style: ResponsiveHelper.textStyle(
                context,
                fontSize: ResponsiveHelper.fontSize(context, mobile: 22, tablet: 24, desktop: 26),
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 4)),
            Text(
              label,
              style: ResponsiveHelper.textStyle(
                context,
                fontSize: ResponsiveHelper.fontSize(context, mobile: 11, tablet: 12, desktop: 13),
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: ResponsiveHelper.padding(
        context,
        all: ResponsiveHelper.isMobile(context) ? 16 : 20,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: ResponsiveHelper.textStyle(
              context,
              fontSize: ResponsiveHelper.fontSize(context, mobile: 17, tablet: 18, desktop: 20),
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          SizedBox(height: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 14 : 16)),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: ResponsiveHelper.spacing(context, 16)),
      child: Row(
        children: [
          Container(
            padding: ResponsiveHelper.padding(context, all: 8),
            decoration: BoxDecoration(
              color: AppTheme.iconscolor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
            ),
            child: Icon(
              icon,
              color: AppTheme.iconscolor,
              size: ResponsiveHelper.iconSize(context, mobile: 20),
            ),
          ),
          SizedBox(width: ResponsiveHelper.spacing(context, 12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: ResponsiveHelper.textStyle(
                    context,
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, 4)),
                Text(
                  value,
                  style: ResponsiveHelper.textStyle(
                    context,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFruitsCard(BuildContext context, List<dynamic> fruits) {
    return Container(
      width: double.infinity,
      padding: ResponsiveHelper.padding(
        context,
        all: ResponsiveHelper.isMobile(context) ? 16 : 20,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selected Fruits',
            style: ResponsiveHelper.textStyle(
              context,
              fontSize: ResponsiveHelper.fontSize(context, mobile: 17, tablet: 18, desktop: 20),
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          SizedBox(height: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 14 : 16)),
          Wrap(
            spacing: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 6 : 8),
            runSpacing: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 6 : 8),
            children: fruits.map((fruit) {
              final fruitName = fruit['name'] as String? ?? 'Unknown';
              return Container(
                padding: ResponsiveHelper.padding(
                  context,
                  horizontal: ResponsiveHelper.isMobile(context) ? 14 : 16,
                  vertical: ResponsiveHelper.isMobile(context) ? 6 : 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 20)),
                  border: Border.all(
                    color: AppTheme.iconscolor.withOpacity(0.2),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.apple,
                      size: ResponsiveHelper.iconSize(context, mobile: 15, tablet: 16, desktop: 17),
                      color: AppTheme.iconscolor,
                    ),
                    SizedBox(width: ResponsiveHelper.spacing(context, 6)),
                    Flexible(
                      child: Text(
                        fruitName,
                        style: ResponsiveHelper.textStyle(
                          context,
                          fontSize: ResponsiveHelper.fontSize(context, mobile: 13, tablet: 14, desktop: 15),
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: ResponsiveHelper.padding(
        context,
        all: ResponsiveHelper.isMobile(context) ? 16 : 20,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSettingTile(
            context,
            Icons.language,
            'Change Language',
            'Select app interface language',
            context.locale.languageCode.toUpperCase(),
            () => _showLanguageSelector(context),
          ),
          Divider(height: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 24 : 32)),
          _buildSettingTile(
            context,
            Icons.edit,
            'Edit Profile',
            'Update your profile information',
            null,
            () => Get.toNamed(Routes.EDIT_PROFILE),
          ),
          Divider(height: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 24 : 32)),
          _buildSettingTile(
            context,
            Icons.logout,
            'Logout',
            'Sign out from your account',
            null,
            () => _showLogoutDialog(context),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 20)),
          ),
          title: Text(
            'Logout',
            style: ResponsiveHelper.textStyle(
              context,
              fontSize: ResponsiveHelper.fontSize(context, mobile: 18, tablet: 20, desktop: 22),
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          content: Text(
            'Are you sure you want to logout?',
            style: ResponsiveHelper.textStyle(
              context,
              fontSize: ResponsiveHelper.fontSize(context, mobile: 15, tablet: 16, desktop: 17),
              color: Colors.black87,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _logout();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.iconscolor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                ),
                padding: ResponsiveHelper.padding(
                  context,
                  horizontal: ResponsiveHelper.isMobile(context) ? 20 : 24,
                  vertical: ResponsiveHelper.isMobile(context) ? 10 : 12,
                ),
              ),
              child: Text(
                'Logout',
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: ResponsiveHelper.fontSize(context, mobile: 15, tablet: 16, desktop: 17),
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

 /* Future<void> _logout() async {
    try {
      final context = Get.context!;
      // Show loading
      Get.dialog(
        Center(
          child: Container(
            padding: ResponsiveHelper.padding(
              context,
              all: ResponsiveHelper.isMobile(context) ? 16 : 20,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: AppTheme.iconscolor,
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 14 : 16)),
                Text(
                  'Logging out...',
                  style: ResponsiveHelper.textStyle(
                    context,
                    fontSize: ResponsiveHelper.fontSize(context, mobile: 13, tablet: 14, desktop: 15),
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
        barrierDismissible: false,
      );

      // Clear user data
      await UserStorage.clearUser();
      
      // Clear cache
      await CacheService.clearAllCache();
      
      // Close dialog
      Get.back();
      
      // Navigate to login page
      Get.offAllNamed(Routes.LOGIN);
      
      // Show success message
      Get.snackbar(
        'Logged Out',
        'You have been successfully logged out',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.withOpacity(0.8),
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
        icon: const Icon(Icons.check_circle, color: Colors.white),
      );
    } catch (e) {
      // Close loading dialog if open
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
      
      Get.snackbar(
        'Error',
        'Failed to logout: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
        icon: const Icon(Icons.error, color: Colors.white),
      );
    }
  }*/

  Future<void> _logout() async {
    try {
      final context = Get.context!;
      // Show loading
      Get.dialog(
        Center(
          child: Container(
            padding: ResponsiveHelper.padding(
              context,
              all: ResponsiveHelper.isMobile(context) ? 16 : 20,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: AppTheme.iconscolor,
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 14 : 16)),
                Text(
                  'Logging out...',
                  style: ResponsiveHelper.textStyle(
                    context,
                    fontSize: ResponsiveHelper.fontSize(context, mobile: 13, tablet: 14, desktop: 15),
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
        barrierDismissible: false,
      );

      // Clear user data
      await UserStorage.clearUser();

      // Clear cache
      await CacheService.clearAllCache();

      // Close dialog
      Get.back();

      // Navigate to login page
      Get.offAllNamed(Routes.LOGIN);

      // Show success message
      Get.snackbar(
        'Logged Out',
        'You have been successfully logged out',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.withOpacity(0.8),
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
        icon: const Icon(Icons.check_circle, color: Colors.white),
      );
    } catch (e) {
      // Close loading dialog if open
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      Get.snackbar(
        'Error',
        'Failed to logout: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
        icon: const Icon(Icons.error, color: Colors.white),
      );
    }
  }

  Widget _buildSettingTile(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    String? trailing,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
      child: Padding(
        padding: ResponsiveHelper.padding(
          context,
          vertical: ResponsiveHelper.isMobile(context) ? 6 : 8,
        ),
        child: Row(
          children: [
            Container(
              padding: ResponsiveHelper.padding(
                context,
                all: ResponsiveHelper.isMobile(context) ? 8 : 10,
              ),
              decoration: BoxDecoration(
                color: AppTheme.iconscolor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 10)),
              ),
              child: Icon(
                icon,
                color: AppTheme.iconscolor,
                size: ResponsiveHelper.iconSize(context, mobile: 22, tablet: 24, desktop: 26),
              ),
            ),
            SizedBox(width: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 14 : 16)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: ResponsiveHelper.fontSize(context, mobile: 15, tablet: 16, desktop: 17),
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(context, 4)),
                  Text(
                    subtitle,
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: ResponsiveHelper.fontSize(context, mobile: 11, tablet: 12, desktop: 13),
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (trailing != null)
              Container(
                padding: ResponsiveHelper.padding(
                  context,
                  horizontal: ResponsiveHelper.isMobile(context) ? 10 : 12,
                  vertical: ResponsiveHelper.isMobile(context) ? 5 : 6,
                ),
                decoration: BoxDecoration(
                    color: AppTheme.iconscolor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
                ),
                child: Text(
                  trailing,
                  style: ResponsiveHelper.textStyle(
                    context,
                  fontSize: ResponsiveHelper.fontSize(context, mobile: 11, tablet: 12, desktop: 13),
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
            SizedBox(width: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 6 : 8)),
            Icon(
              Icons.arrow_forward_ios,
              size: ResponsiveHelper.iconSize(context, mobile: 14, tablet: 16, desktop: 18),
              color: AppTheme.iconscolor,
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageSelector(BuildContext context) {
    final currentLocale = context.locale;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(ResponsiveHelper.borderRadius(context, mobile: 20)),
          ),
        ),
        padding: ResponsiveHelper.padding(
          context,
          all: ResponsiveHelper.isMobile(context) ? 16 : 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Language',
              style: ResponsiveHelper.textStyle(
                context,
                fontSize: ResponsiveHelper.fontSize(context, mobile: 18, tablet: 20, desktop: 22),
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 16 : 20)),
            _buildLanguageOption(
              context,
              'English',
              'EN',
              currentLocale.languageCode == 'en',
              () async {
                await EasyLocalization.of(context)!.setLocale(const Locale('en'));
                if (context.mounted) {
                  Navigator.pop(context);
                  Get.forceAppUpdate();
                  await Future.delayed(const Duration(milliseconds: 100));
                  Get.snackbar(
                    'Language Changed',
                    'App language changed to English',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.green.withOpacity(0.8),
                    colorText: Colors.white,
                    duration: Duration(seconds: 2),
                  );
                }
              },
            ),
                SizedBox(height: ResponsiveHelper.spacing(context, 12)),
            _buildLanguageOption(
              context,
              'Spanish (Español)',
              'ES',
              currentLocale.languageCode == 'es',
              () async {
                await EasyLocalization.of(context)!.setLocale(const Locale('es'));
                if (context.mounted) {
                  Navigator.pop(context);
                  Get.forceAppUpdate();
                  await Future.delayed(const Duration(milliseconds: 100));
                  Get.snackbar(
                    'Language Changed',
                    'App language changed to Spanish',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.green.withOpacity(0.8),
                    colorText: Colors.white,
                    duration: Duration(seconds: 2),
                  );
                }
              },
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 16 : 20)),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(
    BuildContext context,
    String title,
    String code,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
      child: Container(
        padding: ResponsiveHelper.padding(
          context,
          all: ResponsiveHelper.isMobile(context) ? 14 : 16,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.iconscolor.withOpacity(0.1)
              : Colors.grey.withOpacity(0.05),
          borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
          border: Border.all(
            color: isSelected
                ? AppTheme.iconscolor
                : Colors.transparent,
            width: ResponsiveHelper.isMobile(context) ? 1.5 : 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: ResponsiveHelper.padding(
                context,
                all: ResponsiveHelper.isMobile(context) ? 6 : 8,
              ),
              decoration: BoxDecoration(
                color: AppTheme.iconscolor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
              ),
              child: Icon(
                Icons.language,
                color: AppTheme.iconscolor,
                size: ResponsiveHelper.iconSize(context, mobile: 18, tablet: 20, desktop: 22),
              ),
            ),
            SizedBox(width: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 14 : 16)),
            Expanded(
              child: Text(
                title,
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: ResponsiveHelper.fontSize(context, mobile: 15, tablet: 16, desktop: 17),
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Colors.green,
                size: ResponsiveHelper.iconSize(context, mobile: 22, tablet: 24, desktop: 26),
              ),
          ],
        ),
      ),
    );
  }

  /// Show dialog to change profile photo
  void _showChangePhotoDialog(BuildContext context, ProfileController controller, String? currentPhoto) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(ResponsiveHelper.borderRadius(context, mobile: 20)),
          ),
        ),
        padding: ResponsiveHelper.padding(
          context,
          all: ResponsiveHelper.isMobile(context) ? 16 : 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: EdgeInsets.only(bottom: ResponsiveHelper.spacing(context, 16)),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'Change Profile Photo',
              style: ResponsiveHelper.textStyle(
                context,
                fontSize: ResponsiveHelper.fontSize(context, mobile: 18, tablet: 20, desktop: 22),
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 24)),
            ListTile(
              leading: Icon(Icons.photo_library, color: AppTheme.iconscolor),
              title: Text(
                'Choose from Gallery',
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 17, desktop: 18),
                  color: AppTheme.textPrimary,
                ),
              ),
              onTap: () async {
                Navigator.pop(context);
                await _pickAndUpdatePhoto(context, controller, ImageSource.gallery);
              },
            ),
            ListTile(
              leading: Icon(Icons.camera_alt, color: AppTheme.iconscolor),
              title: Text(
                'Take Photo',
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 17, desktop: 18),
                  color: AppTheme.textPrimary,
                ),
              ),
              onTap: () async {
                Navigator.pop(context);
                await _pickAndUpdatePhoto(context, controller, ImageSource.camera);
              },
            ),
            if (currentPhoto != null)
              ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text(
                  'Remove Photo',
                  style: ResponsiveHelper.textStyle(
                    context,
                    fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 17, desktop: 18),
                    color: Colors.red,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  // Note: Removing photo would require backend support
                  Get.snackbar(
                    'Info',
                    'Photo removal feature coming soon',
                    backgroundColor: Colors.blue,
                    colorText: Colors.white,
                    snackPosition: SnackPosition.BOTTOM,
                  );
                },
              ),
            SizedBox(height: ResponsiveHelper.spacing(context, 16)),
          ],
        ),
      ),
    );
  }

  /// Pick photo and update profile
  Future<void> _pickAndUpdatePhoto(BuildContext context, ProfileController controller, ImageSource source) async {
    try {
      // Request permissions first
      bool hasPermission = false;
      if (source == ImageSource.camera) {
        hasPermission = await PermissionManager.requestCameraPermission();
        if (!hasPermission) {
          Get.snackbar(
            'Permission Required',
            'Camera permission is required to take photos. Please enable it in settings.',
            backgroundColor: Colors.orange,
            colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 3),
          );
          return;
        }
      } else {
        hasPermission = await PermissionManager.requestStoragePermission();
        if (!hasPermission) {
          Get.snackbar(
            'Permission Required',
            'Storage permission is required to select photos. Please enable it in settings.',
            backgroundColor: Colors.orange,
            colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 3),
          );
          return;
        }
      }

      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: source,
        imageQuality: 90,
      );
      
      if (image != null) {
        File? fileToUpload;
        
        // Try to crop the image, but if it fails, use original
        // Wrap in a separate try-catch to prevent "Reply already submitted" error
        try {
          // Check if image_cropper is available before using it
          final croppedFile = await ImageCropper().cropImage(
            sourcePath: image.path,
            aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1), // Square crop for profile picture
            uiSettings: [
              AndroidUiSettings(
                toolbarTitle: 'Crop Profile Picture',
                toolbarColor: AppTheme.iconscolor,
                toolbarWidgetColor: Colors.white,
                initAspectRatio: CropAspectRatioPreset.square,
                lockAspectRatio: true,
                aspectRatioPresets: [
                  CropAspectRatioPreset.square,
                ],
              ),
              IOSUiSettings(
                title: 'Crop Profile Picture',
                aspectRatioLockEnabled: true,
                aspectRatioPresets: [
                  CropAspectRatioPreset.square,
                ],
              ),
            ],
            compressFormat: ImageCompressFormat.jpg,
            compressQuality: 85,
          ).timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              print('⚠️ Image cropping timed out');
              return null;
            },
          );
          
          if (croppedFile != null) {
            fileToUpload = File(croppedFile.path);
          } else {
            // User cancelled cropping or timed out
            return;
          }
        } on PlatformException catch (e) {
          // Handle platform-specific errors (like missing UCropActivity)
          print('⚠️ Image cropping platform error: ${e.message}');
          print('⚠️ Using original image instead');
          // If cropping fails due to platform error, use original image
          fileToUpload = File(image.path);
        } catch (e, stackTrace) {
          print('⚠️ Image cropping failed, using original image: $e');
          print('Stack trace: $stackTrace');
          // If cropping fails, use original image
          fileToUpload = File(image.path);
        }
        
        if (fileToUpload != null && await fileToUpload.exists()) {
          await _uploadProfilePhoto(context, controller, fileToUpload);
        } else {
          Get.snackbar(
            'Error',
            'Failed to process image. Please try again.',
            backgroundColor: Colors.red,
            colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 3),
          );
        }
      }
    } catch (e, stackTrace) {
      print('Error in _pickAndUpdatePhoto: $e');
      print('Stack trace: $stackTrace');
      
      // Close loading dialog if open
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
      
      Get.snackbar(
        'Error',
        'Failed to pick image: ${e.toString().replaceAll('Exception: ', '')}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
    }
  }

  /// Upload profile photo helper method
  Future<void> _uploadProfilePhoto(BuildContext screenContext, ProfileController controller, File file) async {
    // Show loading
    Get.dialog(
      Center(
        child: Builder(
          builder: (dialogContext) {
            return Container(
              padding: ResponsiveHelper.padding(
                dialogContext,
                all: ResponsiveHelper.isMobile(dialogContext) ? 20 : 24,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(dialogContext, mobile: 16)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppTheme.iconscolor),
                  SizedBox(height: ResponsiveHelper.spacing(dialogContext, 16)),
                  Text(
                    'Updating profile photo...',
                    style: ResponsiveHelper.textStyle(
                      dialogContext,
                      fontSize: ResponsiveHelper.fontSize(dialogContext, mobile: 14, tablet: 15, desktop: 16),
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            );
          }
        ),
      ),
      barrierDismissible: false,
    );

    // Update profile with new photo
    final success = await controller.updateProfile(profilePhoto: file);
    
    // Close loading dialog
    if (Get.isDialogOpen ?? false) {
      Get.back();
    }

    if (success) {
      Get.snackbar(
        'Success',
        'Profile photo updated successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
        icon: const Icon(Icons.check_circle, color: Colors.white),
      );
    } else {
      Get.snackbar(
        'Error',
        controller.message.value.isNotEmpty 
            ? controller.message.value 
            : 'Failed to update profile photo',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
        icon: const Icon(Icons.error, color: Colors.white),
      );
    }
  }
}

