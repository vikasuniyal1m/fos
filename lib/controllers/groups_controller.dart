import 'dart:async';
import 'dart:io';
import 'package:get/get.dart';
import 'package:fruitsofspirit/services/hive_cache_service.dart';
import 'package:fruitsofspirit/services/groups_service.dart';
import 'package:fruitsofspirit/services/user_storage.dart';
import 'package:fruitsofspirit/services/api_service.dart';
import 'package:fruitsofspirit/services/jingle_service.dart';

import '../controllers/home_controller.dart';

/// Groups Controller
/// Manages groups data and operations
class GroupsController extends GetxController {
  // Observable variables
  var isLoading = false.obs;
  var isCreatingGroup = false.obs;
  var message = ''.obs;
  
  // Data
  var groups = <Map<String, dynamic>>[].obs;
  var userGroups = <Map<String, dynamic>>[].obs;
  var selectedGroup = <String, dynamic>{}.obs;
  var groupMembers = <Map<String, dynamic>>[].obs;
  var userId = 0.obs;

  // Filters
  var selectedCategory = ''.obs;
  var selectedFruit = ''.obs;
  var currentPage = 0.obs;
  var hasMore = true.obs;
  var isLoadingMore = false.obs;
  final int itemsPerPage = 20;
  int _apiPage = 0;
  int _duplicatePageStreak = 0;
  bool _paginationRunning = false;

  // Performance: Store all groups for instant client-side filtering
  var _allGroups = <Map<String, dynamic>>[];
  
  // Performance: Track if data is already loaded to prevent unnecessary reloads
  var _isDataLoaded = false;
  var _isLoading = false;
  int _loadGeneration = 0;
  DateTime? _lastSyncedAt;
  static const Duration _minSyncInterval = Duration(minutes: 2);
  static const Duration _detailsMinSyncInterval = Duration(minutes: 2);
  static const String _groupsListHiveKey = 'groups_list';
  static const String _userGroupsHiveKey = 'user_groups_list';
  Completer<void>? _activeLoadCompleter;
  final Map<int, DateTime> _detailSyncedAtByGroupId = {};
  DateTime? _userGroupsLastSyncedAt;
  int? preparedDetailGroupId;

  /// Seed from home cache for instant open.
  void seedFromHomeIfEmpty(List<Map<String, dynamic>> homeGroups) {
    if (_allGroups.isNotEmpty || homeGroups.isEmpty) return;
    _allGroups = List<Map<String, dynamic>>.from(homeGroups);
    _isDataLoaded = true;
    _apiPage = 0;
    hasMore.value = true;
    _applyClientSideFilter();
  }

  bool get _isHomePreviewOnly => _allGroups.length <= 6;

  void _markHasMoreFromCache() {
    if (_allGroups.isEmpty || _isHomePreviewOnly) {
      hasMore.value = true;
      return;
    }
    hasMore.value = _allGroups.length % itemsPerPage == 0;
  }

  void _appendUniqueGroups(List<Map<String, dynamic>> batch) {
    final existingIds = _allGroups.map(_groupIdFromMap).whereType<int>().toSet();
    for (final group in batch) {
      final id = _groupIdFromMap(group);
      if (id == null || existingIds.contains(id)) continue;
      _allGroups.add(Map<String, dynamic>.from(group));
      existingIds.add(id);
    }
  }
  
  /// Set fruit filter
  void setFruitFilter(String fruitName) {
    // Performance: Only filter if fruit is actually changing
    if (selectedFruit.value != fruitName) {
      selectedFruit.value = fruitName;
      
      // Apply filter instantly from cached data (no API call)
      if (_allGroups.isNotEmpty) {
        _applyClientSideFilter();
        return;
      }
      
      // Only load from API if no cached data exists
      if (_allGroups.isEmpty) {
        currentPage.value = 0;
        _isDataLoaded = false;
        loadGroups(refresh: true);
      }
    }
  }
  
  /// Clear fruit filter
  void clearFruitFilter() {
    // Performance: Only clear if filter is actually set
    if (selectedFruit.value.isNotEmpty) {
      selectedFruit.value = '';
      
      // Show all groups instantly from cached data (no API call)
      if (_allGroups.isNotEmpty) {
        _applyClientSideFilter();
        return;
      }
      
      // Only load from API if no cached data exists
      if (_allGroups.isEmpty) {
        currentPage.value = 0;
        _isDataLoaded = false;
        loadGroups(refresh: true);
      }
    }
  }

