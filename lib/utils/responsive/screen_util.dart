import 'package:flutter/widgets.dart';

class ScreenUtil {
  static late double _screenWidth;
  static late double _screenHeight;
  static late double _pixelRatio;
  static late double _textScaleFactor;

  static void init(BuildContext context) {
    final mediaQueryData = MediaQuery.of(context);
    _screenWidth = mediaQueryData.size.width;
    _screenHeight = mediaQueryData.size.height;
    _pixelRatio = mediaQueryData.devicePixelRatio;
    _textScaleFactor = mediaQueryData.textScaleFactor;
  }

  /// Returns the screen width.
  static double get screenWidth => _screenWidth;

  /// Returns the screen height.
  static double get screenHeight => _screenHeight;

  /// Returns a responsive width value based on the screen width.
  ///
  /// [percentage] is the percentage of the screen width to use (e.g., 0.5 for 50%).
  static double responsiveWidth(double percentage) {
    return _screenWidth * percentage;
  }

  /// Returns a responsive height value based on the screen height.
  ///
  /// [percentage] is the percentage of the percentage of the screen height to use (e.g., 0.5 for 50%).
  static double responsiveHeight(double percentage) {
    return _screenHeight * percentage;
  }

  /// Returns a responsive font size based on the screen width.
  ///
  /// The font size is scaled relative to a base screen width (e.g., 375.0 for iPhone X).
  static double sp(num size) {
    // You can adjust the base screen width as needed for your design.
    const double baseScreenWidth = 375.0; 
    return (size / baseScreenWidth) * _screenWidth / _pixelRatio * _textScaleFactor;
  }

  /// Returns a responsive width value based on the screen width.
  ///
  /// [width] is the desired width in design pixels.
  static double w(num width) {
    return width / 375.0 * _screenWidth;
  }

  /// Returns a responsive height value based on the screen height.
  ///
  /// [height] is the desired height in design pixels.
  static double h(num height) {
    return height / 812.0 * _screenHeight; // Assuming a base height of 812.0 for iPhone X
  }
}