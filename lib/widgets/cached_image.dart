import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';
import 'package:fruitsofspirit/services/image_preload_service.dart';

/// Cached Image Widget
/// Optimized image loading with caching and preloading support
class CachedImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;
  final bool preload; // Whether to preload this image
  final Map<String, String>? headers; // HTTP headers for image request

  const CachedImage({
    Key? key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
    this.preload = false,
    this.headers,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Check if URL is empty or invalid
    if (imageUrl.isEmpty || imageUrl.trim().isEmpty) {
      return errorWidget ?? _defaultErrorWidget(context);
    }

    // Check if it's a local asset path
    if (imageUrl.startsWith('assets/') || imageUrl.startsWith('assets/images/')) {
      // Use AssetImage for local assets with high quality filter
      Widget image = Image.asset(
        imageUrl,
        width: width,
        height: height,
        fit: fit,
        filterQuality: FilterQuality.high, // High quality filter for sharp images
        errorBuilder: (context, error, stackTrace) {
          print('❌ Error loading asset image: $imageUrl - $error');
          return errorWidget ?? _defaultErrorWidget(context);
        },
      );

      if (borderRadius != null) {
        image = ClipRRect(
          borderRadius: borderRadius!,
          child: image,
        );
      }

      return image;
    }

    // Check if it's a file:// URL (invalid for network)
    if (imageUrl.startsWith('file://')) {
      return errorWidget ?? _defaultErrorWidget(context);
    }

    // Preload image if requested (only for network images)
    if (preload && imageUrl.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ImagePreloadService().preloadImage(imageUrl, priority: false);
      });
    }

    // Calculate cache dimensions with 2x resolution for better quality (retina display support)
    // This prevents blurriness on high-DPI screens
    final double devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    final int? cacheWidth = width != null && width!.isFinite 
        ? (width! * devicePixelRatio).round().clamp(1, 2048)
        : null;
    final int? cacheHeight = height != null && height!.isFinite 
        ? (height! * devicePixelRatio).round().clamp(1, 2048)
        : null;

    // Wrap in Builder to catch exceptions at widget level
    return Builder(
      builder: (context) {
        try {
          Widget image = CachedNetworkImage(
            imageUrl: imageUrl,
            width: width,
            height: height,
            fit: fit,
            httpHeaders: headers,
            placeholder: (context, url) => placeholder ?? _defaultPlaceholder(context),
            errorWidget: (context, url, error) {
              // Log the error for debugging
              print('❌ Error loading network image: $url');
              if (error != null) {
                print('   Error type: ${error.runtimeType}');
                print('   Error message: $error');
                // Check for 404 specifically
                if (error.toString().contains('404') || 
                    error.toString().contains('HttpException') ||
                    error.toString().contains('statusCode: 404')) {
                  print('   ⚠️ Image not found (404): $url');
                }
              }
              return errorWidget ?? _defaultErrorWidget(context);
            },
            fadeInDuration: const Duration(milliseconds: 200),
            fadeOutDuration: const Duration(milliseconds: 100),
            // Use 2x resolution for better quality (prevents blur on high-DPI screens)
            memCacheWidth: cacheWidth,
            memCacheHeight: cacheHeight,
            // Use max width/height to reduce memory footprint
            maxWidthDiskCache: 2048,
            maxHeightDiskCache: 2048,
            // Use high quality filter for better image rendering
            imageBuilder: (context, imageProvider) {
              return Image(
                image: imageProvider,
                width: width,
                height: height,
                fit: fit,
                filterQuality: FilterQuality.high, // High quality filter for sharp images
                errorBuilder: (context, error, stackTrace) {
                  // Fallback error handler for Image widget
                  print('❌ Error in Image widget: $error');
                  if (stackTrace != null) {
                    print('   Stack trace: $stackTrace');
                  }
                  return errorWidget ?? _defaultErrorWidget(context);
                },
                // Add frameBuilder to catch errors during image loading
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (frame == null) {
                    // Image is still loading
                    return placeholder ?? _defaultPlaceholder(context);
                  }
                  return child;
                },
              );
            },
          );

          if (borderRadius != null) {
            image = ClipRRect(
              borderRadius: borderRadius!,
              child: image,
            );
          }

          return image;
        } catch (e, stackTrace) {
          // Catch any exceptions during widget build
          print('❌ Exception in CachedImage build: $e');
          print('   Stack trace: $stackTrace');
          return errorWidget ?? _defaultErrorWidget(context);
        }
      },
    );
  }

  Widget _defaultPlaceholder(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey.shade200,
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: const Color(0xFF8B4513),
        ),
      ),
    );
  }

  Widget _defaultErrorWidget(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey.shade300,
      child: Icon(
        Icons.image_not_supported,
        size: ResponsiveHelper.iconSize(context, mobile: 32),
        color: Colors.grey,
      ),
    );
  }
}

/// Lazy Loading Image Widget
/// Only loads image when it's about to become visible
class LazyCachedImage extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;
  final Map<String, String>? headers;
  final double threshold; // Distance from viewport to start loading (in pixels)

  const LazyCachedImage({
    Key? key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
    this.headers,
    this.threshold = 200.0, // Start loading 200px before visible
  }) : super(key: key);

  @override
  State<LazyCachedImage> createState() => _LazyCachedImageState();
}

class _LazyCachedImageState extends State<LazyCachedImage> {
  bool _isVisible = false;
  final GlobalKey _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Check visibility after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkVisibility();
    });
  }

  void _checkVisibility() {
    if (!mounted) return;

    final RenderObject? renderObject = _key.currentContext?.findRenderObject();
    if (renderObject == null) return;

    final RenderBox renderBox = renderObject as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    // Get screen height
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // Check if widget is visible or about to be visible
    final isVisible = position.dy + size.height + widget.threshold >= 0 &&
        position.dy - widget.threshold <= screenHeight &&
        position.dx + size.width >= 0 &&
        position.dx <= screenWidth;

    if (isVisible && !_isVisible) {
      setState(() {
        _isVisible = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        _checkVisibility();
        return false;
      },
      child: Container(
        key: _key,
        width: widget.width,
        height: widget.height,
        child: _isVisible
            ? CachedImage(
                imageUrl: widget.imageUrl,
                width: widget.width,
                height: widget.height,
                fit: widget.fit,
                placeholder: widget.placeholder,
                errorWidget: widget.errorWidget,
                borderRadius: widget.borderRadius,
                headers: widget.headers,
              )
            : (widget.placeholder ?? _defaultPlaceholder()),
      ),
    );
  }

  Widget _defaultPlaceholder() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.grey.shade200,
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: const Color(0xFF8B4513),
        ),
      ),
    );
  }
}