  @override
  void onInit() {
    super.onInit();
    _loadUserId();
    bootstrapGroups();
  }

  /// Hive → home seed — instant groups list (feeling / blogs pattern).
  void bootstrapGroups() {
    loadFromHiveIfEmpty();
    if (_allGroups.isNotEmpty) return;
    try {
      if (Get.isRegistered<HomeController>()) {
        seedFromHomeIfEmpty(Get.find<HomeController>().groups.toList());
      }
    } catch (_) {}
  }

  int? _groupIdFromMap(Map<String, dynamic> group) {
    final id = group['id'];
    if (id is int) return id;
    return int.tryParse(id?.toString() ?? '');
  }

  String _groupDetailHiveKey(int groupId) => 'group_detail_$groupId';
  String _groupMembersHiveKey(int groupId) => 'group_members_$groupId';

  @override
  void onReady() {
    super.onReady();
    if (_allGroups.isNotEmpty) {
      _applyClientSideFilter();
    }
    unawaited(loadUserGroups(silent: userGroups.isNotEmpty));
    if (selectedCategory.value.isNotEmpty) {
      Get.find<JingleService>().startJingle(selectedCategory.value);
    } else {
      Get.find<JingleService>().startJingle('Prayer');
    }
  }

  /// Load user ID from storage
  Future<void> _loadUserId() async {
    final id = await UserStorage.getUserId();
    if (id != null) {
      userId.value = id;
    }
  }

  /// Load groups
  Future<void> loadGroups({bool refresh = false, bool silent = false}) async {
    if (_isLoading) {
      if (_activeLoadCompleter != null) {
        await _activeLoadCompleter!.future;
      }
      if (_allGroups.isNotEmpty) {
        _applyClientSideFilter();
      }
      return;
    }

    if (_isDataLoaded && !refresh && _allGroups.isNotEmpty) {
      _applyClientSideFilter();
      return;
    }

    if (silent &&
        _lastSyncedAt != null &&
        DateTime.now().difference(_lastSyncedAt!) < _minSyncInterval) {
      if (_allGroups.isNotEmpty) {
        _applyClientSideFilter();
      }
      return;
    }

    final generation = silent ? _loadGeneration : ++_loadGeneration;
    _activeLoadCompleter = Completer<void>();

    if (refresh) {
      currentPage.value = 0;
      if (!silent) {
        _isDataLoaded = false;
      }
    }

    _isLoading = true;
    if (!silent) {
      isLoading.value = true;
    }
    message.value = '';

    try {
      final groupsList = await GroupsService.getGroups(
        status: 'Active',
        category: null,
        limit: itemsPerPage,
        offset: currentPage.value * itemsPerPage,
      );

      if (generation != _loadGeneration) {
        return;
      }

      if (groupsList.isEmpty && _allGroups.isNotEmpty) {
        _applyClientSideFilter();
        return;
      }

      if (refresh || currentPage.value == 0) {
        if (_allGroups.isEmpty) {
          _allGroups = List<Map<String, dynamic>>.from(groupsList);
          _applyClientSideFilter();
        } else if (silent) {
          _mergeGroupListPage(groupsList);
        } else if (!_groupListsEqual(_allGroups, groupsList)) {
          _allGroups = List<Map<String, dynamic>>.from(groupsList);
          _applyClientSideFilter();
        }
      } else {
        _allGroups.addAll(groupsList);
        _applyClientSideFilter();
      }

      groups.refresh();
      _isDataLoaded = true;
      _lastSyncedAt = DateTime.now();
      unawaited(
        HiveCacheService.cacheList(
          _groupsListHiveKey,
          _allGroups,
          expiryHours: 24,
        ),
      );
      final homeSlice = _allGroups.take(6).toList();
      if (homeSlice.isNotEmpty) {
        unawaited(
          HiveCacheService.cacheList('home_groups', homeSlice, expiryHours: 24),
        );
      }
    } catch (e) {
      if (!silent) {
        message.value =
            'Error loading groups: ${e.toString().replaceAll('Exception: ', '')}';
      }
      print('Error loading groups: $e');
      if ((refresh || currentPage.value == 0) && _allGroups.isEmpty) {
        groups.value = [];
        _isDataLoaded = false;
      }
    } finally {
      _isLoading = false;
      if (!silent) {
        isLoading.value = false;
      }
      _activeLoadCompleter?.complete();
      _activeLoadCompleter = null;
    }
  }

