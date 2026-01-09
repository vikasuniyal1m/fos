import 'package:flutter/material.dart';
import 'package:fruitsofspirit/utils/app_theme.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/controllers/videos_controller.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';
import 'package:fruitsofspirit/routes/routes.dart';
import 'package:fruitsofspirit/config/image_config.dart';
import 'package:fruitsofspirit/widgets/cached_image.dart';
import 'package:fruitsofspirit/widgets/standard_app_bar.dart';
import 'package:fruitsofspirit/widgets/app_bottom_navigation_bar.dart';

/// Videos Screen
/// Displays list of videos with filters
class VideosScreen extends StatefulWidget {
  const VideosScreen({Key? key}) : super(key: key);

  @override
  State<VideosScreen> createState() => _VideosScreenState();
}

class _VideosScreenState extends State<VideosScreen> {
  final controller = Get.find<VideosController>();

  @override
  void initState() {
    super.initState();
    // Refresh videos when screen is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.loadVideos(refresh: true, includePending: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: StandardAppBar(
        showBackButton: false,
        rightActions: [
          StandardAppBar.buildActionIcon(
            context,
            icon: Icons.add_rounded,
            onTap: () async {
              await Get.toNamed(Routes.UPLOAD_VIDEO);
              controller.loadVideos(refresh: true, includePending: true);
            },
          ),
        ],
      ),
      body: PopScope(
        canPop: true,
        onPopInvoked: (didPop) {
          if (didPop) {
            // Refresh videos when user navigates back
            controller.loadVideos(refresh: true, includePending: true);
          }
        },
        child: Obx(() {
          if (controller.isLoading.value && controller.videos.isEmpty) {
          return Center(
            child: CircularProgressIndicator(
              color: AppTheme.iconscolor,
            ),
          );
        }

        if (controller.videos.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.video_library_outlined,
                  size: ResponsiveHelper.iconSize(context, mobile: 64),
                  color: Colors.grey,
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                Text(
                  'No videos available',
                  style: ResponsiveHelper.textStyle(
                    context,
                    fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
                    color: Colors.grey,
                  ),
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                ElevatedButton(
                  onPressed: () async {
                    await Get.toNamed(Routes.UPLOAD_VIDEO);
                    // Refresh videos when returning from upload screen
                    controller.loadVideos(refresh: true, includePending: true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.iconscolor,
                  ),
                  child: Text(
                    'Upload Video',
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => controller.refresh(),
          color: AppTheme.iconscolor,
          child: GridView.builder(
            padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 16)),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: ResponsiveHelper.isTablet(context) ? 3 : 2,
              crossAxisSpacing: ResponsiveHelper.spacing(context, 12),
              mainAxisSpacing: ResponsiveHelper.spacing(context, 12),
              childAspectRatio: 0.75,
            ),
            itemCount: controller.videos.length,
            itemBuilder: (context, index) {
              final video = controller.videos[index];
              return _buildVideoCard(context, video, controller);
            },
          ),
        );
        }        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Get.toNamed(Routes.UPLOAD_VIDEO);
          // Refresh videos when returning from upload screen
          controller.loadVideos(refresh: true, includePending: true);
        },
        backgroundColor: AppTheme.iconscolor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'Upload Video',
          style: ResponsiveHelper.textStyle(
            context,
            fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNavigationBar(currentIndex: 3),
    );
  }

  Widget _buildVideoCard(BuildContext context, Map<String, dynamic> video, VideosController controller) {
    final isPending = video['status'] == 'Pending' || video['status'] == 'pending';
    final filePath = video['file_path'] as String? ?? '';
    final thumbnailPath = video['thumbnail_path'] as String?;
    final baseUrl = 'https://fruitofthespirit.templateforwebsites.com/';
    
    return GestureDetector(
      onTap: () => Get.toNamed(
        Routes.VIDEO_DETAILS,
        arguments: video['id'],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(
            ResponsiveHelper.borderRadius(context, mobile: 12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Video Thumbnail
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                ),
                child: Stack(
                  children: [
                    // Background Image
                    Positioned.fill(
                      child: thumbnailPath != null
                          ? Image.network(
                              baseUrl + thumbnailPath,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Image.network(
                                  ImageConfig.videoThumbnail,
                                  fit: BoxFit.cover,
                                );
                              },
                            )
                          : Image.network(
                              ImageConfig.videoThumbnail,
                              fit: BoxFit.cover,
                            ),
                    ),
                    // Pending Badge
                    if (isPending)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: ResponsiveHelper.spacing(context, 8),
                            vertical: ResponsiveHelper.spacing(context, 4),
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(
                              ResponsiveHelper.borderRadius(context, mobile: 8),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.pending,
                                size: ResponsiveHelper.iconSize(context, mobile: 12),
                                color: Colors.white,
                              ),
                              SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                              Text(
                                'Pending',
                                style: ResponsiveHelper.textStyle(
                                  context,
                                  fontSize: ResponsiveHelper.fontSize(context, mobile: 10),
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ),
                    // Play Icon
                    Positioned.fill(
                      child: Center(
                        child: Container(
                          padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 8)),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: ResponsiveHelper.iconSize(context, mobile: 32),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Video Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 8)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video['title'] as String? ?? 'Untitled Video',
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                        fontWeight: FontWeight.bold,
                        color: AppTheme.iconscolor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(context, 4)),
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: ResponsiveHelper.iconSize(context, mobile: 14),
                          color: Colors.grey,
                        ),
                        SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                        Expanded(
                          child: Text(
                            video['user_name'] as String? ?? 'Anonymous',
                            style: ResponsiveHelper.textStyle(
                              context,
                              fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                              color: Colors.grey,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

