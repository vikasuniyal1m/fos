import 'dart:async';
import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:fruitsofspirit/services/image_preload_service.dart';
import 'package:fruitsofspirit/services/shorts_service.dart';
import 'package:video_player/video_player.dart';

/// Instagram-style short video caching + adjacent preload.
class ShortVideoPreloadService {
  ShortVideoPreloadService._();
  static final ShortVideoPreloadService instance = ShortVideoPreloadService._();

  static const int maxKeepPlayers = 3;

  final CacheManager _cacheManager = DefaultCacheManager();
  final Set<String> _cachingUrls = {};
  final Set<String> _cachedUrls = {};

  Future<File?> cacheVideoFile(String url) async {
    if (url.isEmpty) return null;
    if (_cachedUrls.contains(url)) {
      try {
        return await _cacheManager.getSingleFile(url);
      } catch (_) {
        return null;
      }
    }
    if (_cachingUrls.contains(url)) return null;

    _cachingUrls.add(url);
    try {
      final file = await _cacheManager.getSingleFile(url);
      _cachedUrls.add(url);
      return file;
    } catch (_) {
      return null;
    } finally {
      _cachingUrls.remove(url);
    }
  }

  void warmCacheForShorts(List<Map<String, dynamic>> shorts, {int focusIndex = 0}) {
    if (shorts.isEmpty) return;

    final thumbUrls = <String>[];
    final videoUrls = <String>[];

    for (var i = focusIndex - 1; i <= focusIndex + 2; i++) {
      if (i < 0 || i >= shorts.length) continue;
      final short = shorts[i];
      final thumb = ShortsService.getThumbnailUrl(short);
      if (thumb != null && thumb.isNotEmpty) thumbUrls.add(thumb);
      final video = ShortsService.getVideoUrl(short);
      if (video != null && video.isNotEmpty) videoUrls.add(video);
    }

    if (thumbUrls.isNotEmpty) {
      unawaited(ImagePreloadService().preloadImages(thumbUrls, priorityLimit: thumbUrls.length));
    }
    for (var i = 0; i < videoUrls.length; i++) {
      unawaited(cacheVideoFile(videoUrls[i]));
    }
  }

  Future<VideoPlayerController?> createInitializedPlayer(String url) async {
    if (url.isEmpty) return null;

    VideoPlayerController controller;
    final cachedFile = await cacheVideoFile(url);
    if (cachedFile != null && await cachedFile.exists()) {
      controller = VideoPlayerController.file(cachedFile);
    } else {
      controller = VideoPlayerController.networkUrl(Uri.parse(url));
    }

    try {
      await controller.initialize();
      await controller.setLooping(true);
      return controller;
    } catch (_) {
      await controller.dispose();
      return null;
    }
  }
}
