import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Screen Size Utility
/// Professional responsive design utility for device-adaptive UI
/// Calculates responsive sizes based on screen dimensions
/// All text, buttons, tiles, and UI elements use this for consistent sizing
class ScreenSize {
  static late MediaQueryData _mediaQueryData;
  static late double screenWidth;
  static late double screenHeight;
  static late double blockSizeHorizontal;
  static late double blockSizeVertical;
  static late double statusBarHeight;
  static late double bottomBarHeight;
  static late double safeAreaTop;
  static late double safeAreaBottom;
  static late double safeAreaHorizontal;
  static late Orientation orientation;
  static late double devicePixelRatio;
  static late double textScaleFactor;
  
  // Device type detection - initialized with defaults
  static bool isSmallPhone = false;
  static bool isMediumPhone = false;
  static bool isLargePhone = false;
  static bool isTablet = false;
  static bool isSmallTablet = false;
  static bool isLargeTablet = false;
  
  // Responsive scale factors - initialized with defaults
  static double scaleFactor = 1.0;
  static double textScale = 1.0;
  static double spacingScale = 1.0;

  /// Initialize screen size - Call this in main.dart or at the start of each screen
  static void init(BuildContext context) {
    _mediaQueryData = MediaQuery.of(context);
    screenWidth = _mediaQueryData.size.width;
    screenHeight = _mediaQueryData.size.height;
    blockSizeHorizontal = screenWidth / 100;
    blockSizeVertical = screenHeight / 100;
    statusBarHeight = _mediaQueryData.padding.top;
    bottomBarHeight = _mediaQueryData.padding.bottom;
    safeAreaTop = _mediaQueryData.padding.top;
    safeAreaBottom = _mediaQueryData.padding.bottom;
    safeAreaHorizontal = _mediaQueryData.padding.left + _mediaQueryData.padding.right;
    orientation = _mediaQueryData.orientation;
    devicePixelRatio = _mediaQueryData.devicePixelRatio;
    textScaleFactor = _mediaQueryData.textScaleFactor;
    
    // Detect device type
    _detectDeviceType();
    
    // Calculate scale factors
    _calculateScaleFactors();
    
    // Note: ScreenUtil is initialized by ScreenUtilInit in main.dart
    // No need to call ScreenUtil.init() here to avoid double initialization
    
    // Debug: Log device detection (only in debug mode)
    if (kDebugMode) {
      print('[ScreenSize] Device Detected: ${deviceCategory}');
      print('[ScreenSize] Screen Width: ${screenWidth.toStringAsFixed(1)}px, Height: ${screenHeight.toStringAsFixed(1)}px');
      print('[ScreenSize] Text Scale: ${textScale.toStringAsFixed(2)}, Spacing Scale: ${spacingScale.toStringAsFixed(2)}');
      print('[ScreenSize] Orientation: ${orientation == Orientation.portrait ? 'Portrait' : 'Landscape'}');
    }
  }
  
  /// Detect device type based on screen width
  static void _detectDeviceType() {
    final width = screenWidth;
    
    // Small phones (iPhone SE, small Android phones) - < 360px
    isSmallPhone = width < 360;
    
    // Medium phones (standard phones like iPhone 12, most Android phones) - 360-414px
    isMediumPhone = width >= 360 && width < 414;
    
    // Large phones (iPhone Pro Max, Samsung Galaxy S25, large Android phones) - 414-600px
    isLargePhone = width >= 414 && width < 600;
    
    // Small tablets (iPad Mini, small Android tablets) - 600-768px
    isSmallTablet = width >= 600 && width < 768;
    
    // Large tablets (iPad Pro, large Android tablets) - >= 768px
    isLargeTablet = width >= 768;
    
    // General tablet check
    isTablet = width >= 600;
  }
  
  /// Calculate responsive scale factors
  static void _calculateScaleFactors() {
    // Base scale on screen width (375 is reference - iPhone X standard)
    final baseWidth = 375.0;
    scaleFactor = screenWidth / baseWidth;
    
    textScale = 1.0;
    spacingScale = 1.0;
  }

  /// Get responsive width percentage
  static double widthPercent(double percent) {
    return screenWidth * (percent / 100);
  }

  /// Get responsive height percentage
  static double heightPercent(double percent) {
    return screenHeight * (percent / 100);
  }
  
  /// Get responsive font size based on device type
  static double responsiveFontSize(double baseSize) {
    return baseSize * textScale * scaleFactor;
  }
  
  /// Get responsive spacing based on device type
  static double responsiveSpacing(double baseSpacing) {
    return baseSpacing * spacingScale;
  }

  /// Text Sizes - Responsive and device-adaptive
  /// Uses ScreenUtil extensions (.sp) - only works after ScreenUtil.init()
  static double get textExtraSmall => 10.0.sp;
  static double get textSmall => 12.0.sp;
  static double get textMedium => 14.0.sp;
  static double get textLarge => 16.0.sp;
  static double get textExtraLarge => 18.0.sp;
  
