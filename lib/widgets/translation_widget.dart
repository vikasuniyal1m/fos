import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/services/translate_service.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';
import 'package:fruitsofspirit/services/api_service.dart';

/// Translation Widget
/// Provides translation functionality for content
class TranslationWidget extends StatefulWidget {
  final String text;
  final String? sourceLanguage;
  final Function(String translatedText)? onTranslated;
  final Widget child;

  const TranslationWidget({
    Key? key,
    required this.text,
    this.sourceLanguage,
    this.onTranslated,
    required this.child,
  }) : super(key: key);

  @override
  State<TranslationWidget> createState() => _TranslationWidgetState();
}

class _TranslationWidgetState extends State<TranslationWidget> {
  String? _translatedText;
  String? _currentLanguage;
  bool _isTranslating = false;
  bool _showOriginal = true;

  // Supported languages
  final List<Map<String, String>> _languages = [
    {'code': 'en', 'name': 'English'},
    {'code': 'es', 'name': 'Spanish'},
    {'code': 'fr', 'name': 'French'},
    {'code': 'de', 'name': 'German'},
    {'code': 'it', 'name': 'Italian'},
    {'code': 'pt', 'name': 'Portuguese'},
    {'code': 'hi', 'name': 'Hindi'},
    {'code': 'ar', 'name': 'Arabic'},
    {'code': 'zh', 'name': 'Chinese'},
    {'code': 'ja', 'name': 'Japanese'},
  ];

  Future<void> _translate(String targetLanguage) async {
    if (widget.text.isEmpty) return;

    setState(() {
      _isTranslating = true;
    });

    try {
      final result = await TranslateService.translate(
        text: widget.text,
        targetLanguage: targetLanguage,
        sourceLanguage: widget.sourceLanguage,
      );

      setState(() {
        _translatedText = result['translated_text'] as String?;
        _currentLanguage = targetLanguage;
        _showOriginal = false;
        _isTranslating = false;
      });

      if (widget.onTranslated != null && _translatedText != null) {
        widget.onTranslated!(_translatedText!);
      }
    } catch (e) {
      setState(() {
        _isTranslating = false;
      });
      
      Get.snackbar(
        'Translation Error',
        e.toString().replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
    }
  }

  void _showOriginalText() {
    setState(() {
      _showOriginal = true;
      _translatedText = null;
      _currentLanguage = null;
    });
  }

  void _showLanguageSelector() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(ResponsiveHelper.borderRadius(context, mobile: 20)),
        ),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Language',
              style: ResponsiveHelper.textStyle(
                context,
                fontSize: ResponsiveHelper.fontSize(context, mobile: 18),
                fontWeight: FontWeight.bold,
                color: const Color(0xFF8B4513),
              ),
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 16)),
            ListView.builder(
              shrinkWrap: true,
              itemCount: _languages.length,
              itemBuilder: (context, index) {
                final lang = _languages[index];
                return ListTile(
                  leading: Icon(
                    Icons.language,
                    color: const Color(0xFF8B4513),
                  ),
                  title: Text(lang['name']!),
                  onTap: () {
                    Navigator.pop(context);
                    _translate(lang['code']!);
                  },
                );
              },
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 8)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Translation Controls
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_showOriginal)
              TextButton.icon(
                onPressed: _isTranslating ? null : _showLanguageSelector,
                icon: _isTranslating
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: const Color(0xFF8B4513),
                        ),
                      )
                    : Icon(
                        Icons.translate,
                        size: ResponsiveHelper.iconSize(context, mobile: 18),
                        color: const Color(0xFF8B4513),
                      ),
                label: Text(
                  _isTranslating ? 'Translating...' : 'Translate',
                  style: ResponsiveHelper.textStyle(
                    context,
                    fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                    color: const Color(0xFF8B4513),
                  ),
                ),
              )
            else
              Wrap(
                spacing: ResponsiveHelper.spacing(context, 4),
                children: [
                  Chip(
                    label: Text(
                      _languages.firstWhere(
                        (l) => l['code'] == _currentLanguage,
                        orElse: () => {'code': '', 'name': 'Unknown'},
                      )['name']!,
                      style: TextStyle(
                        fontSize: ResponsiveHelper.fontSize(context, mobile: 11),
                        color: Colors.white,
                      ),
                    ),
                    backgroundColor: const Color(0xFF8B4513),
                  ),
                  TextButton.icon(
                    onPressed: _showOriginalText,
                    icon: Icon(
                      Icons.undo,
                      size: ResponsiveHelper.iconSize(context, mobile: 16),
                      color: const Color(0xFF8B4513),
                    ),
                    label: Text(
                      'Original',
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                        color: const Color(0xFF8B4513),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
        SizedBox(height: ResponsiveHelper.spacing(context, 8)),
        // Content
        Flexible(
          child: _showOriginal
              ? widget.child
              : _translatedText != null
                  ? Builder(
                      builder: (context) {
                        // Try to extract style from child if it's a Text widget
                        TextStyle? textStyle;
                        if (widget.child is Text) {
                          textStyle = (widget.child as Text).style;
                        }
                        
                        return Text(
                          _translatedText!,
                          style: textStyle ?? ResponsiveHelper.textStyle(
                            context,
                            fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                            color: Colors.black87,
                          ),
                        );
                      },
                    )
                  : widget.child,
        ),
      ],
    );
  }
}

/// Translation Button for AppBar
class TranslationButton extends StatelessWidget {
  final String text;
  final String? sourceLanguage;
  final Function(String translatedText)? onTranslated;

  const TranslationButton({
    Key? key,
    required this.text,
    this.sourceLanguage,
    this.onTranslated,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.translate,
        color: const Color(0xFF8B4513),
        size: ResponsiveHelper.iconSize(context, mobile: 24),
      ),
      onSelected: (languageCode) async {
        if (text.isEmpty) return;

        try {
          final result = await TranslateService.translate(
            text: text,
            targetLanguage: languageCode,
            sourceLanguage: sourceLanguage,
          );

          if (onTranslated != null) {
            onTranslated!(result['translated_text'] as String);
          } else {
            Get.snackbar(
              'Translated',
              'Content translated to ${_getLanguageName(languageCode)}',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: Colors.green.withOpacity(0.8),
              colorText: Colors.white,
            );
          }
        } catch (e) {
          Get.snackbar(
            'Translation Error',
            e.toString().replaceAll('Exception: ', ''),
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red.withOpacity(0.8),
            colorText: Colors.white,
          );
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'es', child: Text('Spanish')),
        const PopupMenuItem(value: 'fr', child: Text('French')),
        const PopupMenuItem(value: 'de', child: Text('German')),
        const PopupMenuItem(value: 'it', child: Text('Italian')),
        const PopupMenuItem(value: 'pt', child: Text('Portuguese')),
        const PopupMenuItem(value: 'hi', child: Text('Hindi')),
        const PopupMenuItem(value: 'ar', child: Text('Arabic')),
        const PopupMenuItem(value: 'zh', child: Text('Chinese')),
        const PopupMenuItem(value: 'ja', child: Text('Japanese')),
        const PopupMenuItem(value: 'en', child: Text('English (Original)')),
      ],
    );
  }

  String _getLanguageName(String code) {
    final languages = {
      'en': 'English',
      'es': 'Spanish',
      'fr': 'French',
      'de': 'German',
      'it': 'Italian',
      'pt': 'Portuguese',
      'hi': 'Hindi',
      'ar': 'Arabic',
      'zh': 'Chinese',
      'ja': 'Japanese',
    };
    return languages[code] ?? code;
  }
}

