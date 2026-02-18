import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../utils/app_theme.dart';
import '../utils/responsive_helper.dart';

class VideoFrameThumbnail extends StatefulWidget {
  final String videoUrl;
  final BoxFit fit;
  final double? width;
  final double? height;

  const VideoFrameThumbnail({
    Key? key,
    required this.videoUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  }) : super(key: key);

  @override
  _VideoFrameThumbnailState createState() => _VideoFrameThumbnailState();
}

class _VideoFrameThumbnailState extends State<VideoFrameThumbnail> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await _controller!.initialize();
      
      // Seek to first frame (0 seconds) and pause
      await _controller!.seekTo(Duration.zero);
      await _controller!.pause();
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _hasError = false;
        });
      }
    } catch (e) {
      print('Error initializing video thumbnail: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isInitialized = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        width: widget.width,
        height: widget.height,
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
      );
    }

    if (!_isInitialized || _controller == null || !_controller!.value.isInitialized) {
      return Container(
        width: widget.width,
        height: widget.height,
        color: Colors.grey[300],
        child: Center(
          child: CircularProgressIndicator(
            color: AppTheme.iconscolor,
            strokeWidth: 2,
          ),
        ),
      );
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: FittedBox(
        fit: widget.fit,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: _controller!.value.size.width,
          height: _controller!.value.size.height,
          child: VideoPlayer(_controller!),
        ),
      ),
    );
  }
}
