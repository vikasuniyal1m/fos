import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

// Custom Exceptions
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException: $message';
}

class NetworkException extends ApiException {
  NetworkException(String message) : super(message);
}

class AuthException extends ApiException {
  AuthException(String message, {int? statusCode}) : super(message, statusCode: statusCode);
}

class ValidationException extends ApiException {
  final Map<String, dynamic> errors;
  ValidationException(String message, this.errors) : super(message);

  @override
  String toString() => 'ValidationException: $message, Errors: $errors';
}

class ServerException extends ApiException {
  ServerException(String message, {int? statusCode}) : super(message, statusCode: statusCode);
}

class OtpService {
  // Use the same base URL as the rest of the app
  final String _baseUrl = ApiConfig.baseUrl;

  Future<Map<String, dynamic>> _handleResponse(http.Response response) async {
    // Check if response body is empty
    if (response.body.trim().isEmpty) {
      print('⚠️ Empty response body. Status code: ${response.statusCode}');
      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Request processed successfully'};
      } else {
        throw ApiException('Server returned empty response', statusCode: response.statusCode);
      }
    }

    // Try to parse JSON response
    try {
      final responseBody = jsonDecode(response.body);
      
    if (response.statusCode == 200) {
        return responseBody is Map<String, dynamic> ? responseBody : {'data': responseBody};
    } else if (response.statusCode == 401) {
        throw AuthException(
          responseBody is Map ? (responseBody['message'] ?? 'Unauthorized') : 'Unauthorized',
          statusCode: response.statusCode,
        );
    } else if (response.statusCode == 422) {
        if (responseBody is Map) {
          throw ValidationException(
            responseBody['message'] ?? 'Validation failed',
            responseBody['errors'] is Map ? Map<String, dynamic>.from(responseBody['errors']) : {},
          );
        } else {
          throw ValidationException('Validation failed', {});
        }
    } else if (response.statusCode >= 400 && response.statusCode < 500) {
        throw ApiException(
          responseBody is Map ? (responseBody['message'] ?? 'Client error') : 'Client error',
          statusCode: response.statusCode,
        );
    } else if (response.statusCode >= 500) {
        throw ServerException(
          responseBody is Map ? (responseBody['message'] ?? 'Server error') : 'Server error',
          statusCode: response.statusCode,
        );
    } else {
      throw ApiException('Something went wrong', statusCode: response.statusCode);
      }
    } catch (e) {
      if (e is ApiException || e is AuthException || e is ValidationException || e is ServerException) {
        rethrow;
      }
      // JSON parsing error
      print('❌ Failed to parse response: $e');
      print('❌ Response body: ${response.body}');
      print('❌ Status code: ${response.statusCode}');
      throw ApiException('Failed to parse response: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> sendOtp(String emailOrPhone) async {
    try {
      // Determine if input is email or phone
      final isEmail = emailOrPhone.contains('@') && emailOrPhone.contains('.');
      
      // Use auth.php with forgot-password action (which sends OTP)
      final url = Uri.parse('${ApiConfig.auth}?action=forgot-password');
      
      // Use form-urlencoded format as per ApiConfig
      final requestBody = isEmail 
          ? {'email': emailOrPhone}
          : {'phone': emailOrPhone};
      
      print('📤 Sending OTP request to: $url');
      print('📤 Request body: $requestBody');
      print('📤 Is Email: $isEmail');
      
      // http.post automatically encodes Map<String, String> as form-urlencoded
      final response = await http.post(
        url,
        headers: ApiConfig.headers, // Use standard headers (form-urlencoded)
        body: requestBody,
      );
      
      print('📥 OTP Response status: ${response.statusCode}');
      print('📥 OTP Response body: ${response.body}');
      print('📥 OTP Response body length: ${response.body.length}');
      print('📥 OTP Response headers: ${response.headers}');
      
      return _handleResponse(response);
    } on SocketException {
      throw NetworkException('No internet connection');
    } catch (e) {
      print('❌ OTP Send Error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> verifyOtp(String emailOrPhone, String otpCode) async {
    try {
      // Determine if input is email or phone
      final isEmail = emailOrPhone.contains('@') && emailOrPhone.contains('.');
      
      // Use auth.php with verify-otp action
      final url = Uri.parse('${ApiConfig.auth}?action=verify-otp');
      
      // Use form-urlencoded format as per ApiConfig
      final requestBody = {
        if (isEmail) 'email': emailOrPhone else 'phone': emailOrPhone,
        'otp': otpCode,
      };
      
      print('📤 Verifying OTP request to: $url');
      print('📤 Request body: $requestBody');
      print('📤 Is Email: $isEmail');
      
      // Use ApiService.post which handles form encoding properly
      // But since we're in OtpService, we'll encode manually
      final response = await http.post(
        url,
        headers: ApiConfig.headers, // Use standard headers (form-urlencoded)
        body: requestBody, // http.post automatically encodes Map<String, String> as form-urlencoded
      );
      
      print('📥 OTP Verify Response status: ${response.statusCode}');
      print('📥 OTP Verify Response body: ${response.body}');
      print('📥 OTP Verify Response body length: ${response.body.length}');
      
      return _handleResponse(response);
    } on SocketException {
      throw NetworkException('No internet connection');
    } catch (e) {
      print('❌ OTP Verify Error: $e');
      rethrow;
    }
  }
}