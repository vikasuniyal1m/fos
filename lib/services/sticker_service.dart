import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';

/// Sticker Model
class Sticker {
  final int id;
  final String name;
  final String imageUrl;
  final String emojiCode;
  final int displayOrder;
  String? localPath;

  Sticker({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.emojiCode,
    required this.displayOrder,
    this.localPath,
  });

  factory Sticker.fromJson(Map<String, dynamic> json) {
    return Sticker(
      id: json['id'] as int,
      name: json['name'] as String,
      imageUrl: json['image_url'] as String,
      emojiCode: json['emoji_code'] as String,
      displayOrder: json['display_order'] as int,
      localPath: json['local_path'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'image_url': imageUrl,
      'emoji_code': emojiCode,
      'display_order': displayOrder,
      'local_path': localPath,
    };
  }
}

/// Sticker Pack Model
class StickerPack {
  final int packId;
  final int productId;
  final String name;
  final String? description;
  final String? category;
  final int totalStickers;
  final String? productImage;
  final int orderItemId;
  final List<Sticker> stickers;
  final String createdAt;

  StickerPack({
    required this.packId,
    required this.productId,
    required this.name,
    this.description,
    this.category,
    required this.totalStickers,
    this.productImage,
    required this.orderItemId,
    required this.stickers,
    required this.createdAt,
  });

  factory StickerPack.fromJson(Map<String, dynamic> json) {
    return StickerPack(
      packId: json['pack_id'] as int,
      productId: json['product_id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      category: json['category'] as String?,
      totalStickers: json['total_stickers'] as int,
      productImage: json['product_image'] as String?,
      orderItemId: json['order_item_id'] as int,
      stickers: (json['stickers'] as List<dynamic>?)
              ?.map((s) => Sticker.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['created_at'] as String,
    );
  }
}

/// Sticker Service
/// Handles fetching, downloading, and managing stickers from Ecommerce panel
class StickerService {
  // Ecommerce API base URL - FROM ECOMMERCE APP CONFIG
  static const String _ecommerceBaseUrl = 'http://admin.fosproductions.org/api';
  
  // Storage keys
  static const String _stickerPacksKey = 'sticker_packs';
  static const String _stickersDir = 'stickers';

  /// Get all user stickers from ecommerce API with pagination support
  /// Requires user's ID and email (for cross-app security verification)
  /// Set testMode=true to show all stickers without purchase check (for testing)
  /// Use page and limit parameters for pagination
  static Future<Map<String, dynamic>> getUserStickers(int userId, {
    bool testMode = false, 
    String? userEmail,
    int page = 1,
    int limit = 10,
  }) async {
    try {
      // Build URL with user_id, user_email and pagination params
      final testParam = testMode ? '&test_mode=1' : '';
      final emailParam = (userEmail != null && userEmail.isNotEmpty) ? '&user_email=${Uri.encodeComponent(userEmail)}' : '';
      
      final url = '$_ecommerceBaseUrl/stickers/user-stickers.php?user_id=$userId$emailParam$testParam&page=$page&limit=$limit';
      print('🔍 Fetching stickers from: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      print('📡 API Response Status: ${response.statusCode}');
      print('📦 API Response Body: ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ API Success: ${data['success']}');
        print('📊 Total packs: ${data['data']?['total_packs'] ?? 0}');
        
        if (data['success'] == true) {
          final packs = (data['data']['sticker_packs'] as List<dynamic>)
              .map((p) => StickerPack.fromJson(p as Map<String, dynamic>))
              .toList();
          
          final pagination = data['data']['pagination'] as Map<String, dynamic>?;
          
          return {
            'packs': packs,
            'pagination': pagination,
            'total_packs': data['data']['total_packs'] ?? 0,
          };
        }
      }
      
      throw Exception('Failed to fetch stickers: ${response.statusCode}');
    } catch (e) {
      print('❌ Error fetching stickers: $e');
      return {'packs': [], 'pagination': null, 'total_packs': 0};
    }
  }

  /// Download sticker image and save locally
  static Future<String?> downloadSticker(Sticker sticker) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final stickersDir = Directory('${directory.path}/$_stickersDir');
      
      if (!await stickersDir.exists()) {
        await stickersDir.create(recursive: true);
      }

      final fileName = 'sticker_${sticker.id}.png';
      final localPath = '${stickersDir.path}/$fileName';
      final file = File(localPath);

      // Skip if already downloaded
      if (await file.exists()) {
        sticker.localPath = localPath;
        return localPath;
      }

      // Download image
      final response = await http.get(Uri.parse(sticker.imageUrl));
      
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        sticker.localPath = localPath;
        return localPath;
      }
    } catch (e) {
      // Silently handle download errors to avoid spam
    }
    return null;
  }

  /// Download all stickers from a pack
  static Future<void> downloadStickerPack(StickerPack pack) async {
    for (final sticker in pack.stickers) {
      await downloadSticker(sticker);
    }
    // Update cache with local paths
    await _updateStickerPackInCache(pack);
  }

  // Cache for sticker existence checks to avoid repeated file system calls
  static final Map<int, bool> _stickerExistenceCache = {};
  
