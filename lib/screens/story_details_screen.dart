import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/utils/share_helper.dart';
import 'package:fruitsofspirit/utils/time_helper.dart';

import 'package:fruitsofspirit/controllers/home_controller.dart';
import 'package:fruitsofspirit/services/stories_service.dart';
import 'package:fruitsofspirit/services/comments_service.dart';
import 'package:fruitsofspirit/services/user_storage.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';
import 'package:fruitsofspirit/services/api_service.dart';
import 'package:fruitsofspirit/widgets/cached_image.dart';
import 'package:fruitsofspirit/services/terms_service.dart';
import 'package:fruitsofspirit/screens/terms_acceptance_screen.dart';
import 'package:fruitsofspirit/services/emojis_service.dart';
import 'package:fruitsofspirit/screens/home_screen.dart';
import 'package:fruitsofspirit/services/user_blocking_service.dart';
import 'package:fruitsofspirit/utils/fruit_emoji_helper.dart';
import 'package:fruitsofspirit/utils/report_utils.dart';
import 'package:fruitsofspirit/utils/sticker_emoji_helper.dart';

import '../utils/app_theme.dart';
import 'package:fruitsofspirit/screens/report_content_screen.dart';
import 'package:fruitsofspirit/widgets/emoji_sticker_picker.dart';
import 'package:fruitsofspirit/widgets/emoji_button.dart';

/// Story Details Screen - Modern Social Media Style
class StoryDetailsScreen extends StatefulWidget {
  const StoryDetailsScreen({Key? key}) : super(key: key);

  @override
  State<StoryDetailsScreen> createState() => _StoryDetailsScreenState();
}

// Message model for proper text/sticker separation (reusable from blog_details_screen)
class CommentMessage {
  final String? text;
  final String? stickerId;
  final bool isSticker;

  CommentMessage({this.text, this.stickerId, required this.isSticker});
}

