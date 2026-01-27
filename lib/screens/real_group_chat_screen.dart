import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fruitsofspirit/controllers/group_chat_controller.dart';
import 'package:fruitsofspirit/controllers/groups_controller.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';
import 'package:fruitsofspirit/widgets/cached_image.dart';
import 'package:fruitsofspirit/services/emojis_service.dart';
import 'package:fruitsofspirit/services/jingle_service.dart';
import 'package:fruitsofspirit/services/groups_service.dart';
import 'package:fruitsofspirit/screens/home_screen.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../services/terms_service.dart';
import '../services/user_storage.dart' as us;
import 'terms_acceptance_screen.dart';

import 'package:fruitsofspirit/screens/report_content_screen.dart' as rcs;
import 'package:fruitsofspirit/services/user_blocking_service.dart';
import 'package:fruitsofspirit/utils/fruit_emoji_helper.dart';
import '../utils/app_theme.dart';

class RealGroupChatScreen extends StatefulWidget {
  final int groupId;
  final String groupName;

  const RealGroupChatScreen({
    Key? key,
    required this.groupId,
    required this.groupName,
  }) : super(key: key);

  @override
  State<RealGroupChatScreen> createState() => _RealGroupChatScreenState();
}

class _RealGroupChatScreenState extends State<RealGroupChatScreen> {
  final GroupChatController controller = Get.put(GroupChatController());
  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  final JingleService _jingleService = Get.find<JingleService>();

  var availableEmojis = <Map<String, dynamic>>[].obs;
  var isLoadingEmojis = true.obs;
  var jingleStatus = <String, dynamic>{}.obs;

