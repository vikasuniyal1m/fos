import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io';
import 'package:fruitsofspirit/utils/screen_size.dart';

/// Responsive helper class for adaptive UI design
/// Based on Flutter's adaptive design principles: https://docs.flutter.dev/ui/adaptive-responsive
class ResponsiveHelper {
  // Breakpoints based on screen width
  // Professional responsive breakpoints following Material Design and iOS guidelines
  static const double mobileBreakpoint = 600.0;  // Below 600px = Mobile
  static const double tabletBreakpoint = 900.0;  // 600-900px = Small Tablet (iPad Mini, iPad)
  static const double largeTabletBreakpoint = 1200.0;  // 900-1200px = Large Tablet (iPad Pro)
  static const double desktopBreakpoint = 1200.0;  // Above 1200px = Desktop

  // Reference device: OnePlus CPH2707 (~363×800 logical) — UI tuned here = scale 1.0
  static const double baseWidth = 360.0;
  static const double baseHeight = 800.0;

  /// Small phones (iPhone SE, compact Android) — width under 340dp
  static bool isSmallPhone(BuildContext context) {
    return isMobile(context) && screenWidth(context) < 340;
  }

  /// Large phones (Pro Max, big Android) — width 400dp+
  static bool isLargePhone(BuildContext context) {
    return isMobile(context) && screenWidth(context) >= 400;
  }

  /// Unified scale: 1.0 on reference phone, smaller on tiny screens, larger on tablets.
  static double deviceScale(BuildContext context) {
    if (isDesktop(context)) return 1.35;
    if (isLargeTablet(context)) return 1.28;
    if (isTablet(context)) return 1.15;

    final info = getScreenInfo(context);
    final scaleW = info['scaleWidth']!;
    final scaleH = info['scaleHeight']!;
    final scale = scaleW < scaleH ? scaleW : scaleH;

    if (isSmallPhone(context)) return scale.clamp(0.82, 0.94);
    if (isLargePhone(context)) return scale.clamp(1.0, 1.12);
    return scale.clamp(0.92, 1.08);
  }

  // Max content width for tablets to prevent content from being too wide
  // Following Material Design guidelines: max content width should be 840px for tablets
  static const double maxTabletContentWidth = 840.0;
  static const double maxLargeTabletContentWidth = 900.0;

