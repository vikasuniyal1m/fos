import 'package:fruitsofspirit/controllers/groups_controller.dart';
import 'package:get/get.dart';
import 'package:app_links/app_links.dart';
import 'package:fruitsofspirit/routes/routes.dart';
import 'package:fruitsofspirit/services/analytics_service.dart';
import 'package:fruitsofspirit/services/user_storage.dart';

/// Deep Link Service
/// Handles app deep linking
class DeepLinkService {
  static bool _initialized = false;
  static AppLinks? _appLinks;

  /// Initialize deep linking
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      _appLinks = AppLinks();
      
      // Listen for initial link
      await _handleInitialLink();

      // Listen for incoming links
      _handleIncomingLinks();

      _initialized = true;
    } catch (e) {
      print('Deep link initialization error: $e');
    }
  }

  /// Handle initial link (when app is opened via link)
  static Future<void> _handleInitialLink() async {
    try {
      if (_appLinks == null) return;
      
      final initialLink = await _appLinks!.getInitialLink();
      if (initialLink != null) {
        // Wait a bit for the app to settle (Splash screen, etc.)
        Future.delayed(const Duration(milliseconds: 1500), () {
          _processLink(initialLink);
        });
      }
    } catch (e) {
      print('Initial link error: $e');
    }
  }

  /// Handle incoming links (when app is already running)
  static void _handleIncomingLinks() {
    try {
      if (_appLinks == null) return;
      
      _appLinks!.uriLinkStream.listen((Uri uri) {
        _processLink(uri);
      }, onError: (err) {
        print('Link error: $err');
      });
    } catch (e) {
      print('Incoming link error: $e');
    }
  }

  /// Process deep link
  static Future<void> _processLink(Uri uri) async {
    try {
      // Safety check: Wait until Navigator is ready
      int attempts = 0;
      while (Get.key.currentState == null && attempts < 10) {
        print('⏳ DeepLink: Waiting for Navigator to be ready (attempt ${attempts + 1})...');
        await Future.delayed(const Duration(milliseconds: 500));
        attempts++;
      }

      if (Get.key.currentState == null) {
        print('❌ DeepLink: Navigator not ready after 5 seconds. Aborting.');
        return;
      }

      final path = uri.path;
      final queryParameters = uri.queryParameters;

      // Track deep link usage
      AnalyticsService.trackEvent('deep_link', parameters: {
        'path': path,
        'query_params': queryParameters,
      });

      // Route based on path
      // 1. Handling share_redirect.php format (?type=...&id=...)
      if (path.contains('share_redirect.php')) {
        final type = queryParameters['type']?.toLowerCase() ?? '';
        final id = int.tryParse(queryParameters['id'] ?? '0') ?? 0;
        if (id > 0) {
          await _navigateToContent(type, id);
          return;
        }
      }

      // 2. Handling path-based /share/ or /api/share/ formats
      if (path.contains('/share/')) {
        final segments = uri.pathSegments;
        final shareIndex = segments.indexOf('share');
        
        if (shareIndex != -1 && segments.length > shareIndex + 2) {
          final type = segments[shareIndex + 1].toLowerCase();
          final id = int.tryParse(segments[shareIndex + 2]) ?? 0;
          
          if (id > 0) {
            await _navigateToContent(type, id);
            return;
          }
        }
      }

      // 3. Handling custom scheme fos://share/type/id
      if (uri.scheme == 'fos') {
        final segments = uri.pathSegments;
        if (segments.length >= 3 && segments[0] == 'share') {
          final type = segments[1].toLowerCase();
          final id = int.tryParse(segments[2]) ?? 0;
          if (id > 0) {
            await _navigateToContent(type, id);
            return;
          }
        }
      }

      switch (path) {
        case '/prayer':
          await _navigateToContent('prayer', int.tryParse(queryParameters['id'] ?? '0') ?? 0);
          break;
        case '/blog':
          await _navigateToContent('blog', int.tryParse(queryParameters['id'] ?? '0') ?? 0);
          break;
        case '/video':
          await _navigateToContent('video', int.tryParse(queryParameters['id'] ?? '0') ?? 0);
          break;
        case '/story':
        case '/testimony':
          await _navigateToContent('story', int.tryParse(queryParameters['id'] ?? '0') ?? 0);
          break;
        case '/group':
          await _navigateToContent('group', int.tryParse(queryParameters['id'] ?? '0') ?? 0);
          break;
        case '/profile':
          Get.toNamed(Routes.PROFILE);
          break;
        case '/search':
          Get.toNamed(Routes.SEARCH, arguments: queryParameters['q']);
          break;
        default:
          Get.toNamed(Routes.DASHBOARD);
      }
    } catch (e) {
      print('Link processing error: $e');
      // If we're here, contextless nav already failed or some other error happened.
      // Only try to go to dashboard if navigator is ready.
      if (Get.key.currentState != null) {
        Get.toNamed(Routes.DASHBOARD);
      }
    }
  }

  static Future<void> _navigateToContent(String type, int id) async {
    if (id <= 0) {
      Get.toNamed(Routes.DASHBOARD);
      return;
    }

    // Check if user is logged in before allowing access to content
    final loggedIn = await UserStorage.isLoggedIn();
    if (!loggedIn) {
      print('🔐 User not logged in, redirecting to login from deep link');
      Get.toNamed(Routes.LOGIN);
      return;
    }

    switch (type) {
      case 'prayer':
        Get.toNamed(Routes.PRAYER_DETAILS, arguments: id);
        break;
      case 'blog':
        Get.toNamed(Routes.BLOG_DETAILS, arguments: id);
        break;
      case 'video':
        Get.toNamed(Routes.VIDEO_DETAILS, arguments: id);
        break;
      case 'story':
      case 'testimony':
        Get.toNamed(Routes.STORY_DETAILS, arguments: id);
        break;
      case 'photo':
        // Check if photo details route exists, if not redirect to gallery
        Get.toNamed(Routes.PHOTO_DETAILS, arguments: id);
        break;
      case 'group':
        Get.toNamed(Routes.GROUP_DETAILS, arguments: id);
        break;
    }
  }

  /// Generate deep link URL
  static String generateLink(String type, {int? id}) {
    final baseUrl = 'https://fruitofthespirit.templateforwebsites.com';
    if (id != null) {
      // Using a direct file in api folder as requested
      return '$baseUrl/api/share_redirect.php?type=${type.toLowerCase()}&id=$id';
    }
    return '$baseUrl/${type.toLowerCase()}';
  }

  /// Generate custom scheme link (more reliable for app opening)
  static String generateAppSchemeLink(String type, int id) {
    return 'fos://share/${type.toLowerCase()}/$id';
  }
}

