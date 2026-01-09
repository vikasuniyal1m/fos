import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/services/group_chat_service.dart';
import 'package:fruitsofspirit/services/user_storage.dart';

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
      
      // Force UI update - create new list instance
      final currentMessages = List<Map<String, dynamic>>.from(messages);
      messages.value = [];
      await Future.delayed(const Duration(milliseconds: 10));
      messages.value = currentMessages;
      messages.refresh();

      if (filteredMessages.isNotEmpty) {
        lastMessageId = filteredMessages.first['id'] as int?;
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
      final existingIds = messages.map((m) => m['id'] as int).toSet();
      
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
        final newestId = trulyNewMessages.map((m) => m['id'] as int).reduce((a, b) => a > b ? a : b);
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
      
      // Ensure sent message has correct group_id and handle null message
      sentMessage['group_id'] = groupId;
      sentMessage['user_id'] = userId.value;
      // Handle null message text - ensure it's not null
      if (sentMessage['message'] == null || sentMessage['message'] == 'null') {
        sentMessage['message'] = '';
      }
      
      // Small delay to ensure backend has processed the message
      await Future.delayed(const Duration(milliseconds: 800));
      
      // Force refresh messages to get the latest grouped messages from backend
      // Clear first to ensure fresh load
      messages.value = [];
      messages.refresh();
      
      // Load fresh messages
      await loadMessages(groupId, refresh: true);
      
      // Additional refresh to ensure UI updates
      await Future.delayed(const Duration(milliseconds: 200));
      messages.refresh();
      
      // Force one more refresh after a short delay
      await Future.delayed(const Duration(milliseconds: 300));
      messages.refresh();

      return true;
    } catch (e) {
      message.value = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      Get.snackbar(
        'Error',
        'Failed to send message: ${e.toString().replaceAll('Exception: ', '')}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
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
      final existingIds = messages.map((m) => m['id'] as int).toSet();
      
      // Add only truly new messages
      final trulyNewMessages = newMessages.where((msg) {
        final msgId = msg['id'] as int?;
        return msgId != null && !existingIds.contains(msgId);
      }).toList();

      if (trulyNewMessages.isNotEmpty) {
        messages.addAll(trulyNewMessages);
        messages.refresh();
        
        // Update lastMessageId
        final newestId = trulyNewMessages.map((m) => m['id'] as int).reduce((a, b) => a > b ? a : b);
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