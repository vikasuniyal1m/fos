import '../config/api_config.dart';
import 'api_service.dart';

/// Banners Service
/// Fetches active and upcoming banners from backend for homepage carousel
class BannersService {
  /// Maximum number of banners to display (set to 0 to show all)
  static const int bannerLimit = 0;

  /// Get banners (both active and upcoming)
  ///
  /// Returns map with: 'active_banners', 'upcoming_banners', and optionally 'countdown'
  /// Each banner has: id, title, file_path, mime_type, starts_at, ends_at, sort_order
  static Future<Map<String, dynamic>> getBanners() async {
    try {
      print('🎯 Fetching banners from API...');
      final queryParameters = bannerLimit > 0 ? <String, String>{'limit': bannerLimit.toString()} : <String, String>{};
      final response = await ApiService.get(ApiConfig.banners, queryParameters: queryParameters);
      print('🎯 API Response: $response');

      if (response['success'] == true && response['data'] != null) {
        final data = response['data'] as Map<String, dynamic>;

        // Handle new format (active_banners + upcoming_banners)
        if (data.containsKey('active_banners') || data.containsKey('upcoming_banners')) {
          final activeBanners = data['active_banners'] as List<dynamic>? ?? [];
          final upcomingBanners = data['upcoming_banners'] as List<dynamic>? ?? [];
          final countdown = data['countdown'] as Map<String, dynamic>?;
          print('🎯 New format detected');
          print('🎯 Active banners count: ${activeBanners.length}');
          print('🎯 Upcoming banners count: ${upcomingBanners.length}');
          print('🎯 Countdown data: $countdown');
          return {
            'active_banners': activeBanners.cast<Map<String, dynamic>>(),
            'upcoming_banners': upcomingBanners.cast<Map<String, dynamic>>(),
            'countdown': countdown,
          };
        }

        // Handle old format (single banners array) - backward compatibility
        if (data.containsKey('banners')) {
          final allBanners = data['banners'] as List<dynamic>? ?? [];
          print('🎯 Old format detected - using backward compatibility');
          print('🎯 Total banners: ${allBanners.length}');

          final now = DateTime.now();
          final activeBanners = <Map<String, dynamic>>[];
          final upcomingBanners = <Map<String, dynamic>>[];

          for (var banner in allBanners) {
            final b = banner as Map<String, dynamic>;
            final startsAt = DateTime.parse(b['starts_at']);
            final endsAt = DateTime.parse(b['ends_at']);

            if (startsAt.isBefore(now) && endsAt.isAfter(now)) {
              activeBanners.add(b);
            } else if (startsAt.isAfter(now)) {
              upcomingBanners.add(b);
            }
          }

          upcomingBanners.sort((a, b) => DateTime.parse(a['starts_at']).compareTo(DateTime.parse(b['starts_at'])));

          print('🎯 Active banners count: ${activeBanners.length}');
          print('🎯 Upcoming banners count: ${upcomingBanners.length}');
          return {
            'active_banners': activeBanners,
            'upcoming_banners': upcomingBanners,
            'countdown': null,
          };
        }

        print('🎯 Unknown API format');
        return {
          'active_banners': [],
          'upcoming_banners': [],
          'countdown': null,
        };
      } else {
        print('🎯 API returned no success or no data');
        return {
          'active_banners': [],
          'upcoming_banners': [],
          'countdown': null,
        };
      }
    } catch (e) {
      print('❌ BannersService Error: $e');
      return {
        'active_banners': [],
        'upcoming_banners': [],
        'countdown': null,
      };
    }
  }

  /// Build full image URL from file_path returned by API
  static String getBannerImageUrl(String filePath) {
    if (filePath.isEmpty) return '';
    // If already a full URL, return as-is
    if (filePath.startsWith('http://') || filePath.startsWith('https://')) {
      return filePath;
    }
    // Otherwise prepend the base URL
    return 'http://admin.fosmessenger.com/$filePath';
  }
}
