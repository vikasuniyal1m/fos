import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/services/stories_service.dart';
import 'package:fruitsofspirit/services/user_storage.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';
import 'package:fruitsofspirit/routes/routes.dart';
import 'package:fruitsofspirit/services/api_service.dart';
import 'package:fruitsofspirit/services/gallery_service.dart';
import 'package:fruitsofspirit/services/emojis_service.dart';
import 'package:fruitsofspirit/widgets/app_bottom_navigation_bar.dart';
import 'package:fruitsofspirit/widgets/cached_image.dart';
import 'package:fruitsofspirit/screens/home_screen.dart';

/// Stories Screen
/// Displays list of stories/testimonies
class StoriesScreen extends StatefulWidget {
  const StoriesScreen({Key? key}) : super(key: key);

  @override
  State<StoriesScreen> createState() => _StoriesScreenState();
}

class _StoriesScreenState extends State<StoriesScreen> {
  var isLoading = false;
  var stories = <Map<String, dynamic>>[];
  var userId = 0;
  String? selectedFruitTag;
  int currentPage = 0;
  final int itemsPerPage = 20;
  
  // Fruit emojis for filtering
  var fruitEmojis = <Map<String, dynamic>>[];
  var isLoadingFruits = true;
  int? selectedFruitId; // Track selected fruit by ID

  @override
  void initState() {
    super.initState();
    _loadUserId();
    _loadFruitEmojis();
    _loadStories();
  }

  Future<void> _loadUserId() async {
    final id = await UserStorage.getUserId();
    if (id != null) {
      setState(() {
        userId = id;
      });
    }
  }

  /// Load fruit emojis for filtering (same as fruits_screen)
  Future<void> _loadFruitEmojis() async {
    try {
      setState(() {
        isLoadingFruits = true;
      });

      // Load all emojis from database
      var emojis = await EmojisService.getEmojis(
        status: 'Active',
        sortBy: 'image_url',
        order: 'ASC',
      );
      
      // Filter to only show fruits
      emojis = emojis.where((emoji) {
        final name = (emoji['name'] as String? ?? '').toLowerCase();
        final category = (emoji['category'] as String? ?? '').toLowerCase();
        
        final fruitNames = [
          'goodness', 'joy', 'kindness', 'peace', 'patience', 
          'faithfulness', 'gentleness', 'meekness', 'self-control', 'self control', 'love'
        ];
        
        final hasFruitName = fruitNames.any((fruit) => name.contains(fruit));
        final hasFruitCategory = category.isNotEmpty && 
                                 category.contains('fruit') && 
                                 !category.contains('opposite') && 
                                 category != 'general';
        final isGenericEmoji = RegExp(r'^emoji \d+$').hasMatch(name.trim());
        
        return (hasFruitName || hasFruitCategory) && !isGenericEmoji;
      }).toList();
      
      // Extract base fruit name helper
      String extractBaseFruitName(String fullName) {
        final name = fullName.trim();
        if (name.isEmpty) return '';
        final parts = name.split(' ');
        return parts.isNotEmpty ? parts[0].trim() : name;
      }
      
      // Get unique fruits (one per base fruit name) - prefer variant 1
      final uniqueFruits = <String, Map<String, dynamic>>{};
      for (var emoji in emojis) {
        final name = (emoji['name'] as String? ?? '').trim();
        final code = (emoji['code'] as String? ?? '').toLowerCase();
        final baseName = extractBaseFruitName(name).toLowerCase();
        
        if (baseName.isEmpty) continue;
        
        if (!uniqueFruits.containsKey(baseName)) {
          uniqueFruits[baseName] = emoji;
        } else {
          final currentName = (uniqueFruits[baseName]!['name'] as String? ?? '').toLowerCase();
          final currentCode = (uniqueFruits[baseName]!['code'] as String? ?? '').toLowerCase();
          
          final isNewVariant1 = name.toLowerCase().contains(' 1') || 
                               name.toLowerCase().endsWith(' 1') ||
                               code.endsWith('_01') ||
                               code.contains('_1');
          
          final isCurrentVariant1 = currentName.contains(' 1') || 
                                    currentName.endsWith(' 1') ||
                                    currentCode.endsWith('_01') ||
                                    currentCode.contains('_1');
          
          if (isNewVariant1 && !isCurrentVariant1) {
            uniqueFruits[baseName] = emoji;
          }
        }
      }
      
      // Update display names
      for (var key in uniqueFruits.keys) {
        final emoji = uniqueFruits[key]!;
        final baseName = extractBaseFruitName(emoji['name'] as String? ?? '');
        emoji['display_name'] = baseName;
      }
      
      // Convert to list and deduplicate by ID
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
      
      setState(() {
        fruitEmojis = deduplicatedFruits;
        isLoadingFruits = false;
      });
      
      print('✅ Loaded ${fruitEmojis.length} unique fruits for Stories screen');
    } catch (e) {
      print('❌ Error loading fruit emojis: $e');
      setState(() {
        isLoadingFruits = false;
        fruitEmojis = [];
      });
    }
  }

