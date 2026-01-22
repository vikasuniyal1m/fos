import 'package:fruitsofspirit/routes/routes.dart';
import 'package:image_cropper/image_cropper.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
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
  
  File? selectedImage;
  String selectedCategory = 'Spiritual';
  String selectedLanguage = 'en';
  
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
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Image',
            toolbarColor: AppTheme.iconscolor,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false, // Allow free cropping
            hideBottomControls: false,
            statusBarColor: AppTheme.iconscolor, // Match status bar color
            activeControlsWidgetColor: AppTheme.iconscolor,
            aspectRatioPresets: [
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio3x2,
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.ratio16x9,
              CropAspectRatioPreset.original,
            ],
          ),
          IOSUiSettings(
            title: 'Crop Image',
            aspectRatioLockEnabled: false, // Allow free cropping
            doneButtonTitle: 'Done',
            cancelButtonTitle: 'Cancel',
            minimumAspectRatio: 1.0,
            aspectRatioPresets: [
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio3x2,
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.ratio16x9,
              CropAspectRatioPreset.original,
            ],
          ),
        ],
      );

      if (croppedFile != null) {
        setState(() {
          selectedImage = File(croppedFile.path);
        });
      }
    }
  }

  void _removeImage() {
    setState(() {
      selectedImage = null;
    });
  }

  Future<void> _submitBlog() async {
    print('[_submitBlog] function called.');

    // Check for terms acceptance
    final hasAcceptedFactors = await TermsService.hasAcceptedTerms();
    if (!hasAcceptedFactors) {
      Get.to(() => TermsAcceptanceScreen(
        onAccepted: () {
          Get.back(); // Pop the terms screen
          _submitBlog(); // Retry submission
        },
      ));
      return;
    }
    // Validation
    if (titleController.text.trim().isEmpty) {
      Get.snackbar(
        'Suggestion',
        'Please enter blog title',
        backgroundColor: Colors.orange.shade300,
        colorText: Colors.black,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (bodyController.text.trim().isEmpty) {
      Get.snackbar(
        'Suggestion',
        'Please enter blog content',
        backgroundColor: Colors.orange.shade300,
        colorText: Colors.black,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (bodyController.text.trim().length < 50) {
      Get.snackbar(
        'Suggestion',
        'Blog content must be at least 50 characters long.',
        backgroundColor: Colors.orange.shade300,
        colorText: Colors.black,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final success = await controller.createBlog(
      title: titleController.text.trim(),
      body: bodyController.text.trim(),
      category: selectedCategory,
      language: selectedLanguage,
      image: selectedImage,
    );

    if (success) {
      print('Blog creation successful. Mounted: $mounted');
      // Show success message FIRST (before navigation)
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          print('Inside addPostFrameCallback. Mounted: $mounted');
          if (mounted) {
            Get.snackbar(
              'Success',
              controller.message.value.isNotEmpty
                  ? controller.message.value
                  : 'Blog created successfully!',
              backgroundColor: Colors.green,
              colorText: Colors.white,
              snackPosition: SnackPosition.BOTTOM,
              duration: const Duration(seconds: 2),
              margin: const EdgeInsets.all(16),
            );
            // Navigate back after snackbar is shown (GetX navigation)
            if (Get.isRegistered<MainDashboardController>()) {
              Get.find<MainDashboardController>().changeIndex(0);
              Get.back();
            } else {
              Get.offAllNamed(Routes.DASHBOARD);
            }
          }
        });
      }
    } else {
      print('Blog creation failed.');
      // Show error message
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            final errorMsg = controller.message.value;
            final isModeration = errorMsg.contains('community guidelines');

            Get.snackbar(
              isModeration ? 'Community Standard' : 'Community Suggestion',
              errorMsg.isNotEmpty 
                  ? errorMsg 
                  : 'Action could not be completed. Please try again.',
              backgroundColor: isModeration ? const Color(0xFF5D4037) : Colors.orange.shade300,
              colorText: isModeration ? Colors.white : Colors.black,
              icon: Icon(
                isModeration ? Icons.security_rounded : Icons.tips_and_updates_outlined,
                color: isModeration ? const Color(0xFFC79211) : Colors.black,
                size: 28,
              ),
              snackPosition: SnackPosition.BOTTOM,
              duration: Duration(seconds: isModeration ? 5 : 3),
              margin: const EdgeInsets.all(16),
              borderRadius: 12,
              mainButton: isModeration ? TextButton(
                onPressed: () => Get.toNamed(Routes.TERMS),
                child: const Text('VIEW TERMS', style: TextStyle(color: Color(0xFFC79211), fontWeight: FontWeight.bold)),
              ) : null,
            );
          }
        });
      }
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

        return SingleChildScrollView(
          padding: ResponsiveHelper.padding(context, all: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Selection Section
              Text(
                'Blog Image',
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: ResponsiveHelper.fontSize(context, mobile: 18, tablet: 19, desktop: 20),
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              SizedBox(height: ResponsiveHelper.spacing(context, 8)),
              Text(
                'Add a cover image for your blog (Optional)',
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: ResponsiveHelper.spacing(context, 12)),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: ResponsiveHelper.imageHeight(context, mobile: 220, tablet: 250, desktop: 280),
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
                  child: selectedImage == null
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
                              'Tap to select image',
                              style: ResponsiveHelper.textStyle(
                                context,
                                fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 17, desktop: 18),
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: ResponsiveHelper.spacing(context, 4)),
                            Text(
                              'JPG, PNG, GIF (Max 5MB)',
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
                              child: Image.file(
                                selectedImage!,
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
                                  onPressed: _removeImage,
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
                            items: ['Spiritual', 'Encouragement', 'Testimony', 'Teaching', 'Other']
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
                  onPressed: controller.isLoading.value ? null : _submitBlog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.iconscolor,
                    elevation: 6,
                    shadowColor: AppTheme.iconscolor.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
                    ),
                  ),
                  child: controller.isLoading.value
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
