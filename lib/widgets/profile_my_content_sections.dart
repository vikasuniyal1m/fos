import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fruitsofspirit/controllers/blogs_controller.dart';
import 'package:fruitsofspirit/controllers/gallery_controller.dart';
import 'package:fruitsofspirit/controllers/home_controller.dart';
import 'package:fruitsofspirit/controllers/prayers_controller.dart';
import 'package:fruitsofspirit/controllers/shorts_controller.dart';
import 'package:fruitsofspirit/routes/routes.dart';
import 'package:fruitsofspirit/services/blogs_service.dart';
import 'package:fruitsofspirit/services/gallery_service.dart';
import 'package:fruitsofspirit/services/payment_gate.dart';
import 'package:fruitsofspirit/services/prayers_service.dart';
import 'package:fruitsofspirit/services/shorts_service.dart';
import 'package:fruitsofspirit/services/user_storage.dart';
import 'package:fruitsofspirit/utils/app_theme.dart';
import 'package:fruitsofspirit/utils/image_helper.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';
import 'package:fruitsofspirit/widgets/social_media_prayer_post.dart';
import 'package:get/get.dart';

class ProfileContentSectionCard extends StatelessWidget {
  const ProfileContentSectionCard({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: ResponsiveHelper.padding(context, all: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: ResponsiveHelper.textStyle(context, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class ProfileMyShortsSection extends StatefulWidget {
  const ProfileMyShortsSection({super.key});

  @override
  State<ProfileMyShortsSection> createState() => _ProfileMyShortsSectionState();
}

class _ProfileMyShortsSectionState extends State<ProfileMyShortsSection> {
  late final ShortsController _shortsController;

  @override
  void initState() {
    super.initState();
    _shortsController = Get.isRegistered<ShortsController>()
        ? Get.find<ShortsController>()
        : Get.put(ShortsController(), permanent: false);
    unawaited(_shortsController.loadMyShorts(refresh: true));
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final myShorts = _shortsController.myShorts.take(8).toList();
      return ProfileContentSectionCard(
        title: 'My Grace Moments',
        children: [
          if (_shortsController.isLoading.value && myShorts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (myShorts.isEmpty)
            _emptyState(
              context,
              message: 'Upload your first grace moment',
              buttonLabel: 'Upload Grace Moment',
              icon: Icons.upload,
              onCreate: () => Get.toNamed(Routes.UPLOAD_SHORT),
            )
          else
            _previewWithActions(
              context,
              preview: _horizontalPreview(
                context,
                itemCount: myShorts.length,
                itemBuilder: (index) {
                  final short = myShorts[index];
                  final thumb = ShortsService.getThumbnailUrl(short);
                  final status = short['status']?.toString() ?? '';
                  return GestureDetector(
                    onTap: () => Get.toNamed(
                      Routes.SHORTS,
                      arguments: {
                        'mode': 'mine',
                        'startIndex': index,
                        'seed': _shortsController.myShorts.toList(),
                      },
                    ),
                    child: _mediaTile(
                      context,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (thumb != null)
                            CachedNetworkImage(imageUrl: thumb, fit: BoxFit.cover)
                          else
                            Container(color: Colors.grey.shade300),
                          if (status == 'Pending') _pendingBadge(),
                          const Center(child: Icon(Icons.play_arrow, color: Colors.white, size: 28)),
                        ],
                      ),
                    ),
                  );
                },
              ),
              viewAllLabel: 'View All My Grace Moments',
              onViewAll: () => Get.toNamed(Routes.MY_SHORTS),
              createLabel: 'Upload',
              onCreate: () => Get.toNamed(Routes.UPLOAD_SHORT),
            ),
        ],
      );
    });
  }
}

class ProfileSavedShortsSection extends StatefulWidget {
  const ProfileSavedShortsSection({super.key});

  @override
  State<ProfileSavedShortsSection> createState() => _ProfileSavedShortsSectionState();
}

class _ProfileSavedShortsSectionState extends State<ProfileSavedShortsSection> {
  late final ShortsController _shortsController;

  @override
  void initState() {
    super.initState();
    _shortsController = Get.isRegistered<ShortsController>()
        ? Get.find<ShortsController>()
        : Get.put(ShortsController(), permanent: false);
    unawaited(_shortsController.loadSavedShorts(silent: _shortsController.savedShorts.isNotEmpty));
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final saved = _shortsController.savedShorts.take(8).toList();
      return ProfileContentSectionCard(
        title: 'Saved Grace Moments',
        children: [
          if (_shortsController.isLoading.value && saved.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (saved.isEmpty)
            _emptyState(
              context,
              message: 'Save grace moments to watch them later',
              buttonLabel: 'Browse Grace Moments',
              icon: Icons.play_circle_outline,
              onCreate: () => Get.toNamed(Routes.SHORTS),
            )
          else
            _previewWithActions(
              context,
              preview: _horizontalPreview(
                context,
                itemCount: saved.length,
                itemBuilder: (index) {
                  final short = saved[index];
                  final thumb = ShortsService.getThumbnailUrl(short);
                  return GestureDetector(
                    onTap: () => Get.toNamed(
                      Routes.SHORTS,
                      arguments: {
                        'mode': 'saved',
                        'startIndex': index,
                        'seed': _shortsController.savedShorts.toList(),
                      },
                    ),
                    child: _mediaTile(
                      context,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (thumb != null)
                            CachedNetworkImage(imageUrl: thumb, fit: BoxFit.cover)
                          else
                            Container(color: Colors.grey.shade300),
                          const Center(
                            child: Icon(Icons.bookmark, color: Colors.white, size: 22),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              viewAllLabel: 'View All Saved',
              onViewAll: () => Get.toNamed(Routes.SAVED_SHORTS),
              createLabel: 'Browse',
              onCreate: () => Get.toNamed(Routes.SHORTS),
            ),
        ],
      );
    });
  }
}

class ProfileMyPrayersSection extends StatefulWidget {
  const ProfileMyPrayersSection({super.key, required this.userId});

  final int userId;

  @override
  State<ProfileMyPrayersSection> createState() => _ProfileMyPrayersSectionState();
}

class _ProfileMyPrayersSectionState extends State<ProfileMyPrayersSection> {
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (widget.userId <= 0) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final currentUserId = await UserStorage.getUserId();
      final list = await PrayersService.getPrayers(
        status: 'Approved,Pending',
        userId: widget.userId,
        currentUserId: currentUserId,
        limit: 8,
      );
      if (mounted) setState(() => _items = list);
    } catch (_) {
      if (mounted) setState(() => _items = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ProfileContentSectionCard(
      title: 'My Prayers',
      children: [
        if (_loading && _items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_items.isEmpty)
          _emptyState(
            context,
            message: 'Share your first prayer request',
            buttonLabel: 'Create Prayer',
            icon: Icons.add,
            onCreate: () => PaymentGate.navigateToFeature(Routes.CREATE_PRAYER),
          )
        else
          _previewWithActions(
            context,
            preview: ProfilePrayersCarousel(prayers: _items),
            viewAllLabel: 'View All My Prayers',
            onViewAll: () => _navigateToUserPrayers(context, widget.userId),
            createLabel: 'Create',
            onCreate: () => PaymentGate.navigateToFeature(Routes.CREATE_PRAYER),
          ),
      ],
    );
  }
}

class ProfileMyBlogsSection extends StatefulWidget {
  const ProfileMyBlogsSection({super.key, required this.userId});

  final int userId;

  @override
  State<ProfileMyBlogsSection> createState() => _ProfileMyBlogsSectionState();
}

class _ProfileMyBlogsSectionState extends State<ProfileMyBlogsSection> {
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (widget.userId <= 0) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final currentUserId = await UserStorage.getUserId();
      final list = await BlogsService.getBlogs(
        status: 'Approved,Pending',
        userId: widget.userId,
        currentUserId: currentUserId,
        limit: 8,
      );
      if (mounted) setState(() => _items = list);
    } catch (_) {
      if (mounted) setState(() => _items = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ProfileContentSectionCard(
      title: 'My Blogs',
      children: [
        if (_loading && _items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_items.isEmpty)
          _emptyState(
            context,
            message: 'Write your first blog post',
            buttonLabel: 'Create Blog',
            icon: Icons.edit,
            onCreate: () => PaymentGate.navigateToFeature(Routes.CREATE_BLOG),
          )
        else
          _previewWithActions(
            context,
            preview: _horizontalPreview(
              context,
              itemCount: _items.length,
              itemBuilder: (index) {
                final blog = _items[index];
                final imageUrl = ImageHelper.resolveBlogImageUrl(blog);
                final status = blog['status']?.toString() ?? '';
                final blogId = blog['id'] is int
                    ? blog['id'] as int
                    : int.tryParse(blog['id'].toString()) ?? 0;
                return GestureDetector(
                  onTap: () => PaymentGate.navigateToFeature(
                    Routes.BLOG_DETAILS,
                    arguments: blogId,
                  ),
                  child: _mediaTile(
                    context,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (imageUrl != null && imageUrl.isNotEmpty)
                          CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover)
                        else
                          Container(
                            color: Colors.grey.shade200,
                            padding: const EdgeInsets.all(8),
                            alignment: Alignment.bottomLeft,
                            child: Text(
                              (blog['title'] ?? 'Blog').toString(),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: ResponsiveHelper.textStyle(context, fontSize: 11),
                            ),
                          ),
                        if (status == 'Pending') _pendingBadge(),
                      ],
                    ),
                  ),
                );
              },
            ),
            viewAllLabel: 'View All My Blogs',
            onViewAll: () => _navigateToUserBlogs(context, widget.userId),
            createLabel: 'Create',
            onCreate: () => PaymentGate.navigateToFeature(Routes.CREATE_BLOG),
          ),
      ],
    );
  }
}

class ProfileMyMediaSection extends StatefulWidget {
  const ProfileMyMediaSection({super.key, required this.userId});

  final int userId;

  @override
  State<ProfileMyMediaSection> createState() => _ProfileMyMediaSectionState();
}

class _ProfileMyMediaSectionState extends State<ProfileMyMediaSection> {
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (widget.userId <= 0) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final currentUserId = await UserStorage.getUserId();
      final list = await GalleryService.getPhotos(
        status: 'Approved,Pending',
        userId: widget.userId,
        currentUserId: currentUserId,
        limit: 8,
      );
      if (mounted) setState(() => _items = list);
    } catch (_) {
      if (mounted) setState(() => _items = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ProfileContentSectionCard(
      title: 'My Media',
      children: [
        if (_loading && _items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_items.isEmpty)
          _emptyState(
            context,
            message: 'Upload your first photo',
            buttonLabel: 'Upload Photo',
            icon: Icons.photo_camera,
            onCreate: () => PaymentGate.navigateToFeature(Routes.UPLOAD_PHOTO),
          )
        else
          _previewWithActions(
            context,
            preview: _horizontalPreview(
              context,
              itemCount: _items.length,
              itemBuilder: (index) {
                final photo = _items[index];
                final imageUrl = ImageHelper.resolveGalleryPhotoUrl(photo);
                final status = photo['status']?.toString() ?? '';
                final photoId = photo['id'];
                return GestureDetector(
                  onTap: () => GalleryController.openPhotoDetail(
                    photoId,
                    previewPhoto: photo,
                  ),
                  child: _mediaTile(
                    context,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (imageUrl != null && imageUrl.isNotEmpty)
                          CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover)
                        else
                          Container(color: Colors.grey.shade300),
                        if (status == 'Pending') _pendingBadge(),
                      ],
                    ),
                  ),
                );
              },
            ),
            viewAllLabel: 'View All My Media',
            onViewAll: () => _navigateToUserGallery(context, widget.userId),
            createLabel: 'Upload',
            onCreate: () => PaymentGate.navigateToFeature(Routes.UPLOAD_PHOTO),
          ),
      ],
    );
  }
}

