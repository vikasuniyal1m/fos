import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:fruitsofspirit/services/user_storage.dart';
import 'package:fruitsofspirit/config/image_config.dart';

/// Jingle Service
/// Handles voice over playback for group categories
class JingleService {
  static final JingleService _instance = JingleService._internal();
  factory JingleService() => _instance;
  JingleService._internal();

  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  bool _isInitialized = false;

  /// Initialize audio player
  void _initializeAudioPlayer() {
    if (!_isInitialized) {
      _audioPlayer = AudioPlayer();
      _audioPlayer.setPlayerMode(PlayerMode.mediaPlayer);
      _isInitialized = true;
      print('✅ AudioPlayer initialized');
    }
  }

  // Map category names to jingle file names
  // Note: 9 voice overs total (8 via WhatsApp + 1 via email = Patience)
  // Currently 8 files in folder, Patience file needs to be added to api/jingle/ folder
  static const Map<String, String> _categoryToJingle = {
    'Love': 'Welcome - LOVE.mp3',           // ✅ File exists
    'Joy': 'Welcome - JOY.mp3',             // ✅ File exists
    'Peace': 'Welcome - PEACE.mp3',         // ✅ File exists
    'Patience': 'Welcome - PATIENCE.mp3',    // ⚠️ 9th file (emailed) - needs to be added to api/jingle/
    'Kindness': 'Welcome - KINDNESS.mp3',    // ✅ File exists
    'Goodness': 'Welcome - GOODNESS.mp3',   // ✅ File exists
    'Faithfulness': 'Welcome - FAITHFULNESS.mp3', // ✅ File exists
    'Gentleness': 'Welcome - MEEKNESS.mp3',  // ✅ File exists
    'Self-Control': 'Welcome - SELF CONTROL.mp3', // ✅ File exists
  };

  // Storage keys for play count and disable preference
  static const String _keyJinglePlayCount = 'jingle_play_count_';
  static const String _keyJingleDisabled = 'jingle_disabled_';
  static const int _maxPlaysBeforeOption = 3;

  /// Get jingle URL for a category
  String _getJingleUrl(String category) {
    final jingleFileName = _categoryToJingle[category];
    if (jingleFileName == null) {
      print('⚠️ No jingle file found for category: $category');
      return ''; // No jingle for this category
    }
    
    // Construct URL: base URL + jingle folder + filename
    // URL format: https://fruitofthespirit.templateforwebsites.com/api/jingle/Welcome%20-%20LOVE.mp3
    // baseUrl is: https://fruitofthespirit.templateforwebsites.com/uploads/
    // So we need: https://fruitofthespirit.templateforwebsites.com/api/jingle/
    final baseUrl = ImageConfig.baseUrl.replaceAll('/uploads/', '');
    // Encode filename for URL (handle spaces and special characters)
    final encodedFileName = Uri.encodeComponent(jingleFileName);
    final fullUrl = '$baseUrl/api/jingle/$encodedFileName';
    print('🔊 Jingle URL for $category: $fullUrl');
    return fullUrl;
  }
  
  /// Get fallback jingle URL if primary doesn't exist (for Patience)
  String _getFallbackJingleUrl(String category) {
    if (category == 'Patience') {
      // Fallback to MEEKNESS if PATIENCE file doesn't exist
      final baseUrl = ImageConfig.baseUrl.replaceAll('/uploads/', '');
      final encodedFileName = Uri.encodeComponent('Welcome - MEEKNESS.mp3');
      return '$baseUrl/api/jingle/$encodedFileName';
    }
    return '';
  }

  /// Get Hive box (helper method)
  Future<dynamic> _getBox() async {
    try {
      // Use reflection or direct Hive access
      // Since UserStorage uses Hive, we'll use Hive directly
      await UserStorage.init();
      return await Hive.openBox('user_storage');
    } catch (e) {
      // If box is already open, get it
      return Hive.box('user_storage');
    }
  }

  /// Get play count for a category
  Future<int> _getPlayCount(String category) async {
    try {
      final box = await _getBox();
      final key = '$_keyJinglePlayCount$category';
      final count = box.get(key);
      if (count is int) {
        return count;
      }
      return 0;
    } catch (e) {
      print('⚠️ Error getting play count: $e');
      return 0;
    }
  }

  /// Increment play count for a category
  Future<void> _incrementPlayCount(String category) async {
    try {
      final box = await _getBox();
      final key = '$_keyJinglePlayCount$category';
      final currentCount = await _getPlayCount(category);
      await box.put(key, currentCount + 1);
    } catch (e) {
      print('⚠️ Error incrementing play count: $e');
    }
  }

  /// Check if jingle is disabled for a category
  Future<bool> _isJingleDisabled(String category) async {
    try {
      final box = await _getBox();
      final key = '$_keyJingleDisabled$category';
      final disabled = box.get(key);
      if (disabled is bool) {
        return disabled;
      }
      return false;
    } catch (e) {
      print('⚠️ Error checking jingle disabled status: $e');
      return false;
    }
  }

