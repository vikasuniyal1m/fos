import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/routes/app_pages.dart';
import 'package:fruitsofspirit/services/iap_service.dart';

/// Payment gate: show payment screen when user tries to use a paid feature.
/// Video dekhna / browse karna free; jab prayer dalen, blog post karen, group me enter karen, live karen, etc. tab payment dikhe.
class PaymentGate {
  /// Returns true if user may access (already paid). If not paid, opens payment screen and returns false.
  static Future<bool> checkAndNavigate() async {
    final iap = Get.find<IAPService>();
    final ok = await iap.hasPremium();
    if (ok) return true;
    Get.toNamed(Routes.PAYMENT);
    return false;
  }

  /// Returns true if user has paid (no navigation).
  static Future<bool> hasPaid() async {
    final iap = Get.find<IAPService>();
    return iap.hasPremium();
  }

  static Future<void> navigateToFeature(String route, {dynamic arguments}) async {
    try {
      final iap = Get.find<IAPService>();
      final ok = await iap.hasPremium();
      if (!ok) {
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