Widget _emptyState(
  BuildContext context, {
  required String message,
  required String buttonLabel,
  required IconData icon,
  required VoidCallback onCreate,
}) {
  return Padding(
    padding: ResponsiveHelper.padding(context, vertical: 12),
    child: Column(
      children: [
        Text(
          message,
          style: ResponsiveHelper.textStyle(context, fontSize: 14, color: Colors.grey[600]),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onCreate,
          icon: Icon(icon),
          label: Text(buttonLabel),
        ),
      ],
    ),
  );
}

Widget _previewWithActions(
  BuildContext context, {
  required Widget preview,
  required String viewAllLabel,
  required VoidCallback onViewAll,
  required String createLabel,
  required VoidCallback onCreate,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      preview,
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onViewAll,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  viewAllLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          TextButton.icon(
            onPressed: onCreate,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.add, size: 18),
            label: Text(
              createLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    ],
  );
}

Widget _horizontalPreview(
  BuildContext context, {
  required int itemCount,
  required Widget Function(int index) itemBuilder,
}) {
  return SizedBox(
    height: ResponsiveHelper.dim(context, mobile: 140, tablet: 160),
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: itemCount,
      separatorBuilder: (_, __) => SizedBox(width: ResponsiveHelper.spacing(context, 10)),
      itemBuilder: (context, index) => itemBuilder(index),
    ),
  );
}

