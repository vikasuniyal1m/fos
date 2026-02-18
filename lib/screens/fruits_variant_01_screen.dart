import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/controllers/fruits_controller.dart';
import 'package:fruitsofspirit/controllers/home_controller.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';
import 'package:fruitsofspirit/widgets/cached_image.dart';
import 'package:fruitsofspirit/config/image_config.dart';
import 'package:fruitsofspirit/widgets/app_bottom_navigation_bar.dart';
import 'package:fruitsofspirit/services/emojis_service.dart';
import 'package:fruitsofspirit/services/user_storage.dart';
import 'package:fruitsofspirit/screens/home_screen.dart';

/// Fruits Variant 01 Screen
/// Displays only fruits with _01 in their code, shown prominently on the front
class FruitsVariant01Screen extends StatefulWidget {
  const FruitsVariant01Screen({Key? key}) : super(key: key);

  @override
  State<FruitsVariant01Screen> createState() => _FruitsVariant01ScreenState();
}

class _FruitsVariant01ScreenState extends State<FruitsVariant01Screen> {
  final controller = Get.find<FruitsController>();
  final homeController = Get.find<HomeController>();
  var fruitEmojis01 = <Map<String, dynamic>>[];
  var isLoadingEmojis = true;

  @override
  void initState() {
    super.initState();
    _loadFruitEmojis01();
  }

  Future<void> _loadFruitEmojis01() async {
    try {
      // Load emojis from folder
      var emojis = await EmojisService.getEmojis(
        status: 'Active',
        category: 'Fruits',
        sortBy: 'image_url',
        order: 'ASC',
      );
      
      // Filter out opposite/negative fruits - only show positive fruits
      emojis = emojis.where((emoji) {
        final category = (emoji['category'] as String? ?? '').toLowerCase();
        // Exclude opposite emotions, only include positive fruits
        return !category.contains('opposite') && category.contains('fruit of spirit');
      }).toList();
      
      // Filter to only show _01 variants - strict check
      emojis = emojis.where((emoji) {
        final code = (emoji['code'] as String? ?? '').toLowerCase();
        // Only include if code ends with _01 (e.g., joy_01, peace_01, self_control_01)
        return code.endsWith('_01');
      }).toList();
      
      // Get unique fruits (one per fruit name) - only _01 variants
      final uniqueFruits = <String, Map<String, dynamic>>{};
      for (var emoji in emojis) {
        final name = (emoji['name'] as String? ?? '').toLowerCase();
        final code = (emoji['code'] as String? ?? '').toLowerCase();
        // Only add if it's a _01 variant and we don't have this fruit yet
        if (code.endsWith('_01') && !uniqueFruits.containsKey(name)) {
          uniqueFruits[name] = emoji;
        }
      }
      
      emojis = uniqueFruits.values.toList();
      
      print('✅ Loaded ${emojis.length} unique _01 variant fruits');
      for (var fruit in emojis) {
        print('   - ${fruit['name']}: ${fruit['code']}');
      }
      
      // If no fruits found, create temporary fruit emojis with _01 variants
      if (emojis.isEmpty) {
        print('⚠️ No _01 fruit emojis found in database, creating temporary ones...');
        emojis = _createTemporaryFruitEmojis01();
      }
      
      setState(() {
        fruitEmojis01 = emojis;
        isLoadingEmojis = false;
      });
    } catch (e) {
      print('Error loading fruit emojis _01: $e');
      // Create temporary emojis even on error
      final tempEmojis = _createTemporaryFruitEmojis01();
      setState(() {
        fruitEmojis01 = tempEmojis;
        isLoadingEmojis = false;
      });
    }
  }

