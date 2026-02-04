import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fruitsofspirit/utils/app_theme.dart';
import 'package:get/get.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:fruitsofspirit/routes/routes.dart';
import 'package:fruitsofspirit/services/deep_link_service.dart';
import 'package:fruitsofspirit/services/push_notification_service.dart';
import 'package:fruitsofspirit/services/analytics_service.dart';
import 'package:fruitsofspirit/services/user_storage.dart';
import 'package:fruitsofspirit/services/hive_cache_service.dart';
import 'package:fruitsofspirit/controllers/notifications_controller.dart';
import 'package:fruitsofspirit/utils/screen_size.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fruitsofspirit/screens/IntroVideoScreen.dart';
import 'package:fruitsofspirit/services/intro_service.dart';
import 'package:fruitsofspirit/services/jingle_service.dart';

import 'bindings/InitialBinding.dart';

// Uncomment next line to run comprehensive tests
// import 'package:fruitsofspirit/testing/comprehensive_test.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Force the app to stay in portrait mode.
  // Only the Intro Video Overlay is allowed to rotate.
  try {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  } catch (e) {
    // Ignore orientation change errors (common on iOS with certain windowing modes)
    print('Orientation change error: $e');
  }

  await _initializeDependencies();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('es')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: const MyApp(),
    ),
  );
}

Future<void> _initializeDependencies() async {
  // 🧪 To run comprehensive tests - Uncomment below
  // await ComprehensiveTest.runAllTests();

  // Initialize SharedPreferences (now handled by IntroService)
  debugPrint('Initializing IntroService...');
  await IntroService.init();

  // Initialize Hive (must be done before other services)
  await Hive.initFlutter();

  // Initialize User Storage (Hive box)
  await UserStorage.init();

  // Initialize Hive Cache Service
  await HiveCacheService.init();

  // Pre-initialize Jingle Service (starts pre-caching)
  // Get.put will automatically call onInit() which calls initialize()
  Get.put(JingleService(), permanent: true);

  // Initialize Easy Localization
  await EasyLocalization.ensureInitialized();

  // Initialize services
  await _initializeServices();
}

Future<void> _initializeServices() async {
  try {
    // Initialize Deep Linking with timeout
    await DeepLinkService.initialize()
        .timeout(const Duration(seconds: 5))
        .catchError((error) {
      debugPrint('⚠️ DeepLinkService initialization failed: $error');
    });
    
    // Initialize Push Notifications with timeout
    await PushNotificationService.initialize()
        .timeout(const Duration(seconds: 5))
        .catchError((error) {
      debugPrint('⚠️ PushNotificationService initialization failed: $error');
    });
    
    // Send pending analytics events (non-blocking)
    AnalyticsService.sendPendingEvents()
        .timeout(const Duration(seconds: 3))
        .catchError((error) {
      debugPrint('⚠️ AnalyticsService sendPendingEvents failed: $error');
    });
  } catch (e) {
    debugPrint('⚠️ Error initializing services: $e');
    // Continue app startup even if services fail
  }
}

class MyApp extends StatefulWidget { // Changed StatelessWidget to StatefulWidget
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // App is in the foreground - resume any paused operations
        _handleAppResumed();
        break;
      case AppLifecycleState.inactive:
        // App is in an inactive state (e.g., phone call, app switcher)
        // Pause video players temporarily
        _handleAppInactive();
        break;
      case AppLifecycleState.paused:
        // App is in the background - pause video players and save state
        _handleAppPaused();
        break;
      case AppLifecycleState.detached:
        // App is detached from the Flutter engine (e.g., terminated)
        _handleAppDetached();
        break;
      case AppLifecycleState.hidden:
        // App is hidden (e.g., minimized)
        _handleAppHidden();
        break;
    }
  }

  /// Handle app resumed - resume video players and refresh data if needed
  void _handleAppResumed() {
    // Refresh notifications when app comes to foreground
    try {
      final notificationsController = Get.find<NotificationsController>();
      notificationsController.loadNotifications();
    } catch (e) {
      // Controller not available, ignore
    }
  }

  /// Handle app inactive - pause video players temporarily
  void _handleAppInactive() {
    // Video players will be paused automatically by their controllers
  }

  /// Handle app paused - pause video players and save state
  void _handleAppPaused() {
    // Save any pending analytics events
    AnalyticsService.sendPendingEvents();
    // Note: App state is automatically preserved by Flutter
    // User session is saved in Hive and will persist across app restarts
    // No need to manually save state - Flutter handles this
  }

  /// Handle app detached - cleanup
  void _handleAppDetached() {
    // Final cleanup if needed
    // This is called when app is terminated, not when minimized
    // User session in Hive will persist even after app termination
  }

  /// Handle app hidden - pause operations
  void _handleAppHidden() {
    // App is minimized but not terminated
    // State is preserved automatically by Flutter
    // User session remains saved in Hive
    // App will resume from same state when brought back to foreground
    _handleAppPaused();
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: '', // Removed the title to hide the system app bar text
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        // Enable keyboard swipe-down functionality
        visualDensity: VisualDensity.adaptivePlatformDensity,
        platform: TargetPlatform.iOS,
        // Set default text input action to Done for all TextFields
        inputDecorationTheme: const InputDecorationTheme(
          // You can add other default input decoration settings here
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            // Text button styles
          ),
        ),
      ),
      initialBinding: InitialBinding(),
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      initialRoute: Routes.SPLASH,
      getPages: AppPages.routes,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        // Safe access to MediaQuery
        final mediaQueryData = MediaQuery.of(context);
        final isTablet = mediaQueryData.size.width >= 600;

        return ScreenUtilInit(
          designSize: isTablet ? const Size(768, 1024) : const Size(375, 812),
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (context, _) {
            // Initialize ScreenSize utility
            ScreenSize.init(context);
            
            // Clamp textScaleFactor for better accessibility
            final constrainedTextScaleFactor = mediaQueryData.textScaleFactor.clamp(0.9, 1.3);

            // Enable keyboard dismiss by dragging down
            return GestureDetector(
              onVerticalDragDown: (_) {
                // Dismiss keyboard when dragging down anywhere on the screen
                FocusManager.instance.primaryFocus?.unfocus();
              },
              child: MediaQuery(
                data: mediaQueryData.copyWith(
                  textScaleFactor: constrainedTextScaleFactor,
                ),
                child: child!,
              ),
            );
          },
        );
      },
    );
  }
}
