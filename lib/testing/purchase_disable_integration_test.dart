import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fruitsofspirit/services/iap_service.dart';
import 'package:fruitsofspirit/utils/purchase_admin_util.dart';

void main() {
  group('Purchase Disable Integration Tests', () {
    setUp(() async {
      // Initialize GetX
      Get.testMode = true;
      
      // Mock SharedPreferences
      SharedPreferences.setMockInitialValues({});
      
      // Initialize IAPService
      final iapService = IAPService();
      Get.put(iapService);
    });

    tearDown(() {
      Get.reset();
    });

    test('should disable purchases temporarily', () async {
      final iapService = Get.find<IAPService>();
      
      // Initially purchases should be enabled
      expect(iapService.purchasesDisabled.value, false);
      
      // Disable purchases for 1 hour
      await iapService.disablePurchasesTemporarily(
        duration: const Duration(hours: 1),
        reason: 'Test disable',
      );
      
      // Now purchases should be disabled
      expect(iapService.purchasesDisabled.value, true);
      expect(iapService.disableReason.value, 'Test disable');
    });

    test('should enable purchases immediately', () async {
      final iapService = Get.find<IAPService>();
      
      // First disable purchases
      await iapService.disablePurchasesTemporarily(
        duration: const Duration(hours: 1),
        reason: 'Test disable',
      );
      
      expect(iapService.purchasesDisabled.value, true);
      
      // Enable purchases immediately
      await iapService.enablePurchases();
      
      // Now purchases should be enabled
      expect(iapService.purchasesDisabled.value, false);
      expect(iapService.disableReason.value, '');
    });

    test('purchasePackage should return false when purchases are disabled', () async {
      final iapService = Get.find<IAPService>();
      
      // Disable purchases
      await iapService.disablePurchasesTemporarily(
        duration: const Duration(hours: 1),
        reason: 'Test disable',
      );
      
      // Try to purchase - should fail due to disable
      final result = await iapService.purchasePackage(1);
      
      expect(result, false);
      expect(iapService.errorMessage.value, contains('temporarily disabled'));
    });

    test('PurchaseAdminUtil should check status correctly', () {
      final iapService = Get.find<IAPService>();
      
      // Initially should be false
      expect(PurchaseAdminUtil.arePurchasesDisabled, false);
      expect(PurchaseAdminUtil.disableReason, '');
      
      // Disable purchases
      iapService.purchasesDisabled.value = true;
      iapService.disableReason.value = 'Test reason';
      
      // Now should be true
      expect(PurchaseAdminUtil.arePurchasesDisabled, true);
      expect(PurchaseAdminUtil.disableReason, 'Test reason');
    });

    test('emergency methods should work', () async {
      final iapService = Get.find<IAPService>();
      
      // Test emergency disable
      await PurchaseAdminUtil.emergencyDisablePurchases();
      expect(iapService.purchasesDisabled.value, true);
      
      // Test emergency enable
      await PurchaseAdminUtil.emergencyEnablePurchases();
      expect(iapService.purchasesDisabled.value, false);
    });
  });
}
