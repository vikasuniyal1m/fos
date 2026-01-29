import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:fruitsofspirit/services/advanced_service.dart';
import 'package:fruitsofspirit/services/user_storage.dart';
import 'package:fruitsofspirit/services/deep_link_service.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';

class ShareHelper {
  static Future<void> shareContent({
    required String contentType,
    required int contentId,
    required String title,
    String? content,
    String? mediaUrl,
  }) async {
    try {
      // Show a non-blocking loading indicator if downloading media
      if (mediaUrl != null && mediaUrl.isNotEmpty) {
        Get.rawSnackbar(
          message: 'Preparing share...',
          duration: const Duration(seconds: 2),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.black87,
          snackStyle: SnackStyle.FLOATING,
        );
      }

      final userId = await UserStorage.getUserId() ?? 0;
      
      // Track share action with API
      try {
        await AdvancedService.shareContent(
          userId: userId,
          contentType: contentType,
          contentId: contentId,
        );
      } catch (e) {
        print('Analytics tracking failed: $e');
      }

      // Generate the official Deep Link using our service
      final shareLink = DeepLinkService.generateLink(contentType, id: contentId);
      
      // Professional formatting with quotes and emojis
      String emoji = _getEmojiForType(contentType);
      final cleanContent = content != null && content.trim().isNotEmpty 
          ? (content.length > 150 ? '${content.substring(0, 147)}...' : content)
          : "";
      
      String shareText = '$emoji $title\n';
      if (cleanContent.isNotEmpty) {
        shareText += '\n"$cleanContent"\n';
      }
      shareText += '\n🔗 Open in App:\n$shareLink';
      
      if (mediaUrl != null && mediaUrl.isNotEmpty) {
        final filePath = await _downloadFile(mediaUrl);
        if (filePath != null) {
          // Sharing as XFile allows platforms like Instagram to show Feed/Stories options properly
          await Share.shareXFiles([XFile(filePath)], text: shareText);
          return;
        }
      }
      
      await Share.share(shareText);
    } catch (e) {
      print('Error sharing content: $e');
      final fallbackLink = 'https://fruitofthespirit.templateforwebsites.com/share/$contentType/$contentId';
      await Share.share('$title\n\nCheck this out on Fruits of Spirit:\n$fallbackLink');
    }
  }

  static String _getEmojiForType(String type) {
    switch (type.toLowerCase()) {
      case 'prayer': return '🙏';
      case 'blog': return '📖';
      case 'video': return '🎥';
      case 'photo': return '📸';
      case 'story': return '🎬';
      case 'testimony': return '✨';
      default: return '🌟';
    }
  }

  static Future<String?> _downloadFile(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final directory = await getTemporaryDirectory();
        final fileName = url.split('/').last.split('?').first;
        final file = File('${directory.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);
        return file.path;
      }
    } catch (e) {
      print('Error downloading file: $e');
    }
    return null;
  }

  static Future<void> shareText(String text) async {
    await Share.share(text);
  }
}
