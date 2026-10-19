import 'package:flutter/material.dart';

/// Image Helper
/// Utility functions for handling images (network, assets, etc.)
class ImageHelper {
  /// Get ImageProvider for profile photo
  /// Handles both network URLs and local asset paths
  static ImageProvider? getProfileImageProvider(String? photoUrl) {
    if (photoUrl == null || photoUrl.isEmpty) {
      return null;
    }
    
    // Check if it's a local asset path
    if (photoUrl.startsWith('assets/') || photoUrl.startsWith('assets/images/')) {
      // Use AssetImage for local assets
      return AssetImage(photoUrl);
    }
    
    // Check if it's already a full URL (http/https)
    if (photoUrl.startsWith('http://') || photoUrl.startsWith('https://')) {
      return NetworkImage(photoUrl);
    }
    
    // Check if it's a file:// URL (invalid)
    if (photoUrl.startsWith('file://')) {
      return null;
    }
    
    // If it's a relative path, construct full URL
    if (photoUrl.startsWith('/')) {
      return NetworkImage('http://admin.fosmessenger.com$photoUrl');
    }
    
    // Default: assume it's a relative path from base URL
    return NetworkImage('http://admin.fosmessenger.com/$photoUrl');
  }

  /// Get profile photo URL string (not ImageProvider)
  /// Handles both network URLs and local asset paths
  /// Returns null for invalid URLs
  static String? getProfilePhotoUrl(String? photoUrl) {
    if (photoUrl == null || photoUrl.isEmpty) {
      return null;
    }
    
    // Check if it's a local asset path - return null (use AssetImage instead)
    if (photoUrl.startsWith('assets/') || photoUrl.startsWith('assets/images/')) {
      return null;
    }
    
    // Check if it's already a full URL (http/https) - return as-is
    if (photoUrl.startsWith('http://') || photoUrl.startsWith('https://')) {
      return photoUrl;
    }
    
    // Check if it's a file:// URL (invalid)
    if (photoUrl.startsWith('file://')) {
      return null;
    }
    
    // If it's a relative path, construct full URL
    if (photoUrl.startsWith('/')) {
      return 'http://admin.fosmessenger.com$photoUrl';
    }
    
    // Default: assume it's a relative path from base URL
    return 'http://admin.fosmessenger.com/$photoUrl';
  }
  
  /// Check if URL is a local asset
  static bool isLocalAsset(String? url) {
    if (url == null || url.isEmpty) return false;
    return url.startsWith('assets/') || url.startsWith('assets/images/');
  }
  
  /// Check if URL is a network URL
  static bool isNetworkUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    return url.startsWith('http://') || url.startsWith('https://');
  }

  /// Resolve relative upload paths and full URLs for content images.
  static String? resolveMediaPath(
    String? path, {
    String baseUrl = 'https://admin.fosmessenger.com',
  }) {
    if (path == null) return null;
    var trimmed = path.trim();
    if (trimmed.isEmpty) return null;

    if (trimmed.startsWith('assets/') || trimmed.startsWith('file://')) {
      return null;
    }

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return _normalizeLegacyMediaHost(trimmed, baseUrl);
    }

    // Strip accidental appended text after image or video extension.
    final urlPattern = RegExp(
      r'[/\w\-.%]+?\.(?:png|jpg|jpeg|webp|gif|bmp|mp4|mov|avi|wmv|flv|webm)',
      caseSensitive: false,
    );
    final match = urlPattern.firstMatch(trimmed);
    if (match != null) {
      trimmed = match.group(0)!;
    }

    final clean = trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
    return '$baseUrl/$clean';
  }

  static bool isVideoUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    final ext = url.split('?').first.split('.').last.toLowerCase();
    return ['mp4', 'mov', 'avi', 'wmv', 'flv', 'webm'].contains(ext);
  }

  static String? resolveBlogMediaUrl(Map<String, dynamic> blog) {
    final raw = blog['image_url'] ?? blog['image'];
    if (raw == null) return null;
    return resolveMediaPath(raw.toString());
  }

  static String? resolveGalleryPhotoUrl(Map<String, dynamic> photo) {
    for (final key in [
      'thumbnail_path',
      'thumbnail_url',
      'image_url',
      'file_path',
    ]) {
      final raw = photo[key];
      if (raw == null) continue;
      final url = resolveMediaPath(raw.toString());
      if (url != null && url.isNotEmpty) return url;
    }
    return null;
  }

  static bool isRealGalleryPhoto(Map<String, dynamic> photo) {
    final id = photo['id'];
    if (id is int && id <= 0) return false;
    if (id is String) {
      final parsed = int.tryParse(id);
      if (parsed != null && parsed <= 0) return false;
    }
    final filePath = photo['file_path']?.toString() ?? '';
    if (filePath.contains('Frame.png') ||
        filePath.contains('Vector.png') ||
        filePath == 'uploads/prayer_group.jpg') {
      return false;
    }
    return true;
  }

  static String? resolveBlogImageUrl(Map<String, dynamic> blog) {
    return resolveBlogMediaUrl(blog);
  }

  /// Chat / upload URLs — rewrite dead legacy hosts to current CDN.
  static String? resolveChatFileUrl(Map<String, dynamic> message) {
    final raw = message['file_url'] ?? message['file_path'];
    if (raw == null) return null;
    return resolveMediaPath(raw.toString());
  }

  static String _normalizeLegacyMediaHost(String url, String baseUrl) {
    try {
      final uri = Uri.parse(url);
      final host = uri.host.toLowerCase();
      if (host.contains('templateforwebsites')) {
        var path = uri.path;
        if (path.startsWith('/')) path = path.substring(1);
        final cleanBase =
            baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
        return '$cleanBase/$path';
      }
    } catch (_) {}
    return url;
  }
}

