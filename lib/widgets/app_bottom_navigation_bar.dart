import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:fruitsofspirit/routes/routes.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';
import 'package:fruitsofspirit/utils/localization_helper.dart';
import 'package:fruitsofspirit/config/image_config.dart';
import 'package:fruitsofspirit/widgets/cached_image.dart';
import 'package:fruitsofspirit/controllers/prayers_controller.dart';
import 'package:fruitsofspirit/controllers/gallery_controller.dart';

/// Animated Praying Hands Icon
class AnimatedPrayingHands extends StatefulWidget {
  final double size;
  final Color color;
  final bool isActive;

  const AnimatedPrayingHands({
    Key? key,
    required this.size,
    required this.color,
    this.isActive = false,
  }) : super(key: key);

  @override
  State<AnimatedPrayingHands> createState() => _AnimatedPrayingHandsState();
}

class _AnimatedPrayingHandsState extends State<AnimatedPrayingHands>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _rotationAnimation = Tween<double>(begin: -0.05, end: 0.05).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.isActive ? _scaleAnimation.value : 1.0,
          child: Transform.rotate(
            angle: widget.isActive ? _rotationAnimation.value : 0.0,
            child: Container(
              padding: EdgeInsets.all(widget.size * 0.18),
              decoration: BoxDecoration(
                color: widget.isActive 
                    ? const Color(0xFFFEECE2)
                    : const Color(0xFFFEECE2).withOpacity(0.6),
                shape: BoxShape.circle,
                border: widget.isActive
                    ? Border.all(
                        color: widget.color,
                        width: widget.size * 0.06,
                      )
                    : null,
                boxShadow: widget.isActive
                    ? [
                        BoxShadow(
                          color: widget.color.withOpacity(0.3),
                          blurRadius: widget.size * 0.2,
                          spreadRadius: widget.size * 0.05,
                        ),
                      ]
                    : null,
              ),
              child: SizedBox(
                width: widget.size * 0.75,
                height: widget.size * 0.75,
                child: Lottie.asset(
                  'assets/animations/praying_hands_advanced.json',
                  width: widget.size * 0.75,
                  height: widget.size * 0.75,
                  repeat: true,
                  fit: BoxFit.contain,
                  options: LottieOptions(
                    enableMergePaths: true,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Reusable Bottom Navigation Bar Widget
/// Use this widget across all screens for consistent navigation
class AppBottomNavigationBar extends StatelessWidget {
  final int currentIndex;

  const AppBottomNavigationBar({
    Key? key,
    required this.currentIndex,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Calculate responsive sizes based on screen width
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Calculate icon sizes - bigger sizes
    double iconSize;
    double activeIconSize;
    
    if (ResponsiveHelper.isMobile(context)) {
      // Mobile: 36-40px (little bit smaller)
      iconSize = 37.0;
      activeIconSize = 40.0;
    } else if (ResponsiveHelper.isTablet(context)) {
      // Tablet: 40-44px (little bit smaller)
      iconSize = 40.0;
      activeIconSize = 44.0;
    } else {
      // Desktop: 44-48px (little bit smaller)
      iconSize = 44.0;
      activeIconSize = 48.0;
    }
    
    final themeColor = const Color(0xFF8B4513);
    
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              spreadRadius: 0,
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: themeColor,
          unselectedItemColor: Colors.grey[600],
          currentIndex: currentIndex,
          elevation: 0,
          iconSize: iconSize,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          onTap: (index) {
            _handleNavigation(context, index);
          },
          items: [
            BottomNavigationBarItem(
              icon: SizedBox(
                width: iconSize,
                height: iconSize,
                child: Image.asset(
                  'assets/home.png',
                  width: iconSize,
                  height: iconSize,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.home,
                      size: iconSize,
                      color: Colors.grey[600],
                    );
                  },
                ),
              ),
              activeIcon: SizedBox(
                width: activeIconSize,
                height: activeIconSize,
                child: Image.asset(
                  'assets/home.png',
                  width: activeIconSize,
                  height: activeIconSize,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.home,
                      size: activeIconSize,
                      color: themeColor,
                    );
                  },
                ),
              ),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: SizedBox(
                width: iconSize,
                height: iconSize,
                child: Image.asset(
                  'assets/happy.png',
                  width: iconSize,
                  height: iconSize,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.apple,
                      size: iconSize,
                      color: Colors.grey[600],
                    );
                  },
                ),
              ),
              activeIcon: SizedBox(
                width: activeIconSize,
                height: activeIconSize,
                child: Image.asset(
                  'assets/happy.png',
                  width: activeIconSize,
                  height: activeIconSize,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.apple,
                      size: activeIconSize,
                      color: themeColor,
                    );
                  },
                ),
              ),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: SizedBox(
                width: iconSize,
                height: iconSize,
                child: Image.asset(
                  'assets/prayer.png',
                  width: iconSize,
                  height: iconSize,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.volunteer_activism_rounded,
                      size: iconSize,
                      color: Colors.grey[600],
                    );
                  },
                ),
              ),
              activeIcon: SizedBox(
                width: activeIconSize,
                height: activeIconSize,
                child: Image.asset(
                  'assets/prayer.png',
                  width: activeIconSize,
                  height: activeIconSize,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.volunteer_activism_rounded,
                      size: activeIconSize,
                      color: themeColor,
                    );
                  },
                ),
              ),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: SizedBox(
                width: iconSize,
                height: iconSize,
                child: Image.asset(
                  'assets/video.png',
                  width: iconSize,
                  height: iconSize,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.play_circle_outline,
                      size: iconSize,
                      color: Colors.grey[600],
                    );
                  },
                ),
              ),
              activeIcon: SizedBox(
                width: activeIconSize,
                height: activeIconSize,
                child: Image.asset(
                  'assets/video.png',
                  width: activeIconSize,
                  height: activeIconSize,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.play_circle_outline,
                      size: activeIconSize,
                      color: themeColor,
                    );
                  },
                ),
              ),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: SizedBox(
                width: iconSize,
                height: iconSize,
                child: Image.asset(
                  'assets/gallery.png',
                  width: iconSize,
                  height: iconSize,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.photo_library,
                      size: iconSize,
                      color: Colors.grey[600],
                    );
                  },
                ),
              ),
              activeIcon: SizedBox(
                width: activeIconSize,
                height: activeIconSize,
                child: Image.asset(
                  'assets/gallery.png',
                  width: activeIconSize,
                  height: activeIconSize,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.photo_library,
                      size: activeIconSize,
                      color: themeColor,
                    );
                  },
                ),
              ),
              label: '',
            ),
          ],
        ),
      ),
    );
  }

  void _handleNavigation(BuildContext context, int index) {
    // Don't navigate if already on the same screen
    if (index == currentIndex) {
      return;
    }

    switch (index) {
      case 0:
        // Home
        Get.offAllNamed(Routes.HOME);
        break;
      case 1:
        // Fruits
        Get.toNamed(Routes.FRUITS);
        break;
      case 2:
        // Prayer Requests (center button)
        // Reset filter to show all users' prayers
        try {
          final prayersController = Get.find<PrayersController>();
          prayersController.filterUserId.value = 0;
          prayersController.loadPrayers(refresh: true);
        } catch (e) {
          // Controller not found, will be created fresh
        }
        Get.toNamed(Routes.PRAYER_REQUESTS);
        break;
      case 3:
        // Videos
        Get.toNamed(Routes.VIDEOS);
        break;
      case 4:
        // Gallery
        try {
          final galleryController = Get.find<GalleryController>();
          galleryController.filterUserId.value = 0;
          galleryController.loadPhotos(refresh: true);
        } catch (e) {
          // Controller not found, will be created fresh
        }
        Get.toNamed(Routes.GALLERY);
        break;
    }
  }
}

