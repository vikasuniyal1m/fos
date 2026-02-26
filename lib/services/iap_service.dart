import 'dart:convert';
import 'package:get/get.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fruitsofspirit/config/api_config.dart';

class IAPService extends GetxService {
  final InAppPurchase _iap = InAppPurchase.instance;
  final RxList<ProductDetails> products = <ProductDetails>[].obs;
  static const Set<String> _productIds = {'com.fruitsofspirit.ios.lifetime'};
  Stream<List<PurchaseDetails>>? _subscription;

  Future<void> initialize() async {
    final available = await _iap.isAvailable();
    if (!available) return;
    _subscription ??= _iap.purchaseStream;
    _subscription!.listen(_handlePurchases, onDone: () {}, onError: (_) {});
    await loadProducts();
  }

  Future<void> loadProducts() async {
    final response = await _iap.queryProductDetails(_productIds);
    if (response.error != null) return;
    products.assignAll(response.productDetails);
  }

  Future<void> purchaseLifetime() async {
    final product = products.firstWhere((p) => p.id == 'com.fruitsofspirit.ios.lifetime', orElse: () => throw Exception('Lifetime product not found'));
    final purchaseParam = PurchaseParam(productDetails: product);
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  void _handlePurchases(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased || purchase.status == PurchaseStatus.restored) {
        _verifyOnBackend(purchase);
      }
      if (purchase.pendingCompletePurchase) {
        _iap.completePurchase(purchase);
      }
    }
  }

  Future<void> _verifyOnBackend(PurchaseDetails purchase) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id')?.toString() ?? '';
      final url = Uri.parse('${ApiConfig.baseUrl}/verify-iap.php');
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'platform': 'apple',
          'product_id': purchase.productID,
          'transaction_id': purchase.purchaseID,
          'receipt': purchase.verificationData.localVerificationData,
          'user_id': userId,
        }),
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        if (data['valid'] == true) {
          await _savePremiumStatus(true);
        }
      }
    } catch (_) {}
  }

  Future<void> _savePremiumStatus(bool isPremium) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_lifetime_premium', isPremium);
  }

  Future<bool> hasPremium() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_lifetime_premium') ?? false;
  }

  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }
}
