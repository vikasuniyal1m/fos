import 'package:fruitsofspirit/routes/routes.dart';
import 'package:image_cropper/image_cropper.dart';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:fruitsofspirit/controllers/blogs_controller.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';
import 'package:fruitsofspirit/utils/app_theme.dart';
import 'package:fruitsofspirit/widgets/standard_app_bar.dart';
import '../controllers/main_dashboard_controller.dart';
import '../services/terms_service.dart';
import '../services/user_storage.dart' as us;
import 'terms_acceptance_screen.dart';

/// Create Blog Screen (Bloggers Only)
class CreateBlogScreen extends StatefulWidget {
  const CreateBlogScreen({Key? key}) : super(key: key);

  @override
  State<CreateBlogScreen> createState() => _CreateBlogScreenState();
}

class _CreateBlogScreenState extends State<CreateBlogScreen> {
  final BlogsController controller = Get.find<BlogsController>();
  final TextEditingController titleController = TextEditingController();
  final TextEditingController bodyController = TextEditingController();
  bool _isSubmitting = false;
  
  // Initialize pickers once in state
  final ImagePicker _picker = ImagePicker();
  final ImageCropper _cropper = ImageCropper();
  
  File? selectedMedia;
  bool selectedMediaIsVideo = false;
  VideoPlayerController? _previewController;
  bool _isPreviewInitialized = false;
  bool _isPreviewPlaying = false;
  String selectedCategory = 'Others';  // Changed from 'Spiritual' to 'Others' as default
  String selectedLanguage = 'en';
  final TextEditingController customCategoryController = TextEditingController();  // For custom 'Others' category
  
  @override
  void initState() {
    super.initState();
    // Add listener to update character count
    bodyController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    titleController.dispose();
    bodyController.dispose();
    customCategoryController.dispose();  // Dispose custom category controller
    _previewController?.removeListener(_previewListener);
    _previewController?.dispose();
    super.dispose();
  }

