import 'package:flutter/material.dart';

/// Professional App Theme
/// Centralized theme configuration for consistent UI design
class AppTheme {
  // Color Palette
  static const Color primaryColor = Color(0xFF8B4513); // Brown
  static const Color secondaryColor = Color(0xFFE3F2FD); // Light Blue
  static const Color backgroundColor = Color(0xFFF5F5DC); // Beige/Cream
  static const Color themeColor = Color(0xFFFEFAE2); // Beige/Cream
  static const Color accentColor = Color(0xFFFEECE2); // Light Peach
  static const Color textPrimary = Color(0xFF2C3E50); // Dark Gray
  static const Color textSecondary = Color(0xFF7F8C8D); // Medium Gray
  static const Color errorColor = Color(0xFFE74C3C); // Red
  static const Color successColor = Color(0xFF27AE60); // Green
  static const Color warningColor = Color(0xFFF39C12); // Orange
  static const Color iconscolor = Color(0xFFF29D38); // Orange


  // Card Styles
  static BoxDecoration cardDecoration({
    Color? color,
    double borderRadius = 16.0,
    bool elevated = true,
  }) {
    return BoxDecoration(
      color: color ?? Colors.white,
      borderRadius: BorderRadius.circular(borderRadius),
      boxShadow: elevated
          ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
                spreadRadius: 0,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 4,
                offset: const Offset(0, 2),
                spreadRadius: 0,
              ),
            ]
          : null,
    );
  }

  // Button Styles
  static ButtonStyle primaryButtonStyle({
    double? borderRadius,
    EdgeInsetsGeometry? padding,
  }) {
    return ElevatedButton.styleFrom(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      elevation: 2,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius ?? 12),
      ),
    );
  }

  static ButtonStyle secondaryButtonStyle({
    double? borderRadius,
    EdgeInsetsGeometry? padding,
  }) {
    return OutlinedButton.styleFrom(
      foregroundColor: primaryColor,
      side: const BorderSide(color: primaryColor, width: 1.5),
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius ?? 12),
      ),
    );
  }

  // Text Styles
  static TextStyle heading1(BuildContext context) {
    return TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.bold,
      color: textPrimary,
      letterSpacing: -0.5,
    );
  }

  static TextStyle heading2(BuildContext context) {
    return TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: textPrimary,
      letterSpacing: -0.3,
    );
  }

  static TextStyle heading3(BuildContext context) {
    return TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: textPrimary,
      letterSpacing: -0.2,
    );
  }

  static TextStyle bodyLarge(BuildContext context) {
    return TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.normal,
      color: textPrimary,
      height: 1.5,
    );
  }

  static TextStyle bodyMedium(BuildContext context) {
    return TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.normal,
      color: textPrimary,
      height: 1.5,
    );
  }

  static TextStyle bodySmall(BuildContext context) {
    return TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.normal,
      color: textSecondary,
      height: 1.4,
    );
  }

  // Spacing
  static const double spacingXS = 4.0;
  static const double spacingSM = 8.0;
  static const double spacingMD = 16.0;
  static const double spacingLG = 24.0;
  static const double spacingXL = 32.0;
  static const double spacingXXL = 48.0;

  // Border Radius
  static const double radiusSM = 8.0;
  static const double radiusMD = 12.0;
  static const double radiusLG = 16.0;
  static const double radiusXL = 24.0;
  static const double radiusFull = 999.0;

  // Animation Durations
  static const Duration animationFast = Duration(milliseconds: 200);
  static const Duration animationNormal = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);

  // Animation Curves
  static const Curve animationCurve = Curves.easeInOutCubic;
}