  List<Map<String, dynamic>> _createTemporaryFruitEmojis01() {
    final baseUrl = 'https://fruitofthespirit.templateforwebsites.com/';
    final fruitsBaseUrl = '${baseUrl}uploads/fruitofspirit/';
    
    // ONLY _01 variants from uploads/fruitofspirit/ folder
    final fruitMappings = <Map<String, String>>[
      {'name': 'Joy', 'emoji_char': '😊', 'code': 'joy_01', 'image': '${fruitsBaseUrl}pineapple-01.png', 'description': 'Pineapple represents joy.'},
      {'name': 'Peace', 'emoji_char': '☮️', 'code': 'peace_01', 'image': '${fruitsBaseUrl}watermelon-01.png', 'description': 'Watermelon symbolizes peace.'},
      {'name': 'Patience', 'emoji_char': '⏳', 'code': 'patience_01', 'image': '${fruitsBaseUrl}pa-01.png', 'description': 'Patience fruit image.'},
      {'name': 'Kindness', 'emoji_char': '🤗', 'code': 'kindness_01', 'image': '${fruitsBaseUrl}Orange-01.png', 'description': 'Orange embodies kindness.'},
      {'name': 'Goodness', 'emoji_char': '✨', 'code': 'goodness_01', 'image': '${fruitsBaseUrl}ad-01.png', 'description': 'Goodness fruit image.'},
      {'name': 'Faithfulness', 'emoji_char': '🙏', 'code': 'faithfulness_01', 'image': '${fruitsBaseUrl}banana-01.png', 'description': 'Banana represents faithfulness.'},
      {'name': 'Gentleness', 'emoji_char': '🕊️', 'code': 'gentleness_01', 'image': '${fruitsBaseUrl}Graps -01.png', 'description': 'Grapes denote gentleness.'},
      {'name': 'Self-Control', 'emoji_char': '🎯', 'code': 'self_control_01', 'image': '${fruitsBaseUrl}Green-apple-01.png', 'description': 'Green Apple signifies self-control.'},
    ];
    
    // Convert to emoji format
    return fruitMappings.map((fruit) {
      return {
        'id': fruitMappings.indexOf(fruit) + 1,
        'name': fruit['name']!,
        'emoji_char': fruit['emoji_char']!,
        'code': fruit['code']!,
        'image_url': fruit['image']!,
        'description': fruit['description']!,
        'category': 'Fruit of Spirit',
        'usage_count': 0,
        'status': 'Active',
        'created_at': DateTime.now().toIso8601String(),
      };
    }).toList();
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
                      child: CachedImage(
                        imageUrl: ImageConfig.logo,
                        width: double.infinity,
                        height: ResponsiveHelper.isMobile(context)
                            ? 52.0
                            : ResponsiveHelper.isTablet(context)
                                ? 58.0
                                : 64.0,
                        fit: BoxFit.contain,
                        errorWidget: Text(
                          'Fruits _01',
                          style: ResponsiveHelper.textStyle(
                            context,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF5F4628),
                          ),
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
                  // Right Side - Back Button
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
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await controller.refresh();
          await _loadFruitEmojis01();
        },
        color: const Color(0xFF8B4513),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: ResponsiveHelper.spacing(context, 20)),
              
