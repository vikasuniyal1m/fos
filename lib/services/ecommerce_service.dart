import '../config/api_config.dart';
import 'api_service.dart';

/// E-Commerce Service
/// Handles e-commerce store URL/link
class EcommerceService {
  /// Get E-Commerce URL
  /// 
  /// Returns: E-commerce URL configuration
  static Future<Map<String, dynamic>> getEcommerceUrl() async {
    try {
      final response = await ApiService.get(
        '${ApiConfig.baseUrl}/ecommerce.php',
      );

      if (response['success'] == true && response['data'] != null) {
        return response['data'] as Map<String, dynamic>;
      } else {
        // Fallback to default
        return {
          'url': 'https://your-ecommerce-app-url.com',
          'type': 'web',
        };
      }
    } catch (e) {
      // Fallback to default on error
      return {
        'url': 'https://your-ecommerce-app-url.com',
        'type': 'web',
      };
    }
  }
}

