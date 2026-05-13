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
      // Skip pre-caching to avoid network issues
      // Just ensure the category is in the cachedFiles map with the URL
      _cachedFiles[category] = url;
    } catch (e) {
      print('⚠️ Error pre-caching jingle for $category: $e');
    }
  }

  // Global flag to enable/disable jingles - set to true to enable
  static bool enableJingles = true;

  // Categories that should NOT play audio
  static const List<String> _blockedCategories = [
    'praise report',
    'holiday',
  ];

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

  Future<bool> startJingle(String category, {String? groupName}) async {
    initialize();
    final cleanCategory = category.trim().toLowerCase();
    print('DEBUG: JingleService.startJingle - category: "$cleanCategory"');
    if (cleanCategory.isEmpty) {
      print('DEBUG: JingleService.startJingle - category is empty, returning false');
      return false;
    }

    // Check if group name contains blocked terms (holiday, praise report)
    if (groupName != null && groupName.isNotEmpty) {
      final cleanGroupName = groupName.trim().toLowerCase();
      for (var blockedTerm in _blockedCategories) {
        if (cleanGroupName.contains(blockedTerm)) {
          print('DEBUG: JingleService.startJingle - group name "$cleanGroupName" contains blocked term "$blockedTerm", skipping jingle');
          return false;
        }
      }
    }

    // Check if category is blocked (praise, report, holiday)
    if (_blockedCategories.contains(cleanCategory)) {
      print('DEBUG: JingleService.startJingle - category "$cleanCategory" is blocked, skipping jingle');
      return false;
    }

    // Check global enable flag
    if (!enableJingles) {
      print('DEBUG: JingleService.startJingle - jingles disabled globally, skipping');
      return false;
    }

    final isDisabled = await _isJingleDisabled(cleanCategory);
    print('DEBUG: JingleService.startJingle - isDisabled: $isDisabled, _isPlaying: $_isPlaying');
    if (isDisabled) return false;

    // Reset playing state to ensure we can play new jingles
    if (_isPlaying) {
      try {
        await _audioPlayer.stop();
        _isPlaying = false;
      } catch (e) {
        print('DEBUG: JingleService.startJingle - Error stopping previous jingle: $e');
        _isPlaying = false;
      }
    }

    final url = _getJingleUrl(cleanCategory);
    
    // Always try to play jingle, don't skip based on mapping existence
    // The _getJingleUrl method already handles fallback logic
    print('🔊 JingleService: Playing from URL: $url');

    try {
      _isPlaying = true;
      
      print('DEBUG: JingleService.startJingle - Caching file from: $url');
      // 1. Get the file via CacheManager (downloads if not cached)
      final fileInfo = await DefaultCacheManager().getSingleFile(url);
      final localPath = fileInfo.path;
      print('DEBUG: JingleService.startJingle - Playing from local path: $localPath');

      // 2. Play using DeviceFileSource instead of UrlSource
      await _audioPlayer.setSource(DeviceFileSource(localPath));
      print('DEBUG: JingleService.startJingle - Resuming audio player');
      await _audioPlayer.resume();

      // Listen for completion
      _audioPlayer.onPlayerComplete.first.then((_) async {
        _isPlaying = false;
        await _incrementPlayCount(category);
        lastFinishedCategory.value = category;
        lastFinishedCategory.refresh();
        print('DEBUG: JingleService.startJingle - Jingle completed: $category');
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
