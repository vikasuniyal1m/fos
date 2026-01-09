import 'dart:io';
import 'package:get/get.dart';
import 'package:fruitsofspirit/services/profile_service.dart';
import 'package:fruitsofspirit/services/user_storage.dart';
import 'package:fruitsofspirit/services/api_service.dart';

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
  }

  @override
  void onReady() {
    super.onReady();
    loadProfile();
  }

  /// Load user ID from storage
  Future<void> _loadUserId() async {
    final id = await UserStorage.getUserId();
    if (id != null) {
      userId.value = id;
    }
  }

  /// Load profile
  Future<void> loadProfile() async {
    if (userId.value == 0) {
      await _loadUserId();
    }

    if (userId.value == 0) {
      profile.value = {};
      return;
    }

    isLoading.value = true;
    message.value = '';

    try {
      final profileData = await ProfileService.getProfile(userId.value);
      profile.value = profileData;
      
      // Update local storage
      await UserStorage.updateUser(profileData);
    } catch (e) {
      message.value = 'Error loading profile: ${e.toString().replaceAll('Exception: ', '')}';
      print('Error loading profile: $e');
      profile.value = {};
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
