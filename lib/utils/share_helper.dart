import 'dart:async';
import 'dart:io';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:fruitsofspirit/services/advanced_service.dart';
import 'package:fruitsofspirit/services/user_storage.dart';
import 'package:fruitsofspirit/services/deep_link_service.dart';
import 'package:fruitsofspirit/utils/image_helper.dart';
import 'package:flutter/material.dart';

class ShareHelper {
  static Future<void> shareContent({
    required String contentType,
    required int contentId,
    required String title,
    String? content,
    String? mediaUrl,
    required BuildContext context,
  }) async {
    final shareText = _buildShareText(
      contentType: contentType,
      contentId: contentId,
      title: title,
      content: content,
    );
    final sharePositionOrigin = _sharePositionOrigin(context);

    unawaited(_trackShare(contentType, contentId));

    try {
      final resolvedMediaUrl = _resolveShareMediaUrl(mediaUrl);
      if (resolvedMediaUrl != null && resolvedMediaUrl.isNotEmpty) {
        final filePath = await _resolveMediaFile(resolvedMediaUrl);
        if (filePath != null) {
          await Share.shareXFiles(
            [XFile(filePath, mimeType: _mimeTypeForPath(filePath))],
            text: shareText,
            sharePositionOrigin: sharePositionOrigin,
          );
          return;
        }
      }

      await Share.share(
        shareText,
        sharePositionOrigin: sharePositionOrigin,
      );
    } catch (e) {
      print('Error sharing content: $e');
      await Share.share(
        shareText,
        sharePositionOrigin: sharePositionOrigin,
      );
    }
  }

  static String _buildShareText({
    required String contentType,
    required int contentId,
    required String title,
    String? content,
  }) {
    final shareLink = DeepLinkService.generateLink(contentType, id: contentId);
    final emoji = _getEmojiForType(contentType);
    final cleanContent = content != null && content.trim().isNotEmpty
        ? (content.length > 150 ? '${content.substring(0, 147)}...' : content)
        : '';

    final buffer = StringBuffer('$emoji $title');
    if (cleanContent.isNotEmpty) {
      buffer.writeln('\n\n"$cleanContent"');
    }
    buffer.writeln('\n\nOpen in Fruits of the Spirit:');
    buffer.write(shareLink);
    return buffer.toString();
  }

  static Future<void> _trackShare(String contentType, int contentId) async {
    try {
      final userId = await UserStorage.getUserId() ?? 0;
      await AdvancedService.shareContent(
        userId: userId,
        contentType: contentType,
        contentId: contentId,
      );
    } catch (e) {
      print('Analytics tracking failed: $e');
    }
  }

  static Rect? _sharePositionOrigin(BuildContext context) {
    try {
      final renderObject = context.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) return null;
      final offset = renderObject.localToGlobal(Offset.zero);
      final size = renderObject.size;
      return Rect.fromLTWH(offset.dx, offset.dy, size.width, size.height);
    } catch (_) {
      return null;
    }
  }

  static String? _resolveShareMediaUrl(String? mediaUrl) {
    if (mediaUrl == null || mediaUrl.trim().isEmpty) return null;
    final trimmed = mediaUrl.trim();
    if (trimmed.contains('/api/') || trimmed.contains('.php')) {
      return null;
    }
    return ImageHelper.resolveMediaPath(trimmed);
  }

  static String? _mimeTypeForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  static String _getEmojiForType(String type) {
    switch (type.toLowerCase()) {
      case 'prayer':
        return '🙏';
      case 'blog':
        return '📖';
      case 'video':
        return '🎥';
      case 'photo':
        return '📸';
      case 'story':
        return '🎬';
      case 'testimony':
        return '✨';
      default:
        return '🌟';
    }
  }

  /// Uses image cache first (instant if already on screen), then downloads.
  static Future<String?> _resolveMediaFile(String url) async {
    try {
      final cached = await DefaultCacheManager()
          .getFileFromCache(url)
          .timeout(const Duration(seconds: 1));
      if (cached != null && await cached.file.exists()) {
        return cached.file.path;
      }
    } catch (_) {}

    try {
      final file = await DefaultCacheManager()
          .getSingleFile(url)
          .timeout(const Duration(seconds: 8));
      if (await file.exists()) return file.path;
    } catch (e) {
      print('Cache manager download failed: $e');
    }

    return _downloadFile(url);
  }

  static Future<String?> _downloadFile(String url) async {
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final directory = await getTemporaryDirectory();
        var fileName = url.split('/').last.split('?').first;
        if (!fileName.contains('.')) fileName = '$fileName.jpg';
        final file = File('${directory.path}/share_$fileName');
        await file.writeAsBytes(response.bodyBytes);
        return file.path;
      }
    } catch (e) {
      print('Error downloading file: $e');
    }
    return null;
  }

  static Future<void> shareText(String text, BuildContext context) async {
    await Share.share(
      text,
      sharePositionOrigin: _sharePositionOrigin(context),
    );
  }
}
