import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fruitsofspirit/controllers/profile_controller.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';
import 'package:fruitsofspirit/routes/routes.dart';
import 'package:fruitsofspirit/widgets/cached_image.dart';
import 'package:fruitsofspirit/widgets/app_bottom_navigation_bar.dart';
import 'package:fruitsofspirit/utils/localization_helper.dart';
import 'package:fruitsofspirit/config/image_config.dart';
import 'package:fruitsofspirit/utils/app_theme.dart';
import 'package:fruitsofspirit/widgets/standard_app_bar.dart';

/// Edit Profile Screen
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final ProfileController controller = Get.find<ProfileController>();
  late TextEditingController usernameController;
  late TextEditingController emailController;
  late TextEditingController phoneController;
  late TextEditingController passwordController;
  File? selectedImage;
  bool _controllersInitialized = false;

  @override
  void initState() {
    super.initState();
    // Initialize controllers with empty values, will be updated when profile loads
    usernameController = TextEditingController();
    emailController = TextEditingController();
    phoneController = TextEditingController();
    passwordController = TextEditingController();
    
    // Load profile if not already loaded
    if (controller.profile.isEmpty) {
      controller.loadProfile().then((_) {
        _updateControllers();
      });
    } else {
      _updateControllers();
    }
  }

  void _updateControllers() {
    if (!mounted) return;
    
    final name = controller.profile['name'] as String? ?? '';
    final email = controller.profile['email'] as String? ?? '';
    final phone = controller.profile['phone'] as String? ?? '';
    
    usernameController.text = name;
    emailController.text = email;
    phoneController.text = phone;
    passwordController.clear(); // Password field should be empty for security
    
    setState(() {
      _controllersInitialized = true;
    });
  }

  @override
  void dispose() {
    usernameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.themeColor,
      appBar: const StandardAppBar(
        showBackButton: false,
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.profile.isEmpty) {
          return Center(
            child: CircularProgressIndicator(
              color: AppTheme.iconscolor,
            ),
          );
        }

        // Update controllers when profile data changes
        if (!_controllersInitialized && controller.profile.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _updateControllers();
          });
        }

        return _buildEditProfileContent(context);
      }),
      extendBodyBehindAppBar: false,
    );
  }

  Widget _buildEditProfileContent(BuildContext context) {
    // Get data from controller (from database)
    final profilePhoto = controller.profile['profile_photo'] as String?;
    
    return StatefulBuilder(
      builder: (context, setState) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Main scrollable content
            SingleChildScrollView(
              child: Column(
                children: [
                  // Header section at top (with space for avatar)
                  Container(
                    height: ResponsiveHelper.isMobile(context) 
                        ? 180 
                        : ResponsiveHelper.isTablet(context) 
                            ? 200 
                            : 220, // More space for larger avatar
                    color: AppTheme.iconscolor,
                  ),
                  // Content section
                  Container(
                    color: AppTheme.themeColor,
                    padding: ResponsiveHelper.padding(context, top: 80, left: 16, right: 16, bottom: 16), // Responsive padding
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // "Change Picture" text - positioned below profile picture
                        Center(
                          child: GestureDetector(
                            onTap: () async {
                              final picker = ImagePicker();
                              final image = await picker.pickImage(source: ImageSource.gallery);
                              if (image != null) {
                                setState(() {
                                  selectedImage = File(image.path);
                                });
                              }
                            },
                            child: Padding(
                              padding: EdgeInsets.only(top: 0), // Removed top padding since avatar is fixed
                              child: Text(
                                'Change Picture',
                                style: ResponsiveHelper.textStyle(
                                  context,
                                  fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 17, desktop: 18),
                                  color: Colors.black,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: ResponsiveHelper.spacing(context, 16)), // Responsive spacing
              
              // Username Field
              Text(
                'Username',
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 17, desktop: 18),
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: ResponsiveHelper.spacing(context, 8)),
              TextField(
                controller: usernameController,
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 17, desktop: 18),
                  color: Colors.black87,
                ),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 6)),
                    borderSide: BorderSide(color: Colors.grey.withOpacity(0.2), width: 1),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 6)),
                    borderSide: BorderSide(color: Colors.grey.withOpacity(0.2), width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 6)),
                    borderSide: BorderSide(color: AppTheme.iconscolor, width: 1.5),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: ResponsiveHelper.padding(context, horizontal: 16, vertical: 14),
                ),
              ),
              SizedBox(height: ResponsiveHelper.spacing(context, 16)),
              
              // Email I'd Field
              Text(
                'Email I\'d',
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 17, desktop: 18),
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: ResponsiveHelper.spacing(context, 8)),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 17, desktop: 18),
                  color: Colors.black87,
                ),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 6)),
                    borderSide: BorderSide(color: Colors.grey.withOpacity(0.2), width: 1),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 6)),
                    borderSide: BorderSide(color: Colors.grey.withOpacity(0.2), width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 6)),
                    borderSide: BorderSide(color: AppTheme.iconscolor, width: 1.5),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: ResponsiveHelper.padding(context, horizontal: 16, vertical: 14),
                ),
              ),
              SizedBox(height: ResponsiveHelper.spacing(context, 16)),
              
              // Phone Number Field
              Text(
                'Phone Number',
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 17, desktop: 18),
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: ResponsiveHelper.spacing(context, 8)),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 17, desktop: 18),
                  color: Colors.black87,
                ),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 6)),
                    borderSide: BorderSide(color: Colors.grey.withOpacity(0.2), width: 1),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 6)),
                    borderSide: BorderSide(color: Colors.grey.withOpacity(0.2), width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 6)),
                    borderSide: BorderSide(color: AppTheme.iconscolor, width: 1.5),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: ResponsiveHelper.padding(context, horizontal: 16, vertical: 14),
                ),
              ),
              SizedBox(height: ResponsiveHelper.spacing(context, 16)),
              
              // Password Field
              Text(
                'Password',
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 17, desktop: 18),
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: ResponsiveHelper.spacing(context, 8)),
              TextField(
                controller: passwordController,
                obscureText: true,
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 17, desktop: 18),
                  color: Colors.black87,
                ),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 6)),
                    borderSide: BorderSide(color: Colors.grey.withOpacity(0.2), width: 1),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 6)),
                    borderSide: BorderSide(color: Colors.grey.withOpacity(0.2), width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 6)),
                    borderSide: BorderSide(color: AppTheme.iconscolor, width: 1.5),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: ResponsiveHelper.padding(context, horizontal: 16, vertical: 14),
                ),
              ),
              SizedBox(height: ResponsiveHelper.spacing(context, 32)),
              
              // Update Button
              SizedBox(
                width: double.infinity,
                height: ResponsiveHelper.buttonHeight(context, mobile: 50, tablet: 55, desktop: 60),
                child: ElevatedButton(
                  onPressed: controller.isLoading.value
                      ? null
                      : () async {
                          final success = await controller.updateProfile(
                            name: usernameController.text.trim().isEmpty
                                ? null
                                : usernameController.text.trim(),
                            email: emailController.text.trim().isEmpty
                                ? null
                                : emailController.text.trim(),
                            phone: phoneController.text.trim().isEmpty
                                ? null
                                : phoneController.text.trim(),
                            password: passwordController.text.trim().isEmpty
                                ? null
                                : passwordController.text.trim(),
                            profilePhoto: selectedImage,
                          );

                          if (success) {
                            // Show success message FIRST (before navigation)
                            if (mounted) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) {
                                  Get.snackbar(
                                    'Success',
                                    controller.message.value.isNotEmpty 
                                        ? controller.message.value 
                                        : 'Profile updated successfully!',
                                    backgroundColor: Colors.green,
                                    colorText: Colors.white,
                                    duration: const Duration(seconds: 2),
                                    margin: const EdgeInsets.all(16),
                                  );
                                }
                              });
                            }
                            
                            // Wait a bit for snackbar to show, then navigate
                            await Future.delayed(const Duration(milliseconds: 500));
                            
                            // Navigate back
                            if (mounted && Navigator.canPop(context)) {
                              Get.back();
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
                                        : 'Failed to update profile. Please try again.',
                                    backgroundColor: Colors.red,
                                    colorText: Colors.white,
                                    duration: const Duration(seconds: 3),
                                    margin: const EdgeInsets.all(16),
                                  );
                                }
                              });
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.iconscolor,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shadowColor: AppTheme.iconscolor.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: controller.isLoading.value
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.save_rounded,
                              color: Colors.white,
                              size: ResponsiveHelper.iconSize(context, mobile: 20, tablet: 22, desktop: 24),
                            ),
                            SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                            Text(
                              'Update',
                              style: ResponsiveHelper.textStyle(
                                context,
                                fontSize: ResponsiveHelper.fontSize(context, mobile: 18, tablet: 20, desktop: 22),
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              
              SizedBox(height: ResponsiveHelper.spacing(context, 16)),
              
              // Delete Account Button
              SizedBox(
                width: double.infinity,
                height: ResponsiveHelper.buttonHeight(context, mobile: 50, tablet: 55, desktop: 60),
                child: ElevatedButton(
                  onPressed: controller.isLoading.value
                      ? null
                      : () async {
                          // Show confirmation dialog
                          final confirm = await Get.dialog<bool>(
                            AlertDialog(
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              title: Row(
                                children: [
                                  Icon(
                                    Icons.warning_rounded,
                                    color: Colors.red,
                                    size: ResponsiveHelper.iconSize(context, mobile: 24, tablet: 26, desktop: 28),
                                  ),
                                  SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                                  const Text(
                                    'Delete Account',
                                    style: TextStyle(color: Colors.black),
                                  ),
                                ],
                              ),
                              content: const Text(
                                'Are you sure you want to delete your account? This action cannot be undone.',
                                style: TextStyle(color: Colors.black87),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Get.back(result: false),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.black87,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.cancel_outlined,
                                        size: ResponsiveHelper.iconSize(context, mobile: 18, tablet: 20, desktop: 22),
                                      ),
                                      SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                                      const Text('Cancel'),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => Get.back(result: true),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.delete_outline_rounded,
                                        size: ResponsiveHelper.iconSize(context, mobile: 18, tablet: 20, desktop: 22),
                                      ),
                                      SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                                      const Text('Delete'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            final success = await controller.deleteAccount();

                            if (success) {
                              // Show success message
                              if (mounted) {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (mounted) {
                                    Get.snackbar(
                                      'Success',
                                      controller.message.value.isNotEmpty
                                          ? controller.message.value
                                          : 'Account deleted successfully!',
                                      backgroundColor: Colors.green,
                                      colorText: Colors.white,
                                      duration: const Duration(seconds: 2),
                                      margin: const EdgeInsets.all(16),
                                    );
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
                                          : 'Failed to delete account. Please try again.',
                                      backgroundColor: Colors.red,
                                      colorText: Colors.white,
                                      duration: const Duration(seconds: 3),
                                      margin: const EdgeInsets.all(16),
                                    );
                                  }
                                });
                              }
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red, // Red color for delete button
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: controller.isLoading.value
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.white,
                              size: ResponsiveHelper.iconSize(context, mobile: 20, tablet: 22, desktop: 24),
                            ),
                            SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                            Text(
                              'Delete Account',
                              style: ResponsiveHelper.textStyle(
                                context,
                                fontSize: ResponsiveHelper.fontSize(context, mobile: 18, tablet: 20, desktop: 22),
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Profile Picture - Fixed position (doesn't scroll)
            Positioned(
              top: ResponsiveHelper.isMobile(context) 
                  ? 120 
                  : ResponsiveHelper.isTablet(context) 
                      ? 130 
                      : 140, // Position for larger avatar
              left: 0,
              right: 0,
              child: IgnorePointer(
                ignoring: false, // Allow taps
                child: Center(
                  child: GestureDetector(
                    onTap: () async {
                      final picker = ImagePicker();
                      final image = await picker.pickImage(source: ImageSource.gallery);
                      if (image != null) {
                        setState(() {
                          selectedImage = File(image.path);
                        });
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                    child: CircleAvatar(
                      radius: ResponsiveHelper.isMobile(context) 
                          ? 60 
                          : ResponsiveHelper.isTablet(context) 
                              ? 70 
                              : 80, // Larger size for better visibility
                      backgroundColor: Colors.grey[200],
                      backgroundImage: selectedImage != null
                          ? FileImage(selectedImage!)
                          : (profilePhoto != null && profilePhoto.isNotEmpty
                              ? NetworkImage(
                                  profilePhoto.startsWith('http://') || profilePhoto.startsWith('https://')
                                    ? profilePhoto
                                    : 'https://fruitofthespirit.templateforwebsites.com/$profilePhoto'
                                )
                              : null) as ImageProvider?,
                      child: selectedImage == null && (profilePhoto == null || profilePhoto.isEmpty)
                          ? Icon(
                              Icons.person,
                              size: ResponsiveHelper.isMobile(context) 
                                  ? 60 
                                  : ResponsiveHelper.isTablet(context) 
                                      ? 70 
                                      : 80, // Match avatar size
                              color: AppTheme.iconscolor,
                            )
                          : null,
                    ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
