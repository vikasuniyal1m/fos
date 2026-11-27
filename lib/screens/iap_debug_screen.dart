import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/services/iap_service.dart';

class IAPDebugScreen extends StatelessWidget {
  final IAPService _iapService = Get.find<IAPService>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('IAP Status'),
      ),
      body: Obx(() => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Status', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Initialized: ${_iapService.isInitialized}'),
                  Text('Loading: ${_iapService.isLoading}'),
                  Text('Premium Active: ${_iapService.premiumActive.value}'),
                  if (_iapService.errorMessage.isNotEmpty)
                    Text('Error: ${_iapService.errorMessage.value}',
                        style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => _iapService.initialize(),
                    child: const Text('Re-initialize IAP'),
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Products', style: TextStyle(fontWeight: FontWeight.bold)),
                  ..._iapService.products.map((p) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text('${p.id} — ${p.price}'),
                  )),
                  if (_iapService.products.isEmpty)
                    const Text('No products loaded'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => _iapService.loadProducts(),
                    child: const Text('Reload Products'),
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ElevatedButton(
                    onPressed: () => _iapService.purchasePackage(1),
                    child: const Text('Purchase'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => _iapService.restorePurchases(),
                    child: const Text('Restore Purchases'),
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