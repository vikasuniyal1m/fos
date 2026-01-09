import 'package:easy_localization/easy_localization.dart';
import 'package:fruitsofspirit/services/translate_service.dart';
import 'package:fruitsofspirit/utils/localization_helper.dart';
import 'package:get/get.dart';

/// Auto Translate Helper
/// Automatically translates content based on app's current locale
/// No UI widget needed - just use in Text widgets
class AutoTranslateHelper {
  // Cache for translations to avoid repeated API calls
  static final Map<String, String> _translationCache = {};
  
  /// Get translated text automatically
  /// Returns translated text if needed, otherwise original text
  static Future<String> getTranslatedText({
    required String text,
    String? sourceLanguage,
  }) async {
    if (text.isEmpty) return text;

    try {
      final appLocale = LocalizationHelper.getCurrentLocale();
      final appLanguage = appLocale.languageCode;
      
      // Get content language (from database or default to 'en')
      final contentLanguage = sourceLanguage ?? 'en';
      
      // If content language matches app language, no translation needed
      if (contentLanguage == appLanguage) {
        return text;
      }
      
      // If app language is English, show original (no translation)
      if (appLanguage == 'en') {
        return text;
      }
      
      // Check cache first
      final cacheKey = '${text}_${contentLanguage}_$appLanguage';
      if (_translationCache.containsKey(cacheKey)) {
        return _translationCache[cacheKey]!;
      }
      
      // Translate text
      try {
        final result = await TranslateService.translate(
          text: text,
          targetLanguage: appLanguage,
          sourceLanguage: contentLanguage,
        );
        
        final translatedText = result['translated_text'] as String? ?? text;
        
        // Cache the translation
        _translationCache[cacheKey] = translatedText;
        
        return translatedText;
      } catch (e) {
        // If translation fails, return original text
        return text;
      }
    } catch (e) {
      // If any error, return original text
      return text;
    }
  }
  
  /// Get translated text synchronously (returns original if not cached)
  /// Use this for immediate display, translation happens in background
  static String getTranslatedTextSync({
    required String text,
    String? sourceLanguage,
  }) {
    if (text.isEmpty) return text;

    try {
      final appLocale = LocalizationHelper.getCurrentLocale();
      final appLanguage = appLocale.languageCode;
      
      final contentLanguage = sourceLanguage ?? 'en';
      
      // If content language matches app language, no translation needed
      if (contentLanguage == appLanguage) {
        return text;
      }
      
      // If app language is English, show original
      if (appLanguage == 'en') {
        return text;
      }
      
      // Check cache
      final cacheKey = '${text}_${contentLanguage}_$appLanguage';
      if (_translationCache.containsKey(cacheKey)) {
        return _translationCache[cacheKey]!;
      }
      
      // Start translation in background
      getTranslatedText(text: text, sourceLanguage: sourceLanguage).then((translated) {
        // Update cache when translation completes
        _translationCache[cacheKey] = translated;
        // Trigger GetX update to refresh UI
        Get.forceAppUpdate();
      });
      
      // Return original for now, will update when translation completes
      return text;
    } catch (e) {
      return text;
    }
  }
  
  /// Clear translation cache
  static void clearCache() {
    _translationCache.clear();
  }
}

/// Extension for easy use in Text widgets
extension AutoTranslateExtension on String {
  /// Auto-translate this text based on app language
  /// Returns original text immediately, translates in background
  /// Usage: Obx(() => Text(prayer['content'].autoTranslate(sourceLanguage: 'en')))
  String autoTranslate({String? sourceLanguage}) {
    // Use the sync method which handles cache internally
    return AutoTranslateHelper.getTranslatedTextSync(
      text: this,
      sourceLanguage: sourceLanguage,
    );
  }
  
  /// Auto-translate async (for FutureBuilder)
  Future<String> autoTranslateAsync({String? sourceLanguage}) {
    return AutoTranslateHelper.getTranslatedText(
      text: this,
      sourceLanguage: sourceLanguage,
    );
  }
}

