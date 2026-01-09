import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/services/advanced_service.dart';
import 'package:fruitsofspirit/services/user_storage.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';
import 'package:fruitsofspirit/routes/routes.dart';
import 'package:fruitsofspirit/services/api_service.dart';

/// Saved Content Screen
class SavedContentScreen extends StatefulWidget {
  const SavedContentScreen({Key? key}) : super(key: key);

  @override
  State<SavedContentScreen> createState() => _SavedContentScreenState();
}

class _SavedContentScreenState extends State<SavedContentScreen> {
  var isLoading = false;
  var savedContent = <Map<String, dynamic>>[];
  var userId = 0;
  String selectedType = 'all';

  @override
  void initState() {
    super.initState();
    _loadUserId();
    _loadSavedContent();
  }

  Future<void> _loadUserId() async {
    final id = await UserStorage.getUserId();
    if (id != null) {
      setState(() {
        userId = id;
      });
    }
  }

  Future<void> _loadSavedContent() async {
    if (userId == 0) {
      await _loadUserId();
    }

    if (userId == 0) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final content = await AdvancedService.getSavedContent(
        userId: userId,
        contentType: selectedType,
      );
      setState(() {
        savedContent = content;
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
            'Saved Content',
            style: ResponsiveHelper.textStyle(
              context,
              fontSize: ResponsiveHelper.fontSize(context, mobile: 20, tablet: 24, desktop: 28),
              fontWeight: FontWeight.bold,
              color: const Color(0xFF8B4513),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Type Filter
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveHelper.spacing(context, 16),
              vertical: ResponsiveHelper.spacing(context, 8),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(context, 'All', 'all'),
                  SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                  _buildFilterChip(context, 'Blogs', 'blog'),
                  SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                  _buildFilterChip(context, 'Prayers', 'prayer'),
                  SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                  _buildFilterChip(context, 'Videos', 'video'),
                  SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                  _buildFilterChip(context, 'Photos', 'photo'),
                  SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                  _buildFilterChip(context, 'Stories', 'story'),
                ],
              ),
            ),
          ),
          
          // Content List
          Expanded(
            child: isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: const Color(0xFF8B4513),
                    ),
                  )
                : savedContent.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.bookmark_border,
                              size: ResponsiveHelper.iconSize(context, mobile: 64),
                              color: Colors.grey,
                            ),
                            SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                            Text(
                              'No saved content',
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
                        onRefresh: _loadSavedContent,
                        color: const Color(0xFF8B4513),
                        child: ListView.builder(
                          padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 16)),
                          itemCount: savedContent.length,
                          itemBuilder: (context, index) {
                            final content = savedContent[index];
                            return _buildContentCard(context, content);
                          },
                        ),
                      ),
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
        setState(() {
          selectedType = type;
        });
        _loadSavedContent();
      },
      selectedColor: const Color(0xFFE3F2FD),
      checkmarkColor: const Color(0xFF8B4513),
      labelStyle: ResponsiveHelper.textStyle(
        context,
        fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
        color: isSelected ? const Color(0xFF8B4513) : Colors.black,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildContentCard(BuildContext context, Map<String, dynamic> content) {
    final contentType = content['content_type'] as String? ?? 'unknown';
    final contentId = content['content_id'] as int? ?? 0;
    
    VoidCallback? onTap;
    String route = '';
    
    switch (contentType) {
      case 'blog':
        onTap = () => Get.toNamed(Routes.BLOG_DETAILS, arguments: contentId);
        break;
      case 'prayer':
        onTap = () => Get.toNamed(Routes.PRAYER_DETAILS, arguments: contentId);
        break;
      case 'video':
        onTap = () => Get.toNamed(Routes.VIDEO_DETAILS, arguments: contentId);
        break;
      case 'photo':
        onTap = () => Get.toNamed(Routes.PHOTO_DETAILS, arguments: contentId);
        break;
      case 'story':
        onTap = () => Get.toNamed(Routes.STORY_DETAILS, arguments: contentId);
        break;
    }

    return Card(
      margin: EdgeInsets.only(bottom: ResponsiveHelper.spacing(context, 12)),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          ResponsiveHelper.borderRadius(context, mobile: 12),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(
          ResponsiveHelper.borderRadius(context, mobile: 12),
        ),
        child: Padding(
          padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 16)),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 8)),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(
                    ResponsiveHelper.borderRadius(context, mobile: 8),
                  ),
                ),
                child: Icon(
                  contentType == 'blog'
                      ? Icons.article
                      : contentType == 'prayer'
                          ? Icons.favorite
                          : contentType == 'video'
                              ? Icons.video_library
                              : contentType == 'photo'
                                  ? Icons.image
                                  : Icons.book,
                  color: const Color(0xFF8B4513),
                  size: ResponsiveHelper.iconSize(context, mobile: 24),
                ),
              ),
              SizedBox(width: ResponsiveHelper.spacing(context, 12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      content['title'] as String? ?? content['content'] as String? ?? 'Saved Item',
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF8B4513),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(context, 4)),
                    Text(
                      contentType.toUpperCase(),
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.bookmark, color: Color(0xFF8B4513)),
                onPressed: () async {
                  try {
                    await AdvancedService.unsaveContent(
                      userId: userId,
                      contentType: contentType,
                      contentId: contentId,
                    );
                    await _loadSavedContent();
                    Get.snackbar(
                      'Success',
                      'Content unsaved',
                      backgroundColor: Colors.green,
                      colorText: Colors.white,
                    );
                  } catch (e) {
                    Get.snackbar(
                      'Error',
                      e.toString().replaceAll('Exception: ', ''),
                      backgroundColor: Colors.red,
                      colorText: Colors.white,
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

