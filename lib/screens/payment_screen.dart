import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/services/iap_service.dart';
import 'package:fruitsofspirit/routes/routes.dart';
import 'package:fruitsofspirit/utils/app_theme.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({Key? key}) : super(key: key);

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  IAPService? _iapService;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initializeIAP();
  }

  Future<void> _initializeIAP() async {
    try {
      if (Get.isRegistered<IAPService>()) {
        _iapService = Get.find<IAPService>();
      } else {
        // Register IAP service if not already registered
        _iapService = Get.put(IAPService(), permanent: true);
        await _iapService!.initialize();
      }
    } catch (e) {
      debugPrint('Error accessing IAP service: $e');
      // Try to register and initialize as fallback
      try {
        _iapService = Get.put(IAPService(), permanent: true);
        await _iapService!.initialize();
      } catch (e2) {
        debugPrint('Fallback IAP initialization failed: $e2');
      }
    }
    setState(() {
      _isInitializing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 700;

    // Show loading during initialization
    if (_isInitializing) {
      return Scaffold(
        backgroundColor: AppTheme.themeColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: AppTheme.primaryColor),
              const SizedBox(height: 16),
              Text(
                'Loading premium options...',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    // If IAP service is not available, show error
    if (_iapService == null) {
      return Scaffold(
        backgroundColor: AppTheme.themeColor,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: AppTheme.errorColor,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Payment Service Unavailable',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Unable to initialize payment service. Please check your internet connection and try again.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Get.offAllNamed(Routes.DASHBOARD),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    ),
                    child: const Text('Go Back'),
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
      // Show loading state while initializing
      if (!iapService.isInitialized.value && iapService.isLoading.value) {
        return Scaffold(
          backgroundColor: AppTheme.themeColor,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: AppTheme.primaryColor),
                const SizedBox(height: 16),
                Text(
                  'Loading premium options...',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                ),
              ],
            ),
          ),
        );
      }

      // Auto-redirect when premium activates with success message
      if (iapService.premiumActive.value) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          // Show success message first
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('🎉 Premium activated successfully! Enjoy all premium features.'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
          
          // Then redirect after delay
          await Future.delayed(const Duration(milliseconds: 2000));
          Get.offAllNamed(Routes.DASHBOARD);
        });
        return const Scaffold(
          backgroundColor: AppTheme.themeColor,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: AppTheme.primaryColor),
                SizedBox(height: 16),
                Text(
                  'Activating Premium...',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                ),
              ],
            ),
          ),
        );
      }

      final product = iapService.products.isNotEmpty ? iapService.products.first : null;
      final displayPrice = product?.price ?? '\$0.99';

      return Scaffold(
        backgroundColor: AppTheme.themeColor,
        body: SafeArea(
          child: Column(
            children: [
              // ── Top Bar ──────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: AppTheme.textPrimary),
                      onPressed: () => Get.offAllNamed(Routes.DASHBOARD),
                    ),
                    const Expanded(
                      child: Text(
                        'Premium Membership',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48), // balance close button
                  ],
                ),
              ),

              // ── Scrollable Body ───────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(16, isSmall ? 4 : 8, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Hero Banner
                      _HeroBanner(price: displayPrice, isSmall: isSmall),
                      SizedBox(height: isSmall ? 10 : 14),

                      // Benefits grid  
                      _BenefitsCard(isSmall: isSmall),
                      SizedBox(height: isSmall ? 8 : 12),

                      // Trust badges
                      const _TrustRow(),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),

              // ── Bottom CTA ────────────────────────────────
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))],
                ),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.errorColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.errorColor.withOpacity(0.3)),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: AppTheme.errorColor,
                                size: 20,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                iapService.errorMessage.value,
                                style: const TextStyle(
                                  color: AppTheme.errorColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              // Add retry button for connection errors
                              if (iapService.errorMessage.value.contains('connection') ||
                                  iapService.errorMessage.value.contains('try again'))
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: TextButton(
                                    onPressed: () {
                                      iapService.errorMessage.value = '';
                                      iapService.loadProducts();
                                    },
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppTheme.errorColor,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                    ),
                                    child: const Text(
                                      'Retry',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                      // Purchase button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: iapService.products.isEmpty || iapService.isLoading.value
                              ? null
                              : () async {
                                  iapService.errorMessage.value = '';
                                  final started = await iapService.purchasePackage(1);
                                  if (!started && iapService.errorMessage.isNotEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(iapService.errorMessage.value),
                                        behavior: SnackBarBehavior.floating,
                                        backgroundColor: AppTheme.primaryColor,
                                        duration: const Duration(seconds: 4),
                                      ),
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppTheme.primaryColor.withOpacity(0.4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 2,
                          ),
                          child: iapService.isLoading.value
                              ? const SizedBox(
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Text(
                                  iapService.products.isEmpty || iapService.errorMessage.isNotEmpty
                                      ? 'Loading...'
                                      : 'Unlock Lifetime Premium – $displayPrice',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Skip button only - restore button hidden after purchase
                      Center(
                        child: TextButton(
                          onPressed: () => Get.offAllNamed(Routes.DASHBOARD),
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.textSecondary,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                          ),
                          child: const Text('Maybe later', style: TextStyle(fontSize: 13)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────
// Hero Banner
// ─────────────────────────────────────────────────────────────
class _HeroBanner extends StatelessWidget {
  final String price;
  final bool isSmall;
  const _HeroBanner({required this.price, required this.isSmall});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isSmall ? 14 : 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B4513), Color(0xFFB5651D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B4513).withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: isSmall ? 46 : 54,
            height: isSmall ? 46 : 54,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.auto_awesome, color: Colors.white, size: isSmall ? 24 : 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lifetime Premium',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isSmall ? 17 : 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'One-time purchase · Unlock everything',
                  style: TextStyle(color: Colors.white70, fontSize: isSmall ? 11 : 12),
                ),
                SizedBox(height: isSmall ? 6 : 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    price,
                    style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
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
  final bool isSmall;
  const _BenefitsCard({required this.isSmall});

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
      decoration: AppTheme.cardDecoration(color: Colors.white, borderRadius: 16, elevated: true),
      padding: EdgeInsets.all(isSmall ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.iconscolor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.stars_rounded, color: AppTheme.iconscolor, size: 16),
              ),
              const SizedBox(width: 8),
              const Text(
                'What you get',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
              ),
            ],
          ),
          SizedBox(height: isSmall ? 8 : 12),
          ..._benefits.map((b) => _BenefitRow(icon: b.$1, label: b.$2, isSmall: isSmall)),
        ],
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSmall;
  const _BenefitRow({required this.icon, required this.label, required this.isSmall});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isSmall ? 3 : 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.iconscolor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: isSmall ? 12 : 13, color: AppTheme.textPrimary, height: 1.3),
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

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _badge(Icons.security_rounded, 'Secure'),
        const SizedBox(width: 16),
        _badge(Icons.refresh_rounded, 'Restorable'),
        const SizedBox(width: 16),
        _badge(Icons.all_inclusive_rounded, 'Lifetime'),
      ],
    );
  }

  Widget _badge(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, size: 18, color: AppTheme.textSecondary),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
      ],
    );
  }
}
