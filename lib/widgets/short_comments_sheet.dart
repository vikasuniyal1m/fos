import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/controllers/shorts_controller.dart';
import 'package:fruitsofspirit/services/user_storage.dart';
import 'package:fruitsofspirit/utils/app_theme.dart';
import 'package:fruitsofspirit/utils/fruit_emoji_helper.dart';
import 'package:fruitsofspirit/utils/image_helper.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';
import 'package:fruitsofspirit/utils/time_helper.dart';
import 'package:fruitsofspirit/widgets/emoji_button.dart';
import 'package:fruitsofspirit/widgets/emoji_sticker_picker.dart';
import 'package:fruitsofspirit/utils/sticker_emoji_helper.dart';
import 'package:fruitsofspirit/utils/content_delete_helper.dart';
import 'dart:io';

/// Instagram-style comments bottom sheet for Shorts
class ShortCommentsSheet extends StatefulWidget {
  final int shortId;
  final int feedIndex;
  final int commentCount;
  final ShortsController controller;

  const ShortCommentsSheet({
    Key? key,
    required this.shortId,
    required this.feedIndex,
    this.commentCount = 0,
    required this.controller,
  }) : super(key: key);

  @override
  State<ShortCommentsSheet> createState() => _ShortCommentsSheetState();
}

