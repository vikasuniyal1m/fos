import 'dart:convert';
import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User Storage Service
/// Manages user session data in local storage using Hive
class UserStorage {
  static const String _boxName = 'user_storage';
  static const String _keyUser = 'user_data';
  static const String _keyUserId = 'user_id';
  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyUserFeeling = 'user_feeling'; // Store selected emoji locally
  static const String _keyOnboardingSeen = 'onboarding_seen'; // Track if user has seen onboarding
  static const String _keyUgcTermsAccepted = 'ugc_terms_accepted'; // Track if user has accepted UGC terms
  
  static Box? _box;
  static bool _isInitialized = false;
  static bool _migrationDone = false;

  /// Initialize Hive box for user storage
  static Future<void> init() async {
    if (_isInitialized) return;
    
    try {
      _box = await Hive.openBox(_boxName);
      _isInitialized = true;
      
      // Migrate data from SharedPreferences to Hive if needed
      if (!_migrationDone) {
        await _migrateFromSharedPreferences();
        _migrationDone = true;
      }
    } catch (e) {
      print('⚠️ Error initializing Hive box: $e');
      try {
        // If box is already open, get it
        _box = Hive.box(_boxName);
        _isInitialized = true;
      } catch (e2) {
        print('⚠️ Error getting Hive box: $e2');
        // Create a new box if all else fails
        _box = await Hive.openBox(_boxName);
        _isInitialized = true;
      }
    }
  }

  /// Migrate data from SharedPreferences to Hive
  static Future<void> _migrateFromSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check if data exists in SharedPreferences
      final hasOldData = prefs.containsKey(_keyUser) || 
                        prefs.containsKey(_keyUserId) || 
                        prefs.containsKey(_keyIsLoggedIn);
      
      // Check if data already exists in Hive
      final box = _box!;
      final hasHiveData = box.containsKey(_keyUser) || 
                         box.containsKey(_keyUserId) || 
                         box.containsKey(_keyIsLoggedIn);
      
