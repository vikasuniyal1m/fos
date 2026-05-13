import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/controllers/blogs_controller.dart';
import 'package:fruitsofspirit/utils/time_helper.dart';
import 'package:fruitsofspirit/routes/routes.dart';
import 'package:fruitsofspirit/widgets/cached_image.dart';
import 'package:fruitsofspirit/widgets/app_bottom_navigation_bar.dart';
import 'package:fruitsofspirit/widgets/standard_app_bar.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';
import 'package:fruitsofspirit/utils/auto_translate_helper.dart';
import 'package:fruitsofspirit/utils/app_theme.dart';
import 'package:fruitsofspirit/services/user_storage.dart';
import 'package:fruitsofspirit/config/image_config.dart';
import 'package:fruitsofspirit/services/payment_gate.dart';
import 'package:fruitsofspirit/utils/role_access_helper.dart';

/// Blogger Zone Screen - Social Media Style
/// Professional, attractive UI with like, comment, and question functionality
class BloggerZoneScreen extends StatefulWidget {
  const BloggerZoneScreen({Key? key}) : super(key: key);

  @override
  State<BloggerZoneScreen> createState() => _BloggerZoneScreenState();
}

class _BloggerZoneScreenState extends State<BloggerZoneScreen> {
  late final BlogsController controller;
  Map<String, dynamic>? _userData;
  bool _isLoadingUserData = true;

  @override
  void initState() {
    super.initState();
    controller = Get.find<BlogsController>();
    
    // Load user data and check access
    _loadUserDataAndCheckAccess();
    
    // Refresh user data from server to get latest role/status
    controller.refreshUserData();
    
    // Start periodic sync to check for role updates
    _startRoleSyncTimer();
  }

  Timer? _roleSyncTimer;