  Future<void> _loadStories({bool refresh = false}) async {
    if (refresh) {
      currentPage = 0;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // Load both stories from stories table AND gallery photos with title/content/testimony
      // (Same as home page - gallery photos that are stories/testimonies)
      final List<Map<String, dynamic>> allStories = [];
      
      // 1. Load from Stories API (stories table)
      try {
        final storiesList = await StoriesService.getStories(
          status: 'Approved',
          fruitTag: selectedFruitTag,
          limit: itemsPerPage,
          offset: currentPage * itemsPerPage,
        );
        allStories.addAll(storiesList);
      } catch (e) {
        // If stories API fails, continue with gallery photos
        print('Stories API error: $e');
      }
      
      // 2. Load gallery photos that have title, content, or testimony (these are stories/testimonies)
      // Same as home page - these are the stories shown on home screen
      try {
        final galleryPhotos = await GalleryService.getPhotos(
          status: 'Approved',
          fruitTag: selectedFruitTag,
          currentUserId: userId > 0 ? userId : null,
          limit: itemsPerPage,
          offset: currentPage * itemsPerPage,
        );
        
        // Filter gallery photos that have story/testimony content (same logic as home page)
        final storyPhotos = galleryPhotos.where((photo) {
          final hasTitle = photo['title'] != null && (photo['title'] as String).isNotEmpty;
          final hasContent = photo['content'] != null && (photo['content'] as String).isNotEmpty;
          final hasTestimony = photo['testimony'] != null && (photo['testimony'] as String).isNotEmpty;
          return hasTitle || hasContent || hasTestimony;
        }).toList();
        
        // Convert gallery photos to story format (same as home page)
        for (var photo in storyPhotos) {
          allStories.add({
            'id': photo['id'],
            'title': photo['title'] ?? photo['testimony']?.toString().split('\n').first ?? 'Untitled Story',
            'content': photo['content'] ?? photo['testimony'] ?? '',
            'image_url': photo['file_path'] ?? photo['thumbnail_path'], // Use image_url for consistency
            'file_path': photo['file_path'], // Keep for navigation
            'thumbnail_path': photo['thumbnail_path'],
            'fruit_tag': photo['fruit_tag'],
            'user_name': photo['user_name'],
            'profile_photo': photo['profile_photo'],
            'created_at': photo['created_at'],
            'is_gallery_story': true, // Mark as gallery-based story
          });
        }
      } catch (e) {
        // If gallery API fails, continue with stories only
        print('Gallery API error: $e');
      }

      // Client-side filtering: Ensure only selected fruit's stories are shown
      List<Map<String, dynamic>> filteredStories = allStories;
      if (selectedFruitTag != null && selectedFruitTag!.isNotEmpty) {
        final normalizedSelectedTag = selectedFruitTag!.toLowerCase().trim();
        print('🔍 Filtering stories for fruit: "$selectedFruitTag" (normalized: "$normalizedSelectedTag")');
        print('🔍 Total stories before filter: ${allStories.length}');
        
        filteredStories = allStories.where((story) {
          final storyFruitTag = (story['fruit_tag'] as String? ?? '').toLowerCase().trim();
          final matches = storyFruitTag == normalizedSelectedTag;
          if (allStories.length <= 10) {
            print('   Story ${story['id']}: fruit_tag="${story['fruit_tag']}" (normalized: "$storyFruitTag") -> matches: $matches');
          }
          return matches;
        }).toList();
        
        print('🔍 Filtered ${allStories.length} stories to ${filteredStories.length} for fruit: $selectedFruitTag');
      } else {
        print('🔍 Showing all stories (no filter)');
      }

      setState(() {
        if (refresh || currentPage == 0) {
          stories = filteredStories;
        } else {
          stories.addAll(filteredStories);
        }
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        if (refresh || currentPage == 0) {
          stories = [];
        }
      });
      Get.snackbar(
        'Error',
        e.toString().replaceAll('Exception: ', ''),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(
          ResponsiveHelper.safeHeight(
            context,
            mobile: 70,
            tablet: 80,
            desktop: 90,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: ResponsiveHelper.isMobile(context) ? 4 : 8,
                offset: Offset(0, ResponsiveHelper.isMobile(context) ? 2 : 4),
              ),
            ],
            border: Border(
              bottom: BorderSide(
                color: Colors.grey.withOpacity(0.15),
                width: ResponsiveHelper.isMobile(context) ? 0.5 : 1,
              ),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: ResponsiveHelper.padding(
                context,
                horizontal: ResponsiveHelper.isMobile(context)
                    ? ResponsiveHelper.spacing(context, 16)
                    : ResponsiveHelper.isTablet(context)
                        ? ResponsiveHelper.spacing(context, 24)
                        : ResponsiveHelper.spacing(context, 32),
                vertical: ResponsiveHelper.isMobile(context)
                    ? ResponsiveHelper.spacing(context, 12)
                    : ResponsiveHelper.isTablet(context)
                        ? ResponsiveHelper.spacing(context, 14)
                        : ResponsiveHelper.spacing(context, 16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left Side - Logo
                  Expanded(
                    flex: ResponsiveHelper.isDesktop(context) ? 4 : 3,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Stories & Testimonies',
                        style: ResponsiveHelper.textStyle(
                          context,
                          fontSize: ResponsiveHelper.fontSize(context, mobile: 22, tablet: 24, desktop: 26),
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF5F4628),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: ResponsiveHelper.isMobile(context)
                        ? 12.0
                        : ResponsiveHelper.isTablet(context)
                            ? 16.0
                            : 20.0,
                  ),
                  // Right Side - Actions
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Create Story/Testimony Button
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Get.toNamed(Routes.CREATE_STORY),
                          borderRadius: BorderRadius.circular(30),
                          child: Container(
                            width: ResponsiveHelper.isMobile(context) ? 40.0 : ResponsiveHelper.isTablet(context) ? 44.0 : 48.0,
                            height: ResponsiveHelper.isMobile(context) ? 40.0 : ResponsiveHelper.isTablet(context) ? 44.0 : 48.0,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  const Color(0xFF8B4513),
                                  const Color(0xFFA0522D),
                                ],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF8B4513).withOpacity(0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.add,
                              color: Colors.white,
                              size: ResponsiveHelper.isMobile(context) ? 20.0 : ResponsiveHelper.isTablet(context) ? 22.0 : 24.0,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: ResponsiveHelper.isMobile(context) ? 10.0 : ResponsiveHelper.isTablet(context) ? 12.0 : 14.0,
                      ),
                      // Back Button
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Get.back(),
                          borderRadius: BorderRadius.circular(30),
                          child: Container(
                            width: ResponsiveHelper.isMobile(context) ? 40.0 : ResponsiveHelper.isTablet(context) ? 44.0 : 48.0,
                            height: ResponsiveHelper.isMobile(context) ? 40.0 : ResponsiveHelper.isTablet(context) ? 44.0 : 48.0,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.grey[50]!,
                                  Colors.grey[100]!,
                                ],
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.grey.withOpacity(0.2),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.arrow_back_rounded,
                              color: const Color(0xFF5F4628),
                              size: ResponsiveHelper.isMobile(context) ? 20.0 : ResponsiveHelper.isTablet(context) ? 22.0 : 24.0,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Fruit Filter - Professional Horizontal Scrollable Row (Instagram/Facebook Stories Style)
          Container(
            height: ResponsiveHelper.isMobile(context) ? 100 : ResponsiveHelper.isTablet(context) ? 110 : 120,
            color: Colors.white,
            child: isLoadingFruits
                ? Center(
                    child: Padding(
                      padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 20)),
                      child: CircularProgressIndicator(
                        color: const Color(0xFF8B4513),
                        strokeWidth: 2,
                      ),
                    ),
                  )
                : fruitEmojis.isEmpty
                    ? const SizedBox.shrink()
                    : Row(
                        children: [
                          SizedBox(width: ResponsiveHelper.spacing(context, 16)),
                          // "All" button
                          _buildFruitFilterButton(
                            context,
                            null,
                            'All',
                            null,
                            selectedFruitId == null,
                          ),
                          SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                          // Horizontal scrollable fruits
                          Expanded(
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              itemCount: fruitEmojis.length,
                              itemBuilder: (context, index) {
                                final fruit = fruitEmojis[index];
                                final fruitId = fruit['id'] as int?;
                                final fruitName = (fruit['display_name'] as String? ?? 
                                                  fruit['name'] as String? ?? 'Unknown').split(' ').first;
                                final isSelected = selectedFruitId == fruitId;
                                
                                return Padding(
                                  padding: EdgeInsets.only(
                                    right: ResponsiveHelper.spacing(context, 12),
                                  ),
                                  child: _buildFruitFilterButton(
                                    context,
                                    fruit,
                                    fruitName,
                                    fruitId,
                                    isSelected,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
          ),
          
          // Stories List
          Expanded(
            child: isLoading && stories.isEmpty
                ? Center(
                    child: CircularProgressIndicator(
                      color: const Color(0xFF8B4513),
                    ),
                  )
                : stories.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.book_outlined,
                              size: ResponsiveHelper.iconSize(context, mobile: 64),
                              color: Colors.grey,
                            ),
                            SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                            Text(
                              'No stories available',
                              style: ResponsiveHelper.textStyle(
                                context,
                                fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _loadStories(refresh: true),
                        color: const Color(0xFF8B4513),
                        child: ListView.builder(
                          padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 16)),
                          itemCount: stories.length,
                          itemBuilder: (context, index) {
                            final story = stories[index];
                            return _buildStoryCard(context, story);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }


  /// Build fruit filter button - Professional Instagram/Facebook Stories Style
  Widget _buildFruitFilterButton(
    BuildContext context,
    Map<String, dynamic>? fruit,
    String label,
    int? fruitId,
    bool isSelected,
  ) {
    return GestureDetector(
      onTap: () {
        print('🖱️ Fruit button tapped: $label (ID: $fruitId)');
        setState(() {
          if (fruitId == null) {
            // "All" selected
            selectedFruitId = null;
            selectedFruitTag = null;
            print('🍎 Selected: All stories');
          } else {
            // Specific fruit selected
            selectedFruitId = fruitId;
            // Extract base fruit name for filtering
            final fruitName = (fruit?['display_name'] as String? ?? 
                              fruit?['name'] as String? ?? 'Unknown').split(' ').first;
            // Capitalize first letter to match database format
            selectedFruitTag = fruitName.isNotEmpty 
                ? fruitName[0].toUpperCase() + (fruitName.length > 1 ? fruitName.substring(1).toLowerCase() : '')
                : fruitName;
            print('🍎 Selected fruit: $selectedFruitTag (ID: $fruitId)');
            print('🍎 Fruit data: ${fruit?['name']}, emoji_char: ${fruit?['emoji_char']}, code: ${fruit?['code']}');
          }
        });
        _loadStories(refresh: true);
      },
      child: Container(
        width: ResponsiveHelper.isMobile(context) ? 70 : ResponsiveHelper.isTablet(context) ? 80 : 90,
        height: ResponsiveHelper.isMobile(context) ? 70 : ResponsiveHelper.isTablet(context) ? 80 : 90,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected 
                ? const Color(0xFF8B4513)
                : Colors.grey.withOpacity(0.3),
            width: isSelected ? 3 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected 
                  ? const Color(0xFF8B4513).withOpacity(0.4)
                  : Colors.black.withOpacity(0.1),
              blurRadius: isSelected ? 10 : 4,
              spreadRadius: isSelected ? 2 : 0,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipOval(
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? const Color(0xFF8B4513).withOpacity(0.1) : Colors.transparent,
            ),
            child: Center(
              child: fruit != null
                  ? HomeScreen.buildEmojiDisplay(
                      context,
                      fruit, // Pass the actual fruit emoji data from fruitEmojis list
                      size: ResponsiveHelper.isMobile(context) ? 45 : ResponsiveHelper.isTablet(context) ? 50 : 55,
                    )
                  : Icon(
                      Icons.apps_rounded,
                      size: ResponsiveHelper.iconSize(context, mobile: 30, tablet: 35, desktop: 40),
                      color: isSelected ? const Color(0xFF8B4513) : Colors.grey[700],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  String _getTimeAgo(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '';
    
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays > 365) {
        final years = (difference.inDays / 365).floor();
        return '$years ${years == 1 ? 'year' : 'years'} ago';
      } else if (difference.inDays > 30) {
        final months = (difference.inDays / 30).floor();
        return '$months ${months == 1 ? 'month' : 'months'} ago';
      } else if (difference.inDays > 0) {
        return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return '';
    }
  }

  Widget _buildStoryCard(BuildContext context, Map<String, dynamic> story) {
    final baseUrl = 'https://fruitofthespirit.templateforwebsites.com/';
    // Handle both stories table (image_url) and gallery photos (file_path/thumbnail_path)
    String? imageUrl;
    if (story['image_url'] != null) {
      final path = story['image_url'] as String;
      imageUrl = path.startsWith('http') ? path : baseUrl + path;
    } else if (story['file_path'] != null) {
      final path = story['file_path'] as String;
      imageUrl = path.startsWith('http') ? path : baseUrl + path;
    } else if (story['thumbnail_path'] != null) {
      final path = story['thumbnail_path'] as String;
      imageUrl = path.startsWith('http') ? path : baseUrl + path;
    }
    
    return Container(
      margin: EdgeInsets.only(bottom: ResponsiveHelper.spacing(context, 16)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          ResponsiveHelper.borderRadius(context, mobile: 16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          // If it's a gallery-based story, navigate to photo details, otherwise story details
          if (story['is_gallery_story'] == true) {
            Get.toNamed(Routes.PHOTO_DETAILS, arguments: story['id']);
          } else {
            Get.toNamed(Routes.STORY_DETAILS, arguments: story['id']);
          }
        },
        borderRadius: BorderRadius.circular(
          ResponsiveHelper.borderRadius(context, mobile: 16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Profile Picture → Time → Name
            Padding(
              padding: ResponsiveHelper.padding(
                context,
                horizontal: 16,
                vertical: 12,
              ),
              child: Row(
                children: [
                  // Profile Picture
                  Container(
                    width: ResponsiveHelper.imageWidth(
                      context,
                      mobile: 48,
                      tablet: 52,
                      desktop: 56,
                    ),
                    height: ResponsiveHelper.imageWidth(
                      context,
                      mobile: 48,
                      tablet: 52,
                      desktop: 56,
                    ),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF8B4513),
                          const Color(0xFF5F4628),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8B4513).withOpacity(0.3),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    padding: ResponsiveHelper.padding(context, all: ResponsiveHelper.isMobile(context) ? 2 : 3),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      padding: ResponsiveHelper.padding(context, all: ResponsiveHelper.isMobile(context) ? 1 : 2),
                      child: ClipOval(
                        child: story['profile_photo'] != null && (story['profile_photo'] as String).isNotEmpty
                            ? CachedImage(
                                imageUrl: story['profile_photo'] as String,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                                errorWidget: Container(
                                  color: Colors.grey[300],
                                  child: Icon(
                                    Icons.person,
                                    size: ResponsiveHelper.iconSize(context, mobile: 24),
                                    color: const Color(0xFF8B4513),
                                  ),
                                ),
                              )
                            : Container(
                                color: Colors.grey[300],
                                child: Icon(
                                  Icons.person,
                                  size: ResponsiveHelper.iconSize(context, mobile: 24),
                                  color: const Color(0xFF8B4513),
                                ),
                              ),
                      ),
                    ),
                  ),
                  SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                  // Time and Name
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Time
                        Text(
                          _getTimeAgo(story['created_at'] as String?),
                          style: ResponsiveHelper.textStyle(
                            context,
                            fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: ResponsiveHelper.spacing(context, 4)),
                        // Name with Story/Testimony Badge
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                story['user_name'] as String? ?? 'Anonymous',
                                style: ResponsiveHelper.textStyle(
                                  context,
                                  fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF5F4628),
                                ),
                              ),
                            ),
                            // Story/Testimony Badge
                            Builder(
                              builder: (context) {
                                // Check if it's a testimony - multiple ways
                                final category = story['category'] as String?;
                                final testimony = story['testimony'] as String?;
                                final title = story['title'] as String?;
                                final content = story['content'] as String?;
                                
                                final isTestimony = (category != null && (category.toLowerCase() == 'testimony' || category.toLowerCase().contains('testimony'))) ||
                                                   (testimony != null && testimony.isNotEmpty) ||
                                                   (title != null && title.toLowerCase().contains('testimony')) ||
                                                   (content != null && content.toLowerCase().contains('testimony'));
                                
                                return Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: ResponsiveHelper.spacing(context, 8),
                                    vertical: ResponsiveHelper.spacing(context, 4),
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: isTestimony
                                        ? LinearGradient(
                                            colors: [
                                              const Color(0xFF9F9467),
                                              const Color(0xFF8B6F47),
                                            ],
                                          )
                                        : LinearGradient(
                                            colors: [
                                              const Color(0xFF8B4513),
                                              const Color(0xFF5F4628),
                                            ],
                                          ),
                                    borderRadius: BorderRadius.circular(
                                      ResponsiveHelper.borderRadius(context, mobile: 12),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isTestimony ? Icons.favorite_rounded : Icons.auto_stories_rounded,
                                        size: ResponsiveHelper.iconSize(context, mobile: 12),
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                                      Text(
                                        isTestimony ? 'Testimony' : 'Story',
                                        style: ResponsiveHelper.textStyle(
                                          context,
                                          fontSize: ResponsiveHelper.fontSize(context, mobile: 11),
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Content
            Padding(
              padding: ResponsiveHelper.padding(
                context,
                horizontal: 16,
                vertical: 8,
              ),
              child: Text(
                story['content'] as String? ?? story['title'] as String? ?? '',
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                  color: Colors.black87,
                  height: 1.5,
                ),
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            
            // Image (if available)
            if (imageUrl != null)
              Padding(
                padding: ResponsiveHelper.padding(
                  context,
                  horizontal: 16,
                  vertical: 8,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    ResponsiveHelper.borderRadius(context, mobile: 12),
                  ),
                  child: Image.network(
                    imageUrl,
                    width: double.infinity,
                    height: ResponsiveHelper.imageHeight(context, mobile: 250, tablet: 300, desktop: 350),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: ResponsiveHelper.imageHeight(context, mobile: 200),
                        color: Colors.grey[200],
                        child: Icon(
                          Icons.broken_image,
                          size: ResponsiveHelper.iconSize(context, mobile: 48),
                          color: Colors.grey[400],
                        ),
                      );
                    },
                  ),
                ),
              ),
            
            // Tags (Fruit tags like Joy, Faithfulness, etc.)
            if (story['fruit_tag'] != null)
              Padding(
                padding: ResponsiveHelper.padding(
                  context,
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Wrap(
                  spacing: ResponsiveHelper.spacing(context, 8),
                  runSpacing: ResponsiveHelper.spacing(context, 8),
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveHelper.spacing(context, 12),
                        vertical: ResponsiveHelper.spacing(context, 6),
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF8B4513).withOpacity(0.15),
                            const Color(0xFF8B4513).withOpacity(0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(
                          ResponsiveHelper.borderRadius(context, mobile: 20),
                        ),
                        border: Border.all(
                          color: const Color(0xFF8B4513).withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.local_fire_department_rounded,
                            size: ResponsiveHelper.iconSize(context, mobile: 16),
                            color: const Color(0xFF8B4513),
                          ),
                          SizedBox(width: ResponsiveHelper.spacing(context, 6)),
                          Text(
                            story['fruit_tag'] as String,
                            style: ResponsiveHelper.textStyle(
                              context,
                              fontSize: ResponsiveHelper.fontSize(context, mobile: 13),
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF8B4513),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            
            // Comments and Likes
            Padding(
              padding: ResponsiveHelper.padding(
                context,
                horizontal: 16,
                vertical: 12,
              ),
              child: Row(
                children: [
                  // Like button
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        // Like functionality
                      },
                      borderRadius: BorderRadius.circular(
                        ResponsiveHelper.borderRadius(context, mobile: 8),
                      ),
                      child: Container(
                        padding: ResponsiveHelper.padding(
                          context,
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(
                            ResponsiveHelper.borderRadius(context, mobile: 8),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.favorite_border_rounded,
                              size: ResponsiveHelper.iconSize(context, mobile: 20),
                              color: Colors.red[700],
                            ),
                            SizedBox(width: ResponsiveHelper.spacing(context, 6)),
                            Text(
                              'Like',
                              style: ResponsiveHelper.textStyle(
                                context,
                                fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                                color: Colors.red[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                  // Comment button
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        if (story['is_gallery_story'] == true) {
                          Get.toNamed(Routes.PHOTO_DETAILS, arguments: story['id']);
                        } else {
                          Get.toNamed(Routes.STORY_DETAILS, arguments: story['id']);
                        }
                      },
                      borderRadius: BorderRadius.circular(
                        ResponsiveHelper.borderRadius(context, mobile: 8),
                      ),
                      child: Container(
                        padding: ResponsiveHelper.padding(
                          context,
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF5F4628).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(
                            ResponsiveHelper.borderRadius(context, mobile: 8),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.comment_outlined,
                              size: ResponsiveHelper.iconSize(context, mobile: 20),
                              color: const Color(0xFF5F4628),
                            ),
                            SizedBox(width: ResponsiveHelper.spacing(context, 6)),
                            Text(
                              'Comment',
                              style: ResponsiveHelper.textStyle(
                                context,
                                fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                                color: const Color(0xFF5F4628),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

