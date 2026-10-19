import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fruitsofspirit/controllers/group_posts_controller.dart';
import 'package:fruitsofspirit/controllers/home_controller.dart';
import 'package:fruitsofspirit/services/comments_service.dart';
import 'package:fruitsofspirit/utils/app_theme.dart';
import 'package:fruitsofspirit/utils/content_delete_helper.dart';
import 'package:fruitsofspirit/utils/image_helper.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';
import 'package:fruitsofspirit/utils/time_helper.dart';
import 'package:fruitsofspirit/widgets/cached_image.dart';
import 'package:fruitsofspirit/screens/group_post_details_screen.dart';

class GroupPostsScreen extends StatefulWidget {
  final int groupId;
  final String groupName;

  const GroupPostsScreen({
    Key? key,
    required this.groupId,
    required this.groupName,
  }) : super(key: key);

  @override
  State<GroupPostsScreen> createState() => _GroupPostsScreenState();
}

class _GroupPostsScreenState extends State<GroupPostsScreen> {
  final GroupPostsController controller = Get.find<GroupPostsController>();
  final Map<int, TextEditingController> _commentControllers = {};
  int? _expandedPostId;
  final Map<int, List<Map<String, dynamic>>> _postComments = {};
  final TextEditingController _newPostController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.bootstrapGroupPosts(widget.groupId);
      if (Get.isRegistered<HomeController>()) {
        controller.seedFromHomeIfEmpty(
          widget.groupId,
          Get.find<HomeController>().groupPosts.toList(),
        );
      }
      if (controller.posts.isNotEmpty) {
        unawaited(
          controller.loadGroupPosts(
            widget.groupId,
            refresh: true,
            silent: true,
          ),
        );
      } else {
        unawaited(controller.loadGroupPosts(widget.groupId, refresh: true));
      }
    });
  }

  @override
  void dispose() {
    _newPostController.dispose();
    for (final c in _commentControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _deletePost(int postId) async {
    if (controller.userId.value == 0) {
      _showSnack('Please login first', isError: true);
      return;
    }
    final confirmed = await ContentDeleteHelper.confirmDelete(context, itemLabel: 'post');
    if (!confirmed) return;

    try {
      await controller.deletePost(postId);
      setState(() {
        _postComments.remove(postId);
        if (_expandedPostId == postId) _expandedPostId = null;
      });
      _showSnack('Post deleted successfully');
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''), isError: true);
    }
  }

  Future<void> _deleteComment(int commentId, int postId) async {
    if (controller.userId.value == 0) return;
    final confirmed = await ContentDeleteHelper.confirmDelete(context, itemLabel: 'comment');
    if (!confirmed) return;

    try {
      await CommentsService.deleteComment(
        userId: controller.userId.value,
        commentId: commentId,
        postType: 'group_post',
      );
      final comments = await CommentsService.getComments(
        postType: 'group_post',
        postId: postId,
        userId: controller.userId.value > 0 ? controller.userId.value : null,
      );
      setState(() => _postComments[postId] = comments);
      _showSnack('Comment deleted successfully');
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''), isError: true);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showCreatePostSheet() async {
    _newPostController.clear();
    String postType = 'text';
    File? selectedImage;
    DateTime? eventDate;
    final picker = ImagePicker();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Create Group Post',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Share text, photo, prayer, event or update with your group',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: postType,
                    decoration: const InputDecoration(
                      labelText: 'Post type',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'text', child: Text('Text')),
                      DropdownMenuItem(value: 'prayer', child: Text('Prayer')),
                      DropdownMenuItem(value: 'event', child: Text('Event')),
                      DropdownMenuItem(value: 'update', child: Text('Update')),
                    ],
                    onChanged: (value) {
                      if (value != null) setSheetState(() => postType = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _newPostController,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: postType == 'prayer' ? 'Prayer request' : 'What\'s on your mind?',
                      hintText: 'Write your post...',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  if (postType == 'event') ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) setSheetState(() => eventDate = picked);
                      },
                      icon: const Icon(Icons.event),
                      label: Text(
                        eventDate == null
                            ? 'Select event date'
                            : 'Event: ${eventDate!.toLocal().toString().split(' ').first}',
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          final image = await picker.pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 85,
                          );
                          if (image != null) {
                            setSheetState(() => selectedImage = File(image.path));
                          }
                        },
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Add photo'),
                      ),
                      if (selectedImage != null) ...[
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => setSheetState(() => selectedImage = null),
                          child: const Text('Remove', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ],
                  ),
                  if (selectedImage != null) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(selectedImage!, height: 120, width: double.infinity, fit: BoxFit.cover),
                    ),
                  ],
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                    onPressed: () async {
                      final content = _newPostController.text.trim();
                      if (content.isEmpty && selectedImage == null) {
                        _showSnack('Add text or a photo', isError: true);
                        return;
                      }
                      Navigator.pop(sheetContext);
                      final success = await controller.createPost(
                        groupId: widget.groupId,
                        content: content.isEmpty ? '📷 Photo post' : content,
                        postType: postType,
                        image: selectedImage,
                        eventDate: eventDate?.toIso8601String().split('T').first,
                      );
                      if (success) {
                        _showSnack('Post created successfully');
                      } else if (controller.message.value.isNotEmpty) {
                        _showSnack(controller.message.value, isError: true);
                      }
                    },
                    child: const Text('Post', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _toggleComments(int postId) async {
    if (_expandedPostId == postId) {
      setState(() => _expandedPostId = null);
      return;
    }

    setState(() => _expandedPostId = postId);

    if (!_postComments.containsKey(postId)) {
      final comments = await CommentsService.getComments(
        postType: 'group_post',
        postId: postId,
        userId: controller.userId.value > 0 ? controller.userId.value : null,
      );
      if (mounted) {
        setState(() => _postComments[postId] = comments);
      }
    }
  }

  Future<void> _addComment(int postId) async {
    final textController = _commentControllers.putIfAbsent(postId, TextEditingController.new);
    final content = textController.text.trim();
    if (content.isEmpty) return;

    final success = await controller.addComment(postId, content);
    if (success) {
      textController.clear();
      final comments = await CommentsService.getComments(
        postType: 'group_post',
        postId: postId,
        userId: controller.userId.value > 0 ? controller.userId.value : null,
      );
      setState(() => _postComments[postId] = comments);
      _showSnack('Comment added');
    } else if (controller.message.value.isNotEmpty) {
      _showSnack(controller.message.value, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.themeColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.primaryColor,
        elevation: 0.5,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.groupName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF5F4628)),
            ),
            const Text('Group Posts', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryColor,
        onPressed: _showCreatePostSheet,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.posts.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
        }

        if (controller.posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.feed_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text('No posts yet', style: TextStyle(color: Colors.grey[600])),
                const SizedBox(height: 8),
                const Text('Tap + to create the first post', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: AppTheme.primaryColor,
          onRefresh: () => controller.loadGroupPosts(
            widget.groupId,
            refresh: true,
            force: true,
          ),
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: controller.posts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _buildPostCard(controller.posts[index]),
          ),
        );
      }),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    final postId = post['id'] as int;
    final isOwner = ContentDeleteHelper.isOwner(controller.userId.value, post['user_id']);
    final profileUrl = ImageHelper.getProfilePhotoUrl(post['profile_photo'] as String?);
    final imagePath = post['image_path'] as String?;
    final imageUrl = imagePath != null && imagePath.isNotEmpty
        ? (imagePath.startsWith('http') ? imagePath : 'http://admin.fosmessenger.com/$imagePath')
        : null;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GroupPostDetailsScreen(
              post: post,
              groupId: widget.groupId,
              groupName: widget.groupName,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
      decoration: AppTheme.cardDecoration(),
      padding: ResponsiveHelper.padding(context, horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage: profileUrl != null ? NetworkImage(profileUrl) : null,
                child: profileUrl == null ? const Icon(Icons.person, size: 18) : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post['user_name'] as String? ?? 'User',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    Text(
                      TimeHelper.getTimeAgo(post['created_at'] as String?),
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              if (isOwner)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'delete') _deletePost(postId);
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Text('Delete Post', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if ((post['post_type'] as String?)?.isNotEmpty == true &&
              (post['post_type'] as String?) != 'text') ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                (post['post_type'] as String).toUpperCase(),
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
              ),
            ),
          ],
          if (post['event_date'] != null && post['event_date'].toString().isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.event, size: 14, color: Colors.grey[700]),
                const SizedBox(width: 4),
                Text(
                  'Event: ${post['event_date']}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ),
          ],
          if ((post['title'] as String?)?.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Text(
              post['title'] as String,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ],
          if ((post['content'] as String?)?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(post['content'] as String, style: const TextStyle(fontSize: 14, height: 1.4)),
          ],
          if (imageUrl != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedImage(imageUrl: imageUrl, height: 180, width: double.infinity, fit: BoxFit.cover),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.favorite_border, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text('${post['reaction_count'] ?? 0}', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
              const SizedBox(width: 16),
              InkWell(
                onTap: () => _toggleComments(postId),
                child: Row(
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text('${post['comment_count'] ?? 0}', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                  ],
                ),
              ),
            ],
          ),
          if (_expandedPostId == postId) ...[
            const Divider(height: 20),
            ...(_postComments[postId] ?? []).map((comment) => _buildCommentTile(comment, postId)),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentControllers.putIfAbsent(postId, TextEditingController.new),
                    decoration: const InputDecoration(
                      hintText: 'Write a comment...',
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: AppTheme.primaryColor),
                  onPressed: () => _addComment(postId),
                ),
              ],
            ),
          ],
        ],
      ),
    ),
    );
  }

  Widget _buildCommentTile(Map<String, dynamic> comment, int postId) {
    final isOwner = ContentDeleteHelper.isOwner(controller.userId.value, comment['user_id']);
    final content = (comment['comment'] as String?) ?? (comment['content'] as String?) ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black87, fontSize: 13),
                children: [
                  TextSpan(
                    text: '${comment['user_name'] ?? 'User'}: ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: content),
                ],
              ),
            ),
          ),
          if (isOwner)
            InkWell(
              onTap: () => _deleteComment(comment['id'] as int, postId),
              child: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
            ),
        ],
      ),
    );
  }
}
