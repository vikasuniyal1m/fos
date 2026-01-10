import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../config/api_config.dart';

/// Base API Service
/// Handles common API operations, error handling, and response parsing
class ApiService {
  /// Handle API response and errors
  static Future<Map<String, dynamic>> _handleResponse(http.Response response) async {
    try {
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else if (response.statusCode == 401) {
        // Try to parse error message from response
        try {
          if (response.body.isNotEmpty) {
            final errorBody = response.body.isNotEmpty ? jsonDecode(response.body) : {'message': 'Unknown error'};
            final errorMsg = errorBody['message'] ?? 'Invalid credentials. Please try again.';
            print('❌ 401 Error message: $errorMsg');
            throw ApiException(errorMsg, statusCode: 401);
          } else {
            throw ApiException('Invalid credentials. Please try again.', statusCode: 401);
          }
        } catch (e) {
          if (e is ApiException) {
            rethrow;
          }
          throw ApiException('Invalid credentials. Please try again.', statusCode: 401);
        }
      } else if (response.statusCode == 400) {
        final errorBody = response.body.isNotEmpty ? jsonDecode(response.body) : {'message': 'Bad request'};
        throw ApiException(errorBody['message'] ?? 'Bad request', statusCode: 400);
      } else if (response.statusCode == 403) {
        // Forbidden - approval pending or account inactive
        final errorBody = jsonDecode(response.body);
        // Return the response so AuthService can handle it properly
        return errorBody;
      } else if (response.statusCode == 404) {
        // Try to parse error message from response
        try {
          if (response.body.isNotEmpty) {
            final errorBody = jsonDecode(response.body);
            final errorMsg = errorBody['message'] ?? 'Resource not found';
            print('❌ 404 Error message: $errorMsg');
            throw ApiException(errorMsg, statusCode: 404);
          } else {
            throw ApiException('Resource not found', statusCode: 404);
          }
        } catch (e) {
          if (e is ApiException) {
            rethrow;
          }
          throw ApiException('Resource not found', statusCode: 404);
        }
      } else if (response.statusCode >= 500) {
        // Try to parse error message from response and log full details for debugging
        try {
          if (response.body.isNotEmpty) {
            final errorBody = jsonDecode(response.body);
            final errorMsg = errorBody['message'] ?? 'Server error. Please try again later.';
            print('❌ Server error ${response.statusCode}: $errorMsg');
            print('❌ Full server error body: $errorBody');
            if (errorBody is Map && errorBody['error_details'] != null) {
              print('❌ Server error details: ${errorBody['error_details']}');
            }
            throw ApiException(errorMsg, statusCode: response.statusCode);
          } else {
            print('❌ Server error with empty response body (status: ${response.statusCode})');
            throw ApiException('Server error. Please try again later.', statusCode: response.statusCode);
          }
        } catch (e) {
          if (e is ApiException) {
            rethrow;
          }
          print('❌ Failed to parse error response: $e');
          print('❌ Raw response body was: ${response.body}');
          throw ApiException('Server error. Please try again later. (Status: ${response.statusCode})', statusCode: response.statusCode);
        }
      } else {
        final errorBody = response.body.isNotEmpty ? jsonDecode(response.body) : {'message': 'Something went wrong'};
        throw ApiException(errorBody['message'] ?? 'Something went wrong', statusCode: response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('Failed to parse response: ${e.toString()}');
    }
  }

  /// GET request
  static Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
  }) async {
    try {
      Uri uri = Uri.parse(endpoint);
      if (queryParameters != null && queryParameters.isNotEmpty) {
        // Merge with existing query parameters instead of replacing
        final existingParams = uri.queryParameters;
        final mergedParams = Map<String, String>.from(existingParams);
        mergedParams.addAll(queryParameters);
        uri = uri.replace(queryParameters: mergedParams);
      }
      
      // Add cache-control headers for group chat messages to ensure fresh data
      final requestHeaders = Map<String, String>.from(headers ?? ApiConfig.headers);
      if (endpoint.contains('groups.php') && (queryParameters?['action'] == 'messages' || uri.queryParameters['action'] == 'messages')) {
        requestHeaders['Cache-Control'] = 'no-cache, no-store, must-revalidate';
        requestHeaders['Pragma'] = 'no-cache';
        requestHeaders['Expires'] = '0';
      }

      final response = await http
          .get(
            uri,
            headers: requestHeaders,
          )
          .timeout(ApiConfig.timeout);

      final result = await _handleResponse(response);
      return result;
    } on SocketException catch (e) {
      throw NetworkException('No internet connection');
    } on HttpException catch (e) {
      throw NetworkException('Network error occurred');
    } on FormatException catch (e) {
      throw ApiException('Invalid response format');
    } catch (e) {
      if (e is ApiException || e is NetworkException) {
        rethrow;
      }
      throw ApiException('Request failed: ${e.toString()}');
    }
  }

