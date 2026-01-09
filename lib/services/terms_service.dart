import '../config/api_config.dart';
import 'api_service.dart';

/// Terms & Conditions Service
/// Handles fetching terms content from backend
class TermsService {
  /// Get Terms & Conditions Content
  /// 
  /// Returns: Terms content with version and updated date
  static Future<Map<String, dynamic>> getTerms() async {
    final response = await ApiService.get(
      ApiConfig.terms,
    );

    if (response['success'] == true && response['data'] != null) {
      return response['data'] as Map<String, dynamic>;
    } else {
      throw ApiException(response['message'] ?? 'Failed to fetch terms');
    }
  }
}

