import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fruitsofspirit/controllers/prayers_controller.dart';
import 'package:fruitsofspirit/routes/routes.dart';
import 'package:fruitsofspirit/services/payment_gate.dart';
import 'package:fruitsofspirit/utils/app_theme.dart';
import 'package:fruitsofspirit/utils/auto_translate_helper.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';
import 'package:fruitsofspirit/widgets/cached_image.dart';
import 'package:get/get.dart';

class SocialMediaPrayerPost extends StatelessWidget {
  const SocialMediaPrayerPost({
    super.key,
    required this.prayer,
    this.showMenu = true,
    this.showPendingBadge = false,
    this.onTap,
  });

  final Map<String, dynamic> prayer;
  final bool showMenu;
  final bool showPendingBadge;
  final VoidCallback? onTap;

  static int prayerIdFrom(Map<String, dynamic> prayer) {
    return prayer['id'] is int
        ? prayer['id'] as int
        : int.tryParse(prayer['id'].toString()) ?? 0;
  }

  static Future<void> openPrayerDetail(BuildContext context, int prayerId) async {
    try {
      final prayersController = Get.isRegistered<PrayersController>()
          ? Get.find<PrayersController>()
          : Get.put(PrayersController(), permanent: true);
      await prayersController.preparePrayerDetails(prayerId);
      await PaymentGate.navigateToFeature(Routes.PRAYER_DETAILS, arguments: prayerId);
    } catch (_) {
      await PaymentGate.navigateToFeature(Routes.PRAYER_DETAILS, arguments: prayerId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAnonymous = prayer['is_anonymous'] == 1 || prayer['is_anonymous'] == true;
    final userName = isAnonymous ? 'Anonymous' : (prayer['user_name'] ?? prayer['name'] ?? 'Anonymous');
    final isPending = prayer['status'] == 'Pending' || prayer['status'] == 'pending';
    String? profilePhotoUrl;
    if (!isAnonymous && prayer['profile_photo'] != null && prayer['profile_photo'].toString().isNotEmpty) {
      final photoPath = prayer['profile_photo'].toString();
      if (photoPath.startsWith('http://') || photoPath.startsWith('https://')) {
        profilePhotoUrl = photoPath;
      } else if (!photoPath.startsWith('assets/') &&
          !photoPath.startsWith('file://') &&
          !photoPath.startsWith('assets/images/')) {
        profilePhotoUrl = 'http://admin.fosmessenger.com/$photoPath';
      }
    }
    final prayerContent = AutoTranslateHelper.getTranslatedTextSync(
      text: prayer['content'] ?? '',
      sourceLanguage: prayer['language'] as String?,
    );
    final responseCount = int.tryParse((prayer['response_count'] ?? 0).toString()) ?? 0;
    final commentCount = int.tryParse((prayer['comment_count'] ?? 0).toString()) ?? 0;
    final category = prayer['category'] as String? ??
        prayer['type'] as String? ??
        prayer['prayer_type'] as String? ??
        'Prayer Request';
    final prayerId = prayerIdFrom(prayer);

    return InkWell(
      onTap: onTap ?? () => unawaited(openPrayerDetail(context, prayerId)),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: ResponsiveHelper.safeMargin(
          context,
          horizontal: 0,
          vertical: ResponsiveHelper.isMobile(context) ? 6 : 8,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.1), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              spreadRadius: 0,
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: ResponsiveHelper.padding(
                    context,
                    all: ResponsiveHelper.isMobile(context) ? 12 : 14,
                  ),
                  child: Row(
                    children: [
                      profilePhotoUrl != null && !isAnonymous
                          ? ClipOval(
                              child: CachedImage(
                                imageUrl: profilePhotoUrl,
                                width: ResponsiveHelper.dim(context, mobile: 36, tablet: 42),
                                height: ResponsiveHelper.dim(context, mobile: 36, tablet: 42),
                                fit: BoxFit.cover,
                                errorWidget: CircleAvatar(
                                  radius: ResponsiveHelper.dim(context, mobile: 18, tablet: 21),
                                  backgroundColor: Colors.grey[200]!,
                                  child: Icon(Icons.person, size: 20, color: Colors.grey[400]),
                                ),
                              ),
                            )
                          : CircleAvatar(
                              radius: ResponsiveHelper.dim(context, mobile: 18, tablet: 21),
                              backgroundColor: Colors.grey[200]!,
                              child: Icon(
                                Icons.person_rounded,
                                size: 20,
                                color: Colors.grey[500],
                              ),
                            ),
                      SizedBox(width: ResponsiveHelper.spacing(context, 10)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              userName,
                              style: ResponsiveHelper.textStyle(
                                context,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            Text(
                              category,
                              style: ResponsiveHelper.textStyle(
                                context,
                                fontSize: 11,
                                color: Colors.grey[500],
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                      if (showMenu)
                        PopupMenuButton<String>(
                          icon: Icon(
                            Icons.more_vert,
                            size: 18,
                            color: Colors.grey[400],
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                            const PopupMenuItem<String>(
                              value: 'view',
                              child: Text('View Details', style: TextStyle(fontSize: 13)),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: ResponsiveHelper.padding(
                    context,
                    horizontal: 12,
                    vertical: 0,
                  ),
                  child: Text(
                    prayerContent,
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: 13,
                      color: Colors.black87,
                    ).copyWith(height: 1.3),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: ResponsiveHelper.padding(
                    context,
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (responseCount > 0)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.favorite, size: 14, color: AppTheme.iconscolor),
                            const SizedBox(width: 4),
                            Text(
                              '$responseCount',
                              style: TextStyle(fontSize: 12, color: AppTheme.iconscolor),
                            ),
                          ],
                        ),
                      if (commentCount > 0)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.comment_outlined, size: 14, color: Colors.grey[400]),
                            const SizedBox(width: 4),
                            Text(
                              '$commentCount',
                              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (showPendingBadge && isPending)
              Positioned(
                top: ResponsiveHelper.isMobile(context) ? 8 : 10,
                right: ResponsiveHelper.isMobile(context) ? 8 : 10,
                child: Container(
                  padding: ResponsiveHelper.padding(
                    context,
                    horizontal: ResponsiveHelper.isMobile(context) ? 8 : 10,
                    vertical: ResponsiveHelper.isMobile(context) ? 5 : 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(
                      ResponsiveHelper.borderRadius(
                        context,
                        mobile: 16,
                        tablet: 20,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.pending,
                        size: ResponsiveHelper.iconSize(context, mobile: 12),
                        color: Colors.white,
                      ),
                      SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                      Text(
                        'Pending',
                        style: ResponsiveHelper.textStyle(
                          context,
                          fontSize: ResponsiveHelper.fontSize(context, mobile: 10),
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ProfilePrayersCarousel extends StatelessWidget {
  const ProfilePrayersCarousel({
    super.key,
    required this.prayers,
    this.showMenu = false,
    this.showPendingBadge = true,
  });

  final List<Map<String, dynamic>> prayers;
  final bool showMenu;
  final bool showPendingBadge;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: ResponsiveHelper.dim(
        context,
        mobile: ResponsiveHelper.screenHeight(context) * 0.21,
        tablet: 190,
        desktop: 210,
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          vertical: ResponsiveHelper.spacing(context, 4),
        ),
        itemCount: prayers.length,
        itemBuilder: (context, index) {
          final prayer = prayers[index];
          return Container(
            width: ResponsiveHelper.dim(
              context,
              mobile: ResponsiveHelper.screenWidth(context) * 0.82,
              tablet: 340,
              desktop: 380,
            ),
            margin: EdgeInsets.only(
              right: ResponsiveHelper.spacing(context, 10),
            ),
            child: SocialMediaPrayerPost(
              prayer: prayer,
              showMenu: showMenu,
              showPendingBadge: showPendingBadge,
            ),
          );
        },
      ),
    );
  }
}
