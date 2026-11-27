import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/controllers/group_posts_controller.dart';
import 'package:fruitsofspirit/services/comments_service.dart';
import 'package:fruitsofspirit/utils/app_theme.dart';
import 'package:fruitsofspirit/utils/content_delete_helper.dart';
import 'package:fruitsofspirit/utils/image_helper.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';
import 'package:fruitsofspirit/utils/time_helper.dart';
import 'package:fruitsofspirit/widgets/cached_image.dart';

class GroupPostDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> post;
  final int groupId;
  final String groupName;

  const GroupPostDetailsScreen({
    Key? key,
    required this.post,
    required this.groupId,
    required this.groupName,
  }) : super(key: key);

  @override
  State<GroupPostDetailsScreen> createState() => _GroupPostDetailsScreenState();
}

class _GroupPostDetailsScreenState extends State<GroupPostDetailsScreen> {
  final GroupPostsController controller = Get.find<GroupPostsController>();
  final TextEditingController _commentController = TextEditingController();
  late Map<String, dynamic> _post;
  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;

  int get _postId {
    final id = _post['id'];
    if (id is int) return id;
    return int.tryParse(id?.toString() ?? '') ?? 0;
  }

  @override
  void initState() {
    super.initState();
    _post = Map<String, dynamic>.from(widget.post);
    controller.currentGroupId.value = widget.groupId;
    controller.selectedPost.value = _post;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final postId = _postId;
    controller.bootstrapGroupPosts(widget.groupId);
    controller.bootstrapPostComments(postId);

    final cached = controller.findPostById(postId);
    if (cached != null) {
      _post = Map<String, dynamic>.from(cached);
      controller.selectedPost.value = _post;
    }

    final hadComments = controller.postComments.isNotEmpty;
    if (hadComments) {
      _comments = List<Map<String, dynamic>>.from(controller.postComments);
    }
    if (!hadComments) {
      if (mounted) setState(() => _isLoading = true);
    }

    try {
      unawaited(
        controller.loadGroupPosts(
          widget.groupId,
          refresh: true,
          silent: true,
        ),
      );
      await controller.loadPostComments(postId, silent: hadComments);

      final refreshed = controller.findPostById(postId);
      if (refreshed != null) {
        _post = Map<String, dynamic>.from(refreshed);
        controller.selectedPost.value = _post;
      }

      if (mounted) {
        setState(() {
          _comments = List<Map<String, dynamic>>.from(controller.postComments);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        if (_comments.isEmpty) {
          _showSnack(e.toString().replaceAll('Exception: ', ''), isError: true);
        }
      }
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

  Future<void> _deletePost() async {
    if (controller.userId.value == 0) {
      _showSnack('Please login first', isError: true);
      return;
    }
    final confirmed = await ContentDeleteHelper.confirmDelete(context, itemLabel: 'post');
    if (!confirmed) return;

    try {
      await controller.deletePost(_postId);
      if (mounted) Navigator.pop(context);
      _showSnack('Post deleted successfully');
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''), isError: true);
    }
  }

  Future<void> _deleteComment(int commentId) async {
    if (controller.userId.value == 0) return;
    final confirmed = await ContentDeleteHelper.confirmDelete(context, itemLabel: 'comment');
    if (!confirmed) return;

    try {
      await CommentsService.deleteComment(
        userId: controller.userId.value,
        commentId: commentId,
        postType: 'group_post',
      );
      await controller.loadPostComments(_postId);
      if (mounted) {
        setState(() => _comments = List<Map<String, dynamic>>.from(controller.postComments));
      }
      _showSnack('Comment deleted successfully');
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''), isError: true);
    }
  }

  Future<void> _addComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    final success = await controller.addComment(_postId, content);
    if (success) {
      _commentController.clear();
      if (mounted) {
        setState(() {
          _comments = List<Map<String, dynamic>>.from(controller.postComments);
          _post['comment_count'] = (_post['comment_count'] as int? ?? 0) + 1;
        });
      }
      _showSnack('Comment added');
    } else if (controller.message.value.isNotEmpty) {
      _showSnack(controller.message.value, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = ContentDeleteHelper.isOwner(controller.userId.value, _post['user_id']);
    final profileUrl = ImageHelper.getProfilePhotoUrl(_post['profile_photo'] as String?);
    final imagePath = _post['image_path'] as String?;
    final imageUrl = imagePath != null && imagePath.isNotEmpty
        ? (imagePath.startsWith('http') ? imagePath : 'http://admin.fosmessenger.com/$imagePath')
        : (_post['image_url'] as String?);

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
            const Text('Group Post', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    color: AppTheme.primaryColor,
                    onRefresh: _loadData,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(12),
                      child: Container(
                        decoration: AppTheme.cardDecoration(),
                        padding: ResponsiveHelper.padding(context, horizontal: 14, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundImage: profileUrl != null ? NetworkImage(profileUrl) : null,
                                  child: profileUrl == null ? const Icon(Icons.person, size: 20) : null,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _post['user_name'] as String? ?? 'User',
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                      ),
                                      Text(
                                        TimeHelper.getTimeAgo(_post['created_at'] as String?),
                                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isOwner)
                                  PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'delete') _deletePost();
                                    },
                                    itemBuilder: (context) => const [
                                      PopupMenuItem(
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
                            if ((_post['post_type'] as String?)?.isNotEmpty == true &&
                                (_post['post_type'] as String?) != 'text') ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  (_post['post_type'] as String).toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                            ],
                            if (_post['event_date'] != null && _post['event_date'].toString().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.event, size: 14, color: Colors.grey[700]),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Event: ${_post['event_date']}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                  ),
                                ],
                              ),
                            ],
                            if ((_post['title'] as String?)?.isNotEmpty == true) ...[
                              const SizedBox(height: 10),
                              Text(
                                _post['title'] as String,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ],
                            if ((_post['content'] as String?)?.isNotEmpty == true) ...[
                              const SizedBox(height: 8),
                              Text(
                                _post['content'] as String,
                                style: const TextStyle(fontSize: 15, height: 1.5),
                              ),
                            ],
                            if (imageUrl != null && imageUrl.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: CachedImage(
                                  imageUrl: imageUrl,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(Icons.favorite_border, size: 16, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(
                                  '${_post['reaction_count'] ?? 0}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                ),
                                const SizedBox(width: 16),
                                Icon(Icons.chat_bubble_outline, size: 16, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(
                                  '${_post['comment_count'] ?? _comments.length}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Text(
                              'Comments',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_comments.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Text(
                                  'No comments yet. Be the first to comment.',
                                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                ),
                              )
                            else
                              ..._comments.map((comment) => _buildCommentTile(comment)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  color: Colors.white,
                  padding: EdgeInsets.only(
                    left: 12,
                    right: 8,
                    top: 8,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          decoration: const InputDecoration(
                            hintText: 'Write a comment...',
                            isDense: true,
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send, color: AppTheme.primaryColor),
                        onPressed: _addComment,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCommentTile(Map<String, dynamic> comment) {
    final isOwner = ContentDeleteHelper.isOwner(controller.userId.value, comment['user_id']);
    final content = (comment['comment'] as String?) ?? (comment['content'] as String?) ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black87, fontSize: 14),
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
              onTap: () {
                final commentId = comment['id'];
                final parsedId = commentId is int
                    ? commentId
                    : int.tryParse(commentId?.toString() ?? '') ?? 0;
                if (parsedId > 0) _deleteComment(parsedId);
              },
              child: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
            ),
        ],
      ),
    );
  }
}
