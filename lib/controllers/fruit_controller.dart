import 'package:get/get.dart';
import 'package:fruitsofspirit/services/fruit_service.dart';
import 'package:fruitsofspirit/services/user_storage.dart';

/// Fruit Controller
/// Manages Fruit of the Spirit data and user selections
class FruitController extends GetxController {
  // Observable variables
  var isLoading = false.obs;
  var message = ''.obs;
  
  // Data
  var allFruit = <Map<String, dynamic>>[].obs;
  var userFruit = <Map<String, dynamic>>[].obs;
  var userId = 0.obs;
  
  // Performance: Track if data is already loaded to prevent unnecessary reloads
  var _isAllFruitLoaded = false;
  var _isUserFruitLoaded = false;
  var _isLoadingAllFruit = false;
  var _isLoadingUserFruit = false;

  @override
  void onInit() {
    super.onInit();
    _loadUserId();
  }

  @override
  void onReady() {
    super.onReady();
    // Performance: Only load if data is not already loaded
    if (!_isAllFruitLoaded && !_isLoadingAllFruit) {
      loadAllFruit();
    }
    if (!_isUserFruitLoaded && !_isLoadingUserFruit && userId.value > 0) {
      loadUserFruit();
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
      allFruit.value = List<Map<String, dynamic>>.from(data);
      _isAllFruitLoaded = true;
    }
  }

  /// Load all fruit
  Future<void> loadAllFruit({bool refresh = false}) async {
    // Performance: Skip if already loading
    if (_isLoadingAllFruit && !refresh) {
      return;
    }
    
    // Performance: Skip if data already loaded and not refreshing
    if (_isAllFruitLoaded && !refresh && allFruit.isNotEmpty) {
      return;
    }

    _isLoadingAllFruit = true;
    isLoading.value = true;
    message.value = '';

    try {
      final fruit = await FruitService.getAllFruit();
      allFruit.value = fruit;
      _isAllFruitLoaded = true;
    } catch (e) {
      message.value = 'Error loading fruit: ${e.toString().replaceAll('Exception: ', '')}';
      print('Error loading fruit: $e');
      if (refresh) {
        allFruit.value = [];
        _isAllFruitLoaded = false;
      }
    } finally {
      _isLoadingAllFruit = false;
      isLoading.value = false;
    }
  }

  /// Load user's selected fruit
  Future<void> loadUserFruit({bool refresh = false}) async {
    // Performance: Skip if already loading
    if (_isLoadingUserFruit && !refresh) {
      return;
    }
    
    // Performance: Skip if data already loaded and not refreshing
    if (_isUserFruitLoaded && !refresh && userFruit.isNotEmpty) {
      return;
    }
    
    if (userId.value == 0) {
      await _loadUserId();
    }

    if (userId.value == 0) {
      userFruit.value = [];
      _isUserFruitLoaded = true;
      return;
    }

    _isLoadingUserFruit = true;
    try {
      final fruit = await FruitService.getUserFruit(userId.value);
      userFruit.value = fruit;
      _isUserFruitLoaded = true;
    } catch (e) {
      print('Error loading user fruit: $e');
      if (refresh) {
        userFruit.value = [];
        _isUserFruitLoaded = false;
      }
    } finally {
      _isLoadingUserFruit = false;
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
      await FruitService.addFruitToUser(
        userId: userId.value,
        fruitId: fruitId,
      );
      
      // Reload user fruit (refresh to get updated data)
      await loadUserFruit(refresh: true);
      await loadAllFruit(refresh: true);
      
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
      await FruitService.removeFruitFromUser(
        userId: userId.value,
        fruitId: fruitId,
      );
      
      // Reload user fruit (refresh to get updated data)
      await loadUserFruit(refresh: true);
      await loadAllFruit(refresh: true);
      
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
    return userFruit.any((fruit) => 
      fruit['id'] == fruitId && (fruit['is_selected'] == 1 || fruit['is_selected'] == true)
    );
  }

  /// Refresh all data
  Future<void> refresh() async {
    _isAllFruitLoaded = false;
    _isUserFruitLoaded = false;
    await Future.wait([
      loadAllFruit(refresh: true),
      loadUserFruit(refresh: true),
    ]);
  }
}

