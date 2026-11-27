import '../config/api_config.dart';
import 'api_service.dart';

class DenominationsService {
  /// Fetch all denominations
  static Future<List<Map<String, dynamic>>> getAllDenominations() async {
    try {
      final response = await ApiService.get(
        '${ApiConfig.denominations}?action=get_all',
      );

      if (response['success'] == true && response['data'] != null) {
        return List<Map<String, dynamic>>.from(response['data']);
      } else {
        throw ApiException(response['message'] ?? 'Failed to load denominations');
      }
    } catch (e) {
      throw ApiException(e.toString());
    }
  }
}
