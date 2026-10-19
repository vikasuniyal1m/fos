import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:fruitsofspirit/controllers/shorts_controller.dart';
import 'package:fruitsofspirit/widgets/standard_app_bar.dart';
import 'package:fruitsofspirit/utils/app_theme.dart';
import 'package:fruitsofspirit/utils/permission_manager.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';
import 'package:permission_handler/permission_handler.dart';

/// Upload Short Screen — vertical video, max 30 seconds
class UploadShortScreen extends StatefulWidget {
  const UploadShortScreen({Key? key}) : super(key: key);

  @override
  State<UploadShortScreen> createState() => _UploadShortScreenState();
}

class _UploadShortScreenState extends State<UploadShortScreen> {
  static const int _maxSeconds = ShortsController.maxShortDurationSeconds;
  static const Color _gold = Color(0xFFD4AF37);

  final controller = Get.find<ShortsController>();
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final _picker = ImagePicker();

  File? selectedVideo;
  File? thumbnailFile;
  VideoPlayerController? _previewController;
  int _duration = 0;
  bool _isPicking = false;
  bool _isPreviewLoading = false;
  String? _durationError;

  bool get _isDurationValid => _duration > 0 && _duration <= _maxSeconds;
  bool get _canUpload => selectedVideo != null && _isDurationValid && !controller.isUploading.value;
  bool get _hasVideoPreview =>
      selectedVideo != null &&
      _previewController != null &&
      _previewController!.value.isInitialized;

  double _previewMaxHeight(BuildContext context) {
    if (!_hasVideoPreview) {
      return ResponsiveHelper.dim(context, mobile: 120, tablet: 132, desktop: 148);
    }
    return ResponsiveHelper.dim(
      context,
      mobile: ResponsiveHelper.screenHeight(context) * 0.48,
      tablet: 420,
      desktop: 460,
    );
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    _previewController?.dispose();
    super.dispose();
  }

  Future<bool> _ensureMediaPermission(ImageSource source) async {
    if (source == ImageSource.gallery) {
      final ok = await PermissionManager.requestGalleryVideoPermission();
      if (ok) return true;
      if (!mounted) return false;
      if (await PermissionManager.isGalleryVideoPermissionDeniedForever()) {
        _snack('Gallery blocked — allow Photos/Videos in Settings', error: true);
        await openAppSettings();
      } else {
        _snack('Allow gallery access to pick downloaded videos', error: true);
      }
      return false;
    }

    final cameraOk = await PermissionManager.requestCameraPermission();
    if (!cameraOk) {
      if (mounted) _snack('Allow camera access to record', error: true);
      return false;
    }
    await PermissionManager.requestMicrophonePermission();
    return true;
  }

