import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/routes/app_pages.dart';
import 'package:fruitsofspirit/services/iap_service.dart';

/// Payment gate: DB check first — already paid → enable everywhere, no payment screen.
class PaymentGate {
  static Future<bool> checkPremiumAccess() async {
    final iap = Get.find<IAPService>();
    return iap.ensurePremiumFromDatabase();
  }

  static Future<void> verifyPremiumStatus() async {
    final iap = Get.find<IAPService>();
    await iap.ensurePremiumFromDatabase();
  }

  /// Returns true if user may access. If not paid, opens payment screen.
  static Future<bool> checkAndNavigate() async {
    final iap = Get.find<IAPService>();
    if (await iap.ensurePremiumFromDatabase()) return true;
    Get.toNamed(Routes.PAYMENT);
    return false;
  }

  static Future<bool> hasPaid() async {
    final iap = Get.find<IAPService>();
    return iap.ensurePremiumFromDatabase();
  }

  static Future<void> navigateToFeature(String route, {dynamic arguments}) async {
    try {
      final iap = Get.find<IAPService>();
      if (!await iap.ensurePremiumFromDatabase()) {
        Get.toNamed(Routes.PAYMENT);
        return;
      }
      if (arguments != null) {
        Get.toNamed(route, arguments: arguments);
      } else {
        Get.toNamed(route);
      }
    } catch (e) {
      debugPrint('PaymentGate.navigateToFeature error: $e');
      Get.toNamed(Routes.PAYMENT);
    }
  }
}
