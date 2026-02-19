import 'package:get/get.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter/widgets.dart';
import 'package:fruitsofspirit/services/payment_service.dart';

class PaymentController extends GetxController {
  var isLoading = false.obs;
  var errorMessage = ''.obs;

  /// One-time $0.99 payment: create intent, show Stripe sheet, confirm on backend.
  Future<void> pay() async {
    if (isLoading.value) return;
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final result = await PaymentService.createPaymentIntent();
      if (result['already_paid'] == 'true') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pop(Get.context!, true);
        });
        return;
      }
      final clientSecret = result['client_secret']!;
      final paymentIntentId = result['payment_intent_id'] ?? '';

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'FOS Productions',
        ),
      );
      await Stripe.instance.presentPaymentSheet();
      // User completed payment in the sheet
      await PaymentService.confirmPayment(
        paymentIntentId: paymentIntentId,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pop(Get.context!, true);
      });
    } on StripeException catch (e) {
      errorMessage.value = e.error.message ?? 'Payment failed';
    } catch (e) {
      errorMessage.value = e.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading.value = false;
    }
  }
}
