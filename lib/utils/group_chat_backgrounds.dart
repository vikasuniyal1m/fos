import 'package:flutter/material.dart';
import 'package:fruitsofspirit/utils/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Per-group chat wallpaper options (stored locally per user).
class GroupChatBackgrounds {
  GroupChatBackgrounds._();

  static const String defaultId = 'classic';

  static const List<GroupChatBackgroundOption> options = [
    GroupChatBackgroundOption(
      id: 'classic',
      label: 'Default',
      colors: [AppTheme.themeColor, AppTheme.themeColor],
      pattern: BackgroundPattern.none,
    ),
    GroupChatBackgroundOption(
      id: 'warm_glow',
      label: 'Warm Glow',
      colors: [Color(0xFFFFE0B2), Color(0xFFFFCC80)],
      pattern: BackgroundPattern.none,
    ),
    GroupChatBackgroundOption(
      id: 'soft_sky',
      label: 'Soft Sky',
      colors: [Color(0xFFB3E5FC), Color(0xFF81D4FA)],
      pattern: BackgroundPattern.none,
    ),
    GroupChatBackgroundOption(
      id: 'peace_mint',
      label: 'Peace Mint',
      colors: [Color(0xFFC8E6C9), Color(0xFFA5D6A7)],
      pattern: BackgroundPattern.none,
    ),
    GroupChatBackgroundOption(
      id: 'sunset',
      label: 'Sunset Peach',
      colors: [Color(0xFFFFCCBC), Color(0xFFFFAB91)],
      pattern: BackgroundPattern.none,
    ),
    GroupChatBackgroundOption(
      id: 'lavender',
      label: 'Lavender',
      colors: [Color(0xFFE1BEE7), Color(0xFFCE93D8)],
      pattern: BackgroundPattern.none,
    ),
    GroupChatBackgroundOption(
      id: 'sandy',
      label: 'Sandy Beige',
      colors: [Color(0xFFD7CCC8), Color(0xFFBCAAA4)],
      pattern: BackgroundPattern.none,
    ),
    GroupChatBackgroundOption(
      id: 'dots',
      label: 'Soft Dots',
      colors: [Color(0xFFFFF9C4), Color(0xFFFFF59D)],
      pattern: BackgroundPattern.dots,
    ),
    GroupChatBackgroundOption(
      id: 'waves',
      label: 'Gentle Waves',
      colors: [Color(0xFF90CAF9), Color(0xFF64B5F6)],
      pattern: BackgroundPattern.waves,
    ),
  ];

  static GroupChatBackgroundOption optionFor(String? id) {
    if (id == null || id.isEmpty) return options.first;
    return options.firstWhere(
      (o) => o.id == id,
      orElse: () => options.first,
    );
  }

  static String _prefsKey(int groupId) => 'group_chat_bg_$groupId';

  static Future<String> loadForGroup(int groupId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefsKey(groupId)) ?? defaultId;
  }

  static Future<void> saveForGroup(int groupId, String optionId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey(groupId), optionId);
  }

  static Widget buildBackground({
    required String optionId,
    required Widget child,
  }) {
    final option = optionFor(optionId);
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: option.colors,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (option.pattern != BackgroundPattern.none)
              CustomPaint(painter: _ChatPatternPainter(option.pattern)),
            child,
          ],
        ),
      ),
    );
  }
}

enum BackgroundPattern { none, dots, waves }

class GroupChatBackgroundOption {
  final String id;
  final String label;
  final List<Color> colors;
  final BackgroundPattern pattern;

  const GroupChatBackgroundOption({
    required this.id,
    required this.label,
    required this.colors,
    required this.pattern,
  });
}

class _ChatPatternPainter extends CustomPainter {
  _ChatPatternPainter(this.pattern);

  final BackgroundPattern pattern;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.iconscolor.withOpacity(0.06)
      ..style = PaintingStyle.fill;

    if (pattern == BackgroundPattern.dots) {
      const spacing = 28.0;
      const radius = 2.2;
      for (var y = spacing / 2; y < size.height; y += spacing) {
        for (var x = spacing / 2; x < size.width; x += spacing) {
          canvas.drawCircle(Offset(x, y), radius, paint);
        }
      }
      return;
    }

    if (pattern == BackgroundPattern.waves) {
      final wavePaint = Paint()
        ..color = AppTheme.primaryColor.withOpacity(0.05)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      for (var i = 0; i < 6; i++) {
        final path = Path();
        final baseY = size.height * (0.15 + i * 0.14);
        path.moveTo(0, baseY);
        for (var x = 0.0; x <= size.width; x += 12) {
          path.lineTo(
            x,
            baseY + (i.isEven ? 8 : -8) * (x / size.width).clamp(0.0, 1.0),
          );
        }
        canvas.drawPath(path, wavePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ChatPatternPainter oldDelegate) {
    return oldDelegate.pattern != pattern;
  }
}
