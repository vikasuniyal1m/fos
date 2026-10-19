import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:fruitsofspirit/utils/app_theme.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';
import 'package:fruitsofspirit/widgets/cached_image.dart';
import 'package:fruitsofspirit/widgets/video_frame_thumbnail.dart';

class BlogMediaWidget extends StatelessWidget {
  final String? mediaUrl;
  final bool isVideo;
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool previewMode;

  const BlogMediaWidget({
    Key? key,
    required this.mediaUrl,
    required this.isVideo,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.previewMode = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final url = mediaUrl?.trim() ?? '';
    if (url.isEmpty) {
      return _placeholder(context);
    }

    if (isVideo) {
      if (previewMode) {
        return VideoFrameThumbnail(
          videoUrl: url,
          width: width,
          height: height,
          fit: fit,
        );
      }
      return BlogVideoPlayer(
        videoUrl: url,
        width: width,
        height: height,
        fit: fit,
      );
    }

    return CachedImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      errorWidget: _placeholder(context),
    );
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey.shade200,
      child: Icon(
        isVideo ? Icons.video_library_rounded : Icons.image_not_supported,
        size: ResponsiveHelper.iconSize(context, mobile: 36, tablet: 44, desktop: 52),
        color: AppTheme.iconscolor,
      ),
    );
  }
}

class BlogVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final double? width;
  final double? height;
  final BoxFit fit;

  const BlogVideoPlayer({
    Key? key,
    required this.videoUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  }) : super(key: key);

  @override
  State<BlogVideoPlayer> createState() => _BlogVideoPlayerState();
}

class _BlogVideoPlayerState extends State<BlogVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void didUpdateWidget(BlogVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _initializePlayer();
    }
  }

  Future<void> _initializePlayer() async {
    _controller?.removeListener(_onPlayerChanged);
    await _controller?.dispose();
    _controller = null;

    setState(() {
      _isInitialized = false;
      _isPlaying = false;
      _hasError = false;
    });

    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _controller = controller;
      await controller.initialize();
      await controller.pause();
      controller.addListener(_onPlayerChanged);

      if (!mounted) return;
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
      });
    }
  }

  void _onPlayerChanged() {
    if (!mounted || _controller == null) return;
    final playing = _controller!.value.isPlaying;
    if (playing != _isPlaying) {
      setState(() {
        _isPlaying = playing;
      });
    }
    if (_controller!.value.hasError && !_hasError) {
      setState(() {
        _hasError = true;
      });
    }
  }

  Future<void> _togglePlayPause() async {
    if (_controller == null || !_isInitialized) return;
    if (_controller!.value.isPlaying) {
      await _controller!.pause();
    } else {
      await _controller!.play();
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onPlayerChanged);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        width: widget.width,
        height: widget.height,
        color: Colors.black,
        child: Center(
          child: Icon(
            Icons.error_outline,
            color: Colors.white,
            size: ResponsiveHelper.iconSize(context, mobile: 36, tablet: 44, desktop: 52),
          ),
        ),
      );
    }

    if (!_isInitialized || _controller == null) {
      return Container(
        width: widget.width,
        height: widget.height,
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return GestureDetector(
      onTap: _togglePlayPause,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: widget.width,
            height: widget.height,
            child: AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: VideoPlayer(_controller!),
            ),
          ),
          if (!_isPlaying)
            Container(
              width: widget.width,
              height: widget.height,
              color: Colors.black26,
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: ResponsiveHelper.iconSize(context, mobile: 42, tablet: 48, desktop: 56),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
