
import 'package:translator/translator.dart';

import '../config/api_config.dart';
import 'api_service.dart';

/// Translation Service
/// Handles multi-language support using Google Translate API
class TranslateService {
  /// In-memory cache: key = 'text_hash|source|target', value = translated text.
  /// Used by See Translation so same text is not re-fetched.
  static final Map<String, String> _translationCache = {};

  static String _cacheKey(String text, String source, String target) {
    // Use hash for long text to avoid huge keys
    final hash = text.length > 200 ? '${text.length}_${text.hashCode}' : text;
    return '$hash|$source|$target';
  }

  /// Get cached translation if available.
  static String? getCachedTranslation({
    required String text,
    required String targetLanguage,
    String? sourceLanguage,
  }) {
    final source = sourceLanguage ?? 'auto';
    return _translationCache[_cacheKey(text, source, targetLanguage)];
  }

  /// Clear translation cache (e.g. on logout or when needed).
  static void clearTranslationCache() {
    _translationCache.clear();
  }

  /// Translate Text
  /// 
  /// Parameters:
  /// - text: Text to translate
  /// - targetLanguage: Target language code (e.g., 'es', 'fr', 'de')
  /// - sourceLanguage: Source language code (optional, auto-detect if not provided)
  /// 
  /// Returns: Translated text with language info. Uses cache when available.
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

      final source = sourceLanguage ?? 'auto';
      final key = _cacheKey(text, source, targetLanguage);
      final cached = _translationCache[key];
      if (cached != null) {
        return {'translated_text': cached};
      }

      final body = <String, dynamic>{
        'text': text,
        'target': targetLanguage,
      };

      if (sourceLanguage != null && sourceLanguage.isNotEmpty) {
        body['source'] = sourceLanguage;
      }

      try {
        final response = await ApiService.post(
          '${ApiConfig.translate}?action=translate',
          body: body,
        );

        if (response['success'] == true && response['data'] != null) {
          final data = response['data'] as Map<String, dynamic>;
          final translatedText = data['translated_text'] as String?;
          if (translatedText != null && translatedText.isNotEmpty) {
            _translationCache[key] = translatedText;
          }
          return data;
        }
      } catch (_) {
        // Server failed (503, no API key, etc.) — fall through to free local fallback
      }

      // Fallback: use local translator package (no API key / no card needed)
      try {
        final translatedText = await _translateWithLocalPackage(
          text: text,
          targetLanguage: targetLanguage,
          sourceLanguage: sourceLanguage,
        );
        if (translatedText != null && translatedText.isNotEmpty) {
          _translationCache[key] = translatedText;
          return {'translated_text': translatedText};
        }
      } catch (_) {}

      throw ApiException('Translation unavailable');
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      // Last chance: local translator (no card / no server key needed)
      try {
        final translatedText = await _translateWithLocalPackage(
          text: text,
          targetLanguage: targetLanguage,
          sourceLanguage: sourceLanguage,
        );
        if (translatedText != null && translatedText.isNotEmpty) {
          final cacheKey = _cacheKey(text, sourceLanguage ?? 'auto', targetLanguage);
          _translationCache[cacheKey] = translatedText;
          return {'translated_text': translatedText};
        }
      } catch (_) {}
      throw ApiException('Translation failed: ${e.toString()}');
    }
  }

  /// Free local translation (no API key, no card) — uses translator package.
  static Future<String?> _translateWithLocalPackage({
    required String text,
    required String targetLanguage,
    String? sourceLanguage,
  }) async {
    final translator = GoogleTranslator();
    if (targetLanguage.isEmpty) return null;
    try {
      final result = sourceLanguage != null && sourceLanguage.isNotEmpty && sourceLanguage != 'auto'
          ? await translator.translate(text, from: sourceLanguage, to: targetLanguage)
          : await translator.translate(text, to: targetLanguage);
      return result.text;
    } catch (_) {
      return null;
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

