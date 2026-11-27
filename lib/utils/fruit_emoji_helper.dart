import 'package:flutter/material.dart';
import 'package:fruitsofspirit/config/image_config.dart';
import 'package:fruitsofspirit/widgets/cached_image.dart';
import 'sticker_emoji_helper.dart';
import 'dart:io';

/// Fruit Emoji Helper
/// Standardized utility to detect and render fruit emojis across the app
class FruitEmojiHelper {
  /// Detect if text is a fruit name, emoji character, sticker emoji, or emoji code
  static bool isFruit(String text) {
    if (text.isEmpty) return false;
    final trimmed = text.trim();
    final lower = trimmed.toLowerCase();

    // Check if it's a direct URL to an emoji
    if (lower.startsWith('http') || lower.contains('.png') || lower.contains('.jpg') || lower.contains('/emojis/')) return true;
    
    // Check if it's an emoji code (e.g., :emoji_212: or :sticker_123:)
    if (lower.startsWith(':emoji_') && lower.endsWith(':')) return true;
    if (lower.startsWith(':sticker_') && lower.endsWith(':')) return true;

    // Check fruit names
    final fruitNames = ['love', 'joy', 'peace', 'patience', 'kindness', 'goodness', 
                       'faithfulness', 'gentleness', 'meekness', 'self-control', 'self control', 'discipline',
                       'patience_orange', 'joy_pineapple', 'peace_watermelon', 'kindness_orange', 'goodness_mango',
                       'faithfulness_cherry', 'gentleness_grapes', 'self_control_apple'];
    if (fruitNames.contains(lower)) return true;
    
    // Check emoji characters
    final emojiChars = ['😊', '☮️', '⏳', '🤗', '✨', '🙏', '🕊️', '🎯', '❤️', '⭐', '👏'];
    if (emojiChars.contains(trimmed)) return true;
    
    return false;
  }

  /// Get image URL for a fruit name, emoji character, or emoji code
  static String? getFruitImageUrl(String text, {double? size, int variant = 1, String? userEmail}) {
    if (text.isEmpty) return null;
    final trimmed = text.trim();
    final lower = trimmed.toLowerCase();
    
    print('🔍 getFruitImageUrl called with: "$text"');
    
    // If it's already a full URL, return it directly
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      print('✅ Input is already a full URL, returning directly: $trimmed');
      return trimmed;
    }

    // Handle emoji codes (e.g., :emoji_212:)
    if (lower.startsWith(':emoji_') && lower.endsWith(':')) {
      final idStr = lower.replaceAll(':emoji_', '').replaceAll(':', '');
      final id = int.tryParse(idStr);
      if (id != null) {
        // Return emoji API URL with ID - use working domain format
        final url = 'http://admin.fosmessenger.com/api/get-emoji-image.php?emoji_id=$id&variant=$variant&user_email=${userEmail ?? ''}';
        print('✅ Using emoji code URL: $url');
        return url;
      }
    }

    // Try to extract fruit name from code (e.g., kindness_01 -> kindness)
    final extractedFruit = extractFruitName(text);
    print('📝 Extracted fruit: $extractedFruit');
    
    if (extractedFruit != null) {
      // Try by extracted fruit name first
      String? url = ImageConfig.getFruitReactionImageUrlByName(extractedFruit, size: size, variant: variant, userEmail: userEmail);
      print('🌐 URL by extracted name: $url');
      if (url != null) return url;
      
      // Fallback to legacy fruit images
      url = ImageConfig.getFruitImageUrl(extractedFruit);
      print('🌐 Legacy URL: $url');
      if (url != null) return url;
    }
    
    // Try by name directly
    String? url = ImageConfig.getFruitReactionImageUrlByName(lower, size: size, variant: variant, userEmail: userEmail);
    print('🌐 URL by direct name: $url');
    if (url != null) return url;
    
    // Try by emoji character
    url = ImageConfig.getFruitReactionImageUrl(trimmed, size: size, variant: variant, userEmail: userEmail);
    print('🌐 URL by emoji character: $url');
    if (url != null) return url;
    
