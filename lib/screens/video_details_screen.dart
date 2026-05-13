import 'package:flutter/material.dart';
import 'package:fruitsofspirit/utils/share_helper.dart';
import 'package:fruitsofspirit/utils/time_helper.dart';

import 'package:flutter/services.dart';
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
import 'package:fruitsofspirit/utils/report_utils.dart';
import 'package:fruitsofspirit/screens/report_content_screen.dart';
import 'package:fruitsofspirit/widgets/emoji_sticker_picker.dart';
import 'package:fruitsofspirit/widgets/emoji_button.dart';
import 'dart:async';
// edit feature: Import comments service for edit functionality
import 'package:fruitsofspirit/services/comments_service.dart';

/// Video Details Screen - Modern Social Media Style
class VideoDetailsScreen extends StatefulWidget {
  const VideoDetailsScreen({Key? key}) : super(key: key);

  @override
  State<VideoDetailsScreen> createState() => _VideoDetailsScreenState();
}

// Message model for proper text/sticker separation (reusable from blog_details_screen)
class CommentMessage {
  final String? text;
  final String? stickerId;
  final bool isSticker;

  CommentMessage({this.text, this.stickerId, required this.isSticker});
}

class _VideoDetailsScreenState extends State<VideoDetailsScreen> with SingleTickerProviderStateMixin {
  final VideosController controller = Get.find<VideosController>();
  final commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final replyControllers = <int, TextEditingController>{};
  final replyFocusNodes = <int, FocusNode>{};
  final showReplyInput = <int, bool>{};
  final expandedReplies = <int>{}; // Track which replies are expanded
  var userId = 0;
  var isLoading = false;
  var _isSendingComment = false;
  final Set<int> _sendingReplies = {};
  var comments = <Map<String, dynamic>>[];
  String? userEmail;
  // edit feature: Comment edit state
  final editControllers = <int, TextEditingController>{}; // edit feature
  final showEditInput = <int, bool>{}; // edit feature
  var isEditingComment = false.obs; // edit feature
  
