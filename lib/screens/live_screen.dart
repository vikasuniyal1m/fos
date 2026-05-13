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

  // Flag to prevent auto-opening dialog when returning from agora screen
  static bool _isNavigatingToAgora = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: StandardAppBar(
        showBackButton: true,
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        // Always show live streaming UI (Go Live, list). Don't replace body with message.
        return LayoutBuilder(
          builder: (context, constraints) {
            if (ResponsiveHelper.isDesktop(context)) {
              return _buildDesktopLayout(context);
            } else if (ResponsiveHelper.isTablet(context)) {
              return _buildTabletLayout(context);
            } else {
              return _buildMobileLayout(context);
            }
          },
        );
      }),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStartStreamSection(context),
          _buildCurrentStreamSection(context),
          _buildStreamList(context),
        ],
      ),
    );
  }

  Widget _buildTabletLayout(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStartStreamSection(context),
          _buildCurrentStreamSection(context),
          _buildStreamList(context),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStartStreamSection(context),
          _buildCurrentStreamSection(context),
          _buildStreamList(context),
        ],
      ),
    );
  }

  Widget _buildStartStreamSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Card(
        elevation: 2,
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.live_tv, color: AppTheme.iconscolor, size: 28),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Broadcast live ',
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
                  // Prevent dialog from auto-opening when returning from agora screen
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
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Card(
          color: AppTheme.secondaryColor,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Live Stream',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 10),
                Text('Title: ${stream['title'] ?? 'N/A'}', style: const TextStyle(color: AppTheme.textPrimary)),
                Text('Status: ${stream['status'] ?? 'N/A'}', style: const TextStyle(color: AppTheme.textSecondary)),
                Text('Viewers: ${stream['viewer_count'] ?? 0}', style: const TextStyle(color: AppTheme.textSecondary)),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () {
                    controller.stopLiveStream(stream['stream_id']);
                  },
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop Stream'),
                  style: AppTheme.primaryButtonStyle(),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  void _showCreateStreamDialog(BuildContext context) {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    final TextEditingController categoryController = TextEditingController();

    Get.dialog(
      AlertDialog(
        backgroundColor: AppTheme.themeColor,
        title: Text('Create New Live Stream', style: TextStyle(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: 'Stream Title',
                labelStyle: const TextStyle(color: AppTheme.textSecondary),
              ),
            ),
            TextField(
              controller: descriptionController,
              decoration: InputDecoration(
                labelText: 'Description (Optional)',
                labelStyle: const TextStyle(color: AppTheme.textSecondary),
              ),
            ),
            TextField(
              controller: categoryController,
              decoration: InputDecoration(
                labelText: 'Category (Optional)',
                labelStyle: const TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Get.back();
            },
            child: Text('Cancel', style: TextStyle(color: AppTheme.primaryColor)),
          ),
          ElevatedButton(
            style: AppTheme.primaryButtonStyle(),
            onPressed: () async {
              if (titleController.text.isEmpty) {
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
                'title': titleController.text,
                'is_broadcaster': true,
              });
              _isNavigatingToAgora = false;
            },
            child: const Text('Go Live (Agora)'),
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
              Text(
                'Live now — tap to watch',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
              ),
            ],
          ),
        ),
        RefreshIndicator(
          onRefresh: () => controller.getAllLiveStreams(),
          child: controller.allLiveStreams.isEmpty && controller.currentStream.isEmpty
              ? SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
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
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: () => controller.getAllLiveStreams(),
                            icon: Icon(Icons.refresh, size: 20, color: AppTheme.iconscolor),
                            label: Text('Refresh', style: TextStyle(color: AppTheme.primaryColor)),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: controller.allLiveStreams.length,
                  itemBuilder: (context, index) {
                    final stream = controller.allLiveStreams[index];
                    final channelName = stream['stream_id'] ?? stream['channel_name'] ?? stream['channelName'];
                    final canJoin = channelName != null && channelName.toString().isNotEmpty;
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      color: Colors.white,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.accentColor,
                          child: Icon(Icons.live_tv, color: AppTheme.iconscolor, size: 28),
                        ),
                        title: Text(
                          stream['title'] ?? 'Untitled Stream',
                          style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                        ),
                        subtitle: Text(
                          stream['description']?.toString().isNotEmpty == true
                              ? (stream['description'] as String)
                              : 'Tap to watch live',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppTheme.textSecondary),
                        ),
                        trailing: canJoin
                            ? Icon(Icons.play_circle_filled, color: AppTheme.iconscolor, size: 36)
                            : null,
                        onTap: () async {
                          if (canJoin) {
                            await PaymentGate.navigateToFeature(Routes.LIVE_AGORA, arguments: {
                              'channel_name': channelName.toString(),
                              'title': stream['title'] ?? 'Live',
                              'is_broadcaster': false,
                            });
                          }
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

