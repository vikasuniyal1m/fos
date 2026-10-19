import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fruitsofspirit/controllers/shorts_controller.dart';
import 'package:fruitsofspirit/services/shorts_service.dart';
import 'package:fruitsofspirit/widgets/standard_app_bar.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';
import 'package:fruitsofspirit/utils/app_theme.dart';
import 'package:fruitsofspirit/routes/routes.dart';

/// Saved Shorts Screen
class SavedShortsScreen extends StatefulWidget {
  const SavedShortsScreen({Key? key}) : super(key: key);

  @override
  State<SavedShortsScreen> createState() => _SavedShortsScreenState();
}

class _SavedShortsScreenState extends State<SavedShortsScreen> {
  final controller = Get.find<ShortsController>();

  @override
  void initState() {
    super.initState();
    controller.loadSavedShorts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: const StandardAppBar(showBackButton: true),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: ResponsiveHelper.padding(context, all: 16),
            child: Text(
              'Saved Grace Moments',
              style: ResponsiveHelper.textStyle(context, fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value && controller.savedShorts.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (controller.savedShorts.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.bookmark_border, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('No saved grace moments yet'),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => Get.toNamed(Routes.SHORTS),
                        child: const Text('Browse Grace Moments'),
                      ),
                    ],
                  ),
                );
              }
              return GridView.builder(
                padding: ResponsiveHelper.padding(context, all: 8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 9 / 16,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: controller.savedShorts.length,
                itemBuilder: (context, index) {
                  final short = controller.savedShorts[index];
                  final thumb = ShortsService.getThumbnailUrl(short);
                  return GestureDetector(
                    onTap: () => Get.toNamed(
                      Routes.SHORTS,
                      arguments: {
                        'mode': 'saved',
                        'startIndex': index,
                        'seed': controller.savedShorts.toList(),
                      },
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: thumb != null
                          ? CachedNetworkImage(imageUrl: thumb, fit: BoxFit.cover)
                          : Container(color: Colors.grey.shade300),
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
