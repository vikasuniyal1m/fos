import 'package:get/get.dart';
import 'package:fruitsofspirit/services/iap_service.dart';

/// Utility class for admin-level purchase management operations
class PurchaseAdminUtil {
  /// Check if purchases are currently disabled
  static bool get arePurchasesDisabled {
    try {
      final iapService = Get.find<IAPService>();
      return iapService.purchasesDisabled.value;
    } catch (e) {
      return false;
    }
  }

  /// Get the current disable reason
  static String get disableReason {
    try {
      final iapService = Get.find<IAPService>();
      return iapService.disableReason.value;
    } catch (e) {
      return '';
    }
  }

  /// Emergency disable purchases (admin override)
  static Future<void> emergencyDisablePurchases({
    String reason = 'Emergency admin disable',
  }) async {
    try {
      final iapService = Get.find<IAPService>();
      await iapService.disablePurchasesTemporarily(
        duration: const Duration(days: 7), // Long duration for emergency
        reason: reason,
      );
    } catch (e) {
      // Silently fail in emergency scenarios
    }
  }

  /// Emergency enable purchases (admin override)
  static Future<void> emergencyEnablePurchases() async {
    try {
      final iapService = Get.find<IAPService>();
      await iapService.enablePurchases();
    } catch (e) {
      // Silently fail in emergency scenarios
    }
  }
}
