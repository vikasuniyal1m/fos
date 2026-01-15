import 'package:get/get.dart';
import 'package:fruitsofspirit/services/fruits_service.dart';
import 'package:fruitsofspirit/services/user_storage.dart';

/// Fruits Controller
/// Manages Fruits of the Spirit data and user selections
class FruitsController extends GetxController {
  // Observable variables
  var isLoading = false.obs;
  var message = ''.obs;
  
  // Data
  var allFruits = <Map<String, dynamic>>[].obs;
  var userFruits = <Map<String, dynamic>>[].obs;
  var userId = 0.obs;
  
  // Performance: Track if data is already loaded to prevent unnecessary reloads
  var _isAllFruitsLoaded = false;
  var _isUserFruitsLoaded = false;
  var _isLoadingAllFruits = false;
  var _isLoadingUserFruits = false;

  @override
  void onInit() {
    super.onInit();
    _loadUserId();
  }

  @override
  void onReady() {
    super.onReady();
    // Performance: Only load if data is not already loaded
    if (!_isAllFruitsLoaded && !_isLoadingAllFruits) {
      loadAllFruits();
    }
    if (!_isUserFruitsLoaded && !_isLoadingUserFruits && userId.value > 0) {
      loadUserFruits();
    }
  }

  /// Load user ID from storage
  Future<void> _loadUserId() async {
    final id = await UserStorage.getUserId();
    if (id != null) {
      userId.value = id;
    }
  }

  /// Set initial data from cache
  void setInitialData(List<Map<String, dynamic>> data) {
    if (data.isNotEmpty) {
      allFruits.value = List<Map<String, dynamic>>.from(data);
      _isAllFruitsLoaded = true;
    }
  }

  /// Load all fruits
  Future<void> loadAllFruits({bool refresh = false}) async {
    // Performance: Skip if already loading
    if (_isLoadingAllFruits && !refresh) {
      return;
    }
    
    // Performance: Skip if data already loaded and not refreshing
    if (_isAllFruitsLoaded && !refresh && allFruits.isNotEmpty) {
      return;
    }

    _isLoadingAllFruits = true;
    isLoading.value = true;
    message.value = '';

    try {
      final fruits = await FruitsService.getAllFruits();
      allFruits.value = fruits;
      _isAllFruitsLoaded = true;
    } catch (e) {
      message.value = 'Error loading fruits: ${e.toString().replaceAll('Exception: ', '')}';
      print('Error loading fruits: $e');
      if (refresh) {
        allFruits.value = [];
        _isAllFruitsLoaded = false;
      }
    } finally {
      _isLoadingAllFruits = false;
      isLoading.value = false;
    }
  }

  /// Load user's selected fruits
  Future<void> loadUserFruits({bool refresh = false}) async {
    // Performance: Skip if already loading
    if (_isLoadingUserFruits && !refresh) {
      return;
    }
    
    // Performance: Skip if data already loaded and not refreshing
    if (_isUserFruitsLoaded && !refresh && userFruits.isNotEmpty) {
      return;
    }
    
    if (userId.value == 0) {
      await _loadUserId();
    }

    if (userId.value == 0) {
      userFruits.value = [];
      _isUserFruitsLoaded = true;
      return;
    }

    _isLoadingUserFruits = true;
    try {
      final fruits = await FruitsService.getUserFruits(userId.value);
      userFruits.value = fruits;
      _isUserFruitsLoaded = true;
    } catch (e) {
      print('Error loading user fruits: $e');
      if (refresh) {
        userFruits.value = [];
        _isUserFruitsLoaded = false;
      }
    } finally {
      _isLoadingUserFruits = false;
    }
  }

  /// Add fruit to user
  Future<void> addFruit(int fruitId) async {
    if (userId.value == 0) {
      await _loadUserId();
    }

    if (userId.value == 0) {
      message.value = 'Please login first';
      return;
    }

    isLoading.value = true;
    message.value = '';

    try {
      await FruitsService.addFruitToUser(
        userId: userId.value,
        fruitId: fruitId,
      );
      
      // Reload user fruits (refresh to get updated data)
      await loadUserFruits(refresh: true);
      await loadAllFruits(refresh: true);
      
      message.value = 'Fruit added successfully';
    } catch (e) {
      message.value = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      print('Error adding fruit: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Remove fruit from user
  Future<void> removeFruit(int fruitId) async {
    if (userId.value == 0) {
      await _loadUserId();
    }

    if (userId.value == 0) {
      message.value = 'Please login first';
      return;
    }

    isLoading.value = true;
    message.value = '';

    try {
      await FruitsService.removeFruitFromUser(
        userId: userId.value,
        fruitId: fruitId,
      );
      
      // Reload user fruits (refresh to get updated data)
      await loadUserFruits(refresh: true);
      await loadAllFruits(refresh: true);
      
      message.value = 'Fruit removed successfully';
    } catch (e) {
      message.value = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      print('Error removing fruit: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Check if fruit is selected by user
  bool isFruitSelected(int fruitId) {
    return userFruits.any((fruit) => 
      fruit['id'] == fruitId && (fruit['is_selected'] == 1 || fruit['is_selected'] == true)
    );
  }

  /// Refresh all data
  Future<void> refresh() async {
    _isAllFruitsLoaded = false;
    _isUserFruitsLoaded = false;
    await Future.wait([
      loadAllFruits(refresh: true),
      loadUserFruits(refresh: true),
    ]);
  }
}

