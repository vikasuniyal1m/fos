import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/controllers/fruits_controller.dart';
import 'package:fruitsofspirit/controllers/home_controller.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';
import 'package:fruitsofspirit/utils/screen_size.dart';
import 'package:fruitsofspirit/widgets/cached_image.dart';
import 'package:fruitsofspirit/config/image_config.dart';
import 'package:fruitsofspirit/widgets/app_bottom_navigation_bar.dart';
import 'package:fruitsofspirit/widgets/standard_app_bar.dart';
import 'package:fruitsofspirit/services/emojis_service.dart';
import 'package:fruitsofspirit/services/fruits_service.dart';
import 'package:fruitsofspirit/services/user_storage.dart';
import 'package:fruitsofspirit/services/hive_cache_service.dart';
import 'package:fruitsofspirit/services/cache_service.dart';
import 'package:fruitsofspirit/screens/home_screen.dart';
import 'package:fruitsofspirit/routes/routes.dart';

import '../utils/app_theme.dart';

/// Fruits of the Spirit Screen
/// Displays all 9 fruits with selection functionality
class FruitsScreen extends StatefulWidget {
  const FruitsScreen({Key? key}) : super(key: key);

  @override
  State<FruitsScreen> createState() => _FruitsScreenState();
}

class _FruitsScreenState extends State<FruitsScreen> {
  final controller = Get.find<FruitsController>();
  final homeController = Get.find<HomeController>();
  var fruitEmojis = <Map<String, dynamic>>[];
  var allFruitVariants = <Map<String, dynamic>>[]; // All variants (01, 02, 03) for each fruit
  var isLoadingEmojis = true;
  
