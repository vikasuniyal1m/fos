import 'package:get/get.dart';
import 'package:app_links/app_links.dart';
import 'package:fruitsofspirit/routes/routes.dart';
import 'package:fruitsofspirit/services/analytics_service.dart';

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
        _processLink(initialLink);
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
  static void _processLink(Uri uri) {
    try {
      final path = uri.path;
      final queryParams = uri.queryParameters;

      // Track deep link usage
      AnalyticsService.trackEvent('deep_link', parameters: {
        'path': path,
        'query_params': queryParams,
      });

      // Route based on path
      switch (path) {
        case '/prayer':
          if (queryParams.containsKey('id')) {
            Get.toNamed(Routes.PRAYER_DETAILS, arguments: int.tryParse(queryParams['id'] ?? '0'));
          } else {
            Get.toNamed(Routes.PRAYER_REQUESTS);
          }
          break;

        case '/blog':
          if (queryParams.containsKey('id')) {
            Get.toNamed(Routes.BLOG_DETAILS, arguments: int.tryParse(queryParams['id'] ?? '0'));
          } else {
            Get.toNamed(Routes.BLOGS);
          }
          break;

        case '/video':
          if (queryParams.containsKey('id')) {
            Get.toNamed(Routes.VIDEO_DETAILS, arguments: int.tryParse(queryParams['id'] ?? '0'));
          } else {
            Get.toNamed(Routes.VIDEOS);
          }
          break;

        case '/story':
          if (queryParams.containsKey('id')) {
            Get.toNamed(Routes.STORY_DETAILS, arguments: int.tryParse(queryParams['id'] ?? '0'));
          } else {
            Get.toNamed(Routes.STORIES);
          }
          break;

        case '/group':
          if (queryParams.containsKey('id')) {
            Get.toNamed(Routes.GROUP_DETAILS, arguments: int.tryParse(queryParams['id'] ?? '0'));
          } else {
            Get.toNamed(Routes.GROUPS);
          }
          break;

        case '/profile':
          Get.toNamed(Routes.PROFILE);
          break;

        case '/search':
          if (queryParams.containsKey('q')) {
            Get.toNamed(Routes.SEARCH, arguments: queryParams['q']);
          } else {
            Get.toNamed(Routes.SEARCH);
          }
          break;

        default:
          // Unknown path, go to dashboard
          Get.toNamed(Routes.DASHBOARD);
      }
    } catch (e) {
      print('Link processing error: $e');
      Get.toNamed(Routes.DASHBOARD);
    }
  }

  /// Generate deep link URL
  static String generateLink(String type, {int? id, Map<String, String>? params}) {
    final baseUrl = 'https://fruitofthespirit.templateforwebsites.com';
    final path = '/$type';
    final queryParams = <String>[];

    if (id != null) {
      queryParams.add('id=$id');
    }

    if (params != null) {
      params.forEach((key, value) {
        queryParams.add('$key=$value');
      });
    }

    if (queryParams.isNotEmpty) {
      return '$baseUrl$path?${queryParams.join('&')}';
    }

    return '$baseUrl$path';
  }
}

