import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/widgets/standard_app_bar.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';
import 'package:fruitsofspirit/utils/app_theme.dart';
import 'package:fruitsofspirit/services/live_streaming_service.dart';
import 'package:fruitsofspirit/screens/video_details_screen.dart'; // Assuming live streams are played via VideoDetailsScreen
import 'package:fruitsofspirit/routes/routes.dart';

class LiveScreen extends StatefulWidget {
  const LiveScreen({Key? key}) : super(key: key);

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  var _liveStreams = <Map<String, dynamic>>[].obs;
  var _isLoading = true.obs;
  var _errorMessage = ''.obs;

  @override
  void initState() {
    super.initState();
    _fetchLiveStreams();
  }

  Future<void> _fetchLiveStreams() async {
    try {
      _isLoading.value = true;
      _errorMessage.value = '';
      final streams = await LiveStreamingService.getLiveStreams();
      _liveStreams.assignAll(streams);
    } catch (e) {
      _errorMessage.value = 'Failed to load live streams: $e';
      print('Error fetching live streams: $e');
    } finally {
      _isLoading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.themeColor,
      appBar: AppBar(
        title: const Text('Live Streams'),
        backgroundColor: AppTheme.themeColor,
        foregroundColor: AppTheme.iconscolor,
      ),
      body: Obx(() {
        if (_isLoading.value) {
          return Center(
            child: CircularProgressIndicator(color: AppTheme.iconscolor),
          );
        }

        if (_errorMessage.value.isNotEmpty) {
          return Center(
            child: Text(
              _errorMessage.value,
              style: ResponsiveHelper.textStyle(context, color: Colors.red, fontSize: ResponsiveHelper.fontSize(context, mobile: 14)),
            ),
          );
        }

        if (_liveStreams.isEmpty) {
          return Center(
            child: Text(
              'No live streams currently available.',
              style: ResponsiveHelper.textStyle(context, fontSize: ResponsiveHelper.fontSize(context, mobile: 16)),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _fetchLiveStreams,
          color: AppTheme.iconscolor,
          child: ListView.builder(
            padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 16)),
            itemCount: _liveStreams.length,
            itemBuilder: (context, index) {
              final stream = _liveStreams[index];
              return _buildLiveStreamCard(context, stream);
            },
          ),
        );
      }),
    );
  }

  Widget _buildLiveStreamCard(BuildContext context, Map<String, dynamic> stream) {
    final title = stream['title'] as String? ?? 'Untitled Live Stream';
    final userName = stream['user_name'] as String? ?? 'Unknown User';
    final thumbnailUrl = stream['thumbnail_path'] as String?; // Assuming a thumbnail path exists

    return GestureDetector(
      onTap: () {
        // Navigate to VideoDetailsScreen to play the live stream
        // Assuming VideoDetailsScreen can handle live stream IDs or URLs
        Get.toNamed(Routes.VIDEO_DETAILS, arguments: stream['id']);
      },
      child: Card(
        margin: EdgeInsets.only(bottom: ResponsiveHelper.spacing(context, 16)),
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                if (thumbnailUrl != null)
                  Image.network(
                    'https://fruitofthespirit.templateforwebsites.com/$thumbnailUrl', // Adjust base URL if needed
                    height: ResponsiveHelper.imageHeight(context, mobile: 200),
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: ResponsiveHelper.imageHeight(context, mobile: 200),
                      color: Colors.grey[300],
                      child: Center(
                        child: Icon(Icons.live_tv, size: ResponsiveHelper.iconSize(context, mobile: 64), color: Colors.grey[600]),
                      ),
                    ),
                  )
                else
                  Container(
                    height: ResponsiveHelper.imageHeight(context, mobile: 200),
                    color: Colors.grey[300],
                    child: Center(
                      child: Icon(Icons.live_tv, size: ResponsiveHelper.iconSize(context, mobile: 64), color: Colors.grey[600]),
                    ),
                  ),
                Positioned(
                  top: ResponsiveHelper.spacing(context, 8),
                  left: ResponsiveHelper.spacing(context, 8),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveHelper.spacing(context, 8),
                      vertical: ResponsiveHelper.spacing(context, 4),
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
                    ),
                    child: Text(
                      'LIVE',
                      style: ResponsiveHelper.textStyle(
                        context,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(context, 4)),
                  Text(
                    'By $userName',
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                      color: Colors.grey[600],
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
}
