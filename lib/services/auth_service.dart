import '../config/api_config.dart';
import 'api_service.dart' show ApiService, ApiException, NetworkException, ApprovalPendingException, RoleMismatchException;

export 'api_service.dart' show ApprovalPendingException, RoleMismatchException;

/// Authentication Service
/// Handles user login, registration, and password management
class AuthService {
  /// User Login
  /// 
  /// Parameters:
  /// - email: User email (optional if phone provided)
  /// - phone: User phone (optional if email provided)
  /// - password: User password
  /// - role: User role ('User' or 'Blogger')
  /// 
  /// Returns: User data with selected fruits
  static Future<Map<String, dynamic>> login({
    String? email,
    String? phone,
    required String password,
    String role = 'User',
  }) async {
    if (email == null && phone == null) {
      throw ApiException('Email or phone is required');
    }

    final body = <String, dynamic>{
      'password': password,
      'role': role, // Send selected role to backend
    };

    if (email != null) {
      body['email'] = email;
    } else {
      body['phone'] = phone;
    }

    try {
      final response = await ApiService.post(
        '${ApiConfig.auth}?action=login',
        body: body,
      );

      if (response['success'] == true && response['data'] != null) {
        print('AuthService.login: Backend response data: ${response['data']}');
        return response['data'] as Map<String, dynamic>;
      } else {
        // Check if it's a role mismatch error
        if (response['data'] != null && response['data']['role'] != null && response['data']['requested_role'] != null) {
          final correctRole = response['data']['role'] as String;
          throw RoleMismatchException(
            response['message'] ?? 'Please select the correct role to login.',
            correctRole: correctRole,
          );
        }
        // Check if it's an approval pending error
        if (response['data'] != null && response['data']['status'] != null) {
          throw ApprovalPendingException(
            response['message'] ?? 'Please wait for approval from admin',
            status: response['data']['status'] ?? 'Inactive',
            role: response['data']['role'] ?? 'User',
          );
        }
        throw ApiException(response['message'] ?? 'Login failed');
      }
    } on ApprovalPendingException {
      rethrow;
    } on RoleMismatchException {
      rethrow;
    } catch (e) {
      if (e is ApprovalPendingException || e is RoleMismatchException) {
        rethrow;
      }
      // Check if it's a 403 error (Forbidden - approval pending)
      throw ApiException(e.toString());
    }
  }

  /// User Registration
  /// 
  /// Parameters:
  /// - name: User full name
  /// - email: User email (optional if phone provided)
  /// - phone: User phone (optional if email provided)
  /// - password: User password
  /// - confirmPassword: Password confirmation
  /// - acceptTerms: Must be true
  /// - requestedRole: Requested role ('User' or 'Blogger'). Default: 'User'
  ///   Note: Blogger role requires admin approval, will be set as 'User' initially
  /// 
  /// Returns: Created user data
  static Future<Map<String, dynamic>> register({
    required String name,
    String? email,
    String? phone,
    required String password,
    required String confirmPassword,
    required bool acceptTerms,
    String requestedRole = 'User',
  }) async {
    if (email == null && phone == null) {
      throw ApiException('Email or phone is required');
    }

    if (password != confirmPassword) {
      throw ApiException('Passwords do not match');
    }

    if (!acceptTerms) {
      throw ApiException('You must accept Terms & Conditions');
    }

    final body = <String, dynamic>{
      'name': name,
      'password': password,
      'confirm_password': confirmPassword,
      'accept_terms': acceptTerms ? '1' : '0',
      'requested_role': requestedRole, // User or Blogger
    };

    if (email != null) {
      body['email'] = email;
    } else {
      body['phone'] = phone;
    }

    final response = await ApiService.post(
      '${ApiConfig.auth}?action=register',
      body: body,
    );

    if (response['success'] == true && response['data'] != null) {
      return response['data'] as Map<String, dynamic>;
    } else {
      throw ApiException(response['message'] ?? 'Registration failed');
    }
  }

  /// Forgot Password - Send OTP
  /// 
  /// Parameters:
  /// - email: User email (optional if phone provided)
  /// - phone: User phone (optional if email provided)
  /// 
  /// Returns: Success message
  static Future<String> forgotPassword({
    String? email,
    String? phone,
  }) async {
    if (email == null && phone == null) {
      throw ApiException('Email or phone is required');
    }

    final body = <String, dynamic>{};
    if (email != null) {
      body['email'] = email;
    } else {
      body['phone'] = phone;
    }

    final response = await ApiService.post(
      '${ApiConfig.auth}?action=forgot-password',
      body: body,
    );

    if (response['success'] == true) {
      return response['message'] ?? 'OTP sent successfully';
    } else {
      throw ApiException(response['message'] ?? 'Failed to send OTP');
    }
  }