    print('❌ No URL found for: "$text"');
    return null;
  }

  /// Extract fruit name from code (e.g., kindness_01 -> kindness, Kindness Peach 3 -> kindness)
  static String? extractFruitName(String text) {
    if (text.isEmpty) return null;
    final lower = text.toLowerCase();
    
    final fruitNames = ['love', 'joy', 'peace', 'patience', 'kindness', 'goodness', 
                       'faithfulness', 'gentleness', 'meekness', 'self-control', 'self control', 'discipline'];
    
    // Check for exact match first
    if (fruitNames.contains(lower)) return lower;
    
    // Check if text contains any fruit name (for codes like kindness_01 or names like Kindness Peach 3)
    for (final fruit in fruitNames) {
      if (lower.contains(fruit)) return fruit;
    }
    
    // Handle self-control variations
    if (lower.contains('selfcontrol') || lower.contains('self_control') || lower.contains('discipline')) {
      return 'self-control';
    }
    
    return null;
  }

  /// Check if text is an actual emoji character
  static bool _isEmojiCharacter(String text) {
    if (text.isEmpty) return false;
    
    // Check for common emoji characters from the emojiChars list
    final emojiChars = ['😊', '☮️', '⏳', '🤗', '✨', '🙏', '🕊️', '🎯', '❤️', '⭐', '👏'];
    if (emojiChars.contains(text)) return true;
    
    // Check if it's a single character that's likely an emoji
    if (text.length == 1) {
      final codeUnit = text.codeUnitAt(0);
      // Emoji ranges
      return (codeUnit >= 0x1F300 && codeUnit <= 0x1F9FF) ||
             (codeUnit >= 0x2600 && codeUnit <= 0x26FF) ||
             (codeUnit >= 0x2700 && codeUnit <= 0x27BF) ||
             (codeUnit >= 0x1F600 && codeUnit <= 0x1F64F) ||
             (codeUnit >= 0x1F680 && codeUnit <= 0x1F6FF);
    }
    
    return false;
  }

  /// Build a fruit emoji widget with enhanced fallback handling
  static Widget buildFruitWidget(String text, {double size = 24, String? userEmail}) {
    // Check if it's a sticker emoji first
    if (StickerEmojiHelper.isStickerEmoji(text)) {
      return StickerEmojiHelper.buildStickerWidget(text, size: size);
    }

    // Check if it's an actual emoji character (Unicode emoji)
    final emojiRegex = RegExp(
      r'[\u{1F300}-\u{1F9FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]|[\u{1F600}-\u{1F64F}]|[\u{1F680}-\u{1F6FF}]|[\u{2764}\u{FE0F}]|[\u{2728}]|[\u{2B50}]',
      unicode: true,
    );
    
    // If it's a short Unicode emoji or emoji character, show it directly
    if (text.length <= 3 && (emojiRegex.hasMatch(text) || _isEmojiCharacter(text))) {
      return Text(
        text,
        style: TextStyle(fontSize: size * 0.8),
      );
    }
    
    final url = getFruitImageUrl(text, size: size, userEmail: userEmail);
    
    if (url != null) {
      return CachedImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorWidget: _buildFallbackEmojiWidget(text, size),
      );
    }
    
    // If it's a character but no URL, just show character
    return Text(
      text,
      style: TextStyle(fontSize: size * 0.8),
    );
  }

  /// Process text to replace fruit names with emojis and sticker codes with stickers
  static Widget buildCommentText(BuildContext context, String text, {TextStyle? style, String? userEmail}) {
    if (text.isEmpty) return const SizedBox.shrink();

    // First, check if the text contains sticker codes and handle them
    if (StickerEmojiHelper.isStickerEmoji(text)) {
      // If the entire text is a sticker code or image URL, just show the sticker/image
      return StickerEmojiHelper.buildStickerWidget(text, size: (style?.fontSize ?? 14) * 2);
    }

    // Handle emoji codes (e.g., :emoji_212:) in mixed content
    if (text.contains(':emoji_')) {
      final List<InlineSpan> spans = [];
      int lastMatchEnd = 0;

      // Match emoji codes :emoji_123:
      final emojiCodePattern = RegExp(r':emoji_\d+:');

      for (final match in emojiCodePattern.allMatches(text)) {
        // Add text before the match
        if (match.start > lastMatchEnd) {
          spans.add(TextSpan(
            text: text.substring(lastMatchEnd, match.start),
            style: style,
          ));
        }

        final emojiCode = match.group(0)!;
        final url = getFruitImageUrl(emojiCode, userEmail: userEmail);

        if (url != null) {
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.0),
                child: CachedImage(
                  imageUrl: url,
                  width: (style?.fontSize ?? 14) * 2,
                  height: (style?.fontSize ?? 14) * 2,
                  fit: BoxFit.contain,
                  errorWidget: _buildFallbackEmojiWidget(emojiCode, (style?.fontSize ?? 14) * 2),
                ),
              ),
            ),
          );
        } else {
          spans.add(TextSpan(text: emojiCode, style: style));
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

      if (spans.length > 1 || (spans.length == 1 && spans.first is WidgetSpan)) {
        return RichText(text: TextSpan(children: spans));
      }
    }

    // For mixed content (text + stickers), use the sticker parser
    if (text.contains(':sticker_')) {
      final stickerSpans = StickerEmojiHelper.parseTextWithStickers(text, emojiSize: (style?.fontSize ?? 14) * 1.5);
      
      // If stickers were found, create RichText with the parsed spans
      if (stickerSpans.length > 1 || (stickerSpans.length == 1 && stickerSpans.first is! TextSpan)) {
        // Apply the text style to any text spans
        final styledSpans = stickerSpans.map((span) {
          if (span is TextSpan && span.style == null) {
            return TextSpan(text: span.text, style: style);
          }
          return span;
        }).toList();
        
        return RichText(text: TextSpan(children: styledSpans));
      }
    }

    // Handle image URLs in mixed content
    print('🔍 buildCommentText received: "$text"');
    // Enhanced detection for image URLs
    if (text.contains('http') && (text.contains('.png') || text.contains('.jpg') || text.contains('.jpeg') || text.contains('uploads/emojis'))) {
      final List<InlineSpan> spans = [];
      int lastMatchEnd = 0;

      // Match HTTP URLs ending with image extensions
      // Non-greedy match stops at first .png/.jpg/.jpeg (handles emoji names with %20 spaces)
      final urlPattern = RegExp(r'https?://.*?\.(?:png|jpg|jpeg)', caseSensitive: false);
      print('🔍 Looking for URLs in text: "$text"');

      for (final match in urlPattern.allMatches(text)) {
        // Add text before the match
        if (match.start > lastMatchEnd) {
          spans.add(TextSpan(
            text: text.substring(lastMatchEnd, match.start),
            style: style,
          ));
        }

        final cleanUrl = match.group(0)!;

        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: CachedImage(
                imageUrl: cleanUrl,
                width: (style?.fontSize ?? 14) * 2,
                height: (style?.fontSize ?? 14) * 2,
                fit: BoxFit.contain,
                errorWidget: const Icon(Icons.broken_image, size: 24, color: Colors.grey),
              ),
            ),
          ),
        );

        lastMatchEnd = match.end;
      }

      // Add remaining text (convert ||, %20, %7C to space for display)
      if (lastMatchEnd < text.length) {
        final remainingText = text.substring(lastMatchEnd);
        // Clean up URL encoding and delimiters
        final decodedText = remainingText
            .replaceAll('||', ' ')
            .replaceAll('%20', ' ')
            .replaceAll('%7C', ' ')
            .replaceAll('|', ' ')
            .trim();
        print('📝 Remaining text after URL: "$decodedText"');
        if (decodedText.isNotEmpty) {
          spans.add(TextSpan(
            text: decodedText,
            style: style,
          ));
        }
      }

      if (spans.length > 1 || (spans.length == 1 && spans.first is WidgetSpan)) {
        return RichText(text: TextSpan(children: spans));
      }
    }

    // Handle URLs with appended text (legacy support for bad data)
    // This catches cases where URLs have text appended without proper delimiters
    if (text.contains('uploads/emojis/') && (text.contains('.png') || text.contains('.jpg'))) {
      final List<InlineSpan> spans = [];
      int lastMatchEnd = 0;

      // Match emoji URLs that might have garbage appended
      // Non-greedy match stops at first .png/.jpg/.jpeg (handles emoji names with %20 spaces)
      final urlPattern = RegExp(r'uploads/emojis/.*?\.(?:png|jpg|jpeg)', caseSensitive: false);

      for (final match in urlPattern.allMatches(text)) {
        // Add text before the match
        if (match.start > lastMatchEnd) {
          spans.add(TextSpan(
            text: text.substring(lastMatchEnd, match.start),
            style: style,
          ));
        }

        final urlPath = match.group(0)!;
        // Construct full URL for emojis (no /api/ prefix)
        final cleanUrl = 'http://admin.fosmessenger.com/' + urlPath;
        print('🖼️ Found emoji path in comment: "$urlPath"');
        print('🧹 Full URL: "$cleanUrl"');
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: CachedImage(
                imageUrl: cleanUrl,
                width: (style?.fontSize ?? 14) * 2,
                height: (style?.fontSize ?? 14) * 2,
                fit: BoxFit.contain,
                errorWidget: _buildFallbackEmojiWidget(urlPath, (style?.fontSize ?? 14) * 2),
              ),
            ),
          ),
        );

        lastMatchEnd = match.end;
      }

      // Add remaining text
      if (lastMatchEnd < text.length) {
        final remainingText = text.substring(lastMatchEnd);
        // Clean up URL encoding and delimiters
        final decodedText = remainingText.replaceAll('||', ' ').replaceAll('%20', ' ').replaceAll('%7C', ' ').trim();
        print('📝 Remaining text after emoji path: "$decodedText"');
        if (decodedText.isNotEmpty) {
          spans.add(TextSpan(
            text: decodedText,
            style: style,
          ));
        }
      }

      if (spans.length > 1 || (spans.length == 1 && spans.first is WidgetSpan)) {
        print('🎨 Rendering RichText with ${spans.length} spans');
        return RichText(text: TextSpan(children: spans));
      }
    }

    // If no stickers, process fruit names and regular emojis as before
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
      final url = getFruitImageUrl(cleanWord, userEmail: userEmail);

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
                errorWidget: _buildFallbackEmojiWidget(matchedText, (style?.fontSize ?? 14) * 1.4),
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

  /// Build fallback emoji widget when image loading fails
  static Widget _buildFallbackEmojiWidget(String text, double size) {
    // Try to extract fruit name for fallback
    final fruitName = extractFruitName(text);
    if (fruitName != null) {
      // Map to simple emoji characters as fallback
      final fallbackMap = {
        'love': '❤️',
        'joy': '😊',
        'peace': '☮️',
        'patience': '⏳',
        'kindness': '🤗',
        'goodness': '✨',
        'faithfulness': '🙏',
        'gentleness': '🕊️',
        'meekness': '🕊️',
        'self-control': '🎯',
      };
      
      final fallbackEmoji = fallbackMap[fruitName];
      if (fallbackEmoji != null) {
        return Text(
          fallbackEmoji,
          style: TextStyle(fontSize: size * 0.8),
        );
      }
    }
    
    // Final fallback - show text or generic icon
    if (text.length <= 10) {
      return Text(
        text,
        style: TextStyle(fontSize: size * 0.6, color: Colors.grey),
      );
    }
    
    return Icon(
      Icons.sentiment_satisfied,
      size: size,
      color: Colors.grey,
    );
  }
}
