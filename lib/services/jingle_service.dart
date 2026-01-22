import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:fruitsofspirit/services/user_storage.dart';
import 'package:fruitsofspirit/config/image_config.dart';
import 'package:fruitsofspirit/config/api_config.dart';

/// Jingle Service
/// Handles voice over playback for group categories
class JingleService extends GetxController {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  bool _isInitialized = false;
  final Map<String, String> _cachedFiles = {};

  // Observable to notify listeners when a jingle finishes
  final RxString lastFinishedCategory = ''.obs;

  @override
  void onInit() {
    super.onInit();
    initialize();
  }

  /// Initialize audio player and pre-cache jingles
  void initialize() {
    if (!_isInitialized) {
      _audioPlayer = AudioPlayer();
      _audioPlayer.setPlayerMode(PlayerMode.mediaPlayer);
      _isInitialized = true;
      print('✅ JingleService: AudioPlayer initialized');
      _preCacheAllJingles();
    }
  }

  void _preCacheAllJingles() {
    for (var category in _categoryToJingle.keys) {
      _preCacheJingle(category);
    }
  }

  Future<void> _preCacheJingle(String category) async {
    final url = _getJingleUrl(category);
    if (url.isEmpty) return;
    try {
      final fileInfo = await DefaultCacheManager().getFileFromCache(url);
      if (fileInfo != null) {
        _cachedFiles[category] = fileInfo.file.path;
      } else {
        final file = await DefaultCacheManager().getSingleFile(url);
        _cachedFiles[category] = file.path;
      }
    } catch (e) {
      print('⚠️ Error pre-caching jingle for $category: $e');
    }
  }

  static const Map<String, String> _categoryToJingle = {
    'Love': 'Welcome - LOVE.mp3',
    'Joy': 'Welcome - JOY.mp3',
    'Peace': 'Welcome - PEACE.mp3',
    'Kindness': 'Welcome - KINDNESS.mp3',
    'Goodness': 'Welcome - GOODNESS.mp3',
    'Faithfulness': 'Welcome - FAITHFULNESS.mp3',
    'Gentleness': 'Welcome - MEEKNESS.mp3',
    'Meekness': 'Welcome - MEEKNESS.mp3',
    'Self-Control': 'Welcome - SELF CONTROL.mp3',
    // Note: Patience and Prayer jingles are currently missing from server
  };

  static const String _keyJinglePlayCount = 'jingle_play_count_';
  static const String _keyJingleDisabled = 'jingle_disabled_';
  static const int _maxPlaysBeforeOption = 3;

  String _getJingleUrl(String category) {
    final cleanCategory = category.trim();
    // Try exact match
    var jingleFileName = _categoryToJingle[cleanCategory];
    
    // Try case-insensitive match if not found
    if (jingleFileName == null) {
      final key = _categoryToJingle.keys.firstWhere(
        (k) => k.toLowerCase() == cleanCategory.toLowerCase(),
        orElse: () => '',
      );
      if (key.isNotEmpty) {
        jingleFileName = _categoryToJingle[key];
      }
    }
    
    // Specific fix for Peace if still strictly null
    if (jingleFileName == null && cleanCategory.toLowerCase() == 'peace') {
      jingleFileName = 'Welcome - PEACE.mp3';
    }

    // Fallback: try to construct filename if not mapped
    if (jingleFileName == null) {
      jingleFileName = 'Welcome - ${cleanCategory.toUpperCase()}.mp3';
    }
    
    final encodedFileName = Uri.encodeComponent(jingleFileName);
    final url = '${ApiConfig.baseUrl}/jingle/$encodedFileName';
    print('🔊 JingleService: Constructed URL for "$cleanCategory": $url');
    return url;
  }

  Future<Box> _getBox() async {
    if (!Hive.isBoxOpen('user_storage')) {
      await UserStorage.init();
      return await Hive.openBox('user_storage');
    }
    return Hive.box('user_storage');
  }

  Future<int> _getPlayCount(String category) async {
    try {
      final box = await _getBox();
      final key = '$_keyJinglePlayCount${category.trim()}';
      final count = box.get(key);
      return count is int ? count : 0;
    } catch (e) {
      return 0;
    }
  }

