import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:fruitsofspirit/services/translate_service.dart';
import 'package:fruitsofspirit/utils/app_theme.dart';
import 'package:fruitsofspirit/utils/localization_helper.dart';

/// Instagram-style "See translation" widget.
/// Shows original text; user taps "See translation" to load translation into app language.
/// Target language is always app locale (user's chosen language), not hardcoded English.
class SeeTranslationWidget extends StatefulWidget {
  final String text;
  final String? sourceLanguage;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  const SeeTranslationWidget({
    super.key,
    required this.text,
    this.sourceLanguage,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  @override
  State<SeeTranslationWidget> createState() => _SeeTranslationWidgetState();
}

class _SeeTranslationWidgetState extends State<SeeTranslationWidget> {
  String? _translatedText;
  bool _isLoading = false;
  bool _showTranslated = false;
  String? _error;

  String get _appLanguage =>
      LocalizationHelper.getCurrentLocale().languageCode;

  bool get _shouldOfferTranslation {
    if (widget.text.trim().isEmpty) return false;
    // Always show "See translation" when there is content, so user can tap anytime
    return true;
  }

  Future<void> _loadTranslation() async {
    if (widget.text.trim().isEmpty) return;

    final target = _appLanguage;
    final source = widget.sourceLanguage;

    final cached = TranslateService.getCachedTranslation(
      text: widget.text,
      targetLanguage: target,
      sourceLanguage: source,
    );
    if (cached != null) {
      if (mounted) {
        setState(() {
          _translatedText = cached;
          _showTranslated = true;
          _error = null;
        });
      }
      return;
    }

    if (mounted) setState(() { _isLoading = true; _error = null; });

    try {
      final result = await TranslateService.translate(
        text: widget.text,
        targetLanguage: target,
        sourceLanguage: source,
      );
      final translated = result['translated_text'] as String?;
      if (mounted) {
        setState(() {
          _translatedText = translated;
          _showTranslated = true;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'translation_unavailable'.tr();
        });
      }
    }
  }

  void _showOriginal() {
    setState(() { _showTranslated = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.text.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final content = _showTranslated && _translatedText != null && _translatedText!.isNotEmpty
        ? _translatedText!
        : widget.text;

    return LayoutBuilder(
      builder: (context, constraints) {
        final hasBoundedHeight = constraints.hasBoundedHeight && constraints.maxHeight.isFinite;
        if (hasBoundedHeight && constraints.maxHeight > 0) {
          return SizedBox(
            height: constraints.maxHeight,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: Text(
                      content,
                      style: widget.style,
                      maxLines: widget.maxLines,
                      overflow: widget.overflow ?? TextOverflow.ellipsis,
                      textAlign: widget.textAlign,
                    ),
                  ),
                ),
                if (_shouldOfferTranslation) ...[
                  const SizedBox(height: 12),
                  _buildActionRow(),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _error!,
                    style: (widget.style ?? const TextStyle()).copyWith(
                      color: Colors.red.shade700,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              content,
              style: widget.style,
              maxLines: widget.maxLines,
              overflow: widget.overflow,
              textAlign: widget.textAlign,
            ),
            if (_shouldOfferTranslation) ...[
              const SizedBox(height: 12),
              _buildActionRow(),
            ],
            if (_error != null) ...[
              const SizedBox(height: 4),
              Text(
                _error!,
                style: (widget.style ?? const TextStyle()).copyWith(
                  color: Colors.red.shade700,
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildActionRow() {
    if (_isLoading) {
      return Semantics(
        label: 'translating'.tr(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.iconscolor,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'translating'.tr(),
              style: (widget.style ?? TextStyle(color: Colors.grey[600])).copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (_showTranslated && _translatedText != null) {
      return Semantics(
        button: true,
        label: 'show_original'.tr(),
        child: InkWell(
          onTap: _showOriginal,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              'show_original'.tr(),
              style: (widget.style ?? TextStyle(color: Colors.grey[700])).copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.iconscolor,
              ),
            ),
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      label: 'see_translation'.tr(),
      child: InkWell(
        onTap: _loadTranslation,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(
            'see_translation'.tr(),
            style: (widget.style ?? TextStyle(color: Colors.grey[700])).copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.iconscolor,
            ),
          ),
        ),
      ),
    );
  }
}
