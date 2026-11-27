import 'package:get/get.dart';
import 'package:fruitsofspirit/services/banners_prefetch_service.dart';
import 'package:fruitsofspirit/services/banners_service.dart';
import 'package:fruitsofspirit/services/hive_cache_service.dart';
import 'dart:async';

/// Banners Controller — cache-first, silent background sync (no flicker).
class BannersController extends GetxController {
  static const String _cacheKey = 'home_banners';

  var activeBanners = <Map<String, dynamic>>[].obs;
  var upcomingBanners = <Map<String, dynamic>>[].obs;
  var isLoading = false.obs;
  var hasInitialLoad = false.obs;
  var currentBannerIndex = 0.obs;
  var countdownText = ''.obs;
  var countdownData = <String, dynamic>{}.obs;

  Timer? _countdownTimer;
  DateTime? _lastSyncedAt;
  bool _countdownReloadPending = false;
  static const Duration _minSyncInterval = Duration(minutes: 2);

  @override
  void onInit() {
    super.onInit();
    bootstrapBanners();
    unawaited(_initBanners());
  }

  Future<void> _initBanners() async {
    await BannersPrefetchService.warmCache();
    bootstrapBanners();
    await loadBanners(
      silent: hasInitialLoad.value,
      force: !hasInitialLoad.value,
    );
  }

  @override
  void onClose() {
    _countdownTimer?.cancel();
    super.onClose();
  }

  void bootstrapBanners() {
    final cached = HiveCacheService.getCachedMap(_cacheKey);
    if (cached.isEmpty) return;
    ingestCachedBanners(cached);
  }

  /// Apply hive / prefetch payload without toggling loading UI.
  void ingestCachedBanners(Map<String, dynamic> cached) {
    final active = cached['active_banners'];
    final upcoming = cached['upcoming_banners'];
    if (active is List && active.isNotEmpty) {
      activeBanners.value = List<Map<String, dynamic>>.from(
        active.cast<Map<String, dynamic>>(),
      );
    }
    if (upcoming is List && upcoming.isNotEmpty) {
      upcomingBanners.value = List<Map<String, dynamic>>.from(
        upcoming.cast<Map<String, dynamic>>(),
      );
    }
    final countdown = cached['countdown'];
    if (countdown is Map) {
      countdownData.value = Map<String, dynamic>.from(countdown);
    }
    if (activeBanners.isNotEmpty || upcomingBanners.isNotEmpty) {
      hasInitialLoad.value = true;
      _startCountdown();
    }
  }

  bool _sameBannerLists(
    List<Map<String, dynamic>> a,
    List<Map<String, dynamic>> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i]['id']?.toString() != b[i]['id']?.toString()) return false;
      if (a[i]['file_path'] != b[i]['file_path']) return false;
      if (a[i]['updated_at'] != b[i]['updated_at']) return false;
    }
    return true;
  }

  Future<void> _persistBanners(Map<String, dynamic> result) async {
    await HiveCacheService.cacheMap(_cacheKey, {
      'active_banners': result['active_banners'] ?? activeBanners.toList(),
      'upcoming_banners': result['upcoming_banners'] ?? upcomingBanners.toList(),
      'countdown': result['countdown'] ?? countdownData,
    }, expiryHours: 12);
  }

  /// Load banners from API (silent = no loading flag, skip if data unchanged).
  Future<void> loadBanners({bool silent = false, bool force = false}) async {
    if (isLoading.value && !force) return;
    if (silent &&
        !force &&
        _lastSyncedAt != null &&
        DateTime.now().difference(_lastSyncedAt!) < _minSyncInterval) {
      return;
    }

    if (!silent && !hasInitialLoad.value) {
      isLoading.value = true;
    }

    try {
      final result = await BannersService.getBanners();

      final activeList = (result['active_banners'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      final upcomingList = (result['upcoming_banners'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      final newCountdown =
          result['countdown'] as Map<String, dynamic>? ?? <String, dynamic>{};

      final activeChanged = !_sameBannerLists(activeBanners, activeList);
      final upcomingChanged = !_sameBannerLists(upcomingBanners, upcomingList);

      if (activeChanged) activeBanners.value = activeList;
      if (upcomingChanged) upcomingBanners.value = upcomingList;
      if (newCountdown.isNotEmpty) {
        countdownData.value = Map<String, dynamic>.from(newCountdown);
      }

      hasInitialLoad.value = true;
      _lastSyncedAt = DateTime.now();
      await _persistBanners(result);

      if (activeChanged || upcomingChanged || newCountdown.isNotEmpty) {
        _startCountdown();
      }
    } catch (e) {
      if (activeBanners.isEmpty && upcomingBanners.isEmpty) {
        bootstrapBanners();
        Future.delayed(const Duration(seconds: 3), () {
          if (activeBanners.isEmpty && upcomingBanners.isEmpty) {
            loadBanners(silent: true, force: true);
          }
        });
      }
    } finally {
      isLoading.value = false;
      if (activeBanners.isNotEmpty || upcomingBanners.isNotEmpty) {
        hasInitialLoad.value = true;
      }
    }
  }

  Future<void> refreshBanners() async {
    await loadBanners(silent: hasInitialLoad.value, force: true);
  }

  void updateBannerIndex(int index) {
    currentBannerIndex.value = index;
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    if (upcomingBanners.isEmpty || countdownData.isEmpty) {
      countdownText.value = '';
      return;
    }

    final totalSeconds = countdownData['total_seconds'] as int? ?? 0;
    if (totalSeconds <= 0) {
      countdownText.value = '';
      return;
    }

    _updateCountdownFromData(totalSeconds);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final currentSeconds = countdownData['total_seconds'] as int? ?? 0;
      if (currentSeconds > 1) {
        countdownData['total_seconds'] = currentSeconds - 1;
        _updateCountdownFromData(currentSeconds - 1);
      } else {
        countdownText.value = '';
        timer.cancel();
        if (!_countdownReloadPending) {
          _countdownReloadPending = true;
          loadBanners(silent: true, force: true).whenComplete(() {
            _countdownReloadPending = false;
          });
        }
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