  // Performance: Use static variable to persist across screen recreations
  static var _isEmojisLoaded = false;
  static var _cachedFruitEmojis = <Map<String, dynamic>>[];
  static var _cachedAllVariants = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    // Try to load from local storage (Hive + SharedPreferences) first for instant display
    _loadFromLocalStorage();
    // Always reload fresh data from API to avoid showing stale cached data
    _loadFruitEmojis();
  }

  /// Load fruits from local storage (Hive + SharedPreferences) for instant display
  Future<void> _loadFromLocalStorage() async {
    try {
      // Try Hive cache first (faster)
      final cachedFruits = HiveCacheService.getCachedList('fruits_screen_emojis');
      final cachedVariants = HiveCacheService.getCachedList('fruits_screen_all_variants');
      
      if (cachedFruits.isNotEmpty) {
        setState(() {
          fruitEmojis = List<Map<String, dynamic>>.from(cachedFruits);
          allFruitVariants = List<Map<String, dynamic>>.from(cachedVariants);
          isLoadingEmojis = false;
        });
        print('✅ Loaded ${fruitEmojis.length} fruits from Hive cache (instant display)');
        return;
      }
      
      // Fallback to SharedPreferences cache
      final prefsCachedFruits = await CacheService.getCachedList('fruits_screen_emojis');
      final prefsCachedVariants = await CacheService.getCachedList('fruits_screen_all_variants');
      
      if (prefsCachedFruits.isNotEmpty) {
        setState(() {
          fruitEmojis = List<Map<String, dynamic>>.from(prefsCachedFruits);
          allFruitVariants = List<Map<String, dynamic>>.from(prefsCachedVariants);
          isLoadingEmojis = false;
        });
        print('✅ Loaded ${fruitEmojis.length} fruits from SharedPreferences cache (instant display)');
        return;
      }
      
      // If static cache is available, use it temporarily
      if (_isEmojisLoaded && _cachedFruitEmojis.isNotEmpty) {
        setState(() {
          fruitEmojis = List<Map<String, dynamic>>.from(_cachedFruitEmojis);
          allFruitVariants = List<Map<String, dynamic>>.from(_cachedAllVariants);
          isLoadingEmojis = true; // Keep loading state to show we're refreshing
        });
        print('📋 Showing static cached fruit emojis temporarily (${fruitEmojis.length} items) while loading fresh data...');
      }
    } catch (e) {
      print('⚠️ Error loading from local storage: $e');
      // Continue to load from API
    }
  }

  Future<void> _loadFruitEmojis() async {
    try {
      setState(() {
        isLoadingEmojis = true;
      });

      // Clear old cache before loading new data to prevent showing stale data
      print('🗑️ Clearing old cache before loading fresh data...');
      _cachedFruitEmojis = [];
      _cachedAllVariants = [];

      // Load fruits from FRUITS table (not emojis table)
      // This ensures only fruits added in the fruits table are shown
      print('🔄 Loading fruits from FRUITS table (not emojis table)...');
      final fruitsFromTable = await FruitsService.getAllFruits();
      
      print('✅ Loaded ${fruitsFromTable.length} fruits from FRUITS table');
      
      // Show sample fruits
      if (fruitsFromTable.isNotEmpty) {
        print('📋 Fruits from table:');
        for (var i = 0; i < fruitsFromTable.length; i++) {
          print('   ${i + 1}. ID: ${fruitsFromTable[i]['id']}, Name: ${fruitsFromTable[i]['name']}');
        }
      }
      
      // Now get emojis for these fruits from emojis table
      // Match emojis by fruit name
      var emojis = await EmojisService.getEmojis(
        status: 'Active',
        sortBy: 'image_url',
        order: 'ASC',
      );
      
      print('✅ Loaded ${emojis.length} total emojis from database');
      
      // Filter emojis to match only fruits from fruits table
      final fruitNamesFromTable = fruitsFromTable.map((f) => (f['name'] as String? ?? '').toLowerCase().trim()).toList();
      print('📋 Fruit names from table: $fruitNamesFromTable');
      
      // Create a map of fruit IDs to names for better matching
      final fruitIdToName = <int, String>{};
      for (var fruit in fruitsFromTable) {
        final id = fruit['id'] as int?;
        final name = (fruit['name'] as String? ?? '').toLowerCase().trim();
        if (id != null) {
          fruitIdToName[id] = name;
        }
      }
      
      emojis = emojis.where((emoji) {
        final name = (emoji['name'] as String? ?? '').toLowerCase();
        final category = (emoji['category'] as String? ?? '').toLowerCase();
        
        // Check if emoji name contains any fruit name from fruits table
        final matchesFruitFromTable = fruitNamesFromTable.any((fruitName) {
          // More flexible matching - split into words and check each word
          final emojiWords = name.split(RegExp(r'[\s_\-]+')).where((w) => w.isNotEmpty).map((w) => w.toLowerCase()).toList();
          final fruitWords = fruitName.split(RegExp(r'[\s_\-]+')).where((w) => w.isNotEmpty).map((w) => w.toLowerCase()).toList();
          
          // Check if any word from fruit name appears in emoji name (or vice versa)
          final hasMatchingWord = fruitWords.any((fruitWord) => 
            emojiWords.any((emojiWord) => 
              emojiWord.contains(fruitWord) || 
              fruitWord.contains(emojiWord) ||
              emojiWord == fruitWord
            )
          );
          
          // Also check direct contains (for cases like "Love Strawberry" contains "Love")
          final directMatch = name.contains(fruitName) || fruitName.contains(name);
          
          // Check if emoji name starts with fruit name or vice versa
          final startsWithMatch = name.startsWith(fruitName) || fruitName.startsWith(name.split(' ').first);
          
          return hasMatchingWord || directMatch || startsWithMatch;
        });
        
        // Also check category if available - if category is "Fruit of Spirit" or similar, include it
        final hasFruitCategory = category.isNotEmpty && 
                                 (category.contains('fruit') || category.contains('spirit')) && 
                                 !category.contains('opposite') && 
                                 category != 'general';
        
        // Exclude generic emoji names
        final isGenericEmoji = RegExp(r'^emoji \d+$').hasMatch(name.trim());
        
        // Include if:
        // 1. It matches a fruit from the fruits table, OR
        // 2. It has a fruit category (for cases where emoji name doesn't match but category does)
        final shouldInclude = (matchesFruitFromTable || hasFruitCategory) && !isGenericEmoji;
        
        if (shouldInclude) {
          print('✅ Including emoji: "${emoji['name']}" (matches table: $matchesFruitFromTable, category: $hasFruitCategory)');
        } else {
          // Debug: Show why emoji was excluded
          print('❌ Excluding emoji: "${emoji['name']}" | Category: "$category" | Matches table: $matchesFruitFromTable | Has fruit category: $hasFruitCategory | Is generic: $isGenericEmoji');
        }
        
        return shouldInclude;
      }).toList();
      
      print('✅ Filtered to ${emojis.length} fruit emojis matching fruits from table');
      
      // Store all variants first (for variant dialog)
      final allVariants = List<Map<String, dynamic>>.from(emojis);
      
      // Extract base fruit name from names like "Goodness Banana 1" -> "Goodness"
      // Base name is the first word (spiritual fruit name)
      String extractBaseFruitName(String fullName) {
        final name = fullName.trim();
        if (name.isEmpty) return '';
        
        // Split by space and take first word
        final parts = name.split(' ');
        if (parts.isEmpty) return name;
        
        // First word is the base fruit name (Goodness, Joy, Kindness, etc.)
        return parts[0].trim();
      }
      
      // Get unique fruits - match each emoji to fruit from table and use fruit name as key
      final uniqueFruits = <String, Map<String, dynamic>>{};
      
      for (var emoji in emojis) {
        final emojiName = (emoji['name'] as String? ?? '').toLowerCase().trim();
        final code = (emoji['code'] as String? ?? '').toLowerCase();
        
        // Find which fruit from table this emoji matches
        String? matchedFruitName;
        for (var fruit in fruitsFromTable) {
          final fruitName = (fruit['name'] as String? ?? '').toLowerCase().trim();
          
          // Check if emoji matches this fruit
          final emojiWords = emojiName.split(RegExp(r'[\s_\-]+')).where((w) => w.isNotEmpty).map((w) => w.toLowerCase()).toList();
          final fruitWords = fruitName.split(RegExp(r'[\s_\-]+')).where((w) => w.isNotEmpty).map((w) => w.toLowerCase()).toList();
          
          final hasMatchingWord = fruitWords.any((fruitWord) => 
            emojiWords.any((emojiWord) => 
              emojiWord.contains(fruitWord) || 
              fruitWord.contains(emojiWord) ||
              emojiWord == fruitWord
            )
          );
          
          final directMatch = emojiName.contains(fruitName) || fruitName.contains(emojiName);
          final startsWithMatch = emojiName.startsWith(fruitName) || fruitName.startsWith(emojiName.split(' ').first);
          
          if (hasMatchingWord || directMatch || startsWithMatch) {
            matchedFruitName = fruitName; // Use fruit name from table as key
            print('🔗 Matched emoji "${emoji['name']}" to fruit "$fruitName" from table');
            break;
          }
        }
        
        // If no match found, try to extract base name from emoji name
        if (matchedFruitName == null || matchedFruitName.isEmpty) {
          matchedFruitName = extractBaseFruitName(emoji['name'] as String? ?? '').toLowerCase();
          if (matchedFruitName.isNotEmpty) {
            print('⚠️ No table match for "${emoji['name']}", using extracted name: "$matchedFruitName"');
          }
        }
        
        if (matchedFruitName.isEmpty) {
          print('❌ Skipping emoji "${emoji['name']}" - no name found');
          continue; // Skip if no name
        }
        
        // If we don't have this fruit yet, add it
        if (!uniqueFruits.containsKey(matchedFruitName)) {
          uniqueFruits[matchedFruitName] = emoji;
        } else {
          // Prefer variant with "1" in name or code ending with _01
          final currentName = (uniqueFruits[matchedFruitName]!['name'] as String? ?? '').toLowerCase();
          final currentCode = (uniqueFruits[matchedFruitName]!['code'] as String? ?? '').toLowerCase();
          
          // Check if new emoji is variant 1
          final isNewVariant1 = emojiName.contains(' 1') || 
                                 emojiName.endsWith(' 1') ||
                                 code.endsWith('_01') ||
                                 code.contains('_1');
          
          // Check if current is variant 1
          final isCurrentVariant1 = currentName.contains(' 1') || 
                                    currentName.endsWith(' 1') ||
                                    currentCode.endsWith('_01') ||
                                    currentCode.contains('_1');
          
          // Prefer variant 1
          if (isNewVariant1 && !isCurrentVariant1) {
            uniqueFruits[matchedFruitName] = emoji;
          }
        }
      }
      
      // Update display names to show fruit name from table (or base name if not matched)
      for (var key in uniqueFruits.keys) {
        final emoji = uniqueFruits[key]!;
        // Use the key (which is the fruit name from table) as display name
        emoji['display_name'] = key;
      }
      
      print('✅ Loaded ${uniqueFruits.length} unique fruits for Fruits screen');
      for (var entry in uniqueFruits.entries) {
        print('   - ${entry.key}: ${entry.value['name']} -> Display: ${entry.value['display_name'] ?? entry.key}');
      }
      
      // Debug: Check which fruits from table were matched
      final matchedFruitNames = uniqueFruits.keys.toList();
      final unmatchedFruits = fruitsFromTable.where((fruit) {
        final fruitName = (fruit['name'] as String? ?? '').toLowerCase().trim();
        return !matchedFruitNames.contains(fruitName);
      }).toList();
      
      if (unmatchedFruits.isNotEmpty) {
        print('⚠️ WARNING: ${unmatchedFruits.length} fruits from table have no matching emojis:');
        for (var fruit in unmatchedFruits) {
          print('   - ID: ${fruit['id']}, Name: "${fruit['name']}"');
        }
        print('💡 Check if emojis exist in emojis table with matching names or category="Fruit of Spirit"');
      } else {
        print('✅ All fruits from table have matching emojis');
      }
      
      // Convert to list and ensure no duplicate IDs
      final fruitEmojisList = uniqueFruits.values.toList();
      final seenIds = <int>{};
      final deduplicatedFruits = <Map<String, dynamic>>[];
      
      for (var fruit in fruitEmojisList) {
        final id = fruit['id'] as int?;
        if (id != null && !seenIds.contains(id)) {
          seenIds.add(id);
          deduplicatedFruits.add(fruit);
        }
      }
      
      // IMPORTANT: Create fresh copies to avoid reference issues
      final freshFruitEmojis = List<Map<String, dynamic>>.from(deduplicatedFruits);
      final freshAllVariants = List<Map<String, dynamic>>.from(allVariants);
      
      // Update static cache with fresh data
      _cachedFruitEmojis = List<Map<String, dynamic>>.from(freshFruitEmojis);
      _cachedAllVariants = List<Map<String, dynamic>>.from(freshAllVariants);
      _isEmojisLoaded = true; // Performance: Mark as loaded
      
      // Save to local storage (Hive + SharedPreferences) for persistence
      try {
        // Save to Hive cache (fast, synchronous)
        await HiveCacheService.cacheList('fruits_screen_emojis', freshFruitEmojis);
        await HiveCacheService.cacheList('fruits_screen_all_variants', freshAllVariants);
        
        // Also save to SharedPreferences cache (for compatibility)
        await CacheService.cacheList('fruits_screen_emojis', freshFruitEmojis);
        await CacheService.cacheList('fruits_screen_all_variants', freshAllVariants);
        
        print('💾 Fruits cached successfully (Hive + SharedPreferences)');
      } catch (e) {
        print('⚠️ Error caching fruits to local storage: $e');
      }
      
      // Update UI with fresh data (not from cache reference)
      setState(() {
        fruitEmojis = freshFruitEmojis;
        allFruitVariants = freshAllVariants;
        isLoadingEmojis = false;
      });
      
      print('✅ Fresh fruit emojis loaded and cached (${fruitEmojis.length} items)');
      print('✅ Cache updated with latest data');
    } catch (e, stackTrace) {
      print('❌ Error loading fruit emojis: $e');
      print('❌ Stack trace: $stackTrace');
      
      // If we have cached data, use it even on error
      if (_isEmojisLoaded && _cachedFruitEmojis.isNotEmpty) {
        setState(() {
          fruitEmojis = List<Map<String, dynamic>>.from(_cachedFruitEmojis);
          allFruitVariants = List<Map<String, dynamic>>.from(_cachedAllVariants);
          isLoadingEmojis = false;
        });
        print('✅ Using cached data after error');
      } else {
        // No cached data - set empty list
        setState(() {
          fruitEmojis = [];
          allFruitVariants = [];
          isLoadingEmojis = false;
        });
      }
    }
  }
  
  /// Clear cache (call this only when explicitly needed, e.g., pull to refresh)
  static void clearCache() {
    _isEmojisLoaded = false;
    _cachedFruitEmojis = [];
    _cachedAllVariants = [];
    
    // Also clear local storage cache
    try {
      HiveCacheService.clearKey('fruits_screen_emojis');
      HiveCacheService.clearKey('fruits_screen_all_variants');
      CacheService.clearCache('fruits_screen_emojis');
      CacheService.clearCache('fruits_screen_all_variants');
      print('🗑️ Fruit emojis cache cleared (static + local storage)');
    } catch (e) {
      print('⚠️ Error clearing local storage cache: $e');
      print('🗑️ Fruit emojis static cache cleared');
    }
  }

  Future<void> _loadAllFruitVariants() async {
    // This function is now redundant - _loadFruitEmojis() already loads all variants
    // Keeping it for backward compatibility but it just calls _loadFruitEmojis
    await _loadFruitEmojis();
  }


  Map<String, dynamic>? _getFruitEmoji(String fruitName) {
    if (fruitEmojis.isEmpty) return null;
    
    final normalizedFruitName = fruitName.toLowerCase().trim();
    
    // Special mappings for variations
    final nameMappings = {
      'gentleness': ['gentleness', 'meekness'],
      'meekness': ['gentleness', 'meekness'],
      'self-control': ['self-control', 'self control', 'discipline'],
      'self control': ['self-control', 'self control', 'discipline'],
    };
    
    // Try to find exact match first
    var exactMatch = fruitEmojis.firstWhere(
      (emoji) {
        final emojiName = (emoji['name'] as String? ?? '').toLowerCase().trim();
        return emojiName == normalizedFruitName;
      },
      orElse: () => <String, dynamic>{},
    );
    
    if (exactMatch.isNotEmpty) {
      return exactMatch;
    }
    
    // Try with name mappings
    if (nameMappings.containsKey(normalizedFruitName)) {
      for (var mappedName in nameMappings[normalizedFruitName]!) {
        exactMatch = fruitEmojis.firstWhere(
          (emoji) {
            final emojiName = (emoji['name'] as String? ?? '').toLowerCase().trim();
            return emojiName == mappedName;
          },
          orElse: () => <String, dynamic>{},
        );
        if (exactMatch.isNotEmpty) {
          return exactMatch;
        }
      }
    }
    
    // Try partial match
    final partialMatch = fruitEmojis.firstWhere(
      (emoji) {
        final emojiName = (emoji['name'] as String? ?? '').toLowerCase().trim();
        return emojiName.contains(normalizedFruitName) ||
               normalizedFruitName.contains(emojiName);
      },
      orElse: () => <String, dynamic>{},
    );
    
    return partialMatch.isNotEmpty ? partialMatch : null;
  }

  /// Build high-quality image widget with proper caching and no blur
  Widget _buildHighQualityImage(BuildContext context, Map<String, dynamic> fruitEmoji, double size) {
    final imageUrl = fruitEmoji['image_url'] as String?;
    final emojiChar = fruitEmoji['emoji_char'] as String? ?? '';
    
    String? fullImageUrl;
    
    // Get full image URL
    if (imageUrl != null && imageUrl.toString().trim().isNotEmpty) {
      fullImageUrl = imageUrl.toString().trim();
      
      // Convert relative paths to full URLs
      if (fullImageUrl.startsWith('uploads/')) {
        fullImageUrl = 'https://fruitofthespirit.templateforwebsites.com/$fullImageUrl';
      } else if (!fullImageUrl.startsWith('http://') && !fullImageUrl.startsWith('https://')) {
        fullImageUrl = 'https://fruitofthespirit.templateforwebsites.com/uploads/$fullImageUrl';
      }
      
      // Replace spaces with %20 for URL encoding
      fullImageUrl = fullImageUrl.replaceAll(' ', '%20');
    }
    
    // If we have an image URL, show it with high quality
    if (fullImageUrl != null && fullImageUrl.isNotEmpty) {
      return CachedImage(
        imageUrl: fullImageUrl,
        width: size,
        height: size,
        fit: BoxFit.contain, // Use contain to show full image without cropping
        errorWidget: _buildEmojiFallback(context, emojiChar, size),
      );
    }
    
    // Fallback to emoji character
    return _buildEmojiFallback(context, emojiChar, size);
  }

  /// Build emoji character fallback
  /// Build emoji fallback - ONLY shows image, NO emoji text
  Widget _buildEmojiFallback(BuildContext context, String emojiChar, double size) {
    // Try to get fruit image from emoji character (NO emoji text display)
    if (emojiChar.isNotEmpty) {
      final imageUrl = ImageConfig.getFruitReactionImageUrl(emojiChar, size: size, variant: 1);
      if (imageUrl != null) {
        return CachedImage(
          imageUrl: imageUrl,
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorWidget: _buildPlaceholderIcon(context, size),
        );
      }
    }
    
    // Fallback: Show placeholder icon (NO emoji text)
    return _buildPlaceholderIcon(context, size);
  }
  
  /// Build placeholder icon (NO emoji text)
  Widget _buildPlaceholderIcon(BuildContext context, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
      ),
      child: Icon(
        Icons.sentiment_satisfied,
        size: size * 0.6,
        color: Colors.grey[400],
      ),
    );
  }

  void _showFruitVariantsDialog(BuildContext context, String fruitName, List<Map<String, dynamic>> allVariants, List<Map<String, dynamic>> fruitEmojisList) {
    // Extract base fruit name (first word) from display name
    String extractBaseFruitName(String fullName) {
      final name = fullName.trim();
      if (name.isEmpty) return '';
      final parts = name.split(' ');
      return parts.isNotEmpty ? parts[0].trim() : name;
    }
    
    // Get base fruit name from the clicked fruit
    final baseFruitName = extractBaseFruitName(fruitName).toLowerCase().trim();
    
    print('🔍 Looking for variants of base fruit: $baseFruitName');
    
    // Get all variants for this fruit - match by first word
    final variants = allVariants.where((emoji) {
      final emojiName = (emoji['name'] as String? ?? '').trim();
      final emojiBaseName = extractBaseFruitName(emojiName).toLowerCase().trim();
      
      // Match by base name (first word)
      return emojiBaseName == baseFruitName;
    }).toList();
    
    // Sort variants by number in name (1, 2, 3) or code
    variants.sort((a, b) {
      final nameA = (a['name'] as String? ?? '').toLowerCase();
      final nameB = (b['name'] as String? ?? '').toLowerCase();
      
      // Extract number from name (e.g., "Goodness Banana 1" -> 1)
      int extractNumber(String name) {
        final match = RegExp(r'\b(\d+)\b').firstMatch(name);
        return match != null ? int.tryParse(match.group(1) ?? '0') ?? 0 : 0;
      }
      
      final numA = extractNumber(nameA);
      final numB = extractNumber(nameB);
      
      if (numA != numB) return numA.compareTo(numB);
      
      // Fallback to code comparison
      final codeA = (a['code'] as String? ?? '').toLowerCase();
      final codeB = (b['code'] as String? ?? '').toLowerCase();
      return codeA.compareTo(codeB);
    });
    
    if (variants.isEmpty) {
      Get.snackbar(
        'No Variants',
        'No variants found for $fruitName',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }
    
    print('🎯 Found ${variants.length} variants for $fruitName');
    for (var variant in variants) {
      print('   - ${variant['code']}: ${variant['image_url']}');
    }
    
    // Store variables accessible to the dialog
    final fruitEmojisForDialog = fruitEmojisList;
    final baseFruitNameForDialog = baseFruitName;
    final homeCtrl = homeController; // Capture for dialog closure
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return _FruitVariantsDialog(
          variants: variants,
          fruitName: fruitName,
          homeController: homeCtrl,
          fruitEmojisList: fruitEmojisForDialog,
          baseFruitName: baseFruitNameForDialog,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return _FruitsScreenContent(
      controller: controller,
      fruitEmojis: fruitEmojis,
      isLoadingEmojis: isLoadingEmojis,
      getFruitEmoji: _getFruitEmoji,
      homeController: homeController,
      showFruitVariants: (context, fruitName) => _showFruitVariantsDialog(context, fruitName, allFruitVariants, fruitEmojis),
      loadFruitEmojis: _loadFruitEmojis,
      loadAllFruitVariants: _loadAllFruitVariants,
      allFruitVariants: allFruitVariants,
      buildHighQualityImage: _buildHighQualityImage,
      buildEmojiFallback: _buildEmojiFallback,
    );
  }
}

// Separate StatefulWidget for dialog to properly handle scroll controller
class _FruitVariantsDialog extends StatefulWidget {
  final List<Map<String, dynamic>> variants;
  final String fruitName;
  final HomeController homeController;
  final List<Map<String, dynamic>> fruitEmojisList;
  final String baseFruitName;

  const _FruitVariantsDialog({
    Key? key,
    required this.variants,
    required this.fruitName,
    required this.homeController,
    required this.fruitEmojisList,
    required this.baseFruitName,
  }) : super(key: key);

  @override
  State<_FruitVariantsDialog> createState() => _FruitVariantsDialogState();
}

class _FruitVariantsDialogState extends State<_FruitVariantsDialog> {
  @override
  Widget build(BuildContext context) {
    return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 24, tablet: 28, desktop: 32)),
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: ResponsiveHelper.screenHeight(context) * 0.85,
              maxWidth: ResponsiveHelper.screenWidth(context) * 0.95,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 24, tablet: 28, desktop: 32)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 30,
                  spreadRadius: 0,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Modern Header
                Container(
                  padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 20)),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFFFFFFFF),
                        const Color(0xFFFFFFFF),
                      ],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(ResponsiveHelper.borderRadius(context, mobile: 24, tablet: 28, desktop: 32)),
                      topRight: Radius.circular(ResponsiveHelper.borderRadius(context, mobile: 24, tablet: 28, desktop: 32)),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.eco_rounded,
                                  color: AppTheme.iconscolor,
                                  size: ResponsiveHelper.iconSize(context, mobile: 24, tablet: 28, desktop: 32),
                                ),
                                SizedBox(width: ResponsiveHelper.spacing(context, 10)),
                                Text(
                                  '${widget.fruitName.split(' ').first} Variant',
                                  style: ResponsiveHelper.textStyle(
                                    context,
                                    fontSize: ResponsiveHelper.fontSize(context, mobile: 22, tablet: 26, desktop: 30),
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: ResponsiveHelper.spacing(context, 6)),
                            Text(
                              '${widget.variants.length} beautiful variants to choose from',
                              style: ResponsiveHelper.textStyle(
                                context,
                                fontSize: ResponsiveHelper.fontSize(context, mobile: 13, tablet: 14, desktop: 15),
                                color: Colors.black,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.of(context).pop(),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 8)),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              color: AppTheme.iconscolor,
                              size: ResponsiveHelper.iconSize(context, mobile: 20, tablet: 22, desktop: 24),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Variants in Column with Description (3 variants max)
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(
                      ResponsiveHelper.isMobile(context) 
                        ? ResponsiveHelper.spacing(context, 16)
                        : ResponsiveHelper.isTablet(context)
                          ? ResponsiveHelper.spacing(context, 20)
                          : ResponsiveHelper.spacing(context, 24),
                    ),
                    child: Column(
                      children: widget.variants.take(3).map((variant) {
                        final index = widget.variants.indexOf(variant);
                        final description = variant['description'] as String? ?? 'No description available';
                        
                        // Extract variant name from image_url path
                        // Example: "uploads/images/Strawberry.png" -> "Strawberry"
                        // Example: "uploads/fruitofspirit/pineapple-01.png" -> "Pineapple"
                        String extractVariantNameFromImagePath(Map<String, dynamic> variant) {
                          final imageUrl = variant['image_url'] as String? ?? '';
                          
                          if (imageUrl.isNotEmpty) {
                            // Get filename from path (e.g., "uploads/images/Strawberry.png" -> "Strawberry.png")
                            final fileName = imageUrl.split('/').last;
                            
                            // Remove extension (.png, .jpg, etc.)
                            final nameWithoutExt = fileName.replaceAll(RegExp(r'\.(png|jpg|jpeg|webp)$', caseSensitive: false), '');
                            
                            // Remove variant numbers and separators (e.g., "pineapple-01" -> "pineapple", "Strawberry_01" -> "Strawberry")
                            String cleanName = nameWithoutExt
                                .replaceAll(RegExp(r'[-_]\d+$'), '') // Remove -01, _01, etc.
                                .replaceAll(RegExp(r'\s+\d+$'), '') // Remove trailing " 1"
                                .replaceAll('_', ' ') // Replace underscores with spaces
                                .replaceAll('-', ' '); // Replace hyphens with spaces
                            
                            // Capitalize first letter of each word
                            if (cleanName.isNotEmpty) {
                              final words = cleanName.split(' ').where((w) => w.isNotEmpty).toList();
                              if (words.isNotEmpty) {
                                return words.map((word) {
                                  if (word.isEmpty) return '';
                                  return word[0].toUpperCase() + (word.length > 1 ? word.substring(1).toLowerCase() : '');
                                }).join(' ');
                              }
                            }
                          }
                          
                          // Fallback: use name field if available
                          final name = variant['name'] as String? ?? '';
                          if (name.isNotEmpty) {
                            // Remove variant numbers from name
                            String cleanName = name
                                .replaceAll(RegExp(r'\s+\d+$'), '') // Remove trailing " 1"
                                .replaceAll(RegExp(r'[-_]\d+$'), ''); // Remove trailing -01, _01
                            
                            if (cleanName.isNotEmpty) {
                              return cleanName;
                            }
                          }
                          
                          // Final fallback
                          return 'Variant ${index + 1}';
                        }
                        
                        final variantName = extractVariantNameFromImagePath(variant);
                        
                        return Container(
                          margin: EdgeInsets.only(
                            bottom: ResponsiveHelper.isMobile(context)
                              ? ResponsiveHelper.spacing(context, 12)
                              : ResponsiveHelper.isTablet(context)
                                ? ResponsiveHelper.spacing(context, 16)
                                : ResponsiveHelper.spacing(context, 20),
                          ),
                          child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () async {
                            print('🖱️ Variant tapped: ${variant['name']}');
                            // Record usage
                            try {
                              final userId = await UserStorage.getUserId();
                              if (userId != null) {
                                // Extract emoji value from variant
                                // Priority: code > emoji_char > image_url (full) > name
                                // API accepts: code (like "meekness_grapes_03"), emoji_char, or full image_url
                                // DO NOT use variant ID - API doesn't accept numeric IDs
                                String? emojiValue;
                                
                                print('📋 Variant data: id=${variant['id']}, code=${variant['code']}, emoji_char=${variant['emoji_char']}, name=${variant['name']}, image_url=${variant['image_url']}');
                                
                                // Priority 1: Use code (like "meekness_grapes_03") - BEST for API
                                final variantCode = variant['code'] as String?;
                                if (variantCode != null && variantCode.toString().trim().isNotEmpty) {
                                  emojiValue = variantCode.toString().trim();
                                  print('✅ Using variant code: $emojiValue');
                                } 
                                // Priority 2: Use emoji_char if available (for emoji-based)
                                else {
                                  final emojiChar = variant['emoji_char'] as String?;
                                  if (emojiChar != null && emojiChar.toString().trim().isNotEmpty) {
                                    emojiValue = emojiChar.toString().trim();
                                    print('✅ Using variant emoji_char: $emojiValue');
                                  }
                                  // Priority 3: Use full image_url (API can match by image URL)
                                   else {
                                    final imageUrl = variant['image_url'] as String?;
                                    if (imageUrl != null && imageUrl.toString().trim().isNotEmpty) {
                                      emojiValue = imageUrl.toString().trim();
                                      print('✅ Using variant image_url: $emojiValue');
                                    }
                                    // Priority 4: Fallback to name (least reliable for API)
                                    else {
                                      emojiValue = variant['name'] as String?;
                                      print('✅ Using variant name: $emojiValue');
                                    }
                                  }
                                }
                                
                                if (emojiValue != null) {
                                  // Extract emoji value from variant
                                  // Priority: code > emoji_char > image_url (full) > name
                                  String? emojiValueForApi;
                                  
                                  // Priority 1: Use code (like "meekness_grapes_03") - BEST for API
                                  final variantCode = variant['code'] as String?;
                                  if (variantCode != null && variantCode.toString().trim().isNotEmpty) {
                                    emojiValueForApi = variantCode.toString().trim();
                                  } 
                                  // Priority 2: Use emoji_char if available
                                  else {
                                    final emojiChar = variant['emoji_char'] as String?;
                                    if (emojiChar != null && emojiChar.toString().trim().isNotEmpty) {
                                      emojiValueForApi = emojiChar.toString().trim();
                                    }
                                    // Priority 3: Use full image_url
                                    else {
                                      final imageUrl = variant['image_url'] as String?;
                                      if (imageUrl != null && imageUrl.toString().trim().isNotEmpty) {
                                        emojiValueForApi = imageUrl.toString().trim();
                                      }
                                      // Priority 4: Fallback to name
                                      else {
                                        emojiValueForApi = variant['name'] as String?;
                                      }
                                    }
                                  }
                                  
                                  if (emojiValueForApi != null && emojiValueForApi.isNotEmpty) {
                                    try {
                                      // STEP 1: Save to database FIRST (via API)
                                      print('🍎 FRUIT ISSUE: 💾 STEP 1: Saving to database via API...');
                                      print('🍎 FRUIT ISSUE:   - userId: $userId');
                                      print('🍎 FRUIT ISSUE:   - emojiValueForApi: $emojiValueForApi');
                                      print('🍎 FRUIT ISSUE:   - variant name: ${variant['name']}');
                                      print('🍎 FRUIT ISSUE:   - variant ID: ${variant['id']}');
                                      final apiResponse = await EmojisService.useEmoji(
                                        userId: userId,
                                        emoji: emojiValueForApi,
                                      );
                                      print('🍎 FRUIT ISSUE: ✅ Emoji saved to database successfully. Response: $apiResponse');
                                      
                                      // STEP 2: Update local storage IMMEDIATELY with variant data
                                      // This ensures instant UI update and persistence
                                      print('🍎 FRUIT ISSUE: 💾 STEP 2: Saving to local storage with variant data...');
                                      print('🍎 FRUIT ISSUE:   - Calling updateUserFeeling with emoji: $emojiValueForApi');
                                      print('🍎 FRUIT ISSUE:   - Variant data: name=${variant['name']}, id=${variant['id']}');
                                      await widget.homeController.updateUserFeeling(emojiValueForApi, emojiData: variant);
                                      print('🍎 FRUIT ISSUE: ✅ Emoji saved to local storage successfully');
                                      
                                      // Close dialog - check if still mounted
                                      if (mounted) {
                                        Navigator.of(context).pop();
                                      }
                                      
                                      // STEP 3: Don't reload from API immediately - trust local storage
                                      // The local storage already has the correct data with proper emoji_details
                                      print('✅ STEP 3: Skipping API reload - local storage has correct data');
                                      print('✅ UI should show the selected variant: ${variant['name']}');
                                      
                                      // Navigate to home page after fruit selection
                                      Get.offNamedUntil(Routes.HOME, (route) => false);
                                      
                                      // Show success message
                                      Get.snackbar(
                                        'Success',
                                        'Feeling updated successfully!',
                                        snackPosition: SnackPosition.BOTTOM,
                                        backgroundColor: Colors.green,
                                        colorText: Colors.white,
                                        duration: const Duration(seconds: 2),
                                      );
                                    } catch (e) {
                                      print('❌ Error saving emoji: $e');
                                      
                                      // Even if API fails, save to local storage for offline support
                                      print('💾 Saving to local storage as fallback...');
                                      try {
                                        await widget.homeController.updateUserFeeling(emojiValueForApi, emojiData: variant);
                                        print('✅ Saved to local storage as fallback');
                                      } catch (localError) {
                                        print('❌ Error saving to local storage: $localError');
                                      }
                                      
                                      // Close dialog on error
                                      if (mounted) {
                                        Navigator.of(context).pop();
                                      }
                                      
                                      // Navigate to home page after fruit selection (even on error)
                                      Get.offNamedUntil(Routes.HOME, (route) => false);
                                      
                                      // Show warning message
                                      Get.snackbar(
                                        'Warning',
                                        'Saved locally. Will sync when online.',
                                        snackPosition: SnackPosition.BOTTOM,
                                        backgroundColor: Colors.orange,
                                        colorText: Colors.white,
                                        duration: const Duration(seconds: 2),
                                      );
                                    }
                                  } else {
                                    print('❌ Could not determine emojiValue for variant: ${variant['name']}');
                                  }
                                } else {
                                  print('❌ Could not determine emojiValue for variant: ${variant['name']}');
                                }
                              } else {
                                print('⚠️ User not logged in, cannot record fruit selection.');
                                Get.snackbar(
                                  'Login Required',
                                  'Please login to select fruits.',
                                  backgroundColor: Colors.redAccent,
                                  colorText: Colors.white,
                                );
                              }
                            } catch (e) {
                              print('❌ Error recording fruit selection: $e');
                              Get.snackbar(
                                'Error',
                                'Failed to record fruit selection: ${e.toString().replaceAll('Exception: ', '')}',
                                backgroundColor: Colors.redAccent,
                                colorText: Colors.white,
                              );
                            }
                          },
                              borderRadius: BorderRadius.circular(ScreenSize.borderRadiusMedium),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white,
                                  Colors.grey[50]!,
                                ],
                              ),
                                  borderRadius: BorderRadius.circular(ScreenSize.borderRadiusMedium),
                              border: Border.all(
                                color: const Color(0xFF8B4513).withOpacity(0.15),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 15,
                                  spreadRadius: 0,
                                  offset: const Offset(0, 6),
                                ),
                                  ],
                                ),
                                padding: EdgeInsets.all(
                                  ResponsiveHelper.isMobile(context)
                                    ? ResponsiveHelper.spacing(context, 12)
                                    : ResponsiveHelper.isTablet(context)
                                      ? ResponsiveHelper.spacing(context, 16)
                                      : ResponsiveHelper.spacing(context, 20),
                                ),
                                child: Row(
                              children: [
                                    // Emoji Display
                                    Container(
                                      width: ResponsiveHelper.isMobile(context) 
                                        ? ResponsiveHelper.screenWidth(context) * 0.2
                                        : ResponsiveHelper.isTablet(context) 
                                          ? ResponsiveHelper.screenWidth(context) * 0.15
                                          : ResponsiveHelper.screenWidth(context) * 0.12,
                                      height: ResponsiveHelper.isMobile(context) 
                                        ? ResponsiveHelper.screenWidth(context) * 0.2
                                        : ResponsiveHelper.isTablet(context) 
                                          ? ResponsiveHelper.screenWidth(context) * 0.15
                                          : ResponsiveHelper.screenWidth(context) * 0.12,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(
                                          ResponsiveHelper.borderRadius(context, mobile: 8, tablet: 10, desktop: 12),
                                        ),
                                        border: Border.all(
                                          color: const Color(0xFF8B4513).withOpacity(0.2),
                                          width: 1,
                                        ),
                                      ),
                                      child: Center(
                                    child: HomeScreen.buildEmojiDisplay(
                                      context,
                                      Map<String, dynamic>.from(variant),
                                          size: ResponsiveHelper.isMobile(context) 
                                            ? ResponsiveHelper.screenWidth(context) * 0.15
                                            : ResponsiveHelper.isTablet(context) 
                                              ? ResponsiveHelper.screenWidth(context) * 0.12
                                              : ResponsiveHelper.screenWidth(context) * 0.1,
                                    ),
                                  ),
                                ),
                                    SizedBox(
                                      width: ResponsiveHelper.isMobile(context)
                                        ? ResponsiveHelper.spacing(context, 12)
                                        : ResponsiveHelper.isTablet(context)
                                          ? ResponsiveHelper.spacing(context, 16)
                                          : ResponsiveHelper.spacing(context, 20),
                                    ),
                                    // Variant Number and Description
                                Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Variant Number Badge
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: ResponsiveHelper.isMobile(context)
                                                ? ResponsiveHelper.spacing(context, 8)
                                                : ResponsiveHelper.isTablet(context)
                                                  ? ResponsiveHelper.spacing(context, 10)
                                                  : ResponsiveHelper.spacing(context, 12),
                                              vertical: ResponsiveHelper.isMobile(context)
                                                ? ResponsiveHelper.spacing(context, 4)
                                                : ResponsiveHelper.isTablet(context)
                                                  ? ResponsiveHelper.spacing(context, 5)
                                                  : ResponsiveHelper.spacing(context, 6),
                                            ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF8B4513).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(
                                                ResponsiveHelper.borderRadius(context, mobile: 6, tablet: 8, desktop: 10),
                                      ),
                                    ),
                                      child: Text(
                                              variantName,
                                        style: ResponsiveHelper.textStyle(
                                          context,
                                                fontSize: ResponsiveHelper.fontSize(
                                                  context,
                                                  mobile: 14,
                                                  tablet: 16,
                                                  desktop: 18,
                                                ),
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF8B4513),
                                        ),
                                      ),
                                    ),
                                          SizedBox(
                                            height: ResponsiveHelper.isMobile(context)
                                              ? ResponsiveHelper.spacing(context, 8)
                                              : ResponsiveHelper.isTablet(context)
                                                ? ResponsiveHelper.spacing(context, 10)
                                                : ResponsiveHelper.spacing(context, 12),
                                          ),
                                          // Description - Full text visible
                                          Text(
                                            description,
                                            style: ResponsiveHelper.textStyle(
                                              context,
                                              fontSize: ResponsiveHelper.fontSize(
                                                context,
                                                mobile: 12,
                                                tablet: 14,
                                                desktop: 16,
                                              ),
                                              color: Colors.black87,
                                              height: 1.5,
                                            ),
                                            // No maxLines limit - show full description
                                            // Text will wrap naturally
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
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
  }
}

