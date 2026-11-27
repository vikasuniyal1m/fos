import '../config/api_config.dart';
import 'api_service.dart';

/// Prayer Types Service
/// Handles prayer types listing and creation
class PrayerTypesService {
  /// Get Prayer Types
  ///
  /// Returns: List of prayer types
  static Future<List<String>> getPrayerTypes() async {
    try {
      final response = await ApiService.get(
        ApiConfig.prayerTypes,
      );

      if (response['success'] == true && response['data'] != null) {
        return List<String>.from(response['data']);
      }
      return [];
    } catch (e) {
      print('Error fetching prayer types: $e');
      return [];
    }
  }

  /// Add Prayer Type
  /// 
  /// Parameters:
  /// - typeName: Name of the prayer type
  /// - userId: User ID creating the prayer type
  /// 
  /// Returns: Success response
  static Future<Map<String, dynamic>> addPrayerType({
    required String typeName,
    required int userId,
  }) async {
    final body = {
      'type_name': typeName,
      'user_id': userId.toString(),
    };

    final response = await ApiService.post(
      ApiConfig.prayerTypes,
      body: body,
    );

    if (response['success'] == true) {
      return response;
    } else {
      throw ApiException(response['message'] ?? 'Failed to add prayer type');
    }
  }
}
