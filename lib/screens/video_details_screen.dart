import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/controllers/videos_controller.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';
import 'package:video_player/video_player.dart';
import 'package:fruitsofspirit/config/image_config.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fruitsofspirit/utils/image_helper.dart';
import 'package:fruitsofspirit/widgets/live_video_player.dart';
import 'package:fruitsofspirit/services/live_streaming_service.dart';
import 'package:fruitsofspirit/services/comments_service.dart';
import 'package:fruitsofspirit/services/user_storage.dart';
import 'package:fruitsofspirit/widgets/cached_image.dart';
import 'package:fruitsofspirit/screens/home_screen.dart';
import 'package:fruitsofspirit/widgets/standard_app_bar.dart';
import 'package:fruitsofspirit/utils/app_theme.dart';
import 'package:fruitsofspirit/utils/fruit_emoji_helper.dart';
import 'package:fruitsofspirit/services/user_blocking_service.dart';
import 'package:fruitsofspirit/screens/report_content_screen.dart';
import 'dart:async';

/// Video Details Screen - Modern Social Media Style
class VideoDetailsScreen extends StatefulWidget {
  const VideoDetailsScreen({Key? key}) : super(key: key);

  @override
  State<VideoDetailsScreen> createState() => _VideoDetailsScreenState();
}

class _VideoDetailsScreenState extends State<VideoDetailsScreen> with SingleTickerProviderStateMixin {
  final VideosController controller = Get.find<VideosController>();
  final commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final replyControllers = <int, TextEditingController>{};
  final showReplyInput = <int, bool>{};
  final expandedReplies = <int>{}; // Track which replies are expanded
  var userId = 0;
  var isLoading = false;
  var comments = <Map<String, dynamic>>[];
  
