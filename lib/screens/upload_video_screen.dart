import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fruitsofspirit/controllers/videos_controller.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';
import 'package:fruitsofspirit/widgets/standard_app_bar.dart';
import 'package:fruitsofspirit/utils/app_theme.dart';
import 'package:fruitsofspirit/utils/permission_manager.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';

/// Upload Video Screen - Modern User-Friendly Design
class UploadVideoScreen extends StatefulWidget {
  const UploadVideoScreen({Key? key}) : super(key: key);

  @override
  State<UploadVideoScreen> createState() => _UploadVideoScreenState();
}

class _UploadVideoScreenState extends State<UploadVideoScreen> with SingleTickerProviderStateMixin {
  final controller = Get.find<VideosController>();
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  File? selectedVideo;
  File? thumbnailFile;
  String? selectedFruitTag;
  VideoPlayerController? _previewController;
  String? _videoFileName;
  String? _videoFileSize;
  Duration? _videoDuration;
  bool _isInitializingPreview = false;
  bool _isPlayingPreview = false;
  bool _isGeneratingThumbnail = false;
  
  AnimationController? _animationController;
  Animation<double>? _fadeAnimation;
  Animation<Offset>? _slideAnimation;

  // Fruit of the Spirit options
  final List<String> _fruitsOfSpirit = [
    'Love',
    'Joy',
    'Peace',
    'Patience',
    'Kindness',
    'Goodness',
    'Faithfulness',
    'Gentleness',
    'Self-Control',
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }
  
  void _initializeAnimations() {
    // Initialize animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController!, curve: Curves.easeInOut),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController!, curve: Curves.easeOutCubic),
    );
    
