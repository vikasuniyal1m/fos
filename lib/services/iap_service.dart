import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
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

  static const Set<String> _productIds = {'com.fruitsofspirit.ios.lifetime'};
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
        errorMessage.value = 'In-app purchases are not available on this device';
        _log('❌ IAP not available');
        isLoading.value = false;
        return;
      }

      _log('✅ IAP is available, setting up purchase stream...');
      _setupPurchaseStream();

      _log('Loading products with IDs: $_productIds');
      await loadProducts();

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

      // Try to load from App Store
      final response = await _iap.queryProductDetails(_productIds);

      if (response.error != null) {
        _log('Store error: ${response.error}');
        // AGAR ERROR AAYE TOH LOCAL PRODUCT BANA DO
        _log('⚠️ Using local test products');
        _createLocalTestProducts();
        return;
      }

      if (response.productDetails.isEmpty) {
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
      id: 'com.fruitsofspirit.ios.lifetime',
      title: 'Lifetime Premium',
      description: 'Full access to all premium features',
      price: '₹ 800',
      rawPrice: 800.0,
      currencyCode: 'INR',
    );

    products.assignAll([dummyProduct]);
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
              (p) => p.id == 'com.fruitsofspirit.ios.lifetime'
      );

      if (product == null) {
        errorMessage.value = 'Product not available';
        _log('❌ Product not found');
        return false;
      }

      isLoading.value = true;

      // 🔴 TEST MODE: Simulate successful purchase
      _log('🧪 TEST MODE: Simulating successful purchase');
      await Future.delayed(Duration(seconds: 2));
      await _savePremiumStatus(true);

      return true;

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
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _verifyOnBackend(purchase);
          break;
        case PurchaseStatus.error:
          errorMessage.value = 'Purchase error';
          break;
        default:
          break;
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

      if (userId.isEmpty) {
        await _storePendingPurchase(purchase);
        return;
      }

      final url = Uri.parse('${ApiConfig.baseUrl}/verify-iap.php');
      final response = await http.post(
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

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['valid'] == true) {
          await _savePremiumStatus(true);
          await _clearPendingPurchase();
        }
      }
    } catch (e) {
      await _storePendingPurchase(purchase);
    }
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
      return false;
    } finally {
      isLoading.value = false;
    }
  }
}