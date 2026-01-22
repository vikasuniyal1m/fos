import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fruitsofspirit/controllers/gallery_controller.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';
import 'package:fruitsofspirit/widgets/cached_image.dart';
import 'package:fruitsofspirit/config/image_config.dart';
import 'package:fruitsofspirit/utils/permission_manager.dart';
import 'package:fruitsofspirit/utils/app_theme.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../controllers/main_dashboard_controller.dart';
import '../routes/app_pages.dart';
import '../services/terms_service.dart';
import '../services/user_storage.dart' as us;
import 'terms_acceptance_screen.dart';

/// New Moment Screen - Social Media Style
/// Upload photo with Fruit tags, feeling tags, hashtags, and testimony
class UploadPhotoScreen extends StatefulWidget {
  const UploadPhotoScreen({Key? key}) : super(key: key);

  @override
  State<UploadPhotoScreen> createState() => _UploadPhotoScreenState();
}

class _UploadPhotoScreenState extends State<UploadPhotoScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _selectedPhoto;
  String? _selectedFruitTag;
  final List<String> _selectedFeelingTags = [];
  final List<String> _hashtags = [];
  final TextEditingController _testimonyController = TextEditingController();
  final TextEditingController _hashtagController = TextEditingController();
  bool _allowComments = true;
  bool _isDraft = false;

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

  // Feeling tags with icons
  final List<Map<String, dynamic>> _feelingTags = [
    {'name': 'Thankful', 'icon': Icons.favorite, 'color': Colors.red},
    {'name': 'At Peace', 'icon': Icons.wb_sunny, 'color': Colors.orange},
    {'name': 'Overflowing', 'icon': Icons.favorite, 'color': Colors.pink},
    {'name': 'Grateful', 'icon': Icons.celebration, 'color': Colors.amber},
    {'name': 'Blessed', 'icon': Icons.star, 'color': Colors.yellow},
    {'name': 'Hopeful', 'icon': Icons.lightbulb, 'color': Colors.blue},
  ];

  @override
  void dispose() {
    _testimonyController.dispose();
    _hashtagController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedPhoto = File(image.path);
      });
    }
  }

  Future<void> _takePhoto() async {
    try {
      // Request camera permission first
      final hasPermission = await PermissionManager.requestCameraPermission();
      if (!hasPermission) {
        Get.snackbar(
          'Permission Required',
          'Camera permission is required to take photos. Please enable it in settings.',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
        return;
      }

      // Check if camera is available (especially for iPad)
      if (!kIsWeb && !Platform.isAndroid && !Platform.isIOS) {
        Get.snackbar(
          'Not Supported',
          'Camera is not available on this device.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      // Use try-catch to handle camera errors gracefully
      final image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85, // Reduce quality for better performance
        preferredCameraDevice: CameraDevice.rear, // Prefer rear camera
      );
      
      if (image != null) {
        setState(() {
          _selectedPhoto = File(image.path);
        });
      }
    } catch (e) {
      // Handle camera errors gracefully
      print('Camera error: $e');
      Get.snackbar(
        'Camera Error',
        'Failed to open camera. Please try again or select from gallery.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
        mainButton: TextButton(
          onPressed: () {
            Get.back(); // Close snackbar
            _pickImage(); // Fallback to gallery
          },
          child: Text('Use Gallery', style: TextStyle(color: Colors.white)),
        ),
      );
    }
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 20)),
        ),
        title: Row(
          children: [
            Icon(
              Icons.add_photo_alternate_rounded,
              color: AppTheme.iconscolor,
              size: ResponsiveHelper.iconSize(context, mobile: 24),
            ),
            SizedBox(width: ResponsiveHelper.spacing(context, 8)),
            Text(
              'Select Image Source',
              style: ResponsiveHelper.textStyle(
                context,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.pop(context);
                  _pickImage();
                },
                borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                child: Container(
                  padding: ResponsiveHelper.padding(context, all: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                    border: Border.all(
                      color: Colors.grey.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: ResponsiveHelper.padding(context, all: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.iconscolor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                        ),
                        child: Icon(
                          Icons.photo_library_rounded,
                          color: AppTheme.iconscolor,
                          size: ResponsiveHelper.iconSize(context, mobile: 24),
                        ),
                      ),
                      SizedBox(width: ResponsiveHelper.spacing(context, 16)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Gallery',
                              style: ResponsiveHelper.textStyle(
                                context,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            SizedBox(height: ResponsiveHelper.spacing(context, 4)),
                            Text(
                              'Choose from your photos',
                              style: ResponsiveHelper.textStyle(
                                context,
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: ResponsiveHelper.iconSize(context, mobile: 16),
                        color: Colors.grey[400],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 12)),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  Navigator.pop(context);
                  await _takePhoto();
                },
                borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                child: Container(
                  padding: ResponsiveHelper.padding(context, all: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                    border: Border.all(
                      color: Colors.grey.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: ResponsiveHelper.padding(context, all: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF9F9467).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                        ),
                        child: Icon(
                          Icons.camera_alt_rounded,
                          color: AppTheme.iconscolor,
                          size: ResponsiveHelper.iconSize(context, mobile: 24),
                        ),
                      ),
                      SizedBox(width: ResponsiveHelper.spacing(context, 16)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Camera',
                              style: ResponsiveHelper.textStyle(
                                context,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            SizedBox(height: ResponsiveHelper.spacing(context, 4)),
                            Text(
                              'Take a new photo',
                              style: ResponsiveHelper.textStyle(
                                context,
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: ResponsiveHelper.iconSize(context, mobile: 16),
                        color: Colors.grey[400],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addHashtag() {
    final tag = _hashtagController.text.trim();
    if (tag.isNotEmpty && !_hashtags.contains(tag)) {
      setState(() {
        _hashtags.add(tag.startsWith('#') ? tag : '#$tag');
        _hashtagController.clear();
      });
    }
  }

  void _removeHashtag(String tag) {
    setState(() {
      _hashtags.remove(tag);
    });
  }

  Future<void> _submitMoment() async {
    // Check for terms acceptance
    final hasAcceptedFactors = await TermsService.hasAcceptedTerms();
    if (!hasAcceptedFactors) {
      Get.to(() => TermsAcceptanceScreen(
        onAccepted: () {
          Get.back(); // Pop the terms screen
          _submitMoment(); // Retry submission
        },
      ));
      return;
    }

    if (_selectedPhoto == null) {
      Get.snackbar(
        'Error',
        'Please select a photo',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
      return;
    }

    try {
      final controller = Get.isRegistered<GalleryController>() 
          ? Get.find<GalleryController>() 
          : Get.put(GalleryController());
      
      print('📸 Starting photo upload...');
      print('📸 User ID: ${controller.userId.value}');
      
      // Show loading
      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );
      
      final success = await controller.uploadPhoto(
        photoFile: _selectedPhoto!,
        fruitTag: _selectedFruitTag,
        testimony: _testimonyController.text.trim().isEmpty 
            ? null 
            : _testimonyController.text.trim(),
        feelingTags: _selectedFeelingTags.isEmpty ? null : _selectedFeelingTags.join(','),
        hashtags: _hashtags.isEmpty ? null : _hashtags.join(','),
        allowComments: _allowComments,
      );

      // Hide loading dialog
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      if (success) {
        // Show success message
        if (mounted) {
          Get.snackbar(
            'Success',
            controller.message.value.isNotEmpty 
                ? controller.message.value 
                : 'Photo uploaded successfully!',
            backgroundColor: Colors.green,
            colorText: Colors.white,
            duration: const Duration(seconds: 2),
            icon: const Icon(Icons.check_circle, color: Colors.white),
            margin: const EdgeInsets.all(16),
          );
        }
        
        // Navigate back to previous screen immediately
        if (mounted) {
          if (Get.isRegistered<MainDashboardController>()) {
            Get.find<MainDashboardController>().changeIndex(4);
          }
          Get.back();
        }
      } else {
        // Show error message
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              final errorMsg = controller.message.value;
              final isModeration = errorMsg.contains('community guidelines');

              Get.snackbar(
                isModeration ? 'Community Standard' : 'Notice',
                errorMsg.isNotEmpty 
                    ? errorMsg 
                    : 'Action could not be completed. Please try again.',
                backgroundColor: isModeration ? const Color(0xFF5D4037) : Colors.grey[800],
                colorText: Colors.white,
                icon: Icon(
                  isModeration ? Icons.security_rounded : Icons.info_outline,
                  color: isModeration ? const Color(0xFFC79211) : Colors.white,
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
    } catch (e) {
      // Hide loading if still showing
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
      
      Get.snackbar(
        'Error',
        'Failed to upload photo: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
        icon: const Icon(Icons.error, color: Colors.white),
      );
      print('Error in _submitMoment: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.themeColor,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(
          ResponsiveHelper.safeHeight(
            context,
            mobile: 70,
            tablet: 120,
            desktop: 90,
          ),
        ),
          child: Container(
          decoration: BoxDecoration(
            color: AppTheme.themeColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: ResponsiveHelper.isMobile(context) ? 4 : 8,
                offset: Offset(0, ResponsiveHelper.isMobile(context) ? 2 : 4),
              ),
            ],
            border: Border(
              bottom: BorderSide(
                color: AppTheme.primaryColor.withOpacity(0.15),
                width: ResponsiveHelper.isMobile(context) ? 0.5 : 1,
              ),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: ResponsiveHelper.padding(
                context,
                horizontal: ResponsiveHelper.isMobile(context)
                    ? ResponsiveHelper.spacing(context, 16)
                    : ResponsiveHelper.isTablet(context)
                        ? ResponsiveHelper.spacing(context, 24)
                        : ResponsiveHelper.spacing(context, 32),
                vertical: ResponsiveHelper.isMobile(context)
                    ? ResponsiveHelper.spacing(context, 12)
                    : ResponsiveHelper.isTablet(context)
                        ? ResponsiveHelper.spacing(context, 14)
                        : ResponsiveHelper.spacing(context, 16),
              ),
              child: Row(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Get.back(),
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.2),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          Icons.arrow_back_rounded,
                          color: AppTheme.primaryColor,
                          size: ResponsiveHelper.iconSize(context, mobile: 20),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: ResponsiveHelper.spacing(context, 16)),
                  Expanded(
                    child: Text(
                      'Share A Moment',
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: GetBuilder<GalleryController>(
        init: Get.isRegistered<GalleryController>() 
            ? Get.find<GalleryController>() 
            : Get.put(GalleryController()),
        builder: (controller) => SingleChildScrollView(
          padding: ResponsiveHelper.padding(context, all: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Preview Section - Enhanced
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 20)),
                  child: Stack(
                    children: [
                      // Image or placeholder
                      Container(
                        height: ResponsiveHelper.imageHeight(context, mobile: 320),
                        width: double.infinity,
                        color: Colors.grey[100],
                        child: _selectedPhoto != null
                            ? Image.file(
                                _selectedPhoto!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              )
                            : Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: ResponsiveHelper.padding(context, all: 24),
                                      decoration: BoxDecoration(
                                        color: AppTheme.iconscolor.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.add_photo_alternate_rounded,
                                        size: ResponsiveHelper.iconSize(context, mobile: 64),
                                        color: AppTheme.iconscolor,
                                      ),
                                    ),
                                    SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                                    Text(
                                      'Tap to select photo',
                                      style: ResponsiveHelper.textStyle(
                                        context,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                    SizedBox(height: ResponsiveHelper.spacing(context, 4)),
                                    Text(
                                      'Choose from gallery or take a new one',
                                      style: ResponsiveHelper.textStyle(
                                        context,
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                      // Overlay buttons
                      if (_selectedPhoto != null)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: ResponsiveHelper.padding(context, all: 16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.7),
                                ],
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: _showImageSourceDialog,
                                    borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                                    child: Container(
                                      padding: ResponsiveHelper.padding(context, horizontal: 16, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.9),
                                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.camera_alt_rounded,
                                            size: ResponsiveHelper.iconSize(context, mobile: 18),
                                            color: AppTheme.primaryColor,
                                          ),
                                          SizedBox(width: ResponsiveHelper.spacing(context, 6)),
                                          Text(
                                            'Change',
                                            style: ResponsiveHelper.textStyle(
                                              context,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.primaryColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      // TODO: Implement image editing
                                      Get.snackbar(
                                        'Info',
                                        'Edit feature coming soon',
                                        backgroundColor: Colors.blue,
                                        colorText: Colors.white,
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                                    child: Container(
                                      padding: ResponsiveHelper.padding(context, horizontal: 16, vertical: 10),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [AppTheme.iconscolor, AppTheme.primaryColor],
                                        ),
                                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.edit_rounded,
                                            size: ResponsiveHelper.iconSize(context, mobile: 18),
                                            color: Colors.white,
                                          ),
                                          SizedBox(width: ResponsiveHelper.spacing(context, 6)),
                                          Text(
                                            'Edit',
                                            style: ResponsiveHelper.textStyle(
                                              context,
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Positioned.fill(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _showImageSourceDialog,
                              borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 20)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: ResponsiveHelper.spacing(context, 24)),
              
              // Select Fruit of the Spirit Section - Enhanced
              Container(
                padding: ResponsiveHelper.padding(context, all: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
                  border: Border.all(
                    color: Colors.grey.withOpacity(0.1),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: ResponsiveHelper.padding(context, all: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.iconscolor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
                          ),
                          child: Icon(
                            Icons.local_fire_department_rounded,
                            size: ResponsiveHelper.iconSize(context, mobile: 20),
                            color: AppTheme.iconscolor,
                          ),
                        ),
                        SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                        Text(
                          'Select Fruit of the Spirit',
                          style: ResponsiveHelper.textStyle(
                            context,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                    SizedBox(
                      height: 40,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _fruitsOfSpirit.length,
                        itemBuilder: (context, index) {
                          final fruit = _fruitsOfSpirit[index];
                          final isSelected = _selectedFruitTag == fruit;
                          return Padding(
                            padding: EdgeInsets.only(
                              right: ResponsiveHelper.spacing(context, 8),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedFruitTag = isSelected ? null : fruit;
                                  });
                                },
                                borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 20)),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: ResponsiveHelper.padding(context, horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    gradient: isSelected
                                        ? LinearGradient(
                                            colors: [AppTheme.iconscolor, AppTheme.primaryColor],
                                          )
                                        : null,
                                    color: isSelected ? null : Colors.white,
                                    borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 20)),
                                    border: Border.all(
                                      color: isSelected 
                                          ? Colors.transparent
                                          : AppTheme.primaryColor.withOpacity(0.3),
                                      width: isSelected ? 0 : 1.5,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: AppTheme.iconscolor.withOpacity(0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Text(
                                    fruit,
                                    style: ResponsiveHelper.textStyle(
                                      context,
                                      fontSize: 13,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: isSelected ? Colors.white : AppTheme.primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: ResponsiveHelper.spacing(context, 20)),
              
              // Testimony/Moment Text Input - Enhanced
              Container(
                padding: ResponsiveHelper.padding(context, all: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
                  border: Border.all(
                    color: Colors.grey.withOpacity(0.1),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: ResponsiveHelper.padding(context, all: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.iconscolor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
                          ),
                          child: Icon(
                            Icons.edit_note_rounded,
                            size: ResponsiveHelper.iconSize(context, mobile: 20),
                            color: AppTheme.iconscolor,
                          ),
                        ),
                        SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                        Text(
                          'Share Your Testimony',
                          style: ResponsiveHelper.textStyle(
                            context,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(context, 12)),
                    TextField(
                      controller: _testimonyController,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: 'Write a short testimony behind this image...',
                        hintStyle: ResponsiveHelper.textStyle(
                          context,
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: ResponsiveHelper.padding(context, all: 16),
                      ),
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: 14,
                        color: const Color(0xFF5F4628),
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: ResponsiveHelper.spacing(context, 20)),
              
              // How are you feeling right now? Section - Enhanced
              Container(
                padding: ResponsiveHelper.padding(context, all: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
                  border: Border.all(
                    color: Colors.grey.withOpacity(0.1),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: ResponsiveHelper.padding(context, all: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.iconscolor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
                          ),
                          child: Icon(
                            Icons.mood_rounded,
                            size: ResponsiveHelper.iconSize(context, mobile: 20),
                            color: AppTheme.iconscolor,
                          ),
                        ),
                        SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                        Text(
                          'How are you feeling?',
                          style: ResponsiveHelper.textStyle(
                            context,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                    SizedBox(
                      height: 50,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _feelingTags.length,
                        itemBuilder: (context, index) {
                          final feeling = _feelingTags[index];
                          final isSelected = _selectedFeelingTags.contains(feeling['name']);
                          return Padding(
                            padding: EdgeInsets.only(
                              right: ResponsiveHelper.spacing(context, 8),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    if (isSelected) {
                                      _selectedFeelingTags.remove(feeling['name']);
                                    } else {
                                      _selectedFeelingTags.add(feeling['name']);
                                    }
                                  });
                                },
                                borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 20)),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: ResponsiveHelper.padding(context, horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected 
                                        ? (feeling['color'] as Color).withOpacity(0.15)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 20)),
                                    border: Border.all(
                                      color: isSelected 
                                          ? feeling['color'] as Color
                                          : AppTheme.primaryColor.withOpacity(0.3),
                                      width: isSelected ? 2 : 1.5,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: (feeling['color'] as Color).withOpacity(0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        feeling['icon'] as IconData,
                                        size: ResponsiveHelper.iconSize(context, mobile: 18),
                                        color: isSelected 
                                            ? feeling['color'] as Color
                                            : AppTheme.primaryColor,
                                      ),
                                      SizedBox(width: ResponsiveHelper.spacing(context, 6)),
                                      Text(
                                        feeling['name'],
                                        style: ResponsiveHelper.textStyle(
                                          context,
                                          fontSize: 13,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          color: isSelected 
                                              ? feeling['color'] as Color
                                              : AppTheme.primaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: ResponsiveHelper.spacing(context, 20)),
              
              // Allow comments checkbox - Enhanced
              Container(
                padding: ResponsiveHelper.padding(context, all: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
                  border: Border.all(
                    color: Colors.grey.withOpacity(0.1),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: ResponsiveHelper.padding(context, all: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.iconscolor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
                      ),
                      child: Icon(
                        Icons.comment_rounded,
                        size: ResponsiveHelper.iconSize(context, mobile: 20),
                        color: AppTheme.iconscolor,
                      ),
                    ),
                    SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                    Expanded(
                      child: Text(
                        'Allow comments',
                        style: ResponsiveHelper.textStyle(
                          context,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    Switch(
                      value: _allowComments,
                      onChanged: (value) {
                        setState(() {
                          _allowComments = value;
                        });
                      },
                      activeColor: AppTheme.iconscolor,
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: ResponsiveHelper.spacing(context, 20)),
              
              // Add hashtags Section - Enhanced
              Container(
                padding: ResponsiveHelper.padding(context, all: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
                  border: Border.all(
                    color: Colors.grey.withOpacity(0.1),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: ResponsiveHelper.padding(context, all: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.iconscolor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
                          ),
                          child: Icon(
                            Icons.tag_rounded,
                            size: ResponsiveHelper.iconSize(context, mobile: 20),
                            color: AppTheme.iconscolor,
                          ),
                        ),
                        SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                        Text(
                          'Add Hashtags',
                          style: ResponsiveHelper.textStyle(
                            context,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(context, 12)),
                    TextField(
                      controller: _hashtagController,
                      decoration: InputDecoration(
                        hintText: 'Type hashtag and press Enter',
                        hintStyle: ResponsiveHelper.textStyle(
                          context,
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: ResponsiveHelper.padding(context, all: 16),
                        suffixIcon: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _addHashtag,
                            borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                            child: Container(
                              margin: ResponsiveHelper.padding(context, all: 8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [AppTheme.iconscolor, AppTheme.primaryColor],
                                ),
                                borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
                              ),
                              child: Icon(
                                Icons.add_rounded,
                                color: Colors.white,
                                size: ResponsiveHelper.iconSize(context, mobile: 20),
                              ),
                            ),
                          ),
                        ),
                      ),
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: 14,
                        color: AppTheme.primaryColor,
                      ),
                      onSubmitted: (_) => _addHashtag(),
                    ),
                    
                    // Display hashtags
                    if (_hashtags.isNotEmpty) ...[
                      SizedBox(height: ResponsiveHelper.spacing(context, 12)),
                      Wrap(
                        spacing: ResponsiveHelper.spacing(context, 8),
                        runSpacing: ResponsiveHelper.spacing(context, 8),
                        children: _hashtags.map((tag) {
                          return Chip(
                            label: Text(tag),
                            onDeleted: () => _removeHashtag(tag),
                            backgroundColor: AppTheme.iconscolor.withOpacity(0.1),
                            deleteIconColor: AppTheme.primaryColor,
                            labelStyle: ResponsiveHelper.textStyle(
                              context,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.iconscolor,
                            ),
                            side: BorderSide(
                              color: AppTheme.iconscolor.withOpacity(0.3),
                              width: 1,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              
              SizedBox(height: ResponsiveHelper.spacing(context, 24)),
              
              // Post Moment Button - Enhanced
              SizedBox(
                width: double.infinity,
                height: ResponsiveHelper.buttonHeight(context, mobile: 56),
                child: Builder(
                  builder: (context) {
                    try {
                      final galleryController = Get.find<GalleryController>();
                      return Obx(() {
                        return ElevatedButton(
                        onPressed: (galleryController.isLoading.value || _selectedPhoto == null) 
                            ? null 
                            : _submitMoment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: (_selectedPhoto == null) 
                              ? Colors.grey[400]
                              : AppTheme.iconscolor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
                          ),
                          elevation: 4,
                          shadowColor: AppTheme.iconscolor.withOpacity(0.4),
                        ),
                        child: galleryController.isLoading.value
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.cloud_upload_rounded,
                                    color: Colors.white,
                                    size: ResponsiveHelper.iconSize(context, mobile: 24),
                                  ),
                                  SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                                  Text(
                                    'Post Moment',
                                    style: ResponsiveHelper.textStyle(
                                      context,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                        );
                      });
                    } catch (e) {
                      // GalleryController not found, create it
                      final galleryController = Get.put(GalleryController());
                      return Obx(() {
                        return ElevatedButton(
                          onPressed: (_selectedPhoto == null) ? null : _submitMoment,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: (_selectedPhoto == null) 
                                ? Colors.grey[400]
                                : AppTheme.iconscolor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
                            ),
                          ),
                          child: galleryController.isLoading.value
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.cloud_upload_rounded,
                                      color: Colors.white,
                                      size: ResponsiveHelper.iconSize(context, mobile: 24),
                                    ),
                                    SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                                    Text(
                                      'Post Moment',
                                      style: ResponsiveHelper.textStyle(
                                        context,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                        );
                      });
                    }
                  },
                ),
              ),
              
              SizedBox(height: ResponsiveHelper.spacing(context, 12)),
              
              // Save as Draft Button - Enhanced
              SizedBox(
                width: double.infinity,
                height: ResponsiveHelper.buttonHeight(context, mobile: 50),
                child: OutlinedButton(
                  onPressed: () {
                    Get.snackbar(
                      'Info',
                      'Draft feature coming soon',
                      backgroundColor: Colors.blue,
                      colorText: Colors.white,
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: AppTheme.iconscolor,
                      width: 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.bookmark_border_rounded,
                        color: AppTheme.iconscolor,
                        size: ResponsiveHelper.iconSize(context, mobile: 20),
                      ),
                      SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                      Text(
                        'Save as Draft',
                        style: ResponsiveHelper.textStyle(
                          context,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.iconscolor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: ResponsiveHelper.spacing(context, 40)),
            ],
          ),
        ),
      ),
    );
  }
}
