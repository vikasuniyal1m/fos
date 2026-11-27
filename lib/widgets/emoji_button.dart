import 'package:flutter/material.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';
import 'package:fruitsofspirit/utils/app_theme.dart';

/// Reusable Emoji Button Widget
/// Matches the exact implementation from blog_details_screen
class EmojiButton extends StatelessWidget {
  final VoidCallback onTap;

  const EmojiButton({
    Key? key,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ResponsiveHelper.isMobile(context) ? 40 : 44),
        child: Padding(
          padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 4)),
          child: Container(
            width: ResponsiveHelper.isMobile(context) ? 44 : 48,
            height: ResponsiveHelper.isMobile(context) ? 44 : 48,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.add_reaction_rounded,
              size: ResponsiveHelper.fontSize(context, mobile: 22),
              color: AppTheme.iconscolor,
            ),
          ),
        ),
      ),
    );
  }
}
