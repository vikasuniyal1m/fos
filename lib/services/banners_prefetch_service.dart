import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/painting.dart';
import 'package:fruitsofspirit/services/banners_service.dart';
import 'package:fruitsofspirit/services/hive_cache_service.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/controllers/banners_controller.dart';

/// Fetches banners + caches images before home — no auth required.
class BannersPrefetchService {
  static const String cacheKey = 'home_banners';

  static Future<void>? _inFlight;

  /// Idempotent: safe from main, splash, login, and controller.
  static Future<void> warmCache({bool force = false}) {
    if (!force && _inFlight != null) return _inFlight!;
    _inFlight = _run(force: force);
    return _inFlight!;
  }

  static Future<void> _run({bool force = false}) async {
    try {
      if (!force) {
        final cached = HiveCacheService.getCachedMap(cacheKey);
        final active = cached['active_banners'];
        if (active is List && active.isNotEmpty ||
            (cached['upcoming_banners'] is List &&
                (cached['upcoming_banners'] as List).isNotEmpty)) {
          _pushToController(cached);
          unawaited(_precacheFromCache(cached));
          return;
        }
      }

      final result = await BannersService.getBanners();
      final activeList =
          (result['active_banners'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      final upcomingList =
          (result['upcoming_banners'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

      if (activeList.isEmpty && upcomingList.isEmpty) return;

      await HiveCacheService.cacheMap(cacheKey, {
        'active_banners': activeList,
        'upcoming_banners': upcomingList,
        'countdown': result['countdown'],
      }, expiryHours: 12);

      final payload = {
        'active_banners': activeList,
        'upcoming_banners': upcomingList,
        'countdown': result['countdown'],
      };
      _pushToController(payload);
      unawaited(_precacheBannerList(activeList));
      unawaited(_precacheBannerList(upcomingList));
    } catch (_) {
      // Hive cache may still have stale banners from a prior session.
      final cached = HiveCacheService.getCachedMap(cacheKey);
      if (cached.isNotEmpty) _pushToController(cached);
    }
  }

  static void _pushToController(Map<String, dynamic> data) {
    if (!Get.isRegistered<BannersController>()) return;
    Get.find<BannersController>().ingestCachedBanners(data);
  }

  static Future<void> _precacheFromCache(Map<String, dynamic> cached) async {
    final active = cached['active_banners'];
    final upcoming = cached['upcoming_banners'];
    if (active is List && active.isNotEmpty) {
      await _precacheBannerList(active.cast<Map<String, dynamic>>());
    }
    if (upcoming is List && upcoming.isNotEmpty) {
      await _precacheBannerList(upcoming.cast<Map<String, dynamic>>());
    }
  }

  static Future<void> _precacheBannerList(List<Map<String, dynamic>> banners) async {
    for (final banner in banners) {
      final url = BannersService.getBannerImageUrl(banner['file_path']?.toString() ?? '');
      if (url.isEmpty) continue;
      await _precacheUrl(url);
    }
  }

  static Future<void> _precacheUrl(String url) async {
    try {
      final provider = CachedNetworkImageProvider(url);
      final stream = provider.resolve(ImageConfiguration.empty);
      final completer = Completer<void>();
      late ImageStreamListener listener;
      listener = ImageStreamListener(
        (ImageInfo _, bool __) {
          stream.removeListener(listener);
          if (!completer.isCompleted) completer.complete();
        },
        onError: (Object _, StackTrace? __) {
          stream.removeListener(listener);
          if (!completer.isCompleted) completer.complete();
        },
      );
      stream.addListener(listener);
      await completer.future.timeout(
        const Duration(seconds: 8),
        onTimeout: () {},
      );
    } catch (_) {}
  }
}