  /// Verify OTP and Reset Password
  /// 
  /// Parameters:
  /// - email: User email (optional if phone provided)
  /// - phone: User phone (optional if email provided)
  /// - otp: OTP code
  /// - newPassword: New password
  /// 
  /// Returns: Success message
  static Future<String> verifyOtpAndResetPassword({
    String? email,
    String? phone,
    required String otp,
    required String newPassword,
  }) async {
    if (email == null && phone == null) {
      throw ApiException('Email or phone is required');
    }

    final body = <String, dynamic>{
      'otp': otp,
      'new_password': newPassword,
    };

    if (email != null) {
      body['email'] = email;
    } else {
      body['phone'] = phone;
    }

    final response = await ApiService.post(
      '${ApiConfig.auth}?action=verify-otp',
      body: body,
    );

    if (response['success'] == true) {
      return response['message'] ?? 'Password reset successful';
    } else {
      throw ApiException(response['message'] ?? 'Failed to reset password');
    }
  }

  /// Google OAuth Login/Register
  /// 
  /// Parameters:
  /// - googleId: Google user ID
  /// - email: User email
  /// - name: User name
  /// - profilePicture: Profile picture URL (optional)
  /// 
  /// Returns: User data with selected fruits
  static Future<Map<String, dynamic>> googleAuth({
    required String googleId,
    required String email,
    required String name,
    String? profilePicture,
  }) async {
    final body = <String, dynamic>{
      'google_id': googleId,
      'email': email,
      'name': name,
      'role': 'User', // Default role for social login
    };

    if (profilePicture != null) {
      body['profile_picture'] = profilePicture;
    }

    final response = await ApiService.post(
      '${ApiConfig.auth}?action=google-auth',
      body: body,
    );

    if (response['success'] == true && response['data'] != null) {
      return response['data'] as Map<String, dynamic>;
    } else {
      throw ApiException(response['message'] ?? 'Google authentication failed');
    }
  }

  /// Facebook OAuth Login/Register
  /// 
  /// Parameters:
  /// - facebookId: Facebook user ID
  /// - email: User email
  /// - name: User name
  /// - profilePicture: Profile picture URL (optional)
  /// 
  /// Returns: User data with selected fruits
  static Future<Map<String, dynamic>> facebookAuth({
    required String facebookId,
    required String email,
    required String name,
    String? profilePicture,
  }) async {
    final body = <String, dynamic>{
      'facebook_id': facebookId,
      'email': email,
      'name': name,
    };

    if (profilePicture != null) {
      body['profile_picture'] = profilePicture;
    }

    final response = await ApiService.post(
      '${ApiConfig.auth}?action=facebook-auth',
      body: body,
    );

    if (response['success'] == true && response['data'] != null) {
      return response['data'] as Map<String, dynamic>;
    } else {
      throw ApiException(response['message'] ?? 'Facebook authentication failed');
    }
  }

  /// Phone/Email OTP Login/Register
  /// 
  /// Parameters:
  /// - email: User email (optional if phone provided)
  /// - phone: User phone (optional if email provided)
  /// - otp: OTP code received via SMS/Email
  /// 
  /// Returns: User data with selected fruits
  static Future<Map<String, dynamic>> phoneOtpLogin({
    String? email,
    String? phone,
    required String otp,
  }) async {
    if (email == null && phone == null) {
      throw ApiException('Email or phone is required');
    }

    final body = <String, dynamic>{
      'otp': otp,
    };

    if (email != null) {
      body['email'] = email;
    } else {
      body['phone'] = phone;
    }

    final response = await ApiService.post(
      '${ApiConfig.auth}?action=phone-otp-login',
      body: body,
    );

    if (response['success'] == true && response['data'] != null) {
      return response['data'] as Map<String, dynamic>;
    } else {
      throw ApiException(response['message'] ?? 'OTP login failed');
    }
  }

  /// Apple Sign In Login/Register
  /// 
  /// Parameters:
  /// - appleId: Apple user ID (unique identifier)
  /// - email: User email (may be private relay email)
  /// - name: User name (first time only, may be null)
  /// - identityToken: JWT identity token from Apple
  /// - authorizationCode: Authorization code from Apple
  /// 
  /// Returns: User data with selected fruits
  static Future<Map<String, dynamic>> appleAuth({
    required String appleId,
    String? email,
    String? name,
    String? identityToken,
    String? authorizationCode,
  }) async {
    if (appleId.isEmpty) {
      throw ApiException('Apple ID is required');
    }

    final body = <String, dynamic>{
      'apple_id': appleId,
    };

    if (email != null && email.isNotEmpty) {
      body['email'] = email;
    }

    if (name != null && name.isNotEmpty) {
      body['name'] = name;
    }

    if (identityToken != null && identityToken.isNotEmpty) {
      body['identity_token'] = identityToken;
    }

    if (authorizationCode != null && authorizationCode.isNotEmpty) {
      body['authorization_code'] = authorizationCode;
    }

    final response = await ApiService.post(
      '${ApiConfig.auth}?action=apple-auth',
      body: body,
    );

    if (response['success'] == true && response['data'] != null) {
      return response['data'] as Map<String, dynamic>;
    } else {
      throw ApiException(response['message'] ?? 'Apple authentication failed');
    }
  }
}

