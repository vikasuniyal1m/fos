import 'package:fruitsofspirit/services/fruits_service.dart';
import 'package:fruitsofspirit/services/prayers_service.dart';
import 'package:fruitsofspirit/services/blogs_service.dart';
import 'package:fruitsofspirit/services/videos_service.dart';
import 'package:fruitsofspirit/services/gallery_service.dart';
import 'package:fruitsofspirit/services/groups_service.dart';
import 'package:fruitsofspirit/services/emojis_service.dart';
import 'package:fruitsofspirit/services/profile_service.dart';
import 'package:fruitsofspirit/services/user_storage.dart';
import 'package:fruitsofspirit/services/cache_service.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/controllers/fruits_controller.dart';
import 'package:fruitsofspirit/controllers/prayers_controller.dart';
import 'package:fruitsofspirit/controllers/blogs_controller.dart';
import 'package:fruitsofspirit/controllers/videos_controller.dart';
import 'package:fruitsofspirit/controllers/gallery_controller.dart';
import 'package:fruitsofspirit/controllers/groups_controller.dart';
import 'package:fruitsofspirit/controllers/profile_controller.dart';
import 'package:fruitsofspirit/controllers/home_controller.dart';

/// Data Loading Service
/// Handles initial data loading and caching for the app
class DataLoadingService {
  static const String _cacheKeyFruits = 'home_fruits';
  static const String _cacheKeyPrayers = 'home_prayers';
  static const String _cacheKeyBlogs = 'home_blogs';
  static const String _cacheKeyVideos = 'home_videos';
  static const String _cacheKeyLiveVideos = 'home_live_videos';
  static const String _cacheKeyGalleryPhotos = 'home_gallery_photos';
  static const String _cacheKeyGroups = 'home_groups';
  static const String _cacheKeyEmojis = 'home_emojis';
  static const String _cacheKeyProfile = 'user_profile';

  /// Load all home page data and cache it
  /// Returns a map with all loaded data
  /// If [preferCache] is true, it returns cached data instantly while refreshing in background
  static Future<Map<String, dynamic>> loadAllHomeData({bool preferCache = true}) async {
    try {
      print('🔄 Starting to load all home data (preferCache: $preferCache)...');
      
      final userId = await UserStorage.getUserId();
      final isLoggedIn = await UserStorage.isLoggedIn();

      // If preferCache is true, check if we have enough cached data to show instantly
      if (preferCache) {
        final cachedData = await _getAllCachedData();
        // Check if we have at least fruits in cache
        final hasCriticalCache = (cachedData['fruits'] as List).isNotEmpty;

        if (hasCriticalCache) {
          print('✅ Found critical home data in cache, returning instantly for fast startup');

          // Force refresh controllers with cached data immediately
          _refreshControllers(cachedData);

          // Trigger refresh in background without awaiting it
          _loadAllDataFromApi().then((freshData) {
            print('✅ Background home data refresh completed');
          }).catchError((e) {
            print('⚠️ Background home data refresh failed: $e');
          });

          return cachedData;
        }
      }

      // If no cache or preferCache is false, we must load from API
      // But for registered users (isLoggedIn), we want to make sure they get their data
      print('🌐 No cache or preferCache=false, fetching from API...');
      return await _loadAllDataFromApi();
    } catch (e) {
      print('❌ Error in loadAllHomeData: $e');
      return await _getAllCachedData(); // Fallback to cache on error
    }
  }

  /// Load all data from API
  static Future<Map<String, dynamic>> _loadAllDataFromApi() async {
    print('🌐 Fetching fresh home data from API...');

    // Load all data in parallel with timeout to prevent hanging
    final results = await Future.wait([
      _loadFruits().timeout(const Duration(seconds: 10), onTimeout: () => <Map<String, dynamic>>[]),
      _loadPrayers().timeout(const Duration(seconds: 10), onTimeout: () => <Map<String, dynamic>>[]),
      _loadBlogs().timeout(const Duration(seconds: 10), onTimeout: () => <Map<String, dynamic>>[]),
      _loadVideos().timeout(const Duration(seconds: 10), onTimeout: () => <Map<String, dynamic>>[]),
      _loadLiveVideos().timeout(const Duration(seconds: 10), onTimeout: () => <Map<String, dynamic>>[]),
      _loadGalleryPhotos().timeout(const Duration(seconds: 10), onTimeout: () => <Map<String, dynamic>>[]),
      _loadGroups().timeout(const Duration(seconds: 10), onTimeout: () => <Map<String, dynamic>>[]),
      _loadEmojis().timeout(const Duration(seconds: 10), onTimeout: () => <Map<String, dynamic>>[]),
      _loadProfile().timeout(const Duration(seconds: 10), onTimeout: () => <String, dynamic>{}),
    ]);

    final data = {
      'fruits': results[0],
      'prayers': results[1],
      'blogs': results[2],
      'videos': results[3],
      'liveVideos': results[4],
      'galleryPhotos': results[5],
      'groups': results[6],
      'emojis': results[7],
      'profile': results[8],
    };

    // Cache all data
    await _cacheAllData(data);

    // Force refresh data in GetX controllers if they are already initialized
    _refreshControllers(data);

    return data;
  }

