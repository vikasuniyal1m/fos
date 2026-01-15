import 'package:flutter/material.dart';
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
    return Obx(() {
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
                      FruitsScreen(),
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
    });
  }
}