              // Header Section
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveHelper.spacing(context, 16),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 8)),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF8B4513),
                            const Color(0xFF5F4628),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                      ),
                      child: Icon(
                        Icons.star,
                        color: Colors.white,
                        size: ResponsiveHelper.iconSize(context, mobile: 24, tablet: 28, desktop: 32),
                      ),
                    ),
                    SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fruits Variant _01',
                            style: ResponsiveHelper.textStyle(
                              context,
                              fontSize: ResponsiveHelper.fontSize(context, mobile: 20, tablet: 22, desktop: 24),
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF8B4513),
                            ),
                          ),
                          SizedBox(height: ResponsiveHelper.spacing(context, 4)),
                          Text(
                            'First variant of each fruit',
                            style: ResponsiveHelper.textStyle(
                              context,
                              fontSize: ResponsiveHelper.fontSize(context, mobile: 12, tablet: 13, desktop: 14),
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: ResponsiveHelper.spacing(context, 24)),
              
              // Fruits Grid - Only _01 variants displayed prominently
              if (isLoadingEmojis)
                Padding(
                  padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 40)),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: const Color(0xFF8B4513),
                    ),
                  ),
                )
              else if (fruitEmojis01.isEmpty)
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
                          'No _01 variant fruits available',
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
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveHelper.spacing(context, 16),
                  ),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: ResponsiveHelper.isDesktop(context) ? 3 : 2,
                      crossAxisSpacing: ResponsiveHelper.spacing(context, 16),
                      mainAxisSpacing: ResponsiveHelper.spacing(context, 20),
                      childAspectRatio: 1.0,
                    ),
                    itemCount: fruitEmojis01.length,
                    itemBuilder: (context, index) {
                      final fruitEmoji = fruitEmojis01[index];
                      final fruitName = fruitEmoji['name'] as String? ?? 'Unknown';
                      
                      return _buildFruitCard01(context, fruitEmoji, fruitName);
                    },
                  ),
                ),
              
              SizedBox(height: ResponsiveHelper.spacing(context, 20)),
            ],
          ),
        ),
      ),
    );
  }

  /// Build individual fruit card for _01 variants - Prominent Display
  Widget _buildFruitCard01(BuildContext context, Map<String, dynamic> fruitEmoji, String fruitName) {
    // Calculate responsive image size based on screen width and grid spacing
    final screenWidth = ResponsiveHelper.screenWidth(context);
    final horizontalPadding = ResponsiveHelper.spacing(context, 16) * 2;
    final gridSpacing = ResponsiveHelper.isDesktop(context) 
        ? ResponsiveHelper.spacing(context, 16) * 2
        : ResponsiveHelper.spacing(context, 16);
    final crossAxisCount = ResponsiveHelper.isDesktop(context) ? 3 : 2;
    
    final availableWidth = screenWidth - horizontalPadding - gridSpacing;
    final cardSize = availableWidth / crossAxisCount;
    
    final double imageSize = cardSize * 0.70;
    final double padding = ResponsiveHelper.spacing(context, 10);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // Show fruit details or variant dialog
          Get.snackbar(
            fruitName,
            'Variant _01 selected',
            backgroundColor: const Color(0xFF8B4513),
            colorText: Colors.white,
          );
        },
        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 20, tablet: 24, desktop: 28)),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 20, tablet: 24, desktop: 28)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B4513).withOpacity(0.12),
                blurRadius: 18,
                spreadRadius: 2,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                spreadRadius: 0,
                offset: const Offset(0, 3),
              ),
            ],
            border: Border.all(
              color: const Color(0xFF8B4513).withOpacity(0.18),
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Fruit Image - Large and Prominent
                Expanded(
                  flex: 4,
                  child: Center(
                    child: Container(
                      width: imageSize,
                      height: imageSize,
                      constraints: BoxConstraints(
                        maxWidth: imageSize,
                        maxHeight: imageSize,
                      ),
                      child: HomeScreen.buildEmojiDisplay(
                        context,
                        fruitEmoji,
                        size: imageSize,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, 6)),
                // Fruit Name
                Expanded(
                  flex: 1,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          fruitName,
                          style: ResponsiveHelper.textStyle(
                            context,
                            fontSize: ResponsiveHelper.fontSize(context, mobile: 13, tablet: 15, desktop: 17),
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF8B4513),
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: ResponsiveHelper.spacing(context, 2)),
                        // Show _01 badge
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: ResponsiveHelper.spacing(context, 6),
                            vertical: ResponsiveHelper.spacing(context, 2),
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B4513).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
                          ),
                          child: Text(
                            '_01',
                            style: ResponsiveHelper.textStyle(
                              context,
                              fontSize: ResponsiveHelper.fontSize(context, mobile: 10, tablet: 11, desktop: 12),
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF8B4513),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

