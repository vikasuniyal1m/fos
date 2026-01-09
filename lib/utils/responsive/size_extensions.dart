import 'package:flutter/material.dart';

extension ResponsiveNumExtension on num {
  /// Returns a responsive font size based on the screen width.
  ///
  /// The font size is scaled relative to a base screen width (e.g., 375.0 for iPhone X).
  double get sp {
    // You can adjust the base screen width as needed for your design.
    const double baseScreenWidth = 375.0; 
    return (this / baseScreenWidth) * WidgetsBinding.instance.window.physicalSize.width / WidgetsBinding.instance.window.devicePixelRatio;
  }
}