class _ShortCommentsSheetState extends State<ShortCommentsSheet> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _editControllers = <int, TextEditingController>{};
  final _replyControllers = <int, TextEditingController>{};
  final _showEditInput = <int, bool>{};
  final _showReplyInput = <int, bool>{};
  var _isSending = false;
  var _isEditing = false;
  String? _userEmail;
  String? _myPhoto;
  String? _myName;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserMeta();
    widget.controller.openComments(
      widget.shortId,
      commentCount: widget.commentCount,
    );
  }

  Future<void> _loadCurrentUserMeta() async {
    final user = await UserStorage.getUser();
    if (!mounted) return;
    setState(() {
      _userEmail = user?['email']?.toString();
      _myPhoto = user?['profile_photo']?.toString();
      _myName = user?['name']?.toString().trim();
    });
  }

  Future<void> _sendComment([String? overrideText]) async {
    final text = (overrideText ?? _textController.text).trim();
    if (text.isEmpty || _isSending) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSending = true);
    final ok = await widget.controller.addComment(
      widget.shortId,
      text,
      widget.feedIndex,
    );
    if (ok) {
      _textController.clear();
      _scrollToBottom();
    }
    if (mounted) setState(() => _isSending = false);
  }

  Future<void> _sendStickerOrEmoji(String value) async {
    if (value.isEmpty || _isSending) return;
    FocusScope.of(context).unfocus();
    await _sendComment(value);
  }

  Future<void> _sendReply(int parentCommentId) async {
    final text = _replyControllers[parentCommentId]?.text.trim() ?? '';
    if (text.isEmpty || _isSending) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSending = true);
    final ok = await widget.controller.addComment(
      widget.shortId,
      text,
      widget.feedIndex,
      parentCommentId: parentCommentId,
    );
    if (!mounted) return;
    if (ok) {
      _replyControllers[parentCommentId]?.clear();
      setState(() => _showReplyInput[parentCommentId] = false);
    }
    setState(() => _isSending = false);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _showStickerPicker() {
    showEmojiStickerPicker(
      context: context,
      onEmojiSelected: (value) async {
        if (StickerEmojiHelper.isStickerEmoji(value)) {
          await _sendStickerOrEmoji(value);
        } else {
          _textController.text = '${_textController.text}$value';
          _textController.selection = TextSelection.fromPosition(
            TextPosition(offset: _textController.text.length),
          );
        }
      },
      height: 280,
    );
  }

  String _commentText(Map<String, dynamic> comment) {
    return comment['comment']?.toString() ??
        comment['content']?.toString() ??
        '';
  }

  String _userName(Map<String, dynamic> comment) {
    final name = comment['user_name']?.toString().trim() ??
        comment['name']?.toString().trim() ??
        '';
    if (name.isNotEmpty && name != 'User') return name;
    final commentUserId = int.tryParse(comment['user_id']?.toString() ?? '0') ?? 0;
    final myId = widget.controller.userId.value;
    if (commentUserId > 0 && commentUserId == myId && (_myName?.isNotEmpty == true)) {
      return _myName!;
    }
    return name.isNotEmpty ? name : 'User';
  }

  int _commentId(Map<String, dynamic> comment) {
    final id = int.tryParse(comment['id']?.toString() ?? '0') ?? 0;
    return id > 0 ? id : 0;
  }

  int? _activeUserId() => widget.controller.userId.value > 0 ? widget.controller.userId.value : null;

  bool _isOwner(Map<String, dynamic> comment) {
    return ContentDeleteHelper.isOwner(_activeUserId(), comment['user_id']);
  }

  bool _canEditComment(Map<String, dynamic> comment) {
    final uid = _activeUserId();
    if (uid == null || uid == 0) return false;
    if (comment['_pending'] == true) return false;
    if (!ContentDeleteHelper.isOwner(uid, comment['user_id'])) return false;
    return TimeHelper.isWithinEditWindow(comment['created_at']);
  }

  String _editableCommentText(Map<String, dynamic> comment) {
    final rawContent = _commentText(comment).trim();
    if (rawContent.isEmpty) return '';
    if (rawContent.startsWith('http') &&
        (rawContent.contains('.png') ||
            rawContent.contains('.jpg') ||
            rawContent.contains('.jpeg'))) {
      return '';
    }
    if (StickerEmojiHelper.isStickerEmoji(rawContent)) return '';
    return rawContent;
  }

  Future<void> _deleteComment(int commentId) async {
    final ok = await ContentDeleteHelper.confirmDelete(context, itemLabel: 'comment');
    if (!ok) return;
    final deleted = await widget.controller.deleteComment(
      widget.shortId,
      commentId,
      feedIndex: widget.feedIndex,
    );
    if (!mounted) return;
    if (deleted) {
      setState(() => _showEditInput.remove(commentId));
      _scrollToBottom();
      _showSnack('Comment deleted successfully');
    } else {
      _showSnack(widget.controller.message.value, isError: true);
    }
  }

  Map<String, dynamic>? _commentById(int commentId) {
    for (final c in widget.controller.comments) {
      if (_commentId(c) == commentId) return c;
    }
    return null;
  }

  Future<void> _saveEdit(int commentId) async {
    final comment = _commentById(commentId);
    if (comment == null || !_canEditComment(comment)) {
      setState(() => _showEditInput[commentId] = false);
      _showSnack('You can only edit your own comments within 15 minutes', isError: true);
      return;
    }

    final controller = _editControllers[commentId];
    final text = controller?.text.trim() ?? '';
    if (text.isEmpty) {
      _showSnack('Comment cannot be empty', isError: true);
      return;
    }
    setState(() => _isEditing = true);
    final ok = await widget.controller.editComment(widget.shortId, commentId, text);
    if (!mounted) return;
    setState(() {
      _isEditing = false;
      if (ok) _showEditInput[commentId] = false;
    });
    if (ok) {
      _showSnack('Comment edited successfully');
    } else {
      _showSnack(widget.controller.message.value, isError: true);
    }
  }

  void _showReportDialog(Map<String, dynamic> comment) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report Comment'),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Reason (optional)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final commentId = _commentId(comment);
              if (commentId <= 0) return;
              final ok = await widget.controller.reportComment(
                commentId,
                reason: reasonController.text.trim().isNotEmpty
                    ? reasonController.text.trim()
                    : null,
              );
              if (!mounted) return;
              _showSnack(
                ok ? 'Comment reported successfully' : widget.controller.message.value,
                isError: !ok,
              );
            },
            child: const Text('Report'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String text, {bool isError = false}) {
    if (text.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? Colors.red : null,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildTimeAndActionsRow(Map<String, dynamic> comment) {
    if (comment['_pending'] == true) {
      return Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          'Sending...',
          style: ResponsiveHelper.textStyle(context, fontSize: 11, color: Colors.grey),
        ),
      );
    }

    final commentId = _commentId(comment);
    final uid = widget.controller.userId.value;
    final canEdit = uid > 0 && _canEditComment(comment);
    final isOwner = uid > 0 && _isOwner(comment);

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          if (comment['created_at'] != null)
            Text(
              TimeHelper.getTimeAgo(comment['created_at'] as String?),
              style: ResponsiveHelper.textStyle(context, fontSize: 11, color: Colors.grey),
            ),
          if (comment['is_edited'] == true || comment['is_edited'] == 1)
            Text(
              ' · edited',
              style: TextStyle(
                fontSize: ResponsiveHelper.fontSize(context, mobile: 10, tablet: 11),
                color: Colors.grey[500],
                fontStyle: FontStyle.italic,
              ),
            ),
          if (commentId > 0) ...[
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () {
                setState(() {
                  final wasOpen = _showReplyInput[commentId] == true;
                  _showReplyInput.clear();
                  _showReplyInput[commentId] = !wasOpen;
                  _replyControllers.putIfAbsent(
                    commentId,
                    () => TextEditingController(),
                  );
                });
              },
              child: Icon(Icons.reply, size: 14, color: Colors.grey.shade600),
            ),
          ],
          if (canEdit) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                if (!_canEditComment(comment)) {
                  _showSnack('You can only edit your own comments within 15 minutes', isError: true);
                  return;
                }
                setState(() {
                  if (!_editControllers.containsKey(commentId)) {
                    _editControllers[commentId] = TextEditingController(
                      text: _editableCommentText(comment),
                    );
                  }
                  _showEditInput[commentId] = !(_showEditInput[commentId] ?? false);
                });
              },
              child: const Icon(Icons.edit_outlined, size: 14, color: Colors.orange),
            ),
          ],
          if (isOwner && commentId > 0) ...[
            const SizedBox(width: 8),
            ContentDeleteHelper.buildDeleteAction(
              onTap: () => _deleteComment(commentId),
            ),
          ],
          if (!isOwner && uid > 0 && commentId > 0) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _showReportDialog(comment),
              child: Icon(Icons.flag_outlined, size: 14, color: Colors.grey.shade600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEditInput(Map<String, dynamic> comment) {
    final commentId = _commentId(comment);
    if (_showEditInput[commentId] != true || !_canEditComment(comment)) {
      return const SizedBox.shrink();
    }
    final editController = _editControllers.putIfAbsent(
      commentId,
      () => TextEditingController(),
    );

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: editController,
            maxLines: 3,
            style: ResponsiveHelper.textStyle(context, fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Colors.blue.shade50,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.all(8),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _isEditing
                    ? null
                    : () => setState(() => _showEditInput[commentId] = false),
                child: const Text('Cancel', style: TextStyle(fontSize: 12)),
              ),
              TextButton(
                onPressed: _isEditing ? null : () => _saveEdit(commentId),
                child: _isEditing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReplyInput(int commentId) {
    if (_showReplyInput[commentId] != true) return const SizedBox.shrink();
    final replyController = _replyControllers.putIfAbsent(
      commentId,
      () => TextEditingController(),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 2),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: replyController,
              style: ResponsiveHelper.textStyle(context, fontSize: 12),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendReply(commentId),
              decoration: InputDecoration(
                hintText: 'Write a reply...',
                hintStyle: ResponsiveHelper.textStyle(context, fontSize: 12, color: Colors.grey),
                isDense: true,
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: _isSending ? null : () => _sendReply(commentId),
            icon: const Icon(Icons.send_rounded, size: 18, color: AppTheme.iconscolor),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentThread(Map<String, dynamic> comment, {int depth = 0}) {
    final commentId = _commentId(comment);
    final replies = comment['replies'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCommentItem(context, comment, depth: depth),
        if (commentId > 0) _buildReplyInput(commentId),
        if (replies is List)
          ...replies.whereType<Map>().map((reply) {
            return Padding(
              padding: EdgeInsets.only(left: depth < 1 ? 22 : 14),
              child: _buildCommentThread(
                Map<String, dynamic>.from(reply),
                depth: depth + 1,
              ),
            );
          }),
      ],
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    for (final c in _editControllers.values) {
      c.dispose();
    }
    for (final c in _replyControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool _isVisualComment(String text) {
    if (text.isEmpty) return false;
    return StickerEmojiHelper.isStickerEmoji(text) ||
        FruitEmojiHelper.isFruit(text) ||
        text.contains(':sticker_') ||
        text.contains(':emoji_');
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final height = MediaQuery.of(context).size.height * 0.55;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: Container(
      height: height,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 36,
            height: 3,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
            child: Text(
              'Comments',
              style: ResponsiveHelper.textStyle(context, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          const Divider(height: 1),
          Obx(() {
            if (!widget.controller.commentsSyncing.value || widget.controller.comments.isEmpty) {
              return const SizedBox.shrink();
            }
            return const LinearProgressIndicator(minHeight: 2);
          }),
          Expanded(
            child: Obx(() {
              final list = widget.controller.comments;
              final _ = widget.controller.userId.value;
              final syncing = widget.controller.commentsSyncing.value;

              if (list.isEmpty && syncing) {
                return const Center(child: CircularProgressIndicator(strokeWidth: 2));
              }
              if (list.isEmpty) {
                return Center(
                  child: Text(
                    'No comments yet',
                    style: ResponsiveHelper.textStyle(context, fontSize: 13, color: Colors.grey),
                  ),
                );
              }
              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
                itemCount: list.length,
                itemBuilder: (context, i) => _buildCommentThread(list[i]),
              );
            }),
          ),
          const Divider(height: 1),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 6, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: ImageHelper.getProfileImageProvider(_myPhoto),
                    child: (_myPhoto == null || _myPhoto!.isEmpty)
                        ? Icon(Icons.person, size: 14, color: AppTheme.iconscolor)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  EmojiButton(onTap: _showStickerPicker),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: ResponsiveHelper.textStyle(context, fontSize: 13),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendComment(),
                      minLines: 1,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Add a comment...',
                        hintStyle: ResponsiveHelper.textStyle(context, fontSize: 13, color: Colors.grey),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    onPressed: _isSending ? null : () => _sendComment(),
                    icon: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded, size: 20, color: AppTheme.iconscolor),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildCommentItem(
    BuildContext context,
    Map<String, dynamic> comment, {
    int depth = 0,
  }) {
    final userName = _userName(comment);
    final text = _commentText(comment);
    final profilePhoto = comment['profile_photo']?.toString();
    final isPending = comment['_pending'] == true;
    final avatarRadius = depth > 0 ? 12.0 : 14.0;

    final bodyStyle = ResponsiveHelper.textStyle(
      context,
      fontSize: depth > 0 ? 12 : 13,
      color: Colors.black87,
      height: 1.25,
    );
    final nameStyle = bodyStyle.copyWith(fontWeight: FontWeight.w600, color: Colors.black);
    final isVisual = _isVisualComment(text);

    return Padding(
      padding: EdgeInsets.only(bottom: depth > 0 ? 6 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: avatarRadius,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: ImageHelper.getProfileImageProvider(profilePhoto),
            child: (profilePhoto == null || profilePhoto.isEmpty)
                ? Icon(Icons.person_rounded, size: 14, color: AppTheme.iconscolor)
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isVisual) ...[
                  Text(userName, style: nameStyle),
                  if (text.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    _buildCommentBody(comment, text),
                  ],
                ] else
                  RichText(
                    text: TextSpan(
                      style: bodyStyle,
                      children: [
                        TextSpan(text: userName, style: nameStyle),
                        if (text.isNotEmpty) const TextSpan(text: ' '),
                        if (text.isNotEmpty) TextSpan(text: text),
                      ],
                    ),
                  ),
                _buildTimeAndActionsRow(comment),
                _buildEditInput(comment),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentBody(Map<String, dynamic> comment, String raw) {
    final text = raw.trim();
    if (text.isEmpty) return const SizedBox.shrink();

    final localPath = comment['sticker_local_path']?.toString();
    if (localPath != null && localPath.isNotEmpty) {
      return Image.file(
        File(localPath),
        width: 32,
        height: 32,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            StickerEmojiHelper.buildStickerWidget(text, size: 32),
      );
    }

    final previewUrl = comment['sticker_image_url']?.toString();
    if (previewUrl != null && previewUrl.isNotEmpty) {
      return Image.network(
        previewUrl,
        width: 32,
        height: 32,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            StickerEmojiHelper.buildStickerWidget(text, size: 32),
      );
    }

    if (StickerEmojiHelper.isStickerEmoji(text)) {
      return SizedBox(
        width: 32,
        height: 32,
        child: StickerEmojiHelper.buildStickerWidget(text, size: 32),
      );
    }

    return FruitEmojiHelper.buildCommentText(
      context,
      text,
      userEmail: _userEmail,
      style: ResponsiveHelper.textStyle(context, fontSize: 13, color: Colors.black87, height: 1.25),
    );
  }
}