class _StoryDetailsScreenState extends State<StoryDetailsScreen> {
  var isLoading = false;
  var story = <String, dynamic>{};
  var comments = <Map<String, dynamic>>[];
  var storyEmojiReactions = <String, List<Map<String, dynamic>>>{}; // emoji -> list of users who reacted
  var availableEmojis = <Map<String, dynamic>>[];
  var quickEmojis = <Map<String, dynamic>>[];
  var userId = 0;
  String? userEmail;
  final controller = Get.find<HomeController>(); // Use HomeController for consistency
  final commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  // Rich text input messages (text + stickers) like blog_details_screen
  final List<CommentMessage> commentMessages = [];
  final replyControllers = <int, TextEditingController>{};
  final showReplyInput = <int, bool>{};
  final expandedReplies = <int>{}; // Track which replies are expanded
  var isSubmittingComment = false.obs; // Track comment submission state
  // edit feature: Comment edit state
  final editControllers = <int, TextEditingController>{}; // edit feature
  final showEditInput = <int, bool>{}; // edit feature
  var isEditingComment = false.obs; // edit feature
  // edit feature: Post edit state
  final postEditTitleController = TextEditingController(); // edit feature
  final postEditContentController = TextEditingController(); // edit feature
  final postEditCategoryController = TextEditingController(); // edit feature
  var showPostEditInput = false.obs; // edit feature
  var isEditingPost = false.obs; // edit feature
  /// Show a custom snackbar using ScaffoldMessenger
  void _showCustomSnackbar(BuildContext context, String title, String message, {bool isError = false}) {
    if (!mounted) return;
    
    // Close any existing snackbars
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    
    final lower = message.toLowerCase();
    final isModeration = lower.contains('community guidelines') ||
        lower.contains('inappropriate content') ||
        lower.contains('terms') ||
        lower.contains('moderation');
    
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

  @override
  void initState() {
    super.initState();
    _loadUserId();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final storyId = ModalRoute.of(context)?.settings.arguments as int? ?? 0;
        if (storyId > 0) {
          _loadStoryDetails(storyId);
        }
      }
    });
  }

  @override
  void dispose() {
    commentController.dispose();
    _scrollController.dispose();
    // edit feature: Dispose comment edit controllers
    for (var controller in editControllers.values) { // edit feature
      controller.dispose(); // edit feature
    } // edit feature
    // edit feature: Dispose post edit controllers
    postEditTitleController.dispose(); // edit feature
    postEditContentController.dispose(); // edit feature
    postEditCategoryController.dispose(); // edit feature
    for (var controller in replyControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadUserId() async {
    final id = await UserStorage.getUserId();
    if (id != null) {
      setState(() {
        userId = id;
      });
    }
  }

  Future<void> _loadUserEmail() async {
    userEmail = await UserStorage.getUserEmail();
  }

  // edit feature: Configurable edit time window in minutes
  static const int _editTimeWindowMinutes = 15; // edit feature

  // edit feature: Check if story can be edited (always allow editing)
  bool _canEditPost(Map<String, dynamic> story) { // edit feature
    print('🔍 Edit check - always allowing editing'); // debug
    return true; // edit feature: Always allow editing
  } // edit feature

  // edit feature: Check if comment can be edited (within 15 minutes only)
  bool _canEditComment(Map<String, dynamic> comment) { // edit feature
    print('🔍 Edit check - created_at: ${comment['created_at']}'); // debug
    
    // Check if user is logged in
    if (userId == null || userId == 0) { // edit feature
      print('❌ Edit blocked: user not logged in'); // debug
      return false; // edit feature
    } // edit feature
    
    // Check if comment belongs to current user
    final commentUserId = comment['user_id']; // edit feature
    if (commentUserId == null || commentUserId.toString() != userId.toString()) { // edit feature
      print('❌ Edit blocked: comment belongs to user $commentUserId, current user is $userId'); // debug
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
  Widget _buildEditButton(BuildContext context, Map<String, dynamic> comment, int storyId) { // edit feature
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
  Widget _buildEditInput(BuildContext context, int commentId, int storyId, String postType) { // edit feature
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
                onPressed: () => _editComment(commentId, storyId, postType), // edit feature
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
  Future<void> _editComment(int commentId, int storyId, String postType) async { // edit feature
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

    if (userId == 0) { // edit feature
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
        userId: userId, // edit feature
        commentId: commentId, // edit feature
        postType: postType, // edit feature
        postId: storyId, // edit feature
        content: content, // edit feature
      ); // edit feature

      setState(() { // edit feature
        showEditInput[commentId] = false; // edit feature
      }); // edit feature

      await _loadStoryDetails(story['id'] as int); // edit feature

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

  // edit feature: Edit story method
  Future<void> _editPost(int storyId) async { // edit feature
    final title = postEditTitleController.text.trim(); // edit feature
    final content = postEditContentController.text.trim(); // edit feature
    final category = postEditCategoryController.text.trim(); // edit feature

    if (title.isEmpty && content.isEmpty && category.isEmpty) { // edit feature
      Get.snackbar( // edit feature
        'Error', // edit feature
        'At least one field must be filled', // edit feature
        backgroundColor: Colors.red, // edit feature
        colorText: Colors.white, // edit feature
        duration: const Duration(seconds: 2), // edit feature
      ); // edit feature
      return; // edit feature
    } // edit feature

    if (userId == 0) { // edit feature
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
      await StoriesService.editStory( // edit feature
        userId: userId, // edit feature
        storyId: storyId, // edit feature
        title: title.isEmpty ? null : title, // edit feature
        content: content.isEmpty ? null : content, // edit feature
        category: category.isEmpty ? null : category, // edit feature
      ); // edit feature

      showPostEditInput.value = false; // edit feature
      await _loadStoryDetails(storyId); // edit feature

      Get.snackbar( // edit feature
        'Success', // edit feature
        'Story edited successfully', // edit feature
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

  /// Check if string is an emoji
  bool _isEmoji(String text) {
    if (text.isEmpty) return false;
    final trimmed = text.trim();
    if (trimmed.length > 4) return false;
    final emojiRegex = RegExp(
      r'[\u{1F300}-\u{1F9FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]|[\u{1F600}-\u{1F64F}]|[\u{1F680}-\u{1F6FF}]|[\u{1F1E0}-\u{1F1FF}]|[\u{2764}\u{FE0F}]|[\u{2728}]|[\u{2B50}]',
      unicode: true,
    );
    final hasEmoji = emojiRegex.hasMatch(trimmed);
    final hasOnlyEmoji = trimmed.runes.every((rune) {
      final char = String.fromCharCode(rune);
      return emojiRegex.hasMatch(char) || rune == 0xFE0F || rune == 0x200D;
    });
    return hasEmoji && hasOnlyEmoji;
  }

  /// Load available emojis
  Future<void> _loadAvailableEmojis() async {
    try {
      final emojis = await EmojisService.getEmojis(
        status: 'Active',
        sortBy: 'image_url',
        order: 'ASC',
      );
      setState(() {
        availableEmojis = emojis;
      });
    } catch (e) {
      print('❌ Error loading emojis: $e');
    }
  }

  /// Load quick emojis
  Future<void> _loadQuickEmojis() async {
    try {
      final emojis = await EmojisService.getQuickEmojis();
      setState(() {
        quickEmojis = emojis;
      });
    } catch (e) {
      print('Error loading quick emojis: $e');
    }
  }

  /// Add emoji reaction to story
  Future<void> _addEmojiReaction(int storyId, String emoji) async {
    if (userId == 0) {
      await _loadUserId();
    }
    if (userId == 0) {
      _showCustomSnackbar(
        context,
        'Login Required',
        'Please login to react',
        isError: true,
      );
      return;
    }
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
          child: const CircularProgressIndicator(
            color: Color(0xFF8B4513),
            strokeWidth: 3,
          ),
        ),
      ),
    );

    try {
      await EmojisService.useEmoji(
        userId: userId,
        emoji: emoji,
        postType: 'story',
        postId: storyId,
      );
      await _loadComments(storyId);
      
      if (mounted) {
        Navigator.of(context).pop(); // Dismiss loading dialog
        _showCustomSnackbar(
          context,
          'Success',
          'Reaction added',
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Dismiss loading dialog
        _showCustomSnackbar(
          context,
          'Error',
          'Failed to add reaction: ${e.toString()}',
          isError: true,
        );
      }
    }
  }

  Future<void> _loadStoryDetails(int storyId) async {
    setState(() {
      isLoading = true;
    });

    try {
      final storyData = await StoriesService.getStoryDetails(storyId);

      // Load emojis and comments
      await Future.wait([
        _loadAvailableEmojis(),
        _loadQuickEmojis(),
        _loadComments(storyId),
      ]);

      // Debug: Print story data to check fields
      print('📖 Story Data: category=${storyData['category']}, testimony=${storyData['testimony']}, title=${storyData['title']}');

      setState(() {
        story = storyData;
        isLoading = false;
      });

      // Load comments
      _loadComments(storyId);
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      _showCustomSnackbar(
        context,
        'Error',
        e.toString().replaceAll('Exception: ', ''),
        isError: true,
      );
    }
  }

  // Helper method to check if story is a testimony
  bool _isTestimony(Map<String, dynamic> storyData) {
    // Check category field
    final category = storyData['category'] as String?;
    if (category != null) {
      final catLower = category.toLowerCase();
      if (catLower == 'testimony' || catLower.contains('testimony')) {
        print('✅ Detected as Testimony by category: $category');
        return true;
      }
    }

    // Check testimony field
    final testimony = storyData['testimony'] as String?;
    if (testimony != null && testimony.isNotEmpty) {
      print('✅ Detected as Testimony by testimony field');
      return true;
    }

    // Check title for testimony keyword
    final title = storyData['title'] as String?;
    if (title != null && title.toLowerCase().contains('testimony')) {
      print('✅ Detected as Testimony by title: $title');
      return true;
    }

    // Check content for testimony keyword
    final content = storyData['content'] as String?;
    if (content != null && content.toLowerCase().contains('testimony')) {
      print('✅ Detected as Testimony by content');
      return true;
    }

    print('📖 Detected as Story (not testimony)');
    return false;
  }

  Future<void> _loadComments(int storyId) async {
    try {
      print('🔄 Loading comments for storyId=$storyId, userId=$userId');
      final commentsList = await CommentsService.getComments(
        postType: 'story',
        postId: storyId,
        userId: userId > 0 ? userId : null,
      );

      print('✅ Loaded ${commentsList.length} top-level comments from API');

      // Flatten nested structure - API returns comments with nested replies array
      // We need to flatten it to a single list for our UI
      final flattenedComments = <Map<String, dynamic>>[];

      void flattenComments(List<dynamic> commentsToFlatten, {int? parentId}) {
        for (var comment in commentsToFlatten) {
          final commentMap = Map<String, dynamic>.from(comment);

          // Set parent_comment_id if this is a nested reply
          if (parentId != null) {
            commentMap['parent_comment_id'] = parentId;
          } else {
            // Ensure parent_comment_id is set (could be null, 0, or missing)
            final existingParentId = commentMap['parent_comment_id'];
            if (existingParentId == null || existingParentId == 0) {
              commentMap['parent_comment_id'] = null;
            }
          }

          // Remove the nested replies array (we'll flatten it)
          final nestedReplies = commentMap.remove('replies') as List<dynamic>?;

          // Add this comment to flattened list
          flattenedComments.add(commentMap);

          // Recursively flatten nested replies
          if (nestedReplies != null && nestedReplies.isNotEmpty) {
            final commentId = commentMap['id'] is int
                ? commentMap['id']
                : (commentMap['id'] is String ? int.tryParse(commentMap['id']) : null);
            if (commentId != null) {
              flattenComments(nestedReplies, parentId: commentId);
            }
          }
        }
      }

      flattenComments(commentsList);

      // Parse emoji reactions from comments (similar to blogs controller)
      final emojiReactions = <String, List<Map<String, dynamic>>>{};
      final textComments = <Map<String, dynamic>>[];

      for (var comment in flattenedComments) {
        final content = comment['content'] as String? ?? comment['comment'] as String? ?? '';
        final trimmed = content.trim();

        // Check if this is an emoji reaction
        bool isEmojiReaction = false;
        String? emojiKey;

        if (trimmed.length <= 4 && _isEmoji(trimmed)) {
          isEmojiReaction = true;
          emojiKey = trimmed;
        } else if (trimmed.contains('_') && (
          trimmed.contains('joy') || trimmed.contains('peace') ||
          trimmed.contains('love') || trimmed.contains('patience') ||
          trimmed.contains('kindness') || trimmed.contains('goodness') ||
          trimmed.contains('faithfulness') || trimmed.contains('gentleness') ||
          trimmed.contains('meekness') || trimmed.contains('self') ||
          trimmed.contains('control')
        )) {
          isEmojiReaction = true;
          emojiKey = trimmed;
        } else if (trimmed.contains('uploads/emojis/') || trimmed.contains('emojis/') ||
                   trimmed.contains('.png') || trimmed.contains('.jpg')) {
          isEmojiReaction = true;
          emojiKey = trimmed;
        } else if (trimmed.isNotEmpty && trimmed.length <= 10 && int.tryParse(trimmed) != null) {
          isEmojiReaction = true;
          emojiKey = trimmed;
        }

        // FIX: Add ALL comments to textComments (including emoji comments)
        // Emoji reactions and emoji comments are both stored in comments table
        // The UI (FruitEmojiHelper.buildCommentText) will render emoji URLs as images
        textComments.add(comment);
        print('✅ Added to comments: id=${comment['id']}, isEmoji=$isEmojiReaction, content="${trimmed.substring(0, trimmed.length > 20 ? 20 : trimmed.length)}..."');
        
        // Also track emoji reactions separately for the reactions bar (if it's an emoji)
        if (isEmojiReaction && emojiKey != null) {
          if (!emojiReactions.containsKey(emojiKey)) {
            emojiReactions[emojiKey] = [];
          }
          emojiReactions[emojiKey]!.add({
            'user_id': comment['user_id'],
            'user_name': comment['user_name'] ?? 'Anonymous',
            'profile_photo': comment['profile_photo'],
            'created_at': comment['created_at'],
          });
          print('✅ Also added to emojiReactions: $emojiKey by ${comment['user_name']}');
        }
      }

      print('✅ Flattened to ${textComments.length} total comments (including ${emojiReactions.length} emoji types)');

      setState(() {
        comments = textComments;
        storyEmojiReactions = emojiReactions;
      });
    } catch (e) {
      print('❌ Error loading comments: $e');
    }
  }

  Future<void> _addComment(int storyId, {int? parentCommentId}) async {
    if (userId == 0) {
      await _loadUserId();
    }

    if (userId == 0) {
      _showCustomSnackbar(
        context,
        'Login Required',
        'Please login to comment',
      );
      return;
    }

    final text = parentCommentId != null
        ? (replyControllers[parentCommentId]?.text.trim() ?? '')
        : commentController.text.trim();

    if (text.isEmpty) return;

    // FIX: Dismiss keyboard immediately
    FocusScope.of(context).unfocus();

    try {
      print('📤 Adding ${parentCommentId != null ? "REPLY" : "COMMENT"}: storyId=$storyId, parentCommentId=$parentCommentId, content=${text.substring(0, text.length > 50 ? 50 : text.length)}...');

      final newCommentId = await CommentsService.addComment(
        userId: userId,
        postType: 'story',
        postId: storyId,
        content: text,
        parentCommentId: parentCommentId,
      );

      print('✅ ${parentCommentId != null ? "Reply" : "Comment"} added successfully: ID=$newCommentId');

      if (parentCommentId != null) {
        replyControllers[parentCommentId]?.clear();
        // Automatically expand parent comment to show the new reply
        expandedReplies.add(parentCommentId);
        showReplyInput[parentCommentId] = false;
      } else {
      commentController.clear();
      }

      // Add a small delay to ensure database is updated
      await Future.delayed(const Duration(milliseconds: 500));

      // Reload comments to show the new reply
      await _loadComments(storyId);

      // Ensure parent comment is expanded after reload to show new reply
      if (parentCommentId != null) {
        setState(() {
          expandedReplies.add(parentCommentId);
        });
      }

      setState(() {}); // Force UI refresh

      print('📋 Total comments after reload: ${comments.length}');
      if (parentCommentId != null) {
        final parentComment = comments.firstWhere(
          (c) => (c['id'] is int ? c['id'] : int.tryParse(c['id'].toString())) == parentCommentId,
          orElse: () => <String, dynamic>{},
        );
        if (parentComment.isNotEmpty) {
          final replies = comments.where((c) {
            final cParentId = c['parent_comment_id'];
            if (cParentId == null) return false;
            final parentIdInt = cParentId is int ? cParentId : (cParentId is String ? int.tryParse(cParentId) : null);
            return parentIdInt == parentCommentId;
          }).toList();
          print('📋 Replies for parent $parentCommentId: ${replies.length}');
        }
      }

      // Show success message
      _showCustomSnackbar(
        context,
        'Success',
        parentCommentId != null ? 'Reply added successfully' : 'Comment added successfully',
      );

      // Scroll to top of comments after adding
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      _showCustomSnackbar(
        context,
        'Error',
        e.toString().replaceAll('Exception: ', ''),
        isError: true,
      );
    }
  }

  Future<bool> _checkCommentLiked(int commentId) async {
    if (userId == 0) return false;
    try {
      // Check if user has liked this comment by checking comment data
      final comment = comments.firstWhere(
        (c) => c['id'] == commentId,
        orElse: () => <String, dynamic>{},
      );
      return comment['is_liked'] == true || comment['user_liked'] == true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _toggleCommentLike(int commentId, int storyId) async {
    if (userId == 0) {
      await _loadUserId();
    }
    if (userId == 0) {
      _showCustomSnackbar(
        context,
        'Login Required',
        'Please login to like comments',
      );
      return;
    }

    try {
      await CommentsService.toggleCommentLike(
        userId: userId,
        commentId: commentId,
      );
      // Reload comments to update like status
      await _loadComments(storyId);
      setState(() {});
    } catch (e) {
      _showCustomSnackbar(
        context,
        'Error',
        e.toString().replaceAll('Exception: ', ''),
        isError: true,
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final baseUrl = 'http://admin.fosmessenger.com/';
    String? imageUrl;

    // Check all possible image fields
    if (story['file_path'] != null && (story['file_path'] as String).isNotEmpty) {
      final path = story['file_path'] as String;
      imageUrl = path.startsWith('http') ? path : baseUrl + path;
    } else if (story['image_url'] != null && (story['image_url'] as String).isNotEmpty) {
      final path = story['image_url'] as String;
      imageUrl = path.startsWith('http') ? path : baseUrl + path;
    } else if (story['image'] != null && (story['image'] as String).isNotEmpty) {
      final path = story['image'] as String;
      imageUrl = path.startsWith('http') ? path : baseUrl + path;
    } else if (story['thumbnail_path'] != null && (story['thumbnail_path'] as String).isNotEmpty) {
      final path = story['thumbnail_path'] as String;
      imageUrl = path.startsWith('http') ? path : baseUrl + path;
    }

    // Check if it's a testimony for theme
    final isTestimony = _isTestimony(story);

    return Scaffold(
      backgroundColor: isTestimony ? const Color(0xFFFAF6EC) : Colors.grey[50],
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(
          ResponsiveHelper.appBarHeight(context),
        ),
        child: AppBar(

          backgroundColor: isTestimony ? const Color(0xFFFAF6EC) : Colors.white,
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
                color: const Color(0xFF8B4513),
                size: ResponsiveHelper.iconSize(context, mobile: 24, tablet: 28, desktop: 32),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          actions: [
            Container(
              margin: EdgeInsets.symmetric(
                horizontal: ResponsiveHelper.spacing(context, 8),
                vertical: ResponsiveHelper.spacing(context, 8),
              ),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(
                  Icons.share_rounded,
                  color: const Color(0xFF8B4513),
                  size: ResponsiveHelper.iconSize(context, mobile: 24, tablet: 28, desktop: 32),
                ),
                onPressed: () {
                  final isTestimony = _isTestimony(story);
                  final baseUrl = 'http://admin.fosmessenger.com/';
                  String? storyMediaUrl;
                  if (story['file_path'] != null && (story['file_path'] as String).isNotEmpty) {
                    final path = story['file_path'] as String;
                    storyMediaUrl = path.startsWith('http') ? path : baseUrl + path;
                  } else if (story['image_url'] != null && (story['image_url'] as String).isNotEmpty) {
                    final path = story['image_url'] as String;
                    storyMediaUrl = path.startsWith('http') ? path : baseUrl + path;
                  }

                  ShareHelper.shareContent(
                    context: context,
                    contentType: isTestimony ? 'testimony' : 'story',
                    contentId: story['id'] is int ? story['id'] : int.tryParse(story['id'].toString()) ?? 0,
                    title: story['title'] ?? (isTestimony ? 'Testimony' : 'Story'),
                    content: story['testimony'] ?? story['content'],
                    mediaUrl: storyMediaUrl,
                  );
                },
              ),
            ),
          ],
          title: Row(

          children: [
            Builder(
              builder: (context) {
                // Check if it's a testimony using helper method
                final isTestimony = _isTestimony(story);

                return Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveHelper.spacing(context, 10),
                    vertical: ResponsiveHelper.spacing(context, 6),
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isTestimony
                          ? [
                              const Color(0xFF9F9467).withOpacity(0.2),
                              const Color(0xFF9F9467).withOpacity(0.1),
                            ]
                          : [
                              const Color(0xFF8B4513).withOpacity(0.1),
                              const Color(0xFF8B4513).withOpacity(0.05),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(
                      ResponsiveHelper.borderRadius(context, mobile: 20),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isTestimony ? Icons.favorite_rounded : Icons.auto_stories_rounded,
                        size: ResponsiveHelper.iconSize(context, mobile: 20),
                        color: isTestimony ? const Color(0xFF9F9467) : const Color(0xFF8B4513),
                      ),
                      SizedBox(width: ResponsiveHelper.spacing(context, 6)),
                      Text(
                        isTestimony ? 'Testimony' : 'Story',
                        style: ResponsiveHelper.textStyle(
                          context,
                          fontSize: ResponsiveHelper.fontSize(context, mobile: 18),
                          fontWeight: FontWeight.bold,
                          color: isTestimony ? const Color(0xFF9F9467) : const Color(0xFF8B4513),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.grey[300]!,
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        ),
      ),
      body: (isLoading && story.isEmpty)
          ? Center(
              child: CircularProgressIndicator(
                color: const Color(0xFF8B4513),
              ),
            )
          : story.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: ResponsiveHelper.iconSize(context, mobile: 64),
                        color: Colors.grey[400],
                      ),
                      SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                      Text(
                        'Story not found',
                        style: ResponsiveHelper.textStyle(
                          context,
                          fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Story Post Card - Enhanced Design with Theme
                            Builder(
                              builder: (context) {
                                final isTestimonyCard = _isTestimony(story);

                                return Container(
                                  margin: EdgeInsets.only(
                                    top: ResponsiveHelper.spacing(context, 8),
                                    bottom: ResponsiveHelper.spacing(context, 16),
                                    left: ResponsiveHelper.spacing(context, 12),
                                    right: ResponsiveHelper.spacing(context, 12),
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(
                                      ResponsiveHelper.borderRadius(context, mobile: 20),
                                    ),
                                    border: isTestimonyCard
                                        ? Border.all(
                                            color: const Color(0xFF9F9467).withOpacity(0.4),
                                            width: 2,
                                          )
                                        : null,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        spreadRadius: 0,
                                        blurRadius: 20,
                                        offset: const Offset(0, 6),
                                      ),
                                      BoxShadow(
                                        color: (isTestimonyCard ? const Color(0xFF9F9467) : const Color(0xFF8B4513)).withOpacity(0.1),
                                        spreadRadius: 2,
                                        blurRadius: 10,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header with User Info - Enhanced
                                  Container(
                                    padding: ResponsiveHelper.padding(
                                      context,
                                      horizontal: 16,
                                      vertical: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Colors.white,
                                          Colors.grey[50]!,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(
                                          ResponsiveHelper.borderRadius(context, mobile: 20),
                                        ),
                                        topRight: Radius.circular(
                                          ResponsiveHelper.borderRadius(context, mobile: 20),
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        // Profile Picture with gradient border
                                        Container(
                                          width: ResponsiveHelper.imageWidth(
                                            context,
                                            mobile: 48,
                                            tablet: 52,
                                            desktop: 56,
                                          ),
                                          height: ResponsiveHelper.imageWidth(
                                            context,
                                            mobile: 48,
                                            tablet: 52,
                                            desktop: 56,
                                          ),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: LinearGradient(
                                              colors: [
                                                const Color(0xFF8B4513),
                                                const Color(0xFF5F4628),
                                              ],
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFF8B4513).withOpacity(0.3),
                                                blurRadius: 8,
                                                spreadRadius: 1,
                                              ),
                                            ],
                                          ),
                                          padding: EdgeInsets.all(3),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.white,
                                            ),
                                            padding: EdgeInsets.all(2),
                                            child: ClipOval(
                                              child: story['profile_photo'] != null
                                                  ? CachedImage(
                                                      imageUrl: story['profile_photo'] as String,
                                  width: double.infinity,
                                                      height: double.infinity,
                                  fit: BoxFit.cover,
                                                      errorWidget: Container(
                                                        decoration: BoxDecoration(
                                                          gradient: LinearGradient(
                                                            colors: [
                                                              Colors.grey[200]!,
                                                              Colors.grey[300]!,
                                                            ],
                                                          ),
                                                        ),
                                                        child: Icon(
                                                          Icons.person,
                                                          size: ResponsiveHelper.iconSize(
                                context,
                                                            mobile: 24,
                                                          ),
                                color: const Color(0xFF8B4513),
                              ),
                            ),
                                                    )
                                                  : Container(
                                                      decoration: BoxDecoration(
                                                        gradient: LinearGradient(
                                                          colors: [
                                                            Colors.grey[200]!,
                                                            Colors.grey[300]!,
                                                          ],
                                                        ),
                                                      ),
                                                      child: Icon(
                                          Icons.person,
                                                        size: ResponsiveHelper.iconSize(
                                                          context,
                                                          mobile: 24,
                                                        ),
                                          color: const Color(0xFF8B4513),
                                                      ),
                                                    ),
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: ResponsiveHelper.spacing(context, 12),
                                        ),
                                        // User Name and Time
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      story['user_name'] as String? ?? 'Anonymous',
                                                      style: ResponsiveHelper.textStyle(
                                                        context,
                                                        fontSize: ResponsiveHelper.fontSize(
                                                          context,
                                                          mobile: 17,
                                                        ),
                                                        fontWeight: FontWeight.bold,
                                                        color: const Color(0xFF5F4628),
                                                      ),
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    width: ResponsiveHelper.spacing(context, 6),
                                                  ),
                                                  // Story/Testimony Badge
                                                  Builder(
                                                    builder: (context) {
                                                      // Use helper method to check if it's a testimony
                                                      final isTestimony = _isTestimony(story);

                                                      return Container(
                                                        padding: EdgeInsets.symmetric(
                                                          horizontal: ResponsiveHelper.spacing(context, 8),
                                                          vertical: ResponsiveHelper.spacing(context, 4),
                                                        ),
                                                        decoration: BoxDecoration(
                                                          gradient: isTestimony
                                                              ? LinearGradient(
                                                                  colors: [
                                                                    const Color(0xFF9F9467),
                                                                    const Color(0xFF8B6F47),
                                                                  ],
                                                                )
                                                              : LinearGradient(
                                                                  colors: [
                                                                    const Color(0xFF8B4513),
                                                                    const Color(0xFF5F4628),
                                                                  ],
                                                                ),
                                                          borderRadius: BorderRadius.circular(
                                                            ResponsiveHelper.borderRadius(context, mobile: 12),
                                                          ),
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: (isTestimony ? const Color(0xFF9F9467) : const Color(0xFF8B4513)).withOpacity(0.3),
                                                              blurRadius: 4,
                                                              offset: const Offset(0, 2),
                                                            ),
                                                          ],
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Icon(
                                                              isTestimony ? Icons.favorite_rounded : Icons.auto_stories_rounded,
                                                              size: ResponsiveHelper.iconSize(context, mobile: 14),
                                                              color: Colors.white,
                                                            ),
                                                            SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                                                            Text(
                                                              isTestimony ? 'Testimony' : 'Story',
                                                              style: ResponsiveHelper.textStyle(
                                                                context,
                                                                fontSize: ResponsiveHelper.fontSize(context, mobile: 11),
                                                                fontWeight: FontWeight.bold,
                                                                color: Colors.white,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                  SizedBox(
                                                    width: ResponsiveHelper.spacing(context, 6),
                                                  ),
                                                  Container(
                                                    padding: EdgeInsets.symmetric(
                                                      horizontal: ResponsiveHelper.spacing(context, 6),
                                                      vertical: 2,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF8B4513).withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Icon(
                                                      Icons.verified,
                                                      size: ResponsiveHelper.iconSize(context, mobile: 14),
                                                      color: const Color(0xFF8B4513),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (story['created_at'] != null)
                                                Padding(
                                                  padding: EdgeInsets.only(
                                                    top: ResponsiveHelper.spacing(context, 4),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons.access_time_rounded,
                                                        size: ResponsiveHelper.iconSize(context, mobile: 12),
                                                        color: Colors.grey[600],
                                                      ),
                                                      SizedBox(
                                                        width: ResponsiveHelper.spacing(context, 4),
                                                      ),
                                                      Text(
                                                        TimeHelper.getTimeAgo(story['created_at'] as String?),
                                                        style: ResponsiveHelper.textStyle(
                                                          context,
                                                          fontSize: ResponsiveHelper.fontSize(
                                                            context,
                                                            mobile: 12,
                                                          ),
                                                          color: Colors.grey[600],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        _buildStoryOptions(context, story),
                                      ],
                                    ),
                                  ),

                                  // Story Image with decorative border - Always show if available
                                  if (imageUrl != null && imageUrl.isNotEmpty)
                                    Container(
                                      margin: EdgeInsets.symmetric(
                                        horizontal: ResponsiveHelper.spacing(context, 12),
                                        vertical: ResponsiveHelper.spacing(context, 8),
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(
                                          ResponsiveHelper.borderRadius(context, mobile: 16),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.15),
                                            blurRadius: 15,
                                            spreadRadius: 2,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                          ResponsiveHelper.borderRadius(context, mobile: 16),
                                        ),
                                        child: Stack(
                              children: [
                                            CachedImage(
                                              imageUrl: imageUrl,
                                              width: double.infinity,
                                              height: ResponsiveHelper.imageHeight(
                                                context,
                                                mobile: 400,
                                                tablet: 450,
                                                desktop: 500,
                                              ),
                                              fit: BoxFit.cover,
                                              errorWidget: Container(
                                                height: ResponsiveHelper.imageHeight(
                                                  context,
                                                  mobile: 400,
                                                  tablet: 450,
                                                  desktop: 500,
                                                ),
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                    colors: [
                                                      const Color(0xFFE3F2FD),
                                                      const Color(0xFFBBDEFB),
                                                      const Color(0xFF8B4513).withOpacity(0.1),
                                                    ],
                                                  ),
                                                ),
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons.broken_image_outlined,
                                                      size: ResponsiveHelper.iconSize(
                                                        context,
                                                        mobile: 60,
                                                      ),
                                                      color: Colors.grey[600],
                                                    ),
                                                    SizedBox(
                                                      height: ResponsiveHelper.spacing(context, 8),
                                                    ),
                                                    Text(
                                                      'Image not available',
                                                      style: ResponsiveHelper.textStyle(
                                                        context,
                                                        fontSize: ResponsiveHelper.fontSize(
                                                          context,
                                                          mobile: 14,
                                                        ),
                                                        color: Colors.grey[600],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            // Gradient overlay at bottom
                                            Positioned(
                                              bottom: 0,
                                              left: 0,
                                              right: 0,
                                              child: Container(
                                                height: 100,
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    begin: Alignment.topCenter,
                                                    end: Alignment.bottomCenter,
                                                    colors: [
                                                      Colors.transparent,
                                                      Colors.black.withOpacity(0.3),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  else if (imageUrl == null || imageUrl.isEmpty)
                                    // Show placeholder if no image
                                    Container(
                                      margin: EdgeInsets.symmetric(
                                        horizontal: ResponsiveHelper.spacing(context, 12),
                                        vertical: ResponsiveHelper.spacing(context, 8),
                                      ),
                                      height: ResponsiveHelper.imageHeight(
                                        context,
                                        mobile: 200,
                                        tablet: 250,
                                        desktop: 300,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            const Color(0xFF8B4513).withOpacity(0.1),
                                            const Color(0xFF5F4628).withOpacity(0.05),
                                            Colors.grey[100]!,
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          ResponsiveHelper.borderRadius(context, mobile: 16),
                                        ),
                                      ),
                                      child: Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.image_outlined,
                                              size: ResponsiveHelper.iconSize(
                                                context,
                                                mobile: 48,
                                              ),
                                              color: Colors.grey[400],
                                            ),
                                            SizedBox(
                                              height: ResponsiveHelper.spacing(context, 8),
                                            ),
                                Text(
                                              'No image available',
                                  style: ResponsiveHelper.textStyle(
                                    context,
                                                fontSize: ResponsiveHelper.fontSize(
                                                  context,
                                                  mobile: 14,
                                                ),
                                                color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                                      ),
                                    ),

                                  // Content Section
                                  Padding(
                                    padding: ResponsiveHelper.padding(
                                      context,
                                      all: 16,
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Title
                                        if (story['title'] != null)
                                          Column( // edit feature
                                            crossAxisAlignment: CrossAxisAlignment.start, // edit feature
                                            children: [ // edit feature
                                              Padding( // edit feature
                                                padding: EdgeInsets.only( // edit feature
                                                  bottom: ResponsiveHelper.spacing(context, 8), // edit feature
                                                ), // edit feature
                                                child: Text( // edit feature
                                                  story['title'] as String, // edit feature
                                                  style: ResponsiveHelper.textStyle( // edit feature
                                                    context, // edit feature
                                                    fontSize: ResponsiveHelper.fontSize( // edit feature
                                                      context, // edit feature
                                                      mobile: 20, // edit feature
                                                    ), // edit feature
                                                    fontWeight: FontWeight.bold, // edit feature
                                                    color: const Color(0xFF5F4628), // edit feature
                                                  ), // edit feature
                                                ), // edit feature
                                              ), // edit feature
                                              // edit feature: Show "edited" label if story was edited
                                              if (story['is_edited'] == true || story['is_edited'] == 1) ...[ // edit feature
                                                SizedBox(height: ResponsiveHelper.spacing(context, 4)), // edit feature
                                                Text( // edit feature
                                                  'edited', // edit feature
                                                  style: TextStyle( // edit feature
                                                    fontSize: 10, // edit feature
                                                    color: Colors.grey[500], // edit feature
                                                    fontStyle: FontStyle.italic, // edit feature
                                                  ), // edit feature
                                                ), // edit feature
                                              ], // edit feature
                                            ], // edit feature
                                          ), // edit feature
                                        // edit feature: Edit button for own stories within 15 minutes
                                        if (_canEditPost(story)) ...[ // edit feature
                                          SizedBox(height: ResponsiveHelper.spacing(context, 8)), // edit feature
                                          GestureDetector( // edit feature
                                            onTap: () { // edit feature
                                              setState(() { // edit feature
                                                postEditTitleController.text = story['title'] as String? ?? ''; // edit feature
                                                postEditContentController.text = story['content'] as String? ?? ''; // edit feature
                                                postEditCategoryController.text = story['category'] as String? ?? ''; // edit feature
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
                                                    'Edit Story', // edit feature
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

                                        // Fruit Tag - Enhanced with Theme
                            if (story['fruit_tag'] != null)
                              Builder(
                                builder: (context) {
                                  final isTestimonyTag = _isTestimony(story);

                                  return Container(
                                    margin: EdgeInsets.only(
                                      bottom: ResponsiveHelper.spacing(context, 12),
                                    ),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: ResponsiveHelper.spacing(context, 14),
                                      vertical: ResponsiveHelper.spacing(context, 8),
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: isTestimonyTag
                                            ? [
                                                const Color(0xFF9F9467).withOpacity(0.2),
                                                const Color(0xFF9F9467).withOpacity(0.1),
                                              ]
                                            : [
                                                const Color(0xFF8B4513).withOpacity(0.15),
                                                const Color(0xFF8B4513).withOpacity(0.08),
                                              ],
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        ResponsiveHelper.borderRadius(
                                          context,
                                          mobile: 25,
                                        ),
                                      ),
                                      border: Border.all(
                                        color: isTestimonyTag
                                            ? const Color(0xFF9F9467).withOpacity(0.4)
                                            : const Color(0xFF8B4513).withOpacity(0.3),
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: (isTestimonyTag ? const Color(0xFF9F9467) : const Color(0xFF8B4513)).withOpacity(0.1),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.local_fire_department_rounded,
                                          size: ResponsiveHelper.iconSize(context, mobile: 16),
                                          color: isTestimonyTag ? const Color(0xFF9F9467) : const Color(0xFF8B4513),
                                        ),
                                        SizedBox(
                                          width: ResponsiveHelper.spacing(context, 6),
                                        ),
                                        Text(
                                          story['fruit_tag'] as String,
                                          style: ResponsiveHelper.textStyle(
                                            context,
                                            fontSize: ResponsiveHelper.fontSize(
                                              context,
                                              mobile: 13,
                                            ),
                                            fontWeight: FontWeight.bold,
                                            color: isTestimonyTag ? const Color(0xFF9F9467) : const Color(0xFF8B4513),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),

                            // Content
                                        if (story['content'] != null)
                            Text(
                                            story['content'] as String,
                              style: ResponsiveHelper.textStyle(
                                context,
                                              fontSize: ResponsiveHelper.fontSize(
                                                context,
                                                mobile: 15,
                                              ),
                                color: Colors.black87,
                                height: 1.6,
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
                                    'Edit Story', // edit feature
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
                                    controller: postEditContentController, // edit feature
                                    decoration: InputDecoration( // edit feature
                                      labelText: 'Content', // edit feature
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
                                        onPressed: () => _editPost(story['id'] as int), // edit feature
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
                                      ],
                                    ),
                                  ),

                                  // Emoji Reactions Section
                                  Padding(
                                    padding: ResponsiveHelper.padding(
                                      context,
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    child: _buildEmojiReactions(context, story['id'] as int),
                                  ),
                                ],
                              ),
                                );
                              },
                            ),

                            // Comments Section - Enhanced Design
                            Container(
                              margin: EdgeInsets.only(
                                bottom: ResponsiveHelper.spacing(context, 12),
                                left: ResponsiveHelper.spacing(context, 12),
                                right: ResponsiveHelper.spacing(context, 12),
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(
                                  ResponsiveHelper.borderRadius(context, mobile: 20),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    spreadRadius: 0,
                                    blurRadius: 20,
                                    offset: const Offset(0, 6),
                                  ),
                                  BoxShadow(
                                    color: const Color(0xFF8B4513).withOpacity(0.05),
                                    spreadRadius: 2,
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Comments Header - Enhanced
                                  Container(
                                    padding: ResponsiveHelper.padding(
                                      context,
                                      horizontal: 16,
                                      vertical: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Colors.white,
                                          Colors.grey[50]!,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(
                                          ResponsiveHelper.borderRadius(context, mobile: 20),
                                        ),
                                        topRight: Radius.circular(
                                          ResponsiveHelper.borderRadius(context, mobile: 20),
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: EdgeInsets.all(
                                            ResponsiveHelper.spacing(context, 8),
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                const Color(0xFF8B4513).withOpacity(0.15),
                                                const Color(0xFF8B4513).withOpacity(0.08),
                                              ],
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.comment_rounded,
                                            size: ResponsiveHelper.iconSize(
                                              context,
                                              mobile: 22,
                                            ),
                                color: const Color(0xFF8B4513),
                              ),
                            ),
                                        SizedBox(
                                          width: ResponsiveHelper.spacing(context, 12),
                                        ),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Comments',
                                                style: ResponsiveHelper.textStyle(
                                                  context,
                                                  fontSize: ResponsiveHelper.fontSize(
                                                    context,
                                                    mobile: 18,
                                                  ),
                                                  fontWeight: FontWeight.bold,
                                                  color: const Color(0xFF5F4628),
                                                ),
                                              ),
                                              Text(
                                                '${comments.length} ${comments.length == 1 ? 'comment' : 'comments'}',
                                                style: ResponsiveHelper.textStyle(
                                                  context,
                                                  fontSize: ResponsiveHelper.fontSize(
                                                    context,
                                                    mobile: 13,
                                                  ),
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Comments List - Nested Comments Support
                            Builder(
                              builder: (context) {
                                // Filter top-level comments (no parent)
                                final topLevelComments = comments.where((comment) {
                                  final parentId = comment['parent_comment_id'];
                                  if (parentId == null) return true;
                                  // Handle both int and String types from API
                                  if (parentId is int) return parentId == 0;
                                  if (parentId is String) {
                                    final parsed = int.tryParse(parentId);
                                    return parsed == null || parsed == 0;
                                  }
                                  return false;
                                }).toList();

                                if (topLevelComments.isEmpty) {
                                  return Padding(
                                    padding: ResponsiveHelper.padding(
                                      context,
                                      all: 24,
                                    ),
                                    child: Center(
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.chat_bubble_outline,
                                            size: ResponsiveHelper.iconSize(
                                              context,
                                              mobile: 48,
                                            ),
                                            color: Colors.grey[400],
                                          ),
                                          SizedBox(
                                            height: ResponsiveHelper.spacing(context, 12),
                                          ),
                                          Text(
                                            'No comments yet',
                                  style: ResponsiveHelper.textStyle(
                                    context,
                                              fontSize: ResponsiveHelper.fontSize(
                                                context,
                                                mobile: 16,
                                              ),
                                              color: Colors.grey[600],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          SizedBox(
                                            height: ResponsiveHelper.spacing(context, 4),
                                          ),
                                          Text(
                                            'Be the first to comment!',
                                            style: ResponsiveHelper.textStyle(
                                              context,
                                              fontSize: ResponsiveHelper.fontSize(
                                                context,
                                                mobile: 14,
                                              ),
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }

                                return Column(
                                  children: topLevelComments.map(
                                    (comment) => _buildCommentItem(
                                      context,
                                      comment,
                                      story['id'] as int,
                                    ),
                                  ).toList(),
                                );
                              },
                            ),
                          ],
                        ),
                      ),



                    // Comment Input Bar - Enhanced Design
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 15,
                            spreadRadius: 2,
                            offset: const Offset(0, -4),
                          ),
                          BoxShadow(
                            color: const Color(0xFF8B4513).withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: SafeArea(
                        top: false,
                        child: Padding(
                          padding: ResponsiveHelper.padding(
                            context,
                            horizontal: 16,
                            vertical: 12,
                      ),
                      child: Row(
                        children: [
                              // User Avatar (if logged in)
                              if (userId > 0)
                                Container(
                                  width: ResponsiveHelper.imageWidth(
                                    context,
                                    mobile: 36,
                                    tablet: 40,
                                    desktop: 44,
                                  ),
                                  height: ResponsiveHelper.imageWidth(
                                    context,
                                    mobile: 36,
                                    tablet: 40,
                                    desktop: 44,
                                  ),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.grey[300],
                                  ),
                                  child: Icon(
                                    Icons.person,
                                    size: ResponsiveHelper.iconSize(
                                      context,
                                      mobile: 20,
                                    ),
                                    color: Colors.grey[600],
                                  ),
                                ),
                              if (userId > 0)
                                SizedBox(
                                  width: ResponsiveHelper.spacing(context, 12),
                                ),

                              // Comment Input - Enhanced
                          Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.grey[100]!,
                                        Colors.grey[50]!,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      ResponsiveHelper.borderRadius(
                                        context,
                                        mobile: 28,
                                      ),
                                    ),
                                    border: Border.all(
                                      color: userId > 0
                                          ? const Color(0xFF8B4513).withOpacity(0.2)
                                          : Colors.grey[300]!,
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                            child: TextField(
                              controller: commentController,
                              decoration: InputDecoration(
                                      hintText: userId > 0
                                          ? 'Write a comment...'
                                          : 'Login to comment',
                                      hintStyle: ResponsiveHelper.textStyle(
                                        context,
                                        fontSize: ResponsiveHelper.fontSize(
                                          context,
                                          mobile: 14,
                                        ),
                                        color: Colors.grey[600],
                                      ),
                                      border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: ResponsiveHelper.spacing(context, 16),
                                  vertical: ResponsiveHelper.spacing(context, 12),
                                ),
                              ),
                                    style: ResponsiveHelper.textStyle(
                                      context,
                                      fontSize: ResponsiveHelper.fontSize(
                                        context,
                                        mobile: 14,
                                      ),
                                      color: Colors.black87,
                                    ),
                                    maxLines: null,
                                    textInputAction: TextInputAction.send,
                                    onSubmitted: (_) => _addComment(story['id'] as int, parentCommentId: null),
                                  ),
                                ),
                              ),

                              SizedBox(
                                width: ResponsiveHelper.spacing(context, 8),
                              ),

                              // Emoji button (reusable widget from blog_details_screen)
                              EmojiButton(
                                onTap: () => _showEmojiPicker(context, story['id'] as int, commentController),
                              ),

                              SizedBox(
                                width: ResponsiveHelper.spacing(context, 8),
                              ),

                              // Send Button - Enhanced
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _addComment(story['id'] as int, parentCommentId: null),
                                  borderRadius: BorderRadius.circular(
                                    ResponsiveHelper.borderRadius(
                                      context,
                                      mobile: 28,
                                    ),
                                  ),
                                  child: Container(
                                    padding: ResponsiveHelper.padding(
                                      context,
                                      all: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: userId > 0
                                          ? LinearGradient(
                                              colors: [
                                                const Color(0xFF8B4513),
                                                const Color(0xFF5F4628),
                                              ],
                                            )
                                          : null,
                                      color: userId > 0 ? null : Colors.grey[300],
                                      shape: BoxShape.circle,
                                      boxShadow: userId > 0
                                          ? [
                                              BoxShadow(
                                                color: const Color(0xFF8B4513).withOpacity(0.4),
                                                blurRadius: 12,
                                                spreadRadius: 1,
                                                offset: const Offset(0, 4),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Icon(
                                      Icons.send_rounded,
                                      color: userId > 0 ? Colors.white : Colors.grey[600],
                                      size: ResponsiveHelper.iconSize(
                                        context,
                                        mobile: 22,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
      ]
                        )
                    )
                    )
                  ],
                ),
    );
  }

  Widget _buildCommentItem(BuildContext context, Map<String, dynamic> comment, int storyId) {
    // Handle comment ID - can be int or String from API
    final commentIdRaw = comment['id'];
    final commentId = commentIdRaw is int ? commentIdRaw : (commentIdRaw is String ? int.tryParse(commentIdRaw) : null);
    if (commentId == null) {
      return const SizedBox.shrink();
    }

    // Handle parent comment ID - can be int, String, or null
    final parentCommentIdRaw = comment['parent_comment_id'];
    final parentCommentId = parentCommentIdRaw == null
        ? null
        : (parentCommentIdRaw is int
            ? parentCommentIdRaw
            : (parentCommentIdRaw is String ? int.tryParse(parentCommentIdRaw) : null));
    final isTopLevel = parentCommentId == null || parentCommentId == 0;

    // Get replies for this comment - handle both int and String types
    final replies = comments.where((c) {
      final cParentId = c['parent_comment_id'];
      if (cParentId == null) return false;
      // Handle both int and String types
      final parentIdInt = cParentId is int ? cParentId : (cParentId is String ? int.tryParse(cParentId) : null);
      if (parentIdInt == null) return false;
      // Compare with commentId (also handle int/String)
      final cIdRaw = c['id'];
      final cId = cIdRaw is int ? cIdRaw : (cIdRaw is String ? int.tryParse(cIdRaw) : null);
      // Reply's parent_comment_id should match this comment's id, and reply's id should be different
      return parentIdInt == commentId && cId != commentId;
    }).toList();

    // Initialize reply controller if not exists
    if (!replyControllers.containsKey(commentId)) {
      replyControllers[commentId] = TextEditingController();
    }

    final showReplies = expandedReplies.contains(commentId);

    return Container(
      padding: ResponsiveHelper.padding(
        context,
        horizontal: isTopLevel ? 16 : 20,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: isTopLevel
              ? BorderSide(
                  color: Colors.grey[200]!,
                  width: 0.5,
                )
              : BorderSide.none,
        ),
        color: !isTopLevel ? Colors.grey[50] : Colors.transparent,
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Picture
              Container(
                width: ResponsiveHelper.imageWidth(
                  context, mobile: isTopLevel ? 40 : 32, tablet: isTopLevel ? 44 : 36, desktop: isTopLevel ? 48 : 40),
                height: ResponsiveHelper.imageWidth(
                  context, mobile: isTopLevel ? 40 : 32, tablet: isTopLevel ? 44 : 36, desktop: isTopLevel ? 48 : 40),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isTopLevel
                      ? LinearGradient(
                          colors: [
                            const Color(0xFF8B4513).withOpacity(0.2),
                            const Color(0xFF5F4628).withOpacity(0.1),
                          ],
                        )
                  : null,
                  color: !isTopLevel ? Colors.grey[200] : null,
                ),
                padding: isTopLevel ? EdgeInsets.all(2) : EdgeInsets.zero,
                child: ClipOval(
                  child: comment['profile_photo'] != null
                      ? CachedImage(
                          imageUrl: comment['profile_photo'] as String,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          errorWidget: Container(
                            color: Colors.grey[300],
                            child: Icon(
                      Icons.person,
                              size: ResponsiveHelper.iconSize(context, mobile: isTopLevel ? 20 : 16),
                              color: Colors.grey[600],
                            ),
                          ),
                        )
                      : Container(
                          color: Colors.grey[300],
                          child: Icon(
                            Icons.person,
                            size: ResponsiveHelper.iconSize(context, mobile: isTopLevel ? 20 : 16),
                            color: Colors.grey[600],
                          ),
                        ),
                ),
              ),

            SizedBox(width: ResponsiveHelper.spacing(context, 12)),

              // Comment Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    // Comment Bubble - Professional Style
                    Container(
                      padding: ResponsiveHelper.padding(
                        context,
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isTopLevel ? Colors.white : Colors.grey[50],
                        borderRadius: BorderRadius.circular(
                          ResponsiveHelper.borderRadius(context, mobile: 16),
                        ),
                        border: Border.all(
                          color: isTopLevel
                              ? const Color(0xFF8B4513).withOpacity(0.1)
                              : Colors.grey[300]!,
                          width: 1,
                        ),
                        boxShadow: isTopLevel
                            ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // User Name and Time
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                    comment['user_name'] as String? ?? 'Anonymous',
                    style: ResponsiveHelper.textStyle(
                      context,
                                    fontSize: ResponsiveHelper.fontSize(
                                      context,
                                      mobile: 14,
                                      tablet: 15,
                                      desktop: 16,
                                    ),
                      fontWeight: FontWeight.bold,
                                    color: const Color(0xFF5F4628),
                                  ),
                                ),
                              ),
                              Text(
                                TimeHelper.getTimeAgo(comment['created_at'] as String?),
                                style: ResponsiveHelper.textStyle(
                                  context,
                                  fontSize: ResponsiveHelper.fontSize(
                                    context,
                                    mobile: 11,
                                    tablet: 12,
                                    desktop: 13,
                                  ),
                                  color: Colors.grey[600],
                                ),
                              ),
                              SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                              // Report Button - Only show for other users' comments
                              if (this.userId != 0 && (comment['user_id'] != null && comment['user_id'].toString() != this.userId.toString()))
                                InkWell(
                                  onTap: () => _showReportDialog(context, comment),
                                  child: Icon(
                                    Icons.report_gmailerrorred_outlined,
                                    size: ResponsiveHelper.iconSize(context, mobile: 14),
                                    color: Colors.grey[400],
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: ResponsiveHelper.spacing(context, 6)),
                          // Comment Text
                          FruitEmojiHelper.buildCommentText(
                            context,
                    comment['content'] as String? ?? '',
                    style: ResponsiveHelper.textStyle(
                      context,
                              fontSize: ResponsiveHelper.fontSize(
                                context,
                                mobile: 14,
                                tablet: 15,
                                desktop: 16,
                              ),
                      color: Colors.black87,
                              height: 1.5,
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
                ],
                      ),
                    ),

                    // Actions Row - Like and Reply
                    Padding(
                      padding: EdgeInsets.only(
                        top: ResponsiveHelper.spacing(context, 8),
                        left: ResponsiveHelper.spacing(context, 4),
                      ),
                      child: Row(
                        children: [
                          // Like button
                          FutureBuilder<bool>(
                            future: _checkCommentLiked(commentId),
                            builder: (context, snapshot) {
                              final isLiked = snapshot.data ?? false;
                              return InkWell(
                                onTap: () => _toggleCommentLike(commentId, storyId),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isLiked ? Icons.favorite : Icons.favorite_border,
                                      size: ResponsiveHelper.iconSize(context, mobile: 16),
                                      color: isLiked ? Colors.red[700] : Colors.grey[600],
                                    ),
                                    SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                                    Text(
                                      'Like',
                                      style: ResponsiveHelper.textStyle(
                                        context,
                                        fontSize: ResponsiveHelper.fontSize(
                                          context,
                                          mobile: 12,
                                        ),
                                        fontWeight: FontWeight.w600,
                                        color: isLiked ? Colors.red[700] : Colors.grey[600],
              ),
            ),
          ],
        ),
                              );
                            },
                          ),
                          SizedBox(width: ResponsiveHelper.spacing(context, 16)),
                          // Reply button
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
                                  size: ResponsiveHelper.iconSize(context, mobile: 16),
                                  color: const Color(0xFF8B4513),
                                ),
                                SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                                Text(
                                  'Reply',
                                  style: ResponsiveHelper.textStyle(
                                    context,
                                    fontSize: ResponsiveHelper.fontSize(
                                      context,
                                      mobile: 12,
                                    ),
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF8B4513),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // edit feature: Edit Button - Show for all comments within 15 minutes
                          _buildEditButton(context, comment, storyId),
                          // View replies button (if replies exist)
                          if (replies.isNotEmpty) ...[
                            SizedBox(width: ResponsiveHelper.spacing(context, 16)),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  if (showReplies) {
                                    expandedReplies.remove(commentId);
                                  } else {
                                    expandedReplies.add(commentId);
                                  }
                                });
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    showReplies ? Icons.expand_less : Icons.expand_more,
                                    size: ResponsiveHelper.iconSize(context, mobile: 16),
                                    color: const Color(0xFF8B4513),
                                  ),
                                  SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                                  Text(
                                    '${replies.length} ${replies.length == 1 ? 'reply' : 'replies'}',
                                    style: ResponsiveHelper.textStyle(
                                      context,
                                      fontSize: ResponsiveHelper.fontSize(
                                        context,
                                        mobile: 12,
                                      ),
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF8B4513),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Reply Input
                    if (showReplyInput[commentId] ?? false)
                      Padding(
                        padding: EdgeInsets.only(
                          top: ResponsiveHelper.spacing(context, 12),
                        ),
                        child: _buildReplyInput(context, commentId, storyId),
                      ),
                    
                    // edit feature: Edit Input
                    if (showEditInput[commentId] ?? false)
                      Padding(
                        padding: EdgeInsets.only(
                          top: ResponsiveHelper.spacing(context, 12),
                        ),
                        child: _buildEditInput(context, commentId, storyId, 'story'),
                      ),

                    // Nested Replies
                    if (showReplies && replies.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(
                          top: ResponsiveHelper.spacing(context, 12),
                          left: ResponsiveHelper.spacing(context, 8),
                        ),
                        child: Column(
                          children: replies.map(
                            (reply) => _buildCommentItem(context, reply, storyId),
                          ).toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReplyInput(BuildContext context, int parentCommentId, int storyId) {
    if (!replyControllers.containsKey(parentCommentId)) {
      replyControllers[parentCommentId] = TextEditingController();
    }
    final replyController = replyControllers[parentCommentId]!;

    return Container(
      padding: ResponsiveHelper.padding(
        context,
        all: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          ResponsiveHelper.borderRadius(context, mobile: 12),
        ),
        border: Border.all(
          color: const Color(0xFF8B4513).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: replyController,
              decoration: InputDecoration(
                hintText: 'Write a reply...',
                hintStyle: ResponsiveHelper.textStyle(
                  context,
                  fontSize: ResponsiveHelper.fontSize(context, mobile: 13),
                  color: Colors.grey[600],
                ),
                border: InputBorder.none,
                contentPadding: ResponsiveHelper.padding(
                  context,
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              style: ResponsiveHelper.textStyle(
                context,
                fontSize: ResponsiveHelper.fontSize(context, mobile: 13),
                color: Colors.black87,
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _addComment(storyId, parentCommentId: parentCommentId),
            ),
          ),
          SizedBox(width: ResponsiveHelper.spacing(context, 8)),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _addComment(storyId, parentCommentId: parentCommentId),
              borderRadius: BorderRadius.circular(
                ResponsiveHelper.borderRadius(context, mobile: 20),
              ),
              child: Container(
                padding: ResponsiveHelper.padding(
                  context,
                  all: 8,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF8B4513),
                      const Color(0xFF5F4628),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.send_rounded,
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

  /// Build Emoji Reactions Widget
  Widget _buildEmojiReactions(BuildContext context, int storyId) {
    final hasReactions = storyEmojiReactions.isNotEmpty;
    final quickEmojisList = quickEmojis;

    // Debug logging
    print('🔍 _buildEmojiReactions: hasReactions=$hasReactions, reactions count=${storyEmojiReactions.length}');
    if (hasReactions) {
      storyEmojiReactions.forEach((key, users) {
        print('   - Emoji key: "$key" (${users.length} users)');
      });
    }

    return Container(
      padding: ResponsiveHelper.padding(
        context,
        all: ResponsiveHelper.isMobile(context) ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4), // Rectangle with small radius
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
                  color: const Color(0xFF8B4513),
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
            SizedBox(height: ResponsiveHelper.spacing(context, 10)),

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
                      color: const Color(0xFF9F9467),
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
                        await _addEmojiReaction(storyId, emoji!);
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
                  onTap: () => _showEmojiPicker(context, storyId, commentController),
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
                        color: const Color(0xFF8B4513),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Display Reactions Count - Phone Style with Actual Emojis
          if (hasReactions) ...[
            SizedBox(height: ResponsiveHelper.spacing(context, 12)),
            Row(
              children: [
                // Show first emoji from reactions instead of heart icon
                if (storyEmojiReactions.isNotEmpty) ...[
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: Builder(
                      builder: (context) {
                        final firstReaction = storyEmojiReactions.entries.first;
                        final emojiChar = firstReaction.key;
                        Map<String, dynamic>? fruitEmoji;

                        // Find matching emoji
                        for (var emoji in availableEmojis) {
                          final emojiCharFromList = emoji['emoji_char'] as String? ?? '';
                          if (emojiCharFromList.trim() == emojiChar.trim() ||
                              emojiCharFromList == emojiChar) {
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
                          color: const Color(0xFF8B4513),
                        );
                      },
                    ),
                  ),
                  SizedBox(width: ResponsiveHelper.spacing(context, 6)),
                ] else
                  Icon(
                    Icons.favorite_rounded,
                    size: ResponsiveHelper.fontSize(context, mobile: 16),
                    color: const Color(0xFF8B4513),
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
            SizedBox(height: ResponsiveHelper.spacing(context, 8)),
            Wrap(
              spacing: ResponsiveHelper.spacing(context, 6),
              runSpacing: ResponsiveHelper.spacing(context, 6),
              children: storyEmojiReactions.entries.map((entry) {
                // Find fruit image for this emoji (can be character, code, image_url, or ID)
                final emojiKey = entry.key;
                final usersWhoReacted = entry.value as List<Map<String, dynamic>>;
                Map<String, dynamic>? fruitEmoji;

                // Try multiple matching strategies
                for (var emoji in availableEmojis) {
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
                }

                return GestureDetector(
                  onTap: () {
                    // Show dialog with users who reacted
                    showDialog(
                      context: context,
                      builder: (context) => Dialog(
                        child: Container(
                          padding: ResponsiveHelper.padding(context, all: 20),
                          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
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
                                      child: HomeScreen.buildEmojiDisplay(context, fruitEmoji!, size: 32, userEmail: userEmail),
                                    ),
                                  SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                                  Text(
                                    '${usersWhoReacted.length} ${usersWhoReacted.length == 1 ? 'person' : 'people'} reacted',
                                    style: ResponsiveHelper.textStyle(context, fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                              Flexible(
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: usersWhoReacted.length,
                                  itemBuilder: (context, index) {
                                    final user = usersWhoReacted[index];
                                    return ListTile(
                                      leading: CircleAvatar(
                                        backgroundImage: user['profile_photo'] != null
                                            ? NetworkImage(
                                                (user['profile_photo'] as String).startsWith('http://') ||
                                                (user['profile_photo'] as String).startsWith('https://')
                                                  ? user['profile_photo'] as String
                                                  : 'http://admin.fosmessenger.com/${user['profile_photo']}'
                                              )
                                            : null,
                                        child: user['profile_photo'] == null ? const Icon(Icons.person) : null,
                                      ),
                                      title: Text(user['user_name'] ?? 'Anonymous'),
                                    );
                                  },
                                ),
                              ),
                              SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
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
                            color: Colors.grey[400],
                          ),
                        ),
                      SizedBox(width: ResponsiveHelper.spacing(context, 6)),
                      Text(
                        '${usersWhoReacted.length}',
                        style: TextStyle(
                          fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF8B4513),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  /// Show Emoji+Sticker Picker for Comment Text - sends emoji directly without showing in input field
  void _showCommentEmojiPicker(BuildContext context, TextEditingController textController) {
    showEmojiStickerPicker(
      context: context,
      onEmojiSelected: (emoji) async {
        // Send emoji directly as comment - no preview in text field!
        final story = this.story;
        if (story != null) {
          await _sendEmojiDirectly(story['id'] as int, emoji);
        }
      },
      height: 350,
    );
  }

  /// Send emoji/sticker directly as comment without showing in input field
  Future<void> _sendEmojiDirectly(int storyId, String emoji, {int? parentCommentId}) async {
    if (emoji.isEmpty || userId == 0) return;

    FocusScope.of(context).unfocus();

    isSubmittingComment.value = true;

    try {
      await CommentsService.addComment(
        userId: userId,
        postType: 'story',
        postId: storyId,
        content: emoji,
        parentCommentId: parentCommentId,
      );

      // Clear and reload
      commentController.clear();
      await _loadComments(storyId);

      // Scroll to bottom
      await Future.delayed(const Duration(milliseconds: 300));
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
        );
      }
      _showCustomSnackbar(context, 'Success', 'Comment added successfully');
    } catch (e) {
      print('Error sending emoji comment: $e');
      _showCustomSnackbar(context, 'Error', 'Failed to send emoji. Please try again.', isError: true);
    } finally {
      isSubmittingComment.value = false;
    }
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

  /// Show emoji picker for story comments - sends emoji directly without showing in input field
  void _showEmojiPicker(BuildContext context, int storyId, TextEditingController controller, {int? parentCommentId}) {
    showEmojiStickerPicker(
      context: context,
      onEmojiSelected: (emoji) async {
        // Send emoji directly as comment - no preview in text field!
        await _sendEmojiDirectly(storyId, emoji, parentCommentId: parentCommentId);
      },
      height: 350,
    );
  }

  void _showReportDialog(BuildContext context, Map<String, dynamic> comment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Content'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choose an action:'),
            const SizedBox(height: 16),
            if (comment['user_id'] != null && comment['user_id'].toString() != this.userId.toString()) ...[
              ListTile(
                leading: const Icon(Icons.report_outlined, color: Colors.orange),
                title: const Text('Report Comment'),
                onTap: () async {
                  Navigator.pop(context);
                  final commentId = comment['id'] is int ? comment['id'] : int.parse(comment['id'].toString());
                  await ReportUtils.handleReportButtonTap(
                    context: context,
                    contentType: 'story_comment',
                    contentId: commentId,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.block, color: Colors.red),
                title: const Text('Block User'),
                onTap: () async {
                  Navigator.pop(context);
                  final userIdRaw = comment['user_id'];
                  if (userIdRaw != null) {
                    final userId = userIdRaw is int ? userIdRaw : int.tryParse(userIdRaw.toString());
                    if (userId == null) return;

                    final userName = comment['user_name'] ?? 'this user';
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
                        await UserBlockingService.blockUser(userId);
                        if (mounted) {
                          _showCustomSnackbar(
                            context,
                            'Success',
                            'User blocked',
                          );
                        }
                        _loadComments(story['id'] as int);
                      } catch (e) {
                        if (mounted) {
                          _showCustomSnackbar(
                            context,
                            'Error',
                            'Failed to block user',
                            isError: true,
                          );
                        }
                      }
                    }
                  }
                },
              ),
            ] else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('This is your own comment.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ],
      ),
    );
  }

  Widget _buildStoryOptions(BuildContext context, Map<String, dynamic> story) {
    final userIdRaw = story['user_id'] ?? story['created_by'];
    final posterId = userIdRaw is int ? userIdRaw : int.tryParse(userIdRaw?.toString() ?? '');
    
    // Check if we have any options to show
    final hasOptions = posterId != null && posterId != this.userId;
    
    // Only show the PopupMenuButton if there are options
    if (!hasOptions) {
      return SizedBox(width: 40); // Empty placeholder for alignment
    }
    
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: Colors.grey[400]),
      onSelected: (value) async {
        if (value == 'report') {
          final storyId = story['id'] is int ? story['id'] : int.parse(story['id'].toString());
          await ReportUtils.handleReportButtonTap(
            context: context,
            contentType: 'story',
            contentId: storyId,
          );
        } else if (value == 'block') {
          final userIdRaw = story['user_id'] ?? story['created_by'];
          if (userIdRaw != null) {
            final userId = userIdRaw is int ? userIdRaw : int.tryParse(userIdRaw.toString());
            if (userId == null) return;

            if (this.userId == userId) {
              _showCustomSnackbar(
                context,
                'Info',
                'You cannot block yourself',
              );
              return;
            }

            final userName = story['user_name'] ?? 'this poster';
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
                await UserBlockingService.blockUser(userId);
                if (mounted) {
                  _showCustomSnackbar(
                    context,
                    'Success',
                    'User blocked',
                  );
                  Navigator.of(context).pop(); // Back to list
                }
              } catch (e) {
                if (mounted) {
                  _showCustomSnackbar(
                    context,
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
        
        // Only show options if it's NOT the current user's story
        if (posterId != null && posterId != this.userId) {
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
