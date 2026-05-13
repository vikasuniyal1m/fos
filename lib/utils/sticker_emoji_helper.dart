import 'package:flutter/material.dart';
import 'dart:io';
import '../services/sticker_service.dart';

/// Sticker Emoji Helper
/// Helps display stickers as emojis in chat and other places
class StickerEmojiHelper {
  /// Check if text is a sticker emoji code or image URL
  static bool isStickerEmoji(String text) {
    return (text.startsWith(':sticker_') && text.endsWith(':')) ||
           (text.startsWith('http') && (text.contains('.png') || text.contains('.jpg') || text.contains('.jpeg')));
  }

  /// Extract sticker ID from emoji code
  static int? extractStickerId(String emojiCode) {
    final match = RegExp(r':sticker_(\d+):').firstMatch(emojiCode);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }
    return null;
  }

  /// Build widget for sticker emoji
  static Widget buildStickerWidget(String emojiCode, {double size = 40}) {
    // If it's an image URL, display it directly
    if (emojiCode.startsWith('http') && (emojiCode.contains('.png') || emojiCode.contains('.jpg') || emojiCode.contains('.jpeg'))) {
      return _buildNetworkImage(emojiCode, size);
    }

    final stickerId = extractStickerId(emojiCode);
    if (stickerId == null) {
      return Text(emojiCode, style: TextStyle(fontSize: size));
    }

    return FutureBuilder<List<Sticker>>(
      future: StickerService.getAllStickers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            width: size,
            height: size,
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildPlaceholder(size, text: 'Loading...');
        }

        final sticker = snapshot.data!.firstWhere(
          (s) => s.id == stickerId,
          orElse: () => Sticker(
            id: stickerId,
            name: 'Unknown',
            imageUrl: '',
            emojiCode: emojiCode,
            displayOrder: 0,
          ),
        );

        // If sticker has no image URL, show placeholder
        if (sticker.imageUrl.isEmpty && (sticker.localPath == null || sticker.localPath!.isEmpty)) {
          return _buildPlaceholder(size, text: 'Sticker $stickerId');
        }

        if (sticker.localPath != null && sticker.localPath!.isNotEmpty) {
          return Image.file(
            File(sticker.localPath!),
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              print('❌ Error loading local sticker ${sticker.id}: $error');
              // Try network as fallback
              if (sticker.imageUrl.isNotEmpty) {
                return _buildNetworkImage(sticker.imageUrl, size);
              }
              return _buildPlaceholder(size, text: 'Error');
            },
          );
        }

        // Fallback to network image
        if (sticker.imageUrl.isNotEmpty) {
          return _buildNetworkImage(sticker.imageUrl, size);
        }

        return _buildPlaceholder(size, text: 'No image');
      },
    );
  }

  static Widget _buildNetworkImage(String url, double size) {
    return Image.network(
      url,
      width: size,
      height: size,
      fit: BoxFit.contain,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return SizedBox(
          width: size,
          height: size,
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        print('❌ Error loading network image: $error');
        return _buildPlaceholder(size, text: 'Error');
      },
    );
  }

  static Widget _buildPlaceholder(double size, {String? text}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(size / 8),
      ),
      child: text != null
          ? Center(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: size / 8,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            )
          : Icon(
              Icons.image,
              size: size / 2,
              color: Colors.grey[400],
            ),
    );
  }

  /// Build sticker picker grid
  static Widget buildStickerPicker({
    required Function(Sticker) onStickerSelected,
    double stickerSize = 60,
    int crossAxisCount = 4,
  }) {
    return FutureBuilder<List<Sticker>>(
      future: StickerService.getAllStickers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState();
        }

        final stickers = snapshot.data!;

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: stickers.length,
          itemBuilder: (context, index) {
            final sticker = stickers[index];
            return _buildStickerItem(
              sticker: sticker,
              size: stickerSize,
              onTap: () => onStickerSelected(sticker),
            );
          },
        );
      },
    );
  }

  static Widget _buildStickerItem({
    required Sticker sticker,
    required double size,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        padding: const EdgeInsets.all(8),
        child: sticker.localPath != null && sticker.localPath!.isNotEmpty
            ? Image.file(
                File(sticker.localPath!),
                width: size,
                height: size,
                fit: BoxFit.contain,
              )
            : Image.network(
                sticker.imageUrl,
                width: size,
                height: size,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
              ),
      ),
    );
  }

  static Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sentiment_dissatisfied, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No stickers downloaded',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Purchase stickers from our store!',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  /// Parse text and build rich text with stickers
  static List<InlineSpan> parseTextWithStickers(String text, {double emojiSize = 20}) {
    final spans = <InlineSpan>[];
    final regex = RegExp(r':sticker_\d+:');
    
    var lastIndex = 0;
    for (final match in regex.allMatches(text)) {
      // Add text before sticker
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
        ));
      }
      
      // Add sticker as widget span
      final emojiCode = match.group(0)!;
      spans.add(WidgetSpan(
        child: StickerEmojiHelper.buildStickerWidget(emojiCode, size: emojiSize),
        alignment: PlaceholderAlignment.middle,
      ));
      
      lastIndex = match.end;
    }
    
    // Add remaining text
    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex)));
    }
    
    return spans;
  }
}
