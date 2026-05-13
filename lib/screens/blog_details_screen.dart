import 'package:flutter/material.dart';
import 'package:fruitsofspirit/utils/app_theme.dart';
import 'package:fruitsofspirit/utils/share_helper.dart';

import 'package:get/get.dart';
import 'package:fruitsofspirit/controllers/blogs_controller.dart';
import 'package:fruitsofspirit/utils/auto_translate_helper.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';
import 'package:fruitsofspirit/widgets/see_translation_widget.dart';
import 'package:fruitsofspirit/widgets/cached_image.dart';
import 'package:fruitsofspirit/services/user_storage.dart';
import 'package:fruitsofspirit/services/comments_service.dart';
import 'package:fruitsofspirit/screens/home_screen.dart';
import 'package:fruitsofspirit/services/user_blocking_service.dart';
import 'package:fruitsofspirit/utils/fruit_emoji_helper.dart';
import 'package:fruitsofspirit/utils/report_utils.dart';
import 'package:fruitsofspirit/utils/sticker_emoji_helper.dart';
import 'package:fruitsofspirit/widgets/emoji_sticker_picker.dart';
import 'package:fruitsofspirit/services/blogs_service.dart'; // edit feature
import 'package:fruitsofspirit/utils/time_helper.dart';

/// Blog Details Screen
/// User-friendly and attractive UI with like, comment, and ask questions functionality
class BlogDetailsScreen extends StatefulWidget {
  const BlogDetailsScreen({Key? key}) : super(key: key);

  @override
  State<BlogDetailsScreen> createState() => _BlogDetailsScreenState();
}

// Message model for proper text/sticker separation
class CommentMessage {
  final String? text;
  final String? stickerId;
  final bool isSticker;

  CommentMessage({this.text, this.stickerId, required this.isSticker});
}

class _BlogDetailsScreenState extends State<BlogDetailsScreen> {
  final BlogsController controller = Get.find<BlogsController>();
  final commentController = TextEditingController();
  final List<CommentMessage> commentMessages = [];
  final questionController = TextEditingController();
  final replyControllers = <int, TextEditingController>{};
  final replyFocusNodes = <int, FocusNode>{};
  final showReplyInput = <int, bool>{};
  final expandedReplies = <int>{}; // Track which replies are expanded
  final ScrollController _scrollController = ScrollController();
  var isSubmittingComment = false.obs;
  var isSubmittingQuestion = false.obs;
  var showQuestionInput = false.obs;
  int? currentUserId;
  String? userEmail;
  int? _loadedBlogId; // Track which blog is currently loaded
  // edit feature: Edit mode state
  final editControllers = <int, TextEditingController>{}; // edit feature
  final showEditInput = <int, bool>{}; // edit feature
  var isEditingComment = false.obs; // edit feature