class _FruitsScreenContent extends StatefulWidget {
  final FruitsController controller;
  final List<Map<String, dynamic>> fruitEmojis;
  final bool isLoadingEmojis;
  final Map<String, dynamic>? Function(String) getFruitEmoji;
  final HomeController homeController;
  final void Function(BuildContext, String) showFruitVariants;
  final Future<void> Function() loadFruitEmojis;
  final Future<void> Function() loadAllFruitVariants;
  final List<Map<String, dynamic>> allFruitVariants;
  final Widget Function(BuildContext, Map<String, dynamic>, double) buildHighQualityImage;
  final Widget Function(BuildContext, String, double) buildEmojiFallback;

  const _FruitsScreenContent({
    Key? key,
    required this.controller,
    required this.fruitEmojis,
    required this.isLoadingEmojis,
    required this.getFruitEmoji,
    required this.homeController,
    required this.showFruitVariants,
    required this.loadFruitEmojis,
    required this.loadAllFruitVariants,
    required this.allFruitVariants,
    required this.buildHighQualityImage,
    required this.buildEmojiFallback,
  }) : super(key: key);

  @override
  State<_FruitsScreenContent> createState() => _FruitsScreenContentState();
}

class _FruitsScreenContentState extends State<_FruitsScreenContent> {

