import 'dart:async';

import 'package:get/get.dart';
import 'package:fruitsofspirit/bindings/InitialBinding.dart';
import 'package:fruitsofspirit/controllers/banners_controller.dart';
import 'package:fruitsofspirit/controllers/home_controller.dart';
import 'package:fruitsofspirit/controllers/profile_controller.dart';
import 'package:fruitsofspirit/routes/routes.dart';
import 'package:fruitsofspirit/services/banners_prefetch_service.dart';
import 'package:fruitsofspirit/services/data_loading_service.dart';
import 'package:fruitsofspirit/services/iap_service.dart';
import 'package:fruitsofspirit/services/user_storage.dart';

/// Fast post-auth: navigate instantly, hydrate app in background.
class AuthSessionService {
  /// Save user → dashboard immediately → background data load.
  static Future<void> finishAuthAndGoHome(Map<String, dynamic> user) async {
    await UserStorage.saveUser(user);
    Get.offAllNamed(Routes.DASHBOARD);
    unawaited(reinitializeAfterAuth(user: user));
  }

  /// Background hydrate — never block login button / splash navigation.
  static Future<void> reinitializeAfterAuth({Map<String, dynamic>? user}) async {
    InitialBinding().dependencies();

    if (user != null && Get.isRegistered<IAPService>()) {
      final iap = Get.find<IAPService>();
      unawaited(_syncPremium(iap, user));
    }

    if (Get.isRegistered<BannersController>()) {
      final banners = Get.find<BannersController>();
      banners.bootstrapBanners();
      unawaited(BannersPrefetchService.warmCache());
      unawaited(banners.loadBanners(silent: true));
    }

    if (Get.isRegistered<ProfileController>()) {
      final profile = Get.find<ProfileController>();
      final rawId = user?['id'] ?? user?['user_id'];
      if (rawId != null) {
        profile.userId.value = int.tryParse(rawId.toString()) ?? 0;
      }
      profile.bootstrapProfile();
      unawaited(profile.prepareProfile());
    }

    if (Get.isRegistered<HomeController>()) {
      final home = Get.find<HomeController>();
      if (home.isInitialLoading.value) {
        home.isInitialLoading.value = false;
      }
      unawaited(
        DataLoadingService.loadAllHomeData(preferCache: true).catchError((_) {}),
      );
    }
  }

  static Future<void> _syncPremium(IAPService iap, Map<String, dynamic> user) async {
    try {
      await iap.updatePremiumStatusFromLogin(user);
      // Login payload already has premium flag — full API sync runs on stale timer only.
    } catch (_) {}
  }
}