  /// Get all data from cache
  static Future<Map<String, dynamic>> _getAllCachedData() async {
    final results = await Future.wait([
      CacheService.getCachedList(_cacheKeyFruits),
      CacheService.getCachedList(_cacheKeyPrayers),
      CacheService.getCachedList(_cacheKeyBlogs),
      CacheService.getCachedList(_cacheKeyVideos),
      CacheService.getCachedList(_cacheKeyLiveVideos),
      CacheService.getCachedList(_cacheKeyGalleryPhotos),
      CacheService.getCachedList(_cacheKeyGroups),
      CacheService.getCachedList(_cacheKeyEmojis),
      CacheService.getCachedMap(_cacheKeyProfile),
    ]);

    return {
      'fruits': results[0],
      'prayers': results[1],
      'blogs': results[2],
      'videos': results[3],
      'liveVideos': results[4],
      'galleryPhotos': results[5],
      'groups': results[6],
      'emojis': results[7],
      'profile': results[8],
    };
  }

  /// Cache all loaded data
  static Future<void> _cacheAllData(Map<String, dynamic> data) async {
    await Future.wait([
      CacheService.cacheList(_cacheKeyFruits, data['fruits'] as List<Map<String, dynamic>>),
      CacheService.cacheList(_cacheKeyPrayers, data['prayers'] as List<Map<String, dynamic>>),
      CacheService.cacheList(_cacheKeyBlogs, data['blogs'] as List<Map<String, dynamic>>),
      CacheService.cacheList(_cacheKeyVideos, data['videos'] as List<Map<String, dynamic>>),
      CacheService.cacheList(_cacheKeyLiveVideos, data['liveVideos'] as List<Map<String, dynamic>>),
      CacheService.cacheList(_cacheKeyGalleryPhotos, data['galleryPhotos'] as List<Map<String, dynamic>>),
      CacheService.cacheList(_cacheKeyGroups, data['groups'] as List<Map<String, dynamic>>),
      CacheService.cacheList(_cacheKeyEmojis, data['emojis'] as List<Map<String, dynamic>>),
      CacheService.cacheMap(_cacheKeyProfile, data['profile'] as Map<String, dynamic>),
    ]);
    print('💾 All data cached successfully!');
  }

  /// Load profile
  static Future<Map<String, dynamic>> _loadProfile() async {
    try {
      final userId = await UserStorage.getUserId();
      if (userId == null) return {};

      final profileData = await ProfileService.getProfile(userId);
      print('✅ Loaded profile for user $userId');
      return profileData;
    } catch (e) {
      print('❌ Error loading profile: $e');
      return {};
    }
  }

  /// Load fruits
  static Future<List<Map<String, dynamic>>> _loadFruits() async {
    try {
      final fruitsList = await FruitsService.getAllFruits();
      print('✅ Loaded ${fruitsList.length} fruits');
      return fruitsList;
    } catch (e) {
      print('❌ Error loading fruits: $e');
      return [];
    }
  }

  /// Load prayers
  static Future<List<Map<String, dynamic>>> _loadPrayers() async {
    try {
      final prayersList = await PrayersService.getPrayers(
        status: 'Approved',
        limit: 5,
      );
      print('✅ Loaded ${prayersList.length} prayers');
      return prayersList;
    } catch (e) {
      print('❌ Error loading prayers: $e');
      return [];
    }
  }

  /// Load blogs
  static Future<List<Map<String, dynamic>>> _loadBlogs() async {
    try {
      final blogsList = await BlogsService.getBlogs(
        status: 'Approved',
        limit: 5,
      );
      print('✅ Loaded ${blogsList.length} blogs');
      return blogsList;
    } catch (e) {
      print('❌ Error loading blogs: $e');
      return [];
    }
  }

  /// Load videos
  static Future<List<Map<String, dynamic>>> _loadVideos() async {
    try {
      final videosList = await VideosService.getVideos(
        status: 'Approved',
        limit: 5,
      );
      print('✅ Loaded ${videosList.length} videos');
      return videosList;
    } catch (e) {
      print('❌ Error loading videos: $e');
      return [];
    }
  }

  /// Load live videos
  static Future<List<Map<String, dynamic>>> _loadLiveVideos() async {
    try {
      final liveList = await VideosService.getLiveVideos();
      print('✅ Loaded ${liveList.length} live videos');
      return liveList;
    } catch (e) {
      print('❌ Error loading live videos: $e');
      return [];
    }
  }

