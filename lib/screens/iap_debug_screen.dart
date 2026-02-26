// screens/iap_debug_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/services/iap_service.dart';

class IAPDebugScreen extends StatelessWidget {
  final IAPService _iapService = Get.find<IAPService>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('IAP Debug'),
      ),
      body: Obx(() => ListView(
        padding: EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Status:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Initialized: ${_iapService.isInitialized.value}'),
                  Text('Loading: ${_iapService.isLoading.value}'),
                  Text('Error: ${_iapService.errorMessage.value}'),
                  SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => _iapService.initialize(),
                    child: Text('Re-initialize IAP'),
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Products:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ..._iapService.products.map((p) => Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text('${p.id} - ${p.price}'),
                  )),
                  if (_iapService.products.isEmpty)
                    Text('No products loaded'),
                  SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => _iapService.loadProducts(),
                    child: Text('Reload Products'),
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  ElevatedButton(
                    onPressed: () => _iapService.purchaseLifetime(),
                    child: Text('Test Purchase'),
                  ),
                  SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => _iapService.restorePurchases(),
                    child: Text('Test Restore'),
                  ),
                ],
              ),
            ),
          ),
        ],
      )),
    );
  }
}