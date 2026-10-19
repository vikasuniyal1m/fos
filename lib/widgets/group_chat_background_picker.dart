import 'package:flutter/material.dart';
import 'package:fruitsofspirit/utils/app_theme.dart';
import 'package:fruitsofspirit/utils/group_chat_backgrounds.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';

/// Top panel — pick chat wallpaper (opens below header, not bottom).
class GroupChatBackgroundPicker extends StatelessWidget {
  final String selectedId;
  final ValueChanged<String> onSelected;

  const GroupChatBackgroundPicker({
    Key? key,
    required this.selectedId,
    required this.onSelected,
  }) : super(key: key);

  static Future<void> show(
    BuildContext context, {
    required String selectedId,
    required ValueChanged<String> onSelected,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black26,
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (ctx, _, __) {
        return SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.only(
                top: ResponsiveHelper.safeHeight(ctx, mobile: 72, tablet: 90),
                left: 12,
                right: 12,
              ),
              child: GroupChatBackgroundPicker(
                selectedId: selectedId,
                onSelected: onSelected,
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim, _, child) {
        return FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.08),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.wallpaper_rounded, color: AppTheme.iconscolor, size: 22),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Chat Background',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5F4628),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.close_rounded, color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.9,
                ),
                itemCount: GroupChatBackgrounds.options.length,
                itemBuilder: (context, index) {
                  final option = GroupChatBackgrounds.options[index];
                  final isSelected = option.id == selectedId;
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      onSelected(option.id);
                      Navigator.pop(context);
                    },
                    child: Column(
                      children: [
                        Expanded(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  gradient: LinearGradient(
                                    colors: option.colors,
                                  ),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppTheme.iconscolor
                                        : Colors.grey.withOpacity(0.3),
                                    width: isSelected ? 2.5 : 1,
                                  ),
                                ),
                                child: option.pattern != BackgroundPattern.none
                                    ? CustomPaint(
                                        painter: _PreviewPatternPainter(
                                          option.pattern,
                                        ),
                                      )
                                    : null,
                              ),
                              if (isSelected)
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.iconscolor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.check,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          option.label,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? AppTheme.iconscolor
                                : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewPatternPainter extends CustomPainter {
  _PreviewPatternPainter(this.pattern);

  final BackgroundPattern pattern;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.iconscolor.withOpacity(0.12)
      ..style = PaintingStyle.fill;
    if (pattern == BackgroundPattern.dots) {
      for (var y = 6.0; y < size.height; y += 12) {
        for (var x = 6.0; x < size.width; x += 12) {
          canvas.drawCircle(Offset(x, y), 1.5, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
