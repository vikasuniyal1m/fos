import 'package:get/get.dart';
import 'package:fruitsofspirit/services/banners_service.dart';
import 'dart:async';

/// Banners Controller
/// Manages banner data for the homepage carousel
class BannersController extends GetxController {
  var activeBanners = <Map<String, dynamic>>[].obs;
  var upcomingBanners = <Map<String, dynamic>>[].obs;
  var isLoading = false.obs;
  var currentBannerIndex = 0.obs;
  var countdownText = ''.obs;
  var countdownData = <String, dynamic>{}.obs;
  Timer? _countdownTimer;

  @override
  void onInit() {
    super.onInit();
    loadBanners();
  }

  @override
  void onClose() {
    _countdownTimer?.cancel();
    super.onClose();
  }

  /// Load banners from API
  Future<void> loadBanners() async {
    if (isLoading.value) return;
    isLoading.value = true;
    print('🎯 BannersController: Loading banners...');
    try {
      final result = await BannersService.getBanners();
      print('🎯 BannersController: API Result: $result');
      
      // Safely cast lists to Map<String, dynamic>
      final activeList = result['active_banners'] as List<dynamic>? ?? [];
      final upcomingList = result['upcoming_banners'] as List<dynamic>? ?? [];
      
      activeBanners.value = activeList.cast<Map<String, dynamic>>();
      upcomingBanners.value = upcomingList.cast<Map<String, dynamic>>();
      countdownData.value = result['countdown'] as Map<String, dynamic>? ?? {};
      
      print('🎯 BannersController: Active banners loaded: ${activeBanners.length}');
      print('🎯 BannersController: Upcoming banners loaded: ${upcomingBanners.length}');
      print('🎯 BannersController: Countdown data: ${countdownData.value}');
      _startCountdown();
    } catch (e) {
      print('❌ BannersController Error: $e');
      print('❌ BannersController Stack trace: ${StackTrace.current}');
      // Don't set empty lists on error - keep existing banners
      // Retry immediately if empty
      if (activeBanners.isEmpty && upcomingBanners.isEmpty) {
        print('🔄 BannersController: Retrying immediately...');
        isLoading.value = false; // Reset to allow retry
        await loadBanners();
        return;
      }
    } finally {
      isLoading.value = false;
      print('🎯 BannersController: Loading complete');
    }
  }

  /// Refresh banners
  Future<void> refreshBanners() async {
    isLoading.value = false; // Reset to allow reload
    await loadBanners();
  }

  /// Update current banner index (for dot indicator)
  void updateBannerIndex(int index) {
    currentBannerIndex.value = index;
  }

  /// Start countdown timer for next upcoming banner
  void _startCountdown() {
    _countdownTimer?.cancel();
    if (upcomingBanners.isEmpty || countdownData.isEmpty) {
      countdownText.value = '';
      return;
    }

    // Use countdown data from API
    final totalSeconds = countdownData['total_seconds'] as int? ?? 0;
    if (totalSeconds <= 0) {
      countdownText.value = '';
      return;
    }

    _updateCountdownFromData(totalSeconds);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final currentSeconds = countdownData['total_seconds'] as int? ?? 0;
      if (currentSeconds > 0) {
        countdownData['total_seconds'] = currentSeconds - 1;
        _updateCountdownFromData(currentSeconds - 1);
      } else {
        countdownText.value = '';
        _countdownTimer?.cancel();
        loadBanners();
      }
    });
  }

  void _updateCountdownFromData(int totalSeconds) {
    if (totalSeconds <= 0) {
      countdownText.value = '';
      return;
    }

    final days = totalSeconds ~/ 86400;
    final hours = (totalSeconds % 86400) ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (days > 0) {
      countdownText.value = '${days}d ${hours}h ${minutes}m';
    } else if (hours > 0) {
      countdownText.value = '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      countdownText.value = '${minutes}m ${seconds}s';
    } else {
      countdownText.value = '${seconds}s';
    }
  }
}
