import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/controllers/prayers_controller.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';
import 'package:fruitsofspirit/utils/auto_translate_helper.dart';
import 'package:fruitsofspirit/utils/image_helper.dart';
import 'package:fruitsofspirit/widgets/cached_image.dart';
import 'package:fruitsofspirit/config/image_config.dart';
import 'package:fruitsofspirit/services/user_storage.dart';
import 'package:fruitsofspirit/screens/home_screen.dart';
import 'package:fruitsofspirit/widgets/standard_app_bar.dart';
import 'package:fruitsofspirit/utils/app_theme.dart';
import 'package:fruitsofspirit/utils/fruit_emoji_helper.dart';

/// Prayer Details Screen
/// Professional, user-friendly design with attractive UI and Facebook-like comment threads
class PrayerDetailsScreen extends StatefulWidget {
  const PrayerDetailsScreen({Key? key}) : super(key: key);

  @override
  State<PrayerDetailsScreen> createState() => _PrayerDetailsScreenState();
}

class _PrayerDetailsScreenState extends State<PrayerDetailsScreen> {
  final PrayersController controller = Get.find<PrayersController>();
  final replyControllers = <int, TextEditingController>{};
  final showReplyInput = <int, bool>{};
  final expandedReplies = <int>{}; // Track which replies are expanded
  final commentController = TextEditingController();
  int? currentUserId;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId();
  }

  Future<void> _loadCurrentUserId() async {
    final user = await UserStorage.getUser();
    if (user != null) {
      setState(() {
        currentUserId = user['id'] as int?;
      });
    }
  }

  @override
  void dispose() {
    commentController.dispose();
    for (var controller in replyControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Format time ago
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

  /// Get prayer type color
  Color _getPrayerTypeColor(String? category) {
    switch (category) {
      case 'Healing':
        return const Color(0xFF4CAF50);
      case 'Peace & Anxiety':
        return const Color(0xFF2196F3);
      case 'Work & Provision':
        return const Color(0xFFFF9800);
      case 'Relationships':
        return const Color(0xFFE91E63);
      case 'Guidance':
        return const Color(0xFF9C27B0);
      default:
        return const Color(0xFF8B4513);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prayerId = Get.arguments as int? ?? 0;
    
    // Load prayer details if not already loaded
    if (prayerId > 0 && (controller.selectedPrayer.isEmpty || controller.selectedPrayer['id'] != prayerId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.loadPrayerDetails(prayerId);
        controller.loadAvailableEmojis();
        controller.loadQuickEmojis();
      });
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const StandardAppBar(showBackButton: true),
      body: Obx(() {
        if (controller.isLoading.value && controller.selectedPrayer.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  color: AppTheme.iconscolor,
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                Text(
                  'Loading prayer details...',
                  style: ResponsiveHelper.textStyle(
                    context,
                    fontSize: ResponsiveHelper.fontSize(context, mobile: 13, tablet: 14, desktop: 15),
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        if (controller.selectedPrayer.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: ResponsiveHelper.iconSize(context, mobile: 60, tablet: 64, desktop: 68),
                  color: Colors.grey[400],
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                Text(
                  'Prayer request not found',
                  style: ResponsiveHelper.textStyle(
                    context,
                    fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 17, desktop: 18),
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, 8)),
                Text(
                  'The prayer you\'re looking for doesn\'t exist',
                  style: ResponsiveHelper.textStyle(
                    context,
                    fontSize: ResponsiveHelper.fontSize(context, mobile: 13, tablet: 14, desktop: 15),
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, 24)),
                ElevatedButton(
                  onPressed: () => Get.back(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.iconscolor,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Go Back',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        }

        final prayer = controller.selectedPrayer;
        final isAnonymous = prayer['is_anonymous'] == 1 || prayer['is_anonymous'] == true;
        final category = prayer['category'] as String? ?? 'General';
        final categoryColor = _getPrayerTypeColor(category);
        final prayerFor = prayer['prayer_for'] as String? ?? 'Me';
        final timeAgo = _getTimeAgo(prayer['created_at'] as String?);
        
        // Get profile photo URL
        String? profilePhotoUrl;
        if (!isAnonymous && prayer['profile_photo'] != null && prayer['profile_photo'].toString().isNotEmpty) {
          final photoPath = prayer['profile_photo'].toString();
          // Check if already a full URL (http/https)
          if (photoPath.startsWith('http://') || photoPath.startsWith('https://')) {
            profilePhotoUrl = photoPath; // Use as-is if already a full URL
          } else if (!photoPath.startsWith('assets/') && 
              !photoPath.startsWith('file://') &&
              !photoPath.startsWith('assets/images/')) {
            profilePhotoUrl = 'https://fruitofthespirit.templateforwebsites.com/$photoPath';
          }
        }

        final prayerId = prayer['id'] as int;
        
        return Column(
          children: [
            // Prayer Content Section
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  print('🔄 Pull-to-refresh triggered');
                  // Reload prayer details (this also reloads comments automatically)
                  await controller.loadPrayerDetails(prayerId);
                  print('✅ Refresh completed');
                },
                              color: AppTheme.iconscolor,
                backgroundColor: Colors.white,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(), // Enable scroll even when content is small
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    // Main Prayer Card - Exact same pattern as home screen
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
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
                          // Header - Profile + Name + Three-dot menu (Exact match home screen)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                // Profile Picture - Exact same as home screen
                                profilePhotoUrl != null && !isAnonymous
                                    ? ClipOval(
                                        child: CachedImage(
                                          imageUrl: profilePhotoUrl,
                                          width: ResponsiveHelper.iconSize(context, mobile: 44, tablet: 48, desktop: 52),
                                          height: ResponsiveHelper.iconSize(context, mobile: 44, tablet: 48, desktop: 52),
                                          fit: BoxFit.cover,
                                          errorWidget: CircleAvatar(
                                            radius: ResponsiveHelper.iconSize(context, mobile: 22, tablet: 24, desktop: 26) / 2,
                                            backgroundColor: Colors.grey[300]!,
                                            child: Icon(
                                              Icons.person_rounded,
                                              size: ResponsiveHelper.iconSize(context, mobile: 22, tablet: 24, desktop: 26),
                                              color: AppTheme.iconscolor,
                                            ),
                                          ),
                                        ),
                                      )
                                    : CircleAvatar(
                                        radius: ResponsiveHelper.iconSize(context, mobile: 22, tablet: 24, desktop: 26) / 2,
                                        backgroundColor: Colors.grey[300]!,
                                        child: Icon(
                                          Icons.person_rounded,
                                          size: ResponsiveHelper.iconSize(context, mobile: 22, tablet: 24, desktop: 26),
                                          color: AppTheme.iconscolor,
                                        ),
                                      ),
                                SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                                // Name - Exact same as home screen
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        isAnonymous ? 'Anonymous' : (prayer['user_name'] as String? ?? 'Anonymous'),
                                        style: ResponsiveHelper.textStyle(
                                          context,
                                          fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 15, desktop: 16),
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ],
                                  ),
                                ),
                                // Three-dot menu - Exact match
                                IconButton(
                                  icon: Icon(
                                    Icons.more_vert,
                                    size: ResponsiveHelper.iconSize(context, mobile: 18, tablet: 20, desktop: 22),
                                    color: AppTheme.iconscolor,
                                  ),
                                  onPressed: () {
                                    // Menu options can be added here
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ),
                          // Prayer Type - Below name (Exact same as home screen subtitle)
                          Padding(
                            padding: ResponsiveHelper.padding(context, horizontal: 16, vertical: 0),
                            child: Text(
                              category,
                              style: ResponsiveHelper.textStyle(
                                context,
                                fontSize: ResponsiveHelper.fontSize(context, mobile: 13, tablet: 14, desktop: 15),
                                color: AppTheme.iconscolor,
                                fontWeight: FontWeight.normal,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          SizedBox(height: ResponsiveHelper.spacing(context, 12)),
                          // Content - Full content displayed (Same style as home screen)
                          Padding(
                            padding: ResponsiveHelper.padding(context, horizontal: 16, vertical: 0),
                            child: Text(
                              AutoTranslateHelper.getTranslatedTextSync(
                                text: prayer['content'] as String? ?? '',
                                sourceLanguage: prayer['language'] as String?,
                              ),
                              style: ResponsiveHelper.textStyle(
                                context,
                                fontSize: ResponsiveHelper.fontSize(context, mobile: 13, tablet: 14, desktop: 15),
                                color: Colors.black87,
                                height: 1.5,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          ),
                          SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                          // Bottom Actions - Left: Prayed count, Right: Comments count (Exact match home screen)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Left: Prayed count with icon - Only show if > 0 (Exact match)
                                if ((prayer['response_count'] ?? 0) > 0)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.favorite,
                                        size: 18,
                                        color: Colors.blue[600],
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${prayer['response_count'] ?? 0} prayed',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.blue[600],
                                          fontWeight: FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                // Right: Comments count with icon - Only show if > 0 (Exact match)
                                if ((controller.prayerComments.length) > 0)
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
                                        '${controller.prayerComments.length} Comments',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: AppTheme.iconscolor,
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
                    
                    const SizedBox(height: 20),
                    
                    // Emoji Reactions Section
                    if (prayer['allow_encouragement'] == 1)
                      _buildEmojiReactions(context, prayerId, controller),
                    
                    const SizedBox(height: 24),
                    
                    // Responses/Comments Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 8)),
                              decoration: BoxDecoration(
                                color: AppTheme.iconscolor,
                                borderRadius: BorderRadius.circular(ResponsiveHelper.isMobile(context) ? 12 : 14),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.iconscolor.withOpacity(0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.chat_bubble_outline_rounded,
                                color: Colors.white,
                                size: ResponsiveHelper.fontSize(context, mobile: 18),
                              ),
                            ),
                            SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                            Text(
                              'Responses',
                              style: TextStyle(
                                fontSize: ResponsiveHelper.fontSize(context, mobile: 20),
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: ResponsiveHelper.spacing(context, 12),
                            vertical: ResponsiveHelper.spacing(context, 6),
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppTheme.iconscolor.withOpacity(0.15),
                                AppTheme.iconscolor.withOpacity(0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(ResponsiveHelper.isMobile(context) ? 12 : 14),
                            border: Border.all(
                              color: AppTheme.iconscolor.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            '${controller.prayerComments.length}',
                            style: TextStyle(
                              fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                              fontWeight: FontWeight.bold,
                              color: AppTheme.iconscolor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Comments List
                    if (controller.prayerComments.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 48,
                              color: AppTheme.iconscolor,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No responses yet',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Be the first to share your thoughts',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.iconscolor,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ...controller.prayerComments.map((comment) => _buildCommentCard(context, comment, prayer['id'] as int)),
                  ],
                ),
              ),
            ),
          ),
            
            // Comment Input Section
            Container(
              padding: ResponsiveHelper.padding(
                context,
                all: ResponsiveHelper.isMobile(context) ? 16 : 20,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(
                    color: Colors.grey.withOpacity(0.15),
                    width: 1,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: ResponsiveHelper.isMobile(context) ? 12 : 16,
                    spreadRadius: 0,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: TextField(
                          controller: commentController,
                          decoration: InputDecoration(
                            hintText: 'Write a response...',
                            hintStyle: TextStyle(
                              color: AppTheme.iconscolor,
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            prefixIcon: IconButton(
                              icon: const Icon(Icons.emoji_emotions_outlined, color: Color(0xFF8B4513)),
                              onPressed: () => _showEmojiPicker(context, prayerId, controller),
                            ),
                          ),
                          maxLines: null,
                          textInputAction: TextInputAction.newline,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF8B4513),
                            Color(0xFF6B3410),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(ResponsiveHelper.isMobile(context) ? 24 : 28),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF8B4513).withOpacity(0.4),
                            blurRadius: ResponsiveHelper.isMobile(context) ? 10 : 12,
                            spreadRadius: 0,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () async {
                            if (commentController.text.trim().isEmpty) return;
                            
                            final success = await controller.addComment(
                              prayerId,
                              commentController.text.trim(),
                            );
                            
                            if (success) {
                              commentController.clear();
                              Get.snackbar(
                                'Success',
                                'Response added successfully',
                                backgroundColor: Colors.green,
                                colorText: Colors.white,
                                duration: const Duration(seconds: 2),
                                icon: const Icon(Icons.check_circle, color: Colors.white),
                              );
                            } else {
                              Get.snackbar(
                                'Error',
                                controller.message.value,
                                backgroundColor: Colors.red,
                                colorText: Colors.white,
                                duration: const Duration(seconds: 2),
                                icon: const Icon(Icons.error, color: Colors.white),
                              );
                            }
                          },
                          borderRadius: BorderRadius.circular(ResponsiveHelper.isMobile(context) ? 24 : 28),
                          child: Padding(
                            padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 12)),
                            child: Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: ResponsiveHelper.fontSize(context, mobile: 24),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildCommentCard(BuildContext context, Map<String, dynamic> comment, int prayerId) {
    final content = comment['content'] as String? ?? '';
    final trimmed = content.trim();
    
    // Safety check: Don't display emoji reactions as comments
    if (trimmed.length <= 4) {
      final emojiRegex = RegExp(
        r'[\u{1F300}-\u{1F9FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]|[\u{1F600}-\u{1F64F}]|[\u{1F680}-\u{1F6FF}]|[\u{2764}\u{FE0F}]|[\u{2728}]|[\u{2B50}]',
        unicode: true,
      );
      if (emojiRegex.hasMatch(trimmed)) {
        return const SizedBox.shrink();
      }
    }
    
    final timeAgo = _getTimeAgo(comment['created_at'] as String?);
    final profilePhoto = comment['profile_photo'] as String?;
    final commentId = comment['id'] as int;
    String? profilePhotoUrl;
    
    if (profilePhoto != null && profilePhoto.toString().isNotEmpty) {
      final photoPath = profilePhoto.toString();
      // Check if already a full URL (http/https)
      if (photoPath.startsWith('http://') || photoPath.startsWith('https://')) {
        profilePhotoUrl = photoPath; // Use as-is if already a full URL
      } else if (!photoPath.startsWith('assets/') && 
          !photoPath.startsWith('file://') &&
          !photoPath.startsWith('assets/images/')) {
        profilePhotoUrl = 'https://fruitofthespirit.templateforwebsites.com/$photoPath';
      }
    }
    
    // Initialize reply controller if not exists
    if (!replyControllers.containsKey(commentId)) {
      replyControllers[commentId] = TextEditingController();
    }
    
    return Container(
      margin: EdgeInsets.only(bottom: ResponsiveHelper.spacing(context, 12)),
      padding: ResponsiveHelper.padding(
        context,
        all: ResponsiveHelper.isMobile(context) ? 16 : 18,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ResponsiveHelper.isMobile(context) ? 18 : 20),
        border: Border.all(
          color: Colors.grey.withOpacity(0.12),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: ResponsiveHelper.isMobile(context) ? 10 : 12,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Photo
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFFFFD1DC),
                      const Color(0xFFFFB6C1),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFB6C1).withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(2),
                child: CircleAvatar(
                  radius: ResponsiveHelper.isMobile(context) ? 20 : 22,
                  backgroundColor: Colors.white,
                  backgroundImage: profilePhotoUrl != null
                      ? NetworkImage(profilePhotoUrl)
                      : null,
                  child: profilePhotoUrl == null
                      ? Icon(
                          Icons.person_rounded,
                          color: Colors.black87,
                          size: ResponsiveHelper.fontSize(context, mobile: 20),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            comment['user_name'] as String? ?? 'Someone',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF5F4628),
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        if (timeAgo.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            '•',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.iconscolor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              timeAgo,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.iconscolor,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    FruitEmojiHelper.buildCommentText(
                      context,
                      AutoTranslateHelper.getTranslatedTextSync(
                        text: content,
                        sourceLanguage: comment['language'] as String?,
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Action Buttons: Like, Reply, Report
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        // Like Button
                        InkWell(
                          onTap: () async {
                            final success = await controller.toggleCommentLike(commentId);
                            if (success) {
                              // Reload comments to get updated like status
                              await controller.loadPrayerComments(prayerId);
                              setState(() {}); // Refresh UI
                            }
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                ((comment['is_liked'] ?? 0) == 1) ? Icons.favorite : Icons.favorite_border,
                                size: 16,
                                color: AppTheme.iconscolor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                (comment['like_count'] ?? 0) > 0 ? '${comment['like_count']}' : 'Like',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.iconscolor,
                                  fontWeight: ((comment['is_liked'] ?? 0) == 1) ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Reply Button
                        InkWell(
                          onTap: () {
                            setState(() {
                              showReplyInput[commentId] = !(showReplyInput[commentId] ?? false);
                            });
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.reply,
                                size: 16,
                                color: AppTheme.iconscolor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Reply',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.iconscolor,
                                ),
                              ),
                              if ((comment['reply_count'] ?? 0) > 0)
                                Text(
                                  ' (${comment['reply_count']})',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.iconscolor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Report Button - Only show for other users' comments
                        if (currentUserId != null && (comment['user_id'] as int? ?? 0) != currentUserId)
                          InkWell(
                            onTap: () => _showReportDialog(context, comment),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.flag_outlined,
                                  size: 16,
                                  color: AppTheme.iconscolor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Report',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.iconscolor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    // Reply Input (if shown)
                    if (showReplyInput[commentId] == true) ...[
                      const SizedBox(height: 12),
                      _buildReplyInput(context, commentId, prayerId),
                    ],
                    // Expand/Collapse button for top-level comment replies
                    if (comment['replies'] != null && (comment['replies'] as List).isNotEmpty) ...[
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () {
                          setState(() {
                            if (expandedReplies.contains(commentId)) {
                              expandedReplies.remove(commentId);
                            } else {
                              expandedReplies.add(commentId);
                            }
                          });
                        },
                        child: Row(
                          children: [
                            Icon(
                              expandedReplies.contains(commentId) ? Icons.expand_less : Icons.expand_more,
                              size: 16,
                              color: AppTheme.iconscolor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              expandedReplies.contains(commentId) 
                                  ? 'Hide ${(comment['replies'] as List).length} ${(comment['replies'] as List).length == 1 ? 'reply' : 'replies'}'
                                  : 'Show ${(comment['replies'] as List).length} ${(comment['replies'] as List).length == 1 ? 'reply' : 'replies'}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF9F9467),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    // Nested Replies (recursive - supports multi-level nesting) - only show if expanded
                    if (comment['replies'] != null && (comment['replies'] as List).isNotEmpty && expandedReplies.contains(commentId)) ...[
                      const SizedBox(height: 12),
                      ...((comment['replies'] as List).map((reply) => _buildReplyCard(context, reply, prayerId, depth: 0))),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build Emoji Reactions Widget
  Widget _buildEmojiReactions(BuildContext context, int prayerId, PrayersController controller) {
    return Obx(() {
      final reactions = controller.prayerEmojiReactions;
      final hasReactions = reactions.isNotEmpty;
      final quickEmojisList = controller.quickEmojis;
      
      // Debug logging
      print('🔍 _buildEmojiReactions: hasReactions=$hasReactions, reactions count=${reactions.length}');
      if (hasReactions) {
        reactions.forEach((key, users) {
          print('   - Emoji key: "$key" (${users.length} users)');
        });
      }
      
      return Container(
        padding: ResponsiveHelper.padding(
          context,
          all: ResponsiveHelper.isMobile(context) ? 16 : 20,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ResponsiveHelper.isMobile(context) ? 18 : 20),
          border: Border.all(
            color: Colors.grey.withOpacity(0.12),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: ResponsiveHelper.isMobile(context) ? 10 : 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 8)),
                  decoration: BoxDecoration(
                    color: AppTheme.iconscolor,
                    borderRadius: BorderRadius.circular(ResponsiveHelper.isMobile(context) ? 10 : 12),
                  ),
                  child: Icon(
                    Icons.volunteer_activism_rounded,
                    color: Colors.white,
                    size: ResponsiveHelper.fontSize(context, mobile: 18),
                  ),
                ),
                SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Show Your Support',
                        style: TextStyle(
                          fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(height: ResponsiveHelper.spacing(context, 2)),
                      Text(
                        'Express your encouragement with emojis',
                        style: TextStyle(
                          fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 16)),
            
            // Quick Emoji Buttons - Phone Style (No borders, minimal gap)
            Wrap(
              spacing: ResponsiveHelper.spacing(context, 6),
              runSpacing: ResponsiveHelper.spacing(context, 6),
              children: [
                if (quickEmojisList.isEmpty)
                  Padding(
                    padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 8)),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.iconscolor,
                      ),
                    ),
                  )
                else
                  ...quickEmojisList.map((emojiData) {
                    // Use emoji_char or code for API, but display fruit image
                    // Try multiple fallbacks: emoji_char -> code -> name (base fruit name)
                    String? emoji = emojiData['emoji_char'] as String?;
                    if (emoji == null || emoji.trim().isEmpty) {
                      emoji = emojiData['code'] as String?;
                    }
                    if (emoji == null || emoji.trim().isEmpty) {
                      // Try to extract base fruit name from name field
                      final name = emojiData['name'] as String? ?? '';
                      if (name.isNotEmpty) {
                        // Extract base fruit name (e.g., "Goodness Banana (1)" -> "goodness")
                        String baseName = name.toLowerCase();
                        if (baseName.contains(':')) {
                          final parts = baseName.split(':');
                          if (parts.length > 1) {
                            baseName = parts[1].trim();
                          }
                        }
                        if (baseName.contains(' ')) {
                          baseName = baseName.split(' ')[0].trim();
                        }
                        emoji = baseName;
                      }
                    }
                    
                    // If still empty, skip this emoji (don't make it clickable)
                    final isValidEmoji = emoji != null && emoji.trim().isNotEmpty;
                    
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: isValidEmoji ? () async {
                          final success = await controller.addEmojiReaction(prayerId, emoji!);
                          if (success) {
                            Get.snackbar(
                              'Success',
                              'Reaction added',
                              backgroundColor: Colors.green,
                              colorText: Colors.white,
                              duration: const Duration(seconds: 1),
                            );
                          }
                        } : null,
                        borderRadius: BorderRadius.circular(ResponsiveHelper.isMobile(context) ? 40 : 44),
                        child: Padding(
                          padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 4)),
                          child: SizedBox(
                            width: ResponsiveHelper.isMobile(context) ? 44 : 48,
                            height: ResponsiveHelper.isMobile(context) ? 44 : 48,
                            child: HomeScreen.buildEmojiDisplay(
                              context,
                              emojiData,
                              size: ResponsiveHelper.isMobile(context) ? 44 : 48,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                // More Emojis Button - Phone Style
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showEmojiPicker(context, prayerId, controller),
                    borderRadius: BorderRadius.circular(ResponsiveHelper.isMobile(context) ? 40 : 44),
                    child: Padding(
                      padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 4)),
                      child: Container(
                        width: ResponsiveHelper.isMobile(context) ? 44 : 48,
                        height: ResponsiveHelper.isMobile(context) ? 44 : 48,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.add_reaction_rounded,
                          size: ResponsiveHelper.fontSize(context, mobile: 22),
                          color: AppTheme.iconscolor,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            // Display Reactions Count - Phone Style with Actual Emojis
            if (hasReactions) ...[
              SizedBox(height: ResponsiveHelper.spacing(context, 20)),
              Row(
                children: [
                  // Show first emoji from reactions instead of heart icon
                  if (reactions.isNotEmpty) ...[
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: Builder(
                        builder: (context) {
                          final firstReaction = reactions.entries.first;
                          final emojiChar = firstReaction.key;
                          Map<String, dynamic>? fruitEmoji;
                          
                          // Find matching emoji
                          for (var emoji in controller.availableEmojis) {
                            final emojiCharFromList = emoji['emoji_char'] as String? ?? '';
                            if (emojiCharFromList.trim() == emojiChar.trim() || 
                                emojiCharFromList == emojiChar) {
                              fruitEmoji = emoji;
                              break;
                            }
                          }
                          
                          if (fruitEmoji != null) {
                            return HomeScreen.buildEmojiDisplay(
                              context,
                              fruitEmoji!,
                              size: 20,
                            );
                          }
                          return Icon(
                            Icons.favorite_rounded,
                            size: ResponsiveHelper.fontSize(context, mobile: 16),
                            color: AppTheme.iconscolor,
                          );
                        },
                      ),
                    ),
                    SizedBox(width: ResponsiveHelper.spacing(context, 6)),
                  ] else
                    Icon(
                      Icons.favorite_rounded,
                      size: ResponsiveHelper.fontSize(context, mobile: 16),
                      color: AppTheme.iconscolor,
                    ),
                  Text(
                    'Community Support',
                    style: TextStyle(
                      fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
              SizedBox(height: ResponsiveHelper.spacing(context, 12)),
              Wrap(
                spacing: ResponsiveHelper.spacing(context, 6),
                runSpacing: ResponsiveHelper.spacing(context, 6),
                children: reactions.entries.map((entry) {
                  // Find fruit image for this emoji (can be character, code, image_url, or ID)
                  final emojiKey = entry.key;
                  final usersWhoReacted = entry.value as List<Map<String, dynamic>>;
                  Map<String, dynamic>? fruitEmoji;
                  
                  // Try multiple matching strategies
                  for (var emoji in controller.availableEmojis) {
                    final emojiCharFromList = emoji['emoji_char'] as String? ?? '';
                    final emojiCodeFromList = emoji['code'] as String? ?? '';
                    final emojiImageUrlFromList = emoji['image_url'] as String? ?? '';
                    final emojiIdFromList = emoji['id']?.toString() ?? '';
                    
                    // Strategy 1: Match by emoji_char
                    if (emojiCharFromList.isNotEmpty && 
                        (emojiCharFromList.trim() == emojiKey.trim() || emojiCharFromList == emojiKey)) {
                      fruitEmoji = emoji;
                      break;
                    }
                    // Strategy 2: Match by code
                    if (emojiCodeFromList.isNotEmpty && 
                        (emojiCodeFromList.trim() == emojiKey.trim() || emojiCodeFromList == emojiKey)) {
                      fruitEmoji = emoji;
                      break;
                    }
                    // Strategy 3: Match by image_url (check if emojiKey is in the URL or vice versa)
                    if (emojiImageUrlFromList.isNotEmpty) {
                      // Extract filename from both URLs
                      String? keyFilename;
                      String? listFilename;
                      
                      if (emojiKey.contains('/')) {
                        keyFilename = emojiKey.split('/').last.replaceAll('%20', ' ').toLowerCase();
                      } else {
                        keyFilename = emojiKey.toLowerCase();
                      }
                      
                      if (emojiImageUrlFromList.contains('/')) {
                        listFilename = emojiImageUrlFromList.split('/').last.replaceAll('%20', ' ').toLowerCase();
                      } else {
                        listFilename = emojiImageUrlFromList.toLowerCase();
                      }
                      
                      if (keyFilename == listFilename || 
                          emojiImageUrlFromList.contains(emojiKey) || 
                          emojiKey.contains(emojiImageUrlFromList)) {
                        fruitEmoji = emoji;
                        break;
                      }
                    }
                    // Strategy 4: Match by ID
                    if (emojiIdFromList.isNotEmpty && emojiIdFromList == emojiKey) {
                      fruitEmoji = emoji;
                      break;
                    }
                  }
                  
                  return GestureDetector(
                    onTap: () {
                      // Show dialog with users who reacted
                      _showReactionUsersDialog(context, emojiKey, usersWhoReacted, fruitEmoji);
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Show fruit image - Phone Style (no border)
                        if (fruitEmoji != null)
                          SizedBox(
                            width: 28,
                            height: 28,
                            child: HomeScreen.buildEmojiDisplay(
                              context,
                              fruitEmoji,
                              size: 28,
                            ),
                          )
                        else
                          // Fallback: show placeholder
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.sentiment_satisfied,
                              size: 18,
                              color: AppTheme.iconscolor,
                            ),
                          ),
                        SizedBox(width: ResponsiveHelper.spacing(context, 6)),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${usersWhoReacted.length}',
                              style: TextStyle(
                                fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                                fontWeight: FontWeight.bold,
                                color: AppTheme.iconscolor,
                              ),
                            ),
                            if (usersWhoReacted.isNotEmpty) ...[
                              SizedBox(height: ResponsiveHelper.spacing(context, 1)),
                              Text(
                                usersWhoReacted.length == 1
                                    ? usersWhoReacted[0]['user_name'] ?? 'Someone'
                                    : '${usersWhoReacted[0]['user_name'] ?? 'Someone'} and ${usersWhoReacted.length - 1} more',
                                style: TextStyle(
                                  fontSize: ResponsiveHelper.fontSize(context, mobile: 11),
                                  color: AppTheme.iconscolor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              
              // "Who Reacted" Section - Show all users who reacted
              if (hasReactions) ...[
                SizedBox(height: ResponsiveHelper.spacing(context, 20)),
                Container(
                  padding: ResponsiveHelper.padding(context, all: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(ResponsiveHelper.isMobile(context) ? 12 : 14),
                    border: Border.all(
                      color: Colors.grey.withOpacity(0.15),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.people_rounded,
                            size: ResponsiveHelper.fontSize(context, mobile: 16),
                            color: AppTheme.iconscolor,
                          ),
                          SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                          Text(
                            'Who Reacted',
                            style: TextStyle(
                              fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: ResponsiveHelper.spacing(context, 12)),
                      // Show all users who reacted (max 5, then show "and X more")
                      Builder(
                        builder: (context) {
                          // Collect all users with their emoji reactions
                          final allUsersWithReactions = <Map<String, dynamic>>[];
                          reactions.entries.forEach((entry) {
                            final emojiChar = entry.key;
                            final usersWhoReacted = entry.value as List<Map<String, dynamic>>;
                            for (var user in usersWhoReacted) {
                              allUsersWithReactions.add({
                                ...user,
                                'reaction_emoji': emojiChar,
                              });
                            }
                          });
                          
                          // Sort by created_at (most recent first)
                          allUsersWithReactions.sort((a, b) {
                            final aTime = a['created_at'] as String? ?? '';
                            final bTime = b['created_at'] as String? ?? '';
                            return bTime.compareTo(aTime);
                          });
                          
                          // Take first 5
                          final usersToShow = allUsersWithReactions.take(5).toList();
                          
                          return Column(
                            children: usersToShow.map((userData) {
                              final userName = userData['user_name'] as String? ?? 'Anonymous';
                              final profilePhoto = userData['profile_photo'] as String?;
                              final emojiChar = userData['reaction_emoji'] as String? ?? '';
                              String? profilePhotoUrl;
                              
                              if (profilePhoto != null && profilePhoto.toString().isNotEmpty) {
                                final photoPath = profilePhoto.toString();
                                if (!photoPath.startsWith('assets/') && 
                                    !photoPath.startsWith('file://') &&
                                    !photoPath.startsWith('assets/images/')) {
                                  profilePhotoUrl = 'https://fruitofthespirit.templateforwebsites.com/$photoPath';
                                }
                              }
                              
                              // Find fruit emoji for this reaction (can be character, code, image_url, or ID)
                              Map<String, dynamic>? fruitEmoji;
                              for (var emoji in controller.availableEmojis) {
                                final emojiCharFromList = emoji['emoji_char'] as String? ?? '';
                                final emojiCodeFromList = emoji['code'] as String? ?? '';
                                final emojiImageUrlFromList = emoji['image_url'] as String? ?? '';
                                final emojiIdFromList = emoji['id']?.toString() ?? '';
                                
                                // Strategy 1: Match by emoji_char
                                if (emojiCharFromList.isNotEmpty && 
                                    (emojiCharFromList.trim() == emojiChar.trim() || emojiCharFromList == emojiChar)) {
                                  fruitEmoji = emoji;
                                  break;
                                }
                                // Strategy 2: Match by code
                                if (emojiCodeFromList.isNotEmpty && 
                                    (emojiCodeFromList.trim() == emojiChar.trim() || emojiCodeFromList == emojiChar)) {
                                  fruitEmoji = emoji;
                                  break;
                                }
                                // Strategy 3: Match by image_url
                                if (emojiImageUrlFromList.isNotEmpty) {
                                  String? keyFilename;
                                  String? listFilename;
                                  
                                  if (emojiChar.contains('/')) {
                                    keyFilename = emojiChar.split('/').last.replaceAll('%20', ' ').toLowerCase();
                                  } else {
                                    keyFilename = emojiChar.toLowerCase();
                                  }
                                  
                                  if (emojiImageUrlFromList.contains('/')) {
                                    listFilename = emojiImageUrlFromList.split('/').last.replaceAll('%20', ' ').toLowerCase();
                                  } else {
                                    listFilename = emojiImageUrlFromList.toLowerCase();
                                  }
                                  
                                  if (keyFilename == listFilename || 
                                      emojiImageUrlFromList.contains(emojiChar) || 
                                      emojiChar.contains(emojiImageUrlFromList)) {
                                    fruitEmoji = emoji;
                                    break;
                                  }
                                }
                                // Strategy 4: Match by ID
                                if (emojiIdFromList.isNotEmpty && emojiIdFromList == emojiChar) {
                                  fruitEmoji = emoji;
                                  break;
                                }
                              }
                              
                              return Padding(
                                padding: EdgeInsets.only(bottom: ResponsiveHelper.spacing(context, 8)),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: ResponsiveHelper.isMobile(context) ? 16 : 18,
                                      backgroundImage: profilePhotoUrl != null ? NetworkImage(profilePhotoUrl) : null,
                                      backgroundColor: Colors.grey[300],
                                      child: profilePhotoUrl == null
                                          ? Text(
                                              userName.isNotEmpty ? userName[0].toUpperCase() : 'A',
                                              style: TextStyle(
                                                fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                                                color: Colors.grey[700],
                                                fontWeight: FontWeight.bold,
                                              ),
                                            )
                                          : null,
                                    ),
                                    SizedBox(width: ResponsiveHelper.spacing(context, 10)),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            userName,
                                            style: TextStyle(
                                              fontSize: ResponsiveHelper.fontSize(context, mobile: 13),
                                              fontWeight: FontWeight.w500,
                                              color: Colors.black,
                                            ),
                                          ),
                                          Text(
                                            _getTimeAgo(userData['created_at'] as String?),
                                            style: TextStyle(
                                              fontSize: ResponsiveHelper.fontSize(context, mobile: 11),
                                              color: AppTheme.iconscolor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Show which emoji they reacted with
                                    if (fruitEmoji != null)
                                      SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: HomeScreen.buildEmojiDisplay(
                                          context,
                                          fruitEmoji,
                                          size: 24,
                                        ),
                                      )
                                    else
                                      SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: Icon(
                                          Icons.sentiment_satisfied,
                                          size: 18,
                                          color: AppTheme.iconscolor,
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                      // Show "and X more" if there are more than 5 users
                      Builder(
                        builder: (context) {
                          final totalUsers = reactions.values.fold<int>(0, (sum, users) => sum + (users as List).length);
                          if (totalUsers > 5) {
                            return GestureDetector(
                              onTap: () {
                                // Show all users in dialog - collect all users from all reactions
                                final allUsers = <Map<String, dynamic>>[];
                                reactions.entries.forEach((entry) {
                                  allUsers.addAll((entry.value as List<Map<String, dynamic>>));
                                });
                                // Show dialog with first emoji or null
                                final firstEmojiChar = reactions.keys.isNotEmpty ? reactions.keys.first : '';
                                Map<String, dynamic>? firstFruitEmoji;
                                if (firstEmojiChar.isNotEmpty) {
                                  for (var emoji in controller.availableEmojis) {
                                    final emojiCharFromList = emoji['emoji_char'] as String? ?? '';
                                    if (emojiCharFromList.trim() == firstEmojiChar.trim() || 
                                        emojiCharFromList == firstEmojiChar) {
                                      firstFruitEmoji = emoji;
                                      break;
                                    }
                                  }
                                }
                                _showReactionUsersDialog(context, firstEmojiChar, allUsers, firstFruitEmoji);
                              },
                              child: Padding(
                                padding: EdgeInsets.only(top: ResponsiveHelper.spacing(context, 4)),
                                child: Row(
                                  children: [
                                    Text(
                                      'and ${totalUsers - 5} more',
                                      style: TextStyle(
                                        fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                                        color: AppTheme.iconscolor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      size: ResponsiveHelper.fontSize(context, mobile: 12),
                                      color: AppTheme.iconscolor,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      );
    });
  }

  Widget _buildReplyInput(BuildContext context, int parentCommentId, int prayerId) {
    if (!replyControllers.containsKey(parentCommentId)) {
      replyControllers[parentCommentId] = TextEditingController();
    }
    final replyController = replyControllers[parentCommentId]!;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: replyController,
              decoration: InputDecoration(
                hintText: 'Write a reply...',
                hintStyle: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 13,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              maxLines: null,
              textInputAction: TextInputAction.newline,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                if (replyController.text.trim().isEmpty) return;
                
                print('📤 Sending reply: parentCommentId=$parentCommentId, content=${replyController.text.trim().substring(0, replyController.text.trim().length > 20 ? 20 : replyController.text.trim().length)}...');
                
                final success = await controller.addComment(
                  prayerId,
                  replyController.text.trim(),
                  parentCommentId: parentCommentId,
                );
                
                if (success) {
                  print('✅ Reply added successfully, reloading comments...');
                  replyController.clear();
                  setState(() {
                    showReplyInput[parentCommentId] = false;
                    // Auto-expand parent to show the new reply
                    expandedReplies.add(parentCommentId);
                  });
                  
                  // Force reload comments to show the new reply
                  await controller.loadPrayerComments(prayerId);
                  setState(() {}); // Refresh UI
                  
                  Get.snackbar(
                    'Success',
                    'Reply added successfully',
                    backgroundColor: Colors.green,
                    colorText: Colors.white,
                    duration: const Duration(seconds: 1),
                    icon: const Icon(Icons.check_circle, color: Colors.white),
                  );
                } else {
                  Get.snackbar(
                    'Error',
                    controller.message.value,
                    backgroundColor: Colors.red,
                    colorText: Colors.white,
                    duration: const Duration(seconds: 2),
                  );
                }
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                              color: AppTheme.iconscolor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.send,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildReplyCard(BuildContext context, Map<String, dynamic> reply, int prayerId, {int depth = 0}) {
    final content = reply['content'] as String? ?? '';
    final trimmed = content.trim();
    
    // Safety check: Don't display emoji reactions as replies
    if (trimmed.length <= 4) {
      final emojiRegex = RegExp(
        r'[\u{1F300}-\u{1F9FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]|[\u{1F600}-\u{1F64F}]|[\u{1F680}-\u{1F6FF}]|[\u{2764}\u{FE0F}]|[\u{2728}]|[\u{2B50}]',
        unicode: true,
      );
      if (emojiRegex.hasMatch(trimmed)) {
        return const SizedBox.shrink();
      }
    }
    
    final timeAgo = _getTimeAgo(reply['created_at'] as String?);
    final profilePhoto = reply['profile_photo'] as String?;
    final replyId = reply['id'] as int;
    String? profilePhotoUrl;
    
    if (profilePhoto != null && profilePhoto.toString().isNotEmpty) {
      final photoPath = profilePhoto.toString();
      // Check if already a full URL (http/https)
      if (photoPath.startsWith('http://') || photoPath.startsWith('https://')) {
        profilePhotoUrl = photoPath; // Use as-is if already a full URL
      } else if (!photoPath.startsWith('assets/') && 
          !photoPath.startsWith('file://') &&
          !photoPath.startsWith('assets/images/')) {
        profilePhotoUrl = 'https://fruitofthespirit.templateforwebsites.com/$photoPath';
      }
    }
    
    // Initialize reply controller if not exists
    if (!replyControllers.containsKey(replyId)) {
      replyControllers[replyId] = TextEditingController();
    }
    
    // Calculate left margin based on depth (responsive - less indentation)
    final leftMargin = ResponsiveHelper.spacing(context, 16) + (depth * ResponsiveHelper.spacing(context, 16));
    
    return Container(
      margin: EdgeInsets.only(
        left: leftMargin,
        top: ResponsiveHelper.spacing(context, 8),
        bottom: ResponsiveHelper.spacing(context, 8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thread connector line - vertical line for nested structure
          if (depth > 0)
            Container(
              width: 2,
              margin: EdgeInsets.only(
                top: ResponsiveHelper.spacing(context, 20),
                right: ResponsiveHelper.spacing(context, 10),
              ),
              decoration: BoxDecoration(
                color: Colors.grey[300]!.withOpacity(0.6),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 12)),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(ResponsiveHelper.isMobile(context) ? 12 : 14),
                    border: Border.all(
                      color: Colors.grey.withOpacity(0.2),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: ResponsiveHelper.isMobile(context) ? 16 : 18,
                            backgroundColor: const Color(0xFFFFD1DC),
                            backgroundImage: profilePhotoUrl != null
                                ? NetworkImage(profilePhotoUrl)
                                : null,
                            child: profilePhotoUrl == null
                                ? Icon(
                                    Icons.person_rounded,
                                    color: Colors.black87,
                                    size: ResponsiveHelper.fontSize(context, mobile: 16),
                                  )
                                : null,
                          ),
                          SizedBox(width: ResponsiveHelper.spacing(context, 10)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        reply['user_name'] as String? ?? 'Someone',
                                        style: TextStyle(
                                          fontSize: ResponsiveHelper.fontSize(context, mobile: 13),
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                    if (timeAgo.isNotEmpty) ...[
                                      SizedBox(width: ResponsiveHelper.spacing(context, 6)),
                                      Text(
                                        '•',
                                        style: TextStyle(
                                          fontSize: ResponsiveHelper.fontSize(context, mobile: 11),
                                          color: AppTheme.iconscolor,
                                        ),
                                      ),
                                      SizedBox(width: ResponsiveHelper.spacing(context, 6)),
                                      Flexible(
                                        child: Text(
                                          timeAgo,
                                          style: TextStyle(
                                            fontSize: ResponsiveHelper.fontSize(context, mobile: 11),
                                            color: AppTheme.iconscolor,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                SizedBox(height: ResponsiveHelper.spacing(context, 6)),
                                Text(
                                  AutoTranslateHelper.getTranslatedTextSync(
                                    text: content,
                                    sourceLanguage: reply['language'] as String?,
                                  ),
                                  style: TextStyle(
                                    fontSize: ResponsiveHelper.fontSize(context, mobile: 13),
                                    color: Colors.black87,
                                    height: 1.5,
                                  ),
                                ),
                                SizedBox(height: ResponsiveHelper.spacing(context, 10)),
                                Wrap(
                                  spacing: ResponsiveHelper.spacing(context, 12),
                                  runSpacing: ResponsiveHelper.spacing(context, 8),
                                  children: [
                                    // Like Button for Reply
                                    InkWell(
                                      onTap: () async {
                                        final success = await controller.toggleCommentLike(replyId);
                                        if (success) {
                                          // Reload comments to get updated like status
                                          await controller.loadPrayerComments(prayerId);
                                          setState(() {}); // Refresh UI
                                        }
                                      },
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            ((reply['is_liked'] ?? 0) == 1) ? Icons.favorite : Icons.favorite_border,
                                            size: ResponsiveHelper.fontSize(context, mobile: 14),
                                            color: AppTheme.iconscolor,
                                          ),
                                          if ((reply['like_count'] ?? 0) > 0) ...[
                                            SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                                            Text(
                                              '${reply['like_count']}',
                                              style: TextStyle(
                                                fontSize: ResponsiveHelper.fontSize(context, mobile: 11),
                                                color: AppTheme.iconscolor,
                                                fontWeight: ((reply['is_liked'] ?? 0) == 1) ? FontWeight.w600 : FontWeight.normal,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    // Reply Button for nested replies
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          showReplyInput[replyId] = !(showReplyInput[replyId] ?? false);
                                        });
                                      },
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.reply,
                                            size: ResponsiveHelper.fontSize(context, mobile: 14),
                                            color: AppTheme.iconscolor,
                                          ),
                                          SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                                          Text(
                                            'Reply',
                                            style: TextStyle(
                                              fontSize: ResponsiveHelper.fontSize(context, mobile: 11),
                                              color: AppTheme.iconscolor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Report Button for Reply - Only show for other users' replies
                                    if (currentUserId != null && (reply['user_id'] as int? ?? 0) != currentUserId)
                                      InkWell(
                                        onTap: () => _showReportDialog(context, reply),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.flag_outlined,
                                              size: ResponsiveHelper.fontSize(context, mobile: 14),
                                              color: AppTheme.iconscolor,
                                            ),
                                            SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                                            Text(
                                              'Report',
                                              style: TextStyle(
                                                fontSize: ResponsiveHelper.fontSize(context, mobile: 11),
                                                color: AppTheme.iconscolor,
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
                        ],
                      ),
                      // Reply Input (if shown)
                      if (showReplyInput[replyId] == true) ...[
                        SizedBox(height: ResponsiveHelper.spacing(context, 10)),
                        _buildReplyInput(context, replyId, prayerId),
                      ],
                      // Expand/Collapse button for nested replies
                      if (reply['replies'] != null && (reply['replies'] as List).isNotEmpty) ...[
                        SizedBox(height: ResponsiveHelper.spacing(context, 8)),
                        InkWell(
                          onTap: () {
                            setState(() {
                              if (expandedReplies.contains(replyId)) {
                                expandedReplies.remove(replyId);
                              } else {
                                expandedReplies.add(replyId);
                              }
                            });
                          },
                          child: Row(
                            children: [
                              Icon(
                                expandedReplies.contains(replyId) ? Icons.expand_less : Icons.expand_more,
                                size: ResponsiveHelper.fontSize(context, mobile: 16),
                                color: AppTheme.iconscolor,
                              ),
                              SizedBox(width: ResponsiveHelper.spacing(context, 6)),
                              Text(
                                expandedReplies.contains(replyId) 
                                    ? 'Hide ${(reply['replies'] as List).length} ${(reply['replies'] as List).length == 1 ? 'reply' : 'replies'}'
                                    : 'Show ${(reply['replies'] as List).length} ${(reply['replies'] as List).length == 1 ? 'reply' : 'replies'}',
                                style: TextStyle(
                                  fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                                  color: AppTheme.iconscolor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Nested Replies (recursive) - only show if expanded - placed outside container
                if (reply['replies'] != null && (reply['replies'] as List).isNotEmpty && expandedReplies.contains(replyId)) ...[
                  SizedBox(height: ResponsiveHelper.spacing(context, 8)),
                  ...((reply['replies'] as List).map((nestedReply) => _buildReplyCard(context, nestedReply, prayerId, depth: depth + 1))),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  void _showReportDialog(BuildContext context, Map<String, dynamic> comment) {
    final reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Report Comment',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF5F4628),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Why are you reporting this comment?',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: InputDecoration(
                  hintText: 'Reason (optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                final commentId = comment['id'] as int;
                final success = await controller.reportComment(
                  commentId,
                  reason: reasonController.text.trim().isNotEmpty 
                      ? reasonController.text.trim() 
                      : null,
                );
                
                if (success) {
                  Get.snackbar(
                    'Reported',
                    'Comment reported successfully. Our team will review it.',
                    backgroundColor: Colors.green,
                    colorText: Colors.white,
                    duration: const Duration(seconds: 2),
                    icon: const Icon(Icons.check_circle, color: Colors.white),
                  );
                } else {
                  Get.snackbar(
                    'Error',
                    controller.message.value,
                    backgroundColor: Colors.red,
                    colorText: Colors.white,
                    duration: const Duration(seconds: 2),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.iconscolor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Report',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Show Emoji Picker Dialog
  void _showReactionUsersDialog(BuildContext context, String emojiChar, List<Map<String, dynamic>> users, Map<String, dynamic>? fruitEmoji) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ResponsiveHelper.isMobile(context) ? 20 : 24),
        ),
        child: Container(
          padding: ResponsiveHelper.padding(context, all: 20),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
            maxWidth: ResponsiveHelper.isMobile(context) ? double.infinity : 500,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  if (fruitEmoji != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: HomeScreen.buildEmojiDisplay(
                          context,
                          fruitEmoji,
                          size: 40,
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.sentiment_satisfied, color: Colors.grey[400]),
                    ),
                  SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${users.length} ${users.length == 1 ? 'Person' : 'People'} Reacted',
                          style: TextStyle(
                            fontSize: ResponsiveHelper.fontSize(context, mobile: 18),
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        SizedBox(height: ResponsiveHelper.spacing(context, 2)),
                        Text(
                          'Tap to see who reacted with this emoji',
                          style: TextStyle(
                            fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.grey[600]),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              SizedBox(height: ResponsiveHelper.spacing(context, 16)),
              // Users List
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final userName = user['user_name'] as String? ?? 'Anonymous';
                    final profilePhoto = user['profile_photo'] as String?;
                    String? profilePhotoUrl;
                    
                    if (profilePhoto != null && profilePhoto.toString().isNotEmpty) {
                      final photoPath = profilePhoto.toString();
                      if (!photoPath.startsWith('assets/') && 
                          !photoPath.startsWith('file://') &&
                          !photoPath.startsWith('assets/images/')) {
                        profilePhotoUrl = 'https://fruitofthespirit.templateforwebsites.com/$photoPath';
                      }
                    }
                    
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundImage: profilePhotoUrl != null ? NetworkImage(profilePhotoUrl) : null,
                        backgroundColor: Colors.grey[300],
                        child: profilePhotoUrl == null
                            ? Text(
                                userName.isNotEmpty ? userName[0].toUpperCase() : 'A',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      title: Text(
                        userName,
                        style: TextStyle(
                          fontSize: ResponsiveHelper.fontSize(context, mobile: 15),
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                      ),
                      subtitle: Text(
                        _getTimeAgo(user['created_at'] as String?),
                        style: TextStyle(
                          fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                          color: Colors.grey[600],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEmojiPicker(BuildContext context, int prayerId, PrayersController controller) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Choose an Emoji',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5F4628),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF5F4628)),
                  onPressed: (){
                    final dialogContext = Get.overlayContext;
                    if (dialogContext != null) {
                      Navigator.of(dialogContext, rootNavigator: true).pop();
                    } else if (context.mounted) {
                      Navigator.of(context, rootNavigator: true).pop();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Obx(() {
                if (controller.availableEmojis.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF9F9467),
                    ),
                  );
                }
                
                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: controller.availableEmojis.length,
                  itemBuilder: (context, index) {
                    final emoji = controller.availableEmojis[index];
                    // Try multiple fallbacks: emoji_char -> code -> name (base fruit name)
                    String? emojiChar = emoji['emoji_char'] as String?;
                    if (emojiChar == null || emojiChar.trim().isEmpty) {
                      emojiChar = emoji['code'] as String?;
                    }
                    if (emojiChar == null || emojiChar.trim().isEmpty) {
                      // Try to extract base fruit name from name field
                      final name = emoji['name'] as String? ?? '';
                      if (name.isNotEmpty) {
                        // Extract base fruit name (e.g., "Goodness Banana (1)" -> "goodness")
                        String baseName = name.toLowerCase();
                        if (baseName.contains(':')) {
                          final parts = baseName.split(':');
                          if (parts.length > 1) {
                            baseName = parts[1].trim();
                          }
                        }
                        if (baseName.contains(' ')) {
                          baseName = baseName.split(' ')[0].trim();
                        }
                        emojiChar = baseName;
                      }
                    }
                    
                    // If still empty, skip this emoji (don't make it clickable)
                    final isValidEmoji = emojiChar != null && emojiChar.trim().isNotEmpty;
                    
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: isValidEmoji ? () async {
                          final success = await controller.addEmojiReaction(prayerId, emojiChar!);
                          if (success) {
                            // Show success message FIRST (before closing dialog)
                            if (mounted) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) {
                                  Get.snackbar(
                                    'Success',
                                    'Reaction added',
                                    backgroundColor: Colors.green,
                                    colorText: Colors.white,
                                    duration: const Duration(seconds: 1),
                                    margin: const EdgeInsets.all(16),
                                  );
                                }
                              });
                            }
                          } else {
                            // Show error message
                            if (mounted) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) {
                                  Get.snackbar(
                                    'Error',
                                    controller.message.value.isNotEmpty 
                                        ? controller.message.value 
                                        : 'Failed to add reaction. Please try again.',
                                    backgroundColor: Colors.red,
                                    colorText: Colors.white,
                                    duration: const Duration(seconds: 2),
                                    margin: const EdgeInsets.all(16),
                                  );
                                }
                              });
                            }
                          }
                          // Wait a bit for snackbar to show, then close dialog
                          await Future.delayed(const Duration(milliseconds: 300));
                          if (mounted && Navigator.canPop(context)) {
                            final dialogContext = Get.overlayContext;
                            if (dialogContext != null) {
                              Navigator.of(dialogContext, rootNavigator: true).pop();
                            } else if (context.mounted) {
                              Navigator.of(context, rootNavigator: true).pop();
                            }
                          }
                        } : null,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey.withOpacity(0.1),
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: SizedBox(
                              width: 32,
                              height: 32,
                              child: HomeScreen.buildEmojiDisplay(
                                context,
                                emoji,
                                size: 32,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
