import 'dart:io';
import 'package:get/get.dart';
import 'package:fruitsofspirit/services/groups_service.dart';
import 'package:fruitsofspirit/services/user_storage.dart';
import 'package:fruitsofspirit/services/api_service.dart';

/// Groups Controller
/// Manages groups data and operations
class GroupsController extends GetxController {
  // Observable variables
  var isLoading = false.obs;
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
  final int itemsPerPage = 20;
  
  // Performance: Store all groups for instant client-side filtering
  var _allGroups = <Map<String, dynamic>>[];
  
  // Performance: Track if data is already loaded to prevent unnecessary reloads
  var _isDataLoaded = false;
  var _isLoading = false;
  
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
  }

  @override
  void onReady() {
    super.onReady();
    // Performance: Only load if data is not already loaded
    if (!_isDataLoaded && !_isLoading && groups.isEmpty && _allGroups.isEmpty) {
      loadGroups();
    } else if (_allGroups.isNotEmpty) {
      // Apply filter from cached data if available
      _applyClientSideFilter();
    }
    loadUserGroups();
  }

  /// Load user ID from storage
  Future<void> _loadUserId() async {
    final id = await UserStorage.getUserId();
    if (id != null) {
      userId.value = id;
    }
  }

  /// Load groups
  Future<void> loadGroups({bool refresh = false}) async {
    // Performance: Skip if already loading
    if (_isLoading && !refresh) {
      return;
    }
    
    // Performance: Skip if data already loaded and not explicitly refreshing
    if (_isDataLoaded && !refresh && groups.isNotEmpty && _allGroups.isNotEmpty) {
      // Apply current filter from cache
      _applyClientSideFilter();
      return;
    }
    
    if (refresh) {
      currentPage.value = 0;
      _isDataLoaded = false;
    }

    _isLoading = true;
    isLoading.value = true;
    message.value = '';

    try {
      // Performance: Always load ALL groups (no filters) to populate cache
      // Then apply client-side filtering for instant updates
      final groupsList = await GroupsService.getGroups(
        status: 'Active',
        category: null, // Always load all groups for cache
        limit: itemsPerPage,
        offset: currentPage.value * itemsPerPage,
      );

      if (refresh || currentPage.value == 0) {
        // Performance: Store ALL groups in cache (no filters)
        _allGroups = List<Map<String, dynamic>>.from(groupsList);
        // Apply current filter to display
        _applyClientSideFilter();
      } else {
        // Performance: Add to all groups cache
        _allGroups.addAll(groupsList);
        // Apply current filter to display
        _applyClientSideFilter();
      }
      
      // Force UI refresh to ensure changes are visible
      groups.refresh();
      
      // Performance: Mark as loaded
      _isDataLoaded = true;
    } catch (e) {
      message.value = 'Error loading groups: ${e.toString().replaceAll('Exception: ', '')}';
      print('Error loading groups: $e');
      if (refresh || currentPage.value == 0) {
        groups.value = [];
        _allGroups = [];
        _isDataLoaded = false;
      }
    } finally {
      _isLoading = false;
      isLoading.value = false;
    }
  }

  /// Load user's groups
  Future<void> loadUserGroups() async {
    if (userId.value == 0) {
      await _loadUserId();
    }

    if (userId.value == 0) {
      userGroups.value = [];
      return;
    }

    try {
      print('🔄 Loading user groups for userId: ${userId.value}');
      final groupsList = await GroupsService.getGroups(
        status: 'Active',
        userId: userId.value,
      );
      // Create new list instance and force UI refresh
      userGroups.value = List<Map<String, dynamic>>.from(groupsList);
      userGroups.refresh();
      print('✅ Loaded ${userGroups.length} user groups');
      if (userGroups.isNotEmpty) {
        print('   Group IDs: ${userGroups.map((g) => g['id']).toList()}');
      }
    } catch (e) {
      print('❌ Error loading user groups: $e');
      userGroups.value = [];
    }
  }

  /// Load more groups (pagination)
  Future<void> loadMore() async {
    if (isLoading.value) return;

    currentPage.value++;
    await loadGroups();
  }

  /// Load single group with members
  Future<void> loadGroupDetails(int groupId) async {
    isLoading.value = true;
    message.value = '';

    try {
      // Ensure userGroups is loaded to check membership
      if (userGroups.isEmpty && userId.value > 0) {
        await loadUserGroups();
      }
      
      final group = await GroupsService.getGroupDetails(groupId);
      selectedGroup.value = group;
      
      // Load members
      await loadGroupMembers(groupId);
      
      // Double-check membership by reloading userGroups if needed
      // This ensures membership state is always accurate
      if (userId.value > 0) {
        await loadUserGroups();
      }
    } catch (e) {
      message.value = 'Error loading group: ${e.toString().replaceAll('Exception: ', '')}';
      print('Error loading group details: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Load group members
  Future<void> loadGroupMembers(int groupId) async {
    try {
      final members = await GroupsService.getGroupMembers(groupId);
      groupMembers.value = members;
    } catch (e) {
      print('Error loading group members: $e');
      groupMembers.value = [];
    }
  }

  /// Create group
  Future<bool> createGroup({
    required String name,
    String? description,
    String category = 'Prayer',
    File? groupImage,
  }) async {
    if (userId.value == 0) {
      await _loadUserId();
    }

    if (userId.value == 0) {
      message.value = 'Please login first';
      return false;
    }

    isLoading.value = true;
    message.value = 'Creating group...';

    try {
      await GroupsService.createGroup(
        userId: userId.value,
        name: name,
        description: description,
        category: category,
        groupImage: groupImage,
      );
      
      message.value = 'Group created successfully';
      
      // Update only specific values - no full page refresh
      // Load groups and user groups to update UI
      await Future.wait([
        loadGroups(refresh: true), // Need to refresh to get new group
        loadUserGroups(), // Update user groups to include new group
      ]);
      
      // UI will auto-update via GetX observables
      
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
      isLoading.value = false;
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

    isLoading.value = true;
    message.value = '';

    try {
      await GroupsService.joinGroup(
        userId: userId.value,
        groupId: groupId,
      );
      
      message.value = 'Joined group successfully';
      
      // Update only specific values - no full reload
      await loadUserGroups();
      // Update members list for this group
      await loadGroupMembers(groupId);
      // Update selected group membership status
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
        
        // Update only specific values - no full reload
        await loadUserGroups();
        // Update members list for this group
        await loadGroupMembers(groupId);
        
        // Update selected group membership status
        if (selectedGroup.isNotEmpty && selectedGroup['id'] == groupId) {
          selectedGroup.refresh();
        }
        userGroups.refresh();
        
        return true; // Return true to show success (UI will update)
      }
      
      message.value = 'Error: $errorMessage';
      print('Error joining group: $e');
      return false;
    } finally {
      isLoading.value = false;
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

    isLoading.value = true;
    message.value = '';

    try {
      await GroupsService.leaveGroup(
        userId: userId.value,
        groupId: groupId,
      );
      
      message.value = 'Left group successfully';
      
      // Update only specific values - no full reload
      await loadUserGroups();
      // Update members list for this group
      await loadGroupMembers(groupId);
      // Update selected group membership status
      if (selectedGroup.isNotEmpty && selectedGroup['id'] == groupId) {
        selectedGroup.refresh();
      }
      
      return true;
    } catch (e) {
      message.value = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      print('Error leaving group: $e');
      return false;
    } finally {
      isLoading.value = false;
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

  /// Refresh data - Only refresh if explicitly called (pull to refresh)
  Future<void> refresh() async {
    // Force refresh only when user explicitly pulls to refresh
    _isDataLoaded = false;
    await Future.wait([
      loadGroups(refresh: true),
      loadUserGroups(),
    ]);
  }
}