  /// Show a custom snackbar using ScaffoldMessenger
  void _showCustomSnackbar(BuildContext context, String title, String message, {bool isError = false}) {
    if (!mounted) return;
    
    // Close any existing snackbars
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    
    final lower = message.toLowerCase();
    final isModeration = lower.contains('community guidelines') ||
        lower.contains('inappropriate content') ||
        lower.contains('terms') ||
        lower.contains('moderation');
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isModeration)
                  const Icon(Icons.security_rounded, color: Color(0xFFC79211), size: 20),
                if (isModeration)
                  const SizedBox(width: 8),
                Text(
                  isModeration ? 'Community Guidelines' : title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              message,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        backgroundColor: isModeration ? const Color(0xFF5D4037) : (isError ? Colors.red : AppTheme.iconscolor),
        duration: isModeration ? const Duration(seconds: 5) : const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  static const String baseUrl = 'http://admin.fosmessenger.com/';

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
    _loadUserEmail();
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
    if (!mounted) return;
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
      
      if (!mounted) return;
      setState(() {
        _isVideoInitialized = true;
        _hasVideoError = false;
        _videoAspectRatio = _videoController!.value.aspectRatio;
      });
      
      print('✅ Video initialized successfully with AspectRatio: $_videoAspectRatio');
    } catch (e) {
      print('❌ Error initializing video: $e');
      
      // If it's a MediaCodec/ExoPlayer error, it might be a hardware capability issue
      String userFriendlyError = e.toString();
      if (userFriendlyError.contains('MediaCodecVideoRenderer') || 
          userFriendlyError.contains('ExoPlaybackException')) {
        userFriendlyError = 'The video format is not supported by your device hardware. This can happen with 60fps videos on some devices.';
      } else if (userFriendlyError.contains('VideoError')) {
        userFriendlyError = 'Video player encountered an error. Please check your internet connection and try again.';
      }

      if (!mounted) return;
      setState(() {
        _hasVideoError = true;
        _videoError = userFriendlyError;
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
      // Hide status bar and navigation bar
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

      // Handle orientation based on video aspect ratio
      if (_videoController != null && _videoController!.value.isInitialized) {
        if (_videoController!.value.aspectRatio > 1.0) {
          // Landscape video - force landscape
          try {
            SystemChrome.setPreferredOrientations([
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]);
          } catch (e) {
            // Ignore orientation change errors (common on iOS with certain windowing modes)
            print('Orientation change error: $e');
          }
        } else {
          // Portrait video - allow all but keep current
          try {
            SystemChrome.setPreferredOrientations([
              DeviceOrientation.portraitUp,
              DeviceOrientation.portraitDown,
            ]);
          } catch (e) {
            // Ignore orientation change errors (common on iOS with certain windowing modes)
            print('Orientation change error: $e');
          }
        }
      }
    } else {
      // Exit full screen
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      // Reset to all orientations
      try {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      } catch (e) {
        // Ignore orientation change errors (common on iOS with certain windowing modes)
        print('Orientation change error: $e');
      }
    }
  }

  @override
  void dispose() {
    // Reset orientations when leaving the screen
    try {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } catch (e) {
      // Ignore orientation change errors (common on iOS with certain windowing modes)
      print('Orientation change error: $e');
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    _controlsTimer?.cancel();
    _videoController?.removeListener(_videoPlayerListener);
    _videoController?.dispose();
    _fadeAnimationController.dispose();
    commentController.dispose();
    _scrollController.dispose();
    for (var controller in replyControllers.values) {
      controller.dispose();
    }
    for (var focusNode in replyFocusNodes.values) {
      focusNode.dispose();
    }
    // edit feature: Dispose comment edit controllers
    for (var controller in editControllers.values) { // edit feature
      controller.dispose(); // edit feature
    } // edit feature
    super.dispose();
  }

  Future<void> _loadUserId() async {
    final id = await UserStorage.getUserId();
    if (!mounted) return;
    if (id != null) {
      setState(() {
        userId = id;
      });
    }
  }

  Future<void> _loadUserEmail() async {
    userEmail = await UserStorage.getUserEmail();
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
    final video = controller.selectedVideo;
    final thumbnailPath = video['thumbnail_path'] as String?;
    final thumbnailUrl = thumbnailPath != null && thumbnailPath.isNotEmpty
        ? (thumbnailPath.startsWith('http') ? thumbnailPath : baseUrl + (thumbnailPath.startsWith('/') ? thumbnailPath.substring(1) : thumbnailPath))
        : null;

    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (thumbnailUrl != null)
            CachedImage(
              imageUrl: thumbnailUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorWidget: const SizedBox.shrink(),
            ),
          Container(
            color: Colors.black.withOpacity(thumbnailUrl != null ? 0.4 : 1.0),
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
          ),
        ],
      ),
    );
  }
  
  Widget _buildVideoErrorState(String videoUrl) {
    final video = controller.selectedVideo;
    final thumbnailPath = video['thumbnail_path'] as String?;
    final baseUrl = 'http://admin.fosmessenger.com/';
    final thumbnailUrl = thumbnailPath != null && thumbnailPath.isNotEmpty
        ? (thumbnailPath.startsWith('http') ? thumbnailPath : baseUrl + (thumbnailPath.startsWith('/') ? thumbnailPath.substring(1) : thumbnailPath))
        : null;

    return Container(
      color: Colors.black87,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (thumbnailUrl != null)
            CachedImage(
              imageUrl: thumbnailUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorWidget: const SizedBox.shrink(),
            ),
          Container(
            color: Colors.black.withOpacity(thumbnailUrl != null ? 0.6 : 0.87),
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
                          _videoError ?? 'The video file may not exist or the URL is invalid. Please try again later.',
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
          ),
        ],
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
              child: VideoPlayer(
                _videoController!,
                key: ValueKey(_videoController!.dataSource),
              ),
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
    if (!mounted) return;
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
      
      if (!mounted) return;
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
    
    // Check if already sending this comment/reply
    if (parentCommentId != null) {
      if (_sendingReplies.contains(parentCommentId)) return;
    } else {
      if (_isSendingComment) return;
    }

    // FIX: Dismiss keyboard immediately
    FocusScope.of(context).unfocus();
    
    setState(() {
      if (parentCommentId != null) {
        _sendingReplies.add(parentCommentId);
      } else {
        _isSendingComment = true;
      }
    });
    
    if (userId == 0) {
      _showCustomSnackbar(
        context,
        'Error',
        'Please login first',
        isError: true,
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
        _showCustomSnackbar(
          context,
          'Success',
          parentCommentId != null ? 'Reply added successfully' : 'Comment added successfully',
        );
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
      } else {
        // Scroll to bottom to show latest comment
        await Future.delayed(const Duration(milliseconds: 300));
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
          );
        }
      }

      _showCustomSnackbar(
        context,
        'Success',
        'Comment added successfully',
      );
    } catch (e) {
      _showCustomSnackbar(
        context,
        'Error',
        e.toString().replaceAll('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          if (parentCommentId != null) {
            _sendingReplies.remove(parentCommentId);
          } else {
            _isSendingComment = false;
          }
        });
      }
    }
  }

  Future<void> _toggleCommentLike(int commentId) async {
    if (userId == 0) {
      _showCustomSnackbar(
        context,
        'Error',
        'Please login first',
        isError: true,
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
      _showCustomSnackbar(
        context,
        'Error',
        e.toString().replaceAll('Exception: ', ''),
        isError: true,
      );
    }
  }

  bool _checkCommentLiked(Map<String, dynamic> comment) {
    return comment['is_liked'] == true || comment['is_liked'] == 1;
  }


  // edit feature: Configurable edit time window in minutes
  static const int _editTimeWindowMinutes = 15; // edit feature

  // edit feature: Check if comment can be edited (within 15 minutes only)
  bool _canEditComment(Map<String, dynamic> comment) { // edit feature
    print('🔍 Edit check - created_at: ${comment['created_at']}'); // debug
    if (comment['created_at'] == null) { // edit feature
      print('❌ Edit blocked: created_at is null'); // debug
      return false; // edit feature
    } // edit feature
    try { // edit feature
      // CRITICAL FIX: Use same logic as TimeHelper.getTimeAgo for consistency
      String formattedDate = comment['created_at'].toString();
      if (!formattedDate.contains('Z') && !formattedDate.contains('+')) {
        formattedDate = formattedDate.replaceAll(' ', 'T') + 'Z';
      }

      // Use SAME logic as backend for consistency
      DateTime serverTimeUtc = DateTime.parse(formattedDate).toUtc();
      serverTimeUtc = serverTimeUtc.add(const Duration(hours: 4)); // 4-hour fix (same as backend)
      
      // Get current UTC time (same as backend)
      DateTime nowUtc = DateTime.now().toUtc();
      
      // Calculate difference in UTC (same as backend)
      final difference = nowUtc.difference(serverTimeUtc);
      final canEdit = difference.inMinutes < _editTimeWindowMinutes; // edit feature: Check 15-minute window
      
      print('  - Backend UTC time (with 4hr fix): $serverTimeUtc'); // debug
      print('  - Current UTC time: $nowUtc'); // debug
      print('  - UTC difference: ${difference.inMinutes} minutes'); // debug
      print('  - Backend logic applied: UTC difference calculation'); // debug
      print('🕐 Video Time check (UTC): ${difference.inMinutes} minutes, canEdit: $canEdit'); // debug
      print('🌍 Video Device timezone: ${DateTime.now().timeZoneName} (${DateTime.now().timeZoneOffset})'); // debug
      
      // CRITICAL DEBUG: Show exact frontend calculation to compare with backend
      print('🔍 VIDEO FRONTEND TIME CALCULATION DEBUG:'); // debug
      print('   - Raw created_at: ${comment['created_at']}'); // debug
      print('   - Formatted date: $formattedDate'); // debug
      print('   - Server time UTC (fixed): $serverTimeUtc'); // debug
      print('   - Current UTC: $nowUtc'); // debug
      print('   - Frontend minutes diff: ${difference.inMinutes}'); // debug
      print('   - Frontend canEdit: $canEdit'); // debug
      print('🔍 VIDEO FRONTEND DEBUG COMPLETE'); // debug
      
      // CRITICAL: If difference is more than 60 minutes, it means backend time is wrong
      if (difference.inMinutes > 60) {
        print('⚠️ WARNING: Time difference too large (${difference.inMinutes} minutes), backend timestamp may be incorrect'); // debug
      }
      return canEdit; // edit feature
    } catch (e) { // edit feature
      print('❌ Edit blocked: date parsing error - $e'); // debug
      return false; // edit feature
    } // edit feature
  } // edit feature

  // edit feature: Build edit button widget
  Widget _buildEditButton(BuildContext context, Map<String, dynamic> comment, int videoId) { // edit feature
    if (!_canEditComment(comment)) return const SizedBox.shrink(); // edit feature
    final commentId = comment['id'] as int; // edit feature

    return InkWell( // edit feature
      onTap: () { // edit feature
        setState(() { // edit feature
          if (!editControllers.containsKey(commentId)) { // edit feature
            editControllers[commentId] = TextEditingController( // edit feature
              text: (comment['comment'] as String? ?? comment['content'] as String? ?? '').trim(), // edit feature
            ); // edit feature
          } // edit feature
          showEditInput[commentId] = !(showEditInput[commentId] ?? false); // edit feature
        }); // edit feature
      }, // edit feature
      child: Row( // edit feature
        children: [ // edit feature
          Icon( // edit feature
            Icons.edit, // edit feature
            size: ResponsiveHelper.iconSize(context, mobile: 18), // edit feature
            color: Colors.orange, // edit feature: Orange like reply button
          ), // edit feature
          SizedBox(width: ResponsiveHelper.spacing(context, 4)), // edit feature
          Text( // edit feature
            'Edit', // edit feature
            style: TextStyle( // edit feature
              fontSize: ResponsiveHelper.fontSize(context, mobile: 11), // edit feature
              color: Colors.orange, // edit feature: Orange like reply button
            ), // edit feature
          ), // edit feature
        ], // edit feature
      ), // edit feature
    ); // edit feature
  } // edit feature

  // edit feature: Build edit input widget
  Widget _buildEditInput(BuildContext context, int commentId, int videoId, String postType) { // edit feature
    if (!editControllers.containsKey(commentId)) { // edit feature
      editControllers[commentId] = TextEditingController(); // edit feature
    } // edit feature
    final editController = editControllers[commentId]!; // edit feature

    return Container( // edit feature
      padding: ResponsiveHelper.padding(context, all: 12), // edit feature
      decoration: BoxDecoration( // edit feature
        color: const Color(0xFFE3F2FD), // edit feature
        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)), // edit feature
        border: Border.all( // edit feature
          color: const Color(0xFF2196F3).withOpacity(0.3), // edit feature
          width: 1.5, // edit feature
        ), // edit feature
      ), // edit feature
      child: Column( // edit feature
        crossAxisAlignment: CrossAxisAlignment.start, // edit feature
        children: [ // edit feature
          Text( // edit feature
            'Edit Comment', // edit feature
            style: ResponsiveHelper.textStyle( // edit feature
              context, // edit feature
              fontSize: ResponsiveHelper.fontSize(context, mobile: 14), // edit feature
              fontWeight: FontWeight.bold, // edit feature
              color: const Color(0xFF1565C0), // edit feature
            ), // edit feature
          ), // edit feature
          SizedBox(height: ResponsiveHelper.spacing(context, 8)), // edit feature
          TextField( // edit feature
            controller: editController, // edit feature
            maxLines: 3, // edit feature
            decoration: InputDecoration( // edit feature
              border: OutlineInputBorder( // edit feature
                borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)), // edit feature
              ), // edit feature
              contentPadding: ResponsiveHelper.padding(context, horizontal: 12, vertical: 8), // edit feature
            ), // edit feature
            style: TextStyle(fontSize: 13), // edit feature
          ), // edit feature
          SizedBox(height: ResponsiveHelper.spacing(context, 8)), // edit feature
          Row( // edit feature
            mainAxisAlignment: MainAxisAlignment.end, // edit feature
            children: [ // edit feature
              TextButton( // edit feature
                onPressed: () { // edit feature
                  setState(() { // edit feature
                    showEditInput[commentId] = false; // edit feature
                  }); // edit feature
                }, // edit feature
                child: Text( // edit feature
                  'Cancel', // edit feature
                  style: ResponsiveHelper.textStyle( // edit feature
                    context, // edit feature
                    fontSize: 12, // edit feature
                    color: Colors.grey[600], // edit feature
                  ), // edit feature
                ), // edit feature
              ), // edit feature
              SizedBox(width: ResponsiveHelper.spacing(context, 8)), // edit feature
              ElevatedButton( // edit feature
                onPressed: () => _editComment(context, commentId, videoId, postType), // edit feature
                style: ElevatedButton.styleFrom( // edit feature
                  backgroundColor: const Color(0xFF2196F3), // edit feature
                  padding: ResponsiveHelper.padding( // edit feature
                    context, // edit feature
                    horizontal: 16, // edit feature
                    vertical: 8, // edit feature
                  ), // edit feature
                ), // edit feature
                child: Obx(() => isEditingComment.value // edit feature
                    ? SizedBox( // edit feature
                        width: 16, // edit feature
                        height: 16, // edit feature
                        child: CircularProgressIndicator( // edit feature
                          strokeWidth: 2, // edit feature
                          color: Colors.white, // edit feature
                        ), // edit feature
                      ) // edit feature
                    : Text( // edit feature
                        'Save', // edit feature
                        style: TextStyle(fontSize: 12, color: Colors.white), // edit feature
                      )), // edit feature
              ), // edit feature
            ], // edit feature
          ), // edit feature
        ], // edit feature
      ), // edit feature
    ); // edit feature
  } // edit feature

  // edit feature: Edit comment method
  Future<void> _editComment(BuildContext context, int commentId, int videoId, String postType) async { // edit feature
    final editController = editControllers[commentId]; // edit feature
    if (editController == null) return; // edit feature

    final content = editController.text.trim(); // edit feature
    if (content.isEmpty) { // edit feature
      ScaffoldMessenger.of(context).showSnackBar( // edit feature
        SnackBar( // edit feature
          content: Text('Comment cannot be empty'), // edit feature
          backgroundColor: Colors.red, // edit feature
          duration: const Duration(seconds: 2), // edit feature
        ), // edit feature
      ); // edit feature
      return; // edit feature
    } // edit feature

    if (userId == 0) { // edit feature
      ScaffoldMessenger.of(context).showSnackBar( // edit feature
        SnackBar( // edit feature
          content: Text('Please login first'), // edit feature
          backgroundColor: Colors.red, // edit feature
          duration: const Duration(seconds: 2), // edit feature
        ), // edit feature
      ); // edit feature
      return; // edit feature
    } // edit feature

    isEditingComment.value = true; // edit feature
    try { // edit feature
      await CommentsService.editComment( // edit feature
        userId: userId, // edit feature
        commentId: commentId, // edit feature
        postType: postType, // edit feature
        postId: videoId, // edit feature
        content: content, // edit feature
      ); // edit feature

      setState(() { // edit feature
        showEditInput[commentId] = false; // edit feature
      }); // edit feature

      // Reload comments
      await _loadComments(videoId); // edit feature

      ScaffoldMessenger.of(context).showSnackBar( // edit feature
        SnackBar( // edit feature
          content: Text('Comment edited successfully'), // edit feature
          backgroundColor: Colors.green, // edit feature
          duration: const Duration(seconds: 2), // edit feature
        ), // edit feature
      ); // edit feature
    } catch (e) { // edit feature
      ScaffoldMessenger.of(context).showSnackBar( // edit feature
        SnackBar( // edit feature
          content: Text('Failed to edit comment'), // edit feature
          backgroundColor: Colors.red, // edit feature
          duration: const Duration(seconds: 2), // edit feature
        ), // edit feature
      ); // edit feature
    } finally { // edit feature
      isEditingComment.value = false; // edit feature
    } // edit feature
  } // edit feature

  @override
  Widget build(BuildContext context) {
    final videoId = Get.arguments as int? ?? 0;

    return PopScope(
      canPop: !_isFullScreen,
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (_isFullScreen) {
          _toggleFullScreen();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        extendBodyBehindAppBar: true,
        appBar: _isFullScreen ? null : const StandardAppBar(
          showBackButton: true,
        ),
        body: Obx(() {
          if (controller.isLoading.value && controller.selectedVideo.isEmpty) {
            return Center(
              child: CircularProgressIndicator(color: AppTheme.iconscolor),
            );
          }

          if (controller.selectedVideo.isEmpty) {
            return _buildEmptyState();
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

          Widget mainVideoWidget = isLiveVideo
              ? LiveVideoPlayer(liveStream: video, autoPlay: true, showControls: true)
              : videoUrl.isNotEmpty
                  ? _buildVideoPlayer(videoUrl)
                  : Center(child: Image.network(ImageConfig.videoThumbnail, fit: BoxFit.cover));

          return Stack(
            children: [
              // Normal View
              if (!_isFullScreen)
                Column(
                  children: [
                    const SizedBox(height: kToolbarHeight + 30),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AspectRatio(
                              key: const ValueKey('video_aspect_ratio'),
                              aspectRatio: (MediaQuery.of(context).orientation == Orientation.landscape)
                                  ? MediaQuery.of(context).size.aspectRatio
                                  : 16 / 9,
                              child: mainVideoWidget,
                            ),
                            _buildVideoInfoAndComments(video, videoId),
                          ],
                        ),
                      ),
                    ),
                    _buildCommentInputBar(videoId),
                  ],
                ),

              // Full Screen Overlay
              if (_isFullScreen)
                Positioned.fill(
                  child: Container(
                    color: Colors.black,
                    child: mainVideoWidget,
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.video_library_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('Video not found', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
        ],
      ),
    );
  }

  // New helper to wrap the rest of the UI
  Widget _buildVideoInfoAndComments(Map<String, dynamic> video, int videoId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Info Card
        Container(
          margin: EdgeInsets.all(ResponsiveHelper.spacing(context, 12)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 20)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 6)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWriterHeader(video, videoId),
              _buildVideoDetails(video),
            ],
          ),
        ),
        _buildEmojiReactions(context, videoId, controller),
        _buildCommentsSection(videoId),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildWriterHeader(Map<String, dynamic> video, int videoId) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundImage: video['profile_photo'] != null && (video['profile_photo'] as String).isNotEmpty
                ? NetworkImage(video['profile_photo'].startsWith('http') ? video['profile_photo'] : baseUrl + video['profile_photo'])
                : null,
            child: video['profile_photo'] == null ? const Icon(Icons.person) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(video['user_name'] ?? 'Anonymous', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Text('Blogger', style: TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          ),
          _buildShareButton(videoId),
        ],
      ),
    );
  }

  Widget _buildShareButton(int videoId) {
    return InkWell(
      onTap: () {
        final video = controller.selectedVideo;
        final baseUrl = 'http://admin.fosmessenger.com/';
        final thumbnailPath = video['thumbnail_path'] as String? ?? '';
        final filePath = video['file_path'] as String? ?? '';
        final mediaUrl = thumbnailPath.isNotEmpty 
            ? baseUrl + thumbnailPath 
            : (filePath.isNotEmpty ? baseUrl + filePath : null);

        ShareHelper.shareContent(
          context: context,
          contentType: 'video',
          contentId: videoId,
          title: video['title'] ?? 'Video',
          content: video['description'],
          mediaUrl: mediaUrl,
        );
      },

      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: AppTheme.iconscolor.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(Icons.share_rounded, size: 22, color: AppTheme.iconscolor),
      ),
    );
  }

  Widget _buildVideoDetails(Map<String, dynamic> video) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(video['title'] ?? 'Untitled', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          if ((video['description'] ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(video['description'], style: const TextStyle(color: Colors.black54, fontSize: 14)),
          ],
        ],
      ),
    );
  }

  Widget _buildCommentsSection(int videoId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text('Comments (${comments.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        if (isLoading)
          const Center(child: CircularProgressIndicator())
        else if (comments.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No comments yet')))
        else
          Column(
            children: comments
                .where((c) => c['parent_comment_id'] == null || c['parent_comment_id'] == 0)
                .map((c) => _buildCommentItem(context, c, videoId))
                .toList(),
          ),
      ],
    );
  }

  Widget _buildCommentInputBar(int videoId) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -2))]),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(25),
                ),
                child: TextField(
                  controller: commentController,
                  decoration: InputDecoration(
                    hintText: userId > 0 ? 'Write a comment...' : 'Login to comment',
                    border: InputBorder.none,
                  ),
                  enabled: userId > 0 && !_isSendingComment,
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: userId > 0 && !_isSendingComment ? (_) => _addComment(videoId) : null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Emoji button (reusable widget from blog_details_screen)
            EmojiButton(
              onTap: () => _showEmojiPicker(context, videoId, commentController),
            ),
            const SizedBox(width: 8),
            _isSendingComment
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : IconButton(
                    icon: Icon(Icons.send_rounded, color: AppTheme.iconscolor),
                    onPressed: userId > 0 ? () => _addComment(videoId) : null,
                  ),
          ],
        ),
      ),
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

    final baseUrl = 'http://admin.fosmessenger.com/';
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
                    // User Name and Time
                    Row(
                      children: [
                        Text(
                          userName,
                          style: ResponsiveHelper.textStyle(
                            context,
                            fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        if (comment['created_at'] != null) ...[
                          SizedBox(width: ResponsiveHelper.spacing(context, 6)),
                          Text(
                            '•',
                            style: ResponsiveHelper.textStyle(
                              context,
                              fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                              color: Colors.grey,
                            ),
                          ),
                          SizedBox(width: ResponsiveHelper.spacing(context, 6)),
                          Text(
                            TimeHelper.getTimeAgo(comment['created_at'] as String?),
                            style: ResponsiveHelper.textStyle(
                              context,
                              fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
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
                      userEmail: userEmail,
                    ),
                    // edit feature: Show "edited" label if comment was edited
                    if (comment['is_edited'] == true || comment['is_edited'] == 1) ...[
                      SizedBox(height: ResponsiveHelper.spacing(context, 6)),
                      Text(
                        'edited',
                        style: TextStyle(
                          fontSize: ResponsiveHelper.fontSize(context, mobile: 11),
                          color: Colors.grey[500],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
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
                    // Close all other reply inputs first
                    showReplyInput.clear();
                    
                    // Toggle current reply input
                    showReplyInput[commentId] = true;
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
              // Edit Button (only show for own comments within time window)
              if (comment['user_id'] == userId) ...[
                SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                _buildEditButton(context, comment, videoId),
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

          // Edit Input
          if (showEditInput[commentId] == true) ...[
            SizedBox(height: ResponsiveHelper.spacing(context, 12)),
            _buildEditInput(context, commentId, videoId, 'video'),
          ],

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
    // Initialize focus node if not exists
    if (!replyFocusNodes.containsKey(parentCommentId)) {
      replyFocusNodes[parentCommentId] = FocusNode();
    }
    
    return Row(
      children: [
        SizedBox(width: ResponsiveHelper.spacing(context, 40)),
        // Emoji button for reply
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showEmojiPicker(context, videoId, replyControllers[parentCommentId]!, parentCommentId: parentCommentId),
            borderRadius: BorderRadius.circular(ResponsiveHelper.isMobile(context) ? 40 : 44),
            child: Padding(
              padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 4)),
              child: Icon(
                Icons.emoji_emotions_outlined,
                color: const Color(0xFF8B4513),
                size: ResponsiveHelper.iconSize(context, mobile: 20),
              ),
            ),
          ),
        ),
        SizedBox(width: ResponsiveHelper.spacing(context, 4)),
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
              focusNode: replyFocusNodes[parentCommentId],
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
              enabled: !_sendingReplies.contains(parentCommentId),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => !_sendingReplies.contains(parentCommentId)
                  ? _addComment(videoId, parentCommentId: parentCommentId)
                  : null,
            ),
          ),
        ),
        SizedBox(width: ResponsiveHelper.spacing(context, 8)),
        _sendingReplies.contains(parentCommentId)
            ? SizedBox(
                width: 38,
                height: 38,
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.iconscolor,
                    ),
                  ),
                ),
              )
            : InkWell(
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
                            _showCustomSnackbar(
                              context,
                              'Success',
                              'Reaction added',
                            );
                          } else {
                            _showCustomSnackbar(
                              context,
                              'Error',
                              controller.message.value,
                              isError: true,
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
                              userEmail: userEmail,
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
                  onTap: () => _showEmojiPicker(context, videoId, commentController),
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
                            userEmail: userEmail,
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
                                profilePhotoUrl = 'http://admin.fosmessenger.com/$photoPath';
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
                                          TimeHelper.getTimeAgo(userData['created_at'] as String?),
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
                                        userEmail: userEmail,
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
                          userEmail: userEmail,
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
                        profilePhotoUrl = 'http://admin.fosmessenger.com/$photoPath';
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
                        TimeHelper.getTimeAgo(user['created_at'] as String?),
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


  /// Show emoji picker for video comments - sends emoji directly without showing in input field
  void _showEmojiPicker(BuildContext context, int videoId, TextEditingController controller, {int? parentCommentId}) {
    showEmojiStickerPicker(
      context: context,
      onEmojiSelected: (emoji) async {
        // Send emoji directly as comment - no preview in text field!
        await _sendEmojiDirectly(videoId, emoji, parentCommentId: parentCommentId);
      },
      height: 350,
    );
  }

  /// Send emoji/sticker directly as comment without showing in input field
  Future<void> _sendEmojiDirectly(int videoId, String emoji, {int? parentCommentId}) async {
    if (emoji.isEmpty || userId == 0) return;

    FocusScope.of(context).unfocus();

    setState(() => _isSendingComment = true);

    try {
      await CommentsService.addComment(
        userId: userId,
        postType: 'video',
        postId: videoId,
        content: emoji,
        parentCommentId: parentCommentId,
      );

      // Clear and reload
      commentController.clear();
      await _loadComments(videoId);
      _scrollToBottom();
    } catch (e) {
      print('Error sending emoji comment: $e');
    } finally {
      setState(() => _isSendingComment = false);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
      );
    }
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
                onTap: () async {
                  Navigator.pop(context);
                  await ReportUtils.handleReportButtonTap(
                    context: context,
                    contentType: 'video_comment',
                    contentId: comment['id'] is int ? comment['id'] : int.parse(comment['id'].toString()),
                  );
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

                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('Block $userName?'),
                        content: const Text('You will no longer see content from this user.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                          TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('Block', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );

                    if (confirmed == true) {
                      try {
                        await UserBlockingService.blockUser(userId);
                        _showCustomSnackbar(context, 'Success', 'User blocked');
                        _loadComments(controller.selectedVideo['id']);
                      } catch (e) {
                        _showCustomSnackbar(context, 'Error', 'Failed to block user', isError: true);
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
    final userIdRaw = video['user_id'] ?? video['created_by'];
    final posterId = userIdRaw is int ? userIdRaw : int.tryParse(userIdRaw?.toString() ?? '');
    
    // Check if we have any options to show
    final hasOptions = posterId != null && posterId != this.userId;
    
    // Only show the PopupMenuButton if there are options
    if (!hasOptions) {
      return SizedBox(width: 40); // Empty placeholder for alignment
    }
    
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: Colors.grey[400]),
      onSelected: (value) async {
        if (value == 'report') {
          await ReportUtils.handleReportButtonTap(
            context: context,
            contentType: 'video',
            contentId: video['id'] is int ? video['id'] : int.parse(video['id'].toString()),
          );
        } else if (value == 'block') {
          final userIdRaw = video['user_id'] ?? video['created_by'];
          if (userIdRaw != null) {
            final userId = userIdRaw is int ? userIdRaw : int.tryParse(userIdRaw.toString());
            if (userId == null) return;

            if (this.userId == userId) {
              _showCustomSnackbar(context, 'Info', 'You cannot block yourself');
              return;
            }

            final userName = video['user_name'] ?? 'this poster';
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('Block $userName?'),
                content: const Text('You will no longer see content from this user.'),
                actions: [
                  TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                  TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Block', style: TextStyle(color: Colors.red))),
                ],
              ),
            );

            if (confirmed == true) {
              try {
                await UserBlockingService.blockUser(userId);
                _showCustomSnackbar(context, 'Success', 'User blocked');
                Navigator.of(context).pop(); // Back to list
              } catch (e) {
                _showCustomSnackbar(context, 'Error', 'Failed to block user', isError: true);
              }
            }
          }
        }
      },
      itemBuilder: (context) {
        final List<PopupMenuEntry<String>> items = [];
        
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
