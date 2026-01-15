import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';
import 'package:fruitsofspirit/services/live_streaming_service.dart';

/// Live Video Player Widget
/// Handles live video streaming with HLS/RTMP support
class LiveVideoPlayer extends StatefulWidget {
  final Map<String, dynamic> liveStream;
  final bool autoPlay;
  final bool showControls;

  const LiveVideoPlayer({
    Key? key,
    required this.liveStream,
    this.autoPlay = true,
    this.showControls = true,
  }) : super(key: key);

  @override
  State<LiveVideoPlayer> createState() => _LiveVideoPlayerState();
}

class _LiveVideoPlayerState extends State<LiveVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = null;
      });

      // Get stream URL
      final streamUrl = LiveStreamingService.getStreamUrl(widget.liveStream);
      
      if (streamUrl == null || streamUrl.isEmpty) {
        throw Exception('No stream URL available');
      }

      print('🔴 Initializing live stream: $streamUrl');

      // Initialize video player
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(streamUrl),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: false,
          allowBackgroundPlayback: false,
        ),
      );

      // Add listener for player state
      _controller!.addListener(_videoListener);

      // Initialize player
      await _controller!.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isLoading = false;
        });

        // Auto-play if enabled
        if (widget.autoPlay) {
          await _controller!.play();
          setState(() {
            _isPlaying = true;
          });
        }
      }
    } catch (e) {
      print('❌ Error initializing live stream: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _videoListener() {
    if (_controller == null || !mounted) return;

    final isPlaying = _controller!.value.isPlaying;
    if (isPlaying != _isPlaying) {
      setState(() {
        _isPlaying = isPlaying;
      });
    }

    // Check for errors
    if (_controller!.value.hasError) {
      if (mounted && !_hasError) {
        setState(() {
          _hasError = true;
          _errorMessage = _controller!.value.errorDescription ?? 'Video playback error';
        });
      }
    }
  }

  Future<void> _togglePlayPause() async {
    if (_controller == null || !_isInitialized) return;

    try {
      if (_isPlaying) {
        await _controller!.pause();
      } else {
        await _controller!.play();
      }
    } catch (e) {
      print('Error toggling play/pause: $e');
    }
  }

  Future<void> _retry() async {
    await _controller?.dispose();
    _controller = null;
    await _initializePlayer();
  }

  @override
  void dispose() {
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              SizedBox(height: ResponsiveHelper.spacing(context, 16)),
              Text(
                'Loading live stream...',
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_hasError) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.red,
                size: ResponsiveHelper.iconSize(context, mobile: 48),
              ),
              SizedBox(height: ResponsiveHelper.spacing(context, 16)),
              Padding(
                padding: ResponsiveHelper.padding(context, horizontal: 16),
                child: Text(
                  _errorMessage ?? 'Failed to load live stream',
                  style: ResponsiveHelper.textStyle(
                    context,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: ResponsiveHelper.spacing(context, 24)),
              ElevatedButton(
                onPressed: _retry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC79211),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized || _controller == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }

    return Stack(
      children: [
        // Video Player
        AspectRatio(
          aspectRatio: _controller!.value.aspectRatio,
          child: VideoPlayer(_controller!),
        ),

        // Live Badge
        if (widget.liveStream['status'] == 'Live')
          Positioned(
            top: ResponsiveHelper.spacing(context, 12),
            right: ResponsiveHelper.spacing(context, 12),
            child: Container(
              padding: ResponsiveHelper.padding(
                context,
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(
                  ResponsiveHelper.borderRadius(context, mobile: 20),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: ResponsiveHelper.spacing(context, 6)),
                  Text(
                    'LIVE',
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Controls Overlay
        if (widget.showControls)
          Positioned.fill(
            child: GestureDetector(
              onTap: _togglePlayPause,
              child: Container(
                color: Colors.transparent,
                child: Center(
                  child: AnimatedOpacity(
                    opacity: _isPlaying ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      padding: ResponsiveHelper.padding(context, all: 16),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: ResponsiveHelper.iconSize(context, mobile: 40),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

