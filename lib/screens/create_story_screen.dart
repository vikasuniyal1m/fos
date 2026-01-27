import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fruitsofspirit/services/stories_service.dart';
import 'package:fruitsofspirit/services/user_storage.dart';
import 'package:fruitsofspirit/services/user_storage.dart' as us;
import 'package:fruitsofspirit/utils/responsive_helper.dart';
import 'package:fruitsofspirit/widgets/cached_image.dart';
import 'package:fruitsofspirit/services/terms_service.dart';
import 'package:fruitsofspirit/screens/terms_acceptance_screen.dart';

import '../routes/app_pages.dart';

/// Create Story Screen
/// Professional, user-friendly design matching home page style
class CreateStoryScreen extends StatefulWidget {
  const CreateStoryScreen({Key? key}) : super(key: key);

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  final titleController = TextEditingController();
  final contentController = TextEditingController();
  File? selectedImage;
  String? selectedFruitTag;
  String selectedCategory = 'testimony';
  var isLoading = false;
  int? userId;

  // Available fruits
  final List<String> fruits = [
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

  // Available categories
  final List<String> categories = [
    'testimony',
    'spiritual',
    'encouragement',
    'praise',
    'miracle',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserId();
    // Handle arguments (type: 'story' or 'testimony')
    final arguments = Get.arguments as Map<String, dynamic>?;
    if (arguments != null && arguments['type'] != null) {
      final type = arguments['type'] as String;
      if (type == 'story') {
        selectedCategory = 'spiritual'; // Default for stories
      } else if (type == 'testimony') {
        selectedCategory = 'testimony';
      }
    }
    // Add listener to update character count
    contentController.addListener(() {
      setState(() {});
    });
  }

  Future<void> _loadUserId() async {
    final user = await UserStorage.getUser();
    if (user != null) {
      setState(() {
        userId = user['id'] as int?;
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        selectedImage = File(image.path);
      });
    }
  }

  void _removeImage() {
    setState(() {
      selectedImage = null;
    });
  }

  Future<void> _createStory() async {
    final hasAcceptedTerms = await TermsService.hasAcceptedTerms();
    if (!hasAcceptedTerms) {
      Get.to(() => TermsAcceptanceScreen(
            onAccepted: () {
              Get.back(); // Pop terms screen
              _createStory(); // Retry
            },
          ));
      return;
    }

    if (userId == null || userId == 0) {
      await _loadUserId();
    }

    if (userId == null || userId == 0) {
      Get.snackbar(
        'Error',
        'Please login first',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (titleController.text.trim().isEmpty) {
      Get.snackbar(
        'Error',
        'Please enter story title',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (contentController.text.trim().isEmpty) {
      Get.snackbar(
        'Error',
        'Please enter story content',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (contentController.text.trim().length < 20) {
      Get.snackbar(
        'Error',
        'Story content must be at least 20 characters',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final storyId = await StoriesService.createStory(
        userId: userId!,
        title: titleController.text.trim(),
        content: contentController.text.trim(),
        fruitTag: selectedFruitTag,
        category: selectedCategory,
        image: selectedImage,
      );

      // Show success message FIRST (before navigation)
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Get.snackbar(
              'Success',
              'Story created successfully. Waiting for admin approval.',
              backgroundColor: Colors.green,
              colorText: Colors.white,
              snackPosition: SnackPosition.BOTTOM,
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
    } catch (e) {
      final errorMsg = e.toString().replaceAll('Exception: ', '');
      final isModeration = errorMsg.contains('community guidelines');

      Get.snackbar(
        isModeration ? 'Community Standard' : 'Notice',
        errorMsg,
        backgroundColor: isModeration ? const Color(0xFF5D4037) : Colors.grey[800],
        colorText: Colors.white,
        icon: Icon(
          isModeration ? Icons.security_rounded : Icons.error_outline,
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
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF6EC),
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(
          ResponsiveHelper.appBarHeight(context),
        ),
        child: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_rounded,
              color: const Color(0xFF5F4628),
              size: ResponsiveHelper.iconSize(context, mobile: 24, tablet: 28, desktop: 32),
            ),
            onPressed: () => Get.back(),
          ),
          title: Text(
            'Share Your Story',
            style: ResponsiveHelper.textStyle(
              context,
              fontSize: ResponsiveHelper.fontSize(context, mobile: 20, tablet: 24, desktop: 28),
              fontWeight: FontWeight.bold,
              color: const Color(0xFF5F4628),
            ),
          ),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(
              height: 1,
              color: Colors.grey.withOpacity(0.2),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: ResponsiveHelper.padding(context, all: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section with Gradient
            Container(
              padding: ResponsiveHelper.padding(context, all: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF5F4628).withOpacity(0.1),
                    const Color(0xFF9F9467).withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 20)),
                border: Border.all(
                  color: const Color(0xFF5F4628).withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: ResponsiveHelper.padding(context, all: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5F4628),
                      borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                    ),
                    child: Icon(
                      Icons.book_outlined,
                      color: Colors.white,
                      size: ResponsiveHelper.iconSize(context, mobile: 24),
                    ),
                  ),
                  SizedBox(width: ResponsiveHelper.spacing(context, 16)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Share Your Testimony',
                          style: ResponsiveHelper.textStyle(
                            context,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF5F4628),
                          ),
                        ),
                        SizedBox(height: ResponsiveHelper.spacing(context, 4)),
                        Text(
                          'Inspire others with your story',
                          style: ResponsiveHelper.textStyle(
                            context,
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 24)),

            // Image Selection Section
            Container(
              padding: ResponsiveHelper.padding(context, all: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
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
                          color: const Color(0xFF5F4628).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
                        ),
                        child: Icon(
                          Icons.image_outlined,
                          size: ResponsiveHelper.iconSize(context, mobile: 20),
                          color: const Color(0xFF5F4628),
                        ),
                      ),
                      SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                      Text(
                        'Story Image',
                        style: ResponsiveHelper.textStyle(
                          context,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF5F4628),
                        ),
                      ),
                      const Spacer(),
                      if (selectedImage != null)
                        InkWell(
                          onTap: _removeImage,
                          borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
                          child: Container(
                            padding: ResponsiveHelper.padding(context, horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.delete_outline,
                                  size: ResponsiveHelper.iconSize(context, mobile: 16),
                                  color: Colors.red,
                                ),
                                SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                                Text(
                                  'Remove',
                                  style: ResponsiveHelper.textStyle(
                                    context,
                                    fontSize: 13,
                                    color: Colors.red,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      height: ResponsiveHelper.imageHeight(context, mobile: 250, tablet: 280, desktop: 300),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.grey[50]!,
                            Colors.grey[100]!,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
                        border: Border.all(
                          color: const Color(0xFF5F4628).withOpacity(0.2),
                          width: 2,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: selectedImage != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 14)),
                              child: Image.file(
                                selectedImage!,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: ResponsiveHelper.padding(context, all: 16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF5F4628).withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.add_photo_alternate_outlined,
                                    size: ResponsiveHelper.iconSize(context, mobile: 48, tablet: 56, desktop: 64),
                                    color: const Color(0xFF5F4628),
                                  ),
                                ),
                                SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                                Text(
                                  'Tap to select image',
                                  style: ResponsiveHelper.textStyle(
                                    context,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF5F4628),
                                  ),
                                ),
                                SizedBox(height: ResponsiveHelper.spacing(context, 4)),
                                Text(
                                  '(Optional)',
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
                ],
              ),
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 24)),

            // Title Section
            Container(
              padding: ResponsiveHelper.padding(context, all: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
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
                          color: const Color(0xFF5F4628).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
                        ),
                        child: Icon(
                          Icons.title_outlined,
                          size: ResponsiveHelper.iconSize(context, mobile: 20),
                          color: const Color(0xFF5F4628),
                        ),
                      ),
                      SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                      Text(
                        'Story Title',
                        style: ResponsiveHelper.textStyle(
                          context,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF5F4628),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                  TextField(
                    controller: titleController,
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter a compelling title for your story...',
                      hintStyle: ResponsiveHelper.textStyle(
                        context,
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                        borderSide: BorderSide(
                          color: Colors.grey.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                        borderSide: BorderSide(
                          color: Colors.grey.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                        borderSide: const BorderSide(
                          color: Color(0xFF5F4628),
                          width: 2,
                        ),
                      ),
                      contentPadding: ResponsiveHelper.padding(context, horizontal: 16, vertical: 16),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 24)),

            // Content Section
            Container(
              padding: ResponsiveHelper.padding(context, all: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
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
                          color: const Color(0xFF5F4628).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
                        ),
                        child: Icon(
                          Icons.edit_note_outlined,
                          size: ResponsiveHelper.iconSize(context, mobile: 20),
                          color: const Color(0xFF5F4628),
                        ),
                      ),
                      SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                      Text(
                        'Your Story',
                        style: ResponsiveHelper.textStyle(
                          context,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF5F4628),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                  TextField(
                    controller: contentController,
                    maxLines: 10,
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: 15,
                      color: Colors.black87,
                      height: 1.6,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Share your testimony, spiritual journey, or inspiring story...\n\nBe authentic and let your story inspire others!',
                      hintStyle: ResponsiveHelper.textStyle(
                        context,
                        fontSize: 14,
                        color: Colors.grey[500],
                        height: 1.5,
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                        borderSide: BorderSide(
                          color: Colors.grey.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                        borderSide: BorderSide(
                          color: Colors.grey.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                        borderSide: const BorderSide(
                          color: Color(0xFF5F4628),
                          width: 2,
                        ),
                      ),
                      contentPadding: ResponsiveHelper.padding(context, all: 16),
                    ),
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(context, 8)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        padding: ResponsiveHelper.padding(context, horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: contentController.text.length < 20 
                              ? Colors.red.withOpacity(0.1) 
                              : Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
                        ),
                        child: Text(
                          '${contentController.text.length} characters',
                          style: ResponsiveHelper.textStyle(
                            context,
                            fontSize: 12,
                            color: contentController.text.length < 20 ? Colors.red : Colors.green[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 24)),

            // Category & Fruit Tag Section
            Container(
              padding: ResponsiveHelper.padding(context, all: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
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
                          color: const Color(0xFF5F4628).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
                        ),
                        child: Icon(
                          Icons.category_outlined,
                          size: ResponsiveHelper.iconSize(context, mobile: 20),
                          color: const Color(0xFF5F4628),
                        ),
                      ),
                      SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                      Text(
                        'Category & Tag',
                        style: ResponsiveHelper.textStyle(
                          context,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF5F4628),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(context, 20)),
                  
                  // Category Dropdown
                  Text(
                    'Category',
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(context, 8)),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                        borderSide: BorderSide(
                          color: Colors.grey.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                        borderSide: BorderSide(
                          color: Colors.grey.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                        borderSide: const BorderSide(
                          color: Color(0xFF5F4628),
                          width: 2,
                        ),
                      ),
                      contentPadding: ResponsiveHelper.padding(context, horizontal: 16, vertical: 16),
                    ),
                    items: categories.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(
                          category[0].toUpperCase() + category.substring(1),
                          style: ResponsiveHelper.textStyle(
                            context,
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          selectedCategory = value;
                        });
                      }
                    },
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(context, 20)),
                  
                  // Fruit Tag Dropdown
                  Text(
                    'Tag with Fruit (Optional)',
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(context, 8)),
                  DropdownButtonFormField<String?>(
                    value: selectedFruitTag,
                    decoration: InputDecoration(
                      hintText: 'Select a fruit of the spirit',
                      hintStyle: ResponsiveHelper.textStyle(
                        context,
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                        borderSide: BorderSide(
                          color: Colors.grey.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                        borderSide: BorderSide(
                          color: Colors.grey.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                        borderSide: const BorderSide(
                          color: Color(0xFF5F4628),
                          width: 2,
                        ),
                      ),
                      contentPadding: ResponsiveHelper.padding(context, horizontal: 16, vertical: 16),
                    ),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(
                          'None',
                          style: ResponsiveHelper.textStyle(
                            context,
                            fontSize: 15,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                      ...fruits.map((fruit) {
                        return DropdownMenuItem<String?>(
                          value: fruit,
                          child: Text(
                            fruit,
                            style: ResponsiveHelper.textStyle(
                              context,
                              fontSize: 15,
                              color: Colors.black87,
                            ),
                          ),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedFruitTag = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 32)),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: ResponsiveHelper.buttonHeight(context, mobile: 56, tablet: 60, desktop: 64),
              child: ElevatedButton(
                onPressed: isLoading ? null : _createStory,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5F4628),
                  disabledBackgroundColor: Colors.grey[400],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
                  ),
                  elevation: 4,
                  shadowColor: const Color(0xFF5F4628).withOpacity(0.3),
                ),
                child: isLoading
                    ? SizedBox(
                        width: ResponsiveHelper.iconSize(context, mobile: 24),
                        height: ResponsiveHelper.iconSize(context, mobile: 24),
                        child: const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.send_rounded,
                            size: ResponsiveHelper.iconSize(context, mobile: 22, tablet: 24, desktop: 26),
                            color: Colors.white,
                          ),
                          SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                          Text(
                            'Share Story',
                            style: ResponsiveHelper.textStyle(
                              context,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 24)),
          ],
        ),
      ),
    );
  }
}
