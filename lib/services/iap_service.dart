import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fruitsofspirit/config/api_config.dart';
import 'package:fruitsofspirit/services/user_storage.dart';

class IAPService extends GetxService {
  final InAppPurchase _iap = InAppPurchase.instance;
  final RxList<ProductDetails> products = <ProductDetails>[].obs;
  final RxBool isInitialized = false.obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxBool premiumActive = false.obs;
  final RxBool purchasesDisabled = false.obs;
  final RxString disableReason = ''.obs;
  final RxBool isSandbox = false.obs;

  static const String _iosProductId = 'com.fruitsofspirit.ios.fosproductions'; // FOS Productions - $0.99 or Full Version
  static const String _androidProductId = 'com.fruitsofspirit.android.premium'; // Fruit-Full Life Pack
  
  static Set<String> get _productIds => {
    Platform.isIOS ? _iosProductId : _androidProductId
  };

  // Check if running in production mode
  static bool get isProductionMode {
    return !kDebugMode && !kProfileMode;
  }
  
  Stream<List<PurchaseDetails>>? _subscription;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);
  
  // StoreKit retry configuration
  static const int _storeKitMaxRetries = 5;
  static const Duration _storeKitRetryDelay = Duration(seconds: 3);
  
  // Purchase disable functionality
  static const String _purchasesDisabledKey = 'purchases_disabled';
  static const String _disableReasonKey = 'disable_reason';
  static const String _disableUntilKey = 'disable_until';

  @override
  void onInit() {
    super.onInit();
    
    // Add StoreKit debugging before initialization
    debugPrint('IAP: === StoreKit Configuration Debug ===');
    debugPrint('IAP: StoreKit config file path: /ios/FruitsOfSpirit_Products.storekit/Configuration.storekit/Configuration.storekit');
    debugPrint('IAP: Product ID from config: com.fruitsofspirit.ios.fosproductions');
    debugPrint('IAP: Flutter platform: ${Platform.operatingSystem}');
    debugPrint('IAP: iOS version: ${Platform.operatingSystemVersion}');
    debugPrint('IAP: Is physical device: ${!_isSimulatorSync()}');
    debugPrint('IAP: Provisioning profile: FOS_Ad_Hoc_Profile.mobileprovision');
    
    _setupPurchaseStream(); // Setup stream once on init
    _loadPurchaseDisableStatus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _delayedInitialize();
    });
    _fetchPremiumStatusFromBackend(); // Fetch premium status from backend
  }

  // Synchronous simulator check for early debugging
  bool _isSimulatorSync() {
    try {
      return Platform.isIOS && 
             (Platform.environment['SIMULATOR_DEVICE_NAME'] != null ||
              Platform.environment['XCODE_VERSION'] != null ||
              (Platform.environment['PATH']?.contains('Platforms/iPhoneOS.platform') ?? false) == false);
    } catch (e) {
      return false;
    }
  }

  Future<void> _delayedInitialize() async {
    await Future.delayed(Duration(milliseconds: 500));
    await initialize();
  }

  Future<void> initialize() async {
    if (isInitialized.value && !errorMessage.value.contains('Store error')) {
      // Still refresh products if they're empty
      if (products.isEmpty) {
        await loadProducts();
      }
      return;
    }

    try {
      isLoading.value = true;
      errorMessage.value = '';

      // Enhanced debugging for real device
      debugPrint('IAP: === Starting IAP Initialization ===');
      debugPrint('IAP: Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
      debugPrint('IAP: Device: ${Platform.isIOS ? "iOS" : "Android"}');
      
      // Detect sandbox environment
      await _detectSandboxEnvironment();
      
      // Check network connectivity first
      await _checkNetworkConnectivity();
      
      // Add timeout and retry logic for StoreKit availability check
      debugPrint('IAP: Checking App Store availability...');
      debugPrint('IAP: Sandbox mode: ${isSandbox.value}');
      
      // Try multiple StoreKit initialization approaches
      final available = await _tryStoreKitInitialization();

      debugPrint('IAP: App Store available: $available');

      if (!available) {
        // Clear loading state before setting error to prevent concurrent states
        isLoading.value = false;
        errorMessage.value = 'App Store is not available. Please check your internet connection and try again.';
        debugPrint('IAP: ❌ App Store not available - possible network or device configuration issue');
        products.clear();
        // Load current premium status
        try {
          final prefs = await SharedPreferences.getInstance();
          premiumActive.value = prefs.getBool('is_lifetime_premium') ?? false;
        } catch (_) {}
        isInitialized.value = true;
        return;
      }

      await loadProducts();
      await _checkPendingPurchase();

      // Load current premium status instantly
      try {
        final prefs = await SharedPreferences.getInstance();
        final isPremium = prefs.getBool('is_lifetime_premium') ?? false;
        premiumActive.value = isPremium;
        
        if (isPremium) {
          debugPrint('IAP: ✅ Premium status loaded instantly on startup');
          // Notify listeners that premium is active
          _notifyPremiumListeners();
        }
      } catch (_) {}
      isInitialized.value = true;
    } catch (e) {
      // Better error handling for StoreKit specific errors
      String errorMsg = 'Failed to initialize';
      
      debugPrint('IAP Initialization Error:');
      debugPrint('  Error: $e');
      debugPrint('  Error Type: ${e.runtimeType}');
      debugPrint('  Platform: ${Platform.isIOS ? "iOS" : "Android"}');
      debugPrint('  Sandbox: ${isSandbox.value}');
      debugPrint('  Stack Trace: ${StackTrace.current}');
      
      if (e.toString().contains('storekit_no_response')) {
        errorMsg = 'Store error: Unable to connect to App Store. Please try again.';
        debugPrint('IAP: ⚠️ StoreKit no response during initialization');
      } else if (e.toString().contains('storekit')) {
        errorMsg = 'Store error: App Store is temporarily unavailable. Please try again later.';
        debugPrint('IAP: ⚠️ StoreKit error during initialization');
      } else {
        errorMsg = 'Failed to initialize: $e';
      }
      
      // Clear loading state before setting error to prevent concurrent states
      isLoading.value = false;
      errorMessage.value = errorMsg;
      
      // Retry logic for StoreKit errors
      if (e.toString().contains('storekit') && !isInitialized.value) {
        Future.delayed(const Duration(seconds: 3), () {
          if (!isInitialized.value) {
            initialize();
          }
        });
      }
    } finally {
      // Ensure loading state is cleared
      isLoading.value = false;
    }
  }

  // Check network connectivity
  Future<void> _checkNetworkConnectivity() async {
    try {
      debugPrint('IAP: Checking network connectivity...');
      final response = await http.get(Uri.parse('https://apps.apple.com')).timeout(
        const Duration(seconds: 5),
      );
      debugPrint('IAP: Network connectivity check: ${response.statusCode}');
      if (response.statusCode != 200) {
        debugPrint('IAP: ⚠️ Network connectivity issue detected');
      }
    } catch (e) {
      debugPrint('IAP: ❌ Network connectivity failed: $e');
    }
  }

  // Try multiple StoreKit initialization approaches
  Future<bool> _tryStoreKitInitialization() async {
    try {
      debugPrint('IAP: Attempting StoreKit initialization...');
      
      // Method 1: Standard availability check
      final available = await _iap.isAvailable().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('IAP: ⚠️ App Store availability check timed out');
          return false;
        },
      );
      
      if (available) {
        debugPrint('IAP: ✅ StoreKit initialization successful');
        return true;
      }
      
      debugPrint('IAP: ❌ StoreKit initialization failed');
      return false;
    } catch (e) {
      debugPrint('IAP: StoreKit initialization error: $e');
      
      // TestFlight-specific fallback
      if (e.toString().contains('storekit_no_response')) {
        debugPrint('IAP: 🔄 TestFlight fallback - trying alternative initialization...');
        return await _tryTestFlightFallback();
      }
      
      return false;
    }
  }

  // TestFlight-specific fallback initialization
  Future<bool> _tryTestFlightFallback() async {
    try {
      debugPrint('IAP: 🛠️ TestFlight fallback initialization...');
      
      // For TestFlight, try to initialize with different approach
      await Future.delayed(const Duration(seconds: 2));
      
      final available = await _iap.isAvailable().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint('IAP: ⚠️ TestFlight fallback timeout');
          return false;
        },
      );
      
      if (available) {
        debugPrint('IAP: ✅ TestFlight fallback successful');
        return true;
      }
      
      debugPrint('IAP: ❌ TestFlight fallback failed');
      return false;
    } catch (e) {
      debugPrint('IAP: TestFlight fallback error: $e');
      return false;
    }
  }

  // Detect sandbox environment for iOS
  Future<void> _detectSandboxEnvironment() async {
    if (Platform.isIOS) {
      try {
        // Check if running in simulator first
        final isSimulator = await _isSimulator();
        if (isSimulator) {
          debugPrint('IAP: 📱 iOS Simulator detected - local StoreKit configuration should work');
          isSandbox.value = true;
          return;
        }
        
        // Check if running in TestFlight
        final isTestFlight = await _isTestFlight();
        if (isTestFlight) {
          debugPrint('IAP: ✈️ TestFlight detected - using production App Store');
          isSandbox.value = false;
          return;
        }
        
        // Check if running in sandbox by evaluating environment
        final isSandboxEnv = await _checkSandboxEnvironment();
        isSandbox.value = isSandboxEnv;
        debugPrint('IAP: Sandbox environment detected: $isSandboxEnv');
      } catch (e) {
        debugPrint('IAP: Error detecting sandbox environment: $e');
        // Default to false if detection fails
        isSandbox.value = false;
      }
    }
  }

  // Check if running in TestFlight
  Future<bool> _isTestFlight() async {
    try {
      // Check for TestFlight indicators
      final receiptsUrl = 'https://buy.itunes.apple.com/verifyReceipt';
      final response = await http.head(Uri.parse(receiptsUrl)).timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw Exception('Timeout'),
      );
      
      // TestFlight builds typically can't reach production App Store
      final isTestFlightEnv = response.statusCode != 200;
      debugPrint('IAP: TestFlight detection: $isTestFlightEnv (status: ${response.statusCode})');
      return isTestFlightEnv;
    } catch (e) {
      debugPrint('IAP: TestFlight detection error: $e');
      // Assume TestFlight if detection fails
      return true;
    }
  }

  // Check if running on iOS simulator
  Future<bool> _isSimulator() async {
    try {
      // Simple simulator detection using platform properties
      if (!Platform.isIOS) return false;
      
      // Check architecture - simulators run on x86_64, devices on ARM
      final isSimulator = Platform.isIOS && 
                        (Platform.environment['SIMULATOR_DEVICE_NAME'] != null ||
                         Platform.environment['XCODE_VERSION'] != null ||
                         (Platform.environment['PATH']?.contains('Platforms/iPhoneOS.platform') ?? false) == false);
      
      debugPrint('IAP: Simulator detection result: $isSimulator');
      return isSimulator;
    } catch (e) {
      debugPrint('IAP: Could not detect simulator: $e');
      // Assume physical device if detection fails
      return false;
    }
  }

  // Check if running in sandbox environment
  Future<bool> _checkSandboxEnvironment() async {
    // For iOS, we can check receipt URL or use platform channel
    // For now, use a simple check based on common indicators
    try {
      // Try to detect sandbox by checking if we can access sandbox receipt URL
      // This is a simplified approach - in production you might want more sophisticated detection
      const receiptUrl = 'https://sandbox.itunes.apple.com/verifyReceipt';
      final response = await http.head(Uri.parse(receiptUrl)).timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw Exception('Timeout'),
      );
      
      // If we can reach sandbox URL, we're likely in sandbox
      return response.statusCode == 200;
    } catch (e) {
      // If we can't reach sandbox, assume production
      return false;
    }
  }

  void _setupPurchaseStream() {
    if (_purchaseSubscription != null) return; // Already subscribed

    _purchaseSubscription = _iap.purchaseStream.listen(
      _handlePurchases,
      onDone: () {
        debugPrint('IAP: Purchase stream closed');
        _purchaseSubscription = null;
        // Auto-reconnect after a delay
        Future.delayed(const Duration(seconds: 2), () {
          if (_purchaseSubscription == null) {
            _setupPurchaseStream();
          }
        });
      },
      onError: (error) {
        debugPrint('IAP: Stream error: $error');
        _purchaseSubscription = null;
        // Auto-reconnect after a delay
        Future.delayed(const Duration(seconds: 3), () {
          if (_purchaseSubscription == null) {
            _setupPurchaseStream();
          }
        });
      },
    );
  }

  // Load products from store with StoreKit retry logic
  Future<void> loadProducts() async {
    int retryCount = 0;
    
    while (retryCount < _storeKitMaxRetries) {
      try {
        debugPrint('IAP: Loading products (attempt ${retryCount + 1}/$_storeKitMaxRetries)');
        debugPrint('IAP: Product IDs: $_productIds');
        debugPrint('IAP: Sandbox mode: ${isSandbox.value}');
        
        // Add a small delay before retry attempts (except first attempt)
        if (retryCount > 0) {
          await Future.delayed(Duration(milliseconds: 500 * retryCount));
        }
        
        // Add timeout for product query
        final response = await _iap.queryProductDetails(_productIds).timeout(
          const Duration(seconds: 15),
          onTimeout: () => ProductDetailsResponse(
            productDetails: [],
            notFoundIDs: _productIds.toList(),
            error: IAPError(
              source: 'store',
              code: 'timeout',
              message: 'Request timed out',
            ),
          ),
        );

      if (response.error != null) {
        String errorMsg = 'Store error: ${response.error!.message}';
        
        // Detailed logging for debugging
        debugPrint('IAP Error Details:');
        debugPrint('  Error Code: ${response.error!.code}');
        debugPrint('  Error Message: ${response.error!.message}');
        debugPrint('  Error Source: ${response.error!.source}');
        debugPrint('  Platform: ${Platform.isIOS ? "iOS" : "Android"}');
        debugPrint('  Product IDs queried: $_productIds');
        debugPrint('  Is Sandbox: $isSandbox');
        debugPrint('  Is Initialized: $isInitialized');
        debugPrint('  Retry Count: $retryCount/$_storeKitMaxRetries');
        
        // Check if this is a retryable StoreKit error
        bool isRetryableError = response.error!.code == 'storekit_no_response' || 
                               response.error!.code == 'timeout' ||
                               response.error!.code == 'storekit';
        
        if (isRetryableError && retryCount < _storeKitMaxRetries - 1) {
          retryCount++;
          debugPrint('IAP: 🔄 Retrying after ${_storeKitRetryDelay.inSeconds}s (attempt $retryCount/$_storeKitMaxRetries)');
          await Future.delayed(_storeKitRetryDelay);
          continue; // Retry the loop
        }
        
        // Better error messages for common StoreKit errors
        if (response.error!.code == 'storekit_no_response') {
          errorMsg = 'Store error: Unable to connect to App Store. Please check your connection and try again.';
          debugPrint('IAP: ⚠️ StoreKit no response - possible network or configuration issue');
        } else if (response.error!.code == 'storekit') {
          errorMsg = 'Store error: App Store is temporarily unavailable. Please try again later.';
          debugPrint('IAP: ⚠️ StoreKit general error - possible App Store issue');
        } else if (response.error!.message?.contains('product') == true) {
          errorMsg = 'Store error: Product configuration issue found. Please contact support.';
          debugPrint('IAP: ⚠️ Product configuration error - check App Store Connect');
        }
        
        errorMessage.value = errorMsg;
        products.clear();
        return;
      }

      if (response.productDetails.isEmpty) {
        if (response.notFoundIDs.isNotEmpty) {
          errorMessage.value = 'Premium product not found. Please check your App Store Connect configuration.';
          debugPrint('IAP: ❌ Product not found: ${response.notFoundIDs}');
        } else {
          errorMessage.value = 'No products available at the moment. Please try again later.';
          debugPrint('IAP: ❌ No products available');
        }
        products.clear();
      } else {
        products.assignAll(response.productDetails);
        errorMessage.value = ''; // Clear error on success
        debugPrint('IAP: ✅ Products loaded successfully: ${response.productDetails.length} products');
        for (var product in response.productDetails) {
          debugPrint('IAP:   - ${product.id}: ${product.title}');
        }
        return; // Success, exit the retry loop
      }
    } catch (e) {
      String errorMsg = 'Error loading products';
      
      if (e.toString().contains('storekit_no_response') && retryCount < _storeKitMaxRetries - 1) {
        retryCount++;
        debugPrint('IAP: 🔄 StoreKit no response, retrying after ${_storeKitRetryDelay.inSeconds}s (attempt $retryCount/$_storeKitMaxRetries)');
        await Future.delayed(_storeKitRetryDelay);
        continue; // Retry the loop
      } else if (e.toString().contains('timeout') && retryCount < _storeKitMaxRetries - 1) {
        retryCount++;
        debugPrint('IAP: 🔄 Timeout, retrying after ${_storeKitRetryDelay.inSeconds}s (attempt $retryCount/$_storeKitMaxRetries)');
        await Future.delayed(_storeKitRetryDelay);
        continue; // Retry the loop
      } else if (e.toString().contains('storekit_no_response')) {
        errorMsg = 'Store error: Unable to connect to App Store. Please try again.';
      } else if (e.toString().contains('timeout')) {
        errorMsg = 'Store error: Connection timed out. Please check your internet connection.';
      }
      
      errorMessage.value = errorMsg + ': $e';
      products.clear();
      return; // Exit on final attempt or non-retryable error
    }
    
    // If we get here, we need to retry
    retryCount++;
    if (retryCount < _storeKitMaxRetries) {
      debugPrint('IAP: 🔄 General retry after ${_storeKitRetryDelay.inSeconds}s (attempt $retryCount/$_storeKitMaxRetries)');
      await Future.delayed(_storeKitRetryDelay);
    }
    }
  }

  // Purchase a package (type unused — single premium product)
  Future<bool> purchasePackage(int type) async {
    try {
      // Check if purchases are disabled
      if (purchasesDisabled.value) {
        errorMessage.value = 'Purchases are temporarily disabled: ${disableReason.value}';
        return false;
      }

      final targetId = Platform.isIOS ? _iosProductId : _androidProductId;

      if (!isInitialized.value) {
        await initialize();
      }

      if (products.isEmpty) {
        await loadProducts();
        // Wait a bit for products to load
        await Future.delayed(const Duration(milliseconds: 500));
      }

      final product = products.firstWhereOrNull((p) => p.id == targetId);

      if (product == null) {
        errorMessage.value = 'Premium product is not available. Please try again later.';
        return false;
      }

      isLoading.value = true;

      // Add timeout for store availability check
      final available = await _iap.isAvailable().timeout(
        const Duration(seconds: 10),
        onTimeout: () => false,
      );
      
      if (available && products.isNotEmpty) {
        final purchaseParam = PurchaseParam(productDetails: product);
        
        // Add timeout for purchase operation
        await _iap.buyNonConsumable(purchaseParam: purchaseParam).timeout(
          const Duration(seconds: 120),
          onTimeout: () {
            throw PlatformException(
              code: 'timeout',
              message: 'The purchase request timed out. Please try again.',
            );
          },
        );
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('iap_last_product_id', product.id);
        return true;
      } else {
        errorMessage.value = 'Store unavailable. Please check your connection and try again.';
        return false;
      }

    } on PlatformException catch (e) {
      String errorMsg = 'Purchase failed';
      
      // Better error handling for specific StoreKit errors
      if (e.code == 'storekit_no_response') {
        errorMsg = 'Store error: Unable to connect to App Store. Please try again.';
      } else if (e.code == 'payment_canceled') {
        errorMsg = 'Purchase was cancelled.';
      } else if (e.code == 'payment_not_allowed') {
        errorMsg = 'Purchases are not allowed on this device.';
      } else if (e.code == 'timeout') {
        if (isProductionMode) {
          // Hide timeout errors in production to avoid confusing users
          errorMsg = 'Payment processing is taking longer than expected. Please check your purchase status in a few minutes.';
        } else {
          errorMsg = 'Purchase timed out. This can happen with slow connections. Please try again.';
        }
      } else if (e.code == 'billing_response_item_already_owned') {
        errorMsg = 'You already own this premium membership. Restoring your purchase...';
        // Handle already owned purchase scenario
        await handleAlreadyOwnedPurchase();
      } else if (e.code == 'billing_response' && e.message?.contains('already owned') == true) {
        errorMsg = 'You already own this premium membership. Restoring your purchase...';
        // Handle already owned purchase scenario
        await handleAlreadyOwnedPurchase();
      } else if (e.message?.contains('storekit') == true) {
        errorMsg = 'Store error: ${e.message ?? 'Unknown StoreKit error'}';
      } else {
        errorMsg = 'Purchase failed: ${e.code} ${e.message ?? ''}'.trim();
      }
      
      errorMessage.value = errorMsg;
      return false;
    } catch (e) {
      String errorMsg = 'Purchase failed';
      if (e.toString().contains('timeout')) {
        if (isProductionMode) {
          // Hide timeout errors in production to avoid confusing users
          errorMsg = 'Payment processing is taking longer than expected. Please check your purchase status in a few minutes.';
        } else {
          errorMsg = 'Purchase timed out. This can happen with slow connections. Please try again.';
        }
      } else if (e.toString().contains('storekit')) {
        errorMsg = 'Store error: Unable to complete purchase. Please try again.';
      }
      
      errorMessage.value = errorMsg + '. Please try again.';
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _handlePurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      debugPrint('IAP: Processing purchase status: ${purchase.status} for ${purchase.productID}');
      debugPrint('IAP: Purchase ID: ${purchase.purchaseID}');
      debugPrint('IAP: Transaction date: ${purchase.transactionDate}');
      
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          debugPrint('IAP: Starting backend verification...');
          
          // For Android: Acknowledge purchase IMMEDIATELY to prevent refunds
          // This must happen before any other operations to avoid cancellation
          if (Platform.isAndroid) {
            try {
              await _iap.completePurchase(purchase);
              debugPrint('IAP: ✅ Purchase acknowledged and completed for Android');
            } catch (e) {
              debugPrint('IAP: ❌ Error acknowledging purchase: $e');
              // Don't proceed if acknowledgment fails
              errorMessage.value = 'Failed to acknowledge purchase. Please try again.';
              return;
            }
          }
          
          // Complete the purchase on the platform side
          if (purchase.pendingCompletePurchase) {
            try {
              await _iap.completePurchase(purchase);
              debugPrint('IAP: ✅ Purchase completed on platform');
            } catch (e) {
              debugPrint('IAP: ❌ Error completing purchase: $e');
            }
          }
          
          // Activate premium immediately for better user experience
          await _activatePremiumInstantly();
          
          // Then verify with backend in background without blocking UI
          _verifyOnBackendInBackground(purchase);
          break;
          
        case PurchaseStatus.error:
          debugPrint('IAP: ❌ Purchase error details:');
          debugPrint('IAP:   Error code: ${purchase.error?.code}');
          debugPrint('IAP:   Error message: ${purchase.error?.message}');
          debugPrint('IAP:   Error details: ${purchase.error?.details}');
          debugPrint('IAP:   Product ID: ${purchase.productID}');
          debugPrint('IAP:   Purchase ID: ${purchase.purchaseID}');
          debugPrint('IAP:   Status: ${purchase.status}');
          debugPrint('IAP:   Pending complete: ${purchase.pendingCompletePurchase}');

          // Handle itemAlreadyOwned - user already owns the product
          final errorCode = purchase.error?.code ?? '';
          final errorMsg = purchase.error?.message ?? '';
          if (errorCode.contains('already_owned') ||
              errorCode.contains('itemAlreadyOwned') ||
              errorMsg.contains('already owned') ||
              errorMsg.contains('AlreadyOwned')) {
            debugPrint('IAP: 🔄 Item already owned - attempting restore...');
            await handleAlreadyOwnedPurchase();
            if (purchase.pendingCompletePurchase) {
              try {
                await _iap.completePurchase(purchase);
                debugPrint('IAP: ✅ Already-owned purchase completed');
              } catch (e) {
                debugPrint('IAP: ❌ Error completing already-owned purchase: $e');
              }
            }
          } else {
            errorMessage.value = 'Purchase failed: ${purchase.error?.message ?? 'Unknown error'}';
          }
          break;
          
        case PurchaseStatus.pending:
          debugPrint('IAP: Purchase pending - storing for retry');
          await _storePendingPurchase(purchase);
          break;
          
        default:
          debugPrint('IAP: Unhandled purchase status: ${purchase.status}');
          break;
      }
    }
  }

  Future<void> _activatePremium() async {
    try {
      debugPrint('IAP: === Activating premium ===');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_lifetime_premium', true);
      premiumActive.value = true;
      errorMessage.value = '';
      debugPrint('IAP: ✅ Premium activated successfully');
      debugPrint('IAP: premiumActive.value: ${premiumActive.value}');
    } catch (e) {
      debugPrint('IAP: ❌ Error activating premium: $e');
      debugPrint('IAP: Exception type: ${e.runtimeType}');
    }
  }

  // Instant premium activation without UI refresh
  Future<void> _activatePremiumInstantly() async {
    try {
      debugPrint('IAP: === INSTANT Premium Activation ===');
      final prefs = await SharedPreferences.getInstance();
      
      // Update all premium-related values instantly
      await prefs.setBool('is_lifetime_premium', true);
      await prefs.setString('premium_activated_at', DateTime.now().toIso8601String());
      await prefs.setBool('premium_verified', true);
      
      // Update reactive variables immediately
      premiumActive.value = true;
      errorMessage.value = '';
      isLoading.value = false;
      
      // Trigger immediate UI updates for all premium features
      _notifyPremiumListeners();
      
      debugPrint('IAP: ✅ Premium activated INSTANTLY');
      debugPrint('IAP: User now has immediate access to all premium features');
    } catch (e) {
      debugPrint('IAP: ❌ Error in instant premium activation: $e');
      debugPrint('IAP: Exception type: ${e.runtimeType}');
    }
  }

  // Notify all premium listeners for instant UI updates
  void _notifyPremiumListeners() {
    try {
      debugPrint('IAP: Notifying all premium listeners...');
      
      // Update any controllers or services that depend on premium status
      // This ensures all parts of the app know premium is active immediately
      
      // Force refresh of premium status across the app
      premiumActive.refresh();
      
      debugPrint('IAP: ✅ All premium listeners notified');
    } catch (e) {
      debugPrint('IAP: ❌ Error notifying premium listeners: $e');
    }
  }

  // Background verification without blocking UI
  void _verifyOnBackendInBackground(PurchaseDetails purchase) {
    try {
      debugPrint('IAP: Starting background verification...');
      
      // Run verification in background without blocking
      Future.microtask(() async {
        try {
          bool verified = await _verifyOnBackend(purchase);
          if (verified) {
            debugPrint('IAP: ✅ Background verification successful');
          } else {
            debugPrint('IAP: ⚠️ Background verification failed, but user has access');
          }
        } catch (e) {
          debugPrint('IAP: ❌ Background verification error: $e');
          // Don't show error to user since they already have premium access
        }
      });
      
    } catch (e) {
      debugPrint('IAP: ❌ Error starting background verification: $e');
    }
  }

  // Instant premium status check - can be called from anywhere in the app
  static Future<bool> isPremiumActive() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('is_lifetime_premium') ?? false;
    } catch (e) {
      debugPrint('IAP: Error checking premium status: $e');
      return false;
    }
  }

  // Get premium activation timestamp
  static Future<String?> getPremiumActivatedAt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('premium_activated_at');
    } catch (e) {
      debugPrint('IAP: Error getting premium activation time: $e');
      return null;
    }
  }

  Future<void> _storePendingPurchase(PurchaseDetails purchase) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = await UserStorage.getUserId();
      
      final pendingData = {
        'product_id': purchase.productID,
        'transaction_id': purchase.purchaseID,
        'verification_data': purchase.verificationData.localVerificationData,
        'server_data': purchase.verificationData.serverVerificationData,
        'user_id': userId?.toString() ?? '',
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      await prefs.setString('pending_purchase', json.encode(pendingData));
      debugPrint('IAP: Stored pending purchase for retry');
    } catch (e) {
      debugPrint('IAP: Error storing pending purchase: $e');
    }
  }

  Future<void> _checkPendingPurchase() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = await UserStorage.getUserId();
      final pendingJson = prefs.getString('pending_purchase');
      
      if (pendingJson != null && userId != null) {
        final data = json.decode(pendingJson);
        
        final success = await _verifyManual(
          productId: data['product_id'] ?? '',
          transactionId: data['transaction_id'],
          verificationData: data['verification_data'] ?? '',
          serverData: data['server_data'],
        );

        if (success) {
          debugPrint('IAP: Pending purchase verified successfully during retry');
          await _clearPendingPurchase();
        } else {
          debugPrint('IAP: Pending purchase retry verification failed');
        }
      }
    } catch (e) {
      debugPrint('IAP: Error checking pending purchase: $e');
    }
  }

  Future<bool> _verifyOnBackend(PurchaseDetails purchase) async {
    return _verifyManual(
      productId: purchase.productID,
      transactionId: purchase.purchaseID,
      verificationData: purchase.verificationData.serverVerificationData,
      serverData: purchase.verificationData.serverVerificationData,
      isPending: false,
    );
  }

  Future<bool> _verifyManual({
    required String productId,
    String? transactionId,
    required String verificationData,
    String? serverData,
    bool isPending = true,
  }) async {
    try {
      debugPrint('IAP: === Starting verification ===');
      debugPrint('IAP: Product ID: $productId');
      debugPrint('IAP: Transaction ID: $transactionId');
      debugPrint('IAP: Is pending: $isPending');
      debugPrint('IAP: Verification data length: ${verificationData.length}');
      debugPrint('IAP: Server data length: ${serverData?.length ?? 0}');
      
      final userIdInt = await UserStorage.getUserId();
      final userId = userIdInt?.toString() ?? '';
      
      debugPrint('IAP: User ID: $userId');

      if (userId.isEmpty) {
        debugPrint('IAP: ❌ No user logged in for verification');
        if (!isPending) {
            // Need to store it so we can retry after login
            final storedData = {
              'product_id': productId,
              'transaction_id': transactionId,
              'verification_data': verificationData,
              'server_data': serverData,
              'timestamp': DateTime.now().toIso8601String(),
            };
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('pending_purchase', json.encode(storedData));
            debugPrint('IAP: Stored purchase for retry after login');
        }
        return false;
      }

      debugPrint('IAP: Calling backend API: ${ApiConfig.verifyPurchase}');
      
      final response = await http.post(
        Uri.parse(ApiConfig.verifyPurchase),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'receipt': verificationData,
          'product_id': productId,
          'transaction_id': transactionId,
          'user_id': userId,
          'platform': Platform.isIOS ? 'apple' : 'android',
          'is_sandbox': isSandbox.value,
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('IAP: Backend verification timed out');
          if (isProductionMode) {
            // In production, don't throw timeout exceptions to avoid UI errors
            debugPrint('IAP: Production mode - suppressing backend timeout error');
            // Return a mock success response to avoid UI errors
            return http.Response('{"success": true, "message": "Backend verification skipped in production"}', 200);
          } else {
            throw TimeoutException('Backend verification timed out', const Duration(seconds: 30));
          }
        },
      );

      
      debugPrint('IAP: Backend response status code: ${response.statusCode}');
      debugPrint('IAP: Backend response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        debugPrint('IAP: Parsed response: $responseData');
        
        if (responseData['success'] == true) {
          debugPrint('IAP: ✅ Backend verification successful');
          if (!isPending) {
            await _activatePremium();
          }
          return true;
        } else {
          debugPrint('IAP: ❌ Backend returned success=false');
          debugPrint('IAP: Error message from backend: ${responseData['error'] ?? 'No error message'}');
        }
      } else {
        debugPrint('IAP: ❌ Backend returned non-200 status: ${response.statusCode}');
      }
      
      return false;
    } catch (e) {
      debugPrint('IAP: ❌ Verification exception: $e');
      debugPrint('IAP: Exception type: ${e.runtimeType}');
      return false;
    }
  }

  Future<void> _clearPendingPurchase() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pending_purchase');
      debugPrint('IAP: Cleared pending purchase');
    } catch (e) {
      debugPrint('IAP: Error clearing pending purchase: $e');
    }
  }

  Future<bool> hasPremium() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_lifetime_premium') ?? false;
  }

  Future<bool> restorePurchases() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      
      // Add timeout for restore operation
      await _iap.restorePurchases().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw PlatformException(
            code: 'timeout',
            message: 'The restore request timed out. Please try again.',
          );
        },
      );
      
      return true;
    } on PlatformException catch (e) {
      String errorMsg = 'Restore failed';
      
      // Better error handling for specific StoreKit errors
      if (e.code == 'storekit_no_response') {
        errorMsg = 'Store error: Unable to connect to App Store. Please try again.';
      } else if (e.code == 'No active account') {
        errorMsg = 'Please sign in to your App Store account to restore purchases.';
      } else if (e.code == 'payment_canceled') {
        errorMsg = 'Restore was cancelled.';
      } else if (e.code == 'timeout') {
        errorMsg = 'Restore timed out. Please check your connection and try again.';
      } else if (e.message?.contains('storekit') == true) {
        errorMsg = 'Store error: ${e.message ?? 'Unknown StoreKit error'}';
      } else {
        errorMsg = 'Restore failed: ${e.code} ${e.message ?? ''}'.trim();
      }
      
      errorMessage.value = errorMsg;
      return false;
    } catch (e) {
      String errorMsg = 'Restore failed';
      if (e.toString().contains('timeout')) {
        errorMsg = 'Restore timed out. Please check your internet connection.';
      } else if (e.toString().contains('storekit')) {
        errorMsg = 'Store error: Unable to restore purchases. Please try again.';
      } else if (e.toString().contains('connection') || e.toString().contains('network')) {
        errorMsg = 'Network issue during restore. Check your internet and try again.';
      }
      
      errorMessage.value = errorMsg + '. Please try again.';
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _fetchPremiumStatusFromBackend() async {
    try {
      final userIdInt = await UserStorage.getUserId();
      if (userIdInt == null || userIdInt == 0) {
        debugPrint('IAP: No user ID, skipping premium status fetch');
        return;
      }

      debugPrint('IAP: Fetching premium status for user ID: $userIdInt');
      debugPrint('IAP: API URL: ${ApiConfig.checkPremiumStatus}?user_id=$userIdInt');
      
      final response = await http.get(
        Uri.parse('${ApiConfig.checkPremiumStatus}?user_id=$userIdInt'),
        headers: ApiConfig.jsonHeaders,
      );

      debugPrint('IAP: Backend response status: ${response.statusCode}');
      debugPrint('IAP: Backend response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('IAP: Parsed response data: $data');
        
        if (data['success'] == true && data['is_premium'] == true) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('is_lifetime_premium', true);
          premiumActive.value = true;
          debugPrint('IAP: ✅ Premium status restored from backend');
        } else {
          debugPrint('IAP: User is not premium or failed response');
          debugPrint('IAP: success: ${data['success']}, is_premium: ${data['is_premium']}');
        }
      } else {
        debugPrint('IAP: Backend returned non-200 status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('IAP: Error fetching premium status from backend: $e');
    }
  }

  /// Update premium status from login response
  Future<void> updatePremiumStatusFromLogin(Map<String, dynamic> userData) async {
    try {
      final isPremium = userData['is_lifetime_premium'] ?? 0;
      debugPrint('IAP: Updating premium status from login: is_lifetime_premium = $isPremium');
      
      if (isPremium == 1) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_lifetime_premium', true);
        premiumActive.value = true;
        debugPrint('IAP: ✅ Premium status updated from login response');
      } else {
        premiumActive.value = false;
        debugPrint('IAP: User is not premium according to login data');
      }
    } catch (e) {
      debugPrint('IAP: Error updating premium status from login: $e');
    }
  }

  /// Load purchase disable status from SharedPreferences
  Future<void> _loadPurchaseDisableStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDisabled = prefs.getBool(_purchasesDisabledKey) ?? false;
      final reason = prefs.getString(_disableReasonKey) ?? '';
      final disableUntil = prefs.getString(_disableUntilKey);
      
      // Check if disable period has expired
      if (isDisabled && disableUntil != null) {
        final disableUntilTime = DateTime.parse(disableUntil);
        if (DateTime.now().isAfter(disableUntilTime)) {
          // Disable period expired, enable purchases
          await _savePurchaseDisableStatus(false, '', null);
        } else {
          // Still disabled
          purchasesDisabled.value = true;
          disableReason.value = reason;
        }
      }
    } catch (e) {
      debugPrint('Error loading purchase disable status: $e');
    }
  }

  /// Save purchase disable status to SharedPreferences
  Future<void> _savePurchaseDisableStatus(bool isDisabled, String reason, DateTime? disableUntil) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_purchasesDisabledKey, isDisabled);
      await prefs.setString(_disableReasonKey, reason);
      if (disableUntil != null) {
        await prefs.setString(_disableUntilKey, disableUntil.toIso8601String());
      } else {
        await prefs.remove(_disableUntilKey);
      }
      
      purchasesDisabled.value = isDisabled;
      disableReason.value = reason;
      debugPrint('IAP: Purchase disable status saved - $isDisabled, $reason');
    } catch (e) {
      debugPrint('Error saving purchase disable status: $e');
    }
  }

  // Disable purchases temporarily
  Future<void> disablePurchasesTemporarily({
    required String reason,
    Duration? duration,
  }) async {
    final disableUntil = duration != null 
        ? DateTime.now().add(duration)
        : null;
    
    await _savePurchaseDisableStatus(true, reason, disableUntil);
  }

  // Enable purchases
  Future<void> enablePurchases() async {
    await _savePurchaseDisableStatus(false, '', null);
  }

  // Check if purchases are disabled
  bool arePurchasesDisabled() {
    return purchasesDisabled.value;
  }

  // Get disable reason
  String getDisableReason() {
    return disableReason.value;
  }

  // Handle already owned purchases by checking with Google Play
  Future<void> handleAlreadyOwnedPurchase() async {
    try {
      debugPrint('IAP: Handling already owned purchase scenario');
      
      // First try to restore purchases which will query existing purchases
      await restorePurchases();
      
      // Also check if premium is already active locally
      final prefs = await SharedPreferences.getInstance();
      final isPremium = prefs.getBool('is_lifetime_premium') ?? false;
      
      if (isPremium) {
        premiumActive.value = true;
        debugPrint('IAP: ✅ Premium status already active locally');
      } else {
        // Try to fetch from backend
        await _fetchPremiumStatusFromBackend();
      }
    } catch (e) {
      debugPrint('IAP: Error handling already owned purchase: $e');
    }
  }
}