  void _startRoleSyncTimer() {
    // Check for role updates every 10 seconds for pending bloggers
    _roleSyncTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_userData != null && RoleAccessHelper.isPendingBlogger(_userData)) {
        _checkForRoleUpdate();
      }
    });
  }

  Future<void> _checkForRoleUpdate() async {
    try {
      final freshUserData = await RoleAccessHelper.getCurrentUserData();
      
      // Check if role has changed from pending to approved
      if (_userData != null && freshUserData != null) {
        final oldRole = _userData!['role'] ?? '';
        final oldStatus = _userData!['status'] ?? '';
        final newRole = freshUserData['role'] ?? '';
        final newStatus = freshUserData['status'] ?? '';
        
        // If user was pending and now is approved
        if (oldRole == 'Blogger' && oldStatus == 'Pending' && 
            newRole == 'Blogger' && newStatus == 'Active') {
          
          print('🎉 [RoleSync] User approved! Updating UI...');
          
          // Update local user data
          setState(() {
            _userData = freshUserData;
          });
          
          // Refresh controller data
          controller.refreshUserData();
          
          // Reload blogs with new permissions
          _loadBlogsBasedOnRole();
          
          // Show success message
          _showCustomSnackbar(
            'Congratulations!',
            'Your blogger request has been approved! You now have full blogger access.',
          );
          
          // Stop the timer since user is now approved
          _roleSyncTimer?.cancel();
          
          // Refresh the entire screen
          if (mounted) {
            setState(() {});
          }
        }
      }
    } catch (e) {
      print('❌ [RoleSync] Error checking role update: $e');
    }
  }

  @override
  void dispose() {
    _roleSyncTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUserDataAndCheckAccess() async {
    setState(() {
      _isLoadingUserData = true;
    });
    
    try {
      final userData = await RoleAccessHelper.getCurrentUserData();
      setState(() {
        _userData = userData;
        _isLoadingUserData = false;
      });
      
      // Check if user can access blogger zone
      if (!(await RoleAccessHelper.canAccessBloggerZone())) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showAccessDeniedDialog();
          }
        });
      } else {
        // User can access blogger zone (both approved and pending bloggers reach here)
        _loadBlogsBasedOnRole();
      }
    } catch (e) {
      setState(() {
        _isLoadingUserData = false;
      });
    }
  }

  void _loadBlogsBasedOnRole() {
    // Load blogs based on user role if not already loading
    if (controller.blogs.isEmpty && !controller.isLoading.value) {
      // Set filter based on user role
      if (_userData != null) {
        final isPendingBlogger = RoleAccessHelper.isPendingBlogger(_userData);
        final isBlogger = RoleAccessHelper.isActiveBlogger(_userData);
        
        print('🔍 DEBUG: User role check - isPendingBlogger: $isPendingBlogger, isBlogger: $isBlogger');
        print('🔍 DEBUG: User data: ${_userData}');
        print('🔍 DEBUG: Controller userId: ${controller.userId.value}');
        
        if (isPendingBlogger) {
          // For pending bloggers, show their own posts (pending + approved)
          controller.filterUserId.value = controller.userId.value;
          print('🔍 DEBUG: Setting filterUserId to ${controller.userId.value} (pending blogger)');
        } else if (isBlogger) {
          // For approved bloggers, show all approved posts  
          controller.filterUserId.value = 0;
          print('🔍 DEBUG: Setting filterUserId to 0 (approved blogger - show all posts)');
        } else {
          // For regular users, shouldn't reach here but set to 0
          controller.filterUserId.value = 0;
          print('🔍 DEBUG: Setting filterUserId to 0 (regular user fallback)');
        }
      } else {
        controller.filterUserId.value = 0;
        print('🔍 DEBUG: User data is null, setting filterUserId to 0');
      }
      
      print('🔍 DEBUG: About to call loadBlogs with filterUserId: ${controller.filterUserId.value}');
      controller.loadBlogs(refresh: true);
    } else {
      print('🔍 DEBUG: Not loading blogs - blogs.isEmpty: ${controller.blogs.isEmpty}, isLoading: ${controller.isLoading.value}');
      print('🔍 DEBUG: Current blogs count: ${controller.blogs.length}');
    }
  }

  void _showAccessDeniedDialog() {
    final isPendingBlogger = RoleAccessHelper.isPendingBlogger(_userData);
    final hasRequestedBlogger = controller.isBloggerRequestPending.value;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: ResponsiveHelper.padding(context, all: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon Section
                Container(
                  width: ResponsiveHelper.spacing(context, 80),
                  height: ResponsiveHelper.spacing(context, 80),
                  decoration: BoxDecoration(
                    color: isPendingBlogger 
                        ? Colors.orange.withOpacity(0.1)
                        : AppTheme.iconscolor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPendingBlogger 
                        ? Icons.hourglass_top_rounded
                        : Icons.lock_outline_rounded,
                    size: ResponsiveHelper.iconSize(context, mobile: 40),
                    color: isPendingBlogger 
                        ? Colors.orange
                        : AppTheme.iconscolor,
                  ),
                ),
                
                SizedBox(height: ResponsiveHelper.spacing(context, 20)),
                
                // Title
                Text(
                  isPendingBlogger 
                      ? '🌱 Blogger Request Pending'
                      : '🔒 Blogger Access Required',
                  textAlign: TextAlign.center,
                  style: ResponsiveHelper.textStyle(
                    context,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                
                SizedBox(height: ResponsiveHelper.spacing(context, 12)),
                
                // Status Badge
                Container(
                  padding: ResponsiveHelper.padding(context, horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isPendingBlogger 
                        ? Colors.orange.withOpacity(0.15)
                        : AppTheme.iconscolor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isPendingBlogger 
                          ? Colors.orange.withOpacity(0.3)
                          : AppTheme.iconscolor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    'Status: ${RoleAccessHelper.getRoleDisplayText(_userData)}',
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isPendingBlogger 
                          ? Colors.orange
                          : AppTheme.iconscolor,
                    ),
                  ),
                ),
                
                SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                
                // Description
                Text(
                  isPendingBlogger 
                      ? 'Your blogger request is currently pending admin approval. You can continue using the app as a regular user - view posts, comment, and like content. Full blogger features will be available once approved.'
                      : 'This section is exclusively for approved bloggers. Request blogger access to create and publish your own blog posts, share your thoughts, and connect with the community.',
                  textAlign: TextAlign.center,
                  style: ResponsiveHelper.textStyle(
                    context,
                    fontSize: 16,
                    color: Colors.grey[700],
                    height: 1.5,
                  ),
                ),
                
                SizedBox(height: ResponsiveHelper.spacing(context, 24)),
                
                // Action Buttons
                if (isPendingBlogger) ...[
                  // Pending Blogger - Single button to continue in blogger zone
                  SizedBox(
                    width: double.infinity,
                    height: ResponsiveHelper.buttonHeight(context, mobile: 50),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        // Don't navigate away - let them stay in blogger zone to view blogs
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'View Blogs in Blogger Zone',
                        style: ResponsiveHelper.textStyle(
                          context,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  // Regular User - Two buttons
                  Row(
                    children: [
                        // Become a Blogger button
                        Expanded(
                          child: SizedBox(
                            height: ResponsiveHelper.buttonHeight(context, mobile: 50),
                            child: ElevatedButton(
                              onPressed: hasRequestedBlogger ? null : () async {
                                Navigator.of(context).pop();
                                final success = await controller.requestBloggerAccess();
                                if (success) {
                                  Get.snackbar(
                                    'Request Sent',
                                    'Your blogger request has been sent to admin. You will be notified once approved.',
                                    backgroundColor: Colors.green,
                                    colorText: Colors.white,
                                    duration: const Duration(seconds: 3),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: hasRequestedBlogger 
                                    ? Colors.grey[300]
                                    : AppTheme.iconscolor,
                                foregroundColor: hasRequestedBlogger 
                                    ? Colors.grey[600]
                                    : Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                hasRequestedBlogger 
                                    ? 'Request Sent'
                                    : 'Become a Blogger',
                                style: ResponsiveHelper.textStyle(
                                  context,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                        // Go to Dashboard button
                        Expanded(
                          child: SizedBox(
                            height: ResponsiveHelper.buttonHeight(context, mobile: 50),
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                // Stay in blogger zone - don't navigate away
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.iconscolor,
                                side: BorderSide(color: AppTheme.iconscolor),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Back',
                                style: ResponsiveHelper.textStyle(
                                  context,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.iconscolor,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                  if (hasRequestedBlogger) ...[
                    SizedBox(height: ResponsiveHelper.spacing(context, 12)),
                    Container(
                      padding: ResponsiveHelper.padding(context, all: 12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.blue,
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Please wait for admin approval. You will be notified once your request is reviewed.',
                              style: ResponsiveHelper.textStyle(
                                context,
                                fontSize: 12,
                                color: Colors.blue[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCustomSnackbar(String title, String message, {bool isError = false}) {
    if (!mounted) return;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          backgroundColor: isError ? Colors.red.withOpacity(0.9) : AppTheme.iconscolor,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(ResponsiveHelper.spacing(context, 16)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 4),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () {
            // Navigate back to previous screen or dashboard
            Get.back();
          },
        ),
        title: Text(
          'Blogger Zone',
          style: ResponsiveHelper.textStyle(
            context,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: _buildBody(context),
      floatingActionButton: Obx(() {
        // Check user role and show appropriate button
        if (RoleAccessHelper.isActiveBlogger(_userData)) {
          // Approved blogger - show create blog button
          return FloatingActionButton.extended(
            onPressed: () async => await PaymentGate.navigateToFeature(Routes.CREATE_BLOG),
            backgroundColor: AppTheme.iconscolor,
            elevation: 8,
            icon: Container(
              padding: ResponsiveHelper.padding(context, all: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.edit,
                color: Colors.white,
                size: ResponsiveHelper.iconSize(context, mobile: 22),
              ),
            ),
            label: Text(
              'New Post',
              style: ResponsiveHelper.textStyle(
                context,
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 0.5,
              ),
            ),
          );
        }

        // 2. If user is a pending blogger, show disabled "Create Blog (Pending Approval)" button
        if (RoleAccessHelper.isPendingBlogger(_userData)) {
          return FloatingActionButton.extended(
            onPressed: () {
              _showCustomSnackbar(
                'Approval Required',
                'Your blogger request is pending admin approval. You cannot create blogs until approved.',
                isError: true,
              );
            },
            backgroundColor: Colors.orange[400],
            elevation: 4,
            icon: const Icon(
              Icons.edit_off_rounded,
              color: Colors.white,
              size: 20,
            ),
            label: const Text(
              'Create Blog (Pending)',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          );
        }
        
        // 3. If user is a regular 'User', show enabled "Become a Blogger" button
        if (controller.userRole.value == 'User') {
          return FloatingActionButton.extended(
            onPressed: controller.isLoading.value ? null : () async {
              // Request blogger access
              final success = await controller.requestBloggerAccess();
              
              if (success) {
                _showCustomSnackbar(
                  'Success',
                  'Your blogger request has been sent. Admin will review your request.'
                );
              } else {
                _showCustomSnackbar(
                  'Notice',
                  controller.message.value.isNotEmpty 
                      ? controller.message.value 
                      : 'Failed to send request. Please try again.',
                  isError: true
                );
              }
            },
            backgroundColor: AppTheme.iconscolor,
            elevation: 8,
            icon: controller.isLoading.value 
              ? const SizedBox(
                  width: 20, 
                  height: 20, 
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                )
              : const Icon(
                  Icons.person_add,
                  color: Colors.white,
                  size: 22,
                ),
            label: Text(
              controller.isLoading.value ? 'Sending...' : 'Become a Blogger',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 0.5,
              ),
            ),
          );
        }
        
        // Default case: Hide the button if none of the above conditions are met.
        return const SizedBox.shrink();
      }),
    );
  }

  /// Social Media Style Blog Card - Same as home page
  Widget _buildSocialMediaBlogCard(BuildContext context, Map<String, dynamic> blog, BlogsController controller) {
    final baseUrl = 'http://admin.fosmessenger.com/';
    final imagePath = blog['image_url'] as String?;
    String? imageUrl;
    if (imagePath != null && imagePath.toString().trim().isNotEmpty) {
      if (imagePath.toString().startsWith('http')) {
        imageUrl = imagePath.toString();
      } else {
        final cleanPath = imagePath.toString().startsWith('/') ? imagePath.toString().substring(1) : imagePath.toString();
        imageUrl = '$baseUrl$cleanPath';
      }
    }
    final title = AutoTranslateHelper.getTranslatedTextSync(
      text: blog['title'] ?? 'Untitled',
      sourceLanguage: blog['language'] as String?,
    );
    final author = blog['user_name'] ?? 'Anonymous';
    final profilePhoto = blog['profile_photo'] as String?;
    final createdAt = blog['created_at'] as String?;
    final likeCount = int.tryParse((blog['like_count'] ?? 0).toString()) ?? 0;
    final commentCount = int.tryParse((blog['comment_count'] ?? 0).toString()) ?? 0;
    
    String? profilePhotoUrl;
    if (profilePhoto != null && profilePhoto.toString().isNotEmpty) {
      final photoPath = profilePhoto.toString();
      if (!photoPath.startsWith('assets/') && !photoPath.startsWith('file://') && !photoPath.startsWith('assets/images/')) {
        profilePhotoUrl = photoPath.startsWith('http') ? photoPath : '$baseUrl$photoPath';
      }
    }

    return InkWell(
      onTap: () => PaymentGate.navigateToFeature(Routes.BLOG_DETAILS, arguments: blog['id']),
      borderRadius: BorderRadius.circular(12),
      child: Container(
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
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Name Section - On Top
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Profile Picture - Same as home page
                  profilePhotoUrl != null
                      ? ClipOval(
                          child: CachedImage(
                            imageUrl: profilePhotoUrl,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorWidget: CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.grey[300]!,
                              child: Icon(
                                Icons.person_rounded,
                                size: 24,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        )
                      : CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.grey[300]!,
                          child: Icon(
                            Icons.person_rounded,
                            size: 24,
                            color: AppTheme.iconscolor,
                          ),
                        ),
                  const SizedBox(width: 12),
                  // Name and Timestamp
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          author,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        if (createdAt != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            TimeHelper.getTimeAgo(createdAt),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.normal,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Three-dot menu
                  IconButton(
                    icon: Icon(
                      Icons.more_vert,
                      size: 20,
                      color: AppTheme.iconscolor,
                    ),
                    onPressed: () {
                      PaymentGate.navigateToFeature(Routes.BLOG_DETAILS, arguments: blog['id']);
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            // Text/Blog Content - Below User Name with "more" option
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              child: _BlogContentWidget(
                title: title,
                content: blog['content'] ?? blog['description'] ?? '',
                language: blog['language'] as String?,
              ),
            ),
            const SizedBox(height: 16),
            // Photo at Bottom (if available) - Properly resized
            if (imageUrl != null && imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
                child: CachedImage(
                  imageUrl: imageUrl,
                  width: double.infinity,
                  height: ResponsiveHelper.imageHeight(context, mobile: 220, tablet: 250, desktop: 280),
                  fit: BoxFit.cover,
                  errorWidget: Container(
                    width: double.infinity,
                    height: ResponsiveHelper.imageHeight(context, mobile: 220, tablet: 250, desktop: 280),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.article_rounded,
                      size: ResponsiveHelper.iconSize(context, mobile: 50, tablet: 60, desktop: 70),
                      color: AppTheme.iconscolor,
                    ),
                  ),
                ),
              ),
            // Bottom Actions - Left: Likes count, Right: Comments count
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left: Likes count with icon - Only show if > 0
                  if (likeCount > 0)
                    Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.favorite,
                            size: 18,
                            color: AppTheme.iconscolor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$likeCount',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.iconscolor,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Right: Comments count with icon - Only show if > 0
                  if (commentCount > 0)
                    Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.comment_outlined,
                            size: 18,
                            color: AppTheme.iconscolor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$commentCount',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.iconscolor,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  

  Widget _buildNonBloggerView(BuildContext context) {
    return Obx(() {
      // Check if user has pending blogger request (role is Blogger but status is Inactive)
      final hasPendingRequest = controller.userRole.value == 'Blogger' && 
                                (controller.userStatus.value == 'Inactive' || controller.userStatus.value == 'Pending');
      
    return SingleChildScrollView(
      padding: ResponsiveHelper.padding(context, all: 20),
      child: Column(

        children: [

          // SizedBox(height: ResponsiveHelper.spacing(context, 40)),
          Container(
            padding: ResponsiveHelper.padding(context, all: 28),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 25,
                  spreadRadius: 3,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              Icons.article_outlined,
              size: ResponsiveHelper.iconSize(context, mobile: 70, tablet: 80, desktop: 90),
              color: AppTheme.iconscolor,
            ),
          ),
          SizedBox(height: ResponsiveHelper.spacing(context, 28)),
          Text(
            'Blogger Zone',
            style: ResponsiveHelper.textStyle(
              context,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.black,
              letterSpacing: 0.5,
            ),
          ),
          // SizedBox(height: ResponsiveHelper.spacing(context, 18)),

            // Show pending request message if applicable
            if (hasPendingRequest) ...[
              Container(
                margin: ResponsiveHelper.padding(context, horizontal: 16, vertical: 12),
                padding: ResponsiveHelper.padding(context, all: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
                  border: Border.all(
                    color: AppTheme.iconscolor.withOpacity(0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: ResponsiveHelper.padding(context, all: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.iconscolor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.hourglass_empty_rounded,
                            color: Colors.white,
                            size: ResponsiveHelper.iconSize(context, mobile: 24),
                          ),
                        ),
                        SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Request Pending Approval',
                                style: ResponsiveHelper.textStyle(
                                  context,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              SizedBox(height: ResponsiveHelper.spacing(context, 4)),
                              Text(
                                'Please wait while admin reviews your blogger request. You will be notified once approved.',
                                style: ResponsiveHelper.textStyle(
                                  context,
                                  fontSize: 14,
                                  color: Colors.black87,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: ResponsiveHelper.spacing(context, 24)),
            ] else ...[
          Text(
            'Only approved bloggers can create and manage blog posts. Request access to share your inspiring messages with the community.',
            textAlign: TextAlign.center,
            style: ResponsiveHelper.textStyle(
              context,
              fontSize: 17,
              color: Colors.grey[800],
              height: 1.6,
            ),
          ),
          // SizedBox(height: ResponsiveHelper.spacing(context, 44)),
          // _buildRequestButton(context),
            ],
          SizedBox(height: ResponsiveHelper.spacing(context, 24)),
          if (controller.blogs.isNotEmpty) ...[
            Container(
              margin: ResponsiveHelper.padding(context, vertical: 24),
              height: ResponsiveHelper.spacing(context, 1),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.grey.withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 8)),
            Container(
              padding: ResponsiveHelper.padding(context, horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                'Recent Blog Posts',
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 20)),
            ...controller.blogs.map((blog) => _buildSocialMediaBlogCard(context, blog, controller)),
          ],
        ],
      ),
    );
    });
  }

  Widget _buildRequestButton(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: ResponsiveHelper.spacing(context, 24)),
      width: double.infinity,
      height: ResponsiveHelper.buttonHeight(context, mobile: 56),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.iconscolor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: controller.isLoading.value ? null : () => _showRequestDialog(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.iconscolor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
          ),
          elevation: 0,
        ),
        child: controller.isLoading.value
            ? const CircularProgressIndicator(color: Colors.white)
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: ResponsiveHelper.padding(context, all: 1),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.send,
                      color: Colors.white,
                      size: ResponsiveHelper.iconSize(context, mobile: 20),
                    ),
                  ),
                  SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                  Flexible(
                    child: Text(
                      'Request Blogger Access',
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: ResponsiveHelper.padding(context, all: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: ResponsiveHelper.padding(context, all: 32),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 25,
                    spreadRadius: 3,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(
                Icons.article_outlined,
                size: ResponsiveHelper.iconSize(context, mobile: 72, tablet: 80, desktop: 90),
                color: AppTheme.iconscolor,
              ),
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 28)),
            Text(
              'No blogs available yet',
              style: ResponsiveHelper.textStyle(
                context,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                letterSpacing: 0.3,
              ),
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 12)),
            Text(
              'Start sharing your inspiring content with the community!',
              textAlign: TextAlign.center,
              style: ResponsiveHelper.textStyle(
                context,
                fontSize: 17,
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRequestDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 20)),
          ),
          title: Text(
            'Request to Become a Blogger',
            style: ResponsiveHelper.textStyle(
              context,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          content: Text(
            'Your request will be sent to the admin for approval. You will be notified once your request is reviewed.',
            style: ResponsiveHelper.textStyle(
              context,
              fontSize: 14,
            ),
          ),
          actions: [
            TextButton(
              onPressed: (){
                final dialogContext = Get.overlayContext;
                if (dialogContext != null) {
                  Navigator.of(dialogContext, rootNavigator: true).pop();
                } else if (context.mounted) {
                  Navigator.of(context, rootNavigator: true).pop();
                }
              },
              child: Text(
                'Cancel',
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final success = await controller.requestBloggerAccess();
                if (success) {
                  Get.snackbar(
                    'Success',
                    'Request sent successfully! Admin will review your request.',
                    backgroundColor: AppTheme.iconscolor,
                    colorText: Colors.black,
                    duration: const Duration(seconds: 3),
                  );
                } else {
                  Get.snackbar(
                    'Error',
                    controller.message.value,
                    backgroundColor: Colors.red,
                    colorText: Colors.white,
                  );
                }
                final dialogContext = Get.overlayContext;
                if (dialogContext != null) {
                  Navigator.of(dialogContext, rootNavigator: true).pop();
                } else if (context.mounted) {
                  Navigator.of(context, rootNavigator: true).pop();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.iconscolor,
              ),
              child: Text(
                'Send Request',
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    // Use our new role-based access control
    if (_isLoadingUserData) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.iconscolor),
      );
    }

    final isBlogger = RoleAccessHelper.isActiveBlogger(_userData);
    final isPendingBlogger = RoleAccessHelper.isPendingBlogger(_userData);
    final isRegularUser = RoleAccessHelper.isRegularUser(_userData);
    
    print('🔍 [BloggerZone] _buildBody role detection:');
    print('  - _userData: $_userData');
    print('  - isBlogger: $isBlogger');
    print('  - isPendingBlogger: $isPendingBlogger');
    print('  - isRegularUser: $isRegularUser');
    print('  - controller.userRole: ${controller.userRole.value}');
    print('  - controller.blogs.length: ${controller.blogs.length}');
    print('  - controller.isLoading.value: ${controller.isLoading.value}');
    
    // Try to show something regardless of role detection
    if (controller.blogs.isNotEmpty) {
      print('🔍 [BloggerZone] Blogs are loaded, showing them regardless of role');
      return Obx(() {
        return RefreshIndicator(
          onRefresh: () => controller.loadBlogs(refresh: true),
          color: AppTheme.iconscolor,
          backgroundColor: Colors.white,
          child: ListView.builder(
            padding: ResponsiveHelper.padding(context, vertical: 12),
            itemCount: controller.blogs.length,
            itemBuilder: (context, index) {
              final blog = controller.blogs[index];
              return _buildSocialMediaBlogCard(context, blog, controller);
            },
          ),
        );
      });
    }

    // If user is a regular user, show access denied view
    if (isRegularUser) {
      return _buildNonBloggerView(context);
    }

    // If user is a pending blogger, show their pending posts but restrict blog creation
    if (isPendingBlogger) {
      return Obx(() {
        if (controller.isLoading.value && controller.blogs.isEmpty) {
          return Center(
            child: CircularProgressIndicator(
              color: AppTheme.iconscolor,
              strokeWidth: ResponsiveHelper.spacing(context, 3),
            ),
          );
        }

        if (controller.blogs.isEmpty) {
          return _buildPendingBloggerEmptyView(context);
        }

        return Column(
          children: [
            // Pending status message
            Container(
              width: double.infinity,
              margin: ResponsiveHelper.padding(context, all: 16),
              padding: ResponsiveHelper.padding(context, all: 16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.hourglass_top_rounded,
                    color: Colors.orange,
                    size: ResponsiveHelper.iconSize(context, mobile: 24),
                  ),
                  SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Blogger Request Pending',
                          style: ResponsiveHelper.textStyle(
                            context,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                        SizedBox(height: ResponsiveHelper.spacing(context, 4)),
                        Text(
                          'Your posts are waiting for admin approval. You can view posts but cannot create new ones until approved.',
                          style: ResponsiveHelper.textStyle(
                            context,
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Blog list
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => controller.loadBlogs(refresh: true),
                color: AppTheme.iconscolor,
                backgroundColor: Colors.white,
                child: ListView.builder(
                  padding: ResponsiveHelper.padding(context, vertical: 12),
                  itemCount: controller.blogs.length,
                  itemBuilder: (context, index) {
                    final blog = controller.blogs[index];
                    return _buildSocialMediaBlogCard(context, blog, controller);
                  },
                ),
              ),
            ),
          ],
        );
      });
    }

    // Show blog list for approved bloggers - use Obx only where needed
    if (isBlogger) {
      return Obx(() {
        if (controller.isLoading.value && controller.blogs.isEmpty) {
          return Center(
            child: CircularProgressIndicator(
              color: AppTheme.iconscolor,
              strokeWidth: ResponsiveHelper.spacing(context, 3),
            ),
          );
        }

        if (controller.blogs.isEmpty) {
          return _buildEmptyState(context);
        }

        return RefreshIndicator(
          onRefresh: () => controller.loadBlogs(refresh: true),
          color: AppTheme.iconscolor,
          backgroundColor: Colors.white,
          child: ListView.builder(
            padding: ResponsiveHelper.padding(context, vertical: 12),
            itemCount: controller.blogs.length,
            itemBuilder: (context, index) {
              final blog = controller.blogs[index];
              return _buildSocialMediaBlogCard(context, blog, controller);
            },
          ),
        );
      });
    }

    // Default case, should ideally not be reached if all roles are handled
    return const SizedBox.shrink();
  }

Widget _buildPendingBloggerEmptyView(BuildContext context) {
    return Center(
      child: Padding(
        padding: ResponsiveHelper.padding(context, all: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: ResponsiveHelper.padding(context, all: 32),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 25,
                    spreadRadius: 3,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(
                Icons.hourglass_top_rounded,
                size: ResponsiveHelper.iconSize(context, mobile: 72, tablet: 80, desktop: 90),
                color: Colors.orange,
              ),
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 28)),
            Text(
              'No Posts Yet',
              style: ResponsiveHelper.textStyle(
                context,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                letterSpacing: 0.3,
              ),
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 12)),
            Text(
              'Your blogger request is pending approval.\nCreate your first post after admin approval!',
              textAlign: TextAlign.center,
              style: ResponsiveHelper.textStyle(
                context,
                fontSize: 17,
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 32)),
            Container(
              padding: ResponsiveHelper.padding(context, all: 24),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 20)),
                border: Border.all(
                  color: Colors.orange.withOpacity(0.2),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What you can do while waiting:',
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                  _buildFeatureItem('✅', 'View other users\' posts'),
                  _buildFeatureItem('✅', 'Comment on posts'),
                  _buildFeatureItem('✅', 'Access all app features'),
                  _buildFeatureItem('⏳', 'Create posts (after approval)'),
                  _buildFeatureItem('⏳', 'Publish content (after approval)'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingBloggerView(BuildContext context) {
    return Center(
      child: Padding(
        padding: ResponsiveHelper.padding(context, horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: ResponsiveHelper.spacing(context, 140),
              height: ResponsiveHelper.spacing(context, 140),
              decoration: BoxDecoration(
                color: AppTheme.iconscolor.withOpacity(0.1),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 25,
                    spreadRadius: 3,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(
                Icons.hourglass_top_rounded,
                size: ResponsiveHelper.iconSize(context, mobile: 72, tablet: 80, desktop: 90),
                color: AppTheme.iconscolor,
              ),
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 28)),
            Text(
              'Blogger Request Pending',
              style: ResponsiveHelper.textStyle(
                context,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                letterSpacing: 0.3,
              ),
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 12)),
            Text(
              'Your blogger request is being reviewed by the admin.\nYou will be able to create blogs once approved.',
              textAlign: TextAlign.center,
              style: ResponsiveHelper.textStyle(
                context,
                fontSize: 17,
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 32)),
            Container(
              padding: ResponsiveHelper.padding(context, all: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 20)),
                border: Border.all(
                  color: AppTheme.iconscolor.withOpacity(0.2),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What you can do while waiting:',
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                  _buildFeatureItem('✅', 'Login as Blogger'),
                  _buildFeatureItem('✅', 'View your profile'),
                  _buildFeatureItem('✅', 'Access basic app features'),
                  _buildFeatureItem('⏳', 'Create blogs (after approval)'),
                  _buildFeatureItem('⏳', 'Publish content (after approval)'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            icon,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: ResponsiveHelper.textStyle(
                context,
                fontSize: 16,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Blog Content Widget with More/Less functionality
class _BlogContentWidget extends StatefulWidget {
  final String title;
  final String content;
  final String? language;

  const _BlogContentWidget({
    required this.title,
    required this.content,
    this.language,
  });

  @override
  State<_BlogContentWidget> createState() => _BlogContentWidgetState();
}

class _BlogContentWidgetState extends State<_BlogContentWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final textToShow = widget.content.isNotEmpty 
        ? AutoTranslateHelper.getTranslatedTextSync(
            text: widget.content,
            sourceLanguage: widget.language,
          )
        : AutoTranslateHelper.getTranslatedTextSync(
            text: widget.title,
            sourceLanguage: widget.language,
          );
    
    final maxLines = 4;
    final needsMoreButton = textToShow.length > 200; // Approximate check for long text
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          textToShow,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black87,
            height: 1.5,
            fontWeight: FontWeight.normal,
          ),
          maxLines: _isExpanded ? null : maxLines,
          overflow: _isExpanded ? null : TextOverflow.ellipsis,
        ),
        if (needsMoreButton && !_isExpanded) ...[
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () {
              setState(() {
                _isExpanded = true;
              });
            },
            child: Text(
              'more',
              style: TextStyle(
                fontSize: 14,
                color: Colors.blue[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        if (_isExpanded) ...[
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () {
              setState(() {
                _isExpanded = false;
              });
            },
            child: Text(
              'less',
              style: TextStyle(
                fontSize: 14,
                color: Colors.blue[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFeatureItem(String icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            icon,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: ResponsiveHelper.textStyle(
                context,
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
