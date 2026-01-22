import 'package:flutter/material.dart';
import 'package:fruitsofspirit/config/image_config.dart';
import 'package:fruitsofspirit/widgets/cached_image.dart';

/// Fruit Emoji Helper
/// Standardized utility to detect and render fruit emojis across the app
class FruitEmojiHelper {
  /// Detect if text is a fruit name or emoji character
  static bool isFruit(String text) {
    if (text.isEmpty) return false;
    final trimmed = text.trim().toLowerCase();
    
    // Check fruit names
    final fruitNames = ['love', 'joy', 'peace', 'patience', 'kindness', 'goodness', 
                       'faithfulness', 'gentleness', 'meekness', 'self-control', 'self control', 'discipline'];
    if (fruitNames.contains(trimmed)) return true;
    
    // Check emoji characters
    final emojiChars = ['😊', '☮️', '⏳', '🤗', '✨', '🙏', '🕊️', '🎯', '❤️', '⭐', '👏'];
    if (emojiChars.contains(trimmed)) return true;
    
    return false;
  }

  /// Get image URL for a fruit name or emoji character
  static String? getFruitImageUrl(String text, {double? size, int variant = 1}) {
    if (text.isEmpty) return null;
    final trimmed = text.trim();
    final lower = trimmed.toLowerCase();
    
    // Try by name first
    String? url = ImageConfig.getFruitReactionImageUrlByName(lower, size: size, variant: variant);
    if (url != null) return url;
    
    // Try by emoji character
    url = ImageConfig.getFruitReactionImageUrl(trimmed, size: size, variant: variant);
    if (url != null) return url;
    
    // Fallback to legacy fruit images if name matches
    final fruitNames = ['love', 'joy', 'peace', 'patience', 'kindness', 'goodness', 
                       'faithfulness', 'gentleness', 'meekness', 'self-control', 'self control', 'discipline'];
    if (fruitNames.contains(lower)) {
      return ImageConfig.getFruitImageUrl(lower);
    }
    
    return null;
  }

  /// Build a fruit emoji widget
  static Widget buildFruitWidget(String text, {double size = 24}) {
    final url = getFruitImageUrl(text, size: size);
    
    if (url != null) {
      return CachedImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorWidget: _buildPlaceholder(size),
      );
    }
    
    // If it's a character but no URL, just show the character
    return Text(
      text,
      style: TextStyle(fontSize: size * 0.8),
    );
  }

  /// Process text to replace fruit names with emojis
  static Widget buildCommentText(BuildContext context, String text, {TextStyle? style}) {
    if (text.isEmpty) return const SizedBox.shrink();

    final fruitNames = ['love', 'joy', 'peace', 'patience', 'kindness', 'goodness', 
                       'faithfulness', 'gentleness', 'meekness', 'self-control', 'self control', 'discipline'];
    
    final emojiChars = ['😊', '☮️', '⏳', '🤗', '✨', '🙏', '🕊️', '🎯', '❤️', '⭐', '👏'];
    
    // Sort fruit names by length descending to match longer phrases first
    final sortedFruitNames = List<String>.from(fruitNames)..sort((a, b) => b.length.compareTo(a.length));
    
    // Create patterns
    final namePattern = sortedFruitNames.map((name) => RegExp.escape(name)).join('|');
    final emojiPattern = emojiChars.map((e) => RegExp.escape(e)).join('|');
    
    // Match fruit names with word boundaries OR emoji characters anywhere
    final regex = RegExp('\\b($namePattern)\\b|($emojiPattern)', caseSensitive: false);

    final List<InlineSpan> spans = [];
    int lastMatchEnd = 0;

    for (final match in regex.allMatches(text)) {
      // Add text before the match
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: text.substring(lastMatchEnd, match.start),
          style: style,
        ));
      }

      final matchedText = match.group(0)!;
      final cleanWord = matchedText.toLowerCase();
      final url = getFruitImageUrl(cleanWord);

      if (url != null) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: CachedImage(
                imageUrl: url,
                width: (style?.fontSize ?? 14) * 1.4,
                height: (style?.fontSize ?? 14) * 1.4,
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
      } else {
        spans.add(TextSpan(text: matchedText, style: style));
      }

      lastMatchEnd = match.end;
    }

    // Add remaining text
    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastMatchEnd),
        style: style,
      ));
    }

    if (spans.isEmpty) {
      return Text(text, style: style);
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }

  static Widget _buildPlaceholder(double size) {
    return Icon(
      Icons.sentiment_satisfied,
      size: size,
      color: const Color(0xFFC79211),
    );
  }
}
