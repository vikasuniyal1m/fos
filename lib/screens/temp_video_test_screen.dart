import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    if (mounted) { // Check if the widget is still mounted before calling setState
      setState(() {
        _isLandscape = !_isLandscape;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Stack(
        children: [
          Center(
            child: _isInitialized
                ? AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  )
                : const CircularProgressIndicator(),
          ),
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
          if (_showCheckbox)
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
    );
  }
}