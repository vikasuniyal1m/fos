import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import '../services/intro_service.dart';

class TempVideoTestScreen extends StatefulWidget {
  final VoidCallback? onVideoFinished;
  const TempVideoTestScreen({super.key, this.onVideoFinished});

  @override
  State<TempVideoTestScreen> createState() => _TempVideoTestScreenState();
}

class _TempVideoTestScreenState extends State<TempVideoTestScreen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isLandscape = false;
  bool _showCheckbox = false;
  bool _isRotating = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    // Check if intro should be skipped permanently
    if (IntroService.getSkipIntroPermanently()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onVideoFinished?.call();
      });
      return;
    }

    _controller = VideoPlayerController.asset('assets/themsong.mp4')
      ..initialize().then((_) {
        setState(() {
          _isInitialized = true;
        });
        _controller.play();
      });

    _controller.addListener(() async {
      if (_controller.value.position == _controller.value.duration) {
        // Video finished playing
        await IntroService.incrementVideoPlayCount();
        if (mounted) { // Check if the widget is still mounted before calling setState
          setState(() {
            _showCheckbox = IntroService.shouldShowCheckbox();
          });
        }

        if (!IntroService.shouldShowCheckbox()) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onVideoFinished?.call();
          });
        }
      }
    });
  }

  Future<void> _toggleRotation() async {
    // Show black screen instantly
    setState(() {
      _isRotating = true;
    });

    if (_isLandscape) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    } else {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    
    // Minimal delay - maximum speed
    await Future.delayed(const Duration(milliseconds: 100));
    
    if (mounted) {
      setState(() {
        _isLandscape = !_isLandscape;
        _isRotating = false;
      });
    }
  }
  
  Future<void> _saveVideo() async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saving video to gallery...'), duration: Duration(seconds: 1)),
        );
      }

      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) await Gal.requestAccess();

      final byteData = await rootBundle.load('assets/themsong.mp4');
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/themsong.mp4');
      await tempFile.writeAsBytes(byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      ));

      await Gal.putVideo(tempFile.path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Video saved to gallery successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 250.0, left: 16.0, right: 16.0), // Push up from bottom to clear other elements
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save video: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    if (_isInitialized) {
      _controller.dispose();
    }
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
      color: Colors.black.withOpacity(0.7),
      child: Stack(
        children: [
          // Video Player with instant black screen during rotation
          Positioned.fill(
            child: ClipRect(
              child: _isRotating
                  ? Container(color: Colors.black) // Instant black screen
                  : _isInitialized
                      ? Center(
                          child: AspectRatio(
                            aspectRatio: _controller.value.aspectRatio,
                            child: VideoPlayer(_controller),
                          ),
                        )
                      : const Center(
                          child: CircularProgressIndicator(),
                        ),
            ),
          ),
          // Rotate button - hidden during rotation
          if (!_isRotating)
            Positioned(
              bottom: 20,
              right: 20,
              child: IconButton(
                icon: Icon(
                  _isLandscape ? Icons.screen_rotation : Icons.screen_lock_portrait,
                  color: Colors.white,
                  size: 30,
                ),
                onPressed: _toggleRotation,
              ),
            ),
          // Download Button
          if (!_isRotating)
            Positioned(
              top: 40,
              left: 20,
              child: GestureDetector(
                onTap: _saveVideo,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.download_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            ),
          Positioned(
            top: 40,
            right: 20,
            child: TextButton(
              onPressed: () async {
                await IntroService.incrementVideoPlayCount();
                if (mounted) { // Check if the widget is still mounted before calling setState
                  setState(() {
                    _showCheckbox = IntroService.shouldShowCheckbox();
                  });
                }
                if (!IntroService.shouldShowCheckbox()) {
                  widget.onVideoFinished?.call();
                }
              },
              child: const Text(
                'Skip',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ),
          // "Don't show next time" checkbox - hidden during rotation
          if (_showCheckbox && !_isRotating)
            Positioned(
              bottom: 80,
              left: 20,
              child: Material(
                color: Colors.transparent, // Make the material transparent
                child: Row(
                  children: [
                    Checkbox(
                      value: IntroService.getSkipIntroPermanently(),
                      onChanged: (bool? value) async {
                        await IntroService.setSkipIntroPermanently(value ?? false);
                        if (mounted) {
                          setState(() {
                            _showCheckbox = !IntroService.getSkipIntroPermanently(); // Update checkbox visibility based on new state
                          });
                        }
                        if (value == true) {
                          widget.onVideoFinished?.call();
                        }
                      },
                      activeColor: Colors.white,
                      checkColor: Colors.black,
                      fillColor: MaterialStateProperty.resolveWith<Color>((Set<MaterialState> states) {
                        if (states.contains(MaterialState.selected)) {
                          return Colors.white; // Color when checked
                        }
                        return Colors.white; // Color when unchecked
                      }),
                    ),
                    const Text(
                      "Don't show next time",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),

        ],
      ),
    ));
  }
}