  /// POST request (form data)
  static Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    print('🌐 ========== API POST REQUEST START ==========');
    print('🌐 Endpoint: $endpoint');
    print('🌐 Body: $body');
    print('🌐 Headers: ${headers ?? ApiConfig.headers}');
    
    try {
      final encodedBody = body != null ? _encodeFormData(body) : null;
      print('🌐 Encoded Body: $encodedBody');
      print('🌐 Final URL: $endpoint');
      print('🌐 Making HTTP POST request...');
      
      final response = await http
          .post(
            Uri.parse(endpoint),
            headers: headers ?? ApiConfig.headers,
            body: encodedBody,
          )
          .timeout(ApiConfig.timeout);

      print('🌐 ========== HTTP RESPONSE RECEIVED ==========');
      print('🌐 Status Code: ${response.statusCode}');
      print('🌐 Response Headers: ${response.headers}');
      print('🌐 Response Body Length: ${response.body.length}');
      print('🌐 Response Body (first 500 chars): ${response.body.length > 500 ? response.body.substring(0, 500) + "..." : response.body}');

      final result = await _handleResponse(response);
      print('🌐 ========== API POST REQUEST SUCCESS ==========');
      return result;
    } on SocketException {
      throw NetworkException('No internet connection');
    } on HttpException {
      throw NetworkException('Network error occurred');
    } on FormatException {
      throw ApiException('Invalid response format');
    } catch (e) {
      if (e is ApiException || e is NetworkException) {
        rethrow;
      }
      throw ApiException('Request failed: ${e.toString()}');
    }
  }

  /// POST request (JSON)
  static Future<Map<String, dynamic>> postJson(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(endpoint),
            headers: headers ?? ApiConfig.jsonHeaders,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(ApiConfig.timeout);

      return await _handleResponse(response);
    } on SocketException {
      throw NetworkException('No internet connection');
    } on HttpException {
      throw NetworkException('Network error occurred');
    } on FormatException {
      throw ApiException('Invalid response format');
    } catch (e) {
      if (e is ApiException || e is NetworkException) {
        rethrow;
      }
      throw ApiException('Request failed: ${e.toString()}');
    }
  }

  /// POST request with multipart (for file uploads)
  static Future<Map<String, dynamic>> postMultipart(
    String endpoint, {
    Map<String, String>? fields,
    Map<String, File>? files,
    Map<String, String>? headers,
  }) async {
    print('🌐 ========== API POST MULTIPART REQUEST START ==========');
    print('🌐 Endpoint: $endpoint');
    print('🌐 Fields: $fields');
    print('🌐 Files: ${files?.keys.toList()}');
    print('🌐 Headers: ${headers ?? ApiConfig.headers}');
    
    try {
      var request = http.MultipartRequest('POST', Uri.parse(endpoint));
      
      // Add headers (but exclude Content-Type - MultipartRequest sets it automatically with boundary)
      final headersToAdd = <String, String>{};
      if (headers != null) {
        headersToAdd.addAll(headers);
      } else {
        headersToAdd.addAll(ApiConfig.headers);
      }
      // Remove Content-Type - MultipartRequest will set it automatically with boundary
      headersToAdd.remove('Content-Type');
      request.headers.addAll(headersToAdd);
      
      print('🌐 Request headers (Content-Type will be set automatically by MultipartRequest): ${request.headers}');
      
      // Add fields
      if (fields != null) {
        request.fields.addAll(fields);
        print('🌐 Added ${fields.length} fields to request');
        print('🌐 Field names: ${fields.keys.toList()}');
        print('🌐 Field values: ${fields.map((k, v) => MapEntry(k, v.length > 50 ? '${v.substring(0, 50)}...' : v))}');
      }
      
      // Add files
      if (files != null) {
        for (var entry in files.entries) {
          final filePath = entry.value.path;
          final file = entry.value;
          
          // Read file bytes to detect actual file format
          final bytes = await file.readAsBytes();
          String detectedExtension = 'mp4'; // Default for videos
          String contentType = 'video/mp4'; // Default for videos
          
          // Get original filename and extension first (for fallback)
          final originalFileName = filePath.split('/').last;
          final originalExtension = originalFileName.contains('.') 
              ? originalFileName.split('.').last.toLowerCase().trim()
              : '';
          
          // Detect file format from magic bytes (file signature)
          if (bytes.length >= 4) {
            // Check for PNG: 89 50 4E 47
            if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) {
              detectedExtension = 'png';
              contentType = 'image/png';
            }
            // Check for JPEG: FF D8 FF
            else if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
              detectedExtension = 'jpg';
              contentType = 'image/jpeg';
            }
            // Check for GIF: 47 49 46 38 (GIF8)
            else if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x38) {
              detectedExtension = 'gif';
              contentType = 'image/gif';
            }
            // Check for WebP: RIFF...WEBP
            else if (bytes.length >= 12 &&
                     bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 &&
                     bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50) {
              detectedExtension = 'webp';
              contentType = 'image/webp';
            }
            // Check for MP4: ftyp box at offset 4 (00 00 00 XX 66 74 79 70)
            else if (bytes.length >= 8 && bytes[4] == 0x66 && bytes[5] == 0x74 && bytes[6] == 0x79 && bytes[7] == 0x70) {
              detectedExtension = 'mp4';
              contentType = 'video/mp4';
            }
            // Check for MOV/QuickTime: ftyp box with qt or mov
            else if (bytes.length >= 12 &&
                     bytes[4] == 0x66 && bytes[5] == 0x74 && bytes[6] == 0x79 && bytes[7] == 0x70 &&
                     ((bytes[8] == 0x71 && bytes[9] == 0x74) || // qt
                      (bytes[8] == 0x6D && bytes[9] == 0x6F && bytes[10] == 0x76))) { // mov
              detectedExtension = 'mov';
              contentType = 'video/quicktime';
            }
            // Check for AVI: RIFF...AVI
            else if (bytes.length >= 12 &&
                     bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 &&
                     bytes[8] == 0x41 && bytes[9] == 0x56 && bytes[10] == 0x49 && bytes[11] == 0x20) {
              detectedExtension = 'avi';
              contentType = 'video/x-msvideo';
            }
            // Check for WMV: 30 26 B2 75 8E 66 CF 11
            else if (bytes.length >= 8 &&
                     bytes[0] == 0x30 && bytes[1] == 0x26 && bytes[2] == 0xB2 && bytes[3] == 0x75 &&
                     bytes[4] == 0x8E && bytes[5] == 0x66 && bytes[6] == 0xCF && bytes[7] == 0x11) {
              detectedExtension = 'wmv';
              contentType = 'video/x-ms-wmv';
            }
            // Check for FLV: 46 4C 56 01 (FLV)
            else if (bytes.length >= 4 &&
                     bytes[0] == 0x46 && bytes[1] == 0x4C && bytes[2] == 0x56 && bytes[3] == 0x01) {
              detectedExtension = 'flv';
              contentType = 'video/x-flv';
            }
            // Check for WebM: 1A 45 DF A3 (EBML header)
            else if (bytes.length >= 4 &&
                     bytes[0] == 0x1A && bytes[1] == 0x45 && bytes[2] == 0xDF && bytes[3] == 0xA3) {
              detectedExtension = 'webm';
              contentType = 'video/webm';
            }
            // If no format detected, try to use original extension if it's a valid video format
            else if (originalExtension.isNotEmpty) {
              final validVideoExtensions = ['mp4', 'mov', 'avi', 'wmv', 'flv', 'webm'];
              if (validVideoExtensions.contains(originalExtension)) {
                detectedExtension = originalExtension;
                // Set appropriate content type based on extension
                switch (originalExtension) {
                  case 'mp4':
                    contentType = 'video/mp4';
                    break;
                  case 'mov':
                    contentType = 'video/quicktime';
                    break;
                  case 'avi':
                    contentType = 'video/x-msvideo';
                    break;
                  case 'wmv':
                    contentType = 'video/x-ms-wmv';
                    break;
                  case 'flv':
                    contentType = 'video/x-flv';
                    break;
                  case 'webm':
                    contentType = 'video/webm';
                    break;
                  default:
                    contentType = 'video/mp4';
                }
              } else {
                // Default to mp4 for videos if extension is not recognized
                detectedExtension = 'mp4';
                contentType = 'video/mp4';
              }
            }
          }
          
          // Always use detected extension to ensure it matches the actual file format
          // This is more reliable than trusting the filename extension
          final String finalExtension = detectedExtension;
          
          // Create a clean filename with the detected extension
          // Remove any existing extension and add the correct one
          String baseName = originalFileName;
          if (originalFileName.contains('.')) {
            // Remove all extensions (handle cases like "image.jpg.tmp")
            baseName = originalFileName.substring(0, originalFileName.lastIndexOf('.'));
          }
          
          // Ensure baseName is not empty and create final filename
          if (baseName.isEmpty) {
            baseName = 'photo';
          }
          // Clean the base name (remove any invalid characters)
          baseName = baseName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
          final finalFileName = '$baseName.$finalExtension';
          
          // Log for debugging
          print('📤 Uploading file:');
          print('   Original path: $filePath');
          print('   Original filename: $originalFileName');
          print('   Original extension: $originalExtension');
          print('   Detected extension: $detectedExtension');
          print('   Final filename: $finalFileName');
          print('   Content type: $contentType');
          print('   File size: ${bytes.length} bytes');
          
          // Create multipart file with correct filename and content type
          var multipartFile = http.MultipartFile.fromBytes(
            entry.key,
            bytes,
            filename: finalFileName,
            contentType: MediaType.parse(contentType),
          );
          
          request.files.add(multipartFile);
        }
      }

      print('🌐 Sending multipart request...');
      final streamedResponse = await request.send().timeout(ApiConfig.timeout);
      print('🌐 Request sent, waiting for response...');
      
      final response = await http.Response.fromStream(streamedResponse);

      // Log response for debugging
      print('📥 ========== API POST MULTIPART RESPONSE ==========');
      print('📥 Response status: ${response.statusCode}');
      print('📥 Response headers: ${response.headers}');
      print('📥 Response body length: ${response.body.length}');
      print('📥 Response body: ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}');
      
      return await _handleResponse(response);
    } on SocketException {
      throw NetworkException('No internet connection');
    } on HttpException {
      throw NetworkException('Network error occurred');
    } catch (e) {
      if (e is ApiException || e is NetworkException) {
        rethrow;
      }
      throw ApiException('Request failed: ${e.toString()}');
    }
  }

  /// PUT request
  static Future<Map<String, dynamic>> put(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    try {
      final response = await http
          .put(
            Uri.parse(endpoint),
            headers: headers ?? ApiConfig.headers,
            body: body != null ? _encodeFormData(body) : null,
          )
          .timeout(ApiConfig.timeout);

      return await _handleResponse(response);
    } on SocketException {
      throw NetworkException('No internet connection');
    } on HttpException {
      throw NetworkException('Network error occurred');
    } on FormatException {
      throw ApiException('Invalid response format');
    } catch (e) {
      if (e is ApiException || e is NetworkException) {
        rethrow;
      }
      throw ApiException('Request failed: ${e.toString()}');
    }
  }

  /// DELETE request
  static Future<Map<String, dynamic>> delete(
    String endpoint, {
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
  }) async {
    try {
      Uri uri = Uri.parse(endpoint);
      if (queryParameters != null && queryParameters.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParameters);
      }

      final response = await http
          .delete(
            uri,
            headers: headers ?? ApiConfig.headers,
          )
          .timeout(ApiConfig.timeout);

      return await _handleResponse(response);
    } on SocketException {
      throw NetworkException('No internet connection');
    } on HttpException {
      throw NetworkException('Network error occurred');
    } catch (e) {
      if (e is ApiException || e is NetworkException) {
        rethrow;
      }
      throw ApiException('Request failed: ${e.toString()}');
    }
  }

  /// Encode form data
  static String _encodeFormData(Map<String, dynamic> data) {
    return data.entries
        .map((e) {
          // Special handling for emoji values - preserve UTF-8 encoding
          String value = e.value.toString();
          // For emoji characters, use proper UTF-8 encoding
          if (e.key == 'emoji' && value.runes.length > 0) {
            // Encode emoji properly for form data
            return '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(value)}';
          }
          return '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(value)}';
        })
        .join('&');
  }
}

/// Custom Exceptions
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

class ApprovalPendingException extends ApiException {
  final String status;
  final String role;
  
  ApprovalPendingException(
    String message, {
    required this.status,
    required this.role,
  }) : super(message, statusCode: 403);
  
  @override
  String toString() => 'ApprovalPendingException: $message (Status: $status, Role: $role)';
}

class RoleMismatchException extends ApiException {
  final String correctRole;
  
  RoleMismatchException(
    String message, {
    required this.correctRole,
  }) : super(message, statusCode: 403);
  
  @override
  String toString() => 'RoleMismatchException: $message (Correct Role: $correctRole)';
}

