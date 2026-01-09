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
      return NetworkImage('https://fruitofthespirit.templateforwebsites.com$photoUrl');
    }
    
    // Default: assume it's a relative path from base URL
    return NetworkImage('https://fruitofthespirit.templateforwebsites.com/$photoUrl');
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
      return 'https://fruitofthespirit.templateforwebsites.com$photoUrl';
    }
    
    // Default: assume it's a relative path from base URL
    return 'https://fruitofthespirit.templateforwebsites.com/$photoUrl';
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
}

