import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/services/iap_service.dart';
import 'package:fruitsofspirit/routes/routes.dart';
import 'package:fruitsofspirit/utils/app_theme.dart';

class PaymentScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final iap = Get.put(IAPService(), permanent: true);
    return Obx(() {
      if (iap.premiumActive.value) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          print('🔔 IAP: Premium active, redirecting to Dashboard...');
          await Future.delayed(const Duration(milliseconds: 400));
          Get.offAllNamed(Routes.DASHBOARD);
        });
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }
      final product = iap.products.isNotEmpty ? iap.products.first : null;
      final displayPrice = product?.price ?? '\$ 0.99';
      return Scaffold(
        backgroundColor: AppTheme.themeColor,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: AppTheme.textPrimary),
          title: const Text('Premium Membership', style: TextStyle(color: AppTheme.textPrimary)),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton.icon(
                  onPressed: (iap.products.isEmpty)
                      ? null
                      : () async {
                    if (iap.isLoading.value) return;
                    iap.errorMessage.value = '';
                    final started = await iap.purchaseLifetime();
                    if (!started) {
                      if (iap.errorMessage.isNotEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Purchase failed: ${iap.errorMessage.value}'),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      }
                      return;
                    }
                  },
                  icon: const Icon(Icons.lock_open),
                  label: iap.isLoading.value
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : Text('Unlock Lifetime Premium – $displayPrice'),
                  style: AppTheme.primaryButtonStyle().copyWith(
                    minimumSize: MaterialStateProperty.all(const Size(double.infinity, 54)),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: (iap.isLoading.value || iap.products.isEmpty)
                            ? null
                            : () async {
                          iap.errorMessage.value = '';
                          final ok = await iap.restorePurchases();
                          if (!ok && iap.errorMessage.isNotEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Restore failed: ${iap.errorMessage.value}'),
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.restore),
                        label: const Text('Restore'),
                        style: AppTheme.secondaryButtonStyle(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Get.offAllNamed(Routes.DASHBOARD),
                        style: AppTheme.secondaryButtonStyle(),
                        child: const Text('Maybe later'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // 🔴 PRODUCT LOAD STATUS - YEH ADD KIYA HAI
                _buildProductStatus(iap),
              ],
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(displayPrice),
              const SizedBox(height: 14),
              _featurePanel(),
              const SizedBox(height: 8),
              if (iap.debugMode.value) _debugPanel(iap),
            ],
          ),
        ),
      );
    });
  }

  Widget _debugPanel(IAPService iap) {
    final status = [
      'initialized: ${iap.isInitialized.value}',
      'loading: ${iap.isLoading.value}',
      'products_count: ${iap.products.length}',
      'products_from_store: ${iap.productsFromStore.value}',
      'premium_active: ${iap.premiumActive.value}',
      if (iap.errorMessage.isNotEmpty) 'error: ${iap.errorMessage.value}',
      if (iap.lastVerifyStatus.isNotEmpty) 'verify_status: ${iap.lastVerifyStatus.value}',
      if (iap.lastErrorCode.isNotEmpty) 'error_code: ${iap.lastErrorCode.value}',
      if (iap.lastErrorReason.isNotEmpty) 'error_reason: ${iap.lastErrorReason.value}',
    ];
    return Container(
      decoration: AppTheme.cardDecoration(color: Colors.white, borderRadius: 12, elevated: true),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Debug Info', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          ...status.map((s) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(s, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              )),
          const SizedBox(height: 8),
          if (iap.lastVerifyBody.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Server Response', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Text(
                    iap.lastVerifyBody.value.length > 800
                        ? iap.lastVerifyBody.value.substring(0, 800) + '...'
                        : iap.lastVerifyBody.value,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: iap.lastVerifyBody.value));
                        Get.snackbar('Copied', 'Server response copied to clipboard');
                      },
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copy', style: TextStyle(fontSize: 12)),
                      style: AppTheme.secondaryButtonStyle(),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await iap.runSelfTest();
                      },
                      icon: const Icon(Icons.bug_report, size: 16),
                      label: const Text('Self Test', style: TextStyle(fontSize: 12)),
                      style: AppTheme.secondaryButtonStyle(),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  // 🔴 NAYA FUNCTION - PRODUCT LOAD STATUS DIKHAYEGA
  Widget _buildProductStatus(IAPService iap) {
    if (iap.isLoading.value) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            SizedBox(
              width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text('Loading products...', style: TextStyle(color: Colors.blue, fontSize: 12)),
          ],
        ),
      );
    } else if (iap.products.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 14),
            const SizedBox(width: 6),
            Text(
              '✅ Product Loaded: ${iap.products.first.price}',
              style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber, color: Colors.orange, size: 14),
            const SizedBox(width: 6),
            Text(
              '⚠️ Using test product',
              style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }
  }

  Widget _benefit(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppTheme.successColor, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _section(String title, List<String> items) {
    return Container(
      decoration: AppTheme.cardDecoration(color: Colors.white, borderRadius: 12, elevated: true),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          ...items.map(_benefit).toList(),
        ],
      ),
    );
  }

  Widget _header(String price) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withOpacity(0.95),
            AppTheme.primaryColor.withOpacity(0.75),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.stars, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Lifetime Premium', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(price, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _featurePanel() {
    return Container(
      decoration: AppTheme.cardDecoration(color: Colors.white, borderRadius: 16, elevated: true),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('You will get', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const SizedBox(height: 10),
          _group('Fruits of the Spirit', [
            'Personalized fruit journey',
            'Daily reflections & growth tracking',
            'Curated devotionals & scriptures',
          ]),
          const SizedBox(height: 10),
          _group('Spiritual Tools', [
            'Prayer reminders & schedules',
            'Scripture cards & inspirations',
            'Saved content library',
          ]),
          const SizedBox(height: 10),
          _group('Community & Media', [
            'Create & join groups',
            'Go live and watch live videos',
            'Upload & share media',
          ]),
          const SizedBox(height: 10),
          _group('Premium Perks', [
            'Ad‑free experience',
            'Priority support & early features',
            'One‑time purchase, lifetime access',
          ]),
        ],
      ),
    );
  }

  Widget _group(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        const SizedBox(height: 6),
        ...items.map(_benefit).toList(),
      ],
    );
  }
}
