import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fruitsofspirit/controllers/group_posts_controller.dart';
import 'package:fruitsofspirit/controllers/groups_controller.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';
import 'package:fruitsofspirit/services/comments_service.dart';
import 'package:fruitsofspirit/widgets/cached_image.dart';
import 'package:fruitsofspirit/config/image_config.dart';
import 'package:fruitsofspirit/screens/home_screen.dart';
import 'package:fruitsofspirit/screens/real_group_chat_screen.dart';
import 'package:fruitsofspirit/services/group_posts_service.dart';
import 'dart:io';

/// Group Chat / Community Screen
/// Shows real-time chat messages (WhatsApp style) OR group posts (Facebook style)
class GroupChatScreen extends StatelessWidget {
  final int groupId;
  final bool useRealChat; // Toggle between real chat and posts
  
  const GroupChatScreen({
    Key? key,
    required this.groupId,
    this.useRealChat = true, // Default to real chat
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // If real chat is enabled, show WhatsApp-style chat
    if (useRealChat) {
      GroupsController groupsController;
      try {
        groupsController = Get.find<GroupsController>();
      } catch (e) {
        groupsController = Get.put(GroupsController());
      }
      
      final groupName = groupsController.selectedGroup['name'] as String? ?? 'Group Chat';
      
      return RealGroupChatScreen(
        groupId: groupId,
        groupName: groupName,
      );
    }
    
    // Otherwise show Facebook-style posts
    final postsController = Get.put(GroupPostsController());
    GroupsController groupsController;
    try {
      groupsController = Get.find<GroupsController>();
    } catch (e) {
      // Controller not found, create it
      groupsController = Get.put(GroupsController());
    }
    
    // Load posts on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      postsController.loadGroupPosts(groupId, refresh: true);
    });

