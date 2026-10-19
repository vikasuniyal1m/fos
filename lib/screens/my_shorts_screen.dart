import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fruitsofspirit/controllers/shorts_controller.dart';
import 'package:fruitsofspirit/services/shorts_service.dart';
import 'package:fruitsofspirit/widgets/standard_app_bar.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';
import 'package:fruitsofspirit/utils/app_theme.dart';
import 'package:fruitsofspirit/routes/routes.dart';

/// Profile screen listing the current user's uploaded shorts
class MyShortsScreen extends StatefulWidget {
  const MyShortsScreen({Key? key}) : super(key: key);

  @override
  State<MyShortsScreen> createState() => _MyShortsScreenState();
}

class _MyShortsScreenState extends State<MyShortsScreen> {
  final controller = Get.find<ShortsController>();

  @override
  void initState() {
    super.initState();
    controller.loadMyShorts(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const StandardAppBar(showBackButton: true),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Get.toNamed(Routes.UPLOAD_SHORT),
        backgroundColor: const Color(0xFFD4AF37),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: ResponsiveHelper.padding(context, all: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My Grace Moments',
                  style: ResponsiveHelper.textStyle(context, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your uploaded grace moments including pending approval',
                  style: ResponsiveHelper.textStyle(context, fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value && controller.myShorts.isEmpty) {
                return Center(child: CircularProgressIndicator(color: AppTheme.iconscolor));
              }
              if (controller.myShorts.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.video_library_outlined, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('You have not uploaded any grace moments yet'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => Get.toNamed(Routes.UPLOAD_SHORT),
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                        child: const Text('Upload Grace Moment', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
              }
              return GridView.builder(
                padding: ResponsiveHelper.padding(context, all: 12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 9 / 16,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: controller.myShorts.length,
                itemBuilder: (context, index) {
                  final short = controller.myShorts[index];
                  final thumb = ShortsService.getThumbnailUrl(short);
                  final status = short['status']?.toString() ?? '';
                  return GestureDetector(
                    onTap: () => Get.toNamed(
                      Routes.SHORTS,
                      arguments: {
                        'mode': 'mine',
                        'startIndex': index,
                        'seed': controller.myShorts.toList(),
                      },
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (thumb != null)
                            CachedNetworkImage(imageUrl: thumb, fit: BoxFit.cover)
                          else
                            Container(color: Colors.grey.shade300),
                          if (status == 'Pending')
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Pending',
                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          Positioned(
                            left: 8,
                            right: 8,
                            bottom: 8,
                            child: Text(
                              short['title']?.toString() ?? 'Grace Moment',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}
