import 'dart:async';

import 'package:get/get.dart';
import 'package:fruitsofspirit/services/gallery_service.dart';
import 'package:fruitsofspirit/services/hive_cache_service.dart';
import 'package:fruitsofspirit/services/stories_service.dart';
import 'package:fruitsofspirit/services/user_storage.dart';

/// Stories list — instant cache + silent background sync.
class StoriesController extends GetxController {
  var isLoading = false.obs;
  var stories = <Map<String, dynamic>>[].obs;
  var selectedFruitTag = RxnString();

  final int itemsPerPage = 20;
  var currentPage = 0;

  var _allStories = <Map<String, dynamic>>[];
  int _loadGeneration = 0;
  DateTime? _lastSyncedAt;
  static const Duration _minSyncInterval = Duration(minutes: 2);
  Completer<void>? _activeLoadCompleter;
  var _isLoading = false;
  int userId = 0;

  @override
  void onInit() {
    super.onInit();
    unawaited(_loadUserId());
  }

  Future<void> _loadUserId() async {
    final id = await UserStorage.getUserId();
    if (id != null) {
      userId = id;
    }
  }

  void seedFromHomeIfEmpty(List<Map<String, dynamic>> homeStories) {
    if (_allStories.isNotEmpty || homeStories.isEmpty) return;
    _allStories = List<Map<String, dynamic>>.from(homeStories);
    _applyClientSideFilter();
  }

  void loadFromHiveIfEmpty() {
    if (_allStories.isNotEmpty) return;
    final cached = HiveCacheService.getCachedList('stories_list');
    if (cached.isEmpty) {
      final homeCached = HiveCacheService.getCachedList('home_stories');
      if (homeCached.isNotEmpty) {
        seedFromHomeIfEmpty(homeCached);
      }
      return;
    }
    _allStories = List<Map<String, dynamic>>.from(cached);
    _applyClientSideFilter();
  }

  void setFruitTag(String? tag) {
    selectedFruitTag.value = tag;
    _applyClientSideFilter();
  }

  void _applyClientSideFilter() {
    if (_allStories.isEmpty) {
      stories.value = [];
      return;
    }

    final tag = selectedFruitTag.value;
    if (tag == null || tag.isEmpty) {
      stories.value = List<Map<String, dynamic>>.from(_allStories);
      return;
    }

    final normalized = tag.toLowerCase().trim();
    stories.value = _allStories.where((story) {
      final storyTag = (story['fruit_tag'] as String? ?? '').toLowerCase().trim();
      return storyTag == normalized;
    }).toList();
  }

  Future<void> loadStories({bool refresh = false, bool silent = false}) async {
    if (_isLoading) {
      if (_activeLoadCompleter != null) {
        await _activeLoadCompleter!.future;
      }
      return;
    }

    if (!refresh &&
        _allStories.isNotEmpty &&
        (selectedFruitTag.value == null || selectedFruitTag.value!.isEmpty)) {
      _applyClientSideFilter();
      return;
    }

    if (silent &&
        _lastSyncedAt != null &&
        DateTime.now().difference(_lastSyncedAt!) < _minSyncInterval) {
      _applyClientSideFilter();
      return;
    }

    final generation = silent ? _loadGeneration : ++_loadGeneration;
    _activeLoadCompleter = Completer<void>();

    if (refresh) {
      currentPage = 0;
    }

    _isLoading = true;
    if (!silent) {
      isLoading.value = true;
    }

    try {
      if (userId == 0) {
        await _loadUserId();
      }

      final allStories = <Map<String, dynamic>>[];

      try {
        final storiesList = await StoriesService.getStories(
          status: 'Approved',
          fruitTag: null,
          limit: itemsPerPage,
          offset: currentPage * itemsPerPage,
        );
        allStories.addAll(storiesList);
      } catch (e) {
        print('Stories API error: $e');
      }

      try {
        final galleryPhotos = await GalleryService.getPhotos(
          status: 'Approved',
          fruitTag: null,
          currentUserId: userId > 0 ? userId : null,
          limit: itemsPerPage,
          offset: currentPage * itemsPerPage,
        );

        final storyPhotos = galleryPhotos.where((photo) {
          final hasTitle =
              photo['title'] != null && (photo['title'] as String).isNotEmpty;
          final hasContent = photo['content'] != null &&
              (photo['content'] as String).isNotEmpty;
          final hasTestimony = photo['testimony'] != null &&
              (photo['testimony'] as String).isNotEmpty;
          return hasTitle || hasContent || hasTestimony;
        }).toList();

        for (final photo in storyPhotos) {
          allStories.add({
            'id': photo['id'],
            'title': photo['title'] ??
                photo['testimony']?.toString().split('\n').first ??
                'Untitled Story',
            'content': photo['content'] ?? photo['testimony'] ?? '',
            'image_url': photo['file_path'] ?? photo['thumbnail_path'],
            'file_path': photo['file_path'],
            'thumbnail_path': photo['thumbnail_path'],
            'fruit_tag': photo['fruit_tag'],
            'user_name': photo['user_name'],
            'profile_photo': photo['profile_photo'],
            'created_at': photo['created_at'],
            'is_gallery_story': true,
          });
        }
      } catch (e) {
        print('Gallery API error: $e');
      }

      if (generation != _loadGeneration) {
        return;
      }

      if (refresh || currentPage == 0) {
        _allStories = List<Map<String, dynamic>>.from(allStories);
      } else {
        _allStories.addAll(allStories);
      }

      _applyClientSideFilter();
      _lastSyncedAt = DateTime.now();
      unawaited(HiveCacheService.cacheList('stories_list', _allStories));
    } catch (e) {
      print('Error loading stories: $e');
      if (_allStories.isEmpty) {
        stories.value = [];
      }
      if (!silent) {
        rethrow;
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
}