    return Scaffold(
      backgroundColor: Colors.white,
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
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: ResponsiveHelper.isMobile(context) ? 4 : 8,
                offset: Offset(0, ResponsiveHelper.isMobile(context) ? 2 : 4),
              ),
            ],
            border: Border(
              bottom: BorderSide(
                color: Colors.grey.withOpacity(0.15),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left Side - Logo
                  Expanded(
                    flex: ResponsiveHelper.isDesktop(context) ? 4 : 3,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Obx(() {
                        final group = groupsController.selectedGroup;
                        return Text(
                          group['name'] as String? ?? 'Group Chat',
                          style: TextStyle(
                            fontSize: ResponsiveHelper.fontSize(context, mobile: 18),
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF5F4628),
                          ),
                        );
                      }),
                    ),
                  ),
                  SizedBox(
                    width: ResponsiveHelper.isMobile(context)
                        ? 12.0
                        : ResponsiveHelper.isTablet(context)
                            ? 16.0
                            : 20.0,
                  ),
                  // Right Side - Refresh and Back Button
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => postsController.refresh(),
                          borderRadius: BorderRadius.circular(30),
                          child: Container(
                            width: ResponsiveHelper.isMobile(context)
                                ? 40.0
                                : ResponsiveHelper.isTablet(context)
                                    ? 44.0
                                    : 48.0,
                            height: ResponsiveHelper.isMobile(context)
                                ? 40.0
                                : ResponsiveHelper.isTablet(context)
                                    ? 44.0
                                    : 48.0,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF8B4513),
                                  Color(0xFF6B3410),
                                ],
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.grey.withOpacity(0.2),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF8B4513).withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.refresh_rounded,
                              color: Colors.white,
                              size: ResponsiveHelper.isMobile(context)
                                  ? 20.0
                                  : ResponsiveHelper.isTablet(context)
                                      ? 22.0
                                      : 24.0,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: ResponsiveHelper.isMobile(context)
                            ? 10.0
                            : ResponsiveHelper.isTablet(context)
                                ? 12.0
                                : 14.0,
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          // Use Navigator pop to avoid GetX snackbar close crash on back
                          onTap: () {
                            Navigator.of(context).maybePop();
                          },
                          borderRadius: BorderRadius.circular(30),
                          child: Container(
                            width: ResponsiveHelper.isMobile(context)
                                ? 40.0
                                : ResponsiveHelper.isTablet(context)
                                    ? 44.0
                                    : 48.0,
                            height: ResponsiveHelper.isMobile(context)
                                ? 40.0
                                : ResponsiveHelper.isTablet(context)
                                    ? 44.0
                                    : 48.0,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF8B4513),
                                  Color(0xFF6B3410),
                                ],
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.grey.withOpacity(0.2),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF8B4513).withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.white,
                              size: ResponsiveHelper.isMobile(context)
                                  ? 20.0
                                  : ResponsiveHelper.isTablet(context)
                                      ? 22.0
                                      : 24.0,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Obx(() {
          if (postsController.isLoading.value && postsController.posts.isEmpty) {
            return Center(
              child: CircularProgressIndicator(
                color: const Color(0xFF8B4513),
              ),
            );
          }

          if (postsController.posts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: ResponsiveHelper.iconSize(context, mobile: 64),
                    color: Colors.grey,
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                  Text(
                    'No posts yet',
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(context, 8)),
                  Text(
                    'Be the first to share something!',
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => postsController.refresh(),
            color: const Color(0xFF8B4513),
            child: ListView.builder(
              padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 12)),
              itemCount: postsController.posts.length + (postsController.hasMore.value ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= postsController.posts.length) {
                  // Load more
                  postsController.loadMore();
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 16)),
                      child: CircularProgressIndicator(
                        color: const Color(0xFF8B4513),
                      ),
                    ),
                  );
                }
                
                return _buildPostCard(context, postsController, postsController.posts[index]);
              },
            ),
          );
        }),
      ),
      floatingActionButton: Obx(() {
        final isBlogger = postsController.userRole.value == 'Blogger';
        final isActive = postsController.userStatus.value == 'Active';
        final hasPendingRequest = postsController.userRole.value == 'Blogger' && 
                                  (postsController.userStatus.value == 'Inactive' || postsController.userStatus.value == 'Pending');
        
        // If user is approved Blogger, allow post creation
        if (isBlogger && isActive) {
          return FloatingActionButton(
            onPressed: () => _showCreatePostDialog(context, postsController),
            backgroundColor: const Color(0xFF8B4513),
            child: const Icon(Icons.add, color: Colors.white),
          );
        }
        
        // If user has pending request, show disabled button
        if (hasPendingRequest) {
          return FloatingActionButton(
            onPressed: () {
              Get.snackbar(
                'Approval Pending',
                'Waiting for approval from admin. You cannot create posts until your blogger request is approved.',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: Colors.orange.withOpacity(0.9),
                colorText: Colors.white,
                duration: const Duration(seconds: 3),
              );
            },
            backgroundColor: Colors.grey,
            child: const Icon(Icons.pending, color: Colors.white),
          );
        }
        
        // For regular users, show button with message
        return FloatingActionButton(
          onPressed: () {
            Get.snackbar(
              'Become a Blogger',
              'Please request to become a blogger to create posts.',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: const Color(0xFF8B4513).withOpacity(0.9),
              colorText: Colors.white,
              duration: const Duration(seconds: 3),
            );
          },
          backgroundColor: const Color(0xFF8B4513),
          child: const Icon(Icons.person_add, color: Colors.white),
        );
      }),
    );
  }

  Widget _buildPostCard(BuildContext context, GroupPostsController controller, Map<String, dynamic> post) {
    final baseUrl = 'https://fruitofthespirit.templateforwebsites.com/';
    String? userPhoto;
    if (post['profile_photo'] != null && post['profile_photo'].toString().isNotEmpty) {
      final photoPath = post['profile_photo'].toString();
      if (!photoPath.startsWith('http')) {
        userPhoto = baseUrl + (photoPath.startsWith('/') ? photoPath.substring(1) : photoPath);
      } else {
        userPhoto = photoPath;
      }
    }
    
    String? imageUrl;
    if (post['image_url'] != null && post['image_url'].toString().isNotEmpty) {
      final imgPath = post['image_url'].toString();
      if (!imgPath.startsWith('http')) {
        imageUrl = baseUrl + (imgPath.startsWith('/') ? imgPath.substring(1) : imgPath);
      } else {
        imageUrl = imgPath;
      }
    }
    
    final reactions = post['reactions'] as List<dynamic>? ?? [];
    final userReaction = post['user_reaction'] as String?;
    final postContent = post['content'] as String? ?? '';
    final postType = post['post_type'] as String? ?? 'text';
    final commentCount = int.tryParse((post['comment_count'] ?? 0).toString()) ?? 0;
    
    return Container(
      margin: EdgeInsets.only(bottom: ResponsiveHelper.spacing(context, 16)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey[200]!.withOpacity(0.5),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Info
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.transparent,
                  backgroundImage: userPhoto != null ? NetworkImage(userPhoto) : null,
                  child: userPhoto == null
                      ? Icon(
                          Icons.person_rounded,
                          size: 20,
                          color: const Color(0xFF5F4628),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post['user_name'] as String? ?? 'Anonymous',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        _formatDate(post['created_at'] as String?),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                // Post Type Badge - Only show if not 'text'
                if (postType != 'text' && postType.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF8B4513),
                          const Color(0xFF9F9467),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      postType.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Post Content - Only show if not empty
            if (postContent.isNotEmpty)
              Text(
                postContent,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  height: 1.5,
                ),
              ),
            
            // Post Image
            if (imageUrl != null && imageUrl.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedImage(
                  imageUrl: imageUrl,
                  width: double.infinity,
                  height: ResponsiveHelper.imageHeight(context, mobile: 200, tablet: 250, desktop: 300),
                  fit: BoxFit.cover,
                  errorWidget: Container(
                    height: ResponsiveHelper.imageHeight(context, mobile: 200, tablet: 250, desktop: 300),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFFFAF6EC),
                          const Color(0xFF9F9467).withOpacity(0.3),
                        ],
                      ),
                    ),
                    child: Icon(
                      Icons.broken_image,
                      color: Colors.grey[600],
                      size: ResponsiveHelper.iconSize(context, mobile: 40, tablet: 50, desktop: 60),
                    ),
                  ),
                ),
              ),
            ],
            
            // Event Date (if event post)
            if (post['post_type'] == 'event' && post['event_date'] != null) ...[
              SizedBox(height: ResponsiveHelper.spacing(context, 8)),
              Container(
                padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 8)),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF9E6),
                  borderRadius: BorderRadius.circular(
                    ResponsiveHelper.borderRadius(context, mobile: 8),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.event,
                      size: ResponsiveHelper.iconSize(context, mobile: 16),
                      color: const Color(0xFF8B4513),
                    ),
                    SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                    Text(
                      'Event: ${_formatDate(post['event_date'] as String?)}',
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                        color: const Color(0xFF8B4513),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            SizedBox(height: ResponsiveHelper.spacing(context, 12)),
            
            // Reactions Summary
            if (reactions.isNotEmpty) ...[
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveHelper.spacing(context, 8),
                  vertical: ResponsiveHelper.spacing(context, 4),
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(
                    ResponsiveHelper.borderRadius(context, mobile: 8),
                  ),
                ),
                child: Obx(() {
                  // Get available emojis from controller
                  final availableEmojis = controller.availableEmojis;
                  
                  return Wrap(
                    spacing: ResponsiveHelper.spacing(context, 8),
                    children: reactions.map<Widget>((reaction) {
                      final emojiCode = reaction['emoji_code'] as String? ?? '';
                      final count = reaction['count'] as int? ?? 0;
                      
                      // Find matching emoji in available emojis
                      Map<String, dynamic>? fruitEmoji;
                      for (var emoji in availableEmojis) {
                        final emojiChar = emoji['emoji_char'] as String? ?? '';
                        final code = emoji['code'] as String? ?? '';
                        if (emojiChar == emojiCode || code == emojiCode) {
                          fruitEmoji = emoji;
                          break;
                        }
                      }
                      
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (fruitEmoji != null)
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: HomeScreen.buildEmojiDisplay(
                                context,
                                fruitEmoji,
                                size: 20,
                              ),
                            )
                          else
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Icon(
                                Icons.sentiment_satisfied,
                                size: 14,
                                color: Colors.grey[400],
                              ),
                            ),
                          SizedBox(width: 4),
                          Text(
                            '$count',
                            style: ResponsiveHelper.textStyle(
                              context,
                              fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  );
                }),
              ),
              SizedBox(height: ResponsiveHelper.spacing(context, 8)),
            ],
            
            const SizedBox(height: 12),
            
            // Reactions Summary - Only show if reactions exist
            if (reactions.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Obx(() {
                  // Get available emojis from controller
                  final availableEmojis = controller.availableEmojis;
                  
                  return Wrap(
                    spacing: 8,
                    children: reactions.map<Widget>((reaction) {
                      final emojiCode = reaction['emoji_code'] as String? ?? '';
                      final count = reaction['count'] as int? ?? 0;
                      if (count > 0) {
                        // Find matching emoji in available emojis
                        Map<String, dynamic>? fruitEmoji;
                        for (var emoji in availableEmojis) {
                          final emojiChar = emoji['emoji_char'] as String? ?? '';
                          final code = emoji['code'] as String? ?? '';
                          if (emojiChar == emojiCode || code == emojiCode) {
                            fruitEmoji = emoji;
                            break;
                          }
                        }
                        
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (fruitEmoji != null)
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: HomeScreen.buildEmojiDisplay(
                                  context,
                                  fruitEmoji,
                                  size: 18,
                                ),
                              )
                            else
                              Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Icon(
                                  Icons.sentiment_satisfied,
                                  size: 12,
                                  color: Colors.grey[400],
                                ),
                              ),
                            SizedBox(width: 4),
                            Text(
                              '$count',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        );
                      }
                      return const SizedBox.shrink();
                    }).toList(),
                  );
                }),
              ),
              const SizedBox(height: 10),
              
              // "Who Reacted" Section - Show users who reacted
              FutureBuilder<List<Map<String, dynamic>>>(
                future: GroupPostsService.getPostReactions(post['id'] as int),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox.shrink();
                  }
                  
                  if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  
                  final allReactions = snapshot.data!;
                  // Take first 5 users
                  final usersToShow = allReactions.take(5).toList();
                  final totalUsers = allReactions.length;
                  
                  return Container(
                    padding: ResponsiveHelper.padding(context, all: 12),
                    margin: EdgeInsets.only(top: ResponsiveHelper.spacing(context, 8)),
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
                              color: const Color(0xFF8B4513),
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
                        ...usersToShow.map((reactionData) {
                          final userName = reactionData['user_name'] as String? ?? 'Anonymous';
                          final profilePhoto = reactionData['profile_photo'] as String?;
                          final emojiCode = reactionData['emoji_code'] as String? ?? reactionData['emoji_char'] as String? ?? '';
                          String? profilePhotoUrl;
                          
                          if (profilePhoto != null && profilePhoto.toString().isNotEmpty) {
                            final photoPath = profilePhoto.toString();
                            if (!photoPath.startsWith('http')) {
                              profilePhotoUrl = 'https://fruitofthespirit.templateforwebsites.com/$photoPath';
                            } else {
                              profilePhotoUrl = photoPath;
                            }
                          }
                          
                          // Find fruit emoji
                          Map<String, dynamic>? fruitEmoji;
                          for (var emoji in controller.availableEmojis) {
                            final emojiChar = emoji['emoji_char'] as String? ?? '';
                            final code = emoji['code'] as String? ?? '';
                            if (emojiChar == emojiCode || code == emojiCode) {
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
                                          color: const Color(0xFF2C2C2C),
                                        ),
                                      ),
                                      Text(
                                        _getTimeAgo(reactionData['created_at'] as String?),
                                        style: TextStyle(
                                          fontSize: ResponsiveHelper.fontSize(context, mobile: 11),
                                          color: Colors.grey[600],
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
                                      color: Colors.grey[400],
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                        // Show "and X more" if there are more than 5 users
                        if (totalUsers > 5)
                          GestureDetector(
                            onTap: () {
                              _showGroupPostReactionsDialog(context, controller, post['id'] as int, allReactions);
                            },
                            child: Padding(
                              padding: EdgeInsets.only(top: ResponsiveHelper.spacing(context, 4)),
                              child: Row(
                                children: [
                                  Text(
                                    'and ${totalUsers - 5} more',
                                    style: TextStyle(
                                      fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                                      color: const Color(0xFF8B4513),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    size: ResponsiveHelper.fontSize(context, mobile: 12),
                                    color: const Color(0xFF8B4513),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
            
            // Action Buttons
            Row(
              children: [
                // React Button
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _showReactionPicker(context, controller, post['id'] as int),
                    icon: Icon(
                      userReaction != null ? Icons.favorite : Icons.favorite_border,
                      size: 18,
                      color: userReaction != null ? Colors.red : const Color(0xFF8B4513),
                    ),
                    label: const Text(
                      'React',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF8B4513),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                // Comment Button - Only show count if > 0
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _showCommentsDialog(context, controller, post),
                    icon: Icon(
                      Icons.comment_outlined,
                      size: 18,
                      color: const Color(0xFF8B4513),
                    ),
                    label: Text(
                      commentCount > 0 ? 'Comment ($commentCount)' : 'Comment',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF8B4513),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCreatePostDialog(BuildContext context, GroupPostsController controller) {
    final contentController = TextEditingController();
    String selectedType = 'text';
    File? selectedImage;
    final eventDateController = TextEditingController();

    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 16)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(
              ResponsiveHelper.borderRadius(context, mobile: 16),
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create Post',
                  style: ResponsiveHelper.textStyle(
                    context,
                    fontSize: ResponsiveHelper.fontSize(context, mobile: 20),
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF8B4513),
                  ),
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                
                // Post Type
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: InputDecoration(
                    labelText: 'Post Type',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        ResponsiveHelper.borderRadius(context, mobile: 8),
                      ),
                    ),
                  ),
                  items: ['text', 'prayer', 'event', 'update'].map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type.toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (value) {
                    selectedType = value ?? 'text';
                  },
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, 12)),
                
                // Content
                TextField(
                  controller: contentController,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: 'What\'s on your mind?',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        ResponsiveHelper.borderRadius(context, mobile: 8),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, 12)),
                
                // Image Picker
                if (selectedImage == null)
                  ElevatedButton.icon(
                    onPressed: () async {
                      final picker = ImagePicker();
                      final image = await picker.pickImage(source: ImageSource.gallery);
                      if (image != null) {
                        selectedImage = File(image.path);
                        Get.back();
                        _showCreatePostDialog(context, controller);
                      }
                    },
                    icon: const Icon(Icons.image),
                    label: const Text('Add Image'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B4513),
                    ),
                  )
                else
                  Stack(
                    children: [
                      Image.file(
                        selectedImage!,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            selectedImage = null;
                            Get.back();
                            _showCreatePostDialog(context, controller);
                          },
                        ),
                      ),
                    ],
                  ),
                
                // Event Date (if event)
                if (selectedType == 'event') ...[
                  SizedBox(height: ResponsiveHelper.spacing(context, 12)),
                  TextField(
                    controller: eventDateController,
                    decoration: InputDecoration(
                      labelText: 'Event Date (YYYY-MM-DD HH:MM)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          ResponsiveHelper.borderRadius(context, mobile: 8),
                        ),
                      ),
                    ),
                  ),
                ],
                
                SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                
                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Get.back(),
                      child: const Text('Cancel'),
                    ),
                    SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                    ElevatedButton(
                      onPressed: controller.isLoading.value
                          ? null
                          : () async {
                              if (contentController.text.trim().isEmpty) {
                                Get.snackbar(
                                  'Error',
                                  'Please enter post content',
                                  backgroundColor: Colors.red,
                                  colorText: Colors.white,
                                );
                                return;
                              }
                              
                              final success = await controller.createPost(
                                groupId: groupId,
                                content: contentController.text.trim(),
                                postType: selectedType,
                                image: selectedImage,
                                eventDate: selectedType == 'event' && eventDateController.text.isNotEmpty
                                    ? eventDateController.text.trim()
                                    : null,
                              );
                              
                              if (success) {
                                // Show success message FIRST (before navigation)
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  Get.snackbar(
                                    'Success',
                                    controller.message.value.isNotEmpty 
                                        ? controller.message.value 
                                        : 'Post created successfully!',
                                    backgroundColor: Colors.green,
                                    colorText: Colors.white,
                                    duration: const Duration(seconds: 2),
                                    margin: const EdgeInsets.all(16),
                                  );
                                });
                                
                                // Wait a bit for snackbar to show, then navigate
                                await Future.delayed(const Duration(milliseconds: 500));
                                
                                // Navigate back
                                if (Navigator.canPop(context)) {
                                  Get.back();
                                }
                              } else {
                                // Show error message
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  Get.snackbar(
                                    'Error',
                                    controller.message.value.isNotEmpty 
                                        ? controller.message.value 
                                        : 'Failed to create post. Please try again.',
                                    backgroundColor: Colors.red,
                                    colorText: Colors.white,
                                    duration: const Duration(seconds: 3),
                                    margin: const EdgeInsets.all(16),
                                  );
                                });
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B4513),
                      ),
                      child: controller.isLoading.value
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Post'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showReactionPicker(BuildContext context, GroupPostsController controller, int postId) {
    Get.bottomSheet(
      Container(
        padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 16)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(ResponsiveHelper.borderRadius(context, mobile: 20)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose Reaction',
              style: ResponsiveHelper.textStyle(
                context,
                fontSize: ResponsiveHelper.fontSize(context, mobile: 18),
                fontWeight: FontWeight.bold,
                color: const Color(0xFF8B4513),
              ),
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 16)),
            Obx(() {
              if (controller.availableEmojis.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              
              return Wrap(
                spacing: ResponsiveHelper.spacing(context, 12),
                runSpacing: ResponsiveHelper.spacing(context, 12),
                children: controller.availableEmojis.take(10).map((emoji) {
                  // Use emoji_char or code for API, but display fruit image
                  final emojiCode = emoji['emoji_char'] as String? ?? emoji['code'] as String? ?? emoji['name'] as String? ?? '';
                  return InkWell(
                    onTap: () async {
                      final success = await controller.reactToPost(postId, emojiCode);
                      if (success) {
                        // Show success message (brief)
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          Get.snackbar(
                            'Success',
                            'Reaction added',
                            backgroundColor: Colors.green,
                            colorText: Colors.white,
                            duration: const Duration(seconds: 1),
                            margin: const EdgeInsets.all(16),
                          );
                        });
                      } else {
                        // Show error message
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          Get.snackbar(
                            'Error',
                            controller.message.value.isNotEmpty 
                                ? controller.message.value 
                                : 'Failed to add reaction. Please try again.',
                            backgroundColor: Colors.red,
                            colorText: Colors.white,
                            duration: const Duration(seconds: 2),
                            margin: const EdgeInsets.all(16),
                          );
                        });
                      }
                      // Wait a bit for snackbar to show, then close dialog
                      await Future.delayed(const Duration(milliseconds: 300));
                      if (Navigator.canPop(context)) {
                        Get.back();
                      }
                    },
                    child: Container(
                      padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 12)),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEECE2),
                        borderRadius: BorderRadius.circular(
                          ResponsiveHelper.borderRadius(context, mobile: 8),
                        ),
                      ),
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: HomeScreen.buildEmojiDisplay(
                          context,
                          emoji,
                          size: 32,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            }),
            SizedBox(height: ResponsiveHelper.spacing(context, 16)),
          ],
        ),
      ),
    );
  }

  /// Format time ago
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

  /// Show group post reactions dialog
  void _showGroupPostReactionsDialog(BuildContext context, GroupPostsController controller, int postId, List<Map<String, dynamic>> allReactions) {
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
                  Icon(
                    Icons.people_rounded,
                    size: ResponsiveHelper.fontSize(context, mobile: 24),
                    color: const Color(0xFF8B4513),
                  ),
                  SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${allReactions.length} ${allReactions.length == 1 ? 'Person' : 'People'} Reacted',
                          style: TextStyle(
                            fontSize: ResponsiveHelper.fontSize(context, mobile: 18),
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2C2C2C),
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
                  itemCount: allReactions.length,
                  itemBuilder: (context, index) {
                    final reaction = allReactions[index];
                    final userName = reaction['user_name'] as String? ?? 'Anonymous';
                    final profilePhoto = reaction['profile_photo'] as String?;
                    final emojiCode = reaction['emoji_code'] as String? ?? reaction['emoji_char'] as String? ?? '';
                    String? profilePhotoUrl;
                    
                    if (profilePhoto != null && profilePhoto.toString().isNotEmpty) {
                      final photoPath = profilePhoto.toString();
                      if (!photoPath.startsWith('http')) {
                        profilePhotoUrl = 'https://fruitofthespirit.templateforwebsites.com/$photoPath';
                      } else {
                        profilePhotoUrl = photoPath;
                      }
                    }
                    
                    // Find fruit emoji
                    Map<String, dynamic>? fruitEmoji;
                    for (var emoji in controller.availableEmojis) {
                      final emojiChar = emoji['emoji_char'] as String? ?? '';
                      final code = emoji['code'] as String? ?? '';
                      if (emojiChar == emojiCode || code == emojiCode) {
                        fruitEmoji = emoji;
                        break;
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
                          color: const Color(0xFF2C2C2C),
                        ),
                      ),
                      subtitle: Text(
                        _getTimeAgo(reaction['created_at'] as String?),
                        style: TextStyle(
                          fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                          color: Colors.grey[600],
                        ),
                      ),
                      trailing: fruitEmoji != null
                          ? SizedBox(
                              width: 24,
                              height: 24,
                              child: HomeScreen.buildEmojiDisplay(
                                context,
                                fruitEmoji,
                                size: 24,
                              ),
                            )
                          : Icon(
                              Icons.sentiment_satisfied,
                              size: 20,
                              color: Colors.grey[400],
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

  void _showCommentsDialog(BuildContext context, GroupPostsController controller, Map<String, dynamic> post) {
    final postId = post['id'] as int;
    final commentController = TextEditingController();
    
    // Load comments
    controller.loadPostComments(postId);
    
    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 16)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(
              ResponsiveHelper.borderRadius(context, mobile: 16),
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Comments',
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: ResponsiveHelper.fontSize(context, mobile: 20),
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF8B4513),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Get.back(),
                  ),
                ],
              ),
              Divider(),
              Expanded(
                child: Obx(() {
                  if (controller.postComments.isEmpty) {
                    return Center(
                      child: Text(
                        'No comments yet',
                        style: ResponsiveHelper.textStyle(
                          context,
                          fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                          color: Colors.grey,
                        ),
                      ),
                    );
                  }
                  
                  return ListView.builder(
                    itemCount: controller.postComments.length,
                    itemBuilder: (context, index) {
                      final comment = controller.postComments[index];
                      return _buildCommentItem(context, controller, comment, postId);
                    },
                  );
                }),
              ),
              Divider(),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: commentController,
                      decoration: InputDecoration(
                        hintText: 'Write a comment...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            ResponsiveHelper.borderRadius(context, mobile: 20),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                  IconButton(
                    icon: const Icon(Icons.send, color: Color(0xFF8B4513)),
                    onPressed: () async {
                      if (commentController.text.trim().isEmpty) return;
                      
                      final success = await controller.addComment(
                        postId,
                        commentController.text.trim(),
                      );
                      
                      if (success) {
                        commentController.clear();
                        // Show success message
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          Get.snackbar(
                            'Success',
                            'Comment added successfully',
                            backgroundColor: Colors.green,
                            colorText: Colors.white,
                            duration: const Duration(seconds: 2),
                            margin: const EdgeInsets.all(16),
                          );
                        });
                      } else {
                        // Show error message
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          Get.snackbar(
                            'Error',
                            controller.message.value.isNotEmpty 
                                ? controller.message.value 
                                : 'Failed to add comment. Please try again.',
                            backgroundColor: Colors.red,
                            colorText: Colors.white,
                            duration: const Duration(seconds: 3),
                            margin: const EdgeInsets.all(16),
                          );
                        });
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommentItem(BuildContext context, GroupPostsController controller, Map<String, dynamic> comment, int postId) {
    final baseUrl = 'https://fruitofthespirit.templateforwebsites.com/';
    final userPhoto = comment['profile_photo'] != null
        ? baseUrl + (comment['profile_photo'] as String)
        : null;
    final replies = comment['replies'] as List<dynamic>? ?? [];
    
    return Padding(
      padding: EdgeInsets.only(bottom: ResponsiveHelper.spacing(context, 12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: ResponsiveHelper.borderRadius(context, mobile: 16),
                backgroundColor: const Color(0xFFFEECE2),
                backgroundImage: userPhoto != null ? NetworkImage(userPhoto) : null,
                child: userPhoto == null
                    ? Icon(
                        Icons.person,
                        size: ResponsiveHelper.iconSize(context, mobile: 16),
                        color: const Color(0xFF8B4513),
                      )
                    : null,
              ),
              SizedBox(width: ResponsiveHelper.spacing(context, 8)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment['user_name'] as String? ?? 'Anonymous',
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF8B4513),
                      ),
                    ),
                    Text(
                      comment['content'] as String? ?? '',
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: ResponsiveHelper.fontSize(context, mobile: 13),
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(context, 4)),
                    Text(
                      _formatDate(comment['created_at'] as String?),
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: ResponsiveHelper.fontSize(context, mobile: 11),
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Replies
          if (replies.isNotEmpty) ...[
            SizedBox(height: ResponsiveHelper.spacing(context, 8)),
            Padding(
              padding: EdgeInsets.only(left: ResponsiveHelper.spacing(context, 40)),
              child: Column(
                children: replies.map((reply) => _buildCommentItem(context, controller, reply, postId)).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays > 7) {
        return '${date.day}/${date.month}/${date.year}';
      } else if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return dateStr;
    }
  }
}

