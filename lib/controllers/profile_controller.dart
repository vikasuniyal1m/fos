import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/services/profile_service.dart';
import 'package:fruitsofspirit/services/user_storage.dart';
import 'package:fruitsofspirit/services/hive_cache_service.dart';
import 'package:fruitsofspirit/utils/image_helper.dart';
import 'package:fruitsofspirit/controllers/home_controller.dart';
import 'package:fruitsofspirit/controllers/prayers_controller.dart';
import 'package:fruitsofspirit/controllers/groups_controller.dart';
import 'package:fruitsofspirit/controllers/notifications_controller.dart';
import 'package:fruitsofspirit/controllers/fruit_controller.dart';
import 'package:fruitsofspirit/controllers/blogs_controller.dart';
import 'package:fruitsofspirit/controllers/videos_controller.dart';
import 'package:fruitsofspirit/controllers/gallery_controller.dart';

/// Profile Controller — Hive cache-first, silent background sync.
class ProfileController extends GetxController {
  var isLoading = false.obs;
  var isSilentSyncing = false.obs;
  var isUpdating = false.obs;
  var message = ''.obs;

  var profile = <String, dynamic>{}.obs;
  var userId = 0.obs;

  static const String _profileHiveKey = 'user_profile';
  static const Duration _minSyncInterval = Duration(minutes: 2);
  DateTime? _lastSyncedAt;
  int _loadGeneration = 0;

  @override
  void onInit() {
    super.onInit();
    _loadUserId();
    bootstrapProfile();
  }

  @override
  void onReady() {
    super.onReady();
    unawaited(prepareProfile());
  }

  void bootstrapProfile() {
    loadProfileFromHive();
    if (profile.isEmpty) {
      unawaited(_loadProfileFromUserStorage().then((_) => _preloadProfilePhoto()));
    } else {
      _preloadProfilePhoto();
    }
  }

  Future<void> prepareProfile() async {
    bootstrapProfile();
    final hasPreview = profile.isNotEmpty;
    unawaited(loadProfile(silent: hasPreview));
  }

  void loadProfileFromHive() {
    final cached = HiveCacheService.getCachedMap(_profileHiveKey);
    if (cached.isEmpty) return;

    final cachedUserId = cached['id'] ?? cached['user_id'];
    if (userId.value > 0 &&
        cachedUserId != null &&
        cachedUserId.toString() != userId.value.toString()) {
      return;
    }

    profile.value = _normalizeProfileData(cached);
    if (userId.value == 0) {
      final id = cached['id'] ?? cached['user_id'];
      if (id is int) {
        userId.value = id;
      } else if (id is String) {
        userId.value = int.tryParse(id) ?? 0;
      }
    }
  }

  Future<void> _loadProfileFromUserStorage() async {
    final user = await UserStorage.getUser();
    if (user == null || user.isEmpty) return;

    if (profile.isEmpty) {
      profile.value = _normalizeProfileData(user);
    } else {
      _mergeProfileFields(user);
    }

    if (userId.value == 0) {
      final id = user['id'];
      if (id is int) {
        userId.value = id;
      } else if (id is String) {
        userId.value = int.tryParse(id) ?? 0;
      }
    }
  }

  Future<void> _cacheProfileSnapshot() async {
    if (profile.isEmpty) return;
    await HiveCacheService.cacheMap(
      _profileHiveKey,
      Map<String, dynamic>.from(profile),
      expiryHours: 24,
    );
  }

  void setInitialData(Map<String, dynamic> data) {
    if (data.isEmpty) return;
    if (profile.isEmpty) {
      profile.value = _normalizeProfileData(data);
    } else {
      _mergeProfileFields(data);
    }
    _preloadProfilePhoto();
    unawaited(_cacheProfileSnapshot());
  }

  Future<void> _loadUserId() async {
    final id = await UserStorage.getUserId();
    if (id != null) {
      userId.value = id;
    }
  }

  Map<String, dynamic> _normalizeProfileData(Map<String, dynamic> data) {
    final normalized = Map<String, dynamic>.from(data);
    if (normalized['fruits'] is List && normalized['fruit'] == null) {
      normalized['fruit'] = normalized['fruits'];
    }
    return normalized;
  }

  bool _profileNeedsUpdate(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) {
    const keys = [
      'name',
      'email',
      'phone',
      'profile_photo',
      'fruit_category',
      'fruit',
      'fruits',
      'updated_at',
    ];
    for (final key in keys) {
      if (local[key] != remote[key]) return true;
    }
    final localStats = local['stats'];
    final remoteStats = remote['stats'];
    if (localStats is Map && remoteStats is Map) {
      for (final key in ['prayers', 'blogs', 'media']) {
        if (localStats[key] != remoteStats[key]) return true;
      }
    } else if (localStats != remoteStats) {
      return true;
    }
    return false;
  }

  void _mergeProfileFields(Map<String, dynamic> remote) {
    final normalized = _normalizeProfileData(remote);
    var changed = false;
    for (final entry in normalized.entries) {
      if (entry.key == 'stats' &&
          entry.value is Map &&
          profile['stats'] is Map) {
        final merged = Map<String, dynamic>.from(profile['stats'] as Map);
        merged.addAll(Map<String, dynamic>.from(entry.value as Map));
        if (merged.toString() != (profile['stats'] as Map).toString()) {
          profile['stats'] = merged;
          changed = true;
        }
        continue;
      }
      if (profile[entry.key] != entry.value) {
        profile[entry.key] = entry.value;
        changed = true;
      }
    }
    if (changed) {
      profile.refresh();
    }
  }

