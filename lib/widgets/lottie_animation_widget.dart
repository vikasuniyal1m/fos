import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Advanced Lottie Animation Widget
/// Use this widget to display Lottie animations in your app
class LottieAnimationWidget extends StatelessWidget {
  final String assetPath;
  final double? width;
  final double? height;
  final bool repeat;
  final bool reverse;
  final AnimationController? controller;
  final BoxFit fit;
  final Color? color;

  const LottieAnimationWidget({
    Key? key,
    required this.assetPath,
    this.width,
    this.height,
    this.repeat = true,
    this.reverse = false,
    this.controller,
    this.fit = BoxFit.contain,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Lottie.asset(
      assetPath,
      width: width,
      height: height,
      repeat: repeat,
      reverse: reverse,
      controller: controller,
      fit: fit,
      options: LottieOptions(
        enableMergePaths: true,
      ),
    );
  }
}

/// Example usage in your code:
/// 
/// LottieAnimationWidget(
///   assetPath: 'assets/animations/praying_hands_advanced.json',
///   width: 200,
///   height: 200,
///   repeat: true,
/// )

