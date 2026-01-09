import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Animated Praying Hands Widget
/// Shows animated praying hands using Lottie animation
class AnimatedPrayingHands extends StatelessWidget {
  final double size;
  final Color color;

  const AnimatedPrayingHands({
    Key? key,
    this.size = 40.0,
    this.color = Colors.red,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Lottie.asset(
        'assets/animations/praying_hands_advanced.json',
        width: size,
        height: size,
        repeat: true,
        fit: BoxFit.contain,
        options: LottieOptions(
          enableMergePaths: true,
        ),
      ),
    );
  }
}