  /// Get all stickers as flat list (for emoji picker)
  static Future<List<Sticker>> getAllStickers() async {
    final packs = await getCachedStickerPacks();
    
    final allStickers = <Sticker>[];
    
    for (final pack in packs) {
      for (final sticker in pack.stickers) {
        // Add sticker if it has an image URL (will download on demand)
        if (sticker.imageUrl.isNotEmpty) {
          allStickers.add(sticker);
        } else if (sticker.localPath != null) {
          // Check if sticker is downloaded using cache
          bool exists = _stickerExistenceCache[sticker.id] ?? false;
          if (!exists) {
            final file = File(sticker.localPath!);
            exists = await file.exists();
            _stickerExistenceCache[sticker.id] = exists;
          }
          
          if (exists) {
            allStickers.add(sticker);
          }
        }
      }
    }
    
    return allStickers;
  }

  /// Get stickers grouped by pack (for sticker picker UI)
  static Future<List<StickerPack>> getStickersByPack() async {
    return await getCachedStickerPacks();
  }

  /// Copy sticker to clipboard as emoji
  static Future<void> copyStickerAsEmoji(Sticker sticker) async {
    await Clipboard.setData(ClipboardData(text: sticker.emojiCode));
  }

  /// Check if sticker is downloaded
  static Future<bool> isStickerDownloaded(Sticker sticker) async {
    if (sticker.localPath == null) return false;
    final file = File(sticker.localPath!);
    return await file.exists();
  }

  // Private helper methods

  static Future<void> _saveStickerPacks(List<StickerPack> packs) async {
    final prefs = await SharedPreferences.getInstance();
    final data = packs.map((p) => {
      'pack_id': p.packId,
      'product_id': p.productId,
      'name': p.name,
      'description': p.description,
      'category': p.category,
      'total_stickers': p.totalStickers,
      'product_image': p.productImage,
      'order_item_id': p.orderItemId,
      'stickers': p.stickers.map((s) => s.toJson()).toList(),
      'created_at': p.createdAt,
    }).toList();
    
    await prefs.setString(_stickerPacksKey, jsonEncode(data));
  }

  static Future<List<StickerPack>> getCachedStickerPacks() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_stickerPacksKey);
    
    if (data == null) return [];
    
    try {
      final packs = (jsonDecode(data) as List<dynamic>)
          .map((p) => StickerPack.fromJson(p as Map<String, dynamic>))
          .toList();
      return packs;
    } catch (e) {
      print('❌ Error parsing cached stickers: $e');
      return [];
    }
  }

  static Future<void> _updateStickerPackInCache(StickerPack pack) async {
    final packs = await getCachedStickerPacks();
    final index = packs.indexWhere((p) => p.packId == pack.packId);
    
    if (index >= 0) {
      packs[index] = pack;
      await _saveStickerPacks(packs);
    }
  }

  /// Clear all cached stickers
  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_stickerPacksKey);
    
    final directory = await getApplicationDocumentsDirectory();
    final stickersDir = Directory('${directory.path}/$_stickersDir');
    if (await stickersDir.exists()) {
      await stickersDir.delete(recursive: true);
    }
    
    // Clear existence cache
    _stickerExistenceCache.clear();
  }

  /// Sync stickers with ecommerce (call periodically) with pagination
  /// Requires user's ID and email from Fruits app
  /// Set testMode=true for testing without purchase
  /// Fetches first page only (10 stickers) for fast loading
  static Future<Map<String, dynamic>> syncStickers(int userId, {bool testMode = false, String? userEmail, int page = 1, int limit = 10}) async {
    try {
      final result = await getUserStickers(userId, testMode: testMode, userEmail: userEmail, page: page, limit: limit);
      final packs = (result['packs'] as List<dynamic>?)
          ?.map((p) => p is StickerPack ? p : StickerPack.fromJson(p as Map<String, dynamic>))
          .toList() ?? <StickerPack>[];
      final pagination = result['pagination'] as Map<String, dynamic>?;
      
      // Save packs to cache first
      await _saveStickerPacks(packs);
      
      // Download stickers for fetched packs
      for (final pack in packs) {
        await downloadStickerPack(pack);
      }
      
      print('✅ Sticker sync completed. Page $page: ${packs.length} packs');
      return result;
    } catch (e) {
      print('❌ Sticker sync failed: $e');
      return {'packs': [], 'pagination': null, 'total_packs': 0};
    }
  }

  /// Share sticker to WhatsApp or other apps
  static Future<void> shareSticker(Sticker sticker) async {
    try {
      if (sticker.localPath == null) {
        throw Exception('Sticker not downloaded');
      }
      
      final file = File(sticker.localPath!);
      if (!await file.exists()) {
        throw Exception('Sticker file not found');
      }
      
      // Use share_plus to share the image file
      await Share.shareXFiles(
        [XFile(sticker.localPath!)],
        text: '${sticker.name} - ${sticker.emojiCode}',
        subject: 'Fruit of the Spirit Sticker',
      );
      
      print('✅ Sticker shared: ${sticker.name}');
    } catch (e) {
      print('❌ Error sharing sticker: $e');
      rethrow;
    }
  }
}
