import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:get/get.dart';
import 'package:fruitsofspirit/controllers/home_controller.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';
import 'package:video_player/video_player.dart';
import 'package:fruitsofspirit/services/emojis_service.dart';
import 'package:fruitsofspirit/services/user_storage.dart';
import 'package:fruitsofspirit/services/ecommerce_service.dart';
import 'package:fruitsofspirit/config/image_config.dart';
import 'package:fruitsofspirit/config/quick_actions_config.dart';
import 'package:fruitsofspirit/routes/routes.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fruitsofspirit/utils/localization_helper.dart';
import 'package:fruitsofspirit/utils/auto_translate_helper.dart';
import 'package:fruitsofspirit/widgets/cached_image.dart';
import 'package:fruitsofspirit/widgets/animated_praying_hands.dart';
import 'package:fruitsofspirit/widgets/app_bottom_navigation_bar.dart';
import 'package:fruitsofspirit/widgets/standard_app_bar.dart';
import 'package:fruitsofspirit/controllers/prayers_controller.dart';
import 'package:fruitsofspirit/controllers/blogs_controller.dart';
import 'package:fruitsofspirit/controllers/gallery_controller.dart';
import 'package:fruitsofspirit/controllers/groups_controller.dart';
import 'package:fruitsofspirit/services/live_streaming_service.dart';
import 'package:fruitsofspirit/widgets/video_frame_thumbnail.dart';

import '../utils/app_theme.dart';
import 'IntroVideoScreen.dart';