  @override
  Widget build(BuildContext context) {
    // Professional responsive design for tablets/iPads
    final isTabletDevice = ResponsiveHelper.isTablet(context);
    final double? maxContentWidthValue = isTabletDevice 
        ? (ResponsiveHelper.isLargeTablet(context) ? 1200.0 : 840.0)
        : null;
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const StandardAppBar(
        showBackButton: false,
      ),
      body: Builder(
        builder: (context) {
          if (widget.isLoadingEmojis && widget.fruitEmojis.isEmpty) {
            return Center(
              child: CircularProgressIndicator(
                color: const Color(0xFF8B4513),
              ),
            );
          }

          if (widget.fruitEmojis.isEmpty && !widget.isLoadingEmojis) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: ResponsiveHelper.iconSize(context, mobile: 64),
                    color: Colors.grey,
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                  Text(
                    'No fruits available',
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                  ElevatedButton(
                    onPressed: () async {
                      await widget.loadFruitEmojis();
                      await widget.loadAllFruitVariants();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B4513),
                      padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveHelper.spacing(context, 24),
                        vertical: ResponsiveHelper.spacing(context, 12),
                      ),
                    ),
                    child: Text(
                      'Retry',
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
          onRefresh: () async {
            // Clear cache and reload
            _FruitsScreenState.clearCache();
            await widget.loadFruitEmojis();
          },
          color: const Color(0xFF8B4513),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                
                // Modern Header Section - Clean and Beautiful
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveHelper.spacing(context, 20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Beautiful Title
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 10)),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  const Color(0xFFFFFFFF),
                                  const Color(0xFFFFFFFF),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 14)),
                              boxShadow: [
                                BoxShadow(
                                  // color: const Color(0xFF8B4513).withOpacity(0.3),
                                  color: AppTheme.iconscolor,
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.eco_rounded,
                              color: AppTheme.iconscolor,
                              size: ResponsiveHelper.iconSize(context, mobile: 28, tablet: 32, desktop: 36),
                            ),
                          ),
                          SizedBox(width: ResponsiveHelper.spacing(context, 14)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'How are you feeling?',
                                  style: ResponsiveHelper.textStyle(
                                    context,
                                    fontSize: ResponsiveHelper.fontSize(context, mobile: 22, tablet: 26, desktop: 30),
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                SizedBox(height: ResponsiveHelper.spacing(context, 4)),
                                Text(
                                  'Select a fruit to express your feeling',
                                  style: ResponsiveHelper.textStyle(
                                    context,
                                    fontSize: ResponsiveHelper.fontSize(context, mobile: 13, tablet: 14, desktop: 15),
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, 28)),
                
                // Modern Section Title
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveHelper.spacing(context, 20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 6)),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
                        ),
                        child: Icon(
                          Icons.apps_rounded,
                          size: ResponsiveHelper.iconSize(context, mobile: 20, tablet: 22, desktop: 24),
                          color: AppTheme.iconscolor,
                        ),
                      ),
                      SizedBox(width: ResponsiveHelper.spacing(context, 10)),
                      Text(
                        'Tap any fruit to see variants',
                        style: ResponsiveHelper.textStyle(
                          context,
                          fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 18, desktop: 20),
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, 20)),
                
                // Fruits Grid - Using fruitEmojis
                if (widget.isLoadingEmojis)
                  Padding(
                    padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 40)),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: const Color(0xFF8B4513),
                      ),
                    ),
                  )
                else if (widget.fruitEmojis.isEmpty)
                  Padding(
                    padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 40)),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: ResponsiveHelper.iconSize(context, mobile: 30),
                            color: Colors.grey,
                          ),
                          SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                          Text(
                            'No fruits available',
                            style: ResponsiveHelper.textStyle(
                              context,
                              fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Builder(
                    builder: (context) {
                      print('🎨 Building fruits grid with ${widget.fruitEmojis.length} fruits');
                      if (widget.fruitEmojis.isEmpty) {
                        print('⚠️ fruitEmojis is empty!');
                        return Padding(
                          padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 40)),
                          child: Center(
                            child: Text(
                              'No fruits available',
                              style: ResponsiveHelper.textStyle(
                                context,
                                fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        );
                      }
                      
                      return Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: ResponsiveHelper.spacing(context, 16),
                        ),
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 6, // Same as prayer section
                            crossAxisSpacing: ResponsiveHelper.spacing(context, 12),
                            mainAxisSpacing: ResponsiveHelper.spacing(context, 12),
                          ),
                          itemCount: widget.fruitEmojis.length,
                          itemBuilder: (context, index) {
                            final fruitEmoji = widget.fruitEmojis[index];
                            final fruitName = (fruitEmoji['display_name'] as String? ?? fruitEmoji['name'] as String? ?? 'Unknown').split(' ').first;
                            
                            print('🎨 Building fruit card $index: $fruitName');
                            return _buildSimpleFruitCard(context, fruitEmoji, fruitName);
                          },
                        ),
                      );
                    },
                  ),
                
                SizedBox(height: ResponsiveHelper.spacing(context, 20)),
              ],
            ),
          ),
        );
        },
      ),
      bottomNavigationBar: const AppBottomNavigationBar(currentIndex: 1),
    );
  }

  /// Build beautiful fruit card - Modern and Engaging
  Widget _buildSimpleFruitCard(BuildContext context, Map<String, dynamic> fruitEmoji, String fruitName) {
    // Get attractive gradient colors for each fruit
    List<Color> getFruitGradient(String name) {
      final lowerName = name.toLowerCase();
      if (lowerName.contains('love')) return [Color(0xFFFFE5E5), Color(0xFFFFF0F0)];
      if (lowerName.contains('joy')) return [Color(0xFFFFF9C4), Color(0xFFFFFDE7)];
      if (lowerName.contains('peace')) return [Color(0xFFE8F5E9), Color(0xFFF1F8E9)];
      if (lowerName.contains('patience')) return [Color(0xFFFFF3E0), Color(0xFFFFF8E1)];
      if (lowerName.contains('kindness')) return [Color(0xFFFFE0B2), Color(0xFFFFECB3)];
      if (lowerName.contains('goodness')) return [Color(0xFFE1F5FE), Color(0xFFE0F2F1)];
      if (lowerName.contains('faithfulness')) return [Color(0xFFFFCDD2), Color(0xFFFFE0E6)];
      if (lowerName.contains('gentleness') || lowerName.contains('meekness')) return [Color(0xFFE1BEE7), Color(0xFFF3E5F5)];
      if (lowerName.contains('self') && lowerName.contains('control')) return [Color(0xFFC8E6C9), Color(0xFFDCEDC8)];
      return [Color(0xFFFEECE2), Color(0xFFFFF5F5)]; // Default peach gradient
    }

    final gradientColors = getFruitGradient(fruitName);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          print('🖱️ Fruit card tapped: $fruitName');
          // Show variants dialog for this fruit
          widget.showFruitVariants(context, fruitName);
        },
        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16, tablet: 18, desktop: 20)),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
            borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16, tablet: 18, desktop: 20)),
            border: Border.all(
              color: Colors.white.withOpacity(0.5),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 6,
                spreadRadius: 1,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 8)),
              child: HomeScreen.buildEmojiDisplay(
                context,
                fruitEmoji,
                size: ResponsiveHelper.isMobile(context) ? 48 : ResponsiveHelper.isTablet(context) ? 56 : 64,
              ),
            ),
          ),
        ),
      ),
    );
  }
}




