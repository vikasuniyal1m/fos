import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/services/group_chat_service.dart';
import 'package:fruitsofspirit/services/user_storage.dart' as us;
import 'package:fruitsofspirit/services/content_moderation_service.dart';
import 'package:fruitsofspirit/utils/fruit_emoji_helper.dart';

import '../routes/app_pages.dart';
import '../utils/app_theme.dart';

/// Group Chat Controller
/// Manages real-time chat messages
class GroupChatController extends GetxController {
  var messages = <Map<String, dynamic>>[].obs;
  var isLoading = false.obs;
  var isSending = false.obs;
  var message = ''.obs;
  var userId = 0.obs;
  var hasMore = true.obs;
  
  int? currentGroupId;
  int? lastMessageId;
  Timer? _pollingTimer;
  int _lastMessageCount = 0;
  int _currentOffset = 0;

  @override
  void onInit() {
    super.onInit();
    print('🚀 GroupChatController: onInit() called');
    _loadUserId();
  }

  @override
  void onClose() {
    _stopPolling();
    super.onClose();
  }

  Future<void> _loadUserId() async {
    print('🔍 GroupChatController: _loadUserId() called');
    final id = await us.UserStorage.getUserId();
    print('🔍 GroupChatController: Retrieved userId: $id');
    if (id != null) {
      userId.value = id;
      print('✅ GroupChatController: userId set to: ${userId.value}');
    } else {
      print('❌ GroupChatController: userId is null');
    }
  }

  /// Load chat messages
  Future<void> loadMessages(int groupId, {bool refresh = false}) async {
    print('🔄 GroupChatController: loadMessages() called - groupId: $groupId, refresh: $refresh');
    print('🔄 GroupChatController: Current userId: ${userId.value}');
    
    if (userId.value == 0) {
      print('🔄 GroupChatController: userId is 0, loading userId...');
      await _loadUserId();
    }

    if (userId.value == 0) {
      print('❌ GroupChatController: userId is still 0 after loading');
      message.value = 'Please login first';
      return;
    }

    // If switching to a different group, clear messages and reset
    if (currentGroupId != null && currentGroupId != groupId) {
      _stopPolling(); // Stop polling for previous group
      messages.value = [];
      messages.refresh();
      lastMessageId = null;
      hasMore.value = true;
      _lastMessageCount = 0;
      _currentOffset = 0;
    }

    if (isLoading.value && !refresh) return;

    // Always clear messages on refresh to force fresh load from backend
    if (refresh) {
      messages.value = [];
      messages.refresh();
      lastMessageId = null;
      _currentOffset = 0;
    }

    isLoading.value = true;
    currentGroupId = groupId;
    message.value = '';

    try {
      print('📡 GroupChatController: Calling GroupChatService.getChatMessages...');
      // Always fetch from backend - no local caching
      // Force fresh data by always using refresh=true behavior
      final chatMessages = await GroupChatService.getChatMessages(
        groupId: groupId,
        userId: userId.value,
        limit: 50,
        offset: _currentOffset, // Always start from beginning
        lastMessageId: null, // Always fetch fresh - no pagination
      );
      print('📡 GroupChatController: Received ${chatMessages.length} messages from service');

      // Ensure all messages have the correct group_id and handle null message text
      final filteredMessages = chatMessages.map((msg) {
        // Ensure group_id is set as int (not string)
        if (msg['group_id'] == null) {
          msg['group_id'] = groupId;
        } else {
          // Convert to int if it's a string
          final groupIdValue = msg['group_id'];
          if (groupIdValue is String) {
            msg['group_id'] = int.tryParse(groupIdValue) ?? groupId;
          } else if (groupIdValue is! int) {
            msg['group_id'] = groupId;
          }
        }
        // Handle null or empty message text - convert to empty string
        if (msg['message'] == null || msg['message'] == 'null') {
          msg['message'] = '';
        }

        // Ensure message_type is correctly identified as 'emoji' for fruit/URL messages
        final content = msg['message']?.toString() ?? '';
        final mType = msg['message_type']?.toString();
        if ((mType == null || mType == 'text') && FruitEmojiHelper.isFruit(content)) {
          msg['message_type'] = 'emoji';
        }
        return msg;
      }).toList();

      // Always replace messages on refresh, append on load more
      if (refresh) {
        // Create completely new list instance to ensure GetX detects change
        messages.value = [];
        messages.refresh();
        await Future.delayed(const Duration(milliseconds: 50));
        // Create deep copy to ensure GetX detects change
        messages.value = filteredMessages.map((msg) => Map<String, dynamic>.from(msg)).toList();
      } else {
        // Check for duplicates before adding
        final existingMessageIds = messages.map((m) => m['id'].toString()).toSet();
        final newMessages = filteredMessages.where((msg) => !existingMessageIds.contains(msg['id'].toString())).toList();
        if (newMessages.isNotEmpty) {
          messages.insertAll(0, newMessages);
          print('🔄 GroupChatController: Added ${newMessages.length} new messages, skipped ${filteredMessages.length - newMessages.length} duplicates');
        }
      }
      
      _currentOffset += filteredMessages.length;
      
      messages.refresh();

      if (filteredMessages.isNotEmpty) {
        // Find the newest message ID in the batch
        final newestId = filteredMessages.map((m) {
          final idValue = m['id'];
          if (idValue is int) return idValue;
          if (idValue is String) return int.tryParse(idValue) ?? 0;
          return 0;
        }).reduce((a, b) => a > b ? a : b);
        
        // Only update lastMessageId if it's the first load or if the new ID is larger
        if (lastMessageId == null || newestId > lastMessageId!) {
          lastMessageId = newestId;
        }
      }

      hasMore.value = filteredMessages.length >= 50;
      
      // Start polling for new messages if message count changed
      if (_lastMessageCount != filteredMessages.length) {
        _lastMessageCount = filteredMessages.length;
        _startPolling(groupId);
      }
    } catch (e) {
      print('❌ GroupChatController: Error in loadMessages: $e');
      print('❌ GroupChatController: Stack trace: ${StackTrace.current}');
      message.value = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
    } finally {
      print('✅ GroupChatController: loadMessages() completed, isLoading set to false');
      isLoading.value = false;
    }
  }

