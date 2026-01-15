import 'package:flutter/material.dart';
import 'package:fruitsofspirit/services/translate_service.dart';
import 'package:fruitsofspirit/utils/localization_helper.dart';

/// Auto Translate Widget
/// Automatically translates content based on app's current locale
/// Only translates if content language differs from app language
class AutoTranslateWidget extends StatefulWidget {
  final String text;
  final String? sourceLanguage; // Content's original language (from database)
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  const AutoTranslateWidget({
    Key? key,
    required this.text,
    this.sourceLanguage,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
  }) : super(key: key);

  @override
  State<AutoTranslateWidget> createState() => _AutoTranslateWidgetState();
}

class _AutoTranslateWidgetState extends State<AutoTranslateWidget> {
  String? _translatedText;
  bool _isTranslating = false;
  bool _shouldTranslate = false;
  String? _currentAppLanguage;

  @override
  void initState() {
    super.initState();
    _checkIfTranslationNeeded();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check if locale changed
    final currentLocale = LocalizationHelper.getCurrentLocale();
    if (_currentAppLanguage != currentLocale.languageCode) {
      _currentAppLanguage = currentLocale.languageCode;
      _checkIfTranslationNeeded();
    }
  }

  void _checkIfTranslationNeeded() {
    if (widget.text.isEmpty) {
      setState(() {
        _shouldTranslate = false;
      });
      return;
    }

    final appLocale = LocalizationHelper.getCurrentLocale();
    final appLanguage = appLocale.languageCode;
    _currentAppLanguage = appLanguage;

    // Get content language (from database or auto-detect)
    final contentLanguage = widget.sourceLanguage ?? 'en'; // Default to English

    // Only translate if content language is different from app language
    if (contentLanguage != appLanguage && appLanguage != 'en') {
      // Translate to app language
      _shouldTranslate = true;
      _translateContent(appLanguage, contentLanguage);
    } else {
      setState(() {
        _shouldTranslate = false;
        _translatedText = null;
      });
    }
  }

  Future<void> _translateContent(String targetLanguage, String sourceLanguage) async {
    if (widget.text.isEmpty) return;

    setState(() {
      _isTranslating = true;
    });

    try {
      final result = await TranslateService.translate(
        text: widget.text,
        targetLanguage: targetLanguage,
        sourceLanguage: sourceLanguage,
      );

      if (mounted) {
        setState(() {
          _translatedText = result['translated_text'] as String?;
          _isTranslating = false;
        });
      }
    } catch (e) {
      // If translation fails, show original text
      if (mounted) {
        setState(() {
          _isTranslating = false;
          _translatedText = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldTranslate) {
      // Show original text
      return Text(
        widget.text,
        style: widget.style,
        maxLines: widget.maxLines,
        overflow: widget.overflow,
        textAlign: widget.textAlign,
      );
    }

    if (_isTranslating) {
      // Show loading indicator or original text while translating
      return Text(
        widget.text,
        style: widget.style?.copyWith(
          color: widget.style?.color?.withOpacity(0.6),
        ),
        maxLines: widget.maxLines,
        overflow: widget.overflow,
        textAlign: widget.textAlign,
      );
    }

    // Show translated text if available, otherwise show original
    return Text(
      _translatedText ?? widget.text,
      style: widget.style,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
      textAlign: widget.textAlign,
    );
  }
}

