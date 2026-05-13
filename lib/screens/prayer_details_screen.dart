import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/utils/share_helper.dart';

import 'package:fruitsofspirit/controllers/prayers_controller.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';
import 'package:fruitsofspirit/utils/auto_translate_helper.dart';
import 'package:fruitsofspirit/utils/image_helper.dart';
import 'package:fruitsofspirit/widgets/see_translation_widget.dart';
import 'package:fruitsofspirit/widgets/cached_image.dart';
import 'package:fruitsofspirit/config/image_config.dart';
import 'package:fruitsofspirit/services/user_storage.dart';
import 'package:fruitsofspirit/widgets/standard_app_bar.dart';
import 'package:fruitsofspirit/widgets/emoji_button.dart';
import 'package:fruitsofspirit/utils/app_theme.dart';
import 'package:fruitsofspirit/utils/fruit_emoji_helper.dart';
import 'package:fruitsofspirit/widgets/emoji_sticker_picker.dart';
import 'package:fruitsofspirit/services/prayers_service.dart'; // edit feature
import 'package:fruitsofspirit/services/comments_service.dart'; // edit feature
import 'package:fruitsofspirit/services/user_blocking_service.dart';
import 'package:fruitsofspirit/utils/report_utils.dart';
import 'package:fruitsofspirit/utils/sticker_emoji_helper.dart';
import 'package:fruitsofspirit/utils/time_helper.dart';

import 'home_screen.dart';

/// Prayer Details Screen
/// Professional, user-friendly design with attractive UI and Facebook-like comment threads
class PrayerDetailsScreen extends StatefulWidget {
  const PrayerDetailsScreen({Key? key}) : super(key: key);

  @override
  State<PrayerDetailsScreen> createState() => _PrayerDetailsScreenState();
}

// Message model for proper text/sticker separation (reusable from blog_details_screen)
class CommentMessage {
  final String? text;
  final String? stickerId;
  final bool isSticker;

  CommentMessage({this.text, this.stickerId, required this.isSticker});
}

class _PrayerDetailsScreenState extends State<PrayerDetailsScreen> {
  final PrayersController controller = Get.find<PrayersController>();
  final replyControllers = <int, TextEditingController>{};
  final replyFocusNodes = <int, FocusNode>{};
  final showReplyInput = <int, bool>{};
  final expandedReplies = <int>{}; // Track which replies are expanded
  final commentController = TextEditingController();
  final scrollController = ScrollController();
  int? currentUserId;
  String? userEmail;
  bool _isSending = false;
  final Set<int> _sendingReplies = {};
  // Rich text input messages (text + stickers) like blog_details_screen
  final List<CommentMessage> commentMessages = [];
  // edit feature: Comment edit state
  final editControllers = <int, TextEditingController>{}; // edit feature
  final showEditInput = <int, bool>{}; // edit feature
  var isEditingComment = false.obs; // edit feature
  // edit feature: Post edit state
  final postEditContentController = TextEditingController(); // edit feature
  final postEditCategoryController = TextEditingController(); // edit feature
  var showPostEditInput = false.obs; // edit feature
  var isEditingPost = false.obs; // edit feature

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

  /// Show emoji picker for prayer comments - sends emoji directly without showing in input field
  void _showEmojiPicker(BuildContext context, int prayerId, TextEditingController controller) {
    showEmojiStickerPicker(
      context: context,
      onEmojiSelected: (emoji) async {
        // Send emoji directly as comment - no preview in text field!
        await _sendEmojiDirectly(prayerId, emoji);
      },
      height: 350,
    );
  }

  /// Send emoji/sticker directly as comment without showing in input field
  Future<void> _sendEmojiDirectly(int prayerId, String emoji) async {
    if (emoji.isEmpty) return;

    FocusScope.of(context).unfocus();

    try {
      final success = await controller.addComment(prayerId, emoji);
      if (success) {
        commentController.clear();
        // Reload prayer details to show new comment
        await controller.loadPrayerDetails(prayerId);
      }
    } catch (e) {
      print('Error sending emoji comment: $e');
    }
  }

