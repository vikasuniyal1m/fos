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

  // Base screen dimensions (iPhone 12 Pro / Common Android device)
  static const double baseWidth = 390.0;
  static const double baseHeight = 844.0;

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
    
    // Mobile: Use original size with scale factor (unchanged - don't touch)
    final screenInfo = getScreenInfo(context);
    final scale = screenInfo['scale']!;
    final baseSize = mobile * scale;
    
    // Mobile: Apply scaling with limits
    final width = screenWidth(context);
    if (baseSize < 10) return 10;
    final maxSize = width * 0.05;
    if (baseSize > maxSize) return maxSize;
    
    return baseSize;
  }

  /// Get responsive padding based on screen size
  /// Professional calculation: Tablets use ScreenSize utility, mobile uses scale
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
        // Mobile: Use scale factor (unchanged - don't touch)
        return _getResponsiveValue(context, value);
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
    final screenInfo = getScreenInfo(context);
    final scale = screenInfo['scale']!;
    
    // Use scale factor to make everything proportional to actual screen
    final scaledValue = value * scale;
    
    // Ensure minimum value to prevent too small elements
    if (scaledValue < value * 0.7) {
      return value * 0.7;
    }
    
    // Ensure maximum value to prevent overflow
    final maxWidth = screenInfo['width']!;
    if (scaledValue > maxWidth * 0.9) {
      return maxWidth * 0.9;
    }
    
    return scaledValue;
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
    // Mobile: Return original (unchanged)
    return mobile;
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
    // Mobile: Return original (unchanged)
    return mobile;
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
    // Mobile: Return original (unchanged)
    return mobile;
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
    
    // Mobile: Use scale factor (unchanged - don't touch)
    final screenInfo = getScreenInfo(context);
    final scale = screenInfo['scale']!;
    final scaledValue = baseSpacing * scale;
    
    // Ensure spacing doesn't cause overflow
    if (scaledValue > width * 0.3) {
      return width * 0.3;
    }
    
    // Ensure minimum spacing
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
    if (isDesktop(context)) {
      return 48.0;
    } else if (isLargeTablet(context)) {
      return 40.0;
    } else if (isTablet(context)) {
      return 32.0;
    }
    return 16.0;
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

  /// Get responsive vertical padding for content
  static double contentVerticalPadding(BuildContext context) {
    if (isDesktop(context)) {
      return 32.0;
    } else if (isTablet(context)) {
      return 24.0;
    }
    return 16.0;
  }

  /// Get responsive app bar height
  static double appBarHeight(BuildContext context) {
    if (isDesktop(context)) {
      return 80.0;
    } else if (isTablet(context)) {
      return 70.0;
    }
    return 56.0;
  }

  /// Get responsive bottom navigation bar height
  static double bottomNavBarHeight(BuildContext context) {
    if (isDesktop(context)) {
      return 70.0;
    } else if (isTablet(context)) {
      return 65.0;
    }
    return 60.0;
  }

  /// Check if platform is iOS
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
}

enum DeviceType {
  mobile,
  tablet,
  desktop,
}

