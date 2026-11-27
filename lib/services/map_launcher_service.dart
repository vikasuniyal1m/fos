import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

/// External maps open karna — billing/API fail par ya user choice se.
class MapLauncherService {
  /// Name + coords — Google Maps par wahi church naam dikhe.
  static String namedDestination(double lat, double lng, String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '$lat,$lng';
    return '${Uri.encodeComponent(trimmed)}@$lat,$lng';
  }

  /// Google Maps directions — destination me naam@lat,lng (label + exact pin).
  static Uri googleMapsDirectionsUri(double lat, double lng, String name) {
    final dest = namedDestination(lat, lng, name);
    return Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$dest&travelmode=driving',
    );
  }

  static Uri googleMapsSearchUri(double lat, double lng, String name) {
    final q = namedDestination(lat, lng, name);
    return Uri.parse('https://www.google.com/maps/search/?api=1&query=$q');
  }

  /// Apple Maps — iOS only.
  static Uri appleMapsUri(double lat, double lng, String name) {
    final q = Uri.encodeComponent(name);
    return Uri.parse('maps://?daddr=$lat,$lng&q=$q');
  }

  static Future<void> openGoogleMaps(double lat, double lng, String name) async {
    final dest = namedDestination(lat, lng, name);
    final webUri = googleMapsDirectionsUri(lat, lng, name);

    if (Platform.isIOS) {
      final appUri = Uri.parse(
        'comgooglemaps://?daddr=$dest&directionsmode=driving',
      );
      if (await canLaunchUrl(appUri)) {
        await launchUrl(appUri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    if (Platform.isAndroid) {
      final geoUri = Uri.parse('geo:$lat,$lng?q=$dest');
      if (await canLaunchUrl(geoUri)) {
        await launchUrl(geoUri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    await launchUrl(webUri, mode: LaunchMode.externalApplication);
  }

  static Future<void> openAppleMaps(double lat, double lng, String name) async {
    final uri = appleMapsUri(lat, lng, name);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      final web = Uri.parse(
        'https://maps.apple.com/?daddr=$lat,$lng&q=${Uri.encodeComponent(name)}',
      );
      await launchUrl(web, mode: LaunchMode.externalApplication);
    }
  }

  static String _churchSearchQuery(String query) {
    final q = query.trim();
    if (q.isEmpty) return 'church';
    final lower = q.toLowerCase();
    if (lower.contains('church') ||
        lower.contains('chapel') ||
        lower.contains('cathedral')) {
      return q;
    }
    return '$q church';
  }

  /// Text search — jab in-app me church na mile.
  static Future<void> openGoogleMapsSearch(
    String query, {
    double? lat,
    double? lng,
  }) async {
    final searchQ = Uri.encodeComponent(_churchSearchQuery(query));
    final uri = lat != null && lng != null
        ? Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=$searchQ&center=$lat,$lng',
          )
        : Uri.parse('https://www.google.com/maps/search/?api=1&query=$searchQ');

    if (Platform.isAndroid) {
      final geo = lat != null && lng != null
          ? Uri.parse('geo:$lat,$lng?q=$searchQ')
          : Uri.parse('geo:0,0?q=$searchQ');
      if (await canLaunchUrl(geo)) {
        await launchUrl(geo, mode: LaunchMode.externalApplication);
        return;
      }
    }

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Platform default — church na mile to sidhe Maps.
  static Future<void> openExternalMapsSearchAuto(
    String query, {
    double? lat,
    double? lng,
  }) async {
    if (Platform.isIOS) {
      await openAppleMapsSearch(query, lat: lat, lng: lng);
    } else {
      await openGoogleMapsSearch(query, lat: lat, lng: lng);
    }
  }

  static Future<void> openAppleMapsSearch(
    String query, {
    double? lat,
    double? lng,
  }) async {
    final searchQ = Uri.encodeComponent(_churchSearchQuery(query));
    final uri = lat != null && lng != null
        ? Uri.parse('maps://?q=$searchQ&sll=$lat,$lng&z=14')
        : Uri.parse('maps://?q=$searchQ');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    final web = lat != null && lng != null
        ? Uri.parse('https://maps.apple.com/?q=$searchQ&sll=$lat,$lng&z=14')
        : Uri.parse('https://maps.apple.com/?q=$searchQ');
    await launchUrl(web, mode: LaunchMode.externalApplication);
  }

  /// In-app me na mile — Google / Apple Maps me dhundho.
  static void showExternalSearchDialog({
    required String query,
    double? lat,
    double? lng,
  }) {
    final label = _churchSearchQuery(query);
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Search in Maps',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Not found in app. Try external maps for:',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            _optionTile(
              icon: Icons.map_outlined,
              label: 'Open in Google Maps',
              onTap: () {
                Get.back();
                openGoogleMapsSearch(query, lat: lat, lng: lng);
              },
            ),
            if (Platform.isIOS) ...[
              const SizedBox(height: 8),
              _optionTile(
                icon: Icons.apple,
                label: 'Open in Apple Maps',
                onTap: () {
                  Get.back();
                  openAppleMapsSearch(query, lat: lat, lng: lng);
                },
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
        ],
      ),
    );
  }

  /// Start Navigation — Google Maps ya in-app choose karo.
  static void showNavigationChoiceDialog({
    required String name,
    required double lat,
    required double lng,
    required VoidCallback onInAppNavigation,
  }) {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Choose Navigation',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              name,
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            _optionTile(
              icon: Icons.navigation,
              label: 'Navigate in app',
              onTap: () {
                Get.back();
                onInAppNavigation();
              },
            ),
            const SizedBox(height: 8),
            _optionTile(
              icon: Icons.map_outlined,
              label: 'Open in Google Maps',
              onTap: () {
                Get.back();
                openGoogleMaps(lat, lng, name);
              },
            ),
            if (Platform.isIOS) ...[
              const SizedBox(height: 8),
              _optionTile(
                icon: Icons.apple,
                label: 'Open in Apple Maps',
                onTap: () {
                  Get.back();
                  openAppleMaps(lat, lng, name);
                },
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
        ],
      ),
    );
  }

  /// Church tap par map options dialog — existing in-app flow ke saath.
  static void showMapOptionsDialog({
    required String name,
    required double lat,
    required double lng,
    VoidCallback? onInAppDirections,
  }) {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Open in Maps',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              name,
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            _optionTile(
              icon: Icons.map_outlined,
              label: 'Open in Google Maps',
              onTap: () {
                Get.back();
                openGoogleMaps(lat, lng, name);
              },
            ),
            if (Platform.isIOS) ...[
              const SizedBox(height: 8),
              _optionTile(
                icon: Icons.apple,
                label: 'Open in Apple Maps',
                onTap: () {
                  Get.back();
                  openAppleMaps(lat, lng, name);
                },
              ),
            ],
            if (onInAppDirections != null) ...[
              const SizedBox(height: 8),
              _optionTile(
                icon: Icons.directions,
                label: 'Directions in app',
                onTap: () {
                  Get.back();
                  onInAppDirections();
                },
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
        ],
      ),
    );
  }

  static Widget _optionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF2196F3), size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
          ],
        ),
      ),
    );
  }
}