class HomeScreen extends GetView<HomeController> {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PopScope(
          canPop: Navigator.of(context).canPop(), // Allow pop if navigation history exists
          onPopInvoked: (didPop) async {
        if (didPop) return;

        // If we can't pop, we're at root - show exit confirmation
        if (!Navigator.of(context).canPop()) {
          final shouldExit = await Get.dialog<bool>(
            AlertDialog(
              title: Text(
                'Exit App?',
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: ResponsiveHelper.fontSize(context, mobile: 18, tablet: 20, desktop: 22),
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              content: Text(
                'Do you want to exit the app?',
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                  color: Colors.black,
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
              ),
              actions: [
                TextButton(
                  onPressed: () => Get.back(result: false),
                  child: Text(
                    'Cancel',
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Get.back(result: true),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF8B4513),
                  ),
                  child: Text(
                    'Exit',
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
            barrierDismissible: false,
          );
          
          // If user confirmed exit, exit the app
          if (shouldExit == true) {
            SystemNavigator.pop();
          }
        } else {
          // We can pop, so just go back normally
          Get.back();
        }
      },
      child: Scaffold(
        // backgroundColor: const Color(0xFFF8F9FA),
        backgroundColor: AppTheme.themeColor,
        appBar: const StandardAppBar(),
        body: Obx(() {
          // Show loading indicator ONLY if no cached data exists
          // If cache exists, data shows instantly, no loading indicator
          final hasCachedData = controller.fruits.isNotEmpty ||
              controller.prayers.isNotEmpty ||
              controller.blogs.isNotEmpty;

          if (controller.isInitialLoading.value && !hasCachedData) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Professional loading indicator
                  Container(
                    padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 20)),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: CircularProgressIndicator(
                      color: const Color(0xFF8B4513),
                      strokeWidth: 3,
                    ),
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(context, 20)),
                  Text(
                    controller.message.value.isNotEmpty
                        ? controller.message.value
                        : 'Loading...',
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
                      color: Colors.black,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          // Show actual content once data is loaded
          // Professional responsive design for tablets/iPads
          final isTabletDevice = ResponsiveHelper.isTablet(context);
          final maxContentWidth = isTabletDevice
              ? (ResponsiveHelper.isLargeTablet(context) ? 1200.0 : 840.0)
              : null;

          return SafeArea(
            top: false,
            bottom: true,
            child: RefreshIndicator(
              onRefresh: () => controller.refreshData(),
              color: const Color(0xFF8B4513),
              child: ResponsiveHelper.constrainedContent(
                context: context,
                maxWidth: maxContentWidth,
                child: SingleChildScrollView(
                  controller: controller.scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Subtle Top Actions - Social Media Style with Expandable Feel Section
                      Padding(
                        padding: ResponsiveHelper.safePadding(
                          context,
                          horizontal: ResponsiveHelper.isMobile(context) ? 16 : 20,
                          vertical: ResponsiveHelper.isMobile(context) ? 10 : 12,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _ExpandableFeelSection(controller: controller),
                            ),
                            SizedBox(width: ResponsiveHelper.spacing(context, 10)),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () async {
                                  try {
                                    // Get e-commerce URL from backend
                                    final ecommerceData = await EcommerceService.getEcommerceUrl();
                                    final ecommerceUrl = ecommerceData['url'] as String? ?? 'https://your-ecommerce-app-url.com';

                                    final uri = Uri.parse(ecommerceUrl);
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                                    } else {
                                      Get.snackbar(
                                        'E-Commerce',
                                        'E-commerce URL is not configured. Please contact admin.',
                                        backgroundColor: Colors.orange,
                                        colorText: Colors.white,
                                      );
                                    }
                                  } catch (e) {
                                    Get.snackbar(
                                      'Error',
                                      'Failed to open e-commerce: $e',
                                      backgroundColor: Colors.red,
                                      colorText: Colors.white,
                                    );
                                  }
                                },
                                borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16, tablet: 18, desktop: 20)),
                                child: Container(
                                  padding: ResponsiveHelper.padding(
                                    context,
                                    horizontal: ResponsiveHelper.isMobile(context) ? 12 : ResponsiveHelper.isTablet(context) ? 16 : 20,
                                    vertical: ResponsiveHelper.isMobile(context) ? 10 : ResponsiveHelper.isTablet(context) ? 12 : 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16, tablet: 18, desktop: 20)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.withOpacity(0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Image.asset(
                                        'assets/fosshoppinglogo.png',
                                        width: ResponsiveHelper.isMobile(context)
                                            ? 50.0
                                            : ResponsiveHelper.isTablet(context)
                                            ? 70.0
                                            : 90.0,
                                        height: ResponsiveHelper.isMobile(context)
                                            ? 50.0
                                            : ResponsiveHelper.isTablet(context)
                                            ? 70.0
                                            : 90.0,
                                        fit: BoxFit.contain,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Icon(
                                            Icons.shopping_bag_rounded,
                                            color: AppTheme.iconscolor,
                                            size: ResponsiveHelper.isMobile(context)
                                                ? 50.0
                                                : ResponsiveHelper.isTablet(context)
                                                ? 70.0
                                                : 90.0,
                                          );
                                        },
                                      ),
                                      SizedBox(height: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 4 : 6)),
                                      Text(
                                        'Shop Now',
                                        style: ResponsiveHelper.textStyle(
                                          context,
                                          fontSize: ResponsiveHelper.fontSize(
                                            context,
                                            mobile: 12,
                                            tablet: 14,
                                            desktop: 16,
                                          ),
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 6 : 8)),
                      // Stories Section - Instagram Style (No Header, Just Stories)
                      // Show only stories from stories table
                      Obx(() {
                        final stories = controller.stories;

                        if (stories.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        // Take first 8 stories (already sorted by created_at DESC from API)
                        final storiesToShow = stories.take(8).toList();
                        return _buildStoriesCarousel(context, storiesToShow);
                      }),
                      SizedBox(height: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 12 : 16)),
                      // Quick Actions - NEW Compact Design with Labels in Colored Box
                      Padding(
                        padding: ResponsiveHelper.padding(
                          context,
                          horizontal: ResponsiveHelper.isMobile(context) ? 16 : 20,
                        ),
                        child: _buildQuickActionsBox(context),
                      ),
                      // OLD Quick Actions - COMMENTED OUT
                      // Padding(
                      //   padding: ResponsiveHelper.padding(context, horizontal: 16),
                      //   child: _buildQuickActionsGrid(context),
                      // ),
                      // Unified Feed - Mixed Content (Social Media Style)
                      // Prayer Requests Feed - Carousel with Header
                      Obx(() {
                        final prayers = controller.prayers.take(50).toList(); // Show more prayers in carousel
                        if (prayers.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Header with View All
                            Padding(
                              padding: ResponsiveHelper.padding(
                                context,
                                horizontal: ResponsiveHelper.isMobile(context) ? 16 : 20,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: ResponsiveHelper.padding(context, all: 6),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.red[400]!,
                                              Colors.red[600]!,
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
                                        ),
                                        child: Icon(
                                          Icons.favorite_rounded,
                                          color: Colors.white,
                                          size: ResponsiveHelper.iconSize(context, mobile: 18),
                                        ),
                                      ),
                                      SizedBox(width: ResponsiveHelper.spacing(context, 10)),
                                      Text(
                                        'Prayer Requests',
                                        style: ResponsiveHelper.textStyle(
                                          context,
                                          fontSize: ResponsiveHelper.fontSize(context, mobile: 18, tablet: 20, desktop: 22),
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      try {
                                        final prayersController = Get.find<PrayersController>();
                                        prayersController.filterUserId.value = 0;
                                        // Performance: Only refresh if needed
                                        if (prayersController.prayers.isEmpty) {
                                          prayersController.loadPrayers(refresh: true);
                                        }
                                      } catch (e) {
                                        Get.put(PrayersController());
                                      }
                                      Get.toNamed(Routes.PRAYER_REQUESTS);
                                    },
                                    child: Text(
                                      'View All',
                                      style: ResponsiveHelper.textStyle(
                                        context,
                                        fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                                        color: Colors.black,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: ResponsiveHelper.spacing(context, 8)),
                            // Prayer Requests Carousel
                            _buildPrayerRequestsCarousel(context, prayers),
                          ],
                        );
                      }),
                      SizedBox(height: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 10 : 12)),
                      // Connect. Pray. Share. Grow Spiritually. Section with Go Live button (Priority: Inspiration)
                      Padding(
                        padding: ResponsiveHelper.padding(
                          context,
                          horizontal: ResponsiveHelper.isMobile(context) ? 16 : 20,
                        ),
                        child: Container(
                          padding: ResponsiveHelper.padding(
                            context,
                            all: ResponsiveHelper.isMobile(context) ? 16 : 20,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white,
                                const Color(0xFFFAF6EC).withOpacity(0.3),
                                Colors.white,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 20)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                spreadRadius: 0,
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Connect. Pray. Share. Grow Spiritually.',
                                      style: ResponsiveHelper.textStyle(
                                        context,
                                        fontSize: ResponsiveHelper.fontSize(context, mobile: 18, tablet: 20, desktop: 22),
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                        letterSpacing: 0.3,
                                        height: 1.3,
                                      ),
                                    ),
                                    SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                                        onTap: () {
                                          Get.toNamed(Routes.LIVE);
                                        },
                                        child: Container(
                                          padding: ResponsiveHelper.padding(
                                            context,
                                            horizontal: ResponsiveHelper.isMobile(context) ? 20 : 24,
                                            vertical: ResponsiveHelper.isMobile(context) ? 12 : 14,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                Color(0xFF4CAF50),
                                                Color(0xFF45A049),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Color(0xFF4CAF50).withOpacity(0.3),
                                                spreadRadius: 0,
                                                blurRadius: 8,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.videocam_rounded,
                                                color: Colors.white,
                                                size: ResponsiveHelper.iconSize(context, mobile: 20),
                                              ),
                                              SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                                              Text(
                                                'Go Live',
                                                style: ResponsiveHelper.textStyle(
                                                  context,
                                                  fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: ResponsiveHelper.spacing(context, 16)),
                              // Dove Image
                              CachedImage(
                                imageUrl: 'https://fruitofthespirit.templateforwebsites.com/uploads/images/dove.png',
                                height: ResponsiveHelper.imageHeight(context, mobile: 110, tablet: 130, desktop: 150),
                                width: ResponsiveHelper.imageWidth(context, mobile: 110, tablet: 130, desktop: 150),
                                fit: BoxFit.contain,
                                errorWidget: Icon(
                                  Icons.air,
                                  size: ResponsiveHelper.iconSize(context, mobile: 50, tablet: 60, desktop: 70),
                                  color: const Color(0xFF8B4513),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 16 : 20)),
                      // Videos Feed - Combined Live and Regular Videos
                      Obx(() {
                        // Combine live videos and regular videos
                        final liveVideos = controller.liveVideos.toList();
                        final regularVideos = controller.videos.toList();

                        // Combine: Live videos first, then regular videos
                        final allVideos = <Map<String, dynamic>>[];
                        allVideos.addAll(liveVideos);
                        allVideos.addAll(regularVideos);

                        if (allVideos.isEmpty) return const SizedBox.shrink();

                        // Take first 15 videos (live + regular)
                        final videosToShow = allVideos.take(15).toList();
                        return _buildVideosReelsCarousel(context, videosToShow);
                      }),
                      SizedBox(height: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 16 : 20)),
                      // Blogs Carousel Section (Last)
                      Obx(() {
                        final blogs = controller.blogs.take(5).toList();
                        if (blogs.isEmpty) return const SizedBox.shrink();
                        return _buildBlogsCarousel(context, blogs);
                      }),
                    ],
                  ),
                ),
              ),
            ),
          );

      }),
      // bottomNavigationBar: const AppBottomNavigationBar(currentIndex: 0),
      ),
    )]);


  }


  Widget _buildFruitItem(BuildContext context, String imagePath, String label) {
    // Convert asset path to network URL
    final networkUrl = ImageConfig.assetPathToNetworkUrl(imagePath);

    return Column(
      children: [
        CachedImage(
          imageUrl: networkUrl,
          height: ResponsiveHelper.imageHeight(context, mobile: 30),
          fit: BoxFit.contain,
          errorWidget: Icon(
            Icons.image,
            size: ResponsiveHelper.iconSize(context, mobile: 30),
            color: Colors.grey,
          ),
        ),
        SizedBox(height: ResponsiveHelper.spacing(context, 5)),
        Text(
          label,
          style: ResponsiveHelper.textStyle(
            context,
            fontSize: ResponsiveHelper.isMobile(context) ? 14 : 16,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  /// Build emoji display widget - ONLY shows fruit images from uploads/images/128-128 or 256-256
  /// NO emoji characters/smiley faces - only fruit images
  static Widget buildEmojiDisplay(BuildContext context, Map<String, dynamic> emoji, {double? size}) {
    final emojiChar = emoji['emoji_char'] as String? ?? '';
    final emojiName = (emoji['name'] as String? ?? '').toLowerCase();
    
    // Use provided size or default emoji size
    final imageSize = size ?? ResponsiveHelper.imageHeight(context, mobile: 40, tablet: 45, desktop: 50);
    
    String? fullImageUrl;
    
    // Priority 1: Use database image_url FIRST (most reliable source)
    // This is the direct path from database and should be used if available
    final imageUrl = emoji['image_url'] as String?;
    if (imageUrl != null && imageUrl.toString().trim().isNotEmpty) {
      fullImageUrl = imageUrl.toString().trim();
      
      // If it's a relative path (starts with uploads/), convert to full URL
      if (fullImageUrl.startsWith('uploads/')) {
        fullImageUrl = 'https://fruitofthespirit.templateforwebsites.com/$fullImageUrl';
      } else if (!fullImageUrl.startsWith('http://') && !fullImageUrl.startsWith('https://')) {
        fullImageUrl = 'https://fruitofthespirit.templateforwebsites.com/uploads/$fullImageUrl';
      }
      print('✅ buildEmojiDisplay: Using database image_url (Priority 1): $fullImageUrl');
    }
    
    // Priority 2: Try to get fruit image from emoji character using new fruit reaction images
    // This works for actual emoji characters like 😊, ☮️, etc. (only if database image_url is not available)
    if (fullImageUrl == null && emojiChar.isNotEmpty) {
      // Check if emojiChar is an actual emoji character or a text string
      // Text strings like "goodness", "kindness" are longer and contain only letters
      final isTextString = emojiChar.length > 3 || 
          (emojiChar.length > 1 && RegExp(r'^[a-zA-Z\s]+$').hasMatch(emojiChar));
      
      if (isTextString) {
        // It's a text string like "goodness", "kindness", etc. - use name-based lookup first
        fullImageUrl = ImageConfig.getFruitReactionImageUrlByName(emojiChar, size: imageSize, variant: 1);
        if (fullImageUrl != null) {
          print('✅ buildEmojiDisplay: Found fruit reaction image from emoji_char (text): $emojiChar -> $fullImageUrl');
        }
      } else {
        // It's likely an actual emoji character - try emoji-based lookup
        fullImageUrl = ImageConfig.getFruitReactionImageUrl(emojiChar, size: imageSize, variant: 1);
        if (fullImageUrl != null) {
          print('✅ buildEmojiDisplay: Found fruit reaction image from emoji: $emojiChar -> $fullImageUrl');
        } else {
          // If emoji lookup failed, try name-based as fallback
          fullImageUrl = ImageConfig.getFruitReactionImageUrlByName(emojiChar, size: imageSize, variant: 1);
          if (fullImageUrl != null) {
            print('✅ buildEmojiDisplay: Found fruit reaction image from emoji_char (fallback): $emojiChar -> $fullImageUrl');
          }
        }
      }
    }
    
    // Priority 3: Try to get from fruit name if emoji character didn't work
    if (fullImageUrl == null && emojiName.isNotEmpty) {
      // Extract base fruit name from emoji name (e.g., "Emoji: goodness" -> "goodness")
      String baseFruitName = emojiName;
      if (emojiName.contains(':')) {
        final parts = emojiName.split(':');
        if (parts.length > 1) {
          baseFruitName = parts[1].trim();
        }
      }
      // Also extract first word if name has multiple words (e.g., "Goodness Banana 1" -> "goodness")
      if (baseFruitName.contains(' ')) {
        baseFruitName = baseFruitName.split(' ')[0].trim();
      }
      
      fullImageUrl = ImageConfig.getFruitReactionImageUrlByName(baseFruitName, size: imageSize, variant: 1);
      if (fullImageUrl != null) {
        print('✅ buildEmojiDisplay: Found fruit reaction image from name: $baseFruitName -> $fullImageUrl');
      }
    }
    
    // If we have an image URL, show it (NO emoji character fallback)
    if (fullImageUrl != null && fullImageUrl.isNotEmpty) {
      // Replace spaces with %20 for URL encoding
      fullImageUrl = fullImageUrl.replaceAll(' ', '%20');
      
      return CachedImage(
        imageUrl: fullImageUrl,
        height: size == null ? null : imageSize,
        width: size == null ? null : imageSize,
        fit: BoxFit.contain,
        errorWidget: _buildPlaceholderIcon(context, imageSize),
      );
    }
    
    // Last resort: Show placeholder icon (NO emoji characters)
    return _buildPlaceholderIcon(context, imageSize);
  }
  
  /// Build placeholder icon (replaces emoji character fallback)
  /// NO emoji characters shown - only icons or fruit images
  static Widget _buildPlaceholderIcon(BuildContext context, double size) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.sentiment_satisfied,
        size: size * 0.6,
        color: Colors.grey[400],
      ),
    );
  }

  Widget _buildVideoThumbnail(String videoUrl) {
    return _VideoPlayerThumbnail(videoUrl: videoUrl);
  }

  // Get video thumbnail URL from video data
  String? _getVideoThumbnail(Map<String, dynamic> video) {
    // Priority 1: Check thumbnail_path (from database - generated during upload)
    if (video['thumbnail_path'] != null && (video['thumbnail_path'] as String).isNotEmpty) {
      final thumbnailPath = video['thumbnail_path'] as String;
      if (!thumbnailPath.startsWith('http')) {
        return 'https://fruitofthespirit.templateforwebsites.com/$thumbnailPath';
      }
      return thumbnailPath;
    }
    
    // Priority 2: Check thumbnail (legacy field)
    if (video['thumbnail'] != null && (video['thumbnail'] as String).isNotEmpty) {
      final thumbnail = video['thumbnail'] as String;
      if (!thumbnail.startsWith('http')) {
        return 'https://fruitofthespirit.templateforwebsites.com/$thumbnail';
      }

      return thumbnail;
    }
    
    // Priority 3: Check if file_path is an image (not a video)
    if (video['file_path'] != null) {
      final filePath = video['file_path'].toString();
      final lowerPath = filePath.toLowerCase();
      if (!lowerPath.endsWith('.mp4') &&
          !lowerPath.endsWith('.mov') &&
          !lowerPath.endsWith('.avi') &&
          !lowerPath.endsWith('.webm') &&
          !lowerPath.endsWith('.mkv')) {
        if (!filePath.startsWith('http')) {
          return 'https://fruitofthespirit.templateforwebsites.com/$filePath';
        }

        return filePath;
      }
    }
    
    // Last resort: Return null to use video frame extraction
    return null;
  }

  // Get video URL from video data
  String? _getVideoUrl(Map<String, dynamic> video) {
    if (video['file_path'] != null) {
      final filePath = video['file_path'].toString();
      if (filePath.isNotEmpty) {
        final lowerPath = filePath.toLowerCase();
        // Check if it's a video file
        if (lowerPath.endsWith('.mp4') ||
            lowerPath.endsWith('.mov') ||
            lowerPath.endsWith('.avi') ||
            lowerPath.endsWith('.webm') ||
            lowerPath.endsWith('.mkv')) {
          if (filePath.startsWith('http')) {
            return filePath;
          }

          return 'https://fruitofthespirit.templateforwebsites.com/$filePath';
        }
      }
    }
    return null;
  }

  // Build Fruit Card (for 9 Fruits Grid) - With specific colors per fruit
  Widget _buildFruitCard(BuildContext context, Map<String, dynamic> fruit, int index) {
    final fruitName = fruit['name'] ?? 'Fruit';
    final fruitImageUrl = ImageConfig.getFruitImageUrl(fruitName);

    // Get attractive gradient colors for each fruit
    List<Color> getFruitGradient(String name) {
      final lowerName = name.toLowerCase();
      if (lowerName.contains('love')) return [Color(0xFFFFE5E5), Color(0xFFFFF0F0)]; // Light pink gradient
      if (lowerName.contains('joy')) return [Color(0xFFFFF9C4), Color(0xFFFFFDE7)]; // Light yellow gradient
      if (lowerName.contains('peace')) return [Color(0xFFE8F5E9), Color(0xFFF1F8E9)]; // Light green gradient
      if (lowerName.contains('patience')) return [Color(0xFFFFF3E0), Color(0xFFFFF8E1)]; // Light orange gradient
      if (lowerName.contains('kindness')) return [Color(0xFFFFE0B2), Color(0xFFFFECB3)]; // Light orange-yellow gradient
      if (lowerName.contains('goodness')) return [Color(0xFFE1F5FE), Color(0xFFE0F2F1)]; // Light blue-green gradient
      if (lowerName.contains('faithfulness')) return [Color(0xFFFFCDD2), Color(0xFFFFE0E6)]; // Light red-pink gradient
      if (lowerName.contains('gentleness') || lowerName.contains('meekness')) return [Color(0xFFE1BEE7), Color(0xFFF3E5F5)]; // Light purple gradient
      if (lowerName.contains('self') && lowerName.contains('control')) return [Color(0xFFC8E6C9), Color(0xFFDCEDC8)]; // Light green gradient
      return [Color(0xFFFEECE2), Color(0xFFFFF5F5)]; // Default light peach gradient
    }

    final gradientColors = getFruitGradient(fruitName);

    return GestureDetector(
      onTap: () {

        // Reload user feeling when coming back from fruits screen
        Get.toNamed(Routes.FRUITS)?.then((_) {
          // Refresh user feeling when returning from fruits screen
          controller.loadUserFeeling();
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
          border: Border.all(
            color: const Color(0xFF5F4628).withOpacity(0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              spreadRadius: 0,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
            onTap: () {
              // Reload user feeling when coming back from fruits screen
              Get.toNamed(Routes.FRUITS)?.then((_) {
                // Refresh user feeling when returning from fruits screen
                controller.loadUserFeeling();
              });
            },
            child: Padding(
              padding: ResponsiveHelper.padding(
                context, 
                horizontal: ResponsiveHelper.isMobile(context) ? 4 : 6,
                vertical: ResponsiveHelper.isMobile(context) ? 6 : 8,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Fruit Image - Bigger
                  CachedImage(
                    imageUrl: fruitImageUrl,
                    height: ResponsiveHelper.imageHeight(context, mobile: 70, tablet: 85, desktop: 100),
                    width: ResponsiveHelper.imageWidth(context, mobile: 70, tablet: 85, desktop: 100),
                    fit: BoxFit.contain,
                    errorWidget: Icon(
                      Icons.favorite,
                      size: ResponsiveHelper.iconSize(context, mobile: 40, tablet: 50, desktop: 60),
                      color: const Color(0xFF8B4513),
                    ),
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(context, 4)),
                  // Fruit Name - Smaller
                  Text(
                    fruitName,
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: ResponsiveHelper.fontSize(context, mobile: 11, tablet: 12, desktop: 13),
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      letterSpacing: 0.2,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(context, 2)),
                  // Active users badge - Smaller
                  Container(
                    padding: ResponsiveHelper.padding(context, horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5F4628).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 6)),
                    ),
                    child: Text(
                      '${fruit['active_users'] ?? 0}',
              style: ResponsiveHelper.textStyle(
                context,
                        fontSize: ResponsiveHelper.fontSize(context, mobile: 10, tablet: 11, desktop: 12),
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Build Social Media Style Prayer Post (Image-like Design)
  Widget _buildSocialMediaPrayerPost(BuildContext context, Map<String, dynamic> prayer) {
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
    final createdAt = prayer['created_at'] as String?;
    final responseCount = int.tryParse((prayer['response_count'] ?? 0).toString()) ?? 0;
    final commentCount = int.tryParse((prayer['comment_count'] ?? 0).toString()) ?? 0;
    // Get prayer type - check multiple fields
    final category = prayer['category'] as String? ?? prayer['type'] as String? ?? prayer['prayer_type'] as String? ?? 'Prayer Request';
    final prayerFor = prayer['prayer_for'] as String? ?? 'Me';
    // Show prayer type as subtitle
    final subtitle = category;

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
            // Header - Profile + Name + Subtitle + Three-dot menu (Exact match)
            Padding(
              padding: ResponsiveHelper.padding(
                context,
                all: ResponsiveHelper.isMobile(context) ? 14 : 16,
              ),
              child: Row(
                children: [
                  // Profile Picture - Responsive size with CachedImage
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
                          color: Colors.grey[600],
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
                      color: isAnonymous ? Colors.grey[600] :  Colors.white,
                    ),
                  ),
                  SizedBox(width: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 10 : 12)),
                  // Name and Subtitle - Responsive
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
                          subtitle,
                          style: ResponsiveHelper.textStyle(
                            context,
                            fontSize: ResponsiveHelper.fontSize(context, mobile: 11, tablet: 12, desktop: 13),
                            color: Colors.grey[600],
                            fontWeight: FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                  // Three-dot menu - Responsive with Report option
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      size: ResponsiveHelper.iconSize(context, mobile: 20, tablet: 22, desktop: 24),
                      color: AppTheme.iconscolor,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onSelected: (value) {
                      if (value == 'view') {
                        Get.toNamed(Routes.PRAYER_DETAILS, arguments: prayer['id']);
                      } else if (value == 'share') {
                        // Share functionality can be added here
                        Get.snackbar(
                          'Info',
                          'Share feature coming soon',
                          backgroundColor: Colors.blue,
                          colorText: Colors.white,
                        );
                      }
                    },
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'view',
                        child: Row(
                          children: [
                            Icon(Icons.visibility, size: 18, color: AppTheme.iconscolor),
                            SizedBox(width: 8),
                            Text('View Details'),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'share',
                        child: Row(
                          children: [
                            Icon(Icons.share, size: 18, color: AppTheme.iconscolor),
                            SizedBox(width: 8),
                            Text('Share'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Content - Truncated text with ellipsis (Responsive)
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
                  fontSize: ResponsiveHelper.fontSize(context, mobile: 13, tablet: 14, desktop: 15),
                  color: Colors.black,
                  fontWeight: FontWeight.normal,
                ).copyWith(height: 1.4),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 10 : 12)),
            // Bottom Actions - Left: Prayed count, Right: Comments count (Responsive)
            Padding(
              padding: ResponsiveHelper.padding(
                context,
                horizontal: ResponsiveHelper.isMobile(context) ? 14 : 16,
                vertical: ResponsiveHelper.isMobile(context) ? 6 : 8,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left: Prayed count with icon - Only show if > 0
                  if (responseCount > 0)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.favorite,
                          size: 18,
                          color: AppTheme.iconscolor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$responseCount prayed',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.iconscolor,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  // Right: Comments count with icon - Only show if > 0
                  if (commentCount > 0)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.comment_outlined,
                          size: 18,
                          color: AppTheme.iconscolor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$commentCount Comments',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.normal,
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

  // Build Social Media Style Blog Post - Exact like Prayer Request
  Widget _buildSocialMediaBlogPost(BuildContext context, Map<String, dynamic> blog) {
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

    return InkWell(
      onTap: () {
        // Scroll to top smoothly before navigating
        controller.scrollToTop();
        // Small delay to allow scroll animation to start
        Future.delayed(const Duration(milliseconds: 100), () {
          Get.toNamed(Routes.BLOG_DETAILS, arguments: blog['id']);
        });
      },
      borderRadius: BorderRadius.zero,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: ResponsiveHelper.isMobile(context) 
              ? ResponsiveHelper.screenHeight(context) * 0.20  // Increased from 0.16 to accommodate spacing
              : ResponsiveHelper.isTablet(context)
                  ? ResponsiveHelper.screenHeight(context) * 0.22  // Increased from 0.18
                  : ResponsiveHelper.screenHeight(context) * 0.24,  // Increased from 0.20
        ),
        margin: ResponsiveHelper.safeMargin(
          context,
          horizontal: 0,
          vertical: ResponsiveHelper.isMobile(context) ? 2 : 3,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.zero,
          border: Border.all(
            color: Colors.grey[200]!.withOpacity(0.3),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              spreadRadius: 0,
              blurRadius: 8,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: ClipRect(
          clipBehavior: Clip.hardEdge,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // Content with proper constraints - With spacing
              Expanded(
                child: ClipRect(
                  clipBehavior: Clip.hardEdge,
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
            // User Name Section - With proper spacing
            Padding(
              padding: EdgeInsets.fromLTRB(
                ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 10 : 12),
                ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 8 : 10),
                ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 10 : 12),
                ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 8 : 10), // Increased bottom padding for spacing before image
              ),
              child: Row(
                children: [
                  // Profile Picture - Same size for all (consistent avatar)
                  CircleAvatar(
                    radius: ResponsiveHelper.isMobile(context) ? 12 : ResponsiveHelper.isTablet(context) ? 14 : 16,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: profilePhoto != null && profilePhoto.isNotEmpty && !profilePhoto.startsWith('assets/')
                        ? NetworkImage(profilePhoto.startsWith('http') ? profilePhoto : baseUrl + profilePhoto)
                        : null,
                    child: profilePhoto == null || profilePhoto.isEmpty || profilePhoto.startsWith('assets/')
                        ? Icon(
                            Icons.person_rounded,
                            size: ResponsiveHelper.isMobile(context) ? 12 : ResponsiveHelper.isTablet(context) ? 14 : 16,
                            color: const Color(0xFF5F4628),
                          )
                        : null,
                  ),
                  SizedBox(width: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 4 : 6)),
                  // Name only (no timestamp to save space)
                  Expanded(
                    child: Text(
                      author,
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: ResponsiveHelper.fontSize(context, mobile: 11, tablet: 12, desktop: 13),
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
            // Gap between profile picture and blog photo - More spacing
            if (imageUrl != null && imageUrl.isNotEmpty) 
              SizedBox(height: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 8 : 10)),
            // Photo at Top (if available) - Compact height
            if (imageUrl != null && imageUrl.isNotEmpty) ...[
              AspectRatio(
                aspectRatio: ResponsiveHelper.isMobile(context) ? 2.0 : 1.9, // Wider aspect ratio = shorter height
                child: ClipRRect(
                  borderRadius: BorderRadius.zero,
                  child: CachedImage(
                    imageUrl: imageUrl,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    errorWidget: Container(
                      width: double.infinity,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFFFAF6EC),
                            const Color(0xFF9F9467).withOpacity(0.3),
                          ],
                        ),
                      ),
                      child: Icon(
                        Icons.article_rounded,
                        size: ResponsiveHelper.iconSize(context, mobile: 18, tablet: 22, desktop: 26),
                        color: const Color(0xFF9F9467),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            // Text/Blog Content - With proper spacing
            Padding(
              padding: EdgeInsets.fromLTRB(
                ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 10 : 12),
                ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 10 : 12), // Increased top padding for spacing after image
                ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 10 : 12),
                ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 6 : 8), // Bottom padding for spacing before actions
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: ResponsiveHelper.fontSize(context, mobile: 10, tablet: 11, desktop: 12),
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ).copyWith(height: ResponsiveHelper.isMobile(context) ? 1.0 : 1.1),
                    maxLines: ResponsiveHelper.isMobile(context) ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!ResponsiveHelper.isMobile(context)) // Only show content on tablet/desktop
                    SizedBox(height: ResponsiveHelper.spacing(context, 1)),
                  if (!ResponsiveHelper.isMobile(context))
                    Text(
                      AutoTranslateHelper.getTranslatedTextSync(
                        text: blog['content'] ?? blog['description'] ?? '',
                        sourceLanguage: blog['language'] as String?,
                      ),
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: ResponsiveHelper.fontSize(context, mobile: 10, tablet: 11, desktop: 12),
                        color: Colors.black,
                      ).copyWith(height: 1.1),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            // Bottom Actions - Likes and Comments with real counts
            Padding(
              padding: EdgeInsets.fromLTRB(
                ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 10 : 12),
                ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 6 : 8), // Top padding for spacing after content
                ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 10 : 12),
                ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 6 : 8), // Bottom padding
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left: Likes count with like icon (same as clickable icon)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.favorite_border_rounded,
                        size: ResponsiveHelper.iconSize(context, mobile: 12, tablet: 13, desktop: 14),
                        color: AppTheme.iconscolor,
                      ),
                      SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                      Text(
                        '$likeCount',
                        style: ResponsiveHelper.textStyle(
                          context,
                          fontSize: ResponsiveHelper.fontSize(context, mobile: 11, tablet: 12, desktop: 13),
                          color: AppTheme.iconscolor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  // Right: Comments count with icon
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.comment_outlined,
                        size: ResponsiveHelper.iconSize(context, mobile: 12, tablet: 13, desktop: 14),
                        color: AppTheme.iconscolor,
                      ),
                      SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                      Text(
                        '$commentCount',
                        style: ResponsiveHelper.textStyle(
                          context,
                          fontSize: ResponsiveHelper.fontSize(context, mobile: 11, tablet: 12, desktop: 13),
                          color: Colors.grey[600],
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build Social Media Style Video Post
  Widget _buildSocialMediaVideoPost(BuildContext context, Map<String, dynamic> video) {
    // Use helper function to get thumbnail
    String? imageUrl = _getVideoThumbnail(video);
    String? videoUrl = _getVideoUrl(video);
    final title = video['title'] ?? 'Video';
    final createdAt = video['created_at'] as String?;
    final thumbnailHeight = ResponsiveHelper.imageHeight(context, mobile: 220, tablet: 280, desktop: 320);

    return Container(
      margin: EdgeInsets.only(
        bottom: ResponsiveHelper.spacing(context, 20),
        left: ResponsiveHelper.spacing(context, 16),
        right: ResponsiveHelper.spacing(context, 16),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            spreadRadius: 0,
            blurRadius: 25,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: const Color(0xFF5F4628).withOpacity(0.03),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Video Thumbnail
          GestureDetector(
            onTap: () => Get.toNamed(Routes.VIDEO_DETAILS, arguments: video['id']),
            child: Stack(
              children: [
                imageUrl != null
                    ? CachedImage(
                        imageUrl: imageUrl!,
                        height: thumbnailHeight,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorWidget: videoUrl != null
                            ? VideoFrameThumbnail(
                                videoUrl: videoUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: thumbnailHeight,
                              )
                            : Container(
                                height: thumbnailHeight,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      AppTheme.themeColor,
                                      AppTheme.primaryColor.withOpacity(0.3),
                                    ],
                                  ),
                                ),
                                child: Icon(
                                  Icons.video_library_rounded,
                                  size: ResponsiveHelper.iconSize(context, mobile: 50, tablet: 60, desktop: 70),
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                      )
                    : videoUrl != null
                        ? VideoFrameThumbnail(
                            videoUrl: videoUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: thumbnailHeight,
                          )
                        : Container(
                            height: thumbnailHeight,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppTheme.themeColor,
                                  AppTheme.primaryColor.withOpacity(0.3),
                                ],
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.video_library_rounded,
                                size: ResponsiveHelper.iconSize(context, mobile: 50, tablet: 60, desktop: 70),
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                Positioned.fill(
                  child: Center(
                    child: Container(
                      padding: ResponsiveHelper.padding(context, all: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.play_circle_fill,
                        color: const Color(0xFF4CAF50),
                        size: ResponsiveHelper.iconSize(context, mobile: 50, tablet: 60, desktop: 70),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Title, Author and Time
          Padding(
            padding: ResponsiveHelper.padding(context, all: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: ResponsiveHelper.textStyle(context, fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                ),
                if (video['user_name'] != null && (video['user_name'] as String).isNotEmpty)
                  Padding(
                    padding: ResponsiveHelper.padding(context, top: 6),
                    child: Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: ResponsiveHelper.iconSize(context, mobile: 14),
                          color: Colors.grey[600],
                        ),
                        SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                        Text(
                          video['user_name'] as String,
                          style: ResponsiveHelper.textStyle(context, fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                if (createdAt != null)
                  Padding(
                    padding: ResponsiveHelper.padding(context, top: 4),
                    child: Text(
                      _getTimeAgo(createdAt),
                      style: ResponsiveHelper.textStyle(context, fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
              ],
            ),
          ),
          // Actions - Modern Design
          Container(
            margin: ResponsiveHelper.padding(context, horizontal: 18, vertical: 8),
            padding: ResponsiveHelper.padding(context, horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => Get.toNamed(Routes.VIDEO_DETAILS, arguments: video['id']),
                    borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
                    child: Container(
                      padding: ResponsiveHelper.padding(context, horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.favorite_border_rounded, size: ResponsiveHelper.iconSize(context, mobile: 22), color: AppTheme.iconscolor),
                          SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                          Flexible(
                            child: Text(
                            'Like',
                            style: ResponsiveHelper.textStyle(context, fontSize: 14, color: AppTheme.iconscolor, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                Expanded(
                  child: InkWell(
                    onTap: () => Get.toNamed(Routes.VIDEO_DETAILS, arguments: video['id']),
                    borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
                    child: Container(
                      padding: ResponsiveHelper.padding(context, horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5F4628).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.comment_outlined, size: ResponsiveHelper.iconSize(context, mobile: 22), color: AppTheme.iconscolor),
                          SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                          Flexible(
                            child: Text(
                            'Comment',
                            style: ResponsiveHelper.textStyle(context, fontSize: 14, color: AppTheme.iconscolor, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                InkWell(
                  onTap: () => Get.toNamed(Routes.VIDEO_DETAILS, arguments: video['id']),
                  borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
                  child: Container(
                    padding: ResponsiveHelper.padding(context, all: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
                    ),
                    child: Icon(Icons.share_rounded, size: ResponsiveHelper.iconSize(context, mobile: 22), color: AppTheme.iconscolor),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: ResponsiveHelper.spacing(context, 4)),
        ],
      ),
    );
  }

  // Build Social Media Style Story Post
  Widget _buildSocialMediaStoryPost(BuildContext context, Map<String, dynamic> story) {
    final imageUrl = story['file_path'] != null
        ? 'https://fruitofthespirit.templateforwebsites.com/${story['file_path']}'
        : null;
    final title = story['title'] ?? story['fruit_tag'] ?? 'Story';
    final createdAt = story['created_at'] as String?;

    return Container(
      margin: EdgeInsets.only(
        bottom: ResponsiveHelper.spacing(context, 20),
        left: ResponsiveHelper.spacing(context, 16),
        right: ResponsiveHelper.spacing(context, 16),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            spreadRadius: 0,
            blurRadius: 25,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: const Color(0xFF5F4628).withOpacity(0.03),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          if (imageUrl != null)
            GestureDetector(
              onTap: () {
                if (story['id'] != null) {
                  Get.toNamed(Routes.STORY_DETAILS, arguments: story['id']);
                } else {
                  Get.toNamed(Routes.GALLERY);
                }
              },
              child: CachedImage(
                imageUrl: imageUrl,
                height: ResponsiveHelper.imageHeight(context, mobile: 300, tablet: 350, desktop: 400),
                width: double.infinity,
                fit: BoxFit.cover,
                errorWidget: Container(
                  height: ResponsiveHelper.imageHeight(context, mobile: 300, tablet: 350, desktop: 400),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [const Color(0xFFE3F2FD), const Color(0xFFBBDEFB)],
                    ),
                  ),
                  child: Icon(Icons.image, size: ResponsiveHelper.iconSize(context, mobile: 60), color: Colors.grey[600]),
                ),
              ),
            ),
          // Title and Time
          Padding(
            padding: ResponsiveHelper.padding(context, all: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: ResponsiveHelper.textStyle(context, fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                ),
                if (createdAt != null)
                  Padding(
                    padding: ResponsiveHelper.padding(context, top: 4),
                    child: Text(
                      _getTimeAgo(createdAt),
                      style: ResponsiveHelper.textStyle(context, fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
              ],
            ),
          ),
          // Actions - Modern Design
          Container(
            margin: ResponsiveHelper.padding(context, horizontal: 18, vertical: 8),
            padding: ResponsiveHelper.padding(context, horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      if (story['id'] != null) {
                        Get.toNamed(Routes.STORY_DETAILS, arguments: story['id']);
                      } else {
                        Get.toNamed(Routes.GALLERY);
                      }
                    },
                    borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
                    child: Container(
                      padding: ResponsiveHelper.padding(context, horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.favorite_border_rounded, size: ResponsiveHelper.iconSize(context, mobile: 22), color: Colors.red[700]),
                          SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                          Text(
                            'Like',
                            style: ResponsiveHelper.textStyle(context, fontSize: 14, color: Colors.red[700], fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      if (story['id'] != null) {
                        Get.toNamed(Routes.STORY_DETAILS, arguments: story['id']);
                      } else {
                        Get.toNamed(Routes.GALLERY);
                      }
                    },
                    borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
                    child: Container(
                      padding: ResponsiveHelper.padding(context, horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5F4628).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.comment_outlined, size: ResponsiveHelper.iconSize(context, mobile: 22), color: const Color(0xFF5F4628)),
                          SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                          Text(
                            'Comment',
                            style: ResponsiveHelper.textStyle(context, fontSize: 14, color: Colors.black, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                InkWell(
                  onTap: () {
                    if (story['id'] != null) {
                      Get.toNamed(Routes.STORY_DETAILS, arguments: story['id']);
                    } else {
                      Get.toNamed(Routes.GALLERY);
                    }
                  },
                  borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
                  child: Container(
                    padding: ResponsiveHelper.padding(context, all: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
                    ),
                    child: Icon(Icons.share_rounded, size: ResponsiveHelper.iconSize(context, mobile: 22), color: AppTheme.iconscolor),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: ResponsiveHelper.spacing(context, 4)),
        ],
      ),
    );
  }

  // Build Prayers Carousel
  Widget _buildPrayersCarousel(BuildContext context, List<Map<String, dynamic>> prayers) {
    return _PrayersCarouselWidget(prayers: prayers, buildPrayerPost: _buildSocialMediaPrayerPost);
  }

  // Build Prayer Requests Carousel with Scroll Indicators
  Widget _buildPrayerRequestsCarousel(BuildContext context, List<Map<String, dynamic>> prayers) {
    return Column(
      children: [
        // Prayer Carousel
        SizedBox(
          height: ResponsiveHelper.safeHeight(
            context,
            mobile: ResponsiveHelper.screenHeight(context) * 0.26,
            tablet: ResponsiveHelper.screenHeight(context) * 0.28,
            desktop: ResponsiveHelper.screenHeight(context) * 0.30,
          ),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 14 : 16),
              vertical: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 6 : 8),
            ),
            itemCount: prayers.length,
            itemBuilder: (context, index) {
              final prayer = prayers[index];
              return Container(
                width: ResponsiveHelper.screenWidth(context) * 0.85,
                margin: EdgeInsets.only(
                  right: ResponsiveHelper.spacing(context, 12),
                ),
                child: _buildSocialMediaPrayerPost(context, prayer),
              );
            },
          ),
        ),
        // Scroll Indicator Text
        SizedBox(height: ResponsiveHelper.spacing(context, 8)),
        Text(
          '← Swipe to see more prayer requests →',
          style: TextStyle(
            fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // Build Blogs Carousel
  Widget _buildBlogsCarousel(BuildContext context, List<Map<String, dynamic>> blogs) {
    return _BlogsCarouselWidget(blogs: blogs, buildBlogPost: _buildSocialMediaBlogPost);
  }

  // Build Videos Carousel - Instagram Style
  Widget _buildVideosCarousel(BuildContext context, List<Map<String, dynamic>> videos) {
    return _VideosCarouselWidget(videos: videos);
  }

  // Build Videos Reels Carousel - Instagram Style (2 full + 10% of 3rd visible, swipeable)
  Widget _buildVideosReelsCarousel(BuildContext context, List<Map<String, dynamic>> videos) {
    if (videos.isEmpty) return const SizedBox.shrink();
    
    // Calculate video width: 2 full videos + 10% of 3rd = 2.1 videos visible
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = ResponsiveHelper.spacing(context, 16) * 2; // Left + Right padding
    final spacingBetween = ResponsiveHelper.spacing(context, 12);
    final availableWidth = screenWidth - horizontalPadding;
    final videoWidth = (availableWidth - spacingBetween) / 2.1; // 2 full + 10% of 3rd
    final videoHeight = videoWidth * 1.4; // Portrait aspect ratio
    
    return Container(
      margin: ResponsiveHelper.padding(context, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Padding(
            padding: ResponsiveHelper.padding(context, horizontal: 16, bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: ResponsiveHelper.padding(context, all: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.video_library_rounded,
                        color: AppTheme.iconscolor,
                        size: ResponsiveHelper.iconSize(context, mobile: 22),
                      ),
                    ),
                    SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                    Text(
                      'Recommended Videos',
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: ResponsiveHelper.fontSize(context, mobile: 20, tablet: 22, desktop: 24),
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => Get.toNamed(Routes.VIDEOS),
                  child: Text(
                    'View All',
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Videos Horizontal Scroll - 2 full + 10% of 3rd visible
          SizedBox(
            height: videoHeight,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: ResponsiveHelper.padding(context, horizontal: 16),
              itemCount: videos.length,
              itemBuilder: (context, index) {
                final video = videos[index];
                return Container(
                  width: videoWidth,
                  margin: EdgeInsets.only(
                    right: index < videos.length - 1 ? spacingBetween : 0,
                  ),
                  child: _buildInstagramVideoCard(context, video, videoWidth, videoHeight),
                );
              },
            ),
          ),
          // Swipe Indicator (if more than 2 videos)
          if (videos.length > 2)
            Padding(
              padding: ResponsiveHelper.padding(context, top: 8),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.swipe_left_alt,
                      size: ResponsiveHelper.iconSize(context, mobile: 16),
                      color: Colors.grey[600],
                    ),
                    SizedBox(width: ResponsiveHelper.spacing(context, 6)),
                    Text(
                      'Swipe to see more videos',
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: ResponsiveHelper.fontSize(context, mobile: 11, tablet: 12, desktop: 13),
                        color: Colors.grey[600],
                      ).copyWith(fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Build Instagram Style Video Card - No Title, Full Image
  Widget _buildInstagramVideoCard(BuildContext context, Map<String, dynamic> video, double width, double height) {
    // Use helper function to get thumbnail
    String? imageUrl = _getVideoThumbnail(video);
    String? videoUrl = _getVideoUrl(video);

    final isLive = video['status'] == 'Live' || video['stream_key'] != null || video['stream_url'] != null;

    return InkWell(
      onTap: () => Get.toNamed(Routes.VIDEO_DETAILS, arguments: video['id']),
      borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16, tablet: 18, desktop: 20)),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16, tablet: 18, desktop: 20)),
          border: Border.all(
            color: Colors.grey.withOpacity(0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16, tablet: 18, desktop: 20)),
          child: Stack(
            fit: StackFit.expand,
            children: [
              imageUrl != null
                  ? CachedImage(
                      imageUrl: imageUrl!,
                      fit: BoxFit.cover,
                      errorWidget: videoUrl != null
                          ? VideoFrameThumbnail(
                              videoUrl: videoUrl,
                              fit: BoxFit.cover,
                              width: width,
                              height: height,
                            )
                          : Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppTheme.themeColor,
                                    AppTheme.primaryColor.withOpacity(0.3),
                                  ],
                                ),
                              ),
                              child: Icon(
                                Icons.video_library_rounded,
                                size: ResponsiveHelper.iconSize(context, mobile: 60, tablet: 70, desktop: 80),
                                color: AppTheme.primaryColor,
                              ),
                            ),
                    )
                  : videoUrl != null
                      ? VideoFrameThumbnail(
                          videoUrl: videoUrl,
                          fit: BoxFit.cover,
                          width: width,
                          height: height,
                        )
                      : Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppTheme.themeColor,
                                AppTheme.primaryColor.withOpacity(0.3),
                              ],
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.video_library_rounded,
                              size: ResponsiveHelper.iconSize(context, mobile: 60, tablet: 70, desktop: 80),
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
              // LIVE Badge - Top Left
              if (isLive)
                Positioned(
                  top: ResponsiveHelper.spacing(context, 10),
                  left: ResponsiveHelper.spacing(context, 10),
                  child: Container(
                    padding: ResponsiveHelper.padding(context, horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.red[600]!,
                          Colors.red[400]!,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 6)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: ResponsiveHelper.spacing(context, 5)),
                        Text(
                          'LIVE',
                          style: ResponsiveHelper.textStyle(
                            context,
                            fontSize: ResponsiveHelper.fontSize(context, mobile: 11, tablet: 12, desktop: 13),
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              // Play Button Overlay - Center (Only for non-live videos)
              if (!isLive)
              Positioned.fill(
                child: Center(
                  child: Container(
                    padding: ResponsiveHelper.padding(context, all: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 15,
                          spreadRadius: 0,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.play_circle_fill,
                      color: const Color(0xFF8B4513),
                      size: ResponsiveHelper.iconSize(context, mobile: 56, tablet: 64, desktop: 72),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build Reel Video Card - Vertical Video Thumbnail - Professional UI (OLD - Keep for reference)
  Widget _buildReelVideoCard(BuildContext context, Map<String, dynamic> video) {
    // Use helper function to get thumbnail
    String? imageUrl = _getVideoThumbnail(video);
    String? videoUrl = _getVideoUrl(video);

    final title = video['title'] ?? 'Video';
    final createdAt = video['created_at'] as String?;
    final isLive = video['status'] == 'Live' || video['stream_key'] != null || video['stream_url'] != null;
    final videoWidth = ResponsiveHelper.imageWidth(context, mobile: 160, tablet: 180, desktop: 200);
    final videoHeight = ResponsiveHelper.imageHeight(context, mobile: 280, tablet: 310, desktop: 350);

    return InkWell(
      onTap: () => Get.toNamed(Routes.VIDEO_DETAILS, arguments: video['id']),
      borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 18, tablet: 20, desktop: 22)),
      child: Container(
        width: videoWidth,
        margin: ResponsiveHelper.padding(context, right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 18, tablet: 20, desktop: 22)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              spreadRadius: 0,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: const Color(0xFF5F4628).withOpacity(0.03),
              blurRadius: 10,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Video Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(ResponsiveHelper.borderRadius(context, mobile: 18, tablet: 20, desktop: 22)),
              ),
              child: Stack(
                children: [
                  imageUrl != null
                      ? CachedImage(
                          imageUrl: imageUrl!,
                          width: videoWidth,
                          height: videoHeight,
                          fit: BoxFit.cover,
                          errorWidget: videoUrl != null
                              ? VideoFrameThumbnail(
                                  videoUrl: videoUrl,
                                  fit: BoxFit.cover,
                                  width: videoWidth,
                                  height: videoHeight,
                                )
                              : Container(
                                  width: videoWidth,
                                  height: videoHeight,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        AppTheme.themeColor,
                                        AppTheme.primaryColor.withOpacity(0.3),
                                      ],
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.video_library_rounded,
                                    size: ResponsiveHelper.iconSize(context, mobile: 50),
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                        )
                      : videoUrl != null
                          ? VideoFrameThumbnail(
                              videoUrl: videoUrl,
                              fit: BoxFit.cover,
                              width: videoWidth,
                              height: videoHeight,
                            )
                          : Container(
                              width: videoWidth,
                              height: videoHeight,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppTheme.themeColor,
                                    AppTheme.primaryColor.withOpacity(0.3),
                                  ],
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.video_library_rounded,
                                  size: ResponsiveHelper.iconSize(context, mobile: 50),
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                  // LIVE Badge - Top Left
                  if (isLive)
                    Positioned(
                      top: ResponsiveHelper.spacing(context, 8),
                      left: ResponsiveHelper.spacing(context, 8),
                      child: Container(
                        padding: ResponsiveHelper.padding(context, horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.red[600]!,
                              Colors.red[400]!,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 4)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                            Text(
                              'LIVE',
                              style: ResponsiveHelper.textStyle(
                                context,
                                fontSize: ResponsiveHelper.fontSize(context, mobile: 10, tablet: 11, desktop: 12),
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Play Button Overlay - Professional Design (Only for non-live videos)
                  if (!isLive)
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        padding: ResponsiveHelper.padding(context, all: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.95),
                              Colors.white.withOpacity(0.9),
                            ],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 12,
                              spreadRadius: 0,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.play_circle_fill,
                          color: const Color(0xFF4CAF50),
                          size: ResponsiveHelper.iconSize(context, mobile: 48, tablet: 52, desktop: 56),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Content Section - Professional Design
            Flexible(
              child: Container(
                padding: EdgeInsets.only(
                  left: ResponsiveHelper.spacing(context, 6),
                  right: ResponsiveHelper.spacing(context, 6),
                  top: ResponsiveHelper.spacing(context, 6),
                  bottom: ResponsiveHelper.spacing(context, 6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    Text(
                      title,
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: ResponsiveHelper.fontSize(context, mobile: 11, tablet: 12, desktop: 13),
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF5F4628),
                        height: 1.15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // User Name
                    if (video['user_name'] != null && (video['user_name'] as String).isNotEmpty) ...[
                      SizedBox(height: ResponsiveHelper.spacing(context, 2)),
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: ResponsiveHelper.iconSize(context, mobile: 10),
                            color: Colors.grey[600],
                          ),
                          SizedBox(width: ResponsiveHelper.spacing(context, 3)),
                          Expanded(
                            child: Text(
                              video['user_name'] as String,
                              style: ResponsiveHelper.textStyle(
                                context,
                                fontSize: ResponsiveHelper.fontSize(context, mobile: 10, tablet: 11, desktop: 12),
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (createdAt != null) ...[
                      SizedBox(height: ResponsiveHelper.spacing(context, 2)),
                      Text(
                        _getTimeAgo(createdAt),
                        style: ResponsiveHelper.textStyle(
                          context,
                          fontSize: ResponsiveHelper.fontSize(context, mobile: 10, tablet: 11, desktop: 12),
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build App Title with Cross Symbol (Fallback when logo not available)
  Widget _buildAppTitle(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);
    final isTablet = ResponsiveHelper.isTablet(context);
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Fruits',
          style: ResponsiveHelper.textStyle(
            context,
            fontSize: isMobile ? 20 : isTablet ? 24 : 28,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF5F4628),
            letterSpacing: isMobile ? 0.5 : 1.0,
          ),
        ),
        SizedBox(
          width: ResponsiveHelper.spacing(
            context,
            isMobile ? 4 : isTablet ? 6 : 8,
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'of',
              style: ResponsiveHelper.textStyle(
                context,
                fontSize: isMobile ? 12 : isTablet ? 14 : 16,
                color: const Color(0xFF5F4628),
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(
              height: ResponsiveHelper.spacing(
                context,
                isMobile ? 2 : isTablet ? 3 : 4,
              ),
            ),
            // Cross Symbol - More responsive
            Container(
              width: ResponsiveHelper.iconSize(
                context,
                mobile: isMobile ? 14 : isTablet ? 18 : 22,
                tablet: 18,
                desktop: 22,
              ),
              height: ResponsiveHelper.iconSize(
                context,
                mobile: isMobile ? 18 : isTablet ? 22 : 26,
                tablet: 22,
                desktop: 26,
              ),
              decoration: BoxDecoration(
                border: Border.all(
                  color: const Color(0xFF5F4628),
                  width: isMobile ? 1.5 : isTablet ? 2 : 2.5,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: isMobile ? 1.5 : isTablet ? 2 : 2.5,
                    height: double.infinity,
                    color: const Color(0xFF5F4628),
                  ),
                  Container(
                    width: double.infinity,
                    height: isMobile ? 1.5 : isTablet ? 2 : 2.5,
                    color: const Color(0xFF5F4628),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: ResponsiveHelper.spacing(
                context,
                isMobile ? 2 : isTablet ? 3 : 4,
              ),
            ),
            Text(
              'the',
              style: ResponsiveHelper.textStyle(
                context,
                fontSize: isMobile ? 12 : isTablet ? 14 : 16,
                color: const Color(0xFF5F4628),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        SizedBox(
          width: ResponsiveHelper.spacing(
            context,
            isMobile ? 4 : isTablet ? 6 : 8,
          ),
        ),
        Text(
          'Spirit',
          style: ResponsiveHelper.textStyle(
            context,
            fontSize: isMobile ? 20 : isTablet ? 24 : 28,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF5F4628),
            letterSpacing: isMobile ? 0.5 : 1.0,
          ),
        ),
      ],
    );
  }

  // Build Stories Carousel
  Widget _buildStoriesCarousel(BuildContext context, List<Map<String, dynamic>> photos) {
    return _StoriesCarouselWidget(photos: photos);
  }

  // OLD: Build Quick Actions Grid - 2x2 Grid Layout (Rectangle buttons) - COMMENTED OUT
  /* Widget _buildQuickActionsGrid(BuildContext context) {
    final quickActions = QuickActionsConfig.getQuickActions();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // 2 columns
        crossAxisSpacing: ResponsiveHelper.spacing(context, 12),
        mainAxisSpacing: ResponsiveHelper.spacing(context, 12),
        childAspectRatio: 1.99, // Rectangle buttons (width:height = 1.5:1)
      ),
      itemCount: quickActions.length,
      itemBuilder: (context, index) {
        return _buildQuickActionButtonWithConfig(context, quickActions[index]);
      },
    );
  } */

  // Build Quick Actions Box with Colored Container (like second image)
  Widget _buildQuickActionsBox(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFFFE5D4), // Light peach/cream background - more visible
        borderRadius: BorderRadius.circular(
          ResponsiveHelper.borderRadius(context, mobile: 20, tablet: 24, desktop: 28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      padding: ResponsiveHelper.padding(
        context,
        horizontal: ResponsiveHelper.isMobile(context) ? 16 : 20,
        vertical: ResponsiveHelper.isMobile(context) ? 18 : 22,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title "Quick Actions"
          /*Padding(
            padding: EdgeInsets.only(
              left: ResponsiveHelper.spacing(context, 4),
            ),
            child: Text(
              'Quick Actions',
              style: ResponsiveHelper.textStyle(
                context,
                fontSize: ResponsiveHelper.fontSize(
                  context,
                  mobile: 18,
                  tablet: 20,
                  desktop: 22,
                ),
                fontWeight: FontWeight.bold,
                color: const Color(0xFF5F4628), // Dark grey/brown text
              ),
            ),
          ),*/
          // SizedBox(height: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 14 : 18)),
          // Quick Actions Grid
          _buildNewQuickActionsGrid(context),
        ],
      ),
    );
  }

  // NEW COMPACT QUICK ACTIONS DESIGN - With Icons/Images and Labels in Row
  Widget _buildNewQuickActionsGrid(BuildContext context) {
    final quickActions = QuickActionsConfig.getQuickActions();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // 2 columns
        crossAxisSpacing: ResponsiveHelper.spacing(context, 12),
        mainAxisSpacing: ResponsiveHelper.spacing(context, 12),
        childAspectRatio: 2.2, // Taller buttons - decreased from 2.8 to 2.2 for more height
      ),
      itemCount: quickActions.length,
      itemBuilder: (context, index) {
        return _buildNewQuickActionButton(context, quickActions[index]);
      },
    );
  }

  /// NEW: Build Compact Quick Action Button with Image/Icon and Label
  Widget _buildNewQuickActionButton(BuildContext context, QuickAction action) {
    VoidCallback? onTap;
    
    // Handle route navigation
    if (action.route == Routes.GROUPS) {
      onTap = () {
        if (!Get.isRegistered<GroupsController>()) {
          Get.put(GroupsController());
        }
        Get.toNamed(action.route);
      };
    } else if (action.route == Routes.FRUITS) {
      // When opening Fruits from Quick Actions, show back button on the target screen
      onTap = () => Get.toNamed(
            action.route,
            arguments: const {
              'showBackButton': true,
              'fromQuickAction': true,
            },
          );
    } else if (action.route == Routes.BLOGGER_ZONE) {
      onTap = () {
        try {
          final blogsController = Get.find<BlogsController>();
          blogsController.filterUserId.value = 0;
          // Performance: Only refresh if filter changed
          if (blogsController.filterUserId.value != 0) {
            // Performance: Only refresh if needed
            if (blogsController.blogs.isEmpty) {
              blogsController.loadBlogs(refresh: true);
            }
          }
        } catch (e) {
          Get.put(BlogsController());
        }
        Get.toNamed(action.route);
      };
    } else {
      onTap = () => Get.toNamed(action.route);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(
          ResponsiveHelper.borderRadius(context, mobile: 16),
        ),
        child: Container(
          padding: ResponsiveHelper.padding(
            context,
            horizontal: 14,
            vertical: ResponsiveHelper.isMobile(context) ? MediaQuery.of(context).size.height*0.01 : 18,
          ),
          decoration: BoxDecoration(
            color: Colors.white, // White background
            borderRadius: BorderRadius.circular(
              ResponsiveHelper.borderRadius(context, mobile: 16),
            ),
            border: Border.all(
              color: Colors.grey.withOpacity(0.2), // Faded border
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon/Image on Left
              action.imagePath != null
                  ? Image.asset(
                      action.imagePath!,
                      width: ResponsiveHelper.iconSize(
                        context,
                        mobile: 45,
                        tablet: 50,
                        desktop: 55,
                      ),
                      height: ResponsiveHelper.iconSize(
                        context,
                        mobile: 45,
                        tablet: 50,
                        desktop: 55,
                      ),
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        // Fallback to icon if image fails to load
                        return Icon(
                          action.icon,
                          size: ResponsiveHelper.iconSize(
                            context,
                            mobile: 45,
                            tablet: 50,
                            desktop: 55,
                          ),
                          color: AppTheme.iconscolor,
                        );
                      },
                    )
                  : Icon(
                      action.icon,
                      size: ResponsiveHelper.iconSize(
                        context,
                        mobile: 45,
                        tablet: 50,
                        desktop: 55,
                      ),
                      color: AppTheme.iconscolor,
                    ),
              SizedBox(
                width: ResponsiveHelper.spacing(context, 12),
              ),
              // Label/Name on Right
              Expanded(
                child: Text(
                  action.label,
                  style: ResponsiveHelper.textStyle(
                    context,
                    fontSize: ResponsiveHelper.fontSize(
                      context,
                      mobile: 14,
                      tablet: 15,
                      desktop: 16,
                    ),
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF5F4628),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// OLD: Build Quick Action Button with Material Icons (New Config-based) - COMMENTED
  /* Widget _buildQuickActionButtonWithConfig(BuildContext context, QuickAction action) {
    VoidCallback? onTap;
    
    // Handle route navigation
    if (action.route == Routes.GROUPS) {
      onTap = () {
        if (!Get.isRegistered<GroupsController>()) {
          Get.put(GroupsController());
        }
        Get.toNamed(action.route);
      };
    } else if (action.route == Routes.BLOGGER_ZONE) {
      onTap = () {
        try {
          final blogsController = Get.find<BlogsController>();
          blogsController.filterUserId.value = 0;
          // Performance: Only refresh if filter changed
          if (blogsController.filterUserId.value != 0) {
            // Performance: Only refresh if needed
          if (blogsController.blogs.isEmpty) {
            blogsController.loadBlogs(refresh: true);
          }
          }
        } catch (e) {
          Get.put(BlogsController());
        }
        Get.toNamed(action.route);
      };
    } else {
      onTap = () => Get.toNamed(action.route);
    }

    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: action.label,
          waitDuration: const Duration(milliseconds: 500),
          child: InkWell(
            onTap: onTap,
            onLongPress: () {
              Get.snackbar(
                action.label,
                action.description,
                backgroundColor: Colors.black87,
                colorText: Colors.white,
                snackPosition: SnackPosition.BOTTOM,
                duration: const Duration(seconds: 2),
                margin: EdgeInsets.all(ResponsiveHelper.spacing(context, 16)),
              );
            },
            borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
            child: Container(
              decoration: BoxDecoration(
                color: action.backgroundColor,
                borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
                border: Border.all(
                  color: action.iconColor.withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: action.iconColor.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Center(
                child: action.imagePath != null
                    ? Image.asset(
                        action.imagePath!,
                        width: ResponsiveHelper.iconSize(context, mobile: 90, tablet: 100, desktop: 110),
                        height: ResponsiveHelper.iconSize(context, mobile: 90, tablet: 100, desktop: 110),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          // Fallback to icon if image fails to load
                          return Icon(
                            action.icon,
                            size: ResponsiveHelper.iconSize(context, mobile: 90, tablet: 100, desktop: 110),
                            color: action.iconColor,
                          );
                        },
                      )
                    : Icon(
                        action.icon,
                        size: ResponsiveHelper.iconSize(context, mobile: 90, tablet: 100, desktop: 110),
                        color: action.iconColor,
                      ),
              ),
            ),
          ),
        ),
    );
  } */



  /// Legacy method for backward compatibility
  Widget _buildQuickActionButton(BuildContext context, String iconUrl, String label, {String? route}) {
    VoidCallback? onTap;
    if (route != null) {
      // Direct route provided
      onTap = () {
        if (route == Routes.CREATE_GROUP) {
          // Ensure GroupsController is available
          if (!Get.isRegistered<GroupsController>()) {
            Get.put(GroupsController());
          }
        }
        Get.toNamed(route);
      };
    } else if (label.contains('Prayer') || label.contains('prayer')) {
      onTap = () => Get.toNamed(Routes.CREATE_PRAYER);
    } else if (label.contains('Blogger') || label.contains('blogger')) {
      onTap = () {
        try {
          final blogsController = Get.find<BlogsController>();
          blogsController.filterUserId.value = 0;
          // Performance: Only refresh if needed
          if (blogsController.blogs.isEmpty) {
            blogsController.loadBlogs(refresh: true);
          }
        } catch (e) {
          Get.put(BlogsController());
        }
        Get.toNamed(Routes.BLOGGER_ZONE);
      };
    } else if (label.contains('Fruit') || label.contains('fruit')) {
      onTap = () {
        // Reload user feeling when coming back from fruits screen
        Get.toNamed(Routes.FRUITS)?.then((_) {
          // Refresh user feeling when returning from fruits screen
          final homeCtrl = Get.find<HomeController>();
          homeCtrl.loadUserFeeling();
        });
      };
    } else if (label.contains('Group') || label.contains('group')) {
      onTap = () {
        if (!Get.isRegistered<GroupsController>()) {
          Get.put(GroupsController());
        }
        Get.toNamed(Routes.GROUPS);
      };
    }

    return Container(
      margin: ResponsiveHelper.padding(context, horizontal: 6),
      child: Material(
        color: Colors.transparent,
        child: Tooltip(
          message: label,
          waitDuration: const Duration(milliseconds: 500),
        child: InkWell(
          onTap: onTap,
            onLongPress: () {
              // Show tooltip on long press
              Get.snackbar(
                label,
                'Tap to open',
                backgroundColor: Colors.black87,
                colorText: Colors.white,
                snackPosition: SnackPosition.BOTTOM,
                duration: const Duration(seconds: 1),
                margin: EdgeInsets.all(ResponsiveHelper.spacing(context, 16)),
              );
            },
            borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
          child: Container(
              height: ResponsiveHelper.safeHeight(context, mobile: 80, tablet: 90, desktop: 100),
              width: ResponsiveHelper.safeHeight(context, mobile: 80, tablet: 90, desktop: 100),
            decoration: BoxDecoration(
              color: Colors.white,
                borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                  offset: const Offset(0, 4),
                    spreadRadius: 0,
                ),
              ],
            ),
              child: Center(
                child: ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    Colors.orange[600]!,
                    BlendMode.srcATop,
                  ),
                  child: CachedImage(
                    imageUrl: iconUrl,
                    height: ResponsiveHelper.iconSize(context, mobile: 50, tablet: 55, desktop: 60),
                    width: ResponsiveHelper.iconSize(context, mobile: 50, tablet: 55, desktop: 60),
                    fit: BoxFit.contain,
                  ),
                ),
                ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper method for time ago
  // Show Go Live Dialog
  void _showGoLiveDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    String? selectedFruitTag;
    var isLoading = false;

    final fruits = [
      'Love',
      'Joy',
      'Peace',
      'Patience',
      'Kindness',
      'Goodness',
      'Faithfulness',
      'Meekness',
      'SelfControl',
    ];

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 20)),
        ),
        child: StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: ResponsiveHelper.padding(context, all: 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Go Live',
                          style: ResponsiveHelper.textStyle(
                            context,
                            fontSize: ResponsiveHelper.fontSize(context, mobile: 20),
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF8B4513),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: isLoading ? null : () => Get.back(),
                        ),
                      ],
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(context, 20)),
                    
                    // Stream Title
                    Text(
                      'Stream Title *',
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF5F4628),
                      ),
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(context, 8)),
                    TextField(
                      controller: titleController,
                      enabled: !isLoading,
                      decoration: InputDecoration(
                        hintText: 'Enter stream title',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF8B4513), width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: ResponsiveHelper.padding(
                          context,
                          horizontal: ResponsiveHelper.isMobile(context) ? 14 : 16,
                          vertical: ResponsiveHelper.isMobile(context) ? 10 : 12,
                        ),
                      ),
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                    
                    // Description
                    Text(
                      'Description (Optional)',
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF5F4628),
                      ),
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(context, 8)),
                    TextField(
                      controller: descriptionController,
                      enabled: !isLoading,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Enter stream description',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF8B4513), width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: ResponsiveHelper.padding(
                          context,
                          horizontal: ResponsiveHelper.isMobile(context) ? 14 : 16,
                          vertical: ResponsiveHelper.isMobile(context) ? 10 : 12,
                        ),
                      ),
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                    
                    // Fruit Tag
                    Text(
                      'Fruit Tag (Optional)',
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF5F4628),
                      ),
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(context, 8)),
                    DropdownButtonFormField<String>(
                      value: selectedFruitTag,
                      decoration: InputDecoration(
                        hintText: 'Select fruit tag',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF8B4513), width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: ResponsiveHelper.padding(
                          context,
                          horizontal: ResponsiveHelper.isMobile(context) ? 14 : 16,
                          vertical: ResponsiveHelper.isMobile(context) ? 10 : 12,
                        ),
                      ),
                      items: fruits.map((fruit) => DropdownMenuItem(
                        value: fruit,
                        child: Text(fruit),
                      )).toList(),
                      onChanged: isLoading ? null : (value) {
                        setState(() {
                          selectedFruitTag = value;
                        });
                      },
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(context, 24)),
                    
                    // Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: isLoading ? null : () {
                            titleController.dispose();
                            descriptionController.dispose();
                            Get.back();
                          },
                          child: Text(
                            'Cancel',
                            style: ResponsiveHelper.textStyle(
                              context,
                              fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                        SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                        ElevatedButton(
                          onPressed: isLoading ? null : () async {
                            if (titleController.text.trim().isEmpty) {
                              Get.snackbar(
                                'Error',
                                'Please enter stream title',
                                backgroundColor: Colors.red,
                                colorText: Colors.white,
                                snackPosition: SnackPosition.BOTTOM,
                              );
                              return;
                            }

                            setState(() {
                              isLoading = true;
                            });

                            try {
                              final userId = await UserStorage.getUserId();
                              if (userId == null || userId == 0) {
                                throw Exception('User not logged in');
                              }

                              final streamData = await LiveStreamingService.createLiveStream(
                                userId: userId,
                                title: titleController.text.trim(),
                                description: descriptionController.text.trim().isEmpty
                                    ? null
                                    : descriptionController.text.trim(),
                                fruitTag: selectedFruitTag,
                              );

                              titleController.dispose();
                              descriptionController.dispose();
                              
                              Get.back();
                              
                              // Show success with stream details
                              Get.dialog(
                                Dialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 20)),
                                  ),
                                  child: Container(
                                    padding: ResponsiveHelper.padding(context, all: 24),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.check_circle,
                                          color: Colors.green,
                                          size: 60,
                                        ),
                                        SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                                        Text(
                                          'Live Stream Created!',
                                          style: ResponsiveHelper.textStyle(
                                            context,
                                            fontSize: ResponsiveHelper.fontSize(context, mobile: 18),
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF8B4513),
                                          ),
                                        ),
                                        SizedBox(height: ResponsiveHelper.spacing(context, 12)),
                                        if (streamData['stream_key'] != null)
                                          Container(
                                            padding: ResponsiveHelper.padding(
                                              context,
                                              all: ResponsiveHelper.isMobile(context) ? 10 : 12,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[100],
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Stream Key:',
                                                  style: ResponsiveHelper.textStyle(
                                                    context,
                                                    fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.grey[700],
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                SelectableText(
                                                  streamData['stream_key'].toString(),
                                                  style: ResponsiveHelper.textStyle(
                                                    context,
                                                    fontSize: ResponsiveHelper.fontSize(context, mobile: 11),
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        if (streamData['rtmp_url'] != null) ...[
                                          SizedBox(height: ResponsiveHelper.spacing(context, 12)),
                                          Container(
                                            padding: ResponsiveHelper.padding(
                                              context,
                                              all: ResponsiveHelper.isMobile(context) ? 10 : 12,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[100],
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'RTMP URL:',
                                                  style: ResponsiveHelper.textStyle(
                                                    context,
                                                    fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.grey[700],
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                SelectableText(
                                                  streamData['rtmp_url'].toString(),
                                                  style: ResponsiveHelper.textStyle(
                                                    context,
                                                    fontSize: ResponsiveHelper.fontSize(context, mobile: 11),
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                        SizedBox(height: ResponsiveHelper.spacing(context, 20)),
                                        ElevatedButton(
                                          onPressed: () {
                                            Get.back();
                                            // Refresh live videos
                                            controller.loadLiveVideos();
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF8B4513),
                                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                          ),
                                          child: Text(
                                            'OK',
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
                                  ),
                                ),
                              );
                            } catch (e) {
                              setState(() {
                                isLoading = false;
                              });
                              
                              Get.snackbar(
                                'Error',
                                e.toString().replaceAll('Exception: ', ''),
                                backgroundColor: Colors.red,
                                colorText: Colors.white,
                                snackPosition: SnackPosition.BOTTOM,
                                duration: const Duration(seconds: 4),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8B4513),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  'Create Stream',
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
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _getTimeAgo(String? dateTimeString) {
    if (dateTimeString == null || dateTimeString.isEmpty) return '';
    try {
      final date = DateTime.parse(dateTimeString);
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

  // Build Prayer Card with View All button (for Dashboard Feed)
  Widget _buildPrayerCardWithViewAll(BuildContext context, Map<String, dynamic> prayer) {
    // Get user profile photo URL
    String? profilePhotoUrl;
    if (prayer['profile_photo'] != null && prayer['profile_photo'].toString().isNotEmpty) {
      final photoPath = prayer['profile_photo'].toString();
      // Check if already a full URL (http/https)
      if (photoPath.startsWith('http://') || photoPath.startsWith('https://')) {
        profilePhotoUrl = photoPath; // Use as-is if already a full URL
      } else if (!photoPath.startsWith('assets/') &&
          !photoPath.startsWith('file://') &&
          !photoPath.startsWith('assets/images/')) {
        profilePhotoUrl = 'https://fruitofthespirit.templateforwebsites.com/$photoPath';
      }
    }

    // Get user name (hide if anonymous)
    final isAnonymous = prayer['is_anonymous'] == 1 || prayer['is_anonymous'] == true;
    final userName = isAnonymous ? 'Someone' : (prayer['user_name'] ?? prayer['name'] ?? 'User');
    final prayerContent = AutoTranslateHelper.getTranslatedTextSync(
      text: prayer['content'] ?? '',
      sourceLanguage: prayer['language'] as String?,
    );

    return Container(
      padding: ResponsiveHelper.padding(context, all: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F8FF), // Very light blue/off-white background
        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
        border: Border.all(
          color: const Color(0xFFB3E5FC).withOpacity(0.5), // Light blue border
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Photo or Avatar (hide if anonymous)
          isAnonymous
              ? CircleAvatar(
                  radius: 25,
                  backgroundColor: Colors.grey[300],
                  child: Icon(
                    Icons.person_outline,
                color: Colors.grey[600],
                    size: 28,
              ),
                )
              : (profilePhotoUrl != null
                  ? ClipOval(
                      child: CachedImage(
                        imageUrl: profilePhotoUrl,
                        width: ResponsiveHelper.iconSize(context, mobile: 50),
                        height: ResponsiveHelper.iconSize(context, mobile: 50),
                        fit: BoxFit.cover,
                        errorWidget: CircleAvatar(
                          radius: 25,
                          backgroundColor: const Color(0xFFFFD1DC), // Light pink background
                          child: Icon(
                            Icons.person,
                            color: Colors.black87,
                            size: 28,
                          ),
                        ),
                      ),
                    )
                  : CircleAvatar(
                      radius: 25,
                      backgroundColor: const Color(0xFFFFD1DC), // Light pink background
                      child: Icon(
                        Icons.person,
                        color: Colors.black87,
                        size: 28,
                      ),
                    )),
          SizedBox(width: ResponsiveHelper.spacing(context, 12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Prayer Request label
                // Text(
                //   'Prayers',
                //   style: TextStyle(
                //     fontWeight: FontWeight.bold,
                //     fontSize: 16,
                //     color: const Color(0xFF1976D2), // Nice blue color
                //   ),
                // ),
                SizedBox(height: ResponsiveHelper.spacing(context, 6)),
                // User name and needs
                Text(
                  '$userName needs healing:',
                  style: ResponsiveHelper.textStyle(
                    context,
                    fontSize: 14,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, 4)),
                // Prayer content
                Text(
                  '"$prayerContent"',
                  style: ResponsiveHelper.textStyle(
                    context,
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
          ),
          SizedBox(width: ResponsiveHelper.spacing(context, 8)),
          // View All button
          ElevatedButton(
            onPressed: () {
              // Reset filter to show all users' prayers
              try {
                final prayersController = Get.find<PrayersController>();
                prayersController.filterUserId.value = 0;
                // Performance: Only refresh if needed
                if (prayersController.prayers.isEmpty) {
                  prayersController.loadPrayers(refresh: true);
                }
              } catch (e) {
                // Controller not found, will be created fresh
              }
              Get.toNamed(Routes.PRAYER_REQUESTS);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50), // Green button
              foregroundColor: Colors.white,
              padding: ResponsiveHelper.padding(context, horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
              ),
              elevation: 0,
            ),
            child: Text(
              'View All',
              style: ResponsiveHelper.textStyle(
                context,
                fontSize: 13,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build Prayer Card (from database)
  Widget _buildPrayerCard(BuildContext context, Map<String, dynamic> prayer) {
    // Check if anonymous
    final isAnonymous = prayer['is_anonymous'] == 1 || prayer['is_anonymous'] == true;

    // Get user profile photo URL (only if not anonymous)
    String? profilePhotoUrl;
    if (!isAnonymous && prayer['profile_photo'] != null && prayer['profile_photo'].toString().isNotEmpty) {
      final photoPath = prayer['profile_photo'].toString();
      // Check if already a full URL (http/https)
      if (photoPath.startsWith('http://') || photoPath.startsWith('https://')) {
        profilePhotoUrl = photoPath; // Use as-is if already a full URL
      } else if (!photoPath.startsWith('assets/') &&
          !photoPath.startsWith('file://') &&
          !photoPath.startsWith('assets/images/')) {
        profilePhotoUrl = 'https://fruitofthespirit.templateforwebsites.com/$photoPath';
      }
    }

    return Padding(
      padding: ResponsiveHelper.padding(context, bottom: 10),
      child: GestureDetector(
        onTap: () {
          if (prayer['id'] != null) {
            Get.toNamed(Routes.PRAYER_DETAILS, arguments: prayer['id']);
          } else {
            // Reset filter to show all users' prayers
            try {
              final prayersController = Get.find<PrayersController>();
              prayersController.filterUserId.value = 0;
              prayersController.loadPrayers(refresh: true);
            } catch (e) {
              // Controller not found, will be created fresh
            }
            Get.toNamed(Routes.PRAYER_REQUESTS);
          }
        },
        child: Container(
        padding: ResponsiveHelper.padding(context, all: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFE3F2FD), // Light blue background for prayer card
          borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.12),
              spreadRadius: 1,
              blurRadius: 6,
              offset: Offset(0, ResponsiveHelper.spacing(context, 2)),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Photo or Avatar (hide if anonymous)
            isAnonymous
                ? CircleAvatar(
                    radius: ResponsiveHelper.borderRadius(context, mobile: 20, tablet: 22, desktop: 25),
                    backgroundColor: Colors.grey[300],
                    child: Icon(
                      Icons.person_outline,
                      color: Colors.grey[600],
                      size: ResponsiveHelper.iconSize(context, mobile: 18, tablet: 20, desktop: 22),
                    ),
                  )
                : (profilePhotoUrl != null
                ? ClipOval(
                    child: CachedImage(
                      imageUrl: profilePhotoUrl,
                      width: ResponsiveHelper.imageWidth(context, mobile: 40, tablet: 45, desktop: 50),
                      height: ResponsiveHelper.imageHeight(context, mobile: 40, tablet: 45, desktop: 50),
                      fit: BoxFit.cover,
                      errorWidget: CircleAvatar(
                        radius: ResponsiveHelper.borderRadius(context, mobile: 20, tablet: 22, desktop: 25),
                        backgroundColor: Colors.blueGrey,
                        child: Icon(
                          Icons.person,
                          color: Colors.white,
                          size: ResponsiveHelper.iconSize(context, mobile: 18, tablet: 20, desktop: 22),
                        ),
                      ),
                    ),
                  )
                : CircleAvatar(
                    radius: ResponsiveHelper.borderRadius(context, mobile: 20, tablet: 22, desktop: 25),
                    backgroundColor: Colors.blueGrey,
                    child: Icon(
                      Icons.person,
                      color: Colors.white,
                      size: ResponsiveHelper.iconSize(context, mobile: 18, tablet: 20, desktop: 22),
                    ),
                      )),
            SizedBox(width: ResponsiveHelper.spacing(context, 10)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Name (hide if anonymous)
                  if (!isAnonymous && prayer['user_name'] != null)
                    Text(
                      prayer['user_name'],
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 16, desktop: 18),
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                  if (!isAnonymous && prayer['user_name'] != null)
                    SizedBox(height: ResponsiveHelper.spacing(context, 4)),
                  // Category
                  Text(
                    prayer['category'] ?? 'Prayer Request',
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontWeight: FontWeight.bold,
                      fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 18, desktop: 20),
                      color: const Color(0xFF8B4513),
                    ),
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(context, 4)),
                  // Content (Auto-translated based on app language)
                  Text(
                    AutoTranslateHelper.getTranslatedTextSync(
                      text: prayer['content'] ?? '',
                      sourceLanguage: prayer['language'] as String?,
                    ),
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 16, desktop: 18),
                      color: Colors.grey[700],
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Response Count (if available)
                  if (prayer['response_count'] != null && (prayer['response_count'] as int) > 0)
                    Padding(
                      padding: ResponsiveHelper.padding(context,top: ResponsiveHelper.spacing(context, 6)),
                      child: Row(
                        children: [
                          Icon(
                            Icons.favorite,
                            size: ResponsiveHelper.iconSize(context, mobile: 14, tablet: 16, desktop: 18),
                            color: Colors.red[300],
                          ),
                          SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                          Text(
                            '${prayer['response_count']} responses',
                            style: ResponsiveHelper.textStyle(
                              context,
                              fontSize: ResponsiveHelper.fontSize(context, mobile: 12, tablet: 14, desktop: 16),
                              color: Colors.grey[600],
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
      ),
    );
  }

  // Build Blog Card (from database)
  Widget _buildBlogCard(BuildContext context, Map<String, dynamic> blog) {
    return Container(
      width: ResponsiveHelper.imageWidth(context, mobile: 250),
      margin: ResponsiveHelper.padding(context, right: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: ResponsiveHelper.spacing(context, 2),
            blurRadius: ResponsiveHelper.spacing(context, 5),
            offset: Offset(0, ResponsiveHelper.spacing(context, 3)),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
            ),
            child: blog['image_url'] != null
                ? LazyCachedImage(
                    imageUrl: 'https://fruitofthespirit.templateforwebsites.com/${blog['image_url']}',
                    height: ResponsiveHelper.imageHeight(context, mobile: 120),
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorWidget: Container(
                      height: ResponsiveHelper.imageHeight(context, mobile: 120),
                      color: Colors.grey[300],
                      child: Icon(Icons.image, size: ResponsiveHelper.iconSize(context, mobile: 40)),
                    ),
                  )
                : Container(
                    height: ResponsiveHelper.imageHeight(context, mobile: 120),
                    color: Colors.grey[300],
                    child: Icon(Icons.article, size: ResponsiveHelper.iconSize(context, mobile: 40)),
            ),
          ),
          Padding(
            padding: ResponsiveHelper.padding(context, all: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AutoTranslateHelper.getTranslatedTextSync(
                    text: blog['title'] ?? 'Blog Title',
                    sourceLanguage: blog['language'] as String?,
                  ),
                  style: ResponsiveHelper.textStyle(
                    context,
                    fontWeight: FontWeight.bold,
                    fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 18, desktop: 20),
                    color: const Color(0xFF8B4513),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, 5)),
                Text(
                  blog['author_name'] ?? 'Blogger',
                  style: ResponsiveHelper.textStyle(
                    context,
                    fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 16, desktop: 18),
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Build Gallery Photo Card (from database)
  Widget _buildGalleryPhotoCard(BuildContext context, Map<String, dynamic> photo) {
    return Container(
      width: ResponsiveHelper.imageWidth(context, mobile: 200),
      margin: ResponsiveHelper.padding(context, right: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: ResponsiveHelper.spacing(context, 2),
            blurRadius: ResponsiveHelper.spacing(context, 5),
            offset: Offset(0, ResponsiveHelper.spacing(context, 3)),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
            ),
            child: photo['file_path'] != null
                ? LazyCachedImage(
                    imageUrl: 'https://fruitofthespirit.templateforwebsites.com/${photo['file_path']}',
                    height: ResponsiveHelper.imageHeight(context, mobile: 150),
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorWidget: Container(
                      height: ResponsiveHelper.imageHeight(context, mobile: 150),
                      color: Colors.grey[300],
                      child: Icon(Icons.image, size: ResponsiveHelper.iconSize(context, mobile: 40)),
                    ),
                  )
                : Container(
                    height: ResponsiveHelper.imageHeight(context, mobile: 150),
                    color: Colors.grey[300],
                    child: Icon(Icons.image, size: ResponsiveHelper.iconSize(context, mobile: 40)),
                  ),
          ),
          if (photo['fruit_tag'] != null)
            Padding(
              padding: ResponsiveHelper.padding(context, all: 8),
              child: Container(
                padding: ResponsiveHelper.padding(context,
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEECE2),
                  borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
                ),
                child: Text(
                  photo['fruit_tag'] ?? '',
                  style: ResponsiveHelper.textStyle(
                    context,
                    fontSize: ResponsiveHelper.fontSize(context, mobile: 12, tablet: 14, desktop: 16),
                    color: const Color(0xFF8B4513),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Build Groups Section - Clean & Simple Design

  // Build Featured Video Card (with Video label and Kindness Moment overlay)
  Widget _buildFeaturedVideoCard(BuildContext context, Map<String, dynamic> video) {
    // Use helper function to get thumbnail
    String? imageUrl = _getVideoThumbnail(video);
    String? videoUrl = _getVideoUrl(video);
    final cardWidth = ResponsiveHelper.imageWidth(context, mobile: 260, tablet: 300, desktop: 340);
    final cardHeight = ResponsiveHelper.imageHeight(context, mobile: 180, tablet: 200, desktop: 220);

    return GestureDetector(
      onTap: () {
        if (video['id'] != null) {
          Get.toNamed(Routes.VIDEO_DETAILS, arguments: video['id']);
        } else {
          Get.toNamed(Routes.VIDEOS);
        }
      },
      child: Container(
        width: cardWidth,
        height: cardHeight,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 10, tablet: 12, desktop: 14)),
        ),
        child: Stack(
          children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 10, tablet: 12, desktop: 14)),
            child: imageUrl != null
                ? LazyCachedImage(
                    imageUrl: imageUrl!,
                    height: cardHeight,
                    width: cardWidth,
                    fit: BoxFit.cover,
                    errorWidget: videoUrl != null
                        ? VideoFrameThumbnail(
                            videoUrl: videoUrl,
                            fit: BoxFit.cover,
                            width: cardWidth,
                            height: cardHeight,
                          )
                        : Container(
                            height: cardHeight,
                            width: cardWidth,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppTheme.themeColor,
                                  AppTheme.primaryColor.withOpacity(0.3),
                                ],
                              ),
                            ),
                            child: Icon(
                              Icons.video_library_rounded,
                              size: ResponsiveHelper.iconSize(context, mobile: 40, tablet: 45, desktop: 50),
                              color: AppTheme.primaryColor,
                            ),
                          ),
                  )
                : videoUrl != null
                    ? VideoFrameThumbnail(
                        videoUrl: videoUrl,
                        fit: BoxFit.cover,
                        width: cardWidth,
                        height: cardHeight,
                      )
                    : Container(
                        height: cardHeight,
                        width: cardWidth,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppTheme.themeColor,
                              AppTheme.primaryColor.withOpacity(0.3),
                            ],
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.video_library_rounded,
                            size: ResponsiveHelper.iconSize(context, mobile: 40, tablet: 45, desktop: 50),
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
          ),
          Positioned.fill(
            child: Center(
              child: Icon(
                Icons.play_circle_fill,
                color: Colors.white.withOpacity(0.8),
                size: ResponsiveHelper.iconSize(context, mobile: 45, tablet: 55, desktop: 65),
              ),
            ),
          ),
          // "Video" label top-left
          Positioned(
            top: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 6 : 8),
            left: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 6 : 8),
            child: Container(
              padding: ResponsiveHelper.padding(context,
                horizontal: ResponsiveHelper.isMobile(context) ? 6 : 8,
                vertical: ResponsiveHelper.isMobile(context) ? 3 : 4,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 6, tablet: 8, desktop: 10)),
              ),
              child: Text(
                'Video',
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: ResponsiveHelper.fontSize(context, mobile: 11, tablet: 12, desktop: 13),
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          // "+ Kindness Moment" overlay bottom-left
          Positioned(
            bottom: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 6 : 8),
            left: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 6 : 8),
            child: Container(
              padding: ResponsiveHelper.padding(context,
                horizontal: ResponsiveHelper.isMobile(context) ? 6 : 8,
                vertical: ResponsiveHelper.isMobile(context) ? 3 : 4,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 6, tablet: 8, desktop: 10)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: ResponsiveHelper.iconSize(context, mobile: 18, tablet: 20, desktop: 22),
                    height: ResponsiveHelper.iconSize(context, mobile: 18, tablet: 20, desktop: 22),
                    decoration: BoxDecoration(
                    color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.add,
                      color: Colors.white,
                      size: ResponsiveHelper.iconSize(context, mobile: 12, tablet: 14, desktop: 16),
                    ),
                  ),
                  SizedBox(width: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 3 : 4)),
                  Text(
                    'Kindness Moment',
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Small circular icon bottom-right
            Positioned(
              bottom: ResponsiveHelper.spacing(context, 8),
              right: ResponsiveHelper.spacing(context, 8),
            child: Container(
              width: ResponsiveHelper.iconSize(context, mobile: 32),
              height: ResponsiveHelper.iconSize(context, mobile: 32),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF8B4513).withOpacity(0.3),
                  width: 1.5,
                ),
              ),
                child: Icon(
                Icons.favorite_border,
                size: 18,
                color: const Color(0xFF8B4513).withOpacity(0.6),
                ),
              ),
            ),
        ],
      ),
      ),
    );
  }

  // Build Empty Video Thumbnail (when no videos available)
  Widget _buildEmptyVideoThumbnail(BuildContext context) {
    return Container(
      height: ResponsiveHelper.imageHeight(context, mobile: 180, tablet: 200, desktop: 220),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 10, tablet: 12, desktop: 14)),
      ),
      child: Stack(
        children: [
          // Background with video icon
          Positioned.fill(
            child: Center(
              child: Icon(
                Icons.video_library,
                size: ResponsiveHelper.iconSize(context, mobile: 50, tablet: 60, desktop: 70),
                color: Colors.white.withOpacity(0.3),
              ),
            ),
          ),
          // Play icon overlay
          Positioned.fill(
            child: Center(
              child: Icon(
                Icons.play_circle_fill,
                color: Colors.white.withOpacity(0.8),
                size: ResponsiveHelper.iconSize(context, mobile: 45, tablet: 55, desktop: 65),
              ),
            ),
          ),
          // "Video" label top-left
          Positioned(
            top: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 6 : 8),
            left: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 6 : 8),
            child: Container(
              padding: ResponsiveHelper.padding(context,
                horizontal: ResponsiveHelper.isMobile(context) ? 6 : 8,
                vertical: ResponsiveHelper.isMobile(context) ? 3 : 4,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
              ),
              child: Text(
                'Video',
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          // "No videos yet" text bottom-center
          Positioned(
            bottom: ResponsiveHelper.spacing(context, 8),
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: ResponsiveHelper.padding(context,
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
                ),
                child: Text(
                  'No videos yet',
                  style: ResponsiveHelper.textStyle(
                    context,
                    fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
          ],
        ),
      );

  }

  // Build Blog Post Card (The Power of Forgiveness style)
  Widget _buildBlogPostCard(BuildContext context, Map<String, dynamic> blog) {
    return GestureDetector(
      onTap: () {
        if (blog['id'] != null) {
          Get.toNamed(Routes.BLOG_DETAILS, arguments: blog['id']);
        } else {
          // Reset filter to show all users' blogs
          try {
            final blogsController = Get.find<BlogsController>();
            blogsController.filterUserId.value = 0;
            // Performance: Only refresh if needed
          if (blogsController.blogs.isEmpty) {
            blogsController.loadBlogs(refresh: true);
          }
          } catch (e) {
            // Controller not found, will be created fresh
          }
          Get.toNamed(Routes.BLOGS);
        }
      },
      child: Container(
        width: ResponsiveHelper.imageWidth(context, mobile: 280, tablet: 320, desktop: 360),
      constraints: BoxConstraints(
          minHeight: 90,
      ),
        padding: ResponsiveHelper.padding(context, all: 10),
        margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            // Square thumbnail image on left
            Container(
              width: ResponsiveHelper.iconSize(context, mobile: 70, tablet: 80, desktop: 90),
              height: ResponsiveHelper.iconSize(context, mobile: 70, tablet: 80, desktop: 90),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD), // Light blue background
                borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
              ),
              child: blog['image_url'] != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
                      child: LazyCachedImage(
                        imageUrl: 'https://fruitofthespirit.templateforwebsites.com/${blog['image_url']}',
                        width: 70,
                        height: 70,
                        fit: BoxFit.cover,
                        errorWidget: Container(
                          width: 70,
                          height: 70,
                          color: const Color(0xFFE3F2FD),
            child: Icon(
                            Icons.image,
                            size: ResponsiveHelper.iconSize(context, mobile: 25),
                            color: Colors.grey[400],
                          ),
                        ),
                      ),
                    )
                  : Container(
                      width: 70,
                      height: 70,
                      color: const Color(0xFFE3F2FD),
                      child: Icon(
                        Icons.image,
                        size: 25,
                        color: Colors.grey[400],
                      ),
            ),
          ),
            SizedBox(width: ResponsiveHelper.spacing(context, 10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                  // Title
                Text(
                    AutoTranslateHelper.getTranslatedTextSync(
                      text: blog['title'] ?? 'The Power of Forgiveness',
                      sourceLanguage: blog['language'] as String?,
                    ),
                    style: TextStyle(
                    fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.black87,
                  ),
                    maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                  SizedBox(height: ResponsiveHelper.spacing(context, 3)),
                  // AON tag with emoji
                Row(
                  children: [
                      Container(
                        padding: ResponsiveHelper.padding(context,
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange[200],
                          borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 4)),
                        ),
                      child: Text(
                          blog['category'] ?? 'AON',
                        style: ResponsiveHelper.textStyle(
                          context,
                            fontSize: 10,
                            color: Colors.orange[900],
                            fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                      SizedBox(width: ResponsiveHelper.spacing(context, 3)),
                    Obx(() {
                        // Get first fruit from database - show image, not emoji text
                      if (controller.emojis.isNotEmpty) {
                        final emoji = controller.emojis[0];
                        return SizedBox(
                          width: 20,
                          height: 20,
                          child: HomeScreen.buildEmojiDisplay(
                            context,
                            emoji,
                            size: 20,
                          ),
                        );
                      }
                        return const SizedBox.shrink();
                    }),
                  ],
                ),
                  SizedBox(height: ResponsiveHelper.spacing(context, 2)),
                  // Author name
                  Text(
                    '${blog['author_name'] ?? 'David Chen'}-Approved Blogger',
                    style: ResponsiveHelper.textStyle(
                      context,
                            fontSize: 10,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
            // Emojis at bottom-right
            Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
          Obx(() {
                  // Get fruits from database - show images, not emoji text
            if (controller.emojis.length >= 2) {
              final emoji1 = controller.emojis[0];
              final emoji2 = controller.emojis[1];

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: HomeScreen.buildEmojiDisplay(
                        context,
                        emoji1,
                        size: 24,
                      ),
                    ),
                        SizedBox(height: ResponsiveHelper.spacing(context, 2)),
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: HomeScreen.buildEmojiDisplay(
                        context,
                        emoji2,
                        size: 24,
                      ),
                    ),
                  ],
                );
            }
            return const SizedBox.shrink();
          }),
              ],
            ),
        ],
      ),
      ),
    );
  }

  // Build Story Card (for Share & Read Stories section)
  Widget _buildStoryCard(BuildContext context, Map<String, dynamic> photo, int index) {
    final storyTitles = ['Prayer walk', 'Noah', 'Selah'];
    final storyTexts = [
      'prayer walk me of',
      'Serving meals with group sought kindness.',
      'Game night with group filled my heart with joy.',
    ];

    return Container(
      width: ResponsiveHelper.imageWidth(context, mobile: 240, tablet: 260, desktop: 280),
      margin: ResponsiveHelper.padding(context, right: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
      onTap: () {
        // Check if this is a story or gallery photo
        if (photo['id'] != null) {
          if (photo['title'] != null || photo['content'] != null) {
            Get.toNamed(Routes.STORY_DETAILS, arguments: photo['id']);
          } else {
            Get.toNamed(Routes.PHOTO_DETAILS, arguments: photo['id']);
          }
        } else {
          Get.toNamed(Routes.STORIES);
        }
      },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Story Image - Larger and more prominent
            ClipRRect(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
              ),
              child: Stack(
                children: [
                  photo['file_path'] != null
                  ? Builder(
                      builder: (context) {
                        final imageUrl = 'https://fruitofthespirit.templateforwebsites.com/${photo['file_path']}';
                        print('🖼️ Loading gallery image: ${photo['file_path']}');
                        print('   Full URL: $imageUrl');
                        return LazyCachedImage(
                          imageUrl: imageUrl,
                              height: ResponsiveHelper.imageHeight(context, mobile: 150, tablet: 170, desktop: 190),
                          width: double.infinity,
                          fit: BoxFit.cover,
                          headers: {
                            'Accept': 'image/*',
                          },
                          errorWidget: Container(
                                height: ResponsiveHelper.imageHeight(context, mobile: 150, tablet: 170, desktop: 190),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
                                  ),
                                ),
                                child: Icon(Icons.image, size: ResponsiveHelper.iconSize(context, mobile: 50, tablet: 60, desktop: 70), color: Colors.grey[600]),
                          ),
                        );
                      },
                    )
                  : Container(
                          height: ResponsiveHelper.imageHeight(context, mobile: 150, tablet: 170, desktop: 190),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
                            ),
                          ),
                          child: Icon(Icons.image, size: ResponsiveHelper.iconSize(context, mobile: 50, tablet: 60, desktop: 70), color: Colors.grey[600]),
                    ),
                  // Gradient overlay at bottom for better text readability
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: ResponsiveHelper.spacing(context, 50),
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
            // Content Section
            Flexible(
              child: Padding(
                padding: ResponsiveHelper.padding(context, all: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Story Title
                    Text(
                        index < storyTitles.length ? storyTitles[index] : photo['fruit_tag'] ?? 'Story',
                        style: ResponsiveHelper.textStyle(
                          context,
                          fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.black87,
                        letterSpacing: 0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    SizedBox(height: ResponsiveHelper.spacing(context, 4)),
                    // Story Text
                    Flexible(
                      child: Text(
                        index < storyTexts.length ? storyTexts[index] : (photo['testimony'] ?? ''),
                        style: ResponsiveHelper.textStyle(
                          context,
                          fontSize: 12,
                          color: Colors.grey[700],
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(context, 6)),
                    // Likes Row
                    Container(
                      padding: ResponsiveHelper.padding(context, horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 10)),
                      ),
                      child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.favorite,
                          color: Colors.red,
                            size: ResponsiveHelper.iconSize(context, mobile: 14),
                          ),
                          SizedBox(width: ResponsiveHelper.spacing(context, 3)),
                        Text(
                          '${128 - (index * 32)}',
                          style: ResponsiveHelper.textStyle(
                            context,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.red[700],
                            ),
                        ),
                      ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ));
  }

  // Build Video Card (from database)
  Widget _buildVideoCard(BuildContext context, Map<String, dynamic> video, {required bool isLive}) {
    // Use helper function to get thumbnail
    String? imageUrl = _getVideoThumbnail(video);
    // For live videos, check stream_url as fallback
    if (imageUrl == null && video['stream_url'] != null) {
      imageUrl = video['stream_url'];
    }

    return GestureDetector(
      onTap: () {
        if (video['id'] != null) {
          Get.toNamed(Routes.VIDEO_DETAILS, arguments: video['id']);
        } else {
          Get.toNamed(Routes.VIDEOS);
        }
      },
      child: Container(
        width: ResponsiveHelper.imageWidth(context, mobile: 250, tablet: 280, desktop: 320),
        margin: ResponsiveHelper.padding(context, right: 10),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12, tablet: 14, desktop: 16)),
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12, tablet: 14, desktop: 16)),
              child: imageUrl != null && !imageUrl!.startsWith('file://') && !imageUrl!.startsWith('assets/')
                  ? LazyCachedImage(
                      imageUrl: imageUrl!,
                      height: ResponsiveHelper.imageHeight(context, mobile: 150, tablet: 180, desktop: 200),
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorWidget: Container(
                        height: ResponsiveHelper.imageHeight(context, mobile: 150, tablet: 180, desktop: 200),
                        width: double.infinity,
                        color: Colors.grey[800],
                        child: Center(
                          child: Icon(
                            Icons.video_library,
                            color: Colors.white,
                            size: ResponsiveHelper.iconSize(context, mobile: 48),
                          ),
                        ),
                      ),
                    )
                  : Container(
                      height: ResponsiveHelper.imageHeight(context, mobile: 150, tablet: 180, desktop: 200),
                      width: double.infinity,
                      color: Colors.grey[800],
                      child: Center(
                        child: Icon(
                          Icons.video_library,
                          color: Colors.white,
                          size: ResponsiveHelper.iconSize(context, mobile: 48),
                        ),
                      ),
                    ),
            ),
            Positioned.fill(
              child: Center(
                child: Icon(
                  Icons.play_circle_fill,
                  color: Colors.white.withOpacity(0.8),
                  size: ResponsiveHelper.iconSize(context, mobile: 50, tablet: 60, desktop: 70),
                ),
              ),
            ),
            if (isLive)
              Positioned(
                top: ResponsiveHelper.spacing(context, ResponsiveHelper.isDesktop(context) ? 12 : ResponsiveHelper.isTablet(context) ? 10 : 8),
                left: ResponsiveHelper.spacing(context, ResponsiveHelper.isDesktop(context) ? 12 : ResponsiveHelper.isTablet(context) ? 10 : 8),
                child: Container(
                  padding: ResponsiveHelper.padding(context,
                    horizontal: ResponsiveHelper.isDesktop(context) ? 12 : ResponsiveHelper.isTablet(context) ? 10 : 8,
                    vertical: ResponsiveHelper.isDesktop(context) ? 6 : ResponsiveHelper.isTablet(context) ? 5 : 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8, tablet: 10, desktop: 12)),
                  ),
                  child: Text(
                    'LIVE',
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: ResponsiveHelper.fontSize(context, mobile: 12, tablet: 14, desktop: 16),
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            if (video['fruit_tag'] != null)
              Positioned(
                bottom: ResponsiveHelper.spacing(context, ResponsiveHelper.isDesktop(context) ? 12 : ResponsiveHelper.isTablet(context) ? 10 : 8),
                left: ResponsiveHelper.spacing(context, ResponsiveHelper.isDesktop(context) ? 12 : ResponsiveHelper.isTablet(context) ? 10 : 8),
                child: Container(
                  padding: ResponsiveHelper.padding(context,
                    horizontal: ResponsiveHelper.isDesktop(context) ? 12 : ResponsiveHelper.isTablet(context) ? 10 : 8,
                    vertical: ResponsiveHelper.isDesktop(context) ? 6 : ResponsiveHelper.isTablet(context) ? 5 : 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8, tablet: 10, desktop: 12)),
                  ),
                  child: Text(
                    video['fruit_tag'] ?? '',
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: ResponsiveHelper.fontSize(context, mobile: 12, tablet: 14, desktop: 16),
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Build Live Video Card (specialized for Live Videos section)
  Widget _buildLiveVideoCard(BuildContext context, Map<String, dynamic> video) {
    // Check if we should navigate to live video details
    final isLive = video['status'] == 'Live' || video['stream_key'] != null;
    // Use helper function to get thumbnail
    String? imageUrl = _getVideoThumbnail(video);
    // For live videos, check stream_url as fallback
    if (imageUrl == null && video['stream_url'] != null) {
      imageUrl = video['stream_url'];
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
        onTap: () {
          if (video['id'] != null) {
            Get.toNamed(Routes.VIDEO_DETAILS, arguments: video['id']);
          } else {
            Get.toNamed(Routes.VIDEOS);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                spreadRadius: 0,
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Video Thumbnail
                Stack(
                  children: [
                    Container(
                      height: ResponsiveHelper.imageHeight(context, mobile: 160, tablet: 180, desktop: 200),
                      width: double.infinity,
                      color: Colors.grey[300],
                      child: imageUrl != null && !imageUrl!.startsWith('file://') && !imageUrl!.startsWith('assets/')
                          ? LazyCachedImage(
                              imageUrl: imageUrl!,
                              height: double.infinity,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorWidget: Container(
                                height: double.infinity,
                                width: double.infinity,
                                color: Colors.grey[300],
                                child: Center(
                                  child: Icon(
                                    Icons.videocam,
                                    color: Colors.grey[600],
                                    size: 40,
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              height: double.infinity,
                              width: double.infinity,
                              color: Colors.grey[300],
                              child: Center(
                                child: Icon(
                                  Icons.videocam,
                                  color: Colors.grey[600],
                                  size: 40,
                                ),
                              ),
                            ),
                    ),
                    // Gradient overlay for better text visibility
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: ResponsiveHelper.spacing(context, 60),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.6),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // LIVE Badge
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: ResponsiveHelper.padding(context, horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.red,
                              Colors.red[700]!,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 20)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.4),
                              spreadRadius: 0,
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: 6),
                            Text(
                              'LIVE',
                              style: ResponsiveHelper.textStyle(
                        context,
                                fontSize: 12,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
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
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.play_arrow,
                            color: const Color(0xFF4CAF50),
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // Video Title/Info
                Padding(
                  padding: ResponsiveHelper.padding(context, all: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (video['title'] != null && video['title'] != 'No live videos yet')
                        Text(
                          video['title'] ?? '',
                          style: ResponsiveHelper.textStyle(
                        context,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                            letterSpacing: 0.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        )
                      else
                        Text(
                          'Live Video',
                          style: TextStyle(
                            fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      if (video['fruit_tag'] != null) ...[
                        SizedBox(height: ResponsiveHelper.spacing(context, 6)),
                        Container(
                          padding: ResponsiveHelper.padding(context, horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF9F9467).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 6)),
                          ),
                          child: Text(
                            video['fruit_tag'] ?? '',
                            style: ResponsiveHelper.textStyle(
                        context,
                              fontSize: 11,
                              color: const Color(0xFF5F4628),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Show Emoji Selection Dialog with Tabs (Main Fruits, Opposites, Emotions)
  void _showEmojiSelectionDialog(BuildContext context) {
    print('🎯 ========== DIALOG OPENED ==========');
    print('🎯 Current emojis count: ${controller.emojis.length}');
    
    // Performance: Only load emojis if truly empty (not just checking)
    // Don't reload if emojis are already loaded
    final hasEmojis = controller.emojis.isNotEmpty || 
                      controller.allEmojis.isNotEmpty || 
                      controller.oppositeEmojis.isNotEmpty || 
                      controller.emotionEmojis.isNotEmpty;
    
    if (!hasEmojis) {
      print('🔄 Dialog opened: Emojis empty, loading...');
      print('🔄 Calling controller.loadEmojis()...');
      controller.loadEmojis().then((_) {
        print('✅ loadEmojis() completed successfully');
        print('✅ Main Fruits: ${controller.emojis.length}');
        print('✅ Opposites: ${controller.oppositeEmojis.length}');
        print('✅ Emotions: ${controller.emotionEmojis.length}');
      }).catchError((error) {
        print('❌ loadEmojis() failed with error: $error');
        print('❌ Error type: ${error.runtimeType}');
        print('❌ Error toString: ${error.toString()}');
      });
    } else {
      print('✅ Emojis already loaded - NO RELOAD');
      print('✅ Main Fruits: ${controller.emojis.length}');
      print('✅ Opposites: ${controller.oppositeEmojis.length}');
      print('✅ Emotions: ${controller.emotionEmojis.length}');
    }
    
    print('🎯 Showing dialog with tabs...');
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 20)),
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: ResponsiveHelper.screenHeight(context) * 0.8,
              maxWidth: ResponsiveHelper.screenWidth(context) * 0.9,
            ),
            child: _EmojiSelectionDialogContent(
              controller: controller,
              dialogContext: dialogContext,
            ),
          ),
        );
      },
    );
  }

  // Build Emoji Carousel with Scroll Indicators
  Widget _buildEmojiCarousel(BuildContext context, List<Map<String, dynamic>> emojis, BuildContext dialogContext) {
    return _EmojiCarouselWidget(emojis: emojis, dialogContext: dialogContext);
  }
}

// Blog Content Widget with "more" option
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
            sourceLanguage: widget.language);
    
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

// Emoji Selection Dialog with Tabs (Main Fruits, Opposites, Emotions)
class _EmojiSelectionDialogContent extends StatefulWidget {
  final HomeController controller;
  final BuildContext dialogContext;

  const _EmojiSelectionDialogContent({
    Key? key,
    required this.controller,
    required this.dialogContext,
  }) : super(key: key);

  @override
  State<_EmojiSelectionDialogContent> createState() => _EmojiSelectionDialogContentState();
}

class _EmojiSelectionDialogContentState extends State<_EmojiSelectionDialogContent> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Padding(
          padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 16)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'How do you feel today?',
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: ResponsiveHelper.fontSize(context, mobile: 20, tablet: 24, desktop: 28),
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF8B4513),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Color(0xFF8B4513)),
                onPressed: () => Navigator.of(widget.dialogContext).pop(),
              ),
            ],
          ),
        ),
        // Tabs
        TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF8B4513),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF8B4513),
          tabs: const [
            Tab(text: 'Fruits'),
            Tab(text: 'Opposites'),
            Tab(text: 'Emotions'),
          ],
        ),
        // Tab Content
        Expanded(
          child: Obx(() {
            if (widget.controller.allEmojis.isEmpty && 
                widget.controller.emojis.isEmpty && 
                widget.controller.oppositeEmojis.isEmpty && 
                widget.controller.emotionEmojis.isEmpty) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 20)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        color: const Color(0xFF8B4513),
                      ),
                      SizedBox(height: ResponsiveHelper.spacing(context, 10)),
                      Text(
                        'Loading emojis...',
                        style: ResponsiveHelper.textStyle(
                          context,
                          fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                          color: Colors.grey,
                        ),
                      ),
                      SizedBox(height: ResponsiveHelper.spacing(context, 8)),
                      TextButton(
                        onPressed: () {
                          widget.controller.loadEmojis().catchError((error) {
                            // Log server error to console
                            print('❌ Error loading emojis: ${error.toString()}');
                            print('❌ Error Type: ${error.runtimeType}');
                            
                            Get.snackbar(
                              'Connection Issue',
                              'Unable to load emojis. Please check your internet connection and try again.',
                              backgroundColor: Colors.orange.withOpacity(0.9),
                              colorText: Colors.white,
                              duration: const Duration(seconds: 3),
                              margin: EdgeInsets.all(ResponsiveHelper.spacing(context, 16)),
                              borderRadius: ResponsiveHelper.borderRadius(context, mobile: 12),
                              icon: Icon(
                                Icons.wifi_off,
                                color: Colors.white,
                                size: ResponsiveHelper.iconSize(context, mobile: 20),
                              ),
                            );
                          });
                        },
                        child: Text(
                          'Retry',
                          style: ResponsiveHelper.textStyle(
                            context,
                            fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                            color: const Color(0xFF8B4513),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return TabBarView(
              controller: _tabController,
              children: [
                // Main Fruits Tab
                _buildFruitsTab(context),
                // Opposites Tab
                _buildOppositesTab(context),
                // Emotions Tab
                _buildEmotionsTab(context),
              ],
            );
          }),
        ),
        // Cancel Button
        Padding(
          padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 16)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(widget.dialogContext).pop(),
                child: Text(
                  'Cancel',
                  style: ResponsiveHelper.textStyle(
                    context,
                    fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFruitsTab(BuildContext context) {
    if (widget.controller.emojis.isEmpty) {
      return Center(
        child: Text(
          'No fruits available',
          style: ResponsiveHelper.textStyle(
            context,
            fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
            color: Colors.grey,
          ),
        ),
      );
    }

    return _EmojiCarouselWidget(
      emojis: widget.controller.emojis,
      dialogContext: widget.dialogContext,
    );
  }

  Widget _buildOppositesTab(BuildContext context) {
    if (widget.controller.oppositeEmojis.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sentiment_dissatisfied_outlined,
              size: ResponsiveHelper.iconSize(context, mobile: 48),
              color: Colors.grey[400],
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 12)),
            Text(
              'No opposite emotions available',
              style: ResponsiveHelper.textStyle(
                context,
                fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return _EmojiCarouselWidget(
      emojis: widget.controller.oppositeEmojis,
      dialogContext: widget.dialogContext,
    );
  }

  Widget _buildEmotionsTab(BuildContext context) {
    if (widget.controller.emotionEmojis.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_outline,
              size: ResponsiveHelper.iconSize(context, mobile: 48),
              color: Colors.grey[400],
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 12)),
            Text(
              'No spiritual emotions available',
              style: ResponsiveHelper.textStyle(
                context,
                fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return _EmojiCarouselWidget(
      emojis: widget.controller.emotionEmojis,
      dialogContext: widget.dialogContext,
    );
  }
}

// Separate StatefulWidget for Emoji Carousel to properly manage ScrollController
class _EmojiCarouselWidget extends StatefulWidget {
  final List<Map<String, dynamic>> emojis;
  final BuildContext dialogContext;

  const _EmojiCarouselWidget({
    Key? key,
    required this.emojis,
    required this.dialogContext,
  }) : super(key: key);

  @override
  _EmojiCarouselWidgetState createState() => _EmojiCarouselWidgetState();
}

class _EmojiCarouselWidgetState extends State<_EmojiCarouselWidget> {
  late PageController _pageController;
  int _currentPage = 0;
  bool _isDisposing = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _pageController.addListener(_updatePage);
  }

  @override
  void dispose() {
    _isDisposing = true;
    _pageController.removeListener(_updatePage);
    _pageController.dispose();
    super.dispose();
  }

  void _updatePage() {
    if (_isDisposing || !mounted) return;
    if (_pageController.hasClients) {
      final newPage = _pageController.page?.round() ?? 0;
      if (newPage != _currentPage) {
        setState(() {
          _currentPage = newPage;
        });
      }
    }
  }

  void _goToPreviousPage() {
    if (_pageController.hasClients && _currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToNextPage() {
    if (_pageController.hasClients && _currentPage < widget.emojis.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Performance: Only log on first build or when emojis change significantly
    if (_currentPage == 0 && widget.emojis.isNotEmpty) {
      print('🎨 _EmojiCarouselWidget build: emojis.length = ${widget.emojis.length}');
    }
    if (widget.emojis.isEmpty) {
      print('⚠️ _EmojiCarouselWidget: Emojis list is empty, showing empty state');
      return Center(
        child: Padding(
          padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.sentiment_dissatisfied,
                size: ResponsiveHelper.iconSize(context, mobile: 48),
                color: Colors.grey[400],
              ),
              SizedBox(height: ResponsiveHelper.spacing(context, 12)),
              Text(
                'No fruits available',
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: ResponsiveHelper.spacing(context, 8)),
              Text(
                'Please check your connection or try again later',
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final bool canGoLeft = _currentPage > 0;
    final bool canGoRight = _currentPage < widget.emojis.length - 1;

    return Column(
      children: [
        // Fruit Carousel - One at a time
        Stack(
          children: [
            SizedBox(
              height: ResponsiveHelper.screenHeight(context) * 0.5,
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.emojis.length,
                physics: const BouncingScrollPhysics(), // Enable swipe
                onPageChanged: (index) {
                  if (mounted && !_isDisposing) {
                    setState(() {
                      _currentPage = index;
                    });
                    print('📄 Page changed to: $index (Total: ${widget.emojis.length})');
                  }
                },
                itemBuilder: (context, index) {
                  final emoji = widget.emojis[index];
                  // Performance: Only log on first build, not every rebuild
                  if (index == 0 && _currentPage == 0) {
                    print('🎨 Building carousel pages: total=${widget.emojis.length}');
                  }
                  return GestureDetector(
                    onTap: () async {
                      // Record emoji usage
                      try {
                        final userId = await UserStorage.getUserId();
                        if (userId == null) {
                          if (widget.dialogContext.mounted) {
                            Navigator.of(widget.dialogContext).pop();
                            Get.snackbar(
                              'Login Required',
                              'Please login to record your feeling',
                              snackPosition: SnackPosition.BOTTOM,
                              backgroundColor: Colors.orange.withOpacity(0.8),
                              colorText: Colors.white,
                              duration: const Duration(seconds: 3),
                            );
                          }
                          return;
                        }

                        // Get emoji value - Priority: emoji_char > code > image_url (last resort)
                        final emojiChar = emoji['emoji_char'] as String?;
                        final emojiCode = emoji['code'] as String?;
                        final imageUrl = emoji['image_url'] as String?;

                        print('📤 Sending fruit to API:');
                        print('   Name: ${emoji['name']}');
                        print('   Emoji Char: $emojiChar');
                        print('   Code: $emojiCode');
                        print('   Image URL: $imageUrl');

                        // Priority: emoji_char > code > image_url (last resort)
                        String emojiValue = '';
                        if (emojiChar != null && emojiChar.toString().trim().isNotEmpty) {
                          emojiValue = emojiChar.toString().trim();
                          print('   ✅ Using emoji_char: $emojiValue');
                        } else if (emojiCode != null && emojiCode.toString().trim().isNotEmpty) {
                          emojiValue = emojiCode.toString().trim();
                          print('   ✅ Using code: $emojiValue');
                        } else if (imageUrl != null && imageUrl.toString().trim().isNotEmpty) {
                          // Last resort: use image URL (but this should be avoided)
                          emojiValue = imageUrl.toString().trim();
                          print('   ⚠️ Using image_url as fallback: $emojiValue');
                        }

                        if (emojiValue.isEmpty) {
                          print('   ❌ ERROR: emoji_char, code, and image_url all empty!');
                          if (widget.dialogContext.mounted) {
                            Navigator.of(widget.dialogContext).pop();
                            // Log server error to console
                            print('❌ Invalid fruit data from server');
                            // print('❌ Fruit data: $fruit');
                            
                            Get.snackbar(
                              'Data Error',
                              'Unable to process fruit selection. Please try again.',
                              snackPosition: SnackPosition.BOTTOM,
                              backgroundColor: Colors.red.withOpacity(0.9),
                              colorText: Colors.white,
                              duration: const Duration(seconds: 3),
                              margin: EdgeInsets.all(ResponsiveHelper.spacing(context, 16)),
                              borderRadius: ResponsiveHelper.borderRadius(context, mobile: 12),
                              icon: Icon(
                                Icons.error_outline,
                                color: Colors.white,
                                size: ResponsiveHelper.iconSize(context, mobile: 20),
                              ),
                            );
                          }
                          return;
                        }

                        try {
                          // STEP 1: Update backend FIRST (replace existing feeling)
                          print('📤 Step 1: Updating backend with new feeling (will replace existing)...');
                          await EmojisService.useEmoji(
                            userId: userId,
                            emoji: emojiValue,
                            // postType and postId are NULL for general feeling - this ensures it REPLACES existing
                          );
                          print('✅ Backend updated successfully - feeling replaced in database');
                          
                          // STEP 2: Wait a bit for backend to process
                          await Future.delayed(const Duration(milliseconds: 500));
                          
                          // STEP 3: Close dialog
                          if (widget.dialogContext.mounted) {
                            Navigator.of(widget.dialogContext).pop();
                          }
                          
                          // STEP 4: Update UI with new feeling from backend
                          final controller = Get.find<HomeController>();
                          
                          // Update optimistically with emoji data for instant display
                          // This already saves to local storage with correct emoji_details
                          await controller.updateUserFeeling(emojiValue, emojiData: emoji);
                          print('✅ UI updated optimistically with emoji: $emojiValue');
                          print('✅ Saved to local storage with emoji_details: ${emoji['name']}');
                          
                          // STEP 5: Don't reload from API immediately - trust local storage
                          // The local storage already has the correct data with proper emoji_details
                          // Reloading from API might return old/wrong data (like ID instead of code)
                          // and overwrite the correct local storage value
                          print('✅ Skipping API reload - local storage has correct data');
                          print('✅ UI should show the selected fruit: ${emoji['name']}');
                          
                          // Force UI refresh to ensure update is visible
                          controller.userFeeling.refresh();
                          print('✅ Forced UI refresh');
                          
                          // Show success message
                          final userName = controller.userName.value;
                          Get.snackbar(
                            'Feeling Updated',
                            userName.isNotEmpty 
                                ? '$userName ka feeling update ho gaya!'
                                : 'Your feeling has been updated!',
                            snackPosition: SnackPosition.BOTTOM,
                            backgroundColor: Colors.green.withOpacity(0.8),
                            colorText: Colors.white,
                            duration: const Duration(seconds: 2),
                          );
                        } catch (e) {
                          print('❌ Error sending fruit: $e');
                          if (widget.dialogContext.mounted) {
                            Navigator.of(widget.dialogContext).pop();
                          }
                          // Still try to update feeling
                          try {
                            final controller = Get.find<HomeController>();
                            await controller.updateUserFeeling(emojiValue);
                            await Future.delayed(const Duration(milliseconds: 500));
                            await controller.loadUserFeeling();
                          } catch (updateError) {
                            print('⚠️ Error updating feeling: $updateError');
                          }
                          // Log server error to console
                          print('❌ Error recording feeling: ${e.toString()}');
                          print('❌ Error Type: ${e.runtimeType}');
                          
                          Get.snackbar(
                            'Unable to Save',
                            'Failed to record your feeling. Please try again.',
                            snackPosition: SnackPosition.BOTTOM,
                            backgroundColor: Colors.red.withOpacity(0.9),
                            colorText: Colors.white,
                            duration: const Duration(seconds: 3),
                            margin: EdgeInsets.all(ResponsiveHelper.spacing(context, 16)),
                            borderRadius: ResponsiveHelper.borderRadius(context, mobile: 12),
                            icon: Icon(
                              Icons.error_outline,
                              color: Colors.white,
                              size: ResponsiveHelper.iconSize(context, mobile: 20),
                            ),
                          );
                        }
                      } catch (e) {
                        if (widget.dialogContext.mounted) {
                          Navigator.of(widget.dialogContext).pop();
                          // Log server error to console
                          print('❌ Error recording feeling: ${e.toString()}');
                          print('❌ Error Type: ${e.runtimeType}');
                          
                          Get.snackbar(
                            'Unable to Save',
                            'Failed to record your feeling. Please try again.',
                            snackPosition: SnackPosition.BOTTOM,
                            backgroundColor: Colors.red.withOpacity(0.9),
                            colorText: Colors.white,
                            duration: const Duration(seconds: 3),
                            margin: EdgeInsets.all(ResponsiveHelper.spacing(context, 16)),
                            borderRadius: ResponsiveHelper.borderRadius(context, mobile: 12),
                            icon: Icon(
                              Icons.error_outline,
                              color: Colors.white,
                              size: ResponsiveHelper.iconSize(context, mobile: 20),
                            ),
                          );
                        }
                      }
                    },
                    child: Container(
                      margin: EdgeInsets.symmetric(
                        horizontal: ResponsiveHelper.spacing(context, 20),
                        vertical: ResponsiveHelper.spacing(context, 10),
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEECE2),
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 20)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Fruit Image - Larger display
                          Expanded(
                            child: Center(
                            child: Container(
                              width: ResponsiveHelper.screenWidth(context) * 0.5,
                              height: ResponsiveHelper.screenWidth(context) * 0.5,
                              padding: ResponsiveHelper.padding(context, all: 20),
                              child: HomeScreen.buildEmojiDisplay(
                                context, 
                                emoji,
                                size: ResponsiveHelper.screenWidth(context) * 0.4,
                              ),
                            ),
                            ),
                          ),
                          // Fruit Name
                          Padding(
                            padding: ResponsiveHelper.padding(context, horizontal: 20, vertical: 15),
                            child: Text(
                              emoji['name'] ?? 'Fruit',
                              style: ResponsiveHelper.textStyle(
                                context,
                                fontSize: ResponsiveHelper.fontSize(context, mobile: 24, tablet: 28, desktop: 32),
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF8B4513),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          // Description if available
                          if (emoji['description'] != null && emoji['description'].toString().isNotEmpty)
                            Padding(
                              padding: ResponsiveHelper.padding(context, horizontal: 20, vertical: 5),
                              child: Text(
                                emoji['description'].toString(),
                                style: ResponsiveHelper.textStyle(
                                  context,
                                  fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 16, desktop: 18),
                                  color: Colors.grey[600],
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            // Left Arrow Button
            if (canGoLeft)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: GestureDetector(
                  onTap: _goToPreviousPage,
                  child: Container(
                    width: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.white.withOpacity(0.9),
                          Colors.white.withOpacity(0.0),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Container(
                        padding: ResponsiveHelper.padding(
                          context,
                          all: ResponsiveHelper.isMobile(context) ? 6 : 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.8),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 5,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.chevron_left,
                          color: AppTheme.iconscolor,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            // Right Arrow Button
            if (canGoRight)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: GestureDetector(
                  onTap: _goToNextPage,
                  child: Container(
                    width: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft,
                        colors: [
                          Colors.white.withOpacity(0.9),
                          Colors.white.withOpacity(0.0),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Container(
                        padding: ResponsiveHelper.padding(
                          context,
                          all: ResponsiveHelper.isMobile(context) ? 6 : 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.8),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 5,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.chevron_right,
                          color: AppTheme.iconscolor,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        // Page Indicator
        SizedBox(height: ResponsiveHelper.spacing(context, 10)),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.emojis.length,
            (index) => Container(
              width: 8,
              height: 8,
              margin: EdgeInsets.symmetric(
                horizontal: ResponsiveHelper.spacing(context, 4),
              ),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _currentPage == index
                    ? const Color(0xFF8B4513)
                    : Colors.grey[300],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _VideoPlayerThumbnail extends StatefulWidget {
  final String videoUrl;

  const _VideoPlayerThumbnail({Key? key, required this.videoUrl}) : super(key: key);

  @override
  _VideoPlayerThumbnailState createState() => _VideoPlayerThumbnailState();
}



class _VideoPlayerThumbnailState extends State<_VideoPlayerThumbnail> with WidgetsBindingObserver {
  late VideoPlayerController _controller;
  bool _isPlaying = false;
  bool _showVideo = false; // New variable to control showing video or thumbnail

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (mounted) {
        setState(() {});
        }
      }).catchError((error) {
        print('Error initializing video: $error');
      });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // Pause video when app goes to background
      if (_controller.value.isInitialized && _isPlaying) {
        _controller.pause();
        if (mounted) {
          setState(() {
            _isPlaying = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: ResponsiveHelper.imageWidth(context, mobile: 200),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 10)),
      ),
      child: _controller.value.isInitialized
          ? Stack(
              alignment: Alignment.center,
              children: [
                if (_showVideo) // Conditionally show VideoPlayer
                  AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  ),
                Positioned.fill(
                  child: Center(
                    child: IconButton(
                      icon: Icon(
                        _isPlaying ? Icons.pause_circle : Icons.play_circle,
                        color: Colors.white.withOpacity(0.8),
                        size: ResponsiveHelper.iconSize(context, mobile: 32),
                      ),
                      onPressed: () {
                        setState(() {
                          _showVideo = true; // Show video when play is pressed
                          _isPlaying ? _controller.pause() : _controller.play();
                          _isPlaying = !_isPlaying;
                        });
                      },
                    ),
                  ),
                ),
                if (!_showVideo) // Show overlay text and icon only when thumbnail is visible
                  Positioned(
                    top: ResponsiveHelper.spacing(context, 5),
                    left: ResponsiveHelper.spacing(context, 5),
                    child: Container(
                      padding: ResponsiveHelper.padding(context,
                          horizontal: 4,
                          vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 5)),
                      ),
                      child: Text(
                        'Video',
                        style: ResponsiveHelper.textStyle(
                          context,
                          color: Colors.white,
                          fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                if (!_showVideo)
                  Positioned(
                    bottom: ResponsiveHelper.spacing(context, 5),
                    left: ResponsiveHelper.spacing(context, 5),
                    child: Container(
                      padding: ResponsiveHelper.padding(context,
                          horizontal: 4,
                          vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 5)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.add_circle,
                            color: Colors.green,
                            size: ResponsiveHelper.iconSize(context, mobile: 12),
                          ),
                          SizedBox(width: ResponsiveHelper.spacing(context, 3)),
                          Text(
                            'Kindness Moment',
                            style: ResponsiveHelper.textStyle(
                              context,
                              color: Colors.white,
                              fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (!_showVideo)
                  Positioned(
                    bottom: ResponsiveHelper.spacing(context, 5),
                    right: ResponsiveHelper.spacing(context, 5),
                    child: CircleAvatar(
                      radius: ResponsiveHelper.borderRadius(context, mobile: 15),
                      backgroundColor: Colors.white.withOpacity(0.8),
                      child: Icon(
                        Icons.person, // Placeholder for the small icon
                        color: Colors.brown,
                        size: ResponsiveHelper.iconSize(context, mobile: 12),
                      ),
                    ),
                  ),
              ],
            )
          : Center(
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            ),
    );
  }
}

// Feed Carousel Widget
class _FeedCarouselWidget extends StatefulWidget {
  final List<Map<String, dynamic>> feedItems;
  final Widget Function(BuildContext, Map<String, dynamic>) buildPrayerPost;
  final Widget Function(BuildContext, Map<String, dynamic>) buildBlogPost;
  final Widget Function(BuildContext, Map<String, dynamic>) buildVideoPost;
  final Widget Function(BuildContext, Map<String, dynamic>) buildStoryPost;

  const _FeedCarouselWidget({
    required this.feedItems,
    required this.buildPrayerPost,
    required this.buildBlogPost,
    required this.buildVideoPost,
    required this.buildStoryPost,
  });

  @override
  State<_FeedCarouselWidget> createState() => _FeedCarouselWidgetState();
}

class _FeedCarouselWidgetState extends State<_FeedCarouselWidget> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.95);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildPostCard(BuildContext context, Map<String, dynamic> item) {
    switch (item['type']) {
      case 'prayer':
        return widget.buildPrayerPost(context, item['data']);
      case 'blog':
        return widget.buildBlogPost(context, item['data']);
      case 'video':
        return widget.buildVideoPost(context, item['data']);
      case 'story':
        return widget.buildStoryPost(context, item['data']);
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: ResponsiveHelper.padding(context, bottom: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Feed Carousel Container - Reduced Height
          Container(
            height: ResponsiveHelper.safeHeight(context, mobile: 380, tablet: 450, desktop: 520),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  spreadRadius: 0,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 20)),
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: widget.feedItems.length,
                itemBuilder: (context, index) {
                  final item = widget.feedItems[index];
                  return Padding(
                    padding: ResponsiveHelper.padding(context, horizontal: 10, vertical: 8),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: IntrinsicHeight(
                              child: _buildPostCard(context, item),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ),
          SizedBox(height: ResponsiveHelper.spacing(context, 16)),
          // Page Indicators and View All Button - Professional Design
          Padding(
            padding: ResponsiveHelper.padding(context, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Page Indicators
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      widget.feedItems.length > 5 ? 5 : widget.feedItems.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        width: ResponsiveHelper.spacing(context, _currentPage == index ? 26 : 8),
                        height: ResponsiveHelper.spacing(context, 8),
                        margin: ResponsiveHelper.padding(context, horizontal: 3),
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? const Color(0xFF5F4628)
                              : Colors.grey[300],
                          borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 4)),
                          boxShadow: _currentPage == index
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF5F4628).withOpacity(0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
                if (widget.feedItems.length > 1) ...[
                  SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                  Flexible(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          try {
                            final prayersController = Get.find<PrayersController>();
                            prayersController.filterUserId.value = 0;
                            // Performance: Only load if data doesn't exist
                            if (prayersController.prayers.isEmpty) {
                              prayersController.loadPrayers(refresh: true);
                            }
                          } catch (e) {
                            Get.put(PrayersController());
                          }
                          Get.toNamed(Routes.PRAYER_REQUESTS);
                        },
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 25)),
                        child: Container(
                          padding: ResponsiveHelper.padding(
                            context,
                            horizontal: ResponsiveHelper.fontSize(context, mobile: 18, tablet: 20, desktop: 22),
                            vertical: ResponsiveHelper.fontSize(context, mobile: 10, tablet: 12, desktop: 14),
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFF5F4628),
                                const Color(0xFF9F9467),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 25)),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF5F4628).withOpacity(0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  'View All',
                                  style: ResponsiveHelper.textStyle(
                                    context,
                                    fontSize: 14,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.3,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                              Icon(
                                Icons.arrow_forward_rounded,
                                color: Colors.white,
                                size: ResponsiveHelper.iconSize(context, mobile: 18),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Prayers Carousel Widget
class _PrayersCarouselWidget extends StatefulWidget {
  final List<Map<String, dynamic>> prayers;
  final Widget Function(BuildContext, Map<String, dynamic>) buildPrayerPost;

  const _PrayersCarouselWidget({
    required this.prayers,
    required this.buildPrayerPost,
  });

  @override
  State<_PrayersCarouselWidget> createState() => _PrayersCarouselWidgetState();
}

class _PrayersCarouselWidgetState extends State<_PrayersCarouselWidget> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.95);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: ResponsiveHelper.padding(context, horizontal: 16, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: ResponsiveHelper.padding(context, all: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF5F4628),
                          const Color(0xFF9F9467),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 10)),
                    ),
                    child: Icon(
                      Icons.favorite_rounded,
                      color: Colors.white,
                      size: ResponsiveHelper.iconSize(context, mobile: 20),
                    ),
                  ),
                  SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                  Text(
                    'Prayer Requests',
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: ResponsiveHelper.fontSize(context, mobile: 20, tablet: 22, desktop: 24),
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF5F4628),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  try {
                    final prayersController = Get.find<PrayersController>();
                    prayersController.filterUserId.value = 0;
                    prayersController.loadPrayers(refresh: true);
                  } catch (e) {
                    Get.put(PrayersController());
                  }
                  Get.toNamed(Routes.PRAYER_REQUESTS);
                },
                child: Text(
                  'View All',
                  style: ResponsiveHelper.textStyle(
                    context,
                    fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: ResponsiveHelper.spacing(context, 12)),
          // Prayer Carousel
          Container(
            height: ResponsiveHelper.safeHeight(context, mobile: 280, tablet: 320, desktop: 360),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  spreadRadius: 0,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 20)),
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: widget.prayers.length,
                itemBuilder: (context, index) {
                  final prayer = widget.prayers[index];
                  return Padding(
                    padding: ResponsiveHelper.padding(context, horizontal: 10, vertical: 8),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: widget.buildPrayerPost(context, prayer),
                    ),
                  );
                },
              ),
            ),
          ),
          SizedBox(height: ResponsiveHelper.spacing(context, 12)),
          // Page Indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.prayers.length > 5 ? 5 : widget.prayers.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                width: ResponsiveHelper.spacing(context, _currentPage == index ? 24 : 8),
                height: ResponsiveHelper.spacing(context, 8),
                margin: ResponsiveHelper.padding(context, horizontal: 3),
                decoration: BoxDecoration(
                  color: _currentPage == index
                      ? const Color(0xFF5F4628)
                      : Colors.grey[300],
                  borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 4)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Blogs Carousel Widget
class _BlogsCarouselWidget extends StatefulWidget {
  final List<Map<String, dynamic>> blogs;
  final Widget Function(BuildContext, Map<String, dynamic>) buildBlogPost;

  const _BlogsCarouselWidget({
    required this.blogs,
    required this.buildBlogPost,
  });

  @override
  State<_BlogsCarouselWidget> createState() => _BlogsCarouselWidgetState();
}

class _BlogsCarouselWidgetState extends State<_BlogsCarouselWidget> {
  @override
  Widget build(BuildContext context) {
    if (widget.blogs.isEmpty) return const SizedBox.shrink();
    
    // Calculate blog width: 2 full blogs + 10% of 3rd = 2.1 blogs visible (Responsive)
    final screenWidth = ResponsiveHelper.screenWidth(context);
    final horizontalPadding = ResponsiveHelper.spacing(
      context, 
      ResponsiveHelper.isMobile(context) ? 14 : 16,
    ) * 2; // Left + Right padding
    final spacingBetween = ResponsiveHelper.spacing(
      context,
      ResponsiveHelper.isMobile(context) ? 10 : 12,
    );
    final availableWidth = screenWidth - horizontalPadding;
    final blogWidth = (availableWidth - spacingBetween) / 2.1; // 2 full + 10% of 3rd
    
    return Container(
      margin: ResponsiveHelper.padding(
        context, 
        horizontal: ResponsiveHelper.isMobile(context) ? 0 : 4,
        bottom: ResponsiveHelper.isMobile(context) ? 8 : 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Section Header
          Padding(
            padding: ResponsiveHelper.padding(
              context, 
              horizontal: ResponsiveHelper.isMobile(context) ? 14 : 16,
              bottom: ResponsiveHelper.isMobile(context) ? 10 : 12,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: ResponsiveHelper.padding(context, all: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 10)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.article_rounded,
                        color: AppTheme.iconscolor,
                        size: ResponsiveHelper.iconSize(context, mobile: 20),
                      ),
                    ),
                    SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                    Text(
                      'Blogs',
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: ResponsiveHelper.fontSize(context, mobile: 20, tablet: 22, desktop: 24),
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    try {
                      final blogsController = Get.find<BlogsController>();
                      blogsController.filterUserId.value = 0;
                      // Performance: Only refresh if needed
          if (blogsController.blogs.isEmpty) {
            blogsController.loadBlogs(refresh: true);
          }
                    } catch (e) {
                      Get.put(BlogsController());
                    }
                    Get.toNamed(Routes.BLOGGER_ZONE);
                  },
                  child: Text(
                    'View All',
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Blogs Horizontal Scroll - 2 full + 10% of 3rd visible
          // Height increased to accommodate proper spacing between elements
          SizedBox(
            height: ResponsiveHelper.safeHeight(
              context,
              mobile: ResponsiveHelper.screenHeight(context) * 0.24,  // Increased from 0.20 to accommodate spacing
              tablet: ResponsiveHelper.screenHeight(context) * 0.26,  // Increased from 0.22
              desktop: ResponsiveHelper.screenHeight(context) * 0.28,  // Increased from 0.24
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: ResponsiveHelper.padding(
                context, 
                horizontal: ResponsiveHelper.isMobile(context) ? 14 : 16,
              ),
              itemCount: widget.blogs.length,
              itemBuilder: (context, index) {
                final blog = widget.blogs[index];
                return Container(
                  width: blogWidth,
                  constraints: BoxConstraints(
                    maxWidth: blogWidth,
                    minWidth: blogWidth,
                  ),
                  margin: EdgeInsets.only(
                    right: index < widget.blogs.length - 1 ? spacingBetween : 0,
                  ),
                  child: widget.buildBlogPost(context, blog),
                );
              },
            ),
          ),
          // Swipe Indicator (if more than 2 blogs)
          if (widget.blogs.length > 2)
            Padding(
              padding: ResponsiveHelper.padding(context, top: 4),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.swipe_left_alt,
                      size: ResponsiveHelper.iconSize(context, mobile: 16),
                      color: Colors.grey[600],
                    ),
                    SizedBox(width: ResponsiveHelper.spacing(context, 6)),
                    Text(
                      'Swipe to see more blogs',
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: ResponsiveHelper.fontSize(context, mobile: 11, tablet: 12, desktop: 13),
                        color: Colors.grey[600],
                      ).copyWith(fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Videos Carousel Widget - 3 Vertical Panels Side-by-Side
class _VideosCarouselWidget extends StatefulWidget {
  final List<Map<String, dynamic>> videos;

  const _VideosCarouselWidget({required this.videos});

  @override
  State<_VideosCarouselWidget> createState() => _VideosCarouselWidgetState();
}

class _VideosCarouselWidgetState extends State<_VideosCarouselWidget> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.95);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String? _getVideoThumbnail(Map<String, dynamic> video) {
    // Priority 1: Check thumbnail_path (from database - generated during upload)
    if (video['thumbnail_path'] != null && (video['thumbnail_path'] as String).isNotEmpty) {
      final thumbnailPath = video['thumbnail_path'] as String;
      if (!thumbnailPath.startsWith('http')) {
        return 'https://fruitofthespirit.templateforwebsites.com/$thumbnailPath';
      }
      return thumbnailPath;
    }
    
    // Priority 2: Check thumbnail (legacy field)
    if (video['thumbnail'] != null && (video['thumbnail'] as String).isNotEmpty) {
      final thumbnail = video['thumbnail'] as String;
      if (!thumbnail.startsWith('http')) {
        return 'https://fruitofthespirit.templateforwebsites.com/$thumbnail';
      }
      return thumbnail;
    }
    
    // Priority 3: Check if file_path is an image (not a video)
    if (video['file_path'] != null) {
      final filePath = video['file_path'].toString();
      final lowerPath = filePath.toLowerCase();
      if (!lowerPath.endsWith('.mp4') &&
          !lowerPath.endsWith('.mov') &&
          !lowerPath.endsWith('.avi') &&
          !lowerPath.endsWith('.webm') &&
          !lowerPath.endsWith('.mkv')) {
        if (!filePath.startsWith('http')) {
          return 'https://fruitofthespirit.templateforwebsites.com/$filePath';
        }
        return filePath;
      }
    }
    
    // Last resort: Try to use first frame of video or return null to show loading
    // Don't use placeholder - let the UI handle missing thumbnails gracefully
    return null;
  }

  Widget _buildVerticalVideoCard(BuildContext context, Map<String, dynamic> video, int index) {
    final thumbnail = _getVideoThumbnail(video);
    final videoUrl = video['file_path'] != null
        ? 'https://fruitofthespirit.templateforwebsites.com/${video['file_path']}'
        : null;

    return GestureDetector(
      onTap: () => Get.toNamed(Routes.VIDEO_DETAILS, arguments: video['id']),
      child: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12, tablet: 14, desktop: 16)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: ResponsiveHelper.spacing(context, 15),
              offset: Offset(0, ResponsiveHelper.spacing(context, 5)),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12, tablet: 14, desktop: 16)),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Video Thumbnail - Proper fit to prevent stretching
              thumbnail != null
                  ? CachedImage(
                      imageUrl: thumbnail,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      errorWidget: videoUrl != null
                          ? VideoFrameThumbnail(
                              videoUrl: videoUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            )
                          : Container(
                              width: double.infinity,
                              height: double.infinity,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppTheme.themeColor,
                                    AppTheme.primaryColor.withOpacity(0.3),
                                  ],
                                ),
                              ),
                              child: Icon(
                                Icons.video_library_rounded,
                                size: ResponsiveHelper.iconSize(context, mobile: 32, tablet: 40, desktop: 48),
                                color: AppTheme.primaryColor,
                              ),
                            ),
                    )
                  : videoUrl != null
                      ? VideoFrameThumbnail(
                          videoUrl: videoUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        )
                      : Container(
                          width: double.infinity,
                          height: double.infinity,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppTheme.themeColor,
                                AppTheme.primaryColor.withOpacity(0.3),
                              ],
                            ),
                          ),
                          child: Icon(
                            Icons.video_library_rounded,
                            size: ResponsiveHelper.iconSize(context, mobile: 32, tablet: 40, desktop: 48),
                            color: AppTheme.primaryColor,
                          ),
                        ),
              // Gradient Overlay for better visibility
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: ResponsiveHelper.imageHeight(context, mobile: 60, tablet: 80, desktop: 100),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                ),
              ),
              // Play Button - Centered
              Positioned.fill(
                child: Center(
                  child: Container(
                    padding: ResponsiveHelper.padding(context, all: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: ResponsiveHelper.spacing(context, 12),
                          offset: Offset(0, ResponsiveHelper.spacing(context, 4)),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.play_circle_fill,
                      color: const Color(0xFF4CAF50),
                      size: ResponsiveHelper.iconSize(context, mobile: 40, tablet: 50, desktop: 60),
                    ),
                  ),
                ),
              ),
              // Video Title (if available) - Bottom
              if (video['title'] != null && video['title'].toString().isNotEmpty)
                Positioned(
                  bottom: ResponsiveHelper.spacing(context, 10),
                  left: ResponsiveHelper.spacing(context, 10),
                  right: ResponsiveHelper.spacing(context, 10),
                  child: Text(
                    video['title'].toString(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              // Video Preview (if first video in first set) - Auto play small part
              if (index == 0 && videoUrl != null && videoUrl.toLowerCase().endsWith('.mp4'))
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.3,
                    child: _VideoPreviewWidget(videoUrl: videoUrl),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Group videos into sets of 3
    final videoSets = <List<Map<String, dynamic>>>[];
    for (int i = 0; i < widget.videos.length; i += 3) {
      final end = (i + 3 < widget.videos.length) ? i + 3 : widget.videos.length;
      videoSets.add(widget.videos.sublist(i, end));
    }

    if (videoSets.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: ResponsiveHelper.padding(context, horizontal: 16, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: ResponsiveHelper.padding(context, all: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF5F4628),
                          const Color(0xFF9F9467),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF5F4628).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.video_library_rounded,
                      color: Colors.white,
                      size: ResponsiveHelper.iconSize(context, mobile: 22),
                    ),
                  ),
                  SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                  Text(
                    'Videos',
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: ResponsiveHelper.fontSize(context, mobile: 20, tablet: 22, desktop: 24),
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF5F4628),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => Get.toNamed(Routes.VIDEOS),
                child: Text(
                  'View All',
                  style: ResponsiveHelper.textStyle(
                    context,
                    fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                    color: const Color(0xFF4CAF50),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: ResponsiveHelper.spacing(context, 16)),
          // 3 Vertical Panels Side-by-Side
          SizedBox(
            height: ResponsiveHelper.imageHeight(
              context,
              mobile: 240, // Further reduced for mobile
              tablet: 300,
              desktop: 360,
            ),
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemCount: videoSets.length,
              itemBuilder: (context, pageIndex) {
                final videoSet = videoSets[pageIndex];
                
                return Padding(
                  padding: ResponsiveHelper.padding(context, horizontal: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // First Video Panel
                      Expanded(
                        child: Padding(
                          padding: ResponsiveHelper.padding(
                            context,
                            right: ResponsiveHelper.spacing(context, 5),
                          ),
                          child: videoSet.isNotEmpty
                              ? _buildVerticalVideoCard(context, videoSet[0], pageIndex * 3)
                              : Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12, tablet: 14, desktop: 16)),
                                  ),
                                ),
                        ),
                      ),
                      // Second Video Panel
                      Expanded(
                        child: Padding(
                          padding: ResponsiveHelper.padding(
                            context,
                            horizontal: ResponsiveHelper.spacing(context, 5),
                          ),
                          child: videoSet.length > 1
                              ? _buildVerticalVideoCard(context, videoSet[1], pageIndex * 3 + 1)
                              : Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12, tablet: 14, desktop: 16)),
                                  ),
                                ),
                        ),
                      ),
                      // Third Video Panel
                      Expanded(
                        child: Padding(
                          padding: ResponsiveHelper.padding(
                            context,
                            left: ResponsiveHelper.spacing(context, 5),
                          ),
                          child: videoSet.length > 2
                              ? _buildVerticalVideoCard(context, videoSet[2], pageIndex * 3 + 2)
                              : Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12, tablet: 14, desktop: 16)),
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          SizedBox(height: ResponsiveHelper.spacing(context, 16)),
          // Page Indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              videoSets.length > 5 ? 5 : videoSets.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                width: ResponsiveHelper.spacing(context, _currentPage == index ? 24 : 8),
                height: ResponsiveHelper.spacing(context, 8),
                margin: ResponsiveHelper.padding(context, horizontal: 4),
                decoration: BoxDecoration(
                  color: _currentPage == index
                      ? const Color(0xFF4CAF50)
                      : Colors.grey[300],
                  borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 4)),
                  boxShadow: _currentPage == index
                      ? [
                          BoxShadow(
                            color: const Color(0xFF4CAF50).withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Expandable Feel Section Widget
class _ExpandableFeelSection extends StatefulWidget {
  final HomeController controller;

  const _ExpandableFeelSection({required this.controller});

  @override
  State<_ExpandableFeelSection> createState() => _ExpandableFeelSectionState();
}

class _ExpandableFeelSectionState extends State<_ExpandableFeelSection> {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Access all observables to ensure Obx rebuilds when any changes
      final userFeeling = widget.controller.userFeeling.value;
      final userName = widget.controller.userName.value;
      final currentUserId = widget.controller.userId.value;
      
      // Debug logging
      print('🔄 Obx rebuild triggered - userFeeling: ${userFeeling != null ? "exists" : "null"}');
      if (userFeeling != null) {
        print('  - emoji: ${userFeeling['emoji']}');
        print('  - emoji_details: ${userFeeling['emoji_details'] != null ? "exists" : "null"}');
      }
      
      final hasFeeling = userFeeling != null && userFeeling['emoji'] != null;
      final emojiDetails = hasFeeling ? userFeeling['emoji_details'] as Map<String, dynamic>? : null;
      // Check if this is current user's feeling - don't show name to current user
      final isCurrentUser = hasFeeling && userFeeling['user_id'] != null && userFeeling['user_id'] == currentUserId;
      
      return Container(
        margin: EdgeInsets.symmetric(
          horizontal: ResponsiveHelper.isMobile(context)
              ? ResponsiveHelper.spacing(context, 16)
              : ResponsiveHelper.isTablet(context)
                  ? ResponsiveHelper.spacing(context, 20)
                  : ResponsiveHelper.spacing(context, 24),
          vertical: ResponsiveHelper.isMobile(context)
              ? ResponsiveHelper.spacing(context, 8)
              : ResponsiveHelper.isTablet(context)
                  ? ResponsiveHelper.spacing(context, 10)
                  : ResponsiveHelper.spacing(context, 12),
        ),
        child: Material(
          color: Colors.transparent,
          elevation: 0,
          borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12, tablet: 14, desktop: 16)),
          child: InkWell(
            onTap: () {
              // Navigate to fruits screen instead of showing dialog
              Get.toNamed(
                Routes.FRUITS
              );
            },
            borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12, tablet: 14, desktop: 16)),
            child: Container(
              padding: ResponsiveHelper.padding(
                context,
                horizontal: ResponsiveHelper.isMobile(context)
                    ? ResponsiveHelper.spacing(context, 12)
                    : ResponsiveHelper.isTablet(context)
                    ? ResponsiveHelper.spacing(context, 16)
                        : ResponsiveHelper.spacing(context, 20),
                vertical: ResponsiveHelper.isMobile(context)
                    ? ResponsiveHelper.spacing(context, 10)
                    : ResponsiveHelper.isTablet(context)
                        ? ResponsiveHelper.spacing(context, 12)
                        : ResponsiveHelper.spacing(context, 14),
              ),
              decoration: BoxDecoration(
                color: Colors.white, // White background
                borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12, tablet: 14, desktop: 16)),
                border: Border.all(
                  color: Colors.grey.withOpacity(0.1),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    spreadRadius: 0,
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: hasFeeling
                  ? Row(
                      children: [
                        // Left: Emoji without circular border - Compact design
                        Builder(
                          builder: (context) {
                            final emojiSize = (ResponsiveHelper.isMobile(context) ? 44.0 : ResponsiveHelper.isTablet(context) ? 50.0 : 56.0);
                                  
                                  // Debug logging
                                  print('🔍 Building emoji display:');
                                  print('  - hasFeeling: $hasFeeling');
                                  print('  - emojiDetails: ${emojiDetails != null ? "exists" : "null"}');
                                  if (emojiDetails != null) {
                                    print('  - emojiDetails name: ${emojiDetails['name']}');
                                    print('  - emojiDetails image_url: ${emojiDetails['image_url']}');
                                  }
                                  print('  - userFeeling emoji: ${userFeeling?['emoji']}');
                                  
                                  // Use emojiDetails if available (from optimistic update or API)
                                  if (emojiDetails != null) {
                                    print('✅ Using emojiDetails for display');
                                    return HomeScreen.buildEmojiDisplay(
                                      context,
                                      emojiDetails,
                                      size: emojiSize,
                                    );
                                  }
                                  
                                  // Otherwise, check if userFeeling['emoji'] is an image URL
                                  final emojiValue = userFeeling?['emoji'] as String? ?? '';
                                  if (emojiValue.isNotEmpty) {
                                    print('⚠️ emojiDetails is null, trying to use emojiValue: $emojiValue');
                                    final isTruncatedUrl = emojiValue.startsWith('http') && 
                                                            (emojiValue.length < 20 || 
                                                             !emojiValue.contains('.png') && !emojiValue.contains('.jpg') && 
                                                             !emojiValue.contains('uploads/') && !emojiValue.contains('emojis/'));
                                    
                                    if (!isTruncatedUrl && (emojiValue.contains('http') || emojiValue.contains('uploads/') || emojiValue.contains('.png') || emojiValue.contains('.jpg'))) {
                                      String imageUrl = emojiValue;
                                      if (imageUrl.startsWith('uploads/') && !imageUrl.startsWith('http')) {
                                        imageUrl = 'https://fruitofthespirit.templateforwebsites.com/$imageUrl';
                                      }
                                      
                                      print('✅ Creating emojiData from image URL: $imageUrl');
                                      final emojiData = {
                                        'emoji_char': '',
                                        'name': 'Selected Emoji',
                                        'image_url': imageUrl,
                                      };
                                      return HomeScreen.buildEmojiDisplay(
                                        context,
                                        emojiData,
                                        size: emojiSize,
                                      );
                                    } else if (!isTruncatedUrl) {
                                      print('✅ Creating emojiData from emoji_char: $emojiValue');
                                      final emojiData = {
                                        'emoji_char': emojiValue,
                                        'name': emojiValue,
                                        'image_url': null,
                                      };
                                      return HomeScreen.buildEmojiDisplay(
                                        context,
                                        emojiData,
                                        size: emojiSize,
                                      );
                                    }
                                  }
                                  
                                  // Fallback: Show placeholder
                                  print('⚠️ No emoji data found, showing placeholder');
                                  return HomeScreen._buildPlaceholderIcon(context, emojiSize);
                                },
                          ),
                        SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                        // Middle: Text Content (3 lines)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Line 1: Heart icon + "feeling"
                              Row(
                                children: [
                                  Icon(
                                    Icons.favorite,
                                    size: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                                    color: const Color(0xFFFFB3BA), // Light pink heart
                                  ),
                                  SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                                  Text(
                                    'feeling',
                                    style: ResponsiveHelper.textStyle(
                                      context,
                                      fontSize: ResponsiveHelper.fontSize(context, mobile: 11, tablet: 12, desktop: 13),
                                      color: const Color(0xFF78909C), // Light grey-blue
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: ResponsiveHelper.spacing(context, 4)),
                              // Line 2: Fruit Name (bold)
                              Builder(
                                builder: (context) {
                                  String getFruitDisplayName() {
                                    if (emojiDetails != null) {
                                      final name = emojiDetails!['name'] as String? ?? '';
                                      if (name.isNotEmpty) {
                                        final parts = name.trim().split(' ');
                                        if (parts.isNotEmpty) {
                                          return parts[0];
                                        }
                                        return name;
                                      }
                                    }
                                    
                                    final emojiValue = userFeeling?['emoji'] as String? ?? '';
                                    if (emojiValue.isNotEmpty) {
                                      final isTruncatedUrl = emojiValue.startsWith('http') && 
                                                              (emojiValue.length < 20 || 
                                                               !emojiValue.contains('.png') && !emojiValue.contains('.jpg') && 
                                                               !emojiValue.contains('uploads/') && !emojiValue.contains('emojis/'));
                                      
                                      if (!isTruncatedUrl && (emojiValue.contains('http') || emojiValue.contains('uploads/'))) {
                                        try {
                                          final uri = Uri.decodeComponent(emojiValue);
                                          final filename = uri.split('/').last.replaceAll(RegExp(r'\.(png|jpg|jpeg|gif|webp|svg)$', caseSensitive: false), '');
                                          final nameWithoutVariant = filename.replaceAll(RegExp(r'\s*\(\d+\)\s*'), '');
                                          final parts = nameWithoutVariant.split('_');
                                          if (parts.isNotEmpty) {
                                            return parts[0];
                                          }
                                        } catch (e) {
                                          // If parsing fails
                                        }
                                      } else if (!isTruncatedUrl) {
                                        return emojiValue;
                                      }
                                    }
                                    
                                    return 'Select a feeling';
                                  }
                                  
                                  final fruitName = getFruitDisplayName();
                                  final displayText = fruitName.length > 20 || fruitName.contains('http') 
                                      ? 'Select a feeling' 
                                      : fruitName;
                                  
                                  return Text(
                                    displayText,
                                    style: ResponsiveHelper.textStyle(
                                      context,
                                      fontSize: ResponsiveHelper.fontSize(context, mobile: 20, tablet: 24, desktop: 28),
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  );
                                },
                              ),
                              SizedBox(height: ResponsiveHelper.spacing(context, 3)),
                              // Line 3: "Tracking daily mood."
                              Text(
                                'Tracking daily mood.',
                                style: ResponsiveHelper.textStyle(
                                  context,
                                  fontSize: ResponsiveHelper.fontSize(context, mobile: 11, tablet: 12, desktop: 13),
                                  color: const Color(0xFF78909C), // Light grey-blue
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                        // Right: Oval Arrow Button
                        Container(
                          width: ResponsiveHelper.isMobile(context) ? 36 : 40,
                          height: ResponsiveHelper.isMobile(context) ? 48 : 52,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(ResponsiveHelper.isMobile(context) ? 18 : 20),
                            border: Border.all(
                              color: const Color(0xFFE8E8D3), // Light beige border
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.chevron_right_rounded,
                              size: ResponsiveHelper.iconSize(context, mobile: 20, tablet: 22, desktop: 24),
                              color: AppTheme.iconscolor, // Orange arrow matching icons color
                            ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        // Left: Icon without circular border - Compact design
                        Icon(
                          Icons.mood_rounded,
                          color: Colors.grey[400],
                          size: ResponsiveHelper.iconSize(context, mobile: 40, tablet: 44, desktop: 48),
                        ),
                        SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'How are you feeling?',
                                style: ResponsiveHelper.textStyle(
                                  context,
                                  fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 18, desktop: 20),
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              SizedBox(height: ResponsiveHelper.spacing(context, 3)),
                              Text(
                                'Tap to share your feeling',
                                style: ResponsiveHelper.textStyle(
                                  context,
                                  fontSize: ResponsiveHelper.fontSize(context, mobile: 11, tablet: 12, desktop: 13),
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: ResponsiveHelper.iconSize(context, mobile: 20, tablet: 24, desktop: 28),
                          color: Colors.grey[400],
                        ),
                      ],
                    ),
            ),
          ),
        ),
      );
    });
  }

  void _showEmojiSelectionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 20)),
          ),
          child: Container(
            padding: ResponsiveHelper.padding(context, all: 20),
            constraints: BoxConstraints(
              maxHeight: ResponsiveHelper.screenHeight(context) * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'How do you feel today?',
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: ResponsiveHelper.fontSize(context, mobile: 20, tablet: 24, desktop: 28),
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF8B4513),
                      ),
            ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.grey[700]),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                    ),
                  ],
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, 20)),
                Obx(() {
                  if (widget.controller.emojis.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: ResponsiveHelper.padding(context, vertical: 20),
                        child: CircularProgressIndicator(
                          color: const Color(0xFF8B4513),
                        ),
                      ),
                    );
                  }

                  return _EmojiCarouselWidget(
                    emojis: widget.controller.emojis,
                    dialogContext: dialogContext,
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Stories Carousel Widget - Instagram Style (Circular Avatars Only)
class _StoriesCarouselWidget extends StatefulWidget {
  final List<Map<String, dynamic>> photos;

  const _StoriesCarouselWidget({required this.photos});

  @override
  State<_StoriesCarouselWidget> createState() => _StoriesCarouselWidgetState();
}

class _StoriesCarouselWidgetState extends State<_StoriesCarouselWidget> {
  @override
  Widget build(BuildContext context) {
    if (widget.photos.isEmpty) {
      return const SizedBox.shrink();
    }

    final storySize = ResponsiveHelper.imageHeight(context, mobile: 70, tablet: 80, desktop: 90);
    final buttonWidth = storySize + (ResponsiveHelper.spacing(context, 6) * 2); // Button width + margins
    
    return Container(
      height: ResponsiveHelper.imageHeight(context, mobile: 90, tablet: 100, desktop: 110),
      padding: ResponsiveHelper.padding(context, vertical: 8),
      child: Row(
        children: [
          // Scrollable stories list
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.only(
                left: ResponsiveHelper.spacing(context, 12),
                right: ResponsiveHelper.spacing(context, 8),
              ),
              itemCount: widget.photos.length,
              itemBuilder: (context, index) {
                final photo = widget.photos[index];
                return _buildInstagramStoryCircle(context, photo, index);
              },
            ),
          ),
          // "View All" button on the right - No overlap
          Padding(
            padding: EdgeInsets.only(
              left: ResponsiveHelper.spacing(context, 8),
              right: ResponsiveHelper.spacing(context, 12),
            ),
            child: Center(
              child: _buildViewAllButton(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewAllButton(BuildContext context) {
    final storySize = ResponsiveHelper.imageHeight(context, mobile: 70, tablet: 80, desktop: 90);
    
    // Check if there's an image for View All (you can add image path here if available)
    final String? viewAllImagePath = null; // Add image path if you have one: 'assets/quickactions/view-all.png'
    
    return GestureDetector(
      onTap: () {
        // Open Stories screen (all stories)
        Get.toNamed(Routes.STORIES);
      },
      child: Container(
        margin: ResponsiveHelper.padding(context, horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // "View All" Button - Home Screen Theme Style
            Container(
              width: storySize,
              height: storySize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF8B4513),
                    const Color(0xFF5F4628),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B4513).withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              padding: EdgeInsets.all(3),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: viewAllImagePath != null
                    ? ClipOval(
                        child: Image.asset(
                          viewAllImagePath,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            // Fallback to text if image fails
                            return _buildViewAllText(context, storySize);
                          },
                        ),
                      )
                    : _buildViewAllText(context, storySize),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewAllText(BuildContext context, double storySize) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.grid_view_rounded,
          size: storySize * 0.28,
          color: AppTheme.iconscolor,
        ),
        SizedBox(height: ResponsiveHelper.spacing(context, 4)),
        Text(
          'View All',
          style: ResponsiveHelper.textStyle(
            context,
            fontSize: ResponsiveHelper.fontSize(context, mobile: 10, tablet: 11, desktop: 12),
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildInstagramStoryCircle(BuildContext context, Map<String, dynamic> photo, int index) {
    final storySize = ResponsiveHelper.imageHeight(context, mobile: 70, tablet: 80, desktop: 90);
    final borderWidth = 3.0;
    
    // Get image URL
    String? imageUrl;
    if (photo['file_path'] != null) {
      imageUrl = 'https://fruitofthespirit.templateforwebsites.com/${photo['file_path']}';
    } else if (photo['image_url'] != null) {
      imageUrl = 'https://fruitofthespirit.templateforwebsites.com/${photo['image_url']}';
    }

    return GestureDetector(
      onTap: () {
        // Open the specific story/post details when tapped
        if (photo['id'] != null) {
          Get.toNamed(Routes.STORY_DETAILS, arguments: photo['id']);
        } else {
          // Fallback to Stories screen if no id
          Get.toNamed(Routes.STORIES);
        }
      },
      child: Container(
        margin: ResponsiveHelper.padding(context, horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Circular Story Avatar with App Theme Color Border
            Container(
              width: storySize,
              height: storySize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF8B4513), // App theme brown color
              ),
              padding: EdgeInsets.all(borderWidth),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                padding: EdgeInsets.all(2),
                child: ClipOval(
                  child: imageUrl != null
                      ? CachedImage(
                          imageUrl: imageUrl!,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          errorWidget: Container(
                            color: Colors.grey[300],
                            child: Icon(
                              Icons.person,
                              size: storySize * 0.5,
                              color: Colors.grey[600],
                            ),
                          ),
                        )
                      : Container(
                          color: Colors.grey[300],
                          child: Icon(
                            Icons.person,
                            size: storySize * 0.5,
                            color: Colors.grey[600],
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Video Preview Widget - Auto play first video
class _VideoPreviewWidget extends StatefulWidget {
  final String videoUrl;

  const _VideoPreviewWidget({required this.videoUrl});

  @override
  State<_VideoPreviewWidget> createState() => _VideoPreviewWidgetState();
}

class _VideoPreviewWidgetState extends State<_VideoPreviewWidget> with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await _controller!.initialize();
      _controller!.setLooping(true);
      if (mounted) {
        _controller!.play();
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      print('Error initializing video preview: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.pause();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // Pause video when app goes to background
      _controller?.pause();
    } else if (state == AppLifecycleState.resumed && _isInitialized) {
      // Resume video when app comes to foreground (if it was playing)
      _controller?.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _controller == null) {
      return const SizedBox.shrink();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
      child: Opacity(
        opacity: 0.3,
        child: VideoPlayer(_controller!),
      ),
    );
  }
}

// Quick Actions Carousel Widget
class _QuickActionsCarouselWidget extends StatefulWidget {
  final List<Map<String, dynamic>> quickActions;

  const _QuickActionsCarouselWidget({required this.quickActions});

  @override
  State<_QuickActionsCarouselWidget> createState() => _QuickActionsCarouselWidgetState();
}

class _QuickActionsCarouselWidgetState extends State<_QuickActionsCarouselWidget> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: ResponsiveHelper.safeHeight(context, mobile: 140, tablet: 150, desktop: 160),
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: widget.quickActions.length,
            itemBuilder: (context, index) {
              final action = widget.quickActions[index];
              return Padding(
                padding: ResponsiveHelper.padding(context, horizontal: 8),
                child: _buildQuickActionButton(
                  context,
                  action['icon'] as String,
                  action['label'] as String,
                ),
              );
            },
          ),
        ),
        SizedBox(height: ResponsiveHelper.spacing(context, 12)),
        // Page Indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.quickActions.length,
            (index) => Container(
              width: ResponsiveHelper.spacing(context, _currentPage == index ? 24 : 8),
              height: ResponsiveHelper.spacing(context, 8),
              margin: ResponsiveHelper.padding(context, horizontal: 4),
              decoration: BoxDecoration(
                color: _currentPage == index
                    ? const Color(0xFF5F4628)
                    : Colors.grey[300],
                borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 4)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionButton(BuildContext context, String iconUrl, String label) {
    return Tooltip(
      message: label,
      waitDuration: const Duration(milliseconds: 500),
      child: Container(
        height: ResponsiveHelper.safeHeight(context, mobile: 100, tablet: 110, desktop: 120),
        width: ResponsiveHelper.safeHeight(context, mobile: 100, tablet: 110, desktop: 120),
      decoration: BoxDecoration(
        color: Colors.white,
          borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
            spreadRadius: 0,
              blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
            borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
          onTap: () {
            if (label.contains('Prayer') || label.contains('prayer')) {
              Get.toNamed(Routes.CREATE_PRAYER);
            } else if (label.contains('Blogger') || label.contains('blogger')) {
              try {
                final blogsController = Get.find<BlogsController>();
                blogsController.filterUserId.value = 0;
                // Performance: Only refresh if needed
          if (blogsController.blogs.isEmpty) {
            blogsController.loadBlogs(refresh: true);
          }
              } catch (e) {
                Get.put(BlogsController());
              }
              Get.toNamed(Routes.BLOGGER_ZONE);
            } else if (label.contains('Fruit') || label.contains('fruit')) {
              Get.toNamed(Routes.FRUITS);
              } else if (label.contains('Group') || label.contains('group')) {
                if (!Get.isRegistered<GroupsController>()) {
                  Get.put(GroupsController());
                }
                Get.toNamed(Routes.GROUPS);
              }
            },
            onLongPress: () {
              Get.snackbar(
                label,
                'Tap to open',
                backgroundColor: Colors.black87,
                colorText: Colors.white,
                snackPosition: SnackPosition.BOTTOM,
                duration: const Duration(seconds: 1),
                margin: EdgeInsets.all(ResponsiveHelper.spacing(context, 16)),
              );
            },
            child: Center(
              child: ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    Colors.orange[600]!,
                    BlendMode.srcATop,
                  ),
                  child: CachedImage(
                    imageUrl: iconUrl,
                  height: ResponsiveHelper.iconSize(context, mobile: 55, tablet: 60, desktop: 65),
                  width: ResponsiveHelper.iconSize(context, mobile: 55, tablet: 60, desktop: 65),
                    fit: BoxFit.contain,
                  ),
                ),
            ),
          ),
        ),
      ),
    );
  }
}


