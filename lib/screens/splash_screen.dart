import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/routes/routes.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';
import 'package:fruitsofspirit/services/user_storage.dart';
import 'package:fruitsofspirit/services/data_loading_service.dart';
import 'package:fruitsofspirit/services/intro_service.dart';
import 'package:fruitsofspirit/config/image_config.dart';

import '../utils/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isLoadingData = false;
  String _loadingMessage = 'Loading...';

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Precache splash image (handle errors gracefully)
      precacheImage(const AssetImage('assets/images/fruit_of_spirit.jpg'), context)
          .catchError((error) {
        // Image precaching failed, but app will still work
        debugPrint('Warning: Could not precache splash image: $error');
      });
    });
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      _animationController.forward();

      // Increment launch count
      await IntroService.incrementLaunchCount();
      debugPrint('DEBUG: App launch count = ${IntroService.getLaunchCount()}');

      // Minimum delay to show splash screen and allow user to read scripture
      // Total delay: 1200ms (animation) + 3000ms (reading time) = 4200ms
      await Future.delayed(const Duration(milliseconds: 1200));

      // Additional delay for user to read scripture (3 seconds)
      await Future.delayed(const Duration(seconds: 3));

      if (!mounted) return;

      // Check if user is logged in with timeout to prevent hanging
      final isLoggedIn = await UserStorage.isLoggedIn()
          .timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('⚠️ UserStorage.isLoggedIn() timed out, defaulting to false');
          return false;
        },
      )
          .catchError((error) {
        debugPrint('❌ Error checking login status: $error');
        return false;
      });

      debugPrint('DEBUG: isLoggedIn = $isLoggedIn');

      if (!mounted) return;

      if (isLoggedIn) {
        debugPrint('➡️ Navigating to HOME');
        
        // Check if we have cached data to show instantly
        final hasCache = await DataLoadingService.isHomeDataCached();
        
        if (hasCache) {
          debugPrint('✅ Found cached data, navigating to home immediately');
          // Trigger background refresh but don't wait for it
          DataLoadingService.loadAllHomeData(preferCache: true).catchError((e) {
            debugPrint('⚠️ Background data refresh failed: $e');
          });
          
          if (!mounted) return;
          Get.offAllNamed(Routes.DASHBOARD);
          return;
        }

        // No cache found, show loading message while fetching critical data
        if (mounted) {
          setState(() {
            _isLoadingData = true;
            _loadingMessage = 'Loading your spiritual journey...';
          });
        }

        // Wait for critical home data to load before navigating
        try {
          await DataLoadingService.loadAllHomeData(preferCache: false).timeout(
            const Duration(seconds: 8),
            onTimeout: () {
              debugPrint('⚠️ Data loading timed out, continuing to home');
              return {};
            },
          );
        } catch (e) {
          debugPrint('⚠️ Error pre-loading data: $e');
        }

        if (!mounted) return;
        Get.offAllNamed(Routes.DASHBOARD);
      } else {
        debugPrint('➡️ Navigating to LOGIN');
        Get.offAllNamed(Routes.LOGIN);
      }
    } catch (e) {
      debugPrint('❌ Error in _initializeApp: $e');
      // Fallback: Navigate to login if anything fails
      if (mounted) {
        Get.offAllNamed(Routes.LOGIN);
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = ResponsiveHelper.safeScreenWidth(context);
    final h = ResponsiveHelper.safeScreenHeight(context);

    // Professional responsive sizing for tablets/iPads
    // Mobile: Keep original behavior (don't touch)
    // Tablets: Use max content width and better proportions
    final isTabletDevice = ResponsiveHelper.isTablet(context);
    final isLargeTabletDevice = ResponsiveHelper.isLargeTablet(context);
    // Get max content width for tablets (840px for small tablets, 1200px for large tablets)
    final double maxContentWidth = isTabletDevice
        ? (isLargeTabletDevice ? 1200.0 : 840.0)
        : w;  // Mobile: use full width

    // Calculate image dimensions based on device type
    double imageWidth;
    double containerMaxWidth;
    double containerMaxHeight;
    double containerPadding;

    if (isTabletDevice) {
      // Tablets/iPads: Use larger sizing for better visibility
      if (isLargeTabletDevice) {
        // Large tablets (iPad Pro 12.9"): Bigger image
        imageWidth = (maxContentWidth * 0.75).clamp(600.0, 800.0);  // 75% of max content width
        containerMaxWidth = maxContentWidth * 0.85; // 85% of max content width
        containerMaxHeight = h * 0.7;  // More height
        containerPadding = 40.0;
      } else {
        // Small tablets (iPad Mini, iPad, iPad Air): Bigger image
        imageWidth = (maxContentWidth * 0.8).clamp(500.0, 700.0);  // 80% of max content width
        containerMaxWidth = maxContentWidth * 0.9; // 90% of max content width
        containerMaxHeight = h * 0.65;  // More height
        containerPadding = 32.0;
      }
    } else {
      // Mobile: Keep original behavior (don't touch)
      imageWidth = w * 0.9;
      containerMaxWidth = w * 0.9;
      containerMaxHeight = h * 0.7;
      containerPadding = ResponsiveHelper.spacing(context, 20);
    }

    return Scaffold(
      body: Container(
        color: Colors.white,
        child: SafeArea(
          top: true,
          bottom: true,
          child: ResponsiveHelper.safeScrollable(
            context: context,
            child: Center(
              child: ResponsiveHelper.constrainedContent(
                context: context,
                maxWidth: isTabletDevice ? maxContentWidth : null,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        // Professional padding: More for tablets, original for mobile
                        padding: EdgeInsets.all(containerPadding),
                        // Constraints: Use max content width for tablets
                        constraints: BoxConstraints(
                          maxWidth: containerMaxWidth,
                          maxHeight: containerMaxHeight,
                        ),
                        child: Image.asset(
                          'assets/images/fruit_of_spirit.jpg',
                          width: imageWidth > containerMaxWidth - (containerPadding * 2)
                              ? containerMaxWidth - (containerPadding * 2)
                              : imageWidth,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            // Fallback to old splash image if new one not found
                            return Image.asset(
                              'assets/images/fruit_of_spirit_splash.jpg',
                              width: imageWidth > containerMaxWidth - (containerPadding * 2)
                                  ? containerMaxWidth - (containerPadding * 2)
                                  : imageWidth,
                              fit: BoxFit.contain,
                            );
                          },
                        ),
                      ),
                    ),
                    // ============================================
                    // SCRIPTURE SECTION - John 15:5, 8 (NIV)
                    // To remove/disable: Comment out the entire section below
                    // ============================================
                SizedBox(
                  height: ResponsiveHelper.spacing(context, 4),
                ),

                    Center(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: ResponsiveHelper.spacing(context, 20),
                          vertical: ResponsiveHelper.spacing(context, 16),
                        ),
                        margin: EdgeInsets.symmetric(
                          horizontal: ResponsiveHelper.spacing(context, 16),
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.themeColor,
                          borderRadius: BorderRadius.circular(
                              ResponsiveHelper.borderRadius(context, mobile: 12, tablet: 14)
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'John 15:5, 8 (NIV)',
                              style: ResponsiveHelper.textStyle(
                                context,
                                fontSize: ResponsiveHelper.fontSize(
                                  context,
                                  mobile: 14,
                                  tablet: 16,
                                ),
                                fontWeight: FontWeight.bold,
                                color: AppTheme.iconscolor,
                              ),
                            ),
                            SizedBox(height: ResponsiveHelper.spacing(context, 12)),
                            Text(
                              '"I am the vine; you are the branches. If you remain in me and I in you, you will bear much fruit; apart from me you can do nothing."',
                              style: ResponsiveHelper.textStyle(
                                context,
                                fontSize: ResponsiveHelper.fontSize(
                                  context,
                                  mobile: 13,
                                  tablet: 15,
                                ),
                                color: Colors.black87,
                                height: 1.5,
                              ).copyWith(fontStyle: FontStyle.italic),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: ResponsiveHelper.spacing(context, 12)),
                            Text(
                              '"This is to my Father\'s glory, that you bear much fruit, showing yourselves to be my disciples."',
                              style: ResponsiveHelper.textStyle(
                                context,
                                fontSize: ResponsiveHelper.fontSize(
                                  context,
                                  mobile: 13,
                                  tablet: 15,
                                ),
                                color: Colors.black87,
                                height: 1.5,
                              ).copyWith(fontStyle: FontStyle.italic),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // ============================================
                    // END OF SCRIPTURE SECTION
                    // ============================================
                    if (_isLoadingData) ...[
                      SizedBox(height: ResponsiveHelper.spacing(
                          context,
                          isTabletDevice ? 40 : 30  // More spacing for tablets
                      )),
                      CircularProgressIndicator(
                        color: const Color(0xFF8B4513),
                        strokeWidth: isTabletDevice ? 3.0 : 2.0,  // Thicker for tablets
                      ),
                      SizedBox(height: ResponsiveHelper.spacing(
                          context,
                          isTabletDevice ? 20 : 16  // More spacing for tablets
                      )),
                      Text(
                        _loadingMessage,
                        style: ResponsiveHelper.textStyle(
                          context,
                          fontSize: ResponsiveHelper.fontSize(
                            context,
                            mobile: 16,
                            tablet: 18,  // Larger text for tablets
                          ),
                          color: const Color(0xFF8B4513),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