  void _preloadProfilePhoto() {
    final url =
        ImageHelper.getProfilePhotoUrl(profile['profile_photo']?.toString());
    if (url == null || url.isEmpty) return;
    final context = Get.context;
    if (context == null) return;
    try {
      precacheImage(NetworkImage(url), context);
    } catch (_) {}
  }

  /// Load profile (silent = merge in background, no full-page loader).
  Future<void> loadProfile({
    bool silent = false,
    bool force = false,
    bool showLoading = true,
  }) async {
    if (userId.value == 0) {
      await _loadUserId();
    }

    if (userId.value == 0) {
      if (profile.isEmpty) profile.value = {};
      return;
    }

    if (silent &&
        !force &&
        _lastSyncedAt != null &&
        DateTime.now().difference(_lastSyncedAt!) < _minSyncInterval) {
      return;
    }

    final generation = silent ? _loadGeneration : ++_loadGeneration;
    final hadPreview = profile.isNotEmpty;
    final blockUi = !silent && showLoading && !hadPreview;

    if (blockUi) {
      isLoading.value = true;
    } else if (silent && hadPreview) {
      isSilentSyncing.value = true;
    }
    message.value = '';

    try {
      final profileData =
          _normalizeProfileData(await ProfileService.getProfile(userId.value));

      if (generation != _loadGeneration) return;

      if (silent &&
          hadPreview &&
          !force &&
          !_profileNeedsUpdate(profile, profileData)) {
        _lastSyncedAt = DateTime.now();
        return;
      }

      if (silent && hadPreview) {
        _mergeProfileFields(profileData);
      } else {
        profile.value = profileData;
      }

      _lastSyncedAt = DateTime.now();
      await UserStorage.updateUser(profileData);
      _preloadProfilePhoto();
      unawaited(_cacheProfileSnapshot());
    } catch (e) {
      if (!silent || !hadPreview) {
        message.value =
            'Error loading profile: ${e.toString().replaceAll('Exception: ', '')}';
      }
      print('Error loading profile: $e');
    } finally {
      isLoading.value = false;
      isSilentSyncing.value = false;
    }
  }

  Future<bool> updateProfile({
    String? name,
    String? email,
    String? phone,
    String? password,
    String? fruitCategory,
    File? profilePhoto,
  }) async {
    if (userId.value == 0) {
      await _loadUserId();
    }

    if (userId.value == 0) {
      message.value = 'Please login first';
      return false;
    }

    final previous = Map<String, dynamic>.from(profile);
    if (name != null) profile['name'] = name;
    if (email != null) profile['email'] = email;
    if (phone != null) profile['phone'] = phone;
    if (fruitCategory != null) profile['fruit_category'] = fruitCategory;
    profile.refresh();

    isUpdating.value = true;
    message.value = 'Updating profile...';

    try {
      await ProfileService.updateProfile(
        userId: userId.value,
        name: name,
        email: email,
        phone: phone,
        password: password,
        fruitCategory: fruitCategory,
        profilePhoto: profilePhoto,
      );

      message.value = 'Profile updated successfully';
      unawaited(loadProfile(silent: true, force: true));
      return true;
    } catch (e) {
      profile.value = previous;
      message.value = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      print('Error updating profile: $e');
      return false;
    } finally {
      isUpdating.value = false;
    }
  }

  void clearProfile() {
    profile.clear();
    userId.value = 0;
    _lastSyncedAt = null;
    unawaited(HiveCacheService.clearKey(_profileHiveKey));
  }

  Future<bool> deleteAccount() async {
    if (userId.value == 0) {
      await _loadUserId();
    }

    if (userId.value == 0) {
      message.value = 'Please login first';
      return false;
    }

    isLoading.value = true;
    message.value = 'Deleting account...';

    try {
      await ProfileService.deleteAccount(userId.value);
      message.value = 'Account deleted successfully';
      await UserStorage.clear();

      try {
        if (Get.isRegistered<HomeController>()) {
          final homeController = Get.find<HomeController>();
          homeController.fruit.clear();
          homeController.prayers.clear();
          homeController.blogs.clear();
          homeController.isInitialLoading.value = true;
        }
        if (Get.isRegistered<PrayersController>()) {
          Get.find<PrayersController>().prayers.clear();
        }
        if (Get.isRegistered<GroupsController>()) {
          Get.find<GroupsController>().groups.clear();
        }
        if (Get.isRegistered<NotificationsController>()) {
          Get.find<NotificationsController>().notifications.clear();
        }
        if (Get.isRegistered<FruitController>()) {
          Get.find<FruitController>().allFruit.clear();
        }
        if (Get.isRegistered<BlogsController>()) {
          Get.find<BlogsController>().blogs.clear();
        }
        if (Get.isRegistered<VideosController>()) {
          Get.find<VideosController>().videos.clear();
        }
        if (Get.isRegistered<GalleryController>()) {
          Get.find<GalleryController>().photos.clear();
        }
        clearProfile();
      } catch (e) {
        print('Error clearing controller data: $e');
      }

      Get.offAllNamed('/login');
      return true;
    } catch (e) {
      message.value = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      print('Error deleting account: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refresh() async {
    await loadProfile(silent: true, force: true);
  }
}
