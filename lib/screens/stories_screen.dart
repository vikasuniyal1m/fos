import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/controllers/home_controller.dart';
import 'package:fruitsofspirit/controllers/stories_controller.dart';
import 'package:fruitsofspirit/services/user_storage.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';
import 'package:fruitsofspirit/utils/time_helper.dart';
import 'package:fruitsofspirit/routes/routes.dart';
import 'package:fruitsofspirit/services/api_service.dart';
import 'package:fruitsofspirit/services/emojis_service.dart';
import 'package:fruitsofspirit/widgets/app_bottom_navigation_bar.dart';
import 'package:fruitsofspirit/widgets/cached_image.dart';
import 'package:fruitsofspirit/screens/home_screen.dart';
import 'package:fruitsofspirit/services/payment_gate.dart';

/// Stories Screen
/// Displays list of stories/testimonies
class StoriesScreen extends StatefulWidget {
  const StoriesScreen({Key? key}) : super(key: key);

  @override
  State<StoriesScreen> createState() => _StoriesScreenState();
}

class _StoriesScreenState extends State<StoriesScreen> {
  late final StoriesController _storiesController;
  var userId = 0;
  String? userEmail;

  // Fruit emojis for filtering
  var fruitEmojis = <Map<String, dynamic>>[];
  var isLoadingFruit = true;
  int? selectedFruitId; // Track selected fruit by ID

  @override
  void initState() {
    super.initState();
    _storiesController = Get.isRegistered<StoriesController>()
        ? Get.find<StoriesController>()
        : Get.put(StoriesController());

    if (Get.isRegistered<HomeController>()) {
      _storiesController.seedFromHomeIfEmpty(
        Get.find<HomeController>().stories.toList(),
      );
    }
    _storiesController.loadFromHiveIfEmpty();

    _loadUserId();
    _loadUserEmail();
    _loadFruitEmojis();

    if (_storiesController.stories.isEmpty) {
      _refreshStories();
    } else {
      _refreshStories(refresh: true, silent: true);
    }
  }

  Future<void> _refreshStories({bool refresh = false, bool silent = false}) async {
    try {
      await _storiesController.loadStories(refresh: refresh, silent: silent);
    } catch (e) {
      Get.snackbar(
        'Error',
        e.toString().replaceAll('Exception: ', ''),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _loadUserId() async {
    final id = await UserStorage.getUserId();
    if (id != null) {
      setState(() {
        userId = id;
      });
      _storiesController.userId = id;
    }
  }

  Future<void> _loadUserEmail() async {
    userEmail = await UserStorage.getUserEmail();
  }

  /// Load fruit emojis for filtering (same as fruits_screen)
  Future<void> _loadFruitEmojis() async {
    try {
      setState(() {
        isLoadingFruit = true;
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
      
      // Get unique fruit (one per base fruit name) - prefer variant 1
      final uniqueFruit = <String, Map<String, dynamic>>{};
      for (var emoji in emojis) {
        final name = (emoji['name'] as String? ?? '').trim();
        final code = (emoji['code'] as String? ?? '').toLowerCase();
        final baseName = extractBaseFruitName(name).toLowerCase();
        
        if (baseName.isEmpty) continue;
        
        if (!uniqueFruit.containsKey(baseName)) {
          uniqueFruit[baseName] = emoji;
        } else {
          final currentName = (uniqueFruit[baseName]!['name'] as String? ?? '').toLowerCase();
          final currentCode = (uniqueFruit[baseName]!['code'] as String? ?? '').toLowerCase();
          
          final isNewVariant1 = name.toLowerCase().contains(' 1') || 
                               name.toLowerCase().endsWith(' 1') ||
                               code.endsWith('_01') ||
                               code.contains('_1');
          
          final isCurrentVariant1 = currentName.contains(' 1') || 
                                    currentName.endsWith(' 1') ||
                                    currentCode.endsWith('_01') ||
                                    currentCode.contains('_1');
          
          if (isNewVariant1 && !isCurrentVariant1) {
            uniqueFruit[baseName] = emoji;
          }
        }
      }
      
      // Update display names
      for (var key in uniqueFruit.keys) {
        final emoji = uniqueFruit[key]!;
        final baseName = extractBaseFruitName(emoji['name'] as String? ?? '');
        emoji['display_name'] = baseName;
      }
      
      // Convert to list and deduplicate by ID
      final fruitEmojisList = uniqueFruit.values.toList();
      final seenIds = <int>{};
      final deduplicatedFruit = <Map<String, dynamic>>[];
      
      for (var fruit in fruitEmojisList) {
        final id = fruit['id'] as int?;
        if (id != null && !seenIds.contains(id)) {
          seenIds.add(id);
          deduplicatedFruit.add(fruit);
        }
      }
      
      setState(() {
        fruitEmojis = deduplicatedFruit;
        isLoadingFruit = false;
      });
      
      print('✅ Loaded ${fruitEmojis.length} unique fruit for Stories screen');
    } catch (e) {
      print('❌ Error loading fruit emojis: $e');
      setState(() {
        isLoadingFruit = false;
        fruitEmojis = [];
      });
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
                          onTap: () async => await Get.toNamed(Routes.CREATE_STORY),
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
            child: isLoadingFruit
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
            child: Obx(() {
              final isLoading = _storiesController.isLoading.value;
              final stories = _storiesController.stories;

              if (isLoading && stories.isEmpty) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF8B4513),
                  ),
                );
              }
              if (stories.isEmpty) {
                return Center(
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
                );
              }
              return RefreshIndicator(
                onRefresh: () => _refreshStories(refresh: true),
                color: const Color(0xFF8B4513),
                child: ListView.builder(
                  padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 16)),
                  itemCount: stories.length,
                  itemBuilder: (context, index) {
                    return _buildStoryCard(context, stories[index]);
                  },
                ),
              );
            }),
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
        String? fruitTag;
        setState(() {
          if (fruitId == null) {
            selectedFruitId = null;
            fruitTag = null;
          } else {
            selectedFruitId = fruitId;
            final fruitName = (fruit?['display_name'] as String? ??
                    fruit?['name'] as String? ??
                    'Unknown')
                .split(' ')
                .first;
            fruitTag = fruitName.isNotEmpty
                ? fruitName[0].toUpperCase() +
                    (fruitName.length > 1 ? fruitName.substring(1).toLowerCase() : '')
                : fruitName;
          }
        });
        _storiesController.setFruitTag(fruitTag);
        _refreshStories(refresh: true, silent: _storiesController.stories.isNotEmpty);
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
                      userEmail: userEmail,
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


  Widget _buildStoryCard(BuildContext context, Map<String, dynamic> story) {
    final baseUrl = 'http://admin.fosmessenger.com/';
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
          if (story['is_gallery_story'] == true) {
            PaymentGate.navigateToFeature(Routes.PHOTO_DETAILS, arguments: story['id']);
          } else {
            PaymentGate.navigateToFeature(Routes.STORY_DETAILS, arguments: story['id']);
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
                          TimeHelper.getTimeAgo(story['created_at'] as String?),
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
                          PaymentGate.navigateToFeature(Routes.PHOTO_DETAILS, arguments: story['id']);
                        } else {
                          PaymentGate.navigateToFeature(Routes.STORY_DETAILS, arguments: story['id']);
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

