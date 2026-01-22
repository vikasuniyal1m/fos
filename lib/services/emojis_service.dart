import '../config/api_config.dart';
import 'api_service.dart';

/// Emojis Service
/// Handles emoji listing and usage tracking
class EmojisService {
  /// Get Emojis
  /// 
  /// Parameters:
  /// - category: Filter by category
  /// - status: Filter by status (default: 'Active')
  /// - limit: Limit number of results (optional)
  /// - sortBy: Sort by field (optional: 'usage_count', 'name')
  /// - order: Sort order (optional: 'DESC', 'ASC', default: 'DESC')
  /// - mainFruitsOnly: If true, returns only main fruit emojis (8-9 main fruits, not subcategories)
  /// - fromFolder: If true, reads emojis directly from uploads/emojis folder instead of database
  /// 
  /// Returns: List of emojis
  static Future<List<Map<String, dynamic>>> getEmojis({
    String? category,
    String status = 'Active',
    int? limit,
    String? sortBy,
    String order = 'DESC',
    bool mainFruitsOnly = false,
    bool fromFolder = false,
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
    
    if (mainFruitsOnly) {
      queryParams['main_fruits_only'] = 'true';
    }
    
    if (limit != null) {
      queryParams['limit'] = limit.toString();
    }
    
    if (sortBy != null) {
      queryParams['sort_by'] = sortBy;
      queryParams['order'] = order;
    }

    print('📡 ========== EMOJIS API CALL START ==========');
    print('📡 API URL: ${ApiConfig.emojis}');
    print('📡 Query Parameters: $queryParams');
    
    try {
      final response = await ApiService.get(
        ApiConfig.emojis,
        queryParameters: queryParams,
      );

      print('📡 ========== EMOJIS API RESPONSE RECEIVED ==========');
      print('📡 Response type: ${response.runtimeType}');
      print('📡 Response keys: ${response.keys}');
      print('📡 Emojis API Response: success=${response['success']}, data length=${response['data']?.length ?? 0}');
      print('📡 Full API Response: $response');

    if (response['success'] == true && response['data'] != null) {
      final emojisList = List<Map<String, dynamic>>.from(response['data']);
      print('✅ Parsed ${emojisList.length} emojis from API');
      
      if (emojisList.isEmpty) {
        print('⚠️ WARNING: API returned success but emojis list is empty!');
        print('⚠️ This might mean:');
        print('   1. Database is empty (run add-fruit-emojis.php script)');
        print('   2. Filter is too restrictive (main_fruits_only might be filtering out all emojis)');
        print('   3. Status filter is excluding all emojis');
      }
      if (emojisList.isNotEmpty) {
        print('📋 Sample emoji: ${emojisList[0]}');
        // Validate emoji_char is present and not equal to code
        for (var emoji in emojisList) {
          final emojiChar = emoji['emoji_char'];
          final emojiCode = emoji['code'];
          
          if (emojiChar == null || emojiChar.toString().isEmpty) {
            print('⚠️ WARNING: Emoji ID ${emoji['id']} (${emoji['name']}) has empty emoji_char!');
          } else if (emojiChar.toString() == emojiCode) {
            print('❌ ERROR: Emoji ID ${emoji['id']} (${emoji['name']}) has emoji_char equal to code!');
            print('   emoji_char: $emojiChar');
            print('   code: $emojiCode');
          } else {
            print('✅ Emoji ID ${emoji['id']} (${emoji['name']}): emoji_char=${emojiChar}, code=$emojiCode');
          }
        }
      }
      print('📡 ========== EMOJIS API CALL SUCCESS ==========');
      return emojisList;
    } else {
      print('❌ ========== EMOJIS API ERROR ==========');
      print('❌ API Error: ${response['message'] ?? 'Unknown error'}');
      print('❌ Response: $response');
      throw ApiException(response['message'] ?? 'Failed to fetch emojis');
    }
    } catch (e, stackTrace) {
      print('❌ ========== EMOJIS API EXCEPTION ==========');
      print('❌ Exception type: ${e.runtimeType}');
      print('❌ Exception message: $e');
      print('❌ Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Get Quick Emojis (Top used emojis for quick reactions)
  /// 
  /// Returns: List of top 6 emojis by usage count
  static Future<List<Map<String, dynamic>>> getQuickEmojis() async {
    final emojis = await getEmojis(
      status: 'Active',
      sortBy: 'usage_count',
      order: 'DESC',
      limit: 6,
    );
    return emojis;
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