  bool _groupListsEqual(
    List<Map<String, dynamic>> previous,
    List<Map<String, dynamic>> next,
  ) {
    if (previous.length != next.length) return false;
    for (var i = 0; i < previous.length; i++) {
      if (!_groupItemEqual(previous[i], next[i])) return false;
    }
    return true;
  }

  bool _groupItemEqual(
    Map<String, dynamic> previous,
    Map<String, dynamic> next,
  ) {
    return previous['id'] == next['id'] &&
        previous['updated_at'] == next['updated_at'] &&
        previous['member_count'] == next['member_count'] &&
        previous['name'] == next['name'] &&
        previous['description'] == next['description'] &&
        previous['category'] == next['category'] &&
        previous['image'] == next['image'] &&
        previous['image_url'] == next['image_url'];
  }

  void _mergeGroupListPage(List<Map<String, dynamic>> incoming) {
    if (incoming.isEmpty) return;
    if (_allGroups.isEmpty) {
      _allGroups = List<Map<String, dynamic>>.from(incoming);
      _applyClientSideFilter();
      return;
    }

    final indexById = <int, int>{};
    for (var i = 0; i < _allGroups.length; i++) {
      final id = _groupIdFromMap(_allGroups[i]);
      if (id != null) indexById[id] = i;
    }

    var changed = false;
    for (final remote in incoming) {
      final id = _groupIdFromMap(remote);
      if (id == null) continue;
      final idx = indexById[id];
      if (idx != null) {
        if (!_groupItemEqual(_allGroups[idx], remote)) {
          _allGroups[idx] = {..._allGroups[idx], ...remote};
          changed = true;
        }
      } else {
        _allGroups.add(Map<String, dynamic>.from(remote));
        changed = true;
      }
    }

    if (changed) {
      _applyClientSideFilter();
    }
  }

  /// Load user's groups — Hive first, silent sync.
  Future<void> loadUserGroups({bool silent = false, bool force = false}) async {
    if (userId.value == 0) {
      await _loadUserId();
    }

    if (userId.value == 0) {
      userGroups.value = [];
      return;
    }

    if (userGroups.isEmpty) {
      final cached = HiveCacheService.getCachedList(_userGroupsHiveKey);
      if (cached.isNotEmpty) {
        userGroups.value = List<Map<String, dynamic>>.from(cached);
      }
    }

    if (silent &&
        !force &&
        _userGroupsLastSyncedAt != null &&
        DateTime.now().difference(_userGroupsLastSyncedAt!) < _minSyncInterval) {
      return;
    }

    try {
      final groupsList = await GroupsService.getGroups(
        status: 'Active',
        userId: userId.value,
      );
      if (!_groupListsEqual(userGroups.toList(), groupsList)) {
        userGroups.value = List<Map<String, dynamic>>.from(groupsList);
      }
      _userGroupsLastSyncedAt = DateTime.now();
      unawaited(
        HiveCacheService.cacheList(
          _userGroupsHiveKey,
          List<Map<String, dynamic>>.from(userGroups),
          expiryHours: 24,
        ),
      );
    } catch (e) {
      print('Error loading user groups: $e');
      if (userGroups.isEmpty) {
        userGroups.value = [];
      }
    }
  }

  /// Load more groups when user scrolls down.
  Future<void> loadMore() async {
    await loadNextPage();
  }

  /// Auto-load all API pages (home shows 6; groups screen needs full list).
  Future<void> startGroupsPagination({
    bool silent = true,
    bool force = false,
  }) async {
    if (_paginationRunning) return;
    if (!force &&
        !_isHomePreviewOnly &&
        _lastSyncedAt != null &&
        DateTime.now().difference(_lastSyncedAt!) < _minSyncInterval) {
      return;
    }

    if (_isHomePreviewOnly || force) {
      _apiPage = 0;
      hasMore.value = true;
    }

    _paginationRunning = true;
    try {
      while (hasMore.value) {
        final keepGoing = await _loadGroupsPage(silent: silent);
        if (!keepGoing) break;
      }
    } finally {
      _paginationRunning = false;
      if (_allGroups.isNotEmpty) {
        _applyClientSideFilter();
      }
    }
  }

  Future<void> expandGroupsIfPreview({bool silent = true}) async {
    await startGroupsPagination(silent: silent, force: _isHomePreviewOnly);
  }

  Future<void> loadNextPage({bool silent = true}) async {
    if (_paginationRunning || !hasMore.value) return;
    await _loadGroupsPage(silent: silent);
  }