    _animationController!.forward();
  }

  @override
  void dispose() {
    _animationController?.dispose();
    _previewController?.dispose();
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    try {
      final picker = ImagePicker();
      final video = await picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 10), // Optional: limit video duration
      );
      
      if (video != null) {
        final file = File(video.path);
        setState(() {
          selectedVideo = file;
          thumbnailFile = null; // Clear previous thumbnail
          _videoFileName = video.name;
          _isInitializingPreview = true;
          _isGeneratingThumbnail = true;
        });
        
        // Get file size
        final fileSize = await file.length();
        _videoFileSize = _formatFileSize(fileSize);
        
        // Generate thumbnail first
        try {
          print('🔄 Starting thumbnail generation...');
          final thumbnail = await _generateThumbnail(file.path);
          if (thumbnail != null && mounted) {
            print('✅ Thumbnail ready: ${thumbnail.path}');
            setState(() {
              thumbnailFile = thumbnail;
              _isGeneratingThumbnail = false;
            });
          } else {
            print('⚠️ Thumbnail generation failed or returned null');
            setState(() {
              thumbnailFile = null;
              _isGeneratingThumbnail = false;
            });
          }
        } catch (e) {
          print('❌ Error generating thumbnail: $e');
          setState(() {
            thumbnailFile = null;
            _isGeneratingThumbnail = false;
          });
        }
        
        // Initialize video preview
        try {
          _previewController?.dispose();
          _previewController = VideoPlayerController.file(file);
          await _previewController!.initialize();
          
          // Don't auto-play, just show first frame (thumbnail)
          _previewController!.pause();
          
          // Add listener to track play state
          _previewController!.addListener(() {
            if (mounted) {
              setState(() {
                _isPlayingPreview = _previewController!.value.isPlaying;
              });
            }
          });
          
          setState(() {
            _videoDuration = _previewController!.value.duration;
            _isInitializingPreview = false;
            _isPlayingPreview = false;
          });
        } catch (e) {
          print('Error initializing video preview: $e');
          setState(() {
            _isInitializingPreview = false;
          });
        }
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to pick video: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  /// Generate thumbnail from video
  Future<File?> _generateThumbnail(String videoPath) async {
    try {
      print('🎬 ========== THUMBNAIL GENERATION START ==========');
      print('🎬 Video path: $videoPath');
      
      // Check if video file exists
      final videoFile = File(videoPath);
      if (!await videoFile.exists()) {
        print('❌ Video file does not exist: $videoPath');
        return null;
      }
      
      final videoSize = await videoFile.length();
      print('🎬 Video file size: $videoSize bytes');
      
      // Request storage permission if needed
      try {
        final hasPermission = await PermissionManager.requestStoragePermission();
        if (!hasPermission) {
          print('⚠️ Storage permission not granted, but continuing...');
        } else {
          print('✅ Storage permission granted');
        }
      } catch (e) {
        print('⚠️ Permission check error: $e (continuing anyway)');
      }
      
      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      print('🎬 Temp directory: ${tempDir.path}');
      
      // Create a unique filename with .jpg extension
      final videoName = videoFile.path.split('/').last.split('.').first.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final thumbnailFileName = 'thumb_${videoName}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final thumbnailPath = '${tempDir.path}/$thumbnailFileName';
      
      print('🎬 Thumbnail will be saved to: $thumbnailPath');
      
      // Try generating thumbnail with timeout
      final generatedPath = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: thumbnailPath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 720, // Set width for portrait aspect ratio
        maxHeight: 1280, // Set height for portrait aspect ratio
        quality: 85,
        timeMs: 1000, // Extract frame at 1 second
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print('❌ Thumbnail generation timeout after 30 seconds');
          return null;
        },
      );
      
      if (generatedPath != null && generatedPath.isNotEmpty) {
        print('🎬 Generated path received: $generatedPath');
        final thumbnailFile = File(generatedPath);
        
        // Wait a bit for file system to sync
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (await thumbnailFile.exists()) {
          final fileSize = await thumbnailFile.length();
          print('✅ Thumbnail generated successfully!');
          print('   Path: $generatedPath');
          print('   Size: $fileSize bytes');
          print('🎬 ========== THUMBNAIL GENERATION SUCCESS ==========');
          return thumbnailFile;
        } else {
          print('❌ Thumbnail file does not exist at: $generatedPath');
          // Try alternative path
          final altPath = File(thumbnailPath);
          if (await altPath.exists()) {
            print('✅ Found thumbnail at alternative path: $thumbnailPath');
            return altPath;
          }
        }
      } else {
        print('❌ Thumbnail generation returned null or empty path');
      }
      
      print('🎬 ========== THUMBNAIL GENERATION FAILED ==========');
      return null;
    } catch (e, stackTrace) {
      print('❌ ========== THUMBNAIL GENERATION ERROR ==========');
      print('❌ Error: $e');
      print('❌ Stack trace: $stackTrace');
      print('❌ ================================================');
      return null;
    }
  }

  Future<void> _uploadVideo() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (selectedVideo == null) {
      Get.snackbar(
        'Error',
        'Please select a video',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    // Log thumbnail status before upload
    final thumbnail = thumbnailFile;
    if (thumbnail != null) {
      print('📤 Uploading with thumbnail: ${thumbnail.path}');
      final thumbnailExists = await thumbnail.exists();
      print('📤 Thumbnail file exists: $thumbnailExists');
      if (thumbnailExists) {
        final thumbnailSize = await thumbnail.length();
        print('📤 Thumbnail size: $thumbnailSize bytes');
      }
    } else {
      print('⚠️ No thumbnail file to upload');
    }
    
    final success = await controller.uploadVideo(
      videoFile: selectedVideo!,
      thumbnailFile: thumbnailFile, // Pass thumbnail if generated
      fruitTag: selectedFruitTag,
      title: titleController.text.trim(),
      description: descriptionController.text.trim(),
      category: selectedFruitTag, // Using fruit_tag as category for now, or add separate category field
    );

    if (success) {
      // Clear form
      if (mounted) {
        setState(() {
          titleController.clear();
          descriptionController.clear();
          selectedVideo = null;
          thumbnailFile = null;
          selectedFruitTag = null;
          _videoFileName = null;
          _videoFileSize = null;
          _videoDuration = null;
        });
      }
      
      _previewController?.dispose();
      _previewController = null;
      _isPlayingPreview = false;
      
      // Show success message
      Get.snackbar(
        'Success',
        controller.message.value.isNotEmpty 
            ? controller.message.value 
            : 'Video uploaded successfully!',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
        icon: const Icon(Icons.check_circle, color: Colors.white),
        margin: const EdgeInsets.all(16),
      );
      
      // Navigate back immediately
      if (mounted) {
        Navigator.of(context).pop();
        
        // Refresh videos on the previous screen
        Future.delayed(const Duration(milliseconds: 100), () {
          try {
            controller.loadVideos(refresh: true, includePending: true);
          } catch (e) {
            print('Error refreshing videos: $e');
          }
        });
      }
    } else {
      // Show error message
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Get.snackbar(
              'Error',
              controller.message.value.isNotEmpty 
                  ? controller.message.value 
                  : 'Failed to upload video. Please try again.',
              backgroundColor: Colors.red,
              colorText: Colors.white,
              snackPosition: SnackPosition.BOTTOM,
              duration: const Duration(seconds: 3),
              icon: const Icon(Icons.error, color: Colors.white),
              margin: const EdgeInsets.all(16),
            );
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.themeColor,
      appBar: const StandardAppBar(
        showBackButton: true,
      ),
      body: Obx(() {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: FadeTransition(
            opacity: _fadeAnimation!,
            child: SlideTransition(
              position: _slideAnimation!,
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Video Selection Card
                    Container(
                      width: double.infinity,
                      margin: EdgeInsets.all(ResponsiveHelper.spacing(context, 12)),
                      child: _buildVideoSelectionCard(),
                    ),

                    // Form Fields
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveHelper.spacing(context, 16),
                        vertical: ResponsiveHelper.spacing(context, 12),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                              // Title Input Card
                              _buildInputCard(
                                title: 'Video Title',
                                isRequired: true,
                                child: TextFormField(
                                  controller: titleController,
                                  validator: (value) {
                                    if (value == null || value
                                        .trim()
                                        .isEmpty) {
                                      return 'Please enter video title';
                                    }
                                    return null;
                                  },
                                  decoration: InputDecoration(
                                    hintText: 'Enter a catchy title for your video',
                                    prefixIcon: Icon(
                                      Icons.title_rounded,
                                      color: AppTheme.iconscolor.withValues(
                                          alpha: 0.6),
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        ResponsiveHelper.borderRadius(
                                            context, mobile: 16),
                                      ),
                                      borderSide: BorderSide(
                                          color: Colors.grey.withOpacity(0.3)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        ResponsiveHelper.borderRadius(
                                            context, mobile: 16),
                                      ),
                                      borderSide: BorderSide(
                                          color: Colors.grey.withOpacity(0.3)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        ResponsiveHelper.borderRadius(
                                            context, mobile: 16),
                                      ),
                                      borderSide: BorderSide(
                                          color: AppTheme.iconscolor, width: 2),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey[50],
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: ResponsiveHelper.spacing(
                                          context, 16),
                                      vertical: ResponsiveHelper.spacing(
                                          context, 16),
                                    ),
                                  ),
                                ),
                              ),

                              SizedBox(height: ResponsiveHelper.spacing(
                                  context, 20)),

                              // Description Input Card
                              _buildInputCard(
                                title: 'Description',
                                isRequired: false,
                                child: TextFormField(
                                  controller: descriptionController,
                                  maxLines: 4,
                                  decoration: InputDecoration(
                                    hintText: 'Tell us about your video (optional)',
                                    prefixIcon: Padding(
                                      padding: EdgeInsets.only(
                                        bottom: ResponsiveHelper.spacing(
                                            context, 60),
                                      ),
                                      child: Icon(
                                        Icons.description_rounded,
                                        color: AppTheme.iconscolor.withValues(
                                            alpha: 0.6),
                                      ),
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        ResponsiveHelper.borderRadius(
                                            context, mobile: 16),
                                      ),
                                      borderSide: BorderSide(
                                          color: Colors.grey.withOpacity(0.3)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        ResponsiveHelper.borderRadius(
                                            context, mobile: 16),
                                      ),
                                      borderSide: BorderSide(
                                          color: Colors.grey.withOpacity(0.3)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        ResponsiveHelper.borderRadius(
                                            context, mobile: 16),
                                      ),
                                      borderSide: BorderSide(
                                          color: AppTheme.iconscolor, width: 2),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey[50],
                                    contentPadding: EdgeInsets.all(
                                      ResponsiveHelper.spacing(context, 16),
                                    ),
                                  ),
                                ),
                              ),

                              SizedBox(height: ResponsiveHelper.spacing(
                                  context, 20)),

                              // Fruit Tag Selection Card
                              _buildInputCard(
                                title: 'Tag with Fruit',
                                isRequired: false,
                                child: DropdownButtonFormField<String>(
                                  value: selectedFruitTag,
                                  decoration: InputDecoration(
                                    hintText: 'Select a fruit (optional)',
                                    prefixIcon: Icon(
                                      Icons.local_florist_rounded,
                                      color: AppTheme.iconscolor.withValues(
                                          alpha: 0.6),
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        ResponsiveHelper.borderRadius(
                                            context, mobile: 16),
                                      ),
                                      borderSide: BorderSide(
                                          color: Colors.grey.withOpacity(0.3)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        ResponsiveHelper.borderRadius(
                                            context, mobile: 16),
                                      ),
                                      borderSide: BorderSide(
                                          color: Colors.grey.withOpacity(0.3)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        ResponsiveHelper.borderRadius(
                                            context, mobile: 16),
                                      ),
                                      borderSide: BorderSide(
                                          color: AppTheme.iconscolor, width: 2),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey[50],
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: ResponsiveHelper.spacing(
                                          context, 16),
                                      vertical: ResponsiveHelper.spacing(
                                          context, 16),
                                    ),
                                  ),
                                  items: _fruitsOfSpirit.map((fruit) {
                                    return DropdownMenuItem(
                                      value: fruit,
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: AppTheme.iconscolor,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          SizedBox(
                                              width: ResponsiveHelper.spacing(
                                                  context, 12)),
                                          Text(
                                            fruit,
                                            style: ResponsiveHelper.textStyle(
                                              context,
                                              fontSize: ResponsiveHelper
                                                  .fontSize(
                                                  context, mobile: 15),
                                              color: Colors.black,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      selectedFruitTag = value;
                                    });
                                  },
                                ),
                              ),

                              SizedBox(height: ResponsiveHelper.spacing(
                                  context, 32)),

                              // Upload Button
                              _buildUploadButton(),

                              SizedBox(height: ResponsiveHelper.spacing(
                                  context, 16)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      }

  Widget _buildVideoSelectionCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          ResponsiveHelper.borderRadius(context, mobile: 20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            spreadRadius: 0,
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: AppTheme.iconscolor.withOpacity(0.05),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header - Compact
          Padding(
            padding: EdgeInsets.only(
              left: ResponsiveHelper.spacing(context, 12),
              right: ResponsiveHelper.spacing(context, 12),
              top: ResponsiveHelper.spacing(context, 12), // Increased slightly
              bottom: ResponsiveHelper.spacing(context, 8), // Increased slightly
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.video_library_rounded,
                  size: ResponsiveHelper.iconSize(context, mobile: 18),
                  color: AppTheme.iconscolor,
                ),
                SizedBox(width: ResponsiveHelper.spacing(context, 6)),
                Flexible(
                  child: Text(
                    'Select Video',
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: ResponsiveHelper.fontSize(context, mobile: 15),
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
          Divider(height: 0.5, thickness: 0.5, color: Colors.grey[200]),
          
          // Video Selection Area - Full Screen, Centered
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveHelper.spacing(context, 8),
              vertical: ResponsiveHelper.spacing(context, 12),
            ),
            child: GestureDetector(
              onTap: _pickVideo,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: selectedVideo != null
                            ? LinearGradient(
                                colors: [
                                  AppTheme.iconscolor.withOpacity(0.1),
                                  AppTheme.iconscolor.withOpacity(0.05),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : LinearGradient(
                                colors: [
                                  Colors.grey[100]!,
                                  Colors.grey[50]!,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                        borderRadius: BorderRadius.circular(
                          ResponsiveHelper.borderRadius(context, mobile: 16),
                        ),
                        border: Border.all(
                          color: selectedVideo != null
                              ? AppTheme.iconscolor.withOpacity(0.3)
                              : Colors.grey[300]!,
                          width: 2,
                        ),
                      ),
                      child: _isInitializingPreview || _isGeneratingThumbnail
                        ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: AppTheme.iconscolor,
                            strokeWidth: 3,
                          ),
                          SizedBox(height: ResponsiveHelper.spacing(context, 12)),
                          Text(
                            _isGeneratingThumbnail 
                                ? 'Generating thumbnail...'
                                : 'Loading preview...',
                            style: ResponsiveHelper.textStyle(
                              context,
                              fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : selectedVideo == null
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 16)),
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
                              child: Icon(
                                Icons.video_library_rounded,
                                size: ResponsiveHelper.iconSize(context, mobile: 48),
                                color: AppTheme.iconscolor,
                              ),
                            ),
                            SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                            Text(
                              'Tap to Select Video',
                              style: ResponsiveHelper.textStyle(
                                context,
                                fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                            SizedBox(height: ResponsiveHelper.spacing(context, 4)),
                            Text(
                              'Choose from gallery',
                              style: ResponsiveHelper.textStyle(
                                context,
                                fontSize: ResponsiveHelper.fontSize(context, mobile: 13),
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        )
                      : Stack(
                          children: [
                            // Video Preview - Full Size
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  ResponsiveHelper.borderRadius(context, mobile: 16),
                                ),
                                child: _previewController != null &&
                                        _previewController!.value.isInitialized
                                    ? FittedBox(
                                        fit: BoxFit.cover,
                                        child: SizedBox(
                                          width: _previewController!.value.size.width,
                                          height: _previewController!.value.size.height,
                                          child: VideoPlayer(_previewController!),
                                        ),
                                      )
                                    : Container(
                                        color: Colors.black87,
                                        child: Center(
                                          child: Icon(
                                            Icons.video_library_rounded,
                                            size: ResponsiveHelper.iconSize(context, mobile: 64),
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                            
                            // Play/Pause Button Overlay - Center (only show when paused or on tap)
                            if (_previewController != null && _previewController!.value.isInitialized)
                              Positioned.fill(
                                child: Center(
                                  child: GestureDetector(
                                    onTap: () {
                                      if (_previewController!.value.isPlaying) {
                                        _previewController!.pause();
                                      } else {
                                        _previewController!.play();
                                      }
                                    },
                                    child: AnimatedOpacity(
                                      opacity: _isPlayingPreview ? 0.0 : 1.0,
                                      duration: const Duration(milliseconds: 200),
                                      child: Container(
                                        padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 16)),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.6),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.3),
                                              blurRadius: 15,
                                              spreadRadius: 2,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          Icons.play_circle_filled,
                                          color: Colors.white,
                                          size: ResponsiveHelper.iconSize(context, mobile: 64, tablet: 72, desktop: 80),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            
                            // Overlay with video info
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 12)),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      Colors.black.withOpacity(0.8),
                                      Colors.transparent,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.only(
                                    bottomLeft: Radius.circular(
                                      ResponsiveHelper.borderRadius(context, mobile: 16),
                                    ),
                                    bottomRight: Radius.circular(
                                      ResponsiveHelper.borderRadius(context, mobile: 16),
                                    ),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_videoFileName != null)
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.video_file_rounded,
                                            size: ResponsiveHelper.iconSize(context, mobile: 16),
                                            color: Colors.white70,
                                          ),
                                          SizedBox(width: ResponsiveHelper.spacing(context, 6)),
                                          Expanded(
                                            child: Text(
                                              _videoFileName!,
                                              style: ResponsiveHelper.textStyle(
                                                context,
                                                fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                                                color: Colors.white70,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    if (_videoFileSize != null || _videoDuration != null)
                                      SizedBox(height: ResponsiveHelper.spacing(context, 4)),
                                    Row(
                                      children: [
                                        if (_videoDuration != null) ...[
                                          Icon(
                                            Icons.timer_rounded,
                                            size: ResponsiveHelper.iconSize(context, mobile: 14),
                                            color: Colors.white70,
                                          ),
                                          SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                                          Text(
                                            _formatDuration(_videoDuration!),
                                            style: ResponsiveHelper.textStyle(
                                              context,
                                              fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                                              color: Colors.white70,
                                            ),
                                          ),
                                        ],
                                        if (_videoFileSize != null && _videoDuration != null)
                                          Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: ResponsiveHelper.spacing(context, 8),
                                            ),
                                            child: Container(
                                              width: 4,
                                              height: 4,
                                              decoration: BoxDecoration(
                                                color: Colors.white70,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ),
                                        if (_videoFileSize != null) ...[
                                          Icon(
                                            Icons.storage_rounded,
                                            size: ResponsiveHelper.iconSize(context, mobile: 14),
                                            color: Colors.white70,
                                          ),
                                          SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                                          Text(
                                            _videoFileSize!,
                                            style: ResponsiveHelper.textStyle(
                                              context,
                                              fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                                              color: Colors.white70,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            
                            // Change Video Button
                            Positioned(
                              top: ResponsiveHelper.spacing(context, 12),
                              right: ResponsiveHelper.spacing(context, 12),
                              child: GestureDetector(
                                onTap: _pickVideo,
                                child: Container(
                                  padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 8)),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.edit_rounded,
                                    size: ResponsiveHelper.iconSize(context, mobile: 20),
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ),
                  ),
                ),
          )
        ],
        ),
      );
  }

  Widget _buildInputCard({
    required String title,
    required bool isRequired,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          ResponsiveHelper.borderRadius(context, mobile: 20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            spreadRadius: 0,
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: AppTheme.iconscolor.withOpacity(0.05),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    title,
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isRequired) ...[
                  SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                  Text(
                    '*',
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 12)),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildUploadButton() {
    final isLoading = controller.isLoading.value;
    final canUpload = selectedVideo != null && !isLoading;
    
    return Container(
      width: double.infinity,
      height: ResponsiveHelper.buttonHeight(context, mobile: 56),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
          ResponsiveHelper.borderRadius(context, mobile: 16),
        ),
        boxShadow: canUpload
            ? [
                BoxShadow(
                  color: AppTheme.iconscolor.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: ElevatedButton(
        onPressed: canUpload ? _uploadVideo : null,
                style: ElevatedButton.styleFrom(
          backgroundColor: canUpload
              ? AppTheme.iconscolor
              : Colors.grey[300],
          foregroundColor: Colors.white,
          elevation: canUpload ? 4 : 0,
                  shadowColor: AppTheme.iconscolor.withOpacity(0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      ResponsiveHelper.borderRadius(context, mobile: 16),
                    ),
                  ),
                ),
        child: isLoading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: ResponsiveHelper.iconSize(context, mobile: 20),
                    height: ResponsiveHelper.iconSize(context, mobile: 20),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                  Text(
                    'Uploading...',
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_upload_rounded,
                    size: ResponsiveHelper.iconSize(context, mobile: 24),
                  ),
                  SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                  Text(
                        'Upload Video',
                        style: ResponsiveHelper.textStyle(
                          context,
                          fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                ],
              ),
            ),
    );
  }
}
