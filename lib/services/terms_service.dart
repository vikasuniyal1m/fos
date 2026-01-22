import '../config/api_config.dart';
import 'api_service.dart';
import 'user_storage.dart' as us;

/// Terms & Conditions Service
/// Handles fetching terms content from backend and local acceptance status
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

  /// Check if user has accepted UGC terms
  static Future<bool> hasAcceptedTerms() async {
    return await us.UserStorage.hasAcceptedUgcTerms();
  }

  /// Accept UGC terms
  static Future<void> acceptTerms() async {
    await us.UserStorage.setUgcTermsAccepted(true);
  }
}

