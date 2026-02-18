import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/controllers/main_dashboard_controller.dart';
import 'package:fruitsofspirit/screens/home_screen.dart';
import 'package:fruitsofspirit/screens/fruits_screen.dart';
import 'package:fruitsofspirit/screens/prayer_requests_screen.dart';
import 'package:fruitsofspirit/screens/videos_screen.dart';
import 'package:fruitsofspirit/screens/gallery_screen.dart';
import 'package:fruitsofspirit/widgets/app_bottom_navigation_bar.dart';

import 'package:fruitsofspirit/screens/temp_video_test_screen.dart';

class MainDashboardScreen extends GetView<MainDashboardController> {
  const MainDashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent default back behavior
      onPopInvoked: (didPop) async {
        if (didPop) return;

        // Show exit confirmation dialog
        final shouldExit = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text(
              'Exit App?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            content: const Text(
              'Do you want to exit the app?',
              style: TextStyle(
                fontSize: 14,
                color: Colors.black,
              ),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(
                  'Exit',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        );

        // If user confirmed exit, exit the app
        if (shouldExit == true) {
          SystemNavigator.pop();
        }
      },
      child: Obx(() {
        return Stack(
          children: [
            Scaffold(
              body: Stack(
                children: [
                  Obx(
                    () => IndexedStack(
                      index: controller.currentIndex.value,
                      children: const [
                        HomeScreen(),
                        FruitsScreen(isRootTab: true),
                        PrayerRequestsScreen(),
                        VideosScreen(),
                        GalleryScreen(),
                      ],
                    ),
                  ),
                ],
              ),
              bottomNavigationBar: AppBottomNavigationBar(
                currentIndex: controller.currentIndex.value,
                onTap: controller.changeIndex,
              ),
            ),
            if (controller.showIntroVideo.value)
              Positioned.fill(
                child: TempVideoTestScreen(
                  onVideoFinished: () {
                    controller.hideIntroVideo();
                  },
                ),
              ),
          ],
        );
      }),
    );
  }
}
