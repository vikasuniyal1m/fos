import '../config/api_config.dart';
import 'api_service.dart';

/// Fruit of the Spirit Service
/// Handles fruit listing, user fruit selection
class FruitService {
  /// Get All Fruit
  /// 
  /// Returns: List of all fruit with active users count
  static Future<List<Map<String, dynamic>>> getAllFruit() async {
    final response = await ApiService.get(ApiConfig.fruit);

    if (response['success'] == true && response['data'] != null) {
      return List<Map<String, dynamic>>.from(response['data']);
    } else {
      throw ApiException(response['message'] ?? 'Failed to fetch fruit');
    }
  }

  /// Get User's Selected Fruit
  /// 
  /// Parameters:
  /// - userId: User ID
  /// 
  /// Returns: List of fruit with selection status
  static Future<List<Map<String, dynamic>>> getUserFruit(int userId) async {
    final response = await ApiService.get(
      ApiConfig.fruit,
      queryParameters: {'user_id': userId.toString()},
    );

    if (response['success'] == true && response['data'] != null) {
      return List<Map<String, dynamic>>.from(response['data']);
    } else {
      throw ApiException(response['message'] ?? 'Failed to fetch user fruit');
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
      ApiConfig.fruit,
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
      ApiConfig.fruit,
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

