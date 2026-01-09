import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Platform;

class PermissionManager {
  static Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  static Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  static Future<bool> requestLocationPermission() async {
    final status = await Permission.location.request();
    return status.isGranted;
  }

  /// Request storage permission for reading videos/images
  static Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      // For Android 13+ (API 33+), use granular media permissions
      if (await Permission.photos.isGranted || 
          await Permission.videos.isGranted ||
          await Permission.audio.isGranted) {
        return true;
      }
      
      // Request photos and videos permissions
      final photosStatus = await Permission.photos.request();
      final videosStatus = await Permission.videos.request();
      
      if (photosStatus.isGranted || videosStatus.isGranted) {
        return true;
      }
      
      // Fallback to storage permission for older Android versions
      final storageStatus = await Permission.storage.request();
      return storageStatus.isGranted;
    } else if (Platform.isIOS) {
      // For iOS, request photos permission
      final photosStatus = await Permission.photos.request();
      return photosStatus.isGranted;
    }
    return true; // For other platforms, assume granted
  }

  static Future<void> requestAllPermissions() async {
    await requestNotificationPermission();
    await requestCameraPermission();
    await requestLocationPermission();
    await requestStoragePermission();
  }
}