import '../config/api_config.dart';
import 'api_service.dart';

/// Fruits of the Spirit Service
/// Handles fruits listing, user fruits selection
class FruitsService {
  /// Get All Fruits
  /// 
  /// Returns: List of all fruits with active users count
  static Future<List<Map<String, dynamic>>> getAllFruits() async {
    final response = await ApiService.get(ApiConfig.fruits);

    if (response['success'] == true && response['data'] != null) {
      return List<Map<String, dynamic>>.from(response['data']);
    } else {
      throw ApiException(response['message'] ?? 'Failed to fetch fruits');
    }
  }

  /// Get User's Selected Fruits
  /// 
  /// Parameters:
  /// - userId: User ID
  /// 
  /// Returns: List of fruits with selection status
  static Future<List<Map<String, dynamic>>> getUserFruits(int userId) async {
    final response = await ApiService.get(
      ApiConfig.fruits,
      queryParameters: {'user_id': userId.toString()},
    );

    if (response['success'] == true && response['data'] != null) {
      return List<Map<String, dynamic>>.from(response['data']);
    } else {
      throw ApiException(response['message'] ?? 'Failed to fetch user fruits');
    }
  }

  /// Add Fruit to User
  /// 
  /// Parameters:
  /// - userId: User ID
  /// - fruitId: Fruit ID to add
  /// 
  /// Returns: Success message
  static Future<String> addFruitToUser({
    required int userId,
    required int fruitId,
  }) async {
    final response = await ApiService.post(
      ApiConfig.fruits,
      body: {
        'user_id': userId.toString(),
        'fruit_id': fruitId.toString(),
      },
    );

    if (response['success'] == true) {
      return response['message'] ?? 'Fruit added successfully';
    } else {
      throw ApiException(response['message'] ?? 'Failed to add fruit');
    }
  }

  /// Remove Fruit from User
  /// 
  /// Parameters:
  /// - userId: User ID
  /// - fruitId: Fruit ID to remove
  /// 
  /// Returns: Success message
  static Future<String> removeFruitFromUser({
    required int userId,
    required int fruitId,
  }) async {
    final response = await ApiService.delete(
      ApiConfig.fruits,
      queryParameters: {
        'user_id': userId.toString(),
        'fruit_id': fruitId.toString(),
      },
    );

    if (response['success'] == true) {
      return response['message'] ?? 'Fruit removed successfully';
    } else {
      throw ApiException(response['message'] ?? 'Failed to remove fruit');
    }
  }
}

