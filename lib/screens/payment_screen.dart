import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/services/iap_service.dart';
import 'package:fruitsofspirit/routes/routes.dart';

class PaymentScreen extends StatelessWidget {
  final IAPService _iapService = Get.find<IAPService>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Premium Membership'),
      ),
      body: Obx(() => Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Product Card
            Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(Icons.stars, size: 80, color: Colors.amber),
                    SizedBox(height: 10),
                    Text(
                      'Lifetime Premium',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 5),
                    Text(
                      '₹ 800',
                      style: TextStyle(fontSize: 20, color: Colors.green),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),

            // Loading Indicator
            if (_iapService.isLoading.value)
              CircularProgressIndicator(),

            // Error Message
            if (_iapService.errorMessage.isNotEmpty)
              Container(
                padding: EdgeInsets.all(10),
                color: Colors.red.shade100,
                child: Text(
                  _iapService.errorMessage.value,
                  style: TextStyle(color: Colors.red),
                ),
              ),

            SizedBox(height: 20),

            // Purchase Button
            ElevatedButton(
              onPressed: _iapService.isLoading.value
                  ? null
                  : () async {
                final success = await _iapService.purchaseLifetime();
                if (success) {
                  // Success message
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ Premium Activated Successfully!'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );

                  // 2 seconds baad home screen par le jao
                  Future.delayed(Duration(seconds: 2), () {
                    Get.offAllNamed(Routes.HOME);
                  });
                }
              },
              child: Text('Purchase Lifetime Access'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
              ),
            ),

            SizedBox(height: 10),

            // Restore Button
            TextButton(
              onPressed: _iapService.isLoading.value
                  ? null
                  : () => _iapService.restorePurchases(),
              child: Text('Restore Purchases'),
            ),
          ],
        ),
      )),
    );
  }
}