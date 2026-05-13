import 'package:get/get.dart';
import 'package:fruitsofspirit/services/denominations_service.dart';

class DenominationsController extends GetxController {
  var isLoading = true.obs;
  var isLoadingMore = false.obs;
  var denominations = <Map<String, dynamic>>[].obs;
  var filteredDenominations = <Map<String, dynamic>>[].obs;
  var allDenominations = <Map<String, dynamic>>[];

  @override
  void onInit() {
    super.onInit();
    fetchDenominations();
  }

  void fetchDenominations() async {
    try {
      isLoading(true);
      var result = await DenominationsService.getAllDenominations();
      allDenominations = result;
      denominations.assignAll(result);

      // Show first 5 immediately for quick response
      filteredDenominations.assignAll(result.take(5).toList());
      print('DEBUG: [Denominations] Loaded first ${filteredDenominations.length} denominations quickly');

      isLoading(false);

      // Load remaining in batches for smoothness
      await _loadRemainingBatches(result);
    } catch (e) {
      Get.snackbar('Error', 'Failed to load denominations: $e',
          snackPosition: SnackPosition.BOTTOM);
      isLoading(false);
    }
  }

  Future<void> _loadRemainingBatches(List<Map<String, dynamic>> allItems) async {
    if (allItems.length <= 5) return;

    isLoadingMore(true);
    final remaining = allItems.skip(5).toList();

    // Load in batches of 8 with 150ms delay
    for (int i = 0; i < remaining.length; i += 8) {
      final batch = remaining.skip(i).take(8).toList();
      await Future.delayed(const Duration(milliseconds: 150));

      // Add to filtered list
      filteredDenominations.addAll(batch);
      print('DEBUG: [Denominations] Loaded batch ${i ~/ 8 + 1}, total: ${filteredDenominations.length}');
    }

    isLoadingMore(false);
    print('DEBUG: [Denominations] All ${allItems.length} denominations loaded');
  }

  void filterDenominations(String query) {
    if (query.isEmpty) {
      // Reset to show all with incremental loading
      filteredDenominations.assignAll(allDenominations.take(5).toList());
      _loadRemainingBatches(allDenominations);
    } else {
      // For search, show filtered results immediately
      final filtered = allDenominations.where((d) =>
          d['name'].toString().toLowerCase().contains(query.toLowerCase())).toList();
      filteredDenominations.assignAll(filtered);
    }
  }
}
