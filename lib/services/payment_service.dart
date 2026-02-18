import 'package:fruitsofspirit/config/api_config.dart';
import 'package:fruitsofspirit/services/api_service.dart';
import 'package:fruitsofspirit/services/user_storage.dart';

/// Service for the one-time $0.99 payment (check status, create intent, confirm).
class PaymentService {
  /// Check if the current user has already paid.
  /// Only returns true when API explicitly returns success: true AND has_paid: true.
  static Future<bool> hasUserPaid() async {
    final userId = await UserStorage.getUserId();
    if (userId == null) return false;
    try {
      final res = await ApiService.get(
        ApiConfig.paymentCheckStatus,
        queryParameters: {'user_id': userId.toString()},
      );
      // Be strict: only "paid" when API says success and has_paid is explicitly true
      final ok = res['success'] == true;
      final data = res['data'] ?? res;
      final hasPaid = data['has_paid'] == true; // use == true so 1 or "true" string doesn't count unless we want
      return ok && hasPaid;
    } catch (_) {
      return false;
    }
  }

  /// Create a Stripe Payment Intent for $0.99. Returns client_secret and payment_intent_id.
  static Future<Map<String, String>> createPaymentIntent() async {
    final userId = await UserStorage.getUserId();
    if (userId == null) throw Exception('User not logged in');
    final res = await ApiService.post(
      ApiConfig.paymentCreateIntent,
      body: {'user_id': userId.toString()},
    );
    if (res['success'] != true) {
      throw Exception(res['message'] ?? 'Failed to create payment intent');
    }
    if (res['already_paid'] == true) {
      return {'already_paid': 'true'};
    }
    final clientSecret = res['client_secret'] as String?;
    final intentId = res['payment_intent_id'] as String?;
    if (clientSecret == null || clientSecret.isEmpty) {
      throw Exception('No client_secret returned');
    }
    return {
      'client_secret': clientSecret,
      'payment_intent_id': intentId ?? '',
    };
  }

  /// Confirm payment after Stripe has succeeded (e.g. from Flutter).
  static Future<String> confirmPayment({
    required String paymentIntentId,
    String? transactionId,
  }) async {
    final userId = await UserStorage.getUserId();
    if (userId == null) throw Exception('User not logged in');
    final body = <String, String>{
      'user_id': userId.toString(),
      'payment_intent_id': paymentIntentId,
    };
    if (transactionId != null && transactionId.isNotEmpty) {
      body['transaction_id'] = transactionId;
    }
    final res = await ApiService.post(ApiConfig.paymentConfirm, body: body);
    if (res['success'] != true) {
      throw Exception(res['message'] ?? 'Failed to confirm payment');
    }
    return (res['transaction_id'] ?? paymentIntentId) as String;
  }
}