  void _showCustomSnackbar(BuildContext context, String title, String message, {bool isError = false, bool isModeration = false}) {
    if (!mounted) return;
    
    final scaffoldContext = Get.context;
    if (scaffoldContext == null) return;
    
    ScaffoldMessenger.of(scaffoldContext).hideCurrentSnackBar();
    
    ScaffoldMessenger.of(scaffoldContext).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(
                isModeration ? Icons.security_rounded : (isError ? Icons.error_outline : Icons.check_circle_outline),
                color: isModeration ? const Color(0xFFC79211) : Colors.white,
                size: 24,
              ),
            ),
            Expanded(
              child: Column(
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
            ),
          ],
        ),
        backgroundColor: isModeration ? const Color(0xFF5D4037) : (isError ? Colors.red : AppTheme.iconscolor),
        duration: Duration(seconds: isModeration ? 5 : 3),
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
    _loadCurrentUserId();
    _loadUserEmail();
  }


  Future<void> _loadCurrentUserId() async {
    final user = await UserStorage.getUser();
    if (user != null) {
      final id = user['id'];
      if (id is int) {
        setState(() {
          currentUserId = id;
        });
      }
    }
  }

  Future<void> _loadUserEmail() async {
    userEmail = await UserStorage.getUserEmail();
  }

  @override
  void dispose() {
    commentController.dispose();
    scrollController.dispose();
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
    // edit feature: Dispose post edit controllers
    postEditContentController.dispose(); // edit feature
    postEditCategoryController.dispose(); // edit feature
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

  // edit feature: Check if prayer can be edited (always allow editing)
  bool _canEditPost(Map<String, dynamic> prayer) { // edit feature
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
      print('🕐 Prayer Time check (UTC): ${difference.inMinutes} minutes, canEdit: $canEdit'); // debug
      print('🌍 Prayer Device timezone: ${DateTime.now().timeZoneName} (${DateTime.now().timeZoneOffset})'); // debug
      
      // CRITICAL DEBUG: Show exact frontend calculation to compare with backend
      print('🔍 FRONTEND TIME CALCULATION DEBUG:'); // debug
      print('   - Raw created_at: ${comment['created_at']}'); // debug
      print('   - Formatted date: $formattedDate'); // debug
      print('   - Server time UTC (fixed): $serverTimeUtc'); // debug
      print('   - Current UTC: $nowUtc'); // debug
      print('   - Frontend minutes diff: ${difference.inMinutes}'); // debug
      print('   - Frontend canEdit: $canEdit'); // debug
      print('🔍 FRONTEND DEBUG COMPLETE'); // debug
      
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
  Widget _buildEditButton(BuildContext context, Map<String, dynamic> comment, int prayerId) { // edit feature
    print('🔨 _buildEditButton called for comment ${comment['id']}'); // debug
    if (!_canEditComment(comment)) return const SizedBox.shrink(); // edit feature
    print('✅ Edit button will be shown for comment ${comment['id']}'); // debug
    final commentId = comment['id'] as int; // edit feature

    return InkWell( // edit feature
      onTap: () { // edit feature
        setState(() { // edit feature
          if (!editControllers.containsKey(commentId)) { // edit feature
            // Get the raw comment content
            final rawContent = (comment['comment'] as String? ?? comment['content'] as String? ?? '').trim();
            print('📝 Edit - Raw content: "$rawContent"');

            // If content is an image URL, don't show it in the edit field (it's an emoji/sticker)
            // Only show text content for editing
            String editContent = rawContent;
            if (rawContent.startsWith('http') && (rawContent.contains('.png') || rawContent.contains('.jpg') || rawContent.contains('.jpeg'))) {
              // It's an image URL - show empty for editing (user can't edit emojis)
              editContent = '';
              print('📝 Edit - Content is image URL, clearing for edit');
            }

            editControllers[commentId] = TextEditingController(
              text: editContent,
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
            style: ResponsiveHelper.textStyle( // edit feature
              context, // edit feature
              fontSize: ResponsiveHelper.fontSize(context, mobile: 12, tablet: 13), // edit feature
              color: Colors.orange, // edit feature: Orange like reply button
            ), // edit feature
          ), // edit feature
        ], // edit feature
      ), // edit feature
    ); // edit feature
  } // edit feature

  // edit feature: Build edit input widget
  Widget _buildEditInput(BuildContext context, int commentId, int prayerId, String postType) { // edit feature
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
                onPressed: () => _editComment(context, commentId, prayerId, postType), // edit feature
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
  Future<void> _editComment(BuildContext context, int commentId, int prayerId, String postType) async { // edit feature
    // CRITICAL DEBUG: Save button click tracking
    print('🔍 SAVE BUTTON DEBUG - START ANALYSIS'); // debug
    print('🔍 Save button clicked for comment ID: $commentId'); // debug
    print('🔍 Prayer ID: $prayerId, Post Type: $postType'); // debug
    print('🔍 Current User ID: $currentUserId'); // debug
    
    final editController = editControllers[commentId];
    if (editController == null) {
      print('❌ SAVE ERROR: Edit controller not found for comment $commentId'); // debug
      return;
    }

    final content = editController.text.trim();
    print('🔍 Edit content: "$content"'); // debug
    
    if (content.isEmpty) {
      print('❌ SAVE ERROR: Content is empty'); // debug
      ScaffoldMessenger.of(context).showSnackBar( // edit feature
        SnackBar( // edit feature
          content: Text('Comment cannot be empty'), // edit feature
          backgroundColor: Colors.red, // edit feature
          duration: const Duration(seconds: 2), // edit feature
        ), // edit feature
      ); // edit feature
      return; // edit feature
    } // edit feature

    if (currentUserId == null || currentUserId == 0) { // edit feature
      print('❌ SAVE ERROR: User not logged in (currentUserId: $currentUserId)'); // debug
      ScaffoldMessenger.of(context).showSnackBar( // edit feature
        SnackBar( // edit feature
          content: Text('Please login first'), // edit feature
          backgroundColor: Colors.red, // edit feature
          duration: const Duration(seconds: 2), // edit feature
        ), // edit feature
      ); // edit feature
      return; // edit feature
    } // edit feature
    
    print('✅ SAVE PRE-CHECKS PASSED - Proceeding with API call'); // debug

    // edit feature: Time window check removed - always allow editing
    // final comment = controller.prayerComments.firstWhereOrNull((c) => c['id'] == commentId);
    // if (comment != null && comment['created_at'] != null) { // edit feature
    //   try { // edit feature
    //     final date = DateTime.parse(comment['created_at'] as String); // edit feature: Use real local time
    //     final date = DateTime.parse(comment['created_at'] as String); // edit feature
    //     final now = _getCurrentTime(); // edit feature: Use configured time zone
    //     final difference = now.difference(date); // edit feature
    //     if (difference.inMinutes >= _editTimeWindowMinutes) { // edit feature
    //       ScaffoldMessenger.of(context).showSnackBar( // edit feature
    //         SnackBar( // edit feature
    //           content: Text('Comments can only be edited within $_editTimeWindowMinutes minutes of posting'), // edit feature
    //           backgroundColor: Colors.orange, // edit feature
    //           duration: const Duration(seconds: 3), // edit feature
    //         ), // edit feature
    //       ); // edit feature
    //       setState(() { // edit feature
    //         showEditInput[commentId] = false; // edit feature
    //       }); // edit feature
    //       return; // edit feature
    //     } // edit feature
    //   } catch (e) { // edit feature
    //     // If date parsing fails, continue with API call // edit feature
    //   } // edit feature
    // } // edit feature

    isEditingComment.value = true; // edit feature
    print('🔍 CALLING COMMENTS SERVICE API'); // debug
    try { // edit feature
      await CommentsService.editComment( // edit feature
        userId: currentUserId!, // edit feature
        commentId: commentId, // edit feature
        postType: postType, // edit feature
        postId: prayerId, // edit feature
        content: content, // edit feature
      ); // edit feature

      print('✅ API CALL SUCCESSFUL - Comment edited'); // debug
      setState(() { // edit feature
        showEditInput[commentId] = false; // edit feature
      }); // edit feature

      await controller.loadPrayerDetails(prayerId); // edit feature

      ScaffoldMessenger.of(context).showSnackBar( // edit feature
        SnackBar( // edit feature
          content: Text('Comment edited successfully'), // edit feature
          backgroundColor: Colors.green, // edit feature
          duration: const Duration(seconds: 2), // edit feature
        ), // edit feature
      ); // edit feature
      print('✅ SAVE COMPLETE - Success message shown'); // debug
    } catch (e) { // edit feature
      print('❌ API CALL FAILED: $e'); // debug
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

  // edit feature: Edit prayer method
  Future<void> _editPost(int prayerId) async { // edit feature
    final content = postEditContentController.text.trim(); // edit feature
    final category = postEditCategoryController.text.trim(); // edit feature

    if (content.isEmpty && category.isEmpty) { // edit feature
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

    // edit feature: Check if prayer can still be edited (time window check)
    final prayer = controller.selectedPrayer;
    if (prayer.isNotEmpty && prayer['created_at'] != null) { // edit feature
      try { // edit feature
        final date = DateTime.parse(prayer['created_at'] as String); // edit feature: Use real local time
        final now = DateTime.now(); // edit feature: Use real local time
        final difference = now.difference(date); // edit feature
        if (difference.inMinutes >= _editTimeWindowMinutes) { // edit feature
          Get.snackbar( // edit feature
            'Edit Time Expired', // edit feature
            'Prayers can only be edited within $_editTimeWindowMinutes minutes of posting', // edit feature
            backgroundColor: Colors.orange, // edit feature
            colorText: Colors.white, // edit feature
            duration: const Duration(seconds: 3), // edit feature
          ); // edit feature
          showPostEditInput.value = false; // edit feature
          return; // edit feature
        } // edit feature
      } catch (e) { // edit feature
        // If date parsing fails, continue with API call // edit feature
      } // edit feature
    } // edit feature

    isEditingPost.value = true; // edit feature
    try { // edit feature
      await PrayersService.editPrayer( // edit feature
        userId: currentUserId!, // edit feature
        prayerId: prayerId, // edit feature
        content: content.isEmpty ? null : content, // edit feature
        category: category.isEmpty ? null : category, // edit feature
      ); // edit feature

      showPostEditInput.value = false; // edit feature
      await controller.loadPrayerDetails(prayerId); // edit feature

      Get.snackbar( // edit feature
        'Success', // edit feature
        'Prayer edited successfully', // edit feature
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

  /// Get prayer type color
  Color _getPrayerTypeColor(String? category) {
    switch (category) {
      case 'Healing':
        return const Color(0xFF4CAF50);
      case 'Peace & Anxiety':
        return const Color(0xFF2196F3);
      case 'Work & Provision':
        return const Color(0xFFFF9800);
      case 'Relationships':
        return const Color(0xFFE91E63);
      case 'Guidance':
        return const Color(0xFF9C27B0);
      default:
        return const Color(0xFF8B4513);
    }
  }

  /// Get image provider (reusable from blog_details_screen)
  ImageProvider? _getImageProvider(String? photoUrl) {
    if (photoUrl == null || photoUrl.isEmpty) return null;
    
    final baseUrl = 'https://fruitofthespirit.templateforwebsites.com/';
    String fixedUrl = photoUrl.trim();
    
    print('🔍 _getImageProvider: Original URL = "$fixedUrl"');
    
    // CRITICAL FIX: Always check for 'uploadsprofile' (missing slash) FIRST, regardless of URL type
    // This is the most common issue - missing slash between 'uploads' and 'profile'
    if (fixedUrl.contains('uploadsprofile')) {
      fixedUrl = fixedUrl.replaceAll('uploadsprofile', 'uploads/profile');
      print('🔧 Fixed missing slash: uploadsprofile -> uploads/profile');
      print('🔍 After fix: "$fixedUrl"');
    }
    
    // If already a full URL
    if (fixedUrl.startsWith('http')) {
      // Additional check: if URL contains 'uploads' but not 'uploads/', fix it
      if (fixedUrl.contains('uploads') && !fixedUrl.contains('uploads/')) {
        // Find 'uploads' and check if next character is '/'
        final uploadsIndex = fixedUrl.indexOf('uploads');
        if (uploadsIndex >= 0 && uploadsIndex + 7 < fixedUrl.length) {
          final nextChar = fixedUrl[uploadsIndex + 7];
          if (nextChar != '/') {
            // Insert slash after 'uploads'
            fixedUrl = fixedUrl.substring(0, uploadsIndex + 7) + '/' + fixedUrl.substring(uploadsIndex + 7);
            print('🔧 Fixed missing slash in full URL after "uploads"');
            print('🔍 After fix: "$fixedUrl"');
          }
        }
      }
      
      // Final check: ensure no 'uploadsprofile' remains
      if (fixedUrl.contains('uploadsprofile')) {
        fixedUrl = fixedUrl.replaceAll('uploadsprofile', 'uploads/profile');
        print('🔧 Final fix for uploadsprofile in full URL');
        print('🔍 After final fix: "$fixedUrl"');
      }
      
      print('📸 Loading profile photo from: $fixedUrl');
      return NetworkImage(fixedUrl);
    } else if (fixedUrl.startsWith('assets/')) {
      // Don't try to load assets that might not exist in Flutter app
      return null;
    } else {
      // Relative URL - ensure proper formatting
      
      // Remove leading slash if present
      if (fixedUrl.startsWith('/')) {
        fixedUrl = fixedUrl.substring(1);
      }
      
      // Ensure 'uploads/' has proper slash
      if (fixedUrl.startsWith('uploads') && !fixedUrl.startsWith('uploads/')) {
        fixedUrl = 'uploads/' + fixedUrl.substring('uploads'.length);
        print('🔧 Fixed relative URL: added slash after "uploads"');
      }
      
      // Construct final URL
      final finalUrl = baseUrl + fixedUrl;
      
      // Final safety check: if the final URL still has 'uploadsprofile', fix it
      if (finalUrl.contains('uploadsprofile')) {
        final correctedUrl = finalUrl.replaceAll('uploadsprofile', 'uploads/profile');
        print('🔧 Final safety fix applied: $correctedUrl');
        return NetworkImage(correctedUrl);
      }
      
      print('📸 Loading profile photo from: $finalUrl');
      return NetworkImage(finalUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prayerId = Get.arguments as int? ?? 0;
    
    // Load prayer details if not already loaded
    if (prayerId > 0 && (controller.selectedPrayer.isEmpty || controller.selectedPrayer['id'] != prayerId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.loadPrayerDetails(prayerId);
        controller.loadAvailableEmojis();
        controller.loadQuickEmojis();
      });
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: StandardAppBar(
        showBackButton: true,
        rightActions: [
          StandardAppBar.buildActionIcon(
            context,
            icon: Icons.share_rounded,
            onTap: () {
              final prayer = controller.selectedPrayer;
              final isAnonymous = prayer['is_anonymous'] == 1 || prayer['is_anonymous'] == true;
              ShareHelper.shareContent(
                context: context,
                contentType: 'prayer',
                contentId: prayer['id'] is int ? prayer['id'] : int.tryParse(prayer['id'].toString()) ?? 0,
                title: 'Prayer Request from ${isAnonymous ? 'Anonymous' : (prayer['user_name'] ?? 'Anonymous')}',
                content: prayer['content'],
              );
            },
          ),
        ],
      ),

      body: Obx(() {
        if (controller.isLoading.value && controller.selectedPrayer.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  color: AppTheme.iconscolor,
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                Text(
                  'Loading prayer details...',
                  style: ResponsiveHelper.textStyle(
                    context,
                    fontSize: ResponsiveHelper.fontSize(context, mobile: 13, tablet: 14, desktop: 15),
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        if (controller.selectedPrayer.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: ResponsiveHelper.iconSize(context, mobile: 60, tablet: 64, desktop: 68),
                  color: Colors.grey[400],
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                Text(
                  'Prayer request not found',
                  style: ResponsiveHelper.textStyle(
                    context,
                    fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 17, desktop: 18),
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, 8)),
                Text(
                  'The prayer you\'re looking for doesn\'t exist',
                  style: ResponsiveHelper.textStyle(
                    context,
                    fontSize: ResponsiveHelper.fontSize(context, mobile: 13, tablet: 14, desktop: 15),
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, 24)),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.iconscolor,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Go Back',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        }

        final prayer = controller.selectedPrayer;
        final isAnonymous = prayer['is_anonymous'] == 1 || prayer['is_anonymous'] == true;
        final category = prayer['category'] as String? ?? 'General';
        final categoryColor = _getPrayerTypeColor(category);
        final prayerFor = prayer['prayer_for'] as String? ?? 'Me';
        final timeAgo = TimeHelper.getTimeAgo(prayer['created_at'] as String?);
        
        // Get profile photo URL
        String? profilePhotoUrl;
        if (!isAnonymous && prayer['profile_photo'] != null && prayer['profile_photo'].toString().isNotEmpty) {
          final photoPath = prayer['profile_photo'].toString();
          // Check if already a full URL (http/https)
          if (photoPath.startsWith('http://') || photoPath.startsWith('https://')) {
            profilePhotoUrl = photoPath; // Use as-is if already a full URL
          } else if (!photoPath.startsWith('assets/') && 
              !photoPath.startsWith('file://') &&
              !photoPath.startsWith('assets/images/')) {
            profilePhotoUrl = 'https://fruitofthespirit.templateforwebsites.com/$photoPath';
          }
        }

        final prayerId = prayer['id'] as int;
        
        return Column(
          children: [
            // Prayer Content Section
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  print('🔄 Pull-to-refresh triggered');
                  // Reload prayer details (this also reloads comments automatically)
                  await controller.loadPrayerDetails(prayerId);
                  print('✅ Refresh completed');
                },
                              color: AppTheme.iconscolor,
                backgroundColor: Colors.white,
                child: SingleChildScrollView(
                  controller: scrollController,
                  physics: const AlwaysScrollableScrollPhysics(), // Enable scroll even when content is small
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    // Main Prayer Card - Exact same pattern as home screen
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            spreadRadius: 0,
                            blurRadius: 8,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header - Profile + Name + Three-dot menu (Exact match home screen)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                // Profile Picture - Exact same as home screen
                                profilePhotoUrl != null && !isAnonymous
                                    ? ClipOval(
                                        child: CachedImage(
                                          imageUrl: profilePhotoUrl,
                                          width: ResponsiveHelper.iconSize(context, mobile: 44, tablet: 48, desktop: 52),
                                          height: ResponsiveHelper.iconSize(context, mobile: 44, tablet: 48, desktop: 52),
                                          fit: BoxFit.cover,
                                          errorWidget: CircleAvatar(
                                            radius: ResponsiveHelper.iconSize(context, mobile: 22, tablet: 24, desktop: 26) / 2,
                                            backgroundColor: Colors.grey[300]!,
                                            child: Icon(
                                              Icons.person_rounded,
                                              size: ResponsiveHelper.iconSize(context, mobile: 22, tablet: 24, desktop: 26),
                                              color: AppTheme.iconscolor,
                                            ),
                                          ),
                                        ),
                                      )
                                    : CircleAvatar(
                                        radius: ResponsiveHelper.iconSize(context, mobile: 22, tablet: 24, desktop: 26) / 2,
                                        backgroundColor: Colors.grey[300]!,
                                        child: Icon(
                                          Icons.person_rounded,
                                          size: ResponsiveHelper.iconSize(context, mobile: 22, tablet: 24, desktop: 26),
                                          color: AppTheme.iconscolor,
                                        ),
                                      ),
                                SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                                // Name - Exact same as home screen
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        isAnonymous ? 'Anonymous' : (prayer['user_name'] as String? ?? 'Anonymous'),
                                        style: ResponsiveHelper.textStyle(
                                          context,
                                          fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ],
                                  ),
                                ),
                                // Three-dot menu - Exact match
                                IconButton(
                                  icon: Icon(
                                    Icons.more_vert,
                                    size: ResponsiveHelper.iconSize(context, mobile: 18, tablet: 20, desktop: 22),
                                    color: AppTheme.iconscolor,
                                  ),
                                  onPressed: () {
                                    // Menu options can be added here
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ),
                          // Prayer Type - Below name (Exact same as home screen subtitle)
                          Padding(
                            padding: ResponsiveHelper.padding(context, horizontal: 16, vertical: 0),
                            child: Text(
                              category,
                              style: ResponsiveHelper.textStyle(
                                context,
                                fontSize: ResponsiveHelper.fontSize(context, mobile: 13, tablet: 14, desktop: 15),
                                color: AppTheme.iconscolor,
                                fontWeight: FontWeight.normal,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          // edit feature: Edit button for own prayers within 15 minutes
                          if (_canEditPost(prayer)) ...[ // edit feature
                            SizedBox(height: ResponsiveHelper.spacing(context, 8)), // edit feature
                            GestureDetector( // edit feature
                              onTap: () { // edit feature
                                setState(() { // edit feature
                                  postEditContentController.text = prayer['content'] as String? ?? ''; // edit feature
                                  postEditCategoryController.text = prayer['category'] as String? ?? ''; // edit feature
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
                                      'Edit Prayer', // edit feature
                                      style: TextStyle( // edit feature
                                        fontSize: 11, // edit feature
                                        color: Colors.grey[700], // edit feature
                                      ), // edit feature
                                    ), // edit feature
                                  ], // edit feature
                                ), // edit feature
                              ), // edit feature
                            ), // edit feature
                          ], // edit feature
                          SizedBox(height: ResponsiveHelper.spacing(context, 12)),
                          // Content - Full content displayed (Same style as home screen)
                          Column( // edit feature
                            crossAxisAlignment: CrossAxisAlignment.start, // edit feature
                            children: [ // edit feature
                              Padding( // edit feature
                                padding: ResponsiveHelper.padding(context, horizontal: 16, vertical: 0), // edit feature
                                child: Text( // edit feature
                                  AutoTranslateHelper.getTranslatedTextSync( // edit feature
                                    text: prayer['content'] as String? ?? '', // edit feature
                                    sourceLanguage: prayer['language'] as String?, // edit feature
                                  ), // edit feature
                                  style: ResponsiveHelper.textStyle( // edit feature
                                    context, // edit feature
                                    fontSize: ResponsiveHelper.fontSize(context, mobile: 13, tablet: 14, desktop: 15), // edit feature
                                    color: Colors.black87, // edit feature
                                    height: 1.5, // edit feature
                                    fontWeight: FontWeight.normal, // edit feature
                                  ), // edit feature
                                ), // edit feature
                              ), // edit feature
                              // edit feature: Show "edited" label if prayer was edited
                              if (prayer['is_edited'] == true || prayer['is_edited'] == 1) ...[ // edit feature
                                SizedBox(height: ResponsiveHelper.spacing(context, 4)), // edit feature
                                Padding( // edit feature
                                  padding: ResponsiveHelper.padding(context, horizontal: 16, vertical: 0), // edit feature
                                  child: Text( // edit feature
                                    'edited', // edit feature
                                    style: TextStyle( // edit feature
                                      fontSize: 10, // edit feature
                                      color: Colors.grey[500], // edit feature
                                      fontStyle: FontStyle.italic, // edit feature
                                    ), // edit feature
                                  ), // edit feature
                                ), // edit feature
                              ], // edit feature
                            ], // edit feature
                          ), // edit feature
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
                                  'Edit Prayer', // edit feature
                                  style: ResponsiveHelper.textStyle( // edit feature
                                    context, // edit feature
                                    fontSize: ResponsiveHelper.fontSize(context, mobile: 14), // edit feature
                                    fontWeight: FontWeight.bold, // edit feature
                                    color: const Color(0xFF1976D2), // edit feature
                                  ), // edit feature
                                ), // edit feature
                                SizedBox(height: ResponsiveHelper.spacing(context, 12)), // edit feature
                                TextField( // edit feature
                                  controller: postEditContentController, // edit feature
                                  decoration: InputDecoration( // edit feature
                                    labelText: 'Prayer Content', // edit feature
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
                                      onPressed: () => _editPost(prayer['id'] as int), // edit feature
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
                          SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                          // Bottom Actions - Left: Prayed count, Right: Comments count (Exact match home screen)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Left: Prayed count with icon - Only show if > 0 (Exact match)
                                if ((prayer['response_count'] ?? 0) > 0)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.favorite,
                                        size: 18,
                                        color: Colors.blue[600],
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${prayer['response_count'] ?? 0} prayed',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.blue[600],
                                          fontWeight: FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                // Right: Comments count with icon - Only show if > 0 (Exact match)
                                if ((controller.prayerComments.length) > 0)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.comment_outlined,
                                        size: 18,
                                        color: AppTheme.iconscolor,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${controller.prayerComments.length} Comments',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: AppTheme.iconscolor,
                                          fontWeight: FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Emoji Reactions Section - Show if allowed (default true) OR if there are already reactions
                    if (prayer['allow_encouragement']?.toString() != '0' || controller.prayerEmojiReactions.isNotEmpty)
                      _buildEmojiReactions(context, prayerId, controller),
                    
                    const SizedBox(height: 24),
                    
                    // Responses/Comments Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 8)),
                              decoration: BoxDecoration(
                                color: AppTheme.iconscolor,
                                borderRadius: BorderRadius.circular(ResponsiveHelper.isMobile(context) ? 12 : 14),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.iconscolor.withOpacity(0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.chat_bubble_outline_rounded,
                                color: Colors.white,
                                size: ResponsiveHelper.fontSize(context, mobile: 18),
                              ),
                            ),
                            SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                            Text(
                              'Responses',
                              style: TextStyle(
                                fontSize: ResponsiveHelper.fontSize(context, mobile: 20),
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: ResponsiveHelper.spacing(context, 12),
                            vertical: ResponsiveHelper.spacing(context, 6),
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppTheme.iconscolor.withOpacity(0.15),
                                AppTheme.iconscolor.withOpacity(0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(ResponsiveHelper.isMobile(context) ? 12 : 14),
                            border: Border.all(
                              color: AppTheme.iconscolor.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            '${controller.prayerComments.length}',
                            style: TextStyle(
                              fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                              fontWeight: FontWeight.bold,
                              color: AppTheme.iconscolor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Comments List
                    if (controller.prayerComments.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 48,
                              color: AppTheme.iconscolor,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No responses yet',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Be the first to share your thoughts',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.iconscolor,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ...controller.prayerComments.map((comment) => _buildCommentCard(context, comment, prayer['id'] as int)),
                  ],
                ),
              ),
            ),
          ),
            
            // Comment Input Section
            Container(
              padding: ResponsiveHelper.padding(
                context,
                all: ResponsiveHelper.isMobile(context) ? 16 : 20,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(
                    color: Colors.grey.withOpacity(0.15),
                    width: 1,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: ResponsiveHelper.isMobile(context) ? 12 : 16,
                    spreadRadius: 0,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
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
                              onPressed: () => _showEmojiPicker(context, prayerId, commentController),
                            ),
                            Expanded(
                              child: _buildRichTextInput(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF8B4513),
                            Color(0xFF6B3410),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(ResponsiveHelper.isMobile(context) ? 24 : 28),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF8B4513).withOpacity(0.4),
                            blurRadius: ResponsiveHelper.isMobile(context) ? 10 : 12,
                            spreadRadius: 0,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _handleSendComment(prayerId),
                          borderRadius: BorderRadius.circular(ResponsiveHelper.isMobile(context) ? 24 : 28),
                          child: Padding(
                            padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 12)),
                            child: _isSending
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Icon(
                                    Icons.send_rounded,
                                    color: Colors.white,
                                    size: ResponsiveHelper.fontSize(context, mobile: 24),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _handleSendComment(int prayerId) async {
    if (commentController.text.trim().isEmpty || _isSending) return;
    
    // Dismiss keyboard immediately
    FocusScope.of(context).unfocus();
    
    setState(() {
      _isSending = true;
    });
    
    try {
      final success = await controller.addComment(
        prayerId,
        commentController.text.trim(),
      );
      
      if (success) {
        commentController.clear();
        
        // Reload comments to show new comment
        await controller.loadPrayerDetails(prayerId);
        
        // Scroll to bottom to show latest comment
        await Future.delayed(const Duration(milliseconds: 300));
        if (scrollController.hasClients) {
          scrollController.animateTo(
            scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
          );
        }
        
        _showCustomSnackbar(
          context,
          'Success',
          'Response added successfully',
        );
      } else {
        final msg = controller.message.value;
        final isModeration = msg.contains('community guidelines') || msg.contains('inappropriate content') || msg.contains('Terms');
        _showCustomSnackbar(
          context,
          isModeration ? 'Community Guidelines' : 'Error',
          msg.isNotEmpty ? msg : 'Action could not be completed. Please try again.',
          isError: !isModeration,
          isModeration: isModeration,
        );
      }
    } catch (e) {
      print("Error adding comment: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _handleSendReply(int prayerId, int parentCommentId, TextEditingController replyController) async {
    if (replyController.text.trim().isEmpty || _sendingReplies.contains(parentCommentId)) return;

    setState(() {
      _sendingReplies.add(parentCommentId);
    });

    try {
      final success = await controller.addComment(
        prayerId,
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

        // Force reload comments to show the new reply
        await controller.loadPrayerComments(prayerId);
        
        _showCustomSnackbar(
          context,
          'Success',
          'Reply added successfully',
        );
      } else {
        _showCustomSnackbar(
          context,
          'Error',
          controller.message.value,
          isError: true,
        );
      }
    } catch (e) {
      print("Error adding reply: $e");
    } finally {
      if (mounted) {
        setState(() {
          _sendingReplies.remove(parentCommentId);
        });
      }
    }
  }

  Widget _buildCommentCard(BuildContext context, Map<String, dynamic> comment, int prayerId) {
    final content = comment['content'] as String? ?? '';
    final trimmed = content.trim();
    
    // Safety check: Don't display emoji reactions as comments
    if (trimmed.length <= 4) {
      final emojiRegex = RegExp(
        r'[\u{1F300}-\u{1F9FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]|[\u{1F600}-\u{1F64F}]|[\u{1F680}-\u{1F6FF}]|[\u{2764}\u{FE0F}]|[\u{2728}]|[\u{2B50}]',
        unicode: true,
      );
      if (emojiRegex.hasMatch(trimmed)) {
        return const SizedBox.shrink();
      }
    }
    
    final timeAgo = TimeHelper.getTimeAgo(comment['created_at'] as String?);
      print('🕰️ Comment duration debug: comment_id=${comment['id']}, created_at=${comment['created_at']}, timeAgo="$timeAgo"'); // debug
    final profilePhoto = comment['profile_photo'] as String?;
    final commentId = comment['id'] as int;
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
    
    // Initialize reply controller if not exists
    if (!replyControllers.containsKey(commentId)) {
      replyControllers[commentId] = TextEditingController();
    }
    
    return Container(
      margin: EdgeInsets.only(bottom: ResponsiveHelper.spacing(context, 12)),
      padding: ResponsiveHelper.padding(
        context,
        all: ResponsiveHelper.isMobile(context) ? 16 : 18,
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
            color: Colors.black.withOpacity(0.05),
            blurRadius: ResponsiveHelper.isMobile(context) ? 10 : 12,
            spreadRadius: 0,
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
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFFFFD1DC),
                      const Color(0xFFFFB6C1),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFB6C1).withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(2),
                child: CircleAvatar(
                  radius: ResponsiveHelper.isMobile(context) ? 20 : 22,
                  backgroundColor: Colors.white,
                  backgroundImage: profilePhotoUrl != null
                      ? NetworkImage(profilePhotoUrl)
                      : null,
                  child: profilePhotoUrl == null
                      ? Icon(
                          Icons.person_rounded,
                          color: Colors.black87,
                          size: ResponsiveHelper.fontSize(context, mobile: 20),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            comment['user_name'] as String? ?? 'Someone',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF5F4628),
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        if (timeAgo.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            '•',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.iconscolor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              timeAgo,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.iconscolor,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    FruitEmojiHelper.buildCommentText(
                      context,
                      AutoTranslateHelper.getTranslatedTextSync(
                        text: content,
                        sourceLanguage: comment['language'] as String?,
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        height: 1.5,
                      ),
                      userEmail: userEmail,
                    ),
                    const SizedBox(height: 12),
                    // Action Buttons: Like, Reply, Report
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        // Like Button
                        InkWell(
                          onTap: () async {
                            final success = await controller.toggleCommentLike(commentId);
                            if (success) {
                              // Reload comments to get updated like status
                              await controller.loadPrayerComments(prayerId);
                              setState(() {}); // Refresh UI
                            }
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                ((comment['is_liked'] ?? 0) == 1) ? Icons.favorite : Icons.favorite_border,
                                size: 16,
                                color: AppTheme.iconscolor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                (comment['like_count'] ?? 0) > 0 ? '${comment['like_count']}' : 'Like',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.iconscolor,
                                  fontWeight: ((comment['is_liked'] ?? 0) == 1) ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
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
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.reply,
                                size: 16,
                                color: AppTheme.iconscolor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Reply',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.iconscolor,
                                ),
                              ),
                              if ((comment['reply_count'] ?? 0) > 0)
                                Text(
                                  ' (${comment['reply_count']})',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.iconscolor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
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
                        SizedBox(width: ResponsiveHelper.spacing(context, 16)),
                        // edit feature: Edit Button - Show for all comments within 15 minutes
                        _buildEditButton(context, comment, prayerId), // edit feature
                        SizedBox(width: ResponsiveHelper.spacing(context, 16)),
                        // Report Button - Only show for other users' comments
                        if (currentUserId != null && (comment['user_id'] as int? ?? 0) != currentUserId)
                          InkWell(
                            onTap: () => _showReportDialog(context, comment),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.flag_outlined,
                                  size: 16,
                                  color: AppTheme.iconscolor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Report',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.iconscolor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    // Reply Input (if shown)
                    if (showReplyInput[commentId] == true) ...[
                      const SizedBox(height: 12),
                      _buildReplyInput(context, commentId, prayerId),
                    ],
                    // edit feature: Edit Input (if shown)
                    if (showEditInput[commentId] == true) ...[ // edit feature
                      const SizedBox(height: 12), // edit feature
                      _buildEditInput(context, commentId, prayerId, 'prayer'), // edit feature
                    ], // edit feature
                    // Expand/Collapse button for top-level comment replies
                    if (comment['replies'] != null && (comment['replies'] as List).isNotEmpty) ...[
                      const SizedBox(height: 8),
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
                              size: 16,
                              color: AppTheme.iconscolor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              expandedReplies.contains(commentId) 
                                  ? 'Hide ${(comment['replies'] as List).length} ${(comment['replies'] as List).length == 1 ? 'reply' : 'replies'}'
                                  : 'Show ${(comment['replies'] as List).length} ${(comment['replies'] as List).length == 1 ? 'reply' : 'replies'}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF9F9467),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    // Nested Replies (recursive - supports multi-level nesting) - only show if expanded
                    if (comment['replies'] != null && (comment['replies'] as List).isNotEmpty && expandedReplies.contains(commentId)) ...[
                      const SizedBox(height: 12),
                      ...((comment['replies'] as List).map((reply) => _buildReplyCard(context, reply, prayerId, depth: 0))),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build Emoji Reactions Widget
  Widget _buildEmojiReactions(BuildContext context, int prayerId, PrayersController controller) {
    return Obx(() {
      final reactions = controller.prayerEmojiReactions;
      final hasReactions = reactions.isNotEmpty;
      final quickEmojisList = controller.quickEmojis;
      
      // Debug logging
      print('🔍 _buildEmojiReactions: hasReactions=$hasReactions, reactions count=${reactions.length}');
      if (hasReactions) {
        reactions.forEach((key, users) {
          print('   - Emoji key: "$key" (${users.length} users)');
        });
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
                          color: Colors.black,
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
            
            // Quick Emoji Buttons - Phone Style (No borders, minimal gap)
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
                        color: AppTheme.iconscolor,
                      ),
                    ),
                  )
                else
                  ...quickEmojisList.map((emojiData) {
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
                    
                    // If still empty, skip this emoji (don't make it clickable)
                    final isValidEmoji = emoji != null && emoji.trim().isNotEmpty;
                    
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: isValidEmoji ? () async {
                          // Show a loading indicator
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (loadingContext) => Center(
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: CircularProgressIndicator(
                                  color: AppTheme.iconscolor,
                                  strokeWidth: 3,
                                ),
                              ),
                            ),
                          );

                          try {
                            final success = await controller.addEmojiReaction(prayerId, emoji!);

                            // Close loading indicator
                            if (mounted) {
                              Navigator.of(context).pop();
                            }

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
                                controller.message.value.isNotEmpty
                                    ? controller.message.value
                                    : 'Failed to add reaction. Please try again.',
                                isError: true,
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              Navigator.of(context).pop();
                            }
                            _showCustomSnackbar(
                              context,
                              'Error',
                              'Failed to add reaction',
                              isError: true,
                            );
                          }
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
                              userEmail: userEmail,
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
                    onTap: () => _showEmojiPicker(context, prayerId, commentController),
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
                          
                          // Find matching emoji
                          for (var emoji in controller.availableEmojis) {
                            final emojiCharFromList = emoji['emoji_char'] as String? ?? '';
                            final emojiNameFromList = emoji['name'] as String? ?? '';
                            final emojiIdFromList = emoji['id']?.toString() ?? '';

                            if (emojiCharFromList.trim() == emojiChar.trim() ||
                                emojiCharFromList == emojiChar ||
                                emojiNameFromList.toLowerCase().contains(emojiChar.toLowerCase()) ||
                                (emojiIdFromList.isNotEmpty && emojiIdFromList == emojiChar)) {
                              fruitEmoji = emoji;
                              break;
                            }
                          }
                          
                          if (fruitEmoji != null) {
                            return HomeScreen.buildEmojiDisplay(
                              context,
                              fruitEmoji!,
                              size: 20,
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
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
              SizedBox(height: ResponsiveHelper.spacing(context, 12)),
              Wrap(
                spacing: ResponsiveHelper.spacing(context, 6),
                runSpacing: ResponsiveHelper.spacing(context, 6),
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
                    // Strategy 5: Match by Name (base fruit name)
                    final emojiNameFromList = emoji['name'] as String? ?? '';
                    if (emojiNameFromList.isNotEmpty && emojiNameFromList.toLowerCase().contains(emojiKey.toLowerCase())) {
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
                            width: 28,
                            height: 28,
                            child: HomeScreen.buildEmojiDisplay(
                              context,
                              fruitEmoji,
                              size: 28,
                            ),
                          )
                        else
                          // Fallback: show placeholder
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.sentiment_satisfied,
                              size: 18,
                              color: AppTheme.iconscolor,
                            ),
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
                                  color: AppTheme.iconscolor,
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
                              color: Colors.black,
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
                                if (!photoPath.startsWith('assets/') && 
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
                                final emojiNameFromList = emoji['name'] as String? ?? '';

                                // Strategy 1: Match by emoji_char
                                if (emojiCharFromList.isNotEmpty && 
                                    (emojiCharFromList.trim() == emojiChar.trim() || emojiCharFromList == emojiChar)) {
                                  fruitEmoji = emoji;
                                  break;
                                }
                                // Strategy 2: Match by code
                                if (emojiCodeFromList.isNotEmpty && 
                                    (emojiCodeFromList.trim() == emojiChar.trim() || emojiCodeFromList == emojiChar)) {
                                  fruitEmoji = emoji;
                                  break;
                                }
                                // Strategy 3: Match by ID
                                if (emojiIdFromList.isNotEmpty && emojiIdFromList == emojiChar) {
                                  fruitEmoji = emoji;
                                  break;
                                }
                                // Strategy 4: Match by image_url
                                if (emojiImageUrlFromList.isNotEmpty) {
                                  String? keyFilename;
                                  String? listFilename;
                                  
                                  if (emojiChar.contains('/')) {
                                    keyFilename = emojiChar.split('/').last.replaceAll('%20', ' ').toLowerCase();
                                  } else {
                                    keyFilename = emojiChar.toLowerCase();
                                  }
                                  
                                  if (emojiImageUrlFromList.contains('/')) {
                                    listFilename = emojiImageUrlFromList.split('/').last.replaceAll('%20', ' ').toLowerCase();
                                  } else {
                                    listFilename = emojiImageUrlFromList.toLowerCase();
                                  }
                                  
                                  if (keyFilename == listFilename || 
                                      emojiImageUrlFromList.contains(emojiChar) || 
                                      emojiChar.contains(emojiImageUrlFromList)) {
                                    fruitEmoji = emoji;
                                    break;
                                  }
                                }
                                // Strategy 5: Match by Name (base fruit name)
                                if (emojiNameFromList.isNotEmpty && emojiNameFromList.toLowerCase().contains(emojiChar.toLowerCase())) {
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
                                              color: Colors.black,
                                            ),
                                          ),
                                          Text(
                                            TimeHelper.getTimeAgo(userData['created_at'] as String?),
                                            style: TextStyle(
                                              fontSize: ResponsiveHelper.fontSize(context, mobile: 11),
                                              color: AppTheme.iconscolor,
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
                                          color: AppTheme.iconscolor,
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
                                final firstEmojiChar = reactions.keys.isNotEmpty ? reactions.keys.first : '';
                                Map<String, dynamic>? firstFruitEmoji;
                                if (firstEmojiChar.isNotEmpty) {
                                  for (var emoji in controller.availableEmojis) {
                                    final emojiCharFromList = emoji['emoji_char'] as String? ?? '';
                                    if (emojiCharFromList.trim() == firstEmojiChar.trim() || 
                                        emojiCharFromList == firstEmojiChar) {
                                      firstFruitEmoji = emoji;
                                      break;
                                    }
                                  }
                                }
                                _showReactionUsersDialog(context, firstEmojiChar, allUsers, firstFruitEmoji);
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
        ),
      );
    });
  }

  Widget _buildReplyInput(BuildContext context, int parentCommentId, int prayerId) {
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
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
                hintStyle: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 13,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                prefixIcon: IconButton(
                  icon: const Icon(Icons.emoji_emotions_outlined, color: Color(0xFF8B4513)),
                  onPressed: () => _showEmojiPicker(context, prayerId, replyController),
                ),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _handleSendReply(prayerId, parentCommentId, replyController),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isSending ? null : () => _handleSendReply(prayerId, parentCommentId, replyController),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSending ? Colors.grey : AppTheme.iconscolor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 18,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildReplyCard(BuildContext context, Map<String, dynamic> reply, int prayerId, {int depth = 0}) {
    final content = reply['content'] as String? ?? '';
    final trimmed = content.trim();
    
    // Safety check: Don't display emoji reactions as replies
    if (trimmed.length <= 4) {
      final emojiRegex = RegExp(
        r'[\u{1F300}-\u{1F9FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]|[\u{1F600}-\u{1F64F}]|[\u{1F680}-\u{1F6FF}]|[\u{2764}\u{FE0F}]|[\u{2728}]|[\u{2B50}]',
        unicode: true,
      );
      if (emojiRegex.hasMatch(trimmed)) {
        return const SizedBox.shrink();
      }
    }
    
    final timeAgo = TimeHelper.getTimeAgo(reply['created_at'] as String?);
    final profilePhoto = reply['profile_photo'] as String?;
    final replyId = reply['id'] as int;
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
    
    // Initialize reply controller if not exists
    if (!replyControllers.containsKey(replyId)) {
      replyControllers[replyId] = TextEditingController();
    }
    
    // Calculate left margin based on depth (responsive - less indentation)
    final leftMargin = ResponsiveHelper.spacing(context, 16) + (depth * ResponsiveHelper.spacing(context, 16));
    
    return Container(
      margin: EdgeInsets.only(
        left: leftMargin,
        top: ResponsiveHelper.spacing(context, 8),
        bottom: ResponsiveHelper.spacing(context, 8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thread connector line - vertical line for nested structure
          if (depth > 0)
            Container(
              width: 2,
              margin: EdgeInsets.only(
                top: ResponsiveHelper.spacing(context, 20),
                right: ResponsiveHelper.spacing(context, 10),
              ),
              decoration: BoxDecoration(
                color: Colors.grey[300]!.withOpacity(0.6),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 12)),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(ResponsiveHelper.isMobile(context) ? 12 : 14),
                    border: Border.all(
                      color: Colors.grey.withOpacity(0.2),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: ResponsiveHelper.isMobile(context) ? 16 : 18,
                            backgroundColor: const Color(0xFFFFD1DC),
                            backgroundImage: profilePhotoUrl != null
                                ? NetworkImage(profilePhotoUrl)
                                : null,
                            child: profilePhotoUrl == null
                                ? Icon(
                                    Icons.person_rounded,
                                    color: Colors.black87,
                                    size: ResponsiveHelper.fontSize(context, mobile: 16),
                                  )
                                : null,
                          ),
                          SizedBox(width: ResponsiveHelper.spacing(context, 10)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        reply['user_name'] as String? ?? 'Someone',
                                        style: TextStyle(
                                          fontSize: ResponsiveHelper.fontSize(context, mobile: 13),
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                    if (timeAgo.isNotEmpty) ...[
                                      SizedBox(width: ResponsiveHelper.spacing(context, 6)),
                                      Text(
                                        '•',
                                        style: TextStyle(
                                          fontSize: ResponsiveHelper.fontSize(context, mobile: 11),
                                          color: AppTheme.iconscolor,
                                        ),
                                      ),
                                      SizedBox(width: ResponsiveHelper.spacing(context, 6)),
                                      Flexible(
                                        child: Text(
                                          timeAgo,
                                          style: TextStyle(
                                            fontSize: ResponsiveHelper.fontSize(context, mobile: 11),
                                            color: AppTheme.iconscolor,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                SizedBox(height: ResponsiveHelper.spacing(context, 6)),
                                Text(
                                  AutoTranslateHelper.getTranslatedTextSync(
                                    text: content,
                                    sourceLanguage: reply['language'] as String?,
                                  ),
                                  style: TextStyle(
                                    fontSize: ResponsiveHelper.fontSize(context, mobile: 13),
                                    color: Colors.black87,
                                    height: 1.5,
                                  ),
                                ),
                                // edit feature: Show "edited" label if reply was edited
                                if (reply['is_edited'] == true || reply['is_edited'] == 1) ...[
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
                                SizedBox(height: ResponsiveHelper.spacing(context, 10)),
                                Wrap(
                                  spacing: ResponsiveHelper.spacing(context, 12),
                                  runSpacing: ResponsiveHelper.spacing(context, 8),
                                  children: [
                                    // Like Button for Reply
                                    InkWell(
                                      onTap: () async {
                                        final success = await controller.toggleCommentLike(replyId);
                                        if (success) {
                                          // Reload comments to get updated like status
                                          await controller.loadPrayerComments(prayerId);
                                          setState(() {}); // Refresh UI
                                        }
                                      },
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            ((reply['is_liked'] ?? 0) == 1) ? Icons.favorite : Icons.favorite_border,
                                            size: ResponsiveHelper.fontSize(context, mobile: 14),
                                            color: AppTheme.iconscolor,
                                          ),
                                          if ((reply['like_count'] ?? 0) > 0) ...[
                                            SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                                            Text(
                                              '${reply['like_count']}',
                                              style: TextStyle(
                                                fontSize: ResponsiveHelper.fontSize(context, mobile: 11),
                                                color: AppTheme.iconscolor,
                                                fontWeight: ((reply['is_liked'] ?? 0) == 1) ? FontWeight.w600 : FontWeight.normal,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    // Reply Button for nested replies
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
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.reply,
                                            size: ResponsiveHelper.fontSize(context, mobile: 14),
                                            color: AppTheme.iconscolor,
                                          ),
                                          SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                                          Text(
                                            'Reply',
                                            style: TextStyle(
                                              fontSize: ResponsiveHelper.fontSize(context, mobile: 11),
                                              color: AppTheme.iconscolor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Report Button for Reply - Only show for other users' replies
                                    if (currentUserId != null && (reply['user_id'] as int? ?? 0) != currentUserId)
                                      InkWell(
                                        onTap: () => _showReportDialog(context, reply),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.flag_outlined,
                                              size: ResponsiveHelper.fontSize(context, mobile: 14),
                                              color: AppTheme.iconscolor,
                                            ),
                                            SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                                            Text(
                                              'Report',
                                              style: TextStyle(
                                                fontSize: ResponsiveHelper.fontSize(context, mobile: 11),
                                                color: AppTheme.iconscolor,
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
                      if (showReplyInput[replyId] == true) ...[
                        SizedBox(height: ResponsiveHelper.spacing(context, 10)),
                        _buildReplyInput(context, replyId, prayerId),
                      ],
                      // Expand/Collapse button for nested replies
                      if (reply['replies'] != null && (reply['replies'] as List).isNotEmpty) ...[
                        SizedBox(height: ResponsiveHelper.spacing(context, 8)),
                        InkWell(
                          onTap: () {
                            setState(() {
                              if (expandedReplies.contains(replyId)) {
                                expandedReplies.remove(replyId);
                              } else {
                                expandedReplies.add(replyId);
                              }
                            });
                          },
                          child: Row(
                            children: [
                              Icon(
                                expandedReplies.contains(replyId) ? Icons.expand_less : Icons.expand_more,
                                size: ResponsiveHelper.fontSize(context, mobile: 16),
                                color: AppTheme.iconscolor,
                              ),
                              SizedBox(width: ResponsiveHelper.spacing(context, 6)),
                              Text(
                                expandedReplies.contains(replyId) 
                                    ? 'Hide ${(reply['replies'] as List).length} ${(reply['replies'] as List).length == 1 ? 'reply' : 'replies'}'
                                    : 'Show ${(reply['replies'] as List).length} ${(reply['replies'] as List).length == 1 ? 'reply' : 'replies'}',
                                style: TextStyle(
                                  fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                                  color: AppTheme.iconscolor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Nested Replies (recursive) - only show if expanded - placed outside container
                if (reply['replies'] != null && (reply['replies'] as List).isNotEmpty && expandedReplies.contains(replyId)) ...[
                  SizedBox(height: ResponsiveHelper.spacing(context, 8)),
                  ...((reply['replies'] as List).map((nestedReply) => _buildReplyCard(context, nestedReply, prayerId, depth: depth + 1))),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showReportDialog(BuildContext context, Map<String, dynamic> comment) {
    final reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Report Comment',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF5F4628),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Why are you reporting this comment?',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: InputDecoration(
                  hintText: 'Reason (optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                final commentId = comment['id'] as int;
                final success = await controller.reportComment(
                  commentId,
                  reason: reasonController.text.trim().isNotEmpty 
                      ? reasonController.text.trim() 
                      : null,
                );
                
                if (success) {
                  _showCustomSnackbar(
                    context,
                    'Reported',
                    'Comment reported successfully. Our team will review it.',
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
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.iconscolor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Report',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Show Emoji Picker Dialog
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
                          style: TextStyle(
                            fontSize: ResponsiveHelper.fontSize(context, mobile: 18),
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        SizedBox(height: ResponsiveHelper.spacing(context, 2)),
                        Text(
                          'Tap to see who reacted with this emoji',
                          style: TextStyle(
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
                        style: TextStyle(
                          fontSize: ResponsiveHelper.fontSize(context, mobile: 15),
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                      ),
                      subtitle: Text(
                        TimeHelper.getTimeAgo(user['created_at'] as String?),
                        style: TextStyle(
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
}

