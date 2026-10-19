import 'package:flutter/material.dart';
import 'package:fruitsofspirit/services/videos_service.dart';
import 'package:fruitsofspirit/utils/app_theme.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';
import 'package:fruitsofspirit/widgets/cached_image.dart';
import 'package:fruitsofspirit/widgets/custom_video_thumbnail.dart';

/// Shows each video's own thumbnail: DB image first, then that video's first frame.
class VideoThumbnailWidget extends StatelessWidget {
  final Map<String, dynamic> video;
  final BoxFit fit;
  final double? width;
  final double? height;
  /// When DB/inferred image missing or fails, extract one frame (max 2 concurrent).
  final bool useVideoFrameFallback;

  const VideoThumbnailWidget({
    Key? key,
    required this.video,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.useVideoFrameFallback = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final thumbnailUrl = VideosService.getThumbnailUrl(video);
    final videoUrl = VideosService.getVideoUrl(video);
    final videoKey = video['id']?.toString() ?? videoUrl ?? thumbnailUrl ?? '';

    if (thumbnailUrl != null) {
      return CachedImage(
        key: ValueKey('thumb-$videoKey-$thumbnailUrl'),
        imageUrl: thumbnailUrl,
        width: width,
        height: height,
        fit: fit,
        fadeInDuration: Duration.zero,
        errorWidget: useVideoFrameFallback && videoUrl != null
            ? CustomVideoThumbnail(
                key: ValueKey('frame-$videoKey-$videoUrl'),
                videoUrl: videoUrl,
                fit: fit,
                width: width,
                height: height,
              )
            : _placeholder(context),
      );
    }

    if (useVideoFrameFallback && videoUrl != null) {
      return CustomVideoThumbnail(
        key: ValueKey('frame-$videoKey-$videoUrl'),
        videoUrl: videoUrl,
        fit: fit,
        width: width,
        height: height,
      );
    }

    return _placeholder(context);
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      width: width,
      height: height,
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
    );
  }
}
