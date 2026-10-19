import 'package:fruitsofspirit/controllers/groups_controller.dart';
import 'package:fruitsofspirit/controllers/shorts_controller.dart';
import 'package:fruitsofspirit/controllers/videos_controller.dart';
import 'package:fruitsofspirit/services/shorts_service.dart';
import 'package:get/get.dart';
import 'package:app_links/app_links.dart';
import 'package:fruitsofspirit/routes/routes.dart';
import 'package:fruitsofspirit/services/analytics_service.dart';
import 'package:fruitsofspirit/services/user_storage.dart';
import 'package:fruitsofspirit/services/payment_gate.dart';
import 'package:fruitsofspirit/routes/app_pages.dart';

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

      // 2. Handling path-based /share/ (fosmessenger.com or legacy admin URLs)
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
        PaymentGate.navigateToFeature(Routes.PRAYER_DETAILS, arguments: id);
        break;
      case 'blog':
        PaymentGate.navigateToFeature(Routes.BLOG_DETAILS, arguments: id);
        break;
      case 'video':
        VideosController.openVideoDetail(id);
        break;
      case 'story':
      case 'testimony':
        PaymentGate.navigateToFeature(Routes.STORY_DETAILS, arguments: id);
        break;
      case 'photo':
        // Check if photo details route exists, if not redirect to gallery
        PaymentGate.navigateToFeature(Routes.PHOTO_DETAILS, arguments: id);
        break;
      case 'group':
        PaymentGate.navigateToFeature(Routes.GROUP_DETAILS, arguments: id);
        break;
      case 'short':
      case 'shorts':
        await _openShort(id);
        break;
    }
  }

  static Future<void> _openShort(int shortId) async {
    try {
      final userId = await UserStorage.getUserId() ?? 0;
      final short = await ShortsService.getShortDetails(
        shortId,
        currentUserId: userId > 0 ? userId : null,
      );
      if (Get.isRegistered<ShortsController>()) {
        Get.find<ShortsController>().useCommunityFeed(seed: [short]);
      }
      await Get.toNamed(
        Routes.SHORTS,
        arguments: {
          'mode': 'community',
          'seed': [short],
          'startIndex': 0,
        },
      );
    } catch (_) {
      await Get.toNamed(Routes.SHORTS);
    }
  }

  /// Public share link shown to users (clean URL, no /api/ path).
  /// Deploy repo /share folder to fosmessenger.com public_html/share/
  static String generateLink(String type, {int? id}) {
    const baseUrl = 'https://fosmessenger.com/share';
    if (id != null && id > 0) {
      return '$baseUrl/${type.toLowerCase()}/$id';
    }
    return 'https://fosmessenger.com';
  }

  /// Generate custom scheme link (more reliable for app opening)
  static String generateAppSchemeLink(String type, int id) {
    return 'fos://share/${type.toLowerCase()}/$id';
  }
}