  /// Disable jingle for a category
  Future<void> disableJingle(String category) async {
    try {
      final box = await _getBox();
      final key = '$_keyJingleDisabled$category';
      await box.put(key, true);
    } catch (e) {
      print('⚠️ Error disabling jingle: $e');
    }
  }

  /// Enable jingle for a category (reset)
  Future<void> enableJingle(String category) async {
    try {
      final box = await _getBox();
      final key = '$_keyJingleDisabled$category';
      await box.delete(key);
    } catch (e) {
      print('⚠️ Error enabling jingle: $e');
    }
  }

  /// Check if user should see option to disable jingle
  Future<bool> shouldShowDisableOption(String category) async {
    final playCount = await _getPlayCount(category);
    final isDisabled = await _isJingleDisabled(category);
    return playCount >= _maxPlaysBeforeOption && !isDisabled;
  }

  /// Start playing jingle for a category (non-blocking, doesn't wait for completion)
  /// Returns true if jingle started playing, false otherwise
  Future<bool> startJingle(String category) async {
    print('🔊 startJingle called for category: $category');
    
    // Initialize audio player if needed
    _initializeAudioPlayer();
    
    // Check if jingle is disabled
    final isDisabled = await _isJingleDisabled(category);
    if (isDisabled) {
      print('⚠️ Jingle is disabled for category: $category');
      return false;
    }

    // Check if already playing
    if (_isPlaying) {
      print('⚠️ Jingle is already playing');
      return false;
    }

    // Get jingle URL
    final jingleUrl = _getJingleUrl(category);
    if (jingleUrl.isEmpty) {
      print('⚠️ Empty jingle URL for category: $category');
      return false; // No jingle for this category
    }

    try {
      _isPlaying = true;
      print('🔊 Starting to play jingle: $jingleUrl');
      
      // Stop any currently playing audio
      try {
        await _audioPlayer.stop();
      } catch (e) {
        // Ignore if nothing is playing
      }
      
      // Start playing the jingle (non-blocking)
      await _audioPlayer.play(UrlSource(jingleUrl));
      print('✅ Jingle play command sent successfully');
      
      // Handle completion in background (don't wait)
      _audioPlayer.onPlayerComplete.first.then((_) {
        print('✅ Jingle playback completed');
        _isPlaying = false;
        // Increment play count after completion
        _incrementPlayCount(category).then((_) async {
          // Check if we should show disable option after 3 plays
          final shouldShow = await shouldShowDisableOption(category);
          if (shouldShow) {
            print('🔔 Should show disable option for $category (3+ plays)');
            // Show snackbar with option to disable
            Get.rawSnackbar(
              message: 'You\'ve heard this voice over 3 times. Tap to disable.',
              duration: const Duration(seconds: 4),
              backgroundColor: Colors.blue,
              snackPosition: SnackPosition.BOTTOM,
              onTap: (snack) async {
                await disableJingle(category);
                Get.closeCurrentSnackbar();
                Get.snackbar(
                  'Voice Over Disabled',
                  'Voice over for $category has been disabled.',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.green,
                  colorText: Colors.white,
                  duration: const Duration(seconds: 2),
                );
              },
            );
          }
        });
      }).catchError((e) {
        print('⚠️ Error in jingle completion: $e');
        _isPlaying = false;
      });

      // Listen for player state changes
      _audioPlayer.onPlayerStateChanged.listen((state) {
        print('🔊 Player state changed: $state');
        if (state == PlayerState.completed) {
          _isPlaying = false;
        }
      });

      return true;
    } catch (e, stackTrace) {
      print('⚠️ Error starting jingle: $e');
      print('⚠️ Stack trace: $stackTrace');
      _isPlaying = false;
      return false;
    }
  }

  /// Play jingle for a category
  /// Returns true if jingle was played, false otherwise
  Future<bool> playJingle(String category) async {
    // Check if jingle is disabled
    final isDisabled = await _isJingleDisabled(category);
    if (isDisabled) {
      return false;
    }

    // Check if already playing
    if (_isPlaying) {
      return false;
    }

    // Get jingle URL
    final jingleUrl = _getJingleUrl(category);
    if (jingleUrl.isEmpty) {
      return false; // No jingle for this category
    }

    try {
      _isPlaying = true;
      
      // Play the jingle
      await _audioPlayer.play(UrlSource(jingleUrl));
      
      // Wait for playback to complete
      await _audioPlayer.onPlayerComplete.first.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print('⚠️ Jingle playback timeout');
        },
      );

      // Increment play count
      await _incrementPlayCount(category);

      return true;
    } catch (e) {
      print('⚠️ Error playing jingle: $e');
      return false;
    } finally {
      _isPlaying = false;
    }
  }

  /// Stop current jingle
  Future<void> stopJingle() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.stop();
        _isPlaying = false;
      }
    } catch (e) {
      print('⚠️ Error stopping jingle: $e');
    }
  }

  /// Dispose audio player
  void dispose() {
    _audioPlayer.dispose();
  }
}

