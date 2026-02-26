import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/services/iap_service.dart';

class PaymentScreen extends StatelessWidget {
  const PaymentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final iap = Get.find<IAPService>();
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                height: 200,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF8B7E6B), Color(0xFF5D4E3D)],
                  ),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.workspace_premium, size: 60, color: Colors.white),
                      SizedBox(height: 16),
                      Text(
                        'Fruits of Spirit Premium',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    _buildBenefit(Icons.check_circle, 'Unlimited daily devotionals'),
                    _buildBenefit(Icons.check_circle, 'Prayer group access'),
                    _buildBenefit(Icons.check_circle, 'No advertisements'),
                    _buildBenefit(Icons.check_circle, 'Premium community features'),
                    const SizedBox(height: 32),
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFD4AF37), Color(0xFF8B6914)],
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => iap.purchaseLifetime(),
                          child: const Padding(
                            padding: EdgeInsets.all(24),
                            child: Column(
                              children: [
                                Text(
                                  'LIFETIME PREMIUM',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'One-time payment',
                                  style: TextStyle(color: Colors.white70),
                                ),
                                SizedBox(height: 20),
                                SizedBox(
                                  width: double.infinity,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(color: Colors.white),
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(vertical: 14),
                                      child: Center(
                                        child: Text(
                                          'Get Lifetime Access',
                                          style: TextStyle(
                                            color: Color(0xFF8B6914),
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => iap.restorePurchases(),
                      child: const Text(
                        'Restore Purchases',
                        style: TextStyle(color: Color(0xFF8B7E6B)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefit(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF6B8E4C), size: 24),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}