Widget _mediaTile(BuildContext context, {required Widget child}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: SizedBox(
      width: ResponsiveHelper.dim(context, mobile: 90, tablet: 110),
      child: child,
    ),
  );
}

Widget _pendingBadge() {
  return Positioned(
    top: 6,
    left: 6,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      color: Colors.orange,
      child: const Text('Pending', style: TextStyle(color: Colors.white, fontSize: 9)),
    ),
  );
}

Future<void> _navigateToUserPrayers(BuildContext context, int userId) async {
  final prayersController = Get.isRegistered<PrayersController>()
      ? Get.find<PrayersController>()
      : Get.put(PrayersController(), permanent: true);
  prayersController.filterUserId.value = userId;
  if (Get.isRegistered<HomeController>()) {
    prayersController.seedFromHomeIfEmpty(Get.find<HomeController>().prayers.toList());
  }
  prayersController.reapplyFilter();
  unawaited(
    prayersController.loadPrayers(
      refresh: true,
      silent: prayersController.prayers.isNotEmpty,
    ),
  );
  await PaymentGate.navigateToFeature(
    Routes.PRAYER_REQUESTS,
    arguments: {'fromProfile': true, 'filterUserId': userId},
  );
}

Future<void> _navigateToUserBlogs(BuildContext context, int userId) async {
  final blogsController = Get.isRegistered<BlogsController>()
      ? Get.find<BlogsController>()
      : Get.put(BlogsController(), permanent: true);
  blogsController.filterUserId.value = userId;
  blogsController.bootstrapBlogs();
  blogsController.loadFromHiveIfEmpty();
  if (Get.isRegistered<HomeController>()) {
    blogsController.seedFromHomeIfEmpty(Get.find<HomeController>().blogs.toList());
  }
  blogsController.reapplyFilter();
  unawaited(
    blogsController.loadBlogs(
      refresh: true,
      silent: blogsController.blogs.isNotEmpty,
    ),
  );
  await PaymentGate.navigateToFeature(
    Routes.BLOGGER_ZONE,
    arguments: {'fromProfile': true, 'filterUserId': userId},
  );
}

Future<void> _navigateToUserGallery(BuildContext context, int userId) async {
  final galleryController = Get.isRegistered<GalleryController>()
      ? Get.find<GalleryController>()
      : Get.put(GalleryController(), permanent: true);
  galleryController.filterUserId.value = userId;
  galleryController.bootstrapGallery();
  if (Get.isRegistered<HomeController>()) {
    galleryController.seedFromHomeIfEmpty(Get.find<HomeController>().galleryPhotos.toList());
  }
  galleryController.loadFromHiveIfEmpty();
  unawaited(
    galleryController.loadPhotos(
      refresh: true,
      silent: galleryController.photos.isNotEmpty,
    ),
  );
  await PaymentGate.navigateToFeature(
    Routes.GALLERY,
    arguments: {'fromProfile': true, 'filterUserId': userId},
  );
}
