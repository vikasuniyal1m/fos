import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/controllers/prayers_controller.dart';
import 'package:fruitsofspirit/controllers/gallery_controller.dart';
import 'package:fruitsofspirit/controllers/home_controller.dart';
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

  /// Switch tab instantly; sync data silently in background (no full-screen reload).
  Future<void> changeIndex(int index) async {
    if (currentIndex.value == index) return;

    if (index >= 1 && index <= 4) {
      final iap = Get.find<IAPService>();
      if (!await iap.hasPremiumFast()) {
        Get.toNamed(Routes.PAYMENT);
        return;
      }
    }

    currentIndex.value = index;
    unawaited(_backgroundSyncForTab(index));
  }

  Future<void> _backgroundSyncForTab(int index) async {
    try {
      if (index == 2) {
        if (!Get.isRegistered<PrayersController>()) return;
        final prayersController = Get.find<PrayersController>();
        prayersController.filterUserId.value = 0;

        if (Get.isRegistered<HomeController>()) {
          prayersController.seedFromHomeIfEmpty(
            Get.find<HomeController>().prayers.toList(),
          );
        }

        await prayersController.loadPrayers(
          refresh: true,
          silent: prayersController.prayers.isNotEmpty,
        );
      } else if (index == 3) {
        if (!Get.isRegistered<VideosController>()) return;
        final videosController = Get.find<VideosController>();
        videosController.selectedFruitTag.value = '';

        if (Get.isRegistered<HomeController>()) {
          final homeController = Get.find<HomeController>();
          videosController.seedFromHomeIfEmpty(
            homeVideos: homeController.videos.toList(),
            homeLiveVideos: homeController.liveVideos.toList(),
          );
        }

        await videosController.loadVideos(
          refresh: true,
          silent: true,
          includePending: true,
        );
        unawaited(videosController.loadLiveVideos());
      } else if (index == 4) {
        if (!Get.isRegistered<GalleryController>()) return;
        final galleryController = Get.find<GalleryController>();
        galleryController.filterUserId.value = 0;
        galleryController.filterByFruitTag('');

        if (Get.isRegistered<HomeController>()) {
          galleryController.seedFromHomeIfEmpty(
            Get.find<HomeController>().galleryPhotos.toList(),
          );
        }

        await galleryController.loadPhotos(refresh: true, silent: true);
      }
    } catch (e) {
      debugPrint('Tab silent sync error: $e');
    }
  }
}