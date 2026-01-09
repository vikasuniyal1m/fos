import '../config/api_config.dart';
import 'api_service.dart';

/// Translation Service
/// Handles multi-language support using Google Translate API
class TranslateService {
  /// Translate Text
  /// 
  /// Parameters:
  /// - text: Text to translate
  /// - targetLanguage: Target language code (e.g., 'es', 'fr', 'de')
  /// - sourceLanguage: Source language code (optional, auto-detect if not provided)
  /// 
  /// Returns: Translated text with language info
  static Future<Map<String, dynamic>> translate({
    required String text,
    required String targetLanguage,
    String? sourceLanguage,
  }) async {
    try {
      // Validate input
      if (text.isEmpty) {
        throw ApiException('Text to translate cannot be empty');
      }

      if (targetLanguage.isEmpty) {
        throw ApiException('Target language is required');
      }

      final body = <String, dynamic>{
        'text': text,
        'target': targetLanguage,
      };

      if (sourceLanguage != null && sourceLanguage.isNotEmpty) {
        body['source'] = sourceLanguage;
      }

      final response = await ApiService.post(
        '${ApiConfig.translate}?action=translate',
        body: body,
      );

      if (response['success'] == true && response['data'] != null) {
        return response['data'] as Map<String, dynamic>;
      } else {
        final errorMessage = response['message'] ?? 'Translation failed';
        
        // Provide user-friendly error messages
        if (errorMessage.contains('API key')) {
          throw ApiException('Translation service is not configured. Please contact support.');
        } else if (errorMessage.contains('quota') || errorMessage.contains('limit')) {
          throw ApiException('Translation service limit reached. Please try again later.');
        } else {
          throw ApiException(errorMessage);
        }
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('Translation failed: ${e.toString()}');
    }
  }

  /// Detect Language
  /// 
  /// Parameters:
  /// - text: Text to detect language for
  /// 
  /// Returns: Detected language code and confidence
  static Future<Map<String, dynamic>> detectLanguage(String text) async {
    try {
      if (text.isEmpty) {
        throw ApiException('Text cannot be empty for language detection');
      }

      final response = await ApiService.post(
        '${ApiConfig.translate}?action=detect',
        body: {'text': text},
      );

      if (response['success'] == true && response['data'] != null) {
        return response['data'] as Map<String, dynamic>;
      } else {
        final errorMessage = response['message'] ?? 'Language detection failed';
        
        if (errorMessage.contains('API key')) {
          throw ApiException('Translation service is not configured. Please contact support.');
        } else {
          throw ApiException(errorMessage);
        }
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('Language detection failed: ${e.toString()}');
    }
  }

  /// Get Supported Languages
  /// 
  /// Returns: List of supported languages
  static Future<List<Map<String, dynamic>>> getSupportedLanguages() async {
    final response = await ApiService.get(
      '${ApiConfig.translate}?action=languages',
    );

    if (response['success'] == true && response['data'] != null) {
      return List<Map<String, dynamic>>.from(response['data']);
    } else {
      throw ApiException(response['message'] ?? 'Failed to fetch languages');
    }
  }
}

