import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/controllers/home_controller.dart';
import 'package:fruitsofspirit/controllers/videos_controller.dart';
import 'package:fruitsofspirit/services/hive_cache_service.dart';
import 'package:fruitsofspirit/services/search_service.dart';
import 'package:fruitsofspirit/utils/share_helper.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';
import 'package:fruitsofspirit/utils/time_helper.dart';

import 'package:fruitsofspirit/routes/routes.dart';
import 'package:fruitsofspirit/services/api_service.dart';
import 'package:fruitsofspirit/services/payment_gate.dart';
import 'package:fruitsofspirit/widgets/standard_app_bar.dart';
import 'package:fruitsofspirit/services/user_storage.dart';
import 'package:fruitsofspirit/utils/app_theme.dart';
import 'package:fruitsofspirit/widgets/cached_image.dart';
import 'package:fruitsofspirit/widgets/blog_media_widget.dart';
import 'package:fruitsofspirit/utils/image_helper.dart';
import 'package:fruitsofspirit/widgets/custom_video_thumbnail.dart';
import 'package:fruitsofspirit/utils/auto_translate_helper.dart';
import 'package:fruitsofspirit/screens/home_screen.dart';

/// Search Screen
class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  // Survives route pop so reopening Search from Home is instant.
  static final Map<String, Map<String, dynamic>> _sessionResultsCache = {};
  static final Map<String, DateTime> _sessionCacheFetchedAt = {};
  static bool _sessionAuthChecked = false;
  static bool _sessionAuthenticated = false;

  static const Duration _cacheMaxAge = Duration(minutes: 5);
  static const List<String> _resultTypes = [
    'blogs',
    'prayers',
    'videos',
    'photos',
    'stories',
  ];

  final searchController = TextEditingController();
  var isLoading = false;
  var _isSilentSyncing = false;
  var searchResults = <String, dynamic>{};
  String selectedType = 'all';
  String _activeQueryKey = '';
  bool _isAuthenticated = false;
  bool _authChecked = false;
  Timer? _debounceTimer;
  int _searchGeneration = 0;
  final Map<String, Map<String, dynamic>> _resultsCache = _sessionResultsCache;
  final Map<String, DateTime> _cacheFetchedAt = _sessionCacheFetchedAt;

  @override
  void initState() {
    super.initState();
    // Logged-in users open Search from Home — show UI immediately, verify auth in background.
    _authChecked = true;
    _isAuthenticated = _sessionAuthChecked ? _sessionAuthenticated : true;
    _restoreSessionOrLoad();
  }

  void _restoreFromHiveIfEmpty() {
    if (_resultsCache.containsKey('')) return;
    final cached = HiveCacheService.getCachedData('search_default');
    if (cached is! Map<String, dynamic>) return;
    _resultsCache[''] = Map<String, dynamic>.from(cached);
    _cacheFetchedAt[''] = DateTime.now().subtract(_cacheMaxAge);
  }

  void _seedFromHomeIfEmpty() {
    if (_resultsCache.containsKey('')) return;
    if (!Get.isRegistered<HomeController>()) return;

    final home = Get.find<HomeController>();
    final seeded = <String, dynamic>{
      'results': {
        'blogs': home.blogs.map((e) => Map<String, dynamic>.from(e)).toList(),
        'prayers': home.prayers.map((e) => Map<String, dynamic>.from(e)).toList(),
        'videos': home.videos.map((e) => Map<String, dynamic>.from(e)).toList(),
        'photos': home.galleryPhotos.map((e) => Map<String, dynamic>.from(e)).toList(),
        'stories': home.stories.map((e) => Map<String, dynamic>.from(e)).toList(),
      },
    };
    final resultsMap = seeded['results']! as Map<String, dynamic>;
    final hasAny = resultsMap.values.any((l) => l is List && l.isNotEmpty);
    if (!hasAny) return;

    _storeInCache('', seeded);
    _cacheFetchedAt[''] = DateTime.now().subtract(_cacheMaxAge);
  }

  void _restoreSessionOrLoad() {
    _restoreFromHiveIfEmpty();
    _seedFromHomeIfEmpty();

    if (_resultsCache.containsKey('')) {
      _applyCachedResults('');
      isLoading = false;
      unawaited(_verifyAuth());
      if (_isCacheStale('')) {
        unawaited(_performSearch('', silent: true));
      }
      return;
    }

    unawaited(_verifyAuth());
    unawaited(_performSearch('', silent: true));
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchGeneration++;
    searchController.dispose();
    super.dispose();
  }

  Future<void> _verifyAuth() async {
    if (_sessionAuthChecked && _sessionAuthenticated) return;

    final isLoggedIn = await UserStorage.isLoggedIn();
    _sessionAuthChecked = true;
    _sessionAuthenticated = isLoggedIn;

    if (!mounted) return;
    if (!isLoggedIn) {
      Get.offAllNamed(Routes.LOGIN);
      return;
    }

    setState(() {
      _isAuthenticated = true;
      _authChecked = true;
    });
  }

  bool _hasDisplayableResults() {
    final results = searchResults['results'] as Map<String, dynamic>? ?? {};
    return results.values.any((list) => list is List && list.isNotEmpty);
  }

  bool _isCacheStale(String queryKey) {
    final fetchedAt = _cacheFetchedAt[queryKey];
    if (fetchedAt == null) return true;
    return DateTime.now().difference(fetchedAt) > _cacheMaxAge;
  }

  void _applyCachedResults(String queryKey) {
    final cached = _resultsCache[queryKey];
    if (cached == null) return;
    _activeQueryKey = queryKey;
    searchResults = Map<String, dynamic>.from(cached);
  }

  void _storeInCache(String queryKey, Map<String, dynamic> results) {
    _resultsCache[queryKey] = Map<String, dynamic>.from(results);
    _cacheFetchedAt[queryKey] = DateTime.now();
    _activeQueryKey = queryKey;
    if (queryKey.isEmpty) {
      unawaited(
        HiveCacheService.cacheData('search_default', results, expiryHours: 1),
      );
    }
  }

  /// Tab switch: client-side filter only — no API.
  void _onFilterTypeSelected(String type) {
    if (selectedType == type) return;
    setState(() => selectedType = type);
  }

  Future<void> _performSearch(String query, {bool silent = false}) async {
    if (!_isAuthenticated) {
      final isLoggedIn = await UserStorage.isLoggedIn();
      if (!isLoggedIn) {
        Get.offAllNamed(Routes.LOGIN);
        return;
      }
      if (!mounted) return;
      setState(() {
        _isAuthenticated = true;
      });
    }

    final trimmed = query.trim();
    final queryKey = trimmed;

    // Same query + fresh cache → show instantly, no network.
    if (!silent && _resultsCache.containsKey(queryKey) && !_isCacheStale(queryKey)) {
      if (!mounted) return;
      setState(() {
        _applyCachedResults(queryKey);
        isLoading = false;
        _isSilentSyncing = false;
      });
      return;
    }

    // Stale cache → show old data immediately, refresh quietly in background.
    if (!silent && _resultsCache.containsKey(queryKey)) {
      if (!mounted) return;
      setState(() {
        _applyCachedResults(queryKey);
        isLoading = false;
      });
      if (_isCacheStale(queryKey)) {
        unawaited(_performSearch(query, silent: true));
      }
      return;
    }

    final generation = silent ? _searchGeneration : ++_searchGeneration;
    final hadResults = _hasDisplayableResults();

    if (!mounted) return;
    setState(() {
      if (silent) {
        _isSilentSyncing = true;
      } else if (!hadResults) {
        isLoading = true;
      } else {
        _isSilentSyncing = true;
      }
    });

    try {
      // One API call loads every tab; chips filter locally.
      final results = await SearchService.search(
        query: trimmed,
        type: 'all',
      );

      if (!mounted || generation != _searchGeneration) return;

      if (results['results'] == null) {
        results['results'] = {
          for (final type in _resultTypes) type: <Map<String, dynamic>>[],
        };
      }

      _storeInCache(queryKey, results);

      if (!mounted) return;
      if (!silent && generation != _searchGeneration) return;

      final isCurrentQuery = searchController.text.trim() == queryKey;
      setState(() {
        if (isCurrentQuery) {
          searchResults = Map<String, dynamic>.from(results);
        }
        isLoading = false;
        _isSilentSyncing = false;
      });

      if (silent) return;

      final resultsData = results['results'] as Map<String, dynamic>? ?? {};
      final hasResults = resultsData.values.any(
        (list) => list is List && list.isNotEmpty,
      );

      if (!hasResults && trimmed.isNotEmpty) {
        Get.snackbar(
          'No Results',
          'No content found for "$trimmed"',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      if (!mounted || generation != _searchGeneration) return;

      setState(() {
        isLoading = false;
        _isSilentSyncing = false;
        if (!hadResults) {
          searchResults = {};
        }
      });

      if (!silent) {
        Get.snackbar(
          'Search Error',
          e.toString().replaceAll('Exception: ', ''),
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAuthenticated) {
      return Scaffold(
        backgroundColor: AppTheme.themeColor,
        body: Center(
          child: Text(
            'Redirecting to login...',
            style: ResponsiveHelper.textStyle(
              context,
              fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.themeColor, // Match home page beige background
      appBar: StandardAppBar(
        showBackButton: true,
        rightActions: [], // No icons in app bar
      ),
      body: Column(
        children: [
          // Search Field
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveHelper.spacing(context, 16),
              vertical: ResponsiveHelper.spacing(context, 12),
            ),
            child: TextField(
              controller: searchController,
              autofocus: false,
              onChanged: (value) {
                // Debounce real-time search to avoid too many API calls
                _debounceTimer?.cancel();
                _debounceTimer = Timer(const Duration(milliseconds: 500), () {
                  _performSearch(value);
                });
              },
              decoration: InputDecoration(
                hintText: 'Search blogs, prayers, videos...',
                prefixIcon: Icon(Icons.search, color: AppTheme.primaryColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
                  borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
                  borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
                  borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: ResponsiveHelper.spacing(context, 16),
                  vertical: ResponsiveHelper.spacing(context, 14),
                ),
              ),
              style: ResponsiveHelper.textStyle(
                context,
                fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 17, desktop: 18),
                color: AppTheme.textPrimary,
              ),
              onSubmitted: _performSearch,
            ),
          ),
          // Type Filter
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveHelper.spacing(context, 16),
              vertical: ResponsiveHelper.spacing(context, 6),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(context, 'All', 'all'),
                  SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                  _buildFilterChip(context, 'Blogs', 'blogs'),
                  SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                  _buildFilterChip(context, 'Prayers', 'prayers'),
                  SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                  _buildFilterChip(context, 'Videos', 'videos'),
                  SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                  _buildFilterChip(context, 'Photos', 'photos'),
                  SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                  _buildFilterChip(context, 'Stories', 'stories'),
                ],
              ),
            ),
          ),
          
          if (_isSilentSyncing)
            const LinearProgressIndicator(
              minHeight: 2,
              color: Color(0xFF8B4513),
              backgroundColor: Colors.transparent,
            ),

          // Results — tabs filter locally; spinner only when no data yet.
          Expanded(
            child: isLoading && !_hasDisplayableResults()
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF8B4513),
                    ),
                  )
                : _buildEmptyOrResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(BuildContext context, String label, String type) {
    final isSelected = selectedType == type;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (isSelected) return;
        _onFilterTypeSelected(type);
      },
      selectedColor: AppTheme.secondaryColor, // Light blue
      checkmarkColor: AppTheme.primaryColor,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: isSelected ? AppTheme.primaryColor : Colors.grey.withOpacity(0.3),
        width: isSelected ? 1.5 : 1,
      ),
      labelStyle: ResponsiveHelper.textStyle(
        context,
        fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
        color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveHelper.spacing(context, 12),
        vertical: ResponsiveHelper.spacing(context, 8),
      ),
    );
  }

  Widget _buildEmptyOrResults() {
    final results = searchResults['results'] as Map<String, dynamic>? ?? {};

    final hasResults = selectedType == 'all'
        ? results.values.any((list) => list is List && list.isNotEmpty)
        : (results[selectedType] is List &&
            (results[selectedType] as List).isNotEmpty);
    
    if (!hasResults && searchController.text.trim().isNotEmpty) {
      // Show "no results" message
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: ResponsiveHelper.iconSize(context, mobile: 64),
              color: Colors.grey,
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 16)),
            Text(
              'No results found',
              style: ResponsiveHelper.textStyle(
                context,
                fontSize: ResponsiveHelper.fontSize(context, mobile: 18),
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 8)),
            Text(
              'Try searching with different keywords',
              style: ResponsiveHelper.textStyle(
                context,
                fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    
    if (!hasResults) {
      // Show "enter query" message
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_outlined,
              size: ResponsiveHelper.iconSize(context, mobile: 64),
              color: Colors.grey,
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 16)),
            Text(
              'Enter a search query',
              style: ResponsiveHelper.textStyle(
                context,
                fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
                color: Colors.grey,
              ),
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 8)),
            Text(
              'Search across blogs, prayers, videos, photos, and stories',
              style: ResponsiveHelper.textStyle(
                context,
                fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    
    // Use the already extracted results
    return _buildResults(results);
  }

  Widget _buildResults(Map<String, dynamic> results) {
    final filteredResults = <String, List<dynamic>>{};

    if (selectedType == 'all') {
      for (final type in _resultTypes) {
        if (results[type] is List && (results[type] as List).isNotEmpty) {
          filteredResults[type] = results[type] as List;
        }
      }
    } else if (results[selectedType] is List) {
      filteredResults[selectedType] = results[selectedType] as List;
    }
    
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveHelper.spacing(context, 16),
        vertical: ResponsiveHelper.spacing(context, 8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (filteredResults['blogs'] != null && filteredResults['blogs']!.isNotEmpty) ...[
            Text(
              'Blogs',
              style: ResponsiveHelper.textStyle(
                context,
                fontSize: ResponsiveHelper.fontSize(context, mobile: 20, tablet: 22),
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 8)),
            SizedBox(
              height: ResponsiveHelper.imageHeight(context, mobile: 180, tablet: 300, desktop: 400),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                cacheExtent: 1200,
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveHelper.spacing(context, 16),
                ),
                itemCount: filteredResults['blogs']!.length,
                itemBuilder: (context, index) {
                  final blog = filteredResults['blogs']![index];
                  return Container(
                    key: ValueKey('search-blog-${blog['id']}'),
                    margin: EdgeInsets.only(
                      right: index < filteredResults['blogs']!.length - 1 
                          ? ResponsiveHelper.spacing(context, 10) 
                          : 0,
                    ),
                    child: _buildResultCard(
                      context,
                      blog,
                      'Blog',
                      () => HomeScreen.navigateToBlogDetail(
                        context,
                        blog['id'] is int
                            ? blog['id'] as int
                            : int.tryParse(blog['id'].toString()) ?? 0,
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 12)),
          ],
          if (filteredResults['prayers'] != null && filteredResults['prayers']!.isNotEmpty) ...[
            Text(
              'Prayers',
              style: ResponsiveHelper.textStyle(
                context,
                fontSize: ResponsiveHelper.fontSize(context, mobile: 20, tablet: 22),
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 8)),
            ...filteredResults['prayers']!.map((prayer) => _buildResultCard(
              context,
              prayer,
              'Prayer',
              () => PaymentGate.navigateToFeature(Routes.PRAYER_DETAILS, arguments: prayer['id']),
            )),
            SizedBox(height: ResponsiveHelper.spacing(context, 12)),
          ],
          if (filteredResults['videos'] != null && filteredResults['videos']!.isNotEmpty) ...[
            Text(
              'Videos',
              style: ResponsiveHelper.textStyle(
                context,
                fontSize: ResponsiveHelper.fontSize(context, mobile: 20, tablet: 22),
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 8)),
            ...filteredResults['videos']!.map((video) => _buildResultCard(
              context,
              video,
              'Video',
              () => VideosController.openVideoDetail(video['id']),
            )),
            SizedBox(height: ResponsiveHelper.spacing(context, 12)),
          ],
          if (filteredResults['photos'] != null && filteredResults['photos']!.isNotEmpty) ...[
            Text(
              'Photos',
              style: ResponsiveHelper.textStyle(
                context,
                fontSize: ResponsiveHelper.fontSize(context, mobile: 20, tablet: 22),
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 8)),
            SizedBox(
              height: ResponsiveHelper.imageHeight(context, mobile: 200, tablet: 350, desktop: 450),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveHelper.spacing(context, 16),
                ),
                itemCount: filteredResults['photos']!.length,
                itemBuilder: (context, index) {
                  final photo = filteredResults['photos']![index];
                  print('🔍 Building photo card $index: ${photo['id']}, file_path: ${photo['file_path']}');
                  return Container(
                    margin: EdgeInsets.only(
                      right: index < filteredResults['photos']!.length - 1 
                          ? ResponsiveHelper.spacing(context, 10) 
                          : 0,
                    ),
                    child: _buildResultCard(
                      context,
                      photo,
                      'Photo',
                      () => Get.toNamed(Routes.PHOTO_DETAILS, arguments: photo['id']),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 12)),
          ],
          if (filteredResults['stories'] != null && filteredResults['stories']!.isNotEmpty) ...[
            Text(
              'Stories',
              style: ResponsiveHelper.textStyle(
                context,
                fontSize: ResponsiveHelper.fontSize(context, mobile: 20, tablet: 22),
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 8)),
            ...filteredResults['stories']!.map((story) => _buildResultCard(
              context,
              story,
              'Story',
              () => PaymentGate.navigateToFeature(Routes.STORY_DETAILS, arguments: story['id']),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildResultCard(BuildContext context, Map<String, dynamic> item, String type, VoidCallback onTap) {
    String? imageUrl;
    
    if (type == 'Blog') {
      imageUrl = ImageHelper.resolveBlogImageUrl(item);
    } else if (type == 'Photo' || type == 'Story') {
      final filePath = item['file_path'] as String?;
      imageUrl = ImageHelper.resolveMediaPath(filePath);
    } else if (type == 'Video') {
      imageUrl = _getVideoThumbnail(item);
    } else {
      imageUrl = null;
    }
    
    // Match home page styling exactly
    if (type == 'Blog') {
      // Use exact home page blog card style
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: ResponsiveHelper.imageWidth(context, mobile: 250, tablet: 350, desktop: 400),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                spreadRadius: ResponsiveHelper.spacing(context, 2),
                blurRadius: ResponsiveHelper.spacing(context, 5),
                offset: Offset(0, ResponsiveHelper.spacing(context, 3)),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                ),
                child: imageUrl != null
                    ? BlogMediaWidget(
                        mediaUrl: imageUrl,
                        isVideo: ImageHelper.isVideoUrl(imageUrl),
                        width: double.infinity,
                        height: ResponsiveHelper.imageHeight(context, mobile: 90, tablet: 150, desktop: 180),
                        fit: BoxFit.cover,
                        previewMode: true,
                      )
                    : Container(
                        height: ResponsiveHelper.imageHeight(context, mobile: 90),
                        color: Colors.grey[300],
                        child: Icon(Icons.article, size: ResponsiveHelper.iconSize(context, mobile: 36)),
                      ),
              ),
              Padding(
                padding: ResponsiveHelper.padding(context, all: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AutoTranslateHelper.getTranslatedTextSync(
                        text: item['title'] ?? 'Blog Title',
                        sourceLanguage: item['language'] as String?,
                      ),
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontWeight: FontWeight.bold,
                        fontSize: ResponsiveHelper.fontSize(context, mobile: 13, tablet: 16, desktop: 18),
                        color: const Color(0xFF8B4513),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(context, 1)),
                    Text(
                      item['user_name'] ?? item['author_name'] ?? 'Blogger',
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: ResponsiveHelper.fontSize(context, mobile: 11, tablet: 14, desktop: 16),
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } else if (type == 'Prayer') {
      // Use exact home page social media prayer post style
      final isAnonymous = item['is_anonymous'] == 1 || item['is_anonymous'] == true;
      final userName = isAnonymous ? 'Anonymous' : (item['user_name'] ?? item['name'] ?? 'Anonymous');
      String? profilePhotoUrl;
      if (!isAnonymous && item['profile_photo'] != null && item['profile_photo'].toString().isNotEmpty) {
        final photoPath = item['profile_photo'].toString();
        if (photoPath.startsWith('http://') || photoPath.startsWith('https://')) {
          profilePhotoUrl = photoPath;
        } else if (!photoPath.startsWith('assets/') && !photoPath.startsWith('file://') && !photoPath.startsWith('assets/images/')) {
          profilePhotoUrl = 'http://admin.fosmessenger.com/$photoPath';
        }
      }
      final prayerContent = AutoTranslateHelper.getTranslatedTextSync(
        text: item['content'] ?? '',
        sourceLanguage: item['language'] as String?,
      );
      final responseCount = int.tryParse((item['response_count'] ?? 0).toString()) ?? 0;
      final commentCount = int.tryParse((item['comment_count'] ?? 0).toString()) ?? 0;
      final category = item['category'] as String? ?? item['type'] as String? ?? item['prayer_type'] as String? ?? 'Prayer Request';
      final subtitle = category;

      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: ResponsiveHelper.safeMargin(
            context,
            horizontal: 0,
            vertical: ResponsiveHelper.isMobile(context) ? 6 : 8,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                spreadRadius: 0,
                blurRadius: 8,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header - Profile + Name + Subtitle + Three-dot menu
              Padding(
                padding: ResponsiveHelper.padding(
                  context,
                  all: ResponsiveHelper.isMobile(context) ? 14 : 16,
                ),
                child: Row(
                  children: [
                    // Profile Picture
                    profilePhotoUrl != null && !isAnonymous
                        ? ClipOval(
                            child: CachedImage(
                              imageUrl: profilePhotoUrl,
                              width: ResponsiveHelper.isMobile(context) ? 44 : ResponsiveHelper.isTablet(context) ? 48 : 52,
                              height: ResponsiveHelper.isMobile(context) ? 44 : ResponsiveHelper.isTablet(context) ? 48 : 52,
                              fit: BoxFit.cover,
                              errorWidget: CircleAvatar(
                                radius: ResponsiveHelper.isMobile(context) ? 22 : ResponsiveHelper.isTablet(context) ? 24 : 26,
                                backgroundColor: Colors.grey[300]!,
                                child: Icon(
                                  Icons.person_rounded,
                                  size: ResponsiveHelper.isMobile(context) ? 22 : ResponsiveHelper.isTablet(context) ? 24 : 26,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          )
                        : CircleAvatar(
                            radius: ResponsiveHelper.isMobile(context) ? 22 : ResponsiveHelper.isTablet(context) ? 24 : 26,
                            backgroundColor: Colors.grey[300]!,
                            child: Icon(
                              Icons.person_rounded,
                              size: ResponsiveHelper.isMobile(context) ? 22 : ResponsiveHelper.isTablet(context) ? 24 : 26,
                              color: isAnonymous ? Colors.grey[600] : Colors.white,
                            ),
                          ),
                    SizedBox(width: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 10 : 12)),
                    // Name and Subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            userName,
                            style: ResponsiveHelper.textStyle(
                              context,
                              fontSize: ResponsiveHelper.fontSize(context, mobile: 15, tablet: 16, desktop: 17),
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          SizedBox(height: ResponsiveHelper.spacing(context, 2)),
                          Text(
                            subtitle,
                            style: ResponsiveHelper.textStyle(
                              context,
                              fontSize: ResponsiveHelper.fontSize(context, mobile: 11, tablet: 12, desktop: 13),
                              color: Colors.grey[600],
                              fontWeight: FontWeight.normal,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                    // Three-dot menu
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        size: ResponsiveHelper.iconSize(context, mobile: 20, tablet: 22, desktop: 24),
                        color: AppTheme.iconscolor,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onSelected: (value) {
                        if (value == 'view') {
                          onTap();
                        } else if (value == 'share') {
                          final shareType = type.toLowerCase() == 'prayer' ? 'prayer' : 
                                           type.toLowerCase() == 'video' ? 'video' :
                                           type.toLowerCase() == 'photo' ? 'photo' :
                                           type.toLowerCase() == 'blog' ? 'blog' : 'story';
                          
                          ShareHelper.shareContent(
                            context: context,
                            contentType: shareType,
                            contentId: item['id'] is int ? item['id'] : int.tryParse(item['id'].toString()) ?? 0,
                            title: type.toLowerCase() == 'prayer' ? 'Prayer Request from $userName' : 
                                   (item['title'] ?? item['description'] ?? type),
                            content: type.toLowerCase() == 'prayer' ? prayerContent : 
                                     (item['body'] ?? item['testimony'] ?? item['content']),
                          );
                        }


                      },
                      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                        PopupMenuItem<String>(
                          value: 'view',
                          child: Row(
                            children: [
                              Icon(Icons.visibility, size: 18, color: AppTheme.iconscolor),
                              SizedBox(width: 8),
                              Text('View Details'),
                            ],
                          ),
                        ),
                        PopupMenuItem<String>(
                          value: 'share',
                          child: Row(
                            children: [
                              Icon(Icons.share, size: 18, color: AppTheme.iconscolor),
                              SizedBox(width: 8),
                              Text('Share'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Content
              Padding(
                padding: ResponsiveHelper.padding(
                  context,
                  horizontal: ResponsiveHelper.isMobile(context) ? 14 : 16,
                  vertical: 0,
                ),
                child: Text(
                  prayerContent,
                  style: ResponsiveHelper.textStyle(
                    context,
                    fontSize: ResponsiveHelper.fontSize(context, mobile: 13, tablet: 14, desktop: 15),
                    color: Colors.black,
                    fontWeight: FontWeight.normal,
                  ).copyWith(height: 1.4),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(height: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 10 : 12)),
              // Bottom Actions - Left: Prayed count, Right: Comments count
              Padding(
                padding: ResponsiveHelper.padding(
                  context,
                  horizontal: ResponsiveHelper.isMobile(context) ? 14 : 16,
                  vertical: ResponsiveHelper.isMobile(context) ? 6 : 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Left: Prayed count with icon
                    if (responseCount > 0)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.favorite,
                            size: 18,
                            color: AppTheme.iconscolor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$responseCount prayed',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.iconscolor,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    // Right: Comments count with icon
                    if (commentCount > 0)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.comment_outlined,
                            size: 18,
                            color: AppTheme.iconscolor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$commentCount Comments',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } else if (type == 'Video') {
      // Use exact home page video card style
      String? imageUrl = _getVideoThumbnail(item);
      String? videoUrl = _getVideoUrl(item);
      final title = item['title'] ?? 'Video';
      final createdAt = item['created_at'] as String?;
      final thumbnailHeight = ResponsiveHelper.imageHeight(context, mobile: 220, tablet: 280, desktop: 320);

      return Container(
        margin: EdgeInsets.only(
          bottom: ResponsiveHelper.spacing(context, 20),
          left: ResponsiveHelper.spacing(context, 16),
          right: ResponsiveHelper.spacing(context, 16),
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              spreadRadius: 0,
              blurRadius: 25,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: const Color(0xFF5F4628).withOpacity(0.03),
              spreadRadius: 1,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Video Thumbnail
            GestureDetector(
              onTap: onTap,
              child: Stack(
                children: [
                  imageUrl != null
                      ? CachedImage(
                          imageUrl: imageUrl!,
                          height: thumbnailHeight,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorWidget: videoUrl != null
                              ? CustomVideoThumbnail(
                                  videoUrl: videoUrl,
                                  fit: BoxFit.cover,
                                  height: thumbnailHeight,
                                  width: double.infinity,
                                )
                              : Container(
                                  height: thumbnailHeight,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        AppTheme.themeColor,
                                        AppTheme.primaryColor.withOpacity(0.3),
                                      ],
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.video_library_rounded,
                                    size: ResponsiveHelper.iconSize(context, mobile: 50, tablet: 60, desktop: 70),
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                        )
                      : videoUrl != null
                          ? CustomVideoThumbnail(
                              videoUrl: videoUrl,
                              fit: BoxFit.cover,
                              height: thumbnailHeight,
                              width: double.infinity,
                            )
                          : Container(
                              height: thumbnailHeight,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppTheme.themeColor,
                                    AppTheme.primaryColor.withOpacity(0.3),
                                  ],
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.video_library_rounded,
                                  size: ResponsiveHelper.iconSize(context, mobile: 50, tablet: 60, desktop: 70),
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        padding: ResponsiveHelper.padding(context, all: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.play_circle_fill,
                          color: const Color(0xFF4CAF50),
                          size: ResponsiveHelper.iconSize(context, mobile: 50, tablet: 60, desktop: 70),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Title, Author and Time
            Padding(
              padding: ResponsiveHelper.padding(context, all: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: ResponsiveHelper.textStyle(context, fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  if (item['user_name'] != null && (item['user_name'] as String).isNotEmpty)
                    Padding(
                      padding: ResponsiveHelper.padding(context, top: 6),
                      child: Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: ResponsiveHelper.iconSize(context, mobile: 14),
                            color: Colors.grey[600],
                          ),
                          SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                          Text(
                            item['user_name'] as String,
                            style: ResponsiveHelper.textStyle(context, fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  if (createdAt != null)
                    Padding(
                      padding: ResponsiveHelper.padding(context, top: 4),
                      child: Text(
                        TimeHelper.getTimeAgo(createdAt),
                        style: ResponsiveHelper.textStyle(context, fontSize: 12, color: Colors.grey[600]),
                      ),
                    ),
                ],
              ),
            ),
            // Actions - Modern Design
            Container(
              margin: ResponsiveHelper.padding(context, horizontal: 18, vertical: 8),
              padding: ResponsiveHelper.padding(context, horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: onTap,
                      borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
                      child: Container(
                        padding: ResponsiveHelper.padding(context, horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.favorite_border_rounded, size: ResponsiveHelper.iconSize(context, mobile: 22), color: AppTheme.iconscolor),
                            SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                            Flexible(
                              child: Text(
                                'Like',
                                style: ResponsiveHelper.textStyle(context, fontSize: 14, color: AppTheme.iconscolor, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                  Expanded(
                    child: InkWell(
                      onTap: onTap,
                      borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
                      child: Container(
                        padding: ResponsiveHelper.padding(context, horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF5F4628).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.comment_outlined, size: ResponsiveHelper.iconSize(context, mobile: 22), color: AppTheme.iconscolor),
                            SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                            Flexible(
                              child: Text(
                                'Comment',
                                style: ResponsiveHelper.textStyle(context, fontSize: 14, color: AppTheme.iconscolor, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                  InkWell(
                    onTap: () => ShareHelper.shareContent(
                      context: context,
                      contentType: 'video',
                      contentId: item['id'] is int ? item['id'] : int.tryParse(item['id'].toString()) ?? 0,
                      title: title,
                    ),
                    borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
                    child: Container(
                      padding: ResponsiveHelper.padding(context, all: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
                      ),
                      child: Icon(Icons.share_rounded, size: ResponsiveHelper.iconSize(context, mobile: 22), color: AppTheme.iconscolor),
                    ),
                  ),

                ],
              ),
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 4)),
          ],
        ),
      );
    } else if (type == 'Photo') {
      // Use exact home page photo card style
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: ResponsiveHelper.imageWidth(context, mobile: 200, tablet: 300, desktop: 350),
          margin: ResponsiveHelper.padding(context, right: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                spreadRadius: ResponsiveHelper.spacing(context, 2),
                blurRadius: ResponsiveHelper.spacing(context, 5),
                offset: Offset(0, ResponsiveHelper.spacing(context, 3)),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                ),
                child: imageUrl != null
                    ? CachedImage(
                        imageUrl: imageUrl!,
                        height: ResponsiveHelper.imageHeight(context, mobile: 150, tablet: 220, desktop: 280),
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorWidget: Container(
                          height: ResponsiveHelper.imageHeight(context, mobile: 150, tablet: 220, desktop: 280),
                          color: Colors.grey[300],
                          child: Icon(Icons.image, size: ResponsiveHelper.iconSize(context, mobile: 40)),
                        ),
                      )
                    : Container(
                        height: ResponsiveHelper.imageHeight(context, mobile: 150, tablet: 220, desktop: 280),
                        color: Colors.grey[300],
                        child: Icon(Icons.image, size: ResponsiveHelper.iconSize(context, mobile: 40)),
                      ),
              ),
              if (item['fruit_tag'] != null)
                Padding(
                  padding: ResponsiveHelper.padding(context, all: 8),
                  child: Container(
                    padding: ResponsiveHelper.padding(context,
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEECE2),
                      borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
                    ),
                    child: Text(
                      item['fruit_tag'] ?? '',
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: ResponsiveHelper.fontSize(context, mobile: 12, tablet: 14, desktop: 16),
                        color: const Color(0xFF8B4513),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    
    // Default card for Stories
    return Container(
      margin: EdgeInsets.only(bottom: ResponsiveHelper.spacing(context, 12)),
      decoration: AppTheme.cardDecoration(
        borderRadius: ResponsiveHelper.borderRadius(context, mobile: 16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
          child: Padding(
            padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 16)),
            child: Row(
              children: [
                if (imageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                    child: LazyCachedImage(
                      imageUrl: imageUrl!,
                      width: ResponsiveHelper.iconSize(context, mobile: 80, tablet: 90),
                      height: ResponsiveHelper.iconSize(context, mobile: 80, tablet: 90),
                      fit: BoxFit.cover,
                      errorWidget: Container(
                        width: ResponsiveHelper.iconSize(context, mobile: 80, tablet: 90),
                        height: ResponsiveHelper.iconSize(context, mobile: 80, tablet: 90),
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryColor,
                          borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                        ),
                        child: Icon(
                          Icons.image_outlined,
                          size: 32,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ),
                if (imageUrl != null) SizedBox(width: ResponsiveHelper.spacing(context, 16)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['title'] as String? ?? item['description'] as String? ?? item['content'] as String? ?? 'Untitled',
                        style: ResponsiveHelper.textStyle(
                          context,
                          fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 18),
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: ResponsiveHelper.spacing(context, 6)),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: ResponsiveHelper.spacing(context, 8),
                          vertical: ResponsiveHelper.spacing(context, 4),
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 6)),
                        ),
                        child: Text(
                          type,
                          style: ResponsiveHelper.textStyle(
                            context,
                            fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper functions for videos (from home page)
  String? _getVideoThumbnail(Map<String, dynamic> video) {
    // Priority 1: Check thumbnail_path (from database - generated during upload)
    if (video['thumbnail_path'] != null && (video['thumbnail_path'] as String).isNotEmpty) {
      final thumbnailPath = video['thumbnail_path'] as String;
      if (!thumbnailPath.startsWith('http')) {
        return 'http://admin.fosmessenger.com/$thumbnailPath';
      }
      return thumbnailPath;
    }
    
    // Priority 2: Check thumbnail (legacy field)
    if (video['thumbnail'] != null && (video['thumbnail'] as String).isNotEmpty) {
      final thumbnail = video['thumbnail'] as String;
      if (!thumbnail.startsWith('http')) {
        return 'http://admin.fosmessenger.com/$thumbnail';
      }
      return thumbnail;
    }
    
    // Priority 3: Check if file_path is an image (not a video)
    if (video['file_path'] != null) {
      final filePath = video['file_path'].toString();
      final lowerPath = filePath.toLowerCase();
      if (!lowerPath.endsWith('.mp4') &&
          !lowerPath.endsWith('.mov') &&
          !lowerPath.endsWith('.avi') &&
          !lowerPath.endsWith('.webm') &&
          !lowerPath.endsWith('.mkv')) {
        if (!filePath.startsWith('http')) {
          return 'http://admin.fosmessenger.com/$filePath';
        }
        return filePath;
      }
    }
    
    // Last resort: Return null to use video frame extraction
    return null;
  }

  // Get video URL from video data
  String? _getVideoUrl(Map<String, dynamic> video) {
    if (video['file_path'] != null) {
      final filePath = video['file_path'].toString();
      if (filePath.isNotEmpty) {
        final lowerPath = filePath.toLowerCase();
        // Check if it's a video file
        if (lowerPath.endsWith('.mp4') ||
            lowerPath.endsWith('.mov') ||
            lowerPath.endsWith('.avi') ||
            lowerPath.endsWith('.webm') ||
            lowerPath.endsWith('.mkv')) {
          if (filePath.startsWith('http')) {
            return filePath;
          }
          return 'http://admin.fosmessenger.com/$filePath';
        }
      }
    }
    return null;
  }

}