  Future<bool> _loadGroupsPage({bool silent = false}) async {
    if (isLoadingMore.value || !hasMore.value) return false;

    isLoadingMore.value = true;
    try {
      final batch = await GroupsService.getGroups(
        status: 'Active',
        category: null,
        limit: itemsPerPage,
        offset: _apiPage * itemsPerPage,
      );

      if (batch.isEmpty) {
        hasMore.value = false;
        return false;
      }

      final beforeCount = _allGroups.length;
      _appendUniqueGroups(batch);
      _apiPage++;

      if (batch.length < itemsPerPage) {
        hasMore.value = false;
        _duplicatePageStreak = 0;
      } else if (_allGroups.length == beforeCount) {
        _duplicatePageStreak++;
        if (_duplicatePageStreak >= 2) {
          hasMore.value = false;
        }
      } else {
        _duplicatePageStreak = 0;
      }

      if (_allGroups.isNotEmpty) {
        _isDataLoaded = true;
        _lastSyncedAt = DateTime.now();
        _applyClientSideFilter();
        if (_allGroups.length > beforeCount) {
          unawaited(
            HiveCacheService.cacheList(
              _groupsListHiveKey,
              _allGroups,
              expiryHours: 24,
            ),
          );
        }
      }

      return hasMore.value;
    } catch (e) {
      if (!silent) {
        message.value =
            'Error loading groups: ${e.toString().replaceAll('Exception: ', '')}';
      }
      print('Error loading groups page $_apiPage: $e');
      return false;
    } finally {
      isLoadingMore.value = false;
    }
  }

  void bootstrapGroupDetail(int groupId) {
    if (groupId <= 0) return;

    final currentId = _groupIdFromMap(selectedGroup);
    if (currentId != null && currentId != groupId) {
      groupMembers.clear();
    }

    _loadGroupDetailFromHive(groupId);
    if (_groupIdFromMap(selectedGroup) != groupId || selectedGroup.isEmpty) {
      _seedGroupDetailFromList(groupId);
    }
    preparedDetailGroupId = groupId;
  }

  void _seedGroupDetailFromList(int groupId) {
    if (_groupIdFromMap(selectedGroup) == groupId && selectedGroup.isNotEmpty) {
      return;
    }

    Map<String, dynamic>? found;
    for (final group in _allGroups) {
      if (_groupIdFromMap(group) == groupId) {
        found = group;
        break;
      }
    }
    if (found == null) {
      for (final group in groups) {
        if (_groupIdFromMap(group) == groupId) {
          found = group;
          break;
        }
      }
    }
    if (found == null) {
      for (final group in userGroups) {
        if (_groupIdFromMap(group) == groupId) {
          found = group;
          break;
        }
      }
    }

    if (found != null) {
      selectedGroup.value = Map<String, dynamic>.from(found);
    }
  }

  void _loadGroupDetailFromHive(int groupId) {
    final cached = HiveCacheService.getCachedData(_groupDetailHiveKey(groupId));
    if (cached is! Map) return;

    if (cached['group'] is Map) {
      selectedGroup.value =
          Map<String, dynamic>.from(cached['group'] as Map<String, dynamic>);
    }
    if (cached['members'] is List) {
      final members = (cached['members'] as List)
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
      if (members.isNotEmpty) {
        groupMembers.value = members;
      }
    }
  }

  Future<void> _cacheGroupDetail(int groupId) async {
    if (selectedGroup.isEmpty) return;
    await HiveCacheService.cacheData(
      _groupDetailHiveKey(groupId),
      {
        'group': Map<String, dynamic>.from(selectedGroup),
        'members': groupMembers
            .map((m) => Map<String, dynamic>.from(m))
            .toList(),
        'cached_at': DateTime.now().millisecondsSinceEpoch,
      },
      expiryHours: 24,
    );
  }

  bool _groupDetailNeedsUpdate(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) {
    const keys = [
      'updated_at',
      'member_count',
      'name',
      'description',
      'category',
      'image',
      'image_url',
    ];
    for (final key in keys) {
      if (local[key] != remote[key]) return true;
    }
    return false;
  }

  void _mergeGroupFields(Map<String, dynamic> remote) {
    var changed = false;
    for (final entry in remote.entries) {
      if (selectedGroup[entry.key] != entry.value) {
        selectedGroup[entry.key] = entry.value;
        changed = true;
      }
    }
    if (changed) {
      selectedGroup.refresh();
    }
  }

