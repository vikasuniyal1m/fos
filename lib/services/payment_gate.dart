import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/routes/app_pages.dart';
import 'package:fruitsofspirit/services/payment_service.dart';

/// Payment gate: show payment screen when user tries to use a paid feature.
/// Video dekhna / browse karna free; jab prayer dalen, blog post karen, group me enter karen, live karen, etc. tab payment dikhe.
class PaymentGate {
  /// Returns true if user may access (already paid). If not paid, opens payment screen and returns false.
  static Future<bool> checkAndNavigate() async {
    final hasPaid = await PaymentService.hasUserPaid();
    if (hasPaid) return true;
    Get.toNamed(Routes.PAYMENT);
    return false;
  }

  /// Returns true if user has paid (no navigation).
  static Future<bool> hasPaid() => PaymentService.hasUserPaid();

  /// Navigate to [route] only if user has paid. If not paid, opens payment screen and does not navigate.
  /// Use this when user taps Create Prayer, Create Blog, Group enter, Go Live, Create Story, Upload Video/Photo, etc.
  static Future<void> navigateToFeature(String route, {dynamic arguments}) async {
    try {
      final hasPaid = await PaymentService.hasUserPaid();
      if (!hasPaid) {
        Get.toNamed(Routes.PAYMENT);
        return;
      }
      if (arguments != null) {
        Get.toNamed(route, arguments: arguments);
      } else {
        Get.toNamed(route);
      }
    } catch (e, st) {
      // On any error (e.g. network), show payment screen so user can retry
      debugPrint('PaymentGate.navigateToFeature error: $e');
      Get.toNamed(Routes.PAYMENT);
    }
  }
}