  Future<void> _incrementPlayCount(String category) async {
    try {
      final box = await _getBox();
      final key = '$_keyJinglePlayCount${category.trim()}';
      final currentCount = await _getPlayCount(category);
      await box.put(key, currentCount + 1);
    } catch (e) {}
  }

  Future<bool> _isJingleDisabled(String category) async {
    try {
      final box = await _getBox();
      final key = '$_keyJingleDisabled${category.trim()}';
      final disabled = box.get(key);
      return disabled is bool ? disabled : false;
    } catch (e) {
      return false;
    }
  }

  Future<void> disableJingle(String category) async {
    try {
      final box = await _getBox();
      final key = '$_keyJingleDisabled${category.trim()}';
      await box.put(key, true);
      // Trigger update
      lastFinishedCategory.refresh();
    } catch (e) {}
  }

  Future<void> enableJingle(String category) async {
    try {
      final box = await _getBox();
      final key = '$_keyJingleDisabled${category.trim()}';
      await box.delete(key);
      // Trigger update
      lastFinishedCategory.refresh();
    } catch (e) {}
  }

  Future<Map<String, dynamic>> getJingleStatus(String category) async {
    final cleanCategory = category.trim();
    final isDisabled = await _isJingleDisabled(cleanCategory);
    final playCount = await _getPlayCount(cleanCategory);
    final shouldShow = playCount >= _maxPlaysBeforeOption;
    return {
      'isDisabled': isDisabled,
      'playCount': playCount,
      'shouldShowOption': shouldShow,
    };
  }

  Future<void> stopJingle() async {
    try {
      await _audioPlayer.stop();
      _isPlaying = false;
    } catch (e) {}
  }

  Future<bool> startJingle(String category) async {
    initialize();
    final cleanCategory = category.trim();
    print('DEBUG: JingleService.startJingle - category: "$cleanCategory"');
    if (cleanCategory.isEmpty) {
      print('DEBUG: JingleService.startJingle - category is empty, returning false');
      return false;
    }

    final isDisabled = await _isJingleDisabled(cleanCategory);
    print('DEBUG: JingleService.startJingle - isDisabled: $isDisabled, _isPlaying: $_isPlaying');
    if (isDisabled || _isPlaying) return false;

    final url = _getJingleUrl(cleanCategory);
    // Check if mapping exists in our constant map to avoid 404s for categories like 'Prayer' or 'Patience'
    // which are currently missing from the server
    final jingleFileName = _categoryToJingle[cleanCategory];
    if (jingleFileName == null) {
      print('⚠️ JingleService: No jingle mapping for "$cleanCategory", skipping playback.');
      return false;
    }

    // Use cached file path if available, otherwise use URL
    String jinglePath = _cachedFiles[cleanCategory] ?? url;
    
    print('🔊 JingleService: Playing from ${jinglePath.startsWith('http') ? 'URL' : 'Cache'}: $jinglePath');

    try {
      _isPlaying = true;
      final isLocal = !jinglePath.startsWith('http');
      if (isLocal) {
        print('DEBUG: JingleService.startJingle - Setting local source: $jinglePath');
        await _audioPlayer.setSource(DeviceFileSource(jinglePath));
      } else {
        print('DEBUG: JingleService.startJingle - Setting URL source: $jinglePath');
        await _audioPlayer.setSource(UrlSource(jinglePath, mimeType: 'audio/mpeg'));
      }
      print('DEBUG: JingleService.startJingle - Resuming audio player');
      await _audioPlayer.resume();

      // Listen for completion
      _audioPlayer.onPlayerComplete.first.then((_) async {
        _isPlaying = false;
        await _incrementPlayCount(category);
        // Update observable to notify screen
        lastFinishedCategory.value = category;
        lastFinishedCategory.refresh();
        print('DEBUG: JingleService.startJingle - Jingle completed for category: $category');
      });

      return true;
    } catch (e) {
      _isPlaying = false;
      print('ERROR: JingleService.startJingle - Failed to play jingle: $e');
      return false;
    }
  }

  @override
  void onClose() {
    _audioPlayer.dispose();
    super.onClose();
  }
}
