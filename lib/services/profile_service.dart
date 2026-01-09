import 'dart:io';
import '../config/api_config.dart';
import 'api_service.dart';

/// Profile Service
/// Handles user profile get and update
class ProfileService {
  /// Get User Profile
  /// 
  /// Parameters:
  /// - userId: User ID
  /// 
  /// Returns: User profile with stats and selected fruits
  static Future<Map<String, dynamic>> getProfile(int userId) async {
    final response = await ApiService.get(
      ApiConfig.profile,
      queryParameters: {'user_id': userId.toString()},
    );

    if (response['success'] == true && response['data'] != null) {
      return response['data'] as Map<String, dynamic>;
    } else {
      throw ApiException(response['message'] ?? 'Failed to fetch profile');
    }
  }

  /// Update User Profile
  /// 
  /// Parameters:
  /// - userId: User ID
  /// - name: Updated name (optional)
  /// - email: Updated email (optional)
  /// - phone: Updated phone (optional)
  /// - password: Updated password (optional)
  /// - fruitCategory: Primary fruit category (optional)
  /// - profilePhoto: Profile photo file (optional)
  /// 
  /// Returns: Success message
  static Future<String> updateProfile({
    required int userId,
    String? name,
    String? email,
    String? phone,
    String? password,
    String? fruitCategory,
    File? profilePhoto,
  }) async {
    final fields = <String, String>{
      'user_id': userId.toString(),
    };

    if (name != null) fields['name'] = name;
    if (email != null) fields['email'] = email;
    if (phone != null) fields['phone'] = phone;
    if (password != null) fields['password'] = password;
    if (fruitCategory != null) fields['fruit_category'] = fruitCategory;

    final files = <String, File>{};
    if (profilePhoto != null) {
      files['profile_photo'] = profilePhoto;
    }

    final response = await ApiService.postMultipart(
      ApiConfig.profile,
      fields: fields,
      files: files.isNotEmpty ? files : null,
    );

    if (response['success'] == true) {
      return response['message'] ?? 'Profile updated successfully';
    } else {
      throw ApiException(response['message'] ?? 'Failed to update profile');
    }
  }
  
  /// Delete User Account
  /// 
  /// Parameters:
  /// - userId: User ID
  /// 
  /// Returns: Success message
  static Future<String> deleteAccount(int userId) async {
    final response = await ApiService.post(
      ApiConfig.deleteAccount,
      body: {
        'action': 'delete',
        'user_id': userId.toString(),
      },
    );

    if (response['success'] == true) {
      return response['message'] ?? 'Account deleted successfully';
    } else {
      throw ApiException(response['message'] ?? 'Failed to delete account');
    }
  }
}