  // Video player state
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _hasVideoError = false;
  String? _videoError;
  bool _showControls = true;
  bool _isFullScreen = false;
  double _videoAspectRatio = 16 / 9;
  Timer? _controlsTimer;
  late AnimationController _fadeAnimationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controller
    _fadeAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeAnimationController, curve: Curves.easeInOut),
    );
    _fadeAnimationController.forward();
    
    _loadUserId();
    final videoId = Get.arguments as int? ?? 0;
    if (videoId > 0 && (controller.selectedVideo.isEmpty || controller.selectedVideo['id'] != videoId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await controller.loadVideoDetails(videoId);
        controller.loadAvailableEmojis(); // Load all available emojis for reactions mapping
        controller.loadQuickEmojis();
        _loadComments(videoId);
        
        // Initialize video after video details are loaded
        if (controller.selectedVideo.isNotEmpty) {
          final video = controller.selectedVideo;
          final filePath = video['file_path'] as String? ?? '';
          if (filePath.isNotEmpty) {
            final baseUrl = 'https://fruitofthespirit.templateforwebsites.com/';
            final videoUrl = filePath.startsWith('http') 
                ? filePath 
                : baseUrl + (filePath.startsWith('/') ? filePath.substring(1) : filePath);
            if (videoUrl.isNotEmpty && !videoUrl.contains('Live')) {
              _initializeVideo(videoUrl);
            }
          }
        }
      });
    } else if (controller.selectedVideo.isNotEmpty) {
      final videoId = controller.selectedVideo['id'] as int? ?? 0;
      if (videoId > 0) {
        _loadComments(videoId);
      }
      
      // Initialize video if already loaded
      final video = controller.selectedVideo;
      final filePath = video['file_path'] as String? ?? '';
      if (filePath.isNotEmpty) {
        final baseUrl = 'https://fruitofthespirit.templateforwebsites.com/';
        final videoUrl = filePath.startsWith('http') 
            ? filePath 
            : baseUrl + (filePath.startsWith('/') ? filePath.substring(1) : filePath);
        if (videoUrl.isNotEmpty && !videoUrl.contains('Live')) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _initializeVideo(videoUrl);
          });
        }
      }
    }
  }
  
  Future<void> _initializeVideo(String videoUrl) async {
    try {
      setState(() {
        _hasVideoError = false;
        _videoError = null;
        _isVideoInitialized = false;
      });
      
      print('🎥 Initializing video from URL: $videoUrl');
      
      // Dispose previous controller if exists
      await _videoController?.dispose();
      
      _videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      await _videoController!.initialize();
      
      // Listen to video player state changes
      _videoController!.addListener(_videoPlayerListener);
      
      // Auto-play video
      await _videoController!.play();
      
      setState(() {
        _isVideoInitialized = true;
        _hasVideoError = false;
        _videoAspectRatio = _videoController!.value.aspectRatio;
      });
      
      print('✅ Video initialized successfully with AspectRatio: $_videoAspectRatio');
    } catch (e) {
      print('❌ Error initializing video: $e');
      setState(() {
        _hasVideoError = true;
        _videoError = e.toString();
        _isVideoInitialized = false;
      });
    }
  }
  
  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    
    // Auto-hide controls after 3 seconds
    _controlsTimer?.cancel();
    if (_showControls) {
      _controlsTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _showControls = false;
          });
        }
      });
    }
  }
  
  void _videoPlayerListener() {
    if (_videoController != null && _videoController!.value.hasError) {
      // Defer setState to avoid calling during build/layout phase
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _hasVideoError = true;
            _videoError = _videoController!.value.errorDescription ?? 'Unknown error';
          });
        }
      });
    } else if (_videoController != null && _videoController!.value.isInitialized) {
      // Update aspect ratio if it changes
      if (_videoController!.value.aspectRatio != _videoAspectRatio) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _videoAspectRatio = _videoController!.value.aspectRatio;
            });
          }
        });
      }
      
      // Update UI when video state changes - defer to avoid build phase issues
      if (mounted) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {});
          }
        });
      }
    }
  }
  
  void _togglePlayPause() {
    if (_videoController != null && _videoController!.value.isInitialized) {
      if (_videoController!.value.isPlaying) {
        _videoController!.pause();
      } else {
        _videoController!.play();
      }
      _toggleControls();
    }
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });

    if (_isFullScreen) {
      // Logic for entering full screen (orientation change)
      // This is often handled by the system or a plugin, 
      // but we ensure our UI reacts gracefully.
    }
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    _videoController?.removeListener(_videoPlayerListener);
    _videoController?.dispose();
    _fadeAnimationController.dispose();
    commentController.dispose();
    _scrollController.dispose();
    for (var controller in replyControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadUserId() async {
    final id = await UserStorage.getUserId();
    if (id != null) {
      setState(() {
        userId = id;
      });
    }
  }
  
  Widget _buildVideoPlayer(String videoUrl) {
    // Initialize video if not already initialized
    if (_videoController == null && !_hasVideoError) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initializeVideo(videoUrl);
      });
    }
    
    if (_hasVideoError) {
      return _buildVideoErrorState(videoUrl);
    }
    
    if (!_isVideoInitialized || _videoController == null) {
      return _buildVideoLoadingState();
    }
    
    return _buildVideoPlayerWithControls();
  }
  
  Widget _buildVideoLoadingState() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: AppTheme.iconscolor,
              strokeWidth: 3,
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 16)),
            Text(
              'Loading video...',
              style: ResponsiveHelper.textStyle(
                context,
                fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildVideoErrorState(String videoUrl) {
    return Container(
      color: Colors.black87,
      child: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 16 : 20)),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.error_outline_rounded,
                    size: ResponsiveHelper.iconSize(context, mobile: 60, tablet: 64, desktop: 68),
                    color: Colors.red[300],
                  ),
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 16 : 20)),
                Text(
                  'Video Not Available',
                  style: ResponsiveHelper.textStyle(
                    context,
                    fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 17, desktop: 18),
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 6 : 8)),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 20 : 24),
                  ),
                  child: Text(
                    'The video file may not exist or the URL is invalid. Please try again later.',
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: ResponsiveHelper.fontSize(context, mobile: 12, tablet: 13, desktop: 14),
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 20 : 24)),
                ElevatedButton.icon(
                  onPressed: () {
                    _initializeVideo(videoUrl);
                  },
                  icon: Icon(Icons.refresh_rounded, size: ResponsiveHelper.iconSize(context, mobile: 18, tablet: 20, desktop: 22)),
                  label: Text(
                    'Retry',
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: ResponsiveHelper.fontSize(context, mobile: 13, tablet: 14, desktop: 15),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveHelper.spacing(context, 24),
                    vertical: ResponsiveHelper.spacing(context, 12),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      ResponsiveHelper.borderRadius(context, mobile: 25),
                    ),
                  ),
                  elevation: 4,
                ),
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildVideoPlayerWithControls() {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return _buildVideoLoadingState();
    }
    
    return GestureDetector(
      onTap: _toggleControls,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video Player
          Center(
            child: AspectRatio(
              aspectRatio: _videoController!.value.aspectRatio,
              child: VideoPlayer(_videoController!),
            ),
          ),
          
          // Controls Overlay
          AnimatedOpacity(
            opacity: _showControls ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withOpacity(0.5),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  // Play/Pause Button (Center)
                  Center(
                    child: GestureDetector(
                      onTap: _togglePlayPause,
                      child: Container(
                        padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 16)),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _videoController!.value.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: ResponsiveHelper.iconSize(context, mobile: 48),
                        ),
                      ),
                    ),
                  ),
                  
                  // Video Info (Bottom Left)
                  Positioned(
                    left: ResponsiveHelper.spacing(context, 12),
                    bottom: ResponsiveHelper.spacing(context, 12),
                    right: ResponsiveHelper.spacing(context, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Duration
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: ResponsiveHelper.spacing(context, 8),
                            vertical: ResponsiveHelper.spacing(context, 4),
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(
                              ResponsiveHelper.borderRadius(context, mobile: 8),
                            ),
                          ),
                          child: Text(
                            _formatDuration(_videoController!.value.position) +
                                ' / ' +
                                _formatDuration(_videoController!.value.duration),
                            style: ResponsiveHelper.textStyle(
                              context,
                              fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        
                        // Full Screen Button
                        GestureDetector(
                          onTap: _toggleFullScreen,
                          child: Icon(
                            _isFullScreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                            color: Colors.white,
                            size: ResponsiveHelper.iconSize(context, mobile: 24),
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
    );
  }
  
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Future<void> _loadComments(int videoId) async {
    setState(() {
      isLoading = true;
    });

    try {
      final commentsList = await CommentsService.getComments(
        postType: 'video',
        postId: videoId,
        userId: userId > 0 ? userId : null,
      );

      // Flatten nested comments structure for easier UI rendering
      final flattenedComments = <Map<String, dynamic>>[];
      void flattenComments(List<dynamic> commentsList, {int? parentId}) {
        for (var comment in commentsList) {
          final commentMap = Map<String, dynamic>.from(comment);
          if (parentId != null) {
            commentMap['parent_comment_id'] = parentId;
          }
          flattenedComments.add(commentMap);
          
          // If comment has replies, flatten them recursively
          if (comment['replies'] != null && (comment['replies'] as List).isNotEmpty) {
            flattenComments(comment['replies'] as List, parentId: comment['id'] as int);
          }
        }
      }

      flattenComments(commentsList);
      
      setState(() {
        comments = flattenedComments;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print('Error loading comments: $e');
    }
  }

  Future<void> _addComment(int videoId, {int? parentCommentId}) async {
    final content = parentCommentId != null
        ? (replyControllers[parentCommentId]?.text ?? '').trim()
        : commentController.text.trim();

    if (content.isEmpty) return;

    if (userId == 0) {
      Get.snackbar(
        'Error',
        'Please login first',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    try {
      await CommentsService.addComment(
        userId: userId,
        postType: 'video',
        postId: videoId,
        content: content,
        parentCommentId: parentCommentId,
      );

      // Show success message
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Get.snackbar(
              'Success',
              parentCommentId != null ? 'Reply added successfully' : 'Comment added successfully',
              backgroundColor: Colors.green,
              colorText: Colors.white,
              duration: const Duration(seconds: 2),
              margin: const EdgeInsets.all(16),
            );
          }
        });
      }

      // Clear controllers
      if (parentCommentId != null) {
        replyControllers[parentCommentId]?.clear();
        showReplyInput[parentCommentId] = false;
      } else {
        commentController.clear();
      }

      // Wait a bit for backend to update
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Reload comments
      await _loadComments(videoId);
      
      // Expand parent comment if it's a reply
      if (parentCommentId != null) {
        expandedReplies.add(parentCommentId);
      }

      Get.snackbar(
        'Success',
        'Comment added successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        e.toString().replaceAll('Exception: ', ''),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _toggleCommentLike(int commentId) async {
    if (userId == 0) {
      Get.snackbar(
        'Error',
        'Please login first',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    try {
      final result = await controller.toggleCommentLike(commentId);
      if (result != null) {
        // Reload comments to update like status
        final videoId = controller.selectedVideo['id'] as int? ?? 0;
        if (videoId > 0) {
          await _loadComments(videoId);
        }
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        e.toString().replaceAll('Exception: ', ''),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  bool _checkCommentLiked(Map<String, dynamic> comment) {
    return comment['is_liked'] == true || comment['is_liked'] == 1;
  }

  @override
  Widget build(BuildContext context) {
    final videoId = Get.arguments as int? ?? 0;
    final baseUrl = 'https://fruitofthespirit.templateforwebsites.com/';

    return Scaffold(
      backgroundColor: AppTheme.themeColor,
      appBar: const StandardAppBar(
        showBackButton: true,
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.selectedVideo.isEmpty) {
          return Center(
            child: CircularProgressIndicator(
              color: AppTheme.iconscolor,
            ),
          );
        }

        if (controller.selectedVideo.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: ResponsiveHelper.iconSize(context, mobile: 64),
                  color: Colors.grey[400],
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                Text(
                  'Video not found',
                  style: ResponsiveHelper.textStyle(
                    context,
                    fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        final video = controller.selectedVideo;
        final filePath = video['file_path'] as String? ?? '';
        final videoUrl = filePath.isNotEmpty 
            ? (filePath.startsWith('http') ? filePath : baseUrl + (filePath.startsWith('/') ? filePath.substring(1) : filePath))
            : '';
        final isLiveVideo = video['status'] == 'Live' ||
            video['stream_key'] != null ||
            video['hls_url'] != null ||
            video['rtmp_url'] != null;
        
        // Validate video URL before trying to play
        if (!isLiveVideo && (videoUrl.isEmpty || !videoUrl.contains('.'))) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.video_library_outlined,
                  size: ResponsiveHelper.iconSize(context, mobile: 64),
                  color: Colors.grey[400],
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                Text(
                  'Video URL not available',
                  style: ResponsiveHelper.textStyle(
                    context,
                    fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, 8)),
                Text(
                  'Please check video file path',
                  style: ResponsiveHelper.textStyle(
                    context,
                    fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Video Player Area
                    AspectRatio(
                      aspectRatio: (MediaQuery.of(context).orientation == Orientation.landscape && _isFullScreen)
                          ? MediaQuery.of(context).size.aspectRatio
                          : (MediaQuery.of(context).orientation == Orientation.landscape) ? 21 / 9 : 16 / 9,
                      child: Container(
                        width: double.infinity,
                        color: Colors.black,
                        child: isLiveVideo
                            ? LiveVideoPlayer(
                                liveStream: video,
                                autoPlay: true,
                                showControls: true,
                              )
                            : videoUrl.isNotEmpty
                                ? _buildVideoPlayer(videoUrl)
                                : Image.network(
                                    ImageConfig.videoThumbnail,
                                    fit: BoxFit.cover,
                                  ),
                      ),
                    ),

                    // Video Info Card - Matching Home Page Theme
                    Container(
                      margin: EdgeInsets.all(ResponsiveHelper.spacing(context, 12)),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(
                          ResponsiveHelper.borderRadius(context, mobile: 20),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            spreadRadius: 0,
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                          BoxShadow(
                            color: const Color(0xFF8B4513).withOpacity(0.05),
                            spreadRadius: 2,
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header with User Info
                          Container(
                            padding: ResponsiveHelper.padding(
                              context,
                              horizontal: 16,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white,
                                  Colors.grey[50]!,
                                ],
                              ),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(
                                  ResponsiveHelper.borderRadius(context, mobile: 20),
                                ),
                                topRight: Radius.circular(
                                  ResponsiveHelper.borderRadius(context, mobile: 20),
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                // Profile Picture
                                Container(
                                  width: ResponsiveHelper.imageWidth(
                                    context,
                                    mobile: 48,
                                    tablet: 52,
                                    desktop: 56,
                                  ),
                                  height: ResponsiveHelper.imageWidth(
                                    context,
                                    mobile: 48,
                                    tablet: 52,
                                    desktop: 56,
                                  ),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(0xFF8B4513).withOpacity(0.2),
                                        const Color(0xFF5F4628).withOpacity(0.1),
                                      ],
                                    ),
                                    border: Border.all(
                                      color: const Color(0xFF8B4513).withOpacity(0.3),
                                      width: 2,
                                    ),
                                  ),
                                  child: ClipOval(
                                    child: video['profile_photo'] != null &&
                                            (video['profile_photo'] as String).isNotEmpty
                                        ? CachedImage(
                                            imageUrl: (video['profile_photo'] as String).startsWith('http://') || (video['profile_photo'] as String).startsWith('https://')
                                                ? (video['profile_photo'] as String)
                                                : baseUrl + (video['profile_photo'] as String),
                                            width: double.infinity,
                                            height: double.infinity,
                                            fit: BoxFit.cover,
                                            errorWidget: Icon(
                                              Icons.person_rounded,
                                              size: ResponsiveHelper.iconSize(context, mobile: 24),
                                              color: AppTheme.iconscolor,
                                            ),
                                          )
                                        : Icon(
                                            Icons.person_rounded,
                                            size: ResponsiveHelper.iconSize(context, mobile: 24),
                                            color: AppTheme.iconscolor,
                                          ),
                                  ),
                                ),
                                SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        video['user_name'] as String? ?? video['name'] as String? ?? 'Anonymous',
                                        style: ResponsiveHelper.textStyle(
                                          context,
                                          fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                      SizedBox(height: ResponsiveHelper.spacing(context, 2)),
                                      Text(
                                        'Blogger',
                                        style: ResponsiveHelper.textStyle(
                                          context,
                                          fontSize: ResponsiveHelper.fontSize(context, mobile: 13),
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Share Button
                                InkWell(
                                  onTap: () async {
                                    final success = await controller.shareVideo(videoId);
                                    if (success) {
                                      final shareUrl = '$baseUrl/share/video/$videoId';
                                      final uri = Uri.parse(shareUrl);
                                      if (await canLaunchUrl(uri)) {
                                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                                      } else {
                                        Get.snackbar(
                                          'Share Link',
                                          shareUrl,
                                          backgroundColor: Colors.blue,
                                          colorText: Colors.white,
                                          duration: const Duration(seconds: 5),
                                        );
                                      }
                                    } else {
                                      Get.snackbar(
                                        'Error',
                                        controller.message.value,
                                        backgroundColor: Colors.red,
                                        colorText: Colors.white,
                                      );
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(
                                    ResponsiveHelper.borderRadius(context, mobile: 8),
                                  ),
                                  child: Container(
                                    padding: ResponsiveHelper.padding(
                                      context,
                                      all: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.iconscolor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(
                                        ResponsiveHelper.borderRadius(context, mobile: 8),
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.share_rounded,
                                      size: ResponsiveHelper.iconSize(context, mobile: 22),
                                      color: AppTheme.iconscolor,
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
                              all: 16,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Title
                                if (video['title'] != null)
                                  Padding(
                                    padding: EdgeInsets.only(
                                      bottom: ResponsiveHelper.spacing(context, 8),
                                    ),
                                    child: Text(
                                      video['title'] as String? ?? 'Untitled Video',
                                      style: ResponsiveHelper.textStyle(
                                        context,
                                        fontSize: ResponsiveHelper.fontSize(context, mobile: 20),
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),

                                // Fruit Tag
                                if (video['fruit_tag'] != null)
                                  Container(
                                    margin: EdgeInsets.only(
                                      bottom: ResponsiveHelper.spacing(context, 12),
                                    ),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: ResponsiveHelper.spacing(context, 14),
                                      vertical: ResponsiveHelper.spacing(context, 8),
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          const Color(0xFF8B4513).withOpacity(0.15),
                                          const Color(0xFF8B4513).withOpacity(0.08),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        ResponsiveHelper.borderRadius(context, mobile: 25),
                                      ),
                                      border: Border.all(
                                        color: const Color(0xFF8B4513).withOpacity(0.3),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.local_fire_department_rounded,
                                          size: ResponsiveHelper.iconSize(context, mobile: 16),
                                          color: AppTheme.iconscolor,
                                        ),
                                        SizedBox(width: ResponsiveHelper.spacing(context, 6)),
                                        Text(
                                          video['fruit_tag'] as String,
                                          style: ResponsiveHelper.textStyle(
                                            context,
                                            fontSize: ResponsiveHelper.fontSize(context, mobile: 13),
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.iconscolor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                // Description
                                if (video['description'] != null)
                                  Text(
                                    video['description'] as String? ?? '',
                                    style: ResponsiveHelper.textStyle(
                                      context,
                                      fontSize: ResponsiveHelper.fontSize(context, mobile: 15),
                                      color: Colors.black87,
                                      height: 1.6,
                                    ),
                                  ),

                                SizedBox(height: ResponsiveHelper.spacing(context, 16)),

                                // Emoji Reactions Section
                                _buildEmojiReactions(context, videoId, controller),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Comments Section
                    Container(
                      margin: EdgeInsets.only(
                        bottom: ResponsiveHelper.spacing(context, 12),
                        left: ResponsiveHelper.spacing(context, 12),
                        right: ResponsiveHelper.spacing(context, 12),
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(
                          ResponsiveHelper.borderRadius(context, mobile: 20),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            spreadRadius: 0,
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                          BoxShadow(
                            color: const Color(0xFF8B4513).withOpacity(0.05),
                            spreadRadius: 2,
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Comments Header
                          Container(
                            padding: ResponsiveHelper.padding(
                              context,
                              horizontal: 16,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white,
                                  Colors.grey[50]!,
                                ],
                              ),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(
                                  ResponsiveHelper.borderRadius(context, mobile: 20),
                                ),
                                topRight: Radius.circular(
                                  ResponsiveHelper.borderRadius(context, mobile: 20),
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(
                                    ResponsiveHelper.spacing(context, 8),
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(0xFF8B4513).withOpacity(0.15),
                                        const Color(0xFF8B4513).withOpacity(0.08),
                                      ],
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.comment_rounded,
                                    size: ResponsiveHelper.iconSize(context, mobile: 22),
                                    color: AppTheme.iconscolor,
                                  ),
                                ),
                                SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Comments',
                                        style: ResponsiveHelper.textStyle(
                                          context,
                                          fontSize: ResponsiveHelper.fontSize(context, mobile: 18),
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                      Text(
                                        '${comments.length} ${comments.length == 1 ? 'comment' : 'comments'}',
                                        style: ResponsiveHelper.textStyle(
                                          context,
                                          fontSize: ResponsiveHelper.fontSize(context, mobile: 13),
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _buildVideoOptions(context, video),
                              ],
                            ),
                          ),

                          // Comments List
                          Builder(
                            builder: (context) {
                              // Filter top-level comments
                              final topLevelComments = comments.where((comment) {
                                final parentId = comment['parent_comment_id'];
                                if (parentId == null) return true;
                                if (parentId is int) return parentId == 0;
                                if (parentId is String) {
                                  final parsed = int.tryParse(parentId);
                                  return parsed == null || parsed == 0;
                                }
                                return false;
                              }).toList();

                              if (topLevelComments.isEmpty) {
                                return Padding(
                                  padding: ResponsiveHelper.padding(context, all: 24),
                                  child: Center(
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.chat_bubble_outline,
                                          size: ResponsiveHelper.iconSize(context, mobile: 48),
                                          color: Colors.grey[400],
                                        ),
                                        SizedBox(height: ResponsiveHelper.spacing(context, 12)),
                                        Text(
                                          'No comments yet',
                                          style: ResponsiveHelper.textStyle(
                                            context,
                                            fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        SizedBox(height: ResponsiveHelper.spacing(context, 4)),
                                        Text(
                                          'Be the first to comment!',
                                          style: ResponsiveHelper.textStyle(
                                            context,
                                            fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }

                              return Column(
                                children: topLevelComments.map(
                                  (comment) => _buildCommentItem(
                                    context,
                                    comment,
                                    videoId,
                                  ),
                                ).toList(),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    // Bottom spacing for comment input
                    SizedBox(height: ResponsiveHelper.spacing(context, 80)),
                  ],
                ),
              ),
            ),

            // Comment Input Bar
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 15,
                    spreadRadius: 2,
                    offset: const Offset(0, -4),
                  ),
                  BoxShadow(
                    color: const Color(0xFF8B4513).withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: ResponsiveHelper.padding(
                    context,
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      // User Avatar
                      if (userId > 0)
                        Container(
                          width: ResponsiveHelper.imageWidth(
                            context,
                            mobile: 36,
                            tablet: 40,
                            desktop: 44,
                          ),
                          height: ResponsiveHelper.imageWidth(
                            context,
                            mobile: 36,
                            tablet: 40,
                            desktop: 44,
                          ),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey[300],
                          ),
                          child: Icon(
                            Icons.person,
                            size: ResponsiveHelper.iconSize(context, mobile: 20),
                            color: Colors.grey[600],
                          ),
                        ),
                      if (userId > 0)
                        SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                      
                      // Comment Input
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.grey[100]!,
                                Colors.grey[50]!,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(
                              ResponsiveHelper.borderRadius(context, mobile: 28),
                            ),
                            border: Border.all(
                              color: userId > 0
                                  ? const Color(0xFF8B4513).withOpacity(0.2)
                                  : Colors.grey[300]!,
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: commentController,
                            decoration: InputDecoration(
                              hintText: userId > 0
                                  ? 'Write a comment...'
                                  : 'Login to comment',
                              hintStyle: ResponsiveHelper.textStyle(
                                context,
                                fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                                color: Colors.grey[600],
                              ),
                                prefixIcon: IconButton(
                                  icon: const Icon(
                                    Icons.emoji_emotions_outlined,
                                    color: Color(0xFF8B4513),
                                  ),
                                  onPressed: () => _showEmojiPicker(context, videoId, controller),
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: ResponsiveHelper.spacing(context, 16),
                                  vertical: ResponsiveHelper.spacing(context, 12),
                                ),
                            ),
                            enabled: userId > 0,
                            maxLines: null,
                            textInputAction: TextInputAction.send,
                            onSubmitted: userId > 0
                                ? (_) => _addComment(videoId)
                                : null,
                          ),
                        ),
                      ),
                      SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                      // Send Button
                      InkWell(
                        onTap: userId > 0
                            ? () => _addComment(videoId)
                            : null,
                        borderRadius: BorderRadius.circular(
                          ResponsiveHelper.borderRadius(context, mobile: 20),
                        ),
                        child: Container(
                          padding: ResponsiveHelper.padding(
                            context,
                            all: 12,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: userId > 0
                                  ? [
                                      const Color(0xD2D6D6D6),
                                      const Color(0xFFFFFFFF),
                                    ]
                                  : [
                                      Colors.grey[400]!,
                                      Colors.grey[500]!,
                                    ],
                            ),
                            borderRadius: BorderRadius.circular(
                              ResponsiveHelper.borderRadius(context, mobile: 20),
                            ),
                            boxShadow: userId > 0
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFFFFFFFF).withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Icon(
                            Icons.send_rounded,
                            size: ResponsiveHelper.iconSize(context, mobile: 20),
                            color: AppTheme.iconscolor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildCommentItem(BuildContext context, Map<String, dynamic> comment, int videoId) {
    final commentId = comment['id'] as int;
    final parentCommentId = comment['parent_comment_id'];
    final isTopLevel = parentCommentId == null || parentCommentId == 0 || (parentCommentId is String && (int.tryParse(parentCommentId) ?? 0) == 0);
    
    // Get replies for this comment
    final replies = comments.where((c) {
      final cParentId = c['parent_comment_id'];
      if (cParentId == null) return false;
      if (cParentId is int) return cParentId == commentId;
      if (cParentId is String) {
        final parsed = int.tryParse(cParentId);
        return parsed == commentId;
      }
      return false;
    }).toList();

    final baseUrl = 'https://fruitofthespirit.templateforwebsites.com/';
    final profilePhoto = comment['profile_photo'] as String?;
    final userName = comment['user_name'] as String? ?? 'Anonymous';
    final content = comment['content'] as String? ?? '';
    final likeCount = comment['like_count'] as int? ?? 0;
    final isLiked = _checkCommentLiked(comment);
    final replyCount = replies.length;
    final isExpanded = expandedReplies.contains(commentId);

    // Initialize reply controller if needed
    if (!replyControllers.containsKey(commentId)) {
      replyControllers[commentId] = TextEditingController();
      showReplyInput[commentId] = false;
    }

    return Container(
      margin: EdgeInsets.only(
        left: isTopLevel ? 0 : ResponsiveHelper.spacing(context, 40),
        top: ResponsiveHelper.spacing(context, 8),
        bottom: ResponsiveHelper.spacing(context, 8),
        right: ResponsiveHelper.spacing(context, 12),
      ),
      padding: ResponsiveHelper.padding(
        context,
        all: 12,
      ),
      decoration: BoxDecoration(
        color: isTopLevel ? Colors.white : Colors.grey[50],
        borderRadius: BorderRadius.circular(
          ResponsiveHelper.borderRadius(context, mobile: 16),
        ),
        border: isTopLevel
            ? null
            : Border.all(
                color: const Color(0xFF8B4513).withOpacity(0.1),
                width: 1,
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Comment Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Picture
              CircleAvatar(
                radius: ResponsiveHelper.isMobile(context) ? 18 : 20,
                backgroundColor: Colors.transparent,
                backgroundImage: profilePhoto != null &&
                        profilePhoto.isNotEmpty &&
                        !profilePhoto.startsWith('assets/')
                    ? NetworkImage(
                        profilePhoto.startsWith('http') ? profilePhoto : baseUrl + profilePhoto)
                    : null,
                child: profilePhoto == null ||
                        profilePhoto.isEmpty ||
                        profilePhoto.startsWith('assets/')
                    ? Icon(
                        Icons.person_rounded,
                        size: ResponsiveHelper.isMobile(context) ? 18 : 20,
                        color: AppTheme.iconscolor,
                      )
                    : null,
              ),
              SizedBox(width: ResponsiveHelper.spacing(context, 10)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // User Name
                    Text(
                      userName,
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(context, 4)),
                    // Comment Content
                    FruitEmojiHelper.buildCommentText(
                      context,
                      content,
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                        color: Colors.black87,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: ResponsiveHelper.spacing(context, 8)),

          // Comment Actions
          Row(
            children: [
              // Like Button
              InkWell(
                onTap: () => _toggleCommentLike(commentId),
                borderRadius: BorderRadius.circular(
                  ResponsiveHelper.borderRadius(context, mobile: 8),
                ),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveHelper.spacing(context, 8),
                    vertical: ResponsiveHelper.spacing(context, 4),
                  ),
                  decoration: BoxDecoration(
                    color: isLiked
                        ? Colors.blue[50]
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(
                      ResponsiveHelper.borderRadius(context, mobile: 8),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        size: ResponsiveHelper.iconSize(context, mobile: 16),
                        color: isLiked ? Colors.blue[600] : Colors.grey[600],
                      ),
                      if (likeCount > 0) ...[
                        SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                        Text(
                          '$likeCount',
                          style: ResponsiveHelper.textStyle(
                            context,
                            fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                            color: isLiked ? Colors.blue[600] : Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SizedBox(width: ResponsiveHelper.spacing(context, 8)),
              // Reply Button
              InkWell(
                onTap: () {
                  setState(() {
                    showReplyInput[commentId] = !(showReplyInput[commentId] ?? false);
                  });
                },
                borderRadius: BorderRadius.circular(
                  ResponsiveHelper.borderRadius(context, mobile: 8),
                ),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveHelper.spacing(context, 8),
                    vertical: ResponsiveHelper.spacing(context, 4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.reply_rounded,
                        size: ResponsiveHelper.iconSize(context, mobile: 16),
                        color: AppTheme.iconscolor,
                      ),
                      SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                      Text(
                        'Reply',
                        style: ResponsiveHelper.textStyle(
                          context,
                          fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                          color: AppTheme.iconscolor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // View Replies Button
              if (replyCount > 0) ...[
                SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                InkWell(
                  onTap: () {
                    setState(() {
                      if (isExpanded) {
                        expandedReplies.remove(commentId);
                      } else {
                        expandedReplies.add(commentId);
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(
                    ResponsiveHelper.borderRadius(context, mobile: 8),
                  ),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveHelper.spacing(context, 8),
                      vertical: ResponsiveHelper.spacing(context, 4),
                    ),
                    child: Text(
                      isExpanded
                          ? 'Hide replies ($replyCount)'
                          : 'View replies ($replyCount)',
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                        color: AppTheme.iconscolor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
              const Spacer(),
              // Report Button
              InkWell(
                onTap: () => _showReportDialog(context, comment),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.flag_outlined,
                    size: ResponsiveHelper.iconSize(context, mobile: 16),
                    color: Colors.grey[400],
                  ),
                ),
              ),
            ],
          ),

          // Reply Input
          if (showReplyInput[commentId] == true) ...[
            SizedBox(height: ResponsiveHelper.spacing(context, 12)),
            _buildReplyInput(context, commentId, videoId),
          ],

          // Replies List
          if (isExpanded && replies.isNotEmpty) ...[
            SizedBox(height: ResponsiveHelper.spacing(context, 8)),
            ...replies.map((reply) => _buildCommentItem(context, reply, videoId)).toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildReplyInput(BuildContext context, int parentCommentId, int videoId) {
    return Row(
      children: [
        SizedBox(width: ResponsiveHelper.spacing(context, 40)),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(
                ResponsiveHelper.borderRadius(context, mobile: 20),
              ),
              border: Border.all(
                color: const Color(0xFF8B4513).withOpacity(0.2),
                width: 1,
              ),
            ),
            child: TextField(
              controller: replyControllers[parentCommentId],
              decoration: InputDecoration(
                hintText: 'Write a reply...',
                hintStyle: ResponsiveHelper.textStyle(
                  context,
                  fontSize: ResponsiveHelper.fontSize(context, mobile: 13),
                  color: Colors.grey[600],
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: ResponsiveHelper.spacing(context, 12),
                  vertical: ResponsiveHelper.spacing(context, 8),
                ),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _addComment(videoId, parentCommentId: parentCommentId),
            ),
          ),
        ),
        SizedBox(width: ResponsiveHelper.spacing(context, 8)),
        InkWell(
          onTap: () => _addComment(videoId, parentCommentId: parentCommentId),
          borderRadius: BorderRadius.circular(
            ResponsiveHelper.borderRadius(context, mobile: 16),
          ),
          child: Container(
            padding: ResponsiveHelper.padding(context, all: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF8B4513),
                  const Color(0xFF5F4628),
                ],
              ),
              borderRadius: BorderRadius.circular(
                ResponsiveHelper.borderRadius(context, mobile: 16),
              ),
            ),
            child: Icon(
              Icons.send_rounded,
              size: ResponsiveHelper.iconSize(context, mobile: 18),
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  /// Build Emoji Reactions Widget
  Widget _buildEmojiReactions(BuildContext context, int videoId, VideosController controller) {
    return Obx(() {
      final reactions = controller.videoEmojiReactions;
      final hasReactions = reactions.isNotEmpty;
      final quickEmojisList = controller.quickEmojis;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick Emoji Buttons
          Row(
            children: [
              Text(
                'React:',
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                  fontWeight: FontWeight.bold,
                  color: AppTheme.iconscolor,
                ),
              ),
              SizedBox(width: ResponsiveHelper.spacing(context, 8)),
              if (quickEmojisList.isEmpty)
                Padding(
                  padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 8)),
                  child: SizedBox(
                    width: ResponsiveHelper.iconSize(context, mobile: 16),
                    height: ResponsiveHelper.iconSize(context, mobile: 16),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.iconscolor,
                    ),
                  ),
                )
              else
                ...quickEmojisList.where((emojiData) {
                  // Filter out emojis with empty values
                  final emojiChar = emojiData['emoji_char'] as String? ?? '';
                  final code = emojiData['code'] as String? ?? '';
                  return emojiChar.isNotEmpty || code.isNotEmpty;
                }).map((emojiData) {
                  // Use emoji_char or code for API, but display fruit image
                  // Try multiple fallbacks: emoji_char -> code -> name (base fruit name)
                  String? emoji = emojiData['emoji_char'] as String?;
                  if (emoji == null || emoji.trim().isEmpty) {
                    emoji = emojiData['code'] as String?;
                  }
                  if (emoji == null || emoji.trim().isEmpty) {
                    // Try to extract base fruit name from name field
                    final name = emojiData['name'] as String? ?? '';
                    if (name.isNotEmpty) {
                      // Extract base fruit name (e.g., "Goodness Banana (1)" -> "goodness")
                      String baseName = name.toLowerCase();
                      if (baseName.contains(':')) {
                        final parts = baseName.split(':');
                        if (parts.length > 1) {
                          baseName = parts[1].trim();
                        }
                      }
                      if (baseName.contains(' ')) {
                        baseName = baseName.split(' ')[0].trim();
                      }
                      emoji = baseName;
                    }
                  }
                  
                  // Skip if emoji is still empty
                  final isValidEmoji = emoji != null && emoji.trim().isNotEmpty;
                  if (!isValidEmoji) {
                    return SizedBox.shrink();
                  }
                  
                  return Padding(
                    padding: EdgeInsets.only(right: ResponsiveHelper.spacing(context, 6)),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          final success = await controller.addEmojiReaction(videoId, emoji!);
                          if (success) {
                            Get.snackbar(
                              'Success',
                              'Reaction added',
                              backgroundColor: Colors.green,
                              colorText: Colors.white,
                              duration: const Duration(seconds: 1),
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
                        borderRadius: BorderRadius.circular(40),
                        child: Padding(
                          padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 4)),
                          child: SizedBox(
                            width: ResponsiveHelper.iconSize(context, mobile: 40),
                            height: ResponsiveHelper.iconSize(context, mobile: 40),
                            child: HomeScreen.buildEmojiDisplay(
                              context,
                              emojiData,
                              size: ResponsiveHelper.iconSize(context, mobile: 40),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              // More Emojis Button - Phone Style
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showEmojiPicker(context, videoId, controller),
                  borderRadius: BorderRadius.circular(40),
                  child: Padding(
                    padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 4)),
                    child: Container(
                      width: ResponsiveHelper.iconSize(context, mobile: 40),
                      height: ResponsiveHelper.iconSize(context, mobile: 40),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.add_reaction,
                        size: ResponsiveHelper.iconSize(context, mobile: 20),
                        color: AppTheme.iconscolor,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Display Reactions Count
          if (hasReactions) ...[
            SizedBox(height: ResponsiveHelper.spacing(context, 12)),
            Wrap(
              spacing: ResponsiveHelper.spacing(context, 8),
              runSpacing: ResponsiveHelper.spacing(context, 8),
              children: reactions.entries.map((entry) {
                // Find fruit image for this emoji (can be character, code, image_url, or ID)
                final emojiKey = entry.key;
                final usersWhoReacted = entry.value as List<Map<String, dynamic>>;
                Map<String, dynamic>? fruitEmoji;
                
                // Try multiple matching strategies
                for (var emoji in controller.availableEmojis) {
                  final emojiCharFromList = emoji['emoji_char'] as String? ?? '';
                  final emojiCodeFromList = emoji['code'] as String? ?? '';
                  final emojiImageUrlFromList = emoji['image_url'] as String? ?? '';
                  final emojiIdFromList = emoji['id']?.toString() ?? '';
                  
                  // Strategy 1: Match by emoji_char
                  if (emojiCharFromList.isNotEmpty && 
                      (emojiCharFromList.trim() == emojiKey.trim() || emojiCharFromList == emojiKey)) {
                    fruitEmoji = emoji;
                    break;
                  }
                  // Strategy 2: Match by code
                  if (emojiCodeFromList.isNotEmpty && 
                      (emojiCodeFromList.trim() == emojiKey.trim() || emojiCodeFromList == emojiKey)) {
                    fruitEmoji = emoji;
                    break;
                  }
                  // Strategy 3: Match by image_url (check if emojiKey is in the URL or vice versa)
                  if (emojiImageUrlFromList.isNotEmpty) {
                    // Extract filename from both URLs
                    String? keyFilename;
                    String? listFilename;
                    
                    if (emojiKey.contains('/')) {
                      keyFilename = emojiKey.split('/').last.replaceAll('%20', ' ').toLowerCase();
                    } else {
                      keyFilename = emojiKey.toLowerCase();
                    }
                    
                    if (emojiImageUrlFromList.contains('/')) {
                      listFilename = emojiImageUrlFromList.split('/').last.replaceAll('%20', ' ').toLowerCase();
                    } else {
                      listFilename = emojiImageUrlFromList.toLowerCase();
                    }
                    
                    if (keyFilename == listFilename || 
                        emojiImageUrlFromList.contains(emojiKey) || 
                        emojiKey.contains(emojiImageUrlFromList)) {
                      fruitEmoji = emoji;
                      break;
                    }
                  }
                  // Strategy 4: Match by ID
                  if (emojiIdFromList.isNotEmpty && emojiIdFromList == emojiKey) {
                    fruitEmoji = emoji;
                    break;
                  }
                }
                
                return GestureDetector(
                  onTap: () {
                    // Show dialog with users who reacted
                    _showReactionUsersDialog(context, emojiKey, usersWhoReacted, fruitEmoji);
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Show fruit image - Phone Style (no border)
                      if (fruitEmoji != null)
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: HomeScreen.buildEmojiDisplay(
                            context,
                            fruitEmoji,
                            size: 24,
                          ),
                        )
                      else
                        // Fallback: show placeholder
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.sentiment_satisfied,
                            size: 16,
                            color: Colors.grey[400],
                          ),
                        ),
                      SizedBox(width: ResponsiveHelper.spacing(context, 6)),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${usersWhoReacted.length}',
                            style: ResponsiveHelper.textStyle(
                              context,
                              fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                              fontWeight: FontWeight.bold,
                              color: AppTheme.iconscolor,
                            ),
                          ),
                          if (usersWhoReacted.isNotEmpty) ...[
                            SizedBox(height: ResponsiveHelper.spacing(context, 1)),
                            Text(
                              usersWhoReacted.length == 1
                                  ? usersWhoReacted[0]['user_name'] ?? 'Someone'
                                  : '${usersWhoReacted[0]['user_name'] ?? 'Someone'} and ${usersWhoReacted.length - 1} more',
                              style: ResponsiveHelper.textStyle(
                                context,
                                fontSize: ResponsiveHelper.fontSize(context, mobile: 10),
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            
            // "Who Reacted" Section - Show all users who reacted
            if (hasReactions) ...[
              SizedBox(height: ResponsiveHelper.spacing(context, 20)),
              Container(
                padding: ResponsiveHelper.padding(context, all: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(ResponsiveHelper.isMobile(context) ? 12 : 14),
                  border: Border.all(
                    color: Colors.grey.withOpacity(0.15),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.people_rounded,
                          size: ResponsiveHelper.fontSize(context, mobile: 16),
                          color: AppTheme.iconscolor,
                        ),
                        SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                        Text(
                          'Who Reacted',
                          style: TextStyle(
                            fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2C2C2C),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(context, 12)),
                    // Show all users who reacted (max 5, then show "and X more")
                    Builder(
                      builder: (context) {
                        // Collect all users with their emoji reactions
                        final allUsersWithReactions = <Map<String, dynamic>>[];
                        reactions.entries.forEach((entry) {
                          final emojiKey = entry.key;
                          final usersWhoReacted = entry.value as List<Map<String, dynamic>>;
                          for (var user in usersWhoReacted) {
                            allUsersWithReactions.add({
                              ...user,
                              'reaction_emoji': emojiKey,
                            });
                          }
                        });
                        
                        // Sort by created_at (most recent first)
                        allUsersWithReactions.sort((a, b) {
                          final aTime = a['created_at'] as String? ?? '';
                          final bTime = b['created_at'] as String? ?? '';
                          return bTime.compareTo(aTime);
                        });
                        
                        // Take first 5
                        final usersToShow = allUsersWithReactions.take(5).toList();
                        
                        return Column(
                          children: usersToShow.map((userData) {
                            final userName = userData['user_name'] as String? ?? 'Anonymous';
                            final profilePhoto = userData['profile_photo'] as String?;
                            final emojiKey = userData['reaction_emoji'] as String? ?? '';
                            String? profilePhotoUrl;
                            
                            if (profilePhoto != null && profilePhoto.toString().isNotEmpty) {
                              final photoPath = profilePhoto.toString();
                              // Check if already a full URL (http/https)
                              if (photoPath.startsWith('http://') || photoPath.startsWith('https://')) {
                                profilePhotoUrl = photoPath; // Use as-is if already a full URL
                              } else if (!photoPath.startsWith('assets/') && 
                                  !photoPath.startsWith('file://') &&
                                  !photoPath.startsWith('assets/images/')) {
                                profilePhotoUrl = 'https://fruitofthespirit.templateforwebsites.com/$photoPath';
                              }
                            }
                            
                            // Find fruit emoji for this reaction (can be character, code, image_url, or ID)
                            Map<String, dynamic>? fruitEmoji;
                            for (var emoji in controller.availableEmojis) {
                              final emojiCharFromList = emoji['emoji_char'] as String? ?? '';
                              final emojiCodeFromList = emoji['code'] as String? ?? '';
                              final emojiImageUrlFromList = emoji['image_url'] as String? ?? '';
                              final emojiIdFromList = emoji['id']?.toString() ?? '';
                              
                              // Strategy 1: Match by emoji_char
                              if (emojiCharFromList.isNotEmpty && 
                                  (emojiCharFromList.trim() == emojiKey.trim() || emojiCharFromList == emojiKey)) {
                                fruitEmoji = emoji;
                                break;
                              }
                              // Strategy 2: Match by code
                              if (emojiCodeFromList.isNotEmpty && 
                                  (emojiCodeFromList.trim() == emojiKey.trim() || emojiCodeFromList == emojiKey)) {
                                fruitEmoji = emoji;
                                break;
                              }
                              // Strategy 3: Match by image_url
                              if (emojiImageUrlFromList.isNotEmpty) {
                                String? keyFilename;
                                String? listFilename;
                                
                                if (emojiKey.contains('/')) {
                                  keyFilename = emojiKey.split('/').last.replaceAll('%20', ' ').toLowerCase();
                                } else {
                                  keyFilename = emojiKey.toLowerCase();
                                }
                                
                                if (emojiImageUrlFromList.contains('/')) {
                                  listFilename = emojiImageUrlFromList.split('/').last.replaceAll('%20', ' ').toLowerCase();
                                } else {
                                  listFilename = emojiImageUrlFromList.toLowerCase();
                                }
                                
                                if (keyFilename == listFilename || 
                                    emojiImageUrlFromList.contains(emojiKey) || 
                                    emojiKey.contains(emojiImageUrlFromList)) {
                                  fruitEmoji = emoji;
                                  break;
                                }
                              }
                              // Strategy 4: Match by ID
                              if (emojiIdFromList.isNotEmpty && emojiIdFromList == emojiKey) {
                                fruitEmoji = emoji;
                                break;
                              }
                            }
                            
                            return Padding(
                              padding: EdgeInsets.only(bottom: ResponsiveHelper.spacing(context, 8)),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: ResponsiveHelper.isMobile(context) ? 16 : 18,
                                    backgroundImage: profilePhotoUrl != null ? NetworkImage(profilePhotoUrl) : null,
                                    backgroundColor: Colors.grey[300],
                                    child: profilePhotoUrl == null
                                        ? Text(
                                            userName.isNotEmpty ? userName[0].toUpperCase() : 'A',
                                            style: TextStyle(
                                              fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                                              color: Colors.grey[700],
                                              fontWeight: FontWeight.bold,
                                            ),
                                          )
                                        : null,
                                  ),
                                  SizedBox(width: ResponsiveHelper.spacing(context, 10)),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          userName,
                                          style: TextStyle(
                                            fontSize: ResponsiveHelper.fontSize(context, mobile: 13),
                                            fontWeight: FontWeight.w500,
                                            color: const Color(0xFF2C2C2C),
                                          ),
                                        ),
                                        Text(
                                          _getTimeAgo(userData['created_at'] as String?),
                                          style: TextStyle(
                                            fontSize: ResponsiveHelper.fontSize(context, mobile: 11),
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Show which emoji they reacted with
                                  if (fruitEmoji != null)
                                    SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: HomeScreen.buildEmojiDisplay(
                                        context,
                                        fruitEmoji,
                                        size: 24,
                                      ),
                                    )
                                  else
                                    SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: Icon(
                                        Icons.sentiment_satisfied,
                                        size: 18,
                                        color: Colors.grey[400],
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                    // Show "and X more" if there are more than 5 users
                    Builder(
                      builder: (context) {
                        final totalUsers = reactions.values.fold<int>(0, (sum, users) => sum + (users as List).length);
                        if (totalUsers > 5) {
                          return GestureDetector(
                            onTap: () {
                              // Show all users in dialog - collect all users from all reactions
                              final allUsers = <Map<String, dynamic>>[];
                              reactions.entries.forEach((entry) {
                                allUsers.addAll((entry.value as List<Map<String, dynamic>>));
                              });
                              // Show dialog with first emoji or null
                              final firstEmojiKey = reactions.keys.isNotEmpty ? reactions.keys.first : '';
                              Map<String, dynamic>? firstFruitEmoji;
                              if (firstEmojiKey.isNotEmpty) {
                                for (var emoji in controller.availableEmojis) {
                                  final emojiCharFromList = emoji['emoji_char'] as String? ?? '';
                                  final emojiIdFromList = emoji['id']?.toString() ?? '';
                                  if ((emojiCharFromList.isNotEmpty && emojiCharFromList.trim() == firstEmojiKey.trim()) ||
                                      (emojiIdFromList.isNotEmpty && emojiIdFromList == firstEmojiKey)) {
                                    firstFruitEmoji = emoji;
                                    break;
                                  }
                                }
                              }
                              _showReactionUsersDialog(context, firstEmojiKey, allUsers, firstFruitEmoji);
                            },
                            child: Padding(
                              padding: EdgeInsets.only(top: ResponsiveHelper.spacing(context, 4)),
                              child: Row(
                                children: [
                                  Text(
                                    'and ${totalUsers - 5} more',
                                    style: TextStyle(
                                      fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                                      color: AppTheme.iconscolor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    size: ResponsiveHelper.fontSize(context, mobile: 12),
                                    color: AppTheme.iconscolor,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      );
    });
  }

  void _showReactionUsersDialog(BuildContext context, String emojiChar, List<Map<String, dynamic>> users, Map<String, dynamic>? fruitEmoji) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ResponsiveHelper.isMobile(context) ? 20 : 24),
        ),
        child: Container(
          padding: ResponsiveHelper.padding(context, all: 20),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
            maxWidth: ResponsiveHelper.isMobile(context) ? double.infinity : 500,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  if (fruitEmoji != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: HomeScreen.buildEmojiDisplay(
                          context,
                          fruitEmoji,
                          size: 40,
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.sentiment_satisfied, color: Colors.grey[400]),
                    ),
                  SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${users.length} ${users.length == 1 ? 'Person' : 'People'} Reacted',
                          style: ResponsiveHelper.textStyle(
                            context,
                            fontSize: ResponsiveHelper.fontSize(context, mobile: 18),
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2C2C2C),
                          ),
                        ),
                        SizedBox(height: ResponsiveHelper.spacing(context, 2)),
                        Text(
                          'Tap to see who reacted with this emoji',
                          style: ResponsiveHelper.textStyle(
                            context,
                            fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.grey[600]),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              SizedBox(height: ResponsiveHelper.spacing(context, 16)),
              // Users List
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final userName = user['user_name'] as String? ?? 'Anonymous';
                    final profilePhoto = user['profile_photo'] as String?;
                    String? profilePhotoUrl;
                    
                    if (profilePhoto != null && profilePhoto.toString().isNotEmpty) {
                      final photoPath = profilePhoto.toString();
                      if (!photoPath.startsWith('assets/') && 
                          !photoPath.startsWith('file://') &&
                          !photoPath.startsWith('assets/images/')) {
                        profilePhotoUrl = 'https://fruitofthespirit.templateforwebsites.com/$photoPath';
                      }
                    }
                    
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundImage: profilePhotoUrl != null ? NetworkImage(profilePhotoUrl) : null,
                        backgroundColor: Colors.grey[300],
                        child: profilePhotoUrl == null
                            ? Text(
                                userName.isNotEmpty ? userName[0].toUpperCase() : 'A',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      title: Text(
                        userName,
                        style: ResponsiveHelper.textStyle(
                          context,
                          fontSize: ResponsiveHelper.fontSize(context, mobile: 15),
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF2C2C2C),
                        ),
                      ),
                      subtitle: Text(
                        _getTimeAgo(user['created_at'] as String?),
                        style: ResponsiveHelper.textStyle(
                          context,
                          fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                          color: Colors.grey[600],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getTimeAgo(String? dateTime) {
    if (dateTime == null || dateTime.isEmpty) return '';
    try {
      final date = DateTime.parse(dateTime);
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays > 365) {
        return '${(difference.inDays / 365).floor()} year${(difference.inDays / 365).floor() > 1 ? 's' : ''} ago';
      } else if (difference.inDays > 30) {
        return '${(difference.inDays / 30).floor()} month${(difference.inDays / 30).floor() > 1 ? 's' : ''} ago';
      } else if (difference.inDays > 0) {
        return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return '';
    }
  }

  /// Show Emoji Picker Dialog
  void _showEmojiPicker(BuildContext context, int videoId, VideosController controller) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(ResponsiveHelper.borderRadius(context, mobile: 20)),
          ),
        ),
        padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose an Emoji',
              style: ResponsiveHelper.textStyle(
                context,
                fontSize: ResponsiveHelper.fontSize(context, mobile: 18),
                fontWeight: FontWeight.bold,
                color: AppTheme.iconscolor,
              ),
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 16)),
            Obx(() {
              if (controller.availableEmojis.isEmpty) {
                return Padding(
                  padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 20)),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.iconscolor,
                    ),
                  ),
                );
              }

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  crossAxisSpacing: ResponsiveHelper.spacing(context, 8),
                  mainAxisSpacing: ResponsiveHelper.spacing(context, 8),
                ),
                itemCount: controller.availableEmojis.length,
                itemBuilder: (context, index) {
                  final emoji = controller.availableEmojis[index];
                  // Try multiple fallbacks: emoji_char -> code -> name (base fruit name)
                  String? emojiChar = emoji['emoji_char'] as String?;
                  if (emojiChar == null || emojiChar.trim().isEmpty) {
                    emojiChar = emoji['code'] as String?;
                  }
                  if (emojiChar == null || emojiChar.trim().isEmpty) {
                    // Try to extract base fruit name from name field
                    final name = emoji['name'] as String? ?? '';
                    if (name.isNotEmpty) {
                      // Extract base fruit name (e.g., "Goodness Banana (1)" -> "goodness")
                      String baseName = name.toLowerCase();
                      if (baseName.contains(':')) {
                        final parts = baseName.split(':');
                        if (parts.length > 1) {
                          baseName = parts[1].trim();
                        }
                      }
                      if (baseName.contains(' ')) {
                        baseName = baseName.split(' ')[0].trim();
                      }
                      emojiChar = baseName;
                    }
                  }
                  
                  // If still empty, skip this emoji (don't make it clickable)
                  final isValidEmoji = emojiChar != null && emojiChar.trim().isNotEmpty;

                  return InkWell(
                    onTap: isValidEmoji ? () async {
                      Get.back();
                      final success = await controller.addEmojiReaction(videoId, emojiChar!);
                      if (success) {
                        Get.snackbar(
                          'Success',
                          'Reaction added',
                          backgroundColor: Colors.green,
                          colorText: Colors.white,
                          duration: const Duration(seconds: 1),
                        );
                      } else {
                        Get.snackbar(
                          'Error',
                          controller.message.value,
                          backgroundColor: Colors.red,
                          colorText: Colors.white,
                        );
                      }
                    } : null,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5DC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: SizedBox(
                          width: 32,
                          height: 32,
                          child: HomeScreen.buildEmojiDisplay(
                            context,
                            emoji,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
            SizedBox(height: ResponsiveHelper.spacing(context, 16)),
          ],
        ),
      ),
    );
  }

  void _showReportDialog(BuildContext context, Map<String, dynamic> comment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Content'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choose an action:'),
            const SizedBox(height: 16),
            if (comment['user_id'] != null && comment['user_id'].toString() != this.userId.toString()) ...[
              ListTile(
                leading: const Icon(Icons.report_outlined, color: Colors.orange),
                title: const Text('Report Comment'),
                onTap: () {
                  Navigator.pop(context);
                  Get.to(() => ReportContentScreen(
                        contentType: 'video_comment',
                        contentId: comment['id'] is int ? comment['id'] : int.parse(comment['id'].toString()),
                      ));
                },
              ),
              ListTile(
                leading: const Icon(Icons.block, color: Colors.red),
                title: const Text('Block User'),
                onTap: () async {
                  Navigator.pop(context);
                  final userIdRaw = comment['user_id'];
                  if (userIdRaw != null) {
                    final userId = userIdRaw is int ? userIdRaw : int.tryParse(userIdRaw.toString());
                    if (userId == null) return;
                    
                    final String userName = comment['user_name'] ?? 'this user';

                    final confirmed = await Get.dialog<bool>(
                      AlertDialog(
                        title: Text('Block $userName?'),
                        content: const Text('You will no longer see content from this user.'),
                        actions: [
                          TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancel')),
                          TextButton(
                              onPressed: () => Get.back(result: true),
                              child: const Text('Block', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );

                    if (confirmed == true) {
                      try {
                        await UserBlockingService.blockUser(userId);
                        Get.snackbar('Success', 'User blocked');
                        _loadComments(controller.selectedVideo['id']);
                      } catch (e) {
                        Get.snackbar('Error', 'Failed to block user');
                      }
                    }
                  }
                },
              ),
            ] else 
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('This is your own comment.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ],
      ),
    );
  }

  Widget _buildVideoOptions(BuildContext context, Map<String, dynamic> video) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: Colors.grey[400]),
      onSelected: (value) async {
        if (value == 'report') {
          Get.to(() => ReportContentScreen(
                contentType: 'video',
                contentId: video['id'] is int ? video['id'] : int.parse(video['id'].toString()),
              ));
        } else if (value == 'block') {
          final userIdRaw = video['user_id'] ?? video['created_by'];
          if (userIdRaw != null) {
            final userId = userIdRaw is int ? userIdRaw : int.tryParse(userIdRaw.toString());
            if (userId == null) return;

            if (this.userId == userId) {
              Get.snackbar('Info', 'You cannot block yourself');
              return;
            }

            final userName = video['user_name'] ?? 'this poster';
            final confirmed = await Get.dialog<bool>(
              AlertDialog(
                title: Text('Block $userName?'),
                content: const Text('You will no longer see content from this user.'),
                actions: [
                  TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancel')),
                  TextButton(
                      onPressed: () => Get.back(result: true),
                      child: const Text('Block', style: TextStyle(color: Colors.red))),
                ],
              ),
            );

            if (confirmed == true) {
              try {
                await UserBlockingService.blockUser(userId);
                Get.snackbar('Success', 'User blocked');
                Get.back(); // Back to list
              } catch (e) {
                Get.snackbar('Error', 'Failed to block user');
              }
            }
          }
        }
      },
      itemBuilder: (context) {
        final List<PopupMenuEntry<String>> items = [];
        
        final userIdRaw = video['user_id'] ?? video['created_by'];
        final posterId = userIdRaw is int ? userIdRaw : int.tryParse(userIdRaw?.toString() ?? '');
        
        // Only show options if it's NOT the current user's video
        if (posterId != null && posterId != this.userId) {
          items.add(
            const PopupMenuItem(
              value: 'report',
              child: Row(
                children: [
                  Icon(Icons.report_outlined, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Text('Report Content'),
                ],
              ),
            ),
          );
          items.add(
            const PopupMenuItem(
              value: 'block',
              child: Row(
                children: [
                  Icon(Icons.block, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Text('Block User'),
                ],
              ),
            ),
          );
        }
        
        return items;
      },
    );
  }
}
