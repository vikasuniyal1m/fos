import 'dart:async';
import 'dart:convert';

import 'package:fruitsofspirit/controllers/blogs_controller.dart';
import 'package:fruitsofspirit/controllers/gallery_controller.dart';
import 'package:fruitsofspirit/controllers/prayers_controller.dart';
import 'package:fruitsofspirit/controllers/shorts_controller.dart';
import 'package:fruitsofspirit/controllers/videos_controller.dart';
import 'package:fruitsofspirit/routes/routes.dart';
import 'package:fruitsofspirit/services/payment_gate.dart';
import 'package:fruitsofspirit/services/shorts_service.dart';
import 'package:fruitsofspirit/services/user_storage.dart';
import 'package:get/get.dart';

/// Routes in-app notifications to the correct screen (prayer/blog/video/etc.).
class NotificationRouter {
  static Map<String, dynamic> parsePayload(Map<String, dynamic> notification) {
    final raw = notification['data'];
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }
    return {};
  }

  static int _int(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static _RouteTarget? _parseShareLink(String link) {
    if (link.isEmpty) return null;
    final uri = Uri.tryParse(link);
    if (uri == null) return null;

    if (uri.queryParameters.containsKey('type') && uri.queryParameters.containsKey('id')) {
      return _RouteTarget(
        uri.queryParameters['type']!.toLowerCase(),
        _int(uri.queryParameters['id']),
      );
    }

    final segments = uri.pathSegments;
    final shareIndex = segments.indexOf('share');
    if (shareIndex != -1 && segments.length > shareIndex + 2) {
      return _RouteTarget(
        segments[shareIndex + 1].toLowerCase(),
        _int(segments[shareIndex + 2]),
      );
    }
    return null;
  }

  static Future<bool> openNotification(Map<String, dynamic> notification) async {
    final loggedIn = await UserStorage.isLoggedIn();
    if (!loggedIn) {
      await Get.toNamed(Routes.LOGIN);
      return false;
    }

    final type = (notification['type'] ?? '').toString().toLowerCase();
    final data = parsePayload(notification);
    final link = notification['link']?.toString() ?? '';

    final fromLink = _parseShareLink(link);
    if (fromLink != null && fromLink.id > 0) {
      await _navigateToContent(fromLink.type, fromLink.id, data);
      return true;
    }

    if (type == 'prayer_reminder') {
      await PaymentGate.navigateToFeature(Routes.PRAYER_REQUESTS);
      return true;
    }

    final prayerId = _int(data['prayer_id'] ?? data['prayerId']);
    if (prayerId > 0 && (type.contains('prayer') || data.containsKey('prayer_id'))) {
      await _openPrayer(prayerId);
      return true;
    }

    final blogId = _int(data['blog_id'] ?? data['blogId'] ?? data['post_id']);
    if (blogId > 0 && (type.contains('blog') || data['post_type'] == 'blog')) {
      await _openBlog(blogId);
      return true;
    }

    final videoId = _int(data['video_id'] ?? data['videoId'] ?? data['post_id']);
    if (videoId > 0 && (type.contains('video') || data['post_type'] == 'video')) {
      await VideosController.openVideoDetail(videoId);
      return true;
    }

    final photoId = _int(data['photo_id'] ?? data['gallery_id'] ?? data['post_id']);
    if (photoId > 0 &&
        (type.contains('gallery') || type.contains('photo') || data['post_type'] == 'gallery')) {
      await GalleryController.openPhotoDetail(photoId);
      return true;
    }

    final storyId = _int(data['story_id'] ?? data['testimony_id'] ?? data['post_id']);
    if (storyId > 0 &&
        (type.contains('story') || type.contains('testimony') || data['post_type'] == 'story')) {
      await PaymentGate.navigateToFeature(Routes.STORY_DETAILS, arguments: storyId);
      return true;
    }

    final shortId = _int(data['short_id'] ?? data['shortId']);
    if (shortId > 0 && type.contains('short')) {
      await _openShort(shortId);
      return true;
    }

    final groupId = _int(data['group_id'] ?? data['groupId']);
    if (groupId > 0 && (type.contains('group') || data.containsKey('group_id'))) {
      await _openGroupChat(groupId);
      return true;
    }

    final streamId = data['stream_id']?.toString() ?? data['channel_name']?.toString() ?? '';
    if (streamId.isNotEmpty && type.contains('live')) {
      await PaymentGate.navigateToFeature(
        Routes.LIVE_STREAM_VIEWER,
        arguments: {'stream_id': streamId, ...data},
      );
      return true;
    }

    if (type == 'user_followed' || type == 'follow') {
      final followerId = _int(data['follower_id'] ?? data['user_id']);
      if (followerId > 0) {
        await Get.toNamed(Routes.PROFILE, arguments: {'userId': followerId});
        return true;
      }
    }

    if (type.contains('comment') || type.contains('like') || type.contains('post_')) {
      final postType = (data['post_type'] ?? '').toString().toLowerCase();
      final postId = _int(data['post_id']);
      if (postId > 0 && postType.isNotEmpty) {
        await _navigateToContent(postType, postId, data);
        return true;
      }
    }

    return false;
  }

  static Future<void> _navigateToContent(
    String type,
    int id,
    Map<String, dynamic> data,
  ) async {
    switch (type) {
      case 'prayer':
        await _openPrayer(id);
        break;
      case 'blog':
        await _openBlog(id);
        break;
      case 'video':
        await VideosController.openVideoDetail(id);
        break;
      case 'photo':
      case 'gallery':
        await GalleryController.openPhotoDetail(id);
        break;
      case 'story':
      case 'testimony':
        await PaymentGate.navigateToFeature(Routes.STORY_DETAILS, arguments: id);
        break;
      case 'short':
      case 'shorts':
        await _openShort(id);
        break;
      case 'group':
        await PaymentGate.navigateToFeature(Routes.GROUP_DETAILS, arguments: id);
        break;
      default:
        break;
    }
  }

  static Future<void> _openPrayer(int prayerId) async {
    final controller = Get.isRegistered<PrayersController>()
        ? Get.find<PrayersController>()
        : Get.put(PrayersController(), permanent: true);
    await controller.preparePrayerDetails(prayerId);
    await PaymentGate.navigateToFeature(Routes.PRAYER_DETAILS, arguments: prayerId);
  }

  static Future<void> _openBlog(int blogId) async {
    final controller = Get.isRegistered<BlogsController>()
        ? Get.find<BlogsController>()
        : Get.put(BlogsController(), permanent: true);
    await controller.prepareBlogDetails(blogId);
    await PaymentGate.navigateToFeature(Routes.BLOG_DETAILS, arguments: blogId);
  }

  static Future<void> _openGroupChat(int groupId) async {
    await PaymentGate.navigateToFeature(Routes.GROUP_CHAT, arguments: groupId);
  }

  static Future<void> _openShort(int shortId) async {
    try {
      final userId = await UserStorage.getUserId() ?? 0;
      final short = await ShortsService.getShortDetails(
        shortId,
        currentUserId: userId > 0 ? userId : null,
      );
      final controller = Get.isRegistered<ShortsController>()
          ? Get.find<ShortsController>()
          : Get.put(ShortsController());
      controller.useCommunityFeed(seed: [short]);
      await Get.toNamed(
        Routes.SHORTS,
        arguments: {
          'mode': 'community',
          'seed': [short],
          'startIndex': 0,
        },
      );
    } catch (_) {
      await Get.toNamed(Routes.SHORTS);
    }
  }
}

class _RouteTarget {
  final String type;
  final int id;

  const _RouteTarget(this.type, this.id);
}
