import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../utils/app_theme.dart';
import '../utils/responsive_helper.dart';

/// Lightweight network video thumbnail via [video_thumbnail] (not full VideoPlayer).
class CustomVideoThumbnail extends StatefulWidget {
  final String videoUrl;
  final BoxFit fit;
  final double? width;
  final double? height;

  const CustomVideoThumbnail({
    Key? key,
    required this.videoUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  }) : super(key: key);

  @override
  State<CustomVideoThumbnail> createState() => _CustomVideoThumbnailState();
}

class _CustomVideoThumbnailState extends State<CustomVideoThumbnail> {
  static final Map<String, Uint8List> _memoryCache = {};
  static final Map<String, Future<Uint8List?>> _inFlight = {};
  static int _activeLoads = 0;
  static const int _maxConcurrent = 2;
  static final List<Completer<void>> _waitQueue = [];

  Uint8List? _imageBytes;
  bool _hasError = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadThumbnail(widget.videoUrl);
  }

  @override
  void didUpdateWidget(CustomVideoThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _loadThumbnail(widget.videoUrl);
    }
  }

  Future<void> _acquireSlot() async {
    if (_activeLoads < _maxConcurrent) {
      _activeLoads++;
      return;
    }
    final completer = Completer<void>();
    _waitQueue.add(completer);
    await completer.future;
    _activeLoads++;
  }

  void _releaseSlot() {
    _activeLoads = (_activeLoads - 1).clamp(0, 999);
    if (_waitQueue.isNotEmpty) {
      _waitQueue.removeAt(0).complete();
    }
  }

  Future<void> _loadThumbnail(String videoUrl) async {
    if (videoUrl.isEmpty) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _loading = false;
        });
      }
      return;
    }

    final cached = _memoryCache[videoUrl];
    if (cached != null) {
      if (mounted) {
        setState(() {
          _imageBytes = cached;
          _hasError = false;
          _loading = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _loading = true;
        _hasError = false;
        _imageBytes = null;
      });
    }

    final future = _inFlight.putIfAbsent(videoUrl, () async {
      await _acquireSlot();
      try {
        return await VideoThumbnail.thumbnailData(
          video: videoUrl,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 400,
          quality: 70,
          timeMs: 800,
        ).timeout(const Duration(seconds: 20));
      } finally {
        _releaseSlot();
      }
    });

    try {
      final bytes = await future;
      if (bytes != null && bytes.isNotEmpty) {
        _memoryCache[videoUrl] = bytes;
      }
      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _hasError = bytes == null || bytes.isEmpty;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _loading = false;
      });
    } finally {
      _inFlight.remove(videoUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _placeholder(context);
    }

    if (_loading || _imageBytes == null) {
      return Container(
        width: widget.width,
        height: widget.height,
        color: Colors.grey[300],
        child: Center(
          child: CircularProgressIndicator(
            color: AppTheme.iconscolor,
            strokeWidth: 2,
          ),
        ),
      );
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Image.memory(
        _imageBytes!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _placeholder(context),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.themeColor,
            AppTheme.primaryColor.withOpacity(0.3),
          ],
        ),
      ),
      child: Icon(
        Icons.video_library_rounded,
        size: ResponsiveHelper.iconSize(context, mobile: 60, tablet: 70, desktop: 80),
        color: AppTheme.primaryColor,
      ),
    );
  }
}
