import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'dart:async';

/// Service for preloading images in the background
/// Helps prevent UI freezing by loading images asynchronously
class ImagePreloadService {
  static final ImagePreloadService _instance = ImagePreloadService._internal();
  factory ImagePreloadService() => _instance;
  ImagePreloadService._internal();

  final Set<String> _preloadingUrls = {};
  final Set<String> _preloadedUrls = {};
  final CacheManager _cacheManager = DefaultCacheManager();

  /// Preload a single image with priority
  /// [url] - Image URL to preload
  /// [priority] - true for high priority (load immediately), false for background
  Future<void> preloadImage(String url, {bool priority = false}) async {
    if (url.isEmpty || _preloadedUrls.contains(url) || _preloadingUrls.contains(url)) {
      return;
    }

    _preloadingUrls.add(url);

    try {
      if (priority) {
        // High priority: load immediately
        await _cacheManager.getSingleFile(url);
        _preloadedUrls.add(url);
      } else {
        // Low priority: load in background without blocking
        unawaited(_cacheManager.getSingleFile(url).then((_) {
          _preloadedUrls.add(url);
          _preloadingUrls.remove(url);
        }).catchError((error) {
          // Silently handle 404 and other errors - don't spam console
          // Only log non-404 errors for debugging
          if (error.toString().contains('404') || error.toString().contains('Not Found')) {
            // 404 errors are expected for missing images, ignore silently
          } else {
            // Log other errors for debugging (optional, can be removed in production)
            // print('⚠️ Failed to preload image: $url - $error');
          }
          _preloadingUrls.remove(url);
        }));
        return;
      }
    } catch (e) {
      // Silently handle 404 and other errors
      if (e.toString().contains('404') || e.toString().contains('Not Found')) {
        // 404 errors are expected for missing images, ignore silently
      } else {
        // Log other errors for debugging (optional, can be removed in production)
        // print('⚠️ Error preloading image: $url - $e');
      }
    } finally {
      _preloadingUrls.remove(url);
    }
  }

  /// Preload multiple images with priority handling
  /// [urls] - List of image URLs to preload
  /// [priorityLimit] - Maximum number of high-priority images to load simultaneously
  /// [backgroundBatchSize] - Number of background images to load per batch
  Future<void> preloadImages(
    List<String> urls, {
    int priorityLimit = 3,
    int backgroundBatchSize = 5,
  }) async {
    if (urls.isEmpty) return;

    // Filter out already preloaded or currently preloading URLs
    final urlsToLoad = urls
        .where((url) => url.isNotEmpty && 
                       !_preloadedUrls.contains(url) && 
                       !_preloadingUrls.contains(url))
        .toList();

    if (urlsToLoad.isEmpty) return;

    // Load first few images with high priority (immediately visible)
    final highPriorityUrls = urlsToLoad.take(priorityLimit).toList();
    final backgroundUrls = urlsToLoad.skip(priorityLimit).toList();

    // Load high priority images immediately
    await Future.wait(
      highPriorityUrls.map((url) => preloadImage(url, priority: true)),
    );

    // Load background images in batches to avoid overwhelming the network
    for (int i = 0; i < backgroundUrls.length; i += backgroundBatchSize) {
      final batch = backgroundUrls.skip(i).take(backgroundBatchSize).toList();
      
      // Load batch in background without blocking
      unawaited(
        Future.wait(
          batch.map((url) => preloadImage(url, priority: false)),
        ),
      );

      // Small delay between batches to prevent network congestion
      if (i + backgroundBatchSize < backgroundUrls.length) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
  }

  /// Preload images from a list of data maps
  /// Extracts image URLs from common field names
  Future<void> preloadImagesFromData(
    List<Map<String, dynamic>> dataList, {
    List<String> imageFields = const ['image_url', 'file_path', 'profile_photo', 'thumbnail'],
    int priorityLimit = 3,
  }) async {
    final urls = <String>[];

    for (var data in dataList) {
      for (var field in imageFields) {
        if (data.containsKey(field) && data[field] != null) {
          final url = data[field].toString();
          if (url.isNotEmpty && !url.startsWith('assets/') && !url.startsWith('file://')) {
            // Construct full URL if needed
            String fullUrl = url;
            if (!url.startsWith('http')) {
              fullUrl = 'https://fruitofthespirit.templateforwebsites.com/$url';
            }
            urls.add(fullUrl);
            break; // Only add one image per item
          }
        }
      }
    }

    await preloadImages(urls, priorityLimit: priorityLimit);
  }

  /// Check if an image is already preloaded
  bool isPreloaded(String url) {
    return _preloadedUrls.contains(url);
  }

  /// Clear preloaded cache (useful for memory management)
  Future<void> clearPreloadCache() async {
    _preloadedUrls.clear();
    _preloadingUrls.clear();
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'preloaded': _preloadedUrls.length,
      'preloading': _preloadingUrls.length,
      'preloaded_urls': _preloadedUrls.toList(),
    };
  }
}

/// Helper function to prevent unawaited future warnings
void unawaited(Future<void> future) {
  // Intentionally not awaiting
}

