import 'dart:async';
import 'package:get/get.dart';
import 'package:fruitsofspirit/services/denominations_service.dart';
import 'package:fruitsofspirit/services/hive_cache_service.dart';

class DenominationsController extends GetxController {
  var isLoading = false.obs;
  var denominations = <Map<String, dynamic>>[].obs;
  var filteredDenominations = <Map<String, dynamic>>[].obs;

  var _allDenominations = <Map<String, dynamic>>[];
  var _isSyncing = false;
  var _isDataLoaded = false;
  DateTime? _lastSyncedAt;
  String _searchQuery = '';

  static const Duration _minSyncInterval = Duration(minutes: 30);
  static const String _hiveKey = 'denominations_list';

  @override
  void onInit() {
    super.onInit();
    bootstrapDenominations();
    unawaited(loadDenominations(silent: _allDenominations.isNotEmpty));
  }

  /// Hive first — instant list (feeling / blogs pattern).
  void bootstrapDenominations() {
    if (_allDenominations.isNotEmpty) return;

    final cached = HiveCacheService.getCachedList(_hiveKey);
    if (cached.isEmpty) return;

    _allDenominations = List<Map<String, dynamic>>.from(cached);
    _isDataLoaded = true;
    denominations.assignAll(_allDenominations);
    _applyFilter(_searchQuery);
  }

  Future<void> loadDenominations({bool silent = false, bool force = false}) async {
    if (silent &&
        !force &&
        _lastSyncedAt != null &&
        DateTime.now().difference(_lastSyncedAt!) < _minSyncInterval) {
      return;
    }
    if (_isSyncing) return;
    _isSyncing = true;

    if (!silent && _allDenominations.isEmpty) {
      isLoading.value = true;
    }

    try {
      final result = await DenominationsService.getAllDenominations();
      if (_allDenominations.isEmpty) {
        _setDenominations(result);
      } else if (!_listsEqual(_allDenominations, result)) {
        _mergeDenominations(result);
      }
      _isDataLoaded = true;
      _lastSyncedAt = DateTime.now();
      unawaited(_cacheDenominations());
    } catch (e) {
      if (!silent && _allDenominations.isEmpty) {
        Get.snackbar(
          'Error',
          'Failed to load denominations: $e',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } finally {
      isLoading.value = false;
      _isSyncing = false;
    }
  }

  Future<void> refresh() async {
    await loadDenominations(silent: false, force: true);
  }

  void filterDenominations(String query) {
    _searchQuery = query.trim();
    _applyFilter(_searchQuery);
  }

  void _setDenominations(List<Map<String, dynamic>> items) {
    _allDenominations = List<Map<String, dynamic>>.from(items);
    denominations.assignAll(_allDenominations);
    _applyFilter(_searchQuery);
  }

  void _mergeDenominations(List<Map<String, dynamic>> incoming) {
    if (incoming.isEmpty) return;

    final indexByKey = <String, int>{};
    for (var i = 0; i < _allDenominations.length; i++) {
      final key = _itemKey(_allDenominations[i]);
      if (key != null) indexByKey[key] = i;
    }

    var changed = false;
    for (final remote in incoming) {
      final key = _itemKey(remote);
      if (key == null) continue;

      final idx = indexByKey[key];
      if (idx != null) {
        if (!_itemEqual(_allDenominations[idx], remote)) {
          _allDenominations[idx] = {
            ..._allDenominations[idx],
            ...remote,
          };
          changed = true;
        }
      } else {
        _allDenominations.add(Map<String, dynamic>.from(remote));
        changed = true;
      }
    }

    if (changed) {
      denominations.assignAll(_allDenominations);
      _applyFilter(_searchQuery);
    }
  }

  void _applyFilter(String query) {
    if (query.isEmpty) {
      filteredDenominations.assignAll(_allDenominations);
      return;
    }

    final q = query.toLowerCase();
    filteredDenominations.assignAll(
      _allDenominations.where((d) {
        final name = d['name']?.toString().toLowerCase() ?? '';
        final description = d['description']?.toString().toLowerCase() ?? '';
        return name.contains(q) || description.contains(q);
      }),
    );
  }

  String? _itemKey(Map<String, dynamic> item) {
    final id = item['id'];
    if (id != null) return id.toString();
    final name = item['name']?.toString().trim();
    if (name != null && name.isNotEmpty) return name.toLowerCase();
    return null;
  }

  bool _listsEqual(
    List<Map<String, dynamic>> previous,
    List<Map<String, dynamic>> next,
  ) {
    if (previous.length != next.length) return false;
    for (var i = 0; i < previous.length; i++) {
      if (!_itemEqual(previous[i], next[i])) return false;
    }
    return true;
  }

  bool _itemEqual(Map<String, dynamic> a, Map<String, dynamic> b) {
    return a['id'] == b['id'] &&
        a['name'] == b['name'] &&
        a['description'] == b['description'] &&
        a['website_url'] == b['website_url'] &&
        a['updated_at'] == b['updated_at'];
  }

  Future<void> _cacheDenominations() async {
    if (_allDenominations.isEmpty) return;
    await HiveCacheService.cacheList(
      _hiveKey,
      List<Map<String, dynamic>>.from(_allDenominations),
      expiryHours: 72,
    );
  }

  bool get hasCachedData => _isDataLoaded && _allDenominations.isNotEmpty;
}
