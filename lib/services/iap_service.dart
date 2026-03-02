import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fruitsofspirit/config/api_config.dart';

class IAPService extends GetxService {
  final InAppPurchase _iap = InAppPurchase.instance;
  final RxList<ProductDetails> products = <ProductDetails>[].obs;
  final RxBool isInitialized = false.obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxBool debugMode = true.obs;
  final RxBool premiumActive = false.obs;
  final RxString testStatus = ''.obs;
  final RxBool productsFromStore = false.obs;
  final RxString lastVerifyStatus = ''.obs;
  final RxString lastVerifyBody = ''.obs;
  final RxString lastErrorCode = ''.obs;
  final RxString lastErrorReason = ''.obs;

  static const Set<String> _productIds = {'com.fruitsofspirit.ios.premium'};
  Stream<List<PurchaseDetails>>? _subscription;

  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  void _log(String message) {
    if (debugMode.value) {
      print('🔍 IAP Debug: $message');
    }
  }

  @override
  void onInit() {
    super.onInit();
    // debugMode.value = !kReleaseMode;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _delayedInitialize();
    });
  }

  Future<void> _delayedInitialize() async {
    await Future.delayed(Duration(seconds: 1));
    await initialize();
  }

  Future<void> initialize() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      _log('Checking IAP availability...');
      final available = await _iap.isAvailable();

      if (!available) {
        errorMessage.value = 'Store not available – using test mode';
        _log('❌ IAP not available – enabling local test product');
        _createLocalTestProducts();
        // Load current premium status
        try {
          final prefs = await SharedPreferences.getInstance();
          premiumActive.value = prefs.getBool('is_lifetime_premium') ?? false;
        } catch (_) {}
        isInitialized.value = true;
        return;
      }

      _log('✅ IAP is available, setting up purchase stream...');
      _setupPurchaseStream();

      _log('Loading products with IDs: $_productIds');
      await loadProducts();

      // Load current premium status
      try {
        final prefs = await SharedPreferences.getInstance();
        premiumActive.value = prefs.getBool('is_lifetime_premium') ?? false;
      } catch (_) {}
      isInitialized.value = true;
      _log('✅ IAP Service initialized successfully');
    } catch (e) {
      errorMessage.value = 'Failed to initialize: $e';
      _log('❌ Error initializing IAP: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void _setupPurchaseStream() {
    _subscription ??= _iap.purchaseStream;
    _subscription!.listen(
      _handlePurchases,
      onDone: () {
        _log('Purchase stream completed');
      },
      onError: (error) {
        _log('❌ Purchase stream error: $error');
        Future.delayed(const Duration(seconds: 3), () {
          _setupPurchaseStream();
        });
      },
    );
  }

  // 🔴 YEH FUNCTION IMPORTANT HAI - LOAD PRODUCTS
  Future<void> loadProducts() async {
    try {
      _log('Loading products with IDs: $_productIds');

      final response = await _iap.queryProductDetails(_productIds);

      _log('Response productDetails length: ${response.productDetails.length}');
      _log('Response error: ${response.error}');  // 🔴 YEH ADD KARO

      if (response.error != null) {
        errorMessage.value = 'Store error: ${response.error!.message} (${response.error!.code})';
        _log('Store error: ${response.error}');
        _log('⚠️ Using local test products');
        _createLocalTestProducts();
        return;
      }

      if (response.productDetails.isEmpty) {
        errorMessage.value = 'No products found for: $_productIds';
        _log('No products from store, using local test products');
        _createLocalTestProducts();
      } else {
        products.assignAll(response.productDetails);
        _log('✅ Loaded ${products.length} products from store');
      }
    } catch (e) {
      _log('Error loading products: $e');
      _createLocalTestProducts();
    }
  }

  // 🔴 LOCAL TEST PRODUCT BANANE KE LIYE
  void _createLocalTestProducts() {
    final dummyProduct = ProductDetails(
      id: 'com.fruitsofspirit.ios.premium',
      title: 'Lifetime Premium',
      description: 'Full access to all premium features',
      price: '\$ 0.99',
      rawPrice: 0.99,
      currencyCode: 'USD',
    );

    products.assignAll([dummyProduct]);
    productsFromStore.value = false;
    _log('✅ Created local test product');
  }

  // 🔴 YEH FUNCTION IMPORTANT HAI - PURCHASE KARNE KE LIYE
  Future<bool> purchaseLifetime() async {
    try {
      _log('Starting purchase process...');

      if (!isInitialized.value) {
        await initialize();
      }

      if (products.isEmpty) {
        await loadProducts();
      }

      final product = products.firstWhereOrNull(
              (p) => p.id == 'com.fruitsofspirit.ios.premium'
      );

      if (product == null) {
        errorMessage.value = 'Product not available';
        _log('❌ Product not found');
        return false;
      }

      _log('Product selected: id=${product.id}, price=${product.price}, raw=${product.rawPrice}, currency=${product.currencyCode}');
      isLoading.value = true;

      // Real purchase when StoreKit is available AND products are from store
      final available = await _iap.isAvailable();
      if (available && productsFromStore.value) {
        _log('🟢 Initiating real purchase');
        final purchaseParam = PurchaseParam(productDetails: product);
        await _iap.buyNonConsumable(purchaseParam: purchaseParam);
        // Completion handled by _handlePurchases → _verifyOnBackend
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('iap_last_mode', 'real');
        await prefs.setString('iap_last_product_id', product.id);
        return true;
      } else if (debugMode.value) {
        // Simulated purchase only in debug/test mode
        _log('🧪 Simulating purchase (debug/test mode)');
        await Future.delayed(Duration(seconds: 1));
        await _savePremiumStatus(true);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('iap_last_mode', 'sim');
        await prefs.setString('iap_last_product_id', product.id);
        await prefs.setString('iap_last_tx', 'SIM-${DateTime.now().millisecondsSinceEpoch}');
        return true;
      } else {
        // In release/TestFlight, do not simulate; surface error
        errorMessage.value = 'Store unavailable. Please try again later';
        _log('❌ Store unavailable; skipping simulation in release');
        return false;
      }

    } on PlatformException catch (e) {
      errorMessage.value = 'Purchase failed: ${e.code} ${e.message ?? ''}'.trim();
      lastErrorCode.value = e.code;
      lastErrorReason.value = e.message ?? '';
      _log('❌ Platform error: ${errorMessage.value}');
      return false;
    } catch (e) {
      errorMessage.value = 'Purchase failed: $e';
      _log('❌ Error: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  void _handlePurchases(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      _log('Purchase update: product=${purchase.productID}, status=${purchase.status}, id=${purchase.purchaseID}');
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _verifyOnBackend(purchase);
          break;
        case PurchaseStatus.error:
          errorMessage.value = 'Purchase error';
          final err = purchase.error;
          if (err != null) {
            lastErrorCode.value = err.code;
            lastErrorReason.value = err.message;
            _log('❌ Purchase error code=${err.code} reason=${err.message}');
          }
          _log('❌ Purchase error event received');
          break;
        default:
          break;
      }

      if (purchase.pendingCompletePurchase) {
        _iap.completePurchase(purchase);
        _log('Completed pending purchase for ${purchase.productID}');
      }
    }
  }

  Future<void> _verifyOnBackend(PurchaseDetails purchase) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id')?.toString() ?? '';

      if (userId.isEmpty) {
        await _storePendingPurchase(purchase);
        return;
      }

      final url = Uri.parse('${ApiConfig.baseUrl}/verify-iap.php');
      final payload = <String, dynamic>{
        'platform': Platform.isAndroid ? 'google' : 'apple',
        'product_id': purchase.productID,
        'transaction_id': purchase.purchaseID,
        'user_id': userId,
      };
      if (Platform.isAndroid) {
        payload['purchase_token'] = purchase.verificationData.serverVerificationData;
      } else {
        payload['receipt'] = purchase.verificationData.localVerificationData;
      }
      final txTail = (purchase.purchaseID ?? '').toString();
      final txSafe = txTail.length > 8 ? txTail.substring(txTail.length - 8) : txTail;
      _log('Verifying on backend: platform=${payload['platform']}, product=${payload['product_id']}, tx=*${txSafe}');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      final maskedPayload = {
        'platform': payload['platform'],
        'product_id': payload['product_id'],
        'user_id': payload['user_id'],
        'tx_tail': txSafe,
        'has_receipt': payload.containsKey('receipt'),
        'has_purchase_token': payload.containsKey('purchase_token'),
      };
      if (response.statusCode != 200) {
        print('🔴 IAP verify failed: code=${response.statusCode}');
        print('🔴 IAP verify endpoint: $url');
        print('🔴 IAP verify payload: ${json.encode(maskedPayload)}');
        print('🔴 IAP verify response body: ${response.body}');
      } else {
        _log('IAP verify success: code=${response.statusCode}');
        _log('IAP verify endpoint: $url');
        _log('IAP verify payload: ${json.encode(maskedPayload)}');
        _log('IAP verify response body len=${response.body.length}');
      }
      lastVerifyStatus.value = response.statusCode.toString();
      lastVerifyBody.value = response.body;
      _log('Backend response code=${response.statusCode}, len=${response.body.length}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['valid'] == true) {
          await _savePremiumStatus(true);
          await _clearPendingPurchase();
          _log('✅ Backend verification success for product=${purchase.productID}');
          final prefs = await SharedPreferences.getInstance();
          final txTail = (purchase.purchaseID ?? '').toString();
          await prefs.setString('iap_last_mode', 'real');
          await prefs.setString('iap_last_product_id', purchase.productID);
          await prefs.setString('iap_last_tx', txTail);
        } else {
          errorMessage.value = 'Verification failed';
          _log('❌ Backend verification returned invalid');
        }
      } else {
        errorMessage.value = 'Backend verify failed: ${response.statusCode}';
        _log('❌ Backend HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      await _storePendingPurchase(purchase);
      _log('❌ Backend verification exception: $e');
    }
  }

  Future<void> runSelfTest() async {
    if (isLoading.value) return;
    errorMessage.value = '';
    testStatus.value = '';
    final ok = await purchaseLifetime();
    final when = DateTime.now().toIso8601String();
    if (ok) {
      testStatus.value = 'PASS $when';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('iap_test_last_pass', when);
    } else {
      testStatus.value = 'FAIL $when';
    }
  }

  Future<Map<String, String>> getLastIapInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString('iap_last_mode') ?? '';
    final pid = prefs.getString('iap_last_product_id') ?? '';
    final tx = prefs.getString('iap_last_tx') ?? '';
    final pass = prefs.getString('iap_test_last_pass') ?? '';
    return {
      'mode': mode,
      'product': pid,
      'tx': tx,
      'last_pass': pass,
    };
  }

  Future<void> _storePendingPurchase(PurchaseDetails purchase) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_purchase', json.encode({
      'product_id': purchase.productID,
      'transaction_id': purchase.purchaseID,
      'timestamp': DateTime.now().toIso8601String(),
    }));
  }

  Future<void> _clearPendingPurchase() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pending_purchase');
  }

  Future<void> _savePremiumStatus(bool isPremium) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_lifetime_premium', isPremium);
    premiumActive.value = isPremium;
    _log('✅ Premium status saved: $isPremium');
  }

  Future<bool> hasPremium() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_lifetime_premium') ?? false;
  }

  Future<bool> restorePurchases() async {
    try {
      isLoading.value = true;
      await _iap.restorePurchases();
      return true;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('No active account')) {
        errorMessage.value = 'Sign in with Sandbox App Store account to restore purchases';
      } else if (msg.contains('timed out') || msg.contains('Connection')) {
        errorMessage.value = 'Network issue during restore. Check internet and try again';
      } else {
        errorMessage.value = 'Restore failed: $msg';
      }
      return false;
    } finally {
      isLoading.value = false;
    }
  }
}