  // edit feature: Post edit state
  final postEditTitleController = TextEditingController(); // edit feature
  final postEditBodyController = TextEditingController(); // edit feature
  final postEditCategoryController = TextEditingController(); // edit feature
  var showPostEditInput = false.obs; // edit feature
  var isEditingPost = false.obs; // edit feature

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
        currentUserId = id;
      }
    }
  }

  Future<void> _loadUserEmail() async {
    userEmail = await UserStorage.getUserEmail();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    commentController.dispose();
    questionController.dispose();
    for (var controller in replyControllers.values) {
      controller.dispose();
    }
    for (var focusNode in replyFocusNodes.values) {
      focusNode.dispose();
    }
    // edit feature: Dispose post edit controllers
    postEditTitleController.dispose(); // edit feature
    postEditBodyController.dispose(); // edit feature
    postEditCategoryController.dispose(); // edit feature
    super.dispose();
  }

  /// Show a custom snackbar using ScaffoldMessenger
  void _showCustomSnackbar(BuildContext context, String title, String message, {bool isError = false}) {
    if (!mounted) return;
    
    // Close any existing snackbars
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    
    final isModeration = message.toLowerCase().contains('community guidelines') ||
        message.toLowerCase().contains('inappropriate content') ||
        message.toLowerCase().contains('terms') ||
        message.toLowerCase().contains('moderation');
    
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

  // edit feature: Check if comment can be edited (within 15 minutes only)
  bool _canEditComment(Map<String, dynamic> comment) { // edit feature
    print('🔍 Edit check - created_at: ${comment['created_at']}'); // debug
    
    // Check if user is logged in
    final currentUserId = controller.userId.value;
    if (currentUserId == 0) {
      print('❌ Edit blocked: user not logged in'); // debug
      return false;
    }
    
    // Check if user owns the comment
    if (comment['user_id'] != currentUserId) {
      print('❌ Edit blocked: not comment owner'); // debug
      return false;
    }
    
    try {
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
      print('🕐 Blog Time check (UTC): ${difference.inMinutes} minutes, canEdit: $canEdit'); // debug
      print('🌍 Blog Device timezone: ${DateTime.now().timeZoneName} (${DateTime.now().timeZoneOffset})'); // debug
      
      // CRITICAL DEBUG: Show exact frontend calculation to compare with backend
      print('🔍 BLOG FRONTEND TIME CALCULATION DEBUG:'); // debug
      print('   - Raw created_at: ${comment['created_at']}'); // debug
      print('   - Formatted date: $formattedDate'); // debug
      print('   - Server time UTC (fixed): $serverTimeUtc'); // debug
      print('   - Current UTC: $nowUtc'); // debug
      print('   - Frontend minutes diff: ${difference.inMinutes}'); // debug
      print('   - Frontend canEdit: $canEdit'); // debug
      print('🔍 BLOG FRONTEND DEBUG COMPLETE'); // debug
      
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
  Widget _buildEditButton(BuildContext context, Map<String, dynamic> comment, int blogId) { // edit feature
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
  Widget _buildEditInput(BuildContext context, int commentId, int blogId, String postType) { // edit feature
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
              fontSize: ResponsiveHelper.fontSize(context, mobile: 12), // edit feature
              fontWeight: FontWeight.bold, // edit feature
              color: const Color(0xFF1976D2), // edit feature
            ), // edit feature
          ), // edit feature
          SizedBox(height: ResponsiveHelper.spacing(context, 8)), // edit feature
          TextField( // edit feature
            controller: editController, // edit feature
            decoration: InputDecoration( // edit feature
              hintText: 'Edit your comment...', // edit feature
              border: InputBorder.none, // edit feature
              hintStyle: ResponsiveHelper.textStyle( // edit feature
                context, // edit feature
                fontSize: 13, // edit feature
                color: Colors.blue[400], // edit feature
              ), // edit feature
              contentPadding: ResponsiveHelper.padding( // edit feature
                context, // edit feature
                horizontal: 12, // edit feature
                vertical: 8, // edit feature
              ), // edit feature
            ), // edit feature
            maxLines: null, // edit feature
            textInputAction: TextInputAction.newline, // edit feature
            style: ResponsiveHelper.textStyle( // edit feature
              context, // edit feature
              fontSize: 13, // edit feature
              color: const Color(0xFF1565C0), // edit feature
            ), // edit feature
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
                onPressed: () => _editComment(commentId, blogId, postType), // edit feature
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
                        width: ResponsiveHelper.iconSize(context, mobile: 16), // edit feature
                        height: ResponsiveHelper.iconSize(context, mobile: 16), // edit feature
                        child: CircularProgressIndicator( // edit feature
                          strokeWidth: 2, // edit feature
                          color: Colors.white, // edit feature
                        ), // edit feature
                      ) // edit feature
                    : Text( // edit feature
                        'Save', // edit feature
                        style: ResponsiveHelper.textStyle( // edit feature
                          context, // edit feature
                          fontSize: 12, // edit feature
                          color: Colors.white, // edit feature
                        ), // edit feature
                      )), // edit feature
              ), // edit feature
            ], // edit feature
          ), // edit feature
        ], // edit feature
      ), // edit feature
    ); // edit feature
  } // edit feature

  // edit feature: Edit comment method
  Future<void> _editComment(int commentId, int blogId, String postType) async { // edit feature
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
      await CommentsService.editComment( // edit feature
        userId: currentUserId!, // edit feature
        commentId: commentId, // edit feature
        postType: postType, // edit feature
        postId: blogId, // edit feature
        content: content, // edit feature
      ); // edit feature

      setState(() { // edit feature
        showEditInput[commentId] = false; // edit feature
      }); // edit feature

      await controller.loadBlogDetails(blogId); // edit feature

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
        e.toString().replaceAll('Exception: ', ''), // edit feature
        backgroundColor: Colors.red, // edit feature
        colorText: Colors.white, // edit feature
        duration: const Duration(seconds: 2), // edit feature
      ); // edit feature
    } finally { // edit feature
      isEditingComment.value = false; // edit feature
    } // edit feature
  } // edit feature

  // edit feature: Check if blog post can be edited (always allow editing)
  bool _canEditPost(Map<String, dynamic> blog) { // edit feature
    print('🔍 Edit check - always allowing editing'); // debug
    return true; // edit feature: Always allow editing
  } // edit feature

  // edit feature: Edit blog post method
  Future<void> _editPost(int blogId) async { // edit feature
    final title = postEditTitleController.text.trim(); // edit feature
    final body = postEditBodyController.text.trim(); // edit feature
    final category = postEditCategoryController.text.trim(); // edit feature

    if (title.isEmpty && body.isEmpty && category.isEmpty) { // edit feature
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
      // edit feature: Import BlogsService
      final response = await BlogsService.editBlog( // edit feature
        userId: currentUserId!, // edit feature
        blogId: blogId, // edit feature
        title: title.isEmpty ? null : title, // edit feature
        body: body.isEmpty ? null : body, // edit feature
        category: category.isEmpty ? null : category, // edit feature
      ); // edit feature

      showPostEditInput.value = false; // edit feature
      await controller.loadBlogDetails(blogId); // edit feature

      Get.snackbar( // edit feature
        'Success', // edit feature
        'Blog edited successfully', // edit feature
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

  /// Get category color
  Color _getCategoryColor(String? category) {
    switch (category?.toLowerCase()) {
      case 'healing':
        return const Color(0xFF4CAF50);
      case 'peace':
      case 'anxiety':
        return const Color(0xFF2196F3);
      case 'work':
      case 'provision':
        return const Color(0xFFFF9800);
      case 'relationships':
        return const Color(0xFFE91E63);
      case 'guidance':
        return const Color(0xFF9C27B0);
      case 'faithfulness':
        return const Color(0xFF673AB7);
      default:
        return const Color(0xFF5F4628);
    }
  }

  /// Get image provider
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
    final blogId = Get.arguments as int? ?? 0;
    
    // Only reload if blog ID is different from the loaded blog ID
    if (blogId > 0 && _loadedBlogId != blogId) {
      _loadedBlogId = blogId;
      
      // Clear previous blog data immediately to prevent showing stale data
      controller.selectedBlog.clear();
      controller.blogComments.clear();
      controller.isLoading.value = true;
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.loadBlogDetails(blogId);
      });
    }

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
              Icons.arrow_back,
              color: AppTheme.iconscolor,
              size: ResponsiveHelper.iconSize(context, mobile: 24, tablet: 28, desktop: 32),
            ),
            onPressed: (){
              final dialogContext = Get.overlayContext;
              if (dialogContext != null) {
                Navigator.of(dialogContext, rootNavigator: true).pop();
              } else if (context.mounted) {
                Navigator.of(context, rootNavigator: true).pop();
              }
            },
          ),
          title: Text(
            'Blog Post',
            style: ResponsiveHelper.textStyle(
              context,
              fontSize: ResponsiveHelper.fontSize(context, mobile: 18, tablet: 20, desktop: 22),
              fontWeight: FontWeight.bold,
              color: const Color(0xFF000000),
            ),
          ),
          actions: [
            // edit feature: Edit post button
            Obx(() {
              final blog = controller.selectedBlog;
              if (blog.isNotEmpty && _canEditPost(blog)) {
                return IconButton(
                  icon: Icon(
                    Icons.edit,
                    color: AppTheme.iconscolor,
                    size: ResponsiveHelper.iconSize(context, mobile: 24, tablet: 28),
                  ),
                  onPressed: () {
                    setState(() {
                      postEditTitleController.text = blog['title'] as String? ?? '';
                      postEditBodyController.text = blog['body'] as String? ?? '';
                      postEditCategoryController.text = blog['category'] as String? ?? '';
                      showPostEditInput.value = true;
                    });
                  },
                );
              }
              return const SizedBox.shrink();
            }),
            IconButton(
              icon: Icon(
                Icons.share,
                color: AppTheme.iconscolor,
                size: ResponsiveHelper.iconSize(context, mobile: 24, tablet: 28, desktop: 32),
              ),
              onPressed: () {
                final blog = controller.selectedBlog;
                final baseUrl = 'http://admin.fosmessenger.com/'; // Fixed base URL to match API config
                final imagePath = blog['image_url'] as String?;
                String? blogImageUrl;
                if (imagePath != null && imagePath.toString().trim().isNotEmpty) {
                  if (imagePath.toString().startsWith('http')) {
                    blogImageUrl = imagePath.toString();
                  } else {
                    final cleanPath = imagePath.toString().startsWith('/') 
                        ? imagePath.toString().substring(1) 
                        : imagePath.toString();
                    blogImageUrl = '$baseUrl$cleanPath';
                  }
                }

                ShareHelper.shareContent(
                  context: context,
                  contentType: 'blog',
                  contentId: blogId,
                  title: blog['title'] ?? 'Blog',
                  content: blog['body'],
                  mediaUrl: blogImageUrl,
                );
              },

            ),
          ],
        ),
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.selectedBlog.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  color: AppTheme.iconscolor,
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                Text(
                  'Loading blog...',
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

        if (controller.selectedBlog.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: ResponsiveHelper.iconSize(context, mobile: 64),
                  color: AppTheme.iconscolor,
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                Text(
                  'Blog not found',
                  style: ResponsiveHelper.textStyle(
                    context,
                    fontSize: ResponsiveHelper.fontSize(context, mobile: 15, tablet: 16, desktop: 17),
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        final blog = controller.selectedBlog;
        final baseUrl = 'http://admin.fosmessenger.com/'; // Fixed base URL to match API config
        final imagePath = blog['image_url'] as String?;
        String? imageUrl;
        
        print('🔍 Blog Image Debug:');
        print('   Full blog data: $blog');
        print('   Raw image_url from backend: $imagePath');
        print('   Blog data keys: ${blog.keys.toList()}');
        print('   Base URL: $baseUrl');
        
        if (imagePath != null && imagePath.toString().trim().isNotEmpty) {
          if (imagePath.toString().startsWith('http')) {
            imageUrl = imagePath.toString();
            print('   Using full URL: $imageUrl');
          } else {
            final cleanPath = imagePath.toString().startsWith('/') 
                ? imagePath.toString().substring(1) 
                : imagePath.toString();
            imageUrl = '$baseUrl$cleanPath';
            print('   Constructed URL: $imageUrl');
          }
        } else {
          print('   ⚠️ Image path is null or empty');
          
          // Try alternative field names
          print('   Checking alternative fields...');
          if (blog['image'] != null) {
            print('   Found "image" field: ${blog['image']}');
          }
          if (blog['featured_image'] != null) {
            print('   Found "featured_image" field: ${blog['featured_image']}');
          }
          if (blog['thumbnail'] != null) {
            print('   Found "thumbnail" field: ${blog['thumbnail']}');
          }
        }

        final isLiked = blog['is_liked'] == true || blog['is_liked'] == 1;
        final likeCount = int.tryParse((blog['like_count'] ?? 0).toString()) ?? 0;
        final commentCount = controller.blogComments.length;

        return RefreshIndicator(
          onRefresh: () => controller.loadBlogDetails(blogId),
          color: AppTheme.iconscolor,
          backgroundColor: Colors.white,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: ResponsiveHelper.padding(context, all: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Blog Image
                      if (imageUrl != null && imageUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 20)),
                          child: CachedImage(
                            imageUrl: imageUrl,
                            height: ResponsiveHelper.imageHeight(context, mobile: 280, tablet: 320, desktop: 360),
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorWidget: Container(
                              height: ResponsiveHelper.imageHeight(context, mobile: 280, tablet: 320, desktop: 360),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFFFAF6EC),
                                    const Color(0xFF9F9467).withOpacity(0.2),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Icon(
                                Icons.image_not_supported,
                                size: ResponsiveHelper.iconSize(context, mobile: 60),
                                color: AppTheme.iconscolor,
                              ),
                            ),
                          ),
                        ),
                      if (imageUrl != null && imageUrl.isNotEmpty) SizedBox(height: ResponsiveHelper.spacing(context, 20)),

                      // Main Blog Card
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
                            // Category Badge
                            if (blog['category'] != null && blog['category'].toString().isNotEmpty)
                              Container(
                                margin: EdgeInsets.only(bottom: ResponsiveHelper.spacing(context, 16)),
                                padding: ResponsiveHelper.padding(context, horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _getCategoryColor(blog['category']).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
                                  border: Border.all(
                                    color: _getCategoryColor(blog['category']).withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  blog['category'] as String,
                                  style: ResponsiveHelper.textStyle(
                                    context,
                                    fontSize: ResponsiveHelper.fontSize(context, mobile: 11, tablet: 12, desktop: 13),
                                    fontWeight: FontWeight.bold,
                                    color: _getCategoryColor(blog['category']),
                                  ),
                                ),
                              ),

                            // Title
                            Column( // edit feature
                              crossAxisAlignment: CrossAxisAlignment.start, // edit feature
                              children: [ // edit feature
                                Text( // edit feature
                                  AutoTranslateHelper.getTranslatedTextSync( // edit feature
                                    text: blog['title'] as String? ?? 'Untitled', // edit feature
                                    sourceLanguage: blog['language'] as String?, // edit feature
                                  ), // edit feature
                                  style: ResponsiveHelper.textStyle( // edit feature
                                    context, // edit feature
                                    fontSize: ResponsiveHelper.fontSize(context, mobile: 20, tablet: 22), // edit feature
                                    fontWeight: FontWeight.bold, // edit feature
                                    color: Colors.black, // edit feature
                                    height: 1.3, // edit feature
                                    letterSpacing: 0.2, // edit feature
                                  ), // edit feature
                                ), // edit feature
                                // edit feature: Show "edited" label if blog was edited
                                if (blog['is_edited'] == true || blog['is_edited'] == 1) ...[ // edit feature
                                  SizedBox(height: ResponsiveHelper.spacing(context, 4)), // edit feature
                                  Text( // edit feature
                                    'edited', // edit feature
                                    style: TextStyle( // edit feature
                                      fontSize: ResponsiveHelper.fontSize(context, mobile: 10, tablet: 11), // edit feature
                                      color: Colors.grey[500],
                                      fontStyle: FontStyle.italic, // edit feature
                                    ), // edit feature
                                  ), // edit feature
                                ], // edit feature
                              ], // edit feature
                            ), // edit feature
                            SizedBox(height: ResponsiveHelper.spacing(context, 16)),

                            // Author Info Row
                            Row(
                              children: [
                                // Profile Photo
                                CircleAvatar(
                                  radius: ResponsiveHelper.iconSize(context, mobile: 20, tablet: 22, desktop: 24) / 2,
                                  backgroundColor: const Color(0xFFFFD1DC),
                                  backgroundImage: _getImageProvider(blog['profile_photo'] as String?),
                                  child: blog['profile_photo'] == null
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
                                      Text(
                                        blog['user_name'] as String? ?? 'Anonymous',
                                        style: ResponsiveHelper.textStyle(
                                          context,
                                          fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black,
                                        ),
                                      ),
                                      if (blog['created_at'] != null) ...[
                                        SizedBox(height: ResponsiveHelper.spacing(context, 4)),
                                        Text(
                                          TimeHelper.getTimeAgo(blog['created_at'] as String?),
                                          style: ResponsiveHelper.textStyle(
                                            context,
                                            fontSize: ResponsiveHelper.fontSize(context, mobile: 11, tablet: 12, desktop: 13),
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                _buildBlogOptions(context, blog),
                              ],
                            ),
                            // edit feature: Edit button for own posts within 15 minutes
                            if (_canEditPost(blog)) ...[ // edit feature
                              SizedBox(height: ResponsiveHelper.spacing(context, 8)), // edit feature
                              GestureDetector( // edit feature
                                onTap: () { // edit feature
                                  setState(() { // edit feature
                                    postEditTitleController.text = blog['title'] as String? ?? ''; // edit feature
                                    postEditBodyController.text = blog['body'] as String? ?? ''; // edit feature
                                    postEditCategoryController.text = blog['category'] as String? ?? ''; // edit feature
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
                                        size: ResponsiveHelper.iconSize(context, mobile: 14), // edit feature
                                        color: Colors.grey[700], // edit feature
                                      ), // edit feature
                                      SizedBox(width: ResponsiveHelper.spacing(context, 4)), // edit feature
                                      Text( // edit feature
                                        'Edit Post', // edit feature
                                        style: ResponsiveHelper.textStyle( // edit feature
                                          context, // edit feature
                                          fontSize: ResponsiveHelper.fontSize(context, mobile: 11, tablet: 12), // edit feature
                                          color: Colors.grey[700], // edit feature
                                        ), // edit feature
                                      ), // edit feature
                                    ], // edit feature
                                  ), // edit feature
                                ), // edit feature
                              ), // edit feature
                            ], // edit feature
                            SizedBox(height: ResponsiveHelper.spacing(context, 20)),

                            // Body Content
                            SeeTranslationWidget(
                              text: blog['body'] as String? ?? '',
                              sourceLanguage: blog['language'] as String?,
                              style: ResponsiveHelper.textStyle(
                                context,
                                fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                                color: Colors.grey[800],
                                height: 1.6,
                                letterSpacing: 0.1,
                              ),
                            ),
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
                                    'Edit Blog Post', // edit feature
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
                                      labelText: 'Title', // edit feature
                                      border: OutlineInputBorder( // edit feature
                                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)), // edit feature
                                      ), // edit feature
                                      contentPadding: ResponsiveHelper.padding(context, horizontal: 12, vertical: 12), // edit feature
                                    ), // edit feature
                                    maxLines: 2, // edit feature
                                    style: ResponsiveHelper.textStyle( // edit feature
                                      context, // edit feature
                                      fontSize: 13, // edit feature
                                    ), // edit feature
                                  ), // edit feature
                                  SizedBox(height: ResponsiveHelper.spacing(context, 12)), // edit feature
                                  TextField( // edit feature
                                    controller: postEditBodyController, // edit feature
                                    decoration: InputDecoration( // edit feature
                                      labelText: 'Content', // edit feature
                                      border: OutlineInputBorder( // edit feature
                                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)), // edit feature
                                      ), // edit feature
                                      contentPadding: ResponsiveHelper.padding(context, horizontal: 12, vertical: 12), // edit feature
                                    ), // edit feature
                                    maxLines: 5, // edit feature
                                    style: ResponsiveHelper.textStyle( // edit feature
                                      context, // edit feature
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
                                    style: ResponsiveHelper.textStyle( // edit feature
                                      context, // edit feature
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
                                          style: ResponsiveHelper.textStyle( // edit feature
                                            context, // edit feature
                                            fontSize: 12, // edit feature
                                            color: Colors.grey[600], // edit feature
                                          ), // edit feature
                                        ), // edit feature
                                      ), // edit feature
                                      SizedBox(width: ResponsiveHelper.spacing(context, 8)), // edit feature
                                      ElevatedButton( // edit feature
                                        onPressed: () => _editPost(blog['id'] as int), // edit feature
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
                                                width: ResponsiveHelper.iconSize(context, mobile: 16), // edit feature
                                                height: ResponsiveHelper.iconSize(context, mobile: 16), // edit feature
                                                child: CircularProgressIndicator( // edit feature
                                                  strokeWidth: 2, // edit feature
                                                  color: Colors.white, // edit feature
                                                ), // edit feature
                                              ) // edit feature
                                            : Text( // edit feature
                                                'Save', // edit feature
                                                style: ResponsiveHelper.textStyle( // edit feature
                                                  context, // edit feature
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
                            SizedBox(height: ResponsiveHelper.spacing(context, 24)),

                            // Like and Comment Count Row
                            Container(
                              padding: ResponsiveHelper.padding(context, vertical: 12),
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(color: Colors.grey.withOpacity(0.2)),
                                  bottom: BorderSide(color: Colors.grey.withOpacity(0.2)),
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Like Count
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.favorite,
                                        size: ResponsiveHelper.iconSize(context, mobile: 18),
                                        color: AppTheme.iconscolor,
                                      ),
                                      SizedBox(width: ResponsiveHelper.spacing(context, 6)),
                                      Text(
                                        '$likeCount',
                                        style: ResponsiveHelper.textStyle(
                                          context,
                                          fontSize: ResponsiveHelper.fontSize(context, mobile: 13, tablet: 14, desktop: 15),
                                          color: Colors.grey[700],
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(width: ResponsiveHelper.spacing(context, 24)),
                                  // Comment Count
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.comment_outlined,
                                        size: ResponsiveHelper.iconSize(context, mobile: 18),
                                        color: AppTheme.iconscolor,
                                      ),
                                      SizedBox(width: ResponsiveHelper.spacing(context, 6)),
                                      Text(
                                        '$commentCount',
                                        style: ResponsiveHelper.textStyle(
                                          context,
                                          fontSize: ResponsiveHelper.fontSize(context, mobile: 13, tablet: 14, desktop: 15),
                                          color: Colors.grey[700],
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: ResponsiveHelper.spacing(context, 16)),

                            // Emoji Reactions Section (replaces Like button)
                            _buildEmojiReactions(context, blogId, controller),
                            
                            SizedBox(height: ResponsiveHelper.spacing(context, 16)),

                            // Action Buttons Row (Comment and Ask)
                            Row(
                              children: [
                                // Comment Button
                                Expanded(
                                  child: InkWell(
                                    onTap: () {
                                      // Scroll to comment input
                                      FocusScope.of(context).requestFocus(FocusNode());
                                      Future.delayed(const Duration(milliseconds: 300), () {
                                        Scrollable.ensureVisible(
                                          context,
                                          duration: const Duration(milliseconds: 300),
                                        );
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                                    child: Container(
                                      padding: ResponsiveHelper.padding(context, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.transparent,
                                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.comment_outlined,
                                            color: AppTheme.iconscolor,
                                            size: ResponsiveHelper.iconSize(context, mobile: 22),
                                          ),
                                          SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                                          Text(
                                            'Comment',
                                            style: ResponsiveHelper.textStyle(
                                              context,
                                              fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                                // Ask Question Button
                                Expanded(
                                  child: InkWell(
                                    onTap: () {
                                      showQuestionInput.value = !showQuestionInput.value;
                                    },
                                    borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                                    child: Container(
                                      padding: ResponsiveHelper.padding(context, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: showQuestionInput.value 
                                            ? const Color(0xFF5F4628).withOpacity(0.1) 
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.help_outline,
                                            color: AppTheme.iconscolor,
                                            size: ResponsiveHelper.iconSize(context, mobile: 22),
                                          ),
                                          SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                                          Text(
                                            'Ask',
                                            style: ResponsiveHelper.textStyle(
                                              context,
                                              fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: ResponsiveHelper.spacing(context, 24)),

                      // Questions Section (Pinned/Sticky at Top) - Separate Container
                      Obx(() {
                        // Filter questions (comments starting with ? or marked as questions)
                        // Note: blog_comments table uses 'comment' field, not 'content'
                        final questions = controller.blogComments.where((comment) {
                          final commentText = (comment['comment'] as String? ?? comment['content'] as String? ?? '').trim();
                          // Check if it's a question: starts with ? (with or without space)
                          final isQuestion = comment['is_question'] == true || 
                                            comment['is_question'] == 1 ||
                                            comment['comment_type'] == 'question' ||
                                            commentText.startsWith('?') ||
                                            commentText.startsWith('? ');
                          return isQuestion && (comment['parent_comment_id'] == null || comment['parent_comment_id'] == 0);
                        }).toList()
                          ..sort((a, b) {
                            // Sort by created_at descending (newest first) for pinned questions
                            final aDate = a['created_at'] as String? ?? '';
                            final bDate = b['created_at'] as String? ?? '';
                            if (aDate.isEmpty && bDate.isEmpty) return 0;
                            if (aDate.isEmpty) return 1;
                            if (bDate.isEmpty) return -1;
                            try {
                              return DateTime.parse(bDate).compareTo(DateTime.parse(aDate));
                            } catch (e) {
                              return 0;
                            }
                          });
                        
                        if (questions.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        
                        return Container(
                          margin: EdgeInsets.only(bottom: ResponsiveHelper.spacing(context, 20)),
                          padding: ResponsiveHelper.padding(context, all: 20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFFE3F2FD),
                                const Color(0xFFBBDEFB).withOpacity(0.7),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 20)),
                            border: Border.all(
                              color: const Color(0xFF2196F3).withOpacity(0.3),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2196F3).withOpacity(0.15),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Questions Header with Pin Icon
                              Row(
                                children: [
                                  Container(
                                    padding: ResponsiveHelper.padding(context, all: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2196F3),
                                      borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 10)),
                                    ),
                                    child: Icon(
                                      Icons.push_pin_rounded,
                                      color: Colors.white,
                                      size: ResponsiveHelper.iconSize(context, mobile: 18),
                                    ),
                                  ),
                                  SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Questions',
                                          style: ResponsiveHelper.textStyle(
                                            context,
                                            fontSize: ResponsiveHelper.fontSize(context, mobile: 20, tablet: 21, desktop: 22),
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF1565C0),
                                          ),
                                        ),
                                        SizedBox(height: ResponsiveHelper.spacing(context, 4)),
                                        Text(
                                          'Pinned at top',
                                          style: TextStyle(
                                            fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                                            color: const Color(0xFF1976D2),
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: ResponsiveHelper.padding(context, horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2196F3).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                                    ),
                                    child: Text(
                                      '${questions.length}',
                                      style: ResponsiveHelper.textStyle(
                                        context,
                                        fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF1565C0),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: ResponsiveHelper.spacing(context, 20)),
                              // Questions List (newest first - pinned)
                              ...questions.map((question) => _buildQuestionCard(context, question, blogId)),
                            ],
                          ),
                        );
                      }),

                      // Comments Section - Separate Container
                      Obx(() {
                        // Filter regular comments (not questions, top-level only)
                        // Note: blog_comments table uses 'comment' field, not 'content'
                        final regularComments = controller.blogComments.where((comment) {
                          final commentText = (comment['comment'] as String? ?? comment['content'] as String? ?? '').trim();
                          // Check if it's NOT a question
                          final isQuestion = comment['is_question'] == true || 
                                            comment['is_question'] == 1 ||
                                            comment['comment_type'] == 'question' ||
                                            commentText.startsWith('?') ||
                                            commentText.startsWith('? ');
                          return !isQuestion && (comment['parent_comment_id'] == null || comment['parent_comment_id'] == 0);
                        }).toList();
                        
                        return Container(
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
                              // Comments Header
                              Row(
                                children: [
                                  Icon(
                                    Icons.comment_outlined,
                                    size: ResponsiveHelper.iconSize(context, mobile: 24),
                                    color: AppTheme.iconscolor,
                                  ),
                                  SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                                  Expanded(
                                    child: Text(
                                      'Comments',
                                      style: ResponsiveHelper.textStyle(
                                        context,
                                        fontSize: ResponsiveHelper.fontSize(context, mobile: 20, tablet: 21, desktop: 22),
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: ResponsiveHelper.padding(context, horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF5F4628).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                                    ),
                                    child: Text(
                                      '${regularComments.length}',
                                      style: ResponsiveHelper.textStyle(
                                        context,
                                        fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: ResponsiveHelper.spacing(context, 20)),
                              
                              // Comments List or Empty State
                              if (regularComments.isEmpty)
                                Padding(
                                  padding: ResponsiveHelper.padding(context, vertical: 40),
                                  child: Center(
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.comment_outlined,
                                          size: ResponsiveHelper.iconSize(context, mobile: 48),
                                          color: AppTheme.iconscolor,
                                        ),
                                        SizedBox(height: ResponsiveHelper.spacing(context, 12)),
                                        Text(
                                          'No comments yet. Be the first to comment!',
                                          style: ResponsiveHelper.textStyle(
                                            context,
                                            fontSize: ResponsiveHelper.fontSize(context, mobile: 13, tablet: 14, desktop: 15),
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else
                                ...regularComments.map((comment) => _buildCommentCard(context, comment, blogId)),
                            ],
                          ),
                        );
                      }),
                      SizedBox(height: ResponsiveHelper.spacing(context, 100)), // Space for input field
                    ],
                  ),
                ),
              ),

              // Comment/Question Input Section
              Container(
                padding: ResponsiveHelper.padding(context, all: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Question Input (if toggled)
                    Obx(() => showQuestionInput.value
                        ? Container(
                            margin: EdgeInsets.only(bottom: ResponsiveHelper.spacing(context, 12)),
                            padding: ResponsiveHelper.padding(context, all: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAF6EC),
                              borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                              border: Border.all(
                                color: const Color(0xFF5F4628).withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.help_outline,
                                  color: AppTheme.iconscolor,
                                  size: ResponsiveHelper.iconSize(context, mobile: 20),
                                ),
                                SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                                Expanded(
                                  child: TextField(
                                    controller: questionController,
                                    decoration: InputDecoration(
                                      hintText: 'Ask a question...',
                                      border: InputBorder.none,
                                      hintStyle: ResponsiveHelper.textStyle(
                                        context,
                                        fontSize: 14,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                    style: ResponsiveHelper.textStyle(context, fontSize: 14),
                                    maxLines: null,
                                  ),
                                ),
                                Obx(() => isSubmittingQuestion.value
                                    ? SizedBox(
                                        width: ResponsiveHelper.iconSize(context, mobile: 20),
                                        height: ResponsiveHelper.iconSize(context, mobile: 20),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.black,
                                        ),
                                      )
                                    : IconButton(
                                        icon: Icon(
                                          Icons.send,
                                          color: AppTheme.iconscolor,
                                          size: ResponsiveHelper.iconSize(context, mobile: 20),
                                        ),
                                        onPressed: () => _submitQuestion(blogId),
                                      )),
                              ],
                            ),
                          )
                        : const SizedBox.shrink()),
                    
                    // Comment Input
                    Container(
                      padding: ResponsiveHelper.padding(context, horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 14)),
                        border: Border.all(
                          color: const Color(0xFF5F4628).withOpacity(0.15),
                          width: 1.5,
                        ),
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
                                  // IconButton(
                                  //   icon: const Icon(
                                  //     Icons.emoji_emotions_outlined,
                                  //     color: Color(0xFF8B4513),
                                  //   ),
                                  //   onPressed: () => _showEmojiPicker(context, blogId, commentController),
                                  // ),
                                  Expanded(
                                    child: _buildCustomCommentInput(blogId),
                                  ),
                          Obx(() => isSubmittingComment.value
                              ? Padding(
                                  padding: ResponsiveHelper.padding(context, all: 8),
                                  child: SizedBox(
                                    width: ResponsiveHelper.iconSize(context, mobile: 20),
                                    height: ResponsiveHelper.iconSize(context, mobile: 20),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.black,
                                    ),
                                  ),
                                )
                              : Container(
                                  margin: ResponsiveHelper.padding(context, all: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEAE0E0),
                                    borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 10)),
                                  ),
                                  child: IconButton(
                                    icon: Icon(
                                      Icons.send,
                                      color: AppTheme.iconscolor,
                                      size: ResponsiveHelper.iconSize(context, mobile: 20),
                                    ),
                                    onPressed: () => _submitComment(blogId, parentCommentId: null),
                                  ),
                                )),
                        ],
                      ),
                    ),
        )],
                ),
              ),
            ],
          ),
        )]));
      }),
    );
  }

  /// Submit comment
  Future<void> _submitComment(int blogId, {int? parentCommentId}) async {
    // Get text from controller
    final text = parentCommentId != null
        ? (replyControllers[parentCommentId]?.text.trim() ?? '')
        : commentController.text.trim();
    
    // Combine stickers and text
    String finalContent = '';

    // Add all sticker codes first (without names)
    for (var msg in commentMessages) {
      if (msg.isSticker && msg.stickerId != null) {
        // Extract just the sticker code (e.g., :sticker_123:)
        final stickerCode = msg.stickerId!;
        finalContent += stickerCode;
        print('📝 Adding sticker to content: $stickerCode');
      } else if (msg.text != null) {
        // Add text messages
        finalContent += msg.text!;
        print('📝 Adding text to content: ${msg.text}');
      }
    }

    // Add text content - just concatenate like WhatsApp (no delimiter)
    if (text.isNotEmpty) {
      finalContent += text;
      print('📝 Adding text field content: "$text"');
    }

    print('📝 Final comment content: "$finalContent"');
    print('📝 Final content length: ${finalContent.length}');

    if (finalContent.trim().isEmpty) return;

    // FIX: Dismiss keyboard immediately
    FocusScope.of(context).unfocus();

    if (parentCommentId != null) {
      isSubmittingComment.value = true;
    } else {
      isSubmittingComment.value = true;
    }
    
    try {
      final success = await controller.addComment(blogId, finalContent, parentCommentId: parentCommentId);
      if (success) {
        if (parentCommentId == null) {
          // Clear comment messages after sending
          commentMessages.clear();
          commentController.clear();

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
        if (parentCommentId != null) {
          replyControllers[parentCommentId]?.clear();
          setState(() {
            showReplyInput[parentCommentId] = false;
            // Auto-expand parent to show the new reply
            expandedReplies.add(parentCommentId);
          });
        }
        
        // Reload comments to show the new comment/reply
        await controller.loadBlogDetails(blogId);
        
        _showCustomSnackbar(
          context,
          'Success',
          parentCommentId != null ? 'Reply added successfully' : 'Comment added successfully',
        );
      } else {
        _showCustomSnackbar(
          context,
          'Error',
          controller.message.value,
          isError: true,
        );
      }
    } finally {
      isSubmittingComment.value = false;
    }
  }

  /// Submit question (marked with ? prefix to distinguish from comments)
  Future<void> _submitQuestion(int blogId) async {
    final questionText = questionController.text.trim();
    if (questionText.isEmpty) return;

    isSubmittingQuestion.value = true;

    // FIX: Dismiss keyboard immediately
    FocusScope.of(context).unfocus();

    try {
      // Add ? prefix to mark as question (will be used for filtering)
      final questionContent = questionText.startsWith('?') ? questionText : '? $questionText';
      final success = await controller.addComment(blogId, questionContent, parentCommentId: null);
      if (success) {
        // Scroll to bottom to show latest question
        await Future.delayed(const Duration(milliseconds: 300));
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
          );
        }
        questionController.clear();
        showQuestionInput.value = false;
        // Reload comments to show the new question
        await controller.loadBlogDetails(blogId);
        _showCustomSnackbar(
          context,
          'Success',
          'Question posted successfully',
        );
      } else {
        _showCustomSnackbar(
          context,
          'Error',
          controller.message.value,
          isError: true,
        );
      }
    } finally {
      isSubmittingQuestion.value = false;
    }
  }

  /// Build comment card
  Widget _buildCommentCard(BuildContext context, Map<String, dynamic> comment, int blogId) {
    final isLiked = comment['is_liked'] == true || comment['is_liked'] == 1;
    final likeCount = int.tryParse((comment['like_count'] ?? 0).toString()) ?? 0;
    final commentId = comment['id'] as int;
    
    // Initialize reply controller if not exists
    if (!replyControllers.containsKey(commentId)) {
      replyControllers[commentId] = TextEditingController();
    }

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
                            fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        if (comment['created_at'] != null) ...[
                          SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                          Text(
                            '•',
                            style: ResponsiveHelper.textStyle(
                              context,
                              fontSize: ResponsiveHelper.fontSize(context, mobile: 11, tablet: 12, desktop: 13),
                              color: Colors.grey[400],
                            ),
                          ),
                          SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                          Text(
                            TimeHelper.getTimeAgo(comment['created_at'] as String?),
                            style: ResponsiveHelper.textStyle(
                              context,
                              fontSize: ResponsiveHelper.fontSize(context, mobile: 11, tablet: 12, desktop: 13),
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(context, 6)),
                    // Comment Content - blog_comments uses 'comment' field, not 'content'
                    FruitEmojiHelper.buildCommentText(
                      context,
                      AutoTranslateHelper.getTranslatedTextSync(
                        text: (comment['comment'] as String? ?? comment['content'] as String? ?? '').trim(),
                        sourceLanguage: comment['language'] as String?,
                      ),
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: ResponsiveHelper.fontSize(context, mobile: 13, tablet: 14, desktop: 15),
                        color: Colors.black87,
                        height: 1.5,
                      ),
                      userEmail: userEmail,
                    ),
                    // edit feature: Show "edited" label if comment was edited
                    if (comment['is_edited'] == true || comment['is_edited'] == 1) ...[ // edit feature
                      SizedBox(height: ResponsiveHelper.spacing(context, 6)), // edit feature
                      Text( // edit feature
                        'edited', // edit feature
                        style: TextStyle( // edit feature
                          fontSize: ResponsiveHelper.fontSize(context, mobile: 10, tablet: 11), // edit feature
                          color: Colors.grey[500], // edit feature
                          fontStyle: FontStyle.italic, // edit feature
                        ), // edit feature
                      ), // edit feature
                    ], // edit feature
                    SizedBox(height: ResponsiveHelper.spacing(context, 12)),
                    // Action Buttons: Like, Reply, Report
                    Row(
                      children: [
                        // Like Button
                        InkWell(
                          onTap: () => _toggleCommentLike(commentId, blogId),
                          child: Row(
                            children: [
                              Icon(
                                isLiked ? Icons.favorite : Icons.favorite_border,
                                size: ResponsiveHelper.iconSize(context, mobile: 18),
                                color: AppTheme.iconscolor,
                              ),
                              if (likeCount > 0) ...[
                                SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                                Text(
                                  '$likeCount',
                                  style: ResponsiveHelper.textStyle(
                                    context,
                                    fontSize: ResponsiveHelper.fontSize(context, mobile: 12, tablet: 13, desktop: 14),
                                    color: AppTheme.iconscolor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
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
                                color: AppTheme.iconscolor,
                              ),
                              SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                              Text(
                                'Reply',
                                style: ResponsiveHelper.textStyle(
                                  context,
                                  fontSize: ResponsiveHelper.fontSize(context, mobile: 12, tablet: 13, desktop: 14),
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: ResponsiveHelper.spacing(context, 16)),
                        // edit feature: Edit Button - Show for all comments within 15 minutes
                        _buildEditButton(context, comment, blogId), // edit feature
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
                                  color: AppTheme.iconscolor,
                                ),
                                SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                                Text(
                                  'Report',
                                  style: ResponsiveHelper.textStyle(
                                    context,
                                    fontSize: ResponsiveHelper.fontSize(context, mobile: 12, tablet: 13, desktop: 14),
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
          // edit feature: Edit Input (if shown)
          if (showEditInput[commentId] == true) ...[ // edit feature
            SizedBox(height: ResponsiveHelper.spacing(context, 12)), // edit feature
            _buildEditInput(context, commentId, blogId, 'blog'), // edit feature
          ], // edit feature
          // Reply Input (if shown)
          if (showReplyInput[commentId] == true) ...[
            SizedBox(height: ResponsiveHelper.spacing(context, 12)),
            _buildReplyInput(context, commentId, blogId),
          ],
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
                      fontSize: ResponsiveHelper.fontSize(context, mobile: 11, tablet: 12, desktop: 13),
                      color: Colors.black,
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
            ...((comment['replies'] as List).map((reply) => _buildReplyCard(context, reply, blogId, depth: 0))),
          ],
        ],
      ),
    );
  }

  /// Build question card (visually distinct from comments)
  Widget _buildQuestionCard(BuildContext context, Map<String, dynamic> question, int blogId) {
    final isLiked = question['is_liked'] == true || question['is_liked'] == 1;
    final likeCount = int.tryParse((question['like_count'] ?? 0).toString()) ?? 0;
    final questionId = question['id'] as int;
    // blog_comments uses 'comment' field, not 'content'
    final content = (question['comment'] as String? ?? question['content'] as String? ?? '').trim();
    // Remove ? prefix if present for display (handle both '?' and '? ' cases)
    final displayContent = content.startsWith('?') 
        ? (content.startsWith('? ') ? content.substring(2).trim() : content.substring(1).trim())
        : content;
    
    // Initialize reply controller if not exists
    if (!replyControllers.containsKey(questionId)) {
      replyControllers[questionId] = TextEditingController();
    }

    return Container(
      margin: EdgeInsets.only(bottom: ResponsiveHelper.spacing(context, 16)),
      padding: ResponsiveHelper.padding(context, all: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD), // Light blue background for questions
        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
        border: Border.all(
          color: const Color(0xFF2196F3).withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2196F3).withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question Header with Pin Icon
          Row(
            children: [
              Container(
                padding: ResponsiveHelper.padding(context, all: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3),
                  borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
                ),
                child: Icon(
                  Icons.help_outline_rounded,
                  color: Colors.white,
                  size: ResponsiveHelper.iconSize(context, mobile: 18),
                ),
              ),
              SizedBox(width: ResponsiveHelper.spacing(context, 10)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            question['user_name'] as String? ?? 'Anonymous',
                            style: ResponsiveHelper.textStyle(
                              context,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1976D2),
                            ),
                          ),
                        ),
                        Container(
                          padding: ResponsiveHelper.padding(context, horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2196F3).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 6)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.push_pin,
                                size: ResponsiveHelper.iconSize(context, mobile: 12),
                                color: const Color(0xFF2196F3),
                              ),
                              SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                              Text(
                                'Question',
                                style: ResponsiveHelper.textStyle(
                                  context,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1976D2),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (question['created_at'] != null) ...[
                      SizedBox(height: ResponsiveHelper.spacing(context, 4)),
                      Text(
                        TimeHelper.getTimeAgo(question['created_at'] as String?),
                        style: ResponsiveHelper.textStyle(
                          context,
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: ResponsiveHelper.spacing(context, 12)),
          // Question Content
          FruitEmojiHelper.buildCommentText(
            context,
            AutoTranslateHelper.getTranslatedTextSync(
              text: displayContent,
              sourceLanguage: question['language'] as String?,
            ),
            style: ResponsiveHelper.textStyle(
              context,
              fontSize: 15,
              color: const Color(0xFF1565C0),
              height: 1.5,
            ),
            userEmail: userEmail,
          ),
          SizedBox(height: ResponsiveHelper.spacing(context, 12)),
          // Question Actions (Like, Answer)
          Row(
            children: [
              // Like Button
              InkWell(
                onTap: () => _toggleCommentLike(questionId, blogId),
                child: Row(
                  children: [
                    Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      size: ResponsiveHelper.iconSize(context, mobile: 20),
                      color: AppTheme.iconscolor,
                    ),
                    SizedBox(width: ResponsiveHelper.spacing(context, 6)),
                    Text(
                      '$likeCount',
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: 14,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: ResponsiveHelper.spacing(context, 20)),
              // Answer Button (instead of Reply)
              InkWell(
                onTap: () {
                  setState(() {
                    // Close all other reply inputs first
                    showReplyInput.clear();
                    
                    // Toggle current reply input
                    showReplyInput[questionId] = true;
                  });
                },
                child: Row(
                  children: [
                    Icon(
                      Icons.reply_rounded,
                      size: ResponsiveHelper.iconSize(context, mobile: 20),
                      color: const Color(0xFF2196F3),
                    ),
                    SizedBox(width: ResponsiveHelper.spacing(context, 6)),
                    Text(
                      'Answer',
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2196F3),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Answer Input (for question threads)
          if (showReplyInput[questionId] == true) ...[
            SizedBox(height: ResponsiveHelper.spacing(context, 12)),
            _buildReplyInput(context, questionId, blogId, isQuestion: true),
          ],
          // Question Thread Replies (separate from comment threads)
          if (question['replies'] != null && (question['replies'] as List).isNotEmpty) ...[
            SizedBox(height: ResponsiveHelper.spacing(context, 12)),
            InkWell(
              onTap: () {
                setState(() {
                  if (expandedReplies.contains(questionId)) {
                    expandedReplies.remove(questionId);
                  } else {
                    expandedReplies.add(questionId);
                  }
                });
              },
              child: Row(
                children: [
                  Icon(
                    expandedReplies.contains(questionId) ? Icons.expand_less : Icons.expand_more,
                    size: ResponsiveHelper.iconSize(context, mobile: 16),
                    color: const Color(0xFF2196F3),
                  ),
                  SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                  Text(
                    expandedReplies.contains(questionId) 
                        ? 'Hide ${(question['replies'] as List).length} ${(question['replies'] as List).length == 1 ? 'answer' : 'answers'}'
                        : 'Show ${(question['replies'] as List).length} ${(question['replies'] as List).length == 1 ? 'answer' : 'answers'}',
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: 13,
                      color: const Color(0xFF2196F3),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Question Thread Answers (only show if expanded)
          if (question['replies'] != null && (question['replies'] as List).isNotEmpty && expandedReplies.contains(questionId)) ...[
            SizedBox(height: ResponsiveHelper.spacing(context, 12)),
            Container(
              margin: EdgeInsets.only(left: ResponsiveHelper.spacing(context, 20)),
              padding: ResponsiveHelper.padding(context, all: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                border: Border.all(
                  color: const Color(0xFF2196F3).withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  ...((question['replies'] as List).map((answer) => _buildReplyCard(context, answer, blogId, depth: 0, isQuestionThread: true))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Toggle comment like
  Future<void> _toggleCommentLike(int commentId, int blogId) async {
    if (currentUserId == null || currentUserId == 0) {
      _showCustomSnackbar(
        context,
        'Error',
        'Please login first',
        isError: true,
      );
      return;
    }

    try {
      await CommentsService.toggleCommentLike(
        userId: currentUserId!,
        commentId: commentId,
      );
      // Reload blog details to get updated comments
      await controller.loadBlogDetails(blogId);
    } catch (e) {
      _showCustomSnackbar(
        context,
        'Error',
        'Failed to like comment',
        isError: true,
      );
    }
  }

  /// Build reply input widget
  Widget _buildReplyInput(BuildContext context, int parentCommentId, int blogId, {bool isQuestion = false}) {
    if (!replyControllers.containsKey(parentCommentId)) {
      replyControllers[parentCommentId] = TextEditingController();
    }
    if (!replyFocusNodes.containsKey(parentCommentId)) {
      replyFocusNodes[parentCommentId] = FocusNode();
    }
    final replyController = replyControllers[parentCommentId]!;
    final replyFocusNode = replyFocusNodes[parentCommentId]!;
    
    return Container(
      padding: ResponsiveHelper.padding(context, all: 12),
      decoration: BoxDecoration(
        color: isQuestion ? const Color(0xFFE3F2FD) : Colors.grey[50],
        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
        border: Border.all(
          color: isQuestion ? const Color(0xFF2196F3).withOpacity(0.3) : Colors.grey.withOpacity(0.2),
          width: isQuestion ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          if (isQuestion) ...[
            Icon(
              Icons.reply_rounded,
              size: ResponsiveHelper.iconSize(context, mobile: 18),
              color: const Color(0xFF2196F3),
            ),
            SizedBox(width: ResponsiveHelper.spacing(context, 8)),
          ],
          Expanded(
            child: TextField(
              controller: replyController,
              focusNode: replyFocusNode,
              decoration: InputDecoration(
                hintText: isQuestion ? 'Write an answer...' : 'Write a reply...',
                hintStyle: ResponsiveHelper.textStyle(
                  context,
                  fontSize: 13,
                  color: isQuestion ? Colors.blue[400] : Colors.grey[400],
                ),
                border: InputBorder.none,
                contentPadding: ResponsiveHelper.padding(
                  context,
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              maxLines: null,
              textInputAction: TextInputAction.newline,
              style: ResponsiveHelper.textStyle(
                context, 
                fontSize: 13,
                color: isQuestion ? const Color(0xFF1565C0) : null,
              ),
            ),
          ),
          SizedBox(width: ResponsiveHelper.spacing(context, 8)),
          Obx(() => isSubmittingComment.value
              ? Padding(
                  padding: ResponsiveHelper.padding(context, all: 8),
                  child: SizedBox(
                    width: ResponsiveHelper.iconSize(context, mobile: 18),
                    height: ResponsiveHelper.iconSize(context, mobile: 18),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: isQuestion ? const Color(0xFF2196F3) : const Color(0xFF9F9467),
                    ),
                  ),
                )
              : Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      FocusScope.of(context).unfocus();
                      _submitComment(blogId, parentCommentId: parentCommentId);
                    },
                    borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 20)),
                    child: Container(
                      padding: ResponsiveHelper.padding(context, all: 8),
                      decoration: BoxDecoration(
                        color: isQuestion ? const Color(0xFF2196F3) : const Color(0xFF9F9467),
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 20)),
                      ),
                      child: Icon(
                        Icons.send,
                        color: Colors.white,
                        size: ResponsiveHelper.iconSize(context, mobile: 18),
                      ),
                    ),
                  ),
                )),
        ],
      ),
    );
  }

  /// Build reply card widget
  Widget _buildReplyCard(BuildContext context, Map<String, dynamic> reply, int blogId, {int depth = 0, bool isQuestionThread = false}) {
    // blog_comments uses 'comment' field, not 'content'
    final content = (reply['comment'] as String? ?? reply['content'] as String? ?? '').trim();
    final timeAgo = TimeHelper.getTimeAgo(reply['created_at'] as String?);
    final replyId = reply['id'] as int;
    final isLiked = reply['is_liked'] == true || reply['is_liked'] == 1;
    final likeCount = int.tryParse((reply['like_count'] ?? 0).toString()) ?? 0;
    
    // Initialize reply controller if not exists
    if (!replyControllers.containsKey(replyId)) {
      replyControllers[replyId] = TextEditingController();
    }
    
    // Calculate left margin based on depth (each level adds 40px)
    final leftMargin = isQuestionThread ? 20.0 : (40.0 + (depth * 40.0));
    final threadColor = isQuestionThread ? const Color(0xFF2196F3) : const Color(0xFF9F9467);
    final bgColor = isQuestionThread ? const Color(0xFFE3F2FD) : Colors.grey[50];
    
    return Container(
      margin: EdgeInsets.only(left: leftMargin, top: ResponsiveHelper.spacing(context, 8), bottom: ResponsiveHelper.spacing(context, 8)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Visual thread connector line
          Container(
            width: 2,
            height: 20,
            margin: EdgeInsets.only(
              top: ResponsiveHelper.spacing(context, 20),
              right: ResponsiveHelper.spacing(context, 12),
            ),
            decoration: BoxDecoration(
              color: threadColor.withOpacity(0.3),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          Expanded(
            child: Container(
              padding: ResponsiveHelper.padding(context, all: 12),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                border: Border.all(
                  color: threadColor.withOpacity(isQuestionThread ? 0.3 : 0.2),
                  width: isQuestionThread ? 1.5 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: ResponsiveHelper.iconSize(context, mobile: 16, tablet: 18, desktop: 20) / 2,
                        backgroundColor: const Color(0xFFFFD1DC),
                        backgroundImage: _getImageProvider(reply['profile_photo'] as String?),
                        child: reply['profile_photo'] == null
                            ? Icon(
                                Icons.person,
                                size: ResponsiveHelper.iconSize(context, mobile: 16),
                                color: Colors.black,
                              )
                            : null,
                      ),
                      SizedBox(width: ResponsiveHelper.spacing(context, 10)),
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
                                    color: isQuestionThread ? const Color(0xFF1976D2) : const Color(0xFF5F4628),
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
                                color: isQuestionThread ? const Color(0xFF1565C0) : Colors.black87,
                                height: 1.4,
                              ),
                            ),
                            SizedBox(height: ResponsiveHelper.spacing(context, 8)),
                            Row(
                              children: [
                                // Like Button for Reply
                                InkWell(
                                  onTap: () => _toggleCommentLike(replyId, blogId),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isLiked ? Icons.favorite : Icons.favorite_border,
                                        size: ResponsiveHelper.iconSize(context, mobile: 14),
                                        color: AppTheme.iconscolor,
                                      ),
                                      if (likeCount > 0) ...[
                                        SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                                        Text(
                                          '$likeCount',
                                          style: ResponsiveHelper.textStyle(
                                            context,
                                            fontSize: 11,
                                            color: AppTheme.iconscolor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                                // Reply/Answer Button for nested replies
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
                                        color: isQuestionThread ? const Color(0xFF2196F3) : Colors.grey[600],
                                      ),
                                      SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                                      Text(
                                        isQuestionThread ? 'Answer' : 'Reply',
                                        style: ResponsiveHelper.textStyle(
                                          context,
                                          fontSize: 11,
                                          color: isQuestionThread ? const Color(0xFF2196F3) : Colors.grey[600],
                                          fontWeight: isQuestionThread ? FontWeight.w600 : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                                // Report Button for Reply - Only show for other users' replies
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
                                            fontSize: 11,
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
                  if (showReplyInput[replyId] == true) ...[
                    SizedBox(height: ResponsiveHelper.spacing(context, 12)),
                    _buildReplyInput(context, replyId, blogId, isQuestion: isQuestionThread),
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
                            size: ResponsiveHelper.iconSize(context, mobile: 16),
                            color: isQuestionThread ? const Color(0xFF2196F3) : const Color(0xFF9F9467),
                          ),
                          SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                          Text(
                            expandedReplies.contains(replyId) 
                                ? 'Hide ${(reply['replies'] as List).length} ${(reply['replies'] as List).length == 1 ? (isQuestionThread ? 'answer' : 'reply') : (isQuestionThread ? 'answers' : 'replies')}'
                                : 'Show ${(reply['replies'] as List).length} ${(reply['replies'] as List).length == 1 ? (isQuestionThread ? 'answer' : 'reply') : (isQuestionThread ? 'answers' : 'replies')}',
                            style: ResponsiveHelper.textStyle(
                              context,
                              fontSize: 11,
                              color: isQuestionThread ? const Color(0xFF2196F3) : Colors.black,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // Nested Replies (recursive) - only show if expanded
                  if (reply['replies'] != null && (reply['replies'] as List).isNotEmpty && expandedReplies.contains(replyId)) ...[
                    SizedBox(height: ResponsiveHelper.spacing(context, 12)),
                    ...((reply['replies'] as List).map((nestedReply) => _buildReplyCard(context, nestedReply, blogId, depth: depth + 1, isQuestionThread: isQuestionThread))),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Show report dialog
  void _showReportDialog(BuildContext context, Map<String, dynamic> comment) {
    final reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 20)),
          ),
          title: Text(
            'Report Comment',
            style: ResponsiveHelper.textStyle(
              context,
              fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 17, desktop: 18),
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Why are you reporting this comment?',
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: ResponsiveHelper.fontSize(context, mobile: 13, tablet: 14, desktop: 15),
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: ResponsiveHelper.spacing(context, 12)),
              TextButton.icon(
                onPressed: () async {
                  final userIdRaw = comment['user_id'] ?? comment['created_by'];
                  if (userIdRaw != null) {
                    final userId = userIdRaw is int ? userIdRaw : int.tryParse(userIdRaw.toString());
                    if (userId == null) return;
                    
                    if (currentUserId == userId) {
                      _showCustomSnackbar(context, 'Info', 'You cannot block yourself');
                      return;
                    }

                    final userName = comment['user_name'] ?? 'this user';
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: Text('Block $userName?'),
                        content: const Text('You will no longer see content from this user.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Block', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );

                    if (confirmed == true) {
                      try {
                        if (currentUserId != null) {
                          await UserBlockingService.blockUser(userId);
                          Navigator.of(context).pop();
                          _showCustomSnackbar(context, 'Success', 'User blocked');
                          final currentBlogId = controller.selectedBlog['id'] is int ? controller.selectedBlog['id'] : int.parse(controller.selectedBlog['id'].toString());
                          controller.loadBlogDetails(currentBlogId);
                        }
                      } catch (e) {
                        _showCustomSnackbar(context, 'Error', 'Failed to block user', isError: true);
                      }
                    }
                  }
                },
                icon: const Icon(Icons.block, color: Colors.red, size: 20),
                label: const Text('Block User', style: TextStyle(color: Colors.red)),
              ),
              SizedBox(height: ResponsiveHelper.spacing(context, 12)),
              TextField(
                controller: reasonController,
                decoration: InputDecoration(
                  hintText: 'Enter reason (optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
                  ),
                  contentPadding: ResponsiveHelper.padding(context, all: 12),
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
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: ResponsiveHelper.fontSize(context, mobile: 13, tablet: 14, desktop: 15),
                  color: Colors.grey[600],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (currentUserId == null || currentUserId == 0) {
                  _showCustomSnackbar(
                    context,
                    'Error',
                    'Please login first',
                    isError: true,
                  );
                  Navigator.of(context).pop();
                  return;
                }

                try {
                  await CommentsService.reportComment(
                    userId: currentUserId!,
                    commentId: comment['id'] as int,
                    reason: reasonController.text.trim().isEmpty ? null : reasonController.text.trim(),
                  );
                  
                  Navigator.of(context).pop();
                  _showCustomSnackbar(
                    context,
                    'Success',
                    'Comment reported successfully',
                  );
                } catch (e) {
                  Navigator.of(context).pop();
                  _showCustomSnackbar(
                    context,
                    'Error',
                    'Failed to report comment',
                    isError: true,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5F4628),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
                ),
              ),
              child: Text(
                'Report',
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: ResponsiveHelper.fontSize(context, mobile: 13, tablet: 14, desktop: 15),
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Build Emoji Reactions Widget (similar to prayer_details_screen)
  Widget _buildEmojiReactions(BuildContext context, int blogId, BlogsController controller) {
    return Obx(() {
      final reactions = controller.blogEmojiReactions;
      final hasReactions = reactions.isNotEmpty;
      final quickEmojisList = controller.quickEmojis;
      
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
                    color: const Color(0xFFFFFFFF),
                    borderRadius: BorderRadius.circular(ResponsiveHelper.isMobile(context) ? 10 : 12),
                  ),
                  child: Icon(
                    Icons.volunteer_activism_rounded,
                    color: AppTheme.iconscolor,
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
                        color: AppTheme.iconscolor,
                      ),
                    ),
                  )
                else
                  ...quickEmojisList.map((emojiData) {
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
                          // Get the root context that will persist
                          final rootContext = context.findRootAncestorStateOfType<NavigatorState>()?.context;
                          if (rootContext == null) return;
                          
                          try {
                            FocusScope.of(rootContext).unfocus();
                            final success = await controller.addEmojiReaction(blogId, emoji!);
                            
                            if (success) {
                              // Show success message (brief)
                              if (rootContext.mounted) {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (rootContext.mounted) {
                                    _showCustomSnackbar(
                                      rootContext,
                                      'Success',
                                      'Reaction added',
                                    );
                                  }
                                });
                              }
                            } else {
                              if (rootContext.mounted) {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (rootContext.mounted) {
                                    _showCustomSnackbar(
                                      rootContext,
                                      'Error',
                                      controller.message.value.isNotEmpty 
                                          ? controller.message.value 
                                          : 'Failed to add reaction. Please try again.',
                                      isError: true,
                                    );
                                  }
                                });
                              }
                            }
                          } catch (e) {
                            if (rootContext.mounted) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (rootContext.mounted) {
                                  _showCustomSnackbar(
                                    rootContext,
                                    'Error',
                                    'Failed to add reaction. Please try again.',
                                    isError: true,
                                  );
                                }
                              });
                            }
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
                              onTap: null, // Handled by the parent InkWell
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
                    onTap: () => _showEmojiPicker(context, blogId, commentController),
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
            
            // Display Reactions Count
            if (hasReactions) ...[
              SizedBox(height: ResponsiveHelper.spacing(context, 20)),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var i = 0; i < reactions.entries.length; i++) ...[
                      Builder(
                        builder: (context) {
                          final entry = reactions.entries.elementAt(i);
                          final emojiKey = entry.key;
                          final users = entry.value as List<Map<String, dynamic>>;
                          final count = users.length;
                          
                          // Find matching emoji from availableEmojis
                          Map<String, dynamic>? matchingEmoji;
                          
                          // Debug: Log what we're trying to match
                          print('🔍 Trying to match emojiKey: "$emojiKey" (type: ${emojiKey.runtimeType})');
                          
                          for (var emoji in controller.availableEmojis) {
                            final emojiId = emoji['id']?.toString() ?? '';
                            final emojiChar = emoji['emoji_char'] as String? ?? '';
                            final code = emoji['code'] as String? ?? '';
                            final imageUrl = emoji['image_url'] as String? ?? '';
                            
                            // Strategy 1: Match by numeric ID (most common for blog reactions)
                            if (emojiId.isNotEmpty && emojiId == emojiKey) {
                              matchingEmoji = emoji;
                              print('✅ Matched emoji by ID: $emojiId -> ${emoji['name']}');
                              break;
                            }
                            // Strategy 2: Match by emoji_char
                            if (emojiChar.isNotEmpty && emojiChar.trim() == emojiKey.trim()) {
                              matchingEmoji = emoji;
                              print('✅ Matched emoji by char: $emojiChar -> ${emoji['name']}');
                              break;
                            }
                            // Strategy 3: Match by code
                            if (code.isNotEmpty && code.trim() == emojiKey.trim()) {
                              matchingEmoji = emoji;
                              print('✅ Matched emoji by code: $code -> ${emoji['name']}');
                              break;
                            }
                            // Strategy 4: Match by image URL (check if emojiKey contains filename from imageUrl)
                            if (imageUrl.isNotEmpty) {
                              final urlParts = imageUrl.split('/');
                              final filename = urlParts.isNotEmpty ? urlParts.last : '';
                              if (filename.isNotEmpty && (emojiKey.contains(filename) || filename.contains(emojiKey))) {
                                matchingEmoji = emoji;
                                print('✅ Matched emoji by image URL: $filename -> ${emoji['name']}');
                                break;
                              }
                            }
                          }
                          
                          if (matchingEmoji == null) {
                            print('⚠️ No matching emoji found for key: "$emojiKey"');
                          }
                          
                          return GestureDetector(
                            onTap: () {
                              // Show users who reacted
                              showDialog(
                                context: context,
                                builder: (dialogContext) =>
                                Dialog(
                                  child: Container(
                                    padding: ResponsiveHelper.padding(context, all: 20),
                                    constraints: BoxConstraints(
                                      maxHeight: MediaQuery.of(context).size.height * 0.7,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            if (matchingEmoji != null)
                                              SizedBox(
                                                width: 32,
                                                height: 32,
                                                child: HomeScreen.buildEmojiDisplay(context, matchingEmoji!, size: 32),
                                              ),
                                            SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                                            Text(
                                              '$count ${count == 1 ? 'person' : 'people'} reacted',
                                              style: ResponsiveHelper.textStyle(
                                                context,
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
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
                                              return ListTile(
                                                leading: CircleAvatar(
                                                  backgroundImage: _getImageProvider(user['profile_photo'] as String?),
                                                  child: user['profile_photo'] == null 
                                                      ? Icon(Icons.person, color: AppTheme.iconscolor) 
                                                      : null,
                                                ),
                                                title: Text(user['user_name'] ?? 'Anonymous'),
                                              );
                                            },
                                          ),
                                        ),
                                        SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                                        TextButton(
                                          onPressed: () => Navigator.of(dialogContext).pop(),
                                          child: const Text('Close'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              padding: ResponsiveHelper.padding(context, horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 20)),
                                border: Border.all(color: Colors.grey.withOpacity(0.2)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (matchingEmoji != null)
                                    SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: HomeScreen.buildEmojiDisplay(context, matchingEmoji!, size: 24),
                                    )
                                  else
                                    Icon(Icons.favorite, size: 16, color: AppTheme.iconscolor),
                                  SizedBox(width: ResponsiveHelper.spacing(context, 6)),
                                  Text(
                                    '$count',
                                    style: ResponsiveHelper.textStyle(
                                      context,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      if (i < reactions.entries.length - 1)
                        SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    });
  }

  /// Build custom comment input field that displays both text and stickers in real-time
  Widget _buildCustomCommentInput(int blogId) {
    return Container(
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
            onPressed: () => _showEmojiPicker(context, blogId, commentController),
          ),
          Expanded(
            child: _buildRichTextInput(),
          ),
        ],
      ),
    );
  }

  /// Build rich text input that can display both text and sticker messages
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

  /// Build message widget that properly renders text vs stickers
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

  /// Show emoji picker for blog comments - sends emoji directly without showing in input field
  void _showEmojiPicker(BuildContext context, int blogId, TextEditingController controller) {
    showEmojiStickerPicker(
      context: context,
      onEmojiSelected: (emoji) async {
        print('Blog emoji selected: "$emoji"');

        // Send emoji directly as comment - no preview in text field!
        await _sendEmojiDirectly(blogId, emoji);
      },
      height: 350,
    );
  }

  /// Send emoji/sticker directly as comment without showing in input field
  Future<void> _sendEmojiDirectly(int blogId, String emoji) async {
    if (emoji.isEmpty) return;

    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    isSubmittingComment.value = true;

    try {
      final success = await controller.addComment(blogId, emoji);
      if (success) {
        // Scroll to bottom to show new comment
        await Future.delayed(const Duration(milliseconds: 300));
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
          );
        }

        // Reload comments
        await controller.loadBlogDetails(blogId);

        _showCustomSnackbar(context, 'Success', 'Comment added successfully');
      } else {
        _showCustomSnackbar(context, 'Error', controller.message.value, isError: true);
      }
    } finally {
      isSubmittingComment.value = false;
    }
  }

  Widget _buildBlogOptions(BuildContext context, Map<String, dynamic> blog) {
    final userIdRaw = blog['user_id'] ?? blog['created_by'];
    final posterId = userIdRaw is int ? userIdRaw : int.tryParse(userIdRaw?.toString() ?? '');
    
    // Check if we have any options to show
    final hasOptions = posterId != null && posterId != currentUserId;
    
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
            contentType: 'blog',
            contentId: blog['id'] is int ? blog['id'] : int.parse(blog['id'].toString()),
          );
        } else if (value == 'block') {
          final userIdRaw = blog['user_id'] ?? blog['created_by'];
          if (userIdRaw != null) {
            final userId = userIdRaw is int ? userIdRaw : int.tryParse(userIdRaw.toString());
            if (userId == null) return;

            if (currentUserId == userId) {
              _showCustomSnackbar(context, 'Info', 'You cannot block yourself');
              return;
            }

            final userName = blog['user_name'] ?? 'this blogger';
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: Text('Block $userName?'),
                content: const Text('You will no longer see content from this user.'),
                actions: [
                  TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
                  TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      child: const Text('Block', style: TextStyle(color: Colors.red))),
                ],
              ),
            );

            if (confirmed == true) {
              try {
                if (currentUserId != null) {
                  await UserBlockingService.blockUser(userId);
                  _showCustomSnackbar(context, 'Success', 'User blocked');
                  Navigator.of(context).pop(); // Back to list
                }
              } catch (e) {
                _showCustomSnackbar(context, 'Error', 'Failed to block user', isError: true);
              }
            }
          }
        }
      },
      itemBuilder: (context) {
        final List<PopupMenuEntry<String>> items = [];
        
        // Only show options if it's NOT the current user's blog
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
}
