import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Platform;

class LivePermissionResult {
  final bool granted;
  final bool needsSettings;
  final String? deniedLabel;

  const LivePermissionResult({
    required this.granted,
    this.needsSettings = false,
    this.deniedLabel,
  });
}

class PermissionManager {
  static Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  static Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  static Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Camera + microphone for live broadcast (iOS needs Podfile PERMISSION_* flags).
  static Future<LivePermissionResult> requestLivePermissions() async {
    var camera = await Permission.camera.status;
    var microphone = await Permission.microphone.status;

    if (!camera.isGranted) {
      camera = await Permission.camera.request();
    }
    if (!microphone.isGranted) {
      microphone = await Permission.microphone.request();
    }

    if (camera.isGranted && microphone.isGranted) {
      return const LivePermissionResult(granted: true);
    }

    String? deniedLabel;
    if (!camera.isGranted && !microphone.isGranted) {
      deniedLabel = 'Camera and Microphone';
    } else if (!camera.isGranted) {
      deniedLabel = 'Camera';
    } else {
      deniedLabel = 'Microphone';
    }

    final needsSettings = !camera.isGranted || !microphone.isGranted;
    return LivePermissionResult(
      granted: false,
      needsSettings: needsSettings,
      deniedLabel: deniedLabel,
    );
  }

  static String livePermissionSettingsHint() {
    if (Platform.isIOS) {
      return 'Settings → FOS Messenger → turn on Camera and Microphone.';
    }
    return 'Settings → Apps → FOS Messenger → Permissions → allow Camera and Microphone.';
  }

  static Future<bool> requestLocationPermission() async {
    final status = await Permission.location.request();
    return status.isGranted;
  }

  static bool _mediaAccessGranted(PermissionStatus status) =>
      status.isGranted || status.isLimited;

  /// Gallery / downloads — videos + photos (Android 13+ READ_MEDIA_VIDEO).
  static Future<bool> requestGalleryVideoPermission() async {
    if (Platform.isAndroid) {
      var videos = await Permission.videos.status;
      var photos = await Permission.photos.status;
      if (_mediaAccessGranted(videos) || _mediaAccessGranted(photos)) {
        return true;
      }

      videos = await Permission.videos.request();
      if (_mediaAccessGranted(videos)) return true;

      photos = await Permission.photos.request();
      if (_mediaAccessGranted(photos)) return true;

      final storage = await Permission.storage.request();
      return storage.isGranted;
    }
    if (Platform.isIOS) {
      var photos = await Permission.photos.status;
      if (_mediaAccessGranted(photos)) return true;
      photos = await Permission.photos.request();
      return _mediaAccessGranted(photos);
    }
    return true;
  }

  static Future<bool> isGalleryVideoPermissionDeniedForever() async {
    if (Platform.isIOS) {
      return (await Permission.photos.status).isPermanentlyDenied;
    }
    final videos = await Permission.videos.status;
    final photos = await Permission.photos.status;
    final storage = await Permission.storage.status;
    return videos.isPermanentlyDenied ||
        photos.isPermanentlyDenied ||
        storage.isPermanentlyDenied;
  }

  /// Request storage permission for reading videos/images
  static Future<bool> requestStoragePermission() async {
    return requestGalleryVideoPermission();
  }

  static Future<void> requestAllPermissions() async {
    await requestNotificationPermission();
    await requestCameraPermission();
    await requestLocationPermission();
    await requestStoragePermission();
  }
}