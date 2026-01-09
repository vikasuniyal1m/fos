import 'package:flutter/material.dart';
import 'package:fruitsofspirit/routes/app_pages.dart';
import 'package:get/get.dart';
import 'package:flutter_svg/flutter_svg.dart'; // Import flutter_svg
import 'package:fruitsofspirit/utils/responsive_helper.dart'; // Import ResponsiveHelper
import 'package:fruitsofspirit/config/image_config.dart';
import 'package:fruitsofspirit/services/user_storage.dart';


class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isLoading = false;

  final List<Map<String, dynamic>> onboardingData = [
    {
      "image": "assets/images/onboardingfirst.png",
      "title": "FRUIT OF THE SPIRIT",
      "description": "Nourish your Soul , Grow Your spirit",
      "subtitle2": "We Are All Messengers",
      "startColor": 0xFFB0D9E7, // Light blue
      "endColor": 0xFFFFFFFF, // White
    },
      {
        "image": "assets/images/grow.png",
        "title": "Grow in the Word",
        "description": "Deepen your understanding of the Bible with our insightful studies and devotionals.",
        "subtitle2": "Daily devotions, study plans, and prayer guides.",
        "startColor": 0xFFFDF5E6,
        "endColor": 0xFFFFFFFF,
      },
    {
      "image": "assets/images/onboardingthird.png",
      "title": "Explore & Be Inspired",
      "description": "Watch, share, and discover daily inspiration for your spirit",
      "subtitle2": "Bring Hope , Bring Help",
      "startColor": 0xFFFDF5E6, // Light yellowish
      "endColor": 0xFFFFFFFF, // White
    },
    {
      "image": "assets/images/onboardingfourth.png",
      "title": "Live Your Faith , Everyday",
      "description": "Grow in love, joy, peace, and patience—your journey starts now",
      "subtitle2": "Be The Light",
      "startColor": 0xFFFEECE2, // Light peach
      "endColor": 0xFFFFFFFF, // White
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(onboardingData[_currentPage]["startColor"]!),
              Color(onboardingData[_currentPage]["endColor"]!),
            ],
            stops: const [
              0.0,
              0.59,
            ],
          ),
        ),
        child: SafeArea(
          top: true,
          bottom: true,
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (int page) {
                    setState(() {
                      _currentPage = page;
                    });
                  },
                  itemCount: onboardingData.length,
                  itemBuilder: (context, index) => OnboardingContent(
                    image: onboardingData[index]["image"]!,
                    title: onboardingData[index]["title"]!,
                    description: onboardingData[index]["description"]!,
                    subtitle2: onboardingData[index]["subtitle2"]!,
                    startColor: onboardingData[index]["startColor"]!,
                    endColor: onboardingData[index]["endColor"]!,
                  ),
                ),
              ),
              Padding(
                padding: ResponsiveHelper.safePadding(context, horizontal: 20, vertical: 10), // Use responsive padding
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _currentPage != 0
                        ? TextButton(
                            onPressed: () {
                              _pageController.previousPage(
                                duration: Duration(milliseconds: 300),
                                curve: Curves.ease,
                              );
                            },
                            child: Text("Prev", style: ResponsiveHelper.textStyle(context, fontSize: 60, color: Color(0xFFC79211))), // Responsive font size and updated color
                          )
                        : SizedBox(width: ResponsiveHelper.spacing(context, 50)), // Responsive width
                    Row(
                      children: List.generate(
                        onboardingData.length,
                        (index) => buildDot(index: index),
                      ),
                    ),
                    _currentPage != onboardingData.length - 1
                        ? TextButton(
                            onPressed: () {
                              _pageController.nextPage(
                                duration: Duration(milliseconds: 300),
                                curve: Curves.ease,
                              );
                            },
                            child: Text("Next", style: ResponsiveHelper.textStyle(context, fontSize: 60, color: Color(0xFFC79211))), // Responsive font size and updated color
                          )
                        : ElevatedButton(
                            onPressed: _isLoading ? null : () async {
                              setState(() {
                                _isLoading = true;
                              });
                              // Mark onboarding as seen
                              await UserStorage.setOnboardingSeen();
                              debugPrint('✅ Onboarding marked as seen, navigating to LOGIN');
                              // Small delay to show loading, then navigate
                              await Future.delayed(const Duration(milliseconds: 500));
                              if (mounted) {
                                setState(() {
                                  _isLoading = false;
                                });
                                Get.offAllNamed(Routes.LOGIN); // Navigate to Login screen
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isLoading ? Colors.grey : Color(0xFFC79211), // Button background color
                              foregroundColor: Colors.white, // Text color
                            ),
                            child: _isLoading
                                ? SizedBox(
                                    height: ResponsiveHelper.iconSize(context, mobile: 20),
                                    width: ResponsiveHelper.iconSize(context, mobile: 20),
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Text("Get Started", style: ResponsiveHelper.textStyle(context, fontSize: 60)), // Responsive font size
                          ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  AnimatedContainer buildDot({int? index}) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 200),
      margin: EdgeInsets.only(right: ResponsiveHelper.spacing(context, 5)), // Responsive margin
      height: ResponsiveHelper.spacing(context, 6), // Responsive height
      width: _currentPage == index ? ResponsiveHelper.spacing(context, 20) : ResponsiveHelper.spacing(context, 6), // Responsive width
      decoration: BoxDecoration(
        color: _currentPage == index ? Colors.orange : Color(0xFFD8D8D8),
        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 3)), // Responsive border radius
      ),
    );
  }
}

class OnboardingContent extends StatelessWidget {
  const OnboardingContent({
    Key? key,
    required this.image,
    required this.title,
    required this.description,
    required this.subtitle2,
    required this.startColor,
    required this.endColor,
  }) : super(key: key);

  final String image, title, description, subtitle2;
  final int startColor, endColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Spacer(),
        Image.asset(
          image,
          errorBuilder: (context, error, stackTrace) {
            // Fallback to network image if asset fails
            return Image.network(
              ImageConfig.assetPathToNetworkUrl(image),
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.image,
                  size: ResponsiveHelper.iconSize(context, mobile: 100),
                  color: Colors.grey,
                );
              },
            );
          },
        ),
        const Spacer(),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: ResponsiveHelper.fontSize(context, mobile: 100), // Responsive font size
            fontWeight: FontWeight.bold,
            color: const Color(0xFFC79211), // Updated color
          ),
        ),
        SizedBox(height: ResponsiveHelper.spacing(context, 20)), // Responsive spacing
        Text(
          description,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: ResponsiveHelper.fontSize(context, mobile: 60), // Responsive font size
            color: Colors.grey,
          ),
        ),
        SizedBox(height: ResponsiveHelper.spacing(context, 20)), // Responsive spacing
        Text(
          subtitle2,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: ResponsiveHelper.fontSize(context, mobile: 60), // Responsive font size
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const Spacer(flex: 2),
      ],
    );
  }
}