  Future<void> _showMediaPickerOptions() async {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo),
                title: const Text('Select Image'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.video_library),
                title: const Text('Select Video'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickVideo();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      final croppedFile = await _cropper.cropImage(
        sourcePath: pickedFile.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Image',
            toolbarColor: AppTheme.iconscolor,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'Crop Image',
            aspectRatioLockEnabled: false,
            doneButtonTitle: 'Done',
            cancelButtonTitle: 'Cancel',
          ),
        ],
      );

      if (croppedFile != null) {
        setState(() {
          selectedMedia = File(croppedFile.path);
          selectedMediaIsVideo = false;
        });
      }
    }
  }

  Future<void> _pickVideo() async {
    final pickedFile = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 10),
    );

    if (pickedFile != null) {
      final file = File(pickedFile.path);
      await _initPreviewController(file);
      setState(() {
        selectedMedia = file;
        selectedMediaIsVideo = true;
      });
    }
  }

  Future<void> _initPreviewController(File file) async {
    try {
      _previewController?.removeListener(_previewListener);
      await _previewController?.dispose();
      _previewController = null;
      _isPreviewInitialized = false;
      _isPreviewPlaying = false;

      final controller = VideoPlayerController.file(file);
      _previewController = controller;
      await controller.initialize();
      await controller.pause();
      controller.addListener(_previewListener);
      if (mounted) {
        setState(() {
          _isPreviewInitialized = true;
        });
      }
    } catch (e) {
      print('Preview init error: $e');
      if (mounted) {
        setState(() {
          _isPreviewInitialized = false;
        });
      }
    }
  }

  void _previewListener() {
    if (!mounted || _previewController == null) return;
    final playing = _previewController!.value.isPlaying;
    if (playing != _isPreviewPlaying) {
      setState(() {
        _isPreviewPlaying = playing;
      });
    }
    if (_previewController!.value.hasError) {
      print('Preview controller error: ${_previewController!.value.errorDescription}');
    }
  }

  void _removeMedia() {
    setState(() {
      selectedMedia = null;
      selectedMediaIsVideo = false;
    });
    _previewController?.removeListener(_previewListener);
    _previewController?.dispose();
    _previewController = null;
    _isPreviewInitialized = false;
    _isPreviewPlaying = false;
  }

  /// Show a custom snackbar using ScaffoldMessenger
  void _showCustomSnackbar(BuildContext context, String title, String message, {bool isError = false, Color? backgroundColor, Color? textColor, Icon? icon, Duration? duration}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: icon,
              ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: textColor ?? Colors.white)),
                  Text(message, style: TextStyle(color: textColor ?? Colors.white)),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor ?? (isError ? Colors.red : AppTheme.iconscolor),
        duration: duration ?? const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _submitBlog() async {
    if (_isSubmitting) return;

    FocusScope.of(context).unfocus();

    // Check for terms acceptance
    final hasAcceptedFactors = await TermsService.hasAcceptedTerms();
    if (!hasAcceptedFactors) {
      Get.to(() => TermsAcceptanceScreen(
        onAccepted: () {
          if (mounted) {
            Navigator.of(context).pop();
            _submitBlog();
          }
        },
      ));
      return;
    }
    // Validation
    if (titleController.text.trim().isEmpty) {
      _showCustomSnackbar(
        context,
        'Suggestion',
        'Please enter blog title',
        backgroundColor: Colors.orange.shade300,
        textColor: Colors.black,
      );
      return;
    }

    if (bodyController.text.trim().isEmpty) {
      _showCustomSnackbar(
        context,
        'Suggestion',
        'Please enter blog content',
        backgroundColor: Colors.orange.shade300,
        textColor: Colors.black,
      );
      return;
    }

    if (bodyController.text.trim().length < 50) {
      _showCustomSnackbar(
        context,
        'Suggestion',
        'Blog content must be at least 50 characters long.',
        backgroundColor: Colors.orange.shade300,
        textColor: Colors.black,
      );
      return;
    }

    // Validate custom category when 'Others' is selected
    if (selectedCategory == 'Others' && customCategoryController.text.trim().isEmpty) {
      _showCustomSnackbar(
        context,
        'Required',
        'Please enter a custom category or select a different category.',
        backgroundColor: Colors.orange.shade300,
        textColor: Colors.black,
      );
      return;
    }

    // Use custom category if 'Others' is selected and custom text is entered
    final String categoryToSubmit = (selectedCategory == 'Others' && customCategoryController.text.trim().isNotEmpty)
        ? customCategoryController.text.trim()
        : selectedCategory;

    setState(() {
      _isSubmitting = true;
    });

    final title = titleController.text.trim();
    final body = bodyController.text.trim();

    final success = await controller.createBlog(
      title: title,
      body: body,
      category: categoryToSubmit,
      language: selectedLanguage,
      media: selectedMedia,
    );

    if (!mounted) return;

    if (success) {
      controller.filterUserId.value = 0;

      if (Get.isRegistered<MainDashboardController>()) {
        try {
          Get.find<MainDashboardController>().changeIndex(0);
        } catch (e) {
          print('Error changing dashboard index: $e');
        }
      }

      Get.offNamedUntil(Routes.DASHBOARD, (route) => false);
      Get.snackbar(
        'Success',
        controller.message.value.isNotEmpty
            ? controller.message.value
            : 'Blog created successfully! Waiting for approval.',
        backgroundColor: AppTheme.iconscolor,
        colorText: Colors.black,
        duration: const Duration(seconds: 2),
      );
      return;
    }

    setState(() {
      _isSubmitting = false;
    });

    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final errorMsg = controller.message.value;
          final isModeration = errorMsg.contains('community guidelines');

          _showCustomSnackbar(
            context,
            isModeration ? 'Community Standard' : 'Community Suggestion',
            errorMsg.isNotEmpty
                ? errorMsg
                : 'Action could not be completed. Please try again.',
            backgroundColor: isModeration ? const Color(0xFF5D4037) : Colors.orange.shade300,
            textColor: isModeration ? Colors.white : Colors.black,
            icon: Icon(
              isModeration ? Icons.security_rounded : Icons.tips_and_updates_outlined,
              color: isModeration ? const Color(0xFFC79211) : Colors.black,
              size: 28,
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.themeColor, // Match other pages - beige background
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(
          ResponsiveHelper.appBarHeight(context),
        ),
        child: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: Container(
            margin: EdgeInsets.all(ResponsiveHelper.spacing(context, 8)),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: AppTheme.iconscolor,
                size: ResponsiveHelper.iconSize(context, mobile: 24, tablet: 28, desktop: 32),
              ),
              onPressed: () => Get.back(),
            ),
          ),
          title: Text(
            'Create New Blog',
            style: ResponsiveHelper.textStyle(
              context,
              fontSize: ResponsiveHelper.fontSize(context, mobile: 18, tablet: 20, desktop: 22),
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          centerTitle: true,
        ),
      ),
      body: Obx(() {
        if (controller.userRole.value != 'Blogger') {
          return Center(
            child: Padding(
              padding: ResponsiveHelper.padding(context, all: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: ResponsiveHelper.padding(context, all: 24),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_outline_rounded,
                      size: ResponsiveHelper.iconSize(context, mobile: 64, tablet: 72, desktop: 80),
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(context, 24)),
                  Text(
                    'Blogger Access Required',
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: ResponsiveHelper.fontSize(context, mobile: 22, tablet: 24, desktop: 26),
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(context, 12)),
                  Text(
                    'Only approved bloggers can create and publish blog posts.',
                    textAlign: TextAlign.center,
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 17, desktop: 18),
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final double minMediaHeight = ResponsiveHelper.imageHeight(context, mobile: 220, tablet: 250, desktop: 280);
        final double maxMediaHeight = ResponsiveHelper.imageHeight(context, mobile: 320, tablet: 340, desktop: 380);
        final double mediaPreviewHeight = selectedMediaIsVideo && _isPreviewInitialized && _previewController != null
            ? (MediaQuery.of(context).size.width / _previewController!.value.aspectRatio).clamp(minMediaHeight, maxMediaHeight)
            : minMediaHeight;

        return SingleChildScrollView(
          padding: ResponsiveHelper.padding(context, all: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Blog Media Selection Section
              Text(
                'Blog Media',
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: ResponsiveHelper.fontSize(context, mobile: 18, tablet: 19, desktop: 20),
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              SizedBox(height: ResponsiveHelper.spacing(context, 8)),
              Text(
                'Add a cover image or video for your blog (Optional)',
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: ResponsiveHelper.spacing(context, 12)),
              GestureDetector(
                onTap: _showMediaPickerOptions,
                child: Container(
                  height: mediaPreviewHeight,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
                    border: Border.all(
                      color: AppTheme.iconscolor.withOpacity(0.2),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: selectedMedia == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate_rounded,
                              size: ResponsiveHelper.iconSize(context, mobile: 56, tablet: 64, desktop: 72),
                              color: AppTheme.iconscolor,
                            ),
                            SizedBox(height: ResponsiveHelper.spacing(context, 12)),
                            Text(
                              'Tap to select media',
                              style: ResponsiveHelper.textStyle(
                                context,
                                fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 17, desktop: 18),
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: ResponsiveHelper.spacing(context, 4)),
                            Text(
                              'JPG, PNG, GIF, MP4, MOV, WEBM (Max 5MB)',
                              style: ResponsiveHelper.textStyle(
                                context,
                                fontSize: ResponsiveHelper.fontSize(context, mobile: 12, tablet: 13, desktop: 14),
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        )
                      : Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
                              child: selectedMediaIsVideo
                                  ? _isPreviewInitialized && _previewController != null
                                      ? GestureDetector(
                                          onTap: () async {
                                            if (_previewController == null) return;
                                            if (_previewController!.value.isPlaying) {
                                              await _previewController!.pause();
                                            } else {
                                              await _previewController!.play();
                                            }
                                          },
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              SizedBox(
                                                width: double.infinity,
                                                height: double.infinity,
                                                child: AspectRatio(
                                                  aspectRatio: _previewController!.value.aspectRatio,
                                                  child: VideoPlayer(_previewController!),
                                                ),
                                              ),
                                              if (!_isPreviewPlaying)
                                                Container(
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
                                        )
                                      : Container(
                                          color: Colors.black,
                                          child: const Center(
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                            ),
                                          ),
                                        )
                                  : Image.file(
                                      selectedMedia!,
                                      fit: BoxFit.contain,
                                      width: double.infinity,
                                      height: double.infinity,
                                    ),
                            ),
                            Positioned(
                              top: ResponsiveHelper.spacing(context, 8),
                              right: ResponsiveHelper.spacing(context, 8),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    Icons.close_rounded,
                                    color: Colors.white,
                                    size: ResponsiveHelper.iconSize(context, mobile: 20),
                                  ),
                                  onPressed: _removeMedia,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              SizedBox(height: ResponsiveHelper.spacing(context, 32)),

              // Title Section
              Text(
                'Title *',
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: ResponsiveHelper.fontSize(context, mobile: 18, tablet: 19, desktop: 20),
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              SizedBox(height: ResponsiveHelper.spacing(context, 8)),
              TextField(
                controller: titleController,
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 17, desktop: 18),
                  color: AppTheme.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Enter a compelling title for your blog',
                  hintStyle: ResponsiveHelper.textStyle(
                    context,
                    fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                    color: Colors.grey[500],
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                    borderSide: BorderSide(color: Colors.grey.withOpacity(0.3), width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                    borderSide: BorderSide(color: Colors.grey.withOpacity(0.3), width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                    borderSide: BorderSide(color: AppTheme.iconscolor, width: 2.5),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: ResponsiveHelper.padding(context, all: 16),
                ),
                maxLength: 200,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  // Dismiss keyboard when Done is pressed
                  FocusManager.instance.primaryFocus?.unfocus();
                },
              ),
              SizedBox(height: ResponsiveHelper.spacing(context, 24)),

              // Category and Language Row
              Row(
                children: [
                  // Category
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Category *',
                          style: ResponsiveHelper.textStyle(
                            context,
                            fontSize: ResponsiveHelper.fontSize(context, mobile: 18, tablet: 19, desktop: 20),
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        SizedBox(height: ResponsiveHelper.spacing(context, 8)),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                            border: Border.all(
                              color: Colors.grey.withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: selectedCategory,
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              contentPadding: ResponsiveHelper.padding(context, horizontal: 16, vertical: 12),
                            ),
                            style: ResponsiveHelper.textStyle(
                              context,
                              fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 17, desktop: 18),
                              color: AppTheme.textPrimary,
                            ),
                            items: ['Spiritual', 'Encouragement', 'Testimony', 'Teaching', 'Others']
                                .map((cat) => DropdownMenuItem(
                                      value: cat,
                                      child: Text(cat),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedCategory = value!;
                              });
                            },
                          ),
                        ),
                        // Show custom category text field when 'Others' is selected
                        if (selectedCategory == 'Others') ...[
                          SizedBox(height: ResponsiveHelper.spacing(context, 12)),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                              border: Border.all(
                                color: Colors.grey.withOpacity(0.3),
                                width: 1.5,
                              ),
                            ),
                            child: TextField(
                              controller: customCategoryController,
                              decoration: InputDecoration(
                                hintText: 'Enter custom category',
                                hintStyle: ResponsiveHelper.textStyle(
                                  context,
                                  fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 17, desktop: 18),
                                  color: Colors.grey,
                                ),
                                border: InputBorder.none,
                                contentPadding: ResponsiveHelper.padding(context, horizontal: 16, vertical: 12),
                              ),
                              style: ResponsiveHelper.textStyle(
                                context,
                                fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 17, desktop: 18),
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(width: ResponsiveHelper.spacing(context, 16)),
                  // Language
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Language *',
                          style: ResponsiveHelper.textStyle(
                            context,
                            fontSize: ResponsiveHelper.fontSize(context, mobile: 18, tablet: 19, desktop: 20),
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        SizedBox(height: ResponsiveHelper.spacing(context, 8)),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                            border: Border.all(
                              color: Colors.grey.withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: selectedLanguage,
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              contentPadding: ResponsiveHelper.padding(context, horizontal: 16, vertical: 12),
                            ),
                            style: ResponsiveHelper.textStyle(
                              context,
                              fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 17, desktop: 18),
                              color: AppTheme.textPrimary,
                            ),
                            items: [
                              DropdownMenuItem(value: 'en', child: Text('English')),
                              DropdownMenuItem(value: 'es', child: Text('Spanish')),
                              DropdownMenuItem(value: 'fr', child: Text('French')),
                              DropdownMenuItem(value: 'hi', child: Text('Hindi')),
                              DropdownMenuItem(value: 'ar', child: Text('Arabic')),
                            ],
                            onChanged: (value) {
                              setState(() {
                                selectedLanguage = value!;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: ResponsiveHelper.spacing(context, 24)),

              // Content Section
              Text(
                'Content *',
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: ResponsiveHelper.fontSize(context, mobile: 18, tablet: 19, desktop: 20),
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              SizedBox(height: ResponsiveHelper.spacing(context, 8)),
              Text(
                'Write your blog content (Minimum 50 characters)',
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: ResponsiveHelper.spacing(context, 12)),
              TextField(
                controller: bodyController,
                maxLines: 12,
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 17, desktop: 18),
                  color: AppTheme.textPrimary,
                  height: 1.6,
                ),
                decoration: InputDecoration(
                  hintText: 'Share your thoughts, experiences, and insights...',
                  hintStyle: ResponsiveHelper.textStyle(
                    context,
                    fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                    color: Colors.grey[500],
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                    borderSide: BorderSide(color: Colors.grey.withOpacity(0.3), width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                    borderSide: BorderSide(color: Colors.grey.withOpacity(0.3), width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                    borderSide: BorderSide(color: AppTheme.iconscolor, width: 2.5),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: ResponsiveHelper.padding(context, all: 16),
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  // Dismiss keyboard when Done is pressed
                  FocusManager.instance.primaryFocus?.unfocus();
                },
              ),
              SizedBox(height: ResponsiveHelper.spacing(context, 8)),
              if (bodyController.text.trim().length < 50)
                Text(
                  'Minimum 50 characters required',
                  style: ResponsiveHelper.textStyle(
                    context,
                    fontSize: ResponsiveHelper.fontSize(context, mobile: 12, tablet: 13, desktop: 14),
                    color: AppTheme.iconscolor, // Changed to theme color for suggestion
                  ),
                ),
              SizedBox(height: ResponsiveHelper.spacing(context, 32)),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: ResponsiveHelper.buttonHeight(context, mobile: 56, tablet: 60, desktop: 64),
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitBlog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.iconscolor,
                    elevation: 6,
                    shadowColor: AppTheme.iconscolor.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
                    ),
                  ),
                  child: _isSubmitting
                      ? SizedBox(
                          height: ResponsiveHelper.iconSize(context, mobile: 24),
                          width: ResponsiveHelper.iconSize(context, mobile: 24),
                          child: const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.publish_rounded,
                              color: Colors.white,
                              size: ResponsiveHelper.iconSize(context, mobile: 22, tablet: 24, desktop: 26),
                            ),
                            SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                            Text(
                              'Publish Blog',
                              style: ResponsiveHelper.textStyle(
                                context,
                                fontSize: ResponsiveHelper.fontSize(context, mobile: 18, tablet: 19, desktop: 20),
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              SizedBox(height: ResponsiveHelper.spacing(context, 16)),
              Center(
                child: Text(
                  'Your blog will be reviewed by admin before publishing',
                  textAlign: TextAlign.center,
                  style: ResponsiveHelper.textStyle(
                    context,
                    fontSize: ResponsiveHelper.fontSize(context, mobile: 12, tablet: 13, desktop: 14),
                    color: Colors.grey[600],
                  ).copyWith(fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
