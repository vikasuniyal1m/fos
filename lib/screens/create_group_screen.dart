import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fruitsofspirit/controllers/home_controller.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fruitsofspirit/controllers/groups_controller.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';
import 'package:fruitsofspirit/widgets/cached_image.dart';
import 'package:fruitsofspirit/widgets/standard_app_bar.dart';
import 'package:fruitsofspirit/config/image_config.dart';
import 'package:fruitsofspirit/utils/app_theme.dart';

/// Create Group Screen
class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({Key? key}) : super(key: key);

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final GroupsController controller = Get.find<GroupsController>();
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  File? selectedImage;
  String selectedCategory = 'Love';
  bool _isSubmitting = false; // Loading state

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: AppTheme.themeColor, // Match other pages - beige background
      appBar: StandardAppBar(
        showBackButton: true,
        rightActions: [], // No icons
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 16)),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Group Image
            Text(
              'Group Image (Optional)',
              style: ResponsiveHelper.textStyle(
                context,
                fontSize: ResponsiveHelper.fontSize(context, mobile: 18, tablet: 19, desktop: 20),
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 8)),
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
                child: Container(
                  width: ResponsiveHelper.isMobile(context)
                      ? MediaQuery.of(context).size.width * 0.5
                      : ResponsiveHelper.isTablet(context)
                          ? MediaQuery.of(context).size.width * 0.4
                          : MediaQuery.of(context).size.width * 0.35,
                  height: ResponsiveHelper.isMobile(context)
                      ? MediaQuery.of(context).size.width * 0.5
                      : ResponsiveHelper.isTablet(context)
                          ? MediaQuery.of(context).size.width * 0.4
                          : MediaQuery.of(context).size.width * 0.35,
                  decoration: BoxDecoration(
                    color: Colors.white, // White background
                    borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                    border: Border.all(
                      color: AppTheme.iconscolor.withOpacity(0.2),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        spreadRadius: 0,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    image: selectedImage != null
                        ? DecorationImage(
                            image: FileImage(selectedImage!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: selectedImage == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate_rounded,
                              size: ResponsiveHelper.iconSize(context, mobile: 40, tablet: 45, desktop: 50),
                              color: AppTheme.iconscolor,
                            ),
                            SizedBox(height: ResponsiveHelper.spacing(context, 8)),
                            Text(
                              'Tap to select image',
                              style: TextStyle(
                                fontSize: ResponsiveHelper.fontSize(context, mobile: 13),
                                color: Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        )
                      : null,
                ),
              ),
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 20)),
            
            // Group Name
            Text(
              'Group Name *',
              style: ResponsiveHelper.textStyle(
                context,
                fontSize: ResponsiveHelper.fontSize(context, mobile: 18, tablet: 19, desktop: 20),
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 8)),
            TextFormField(
              controller: nameController,
              maxLength: 100,
              decoration: InputDecoration(
                hintText: 'Enter group name (3-100 characters)',
                hintStyle: TextStyle(
                  fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
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
                counterText: '',
              ),
              style: ResponsiveHelper.textStyle(
                context,
                fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 17, desktop: 18),
                color: AppTheme.textPrimary,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Group name is required';
                }
                final length = value.trim().length;
                if (length < 3) {
                  return 'Group name must be at least 3 characters';
                }
                if (length > 100) {
                  return 'Group name must not exceed 100 characters';
                }
                return null;
              },
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 16)),
            
            // Category
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
            DropdownButtonFormField<String>(
              value: selectedCategory,
              decoration: InputDecoration(
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
              items: [
                    'Love',
                    'Joy',
                    'Peace',
                    'Patience',
                    'Kindness',
                    'Goodness',
                    'Faithfulness',
                    'Gentleness',
                    'Self-Control'
                  ]
                  .map((category) => DropdownMenuItem(
                        value: category,
                        child: Text(
                          category,
                          style: TextStyle(
                            fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                            color: Colors.black87,
                          ),
                        ),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  selectedCategory = value!;
                });
              },
              style: ResponsiveHelper.textStyle(
                context,
                fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 17, desktop: 18),
                color: AppTheme.textPrimary,
              ),
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 16)),
            
            // Description
            Text(
              'Description (Optional)',
              style: ResponsiveHelper.textStyle(
                context,
                fontSize: ResponsiveHelper.fontSize(context, mobile: 18, tablet: 19, desktop: 20),
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 8)),
            TextFormField(
              controller: descriptionController,
              maxLines: 4,
              maxLength: 1000,
              decoration: InputDecoration(
                hintText: 'Enter group description (optional, max 1000 characters)',
                hintStyle: TextStyle(
                  fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
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
                counterText: '',
              ),
              style: ResponsiveHelper.textStyle(
                context,
                fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 17, desktop: 18),
                color: AppTheme.textPrimary,
              ),
              validator: (value) {
                if (value != null && value.trim().length > 1000) {
                  return 'Description must not exceed 1000 characters';
                }
                return null;
              },
            ),
            // Character counter
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${descriptionController.text.length}/1000',
                  style: TextStyle(
                    fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                    color: descriptionController.text.length > 1000 ? Colors.red : Colors.grey[600],
                  ),
                ),
              ),
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 24)),
            
            // Submit Button
            SizedBox(
              width: double.infinity,
              height: ResponsiveHelper.buttonHeight(context, mobile: 52),
              child: ElevatedButton(
                onPressed: (_isSubmitting || controller.isLoading.value)
                    ? null
                    : () async {
                        // Validate form
                        if (!_formKey.currentState!.validate()) {
                          return;
                        }

                        if (nameController.text.trim().isEmpty) {
                          Get.snackbar(
                            'Error',
                            'Please enter group name',
                            backgroundColor: Colors.red,
                            colorText: Colors.white,
                            duration: const Duration(seconds: 2),
                            margin: const EdgeInsets.all(16),
                          );
                          return;
                        }

                        // Set loading state
                        setState(() {
                          _isSubmitting = true;
                        });

                        try {
                          final success = await controller.createGroup(
                            name: nameController.text.trim(),
                            description: descriptionController.text.trim().isEmpty
                                ? null
                                : descriptionController.text.trim(),
                            category: selectedCategory,
                            groupImage: selectedImage,
                          );

                          if (success) {
                            // Refresh home controller groups (silent update)
                            try {
                              if (Get.isRegistered<HomeController>()) {
                                try {
                                  final homeController = Get.find<HomeController>();
                                  homeController.loadGroups();
                                } catch (e) {
                                  // HomeController not found - ignore
                                }
                              }
                            } catch (e) {
                              // HomeController not available - ignore
                            }
                            
                            // Show success message and navigate back
                            if (mounted) {
                              // Show simple UI success message (not from server)
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) {
                                  Get.snackbar(
                                    'Success',
                                    'Group created successfully!',
                                    backgroundColor: Colors.green,
                                    colorText: Colors.white,
                                    icon: const Icon(Icons.check_circle, color: Colors.white),
                                    duration: const Duration(seconds: 2),
                                    margin: const EdgeInsets.all(16),
                                  );
                                }
                              });
                              
                              // Wait a bit for snackbar to show, then navigate
                              Future.delayed(const Duration(milliseconds: 800), () async {
                                if (mounted && Navigator.canPop(context)) {
                                  Get.back();
                                }
                              });
                            }
                          } else {
                            // Show error message
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) {
                                Get.snackbar(
                                  'Error',
                                  controller.message.value.isNotEmpty 
                                      ? controller.message.value 
                                      : 'Failed to create group. Please try again.',
                                  backgroundColor: Colors.red,
                                  colorText: Colors.white,
                                  icon: const Icon(Icons.error, color: Colors.white),
                                  duration: const Duration(seconds: 3),
                                  margin: const EdgeInsets.all(16),
                                );
                              }
                            });
                          }
                        } finally {
                          // Reset loading state
                          if (mounted) {
                            setState(() {
                              _isSubmitting = false;
                            });
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.iconscolor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                  ),
                ),
                child: (_isSubmitting || controller.isLoading.value)
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'Create Group',
                        style: TextStyle(
                          fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}

