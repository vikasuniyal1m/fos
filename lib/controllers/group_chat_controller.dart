import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/services/group_chat_service.dart';
import 'package:fruitsofspirit/services/user_storage.dart';
import 'package:fruitsofspirit/services/content_moderation_service.dart';
import 'package:fruitsofspirit/utils/fruit_emoji_helper.dart';

import '../routes/app_pages.dart';

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
    _loadUserId();
  }

  @override
  void onClose() {
    _stopPolling();
    super.onClose();
  }

  Future<void> _loadUserId() async {
    final id = await UserStorage.getUserId();
    if (id != null) {
      userId.value = id;
    }
  }

  /// Load chat messages
  Future<void> loadMessages(int groupId, {bool refresh = false}) async {
    if (userId.value == 0) {
      await _loadUserId();
    }

    if (userId.value == 0) {
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
      // Always fetch from backend - no local caching
      // Force fresh data by always using refresh=true behavior
      final chatMessages = await GroupChatService.getChatMessages(
        groupId: groupId,
        userId: userId.value,
        limit: 50,
        offset: _currentOffset, // Always start from beginning
        lastMessageId: null, // Always fetch fresh - no pagination
      );

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
        messages.insertAll(0, filteredMessages);
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
      message.value = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
    } finally {
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
        return msg;
      }).toList();

      // Get existing message IDs to avoid duplicates
      final existingIds = messages.map((m) {
        final idVal = m['id'];
        if (idVal is int) return idVal;
        if (idVal is String) return int.tryParse(idVal) ?? 0;
        return 0;
      }).toSet();
      
      // Filter out messages that already exist
      final trulyNewMessages = newMessages.where((msg) {
        final msgId = msg['id'] as int?;
        return msgId != null && !existingIds.contains(msgId);
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
        
        // Show user-friendly error
        Get.snackbar(
          'Community Guidelines',
          'Your message contains inappropriate content. Please revise and try again.',
          backgroundColor: const Color(0xFF5D4037),
          colorText: Colors.white,
          icon: const Icon(
            Icons.security_rounded,
            color: Color(0xFFC79211),
            size: 28,
          ),
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 4),
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
          mainButton: TextButton(
            onPressed: () => Get.toNamed(Routes.TERMS),
            child: const Text(
              'VIEW TERMS',
              style: TextStyle(
                color: Color(0xFFC79211),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
        
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
      
      sentMessage['group_id'] = groupId;
      sentMessage['user_id'] = userId.value;
      if ((sentMessage['message'] == null || sentMessage['message'] == '' || sentMessage['message'] == 'null') &&
          sentMessage['text'] != null &&
          sentMessage['text'] is String &&
          (sentMessage['text'] as String).trim().isNotEmpty) {
        sentMessage['message'] = (sentMessage['text'] as String).trim();
      }
      if (sentMessage['created_at'] == null && sentMessage['time'] != null) {
        sentMessage['created_at'] = sentMessage['time'];
      }
      if (sentMessage['message'] == null || sentMessage['message'] == 'null') {
        sentMessage['message'] = '';
      }
      
      // Check if message already exists (prevent duplicates)
      final sentMsgId = sentMessage['id'];
      int? sentMessageId;
      if (sentMsgId is int) {
        sentMessageId = sentMsgId;
      } else if (sentMsgId is String) {
        sentMessageId = int.tryParse(sentMsgId);
      }
      
      // Only add if message doesn't already exist
      final existingIds = messages.map((m) {
        final idVal = m['id'];
        if (idVal is int) return idVal;
        if (idVal is String) return int.tryParse(idVal) ?? 0;
        return 0;
      }).toSet();
      
      if (sentMessageId != null && !existingIds.contains(sentMessageId)) {
        // Add the newly sent message to the list
        messages.add(sentMessage);
        messages.refresh();
        
        // Update lastMessageId if this is the newest message
        if (sentMessageId > (lastMessageId ?? 0)) {
          lastMessageId = sentMessageId;
        }
      }
      
      // Check for any other new messages that might have arrived
      await _checkForNewMessages(groupId);

      return true;
    } catch (e) {
      final errorMsg = e.toString().replaceAll('Exception: ', '');
      final isModeration = errorMsg.contains('community guidelines');
      message.value = 'Error: $errorMsg';
      
      Get.snackbar(
        isModeration ? 'Community Standard' : 'Notice',
        errorMsg,
        backgroundColor: isModeration ? const Color(0xFF5D4037) : Colors.grey[800],
        colorText: Colors.white,
        icon: Icon(
          isModeration ? Icons.security_rounded : Icons.info_outline,
          color: isModeration ? const Color(0xFFC79211) : Colors.white,
          size: 28,
        ),
        snackPosition: SnackPosition.BOTTOM,
        duration: Duration(seconds: isModeration ? 5 : 3),
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        mainButton: isModeration ? TextButton(
          onPressed: () => Get.toNamed(Routes.TERMS),
          child: const Text('VIEW TERMS', style: TextStyle(color: Color(0xFFC79211), fontWeight: FontWeight.bold)),
        ) : null,
      );
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