  /// Heading Sizes - Professional and responsive
  static double get headingSmall => 20.0.sp;
  static double get headingMedium => 24.0.sp;
  static double get headingLarge => 28.0.sp;
  static double get headingExtraLarge => 32.0.sp;
  static double get headingHuge => 36.0.sp;
  
  /// Button Sizes - Touch-friendly and adaptive
  static double get buttonHeightSmall => 40.0.h;
  static double get buttonHeightMedium => 48.0.h;
  static double get buttonHeightLarge => 56.0.h;
  static double get buttonHeightExtraLarge => 64.0.h;
  static double get buttonPaddingHorizontal => 24.0.w;
  static double get buttonPaddingVertical => 12.0.h;
  static double get buttonBorderRadius => 8.0.r;
  static double get buttonBorderRadiusLarge => 12.0.r;
  
  /// Tile/Card Sizes - Responsive card dimensions
  static double get tilePadding => 16.0.w;
  static double get tileBorderRadius => 12.0.r;
  static double get tileBorderRadiusLarge => 16.0.r;
  static double get tileElevation => 2.0;
  static double get tileMargin => 8.0.h;
  
  /// Icon Sizes - Adaptive icon sizing
  static double get iconSmall => 16.0.w;
  static double get iconMedium => 24.0.w;
  static double get iconLarge => 32.0.w;
  static double get iconExtraLarge => 48.0.w;
  
  /// Spacing - Professional spacing system
  static double get spacingExtraSmall => 4.0.h;
  static double get spacingXSmall => 4.0.h; // Alias for spacingExtraSmall
  static double get spacingSmall => 8.0.h;
  static double get spacingMedium => 15.0.h;
  static double get spacingLarge => 24.0.h;
  static double get spacingExtraLarge => 32.0.h;
  static double get spacingXLarge => 32.0.h; // Alias for spacingExtraLarge
  static double get spacingHuge => 48.0.h;
  
  /// App Bar - Responsive app bar height
  static double get appBarHeight => 56.0.h;
  static double get appBarElevation => 0.0;
  
  /// Bottom Navigation - Adaptive bottom nav
  static double get bottomNavHeight => 60.0.h;
  static double get bottomNavIconSize => 24.0.w;
  
  /// Input Fields - Touch-friendly input sizes
  static double get inputHeight => 48.0.h;
  static double get inputBorderRadius => 8.0.r;
  static double get inputPadding => 16.0.w;
  
  /// Border Radius - General purpose border radius values
  static double get borderRadiusSmall => 6.0.r;
  static double get borderRadiusMedium => 12.0.r;
  static double get borderRadiusLarge => 16.0.r;
  
  /// Dividers
  static double get dividerHeight => 1.0.h;
  static double get dividerThickness => 0.5;
  
  /// Banner/Carousel Heights - Responsive banner sizes
  static double get bannerHeight => 180.0.h;
  static double get bannerHeightLarge => 220.0.h;
  
  /// Category Item Sizes - Adaptive category icons
  static double get categoryIconSize => 70.0.w;
  static double get categoryItemWidth => 80.0.w;
  static double get categorySectionHeight => 100.0.h;
  
  /// Product Card Sizes - Responsive product grid
  static double get productCardImageHeight => 140.0.h;
  static double get productCardAspectRatio => 0.68;
  static double get productCardHorizontalWidth => 200.0.w;
  static double get productCardHorizontalHeight => 280.0.h;
  
  /// Grid Configuration - Adaptive grid layouts
  static int get gridCrossAxisCount => isTablet ? 3 : 2; // 3 columns for tablet now that items are scaled up
  static double get gridSpacing => 16.0.w;
  
  /// Padding/Margin - Responsive padding system
  static double get paddingExtraSmall => 4.0.w;
  static double get paddingSmall => 8.0.w;
  static double get paddingMedium => 16.0.w;
  static double get paddingLarge => 24.0.w;
  static double get paddingExtraLarge => 32.0.w;
  
  /// Section Spacing - Professional section gaps
  static double get sectionSpacing => 24.0.h;
  static double get sectionSpacingLarge => 32.0.h;
  
  /// Badge Sizes - Responsive badge dimensions
  static double get badgeHeight => 20.0.h;
  static double get badgePadding => 6.0.w;
  static double get badgeFontSize => 10.0.sp;

  /// Check if device is tablet
  static bool get isTabletDevice => isTablet;
  
  /// Check if device is phone
  static bool get isPhoneDevice => !isTablet;
  
  /// Check if landscape
  static bool get isLandscape => orientation == Orientation.landscape;
  
  /// Check if portrait
  static bool get isPortrait => orientation == Orientation.portrait;
  
  /// Get device category name (for debugging)
  static String get deviceCategory {
    if (isSmallPhone) return 'Small Phone';
    if (isMediumPhone) return 'Medium Phone';
    if (isLargePhone) return 'Large Phone';
    if (isSmallTablet) return 'Small Tablet';
    if (isLargeTablet) return 'Large Tablet';
    return 'Unknown';
  }
}
