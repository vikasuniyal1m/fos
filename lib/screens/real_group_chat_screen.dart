import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fruitsofspirit/controllers/group_chat_controller.dart';
import 'package:fruitsofspirit/controllers/groups_controller.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';
import 'package:fruitsofspirit/widgets/cached_image.dart';
import 'package:fruitsofspirit/config/image_config.dart';
import 'package:fruitsofspirit/services/emojis_service.dart';
import 'package:fruitsofspirit/services/jingle_service.dart';
import 'package:fruitsofspirit/services/groups_service.dart';
import 'package:fruitsofspirit/screens/home_screen.dart';
import 'dart:io';

/// Real Group Chat Screen - App Theme Style
/// Shows real-time chat messages with app theme colors
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
  var availableEmojis = <Map<String, dynamic>>[].obs;
  var isLoadingEmojis = true.obs;
  int? groupOwnerId; // Group owner/creator ID
  String? groupCategory; // Group category for jingle
  final JingleService _jingleService = JingleService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Don't play jingle here - it's already played before navigation
      // Just load group info for owner check
      _loadGroupOwner();
      controller.loadMessages(widget.groupId, refresh: true);
      _loadEmojis();
    });
    
    // Auto-scroll to bottom when new messages arrive (only for current group)
    controller.messages.listen((_) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (scrollController.hasClients) {
          scrollController.animateTo(
            scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    });
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Don't reload automatically - polling will handle new messages
    // Only load if this is the first time or group changed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Only load if messages are empty or group changed
        if (controller.messages.isEmpty || controller.currentGroupId != widget.groupId) {
          controller.loadMessages(widget.groupId, refresh: true);
        }
      }
    });
  }
  
  @override
  void didUpdateWidget(RealGroupChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If group changed, reload messages
    if (oldWidget.groupId != widget.groupId) {
      controller.loadMessages(widget.groupId, refresh: true);
    }
  }

  Future<void> _loadEmojis() async {
    try {
      isLoadingEmojis.value = true;
      final emojis = await EmojisService.getEmojis(
        status: 'Active',
        sortBy: 'image_url',
        order: 'ASC',
      );
      availableEmojis.value = emojis;
    } catch (e) {
      availableEmojis.value = [];
    } finally {
      isLoadingEmojis.value = false;
    }
  }

  /// Load group category and play jingle
  Future<void> _loadGroupCategoryAndPlayJingle() async {
    try {
      // Try to get group info from GroupsController first
      try {
        final groupsController = Get.find<GroupsController>();
        final selectedGroup = groupsController.selectedGroup;
        if (selectedGroup != null && selectedGroup['id'] == widget.groupId) {
          groupOwnerId = selectedGroup['created_by'] as int?;
          groupCategory = selectedGroup['category'] as String?;
          
          // Play jingle if category is available
          if (groupCategory != null && groupCategory!.isNotEmpty) {
            await _playJingleForCategory(groupCategory!);
          }
          return;
        }
      } catch (e) {
        // GroupsController not found, continue
      }
      
      // If not found in controller, fetch from API
      try {
        final groupDetails = await GroupsService.getGroupDetails(widget.groupId);
        groupOwnerId = groupDetails['created_by'] as int?;
        groupCategory = groupDetails['category'] as String?;
        
        // Play jingle if category is available
        if (groupCategory != null && groupCategory!.isNotEmpty) {
          await _playJingleForCategory(groupCategory!);
        }
      } catch (e) {
        print('⚠️ Error loading group details: $e');
      }
    } catch (e) {
      print('⚠️ Error loading group category: $e');
    }
  }

  /// Play jingle for category and show disable option if needed
  /// This is called when page loads (not used anymore since we play before navigation)
  Future<void> _playJingleForCategory(String category) async {
    // This method is kept for backward compatibility but not actively used
    // Jingle is now played before navigation in groups_screen.dart
    print('⚠️ _playJingleForCategory called but jingle should be played before navigation');
  }

  /// Show dialog to disable jingle
  void _showDisableJingleDialog(String category) {
    Get.dialog(
      AlertDialog(
        title: Text(
          'Disable Voice Over?',
          style: ResponsiveHelper.textStyle(
            context,
            fontSize: ResponsiveHelper.fontSize(context, mobile: 18, tablet: 20, desktop: 22),
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        content: Text(
          'You\'ve heard this voice over 3 times. Would you like to disable it for this category?',
          style: ResponsiveHelper.textStyle(
            context,
            fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 16, desktop: 18),
            color: Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Get.back();
            },
            child: Text(
              'Keep Playing',
              style: ResponsiveHelper.textStyle(
                context,
                fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                color: Colors.grey[600],
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              await _jingleService.disableJingle(category);
              Get.back();
              Get.snackbar(
                'Voice Over Disabled',
                'Voice over for $category has been disabled. You can enable it again in settings.',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: Colors.green,
                colorText: Colors.white,
                duration: const Duration(seconds: 2),
              );
            },
            child: Text(
              'Disable',
              style: ResponsiveHelper.textStyle(
                context,
                fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      barrierDismissible: true,
    );
  }

  Future<void> _loadGroupOwner() async {
    try {
      // Try to get group info from GroupsController
      try {
        final groupsController = Get.find<GroupsController>();
        final selectedGroup = groupsController.selectedGroup;
        if (selectedGroup != null && selectedGroup['id'] == widget.groupId) {
          groupOwnerId = selectedGroup['created_by'] as int?;
          return;
        }
      } catch (e) {
        // GroupsController not found, continue
      }
    } catch (e) {
      // Error loading group owner
    }
  }

  @override
  void dispose() {
    // Stop polling when screen is disposed
    controller.stopPolling();
    messageController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // App theme background
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
                children: [
                  // Back button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Get.back(),
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        width: ResponsiveHelper.isMobile(context) ? 40.0 : ResponsiveHelper.isTablet(context) ? 44.0 : 48.0,
                        height: ResponsiveHelper.isMobile(context) ? 40.0 : ResponsiveHelper.isTablet(context) ? 44.0 : 48.0,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.grey[50]!,
                              Colors.grey[100]!,
                            ],
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.2),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.arrow_back_rounded,
                          color: const Color(0xFF5F4628),
                          size: ResponsiveHelper.isMobile(context) ? 20.0 : ResponsiveHelper.isTablet(context) ? 22.0 : 24.0,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                  // Group avatar
                  CircleAvatar(
                    radius: ResponsiveHelper.isMobile(context) ? 20 : 24,
                    backgroundColor: const Color(0xFF8B4513).withOpacity(0.1),
                    child: Icon(
                      Icons.group,
                      color: const Color(0xFF8B4513),
                      size: ResponsiveHelper.isMobile(context) ? 24 : 28,
                    ),
                  ),
                  SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                  // Group name and member count
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.groupName,
                          style: ResponsiveHelper.textStyle(
                            context,
                            fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 18, desktop: 20),
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF5F4628),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Obx(() {
                          // Count unique users in current group messages
                          final groupMessages = controller.messages.where((m) {
                            final msgGroupId = m['group_id'] as int?;
                            return msgGroupId == widget.groupId;
                          }).toList();
                          
                          final memberCount = groupMessages
                              .map((m) => m['user_id'])
                              .toSet()
                              .length;
                          return Text(
                            '$memberCount members',
                            style: ResponsiveHelper.textStyle(
                              context,
                              fontSize: ResponsiveHelper.fontSize(context, mobile: 12, tablet: 13, desktop: 14),
                              color: Colors.grey[600],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  // More options
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        // Group info menu
                      },
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        width: ResponsiveHelper.isMobile(context) ? 40.0 : ResponsiveHelper.isTablet(context) ? 44.0 : 48.0,
                        height: ResponsiveHelper.isMobile(context) ? 40.0 : ResponsiveHelper.isTablet(context) ? 44.0 : 48.0,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.grey[50]!,
                              Colors.grey[100]!,
                            ],
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.2),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          Icons.more_vert,
                          color: const Color(0xFF5F4628),
                          size: ResponsiveHelper.isMobile(context) ? 20.0 : ResponsiveHelper.isTablet(context) ? 22.0 : 24.0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: Obx(() {
              // Access messages to ensure Obx tracks changes
              final allMessages = controller.messages;
              
              // Filter messages by current group_id
              // IMPORTANT: Always show messages for current group, even if group_id is missing (backward compatibility)
              final groupMessages = allMessages.where((msg) {
                final msgGroupId = msg['group_id'];
                // Convert to int for comparison (handle both int and String types)
                int? msgGroupIdInt;
                if (msgGroupId is int) {
                  msgGroupIdInt = msgGroupId;
                } else if (msgGroupId is String) {
                  msgGroupIdInt = int.tryParse(msgGroupId);
                } else if (msgGroupId != null) {
                  msgGroupIdInt = int.tryParse(msgGroupId.toString());
                }
                
                // If group_id is null or matches current group, include it
                final matches = msgGroupIdInt == null || msgGroupIdInt == widget.groupId;
                if (matches) {
                  // Ensure message has group_id set as int
                  if (msgGroupIdInt == null || msgGroupIdInt != widget.groupId) {
                    msg['group_id'] = widget.groupId;
                  }
                }
                return matches;
              }).toList();
              
              if (controller.isLoading.value && groupMessages.isEmpty) {
                return Center(
                  child: CircularProgressIndicator(
                    color: const Color(0xFF8B4513),
                  ),
                );
              }

              if (groupMessages.isEmpty) {
                
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No messages yet',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start the conversation!',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                      if (controller.messages.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Debug: ${controller.messages.length} messages loaded\nbut none match group ${widget.groupId}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red[300],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                );
              }
              
              // First, sort all messages chronologically (oldest to newest) by created_at
              final sortedMessages = List<Map<String, dynamic>>.from(groupMessages);
              sortedMessages.sort((a, b) {
                String aTime = a['created_at'] as String? ?? '';
                String bTime = b['created_at'] as String? ?? '';
                try {
                  final aDate = DateTime.parse(aTime);
                  final bDate = DateTime.parse(bTime);
                  return aDate.compareTo(bDate); // Ascending order (oldest first)
                } catch (e) {
                  return 0; // If parsing fails, keep original order
                }
              });
              
              // Group consecutive messages from the same user (WhatsApp style)
              final groupedMessages = _groupConsecutiveMessages(sortedMessages);
              
              return RefreshIndicator(
                onRefresh: () async {
                  await controller.refresh();
                  // Force UI rebuild after refresh
                  setState(() {});
                },
                color: const Color(0xFF8B4513),
                child: ListView.builder(
                  controller: scrollController,
                  padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 8)),
                  reverse: true, // WhatsApp style: newest messages at bottom
                  itemCount: groupedMessages.length + (controller.hasMore.value ? 1 : 0),
                  key: ValueKey('messages_${groupedMessages.length}_${DateTime.now().millisecondsSinceEpoch}'),
                  itemBuilder: (context, index) {
                    // In reversed ListView, index 0 is the last item (newest message)
                    // Load more button should be at the top (index == itemCount - 1 when reversed)
                    if (controller.hasMore.value && index == groupedMessages.length) {
                      return Center(
                        child: Padding(
                          padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 8)),
                          child: TextButton(
                            onPressed: () => controller.loadMore(),
                            child: const Text('Load older messages'),
                          ),
                        ),
                      );
                    }
                    
                    // Calculate actual message index (reverse the index for reversed ListView)
                    final messageIndex = groupedMessages.length - 1 - index;
                    if (messageIndex < 0 || messageIndex >= groupedMessages.length) {
                      return const SizedBox.shrink();
                    }
                    final messageGroup = groupedMessages[messageIndex];
                    // Build grouped message bubble
                    return _buildMessageBubble(context, messageGroup, messageIndex, groupedMessages);
                  },
                ),
              );
            }),
          ),
          
          // Message Input
          _buildMessageInput(context),
        ],
      ),
    );
  }

  /// Get user initials from first and last name
  String _getUserInitials(String userName) {
    if (userName.isEmpty) return '?';
    final parts = userName.trim().split(' ');
    if (parts.length >= 2) {
      // First letter of first name + first letter of last name
      return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
    } else if (parts.length == 1) {
      // Only first name, use first letter
      return parts[0][0].toUpperCase();
    }
    return '?';
  }

  /// Group consecutive messages from the same user (WhatsApp style - no time limit)
  List<Map<String, dynamic>> _groupConsecutiveMessages(List<Map<String, dynamic>> messages) {
    // Return messages as-is, without grouping by user, to ensure strict chronological order
    return messages;
  }

  Widget _buildMessageBubble(BuildContext context, Map<String, dynamic> message, int index, List<Map<String, dynamic>> allMessages) {
    final msgUserId = message['user_id'] as int? ?? 0;
    final isOwner = groupOwnerId != null && msgUserId == groupOwnerId;
    final isMe = msgUserId == controller.userId.value;
    final isLeftSide = !isMe;
    final userName = message['user_name'] as String? ?? 'Unknown';
    final profilePhoto = message['profile_photo'] as String?;
    final createdAt = message['created_at'] as String? ?? '';
    
    final baseUrl = 'https://fruitofthespirit.templateforwebsites.com/';
    String? photoUrl;
    if (profilePhoto != null && profilePhoto.isNotEmpty) {
      final photoPath = profilePhoto.toString();
      if (!photoPath.startsWith('http')) {
        photoUrl = baseUrl + (photoPath.startsWith('/') ? photoPath.substring(1) : photoPath);
      } else {
        photoUrl = photoPath;
      }
    }

    final userInitials = _getUserInitials(userName);
    // Avatar should always be shown for each message now
    final shouldShowAvatar = true;

    return Container(
      margin: EdgeInsets.only(
        bottom: ResponsiveHelper.spacing(context, 4), // Consistent spacing between messages
        top: ResponsiveHelper.spacing(context, 4),
      ),
      child: Row(
        mainAxisAlignment: isLeftSide ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar (LEFT side only)
          if (isLeftSide) ...[
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey[300],
              backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
              child: photoUrl == null
                  ? Text(
                      userInitials,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          
          // Message Bubble
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveHelper.spacing(context, 12),
                vertical: ResponsiveHelper.spacing(context, 8),
              ),
              decoration: BoxDecoration(
                color: isLeftSide 
                    ? Colors.grey[200]
                    : const Color(0xFFDCF8C6),
                borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)), // Uniform rounded corners
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // User name (only for left side)
                  if (isLeftSide) ...[ // Always show username for left side messages
                    Text(
                      userName + (isOwner ? ' (Owner)' : ''),
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: ResponsiveHelper.fontSize(context, mobile: 13, tablet: 14, desktop: 15),
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF8B4513),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  
                  // Display single message content
                  _buildSingleMessageContent(context, message, isLeftSide),
                  
                  // Timestamp
                  const SizedBox(height: 4),
                  Align(
                    alignment: isLeftSide ? Alignment.bottomLeft : Alignment.bottomRight,
                    child: Text(
                      _formatTime(createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: isLeftSide ? Colors.grey[600] : Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Spacing for alignment (RIGHT side)
          if (!isLeftSide) ...[
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  /// Build single message content (for backward compatibility)
  Widget _buildSingleMessageContent(BuildContext context, Map<String, dynamic> msg, bool isLeftSide) {
    var messageText = msg['message'] as String? ?? '';
    if (messageText == null || messageText == 'null') {
      messageText = '';
    }
    final messageType = msg['message_type'] as String? ?? 'text';
    final fileUrl = msg['file_url'] as String?;
    
    if (messageType == 'image' && fileUrl != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: CachedImage(
              imageUrl: fileUrl,
              width: double.infinity,
              height: 150,
              fit: BoxFit.cover,
            ),
          ),
          if (messageText.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              messageText,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ],
        ],
      );
    } else if (messageType == 'file' && fileUrl != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            const Icon(Icons.insert_drive_file, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                messageText.isNotEmpty ? messageText : 'File',
                style: const TextStyle(fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    } else {
      return _buildMessageText(context, messageText);
    }
  }



  bool _shouldShowAvatar(Map<String, dynamic> msg, int index, List<Map<String, dynamic>> groupMessages) {
    return true; // Always show avatar for each message
  }

  Widget _buildMessageInput(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveHelper.spacing(context, 8),
        vertical: ResponsiveHelper.spacing(context, 8),
      ),
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
      child: SafeArea(
          child: Row(
            children: [
              // Emoji button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showEmojiPicker(context),
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.emoji_emotions_outlined,
                      color: const Color(0xFF8B4513),
                      size: 20,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 8),
              
              // Attachment button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showAttachmentOptions(context),
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.attach_file,
                      color: const Color(0xFF8B4513),
                      size: 20,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 8),
              
              // Text input
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 24)),
                  border: Border.all(
                    color: const Color(0xFF8B4513).withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: messageController,
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  // Completely disable autocomplete, suggestions, and autocorrect
                  autocorrect: false,
                  enableSuggestions: false,
                  autofillHints: const [],
                  // Use multiline to avoid keyboard suggestions
                  keyboardType: TextInputType.multiline,
                  // Disable smart quotes and dashes
                  smartDashesType: SmartDashesType.disabled,
                  smartQuotesType: SmartQuotesType.disabled,
                  // Disable text selection suggestions
                  enableInteractiveSelection: true,
                  style: ResponsiveHelper.textStyle(
                    context,
                    fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                    color: const Color(0xFF5F4628),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: ResponsiveHelper.textStyle(
                      context,
                      fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                      color: Colors.grey[500],
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: ResponsiveHelper.spacing(context, 16),
                      vertical: ResponsiveHelper.spacing(context, 10),
                    ),
                  ),
                ),
              ),
            ),
            
            const SizedBox(width: 8),
            
            // Send button
            Obx(() {
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: controller.isSending.value ? null : _sendMessage,
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF8B4513),
                          const Color(0xFF5F4628),
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8B4513).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: controller.isSending.value
                        ? Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                          )
                        : Icon(
                            Icons.send,
                            color: Colors.white,
                            size: 20,
                          ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showAttachmentOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo, color: const Color(0xFF8B4513)),
              title: Text(
                'Photo',
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
                  color: const Color(0xFF5F4628),
                ),
              ),
              onTap: () {
                Get.back();
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: Icon(Icons.camera_alt, color: const Color(0xFF8B4513)),
              title: Text(
                'Camera',
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
                  color: const Color(0xFF5F4628),
                ),
              ),
              onTap: () {
                Get.back();
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await _picker.pickImage(source: source);
      if (image != null) {
        await controller.sendMessage(
          groupId: widget.groupId,
          text: '',
          file: File(image.path),
          messageType: 'image',
        );
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to pick image: $e');
    }
  }

  Future<void> _sendMessage() async {
    final text = messageController.text.trim();
    if (text.isEmpty) return;
    
    
    // Clear input immediately for better UX
    messageController.clear();
    
    final success = await controller.sendMessage(
      groupId: widget.groupId,
      text: text,
    );
    
    if (success) {
      // Wait for UI to update, then scroll to bottom
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted && scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } else {
      // Restore text if sending failed
      messageController.text = text;
    }
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays > 0) {
        return '${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      } else {
        return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      return '';
    }
  }

  void _showEmojiPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: ResponsiveHelper.screenHeight(context) * 0.5,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(ResponsiveHelper.borderRadius(context, mobile: 24)),
            topRight: Radius.circular(ResponsiveHelper.borderRadius(context, mobile: 24)),
          ),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 16)),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey.withOpacity(0.2),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select Emoji',
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: ResponsiveHelper.fontSize(context, mobile: 18, tablet: 20, desktop: 22),
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF8B4513),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF8B4513)),
                    onPressed: () => Get.back(),
                  ),
                ],
              ),
            ),
            // Emoji Grid
            Expanded(
              child: Obx(() {
                if (isLoadingEmojis.value) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF8B4513),
                    ),
                  );
                }
                
                if (availableEmojis.isEmpty) {
                  return Center(
                    child: Text(
                      'No emojis available',
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                        color: Colors.grey[600],
                      ),
                    ),
                  );
                }
                
                return GridView.builder(
                  padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 12)),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: ResponsiveHelper.isMobile(context) ? 6 : ResponsiveHelper.isTablet(context) ? 8 : 10,
                    crossAxisSpacing: ResponsiveHelper.spacing(context, 10),
                    mainAxisSpacing: ResponsiveHelper.spacing(context, 10),
                    childAspectRatio: 1.0,
                  ),
                  itemCount: availableEmojis.length,
                  itemBuilder: (context, index) {
                    final emoji = availableEmojis[index];
                    final emojiChar = emoji['emoji_char'] as String? ?? '';
                    final emojiCode = emoji['code'] as String? ?? '';
                    final emojiName = emoji['name'] as String? ?? '';
                    
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          // WhatsApp/Instagram style: Send emoji directly when selected
                          // Priority: emoji_char > code > id > image_url filename
                          String textToSend;
                          if (emojiChar.isNotEmpty) {
                            textToSend = emojiChar;
                          } else if (emojiCode.isNotEmpty) {
                            textToSend = emojiCode;
                          } else {
                            // Use emoji ID as fallback
                            final emojiId = emoji['id']?.toString() ?? '';
                            if (emojiId.isNotEmpty) {
                              textToSend = emojiId;
                            } else {
                              // Last resort: use image URL filename
                              final imageUrl = emoji['image_url'] as String? ?? '';
                              if (imageUrl.isNotEmpty && imageUrl.contains('/')) {
                                textToSend = imageUrl.split('/').last;
                              } else {
                                textToSend = emojiName; // Use name as last fallback
                              }
                            }
                          }
                          
                          
                          // Close emoji picker
                          Get.back();
                          
                          // Send message directly
                          final success = await controller.sendMessage(
                            groupId: widget.groupId,
                            text: textToSend,
                          );
                          
                          if (success) {
                            // Scroll to bottom after sending
                            Future.delayed(const Duration(milliseconds: 200), () {
                              if (scrollController.hasClients) {
                                scrollController.animateTo(
                                  scrollController.position.maxScrollExtent,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOut,
                                );
                              }
                            });
                          } else {
                            Get.snackbar(
                              'Error',
                              'Failed to send emoji',
                              backgroundColor: Colors.red,
                              colorText: Colors.white,
                              duration: const Duration(seconds: 2),
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
                        splashColor: const Color(0xFF8B4513).withOpacity(0.1),
                        highlightColor: const Color(0xFF8B4513).withOpacity(0.05),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
                            border: Border.all(
                              color: Colors.grey.withOpacity(0.15),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 8)),
                              child: HomeScreen.buildEmojiDisplay(
                                context,
                                emoji,
                                size: ResponsiveHelper.isMobile(context) ? 36 : ResponsiveHelper.isTablet(context) ? 40 : 44,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  /// Build message text with emoji support
  Widget _buildMessageText(BuildContext context, String messageText) {
    final trimmed = messageText.trim();
    
    if (trimmed.isEmpty) {
      return const SizedBox.shrink();
    }
    
    // Check if message contains Unicode emoji characters
    final emojiPattern = RegExp(r'[\u{1F300}-\u{1F9FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]', unicode: true);
    final hasEmojiChar = emojiPattern.hasMatch(messageText);
    
    // For group chat: Only check for emoji codes if message is very short (likely an emoji ID/code)
    // Regular text messages should NOT be matched with emojis
    Map<String, dynamic>? emojiData;
    bool isOnlyEmoji = false;
    
    // Only check for emoji if:
    // 1. Message contains Unicode emoji characters, OR
    // 2. Message is very short (<= 10 chars) and looks like an emoji code/ID (numeric or short code)
    if (hasEmojiChar || (trimmed.length <= 10 && (RegExp(r'^\d+$').hasMatch(trimmed) || trimmed.length <= 5))) {
      emojiData = _findEmojiByText(trimmed);
      isOnlyEmoji = emojiData != null && trimmed.length <= 10 && !hasEmojiChar;
    }
    
    // If message is ONLY an emoji code/ID (no Unicode emoji, very short, and matches an emoji)
    if (isOnlyEmoji && messageText.trim() == trimmed && emojiData != null) {
      return SizedBox(
        width: 48,
        height: 48,
        child: HomeScreen.buildEmojiDisplay(
          context,
          emojiData!,
          size: 48,
        ),
      );
    }
    
    // If message contains Unicode emoji characters, parse and display with emoji images inline
    if (hasEmojiChar) {
      // Message has Unicode emoji characters - parse and display with emoji images
      return RichText(
        text: TextSpan(
          style: ResponsiveHelper.textStyle(
            context,
            fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
            color: Colors.black87,
          ),
          children: _parseMessageWithEmojis(context, messageText),
        ),
      );
    }
    
    // Regular text message - display as plain text (no emoji matching)
    return Text(
      messageText,
      style: ResponsiveHelper.textStyle(
        context,
        fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
        color: Colors.black87,
      ),
    );
  }
  
  /// Find emoji by text (can be character, code, image URL, or ID)
  /// Only called for short messages that might be emoji codes
  Map<String, dynamic>? _findEmojiByText(String text) {
    if (text.isEmpty) return null;
    
    final trimmedText = text.trim();
    // Only log for very short messages (likely emoji codes)
    if (trimmedText.length <= 10) {
    }
    
    for (var emoji in availableEmojis) {
      final emojiChar = emoji['emoji_char'] as String? ?? '';
      final emojiCode = emoji['code'] as String? ?? '';
      final emojiImageUrl = emoji['image_url'] as String? ?? '';
      final emojiId = emoji['id']?.toString() ?? '';
      final emojiName = emoji['name'] as String? ?? '';
      
      // Strategy 1: Match by ID (most reliable for numeric IDs)
      if (emojiId.isNotEmpty && emojiId == trimmedText) {
        return emoji;
      }
      
      // Strategy 2: Match by emoji_char
      if (emojiChar.isNotEmpty && emojiChar.trim() == trimmedText) {
        return emoji;
      }
      
      // Strategy 3: Match by code
      if (emojiCode.isNotEmpty && emojiCode.trim() == trimmedText) {
        return emoji;
      }
      
      // Strategy 4: Match by image_url filename
      if (emojiImageUrl.isNotEmpty) {
        String? textFilename;
        String? urlFilename;
        
        if (trimmedText.contains('/')) {
          textFilename = trimmedText.split('/').last.replaceAll('%20', ' ').toLowerCase();
        } else {
          textFilename = trimmedText.toLowerCase();
        }
        
        if (emojiImageUrl.contains('/')) {
          urlFilename = emojiImageUrl.split('/').last.replaceAll('%20', ' ').toLowerCase();
        } else {
          urlFilename = emojiImageUrl.toLowerCase();
        }
        
        if (textFilename == urlFilename || 
            emojiImageUrl.contains(trimmedText) || 
            trimmedText.contains(emojiImageUrl)) {
          return emoji;
        }
      }
      
      // Strategy 5: Match by name (partial match for filenames)
      if (emojiName.isNotEmpty) {
        final nameLower = emojiName.toLowerCase();
        final textLower = trimmedText.toLowerCase();
        // Check if text is part of emoji name (e.g., "Joy_Pineapple" matches "Joy_Pineapple (1).png")
        if (nameLower.contains(textLower) || textLower.contains(nameLower.replaceAll(' ', '_'))) {
          return emoji;
        }
      }
    }
    return null;
  }

  List<InlineSpan> _parseMessageWithEmojis(BuildContext context, String text) {
    final List<InlineSpan> spans = [];
    final emojiPattern = RegExp(r'[\u{1F300}-\u{1F9FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]', unicode: true);
    
    // Also check for emoji codes (words with underscores like "joy_01", "kindness_peach_01")
    final emojiCodePattern = RegExp(r'\b(joy|peace|love|patience|kindness|goodness|faithfulness|gentleness|meekness|self|control)[_\w]*\b', caseSensitive: false);
    
    int lastIndex = 0;
    
    // Find all potential emoji matches (both Unicode and codes)
    final allMatches = <_EmojiMatch>[];
    
    // Unicode emoji matches
    for (final match in emojiPattern.allMatches(text)) {
      allMatches.add(_EmojiMatch(match.start, match.end, match.group(0)!, isUnicode: true));
    }
    
    // Emoji code matches
    for (final match in emojiCodePattern.allMatches(text)) {
      allMatches.add(_EmojiMatch(match.start, match.end, match.group(0)!, isUnicode: false));
    }
    
    // Sort by position
    allMatches.sort((a, b) => a.start.compareTo(b.start));
    
    // Remove overlapping matches (keep first)
    final nonOverlappingMatches = <_EmojiMatch>[];
    for (var match in allMatches) {
      if (nonOverlappingMatches.isEmpty || match.start >= nonOverlappingMatches.last.end) {
        nonOverlappingMatches.add(match);
      }
    }
    
    // Build spans
    for (final match in nonOverlappingMatches) {
      // Add text before emoji
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
        ));
      }
      
      // Try to find emoji in available emojis
      Map<String, dynamic>? emojiData;
      
      if (match.isUnicode) {
        // Unicode emoji - match by emoji_char
        for (var emoji in availableEmojis) {
          if (emoji['emoji_char'] == match.text) {
            emojiData = emoji;
            break;
          }
        }
      } else {
        // Emoji code - match by code or name
        emojiData = _findEmojiByText(match.text);
      }
      
      if (emojiData != null) {
        // Add emoji as widget span (will be rendered as image)
        spans.add(WidgetSpan(
          child: SizedBox(
            width: 20,
            height: 20,
            child: HomeScreen.buildEmojiDisplay(
              context,
              emojiData,
              size: 20,
            ),
          ),
        ));
      } else {
        // Fallback to text
        spans.add(TextSpan(text: match.text));
      }
      
      lastIndex = match.end;
    }
    
    // Add remaining text
    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex)));
    }
    
    return spans;
  }
}

/// Helper class for emoji matches
class _EmojiMatch {
  final int start;
  final int end;
  final String text;
  final bool isUnicode;
  
  _EmojiMatch(this.start, this.end, this.text, {this.isUnicode = true});
}

