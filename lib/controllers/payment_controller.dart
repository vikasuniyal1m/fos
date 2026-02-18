import 'package:get/get.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
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
        Get.back(result: true);
        return;
      }
      final clientSecret = result['client_secret']!;
      final paymentIntentId = result['payment_intent_id'] ?? '';

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Fruits of the Spirit',
        ),
      );
      await Stripe.instance.presentPaymentSheet();
      // User completed payment in the sheet
      await PaymentService.confirmPayment(
        paymentIntentId: paymentIntentId,
      );
      Get.back(result: true);
    } on StripeException catch (e) {
      errorMessage.value = e.error.message ?? 'Payment failed';
    } catch (e) {
      errorMessage.value = e.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading.value = false;
    }
  }
}