  int? groupOwnerId;
  String? groupCategory;
  String? groupImage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadGroupData();
      controller.loadMessages(widget.groupId, refresh: true);
      _loadEmojis();
    });

    // Automatically show disable dialog when jingle finishes for the 3rd time
    ever(_jingleService.lastFinishedCategory, (String category) {
      if (category == groupCategory && category.isNotEmpty) {
        _loadJingleStatus();
      }
    });

    controller.messages.listen((_) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (scrollController.hasClients) {
          scrollController.animateTo(
            0, // Scroll to bottom (0 offset in reverse ListView)
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    });
  }

  Future<void> _loadGroupData() async {
    try {
      final details = await GroupsService.getGroupDetails(widget.groupId);
      if (mounted) {
        setState(() {
          groupOwnerId = details['created_by'] as int?;
          groupCategory = details['category'] as String?;
          groupImage = details['group_image'] as String? ?? details['image_url'] as String?;
        });
        _loadJingleStatus();
      }
    } catch (e) {
      print('Error loading group data: $e');
    }
  }

  Future<void> _loadJingleStatus() async {
    if (groupCategory == null || groupCategory!.isEmpty) return;
    final status = await _jingleService.getJingleStatus(groupCategory!);
    jingleStatus.value = status;

    // Show dialog if play count reached 3 and not disabled yet
    if (status['shouldShowOption'] == true && !(status['isDisabled'] ?? false)) {
      _showDisableJingleDialog(groupCategory!);
    }
  }

  Future<void> _loadEmojis() async {
    try {
      isLoadingEmojis.value = true;
      availableEmojis.value = await EmojisService.getEmojis(status: 'Active', sortBy: 'image_url', order: 'ASC');
    } catch (e) {
      availableEmojis.value = [];
    } finally {
      isLoadingEmojis.value = false;
    }
  }

  void _showDisableJingleDialog(String category) {
    if (Get.isDialogOpen ?? false) return; // Prevent duplicate dialogs
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Voice Over Option', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('You\'ve heard this voice over 3 times. Would you like to disable it for this group? \n\n(You can change this anytime from the menu.)'),
        actions: [
          TextButton(onPressed: (){
            final dialogContext = Get.overlayContext;
            if (dialogContext != null) {
              Navigator.of(dialogContext, rootNavigator: true).pop();
            } else if (context.mounted) {
              Navigator.of(context, rootNavigator: true).pop();
            }
          }, child: const Text('Keep it')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B4513), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () async {
              await _jingleService.disableJingle(category);
              await _jingleService.stopJingle();
              Get.back();
              _loadJingleStatus();
            },
            child: const Text('Disable', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleJingle() async {
    if (groupCategory == null) return;
    final isDisabled = jingleStatus['isDisabled'] ?? false;
    if (isDisabled) {
      await _jingleService.enableJingle(groupCategory!);
      Get.snackbar('Voice Enabled', 'Voice over will play when you enter.', snackPosition: SnackPosition.BOTTOM);
    } else {
      await _jingleService.disableJingle(groupCategory!);
      await _jingleService.stopJingle();
      Get.snackbar('Voice Disabled', 'Voice over turned off.', snackPosition: SnackPosition.BOTTOM);
    }
    _loadJingleStatus();
  }

  Future<void> _runWithTermsCheck(Function action) async {
    try {
      final hasAcceptedFactors = await TermsService.hasAcceptedTerms();
      if (hasAcceptedFactors) {
        action();
      } else {
        _showUgcTermsDialog(action);
      }
    } catch (e) {
      print('Error checking terms: $e');
      // If check fails, default to showing dialog as safe fallback
      _showUgcTermsDialog(action);
    }
  }

  void _showUgcTermsDialog(Function action) {
    Get.dialog(
      AlertDialog(
        title: const Text("Community Guidelines"),
        content: const Text(
          "To keep our community safe, please agree to our terms. "
          "Hate speech, bullying, or inappropriate content is strictly prohibited."
        ),
        actions: [
          TextButton(
            onPressed: (){
              final dialogContext = Get.overlayContext;
              if (dialogContext != null) {
                Navigator.of(dialogContext, rootNavigator: true).pop();
              } else if (context.mounted) {
                Navigator.of(context, rootNavigator: true).pop();
              }
            },
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            onPressed: () async {
              await TermsService.acceptTerms();
              final dialogContext = Get.overlayContext;
              if (dialogContext != null) {
                Navigator.of(dialogContext, rootNavigator: true).pop();
              } else if (context.mounted) {
                Navigator.of(context, rootNavigator: true).pop();
              }
              print("Action calling");
              // Close dialog
              action(); // Perform action
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text("I AGREE"),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  @override
  void dispose() {
    controller.stopPolling();
    messageController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseUrl = 'https://fruitofthespirit.templateforwebsites.com/';

    return Scaffold(
      backgroundColor: AppTheme.themeColor,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(ResponsiveHelper.safeHeight(context, mobile: 70, tablet: 120, desktop: 90)),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
            border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.15), width: 0.5)),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // Use Navigator pop to avoid GetX snackbar close crash on back
                  _buildOldStyleRoundButton(
                    context,
                    icon: Icons.arrow_back_rounded,
                    onTap: () {
                      Navigator.of(context).maybePop();
                    },
                  ),
                  const SizedBox(width: 12),
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFF8B4513).withOpacity(0.1),
                    backgroundImage: groupImage != null && groupImage!.isNotEmpty
                        ? NetworkImage(groupImage!.startsWith('http') ? groupImage! : baseUrl + groupImage!)
                        : null,
                    child: groupImage == null || groupImage!.isEmpty
                        ? const Icon(Icons.group, color: Color(0xFF8B4513), size: 24)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(widget.groupName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF5F4628)), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Obx(() {
                          final count = controller.messages.where((m) => m['group_id'].toString() == widget.groupId.toString()).map((m) => m['user_id']).toSet().length;
                          return Text('$count members', style: TextStyle(fontSize: 12, color: Colors.grey[600]));
                        }),
                      ],
                    ),
                  ),
                  Obx(() {
                    if (!(jingleStatus['shouldShowOption'] ?? false)) return const SizedBox.shrink();
                    final isDisabled = jingleStatus['isDisabled'] ?? false;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildOldStyleRoundButton(
                          context,
                          icon: isDisabled ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                          onTap: _toggleJingle
                        ),
                        const SizedBox(width: 8),
                      ],
                    );
                  }),
                  _buildMoreMenu(context),
                ],
              ),
            ),
          ),
        ),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
          Expanded(
            child: Obx(() {
              final groupMessages = controller.messages.where((msg) => msg['group_id'].toString() == widget.groupId.toString()).toList();
              if (controller.isLoading.value && groupMessages.isEmpty) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF8B4513)));
              }
              if (groupMessages.isEmpty) {
                return Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text('No messages yet', style: TextStyle(color: Colors.grey[600])),
                  ],
                ));
              }
              return ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(8),
                reverse: true,
                itemCount: groupMessages.length,
                itemBuilder: (context, index) {
                  final currentMessage = groupMessages[groupMessages.length - 1 - index];
                  final currentMessageDate = DateTime.parse(currentMessage['created_at']);

                  bool showDateSeparator = false;
                  if (index == groupMessages.length - 1) {
                    showDateSeparator = true;
                  } else {
                    final previousMessage = groupMessages[groupMessages.length - 1 - (index + 1)];
                    final previousMessageDate = DateTime.parse(previousMessage['created_at']);
                    if (currentMessageDate.day != previousMessageDate.day ||
                        currentMessageDate.month != previousMessageDate.month ||
                        currentMessageDate.year != previousMessageDate.year) {
                      showDateSeparator = true;
                    }
                  }

                  List<Widget> widgets = [];
                  if (showDateSeparator) {
                    widgets.add(
                      Center(
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _formatDateSeparator(currentMessageDate),
                            style: const TextStyle(color: Colors.black, fontSize: 12),
                          ),
                        ),
                      ),
                    );
                  }
                  widgets.add(_buildMessageBubble(context, currentMessage));
                  return Column(children: widgets);
                },
              );
            }),
          ),
          _buildMessageInput(context),
          ],
        ),
      ),
    );
  }

  String _formatDateSeparator(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return 'Today';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('dd MMMM yyyy').format(date);
    }
  }

  String _formatTime(String createdAt) {
    final dateTime = DateTime.parse(createdAt);
    return DateFormat('h:mm a').format(dateTime);
  }

  Widget _buildOldStyleRoundButton(BuildContext context, {required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          width: 40.0, height: 40.0,
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.grey[50]!, Colors.grey[100]!]),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.withOpacity(0.2), width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
          ),
          child: Icon(icon, color: AppTheme.iconscolor, size: 20.0),
        ),
      ),
    );
  }

  Widget _buildMoreMenu(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (value) { if (value == 'toggle') _toggleJingle(); },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      icon: _buildOldStyleRoundButton(context, icon: Icons.more_vert, onTap: () {}),
      itemBuilder: (context) {
        final status = jingleStatus.value;
        final shouldShow = status['shouldShowOption'] ?? false;
        final isDisabled = status['isDisabled'] ?? false;
        return [
          if (shouldShow)
            PopupMenuItem(
              value: 'toggle',
              child: Row(children: [
                Icon(isDisabled ? Icons.volume_up_rounded : Icons.volume_off_rounded, color: const Color(0xFF5F4628), size: 20),
                const SizedBox(width: 12),
                Text(isDisabled ? 'Enable Voice' : 'Disable Voice'),
              ]),
            ),
          const PopupMenuItem(value: 'info', child: Row(children: [
            Icon(Icons.info_outline_rounded, color: Color(0xFF5F4628), size: 20),
            const SizedBox(width: 12),
            Text('Group Info'),
          ])),
        ];
      },
    );
  }

  Widget _buildMessageBubble(BuildContext context, Map<String, dynamic> message) {
    final isMe = message['user_id'].toString() == controller.userId.value.toString();
    final profilePhoto = message['profile_photo'] as String?;
    final userName = message['user_name'] as String? ?? 'User';
    final createdAt = message['created_at'] as String? ?? '';
    final baseUrl = 'https://fruitofthespirit.templateforwebsites.com/';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[300],
              backgroundImage: profilePhoto != null && profilePhoto.isNotEmpty
                  ? NetworkImage(profilePhoto.startsWith('http') ? profilePhoto : baseUrl + profilePhoto)
                  : null,
              child: profilePhoto == null ? Text(userName.isNotEmpty ? userName[0].toUpperCase() : 'U', style: const TextStyle(fontSize: 12)) : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: InkWell(
              onLongPress: () => _showModerationDialog(context, message),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.8, // Max width 80% of screen
                ),
                child: Container(
                  width: double.infinity, // Make the container expand horizontally
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), // Increased vertical padding
                  decoration: BoxDecoration(
                    color: isMe ? const Color(0xFFDCF8C6) : const Color(0xFFFFFFFF), // WhatsApp sent (light green) vs received (white)
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(10),
                      topRight: const Radius.circular(10),
                      bottomLeft: Radius.circular(isMe ? 10 : 0), // Pointed corner for received
                      bottomRight: Radius.circular(isMe ? 0 : 10), // Pointed corner for sent
                    ),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 2, offset: const Offset(0, 1))], // Slightly more prominent shadow
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isMe) Padding(
                        padding: const EdgeInsets.only(bottom: 2.0),
                        child: Text(userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF8B4513))),
                      ),
                      _buildMessageContent(context, message),
                      Padding( // Wrap timestamp in Padding to control its position
                        padding: const EdgeInsets.only(top: 4.0), // Space between message content and time
                        child: Align(
                          alignment: Alignment.bottomRight, // Align time to bottom right within the bubble
                          child: Text(_formatTime(createdAt), style: const TextStyle(fontSize: 10, color: Colors.grey)), // Smaller font size for time
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context, Map<String, dynamic> msg) {
    final messageType = msg['message_type']?.toString() ?? 'text';
    final content = msg['message']?.toString() ?? '';

    if (messageType == 'emoji' || FruitEmojiHelper.isFruit(content)) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: FruitEmojiHelper.buildFruitWidget(content, size: 40),
      );
    }

    if (messageType == 'image' && msg['file_url'] != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: CachedImage(imageUrl: msg['file_url'], width: 200, height: 150, fit: BoxFit.cover),
          ),
          if (content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(content, style: const TextStyle(fontSize: 14)),
            ),
        ],
      );
    }
    return FruitEmojiHelper.buildCommentText(
      context,
      content,
      style: const TextStyle(color: Colors.black87, fontSize: 14),
    );
  }

  Widget _buildMessageInput(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, -2))]
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(icon: const Icon(Icons.emoji_emotions_outlined, color: AppTheme.iconscolor), onPressed: () => _showEmojiPicker(context)),
            IconButton(icon: const Icon(Icons.attach_file, color: AppTheme.iconscolor), onPressed: () => _showAttachmentOptions(context)),
            Expanded(
              child: TextField(
                controller: messageController,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  fillColor: Colors.grey[100],
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _sendMessage,
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.withOpacity(0.2), width: 1.5),


                      gradient: const LinearGradient(
                          colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF)]),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.send, color: AppTheme.iconscolor, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendMessage() async {
    _runWithTermsCheck(() async {
      final text = messageController.text.trim();
      if (text.isEmpty) return;
      messageController.clear();
      await controller.sendMessage(groupId: widget.groupId, text: text);
    });
  }

  void _showEmojiPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Obx(() => GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 6, crossAxisSpacing: 12, mainAxisSpacing: 12),
        itemCount: availableEmojis.length,
        itemBuilder: (context, index) => InkWell(
          onTap: () async {
            _runWithTermsCheck(() async {
              final emojiChar = availableEmojis[index]['emoji_char'] ?? availableEmojis[index]['code'];
              await controller.sendMessage(
                groupId: widget.groupId, 
                text: emojiChar,
                messageType: 'emoji',
              );
              Get.back();
            });
          },
          child: HomeScreen.buildEmojiDisplay(context, availableEmojis[index], size: 32),
        ),
      )),
    );
  }

  void _showAttachmentOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(leading: const Icon(Icons.photo), title: const Text('Gallery'), onTap: () { Get.back(); _pickImage(ImageSource.gallery); }),
          ListTile(leading: const Icon(Icons.camera_alt), title: const Text('Camera'), onTap: () { Get.back(); _pickImage(ImageSource.camera); }),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final file = await _picker.pickImage(source: source);
    if (file != null) {
      _runWithTermsCheck(() {
        controller.sendMessage(groupId: widget.groupId, text: '', file: File(file.path), messageType: 'image');
      });
    }
  }

 /* String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) { return ''; }
  }

  String _formatDateSeparator(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return 'Today';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }*/
  void _showModerationDialog(BuildContext context, Map<String, dynamic> message) {
    final isMe = message['user_id'].toString() == controller.userId.value.toString();
    if (isMe) return;

    Get.dialog(
      AlertDialog(
        title: const Text('Message Options'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.report_outlined, color: Colors.orange),
              title: const Text('Report Content'),
              onTap: () {
                Get.back();
                Get.to(() => rcs.ReportContentScreen(
                      contentType: 'group_message',
                      contentId: message['id'] is int ? message['id'] : int.parse(message['id'].toString()),
                    ));
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: Colors.red),
              title: const Text('Block User'),
              onTap: () async {
                Get.back();
                final userId = message['user_id'] is int ? message['user_id'] : int.tryParse(message['user_id'].toString());
                if (userId != null) {
                  final userName = message['user_name'] ?? 'this user';
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
                      controller.loadMessages(widget.groupId, refresh: true);
                    } catch (e) {
                      Get.snackbar('Error', 'Failed to block user');
                    }
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
