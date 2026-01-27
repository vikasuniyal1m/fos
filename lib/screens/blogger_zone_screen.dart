import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/controllers/blogs_controller.dart';
import 'package:fruitsofspirit/routes/routes.dart';
import 'package:fruitsofspirit/widgets/cached_image.dart';
import 'package:fruitsofspirit/widgets/app_bottom_navigation_bar.dart';
import 'package:fruitsofspirit/widgets/standard_app_bar.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';
import 'package:fruitsofspirit/utils/auto_translate_helper.dart';
import 'package:fruitsofspirit/utils/app_theme.dart';
import 'package:fruitsofspirit/services/user_storage.dart';
import 'package:fruitsofspirit/config/image_config.dart';

/// Blogger Zone Screen - Social Media Style
/// Professional, attractive UI with like, comment, and question functionality
class BloggerZoneScreen extends GetView<BlogsController> {
  const BloggerZoneScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Load blogs on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.blogs.isEmpty && !controller.isLoading.value) {
        controller.filterUserId.value = 0;
        controller.loadBlogs(refresh: true);
      }
    });

    return Scaffold(
        backgroundColor: Colors.white,
      appBar: const StandardAppBar(        showBackButton: true,
      ),
      body: Obx(() {
        // Show request button for non-bloggers
        if (controller.userRole.value != 'Blogger') {
          return _buildNonBloggerView(context);
        }

        // Show blog list for bloggers
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
      }),
      floatingActionButton: Obx(() {
        final isBlogger = controller.userRole.value == 'Blogger';
        final isActive = controller.userStatus.value == 'Active';
        final hasPendingRequest = controller.userRole.value == 'Blogger' && 
                                  (controller.userStatus.value == 'Inactive' || controller.userStatus.value == 'Pending');
        
        // Show button only if user is approved Blogger (role=Blogger, status=Active)
        if (isBlogger && isActive) {
          return FloatingActionButton.extended(
            onPressed: () => Get.toNamed(Routes.CREATE_BLOG),
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
        
        // Show disabled button with message if pending approval
        if (hasPendingRequest) {
          return FloatingActionButton.extended(
            onPressed: () {
              Get.snackbar(
                'Approval Pending',
                'Waiting for approval from admin. You cannot create posts until your blogger request is approved.',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: Colors.orange.withOpacity(0.9),
                colorText: Colors.white,
                duration: const Duration(seconds: 3),
              );
            },
            backgroundColor: Colors.grey,
            elevation: 8,
            icon: Icon(
              Icons.pending,
              color: Colors.white,
              size: ResponsiveHelper.iconSize(context, mobile: 22),
            ),
            label: Text(
              'Waiting for Approval',
              style: ResponsiveHelper.textStyle(
                context,
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 0.5,
              ),
            ),
          );
        }
        
        // Show button for non-bloggers to request access
        return FloatingActionButton.extended(
          onPressed: () async {
            // Show snackbar and then request blogger access
            Get.snackbar(
              'Become a Blogger',
              'Requesting blogger access...',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: AppTheme.iconscolor.withOpacity(0.9),
              colorText: Colors.white,
              duration: const Duration(seconds: 2),
            );
            
            // Request blogger access
            final success = await controller.requestBloggerAccess();
            
            if (success) {
              Get.snackbar(
                'Request Sent',
                'Your blogger request has been sent. Admin will review your request.',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: Colors.green.withOpacity(0.9),
                colorText: Colors.white,
                duration: const Duration(seconds: 3),
              );
            } else {
              Get.snackbar(
                'Error',
                controller.message.value.isNotEmpty 
                    ? controller.message.value 
                    : 'Failed to send request. Please try again.',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: Colors.red.withOpacity(0.9),
                colorText: Colors.white,
                duration: const Duration(seconds: 3),
              );
            }
          },
          backgroundColor: AppTheme.iconscolor,
          elevation: 8,
          icon: Icon(
            Icons.person_add,
            color: Colors.white,
            size: ResponsiveHelper.iconSize(context, mobile: 22),
          ),
          label: Text(
            'Become a Blogger',
            style: ResponsiveHelper.textStyle(
              context,
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              letterSpacing: 0.5,
            ),
          ),
        );
      }),
    );
  }

  /// Social Media Style Blog Card - Same as home page
  Widget _buildSocialMediaBlogCard(BuildContext context, Map<String, dynamic> blog, BlogsController controller) {
    final baseUrl = 'https://fruitofthespirit.templateforwebsites.com/';
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
      onTap: () => Get.toNamed(Routes.BLOG_DETAILS, arguments: blog['id']),
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
                            _getTimeAgo(createdAt),
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
                      Get.toNamed(Routes.BLOG_DETAILS, arguments: blog['id']);
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

  Widget _buildNonBloggerView(BuildContext context) {
    return Obx(() {
      // Check if user has pending blogger request (role is Blogger but status is Inactive)
      final hasPendingRequest = controller.userRole.value == 'Blogger' && 
                                (controller.userStatus.value == 'Inactive' || controller.userStatus.value == 'Pending');
      
    return SingleChildScrollView(
      padding: ResponsiveHelper.padding(context, all: 20),
      child: Column(

        children: [

          SizedBox(height: ResponsiveHelper.spacing(context, 40)),
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
          SizedBox(height: ResponsiveHelper.spacing(context, 18)),

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
          SizedBox(height: ResponsiveHelper.spacing(context, 44)),
          _buildRequestButton(context),
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
                final dialogContext = Get.overlayContext;
                if (dialogContext != null) {
                  Navigator.of(dialogContext, rootNavigator: true).pop();
                } else if (context.mounted) {
                  Navigator.of(context, rootNavigator: true).pop();
                }
                print("Done");
                final success = await controller.requestBloggerAccess();
                if (success) {
                  Get.snackbar(
                    'Success',
                    'Request sent successfully! Admin will review your request.',
                    backgroundColor: Colors.green,
                    colorText: Colors.white,
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
}
