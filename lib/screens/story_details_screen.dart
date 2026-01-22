import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
import 'package:fruitsofspirit/screens/report_content_screen.dart';

/// Story Details Screen - Modern Social Media Style
class StoryDetailsScreen extends StatefulWidget {
  const StoryDetailsScreen({Key? key}) : super(key: key);

  @override
  State<StoryDetailsScreen> createState() => _StoryDetailsScreenState();
}

class _StoryDetailsScreenState extends State<StoryDetailsScreen> {
  var isLoading = false;
  var story = <String, dynamic>{};
  var comments = <Map<String, dynamic>>[];
  var storyEmojiReactions = <String, List<Map<String, dynamic>>>{}; // emoji -> list of users who reacted
  var availableEmojis = <Map<String, dynamic>>[];
  var quickEmojis = <Map<String, dynamic>>[];
  var userId = 0;
  final commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final replyControllers = <int, TextEditingController>{};
  final showReplyInput = <int, bool>{};
  final expandedReplies = <int>{}; // Track which replies are expanded

  @override
  void initState() {
    super.initState();
    _loadUserId();
    final storyId = Get.arguments as int? ?? 0;
    if (storyId > 0) {
      _loadStoryDetails(storyId);
    }
  }

  @override
  void dispose() {
    commentController.dispose();
    _scrollController.dispose();
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
      Get.snackbar('Login Required', 'Please login to react', backgroundColor: Colors.orange);
      return;
    }
    try {
      await EmojisService.useEmoji(
        userId: userId,
        emoji: emoji,
        postType: 'story',
        postId: storyId,
      );
      await _loadComments(storyId);
      Get.snackbar('Success', 'Reaction added', backgroundColor: Colors.green, colorText: Colors.white, duration: const Duration(seconds: 1));
    } catch (e) {
      Get.snackbar('Error', 'Failed to add reaction: ${e.toString()}', backgroundColor: Colors.red);
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
      Get.snackbar(
        'Error',
        e.toString().replaceAll('Exception: ', ''),
        backgroundColor: Colors.red,
        colorText: Colors.white,
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
        
        if (isEmojiReaction && emojiKey != null) {
          // It's an emoji reaction
          if (!emojiReactions.containsKey(emojiKey)) {
            emojiReactions[emojiKey] = [];
          }
          emojiReactions[emojiKey]!.add({
            'user_id': comment['user_id'],
            'user_name': comment['user_name'] ?? 'Anonymous',
            'profile_photo': comment['profile_photo'],
            'created_at': comment['created_at'],
          });
        } else {
          // It's a text comment
          textComments.add(comment);
        }
      }
      
      print('✅ Flattened to ${textComments.length} text comments and ${emojiReactions.length} emoji reaction types');
      
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
      Get.snackbar(
        'Login Required',
        'Please login to comment',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange.withOpacity(0.8),
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    final text = parentCommentId != null 
        ? (replyControllers[parentCommentId]?.text.trim() ?? '')
        : commentController.text.trim();
    
    if (text.isEmpty) return;

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
      Get.snackbar(
        'Success',
        parentCommentId != null ? 'Reply added successfully' : 'Comment added successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.withOpacity(0.8),
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
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
      Get.snackbar(
        'Error',
        e.toString().replaceAll('Exception: ', ''),
        backgroundColor: Colors.red,
        colorText: Colors.white,
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
      Get.snackbar(
        'Login Required',
        'Please login to like comments',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange.withOpacity(0.8),
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
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
      Get.snackbar(
        'Error',
        e.toString().replaceAll('Exception: ', ''),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  String _getTimeAgo(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '';
    
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays > 365) {
        final years = (difference.inDays / 365).floor();
        return '$years ${years == 1 ? 'year' : 'years'} ago';
      } else if (difference.inDays > 30) {
        final months = (difference.inDays / 30).floor();
        return '$months ${months == 1 ? 'month' : 'months'} ago';
      } else if (difference.inDays > 0) {
        return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseUrl = 'https://fruitofthespirit.templateforwebsites.com/';
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
              onPressed: () => Get.back(),
            ),
          ),
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
                                                        _getTimeAgo(story['created_at'] as String?),
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
                                          Padding(
                                            padding: EdgeInsets.only(
                                              bottom: ResponsiveHelper.spacing(context, 8),
                                            ),
                                            child: Text(
                                              story['title'] as String,
                                              style: ResponsiveHelper.textStyle(
                                                context,
                                                fontSize: ResponsiveHelper.fontSize(
                                                  context,
                                                  mobile: 20,
                                                ),
                                                fontWeight: FontWeight.bold,
                                                color: const Color(0xFF5F4628),
                                              ),
                                            ),
                                          ),
                                        
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
                                      prefixIcon: IconButton(
                                        icon: const Icon(
                                          Icons.emoji_emotions_outlined,
                                          color: Color(0xFF8B4513),
                                        ),
                                        onPressed: () => _showEmojiPicker(context, story['id'] as int),
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
                                _getTimeAgo(comment['created_at'] as String?),
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
                                showReplyInput[commentId] = !(showReplyInput[commentId] ?? false);
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
                  onTap: () => _showEmojiPicker(context, storyId),
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
                    Get.dialog(
                      Dialog(
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
                                      child: HomeScreen.buildEmojiDisplay(context, fruitEmoji!, size: 32),
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
                                                  : 'https://fruitofthespirit.templateforwebsites.com/${user['profile_photo']}'
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
                                onPressed: () => Get.back(),
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

  /// Show Emoji Picker Dialog
  void _showEmojiPicker(BuildContext context, int storyId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Choose an Emoji',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF5F4628)),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF5F4628)),
                  onPressed: () => Get.back(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: availableEmojis.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1,
                      ),
                      itemCount: availableEmojis.length,
                      itemBuilder: (context, index) {
                        final emojiData = availableEmojis[index];
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
                              if (parts.length > 1) baseName = parts[1].trim();
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
                              Get.back();
                              await _addEmojiReaction(storyId, emoji!);
                            } : null,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: HomeScreen.buildEmojiDisplay(context, emojiData, size: 48),
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
                onTap: () {
                  Navigator.pop(context);
                  final commentId = comment['id'] is int ? comment['id'] : int.parse(comment['id'].toString());
                  Get.to(() => ReportContentScreen(
                        contentType: 'story_comment',
                        contentId: commentId,
                      ));
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
                    final confirmed = await Get.dialog<bool>(
                      AlertDialog(
                        title: Text('Block $userName?'),
                        content: const Text('You will no longer see content from this user.'),
                        actions: [
                          TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancel')),
                          TextButton(
                              onPressed: () => Get.back(result: true),
                              child: const Text('Block', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );

                    if (confirmed == true) {
                      try {
                        await UserBlockingService.blockUser(userId);
                        Get.snackbar('Success', 'User blocked');
                        _loadComments(story['id'] as int);
                      } catch (e) {
                        Get.snackbar('Error', 'Failed to block user');
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
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: Colors.grey[400]),
      onSelected: (value) async {
        if (value == 'report') {
          final storyId = story['id'] is int ? story['id'] : int.parse(story['id'].toString());
          Get.to(() => ReportContentScreen(
                contentType: 'story',
                contentId: storyId,
              ));
        } else if (value == 'block') {
          final userIdRaw = story['user_id'] ?? story['created_by'];
          if (userIdRaw != null) {
            final userId = userIdRaw is int ? userIdRaw : int.tryParse(userIdRaw.toString());
            if (userId == null) return;

            if (this.userId == userId) {
              Get.snackbar('Info', 'You cannot block yourself');
              return;
            }

            final userName = story['user_name'] ?? 'this poster';
            final confirmed = await Get.dialog<bool>(
              AlertDialog(
                title: Text('Block $userName?'),
                content: const Text('You will no longer see content from this user.'),
                actions: [
                  TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancel')),
                  TextButton(
                      onPressed: () => Get.back(result: true),
                      child: const Text('Block', style: TextStyle(color: Colors.red))),
                ],
              ),
            );

            if (confirmed == true) {
              try {
                await UserBlockingService.blockUser(userId);
                Get.snackbar('Success', 'User blocked');
                Get.back(); // Back to list
              } catch (e) {
                Get.snackbar('Error', 'Failed to block user');
              }
            }
          }
        }
      },
      itemBuilder: (context) {
        final List<PopupMenuEntry<String>> items = [];
        
        final userIdRaw = story['user_id'] ?? story['created_by'];
        final posterId = userIdRaw is int ? userIdRaw : int.tryParse(userIdRaw?.toString() ?? '');
        
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