  /// Get actual screen width at runtime
  static double screenWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    // print('📱 Screen Width: $width'); // Commented out to reduce console spam
    return width;
  }

  /// Get actual screen height at runtime
  static double screenHeight(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    // print('📱 Screen Height: $height'); // Commented out to reduce console spam
    return height;
  }

  /// Get actual screen dimensions and calculate scale factors
  static Map<String, double> getScreenInfo(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final width = mediaQuery.size.width;
    final height = mediaQuery.size.height;
    final scaleWidth = width / baseWidth;
    final scaleHeight = height / baseHeight;
    final scale = scaleWidth < scaleHeight ? scaleWidth : scaleHeight; // Use smaller scale to prevent overflow
    
    // Commented out to reduce console spam
    // print('📱 Screen Info:');
    // print('   Width: $width');
    // print('   Height: $height');
    // print('   Scale Width: $scaleWidth');
    // print('   Scale Height: $scaleHeight');
    // print('   Using Scale: $scale');
    
    return {
      'width': width,
      'height': height,
      'scaleWidth': scaleWidth,
      'scaleHeight': scaleHeight,
      'scale': scale,
    };
  }

  /// Check if device is mobile
  static bool isMobile(BuildContext context) {
    return screenWidth(context) < mobileBreakpoint;
  }

  /// Check if device is tablet (includes iPad Mini, iPad, iPad Air, iPad Pro)
  static bool isTablet(BuildContext context) {
    final width = screenWidth(context);
    return width >= mobileBreakpoint && width < desktopBreakpoint;
  }

  /// Check if device is small tablet (iPad Mini, iPad, iPad Air, iPad Pro 11")
  static bool isSmallTablet(BuildContext context) {
    final width = screenWidth(context);
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }

  /// Check if device is large tablet (iPad Pro 12.9")
  static bool isLargeTablet(BuildContext context) {
    final width = screenWidth(context);
    return width >= tabletBreakpoint && width < desktopBreakpoint;
  }

  /// Check if device is iPad (iOS tablet)
  static bool isIPad(BuildContext context) {
    return Platform.isIOS && isTablet(context);
  }

  /// Check if device is desktop
  static bool isDesktop(BuildContext context) {
    return screenWidth(context) >= desktopBreakpoint;
  }

  /// Get device type
  static DeviceType getDeviceType(BuildContext context) {
    if (isDesktop(context)) return DeviceType.desktop;
    if (isTablet(context)) return DeviceType.tablet;
    return DeviceType.mobile;
  }

  /// Get responsive font size based on actual screen size
  /// Professional calculation: Tablets use ScreenSize utility, mobile stays as is
  static double fontSize(BuildContext context, {
    required double mobile,
    double? tablet,
    double? desktop,
  }) {
    // For tablets: Use ScreenSize utility (uses flutter_screenutil .sp extension)
    if (isLargeTablet(context) || isDesktop(context)) {
      // Map mobile size to ScreenSize equivalent
      if (tablet != null) return tablet;
      if (mobile <= 12) return ScreenSize.textSmall;
      if (mobile <= 14) return ScreenSize.textMedium;
      if (mobile <= 16) return ScreenSize.textLarge;
      if (mobile <= 18) return ScreenSize.textExtraLarge;
      if (mobile <= 20) return ScreenSize.headingSmall;
      if (mobile <= 24) return ScreenSize.headingMedium;
      if (mobile <= 28) return ScreenSize.headingLarge;
      if (mobile <= 32) return ScreenSize.headingExtraLarge;
      return ScreenSize.headingHuge;
    } else if (isTablet(context)) {
      // Small tablets: Use ScreenSize with slightly smaller values
      if (tablet != null) return tablet;
      if (mobile <= 12) return ScreenSize.textSmall;
      if (mobile <= 14) return ScreenSize.textMedium;
      if (mobile <= 16) return ScreenSize.textLarge;
      if (mobile <= 18) return ScreenSize.textExtraLarge;
      if (mobile <= 20) return ScreenSize.headingSmall;
      if (mobile <= 24) return ScreenSize.headingMedium;
      return ScreenSize.headingLarge;
    }
    
    // Mobile: scale from reference device (OnePlus baseline)
    final scale = deviceScale(context);
    final baseSize = mobile * scale;
    
    final width = screenWidth(context);
    if (baseSize < 10) return 10;
    final maxSize = width * 0.055;
    if (baseSize > maxSize) return maxSize;
    
    return baseSize;
  }

  /// Get responsive padding based on screen size
  /// Professional calculation: Tablets use ScreenSize utility, mobile uses consistent scale
  static EdgeInsets padding(BuildContext context, {
    double? all,
    double? horizontal,
    double? vertical,
    double? top,
    double? bottom,
    double? left,
    double? right,
  }) {
    // Helper to get responsive value
    double getValue(double value) {
      // For tablets: Use ScreenSize utility
      if (isLargeTablet(context) || isDesktop(context)) {
        // Map value to ScreenSize equivalent
        if (value <= 4) return ScreenSize.spacingExtraSmall;
        if (value <= 8) return ScreenSize.spacingSmall;
        if (value <= 15) return ScreenSize.spacingMedium;
        if (value <= 24) return ScreenSize.spacingLarge;
        return ScreenSize.spacingExtraLarge;
      } else if (isTablet(context)) {
        // Small tablets: Use ScreenSize
        if (value <= 4) return ScreenSize.spacingExtraSmall;
        if (value <= 8) return ScreenSize.spacingSmall;
        if (value <= 15) return ScreenSize.spacingMedium;
        return ScreenSize.spacingLarge;
      } else {
        final scaledValue = value * deviceScale(context);
        final maxWidth = screenWidth(context);
        if (scaledValue > maxWidth * 0.9) return maxWidth * 0.9;
        if (scaledValue < value * 0.82) return value * 0.82;
        return scaledValue;
      }
    }
    
    if (all != null) {
      return EdgeInsets.all(getValue(all));
    }
    
    return EdgeInsets.only(
      left: left != null ? getValue(left) : (horizontal != null ? getValue(horizontal) : 0.0),
      right: right != null ? getValue(right) : (horizontal != null ? getValue(horizontal) : 0.0),
      top: top != null ? getValue(top) : (vertical != null ? getValue(vertical) : 0.0),
      bottom: bottom != null ? getValue(bottom) : (vertical != null ? getValue(vertical) : 0.0),
    );
  }

  /// Get responsive width multiplier based on actual screen
  static double widthMultiplier(BuildContext context) {
    final screenInfo = getScreenInfo(context);
    return screenInfo['scaleWidth']!;
  }

  /// Get responsive height multiplier based on actual screen
  static double heightMultiplier(BuildContext context) {
    final screenInfo = getScreenInfo(context);
    return screenInfo['scaleHeight']!;
  }

  /// Get unified scale factor (prevents overflow)
  static double scaleFactor(BuildContext context) {
    final screenInfo = getScreenInfo(context);
    return screenInfo['scale']!;
  }

  /// Get responsive value based on actual screen size (prevents overflow)
  static double _getResponsiveValue(BuildContext context, double value) {
    return value * deviceScale(context);
  }

  /// Get responsive icon size
  /// Professional calculation: Tablets use ScreenSize utility, mobile stays as is
  static double iconSize(BuildContext context, {
    double mobile = 24.0,
    double? tablet,
    double? desktop,
  }) {
    // For tablets: Use ScreenSize utility
    if (isDesktop(context)) {
      return desktop ?? tablet ?? ScreenSize.iconLarge;
    } else if (isLargeTablet(context)) {
      return tablet ?? ScreenSize.iconLarge;
    } else if (isTablet(context)) {
      return tablet ?? ScreenSize.iconMedium;
    }
    // Mobile: Return responsive value
    return _getResponsiveValue(context, mobile);
  }

  /// Get responsive button height
  /// Professional calculation: Tablets use ScreenSize utility, mobile stays as is
  static double buttonHeight(BuildContext context, {
    double mobile = 48.0,
    double? tablet,
    double? desktop,
  }) {
    // For tablets: Use ScreenSize utility
    if (isDesktop(context)) {
      return desktop ?? tablet ?? ScreenSize.buttonHeightLarge;
    } else if (isLargeTablet(context)) {
      return tablet ?? ScreenSize.buttonHeightLarge;
    } else if (isTablet(context)) {
      return tablet ?? ScreenSize.buttonHeightMedium;
    }
    // Mobile: Return responsive value based on screen height
    return _getResponsiveValue(context, mobile);
  }

  /// Get responsive border radius
  /// Professional calculation: Tablets use ScreenSize utility, mobile stays as is
  static double borderRadius(BuildContext context, {
    double mobile = 8.0,
    double? tablet,
    double? desktop,
  }) {
    // For tablets: Use ScreenSize utility
    if (isDesktop(context)) {
      return desktop ?? tablet ?? ScreenSize.buttonBorderRadiusLarge;
    } else if (isLargeTablet(context)) {
      return tablet ?? ScreenSize.buttonBorderRadiusLarge;
    } else if (isTablet(context)) {
      return tablet ?? ScreenSize.buttonBorderRadius;
    }
    // Mobile: Return responsive value
    return _getResponsiveValue(context, mobile);
  }

  /// Get number of columns for grid based on screen size
  static int gridColumns(BuildContext context, {
    int mobile = 2,
    int? tablet,
    int? desktop,
  }) {
    if (isDesktop(context)) {
      return desktop ?? tablet ?? (mobile * 2);
    } else if (isTablet(context)) {
      return tablet ?? (mobile * 1.5).round();
    }
    return mobile;
  }

  /// Get responsive spacing based on actual screen size (prevents overflow)
  /// Professional calculation: Tablets use ScreenSize utility, mobile uses scale
  static double spacing(BuildContext context, double baseSpacing) {
    final width = screenWidth(context);
    
    // For tablets: Use ScreenSize utility
    if (isLargeTablet(context) || isDesktop(context)) {
      // Map baseSpacing to ScreenSize equivalent
      if (baseSpacing <= 4) return ScreenSize.spacingExtraSmall;
      if (baseSpacing <= 8) return ScreenSize.spacingSmall;
      if (baseSpacing <= 15) return ScreenSize.spacingMedium;
      if (baseSpacing <= 24) return ScreenSize.spacingLarge;
      return ScreenSize.spacingExtraLarge;
    } else if (isTablet(context)) {
      // Small tablets: Use ScreenSize with slightly smaller values
      if (baseSpacing <= 4) return ScreenSize.spacingExtraSmall;
      if (baseSpacing <= 8) return ScreenSize.spacingSmall;
      if (baseSpacing <= 15) return ScreenSize.spacingMedium;
      return ScreenSize.spacingLarge;
    }
    
    // Mobile: scale spacing from reference device
    final scale = deviceScale(context);
    final scaledValue = baseSpacing * scale;
    
    if (scaledValue > width * 0.3) {
      return width * 0.3;
    }
    if (scaledValue < 4) return 4;
    
    return scaledValue;
  }

  /// Get responsive card width
  static double cardWidth(BuildContext context, {
    double? mobile,
    double? tablet,
    double? desktop,
  }) {
    final width = screenWidth(context);
    if (isDesktop(context)) {
      return desktop ?? (width * 0.3);
    } else if (isTablet(context)) {
      return tablet ?? (width * 0.45);
    }
    return mobile ?? (width * 0.9);
  }

  /// Get responsive card height
  static double cardHeight(BuildContext context, {
    double? mobile,
    double? tablet,
    double? desktop,
  }) {
    final height = screenHeight(context);
    if (isDesktop(context)) {
      return desktop ?? (height * 0.4);
    } else if (isTablet(context)) {
      return tablet ?? (height * 0.35);
    }
    return mobile ?? (height * 0.3);
  }

  /// Get responsive image width
  /// For tablets, uses max content width to prevent images from being too wide
  static double imageWidth(BuildContext context, {
    double? mobile,
    double? tablet,
    double? desktop,
  }) {
    final width = screenWidth(context);
    if (isDesktop(context)) {
      return desktop ?? (width * 0.4);
    } else if (isLargeTablet(context)) {
      // Large tablets: use max content width constraint
      final calculatedWidth = tablet ?? (width * 0.5);
      return calculatedWidth > maxLargeTabletContentWidth * 0.6 
          ? maxLargeTabletContentWidth * 0.6 
          : calculatedWidth;
    } else if (isTablet(context)) {
      // Small tablets: use max content width constraint
      final calculatedWidth = tablet ?? (width * 0.5);
      return calculatedWidth > maxTabletContentWidth * 0.7 
          ? maxTabletContentWidth * 0.7 
          : calculatedWidth;
    }
    return mobile ?? (width * 0.9);
  }

  /// Get responsive image height
  /// For tablets, maintains aspect ratio while preventing overflow
  static double imageHeight(BuildContext context, {
    double? mobile,
    double? tablet,
    double? desktop,
  }) {
    final height = screenHeight(context);
    if (isDesktop(context)) {
      return desktop ?? (height * 0.5);
    } else if (isLargeTablet(context)) {
      return tablet ?? (height * 0.45);
    } else if (isTablet(context)) {
      return tablet ?? (height * 0.4);
    }
    return mobile ?? (height * 0.25);
  }

  /// Get responsive horizontal padding for content
  /// For tablets, provides more padding for better readability
  static double contentPadding(BuildContext context) {
    return screenHorizontalInset(context);
  }

  /// Device-aware side inset — compact on phones for more content width.
  static double screenHorizontalInset(BuildContext context) {
    if (isDesktop(context)) {
      return dim(context, mobile: 20, tablet: 24, min: 16, max: 28);
    }
    if (isLargeTablet(context)) {
      return dim(context, mobile: 16, tablet: 20, min: 14, max: 24);
    }
    if (isTablet(context)) {
      return dim(context, mobile: 14, tablet: 18, min: 12, max: 22);
    }
    if (isSmallPhone(context)) {
      return dim(context, mobile: 8, min: 6, max: 10);
    }
    if (isLargePhone(context)) {
      return dim(context, mobile: 12, min: 10, max: 14);
    }
    return dim(context, mobile: 10, min: 8, max: 12);
  }

  /// Compact top gap below app bar / above first home section.
  static double screenTopInset(BuildContext context) {
    if (isTablet(context)) {
      return dim(context, mobile: 6, tablet: 8, min: 4, max: 10);
    }
    if (isSmallPhone(context)) {
      return dim(context, mobile: 2, min: 0, max: 3);
    }
    return dim(context, mobile: 3, min: 2, max: 5);
  }

  /// Vertical gap between home sections — scales down on small phones.
  static double homeSectionGap(BuildContext context, {double mobile = 4}) {
    if (isTablet(context)) {
      return dim(context, mobile: mobile + 2, tablet: mobile + 4);
    }
    if (isSmallPhone(context)) {
      return dim(context, mobile: mobile * 0.5, min: 2, max: mobile);
    }
    return dim(context, mobile: mobile * 0.75, min: 2, max: mobile + 1);
  }

  /// Standard home screen horizontal padding (no double scaling).
  static EdgeInsets homeScreenPadding(
    BuildContext context, {
    double vertical = 0,
    bool top = false,
    bool bottom = false,
  }) {
    final h = screenHorizontalInset(context);
    return EdgeInsets.only(
      left: h,
      right: h,
      top: top ? (vertical > 0 ? homeSectionGap(context, mobile: vertical) : screenTopInset(context)) : 0,
      bottom: bottom ? homeSectionGap(context, mobile: vertical > 0 ? vertical : 4) : 0,
    );
  }

  /// Get max content width for tablets to prevent content from being too wide
  /// Following Material Design guidelines for optimal reading width
  static double maxContentWidth(BuildContext context) {
    if (isDesktop(context)) {
      return maxLargeTabletContentWidth;
    } else if (isLargeTablet(context)) {
      return maxLargeTabletContentWidth;
    } else if (isTablet(context)) {
      return maxTabletContentWidth;
    }
    return screenWidth(context); // Mobile: use full width
  }

  /// Get responsive bottom navigation bar height
  static double bottomNavBarHeight(BuildContext context) {
    return dim(context, mobile: 56, tablet: 62, desktop: 68, min: 48, max: 72);
  }

  /// Get responsive vertical padding for content
  static double contentVerticalPadding(BuildContext context) {
    return homeSectionGap(context, mobile: isTablet(context) ? 12 : 6);
  }

  /// Generic responsive dimension from a mobile base (scales on every device).
  static double dim(BuildContext context, {
    required double mobile,
    double? tablet,
    double? desktop,
    double? min,
    double? max,
  }) {
    double value;
    if (isDesktop(context)) {
      value = desktop ?? tablet ?? mobile * 1.35;
    } else if (isLargeTablet(context)) {
      value = tablet ?? mobile * 1.28;
    } else if (isTablet(context)) {
      value = tablet ?? mobile * 1.15;
    } else {
      value = mobile * deviceScale(context);
    }
    if (min != null && value < min) value = min;
    if (max != null && value > max) value = max;
    return value;
  }

  /// Toolbar height without BuildContext (for PreferredSizeWidget).
  static double scaledToolbarHeight([BuildContext? context]) {
    if (context != null) return appBarHeight(context);
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return kToolbarHeight;
    final width = MediaQueryData.fromView(views.first).size.width;
    
    if (width >= desktopBreakpoint) return 88.0;
    if (width >= tabletBreakpoint) return 84.0;
    if (width >= mobileBreakpoint) {
       // Consistent fluid scale for tablets
       return (74.0 + (width - 600) / 600 * 8).clamp(74.0, 82.0);
    }
    
    return 56.0;
  }

  /// Bottom nav icons — scaled and capped to avoid overflow in the bar.
  static double bottomNavIconSize(BuildContext context) {
    final base = isTablet(context) ? 28.0 : 26.0;
    final size = dim(context, mobile: base, tablet: 30, desktop: 32);
    final max = kBottomNavigationBarHeight * (isTablet(context) ? 0.46 : 0.44);
    return size > max ? max : size;
  }

  static double bottomNavActiveIconSize(BuildContext context) {
    final active = bottomNavIconSize(context) * 1.06;
    final max = kBottomNavigationBarHeight * 0.48;
    return active > max ? max : active;
  }

  /// Circular action button in app bar (search, profile, etc.).
  static double appBarActionSize(BuildContext context) {
    return dim(context, mobile: 40, tablet: 48, desktop: 52, min: 36, max: 56);
  }

  /// Get responsive app bar height
  static double appBarHeight(BuildContext context) {
    final width = screenWidth(context);
    if (isDesktop(context)) return 88.0;
    if (isLargeTablet(context)) return 84.0;
    if (isTablet(context)) {
      // Fluid scale for tablets: starts at 74 for 600px width, reaches 82 for 1200px
      return (74.0 + (width - 600) / 600 * 8).clamp(74.0, 82.0);
    }
    // Mobile: scale between 56 and 70
    return (56.0 * deviceScale(context)).clamp(56.0, 70.0);
  }

  /// Notch / status bar inset (works without BuildContext).
  static double statusBarHeight([BuildContext? context]) {
    if (context != null) {
      return MediaQuery.of(context).padding.top;
    }
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return 47;
    return MediaQueryData.fromView(views.first).padding.top;
  }

  /// Home indicator / gesture bar inset.
  static double bottomSafeHeight([BuildContext? context]) {
    if (context != null) {
      return MediaQuery.of(context).padding.bottom;
    }
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return 34;
    return MediaQueryData.fromView(views.first).padding.bottom;
  }

  /// Status bar + toolbar — for StandardAppBar preferredSize.
  static double totalAppBarHeight(BuildContext context) {
    return statusBarHeight(context) + appBarHeight(context);
  }

  /// Bottom nav bar + home indicator — for bottomNavigationBar slot.
  static double totalBottomNavHeight(BuildContext context) {
    return bottomSafeHeight(context) + bottomNavBarHeight(context);
  }

  static bool isIOS(BuildContext context) {
    return Platform.isIOS;
  }

  /// Check if platform is Android
  static bool isAndroid(BuildContext context) {
    return Platform.isAndroid;
  }

  /// Get iOS-specific safe area padding
  static EdgeInsets iosSafeAreaPadding(BuildContext context) {
    if (!Platform.isIOS) {
      return EdgeInsets.zero;
    }
    final mediaQuery = MediaQuery.of(context);
    return EdgeInsets.only(
      top: mediaQuery.padding.top,
      bottom: mediaQuery.padding.bottom,
      left: mediaQuery.padding.left,
      right: mediaQuery.padding.right,
    );
  }

  /// Get iOS-specific button style
  /// Note: CupertinoButton doesn't have styleFrom, use CupertinoButton.filled instead
  static ButtonStyle iosButtonStyle({
    Color? backgroundColor,
    Color? foregroundColor,
  }) {
    // For iOS, return a ButtonStyle that works with CupertinoButton
    return ElevatedButton.styleFrom(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
    );
  }

  /// Get platform-adaptive text style (iOS uses SF Pro, Android uses Roboto)
  static TextStyle adaptiveTextStyle(BuildContext context, {
    required double fontSize,
    FontWeight? fontWeight,
    Color? color,
  }) {
    if (Platform.isIOS) {
      return TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        fontFamily: '.SF Pro Text', // iOS default font
      );
    }
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      fontFamily: 'Roboto', // Android default font
    );
  }

  /// Get iOS-specific spacing (iOS uses 8pt grid system)
  static double iosSpacing(BuildContext context, double value) {
    if (!Platform.isIOS) {
      return spacing(context, value);
    }
    // iOS uses 8pt grid system, round to nearest 8
    return (value / 8).round() * 8.0;
  }

  /// Get iOS-specific border radius
  static double iosBorderRadius(BuildContext context, {double? mobile}) {
    if (!Platform.isIOS) {
      return borderRadius(context, mobile: mobile ?? 12.0);
    }
    // iOS typically uses 8, 12, 16, 20 for border radius
    return mobile ?? 12.0;
  }

  /// Get platform-adaptive button style
  static ButtonStyle adaptiveButtonStyle(BuildContext context, {
    Color? backgroundColor,
    Color? foregroundColor,
    double? elevation,
  }) {
    final isIOSDevice = isIOS(context);
    final isMobileDevice = isMobile(context);
    
    if (isIOSDevice) {
      return ElevatedButton.styleFrom(
        backgroundColor: backgroundColor ?? Theme.of(context).primaryColor,
        foregroundColor: foregroundColor ?? Colors.white,
        padding: padding(context, vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius(context)),
        ),
        elevation: elevation ?? 0,
      );
    }
    
    return ElevatedButton.styleFrom(
      backgroundColor: backgroundColor ?? Theme.of(context).primaryColor,
      foregroundColor: foregroundColor ?? Colors.white,
      padding: padding(context, vertical: isMobileDevice ? 14 : 16, horizontal: isMobileDevice ? 20 : 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius(context)),
      ),
      elevation: elevation ?? 2,
    );
  }

  /// Get responsive text style
  static TextStyle textStyle(BuildContext context, {
    required double fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    return TextStyle(
      fontSize: ResponsiveHelper.fontSize(context, mobile: fontSize),
      fontWeight: fontWeight ?? FontWeight.normal,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  /// Get responsive heading text style
  static TextStyle headingStyle(BuildContext context, {
    Color? color,
    FontWeight? fontWeight,
  }) {
    return textStyle(
      context,
      fontSize: fontSize(context, mobile: 24, tablet: 28, desktop: 32),
      fontWeight: fontWeight ?? FontWeight.bold,
      color: color,
    );
  }

  /// Get responsive subheading text style
  static TextStyle subheadingStyle(BuildContext context, {
    Color? color,
    FontWeight? fontWeight,
  }) {
    return textStyle(
      context,
      fontSize: fontSize(context, mobile: 17, tablet: 20, desktop: 24),
      fontWeight: fontWeight ?? FontWeight.w600,
      color: color,
    );
  }

  /// Get responsive body text style
  static TextStyle bodyStyle(BuildContext context, {
    Color? color,
    FontWeight? fontWeight,
  }) {
    return textStyle(
      context,
      fontSize: fontSize(context, mobile: 16, tablet: 17, desktop: 18),
      fontWeight: fontWeight ?? FontWeight.normal,
      color: color,
    );
  }

  /// Get responsive caption text style
  static TextStyle captionStyle(BuildContext context, {
    Color? color,
    FontWeight? fontWeight,
  }) {
    return textStyle(
      context,
      fontSize: fontSize(context, mobile: 12, tablet: 13, desktop: 14),
      fontWeight: fontWeight ?? FontWeight.normal,
      color: color,
    );
  }

  /// Get responsive safe area padding
  static EdgeInsets safeAreaPadding(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return mediaQuery.padding;
  }

  /// Get responsive list item spacing
  static double listItemSpacing(BuildContext context) {
    return spacing(context, 12.0);
  }

  /// Get responsive grid spacing
  static double gridSpacing(BuildContext context) {
    return spacing(context, 16.0);
  }

  /// Get safe screen height (excluding status bar, app bar, etc.)
  static double safeScreenHeight(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return mediaQuery.size.height - 
           mediaQuery.padding.top - 
           mediaQuery.padding.bottom;
  }

  /// Get safe screen width
  static double safeScreenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  /// Get responsive height that prevents overflow
  static double safeHeight(BuildContext context, {
    required double mobile,
    double? tablet,
    double? desktop,
    double? maxHeight,
  }) {
    final height = isDesktop(context)
        ? (desktop ?? mobile * 1.5)
        : isTablet(context)
            ? (tablet ?? mobile * 1.2)
            : mobile;
    
    final maxAvailable = safeScreenHeight(context);
    final max = maxHeight ?? maxAvailable * 0.9;
    
    return height > max ? max : height;
  }

  /// Get responsive width that prevents overflow
  static double safeWidth(BuildContext context, {
    required double mobile,
    double? tablet,
    double? desktop,
    double? maxWidth,
  }) {
    final width = isDesktop(context)
        ? (desktop ?? mobile * 1.5)
        : isTablet(context)
            ? (tablet ?? mobile * 1.2)
            : mobile;
    
    final maxAvailable = safeScreenWidth(context);
    final max = maxWidth ?? maxAvailable * 0.95;
    
    return width > max ? max : width;
  }

  /// Get responsive padding that adapts to actual screen size (prevents overflow)
  /// Professional calculation: Tablets get more padding
  static EdgeInsets safePadding(BuildContext context, {
    double? all,
    double? horizontal,
    double? vertical,
    double? top,
    double? bottom,
    double? left,
    double? right,
  }) {
    final screenWidth = ResponsiveHelper.screenWidth(context);
    final screenHeight = ResponsiveHelper.screenHeight(context);
    
    // Calculate safe padding based on device type
    double getSafeValue(double value) {
      double scaledValue;
      
      if (isLargeTablet(context)) {
        scaledValue = value * 1.3;  // 30% more for large tablets
      } else if (isTablet(context)) {
        scaledValue = value * 1.25;  // 25% more for small tablets
      } else {
        // Mobile: Use scale factor
        final screenInfo = getScreenInfo(context);
        final scale = screenInfo['scale']!;
        scaledValue = value * scale;
      }
      
      // Ensure padding doesn't exceed 10% of screen width/height
      final maxHorizontal = screenWidth * 0.1;
      final maxVertical = screenHeight * 0.1;
      
      if (scaledValue > maxHorizontal) return maxHorizontal;
      if (scaledValue > maxVertical) return maxVertical;
      
      // Ensure minimum padding
      if (scaledValue < 4) return 4;
      
      return scaledValue;
    }
    
    if (all != null) {
      final safeAll = getSafeValue(all);
      return EdgeInsets.all(safeAll);
    }
    
    return EdgeInsets.only(
      left: left != null ? getSafeValue(left) : (horizontal != null ? getSafeValue(horizontal) : 0.0),
      right: right != null ? getSafeValue(right) : (horizontal != null ? getSafeValue(horizontal) : 0.0),
      top: top != null ? getSafeValue(top) : (vertical != null ? getSafeValue(vertical) : 0.0),
      bottom: bottom != null ? getSafeValue(bottom) : (vertical != null ? getSafeValue(vertical) : 0.0),
    );
  }

  /// Get responsive margin
  static EdgeInsets safeMargin(BuildContext context, {
    double? all,
    double? horizontal,
    double? vertical,
    double? top,
    double? bottom,
    double? left,
    double? right,
  }) {
    final baseMargin = isDesktop(context) ? 16.0 : isTablet(context) ? 12.0 : 8.0;
    
    return EdgeInsets.only(
      top: top ?? vertical ?? all ?? baseMargin,
      bottom: bottom ?? vertical ?? all ?? baseMargin,
      left: left ?? horizontal ?? all ?? baseMargin,
      right: right ?? horizontal ?? all ?? baseMargin,
    );
  }

  /// Create a safe scrollable container
  static Widget safeScrollable({
    required BuildContext context,
    required Widget child,
    bool enableScroll = true,
    ScrollPhysics? physics,
  }) {
    if (!enableScroll) {
      return child;
    }
    
    return SingleChildScrollView(
      physics: physics ?? const BouncingScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: safeScreenHeight(context),
        ),
        child: child,
      ),
    );
  }

  /// Wrap content with max width constraint for tablets/iPads
  /// This prevents content from being too wide on large screens
  /// Mobile: Uses full width (no constraint)
  /// Tablets: Uses max content width for optimal readability
  static Widget constrainedContent({
    required BuildContext context,
    required Widget child,
    double? maxWidth,
    Alignment alignment = Alignment.center,
  }) {
    if (isMobile(context)) {
      // Mobile: No constraint, use full width
      return child;
    }
    
    // Tablets/iPads: Apply max width constraint
    final contentMaxWidth = maxWidth ?? maxContentWidth(context);
    
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: contentMaxWidth,
        ),
        child: Align(
          alignment: alignment,
          child: child,
        ),
      ),
    );
  }

  /// Shorter screens (small phones, landscape) — tighter vertical layout.
  static bool isCompactHeight(BuildContext context) {
    return screenHeight(context) < dim(context, mobile: 700, tablet: 750);
  }

  static Widget vGap(BuildContext context, double mobile, {double? tablet}) {
    return SizedBox(height: spacing(context, mobile));
  }

  static Widget hGap(BuildContext context, double mobile) {
    return SizedBox(width: spacing(context, mobile));
  }
}

enum DeviceType {
  mobile,
  tablet,
  desktop,
}