      // Only migrate if old data exists and Hive is empty
      if (hasOldData && !hasHiveData) {
        print('🔄 Migrating user data from SharedPreferences to Hive...');
        
        final userJson = prefs.getString(_keyUser);
        final userId = prefs.getInt(_keyUserId);
        final isLoggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;
        
        if (userJson != null) {
          await box.put(_keyUser, userJson);
        }
        if (userId != null) {
          await box.put(_keyUserId, userId);
        }
        await box.put(_keyIsLoggedIn, isLoggedIn);
        
        print('✅ Migration completed successfully');
      }
    } catch (e) {
      print('⚠️ Error migrating from SharedPreferences: $e');
      // Continue even if migration fails
    }
  }

  /// Get the Hive box (initializes if needed)
  static Future<Box> _getBox() async {
    if (!_isInitialized || _box == null) {
      await init();
    }
    if (_box == null) {
      throw Exception('Hive box is not initialized');
    }
    return _box!;
  }

  /// Save User Data
  static Future<void> saveUser(Map<String, dynamic> user) async {
    final box = await _getBox();
    await box.put(_keyUser, jsonEncode(user));

    // Safely parse ID which might be String or Int from different APIs
    int? userId;
    if (user['id'] != null) {
      if (user['id'] is int) {
        userId = user['id'] as int;
      } else if (user['id'] is String) {
        userId = int.tryParse(user['id']);
      }
    }

    if (userId != null) {
      await box.put(_keyUserId, userId);
      print('✅ User ID saved to storage: $userId');
    } else {
      print('⚠️ Warning: No valid ID found in user data: ${user['id']}');
    }

    await box.put(_keyIsLoggedIn, true);
  }

  /// Get User Data
  static Future<Map<String, dynamic>?> getUser() async {
    try {
      final box = await _getBox();
      final userJson = box.get(_keyUser);
      if (userJson is String && userJson.isNotEmpty) {
        return jsonDecode(userJson) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('⚠️ Error getting user data from Hive: $e');
      return null;
    }
  }

  /// Get User ID
  static Future<int?> getUserId() async {
    try {
      final box = await _getBox();
      final userId = box.get(_keyUserId);
      if (userId is int) {
        return userId;
      } else if (userId is String) {
        final parsed = int.tryParse(userId);
        if (parsed != null) return parsed;
      }

      // Fallback: Check in user_data map if ID exists there
      final user = await getUser();
      if (user != null && user['id'] != null) {
        if (user['id'] is int) return user['id'] as int;
        if (user['id'] is String) return int.tryParse(user['id']);
      }

      return null;
    } catch (e) {
      print('⚠️ Error getting user ID from Hive: $e');
      return null;
    }
  }

  /// Check if User is Logged In
  static Future<bool> isLoggedIn() async {
    try {
      final box = await _getBox()
          .timeout(const Duration(seconds: 3), onTimeout: () {
        print('⚠️ Hive box initialization timed out');
        throw TimeoutException('Hive initialization timeout');
      });
      final isLoggedIn = box.get(_keyIsLoggedIn);
      if (isLoggedIn is bool) {
        return isLoggedIn;
      }
      return false;
    } catch (e) {
      print('⚠️ Error checking login status from Hive: $e');
      return false;
    }
  }

  /// Clear User Data (Logout)
  static Future<void> clearUser() async {
    final box = await _getBox();
    await box.delete(_keyUser);
    await box.delete(_keyUserId);
    await box.delete(_keyUserFeeling); // Also clear feeling on logout
    await box.delete(_keyUgcTermsAccepted); // Clear terms acceptance on logout to ensure safety
    await box.put(_keyIsLoggedIn, false);
  }

  /// Clear User Data (Alias for clearUser - for account deletion)
  /// Clears all user data from local storage
  static Future<void> clear() async {
    await clearUser();
  }

  /// Update User Data
  static Future<void> updateUser(Map<String, dynamic> updatedData) async {
    final currentUser = await getUser();
    if (currentUser != null) {
      currentUser.addAll(updatedData);
      await saveUser(currentUser);
    }
  }

  /// Save User Feeling (Selected Emoji) - For instant UI updates
  static Future<void> saveUserFeeling(Map<String, dynamic> feeling) async {
    try {
      final box = await _getBox();
      await box.put(_keyUserFeeling, jsonEncode(feeling));
      print('✅ User feeling saved to local storage: ${feeling['emoji']}');
    } catch (e) {
      print('⚠️ Error saving user feeling to local storage: $e');
    }
  }

  /// Get User Feeling (Selected Emoji) - For instant UI updates
  static Future<Map<String, dynamic>?> getUserFeeling() async {
    try {
      final box = await _getBox();
      final feelingJson = box.get(_keyUserFeeling);
      if (feelingJson is String && feelingJson.isNotEmpty) {
        final feeling = jsonDecode(feelingJson) as Map<String, dynamic>;
        print('✅ User feeling loaded from local storage: ${feeling['emoji']}');
        return feeling;
      }
      return null;
    } catch (e) {
      print('⚠️ Error getting user feeling from local storage: $e');
      return null;
    }
  }

  /// Clear User Feeling (when user logs out or clears data)
  static Future<void> clearUserFeeling() async {
    try {
      final box = await _getBox();
      await box.delete(_keyUserFeeling);
      print('✅ User feeling cleared from local storage');
    } catch (e) {
      print('⚠️ Error clearing user feeling from local storage: $e');
    }
  }

  /// Mark Onboarding as Seen
  static Future<void> setOnboardingSeen() async {
    try {
      final box = await _getBox();
      await box.put(_keyOnboardingSeen, true);
      print('✅ Onboarding marked as seen');
    } catch (e) {
      print('⚠️ Error saving onboarding status: $e');
    }
  }

  /// Check if Onboarding has been Seen
  static Future<bool> hasSeenOnboarding() async {
    try {
      final box = await _getBox()
          .timeout(const Duration(seconds: 3), onTimeout: () {
        print('⚠️ Hive box initialization timed out');
        throw TimeoutException('Hive initialization timeout');
      });
      final hasSeen = box.get(_keyOnboardingSeen);
      if (hasSeen is bool) {
        return hasSeen;
      }
      // Default to false if not set (first time user)
      return false;
    } catch (e) {
      print('⚠️ Error checking onboarding status: $e');
      // Default to false on error (show onboarding to be safe)
      return false;
    }
  }

  /// Reset Onboarding Status (for testing purposes)
  static Future<void> resetOnboarding() async {
    try {
      final box = await _getBox();
      await box.delete(_keyOnboardingSeen);
      print('✅ Onboarding status reset');
    } catch (e) {
      print('⚠️ Error resetting onboarding status: $e');
    }
  }
  /// Mark UGC Terms as Accepted
  static Future<void> setUgcTermsAccepted(bool accepted) async {
    try {
      final box = await _getBox();
      await box.put(_keyUgcTermsAccepted, accepted);
      print('✅ UGC terms acceptance status updated: $accepted');
    } catch (e) {
      print('⚠️ Error saving terms acceptance status: $e');
    }
  }

  /// Check if UGC Terms have been Accepted
  static Future<bool> hasAcceptedUgcTerms() async {
    try {
      final box = await _getBox();
      return box.get(_keyUgcTermsAccepted, defaultValue: false);
    } catch (e) {
      print('⚠️ Error checking terms acceptance status: $e');
      return false;
    }
  }
}