  Future<void> prepareGroupDetails(int groupId) async {
    if (groupId <= 0) return;

    bootstrapGroupDetail(groupId);

    final hasPreview =
        _groupIdFromMap(selectedGroup) == groupId && selectedGroup.isNotEmpty;
    if (!hasPreview) {
      await loadGroupDetails(groupId, silent: false);
    } else {
      unawaited(loadGroupDetails(groupId, silent: true));
    }
  }

  /// Load single group with members — cache first, silent sync.
  Future<void> loadGroupDetails(
    int groupId, {
    bool silent = false,
    bool force = false,
  }) async {
    if (silent && !force) {
      final lastSync = _detailSyncedAtByGroupId[groupId];
      if (lastSync != null &&
          DateTime.now().difference(lastSync) < _detailsMinSyncInterval) {
        return;
      }
    }

    final hadPreview =
        _groupIdFromMap(selectedGroup) == groupId && selectedGroup.isNotEmpty;

    if (!silent && !hadPreview) {
      isLoading.value = true;
    }
    message.value = '';

    try {
      if (userGroups.isEmpty && userId.value > 0) {
        unawaited(loadUserGroups(silent: true));
      }

      final group = await GroupsService.getGroupDetails(groupId);

      if (silent &&
          hadPreview &&
          !force &&
          !_groupDetailNeedsUpdate(selectedGroup, group)) {
        _detailSyncedAtByGroupId[groupId] = DateTime.now();
        return;
      }

      if (silent && hadPreview) {
        _mergeGroupFields(group);
      } else {
        selectedGroup.value = group;
      }

      await loadGroupMembers(groupId, silent: silent);
      _detailSyncedAtByGroupId[groupId] = DateTime.now();
      unawaited(_cacheGroupDetail(groupId));
      _syncGroupInLists(groupId);
    } catch (e) {
      if (!silent || !hadPreview) {
        message.value =
            'Error loading group: ${e.toString().replaceAll('Exception: ', '')}';
      }
      print('Error loading group details: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void _syncGroupInLists(int groupId) {
    if (selectedGroup.isEmpty) return;
    final snapshot = Map<String, dynamic>.from(selectedGroup);

    for (var i = 0; i < _allGroups.length; i++) {
      if (_groupIdFromMap(_allGroups[i]) == groupId) {
        _allGroups[i] = {..._allGroups[i], ...snapshot};
        break;
      }
    }

    for (var i = 0; i < groups.length; i++) {
      if (_groupIdFromMap(groups[i]) == groupId) {
        groups[i] = {...groups[i], ...snapshot};
        break;
      }
    }
    groups.refresh();
    unawaited(
      HiveCacheService.cacheList(_groupsListHiveKey, _allGroups, expiryHours: 24),
    );
  }

  /// Load group members
  Future<void> loadGroupMembers(int groupId, {bool silent = false}) async {
    try {
      final members = await GroupsService.getGroupMembers(groupId);
      if (members.isEmpty && groupMembers.isNotEmpty && silent) {
        return;
      }
      groupMembers.value = members;
      unawaited(
        HiveCacheService.cacheList(
          _groupMembersHiveKey(groupId),
          List<Map<String, dynamic>>.from(members),
          expiryHours: 24,
        ),
      );
    } catch (e) {
      print('Error loading group members: $e');
      if (!silent || groupMembers.isEmpty) {
        groupMembers.value = [];
      }
    }
  }

  void _markJoinedLocally(int groupId) {
    if (isMember(groupId)) return;

    Map<String, dynamic>? group;
    for (final item in _allGroups) {
      if (_groupIdFromMap(item) == groupId) {
        group = item;
        break;
      }
    }
    if (group == null) {
      for (final item in groups) {
        if (_groupIdFromMap(item) == groupId) {
          group = item;
          break;
        }
      }
    }

    userGroups.add(
      group != null
          ? Map<String, dynamic>.from(group)
          : {'id': groupId},
    );
    userGroups.refresh();
  }

  /// Create group
  Future<bool> createGroup({
    required String name,
    String? description,
    String? category,
    File? groupImage,
  }) async {
    if (userId.value == 0) {
      await _loadUserId();
    }

    if (userId.value == 0) {
      message.value = 'Please login first';
      return false;
    }

    isCreatingGroup.value = true;
    message.value = 'Creating group...';

    try {
      final newGroupId = await GroupsService.createGroup(
        userId: userId.value,
        name: name,
        description: description,
        category: category,
        groupImage: groupImage,
      );

      message.value = 'Group created successfully';

      final optimisticGroup = <String, dynamic>{
        'id': newGroupId,
        'name': name,
        'description': description ?? '',
        'category': category ?? '',
        'created_by': userId.value,
        'status': 'Active',
        'member_count': 1,
      };
      _allGroups.insert(0, optimisticGroup);
      _markJoinedLocally(newGroupId);
      _applyClientSideFilter();
      unawaited(
        HiveCacheService.cacheList(
          _groupsListHiveKey,
          _allGroups,
          expiryHours: 24,
        ),
      );

      unawaited(Future.wait([
        loadGroups(refresh: true, silent: true),
        loadUserGroups(force: true),
      ]));

      return true;
    } catch (e) {
      // Handle network errors specifically
      if (e.toString().contains('NetworkException') || e.toString().contains('No internet')) {
        message.value = 'No internet connection. Please check your network and try again.';
      } else if (e.toString().contains('SocketException')) {
        message.value = 'Network error. Please check your connection.';
      } else if (e.toString().contains('TimeoutException')) {
        message.value = 'Request timed out. Please try again.';
      } else {
        message.value = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      }
      print('Error creating group: $e');
      return false;
    } finally {
      isCreatingGroup.value = false;
    }
  }

  /// Join group
  Future<bool> joinGroup(int groupId) async {
    if (userId.value == 0) {
      await _loadUserId();
    }

    if (userId.value == 0) {
      message.value = 'Please login first';
      return false;
    }

    message.value = '';

    try {
      await GroupsService.joinGroup(
        userId: userId.value,
        groupId: groupId,
      );
      
      message.value = 'Joined group successfully';
      _markJoinedLocally(groupId);
      unawaited(loadUserGroups(force: true));
      unawaited(loadGroupMembers(groupId, silent: true));
      if (selectedGroup.isNotEmpty && selectedGroup['id'] == groupId) {
        selectedGroup.refresh();
      }

      return true;
    } catch (e) {
      final errorMessage = e.toString().replaceAll('Exception: ', '');
      
      // If already a member, treat it as success and refresh UI
      if (errorMessage.contains('Already a member') || 
          errorMessage.contains('already a member') ||
          errorMessage.contains('Already a member of this group')) {
        print('ℹ️ User is already a member - refreshing UI');
        message.value = 'You are already a member of this group';
        
        _markJoinedLocally(groupId);
        unawaited(loadUserGroups(force: true));
        unawaited(loadGroupMembers(groupId, silent: true));
        if (selectedGroup.isNotEmpty && selectedGroup['id'] == groupId) {
          selectedGroup.refresh();
        }

        return true;
      }
      
      message.value = errorMessage;
      print('Error joining group: $e');
      return false;
    }
  }

  /// Check if current user is the group owner
  bool isGroupOwner([int? groupId]) {
    if (userId.value == 0 || selectedGroup.isEmpty) return false;

    final targetGroupId = groupId ?? selectedGroup['id'];
    if (targetGroupId != null && groupId != null) {
      final groupIdValue = selectedGroup['id'];
      final matches = groupIdValue == groupId ||
          (groupIdValue is String && int.tryParse(groupIdValue) == groupId);
      if (!matches) return false;
    }

    final createdBy = selectedGroup['created_by'];
    if (createdBy is int) return createdBy == userId.value;
    if (createdBy is String) return int.tryParse(createdBy) == userId.value;
    return false;
  }

  /// Remove a member from group (owner only)
  Future<bool> removeMember(int groupId, int memberId) async {
    if (userId.value == 0) {
      await _loadUserId();
    }

    if (userId.value == 0) {
      message.value = 'Please login first';
      return false;
    }

    message.value = '';

    try {
      await GroupsService.removeMember(
        userId: userId.value,
        groupId: groupId,
        memberId: memberId,
      );

      message.value = 'Member removed successfully';
      await loadGroupMembers(groupId);
      await loadUserGroups();
      return true;
    } catch (e) {
      message.value = e.toString().replaceAll('Exception: ', '');
      print('Error removing member: $e');
      return false;
    }
  }

  /// Leave group
  Future<bool> leaveGroup(int groupId) async {
    if (userId.value == 0) {
      await _loadUserId();
    }

    if (userId.value == 0) {
      message.value = 'Please login first';
      return false;
    }

    message.value = '';

    try {
      await GroupsService.leaveGroup(
        userId: userId.value,
        groupId: groupId,
      );
      
      message.value = 'Left group successfully';
      
      // Update only specific values - no full reload
      await loadUserGroups(force: true);
      await loadGroupMembers(groupId);
      // Update selected group membership status
      if (selectedGroup.isNotEmpty && selectedGroup['id'] == groupId) {
        selectedGroup.refresh();
      }
      
      return true;
    } catch (e) {
      String errorMessage = e.toString().replaceAll('Exception: ', '');
      
      // Use custom frontend message for "only admin" error
      if (errorMessage.contains('Cannot leave group') && errorMessage.contains('only admin')) {
        message.value = 'You cannot leave this group as you are the only admin. Please assign another admin first.';
      } else {
        message.value = errorMessage;
      }
      
      print('Error leaving group: $e');
      return false;
    }
  }

  /// Check if user is member of group
  bool isMember(int groupId) {
    // Ensure we're checking with the correct type (int)
    final isMemberResult = userGroups.any((group) {
      final groupIdValue = group['id'];
      // Handle both int and string types
      if (groupIdValue is int) {
        return groupIdValue == groupId;
      } else if (groupIdValue is String) {
        return int.tryParse(groupIdValue) == groupId;
      }
      return groupIdValue == groupId;
    });
    
    print('🔍 isMember check: groupId=$groupId, userGroups count=${userGroups.length}, isMember=$isMemberResult');
    if (userGroups.isNotEmpty) {
      print('   User groups IDs: ${userGroups.map((g) => g['id']).toList()}');
    }
    
    return isMemberResult;
  }

  /// Load from Hive if memory cache is empty.
  void loadFromHiveIfEmpty() {
    if (_allGroups.isNotEmpty) return;
    final cached = HiveCacheService.getCachedList(_groupsListHiveKey);
    if (cached.isEmpty) {
      final homeCached = HiveCacheService.getCachedList('home_groups');
      if (homeCached.isNotEmpty) {
        seedFromHomeIfEmpty(homeCached);
      }
      return;
    }
    _allGroups = List<Map<String, dynamic>>.from(cached);
    _isDataLoaded = true;
    _apiPage = _allGroups.length ~/ itemsPerPage;
    if (_allGroups.length % itemsPerPage != 0) {
      _apiPage++;
    }
    _markHasMoreFromCache();
    _applyClientSideFilter();
  }

  /// Set initial data from cache
  void setInitialData(List<Map<String, dynamic>> data) {
    if (data.isNotEmpty) {
      _allGroups = List<Map<String, dynamic>>.from(data);
      _isDataLoaded = true;
      _applyClientSideFilter();
    }
  }

  /// Apply client-side filter instantly (no API call)
  void _applyClientSideFilter() {
    if (_allGroups.isEmpty) {
      groups.value = [];
      groups.refresh();
      return;
    }
    
    var filtered = List<Map<String, dynamic>>.from(_allGroups);
    
    // Filter by category
    if (selectedCategory.value.isNotEmpty) {
      filtered = filtered.where((group) {
        final groupCategory = group['category'] as String? ?? '';
        return groupCategory.toLowerCase() == selectedCategory.value.toLowerCase();
      }).toList();
    }
    
    // Filter by fruit
    if (selectedFruit.value.isNotEmpty) {
      filtered = filtered.where((group) {
        final groupFruit = group['fruit_tag'] as String? ?? 
                         group['fruit'] as String? ?? '';
        return groupFruit.toLowerCase() == selectedFruit.value.toLowerCase();
      }).toList();
    }
    
    // Create new list instance to ensure GetX detects change
    groups.value = List<Map<String, dynamic>>.from(filtered);
    // Force UI refresh
    groups.refresh();
  }

  /// Filter by category - Instant client-side filtering only (no API call if data exists)
  void filterByCategory(String category) {
    // Performance: Only filter if category is actually changing
    if (selectedCategory.value != category) {
      selectedCategory.value = category;
      
      // If "All" is selected and we have cached data, show all instantly
      if (category.isEmpty && _allGroups.isNotEmpty) {
        _applyClientSideFilter();
        return;
      }
      
      // If specific category selected and we have cached data, filter instantly
      if (_allGroups.isNotEmpty) {
        _applyClientSideFilter();
        return;
      }
      
      // Only load from API if no cached data exists
      if (_allGroups.isEmpty) {
        _isDataLoaded = false;
        loadGroups(refresh: true);
      }
    }
  }

  /// Clear filter - Instant client-side filtering only (no API call if data exists)
  void clearFilter() {
    // Performance: Only clear if filter is actually set
    if (selectedCategory.value.isNotEmpty) {
      selectedCategory.value = '';
      
      // Show all groups instantly from cached data (no API call)
      if (_allGroups.isNotEmpty) {
        _applyClientSideFilter();
        return;
      }
      
      // Only load from API if no cached data exists
      if (_allGroups.isEmpty) {
        _isDataLoaded = false;
        loadGroups(refresh: true);
      }
    }
  }

  /// Fetch every active group page (home shows 6; groups screen needs full list).
  Future<void> fetchAllGroups({bool silent = false, bool force = false}) async {
    if (_isLoading) {
      if (_activeLoadCompleter != null) {
        await _activeLoadCompleter!.future;
      }
      return;
    }

    if (silent &&
        !force &&
        _lastSyncedAt != null &&
        DateTime.now().difference(_lastSyncedAt!) < _minSyncInterval) {
      return;
    }

    final generation = silent ? _loadGeneration : ++_loadGeneration;
    _activeLoadCompleter = Completer<void>();
    _isLoading = true;
    if (!silent) {
      isLoading.value = true;
    }
    message.value = '';

    try {
      final all = <Map<String, dynamic>>[];
      var page = 0;
      while (true) {
        final batch = await GroupsService.getGroups(
          status: 'Active',
          category: null,
          limit: itemsPerPage,
          offset: page * itemsPerPage,
        );
        if (generation != _loadGeneration) {
          return;
        }
        if (batch.isEmpty) break;
        all.addAll(batch);
        if (batch.length < itemsPerPage) break;
        page++;
      }

      if (all.isEmpty) {
        if (!silent && _allGroups.isEmpty) {
          groups.value = [];
          _isDataLoaded = false;
        }
        return;
      }

      final hadGroups = _allGroups.isNotEmpty;
      if (silent &&
          hadGroups &&
          !force &&
          _groupListsEqual(_allGroups, all)) {
        _lastSyncedAt = DateTime.now();
        return;
      }

      _allGroups = all;
      currentPage.value = page;
      _isDataLoaded = true;
      hasMore.value = false;
      _lastSyncedAt = DateTime.now();
      _applyClientSideFilter();
      unawaited(
        HiveCacheService.cacheList(
          _groupsListHiveKey,
          _allGroups,
          expiryHours: 24,
        ),
      );
      final homeSlice = _allGroups.take(6).toList();
      if (homeSlice.isNotEmpty) {
        unawaited(
          HiveCacheService.cacheList('home_groups', homeSlice, expiryHours: 24),
        );
      }
    } catch (e) {
      if (!silent) {
        message.value =
            'Error loading groups: ${e.toString().replaceAll('Exception: ', '')}';
      }
      print('Error loading all groups: $e');
    } finally {
      _isLoading = false;
      if (!silent) {
        isLoading.value = false;
      }
      _activeLoadCompleter?.complete();
      _activeLoadCompleter = null;
    }
  }

  /// Refresh data — keep current list visible until new data arrives.
  Future<void> refresh() async {
    final snapshot = List<Map<String, dynamic>>.from(_allGroups);
    _lastSyncedAt = null;
    isLoading.value = true;

    try {
      final fetched = <Map<String, dynamic>>[];
      var page = 0;
      while (true) {
        final batch = await GroupsService.getGroups(
          status: 'Active',
          category: null,
          limit: itemsPerPage,
          offset: page * itemsPerPage,
        );
        if (batch.isEmpty) break;
        fetched.addAll(batch);
        if (batch.length < itemsPerPage) break;
        page++;
      }

      if (fetched.isNotEmpty) {
        _allGroups = fetched;
        _apiPage = page + 1;
        hasMore.value = false;
        _isDataLoaded = true;
        _lastSyncedAt = DateTime.now();
        _applyClientSideFilter();
        unawaited(
          HiveCacheService.cacheList(
            _groupsListHiveKey,
            _allGroups,
            expiryHours: 24,
          ),
        );
      } else if (snapshot.isNotEmpty) {
        _allGroups = snapshot;
        _applyClientSideFilter();
      }
    } catch (e) {
      if (snapshot.isNotEmpty) {
        _allGroups = snapshot;
        _applyClientSideFilter();
      }
      message.value =
          'Error refreshing groups: ${e.toString().replaceAll('Exception: ', '')}';
    } finally {
      isLoading.value = false;
    }

    await loadUserGroups(force: true);
  }
}

