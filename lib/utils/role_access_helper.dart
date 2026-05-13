import 'package:fruitsofspirit/services/user_storage.dart';

/// Role-based Access Control Helper
/// Manages user permissions and access based on role and approval status
class RoleAccessHelper {
  /// Check if user can access blogging features
  static bool canAccessBloggingFeatures(Map<String, dynamic>? userData) {
    if (userData == null) return false;
    
    final String role = userData['role'] ?? 'User';
    final String status = userData['status'] ?? 'Active';
    
    // Only active bloggers can access all blogging features
    return role == 'Blogger' && status == 'Active';
  }
  
  /// Check if user is a pending blogger (can login but with limited access)
  static bool isPendingBlogger(Map<String, dynamic>? userData) {
    if (userData == null) return false;
    
    final String role = userData['role'] ?? 'User';
    final String status = userData['status'] ?? 'Active';
    
    return role == 'Blogger' && status == 'Pending';
  }
  
  /// Check if user is an active blogger
  static bool isActiveBlogger(Map<String, dynamic>? userData) {
    if (userData == null) return false;
    
    final String role = userData['role'] ?? 'User';
    final String status = userData['status'] ?? 'Active';
    
    return role == 'Blogger' && status == 'Active';
  }
  
  /// Check if user is a regular user
  static bool isRegularUser(Map<String, dynamic>? userData) {
    if (userData == null) return false;
    
    final String role = userData['role'] ?? 'User';
    return role == 'User';
  }
  
  /// Get user-friendly status message for pending bloggers
  static String getBloggerStatusMessage(Map<String, dynamic>? userData) {
    if (userData == null) return '';
    
    final String status = userData['status'] ?? 'Active';
    final String role = userData['role'] ?? 'User';
    
    if (role == 'Blogger' && status == 'Pending') {
      return '📝 Your Blogger account is pending admin approval. You can login but blogging features will be available after approval.';
    }
    
    if (role == 'Blogger' && status == 'Inactive') {
      return '⏸ Your Blogger account is inactive. Please contact admin.';
    }
    
    return '';
  }
  
  /// Get current user data from storage
  static Future<Map<String, dynamic>?> getCurrentUserData() async {
    try {
      final userId = await UserStorage.getUserId();
      if (userId == null) return null;
      
      // Get user data from storage
      final user = await UserStorage.getUser();
      if (user != null) {
        return {
          'id': userId,
          'name': user['name'],
          'email': user['email'],
          'phone': user['phone'],
          'role': user['role'],
          'status': user['status'],
          'profile_photo': user['profile_photo'],
          'fruit_category': user['fruit_category'],
        };
      }
      return null;
    } catch (e) {
      return null;
    }
  }
  
  /// Check if current user can access specific features
  static Future<bool> canCreateBlog() async {
    final userData = await getCurrentUserData();
    return canAccessBloggingFeatures(userData);
  }
  
  static Future<bool> canEditBlog() async {
    final userData = await getCurrentUserData();
    return canAccessBloggingFeatures(userData);
  }
  
  static Future<bool> canDeleteBlog() async {
    final userData = await getCurrentUserData();
    return canAccessBloggingFeatures(userData);
  }
  
  static Future<bool> canAccessBloggerZone() async {
    final userData = await getCurrentUserData();
    return isActiveBlogger(userData) || isPendingBlogger(userData); // Allow both approved and pending bloggers
  }
  
  /// Get user role display text
  static String getRoleDisplayText(Map<String, dynamic>? userData) {
    if (userData == null) return 'User';
    
    final String role = userData['role'] ?? 'User';
    final String status = userData['status'] ?? 'Active';
    
    if (role == 'Blogger') {
      if (status == 'Pending') {
        return 'Blogger (Pending)';
      } else if (status == 'Active') {
        return 'Blogger';
      } else {
        return 'Blogger (Inactive)';
      }
    }
    
    return 'User';
  }
}
