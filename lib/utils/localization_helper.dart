import 'package:flutter/material.dart';
// Import only Get class from GetX to avoid extension conflict
import 'package:get/get.dart' show Get, GetNavigation;
// Import easy_localization - its extension will be used
import 'package:easy_localization/easy_localization.dart';

/// Localization Helper
/// Provides easy access to translated strings
class LocalizationHelper {
  /// Get translated string
  /// Uses easy_localization's tr extension (not GetX's)
  /// Note: Both packages provide a 'tr' extension, but easy_localization's
  /// is preferred when imported last. If conflict persists, use explicit extension.
  static String tr(String key, {Map<String, String>? args}) {
    // Use extension method - Dart will prefer easy_localization's extension
    // when both are available, especially when imported last
    if (args != null) {
      // Explicitly qualify to avoid ambiguity
      return (key as String).tr(namedArgs: args);
    }
    return (key as String).tr();
  }

  /// Get current locale
  static Locale getCurrentLocale() {
    // Use GetX context or a global navigator key
    try {
      final context = Get.context;
      if (context != null) {
        return EasyLocalization.of(context)?.locale ?? const Locale('en');
      }
    } catch (e) {
      // Fallback if context is not available
    }
    return const Locale('en');
  }

  /// Change language
  static Future<void> changeLanguage(String languageCode) async {
    try {
      final context = Get.context;
      if (context != null) {
        await EasyLocalization.of(context)!.setLocale(Locale(languageCode));
      }
    } catch (e) {
      // Fallback if context is not available
    }
  }

  /// Get available locales
  static List<Locale> getAvailableLocales() {
    return [const Locale('en'), const Locale('es')];
  }
}

