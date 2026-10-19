import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/controllers/live_stream_controller.dart';
import 'package:fruitsofspirit/utils/app_theme.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';
import 'package:fruitsofspirit/widgets/standard_app_bar.dart';
import 'package:fruitsofspirit/routes/routes.dart';
import 'package:fruitsofspirit/services/payment_gate.dart';

class LiveScreen extends GetView<LiveStreamController> {
  const LiveScreen({Key? key}) : super(key: key);

  static bool _isNavigatingToAgora = false;

  static Future<void> navigateToLive() async {
    final c = Get.find<LiveStreamController>();
    unawaited(c.prepareLive());
    await PaymentGate.navigateToFeature(Routes.LIVE);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: StandardAppBar(
        showBackButton: true,
      ),
      body: ResponsiveHelper.constrainedContent(
        context: context,
        child: Obx(() {
        if (controller.isLoading.value && !controller.hasInitialLoad.value) {
          return const Center(child: CircularProgressIndicator());
        }

        return Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                if (ResponsiveHelper.isDesktop(context)) {
                  return _buildDesktopLayout(context);
                } else if (ResponsiveHelper.isTablet(context)) {
                  return _buildTabletLayout(context);
                } else {
                  return _buildMobileLayout(context);
                }
              },
            ),
            if (controller.isRefreshing.value)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(minHeight: 2),
              ),
          ],
        );
      }),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => controller.getAllLiveStreams(
            silent: controller.hasInitialLoad.value,
            force: true,
          ),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStartStreamSection(context),
            _buildCurrentStreamSection(context),
            _buildStreamList(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTabletLayout(BuildContext context) => _buildMobileLayout(context);

  Widget _buildDesktopLayout(BuildContext context) => _buildMobileLayout(context);

  Widget _buildStartStreamSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Card(
        elevation: 3,
        shadowColor: AppTheme.iconscolor.withValues(alpha: 0.2),
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE53935), Color(0xFFFF7043)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.live_tv, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Broadcast live',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '1. Tap "Go Live Now" below\n'
                '2. Enter a title for your stream\n'
                '3. Tap "Go Live" — your camera will turn on and you\'re live.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  if (_isNavigatingToAgora) return;
                  _showCreateStreamDialog(context);
                },
                icon: const Icon(Icons.videocam),
                label: const Text('Go Live Now'),
                style: AppTheme.primaryButtonStyle(padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStreamSection(BuildContext context) {
    return Obx(() {
      if (controller.currentStream.isEmpty) {
        return const SizedBox.shrink();
      }
      final stream = controller.currentStream;
      final channelName = stream['stream_id'] ?? stream['channel_name'];
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Card(
          color: AppTheme.secondaryColor,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'LIVE',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Your stream is active',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text('Title: ${stream['title'] ?? 'N/A'}', style: const TextStyle(color: AppTheme.textPrimary)),
                Text(
                  'Viewers: ${stream['viewer_count'] ?? 0}',
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (channelName != null && channelName.toString().isNotEmpty)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await PaymentGate.navigateToFeature(Routes.LIVE_AGORA, arguments: {
                              'channel_name': channelName.toString(),
                              'title': stream['title'] ?? 'Live',
                              'description': stream['description'] ?? '',
                              'is_broadcaster': true,
                            });
                            controller.getAllLiveStreams(silent: true);
                          },
                          icon: const Icon(Icons.videocam),
                          label: const Text('Return to stream'),
                        ),
                      ),
                    if (channelName != null && channelName.toString().isNotEmpty)
                      const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final id = stream['stream_id'] ?? channelName;
                          if (id != null) {
                            controller.stopLiveStream(id.toString());
                          }
                        },
                        icon: const Icon(Icons.stop),
                        label: const Text('End stream'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.errorColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  void _showCreateStreamDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();

    Get.dialog(
      AlertDialog(
        backgroundColor: AppTheme.themeColor,
        title: Text('Go Live', style: TextStyle(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Stream Title *',
                labelStyle: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                labelStyle: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: Text('Cancel', style: TextStyle(color: AppTheme.primaryColor)),
          ),
          ElevatedButton(
            style: AppTheme.primaryButtonStyle(),
            onPressed: () async {
              if (titleController.text.trim().isEmpty) {
                Get.snackbar('Error', 'Stream title cannot be empty.', snackPosition: SnackPosition.BOTTOM);
                return;
              }
              Get.back();
              _isNavigatingToAgora = true;
              final uid = controller.userId.value;
              if (uid == 0) {
                Get.snackbar('Error', 'Please login first to go live.', snackPosition: SnackPosition.BOTTOM);
                _isNavigatingToAgora = false;
                return;
              }
              final channelName = 'live_${uid}_${DateTime.now().millisecondsSinceEpoch}';
              await PaymentGate.navigateToFeature(Routes.LIVE_AGORA, arguments: {
                'channel_name': channelName,
                'title': titleController.text.trim(),
                'description': descriptionController.text.trim(),
                'is_broadcaster': true,
              });
              _isNavigatingToAgora = false;
              controller.getAllLiveStreams(silent: true);
            },
            child: const Text('Go Live'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  Widget _buildStreamList(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
          child: Row(
            children: [
              Icon(Icons.live_tv, color: AppTheme.iconscolor, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Live now — tap to watch',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: () => controller.getAllLiveStreams(),
                icon: Icon(Icons.refresh, color: AppTheme.iconscolor),
              ),
            ],
          ),
        ),
        Obx(() {
          if (controller.allLiveStreams.isEmpty && controller.currentStream.isEmpty) {
            return SizedBox(
              height: 180,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.live_tv, size: 48, color: AppTheme.textSecondary),
                    const SizedBox(height: 12),
                    Text(
                      'No one is live right now.',
                      style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pull down to refresh.',
                      style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: controller.allLiveStreams.length,
            itemBuilder: (context, index) {
              final stream = controller.allLiveStreams[index];
              final channelName = stream['stream_id'] ?? stream['channel_name'] ?? stream['channelName'];
              final canJoin = channelName != null && channelName.toString().isNotEmpty;
              final viewerCount = stream['viewer_count'] ?? 0;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                elevation: 2,
                shadowColor: Colors.red.withValues(alpha: 0.15),
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Colors.red.withValues(alpha: 0.35), width: 1),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  leading: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: AppTheme.accentColor,
                        child: Icon(Icons.live_tv, color: AppTheme.iconscolor, size: 28),
                      ),
                      Positioned(
                        right: -4,
                        bottom: -2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withValues(alpha: 0.4),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: const Text(
                            'LIVE',
                            style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                  title: Text(
                    stream['title'] ?? 'Untitled Stream',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
                  subtitle: Text(
                    stream['description']?.toString().isNotEmpty == true
                        ? '${stream['description']} · $viewerCount watching'
                        : '$viewerCount watching',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                  trailing: canJoin
                      ? Icon(Icons.play_circle_filled, color: AppTheme.iconscolor, size: 38)
                      : null,
                  onTap: () async {
                    if (canJoin) {
                      await PaymentGate.navigateToFeature(Routes.LIVE_AGORA, arguments: {
                        'channel_name': channelName.toString(),
                        'title': stream['title'] ?? 'Live',
                        'description': stream['description'] ?? '',
                        'is_broadcaster': false,
                      });
                      controller.getAllLiveStreams(silent: true);
                    }
                  },
                ),
              );
            },
          );
        }),
      ],
    );
  }
}
