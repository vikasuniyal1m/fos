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
import 'package:fruitsofspirit/services/user_storage.dart';
import 'dart:io';

/// Group Chat / Community Screen
/// Shows real-time chat messages (WhatsApp style) OR group posts (Facebook style)
class GroupChatScreen extends StatefulWidget {
  final int groupId;
  final bool useRealChat; // Toggle between real chat and posts
  
  const GroupChatScreen({
    Key? key,
    required this.groupId,
    this.useRealChat = true, // Default to real chat
  }) : super(key: key);
  
  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
  
  /// Show a custom snackbar using ScaffoldMessenger
  void _showCustomSnackbar(BuildContext context, String title, String message, {bool isError = false}) {
    if (!context.mounted) return;
    
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
        backgroundColor: isModeration ? const Color(0xFF5D4037) : (isError ? Colors.red : Colors.green),
        duration: isModeration ? const Duration(seconds: 5) : const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  String? userEmail;

  @override
  void initState() {
    super.initState();
    _loadUserEmail();
    print('🚀 _GroupChatScreenState: initState() called for groupId: ${widget.groupId}');
    print('🚀 _GroupChatScreenState: useRealChat: ${widget.useRealChat}');
  }

  Future<void> _loadUserEmail() async {
    userEmail = await UserStorage.getUserEmail();
  }

  @override
  Widget build(BuildContext context) {
    print('🏗️ _GroupChatScreenState: build() called');
    print('🏗️ _GroupChatScreenState: widget.useRealChat: ${widget.useRealChat}');
    print('🏗️ _GroupChatScreenState: widget.groupId: ${widget.groupId}');
    
    // If real chat is enabled, show WhatsApp-style chat
    if (widget.useRealChat) {
      print('📱 _GroupChatScreenState: Building real-time chat interface');
      GroupsController groupsController;
      try {
        groupsController = Get.find<GroupsController>();
        print('✅ _GroupChatScreenState: GroupsController found');
      } catch (e) {
        print('⚠️ _GroupChatScreenState: GroupsController not found, creating new one: $e');
        groupsController = Get.put(GroupsController());
      }
      
      final groupName = groupsController.selectedGroup['name'] as String? ?? 'Group Chat';
      print('📝 _GroupChatScreenState: groupName: $groupName');

      print('🔄 _GroupChatScreenState: Calling RealGroupChatScreen...');
      return RealGroupChatScreen(
        groupId: widget.groupId,
        groupName: groupName,
        userEmail: userEmail,
      );
    }
    
    // Otherwise show Facebook-style posts
    print('📄 _GroupChatScreenState: Building posts interface');
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Group ${widget.groupId}'),
        backgroundColor: const Color(0xFF8B4513),
      ),
      body: const Center(
        child: Text(
          'Posts functionality - Debug mode',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ),
    );
  }
}
