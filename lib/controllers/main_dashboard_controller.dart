import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/controllers/prayers_controller.dart';
import 'package:fruitsofspirit/controllers/gallery_controller.dart';
import 'package:fruitsofspirit/controllers/videos_controller.dart';
import 'package:fruitsofspirit/routes/app_pages.dart';
import 'package:fruitsofspirit/services/intro_service.dart';
import 'package:fruitsofspirit/services/iap_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MainDashboardController extends GetxController {
  var currentIndex = 0.obs;
  var showIntroVideo = true.obs;

  @override
  void onInit() {
    super.onInit();
    _loadIntroVideoPreference();
  }

  Future<void> _loadIntroVideoPreference() async {
    await IntroService.init();
    showIntroVideo.value = IntroService.shouldShowIntroOverlay();
    debugPrint('MainDashboardController: showIntroVideo after loading preference: ${showIntroVideo.value}');
  }

  void hideIntroVideo() {
    showIntroVideo.value = false;
  }

  // 🔴 YEH FUNCTION IMPORTANT HAI - ISME PREMIUM CHECK HAI
  Future<void> changeIndex(int index) async {  // <-- async add karo
    if (currentIndex.value == index) return;

    // 🔴 PREMIUM CHECK - YEH LINES ADD KARO
    if (index == 1 || index == 2 || index == 3 || index == 4) {
      final ok = await Get.find<IAPService>().hasPremium();
      if (!ok) {
        Get.toNamed(Routes.PAYMENT);
        return;
      }
    }

    // Special logic for certain tabs
    if (index == 2) {
      // Prayer Requests
      try {
        if (Get.isRegistered<PrayersController>()) {
          final prayersController = Get.find<PrayersController>();
          prayersController.filterUserId.value = 0;
          prayersController.loadPrayers(refresh: true);
        }
      } catch (e) {
        print('Error resetting prayers filter: $e');
      }
    } else if (index == 3) {
      // Videos
      try {
        if (Get.isRegistered<VideosController>()) {
          final videosController = Get.find<VideosController>();
          videosController.loadVideos(refresh: true, includePending: true);
        }
      } catch (e) {
        print('Error refreshing videos: $e');
      }
    } else if (index == 4) {
      // Gallery
      try {
        if (Get.isRegistered<GalleryController>()) {
          final galleryController = Get.find<GalleryController>();
          galleryController.filterUserId.value = 0;
          galleryController.loadPhotos(refresh: true);
        }
      } catch (e) {
        print('Error resetting gallery filter: $e');
      }
    }

    currentIndex.value = index;
  }
}