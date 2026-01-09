import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/controllers/gallery_controller.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';
import 'package:fruitsofspirit/utils/screen_size.dart';
import 'package:fruitsofspirit/routes/routes.dart';
import 'package:fruitsofspirit/widgets/cached_image.dart';
import 'package:fruitsofspirit/widgets/standard_app_bar.dart';
import 'package:fruitsofspirit/services/user_storage.dart';
import 'package:fruitsofspirit/config/image_config.dart';
import 'package:fruitsofspirit/widgets/app_bottom_navigation_bar.dart';
import 'package:fruitsofspirit/utils/app_theme.dart';

/// Gallery Screen - Social Media Style
/// User-friendly design like home page with modern UI
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({Key? key}) : super(key: key);

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final controller = Get.find<GalleryController>();
  final ScrollController _scrollController = ScrollController();
  
  // Header collapse/expand state (sticky behavior)
  double _headerHeight = 200.0; // Initial header height
  double _minHeaderHeight = 80.0; // Minimum collapsed height (sticky)
  double _maxHeaderHeight = 200.0; // Maximum expanded height
  double _lastScrollOffset = 0.0; // Track last scroll position
  bool _isCollapsed = false; // Track if header is collapsed

  @override
  void initState() {
    super.initState();

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
        }
        controller.loadPhotos(refresh: true);
        return;
      }

      if (controller.filterUserId.value != 0) {
        controller.filterUserId.value = 0;
        controller.loadPhotos(refresh: true);
      }
    });
    
    // Initialize header heights based on screen size
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final screenHeight = MediaQuery.of(context).size.height;
        setState(() {
          _maxHeaderHeight = screenHeight * 0.25; // 25% of screen height
          _minHeaderHeight = 80.0; // Minimum collapsed height
          _headerHeight = _maxHeaderHeight;
        });
      }
    });
    
    // Listen to scroll changes
    _scrollController.addListener(_onScroll);
  }
  
  void _onScroll() {
    if (!mounted) return;
    
    final scrollOffset = _scrollController.offset;
    final scrollDelta = scrollOffset - _lastScrollOffset;
    _lastScrollOffset = scrollOffset;
    
    // If scrolled to top (within 100px), always expand header
    if (scrollOffset <= 100.0) {
      if (_isCollapsed || _headerHeight < _maxHeaderHeight) {
        setState(() {
          _headerHeight = _maxHeaderHeight;
          _isCollapsed = false;
        });
      }
      return;
    }
    
    // When scrolling down, collapse header (threshold: 2px to avoid jitter)
    if (scrollDelta > 2.0 && scrollOffset > 120.0) {
      // Collapse threshold - once scrolled past 120px, collapse
      if (!_isCollapsed || _headerHeight > _minHeaderHeight) {
        setState(() {
          _headerHeight = _minHeaderHeight;
          _isCollapsed = true;
        });
      }
    }
    // When scrolling up, expand header (threshold: 2px to avoid jitter)
    else if (scrollDelta < -2.0) {
      // Expand header when scrolling up (anywhere, not just at top)
      if (_isCollapsed || _headerHeight < _maxHeaderHeight) {
        setState(() {
          _headerHeight = _maxHeaderHeight;
          _isCollapsed = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Initialize ScreenSize for responsive design
    ScreenSize.init(context);
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: StandardAppBar(
        showBackButton: false,
        rightActions: [
          StandardAppBar.buildActionIcon(
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
          StandardAppBar.buildActionIcon(
            context,
            icon: Icons.camera_alt_rounded,
            onTap: () => Get.toNamed(Routes.UPLOAD_PHOTO),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.photos.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  color: AppTheme.iconscolor,
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                Text(
                  'Loading moments...',
                  style: ResponsiveHelper.textStyle(
                    context,
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        // Show error message if there's an error and no photos
        if (!controller.isLoading.value && 
            controller.photos.isEmpty && 
            controller.message.value.isNotEmpty &&
            controller.message.value.contains('No internet')) {
          return Center(
            child: Padding(
              padding: ResponsiveHelper.padding(context, all: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: ResponsiveHelper.padding(context, all: 24),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.wifi_off_rounded,
                      size: ResponsiveHelper.iconSize(context, mobile: 64),
                      color: Colors.red[700],
                    ),
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(context, 24)),
                  Text(
                    'No Internet Connection',
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(context, 12)),
                  Text(
                    'Please check your internet connection\nand try again',
                    textAlign: TextAlign.center,
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: 14,
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(context, 32)),
                  SizedBox(
                    width: double.infinity,
                    height: ResponsiveHelper.buttonHeight(context, mobile: 50),
                    child: ElevatedButton(
                      onPressed: () => controller.refresh(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.iconscolor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            ResponsiveHelper.borderRadius(context, mobile: 12),
                          ),
                        ),
                        elevation: 2,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.refresh_rounded,
                            color: Colors.white,
                            size: ResponsiveHelper.iconSize(context, mobile: 20),
                          ),
                          SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                          Flexible(
                            child: Text(
                              'Retry',
                              style: ResponsiveHelper.textStyle(
                                context,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
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

        return Stack(
          fit: StackFit.expand,
          children: [
            // Main scrollable content
            RefreshIndicator(
              onRefresh: () => controller.refresh(),
              color: AppTheme.iconscolor,
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Section with Stats (collapsible on scroll)
                    // When collapsed, add space for sticky header; when expanded, show full header
                    if (!_isCollapsed) _buildHeaderSection(context),
                    if (_isCollapsed) SizedBox(height: _minHeaderHeight),
                    
                    // Latest Moments Section
                    Padding(
                      padding: ResponsiveHelper.padding(
                        context, 
                        horizontal: ScreenSize.isSmallPhone 
                            ? ScreenSize.spacingSmall 
                            : ScreenSize.spacingMedium, 
                        vertical: ScreenSize.spacingSmall,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.collections_rounded,
                                  size: ResponsiveHelper.iconSize(
                                    context, 
                                    mobile: ScreenSize.isSmallPhone ? 20 : 24,
                                    tablet: 26,
                                  ),
                                  color: Colors.black,
                                ),
                                SizedBox(width: ScreenSize.spacingSmall),
                                Flexible(
                                  child: Text(
                                    'Latest Moments',
                                    style: ResponsiveHelper.textStyle(
                                      context,
                                      fontSize: ResponsiveHelper.fontSize(
                                        context,
                                        mobile: ScreenSize.isSmallPhone ? 18 : 22,
                                        tablet: 24,
                                      ),
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
                          if (controller.photos.isNotEmpty)
                            Container(
                              padding: ResponsiveHelper.padding(
                                context, 
                                horizontal: ScreenSize.isSmallPhone ? 10 : 12, 
                                vertical: ScreenSize.isSmallPhone ? 5 : 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.iconscolor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(
                                  ResponsiveHelper.borderRadius(
                                    context, 
                                    mobile: ScreenSize.isSmallPhone ? 16 : 20,
                                  ),
                                ),
                              ),
                              child: Text(
                                '${controller.photos.length} ${controller.photos.length == 1 ? 'photo' : 'photos'}',
                                style: ResponsiveHelper.textStyle(
                                  context,
                                  fontSize: ResponsiveHelper.fontSize(
                                    context,
                                    mobile: ScreenSize.isSmallPhone ? 11 : 12,
                                    tablet: 13,
                                  ),
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.iconscolor,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(height: ScreenSize.spacingMedium),
                    
                    // Photos Grid or Empty State
                    if (controller.photos.isEmpty)
                      _buildEmptyState(context)
                    else
                      _buildPhotosGrid(context),
                    
                    SizedBox(height: ScreenSize.spacingMedium),
                    
                    // Load More Button (if more photos available)
                    if (controller.photos.length >= 4)
                      _buildLoadMoreButton(context),
                    
                    SizedBox(height: ScreenSize.isSmallPhone 
                        ? ScreenSize.spacingLarge * 2 
                        : ScreenSize.spacingLarge * 3), // Space for bottom nav
                  ],
                ),
              ),
            ),
            // Sticky header when collapsed (positioned below app bar)
            if (_isCollapsed)
                Positioned(
                  top: ResponsiveHelper.safeHeight(
                    context,
                    mobile: 70,
                    tablet: 80,
                    desktop: 90,
                  ),
                  left: 0,
                  right: 0,
                  child: _buildStickyHeader(context),
                ),
            ],
          );
      }),
      bottomNavigationBar: const AppBottomNavigationBar(currentIndex: 4),
    );
  }

  /// Build Sticky Header (shown when collapsed)
  Widget _buildStickyHeader(BuildContext context) {
    ScreenSize.init(context);
    
    return Container(
      height: _minHeaderHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: ResponsiveHelper.padding(
            context,
            horizontal: ScreenSize.isSmallPhone 
                ? ScreenSize.spacingSmall 
                : ScreenSize.spacingMedium,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.photo_library_rounded,
                color: Colors.white,
                size: ResponsiveHelper.iconSize(
                  context, 
                  mobile: 24,
                  tablet: 28,
                ),
              ),
              SizedBox(width: ScreenSize.spacingSmall),
              Text(
                'Gallery',
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: ResponsiveHelper.fontSize(
                    context,
                    mobile: 18,
                    tablet: 20,
                  ),
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build Header Section with Stats (collapsible on scroll)
  Widget _buildHeaderSection(BuildContext context) {
    // Initialize ScreenSize for responsive design
    ScreenSize.init(context);
    
    // Calculate opacity based on header height (fade out when collapsed)
    final opacity = ((_headerHeight - _minHeaderHeight) / (_maxHeaderHeight - _minHeaderHeight)).clamp(0.3, 1.0);
    
    // Hide header section when collapsed (sticky header will show instead)
    if (_isCollapsed) {
      return const SizedBox.shrink();
    }
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 100), // Smooth animation
      height: _headerHeight,
      clipBehavior: Clip.antiAlias,
      margin: ResponsiveHelper.padding(
        context, 
        all: ScreenSize.isSmallPhone 
            ? ScreenSize.spacingSmall 
            : ScreenSize.spacingMedium,
      ),
      padding: ResponsiveHelper.padding(
        context, 
        all: ScreenSize.isSmallPhone 
            ? ScreenSize.spacingMedium 
            : ScreenSize.spacingLarge,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          ResponsiveHelper.borderRadius(
            context, 
            mobile: ScreenSize.isSmallPhone ? 16 : 20,
            tablet: 24,
          ),
        ),
        border: Border.all(
          color: AppTheme.iconscolor.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: ScreenSize.isSmallPhone ? 8 : 12,
            offset: Offset(0, ScreenSize.isSmallPhone ? 2 : 4),
          ),
        ],
      ),
      child: Opacity(
        opacity: ((_headerHeight - _minHeaderHeight) / (_maxHeaderHeight - _minHeaderHeight)).clamp(0.3, 1.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Show/hide content based on header height
            if (_headerHeight > _minHeaderHeight + 20) ...[
              Flexible(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Share Your Moments',
                            style: ResponsiveHelper.textStyle(
                              context,
                              fontSize: ResponsiveHelper.fontSize(
                                context,
                                mobile: ScreenSize.isSmallPhone ? 18 : 20,
                                tablet: 22,
                              ),
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                            maxLines: _headerHeight > _minHeaderHeight + 60 ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_headerHeight > _minHeaderHeight + 60) ...[
                            SizedBox(height: _headerHeight > _minHeaderHeight + 80 ? ScreenSize.spacingSmall : 4),
                            Expanded(
                              child: Text(
                                'Capture and share your spiritual journey with the community',
                                style: ResponsiveHelper.textStyle(
                                  context,
                                  fontSize: ResponsiveHelper.fontSize(
                                    context,
                                    mobile: ScreenSize.isSmallPhone ? 13 : 14,
                                    tablet: 15,
                                  ),
                                  color: Colors.grey[700],
                                  height: 1.4,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.visible,
                                softWrap: true,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (_headerHeight > _minHeaderHeight + 40) ...[
                      SizedBox(width: ScreenSize.spacingMedium),
                      Container(
                        padding: ResponsiveHelper.padding(
                        context, 
                        all: ScreenSize.isSmallPhone 
                            ? ScreenSize.spacingSmall 
                            : ScreenSize.spacingMedium,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.iconscolor,
                            AppTheme.iconscolor,
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.iconscolor.withOpacity(0.4),
                            blurRadius: ScreenSize.isSmallPhone ? 6 : 8,
                            offset: Offset(0, ScreenSize.isSmallPhone ? 2 : 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.camera_enhance_rounded,
                        color: Colors.white,
                        size: ResponsiveHelper.iconSize(
                          context, 
                          mobile: ScreenSize.isSmallPhone ? 28 : 32,
                          tablet: 36,
                        ),
                      ),
                    ),
                  ],
                ],
                ),
              ),
            ],
            if (_headerHeight > _minHeaderHeight + 80) ...[
                SizedBox(height: ScreenSize.spacingLarge),
                SizedBox(
                  width: double.infinity,
                  height: ResponsiveHelper.buttonHeight(
                    context, 
                    mobile: ScreenSize.isSmallPhone ? 48 : 50,
                    tablet: 54,
                  ),
                  child: ElevatedButton(
                    onPressed: () => Get.toNamed(Routes.UPLOAD_PHOTO),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.iconscolor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          ResponsiveHelper.borderRadius(
                            context, 
                            mobile: ScreenSize.isSmallPhone ? 12 : 16,
                            tablet: 20,
                          ),
                        ),
                      ),
                      elevation: 4,
                      shadowColor: AppTheme.iconscolor.withOpacity(0.4),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.camera_alt_rounded,
                          color: AppTheme.iconscolor,
                          size: ResponsiveHelper.iconSize(
                            context, 
                            mobile: ScreenSize.isSmallPhone ? 20 : 22,
                            tablet: 24,
                          ),
                        ),
                        SizedBox(width: ScreenSize.spacingSmall),
                        Flexible(
                          child: Text(
                            'Share A Moment',
                            style: ResponsiveHelper.textStyle(
                              context,
                              fontSize: ResponsiveHelper.fontSize(
                                context,
                                mobile: ScreenSize.isSmallPhone ? 15 : 16,
                                tablet: 17,
                              ),
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  /// Build Photos Grid
  Widget _buildPhotosGrid(BuildContext context) {
    // Initialize ScreenSize for responsive grid
    ScreenSize.init(context);
    
    // Responsive grid columns: 2 for phones, 3 for tablets
    final crossAxisCount = ResponsiveHelper.isMobile(context) 
        ? 2 
        : ResponsiveHelper.isTablet(context) 
            ? 3 
            : 4;
    
    // Responsive aspect ratio based on device size
    final aspectRatio = ScreenSize.isSmallPhone
        ? 0.80  // More compact for small phones
        : ScreenSize.isMediumPhone
            ? 0.82
            : ScreenSize.isLargePhone
                ? 0.85
                : ScreenSize.isTablet
                    ? 0.90  // Wider on tablets
                    : 0.95;
    
    return Padding(
      padding: ResponsiveHelper.padding(
        context, 
        horizontal: ScreenSize.isSmallPhone 
            ? ScreenSize.spacingSmall 
            : ScreenSize.spacingMedium,
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: ScreenSize.gridSpacing,
          mainAxisSpacing: ScreenSize.gridSpacing,
          childAspectRatio: aspectRatio,
        ),
        itemCount: controller.photos.length,
        itemBuilder: (context, index) {
          final photo = controller.photos[index];
          return _buildMomentCard(context, photo);
        },
      ),
    );
  }

  /// Build Moment Card - Enhanced Design
  Widget _buildMomentCard(BuildContext context, Map<String, dynamic> photo) {
    // Initialize ScreenSize for responsive design
    ScreenSize.init(context);
    
    final baseUrl = 'https://fruitofthespirit.templateforwebsites.com/';
    final thumbnailPath = photo['thumbnail_path'] as String?;
    final filePath = photo['file_path'] as String? ?? '';
    final imageUrl = thumbnailPath != null 
        ? baseUrl + thumbnailPath 
        : (filePath.isNotEmpty ? baseUrl + filePath : null);
    
    final userName = photo['user_name'] as String? ?? 'Anonymous';
    final testimony = photo['testimony'] as String? ?? '';
    final likeCount = int.tryParse((photo['like_count'] ?? 0).toString()) ?? 0;
    final commentCount = int.tryParse((photo['comment_count'] ?? 0).toString()) ?? 0;
    final isLiked = photo['is_liked'] == true || photo['is_liked'] == 1;
    final fruitTag = photo['fruit_tag'] as String?;
    
    return GestureDetector(
      onTap: () => Get.toNamed(
        Routes.PHOTO_DETAILS,
        arguments: photo['id'],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(
            ResponsiveHelper.borderRadius(
              context, 
              mobile: ScreenSize.isSmallPhone ? 12 : 16,
              tablet: 20,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: ScreenSize.isSmallPhone ? 8 : 12,
              offset: Offset(0, ScreenSize.isSmallPhone ? 2 : 4),
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with overlay
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(
                        ResponsiveHelper.borderRadius(
                          context, 
                          mobile: ScreenSize.isSmallPhone ? 12 : 16,
                          tablet: 20,
                        ),
                      ),
                      topRight: Radius.circular(
                        ResponsiveHelper.borderRadius(
                          context, 
                          mobile: ScreenSize.isSmallPhone ? 12 : 16,
                          tablet: 20,
                        ),
                      ),
                    ),
                    child: imageUrl != null
                        ? CachedImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorWidget: Container(
                              color: Colors.grey[200],
                              child: Icon(
                                Icons.broken_image,
                                size: ResponsiveHelper.iconSize(
                                  context, 
                                  mobile: ScreenSize.isSmallPhone ? 28 : 32,
                                  tablet: 36,
                                ),
                                color: Colors.grey,
                              ),
                            ),
                          )
                        : Container(
                            color: Colors.grey[200],
                            child: Icon(
                              Icons.image_not_supported,
                              size: ResponsiveHelper.iconSize(
                                context, 
                                mobile: ScreenSize.isSmallPhone ? 28 : 32,
                                tablet: 36,
                              ),
                              color: Colors.grey,
                            ),
                          ),
                  ),
                  // Fruit Tag Badge
                  if (fruitTag != null && fruitTag.isNotEmpty)
                    Positioned(
                      top: ScreenSize.isSmallPhone ? 6 : 8,
                      right: ScreenSize.isSmallPhone ? 6 : 8,
                      child: Container(
                        padding: ResponsiveHelper.padding(
                          context, 
                          horizontal: ScreenSize.isSmallPhone ? 8 : 10, 
                          vertical: ScreenSize.isSmallPhone ? 5 : 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(
                            ResponsiveHelper.borderRadius(
                              context, 
                              mobile: ScreenSize.isSmallPhone ? 16 : 20,
                              tablet: 24,
                            ),
                          ),
                        ),
                        child: Text(
                          fruitTag,
                          style: ResponsiveHelper.textStyle(
                            context,
                            fontSize: ResponsiveHelper.fontSize(
                              context,
                              mobile: ScreenSize.isSmallPhone ? 10 : 11,
                              tablet: 12,
                            ),
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Content Section
            Padding(
              padding: ResponsiveHelper.padding(
                context, 
                all: ScreenSize.isSmallPhone 
                    ? ScreenSize.spacingSmall 
                    : 12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Name
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          userName,
                          style: ResponsiveHelper.textStyle(
                            context,
                            fontSize: ResponsiveHelper.fontSize(
                              context,
                              mobile: ScreenSize.isSmallPhone ? 13 : 14,
                              tablet: 15,
                            ),
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (testimony.isNotEmpty) ...[
                    SizedBox(height: ScreenSize.spacingSmall),
                    Text(
                      testimony,
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: ResponsiveHelper.fontSize(
                          context,
                          mobile: ScreenSize.isSmallPhone ? 11 : 12,
                          tablet: 13,
                        ),
                        color: Colors.grey[700],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  SizedBox(height: ScreenSize.isSmallPhone 
                      ? ScreenSize.spacingSmall 
                      : 10),
                  // Stats Row
                  Row(
                    children: [
                      // Like Count
                      Row(
                        children: [
                          Icon(
                            isLiked ? Icons.favorite : Icons.favorite_border,
                            size: ResponsiveHelper.iconSize(
                              context, 
                              mobile: ScreenSize.isSmallPhone ? 14 : 16,
                              tablet: 18,
                            ),
                            color: AppTheme.iconscolor,
                          ),
                          SizedBox(width: ScreenSize.spacingSmall / 2),
                          Text(
                            '$likeCount',
                            style: ResponsiveHelper.textStyle(
                              context,
                              fontSize: ResponsiveHelper.fontSize(
                                context,
                                mobile: ScreenSize.isSmallPhone ? 11 : 12,
                                tablet: 13,
                              ),
                              fontWeight: FontWeight.w600,
                              color: AppTheme.iconscolor,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(width: ScreenSize.spacingMedium),
                      // Comment Count
                      Row(
                        children: [
                          Icon(
                            Icons.comment_outlined,
                            size: ResponsiveHelper.iconSize(
                              context, 
                              mobile: ScreenSize.isSmallPhone ? 14 : 16,
                              tablet: 18,
                            ),
                            color: AppTheme.iconscolor,
                          ),
                          SizedBox(width: ScreenSize.spacingSmall / 2),
                          Text(
                            '$commentCount',
                            style: ResponsiveHelper.textStyle(
                              context,
                              fontSize: ResponsiveHelper.fontSize(
                                context,
                                mobile: ScreenSize.isSmallPhone ? 11 : 12,
                                tablet: 13,
                              ),
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
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
    );
  }

  /// Build Empty State
  Widget _buildEmptyState(BuildContext context) {
    // Initialize ScreenSize for responsive design
    ScreenSize.init(context);
    
    return Container(
      margin: ResponsiveHelper.padding(
        context, 
        all: ScreenSize.isSmallPhone 
            ? ScreenSize.spacingLarge 
            : ScreenSize.spacingLarge * 2,
      ),
      padding: ResponsiveHelper.padding(
        context, 
        all: ScreenSize.isSmallPhone 
            ? ScreenSize.spacingLarge 
            : ScreenSize.spacingLarge * 1.5,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          ResponsiveHelper.borderRadius(
            context, 
            mobile: ScreenSize.isSmallPhone ? 16 : 20,
            tablet: 24,
          ),
        ),
        border: Border.all(
          color: Colors.grey.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: ScreenSize.isSmallPhone ? 8 : 12,
            offset: Offset(0, ScreenSize.isSmallPhone ? 2 : 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: ResponsiveHelper.padding(
              context, 
              all: ScreenSize.isSmallPhone 
                  ? ScreenSize.spacingMedium 
                  : ScreenSize.spacingLarge,
            ),
            decoration: BoxDecoration(
              color: AppTheme.iconscolor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.photo_library_outlined,
              size: ResponsiveHelper.iconSize(
                context, 
                mobile: ScreenSize.isSmallPhone ? 56 : 64,
                tablet: 72,
              ),
              color: AppTheme.iconscolor,
            ),
          ),
          SizedBox(height: ScreenSize.spacingLarge),
          Text(
            'No moments yet',
            style: ResponsiveHelper.textStyle(
              context,
              fontSize: ResponsiveHelper.fontSize(
                context,
                mobile: ScreenSize.isSmallPhone ? 18 : 20,
                tablet: 22,
              ),
              fontWeight: FontWeight.bold,
                                  color: AppTheme.iconscolor,
            ),
          ),
          SizedBox(height: ScreenSize.spacingSmall),
          Text(
            'Be the first to share a moment\nand inspire others!',
            textAlign: TextAlign.center,
            style: ResponsiveHelper.textStyle(
              context,
              fontSize: ResponsiveHelper.fontSize(
                context,
                mobile: ScreenSize.isSmallPhone ? 13 : 14,
                tablet: 15,
              ),
              color: Colors.grey[600],
              height: 1.5,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: ScreenSize.spacingLarge),
          SizedBox(
            width: double.infinity,
            height: ResponsiveHelper.buttonHeight(
              context, 
              mobile: ScreenSize.isSmallPhone ? 46 : 48,
              tablet: 52,
            ),
            child: ElevatedButton(
              onPressed: () => Get.toNamed(Routes.UPLOAD_PHOTO),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9F9467),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    ResponsiveHelper.borderRadius(context, mobile: 12),
                  ),
                ),
                elevation: 2,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.add_photo_alternate_rounded,
                    color: Colors.white,
                    size: ResponsiveHelper.iconSize(
                      context, 
                      mobile: ScreenSize.isSmallPhone ? 18 : 20,
                      tablet: 22,
                    ),
                  ),
                  SizedBox(width: ScreenSize.spacingSmall),
                  Flexible(
                    child: Text(
                      'Share Your First Moment',
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: ResponsiveHelper.fontSize(
                          context,
                          mobile: ScreenSize.isSmallPhone ? 14 : 15,
                          tablet: 16,
                        ),
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build Load More Button
  Widget _buildLoadMoreButton(BuildContext context) {
    // Initialize ScreenSize for responsive design
    ScreenSize.init(context);
    
    return Obx(() {
      if (controller.isLoading.value) {
        return Center(
          child: Padding(
            padding: ResponsiveHelper.padding(
              context, 
              vertical: ScreenSize.spacingMedium,
            ),
            child: CircularProgressIndicator(
              color: AppTheme.iconscolor,
            ),
          ),
        );
      }

      return Padding(
        padding: ResponsiveHelper.padding(
          context, 
          horizontal: ScreenSize.isSmallPhone 
              ? ScreenSize.spacingSmall 
              : ScreenSize.spacingMedium,
        ),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => controller.loadMore(),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: AppTheme.iconscolor,
                width: 2,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  ResponsiveHelper.borderRadius(
                    context, 
                    mobile: ScreenSize.isSmallPhone ? 10 : 12,
                    tablet: 14,
                  ),
                ),
              ),
              padding: ResponsiveHelper.padding(
                context, 
                vertical: ScreenSize.isSmallPhone ? 12 : 14,
              ),
            ),
            child: Text(
              'Load More Moments',
              style: ResponsiveHelper.textStyle(
                context,
                fontSize: ResponsiveHelper.fontSize(
                  context,
                  mobile: ScreenSize.isSmallPhone ? 14 : 15,
                  tablet: 16,
                ),
                fontWeight: FontWeight.bold,
                color: AppTheme.iconscolor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      );
    });
  }
}