  /// Load gallery photos
  static Future<List<Map<String, dynamic>>> _loadGalleryPhotos() async {
    // Always include static images
    final staticImages = [
      {
        'id': -1,
        'file_path': 'uploads/Frame.png',
        'fruit_tag': 'Love',
        'testimony': 'Frame of love and kindness',
        'user_name': 'Community',
      },
      {
        'id': -2,
        'file_path': 'uploads/Vector.png',
        'fruit_tag': 'Joy',
        'testimony': 'Vector of joy and peace',
        'user_name': 'Community',
      },
      {
        'id': -3,
        'file_path': 'uploads/prayer_group.jpg',
        'fruit_tag': 'Peace',
        'testimony': 'Vector of peace and harmony',
        'user_name': 'Community',
      },
    ];

    try {
      final photosList = await GalleryService.getPhotos(
        status: 'Approved',
        limit: 6,
      );
      
      // Merge API photos with static images (static images first)
      final allPhotos = [...staticImages, ...photosList];
      print('✅ Loaded ${allPhotos.length} gallery photos (${staticImages.length} static + ${photosList.length} from API)');
      return allPhotos;
    } catch (e) {
      print('❌ Error loading gallery photos: $e');
      // On error, return static images
      return staticImages;
    }
  }

  /// Load groups
  static Future<List<Map<String, dynamic>>> _loadGroups() async {
    try {
      final groupsList = await GroupsService.getGroups(
        status: 'Active',
        limit: 6,
      );
      print('✅ Loaded ${groupsList.length} groups');
      return groupsList;
    } catch (e) {
      print('❌ Error loading groups: $e');
      return [];
    }
  }

  /// Load emojis
  static Future<List<Map<String, dynamic>>> _loadEmojis() async {
    try {
      final emojisList = await EmojisService.getEmojis(
        status: 'Active',
        sortBy: 'image_url',
        order: 'ASC',
      );
      print('✅ Loaded ${emojisList.length} emojis from database');
      return emojisList;
    } catch (e) {
      print('❌ Error loading emojis: $e');
      return [];
    }
  }

  /// Get cached home data
  static Future<Map<String, dynamic>> getCachedHomeData() async {
    final cached = {
      'fruits': await CacheService.getCachedList(_cacheKeyFruits),
      'prayers': await CacheService.getCachedList(_cacheKeyPrayers),
      'blogs': await CacheService.getCachedList(_cacheKeyBlogs),
      'videos': await CacheService.getCachedList(_cacheKeyVideos),
      'liveVideos': await CacheService.getCachedList(_cacheKeyLiveVideos),
      'galleryPhotos': await CacheService.getCachedList(_cacheKeyGalleryPhotos),
      'groups': await CacheService.getCachedList(_cacheKeyGroups),
      'emojis': await CacheService.getCachedList(_cacheKeyEmojis),
      'profile': await CacheService.getCachedMap(_cacheKeyProfile),
    };
    return cached;
  }

  /// Check if home data is cached
  static Future<bool> isHomeDataCached() async {
    final cached = await getCachedHomeData();
    // Check if at least some data is cached
    return cached['fruits']?.isNotEmpty == true ||
           cached['prayers']?.isNotEmpty == true ||
           cached['blogs']?.isNotEmpty == true;
  }

  /// Force refresh data in GetX controllers if they are already initialized
  static void _refreshControllers(Map<String, dynamic> data) {
    try {
      if (Get.isRegistered<FruitsController>()) {
        Get.find<FruitsController>().setInitialData(data['fruits']);
      }
      if (Get.isRegistered<PrayersController>()) {
        Get.find<PrayersController>().setInitialData(data['prayers']);
      }
      if (Get.isRegistered<BlogsController>()) {
        Get.find<BlogsController>().setInitialData(data['blogs']);
      }
      if (Get.isRegistered<VideosController>()) {
        Get.find<VideosController>().setInitialData(data['videos']);
      }
      if (Get.isRegistered<GalleryController>()) {
        Get.find<GalleryController>().setInitialData(data['galleryPhotos']);
      }
      if (Get.isRegistered<GroupsController>()) {
        Get.find<GroupsController>().setInitialData(data['groups']);
      }
      if (Get.isRegistered<ProfileController>()) {
        Get.find<ProfileController>().setInitialData(data['profile']);
      }
      if (Get.isRegistered<HomeController>()) {
        Get.find<HomeController>().setInitialData(data);
      }
      print('🔄 Controllers refreshed with pre-loaded data');
    } catch (e) {
      print('⚠️ Error refreshing controllers: $e');
    }
  }
}

