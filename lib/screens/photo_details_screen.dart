import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:fruitsofspirit/utils/share_helper.dart';
import 'package:fruitsofspirit/utils/time_helper.dart';

import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/controllers/gallery_controller.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';
import 'package:fruitsofspirit/utils/auto_translate_helper.dart';
import 'package:fruitsofspirit/widgets/cached_image.dart';
import 'package:fruitsofspirit/services/user_storage.dart';
import 'package:fruitsofspirit/screens/home_screen.dart';
import 'package:fruitsofspirit/services/emojis_service.dart';
import 'package:fruitsofspirit/widgets/standard_app_bar.dart';
import 'package:fruitsofspirit/utils/app_theme.dart';
import 'package:fruitsofspirit/utils/fruit_emoji_helper.dart';
import 'package:fruitsofspirit/services/user_blocking_service.dart';
import 'package:fruitsofspirit/utils/report_utils.dart';
import 'package:fruitsofspirit/utils/sticker_emoji_helper.dart';
import 'package:fruitsofspirit/widgets/emoji_sticker_picker.dart';
import 'package:fruitsofspirit/widgets/emoji_button.dart';
import 'package:fruitsofspirit/services/gallery_service.dart'; // edit feature
import 'package:fruitsofspirit/services/comments_service.dart'; // edit feature
import 'package:fruitsofspirit/screens/report_content_screen.dart';

/// Photo Details Screen
/// Shows single photo with full comment system (like blog/prayer details)
class PhotoDetailsScreen extends StatefulWidget {
  const PhotoDetailsScreen({Key? key}) : super(key: key);

  @override
  State<PhotoDetailsScreen> createState() => _PhotoDetailsScreenState();
}

// Message model for proper text/sticker separation (reusable from blog_details_screen)
class CommentMessage {
  final String? text;
  final String? stickerId;
  final bool isSticker;

  CommentMessage({this.text, this.stickerId, required this.isSticker});
}

class _PhotoDetailsScreenState extends State<PhotoDetailsScreen> {
  late final GalleryController controller;
  final replyControllers = <int, TextEditingController>{};
  final replyFocusNodes = <int, FocusNode>{}; // Focus nodes for replies
  final showReplyInput = <int, bool>{};
  final expandedReplies = <int>{}; // Track which replies are expanded
  final _sendingReplies = <int>{}; // Track which replies are being sent
  final commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _commentFocusNode = FocusNode();
  // Rich text input messages (text + stickers) like blog_details_screen
  final List<CommentMessage> commentMessages = [];
  int? currentUserId;
  String? userEmail;
  double _photoHeight = 350.0; // Initial photo height
  double _minPhotoHeight = 100.0; // Minimum collapsed height
  double _maxPhotoHeight = 350.0; // Maximum expanded height
  bool _isSendingComment = false; // Track comment sending state
  // edit feature: Comment edit state
  final editControllers = <int, TextEditingController>{}; // edit feature
  final showEditInput = <int, bool>{}; // edit feature
  var isEditingComment = false.obs; // edit feature
  var isSubmittingComment = false.obs; // Track comment submission state
  // edit feature: Post edit state
  final postEditTitleController = TextEditingController(); // edit feature
  final postEditDescriptionController = TextEditingController(); // edit feature
  final postEditCategoryController = TextEditingController(); // edit feature
  var showPostEditInput = false.obs; // edit feature
  var isEditingPost = false.obs; // edit feature

