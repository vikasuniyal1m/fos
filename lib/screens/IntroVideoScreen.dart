// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:video_player/video_player.dart';
// import 'package:get/get.dart'; // Import Get for navigation
// import 'package:fruitsofspirit/services/intro_service.dart';
// import 'package:fruitsofspirit/services/user_storage.dart'; // Import UserStorage
// import 'package:fruitsofspirit/routes/routes.dart'; // Import Routes
// import 'dart:async'; // Import for Timer
//
// class IntroVideoScreen extends StatefulWidget {
//   final VoidCallback onClose;
//   const IntroVideoScreen({super.key, required this.onClose});
//
//   @override
//   State<IntroVideoScreen> createState() => _IntroVideoScreenState();
// }
//
// class _IntroVideoScreenState extends State<IntroVideoScreen> {
//   late VideoPlayerController _controller;
//   bool _isLoading = true;
//   bool _skipIntroPermanently = false; // New state for the checkbox
//   bool _showSkipButton = false; // State to control skip button visibility
//   bool _isLandscape = false;
//   Timer? _timer;
//
//   @override
//   void initState() {
//     super.initState();
//     // Initially, let the system handle it, but we'll track state
//     _initializeIntro();
//   }
//
//   Future<void> _toggleRotation() async {
//     if (_isLandscape) {
//       await SystemChrome.setPreferredOrientations([
//         DeviceOrientation.portraitUp,
//       ]);
//     } else {
//       await SystemChrome.setPreferredOrientations([
//         DeviceOrientation.landscapeLeft,
//         DeviceOrientation.landscapeRight,
//       ]);
//     }
//     setState(() {
//       _isLandscape = !_isLandscape;
//     });
//   }
//
//   Future<void> _lockPortrait() async {
//     // Force device back to portrait and lock it
//     await SystemChrome.setPreferredOrientations([
//       DeviceOrientation.portraitUp,
//     ]);
//     // Small delay to ensure OS handles the rotation back before allowing portraitDown
//     await Future.delayed(const Duration(milliseconds: 200));
//     await SystemChrome.setPreferredOrientations([
//       DeviceOrientation.portraitUp,
//       DeviceOrientation.portraitDown,
//     ]);
//   }
//
//   void _videoListener() {
//     debugPrint('🎬 _videoListener called. Position: ${_controller.value.position}, Duration: ${_controller.value.duration}');
//     if (_controller.value.isInitialized &&
//         _controller.value.position >= _controller.value.duration) {
//       _handleClose();
//     }
//   }
//
//   Future<void> _initializeIntro() async {
//     debugPrint('🎬 _initializeIntro called');
//     try {
//       // Get initial state of skipIntroPermanently
//       _skipIntroPermanently = IntroService.getSkipIntroPermanently();
//
//       // 2. Initialize Video
//       _controller = VideoPlayerController.asset('assets/themsong.mp4');
//
//       await _controller.initialize();
//       debugPrint('🎬 After controller initialize. isInitialized: ${_controller.value.isInitialized}, hasError: ${_controller.value.hasError}');
//
//       if (!mounted) return;
//
//       debugPrint('🎬 Video controller initialized: ${_controller.value.isInitialized}');
//       debugPrint('🎬 Video controller hasError: ${_controller.value.hasError}');
//       debugPrint('🎬 Video controller isBuffering: ${_controller.value.isBuffering}');
//
//       debugPrint('🎬 Video controller duration: ${_controller.value.duration}');
//       debugPrint('🎬 Video controller position: ${_controller.value.position}');
//
//       // 3. Logic: Always play since it's an overlay now
//       _controller.play();
//       _controller.addListener(_videoListener);
//
//       // Start timer to show skip button after 3 seconds
//       _timer = Timer(const Duration(seconds: 3), () {
//         if (mounted) {
//           setState(() {
//             _showSkipButton = true;
//           });
//         }
//       });
//
//       setState(() {
//         _isLoading = false;
//       });
//     } catch (e) {
//       debugPrint('🎬 Error initializing intro video: $e');
//       if (mounted) {
//         _handleClose(); // Close overlay if video fails to load
//       }
//     }
//   }
//
//   void _handleClose() async {
//     if (!mounted) return;
//
//     try {
//       await _lockPortrait(); // Lock orientation back to portrait
//       _controller.removeListener(_videoListener);
//       _controller.pause();
//       await IntroService.setSkipIntroPermanently(_skipIntroPermanently);
//       await IntroService.setHasWatchedIntro(true);
//       _timer?.cancel();
//       widget.onClose();
//     } catch (e) {
//       debugPrint('Error closing intro: $e');
//       await _lockPortrait();
//       widget.onClose();
//     }
//   }
//
//   @override
//   void dispose() {
//     _lockPortrait(); // Ensure portrait lock is restored
//     _timer?.cancel();
//     _controller.removeListener(_videoListener);
//     _controller.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     print('🎬 Building IntroVideoScreen Overlay');
//     if (_isLoading) return const Material(color: Colors.black, child: Center(child: CircularProgressIndicator()));
//
//     return Material(
//       // color: Colors.black.withOpacity(0.6),
//       child: AnimatedSwitcher(
//         duration: const Duration(milliseconds: 600),
//         transitionBuilder: (Widget child, Animation<double> animation) {
//           return FadeTransition(opacity: animation, child: child);
//         },
//         child: Stack(
//           key: ValueKey<bool>(_isLandscape),
//           children: [
//             // The Video Player
//             Center(
//               child: AspectRatio(
//                 aspectRatio: _controller.value.aspectRatio,
//                 child: VideoPlayer(_controller),
//               ),
//             ),
//
//             // Black overlay with slight gradient for better button visibility
//             // Container(
//             //   decoration: BoxDecoration(
//             //     gradient: LinearGradient(
//             //       begin: Alignment.topCenter,
//             //       end: Alignment.bottomCenter,
//             //       colors: [
//             //         Colors.black.withOpacity(0.4),
//             //         Colors.transparent,
//             //         Colors.transparent,
//             //         Colors.black.withOpacity(0.4),
//             //       ],
//             //       stops: const [0.0, 0.2, 0.8, 1.0],
//             //     ),
//             //   ),
//             // ),
//
//             // Skip button (appears after 3 seconds)
//             if (_showSkipButton)
//               Positioned(
//                 top: 40,
//                 right: 20,
//                 child: TweenAnimationBuilder<double>(
//                   tween: Tween<double>(begin: 0.0, end: 1.0),
//                   duration: const Duration(milliseconds: 500),
//                   builder: (context, value, child) {
//                     return Opacity(opacity: value, child: child);
//                   },
//                   child: TextButton(
//                     onPressed: _handleClose,
//                     style: TextButton.styleFrom(
//                       backgroundColor: Colors.black26,
//                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//                       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                     ),
//                     child: const Text("Skip", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
//                   ),
//                 ),
//               ),
//
//             // Rotate button
//             Positioned(
//               top: 40,
//               left: 20,
//               child: TweenAnimationBuilder<double>(
//                 tween: Tween<double>(begin: 0.0, end: _isLandscape ? 0.25 : 0.0),
//                 duration: const Duration(milliseconds: 500),
//                 builder: (context, value, child) {
//                   return RotationTransition(
//                     turns: AlwaysStoppedAnimation(value),
//                     child: IconButton(
//                       icon: Icon(
//                         _isLandscape ? Icons.screen_lock_portrait : Icons.screen_rotation,
//                         color: Colors.black,
//                         size: 30,
//                       ),
//                       onPressed: _toggleRotation,
//                     ),
//                   );
//                 },
//               ),
//             ),
//
//             // "Don't show intro again" checkbox (visible after 3 launches)
//             if (IntroService.getLaunchCount() >= 3)
//               Positioned(
//                 bottom: _isLandscape ? 20 : 50,
//                 left: 0,
//                 right: 0,
//                 child: AnimatedOpacity(
//                   opacity: 1.0,
//                   duration: const Duration(milliseconds: 500),
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Theme(
//                         data: ThemeData(unselectedWidgetColor: Colors.white),
//                         child: Checkbox(
//                           value: _skipIntroPermanently,
//                           onChanged: (bool? newValue) {
//                             setState(() {
//                               _skipIntroPermanently = newValue ?? false;
//                             });
//                           },
//                           activeColor: Colors.white,
//                           checkColor: Colors.black,
//                         ),
//                       ),
//                       const Text(
//                         "Don't show intro again",
//                         style: TextStyle(color: Colors.white, fontSize: 14, shadows: [Shadow(blurRadius: 2, color: Colors.black)]),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//           ],
//         ),
//       ),
//     );
//   }
// }