  Future<void> _pickVideo(ImageSource source) async {
    if (_isPicking) return;
    if (!await _ensureMediaPermission(source)) return;

    setState(() {
      _isPicking = true;
      _durationError = null;
    });

    try {
      final picked = await _picker.pickVideo(
        source: source,
        maxDuration: source == ImageSource.camera ? Duration(seconds: _maxSeconds) : null,
      );
      if (picked == null) return;
      await _loadVideoPreview(File(picked.path));
    } catch (e) {
      if (mounted) {
        _snack('Could not open gallery. Check permission and try again.', error: true);
      }
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  Future<void> _loadVideoPreview(File file) async {
    setState(() {
      selectedVideo = file;
      _isPreviewLoading = true;
      _durationError = null;
      thumbnailFile = null;
    });

    _previewController?.dispose();
    _previewController = VideoPlayerController.file(file);

    try {
      await _previewController!.initialize();
      _duration = _previewController!.value.duration.inSeconds;
      if (_duration <= 0) _duration = 1;

      if (_duration > _maxSeconds) {
        _durationError = 'Video is ${_duration}s. Grace moments must be $_maxSeconds seconds or less.';
        await _previewController?.dispose();
        _previewController = null;
        if (mounted) {
          setState(() {
            selectedVideo = null;
            _isPreviewLoading = false;
          });
        }
        return;
      }

      await _previewController!.setLooping(true);
      await _previewController!.play();

      await PermissionManager.requestGalleryVideoPermission();
      final thumbPath = await VideoThumbnail.thumbnailFile(
        video: file.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 720,
        quality: 85,
      );
      if (thumbPath != null && mounted) {
        setState(() => thumbnailFile = File(thumbPath));
      }
    } catch (_) {
      _durationError = 'Could not read this video. Try another file.';
      await _previewController?.dispose();
      _previewController = null;
      selectedVideo = null;
    } finally {
      if (mounted) setState(() => _isPreviewLoading = false);
    }
  }

  Future<void> _upload() async {
    if (selectedVideo == null) {
      _snack('Please select a vertical video first', error: true);
      return;
    }
    if (!_isDurationValid) {
      _snack('Video must be between 1 and $_maxSeconds seconds', error: true);
      return;
    }

    final ok = await controller.uploadShort(
      videoFile: selectedVideo!,
      thumbnailFile: thumbnailFile,
      title: titleController.text.trim(),
      description: descriptionController.text.trim(),
      duration: _duration,
    );
    if (ok && mounted) {
      _snack(controller.message.value);
      Get.back();
    } else if (mounted) {
      _snack(controller.message.value, error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppTheme.errorColor : AppTheme.successColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: const StandardAppBar(showBackButton: true),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: ResponsiveHelper.padding(context, horizontal: 16, vertical: 12),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Upload Grace Moment',
                      style: ResponsiveHelper.textStyle(context, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(context, 12)),
                    _buildGuidelinesCard(context),
                    SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                    _buildPreviewArea(context),
                    if (_durationError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _durationError!,
                        style: ResponsiveHelper.textStyle(context, fontSize: 13, color: Colors.red),
                      ),
                    ],
                    SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                    _buildPickButtons(context),
                    SizedBox(height: ResponsiveHelper.spacing(context, 20)),
                    TextField(
                      controller: titleController,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Title (optional)',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Description (optional)',
                        filled: true,
                        fillColor: Colors.white,
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(context, 24)),
                    Obx(() => SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _canUpload ? _upload : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _gold,
                              disabledBackgroundColor: Colors.grey.shade300,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: controller.isUploading.value
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : Text(
                                    'Upload Grace Moment',
                                    style: ResponsiveHelper.textStyle(
                                      context,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        )),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildGuidelinesCard(BuildContext context) {
    return Container(
      padding: ResponsiveHelper.padding(context, all: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _gold.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: _gold, size: ResponsiveHelper.iconSize(context, mobile: 22)),
          SizedBox(width: ResponsiveHelper.spacing(context, 10)),
          Expanded(
            child: Text(
              'Vertical video only • Max $_maxSeconds seconds • MP4/MOV recommended',
              style: ResponsiveHelper.textStyle(context, fontSize: 13, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewArea(BuildContext context) {
    final maxHeight = _previewMaxHeight(context);
    final hasPreview = _hasVideoPreview;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: Alignment.center,
      child: AspectRatio(
        aspectRatio: 9 / 16,
        child: Container(
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasPreview)
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _previewController!.value.size.width,
                    height: _previewController!.value.size.height,
                    child: VideoPlayer(_previewController!),
                  ),
                )
              else
                Container(
                  color: Colors.grey.shade900,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.video_library_outlined,
                        size: hasPreview ? 56 : 36,
                        color: Colors.white.withOpacity(0.7),
                      ),
                      SizedBox(height: hasPreview ? 12 : 8),
                      Text(
                        'Tap Gallery for downloaded videos',
                        textAlign: TextAlign.center,
                        style: ResponsiveHelper.textStyle(
                          context,
                          fontSize: hasPreview ? 14 : 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
            if (_isPicking || _isPreviewLoading)
              Container(
                color: Colors.black45,
                child: const Center(child: CircularProgressIndicator(color: _gold)),
              ),
            if (_duration > 0)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _isDurationValid ? Colors.black54 : Colors.red.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _formatDuration(_duration),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPickButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isPicking ? null : () => _pickVideo(ImageSource.gallery),
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Gallery'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isPicking ? null : () => _pickVideo(ImageSource.camera),
            icon: const Icon(Icons.videocam_outlined, color: Colors.white),
            label: const Text('Record', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _gold,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }
}