  /// Show a custom snackbar using ScaffoldMessenger
  void _showCustomSnackbar(String title, String message, {bool isError = false}) {
    if (!mounted) return;
    
    // Close any existing snackbars
    ScaffoldMessenger.of(this.context).hideCurrentSnackBar();
    
    ScaffoldMessenger.of(this.context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              message,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red : AppTheme.iconscolor,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }


  @override
  void initState() {
    super.initState();
    // Lazily initialize controller if not already registered
    controller = Get.isRegistered<GalleryController>()
        ? Get.find<GalleryController>()
        : Get.put(GalleryController(), permanent: true);
    _loadCurrentUserId();
    _loadUserEmail();
    final photoId = Get.arguments as int? ?? 0;
    if (photoId > 0 && (controller.selectedPhoto.isEmpty || controller.selectedPhoto['id'] != photoId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.loadPhotoDetails(photoId);
        // Load emojis for reactions
        controller.loadAvailableEmojis();
        controller.loadQuickEmojis();
      });
    }
    
    // Initialize photo heights based on screen size
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final screenHeight = MediaQuery.of(context).size.height;
        setState(() {
          _maxPhotoHeight = screenHeight * 0.5; // 50% of screen height
          _minPhotoHeight = 100.0; // Minimum collapsed height
          _photoHeight = _maxPhotoHeight;
        });
      }
    });
    
    // Listen to scroll changes
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!mounted) return;
    
    final scrollOffset = _scrollController.offset;
    // Calculate new photo height based on scroll
    // When scroll is 0, photo is max height, as scroll increases, photo shrinks
    // When scrolling back down (scrollOffset decreases), photo expands again (social media style)
    // Use a threshold of 300px scroll to fully collapse
    final collapseThreshold = 300.0;
    final scrollProgress = (scrollOffset / collapseThreshold).clamp(0.0, 1.0);
    final newHeight = _maxPhotoHeight - ((_maxPhotoHeight - _minPhotoHeight) * scrollProgress);
    
    // Update height immediately for smooth scrolling (like other modules)
    // Scroll events are safe to call setState directly
    if ((_photoHeight - newHeight).abs() > 0.1) {
      setState(() {
        _photoHeight = newHeight.clamp(_minPhotoHeight, _maxPhotoHeight);
      });
    }
  }

  Future<void> _loadCurrentUserId() async {
    final user = await UserStorage.getUser();
    if (user != null) {
      final id = user['id'];
      if (id is int) {
        currentUserId = id;
      }
    }
  }

  Future<void> _loadUserEmail() async {
    userEmail = await UserStorage.getUserEmail();
  }

  /// Show Full Screen Image Preview
  void _showImagePreview(BuildContext context, String imageUrl, Map<String, dynamic> photo) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _ImagePreviewScreen(
          imageUrl: imageUrl,
          photo: photo,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _commentFocusNode.dispose();
    commentController.dispose();
    // edit feature: Dispose comment edit controllers
    for (var controller in editControllers.values) { // edit feature
      controller.dispose(); // edit feature
    } // edit feature
    // edit feature: Dispose post edit controllers
    postEditTitleController.dispose(); // edit feature
    postEditDescriptionController.dispose(); // edit feature
    postEditCategoryController.dispose(); // edit feature
    for (var controller in replyControllers.values) {
      controller.dispose();
    }
    for (var focusNode in replyFocusNodes.values) {
      focusNode.dispose();
    }
    super.dispose();
  }

  /// Get India time (IST) from timestamp
  String _getIndiaTime(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '';

    try {
      DateTime date;
      // Handle different timestamp formats
      if (dateString.contains('T')) {
        // ISO 8601 format
        date = DateTime.parse(dateString);
      } else {
        // Try parsing as standard MySQL datetime format
        date = DateTime.parse('${dateString}Z');
      }

      // Convert to India time (IST = UTC+5:30)
      final indiaTimeZone = Duration(hours: 5, minutes: 30);
      final indiaTime = date.toUtc().add(indiaTimeZone);

      // Format as HH:MM AM/PM
      final hour = indiaTime.hour;
      final minute = indiaTime.minute;
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      final displayMinute = minute.toString().padLeft(2, '0');

      return '$displayHour:$displayMinute $period IST';
    } catch (e) {
      return '';
    }
  }

  // edit feature: Configurable edit time window in minutes
  static const int _editTimeWindowMinutes = 15; // edit feature


  // edit feature: Configurable time zone offset in minutes (default India UTC+5:30 = 330 minutes)
  // Change this value to manually control the time zone for testing
  // Examples: UTC = 0, India = 330, US Eastern = -300, US Pacific = -480
  static const int _timeZoneOffsetMinutes = 0; // edit feature: UTC (for testing)

  // edit feature: Get current time with configured time zone offset
  DateTime _getCurrentTime() { // edit feature
    final utcNow = DateTime.now().toUtc(); // edit feature
    return utcNow.add(Duration(minutes: _timeZoneOffsetMinutes)); // edit feature
  } // edit feature

  // edit feature: Check if photo can be edited (always allow editing)
  bool _canEditPost(Map<String, dynamic> photo) { // edit feature
    print('🔍 Edit check - always allowing editing'); // debug
    return true; // edit feature: Always allow editing
  } // edit feature

  // edit feature: Check if comment can be edited (within 15 minutes only)
  bool _canEditComment(Map<String, dynamic> comment) { // edit feature
    print('🔍 Edit check - created_at: ${comment['created_at']}'); // debug
    
    // Check if user is logged in
    if (currentUserId == null || currentUserId == 0) { // edit feature
      print('❌ Edit blocked: user not logged in'); // debug
      return false; // edit feature
    } // edit feature
    
    // Check if comment belongs to current user
    final commentUserId = comment['user_id']; // edit feature
    if (commentUserId == null || commentUserId.toString() != currentUserId.toString()) { // edit feature
      print('❌ Edit blocked: comment belongs to user $commentUserId, current user is $currentUserId'); // debug
      return false; // edit feature
    } // edit feature
    
    if (comment['created_at'] == null) { // edit feature
      print('❌ Edit blocked: created_at is null'); // debug
      return false; // edit feature
    } // edit feature
    try { // edit feature
      DateTime backendTime;
      // Handle different timestamp formats - use UTC logic like TimeHelper
      if (comment['created_at'].toString().contains('T')) {
        // ISO 8601 format
        if (comment['created_at'].toString().endsWith('Z')) {
          backendTime = DateTime.parse(comment['created_at'] as String);
        } else {
          backendTime = DateTime.parse('${comment['created_at']}Z');
        }
      } else {
        // MySQL datetime format - treat as UTC
        backendTime = DateTime.parse(comment['created_at'].toString()).toUtc();
      }

      // CRITICAL FIX: Use device's current timezone for accurate time calculation
      final nowDevice = DateTime.now(); // This is LOCAL device time
      final backendTimeLocal = backendTime.toLocal(); // Convert backend time to local
      final difference = nowDevice.difference(backendTimeLocal);
      final canEdit = difference.inMinutes < _editTimeWindowMinutes; // edit feature: Check 15-minute window
      print('🕐 Time check (LOCAL): ${difference.inMinutes} minutes, canEdit: $canEdit'); // debug
      print('🌍 Device timezone: ${nowDevice.timeZoneName} (${nowDevice.timeZoneOffset})'); // debug
      return canEdit; // edit feature
    } catch (e) { // edit feature
      print('❌ Edit blocked: date parsing error - $e'); // debug
      return false; // edit feature
    } // edit feature
  } // edit feature

  // edit feature: Build edit button widget
  Widget _buildEditButton(BuildContext context, Map<String, dynamic> comment, int photoId) { // edit feature
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
  Widget _buildEditInput(BuildContext context, int commentId, int photoId, String postType) { // edit feature
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
                onPressed: () => _editComment(commentId, photoId, postType), // edit feature
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
  Future<void> _editComment(int commentId, int photoId, String postType) async { // edit feature
    final editController = editControllers[commentId]; // edit feature
    if (editController == null) return; // edit feature

    final content = editController.text.trim(); // edit feature
    if (content.isEmpty) { // edit feature
      Get.snackbar( // edit feature
        'Error', // edit feature
        'Comment cannot be empty', // edit feature
        backgroundColor: Colors.red, // edit feature
        colorText: Colors.white, // edit feature
        duration: const Duration(seconds: 2), // edit feature
      ); // edit feature
      return; // edit feature
    } // edit feature

    if (currentUserId == null || currentUserId == 0) { // edit feature
      Get.snackbar( // edit feature
        'Error', // edit feature
        'Please login first', // edit feature
        backgroundColor: Colors.red, // edit feature
        colorText: Colors.white, // edit feature
        duration: const Duration(seconds: 2), // edit feature
      ); // edit feature
      return; // edit feature
    } // edit feature

    isEditingComment.value = true; // edit feature
    try { // edit feature
      // Use GalleryService for photo comments
      await GalleryService.editComment( // edit feature
        userId: currentUserId!, // edit feature
        commentId: commentId, // edit feature
        photoId: photoId, // edit feature
        content: content, // edit feature
      ); // edit feature

      setState(() { // edit feature
        showEditInput[commentId] = false; // edit feature
      }); // edit feature

      await controller.loadPhotoComments(photoId); // edit feature

      Get.snackbar( // edit feature
        'Success', // edit feature
        'Comment edited successfully', // edit feature
        backgroundColor: Colors.green, // edit feature
        colorText: Colors.white, // edit feature
        duration: const Duration(seconds: 2), // edit feature
      ); // edit feature
    } catch (e) { // edit feature
      Get.snackbar( // edit feature
        'Error', // edit feature
        'Failed to edit comment', // edit feature
        backgroundColor: Colors.red, // edit feature
        colorText: Colors.white, // edit feature
        duration: const Duration(seconds: 2), // edit feature
      ); // edit feature
    } finally { // edit feature
      isEditingComment.value = false; // edit feature
    } // edit feature
  } // edit feature

  // edit feature: Edit photo method
  Future<void> _editPost(int mediaId) async { // edit feature
    final title = postEditTitleController.text.trim(); // edit feature
    final description = postEditDescriptionController.text.trim(); // edit feature
    final category = postEditCategoryController.text.trim(); // edit feature

    if (title.isEmpty && description.isEmpty && category.isEmpty) { // edit feature
      Get.snackbar( // edit feature
        'Error', // edit feature
        'At least one field must be filled', // edit feature
        backgroundColor: Colors.red, // edit feature
        colorText: Colors.white, // edit feature
        duration: const Duration(seconds: 2), // edit feature
      ); // edit feature
      return; // edit feature
    } // edit feature

    if (currentUserId == null || currentUserId == 0) { // edit feature
      Get.snackbar( // edit feature
        'Error', // edit feature
        'Please login first', // edit feature
        backgroundColor: Colors.red, // edit feature
        colorText: Colors.white, // edit feature
        duration: const Duration(seconds: 2), // edit feature
      ); // edit feature
      return; // edit feature
    } // edit feature

    isEditingPost.value = true; // edit feature
    try { // edit feature
      await GalleryService.editPhoto( // edit feature
        userId: currentUserId!, // edit feature
        mediaId: mediaId, // edit feature
        title: title.isEmpty ? null : title, // edit feature
        description: description.isEmpty ? null : description, // edit feature
        category: category.isEmpty ? null : category, // edit feature
      ); // edit feature

      showPostEditInput.value = false; // edit feature
      final photoId = Get.arguments as int? ?? 0; // edit feature
      await controller.loadPhotoDetails(photoId); // edit feature

      Get.snackbar( // edit feature
        'Success', // edit feature
        'Photo edited successfully', // edit feature
        backgroundColor: Colors.green, // edit feature
        colorText: Colors.white, // edit feature
        duration: const Duration(seconds: 2), // edit feature
      ); // edit feature
    } catch (e) { // edit feature
      Get.snackbar( // edit feature
        'Error', // edit feature
        e.toString().replaceAll('Exception: ', ''), // edit feature
        backgroundColor: Colors.red, // edit feature
        colorText: Colors.white, // edit feature
        duration: const Duration(seconds: 2), // edit feature
      ); // edit feature
    } finally { // edit feature
      isEditingPost.value = false; // edit feature
    } // edit feature
  } // edit feature

  /// Get image provider for profile photo
  ImageProvider? _getImageProvider(String? photoUrl) {
    if (photoUrl == null || photoUrl.isEmpty) return null;
    
    final photoPath = photoUrl.toString();
    
    // Check if it's a local asset path
    if (photoPath.startsWith('assets/') || 
        photoPath.startsWith('file://') ||
        photoPath.startsWith('assets/images/')) {
      return null;
    }
    
    // Check if it's already a full URL (http/https) - use as-is
    if (photoPath.startsWith('http://') || photoPath.startsWith('https://')) {
      return NetworkImage(photoPath);
    }
    
    // If it's a relative path, construct full URL
    return NetworkImage('http://admin.fosmessenger.com/$photoPath');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.themeColor,
      resizeToAvoidBottomInset: true,
      appBar: const StandardAppBar(
        showBackButton: true,
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.selectedPhoto.isEmpty) {
          return Center(
            child: CircularProgressIndicator(
              color: AppTheme.iconscolor,
            ),
          );
        }

        if (controller.selectedPhoto.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: ResponsiveHelper.iconSize(context, mobile: 64),
                  color: Colors.white,
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                Text(
                  'Photo not found',
                  style: ResponsiveHelper.textStyle(
                    context,
                    fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B4513),
                  ),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          );
        }

        final photo = controller.selectedPhoto;
        final isPending = photo['status'] == 'Pending';
        final photoId = photo['id'] as int;
        final baseUrl = 'http://admin.fosmessenger.com/';
        final filePath = photo['file_path'] as String? ?? '';
        final imageUrl = filePath.isNotEmpty ? baseUrl + filePath : null;
        final testimony = photo['testimony'] as String? ?? '';

        // Get keyboard height to adjust photo height
        final keyboardHeight = MediaQuery
            .of(context)
            .viewInsets
            .bottom;
        final screenHeight = MediaQuery
            .of(context)
            .size
            .height;

        return LayoutBuilder(
            builder: (context, constraints) {
              // Calculate available height considering keyboard
              final availableHeight = constraints.maxHeight;
              final commentInputHeight = 80.0; // Approximate height of comment input bar
              final minContentHeight = 200.0; // Minimum height for scrollable content

              // When keyboard is open, aggressively shrink photo to prevent overflow
              final effectivePhotoHeight = keyboardHeight > 0
                  ? (_minPhotoHeight).clamp(_minPhotoHeight,
                  availableHeight - commentInputHeight - minContentHeight)
                  : _photoHeight.clamp(_minPhotoHeight,
                  (screenHeight * 0.5).clamp(_minPhotoHeight, _maxPhotoHeight));

              return Column(
                children: [
                  // Photo Display - Animated based on scroll (Social Media Style)
                  Flexible(
                    flex: 0,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      curve: Curves.easeOut,
                      height: effectivePhotoHeight,
                      constraints: BoxConstraints(
                        maxHeight: keyboardHeight > 0
                            ? (availableHeight - commentInputHeight -
                            minContentHeight).clamp(_minPhotoHeight,
                            _maxPhotoHeight)
                            : screenHeight * 0.5,
                      ),
                      child: GestureDetector(
                        onTap: () {
                          // Show full screen image preview when tapped
                          if (imageUrl != null) {
                            _showImagePreview(context, imageUrl, photo);
                          }
                        },
                        child: Container(
                          color: Colors.black,
                          child: imageUrl != null
                              ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Icon(
                                  Icons.broken_image,
                                  size: ResponsiveHelper.iconSize(
                                      context, mobile: 64),
                                  color: Colors.white,
                                ),
                              );
                            },
                          )
                              : Center(
                            child: Icon(
                              Icons.image_not_supported,
                              size: ResponsiveHelper.iconSize(
                                  context, mobile: 64),
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Photo Info & Comments - Scrollable
                  Expanded(
                    child: Container(
                      color: const Color(0xFFF8F9FA),
                      // Match home page background
                      child: Column(
                        children: [
                          Expanded(
                            child: RefreshIndicator(
                              onRefresh: () async {
                                if (kDebugMode) debugPrint(
                                    '🔄 Pull-to-refresh triggered on photo details');
                                await controller.loadPhotoDetails(photoId);
                                await controller.loadPhotoComments(photoId);
                                if (kDebugMode) debugPrint(
                                    '✅ Refresh completed');
                              },
                              color: AppTheme.iconscolor,
                              backgroundColor: Colors.white,
                              child: SingleChildScrollView(
                                controller: _scrollController,
                                physics: const AlwaysScrollableScrollPhysics(),
                                // Enable scroll for pull-to-refresh
                                padding: EdgeInsets.all(
                                    ResponsiveHelper.spacing(context, 16)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // User Info
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: ResponsiveHelper.borderRadius(
                                              context, mobile: 20),
                                          backgroundColor: const Color(
                                              0xFFFEECE2),
                                          backgroundImage: _getImageProvider(
                                              photo['profile_photo'] as String?),
                                          child: photo['profile_photo'] == null
                                              ? Icon(
                                            Icons.person,
                                            size: ResponsiveHelper.iconSize(
                                                context, mobile: 24),
                                            color: AppTheme.iconscolor,
                                          )
                                              : null,
                                        ),
                                        SizedBox(
                                            width: ResponsiveHelper.spacing(
                                                context, 12)),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment
                                                .start,
                                            children: [
                                              Text(
                                                photo['user_name'] as String? ??
                                                    'Anonymous',
                                                style: ResponsiveHelper
                                                    .textStyle(
                                                  context,
                                                  fontSize: ResponsiveHelper
                                                      .fontSize(
                                                      context, mobile: 14),
                                                  fontWeight: FontWeight.bold,
                                                  color: AppTheme.iconscolor,
                                                ),
                                              ),
                                              if (photo['fruit_tag'] != null &&
                                                  (photo['fruit_tag'] as String)
                                                      .isNotEmpty) ...[
                                                SizedBox(
                                                    height: ResponsiveHelper
                                                        .spacing(context, 4)),
                                                Container(
                                                  padding: ResponsiveHelper
                                                      .padding(
                                                      context, horizontal: 8,
                                                      vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                        0xFF8B4513).withOpacity(
                                                        0.1),
                                                    borderRadius: BorderRadius
                                                        .circular(
                                                        ResponsiveHelper
                                                            .borderRadius(
                                                            context,
                                                            mobile: 12)),
                                                  ),
                                                  child: Text(
                                                    photo['fruit_tag'] as String,
                                                    style: ResponsiveHelper
                                                        .textStyle(
                                                      context,
                                                      fontSize: 11,
                                                      fontWeight: FontWeight
                                                          .w600,
                                                      color: AppTheme
                                                          .iconscolor,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        Padding(
                                          padding: ResponsiveHelper.padding(context, all: 8),
                                          child: Container(
                                            padding: EdgeInsets.all(4),
                                            child: _buildPhotoOptions(context, photo),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: ResponsiveHelper.spacing(
                                        context, 12)),

                                    // Testimony/Description - Check both testimony field and first comment
                                    Builder(
                                      builder: (context) {
                                        // First check if testimony field exists in photo data
                                        String? testimonyText = photo['testimony'] as String?;

                                        // If not found, check first comment (testimony is saved as first comment)
                                        if ((testimonyText == null ||
                                            testimonyText.isEmpty) &&
                                            controller.photoComments
                                                .isNotEmpty) {
                                          final firstComment = controller
                                              .photoComments.first;
                                          // Check if it's the testimony comment (usually the first one by the same user)
                                          if (firstComment['user_id'] ==
                                              photo['user_id']) {
                                            testimonyText =
                                            firstComment['content'] as String?;
                                          }
                                        }

                                        if (testimonyText != null &&
                                            testimonyText.isNotEmpty) {
                                          return Container(
                                            margin: EdgeInsets.only(
                                                bottom: ResponsiveHelper
                                                    .spacing(context, 16)),
                                            padding: ResponsiveHelper.padding(
                                                context, all: 16),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius
                                                  .circular(
                                                  ResponsiveHelper.borderRadius(
                                                      context, mobile: 16)),
                                              border: Border.all(
                                                color: const Color(0xFF8B4513)
                                                    .withOpacity(0.2),
                                                width: 1,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.04),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment
                                                  .start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons
                                                          .format_quote_rounded,
                                                      size: ResponsiveHelper
                                                          .iconSize(context,
                                                          mobile: 20),
                                                      color: AppTheme
                                                          .iconscolor,
                                                    ),
                                                    SizedBox(
                                                        width: ResponsiveHelper
                                                            .spacing(context,
                                                            8)),
                                                    Text(
                                                      'Testimony',
                                                      style: ResponsiveHelper
                                                          .textStyle(
                                                        context,
                                                        fontSize: 16,
                                                        fontWeight: FontWeight
                                                            .bold,
                                                        color: AppTheme
                                                            .iconscolor,
                                                      ),
                                                    ),
                                                    ///TEST EDIT
                                                    // edit feature: Show "edited" label if photo was edited
                                                    if (photo['is_edited'] == true || photo['is_edited'] == 1) ...[ // edit feature
                                                      SizedBox(height: ResponsiveHelper.spacing(context, 8)), // edit feature
                                                      Text( // edit feature
                                                        'edited', // edit feature
                                                        style: TextStyle( // edit feature
                                                          fontSize: 10, // edit feature
                                                          color: Colors.grey[500], // edit feature
                                                          fontStyle: FontStyle.italic, // edit feature
                                                        ), // edit feature
                                                      ), // edit feature
                                                    ], // edit feature


                                                  ]
                                                ),
                                                SizedBox(
                                                    height: ResponsiveHelper
                                                        .spacing(context, 12)),
                                                Text(
                                                  testimonyText,
                                                  style: ResponsiveHelper
                                                      .textStyle(
                                                    context,
                                                    fontSize: ResponsiveHelper
                                                        .fontSize(
                                                        context, mobile: 14),
                                                    color: Colors.black87,
                                                    height: 1.6,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }
                                        return const SizedBox.shrink();
                                      },
                                    ),
                                    // edit feature: Edit button for own photos within 15 minutes
                                    if (_canEditPost(photo)) ...[ // edit feature
                                      SizedBox(height: ResponsiveHelper.spacing(context, 8)), // edit feature
                                      GestureDetector( // edit feature
                                        onTap: () { // edit feature
                                          setState(() { // edit feature
                                            postEditTitleController.text = photo['title'] as String? ?? ''; // edit feature
                                            postEditDescriptionController.text = photo['testimony'] as String? ?? ''; // edit feature
                                            postEditCategoryController.text = photo['category'] as String? ?? ''; // edit feature
                                            showPostEditInput.value = !showPostEditInput.value; // edit feature
                                          }); // edit feature
                                        }, // edit feature
                                        child: Container( // edit feature
                                          padding: ResponsiveHelper.padding(context, horizontal: 12, vertical: 6), // edit feature
                                          decoration: BoxDecoration( // edit feature
                                            color: Colors.grey[200], // edit feature
                                            borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)), // edit feature
                                          ), // edit feature
                                          child: Row( // edit feature
                                            mainAxisSize: MainAxisSize.min, // edit feature
                                            children: [ // edit feature
                                              Icon( // edit feature
                                                Icons.edit, // edit feature
                                                size: 14, // edit feature
                                                color: Colors.grey[700], // edit feature
                                              ), // edit feature
                                              SizedBox(width: ResponsiveHelper.spacing(context, 4)), // edit feature
                                              Text( // edit feature
                                                'Edit Photo', // edit feature
                                                style: TextStyle( // edit feature
                                                  fontSize: 11, // edit feature
                                                  color: Colors.grey[700], // edit feature
                                                ), // edit feature
                                              ), // edit feature
                                            ], // edit feature
                                          ), // edit feature
                                        ), // edit feature
                                      ), // edit feature
                                    ],
                                    //OBXTEST
                                    // edit feature: Post edit input UI
                                    Obx(() => showPostEditInput.value ? Container( // edit feature
                                      margin: EdgeInsets.only(top: ResponsiveHelper.spacing(context, 16)), // edit feature
                                      padding: ResponsiveHelper.padding(context, all: 16), // edit feature
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
                                            'Edit Photo', // edit feature
                                            style: ResponsiveHelper.textStyle( // edit feature
                                              context, // edit feature
                                              fontSize: ResponsiveHelper.fontSize(context, mobile: 14), // edit feature
                                              fontWeight: FontWeight.bold, // edit feature
                                              color: const Color(0xFF1976D2), // edit feature
                                            ), // edit feature
                                          ), // edit feature
                                          SizedBox(height: ResponsiveHelper.spacing(context, 12)), // edit feature
                                          TextField( // edit feature
                                            controller: postEditTitleController, // edit feature
                                            decoration: InputDecoration( // edit feature
                                              labelText: 'Title (optional)', // edit feature
                                              border: OutlineInputBorder( // edit feature
                                                borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)), // edit feature
                                              ), // edit feature
                                              contentPadding: ResponsiveHelper.padding(context, horizontal: 12, vertical: 12), // edit feature
                                            ), // edit feature
                                            maxLines: 2, // edit feature
                                            style: TextStyle( // edit feature
                                              fontSize: 13, // edit feature
                                            ), // edit feature
                                          ), // edit feature
                                          SizedBox(height: ResponsiveHelper.spacing(context, 12)), // edit feature
                                          TextField( // edit feature
                                            controller: postEditDescriptionController, // edit feature
                                            decoration: InputDecoration( // edit feature
                                              labelText: 'Testimony', // edit feature
                                              border: OutlineInputBorder( // edit feature
                                                borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)), // edit feature
                                              ), // edit feature
                                              contentPadding: ResponsiveHelper.padding(context, horizontal: 12, vertical: 12), // edit feature
                                            ), // edit feature
                                            maxLines: 5, // edit feature
                                            style: TextStyle( // edit feature
                                              fontSize: 13, // edit feature
                                            ), // edit feature
                                          ), // edit feature
                                          SizedBox(height: ResponsiveHelper.spacing(context, 12)), // edit feature
                                          TextField( // edit feature
                                            controller: postEditCategoryController, // edit feature
                                            decoration: InputDecoration( // edit feature
                                              labelText: 'Category (optional)', // edit feature
                                              border: OutlineInputBorder( // edit feature
                                                borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)), // edit feature
                                              ), // edit feature
                                              contentPadding: ResponsiveHelper.padding(context, horizontal: 12, vertical: 12), // edit feature
                                            ), // edit feature
                                            style: TextStyle( // edit feature
                                              fontSize: 13, // edit feature
                                            ), // edit feature
                                          ), // edit feature
                                          SizedBox(height: ResponsiveHelper.spacing(context, 12)), // edit feature
                                          Row( // edit feature
                                            mainAxisAlignment: MainAxisAlignment.end, // edit feature
                                            children: [ // edit feature
                                              TextButton( // edit feature
                                                onPressed: () { // edit feature
                                                  showPostEditInput.value = false; // edit feature
                                                }, // edit feature
                                                child: Text( // edit feature
                                                  'Cancel', // edit feature
                                                  style: TextStyle( // edit feature
                                                    fontSize: 12, // edit feature
                                                    color: Colors.grey[600], // edit feature
                                                  ), // edit feature
                                                ), // edit feature
                                              ), // edit feature
                                              SizedBox(width: ResponsiveHelper.spacing(context, 8)), // edit feature
                                              ElevatedButton( // edit feature
                                                onPressed: () => _editPost(photo['id'] as int), // edit feature
                                                style: ElevatedButton.styleFrom( // edit feature
                                                  backgroundColor: const Color(0xFF2196F3), // edit feature
                                                  padding: ResponsiveHelper.padding( // edit feature
                                                    context, // edit feature
                                                    horizontal: 16, // edit feature
                                                    vertical: 8, // edit feature
                                                  ), // edit feature
                                                ), // edit feature
                                                child: Obx(() => isEditingPost.value // edit feature
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
                                                  style: TextStyle( // edit feature
                                                    fontSize: 12, // edit feature
                                                    color: Colors.white, // edit feature
                                                  ), // edit feature
                                                )), // edit feature
                                              ), // edit feature
                                            ], // edit feature
                                          ), // edit feature
                                        ], // edit feature
                                      ), // edit feature
                                    ) : const SizedBox.shrink()), // edit feature
                                    SizedBox(height: ResponsiveHelper.spacing(
                                        context, 16)),

                                    // Fruits Section - Prominent Display (Social Media Style)
                                    if (photo['fruit_tag'] != null &&
                                        (photo['fruit_tag'] as String)
                                            .isNotEmpty) ...[
                                      Container(
                                        margin: EdgeInsets.only(
                                            bottom: ResponsiveHelper.spacing(
                                                context, 16)),
                                        padding: ResponsiveHelper.padding(
                                            context, all: 16),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              const Color(0xFF8B4513)
                                                  .withOpacity(0.1),
                                              const Color(0xFF8B4513)
                                                  .withOpacity(0.05),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(
                                              ResponsiveHelper.borderRadius(
                                                  context, mobile: 16,
                                                  tablet: 18,
                                                  desktop: 20)),
                                          border: Border.all(
                                            color: const Color(0xFF8B4513)
                                                .withOpacity(0.3),
                                            width: 1.5,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF8B4513)
                                                  .withOpacity(0.1),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          children: [
                                            // Fruit Icon/Emoji
                                            Container(
                                              width: ResponsiveHelper.iconSize(
                                                  context, mobile: 48,
                                                  tablet: 52,
                                                  desktop: 56),
                                              height: ResponsiveHelper.iconSize(
                                                  context, mobile: 48,
                                                  tablet: 52,
                                                  desktop: 56),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF8B4513)
                                                    .withOpacity(0.15),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: const Color(0xFF8B4513)
                                                      .withOpacity(0.3),
                                                  width: 2,
                                                ),
                                              ),
                                              child: Icon(
                                                Icons.local_florist_rounded,
                                                size: ResponsiveHelper.iconSize(
                                                    context, mobile: 28,
                                                    tablet: 30,
                                                    desktop: 32),
                                                color: AppTheme.iconscolor,
                                              ),
                                            ),
                                            SizedBox(
                                                width: ResponsiveHelper.spacing(
                                                    context, 12)),
                                            // Fruit Tag Text
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment
                                                    .start,
                                                children: [
                                                  Text(
                                                    'Fruit of the Spirit',
                                                    style: ResponsiveHelper
                                                        .textStyle(
                                                      context,
                                                      fontSize: ResponsiveHelper
                                                          .fontSize(
                                                          context, mobile: 11,
                                                          tablet: 12,
                                                          desktop: 13),
                                                      color: const Color(
                                                          0xFF8B4513)
                                                          .withOpacity(0.7),
                                                      fontWeight: FontWeight
                                                          .w500,
                                                    ),
                                                  ),
                                                  SizedBox(
                                                      height: ResponsiveHelper
                                                          .spacing(context, 2)),
                                                  Text(
                                                    photo['fruit_tag'] as String,
                                                    style: ResponsiveHelper
                                                        .textStyle(
                                                      context,
                                                      fontSize: ResponsiveHelper
                                                          .fontSize(
                                                          context, mobile: 18,
                                                          tablet: 20,
                                                          desktop: 22),
                                                      fontWeight: FontWeight
                                                          .bold,
                                                      color: AppTheme
                                                          .iconscolor,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // Arrow Icon
                                            Icon(
                                              Icons.arrow_forward_ios_rounded,
                                              size: ResponsiveHelper.iconSize(
                                                  context, mobile: 16,
                                                  tablet: 18,
                                                  desktop: 20),
                                              color: const Color(0xFF8B4513)
                                                  .withOpacity(0.6),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],

                                    // Action Buttons Section (Like, Share, Comment) - Social Media Style
                                    SizedBox(height: ResponsiveHelper.spacing(
                                        context, 16)),
                                    Container(
                                      padding: ResponsiveHelper.padding(
                                          context, vertical: 12,
                                          horizontal: 16),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(
                                            ResponsiveHelper.borderRadius(
                                                context, mobile: 16)),
                                        border: Border.all(
                                          color: Colors.grey.withOpacity(0.2),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment
                                            .spaceAround,
                                        children: [
                                          // Like Button
                                          Obx(() {
                                            final isLiked = controller
                                                .selectedPhoto['is_liked'] ==
                                                true || controller
                                                .selectedPhoto['is_liked'] == 1;
                                            final likeCount = controller
                                                .selectedPhoto['like_count'] as int? ??
                                                0;
                                            return InkWell(
                                              onTap: () async {
                                                final success = await controller
                                                    .toggleLike(photoId);
                                                if (success) {
                                                  // Reload photo details to get updated like status
                                                  await controller
                                                      .loadPhotoDetails(
                                                      photoId);
                                                  // Show success message (brief)
                                                  if (mounted) {
                                                    WidgetsBinding.instance
                                                        .addPostFrameCallback((
                                                        _) {
                                                      if (mounted) {
                                                        _showCustomSnackbar(
                                                          'Success',
                                                          'Like updated',
                                                        );
                                                      }
                                                    });
                                                  }
                                                } else {
                                                  // Show error message
                                                  if (mounted) {
                                                    WidgetsBinding.instance
                                                        .addPostFrameCallback((
                                                        _) {
                                                      if (mounted) {
                                                        _showCustomSnackbar(
                                                          'Error',
                                                          controller.message
                                                              .value.isNotEmpty
                                                              ? controller
                                                              .message.value
                                                              : 'Failed to update like. Please try again.',
                                                          isError: true,
                                                        );
                                                      }
                                                    });
                                                  }
                                                }
                                              },
                                              borderRadius: BorderRadius
                                                  .circular(
                                                  ResponsiveHelper.borderRadius(
                                                      context, mobile: 12)),
                                              child: Padding(
                                                padding: ResponsiveHelper
                                                    .padding(context, all: 8),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize
                                                      .min,
                                                  children: [
                                                    Icon(
                                                      isLiked
                                                          ? Icons.favorite
                                                          : Icons
                                                          .favorite_border,
                                                      color: isLiked ? Colors
                                                          .red : Colors
                                                          .grey[600],
                                                      size: ResponsiveHelper
                                                          .iconSize(
                                                          context, mobile: 24),
                                                    ),
                                                    SizedBox(
                                                        width: ResponsiveHelper
                                                            .spacing(
                                                            context, 6)),
                                                    Text(
                                                      likeCount > 0 ? likeCount
                                                          .toString() : 'Like',
                                                      style: ResponsiveHelper
                                                          .textStyle(
                                                        context,
                                                        fontSize: ResponsiveHelper
                                                            .fontSize(context,
                                                            mobile: 14),
                                                        fontWeight: FontWeight
                                                            .w600,
                                                        color: isLiked ? Colors
                                                            .red : Colors
                                                            .grey[600],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          }),

                                          // Share Button
                                          InkWell(
                                            onTap: () {
                                              final photo = controller
                                                  .selectedPhoto;
                                              final baseUrl = 'http://admin.fosmessenger.com/';
                                              final filePath = photo['file_path'] as String? ??
                                                  '';
                                              final photoUrl = filePath
                                                  .isNotEmpty ? baseUrl +
                                                  filePath : null;

                                              ShareHelper.shareContent(
                                                context: context,
                                                contentType: 'photo',
                                                contentId: photoId,
                                                title: 'Photo from ${photo['user_name'] ??
                                                    'Anonymous'}',
                                                content: photo['testimony'],
                                                mediaUrl: photoUrl,
                                              );
                                            },

                                            borderRadius: BorderRadius.circular(
                                                ResponsiveHelper.borderRadius(
                                                    context, mobile: 12)),
                                            child: Padding(
                                              padding: ResponsiveHelper.padding(
                                                  context, all: 8),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.share_outlined,
                                                    color: Colors.grey[600],
                                                    size: ResponsiveHelper
                                                        .iconSize(
                                                        context, mobile: 24),
                                                  ),
                                                  SizedBox(
                                                      width: ResponsiveHelper
                                                          .spacing(context, 6)),
                                                  Text(
                                                    'Share',
                                                    style: ResponsiveHelper
                                                        .textStyle(
                                                      context,
                                                      fontSize: ResponsiveHelper
                                                          .fontSize(context,
                                                          mobile: 14),
                                                      fontWeight: FontWeight
                                                          .w600,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),

                                          // Comment Button
                                          InkWell(
                                            onTap: () {
                                              // Scroll to comment input
                                              commentController.text = '';
                                              _scrollController.animateTo(
                                                _scrollController.position
                                                    .maxScrollExtent,
                                                duration: const Duration(
                                                    milliseconds: 300),
                                                curve: Curves.easeOut,
                                              );
                                              // Focus comment input after scroll
                                              Future.delayed(const Duration(
                                                  milliseconds: 350), () {
                                                FocusScope
                                                    .of(context)
                                                    .requestFocus(FocusNode());
                                              });
                                            },
                                            borderRadius: BorderRadius.circular(
                                                ResponsiveHelper.borderRadius(
                                                    context, mobile: 12)),
                                            child: Padding(
                                              padding: ResponsiveHelper.padding(
                                                  context, all: 8),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.comment_outlined,
                                                    color: Colors.grey[600],
                                                    size: ResponsiveHelper
                                                        .iconSize(
                                                        context, mobile: 24),
                                                  ),
                                                  SizedBox(
                                                      width: ResponsiveHelper
                                                          .spacing(context, 6)),
                                                  Obx(() =>
                                                      Text(
                                                        '${controller
                                                            .photoComments
                                                            .length}',
                                                        style: ResponsiveHelper
                                                            .textStyle(
                                                          context,
                                                          fontSize: ResponsiveHelper
                                                              .fontSize(context,
                                                              mobile: 14),
                                                          fontWeight: FontWeight
                                                              .w600,
                                                          color: Colors
                                                              .grey[600],
                                                        ),
                                                      )),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(height: ResponsiveHelper.spacing(
                                        context, 16)),

                                    // Emoji Reactions Section (same as prayer_details_screen)
                                    _buildEmojiReactions(
                                        context, photoId, controller),

                                    SizedBox(height: ResponsiveHelper.spacing(
                                        context, 24)),

                                    // Comments Section Header
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment
                                          .spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: EdgeInsets.all(
                                                  ResponsiveHelper.spacing(
                                                      context, 8)),
                                              decoration: BoxDecoration(
                                                gradient: const LinearGradient(
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                  colors: [
                                                    Color(0xFFFFFFFF),
                                                    Color(0xFFFDFDFD),
                                                  ],
                                                ),
                                                borderRadius: BorderRadius
                                                    .circular(
                                                    ResponsiveHelper.isMobile(
                                                        context) ? 12 : 14),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: const Color(
                                                        0xFFEDEDED).withOpacity(
                                                        0.3),
                                                    blurRadius: 6,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: Icon(
                                                Icons
                                                    .chat_bubble_outline_rounded,
                                                color: AppTheme.iconscolor,
                                                size: ResponsiveHelper.fontSize(
                                                    context, mobile: 18),
                                              ),
                                            ),
                                            SizedBox(
                                                width: ResponsiveHelper.spacing(
                                                    context, 12)),
                                            Text(
                                              'Comments',
                                              style: TextStyle(
                                                fontSize: ResponsiveHelper
                                                    .fontSize(
                                                    context, mobile: 20),
                                                fontWeight: FontWeight.bold,
                                                color: const Color(0xFF2C2C2C),
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: ResponsiveHelper
                                                .spacing(context, 12),
                                            vertical: ResponsiveHelper.spacing(
                                                context, 6),
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                const Color(0xFF9F9467)
                                                    .withOpacity(0.15),
                                                const Color(0xFF9F9467)
                                                    .withOpacity(0.1),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(
                                                ResponsiveHelper.isMobile(
                                                    context) ? 12 : 14),
                                            border: Border.all(
                                              color: const Color(0xFF9F9467)
                                                  .withOpacity(0.3),
                                              width: 1,
                                            ),
                                          ),
                                          child: Text(
                                            '${controller.photoComments
                                                .length}',
                                            style: TextStyle(
                                              fontSize: ResponsiveHelper
                                                  .fontSize(
                                                  context, mobile: 14),
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFF9F9467),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: ResponsiveHelper.spacing(
                                        context, 16)),

                                    // Comments List or Empty State - Use Obx for reactive updates
                                    Obx(() {
                                      // Filter out testimony comment if it exists (first comment by same user)
                                      final photoUserId = photo['user_id'] as int?;
                                      final filteredComments = controller
                                          .photoComments.where((comment) {
                                        // If this is the first comment and by the same user as photo owner, it might be testimony
                                        final isFirstComment = controller
                                            .photoComments.indexOf(comment) ==
                                            0;
                                        final isPhotoOwnerComment = comment['user_id'] ==
                                            photoUserId;

                                        // Get testimony text
                                        String? testimonyText = photo['testimony'] as String?;
                                        if ((testimonyText == null ||
                                            testimonyText.isEmpty) &&
                                            controller.photoComments
                                                .isNotEmpty) {
                                          final firstComment = controller
                                              .photoComments.first;
                                          if (firstComment['user_id'] ==
                                              photoUserId) {
                                            testimonyText =
                                            firstComment['content'] as String?;
                                          }
                                        }

                                        // If this comment matches the testimony text, exclude it
                                        if (isFirstComment &&
                                            isPhotoOwnerComment &&
                                            testimonyText != null) {
                                          final commentContent = (comment['content'] as String? ??
                                              '').trim();
                                          if (commentContent ==
                                              testimonyText.trim()) {
                                            return false; // Exclude testimony comment
                                          }
                                        }
                                        return true;
                                      }).toList();

                                      if (filteredComments.isEmpty) {
                                        return Container(
                                          padding: ResponsiveHelper.padding(
                                              context, vertical: 40,
                                              horizontal: 100),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                                ResponsiveHelper.borderRadius(
                                                    context, mobile: 16)),
                                            border: Border.all(
                                              color: Colors.grey.withOpacity(
                                                  0.2),
                                              width: 1,
                                            ),
                                          ),
                                          child: Column(
                                            children: [
                                              Icon(
                                                Icons.comment_outlined,
                                                size: ResponsiveHelper.iconSize(
                                                    context, mobile: 48),
                                                color: Colors.grey[400],
                                              ),
                                              SizedBox(height: ResponsiveHelper
                                                  .spacing(context, 12)),
                                              Text(
                                                'No comments yet',
                                                style: ResponsiveHelper
                                                    .textStyle(
                                                  context,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppTheme.iconscolor,
                                                ),
                                              ),
                                              SizedBox(height: ResponsiveHelper
                                                  .spacing(context, 8)),
                                              Text(
                                                'Be the first to share your thoughts',
                                                style: ResponsiveHelper
                                                    .textStyle(
                                                  context,
                                                  fontSize: 13,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }

                                      return Column(
                                        children: filteredComments
                                            .map((
                                            comment) =>
                                            _buildCommentCard(
                                                context, comment, photoId))
                                            .toList(),
                                      );
                                    },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Comment Input Section (same as prayer_details_screen)
                          Container(
                            padding: ResponsiveHelper.padding(context, all: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, -2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(25),
                                    ),
                                    child: Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.emoji_emotions_outlined,
                                            color: Color(0xFF8B4513),
                                          ),
                                          onPressed: () => _showEmojiPicker(context, photoId, commentController),
                                        ),
                                        Expanded(
                                          child: _buildRichTextInput(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(width: ResponsiveHelper.spacing(
                                    context, 12)),
                                Container(
                                  decoration: BoxDecoration(
                                    color: AppTheme.iconscolor,
                                    borderRadius: BorderRadius.circular(
                                        ResponsiveHelper.borderRadius(
                                            context, mobile: 24)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF8B4513)
                                            .withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: _isSendingComment
                                          ? null
                                          : () async {
                                        if (commentController.text
                                            .trim()
                                            .isEmpty) return;

                                        // FIX: Dismiss keyboard immediately
                                        FocusScope.of(context).unfocus();

                                        setState(() {
                                          _isSendingComment = true;
                                        });

                                        final success = await controller
                                            .addComment(
                                          photoId,
                                          commentController.text.trim(),
                                        );

                                        if (mounted) {
                                          setState(() {
                                            _isSendingComment = false;
                                          });
                                        }

                                        if (success) {
                                          commentController.clear();

                                          // Scroll to bottom to show latest comment
                                          await Future.delayed(const Duration(
                                              milliseconds: 300));
                                          if (_scrollController.hasClients) {
                                            _scrollController.animateTo(
                                              _scrollController.position
                                                  .maxScrollExtent,
                                              duration: const Duration(
                                                  milliseconds: 500),
                                              curve: Curves.easeOut,
                                            );
                                          }
                                          if (mounted) {
                                            _showCustomSnackbar(
                                              'Success',
                                              'Comment added successfully',
                                            );
                                          }
                                        } else {
                                          if (mounted) {
                                            _showCustomSnackbar(
                                              'Error',
                                              controller.message.value,
                                              isError: true,
                                            );
                                          }
                                        }
                                      },
                                      borderRadius: BorderRadius.circular(
                                          ResponsiveHelper.borderRadius(
                                              context, mobile: 24)),
                                      child: Container(
                                        padding: ResponsiveHelper.padding(
                                            context, all: 12),
                                        child: _isSendingComment
                                            ? SizedBox(
                                          width: ResponsiveHelper.iconSize(
                                              context, mobile: 24),
                                          height: ResponsiveHelper.iconSize(
                                              context, mobile: 24),
                                          child: const CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<
                                                Color>(Colors.white),
                                          ),
                                        )
                                            : Icon(
                                          Icons.send,
                                          color: Colors.white,
                                          size: ResponsiveHelper.iconSize(
                                              context, mobile: 24),
                                        ),
                                      ),
                                    ),
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
              );
            }
        );
      }
      )
    );
  }

  /// Build comment card
  Widget _buildCommentCard(BuildContext context, Map<String, dynamic> comment, int photoId) {
    final isLiked = comment['is_liked'] == true || comment['is_liked'] == 1;
    final likeCount = int.tryParse((comment['like_count'] ?? 0).toString()) ?? 0;
    final commentId = comment['id'] as int;
    final content = comment['content'] as String? ?? '';
    final timeAgo = TimeHelper.getTimeAgo(comment['created_at'] as String?);
    
    // Initialize reply controller if not exists
    if (!replyControllers.containsKey(commentId)) {
      replyControllers[commentId] = TextEditingController();
    }
    
    // NOTE: Don't filter emoji comments - display them as regular comments
    // Emoji comments should be shown in the comment list, not just in reactions

    return Container(
      margin: EdgeInsets.only(bottom: ResponsiveHelper.spacing(context, 16)),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              // Profile Photo
            CircleAvatar(
                radius: ResponsiveHelper.iconSize(context, mobile: 20, tablet: 22, desktop: 24) / 2,
                backgroundColor: const Color(0xFFFFD1DC),
                backgroundImage: _getImageProvider(comment['profile_photo'] as String?),
              child: comment['profile_photo'] == null
                  ? Icon(
                      Icons.person,
                        size: ResponsiveHelper.iconSize(context, mobile: 22),
                      color: AppTheme.iconscolor,
                    )
                  : null,
            ),
            SizedBox(width: ResponsiveHelper.spacing(context, 12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                children: [
                  Text(
                    comment['user_name'] as String? ?? 'Anonymous',
                    style: ResponsiveHelper.textStyle(
                      context,
                            fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.iconscolor,
                          ),
                        ),
                        if (timeAgo.isNotEmpty) ...[
                          SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                          Text(
                            '•',
                            style: ResponsiveHelper.textStyle(
                              context,
                              fontSize: 12,
                              color: Colors.grey[400],
                            ),
                          ),
                          SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                          Text(
                            timeAgo,
                            style: ResponsiveHelper.textStyle(
                              context,
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(context, 6)),
                    // Comment Content
                    FruitEmojiHelper.buildCommentText(
                      context,
                      AutoTranslateHelper.getTranslatedTextSync(
                        text: content,
                        sourceLanguage: comment['language'] as String?,
                      ),
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: 14,
                        color: Colors.black87,
                        height: 1.5,
                      ),
                      userEmail: userEmail,
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(context, 12)),
                    // Action Buttons: Like, Reply, Report
                    Row(
                      children: [
                        // Like Button - Use Obx for reactive updates
                        Obx(() {
                          // Reload like status from controller
                          final updatedComment = controller.photoComments.firstWhere(
                            (c) => c['id'] == commentId,
                            orElse: () => comment,
                          );
                          final updatedIsLiked = updatedComment['is_liked'] == true || updatedComment['is_liked'] == 1;
                          final updatedLikeCount = int.tryParse((updatedComment['like_count'] ?? 0).toString()) ?? 0;
                          
                          return InkWell(
                            onTap: () async {
                              final success = await controller.toggleCommentLike(commentId);
                              if (success) {
                                // Comments will reload automatically via Obx
                                await controller.loadPhotoComments(photoId);
                              }
                            },
                            child: Row(
                              children: [
                                Icon(
                                  updatedIsLiked ? Icons.favorite : Icons.favorite_border,
                                  size: ResponsiveHelper.iconSize(context, mobile: 18),
                                  color: updatedIsLiked ? Colors.red : Colors.grey[600],
                                ),
                                if (updatedLikeCount > 0) ...[
                                  SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                                  Text(
                                    '$updatedLikeCount',
                                    style: ResponsiveHelper.textStyle(
                                      context,
                                      fontSize: 13,
                                      color: updatedIsLiked ? Colors.red : Colors.grey[600],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }),
                        SizedBox(width: ResponsiveHelper.spacing(context, 16)),
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
                          child: Row(
                            children: [
                              Icon(
                                Icons.reply,
                                size: ResponsiveHelper.iconSize(context, mobile: 18),
                                color: Colors.grey[600],
                              ),
                              SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                              Text(
                                'Reply',
                                style: ResponsiveHelper.textStyle(
                                  context,
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                              if ((comment['reply_count'] ?? 0) > 0)
                                Text(
                                  ' (${comment['reply_count']})',
                                  style: ResponsiveHelper.textStyle(
                                    context,
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // edit feature: Edit Button
                        _buildEditButton(context, comment, photoId),
                        SizedBox(width: ResponsiveHelper.spacing(context, 16)),
                        // Report Button - Only show for other users' comments
                        if (currentUserId != null && (comment['user_id'] != null && comment['user_id'].toString() != currentUserId.toString()))
                          InkWell(
                            onTap: () => _showReportDialog(context, comment),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.flag_outlined,
                                  size: ResponsiveHelper.iconSize(context, mobile: 18),
                                  color: Colors.grey[600],
                                ),
                                SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                                Text(
                                  'Report',
                                  style: ResponsiveHelper.textStyle(
                                    context,
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Reply Input (if shown)
          if (showReplyInput[commentId] == true) ...[
            SizedBox(height: ResponsiveHelper.spacing(context, 12)),
            _buildReplyInput(context, commentId, photoId),
          ],
          // edit feature: Edit Input (if shown)
          if (showEditInput[commentId] == true) ...[ // edit feature
            SizedBox(height: ResponsiveHelper.spacing(context, 12)), // edit feature
            _buildEditInput(context, commentId, photoId, 'photo'), // edit feature
          ], // edit feature
          // Expand/Collapse button for top-level comment replies
          if (comment['replies'] != null && (comment['replies'] as List).isNotEmpty) ...[
            SizedBox(height: ResponsiveHelper.spacing(context, 8)),
            InkWell(
              onTap: () {
                setState(() {
                  if (expandedReplies.contains(commentId)) {
                    expandedReplies.remove(commentId);
                  } else {
                    expandedReplies.add(commentId);
                  }
                });
              },
              child: Row(
                children: [
                  Icon(
                    expandedReplies.contains(commentId) ? Icons.expand_less : Icons.expand_more,
                    size: ResponsiveHelper.iconSize(context, mobile: 16),
                    color: AppTheme.iconscolor,
                  ),
                  SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                  Text(
                    expandedReplies.contains(commentId) 
                        ? 'Hide ${(comment['replies'] as List).length} ${(comment['replies'] as List).length == 1 ? 'reply' : 'replies'}'
                        : 'Show ${(comment['replies'] as List).length} ${(comment['replies'] as List).length == 1 ? 'reply' : 'replies'}',
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: 12,
                      color: AppTheme.iconscolor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Nested Replies (only show if expanded)
          if (comment['replies'] != null && (comment['replies'] as List).isNotEmpty && expandedReplies.contains(commentId)) ...[
            SizedBox(height: ResponsiveHelper.spacing(context, 12)),
            ...((comment['replies'] as List).map((reply) => _buildReplyCard(context, reply, photoId, depth: 0, parentCommentId: commentId))),
          ],
        ],
      ),
    );
  }

  /// Build reply input widget (same as prayer_details_screen)
  Widget _buildReplyInput(BuildContext context, int parentCommentId, int photoId) {
    if (!replyControllers.containsKey(parentCommentId)) {
      replyControllers[parentCommentId] = TextEditingController();
    }
    // Initialize focus node if not exists
    if (!replyFocusNodes.containsKey(parentCommentId)) {
      replyFocusNodes[parentCommentId] = FocusNode();
    }
    final replyController = replyControllers[parentCommentId]!;
    final replyFocusNode = replyFocusNodes[parentCommentId]!;
    final isSending = _sendingReplies.contains(parentCommentId);
    
    return Container(
      padding: ResponsiveHelper.padding(context, all: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
        border: Border.all(
          color: Colors.grey.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: replyController,
              focusNode: replyFocusNode,
              enabled: !isSending,
              decoration: InputDecoration(
                hintText: 'Write a reply...',
                hintStyle: ResponsiveHelper.textStyle(
                  context,
                  fontSize: 13,
                  color: Colors.grey[400],
                ),
                border: InputBorder.none,
                contentPadding: ResponsiveHelper.padding(
                  context,
                  horizontal: 12,
                  vertical: 8,
                ),
                prefixIcon: IconButton(
                  icon: const Icon(Icons.emoji_emotions_outlined, color: Color(0xFF8B4513)),
                  onPressed: () => _showEmojiPicker(context, photoId, replyController, parentCommentId: parentCommentId),
                ),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _handleSendReply(photoId, parentCommentId, replyController),
              style: ResponsiveHelper.textStyle(context, fontSize: 13),
            ),
          ),
          SizedBox(width: ResponsiveHelper.spacing(context, 8)),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isSending ? null : () => _handleSendReply(photoId, parentCommentId, replyController),
              borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 20)),
              child: Container(
                padding: ResponsiveHelper.padding(context, all: 8),
                decoration: BoxDecoration(
                  color: isSending ? Colors.grey : AppTheme.iconscolor,
                  borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 20)),
                ),
                child: isSending
                    ? SizedBox(
                        width: ResponsiveHelper.iconSize(context, mobile: 18),
                        height: ResponsiveHelper.iconSize(context, mobile: 18),
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Icon(
                        Icons.send,
                        color: Colors.white,
                        size: ResponsiveHelper.iconSize(context, mobile: 18),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Handle sending reply (same as prayer_details_screen)
  Future<void> _handleSendReply(int photoId, int parentCommentId, TextEditingController replyController) async {
    if (replyController.text.trim().isEmpty) return;
    
    // FIX: Dismiss keyboard immediately
    FocusScope.of(context).unfocus();
    
    setState(() {
      _sendingReplies.add(parentCommentId);
    });
    
    try {
      final success = await controller.addComment(
        photoId,
        replyController.text.trim(),
        parentCommentId: parentCommentId,
      );
      
      if (success) {
        replyController.clear();
        setState(() {
          showReplyInput[parentCommentId] = false;
          // Auto-expand parent to show the new reply
          expandedReplies.add(parentCommentId);
        });
        
        await controller.loadPhotoComments(photoId);
        setState(() {}); // Refresh UI
        
        if (mounted) {
          _showCustomSnackbar(
            'Success',
            'Reply added successfully',
          );
        }
      } else {
        if (mounted) {
          _showCustomSnackbar(
            'Error',
            controller.message.value,
            isError: true,
          );
        }
      }
    } finally {
      setState(() {
        _sendingReplies.remove(parentCommentId);
      });
    }
  }

  /// Build reply card widget
  Widget _buildReplyCard(BuildContext context, Map<String, dynamic> reply, int photoId, {int depth = 0, int? parentCommentId}) {
    final content = reply['content'] as String? ?? '';
    final timeAgo = TimeHelper.getTimeAgo(reply['created_at'] as String?);
    final replyId = reply['id'] as int;
    final isLiked = reply['is_liked'] == true || reply['is_liked'] == 1;
    final likeCount = int.tryParse((reply['like_count'] ?? 0).toString()) ?? 0;
    
    // Get parent comment ID from reply data if not provided
    if (parentCommentId == null) {
      parentCommentId = reply['parent_comment_id'] as int?;
    }
    
    // Initialize reply controller if not exists
    if (!replyControllers.containsKey(replyId)) {
      replyControllers[replyId] = TextEditingController();
    }
    
    // Calculate left margin based on depth (each level adds 40px)
    final leftMargin = 40.0 + (depth * 40.0);
    
    return Container(
      margin: EdgeInsets.only(left: leftMargin, top: ResponsiveHelper.spacing(context, 8), bottom: ResponsiveHelper.spacing(context, 8)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thread line
          Container(
            width: 2,
            height: 60,
            color: const Color(0xFF8B4513).withOpacity(0.3),
            margin: EdgeInsets.only(right: ResponsiveHelper.spacing(context, 12)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: ResponsiveHelper.iconSize(context, mobile: 16) / 2,
                      backgroundColor: const Color(0xFFFFD1DC),
                      backgroundImage: _getImageProvider(reply['profile_photo'] as String?),
                      child: reply['profile_photo'] == null
                          ? Icon(
                              Icons.person,
                              size: ResponsiveHelper.iconSize(context, mobile: 16),
                              color: AppTheme.iconscolor,
                            )
                          : null,
                    ),
                    SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                reply['user_name'] as String? ?? 'Anonymous',
                                style: ResponsiveHelper.textStyle(
                                  context,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.iconscolor,
                                ),
                              ),
                              if (timeAgo.isNotEmpty) ...[
                                SizedBox(width: ResponsiveHelper.spacing(context, 6)),
                                Text(
                                  '•',
                                  style: ResponsiveHelper.textStyle(
                                    context,
                                    fontSize: 11,
                                    color: Colors.grey[400],
                                  ),
                                ),
                                SizedBox(width: ResponsiveHelper.spacing(context, 6)),
                                Text(
                                  timeAgo,
                                  style: ResponsiveHelper.textStyle(
                                    context,
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          SizedBox(height: ResponsiveHelper.spacing(context, 4)),
                          FruitEmojiHelper.buildCommentText(
                            context,
                            AutoTranslateHelper.getTranslatedTextSync(
                              text: content,
                              sourceLanguage: reply['language'] as String?,
                            ),
                            style: ResponsiveHelper.textStyle(
                              context,
                              fontSize: 13,
                              color: Colors.black87,
                              height: 1.4,
                            ),
                          ),
                          SizedBox(height: ResponsiveHelper.spacing(context, 8)),
                          Row(
                            children: [
                              Obx(() {
                                // Get updated reply data from controller
                                // parentCommentId might be null, so find parent comment
                                int? actualParentId = parentCommentId ?? reply['parent_comment_id'] as int?;
                                if (actualParentId == null) {
                                  // Try to find parent by searching all comments
                                  for (var comment in controller.photoComments) {
                                    final replies = comment['replies'] as List? ?? [];
                                    if (replies.any((r) => r['id'] == replyId)) {
                                      actualParentId = comment['id'] as int?;
                                      break;
                                    }
                                  }
                                }
                                
                                final parentComment = actualParentId != null
                                    ? controller.photoComments.firstWhere(
                                        (c) => c['id'] == actualParentId,
                                        orElse: () => <String, dynamic>{},
                                      )
                                    : <String, dynamic>{};
                                final replies = parentComment['replies'] as List? ?? [];
                                final updatedReply = replies.firstWhere(
                                  (r) => r['id'] == replyId,
                                  orElse: () => reply,
                                );
                                final updatedIsLiked = updatedReply['is_liked'] == true || updatedReply['is_liked'] == 1;
                                final updatedLikeCount = int.tryParse((updatedReply['like_count'] ?? 0).toString()) ?? 0;
                                
                                return InkWell(
                                  onTap: () async {
                                    final success = await controller.toggleCommentLike(replyId);
                                    if (success) {
                                      await controller.loadPhotoComments(photoId);
                                    }
                                  },
                                  child: Row(
                                    children: [
                                      Icon(
                                        updatedIsLiked ? Icons.favorite : Icons.favorite_border,
                                        size: ResponsiveHelper.iconSize(context, mobile: 14),
                                        color: updatedIsLiked ? Colors.red : Colors.grey[600],
                                      ),
                                      if (updatedLikeCount > 0) ...[
                                        SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                                        Text(
                                          '$updatedLikeCount',
                                          style: ResponsiveHelper.textStyle(
                                            context,
                                            fontSize: 12,
                                            color: updatedIsLiked ? Colors.red : Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              }),
                              SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    // Close all other reply inputs first
                                    showReplyInput.clear();

                                    // Toggle current reply input
                                    showReplyInput[replyId] = true;
                                  });
                                },
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.reply,
                                      size: ResponsiveHelper.iconSize(context, mobile: 14),
                                      color: Colors.grey[600],
                                    ),
                                    SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                                    Text(
                                      'Reply',
                                      style: ResponsiveHelper.textStyle(
                                        context,
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                              if (currentUserId != null && (reply['user_id'] != null && reply['user_id'].toString() != currentUserId.toString()))
                                InkWell(
                                  onTap: () => _showReportDialog(context, reply),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.flag_outlined,
                                        size: ResponsiveHelper.iconSize(context, mobile: 14),
                                        color: Colors.grey[600],
                                      ),
                                      SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                                      Text(
                                        'Report',
                                        style: ResponsiveHelper.textStyle(
                                          context,
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Nested reply input
                if (showReplyInput[replyId] == true) ...[
                  SizedBox(height: ResponsiveHelper.spacing(context, 8)),
                  _buildReplyInput(context, replyId, photoId),
                ],
                // Recursive nested replies
                if (reply['replies'] != null && (reply['replies'] as List).isNotEmpty) ...[
                  ...((reply['replies'] as List).map((nestedReply) => _buildReplyCard(context, nestedReply, photoId, depth: depth + 1, parentCommentId: parentCommentId ?? replyId))),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Show report dialog
  void _showReportDialog(BuildContext context, Map<String, dynamic> comment) {
    final reasons = [
      'Spam',
      'Harassment',
      'Hate speech',
      'Inappropriate content',
      'Other',
    ];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Report Comment',
          style: ResponsiveHelper.textStyle(
            context,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF8B4513),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (comment['user_id'] != null && comment['user_id'].toString() != currentUserId.toString()) ...[
              ...reasons.map((reason) {
                return ListTile(
                  title: Text(reason),
                  dense: true,
                  onTap: () async {
                    Navigator.pop(context);
                    final success = await controller.reportComment(comment['id'] as int, reason);
                    if (success) {
                      if (mounted) {
                      _showCustomSnackbar(
                        'Success',
                        'Comment reported successfully',
                      );
                    }
                    } else {
                      if (mounted) {
                        _showCustomSnackbar(
                          'Error',
                          controller.message.value,
                          isError: true,
                        );
                      }
                    }
                  },
                );
              }).toList(),
              const Divider(),
              TextButton.icon(
                onPressed: () async {
                  final userIdRaw = comment['user_id'];
                  if (userIdRaw != null) {
                    final userId = userIdRaw is int ? userIdRaw : int.tryParse(userIdRaw.toString());
                    if (userId == null) return;
                    
                    if (currentUserId == userId) {
                      if (mounted) {
                        _showCustomSnackbar(
                          'Info',
                          'You cannot block yourself',
                        );
                      }
                      return;
                    }

                    final userName = comment['user_name'] ?? 'this user';
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('Block $userName?'),
                        content: const Text('You will no longer see content from this user.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Block', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );

                    if (confirmed == true) {
                      try {
                        if (currentUserId != null) {
                          await UserBlockingService.blockUser(userId);
                          if (mounted) {
                            Navigator.of(context).pop();
                            _showCustomSnackbar(
                              'Success',
                              'User blocked',
                            );
                            final currentPhotoId = controller.selectedPhoto['id'] is int ? controller.selectedPhoto['id'] : int.parse(controller.selectedPhoto['id'].toString());
                            controller.loadPhotoComments(currentPhotoId);
                          }
                        }
                      } catch (e) {
                        if (mounted) {
                          _showCustomSnackbar(
                            'Error',
                            'Failed to block user',
                            isError: true,
                          );
                        }
                      }
                    }
                  }
                },
                icon: const Icon(Icons.block, color: Colors.red, size: 20),
                label: const Text('Block User', style: TextStyle(color: Colors.red)),
              ),
            ] else 
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('This is your own comment.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: ResponsiveHelper.textStyle(
                context,
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoOptions(BuildContext context, Map<String, dynamic> photo) {
    final userIdRaw = photo['user_id'];
    final posterId = userIdRaw is int ? userIdRaw : int.tryParse(userIdRaw?.toString() ?? '');
    
    // Check if we have any options to show
    final hasOptions = posterId != null && posterId != currentUserId;
    
    // Only show the PopupMenuButton if there are options
    if (!hasOptions) {
      return SizedBox(width: ResponsiveHelper.iconSize(context, mobile: 40)); // Empty placeholder for alignment
    }
    
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: Colors.grey[400]),
      onSelected: (value) async {
        if (value == 'report') {
          await ReportUtils.handleReportButtonTap(
            context: context,
            contentType: 'gallery',
            contentId: photo['id'] is int ? photo['id'] : int.parse(photo['id'].toString()),
          );
        } else if (value == 'block') {
          final userIdRaw = photo['user_id'];
          if (userIdRaw != null) {
            final userId = userIdRaw is int ? userIdRaw : int.tryParse(userIdRaw.toString());
            if (userId == null) return;

            if (currentUserId == userId) {
              if (mounted) {
              _showCustomSnackbar(
                'Info',
                'You cannot block yourself',
              );
            }
              return;
            }

            final userName = photo['user_name'] ?? 'this user';
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
                if (currentUserId != null) {
                  await UserBlockingService.blockUser(userId);
                  if (mounted) {
                    _showCustomSnackbar(
                      'Success',
                      'User blocked',
                    );
                    Navigator.of(context).pop(); // Back to gallery
                  }
                }
              } catch (e) {
                if (mounted) {
                  _showCustomSnackbar(
                    'Error',
                    'Failed to block user',
                    isError: true,
                  );
                }
              }
            }
          }
        }
      },
      itemBuilder: (context) {
        final List<PopupMenuEntry<String>> items = [];
        
        // Only show options if it's NOT the current user's photo
        if (posterId != null && posterId != currentUserId) {
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

  /// Build Emoji Reactions Section (same as prayer_details_screen)
  Widget _buildEmojiReactions(BuildContext context, int photoId, GalleryController controller) {
    // Use Obx exactly like prayers - it automatically rebuilds when photoEmojiReactions changes
    return Obx(() {
        final reactions = controller.photoEmojiReactions;
        final hasReactions = reactions.isNotEmpty;
        final quickEmojisList = controller.quickEmojis;
        
        // Debug logging with GALLERY EMOJI prefix
        if (kDebugMode) debugPrint('🍎 GALLERY EMOJI: 🔍 _buildEmojiReactions called (Obx rebuild)');
        if (kDebugMode) debugPrint('🍎 GALLERY EMOJI:   - hasReactions: $hasReactions');
        if (kDebugMode) debugPrint('🍎 GALLERY EMOJI:   - reactions count: ${reactions.length}');
        if (kDebugMode) debugPrint('🍎 GALLERY EMOJI:   - quickEmojisList count: ${quickEmojisList.length}');
        if (hasReactions) {
          if (kDebugMode) debugPrint('🍎 GALLERY EMOJI: 📋 ALL REACTIONS IN MAP:');
          reactions.forEach((key, users) {
            if (kDebugMode) debugPrint('🍎 GALLERY EMOJI:   - Emoji key: "$key" (${users.length} users)');
            if (users.isNotEmpty) {
              if (kDebugMode) debugPrint('🍎 GALLERY EMOJI:     - Users: ${users.map((u) => u['user_name']).join(", ")}');
            }
          });
          if (kDebugMode) debugPrint('🍎 GALLERY EMOJI: 📊 Total unique emoji types: ${reactions.length}');
          if (kDebugMode) debugPrint('🍎 GALLERY EMOJI: 📊 Will display ${reactions.length} different emoji reactions');
        } else {
          if (kDebugMode) debugPrint('🍎 GALLERY EMOJI: ⚠️ No reactions found - reactions map is empty');
        }
      
      return Container(
        padding: ResponsiveHelper.padding(
          context,
          all: ResponsiveHelper.isMobile(context) ? 16 : 20,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ResponsiveHelper.isMobile(context) ? 18 : 20),
          border: Border.all(
            color: Colors.grey.withOpacity(0.12),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: ResponsiveHelper.isMobile(context) ? 10 : 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 8)),
                  decoration: BoxDecoration(
                    color: AppTheme.iconscolor,
                    borderRadius: BorderRadius.circular(ResponsiveHelper.isMobile(context) ? 10 : 12),
                  ),
                  child: Icon(
                    Icons.volunteer_activism_rounded,
                    color: Colors.white,
                    size: ResponsiveHelper.fontSize(context, mobile: 18),
                  ),
                ),
                SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Show Your Support',
                        style: TextStyle(
                          fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2C2C2C),
                        ),
                      ),
                      SizedBox(height: ResponsiveHelper.spacing(context, 2)),
                      Text(
                        'Express your encouragement with emojis',
                        style: TextStyle(
                          fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 16)),
            
            // Quick Emoji Buttons
            Wrap(
              spacing: ResponsiveHelper.spacing(context, 6),
              runSpacing: ResponsiveHelper.spacing(context, 6),
              children: [
                if (quickEmojisList.isEmpty)
                  Padding(
                    padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 8)),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: const Color(0xFF9F9467),
                      ),
                    ),
                  )
                else
                  ...quickEmojisList.map((emojiData) {
                    // Use same priority as story screen: emoji_char -> code -> name
                    String? emoji = emojiData['emoji_char'] as String?;
                    if (emoji == null || emoji.trim().isEmpty) {
                      emoji = emojiData['code'] as String?;
                    }
                    if (emoji == null || emoji.trim().isEmpty) {
                      final name = emojiData['name'] as String? ?? '';
                      if (name.isNotEmpty) {
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
                    
                    final isValidEmoji = emoji != null && emoji.trim().isNotEmpty;
                    
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: isValidEmoji ? () async {
                          FocusScope.of(context).unfocus(); // Dismiss keyboard when emoji is tapped
                          if (kDebugMode) debugPrint('🍎 GALLERY EMOJI: ========== EMOJI SELECTION START ==========');
                          if (kDebugMode) debugPrint('🍎 GALLERY EMOJI: User tapped quick emoji: $emoji');
                          if (kDebugMode) debugPrint('🍎 GALLERY EMOJI:   - emojiData: name=${emojiData['name']}, id=${emojiData['id']}');
                          if (kDebugMode) debugPrint('🍎 GALLERY EMOJI:   - emojiData code: ${emojiData['code']}');
                          if (kDebugMode) debugPrint('🍎 GALLERY EMOJI:   - emojiData image_url: ${emojiData['image_url']}');
                          if (kDebugMode) debugPrint('🍎 GALLERY EMOJI:   - emojiData emoji_char: ${emojiData['emoji_char']}');
                          
                          // Determine the best emoji value to send to API
                          // Priority: code > image_url > emoji_char > name
                          String? emojiValueToSend;
                          
                          // Priority 1: Use code if available (best for API matching)
                          final emojiCode = emojiData['code'] as String?;
                          if (emojiCode != null && emojiCode.toString().trim().isNotEmpty) {
                            emojiValueToSend = emojiCode.toString().trim();
                            if (kDebugMode) debugPrint('🍎 GALLERY EMOJI: ✅ SELECTED: Using emoji code: $emojiValueToSend');
                          }
                          // Priority 2: Use image_url if code is not available
                          else {
                            final emojiImageUrl = emojiData['image_url'] as String?;
                            if (emojiImageUrl != null && emojiImageUrl.toString().trim().isNotEmpty) {
                              emojiValueToSend = emojiImageUrl.toString().trim();
                              if (kDebugMode) debugPrint('🍎 GALLERY EMOJI: ✅ SELECTED: Using emoji image_url: $emojiValueToSend');
                            }
                            // Priority 3: Use emoji_char
                            else if (emoji != null && emoji.trim().isNotEmpty) {
                              emojiValueToSend = emoji.trim();
                              if (kDebugMode) debugPrint('🍎 GALLERY EMOJI: ✅ SELECTED: Using emoji_char: $emojiValueToSend');
                            }
                            // Priority 4: Fallback to name
                            else {
                              final emojiName = emojiData['name'] as String?;
                              if (emojiName != null && emojiName.toString().trim().isNotEmpty) {
                                emojiValueToSend = emojiName.toString().trim();
                                if (kDebugMode) debugPrint('🍎 GALLERY EMOJI: ✅ SELECTED: Using emoji name: $emojiValueToSend');
                              }
                            }
                          }
                          
                          if (emojiValueToSend == null || emojiValueToSend.isEmpty) {
                            if (kDebugMode) debugPrint('🍎 GALLERY EMOJI: ❌ ERROR: Could not determine emoji value to send');
                            if (mounted) {
                              _showCustomSnackbar(
                                'Error',
                                'Invalid emoji data. Please try again.',
                                isError: true,
                              );
                            }
                            return;
                          }
                          
                          // Send emoji directly as comment (no text box)
                          final content = commentController.text;
                          commentController.text = emojiValueToSend;
                          await controller.addComment(photoId, emojiValueToSend);
                          commentController.text = content;
                        } : null,
                        borderRadius: BorderRadius.circular(ResponsiveHelper.isMobile(context) ? 40 : 44),
                        child: Padding(
                          padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 4)),
                          child: SizedBox(
                            width: ResponsiveHelper.isMobile(context) ? 44 : 48,
                            height: ResponsiveHelper.isMobile(context) ? 44 : 48,
                            child: HomeScreen.buildEmojiDisplay(
                              context,
                              emojiData,
                              size: ResponsiveHelper.isMobile(context) ? 44 : 48,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                // More Emojis Button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showEmojiPicker(context, photoId, commentController),
                    borderRadius: BorderRadius.circular(ResponsiveHelper.isMobile(context) ? 40 : 44),
                    child: Padding(
                      padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 4)),
                      child: Container(
                        width: ResponsiveHelper.isMobile(context) ? 44 : 48,
                        height: ResponsiveHelper.isMobile(context) ? 44 : 48,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.add_reaction_rounded,
                          size: ResponsiveHelper.fontSize(context, mobile: 22),
                          color: AppTheme.iconscolor,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            // Display Reactions Count - Phone Style with Actual Emojis
            if (hasReactions) ...[
              SizedBox(height: ResponsiveHelper.spacing(context, 20)),
              Row(
                children: [
                  // Show first emoji from reactions instead of heart icon
                  if (reactions.isNotEmpty) ...[
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: Builder(
                        builder: (context) {
                          final firstReaction = reactions.entries.first;
                          final emojiChar = firstReaction.key;
                          Map<String, dynamic>? fruitEmoji;
                          
                          // Find matching emoji with improved matching
                          final normalizedKey = emojiChar.trim().toLowerCase();
                          for (var emoji in controller.availableEmojis) {
                            final emojiCharFromList = (emoji['emoji_char'] as String? ?? '').trim();
                            final emojiCodeFromList = (emoji['code'] as String? ?? '').trim().toLowerCase();
                            final emojiNameFromList = (emoji['name'] as String? ?? '').toLowerCase();
                            
                            // Match by emoji_char
                            if (emojiCharFromList.isNotEmpty && 
                                (emojiCharFromList.toLowerCase() == normalizedKey || emojiCharFromList == emojiChar.trim())) {
                              fruitEmoji = emoji;
                              break;
                            }
                            // Match by code
                            if (emojiCodeFromList.isNotEmpty && emojiCodeFromList == normalizedKey) {
                              fruitEmoji = emoji;
                              break;
                            }
                            // Match by name (extract base name)
                            if (emojiNameFromList.isNotEmpty) {
                              String baseName = emojiNameFromList;
                              if (baseName.contains(':')) {
                                final parts = baseName.split(':');
                                if (parts.length > 1) {
                                  baseName = parts[1].trim();
                                }
                              }
                              if (baseName.contains(' ')) {
                                baseName = baseName.split(' ')[0].trim();
                              }
                              if (baseName == normalizedKey || baseName.contains(normalizedKey)) {
                                fruitEmoji = emoji;
                                break;
                              }
                            }
                          }
                          
                          // If still not found, try partial match
                          if (fruitEmoji == null) {
                            for (var emoji in controller.availableEmojis) {
                              final emojiCodeFromList = (emoji['code'] as String? ?? '').toLowerCase();
                              final emojiNameFromList = (emoji['name'] as String? ?? '').toLowerCase();
                              
                              if ((emojiCodeFromList.isNotEmpty && emojiCodeFromList.contains(normalizedKey)) ||
                                  (emojiNameFromList.isNotEmpty && emojiNameFromList.contains(normalizedKey))) {
                                fruitEmoji = emoji;
                                break;
                              }
                            }
                          }
                          
                          if (fruitEmoji != null) {
                            return HomeScreen.buildEmojiDisplay(
                              context,
                              fruitEmoji!,
                              size: 20,
                              userEmail: userEmail,
                            );
                          }
                          return Icon(
                            Icons.favorite_rounded,
                            size: ResponsiveHelper.fontSize(context, mobile: 16),
                            color: AppTheme.iconscolor,
                          );
                        },
                      ),
                    ),
                    SizedBox(width: ResponsiveHelper.spacing(context, 6)),
                  ] else
                    Icon(
                      Icons.favorite_rounded,
                      size: ResponsiveHelper.fontSize(context, mobile: 16),
                      color: AppTheme.iconscolor,
                    ),
                  Text(
                    'Community Support',
                    style: TextStyle(
                      fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2C2C2C),
                    ),
                  ),
                ],
              ),
              SizedBox(height: ResponsiveHelper.spacing(context, 12)),
              // Display all reactions with emoji images
              if (reactions.isNotEmpty) ...[
                Builder(
                  builder: (context) {
                    final entriesList = reactions.entries.toList();
                    if (kDebugMode) debugPrint('🍎 GALLERY EMOJI: 🎨 Building reactions display widget');
                    if (kDebugMode) debugPrint('🍎 GALLERY EMOJI:   - Total reactions entries: ${entriesList.length}');
                    for (var i = 0; i < entriesList.length; i++) {
                      if (kDebugMode) debugPrint('🍎 GALLERY EMOJI:     Entry $i: key="${entriesList[i].key}", users=${entriesList[i].value.length}');
                    }
                    return Wrap(
                      spacing: ResponsiveHelper.spacing(context, 6),
                      runSpacing: ResponsiveHelper.spacing(context, 6),
                      children: entriesList.map((entry) {
                        // Find fruit image for this emoji (can be character, code, image_url, or ID)
                        final emojiKey = entry.key;
                        final usersWhoReacted = entry.value as List<Map<String, dynamic>>;
                        Map<String, dynamic>? fruitEmoji;
                        
                        if (kDebugMode) debugPrint('🍎 GALLERY EMOJI: 🔍 Finding emoji for key: "$emojiKey" (${usersWhoReacted.length} users)');
                  
                  // Try multiple matching strategies (same as prayer screen)
                  for (var emoji in controller.availableEmojis) {
                    final emojiCharFromList = emoji['emoji_char'] as String? ?? '';
                    final emojiCodeFromList = emoji['code'] as String? ?? '';
                    final emojiImageUrlFromList = emoji['image_url'] as String? ?? '';
                    final emojiIdFromList = emoji['id']?.toString() ?? '';
                    
                    // Strategy 1: Match by emoji_char (exact match)
                    if (emojiCharFromList.isNotEmpty && 
                        (emojiCharFromList.trim() == emojiKey.trim() || emojiCharFromList == emojiKey)) {
                      fruitEmoji = emoji;
                      if (kDebugMode) debugPrint('🍎 GALLERY EMOJI: ✅ Matched by emoji_char: "$emojiKey" -> ${emoji['name']}');
                      break;
                    }
                    // Strategy 2: Match by code (exact match)
                    if (emojiCodeFromList.isNotEmpty && 
                        (emojiCodeFromList.trim() == emojiKey.trim() || emojiCodeFromList == emojiKey)) {
                      fruitEmoji = emoji;
                      if (kDebugMode) debugPrint('🍎 GALLERY EMOJI: ✅ Matched by code: "$emojiKey" -> ${emoji['name']}');
                      break;
                    }
                    // Strategy 3: Match by image_url (improved matching for full URLs and relative paths)
                    if (emojiImageUrlFromList.isNotEmpty) {
                      // Normalize both URLs - remove domain, extract relative path
                      String normalizeUrl(String url) {
                        // Remove protocol and domain
                        String normalized = url;
                        if (normalized.contains('://')) {
                          final parts = normalized.split('://');
                          if (parts.length > 1) {
                            final pathParts = parts[1].split('/');
                            if (pathParts.length > 1) {
                              // Get path after domain (e.g., "uploads/emojis/file.png")
                              normalized = pathParts.sublist(1).join('/');
                            }
                          }
                        }
                        // Remove URL encoding
                        normalized = normalized.replaceAll('%20', ' ').toLowerCase();
                        return normalized;
                      }
                      
                      final normalizedKey = normalizeUrl(emojiKey);
                      final normalizedListUrl = normalizeUrl(emojiImageUrlFromList);
                      
                      // Also check if either contains the other (for partial matches)
                      if (normalizedKey == normalizedListUrl || 
                          normalizedKey.contains(normalizedListUrl) ||
                          normalizedListUrl.contains(normalizedKey) ||
                          emojiImageUrlFromList.contains(emojiKey) || 
                          emojiKey.contains(emojiImageUrlFromList)) {
                        fruitEmoji = emoji;
                        if (kDebugMode) debugPrint('🍎 GALLERY EMOJI: ✅ Matched by image_url: "$emojiKey" -> ${emoji['name']}');
                        if (kDebugMode) debugPrint('🍎 GALLERY EMOJI:   - normalizedKey: $normalizedKey');
                        if (kDebugMode) debugPrint('🍎 GALLERY EMOJI:   - normalizedListUrl: $normalizedListUrl');
                        break;
                      }
                      
                      // Also check filename match
                      final keyFilename = emojiKey.split('/').last.replaceAll('%20', ' ').toLowerCase();
                      final listFilename = emojiImageUrlFromList.split('/').last.replaceAll('%20', ' ').toLowerCase();
                      if (keyFilename == listFilename) {
                        fruitEmoji = emoji;
                        if (kDebugMode) debugPrint('🍎 GALLERY EMOJI: ✅ Matched by filename: "$keyFilename" -> ${emoji['name']}');
                        break;
                      }
                    }
                    // Strategy 4: Match by ID
                    if (emojiIdFromList.isNotEmpty && emojiIdFromList == emojiKey) {
                      fruitEmoji = emoji;
                      if (kDebugMode) debugPrint('🍎 GALLERY EMOJI: ✅ Matched by ID: "$emojiKey" -> ${emoji['name']}');
                      break;
                    }
                    // Strategy 5: Match by name (extract base name and compare)
                    final emojiNameFromList = (emoji['name'] as String? ?? '').toLowerCase();
                    if (emojiNameFromList.isNotEmpty) {
                      String baseName = emojiNameFromList;
                      if (baseName.contains(':')) {
                        final parts = baseName.split(':');
                        if (parts.length > 1) {
                          baseName = parts[1].trim();
                        }
                      }
                      if (baseName.contains(' ')) {
                        baseName = baseName.split(' ')[0].trim();
                      }
                      final normalizedKey = emojiKey.trim().toLowerCase();
                      if (baseName == normalizedKey || baseName.contains(normalizedKey) || normalizedKey.contains(baseName)) {
                        fruitEmoji = emoji;
                        if (kDebugMode) debugPrint('🍎 GALLERY EMOJI: ✅ Matched by name: "$emojiKey" -> ${emoji['name']}');
                        break;
                      }
                    }
                  }
                  
                  // If still not found, try partial match (fallback)
                  if (fruitEmoji == null) {
                    if (kDebugMode) debugPrint('🍎 GALLERY EMOJI: ⚠️ Exact match failed, trying partial match...');
                    final normalizedKey = emojiKey.trim().toLowerCase();
                    for (var emoji in controller.availableEmojis) {
                      final emojiCodeFromList = (emoji['code'] as String? ?? '').toLowerCase();
                      final emojiNameFromList = (emoji['name'] as String? ?? '').toLowerCase();
                      final emojiImageUrlFromList = (emoji['image_url'] as String? ?? '').toLowerCase();
                      
                      // Check if emojiKey is contained in code, name, or image_url
                      if ((emojiCodeFromList.isNotEmpty && (emojiCodeFromList == normalizedKey || emojiCodeFromList.contains(normalizedKey) || normalizedKey.contains(emojiCodeFromList))) ||
                          (emojiNameFromList.isNotEmpty && (emojiNameFromList.contains(normalizedKey) || normalizedKey.contains(emojiNameFromList))) ||
                          (emojiImageUrlFromList.isNotEmpty && (emojiImageUrlFromList.contains(normalizedKey) || normalizedKey.contains(emojiImageUrlFromList)))) {
                        fruitEmoji = emoji;
                        if (kDebugMode) debugPrint('🍎 GALLERY EMOJI: ✅ Found emoji by partial match: "$emojiKey" -> ${emoji['name']}');
                        break;
                      }
                    }
                  }
                  
                  // Debug logging if emoji not found
                  if (fruitEmoji == null) {
                    if (kDebugMode) debugPrint('🍎 GALLERY EMOJI: ❌ Emoji not found in availableEmojis: emojiKey="$emojiKey"');
                    if (kDebugMode) debugPrint('🍎 GALLERY EMOJI:   Available emojis count: ${controller.availableEmojis.length}');
                    if (controller.availableEmojis.isNotEmpty) {
                      if (kDebugMode) debugPrint('🍎 GALLERY EMOJI:   Sample emoji: code=${controller.availableEmojis[0]['code']}, emoji_char=${controller.availableEmojis[0]['emoji_char']}, name=${controller.availableEmojis[0]['name']}, image_url=${controller.availableEmojis[0]['image_url']}');
                    }
                  } else {
                    if (kDebugMode) debugPrint('🍎 GALLERY EMOJI: ✅ Emoji found and will be displayed: ${fruitEmoji['name']}');
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
                            width: 28,
                            height: 28,
                            child: HomeScreen.buildEmojiDisplay(
                              context,
                              fruitEmoji,
                              size: 28,
                              userEmail: userEmail,
                            ),
                          )
                        else
                          // Fallback: show placeholder with emoji key
                          Builder(
                            builder: (context) {
                              if (kDebugMode) debugPrint('🍎 GALLERY EMOJI: ⚠️ Using fallback display for emojiKey: "$emojiKey"');
                              // Try to create a minimal emoji data structure from emojiKey
                              // If emojiKey is an image URL, try to extract info
                              final fallbackEmojiData = <String, dynamic>{
                                'emoji_char': emojiKey,
                                'code': emojiKey,
                                'name': emojiKey,
                                'image_url': emojiKey.contains('http') || emojiKey.contains('uploads/') ? emojiKey : null,
                              };
                              return SizedBox(
                                width: 28,
                                height: 28,
                                child: HomeScreen.buildEmojiDisplay(
                                  context,
                                  fallbackEmojiData,
                                  size: 28,
                                  userEmail: userEmail,
                                ),
                              );
                            },
                          ),
                        SizedBox(width: ResponsiveHelper.spacing(context, 6)),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${usersWhoReacted.length}',
                              style: TextStyle(
                                fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
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
                                style: TextStyle(
                                  fontSize: ResponsiveHelper.fontSize(context, mobile: 11),
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
                    );
                  },
                ),
              ] else ...[
                // Show message when no reactions yet
                Padding(
                  padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 12)),
                  child: Text(
                    'No reactions yet. Be the first to react!',
                    style: TextStyle(
                      fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
              
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
                            final emojiChar = entry.key;
                            final usersWhoReacted = entry.value as List<Map<String, dynamic>>;
                            for (var user in usersWhoReacted) {
                              allUsersWithReactions.add({
                                ...user,
                                'reaction_emoji': emojiChar,
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
                              final emojiChar = userData['reaction_emoji'] as String? ?? '';
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
                              // Use improved matching like in the reactions display above
                              Map<String, dynamic>? fruitEmoji;
                              if (kDebugMode) debugPrint('🍎 GALLERY EMOJI: 🔍 Finding emoji for "Who Reacted" section: "$emojiChar"');
                              
                              for (var emoji in controller.availableEmojis) {
                                final emojiCharFromList = emoji['emoji_char'] as String? ?? '';
                                final emojiCodeFromList = emoji['code'] as String? ?? '';
                                final emojiImageUrlFromList = emoji['image_url'] as String? ?? '';
                                final emojiIdFromList = emoji['id']?.toString() ?? '';
                                
                                // Strategy 1: Match by emoji_char
                                if (emojiCharFromList.isNotEmpty && 
                                    (emojiCharFromList.trim() == emojiChar.trim() || emojiCharFromList == emojiChar)) {
                                  fruitEmoji = emoji;
                                  if (kDebugMode) debugPrint('🍎 GALLERY EMOJI: ✅ Matched by emoji_char in "Who Reacted": "$emojiChar" -> ${emoji['name']}');
                                  break;
                                }
                                // Strategy 2: Match by code
                                if (emojiCodeFromList.isNotEmpty && 
                                    (emojiCodeFromList.trim() == emojiChar.trim() || emojiCodeFromList == emojiChar)) {
                                  fruitEmoji = emoji;
                                  if (kDebugMode) debugPrint('🍎 GALLERY EMOJI: ✅ Matched by code in "Who Reacted": "$emojiChar" -> ${emoji['name']}');
                                  break;
                                }
                                // Strategy 3: Match by image_url (improved matching)
                                if (emojiImageUrlFromList.isNotEmpty) {
                                  // Normalize both URLs - remove domain, extract relative path
                                  String normalizeUrl(String url) {
                                    String normalized = url;
                                    if (normalized.contains('://')) {
                                      final parts = normalized.split('://');
                                      if (parts.length > 1) {
                                        final pathParts = parts[1].split('/');
                                        if (pathParts.length > 1) {
                                          normalized = pathParts.sublist(1).join('/');
                                        }
                                      }
                                    }
                                    normalized = normalized.replaceAll('%20', ' ').toLowerCase();
                                    return normalized;
                                  }
                                  
                                  final normalizedKey = normalizeUrl(emojiChar);
                                  final normalizedListUrl = normalizeUrl(emojiImageUrlFromList);
                                  
                                  if (normalizedKey == normalizedListUrl || 
                                      normalizedKey.contains(normalizedListUrl) ||
                                      normalizedListUrl.contains(normalizedKey) ||
                                      emojiImageUrlFromList.contains(emojiChar) || 
                                      emojiChar.contains(emojiImageUrlFromList)) {
                                    fruitEmoji = emoji;
                                    if (kDebugMode) debugPrint('🍎 GALLERY EMOJI: ✅ Matched by image_url in "Who Reacted": "$emojiChar" -> ${emoji['name']}');
                                    break;
                                  }
                                  
                                  // Also check filename match
                                  final keyFilename = emojiChar.split('/').last.replaceAll('%20', ' ').toLowerCase();
                                  final listFilename = emojiImageUrlFromList.split('/').last.replaceAll('%20', ' ').toLowerCase();
                                  if (keyFilename == listFilename) {
                                    fruitEmoji = emoji;
                                    if (kDebugMode) debugPrint('🍎 GALLERY EMOJI: ✅ Matched by filename in "Who Reacted": "$keyFilename" -> ${emoji['name']}');
                                    break;
                                  }
                                }
                                // Strategy 4: Match by ID
                                if (emojiIdFromList.isNotEmpty && emojiIdFromList == emojiChar) {
                                  fruitEmoji = emoji;
                                  if (kDebugMode) debugPrint('🍎 GALLERY EMOJI: ✅ Matched by ID in "Who Reacted": "$emojiChar" -> ${emoji['name']}');
                                  break;
                                }
                              }
                              
                              // If still not found, try partial match
                              if (fruitEmoji == null) {
                                final normalizedKey = emojiChar.trim().toLowerCase();
                                for (var emoji in controller.availableEmojis) {
                                  final emojiCodeFromList = (emoji['code'] as String? ?? '').toLowerCase();
                                  final emojiNameFromList = (emoji['name'] as String? ?? '').toLowerCase();
                                  final emojiImageUrlFromList = (emoji['image_url'] as String? ?? '').toLowerCase();
                                  
                                  if ((emojiCodeFromList.isNotEmpty && (emojiCodeFromList == normalizedKey || emojiCodeFromList.contains(normalizedKey) || normalizedKey.contains(emojiCodeFromList))) ||
                                      (emojiNameFromList.isNotEmpty && (emojiNameFromList.contains(normalizedKey) || normalizedKey.contains(emojiNameFromList))) ||
                                      (emojiImageUrlFromList.isNotEmpty && (emojiImageUrlFromList.contains(normalizedKey) || normalizedKey.contains(emojiImageUrlFromList)))) {
                                    fruitEmoji = emoji;
                                    if (kDebugMode) debugPrint('🍎 GALLERY EMOJI: ✅ Found by partial match in "Who Reacted": "$emojiChar" -> ${emoji['name']}');
                                    break;
                                  }
                                }
                              }
                              
                              if (fruitEmoji == null) {
                                if (kDebugMode) debugPrint('🍎 GALLERY EMOJI: ❌ Emoji not found in "Who Reacted" section: "$emojiChar"');
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
                                    // Show which emoji they reacted with (on the RIGHT side, like prayer details)
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
                      // Show "and X more" if there are more than 5 users (same as prayer details)
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
                                final firstEmojiChar = reactions.keys.isNotEmpty ? reactions.keys.first : '';
                                Map<String, dynamic>? firstFruitEmoji;
                                if (firstEmojiChar.isNotEmpty) {
                                  // Use improved matching
                                  for (var emoji in controller.availableEmojis) {
                                    final emojiCharFromList = emoji['emoji_char'] as String? ?? '';
                                    final emojiCodeFromList = emoji['code'] as String? ?? '';
                                    final emojiImageUrlFromList = emoji['image_url'] as String? ?? '';
                                    
                                    if ((emojiCharFromList.isNotEmpty && (emojiCharFromList.trim() == firstEmojiChar.trim() || emojiCharFromList == firstEmojiChar)) ||
                                        (emojiCodeFromList.isNotEmpty && (emojiCodeFromList.trim() == firstEmojiChar.trim() || emojiCodeFromList == firstEmojiChar)) ||
                                        (emojiImageUrlFromList.isNotEmpty && (emojiImageUrlFromList.contains(firstEmojiChar) || firstEmojiChar.contains(emojiImageUrlFromList)))) {
                                      firstFruitEmoji = emoji;
                                      break;
                                    }
                                  }
                                }
                                _showReactionUsersDialog(context, firstEmojiChar, allUsers, firstFruitEmoji);
                              },
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: ResponsiveHelper.spacing(context, 8)),
                                child: Row(
                                  children: [
                                    Text(
                                      'and ${totalUsers - 5} more',
                                      style: TextStyle(
                                        fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                                        color: AppTheme.iconscolor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      size: ResponsiveHelper.fontSize(context, mobile: 10),
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
        ),
      );
    });
  }

  /// Build rich text input that can display both text and sticker messages (from blog_details_screen)
  Widget _buildRichTextInput() {
    return Container(
      padding: ResponsiveHelper.padding(context, horizontal: 8, vertical: 8),
      child: Row(
        children: [
          // Display all sticker messages as images
          ...commentMessages.map((message) => _buildCommentMessage(message)).toList(),
          // Text input field for regular text
          Expanded(
            child: TextField(
              controller: commentController,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: commentMessages.isEmpty ? 'Write a comment...' : '',
                hintStyle: ResponsiveHelper.textStyle(
                  context,
                  fontSize: 15,
                  color: Colors.grey[500],
                ),
              ),
              style: ResponsiveHelper.textStyle(context, fontSize: 15),
              maxLines: null,
              onChanged: (value) {
                setState(() {});
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Build message widget that properly renders text vs stickers (from blog_details_screen)
  Widget _buildCommentMessage(CommentMessage message) {
    if (message.isSticker) {
      // Return sticker widget
      return StickerEmojiHelper.buildStickerWidget(message.stickerId ?? '', size: 40);
    } else {
      // Return text widget
      return Text(
        message.text ?? '',
        style: ResponsiveHelper.textStyle(context, fontSize: 15),
      );
    }
  }

  /// Show emoji picker for photo comments - sends emoji directly without showing in input field
  void _showEmojiPicker(BuildContext context, int photoId, TextEditingController controller, {int? parentCommentId}) {
    showEmojiStickerPicker(
      context: context,
      onEmojiSelected: (emoji) async {
        // Send emoji directly as comment - no preview in text field!
        await _sendEmojiDirectly(photoId, emoji, parentCommentId: parentCommentId);
      },
      height: 350,
    );
  }

  /// Send emoji/sticker directly as comment without showing in input field
  Future<void> _sendEmojiDirectly(int photoId, String emoji, {int? parentCommentId}) async {
    if (emoji.isEmpty) return;

    FocusScope.of(context).unfocus();

    isSubmittingComment.value = true;

    try {
      final success = await controller.addComment(photoId, emoji, parentCommentId: parentCommentId);
      if (success) {
        commentController.clear();
        // Scroll to show new comment
        await Future.delayed(const Duration(milliseconds: 300));
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
          );
        }
        // Reload photo details to show new comment
        await controller.loadPhotoDetails(photoId);
        _showCustomSnackbar('Success', 'Comment added successfully');
      } else {
        _showCustomSnackbar('Error', controller.message.value, isError: true);
      }
    } catch (e) {
      print('Error sending emoji comment: $e');
      _showCustomSnackbar('Error', 'Failed to send emoji. Please try again.', isError: true);
    } finally {
      isSubmittingComment.value = false;
    }
  }

  /// Show Reaction Users Dialog
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
              Row(
                children: [
                  if (fruitEmoji != null)
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: HomeScreen.buildEmojiDisplay(
                        context,
                        fruitEmoji,
                        size: 32,
                        userEmail: userEmail,
                      ),
                    ),
                  SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                  Expanded(
                    child: Text(
                      '${users.length} ${users.length == 1 ? 'person' : 'people'} reacted',
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: ResponsiveHelper.fontSize(context, mobile: 18),
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF5F4628)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              SizedBox(height: ResponsiveHelper.spacing(context, 16)),
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
                      // Check if already a full URL (http/https)
                      if (photoPath.startsWith('http://') || photoPath.startsWith('https://')) {
                        profilePhotoUrl = photoPath; // Use as-is if already a full URL
                      } else if (!photoPath.startsWith('assets/') && 
                          !photoPath.startsWith('file://') &&
                          !photoPath.startsWith('assets/images/')) {
                        profilePhotoUrl = 'http://admin.fosmessenger.com/$photoPath';
                      }
                    }
                    
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFFFFD1DC),
                        backgroundImage: profilePhotoUrl != null
                            ? NetworkImage(profilePhotoUrl)
                            : null,
                        child: profilePhotoUrl == null
                            ? Icon(
                                Icons.person,
                                size: ResponsiveHelper.fontSize(context, mobile: 20),
                                color: AppTheme.iconscolor,
                              )
                            : null,
                      ),
                      title: Text(
                        userName,
                        style: ResponsiveHelper.textStyle(
                          context,
                          fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
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
}

/// Full Screen Image Preview Screen
class _ImagePreviewScreen extends StatelessWidget {
  final String imageUrl;
  final Map<String, dynamic> photo;

  const _ImagePreviewScreen({
    required this.imageUrl,
    required this.photo,
  });

  @override
  Widget build(BuildContext context) {
    final userName = photo['user_name'] as String? ?? 'Anonymous';
    final testimony = photo['testimony'] as String? ?? '';
    final fruitTag = photo['fruit_tag'] as String?;
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Full Screen Image
          Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[900],
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.broken_image,
                          size: ResponsiveHelper.iconSize(context, mobile: 64),
                          color: Colors.grey,
                        ),
                        SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                        Text(
                          'Failed to load image',
                          style: ResponsiveHelper.textStyle(
                            context,
                            fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          
          // Back Button
          SafeArea(
            child: Padding(
              padding: ResponsiveHelper.padding(
                context,
                all: ResponsiveHelper.isMobile(context) 
                    ? ResponsiveHelper.spacing(context, 12)
                    : ResponsiveHelper.spacing(context, 16),
              ),
              child: Material(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(
                  ResponsiveHelper.borderRadius(context, mobile: 30),
                ),
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(
                    ResponsiveHelper.borderRadius(context, mobile: 30),
                  ),
                  child: Container(
                    padding: EdgeInsets.all(
                      ResponsiveHelper.isMobile(context) 
                          ? ResponsiveHelper.spacing(context, 10)
                          : ResponsiveHelper.spacing(context, 12),
                    ),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: ResponsiveHelper.iconSize(
                        context,
                        mobile: 24,
                        tablet: 28,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // Bottom Info (optional - show user name and testimony)
          if (testimony.isNotEmpty || userName != 'Anonymous')
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Container(
                  padding: EdgeInsets.all(
                    ResponsiveHelper.isMobile(context)
                        ? ResponsiveHelper.spacing(context, 16)
                        : ResponsiveHelper.spacing(context, 20),
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                        Colors.black.withOpacity(0.9),
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (userName != 'Anonymous') ...[
                        Text(
                          userName,
                          style: ResponsiveHelper.textStyle(
                            context,
                            fontSize: ResponsiveHelper.fontSize(
                              context,
                              mobile: 16,
                              tablet: 18,
                            ),
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: ResponsiveHelper.spacing(context, 8)),
                      ],
                      if (testimony.isNotEmpty) ...[
                        Text(
                          testimony,
                          style: ResponsiveHelper.textStyle(
                            context,
                            fontSize: ResponsiveHelper.fontSize(
                              context,
                              mobile: 14,
                              tablet: 16,
                            ),
                            color: Colors.white,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (fruitTag != null && fruitTag.isNotEmpty) ...[
                        SizedBox(height: ResponsiveHelper.spacing(context, 8)),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: ResponsiveHelper.spacing(context, 12),
                            vertical: ResponsiveHelper.spacing(context, 6),
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B4513).withOpacity(0.8),
                            borderRadius: BorderRadius.circular(
                              ResponsiveHelper.borderRadius(context, mobile: 20),
                            ),
                          ),
                          child: Text(
                            fruitTag,
                            style: ResponsiveHelper.textStyle(
                              context,
                              fontSize: ResponsiveHelper.fontSize(
                                context,
                                mobile: 12,
                                tablet: 14,
                              ),
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