  /// Start polling for new messages
  void _startPolling(int groupId) {
    _stopPolling(); // Stop any existing timer
    
    // Poll every 3 seconds for new messages
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (currentGroupId == groupId && !isLoading.value && !isSending.value) {
        _checkForNewMessages(groupId);
      }
    });
  }

  /// Stop polling for new messages
  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  /// Private method for internal use
  void _stopPolling() {
    stopPolling();
  }

  /// Sync new messages from database (incremental update, no refresh)
  Future<void> _checkForNewMessages(int groupId) async {
    if (userId.value == 0 || currentGroupId != groupId || isLoading.value) {
      return;
    }

    try {
      // Fetch only new messages (after lastMessageId) - incremental sync
      final chatMessages = await GroupChatService.getChatMessages(
        groupId: groupId,
        userId: userId.value,
        limit: 50,
        offset: 0,
        lastMessageId: lastMessageId,
        syncNew: true, // Fetch new messages after lastMessageId
      );

      if (chatMessages.isEmpty) {
        return;
      }

      // Process and add only new messages
      final newMessages = chatMessages.map((msg) {
        // Ensure group_id is set as int
        if (msg['group_id'] == null) {
          msg['group_id'] = groupId;
        } else {
          final groupIdValue = msg['group_id'];
          if (groupIdValue is String) {
            msg['group_id'] = int.tryParse(groupIdValue) ?? groupId;
          } else if (groupIdValue is! int) {
            msg['group_id'] = groupId;
          }
        }
        // Handle null message text
        if (msg['message'] == null || msg['message'] == 'null') {
          msg['message'] = '';
        }

        // Ensure message_type is correctly identified as 'emoji' for fruit/URL messages
        final content = msg['message']?.toString() ?? '';
        final mType = msg['message_type']?.toString();
        if ((mType == null || mType == 'text') && FruitEmojiHelper.isFruit(content)) {
          msg['message_type'] = 'emoji';
        }
        return msg;
      }).toList();

      // Get existing message IDs to avoid duplicates - check both msg_id and id
      final existingIds = <String>{};
      for (var m in messages) {
        if (m['msg_id'] != null) {
          existingIds.add(m['msg_id'].toString());
        }
        if (m['id'] != null) {
          existingIds.add(m['id'].toString());
        }
      }
      
      // Filter out messages that already exist
      final trulyNewMessages = newMessages.where((msg) {
        final msgMsgId = msg['msg_id']?.toString();
        final msgId = msg['id']?.toString();
        
        // If message has msg_id, check against existing msg_ids
        if (msgMsgId != null && existingIds.contains(msgMsgId)) {
          return false;
        }
        
        // If message has id, check against existing ids
        if (msgId != null && existingIds.contains(msgId)) {
          return false;
        }
        
        // Additional check: compare message content and timestamp to catch any edge cases
        final msgContent = msg['message']?.toString() ?? '';
        final msgTime = msg['created_at']?.toString() ?? '';
        
        for (var existingMsg in messages) {
          final existingContent = existingMsg['message']?.toString() ?? '';
          final existingTime = existingMsg['created_at']?.toString() ?? '';
          
          // If same content and very similar timestamp (within 1 second), consider it duplicate
          if (msgContent == existingContent && msgTime.isNotEmpty && existingTime.isNotEmpty) {
            try {
              final msgDateTime = DateTime.parse(msgTime);
              final existingDateTime = DateTime.parse(existingTime);
              final difference = msgDateTime.difference(existingDateTime).inSeconds;
              
              if (difference.abs() <= 1) {
                return false; // Likely duplicate
              }
            } catch (e) {
              // If parsing fails, skip this check
            }
          }
        }
        
        // Message is truly new
        return true;
      }).toList();

      if (trulyNewMessages.isNotEmpty) {
        // Add new messages to the end (newest messages)
        messages.addAll(trulyNewMessages);
        messages.refresh(); // Update UI
        
        // Update lastMessageId to the newest message
        final newestId = trulyNewMessages.map((m) {
          final idVal = m['id'];
          if (idVal is int) return idVal;
          if (idVal is String) return int.tryParse(idVal) ?? 0;
          return 0;
        }).reduce((a, b) => a > b ? a : b);
        
        if (newestId > (lastMessageId ?? 0)) {
          lastMessageId = newestId;
        }
        _lastMessageCount = messages.length;
      }
    } catch (e) {
      // Silently fail - don't show error for polling
    }
  }

  /// Send message
  Future<bool> sendMessage({
    required int groupId,
    required String text,
    File? file,
    String messageType = 'text',
  }) async {
    // If text is a fruit emoji, automatically set messageType to 'emoji'
    final textTrimmed = text.trim();
    if (messageType == 'text' && textTrimmed.isNotEmpty) {
      if (FruitEmojiHelper.isFruit(textTrimmed) || textTrimmed.length <= 2) {
        // Checking for Unicode emojis as well
        final emojiRegex = RegExp(
          r'[\u{1F300}-\u{1F9FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]|[\u{1F600}-\u{1F64F}]|[\u{1F680}-\u{1F6FF}]|[\u{2764}\u{FE0F}]|[\u{2728}]|[\u{2B50}]',
          unicode: true,
        );
        if (emojiRegex.hasMatch(textTrimmed) || FruitEmojiHelper.isFruit(textTrimmed)) {
          messageType = 'emoji';
        }
      }
    }

    if (userId.value == 0) {
      await _loadUserId();
    }

    if (userId.value == 0) {
      message.value = 'Please login first';
      return false;
    }

    if (text.trim().isEmpty && file == null) {
      message.value = 'Message cannot be empty';
      return false;
    }

    // Check for inappropriate content (only for text messages)
    if (text.trim().isNotEmpty) {
      final moderationCheck = ContentModerationService.checkContent(text);
      if (!moderationCheck['isClean']) {
        message.value = moderationCheck['message'];
        final ctx = Get.context;
        if (ctx != null) {
          ScaffoldMessenger.of(ctx).hideCurrentSnackBar();
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: Icon(Icons.security_rounded, color: Color(0xFFC79211), size: 28),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Community Guidelines', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        Text(moderationCheck['message'], style: const TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF5D4037),
              duration: const Duration(seconds: 5),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
        
        return false;
      }
    }

    isSending.value = true;
    message.value = '';

    try {
      final sentMessage = await GroupChatService.sendMessage(
        userId: userId.value,
        groupId: groupId,
        message: text.trim(),
        messageType: messageType,
        file: file,
      );
      
      // Extract flattened message from messages_list if it exists (to match backend format)
      Map<String, dynamic> flattenedMessage = sentMessage;
      
      // If sentMessage has messages_list, extract the first message from it (since we always have one message per row now)
      if (sentMessage.containsKey('messages_list') && sentMessage['messages_list'] != null) {
        final messagesList = sentMessage['messages_list'];
        if (messagesList is List && messagesList.isNotEmpty) {
          final firstMessage = messagesList[0];
          if (firstMessage is Map<String, dynamic>) {
            // Create flattened message using the individual message data
            flattenedMessage = {
              'id': sentMessage['id'],
              'msg_id': firstMessage['msg_id'],
              'user_id': sentMessage['user_id'],
              'user_name': sentMessage['user_name'],
              'profile_photo': sentMessage['profile_photo'],
              'group_id': groupId,
              'message': firstMessage['text'] ?? sentMessage['message'] ?? '',
              'message_type': firstMessage['message_type'] ?? sentMessage['message_type'] ?? 'text',
              'file_url': firstMessage['file_url'] ?? sentMessage['file_url'],
              'created_at': firstMessage['time'] ?? sentMessage['created_at'] ?? DateTime.now().toString(),
              'status': sentMessage['status'] ?? 'active'
            };
          }
        }
      } else {
        // Ensure basic fields are set if no messages_list
        flattenedMessage['group_id'] = groupId;
        flattenedMessage['user_id'] = userId.value;
        flattenedMessage['msg_id'] = flattenedMessage['msg_id'] ?? 'msg_' + flattenedMessage['id'].toString() + '_' + DateTime.now().millisecondsSinceEpoch.toString();
      }

      // Ensure message text is present
      if ((flattenedMessage['message'] == null || flattenedMessage['message'] == '' || flattenedMessage['message'] == 'null')) {
        flattenedMessage['message'] = flattenedMessage['text'] ?? '';
      }

      // Ensure message_type is correctly identified as 'emoji' for fruit/URL messages
      final content = flattenedMessage['message']?.toString() ?? '';
      final mType = flattenedMessage['message_type']?.toString();
      if ((mType == null || mType == 'text') && FruitEmojiHelper.isFruit(content)) {
        flattenedMessage['message_type'] = 'emoji';
      }

      // Ensure timestamp is present
      if (flattenedMessage['created_at'] == null) {
        flattenedMessage['created_at'] = flattenedMessage['time'] ?? DateTime.now().toString();
      }

      // Add current user info to the message so it displays correctly immediately
      try {
        final user = await us.UserStorage.getUser();
        if (user != null) {
          flattenedMessage['user_name'] = user['name'];
          flattenedMessage['profile_photo'] = user['profile_photo'];
        }
      } catch (e) {
        print('Error adding user info to sent message: $e');
      }
      
      // Handle different ID fields returned by backend (id, msg_id)
      final rawId = flattenedMessage['id'] ?? flattenedMessage['msg_id'];
      int? sentMessageId;
      if (rawId is int) {
        sentMessageId = rawId;
      } else if (rawId is String) {
        sentMessageId = int.tryParse(rawId);
      }

      // Map msg_id to id for consistency if id is missing
      if (flattenedMessage['id'] == null && rawId != null) {
        flattenedMessage['id'] = rawId;
      }
      
      // Prevent duplicates in the local list
      final existingMsgIds = <String>{};
      for (var m in messages) {
        if (m['msg_id'] != null) {
          existingMsgIds.add(m['msg_id'].toString());
        }
        if (m['id'] != null) {
          existingMsgIds.add(m['id'].toString());
        }
      }
      
      final currentMsgId = flattenedMessage['msg_id']?.toString() ?? flattenedMessage['id']?.toString();
      
      if (currentMsgId != null && !existingMsgIds.contains(currentMsgId)) {
        // Add the newly sent message to the end (newest messages at bottom)
        messages.add(flattenedMessage);
        messages.refresh();
        
        // Update lastMessageId immediately to prevent polling from fetching the same message
        if (sentMessageId != null && sentMessageId > (lastMessageId ?? 0)) {
          lastMessageId = sentMessageId;
        }
      }
      
      // Don't check for new messages immediately after sending
      // This prevents the same message from being fetched again and causing duplicates
      // await _checkForNewMessages(groupId); // REMOVED TO PREVENT DUPLICATES
      
      // Temporarily pause polling to prevent race condition
      _stopPolling();
      // Restart polling after a short delay to allow the message to be fully processed
      Future.delayed(const Duration(seconds: 5), () {
        if (currentGroupId == groupId) {
          _startPolling(groupId);
        }
      });

      return true;
    } catch (e) {
      final errorMsg = e.toString().replaceAll('Exception: ', '');
      final isModeration = errorMsg.contains('community guidelines');
      message.value = 'Error: $errorMsg';
      final ctx = Get.context;
      if (ctx != null) {
        ScaffoldMessenger.of(ctx).hideCurrentSnackBar();
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Icon(
                    isModeration ? Icons.security_rounded : Icons.info_outline,
                    color: isModeration ? const Color(0xFFC79211) : Colors.white,
                    size: 28,
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isModeration ? 'Community Guidelines' : 'Notice', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      Text(errorMsg, style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: isModeration ? const Color(0xFF5D4037) : Colors.grey[800],
            duration: Duration(seconds: isModeration ? 5 : 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
      return false;
    } finally {
      isSending.value = false;
    }
  }

  /// Refresh messages
  Future<void> refresh() async {
    if (currentGroupId != null) {
      lastMessageId = null;
      await loadMessages(currentGroupId!, refresh: true);
    }
  }

  /// Load more messages (pagination)
  Future<void> loadMore() async {
    if (currentGroupId != null && hasMore.value && !isLoading.value) {
      await loadMessages(currentGroupId!);
    }
  }

  /// Sync new messages from database (called after sending message)
  Future<void> _syncNewMessages(int groupId) async {
    if (userId.value == 0 || currentGroupId != groupId) {
      return;
    }

    try {
      // Fetch only new messages after lastMessageId
      final chatMessages = await GroupChatService.getChatMessages(
        groupId: groupId,
        userId: userId.value,
        limit: 50,
        offset: 0,
        lastMessageId: lastMessageId,
        syncNew: true, // Fetch new messages after lastMessageId
      );

      if (chatMessages.isEmpty) {
        return;
      }

      // Process new messages
      final newMessages = chatMessages.map((msg) {
        if (msg['group_id'] == null) {
          msg['group_id'] = groupId;
        } else {
          final groupIdValue = msg['group_id'];
          if (groupIdValue is String) {
            msg['group_id'] = int.tryParse(groupIdValue) ?? groupId;
          } else if (groupIdValue is! int) {
            msg['group_id'] = groupId;
          }
        }
        if (msg['message'] == null || msg['message'] == 'null') {
          msg['message'] = '';
        }
        return msg;
      }).toList();

      // Get existing message IDs
      final existingIds = messages.map((m) {
        final idVal = m['id'];
        if (idVal is int) return idVal;
        if (idVal is String) return int.tryParse(idVal) ?? 0;
        return 0;
      }).toSet();
      
      // Add only truly new messages
      final trulyNewMessages = newMessages.where((msg) {
        final msgId = msg['id'] as int?;
        return msgId != null && !existingIds.contains(msgId);
      }).toList();

      if (trulyNewMessages.isNotEmpty) {
        messages.addAll(trulyNewMessages);
        messages.refresh();
        
        // Update lastMessageId
        final newestId = trulyNewMessages.map((m) {
          final idVal = m['id'];
          if (idVal is int) return idVal;
          if (idVal is String) return int.tryParse(idVal) ?? 0;
          return 0;
        }).reduce((a, b) => a > b ? a : b);
        
        if (newestId > (lastMessageId ?? 0)) {
          lastMessageId = newestId;
        }
        _lastMessageCount = messages.length;
      }
    } catch (e) {
      // Silently fail
    }
  }
}
