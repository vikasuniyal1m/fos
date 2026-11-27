import 'dart:async';

import '../config/api_config.dart';
import 'api_service.dart';
import 'hive_cache_service.dart';

class _EmojiCacheEntry {
  final List<Map<String, dynamic>> data;
  final DateTime fetchedAt;
  _EmojiCacheEntry(this.data, this.fetchedAt);
}

/// Emojis Service
/// Handles emoji listing and usage tracking
class EmojisService {
  static final Map<String, _EmojiCacheEntry> _memoryCache = {};
  static const Duration _cacheTtl = Duration(hours: 24);
  static const Duration _minSyncInterval = Duration(hours: 6);
  static const String _hiveEmojisKey = 'emojis_active_all';
  static const String _syncMetaKey = 'emojis_sync_meta';
  static List<Map<String, dynamic>>? _canonicalEmojis;
  static List<Map<String, dynamic>>? _sessionPickerEmojis;
  static DateTime? _lastApiSyncAt;

  static String _buildCacheKey(Map<String, String> queryParams) {
    final keys = queryParams.keys.toList()..sort();
    return keys.map((k) => '$k=${queryParams[k]}').join('|');
  }

  static List<Map<String, dynamic>>? _readMemory(String key) {
    final entry = _memoryCache[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.fetchedAt) > _cacheTtl) {
      _memoryCache.remove(key);
      return null;
    }
    return List<Map<String, dynamic>>.from(entry.data);
  }

  static void _writeMemory(String key, List<Map<String, dynamic>> data) {
    _memoryCache[key] = _EmojiCacheEntry(
      List<Map<String, dynamic>>.from(data),
      DateTime.now(),
    );
  }

  static bool _shouldSyncFromApi() {
    if (_lastApiSyncAt == null) {
      final meta = HiveCacheService.getCachedMap(_syncMetaKey);
      final ms = meta['last_sync_ms'];
      if (ms is int) {
        _lastApiSyncAt = DateTime.fromMillisecondsSinceEpoch(ms);
      }
    }
    if (_lastApiSyncAt == null) return true;
    return DateTime.now().difference(_lastApiSyncAt!) > _minSyncInterval;
  }

  static void _markSynced() {
    _lastApiSyncAt = DateTime.now();
    unawaited(
      HiveCacheService.cacheMap(
        _syncMetaKey,
        {'last_sync_ms': _lastApiSyncAt!.millisecondsSinceEpoch},
        expiryHours: 168,
      ),
    );
  }

  static void _maybeBackgroundSync(
    Map<String, String> queryParams,
    String cacheKey,
  ) {
    if (!_shouldSyncFromApi()) return;
    unawaited(
      _fetchEmojisFromApi(queryParams, cacheKey)
          .then((data) {
            _markSynced();
            if (!queryParams.containsKey('limit')) {
              _canonicalEmojis = data;
            }
            _sessionPickerEmojis = null;
          })
          .catchError((_) => <Map<String, dynamic>>[]),
    );
  }

  static List<Map<String, dynamic>>? _getCanonicalEmojis() {
    if (_canonicalEmojis != null && _canonicalEmojis!.isNotEmpty) {
      return _canonicalEmojis;
    }
    var hive = HiveCacheService.getCachedList(_hiveEmojisKey);
    if (hive.isEmpty) {
      hive = HiveCacheService.getCachedList('home_emojis');
    }
    if (hive.isEmpty) return null;
    _canonicalEmojis = List<Map<String, dynamic>>.from(hive);
    return _canonicalEmojis;
  }

  static bool _canDeriveFromCanonical(Map<String, String> queryParams) {
    return !queryParams.containsKey('source') &&
        !queryParams.containsKey('category') &&
        !queryParams.containsKey('main_fruit_only') &&
        !queryParams.containsKey('get_latest_feeling');
  }

  static List<Map<String, dynamic>> _deriveFromCanonical(
    List<Map<String, dynamic>> canonical,
    Map<String, String> queryParams,
  ) {
    final list = List<Map<String, dynamic>>.from(canonical);
    final sortBy = queryParams['sort_by'];
    final order = queryParams['order'] ?? 'DESC';
    final limit = int.tryParse(queryParams['limit'] ?? '');
    return _sortAndLimit(
      list,
      sortBy: sortBy,
      order: order,
      limit: limit,
    );
  }

  static List<Map<String, dynamic>> _sortAndLimit(
    List<Map<String, dynamic>> source, {
    String? sortBy,
    String order = 'DESC',
    int? limit,
  }) {
    final list = List<Map<String, dynamic>>.from(source);
    if (sortBy != null) {
      list.sort((a, b) {
        int cmp;
        if (sortBy == 'usage_count') {
          final av = int.tryParse(a['usage_count']?.toString() ?? '0') ?? 0;
          final bv = int.tryParse(b['usage_count']?.toString() ?? '0') ?? 0;
          cmp = av.compareTo(bv);
        } else {
          final av = a[sortBy]?.toString() ?? '';
          final bv = b[sortBy]?.toString() ?? '';
          cmp = av.compareTo(bv);
        }
        return order.toUpperCase() == 'ASC' ? cmp : -cmp;
      });
    }
    if (limit != null && list.length > limit) {
      return list.sublist(0, limit);
    }
    return list;
  }

  /// Instant picker emojis if already loaded this session.
  static List<Map<String, dynamic>>? getPickerEmojisSync() => _sessionPickerEmojis;

  /// Picker emojis — load once per session, stale sync only in background.
  static Future<List<Map<String, dynamic>>> getPickerEmojis({
    String? userEmail,
  }) async {
    if (_sessionPickerEmojis != null && _sessionPickerEmojis!.isNotEmpty) {
      return _sessionPickerEmojis!;
    }
    final emojis = await getEmojis(
      status: 'Active',
      sortBy: 'usage_count',
      order: 'DESC',
      userEmail: userEmail,
    );
    _sessionPickerEmojis = emojis;
    return emojis;
  }

  static Future<List<Map<String, dynamic>>> _fetchEmojisFromApi(
    Map<String, String> queryParams,
    String cacheKey,
  ) async {
    final response = await ApiService.get(
      ApiConfig.emojis,
      queryParameters: queryParams,
    );

    if (response['success'] == true && response['data'] != null) {
      final emojisList = List<Map<String, dynamic>>.from(response['data']);
      _writeMemory(cacheKey, emojisList);
      if (queryParams['status'] == 'Active' &&
          !queryParams.containsKey('limit') &&
          !queryParams.containsKey('get_latest_feeling')) {
        _canonicalEmojis = emojisList;
        unawaited(
          HiveCacheService.cacheList(_hiveEmojisKey, emojisList, maxItems: 80),
        );
      }
      return emojisList;
    }
    throw ApiException(response['message'] ?? 'Failed to fetch emojis');
  }
  /// Get Emojis
  /// 
  /// Parameters:
  /// - category: Filter by category
  /// - status: Filter by status (default: 'Active')
  /// - limit: Limit number of results (optional)
  /// - sortBy: Sort by field (optional: 'usage_count', 'name')
  /// - order: Sort order (optional: 'DESC', 'ASC', default: 'DESC')
  /// - mainFruitOnly: If true, returns only main fruit emojis (8-9 main fruits, not subcategories)
  /// - fromFolder: If true, reads emojis directly from uploads/emojis folder instead of database
  /// 
  /// Returns: List of emojis
  static Future<List<Map<String, dynamic>>> getEmojis({
    String? category,
    String status = 'Active',
    int? limit,
    String? sortBy,
    String order = 'DESC',
    bool mainFruitOnly = false,
    bool fromFolder = false,
    String? userEmail,
  }) async {
    final queryParams = <String, String>{
      'status': status,
    };
    
    // If fromFolder is true, add source parameter
    if (fromFolder) {
      queryParams['source'] = 'folder';
    }

    if (category != null) {
      queryParams['category'] = category;
    }
    
    if (mainFruitOnly) {
      queryParams['main_fruit_only'] = 'true';
    }
    
    if (limit != null) {
      queryParams['limit'] = limit.toString();
    }
    
    if (sortBy != null) {
      queryParams['sort_by'] = sortBy;
      queryParams['order'] = order;
    }

    if (userEmail != null && userEmail.isNotEmpty) {
      queryParams['user_email'] = userEmail;
    }

    final cacheKey = _buildCacheKey(queryParams);
    final memory = _readMemory(cacheKey);
    if (memory != null) {
      return memory;
    }

    final canonical = _getCanonicalEmojis();
    if (canonical != null &&
        canonical.isNotEmpty &&
        _canDeriveFromCanonical(queryParams)) {
      final derived = _deriveFromCanonical(canonical, queryParams);
      _writeMemory(cacheKey, derived);
      _maybeBackgroundSync(queryParams, cacheKey);
      return derived;
    }

    try {
      final data = await _fetchEmojisFromApi(queryParams, cacheKey);
      _markSynced();
      return data;
    } catch (e) {
      print('❌ Error fetching emojis: $e');
      rethrow;
    }
  }

  /// Get Quick Emojis (Top used emojis for quick reactions)
  /// 
  /// Returns: List of top 6 emojis by usage count
  static Future<List<Map<String, dynamic>>> getQuickEmojis() async {
    const quickKey = 'limit=6|order=DESC|sort_by=usage_count|status=Active';
    final cached = _readMemory(quickKey);
    if (cached != null) return cached;

    final canonical = _getCanonicalEmojis();
    if (canonical != null && canonical.isNotEmpty) {
      final quick = _sortAndLimit(
        canonical,
        sortBy: 'usage_count',
        order: 'DESC',
        limit: 6,
      );
      _writeMemory(quickKey, quick);
      return quick;
    }

    return getEmojis(
      status: 'Active',
      sortBy: 'usage_count',
      order: 'DESC',
      limit: 6,
    );
  }

  /// Pre-warm emoji cache at app start (non-blocking).
  static void warmCache() {
    if (_getCanonicalEmojis() != null) return;
    unawaited(
      getEmojis(status: 'Active', sortBy: 'image_url', order: 'ASC')
          .catchError((_) => <Map<String, dynamic>>[]),
    );
  }

  /// Get User's Latest Feeling
  /// 
  /// Parameters:
  /// - userId: User ID
  /// 
  /// Returns: Map with user's latest feeling data or null if no feeling recorded
  static Future<Map<String, dynamic>?> getUserLatestFeeling({
    required int userId,
  }) async {
    print('📡 EmojisService.getUserLatestFeeling called:');
    print('   User ID: $userId');
    
    final queryParams = <String, String>{
      'user_id': userId.toString(),
      'get_latest_feeling': 'true',
    };

    print('📤 GET request: ${ApiConfig.emojis}');
    print('📤 Query Parameters: $queryParams');
    
    try {
      final response = await ApiService.get(
        ApiConfig.emojis,
        queryParameters: queryParams,
      );

      print('📥 API Response: success=${response['success']}, data=${response['data']}');
      print('📥 API Response data type: ${response['data']?.runtimeType}');
      print('📥 API Response data content: ${response['data']}');

      if (response['success'] == true) {
        if (response['data'] != null) {
          final feelingData = response['data'] as Map<String, dynamic>;
          print('✅ User feeling loaded: emoji=${feelingData['emoji']}, emoji_details=${feelingData['emoji_details']}');
          return feelingData;
        } else {
          print('⚠️ No feeling data in response');
          return null; // No feeling recorded yet
        }
      } else {
        throw ApiException(response['message'] ?? 'Failed to get user feeling');
      }
    } catch (e) {
      print('❌ Error getting user feeling: $e');
      rethrow;
    }
  }

  /// Use Emoji
  /// 
  /// Parameters:
  /// - userId: User ID
  /// - emoji: Emoji character or code
  /// - postType: Type of post (optional: 'prayer', 'blog', 'video', 'gallery')
  /// - postId: Post ID (optional)
  /// 
  /// Returns: Success message
  static Future<String> useEmoji({
    required int userId,
    required String emoji,
    String? postType,
    int? postId,
  }) async {
    print('📡 EmojisService.useEmoji called:');
    print('   User ID: $userId');
    print('   Emoji: $emoji (length: ${emoji.length}, codeUnits: ${emoji.codeUnits})');
    print('   Post Type: $postType');
    print('   Post ID: $postId');
    
    // Validate emoji is not empty
    if (emoji.trim().isEmpty) {
      throw ApiException('Emoji cannot be empty. Please select a valid emoji.');
    }
    
    // Validate userId
    if (userId <= 0) {
      throw ApiException('User ID is required');
    }
    
    final body = <String, dynamic>{
      'user_id': userId.toString(),
      'emoji': emoji.trim(),
    };

    // Only add post_type and post_id if they are explicitly provided
    // IMPORTANT: When post_type and post_id are NULL, this is for "How are you feeling" (general feeling)
    // Backend should UPDATE existing feeling for this user (where post_type IS NULL and post_id IS NULL)
    // instead of creating a new entry
    if (postType != null && postType.isNotEmpty) {
      body['post_type'] = postType;
      print('   📝 Adding post_type to request: $postType');
    } else {
      print('   📝 postType is NULL - This is for "How are you feeling" (general feeling)');
      print('   ⚠️ Backend should UPDATE existing feeling, not create new one');
    }
    
    if (postId != null && postId > 0) {
      body['post_id'] = postId.toString();
      print('   📝 Adding post_id to request: $postId');
    } else {
      print('   📝 postId is NULL - This is for "How are you feeling" (general feeling)');
    }

    print('📤 POST body: $body');
    
    final response = await ApiService.post(
      ApiConfig.emojis,
      body: body,
    );

    print('📥 API Response: success=${response['success']}, message=${response['message']}');
    print('📥 API Response data: ${response['data']}');
    print('📥 API Response full: $response');

    if (response['success'] == true) {
      // Check if reaction was removed (toggle off)
      final data = response['data'] as Map<String, dynamic>?;
      if (data != null && data['removed'] == true) {
        print('✅ Emoji reaction removed (toggled off)');
        print('📊 📋 TABLE: emoji_usage - Entry removed');
        return 'Emoji reaction removed';
      } else {
        print('✅ Emoji reaction added (toggled on)');
        print('📊 📋 TABLE: emoji_usage - Entry should be saved here');
        
        // Check if response contains database confirmation
        if (data != null) {
          print('📊 Response data details:');
          print('   - id: ${data['id']}');
          print('   - user_id: ${data['user_id']}');
          print('   - emoji: ${data['emoji']}');
          print('   - post_type: ${data['post_type']}');
          print('   - post_id: ${data['post_id']}');
          print('   - created_at: ${data['created_at']}');
          
          // Verify database save
          if (data['id'] != null) {
            print('✅ VERIFIED: Database returned ID=${data['id']}');
            print('📊 📋 TABLE: emoji_usage - Entry saved successfully!');
            print('📊 📋 SQL Query would be: INSERT INTO emoji_usage (user_id, emoji, post_type, post_id) VALUES (${userId}, "${emoji.trim()}", "$postType", $postId)');
          } else {
            print('⚠️ WARNING: Database did not return ID - might not be saved!');
            print('📊 📋 TABLE: emoji_usage - Entry might NOT be saved');
          }
        } else {
          print('⚠️ WARNING: Response data is null - cannot verify database save');
          print('📊 📋 TABLE: emoji_usage - Cannot confirm if saved');
        }
        
        return response['message'] ?? 'Emoji used successfully';
      }
    } else {
      print('❌ API Error: ${response['message']}');
      print('❌ Database Status: Entry NOT saved to emoji_usage table');
      print('📊 📋 TABLE: emoji_usage - Save FAILED');
      throw ApiException(response['message'] ?? 'Failed to use emoji');
    }
  }

  /// Get Emojis from Folder
  /// Reads all emoji images directly from uploads/emojis folder on server
  /// 
  /// Returns: List of emojis from folder
  static Future<List<Map<String, dynamic>>> getEmojisFromFolder() async {
    return getEmojis(fromFolder: true);
  }

  /// Get Emoji Reactions for a Post
  /// Fetches emoji reactions from emoji_usage table for a specific post
  /// 
  /// Parameters:
  /// - postType: Type of post ('prayer', 'blog', 'video', 'photo', 'gallery')
  /// - postId: Post ID
  /// 
  /// Returns: List of emoji reactions with user info
  static Future<List<Map<String, dynamic>>> getEmojiReactions({
    required String postType,
    required int postId,
  }) async {
    print('📡 EmojisService.getEmojiReactions called:');
    print('   Post Type: $postType');
    print('   Post ID: $postId');
    
    final queryParams = <String, String>{
      'get_reactions': 'true',
      'post_type': postType,
      'post_id': postId.toString(),
    };

    print('📤 GET request: ${ApiConfig.emojis}');
    print('📤 Query Parameters: $queryParams');
    
    try {
      final response = await ApiService.get(
        ApiConfig.emojis,
        queryParameters: queryParams,
      );

      print('📥 API Response: success=${response['success']}, message=${response['message']}');
      print('📥 API Response data type: ${response['data']?.runtimeType}');
      print('📥 API Response data: ${response['data']}');

      if (response['success'] == true && response['data'] != null) {
        final reactions = List<Map<String, dynamic>>.from(response['data']);
        print('✅ Fetched ${reactions.length} emoji reactions from emoji_usage table');
        if (reactions.isNotEmpty) {
          print('📋 Sample reaction: ${reactions[0]}');
        }
        return reactions;
      } else {
        print('⚠️ No emoji reactions found or API error');
        print('⚠️ Response message: ${response['message']}');
        return [];
      }
    } catch (e) {
      print('❌ Error getting emoji reactions: $e');
      print('❌ This might mean the backend API does not support get_reactions endpoint yet');
      print('❌ Backend needs to add support for: ?get_reactions=true&post_type=photo&post_id=X');
      // Return empty list if API doesn't support this endpoint yet
      return [];
    }
  }
}

