import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/services/fruits_service.dart';
import 'package:fruitsofspirit/services/stories_service.dart';
import 'package:fruitsofspirit/services/videos_service.dart';
import 'package:fruitsofspirit/services/gallery_service.dart';
import 'package:fruitsofspirit/services/emojis_service.dart';
import 'package:fruitsofspirit/services/user_storage.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';
import 'package:fruitsofspirit/routes/routes.dart';
import 'package:fruitsofspirit/services/api_service.dart';
import 'package:fruitsofspirit/widgets/cached_image.dart';
import 'package:fruitsofspirit/config/image_config.dart';
import 'package:fruitsofspirit/screens/home_screen.dart';

/// Fruit Details Screen
/// Shows stories, videos, photos related to a specific fruit
class FruitDetailsScreen extends StatefulWidget {
  const FruitDetailsScreen({Key? key}) : super(key: key);

  @override
  State<FruitDetailsScreen> createState() => _FruitDetailsScreenState();
}

class _FruitDetailsScreenState extends State<FruitDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  var isLoading = false;
  var fruit = <String, dynamic>{};
  var stories = <Map<String, dynamic>>[];
  var videos = <Map<String, dynamic>>[];
  var photos = <Map<String, dynamic>>[];
  var oppositeEmojis = <Map<String, dynamic>>[];
  var emotionEmojis = <Map<String, dynamic>>[];
  var userId = 0;
  String? fruitName;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this); // Updated to 5 tabs
    _loadUserId();
    _loadFruitDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserId() async {
    final id = await UserStorage.getUserId();
    if (id != null) {
      setState(() {
        userId = id;
      });
    }
  }

  Future<void> _loadFruitDetails() async {
    final fruitData = Get.arguments;
    if (fruitData == null) {
      Get.back();
      return;
    }

    setState(() {
      fruit = fruitData is Map<String, dynamic> ? fruitData : {'name': fruitData.toString()};
      fruitName = fruit['name'] as String?;
      isLoading = true;
    });

    try {
      // Load stories, videos, photos, and opposites/emotions for this fruit
      await Future.wait([
        _loadStories(),
        _loadVideos(),
        _loadPhotos(),
        _loadOppositeEmojis(),
        _loadEmotionEmojis(),
      ]);

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      Get.snackbar(
        'Error',
        e.toString().replaceAll('Exception: ', ''),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _loadStories() async {
    try {
      final storiesList = await StoriesService.getStories(
        status: 'Approved',
        fruitTag: fruitName,
        limit: 50,
      );
      setState(() {
        stories = storiesList;
      });
    } catch (e) {
      print('Error loading stories: $e');
    }
  }

  Future<void> _loadVideos() async {
    try {
      final videosList = await VideosService.getVideos(
        fruitTag: fruitName,
        limit: 50,
      );
      setState(() {
        videos = videosList;
      });
    } catch (e) {
      print('Error loading videos: $e');
    }
  }

  Future<void> _loadPhotos() async {
    try {
      final photosList = await GalleryService.getPhotos(
        fruitTag: fruitName,
        limit: 50,
      );
      setState(() {
        photos = photosList;
      });
    } catch (e) {
      print('Error loading photos: $e');
    }
  }

  Future<void> _loadOppositeEmojis() async {
    try {
      // Load opposites for this fruit (e.g., "Lacking Love" for "Love")
      final opposites = await EmojisService.getEmojis(
        status: 'Active',
        category: 'Opposite Emotion',
        limit: 50,
      );
      
      // Filter opposites related to current fruit
      final fruitOpposites = opposites.where((emoji) {
        final name = (emoji['name'] as String? ?? '').toLowerCase();
        final fruitLower = (fruitName ?? '').toLowerCase();
        
        // Map fruit to its opposites
        final oppositeMap = {
          'love': ['lacking love', 'feeling unloved'],
          'joy': ['lacking joy', 'sadness'],
          'peace': ['struggling with peace', 'anxiety'],
          'patience': ['impatient', 'restless'],
          'kindness': ['unkind', 'harsh'],
          'goodness': ['lacking goodness'],
          'faithfulness': ['unfaithful', 'doubt'],
          'gentleness': ['proud', 'arrogant'],
          'meekness': ['proud', 'arrogant'],
          'self-control': ['lacking self-control', 'tempted'],
        };
        
        final oppositesForFruit = oppositeMap[fruitLower] ?? [];
        return oppositesForFruit.any((opposite) => name.contains(opposite));
      }).toList();
      
      setState(() {
        oppositeEmojis = fruitOpposites;
      });
    } catch (e) {
      print('Error loading opposite emojis: $e');
    }
  }

  Future<void> _loadEmotionEmojis() async {
    try {
      // Load emotion-based emojis (Thankful, Grateful, etc.)
      final emotions = await EmojisService.getEmojis(
        status: 'Active',
        category: 'Spiritual Emotion',
        limit: 50,
      );
      
      setState(() {
        emotionEmojis = emotions;
      });
    } catch (e) {
      print('Error loading emotion emojis: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5DC),
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(
          ResponsiveHelper.appBarHeight(context),
        ),
        child: AppBar(
          backgroundColor: const Color(0xFFF5F5DC),
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: const Color(0xFF8B4513),
              size: ResponsiveHelper.iconSize(context, mobile: 24, tablet: 28, desktop: 32),
            ),
            onPressed: () => Get.back(),
          ),
          title: Text(
            fruitName ?? 'Fruit Details',
            style: ResponsiveHelper.textStyle(
              context,
              fontSize: ResponsiveHelper.fontSize(context, mobile: 20, tablet: 24, desktop: 28),
              fontWeight: FontWeight.bold,
              color: const Color(0xFF8B4513),
            ),
          ),
          bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF8B4513),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF8B4513),
          isScrollable: true,
          tabs: const [
            Tab(text: 'Stories'),
            Tab(text: 'Videos'),
            Tab(text: 'Photos'),
            Tab(text: 'Opposites'),
            Tab(text: 'Emotions'),
          ],
        ),
        ),
      ),
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: const Color(0xFF8B4513),
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildStoriesTab(),
                _buildVideosTab(),
                _buildPhotosTab(),
                _buildOppositesTab(),
                _buildEmotionsTab(),
              ],
            ),
    );
  }

  Widget _buildStoriesTab() {
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
              'No stories available for ${fruitName ?? "this fruit"}',
              style: ResponsiveHelper.textStyle(
                context,
                fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 16)),
            ElevatedButton(
              onPressed: () => Get.toNamed(Routes.CREATE_STORY),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B4513),
              ),
              child: const Text('Share Your Story'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadStories,
      color: const Color(0xFF8B4513),
      child: ListView.builder(
        padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 16)),
        itemCount: stories.length,
        itemBuilder: (context, index) {
          final story = stories[index];
          return _buildStoryCard(context, story);
        },
      ),
    );
  }

  Widget _buildVideosTab() {
    if (videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.video_library_outlined,
              size: ResponsiveHelper.iconSize(context, mobile: 64),
              color: Colors.grey,
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 16)),
            Text(
              'No videos available for ${fruitName ?? "this fruit"}',
              style: ResponsiveHelper.textStyle(
                context,
                fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadVideos,
      color: const Color(0xFF8B4513),
      child: GridView.builder(
        padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 16)),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: ResponsiveHelper.isTablet(context) ? 3 : 2,
          crossAxisSpacing: ResponsiveHelper.spacing(context, 12),
          mainAxisSpacing: ResponsiveHelper.spacing(context, 12),
          childAspectRatio: 0.75,
        ),
        itemCount: videos.length,
        itemBuilder: (context, index) {
          final video = videos[index];
          return _buildVideoCard(context, video);
        },
      ),
    );
  }

  Widget _buildPhotosTab() {
    if (photos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: ResponsiveHelper.iconSize(context, mobile: 64),
              color: Colors.grey,
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 16)),
            Text(
              'No photos available for ${fruitName ?? "this fruit"}',
              style: ResponsiveHelper.textStyle(
                context,
                fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPhotos,
      color: const Color(0xFF8B4513),
      child: GridView.builder(
        padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 16)),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: ResponsiveHelper.isTablet(context) ? 3 : 2,
          crossAxisSpacing: ResponsiveHelper.spacing(context, 12),
          mainAxisSpacing: ResponsiveHelper.spacing(context, 12),
          childAspectRatio: 1,
        ),
        itemCount: photos.length,
        itemBuilder: (context, index) {
          final photo = photos[index];
          return _buildPhotoCard(context, photo);
        },
      ),
    );
  }

  Widget _buildStoryCard(BuildContext context, Map<String, dynamic> story) {
    final baseUrl = 'https://fruitofthespirit.templateforwebsites.com/';
    final imageUrl = story['image'] != null ? baseUrl + (story['image'] as String) : null;
    
    return Card(
      margin: EdgeInsets.only(bottom: ResponsiveHelper.spacing(context, 12)),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          ResponsiveHelper.borderRadius(context, mobile: 16),
        ),
      ),
      child: InkWell(
        onTap: () => Get.toNamed(Routes.STORY_DETAILS, arguments: story['id']),
        borderRadius: BorderRadius.circular(
          ResponsiveHelper.borderRadius(context, mobile: 16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
                ),
                child: CachedImage(
                  imageUrl: imageUrl,
                  height: ResponsiveHelper.imageHeight(context, mobile: 180),
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            Padding(
              padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    story['title'] as String? ?? 'Untitled Story',
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: ResponsiveHelper.fontSize(context, mobile: 18),
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF8B4513),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(context, 8)),
                  Text(
                    story['content'] as String? ?? '',
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                      color: Colors.black87,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(context, 12)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: ResponsiveHelper.borderRadius(context, mobile: 12),
                            backgroundColor: const Color(0xFFFEECE2),
                            child: Icon(
                              Icons.person,
                              size: ResponsiveHelper.iconSize(context, mobile: 16),
                              color: const Color(0xFF8B4513),
                            ),
                          ),
                          SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                          Text(
                            story['user_name'] as String? ?? 'Anonymous',
                            style: ResponsiveHelper.textStyle(
                              context,
                              fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.favorite_outline,
                            size: ResponsiveHelper.iconSize(context, mobile: 16),
                            color: Colors.grey,
                          ),
                          SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                          Text(
                            '${story['like_count'] ?? 0}',
                            style: ResponsiveHelper.textStyle(
                              context,
                              fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                              color: Colors.grey,
                            ),
                          ),
                        ],
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
  }

  Widget _buildVideoCard(BuildContext context, Map<String, dynamic> video) {
    final baseUrl = 'https://fruitofthespirit.templateforwebsites.com/';
    final thumbnailUrl = video['thumbnail_url'] != null 
        ? baseUrl + (video['thumbnail_url'] as String)
        : null;
    
    return GestureDetector(
      onTap: () => Get.toNamed(Routes.VIDEO_DETAILS, arguments: video['id']),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(
            ResponsiveHelper.borderRadius(context, mobile: 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.15),
              spreadRadius: 1,
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
              ),
              child: Stack(
                children: [
                  thumbnailUrl != null
                      ? CachedImage(
                          imageUrl: thumbnailUrl,
                          height: ResponsiveHelper.imageHeight(context, mobile: 120),
                          width: double.infinity,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          height: ResponsiveHelper.imageHeight(context, mobile: 120),
                          color: Colors.grey[300],
                          child: Icon(
                            Icons.video_library,
                            size: ResponsiveHelper.iconSize(context, mobile: 40),
                            color: Colors.grey,
                          ),
                        ),
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 8)),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: ResponsiveHelper.iconSize(context, mobile: 32),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video['title'] as String? ?? 'Untitled Video',
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF8B4513),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(context, 4)),
                  Text(
                    video['user_name'] as String? ?? 'Anonymous',
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                      color: Colors.grey,
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

  Widget _buildPhotoCard(BuildContext context, Map<String, dynamic> photo) {
    final baseUrl = 'https://fruitofthespirit.templateforwebsites.com/';
    final thumbnailPath = photo['thumbnail_path'] as String?;
    final filePath = photo['file_path'] as String? ?? '';
    final imageUrl = thumbnailPath != null 
        ? baseUrl + thumbnailPath 
        : (filePath.isNotEmpty ? baseUrl + filePath : null);
    
    return GestureDetector(
      onTap: () => Get.toNamed(Routes.PHOTO_DETAILS, arguments: photo['id']),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(
            ResponsiveHelper.borderRadius(context, mobile: 12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(
            ResponsiveHelper.borderRadius(context, mobile: 12),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              imageUrl != null
                  ? CachedImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: Colors.grey[300],
                      child: Icon(
                        Icons.image,
                        size: ResponsiveHelper.iconSize(context, mobile: 32),
                        color: Colors.grey,
                      ),
                    ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 4)),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.favorite_outline,
                        size: ResponsiveHelper.iconSize(context, mobile: 12),
                        color: Colors.white,
                      ),
                      SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                      Text(
                        '${photo['like_count'] ?? 0}',
                        style: ResponsiveHelper.textStyle(
                          context,
                          fontSize: ResponsiveHelper.fontSize(context, mobile: 10),
                          color: Colors.white,
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
    );
  }

  Widget _buildOppositesTab() {
    if (oppositeEmojis.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sentiment_dissatisfied_outlined,
              size: ResponsiveHelper.iconSize(context, mobile: 64),
              color: Colors.grey,
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 16)),
            Text(
              'No opposite emotions available',
              style: ResponsiveHelper.textStyle(
                context,
                fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 8)),
            Text(
              'These represent struggles with ${fruitName ?? "this fruit"}',
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

    return RefreshIndicator(
      onRefresh: _loadOppositeEmojis,
      color: const Color(0xFF8B4513),
      child: ListView.builder(
        padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 16)),
        itemCount: oppositeEmojis.length,
        itemBuilder: (context, index) {
          final emoji = oppositeEmojis[index];
          return _buildEmojiCard(context, emoji, isOpposite: true);
        },
      ),
    );
  }

  Widget _buildEmotionsTab() {
    if (emotionEmojis.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_outline,
              size: ResponsiveHelper.iconSize(context, mobile: 64),
              color: Colors.grey,
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 16)),
            Text(
              'No spiritual emotions available',
              style: ResponsiveHelper.textStyle(
                context,
                fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 8)),
            Text(
              'Express your spiritual emotions',
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

    return RefreshIndicator(
      onRefresh: _loadEmotionEmojis,
      color: const Color(0xFF8B4513),
      child: GridView.builder(
        padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 16)),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: ResponsiveHelper.isTablet(context) ? 3 : 2,
          crossAxisSpacing: ResponsiveHelper.spacing(context, 12),
          mainAxisSpacing: ResponsiveHelper.spacing(context, 12),
          childAspectRatio: 0.85,
        ),
        itemCount: emotionEmojis.length,
        itemBuilder: (context, index) {
          final emoji = emotionEmojis[index];
          return _buildEmojiCard(context, emoji, isOpposite: false);
        },
      ),
    );
  }

  Widget _buildEmojiCard(BuildContext context, Map<String, dynamic> emoji, {required bool isOpposite}) {
    return Card(
      margin: EdgeInsets.only(bottom: ResponsiveHelper.spacing(context, 12)),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          ResponsiveHelper.borderRadius(context, mobile: 16),
        ),
      ),
      child: InkWell(
        onTap: () async {
          // Record emoji usage
          try {
            if (userId > 0) {
              final emojiChar = emoji['emoji_char'] ?? emoji['code'];
              await EmojisService.useEmoji(
                userId: userId,
                emoji: emojiChar.toString(),
              );
              Get.snackbar(
                'Recorded',
                'Your feeling has been recorded',
                backgroundColor: Colors.green,
                colorText: Colors.white,
                duration: const Duration(seconds: 2),
              );
            } else {
              Get.snackbar(
                'Login Required',
                'Please login to record your feeling',
                backgroundColor: Colors.orange,
                colorText: Colors.white,
              );
            }
          } catch (e) {
            print('Error recording emoji: $e');
          }
        },
        borderRadius: BorderRadius.circular(
          ResponsiveHelper.borderRadius(context, mobile: 16),
        ),
        child: Padding(
          padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 16)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Emoji Image
              Container(
                width: ResponsiveHelper.iconSize(context, mobile: 60),
                height: ResponsiveHelper.iconSize(context, mobile: 60),
                decoration: BoxDecoration(
                  color: isOpposite ? Colors.orange[50] : Colors.green[50],
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isOpposite ? Colors.orange[300]! : Colors.green[300]!,
                    width: 2,
                  ),
                ),
                child: ClipOval(
                  child: HomeScreen.buildEmojiDisplay(
                    context,
                    emoji,
                    size: ResponsiveHelper.iconSize(context, mobile: 50),
                  ),
                ),
              ),
              SizedBox(height: ResponsiveHelper.spacing(context, 8)),
              // Emoji Name
              Text(
                emoji['name'] as String? ?? 'Unknown',
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF8B4513),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (emoji['description'] != null) ...[
                SizedBox(height: ResponsiveHelper.spacing(context, 4)),
                Text(
                  emoji['description'] as String,
                  style: ResponsiveHelper.textStyle(
                    context,
                    fontSize: ResponsiveHelper.fontSize(context, mobile: 11),
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

