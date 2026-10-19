import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/services/iap_service.dart';
import 'package:fruitsofspirit/routes/routes.dart';
import 'package:fruitsofspirit/utils/app_theme.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({Key? key}) : super(key: key);

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  IAPService? _iapService;
  bool _isInitializing = true;
  bool _processingOverlayVisible = true;
  String _processingOverlayMessage = 'Checking your purchase status...';
  bool _premiumCloseScheduled = false;

  @override
  void initState() {
    super.initState();
    _iapService = Get.isRegistered<IAPService>()
        ? Get.find<IAPService>()
        : Get.put(IAPService(), permanent: true);
    _initializeIAP();
  }

  Future<void> _initializeIAP() async {
    try {
      setState(() {
        _processingOverlayVisible = true;
        _processingOverlayMessage = 'Checking your account...';
      });

      // Fast DB check only — payment UI stays visible under the overlay.
      final alreadyPaid = await _iapService!
          .ensurePremiumFromDatabase(forceRefresh: true)
          .timeout(const Duration(seconds: 10), onTimeout: () {
        debugPrint('Payment: DB premium check timed out');
        return false;
      });

      if (alreadyPaid) {
        _schedulePremiumSuccessClose();
        return;
      }
    } catch (e) {
      debugPrint('Payment: init error: $e');
      _iapService ??= Get.put(IAPService(), permanent: true);
    }

    if (!mounted) return;
    setState(() {
      _isInitializing = false;
      _processingOverlayVisible = false;
    });

    unawaited(_bootstrapStoreInBackground());
  }

  Future<void> _bootstrapStoreInBackground() async {
    final iap = _iapService;
    if (iap == null) return;

    try {
      // Load store products only — no silent restore (user must tap Buy or Restore).
      await iap.initialize();
    } catch (e) {
      debugPrint('Payment: store bootstrap failed: $e');
    }
  }

  void _closeAsPremiumRestored({String? message}) {
    if (!mounted) return;
    Get.back(result: true);
    Get.snackbar(
      'Premium Restored',
      message ?? 'Your purchase is active. Enjoy all premium features!',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.green.shade700,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
    );
  }

  void _showProcessingOverlay(String message) {
    if (!mounted) return;
    setState(() {
      _processingOverlayVisible = true;
      _processingOverlayMessage = message;
    });
  }

  void _hideProcessingOverlay() {
    if (!mounted) return;
    setState(() => _processingOverlayVisible = false);
  }

  void _schedulePremiumSuccessClose() {
    if (_premiumCloseScheduled || !mounted) return;
    _premiumCloseScheduled = true;
    _showProcessingOverlay('Premium activated!');
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      _hideProcessingOverlay();
      _closeAsPremiumRestored();
    });
  }

  Future<void> _handleRestorePurchases(IAPService iap) async {
    _showProcessingOverlay('Restoring your purchase...');
    final result = await iap.restorePremiumMembership();
    if (!mounted) return;

    if (result.success) {
      _schedulePremiumSuccessClose();
      return;
    }

    _hideProcessingOverlay();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.primaryColor,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = ResponsiveHelper.isCompactHeight(context);

    // If IAP service is not available, show error
    if (_iapService == null) {
      return Scaffold(
        backgroundColor: AppTheme.themeColor,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: ResponsiveHelper.padding(context, all: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: AppTheme.errorColor,
                    size: ResponsiveHelper.iconSize(context, mobile: 48, tablet: 56),
                  ),
                  ResponsiveHelper.vGap(context, 16),
                  Text(
                    'Payment Service Unavailable',
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  ResponsiveHelper.vGap(context, 8),
                  Text(
                    'Unable to initialize payment service. Please check your internet connection and try again.',
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  ResponsiveHelper.vGap(context, 24),
                  ElevatedButton(
                    onPressed: () => Get.offAllNamed(Routes.DASHBOARD),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: ResponsiveHelper.padding(
                        context,
                        horizontal: 32,
                        vertical: 12,
                      ),
                    ),
                    child: Text(
                      'Go Back',
                      style: ResponsiveHelper.textStyle(context, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // IAP service is available
    final iapService = _iapService!;

    return Obx(() {
      if (iapService.premiumActive.value && !_premiumCloseScheduled) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _schedulePremiumSuccessClose();
        });
      }

      if (_processingOverlayVisible &&
          !_premiumCloseScheduled &&
          iapService.errorMessage.isNotEmpty &&
          !iapService.premiumActive.value) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _processingOverlayVisible) _hideProcessingOverlay();
        });
      }

      final product = iapService.products.isNotEmpty ? iapService.products.first : null;
      final displayPrice = product?.price ?? '\$0.99';
      final storeLoading = !iapService.isInitialized.value && iapService.isLoading.value;
      final productsMissing = iapService.isInitialized.value &&
          iapService.products.isEmpty &&
          !iapService.isLoading.value;

      return _PaymentShell(
        child: Stack(
          fit: StackFit.expand,
          children: [
            SafeArea(
          child: Column(
            children: [
              Padding(
                padding: ResponsiveHelper.padding(context, horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: AppTheme.textPrimary,
                        size: ResponsiveHelper.iconSize(context, mobile: 24),
                      ),
                      onPressed: _isInitializing
                          ? null
                          : () {
                              if (Get.key.currentState?.canPop() == true) {
                                Get.back();
                              } else {
                                Get.offAllNamed(Routes.DASHBOARD);
                              }
                            },
                    ),
                    Expanded(
                      child: Text(
                        'Premium Membership',
                        textAlign: TextAlign.center,
                        style: ResponsiveHelper.textStyle(
                          context,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    SizedBox(width: ResponsiveHelper.dim(context, mobile: 48)),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    ResponsiveHelper.spacing(context, 16),
                    isCompact ? ResponsiveHelper.spacing(context, 4) : ResponsiveHelper.spacing(context, 8),
                    ResponsiveHelper.spacing(context, 16),
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _HeroBanner(price: displayPrice, isCompact: isCompact),
                      SizedBox(
                        height: isCompact
                            ? ResponsiveHelper.spacing(context, 10)
                            : ResponsiveHelper.spacing(context, 14),
                      ),
                      _BenefitsCard(isCompact: isCompact),
                      SizedBox(
                        height: isCompact
                            ? ResponsiveHelper.spacing(context, 8)
                            : ResponsiveHelper.spacing(context, 12),
                      ),
                      const _TrustRow(),
                      ResponsiveHelper.vGap(context, 8),

                      if (storeLoading)
                        const _InlineStatusCard(
                          title: 'Connecting to store...',
                          subtitle: 'Fetching price and purchase options.',
                        ),

                      if (productsMissing)
                        _StoreSetupCard(
                          isAndroid: Platform.isAndroid,
                          isDebug: kDebugMode,
                          onRetry: () {
                            iapService.errorMessage.value = '';
                            iapService.initialize();
                          },
                        ),
                    ],
                  ),
                ),
              ),

              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: ResponsiveHelper.dim(context, mobile: 8),
                      offset: Offset(0, -ResponsiveHelper.dim(context, mobile: 2)),
                    ),
                  ],
                ),
                padding: ResponsiveHelper.padding(
                  context,
                  horizontal: 16,
                  vertical: 12,
                ).copyWith(bottom: ResponsiveHelper.spacing(context, 16)),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Error message with better styling - only show when not loading and after initialization
                      if (iapService.errorMessage.isNotEmpty && 
                          iapService.isInitialized.value && 
                          !iapService.isLoading.value)
                        Container(
                          padding: ResponsiveHelper.padding(context, all: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.errorColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(
                              ResponsiveHelper.borderRadius(context, mobile: 8),
                            ),
                            border: Border.all(color: AppTheme.errorColor.withOpacity(0.3)),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: AppTheme.errorColor,
                                size: ResponsiveHelper.iconSize(context, mobile: 20),
                              ),
                              ResponsiveHelper.vGap(context, 4),
                              Text(
                                iapService.errorMessage.value,
                                style: ResponsiveHelper.textStyle(
                                  context,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.errorColor,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (iapService.errorMessage.value.contains('connection') ||
                                  iapService.errorMessage.value.contains('try again'))
                                Padding(
                                  padding: EdgeInsets.only(top: ResponsiveHelper.spacing(context, 8)),
                                  child: TextButton(
                                    onPressed: () {
                                      iapService.errorMessage.value = '';
                                      iapService.loadProducts();
                                    },
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppTheme.errorColor,
                                      padding: ResponsiveHelper.padding(
                                        context,
                                        horizontal: 16,
                                        vertical: 4,
                                      ),
                                    ),
                                    child: Text(
                                      'Retry',
                                      style: ResponsiveHelper.textStyle(
                                        context,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.errorColor,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                      SizedBox(
                        width: double.infinity,
                        height: ResponsiveHelper.buttonHeight(context, mobile: 50),
                        child: ElevatedButton(
                          onPressed: _isInitializing ||
                                  iapService.products.isEmpty ||
                                  iapService.isLoading.value
                              ? null
                              : () async {
                                  iapService.errorMessage.value = '';
                                  _showProcessingOverlay('Processing your purchase...');
                                  final started = await iapService.purchasePackage(1);
                                  if (!mounted) return;
                                  if (!started) {
                                    _hideProcessingOverlay();
                                    if (iapService.errorMessage.isNotEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(iapService.errorMessage.value),
                                          behavior: SnackBarBehavior.floating,
                                          backgroundColor: AppTheme.primaryColor,
                                          duration: const Duration(seconds: 4),
                                        ),
                                      );
                                    }
                                  } else {
                                    setState(() {
                                      _processingOverlayMessage =
                                          'Waiting for store confirmation...';
                                    });
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppTheme.primaryColor.withOpacity(0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                ResponsiveHelper.borderRadius(context, mobile: 14),
                              ),
                            ),
                            elevation: 2,
                          ),
                          child: iapService.isLoading.value
                              ? SizedBox(
                                  width: ResponsiveHelper.dim(context, mobile: 20),
                                  height: ResponsiveHelper.dim(context, mobile: 20),
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  iapService.products.isEmpty
                                      ? (storeLoading ? 'Loading price...' : 'Waiting for store...')
                                      : 'Unlock Lifetime Premium – $displayPrice',
                                  style: ResponsiveHelper.textStyle(
                                    context,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                      ResponsiveHelper.vGap(context, 4),

                      Center(
                        child: TextButton.icon(
                          onPressed: _isInitializing || iapService.isLoading.value
                              ? null
                              : () => _handleRestorePurchases(iapService),
                          icon: Icon(
                            Icons.restore_rounded,
                            size: ResponsiveHelper.iconSize(context, mobile: 18),
                          ),
                          label: Text(
                            'Restore Purchases',
                            style: ResponsiveHelper.textStyle(
                              context,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.primaryColor,
                            padding: ResponsiveHelper.padding(
                              context,
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ),
                      Center(
                        child: TextButton(
                          onPressed: _isInitializing || iapService.isLoading.value
                              ? null
                              : () {
                                  if (Get.key.currentState?.canPop() == true) {
                                    Get.back();
                                  } else {
                                    Get.offAllNamed(Routes.DASHBOARD);
                                  }
                                },
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.textSecondary,
                            padding: ResponsiveHelper.padding(
                              context,
                              horizontal: 32,
                              vertical: 8,
                            ),
                          ),
                          child: Text(
                            'Maybe later',
                            style: ResponsiveHelper.textStyle(
                              context,
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
            if (_processingOverlayVisible || _isInitializing)
              _ProcessingOverlay(message: _processingOverlayMessage),
          ],
        ),
      );
    });
  }
}

/// Light transparent overlay — payment page stays visible underneath.
class _ProcessingOverlay extends StatelessWidget {
  final String message;
  const _ProcessingOverlay({required this.message});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AbsorbPointer(
        child: ColoredBox(
          color: Colors.black.withOpacity(0.22),
          child: Center(
            child: Container(
              margin: ResponsiveHelper.padding(context, horizontal: 32),
              padding: ResponsiveHelper.padding(
                context,
                horizontal: 24,
                vertical: 22,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.96),
                borderRadius: BorderRadius.circular(
                  ResponsiveHelper.borderRadius(context, mobile: 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: ResponsiveHelper.dim(context, mobile: 20),
                    offset: Offset(0, ResponsiveHelper.dim(context, mobile: 8)),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: ResponsiveHelper.dim(context, mobile: 32),
                    height: ResponsiveHelper.dim(context, mobile: 32),
                    child: const CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  ResponsiveHelper.vGap(context, 16),
                  Text(
                    message,
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  ResponsiveHelper.vGap(context, 6),
                  Text(
                    'Please wait',
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentShell extends StatelessWidget {
  final Widget child;
  const _PaymentShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.themeColor,
      body: ResponsiveHelper.constrainedContent(
        context: context,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFEFAE2), Color(0xFFF5F0D8)],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _InlineStatusCard extends StatelessWidget {
  final String title;
  final String subtitle;
  const _InlineStatusCard({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: ResponsiveHelper.spacing(context, 8)),
      padding: ResponsiveHelper.padding(context, all: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: ResponsiveHelper.dim(context, mobile: 22),
            height: ResponsiveHelper.dim(context, mobile: 22),
            child: const CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
          ),
          ResponsiveHelper.hGap(context, 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: ResponsiveHelper.textStyle(
                    context,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: ResponsiveHelper.textStyle(
                    context,
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreSetupCard extends StatelessWidget {
  final bool isAndroid;
  final bool isDebug;
  final VoidCallback onRetry;
  const _StoreSetupCard({
    required this.isAndroid,
    required this.isDebug,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final String body = isAndroid
        ? (isDebug
            ? 'Debug APK se sideload karne par Play Billing products nahi aate. '
              'App ko Play Console par Internal Testing track me upload karo, '
              'product `com.fruitsofspirit.android.premium` active karo, '
              'aur apna Gmail License Tester me add karo. Public Play Store zaroori nahi.'
            : 'Google Play se install karo aur product Play Console me active hona chahiye.')
        : (isDebug
            ? 'iOS Simulator par real purchase nahi hota. Real device + Sandbox Apple ID ya TestFlight use karo.'
            : 'App Store product configure hona chahiye.');

    return Container(
      margin: EdgeInsets.only(top: ResponsiveHelper.spacing(context, 8)),
      padding: ResponsiveHelper.padding(context, all: 14),
      decoration: BoxDecoration(
        color: AppTheme.warningColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
        border: Border.all(color: AppTheme.warningColor.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: AppTheme.warningColor,
                size: ResponsiveHelper.iconSize(context, mobile: 20),
              ),
              ResponsiveHelper.hGap(context, 8),
              Text(
                'Store not ready yet',
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          ResponsiveHelper.vGap(context, 8),
          Text(
            body,
            style: ResponsiveHelper.textStyle(
              context,
              fontSize: 12,
              height: 1.4,
              color: AppTheme.textPrimary,
            ),
          ),
          ResponsiveHelper.vGap(context, 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onRetry,
              icon: Icon(
                Icons.refresh,
                size: ResponsiveHelper.iconSize(context, mobile: 16),
              ),
              label: Text(
                'Retry',
                style: ResponsiveHelper.textStyle(context, fontSize: 13),
              ),
              style: TextButton.styleFrom(foregroundColor: AppTheme.primaryColor),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Hero Banner
// ─────────────────────────────────────────────────────────────
class _HeroBanner extends StatelessWidget {
  final String price;
  final bool isCompact;
  const _HeroBanner({required this.price, required this.isCompact});

  @override
  Widget build(BuildContext context) {
    final iconBox = ResponsiveHelper.dim(context, mobile: isCompact ? 46 : 54);
    return Container(
      padding: EdgeInsets.all(
        isCompact ? ResponsiveHelper.spacing(context, 14) : ResponsiveHelper.spacing(context, 18),
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B4513), Color(0xFFB5651D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 18)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B4513).withOpacity(0.3),
            blurRadius: ResponsiveHelper.dim(context, mobile: 16),
            offset: Offset(0, ResponsiveHelper.dim(context, mobile: 6)),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: iconBox,
            height: iconBox,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 14)),
            ),
            child: Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: ResponsiveHelper.iconSize(context, mobile: isCompact ? 24 : 28),
            ),
          ),
          ResponsiveHelper.hGap(context, 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lifetime Premium',
                  style: ResponsiveHelper.textStyle(
                    context,
                    fontSize: isCompact ? 17 : 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ).copyWith(letterSpacing: 0.2),
                ),
                ResponsiveHelper.vGap(context, 2),
                Text(
                  'One-time purchase · Unlock everything',
                  style: ResponsiveHelper.textStyle(
                    context,
                    fontSize: isCompact ? 11 : 12,
                    color: Colors.white70,
                  ),
                ),
                SizedBox(
                  height: isCompact
                      ? ResponsiveHelper.spacing(context, 6)
                      : ResponsiveHelper.spacing(context, 8),
                ),
                Container(
                  padding: ResponsiveHelper.padding(
                    context,
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    price,
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Benefits Card
// ─────────────────────────────────────────────────────────────
class _BenefitsCard extends StatelessWidget {
  final bool isCompact;
  const _BenefitsCard({required this.isCompact});

  static const _benefits = [
    (Icons.spa_rounded,            'Personalized fruit journey'),
    (Icons.menu_book_rounded,      'Daily devotionals & reflections'),
    (Icons.notifications_rounded,  'Prayer reminders & schedules'),
    (Icons.group_rounded,          'Create & join spiritual groups'),
    (Icons.live_tv_rounded,        'Go live & watch live videos'),
    (Icons.photo_library_rounded,  'Upload & share media freely'),
    (Icons.block,                  'Ad-free experience'),
    (Icons.all_inclusive,          'One-time purchase, lifetime access'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration(
        color: Colors.white,
        borderRadius: ResponsiveHelper.borderRadius(context, mobile: 16),
        elevated: true,
      ),
      padding: EdgeInsets.all(
        isCompact ? ResponsiveHelper.spacing(context, 12) : ResponsiveHelper.spacing(context, 16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: ResponsiveHelper.padding(context, all: 6),
                decoration: BoxDecoration(
                  color: AppTheme.iconscolor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
                ),
                child: Icon(
                  Icons.stars_rounded,
                  color: AppTheme.iconscolor,
                  size: ResponsiveHelper.iconSize(context, mobile: 16),
                ),
              ),
              ResponsiveHelper.hGap(context, 8),
              Text(
                'What you get',
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(
            height: isCompact
                ? ResponsiveHelper.spacing(context, 8)
                : ResponsiveHelper.spacing(context, 12),
          ),
          ..._benefits.map((b) => _BenefitRow(icon: b.$1, label: b.$2, isCompact: isCompact)),
        ],
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isCompact;
  const _BenefitRow({required this.icon, required this.label, required this.isCompact});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: isCompact ? ResponsiveHelper.spacing(context, 3) : ResponsiveHelper.spacing(context, 4),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: ResponsiveHelper.iconSize(context, mobile: 16),
            color: AppTheme.iconscolor,
          ),
          ResponsiveHelper.hGap(context, 10),
          Expanded(
            child: Text(
              label,
              style: ResponsiveHelper.textStyle(
                context,
                fontSize: isCompact ? 12 : 13,
                color: AppTheme.textPrimary,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Trust badges row
// ─────────────────────────────────────────────────────────────
class _TrustRow extends StatelessWidget {
  const _TrustRow();

  Widget _badge(BuildContext context, IconData icon, String label) {
    return Column(
      children: [
        Icon(
          icon,
          size: ResponsiveHelper.iconSize(context, mobile: 18),
          color: AppTheme.textSecondary,
        ),
        ResponsiveHelper.vGap(context, 2),
        Text(
          label,
          style: ResponsiveHelper.textStyle(
            context,
            fontSize: 10,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _badge(context, Icons.security_rounded, 'Secure'),
        ResponsiveHelper.hGap(context, 16),
        _badge(context, Icons.refresh_rounded, 'Restorable'),
        ResponsiveHelper.hGap(context, 16),
        _badge(context, Icons.all_inclusive_rounded, 'Lifetime'),
      ],
    );
  }
}
