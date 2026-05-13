import 'dart:io';
import 'package:get/get.dart';
import 'package:fruitsofspirit/services/profile_service.dart';
import 'package:fruitsofspirit/services/user_storage.dart';
import 'package:fruitsofspirit/services/api_service.dart';
import 'package:fruitsofspirit/controllers/home_controller.dart';
import 'package:fruitsofspirit/controllers/prayers_controller.dart';
import 'package:fruitsofspirit/controllers/groups_controller.dart';
import 'package:fruitsofspirit/controllers/notifications_controller.dart';
import 'package:fruitsofspirit/controllers/fruit_controller.dart';
import 'package:fruitsofspirit/controllers/blogs_controller.dart';
import 'package:fruitsofspirit/controllers/videos_controller.dart';
import 'package:fruitsofspirit/controllers/gallery_controller.dart';

/// Profile Controller
/// Manages user profile data and operations
class ProfileController extends GetxController {
  // Observable variables
  var isLoading = false.obs;
  var message = ''.obs;
  
  // Data
  var profile = <String, dynamic>{}.obs;
  var userId = 0.obs;

  @override
  void onInit() {
    super.onInit();
    _loadUserId();
    // Clear any existing profile data on init to prevent data leak
    profile.clear();
  }

  /// Set initial data from pre-loaded source
  void setInitialData(Map<String, dynamic> data) {
    if (data.isNotEmpty) {
      profile.value = data;
    }
  }

  @override
  void onReady() {
    super.onReady();
    // Don't call loadProfile here if we expect DataLoadingService to handle it,
    // or call it with showLoading: false to avoid flashing a loader.
    loadProfile(showLoading: false);
  }

  /// Load user ID from storage
  Future<void> _loadUserId() async {
    final id = await UserStorage.getUserId();
    if (id != null) {
      userId.value = id;
    }
  }

  /// Load profile
  Future<void> loadProfile({bool showLoading = true}) async {
    if (userId.value == 0) {
      await _loadUserId();
    }

    if (userId.value == 0) {
      profile.value = {};
      return;
    }

    // Only show loading if requested and profile is empty
    if (showLoading && profile.isEmpty) {
      isLoading.value = true;
    }
    message.value = '';

    try {
      final profileData = await ProfileService.getProfile(userId.value);
      profile.value = profileData;
      
      // Update local storage
      await UserStorage.updateUser(profileData);
    } catch (e) {
      message.value = 'Error loading profile: ${e.toString().replaceAll('Exception: ', '')}';
      print('Error loading profile: $e');
      if (profile.isEmpty) {
        profile.value = {};
      }
    } finally {
      isLoading.value = false;
    }
  }

  /// Update profile
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

    isLoading.value = true;
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
      
      // Reload profile
      await loadProfile();
      
      return true;
    } catch (e) {
      message.value = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      print('Error updating profile: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }
  
  /// Delete account
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
      
      // Clear local storage and navigate to login screen
      await UserStorage.clear();

      // Clear controller data instead of deleting permanent controllers
      try {
        if (Get.isRegistered<HomeController>()) {
          final homeController = Get.find<HomeController>();
          homeController.fruit.clear();
          homeController.prayers.clear();
          homeController.blogs.clear();
          homeController.isInitialLoading.value = true;
        }
        if (Get.isRegistered<PrayersController>()) {
          final prayersController = Get.find<PrayersController>();
          prayersController.prayers.clear();
        }
        if (Get.isRegistered<GroupsController>()) {
          final groupsController = Get.find<GroupsController>();
          groupsController.groups.clear();
        }
        if (Get.isRegistered<NotificationsController>()) {
          final notificationsController = Get.find<NotificationsController>();
          notificationsController.notifications.clear();
        }
        if (Get.isRegistered<FruitController>()) {
          final fruitController = Get.find<FruitController>();
          fruitController.allFruit.clear();
        }
        if (Get.isRegistered<BlogsController>()) {
          final blogsController = Get.find<BlogsController>();
          blogsController.blogs.clear();
        }
        if (Get.isRegistered<VideosController>()) {
          final videosController = Get.find<VideosController>();
          videosController.videos.clear();
        }
        if (Get.isRegistered<GalleryController>()) {
          final galleryController = Get.find<GalleryController>();
          galleryController.photos.clear();
        }
        // Clear this controller's data last
        profile.clear();
        userId.value = 0;
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

  /// Refresh profile
  Future<void> refresh() async {
    await loadProfile();
  }
}
