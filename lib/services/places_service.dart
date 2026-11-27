import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../config/api_config.dart'; // Ensure you have your Places API Key here or in a secure place

class PlacesService {
  static final String _apiKey = ApiConfig.googleMapsApiKey;
  static bool get _googleEnabled => ApiConfig.googleMapsBillingApisEnabled;

  /// Strip HTML tags from Google Directions step instructions.
  static String stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String? extractPhotoUrlFromPlace(Map<String, dynamic> place, {int maxWidth = 400}) {
    try {
      final photos = place['photos'];
      if (photos is List && photos.isNotEmpty) {
        final first = photos.first;
        if (first is Map && first['photo_reference'] != null) {
          final ref = first['photo_reference'].toString();
          if (ref.isNotEmpty) {
            return 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=$maxWidth&photo_reference=${Uri.encodeComponent(ref)}&key=$_apiKey';
          }
        }
      }
    } catch (_) {}
    return null;
  }

  static List<String> extractAllPhotoUrls(Map<String, dynamic> place, {int maxWidth = 800}) {
    final urls = <String>[];
    final photos = place['photos'];
    if (photos is List) {
      for (final photo in photos.take(6)) {
        if (photo is Map && photo['photo_reference'] != null) {
          final ref = photo['photo_reference'].toString();
          if (ref.isNotEmpty) {
            urls.add(
              'https://maps.googleapis.com/maps/api/place/photo?maxwidth=$maxWidth&photo_reference=${Uri.encodeComponent(ref)}&key=$_apiKey',
            );
          }
        }
      }
    }
    if (urls.isEmpty) {
      final single = extractPhotoUrlFromPlace(place, maxWidth: maxWidth);
      if (single != null) urls.add(single);
    }
    return urls;
  }

  static String buildDescriptionFromDetails(Map<String, dynamic> place) {
    final editorial = place['editorial_summary'];
    if (editorial is Map) {
      final overview = editorial['overview']?.toString().trim();
      if (overview != null && overview.isNotEmpty) return overview;
    }
    if (editorial is String && editorial.trim().isNotEmpty) {
      return editorial.trim();
    }

    final reviews = place['reviews'];
    if (reviews is List && reviews.isNotEmpty) {
      final parts = <String>[];
      for (final review in reviews.take(2)) {
        if (review is Map) {
          final author = review['author_name']?.toString().trim();
          final text = review['text']?.toString().trim();
          if (text != null && text.isNotEmpty) {
            final snippet = text.length > 320 ? '${text.substring(0, 317)}...' : text;
            parts.add(author != null && author.isNotEmpty ? '$author: $snippet' : snippet);
          }
        }
      }
      if (parts.isNotEmpty) return parts.join('\n\n');
    }

    final types = place['types'];
    final typeLabels = <String>[];
    if (types is List) {
      for (final t in types) {
        final label = t.toString().replaceAll('_', ' ');
        if (!label.contains('point of interest') && !label.contains('establishment')) {
          typeLabels.add(label);
        }
      }
    }

    final name = place['name']?.toString() ?? 'This church';
    final denomination = place['denomination']?.toString();
    final address = place['formatted_address'] ?? place['vicinity'];
    final rating = place['rating'];
    final ratingsTotal = place['user_ratings_total'];
    final buffer = StringBuffer();
    buffer.write(name);
    if (denomination != null && denomination.isNotEmpty && denomination != 'Church') {
      buffer.write(' is a $denomination church');
    } else if (typeLabels.isNotEmpty) {
      buffer.write(' is listed as ${typeLabels.take(2).join(', ')}');
    } else {
      buffer.write(' is a local church');
    }
    if (address != null && address.toString().isNotEmpty) {
      buffer.write(' at ${address.toString()}.');
    } else {
      buffer.write('.');
    }
    if (rating != null) {
      buffer.write(' Google rating: $rating');
      if (ratingsTotal != null) buffer.write(' from $ratingsTotal reviews');
      buffer.write('.');
    }
    return buffer.toString();
  }

  static Map<String, dynamic> mergePlaceWithDetails(
    Map<String, dynamic> source,
    Map<String, dynamic> details,
  ) {
    final merged = Map<String, dynamic>.from(source);
    details.forEach((key, value) {
      if (value != null) merged[key] = value;
    });
    if (source['distance'] != null) merged['distance'] = source['distance'];
    if (source['denomination'] != null && source['denomination'].toString().isNotEmpty) {
      merged['denomination'] = source['denomination'];
    } else {
      merged['denomination'] = _denominationFromName(merged['name']?.toString() ?? '');
    }
    merged['photo_urls'] = extractAllPhotoUrls(merged, maxWidth: 800);
    if (merged['photo_urls'] is List && (merged['photo_urls'] as List).isNotEmpty) {
      merged['church_image_url'] = (merged['photo_urls'] as List).first;
    } else {
      final photoUrl = extractPhotoUrlFromPlace(merged, maxWidth: 800);
      if (photoUrl != null) merged['church_image_url'] = photoUrl;
    }
    merged['description'] = buildDescriptionFromDetails(merged);
    return merged;
  }

  static String _denominationFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('catholic')) return 'Catholic';
    if (lower.contains('baptist')) return 'Baptist';
    if (lower.contains('pentecost')) return 'Pentecostal';
    if (lower.contains('lutheran')) return 'Lutheran';
    if (lower.contains('methodist')) return 'Methodist';
    if (lower.contains('presbyterian')) return 'Presbyterian';
    if (lower.contains('adventist')) return 'Adventist';
    if (lower.contains('orthodox')) return 'Orthodox';
    return 'Church';
  }

  static Future<Map<String, dynamic>> resolvePlaceDetails(Map<String, dynamic> place) async {
    if (!_googleEnabled) return Map<String, dynamic>.from(place);
    final placeId = place['place_id']?.toString() ?? '';
    final hasRealPlaceId = placeId.isNotEmpty &&
        !placeId.startsWith('dummy') &&
        placeId != 'selected_church';
    Map<String, dynamic>? details;

    if (hasRealPlaceId) {
      details = await placeDetails(placeId: placeId);
    }

    if (details == null) {
      final name = place['name']?.toString() ?? '';
      final loc = place['geometry']?['location'];
      if (name.isNotEmpty && loc is Map) {
        final lat = loc['lat'];
        final lng = loc['lng'];
        if (lat != null && lng != null) {
          final nearby = await searchNearbyChurches(
            location: LatLng(lat, lng),
            radius: 800,
          );
          for (final candidate in nearby) {
            final candidateName = candidate['name']?.toString().toLowerCase() ?? '';
            if (candidateName == name.toLowerCase() ||
                candidateName.contains(name.toLowerCase()) ||
                name.toLowerCase().contains(candidateName)) {
              final candidateId = candidate['place_id']?.toString();
              if (candidateId != null && candidateId.isNotEmpty) {
                details = await placeDetails(placeId: candidateId);
                break;
              }
            }
          }

          if (details == null) {
            final results = await searchByQuery(
              query: name,
              location: LatLng(lat, lng),
              radius: 1500,
            );
            for (final candidate in results) {
              final candidateName = candidate['name']?.toString().toLowerCase() ?? '';
              if (candidateName == name.toLowerCase() || candidateName.contains(name.toLowerCase())) {
                final candidateId = candidate['place_id']?.toString();
                if (candidateId != null && candidateId.isNotEmpty) {
                  details = await placeDetails(placeId: candidateId);
                  break;
                }
              }
            }
            if (details == null && results.isNotEmpty) {
              final fallbackId = results.first['place_id']?.toString();
              if (fallbackId != null && fallbackId.isNotEmpty) {
                details = await placeDetails(placeId: fallbackId);
              }
            }
          }
        }
      }
    }

    if (details != null) {
      return mergePlaceWithDetails(place, details);
    }

    final fallback = Map<String, dynamic>.from(place);
    fallback['photo_urls'] = extractAllPhotoUrls(fallback, maxWidth: 800);
    if (fallback['photo_urls'] is List && (fallback['photo_urls'] as List).isNotEmpty) {
      fallback['church_image_url'] = (fallback['photo_urls'] as List).first;
    } else {
      final photoUrl = extractPhotoUrlFromPlace(fallback, maxWidth: 800);
      if (photoUrl != null) fallback['church_image_url'] = photoUrl;
    }
    fallback['description'] = buildDescriptionFromDetails(fallback);
    if (fallback['denomination'] == null) {
      fallback['denomination'] = _denominationFromName(fallback['name']?.toString() ?? '');
    }
    return fallback;
  }

  static List<Map<String, dynamic>> _attachPhotoUrls(List<Map<String, dynamic>> items) {
    return items.map((p) {
      final photoUrl = extractPhotoUrlFromPlace(p);
      final copy = Map<String, dynamic>.from(p);
      if (photoUrl != null) {
        copy['church_image_url'] = photoUrl;
      }
      return copy;
    }).toList();
  }

  static Future<List<Map<String, dynamic>>> searchChurches({
    required LatLng location,
    String? denomination,
    double radius = 5000, // 5km radius
  }) async {
    if (!_googleEnabled) return [];
    if (ApiConfig.isDummyMode) {
      final baseLat = location.latitude;
      final baseLng = location.longitude;
      final label = denomination != null && denomination.isNotEmpty ? denomination : 'Church';
      return [
        {
          'place_id': 'dummy_1',
          'name': '$label Center',
          'vicinity': 'Main Street',
          'geometry': {
            'location': {'lat': baseLat + 0.01, 'lng': baseLng + 0.01}
          }
        },
        {
          'place_id': 'dummy_2',
          'name': '$label Community',
          'vicinity': '2nd Avenue',
          'geometry': {
            'location': {'lat': baseLat - 0.008, 'lng': baseLng + 0.012}
          }
        },
        {
          'place_id': 'dummy_3',
          'name': '$label Fellowship',
          'vicinity': 'Park Road',
          'geometry': {
            'location': {'lat': baseLat + 0.006, 'lng': baseLng - 0.009}
          }
        },
      ];
    }
    final String baseUrl = 'https://maps.googleapis.com/maps/api/place/textsearch/json';
    
    // Construct query
    // If denomination is provided: "{Denomination} church"
    // If not: "Church"
    String query = denomination != null && denomination.isNotEmpty
        ? '$denomination church'
        : 'Church';

    final String initialUrl =
        '$baseUrl?query=${Uri.encodeComponent(query)}&type=church&location=${location.latitude},${location.longitude}&radius=$radius&key=$_apiKey';

    try {
      // Only 1 page for maximum speed
      final results = <Map<String, dynamic>>[];
      
      final response = await http.get(Uri.parse(initialUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'] != null) {
          results.addAll(_attachPhotoUrls(List<Map<String, dynamic>>.from(data['results'])));
        }
      }
      
      // Fallback to nearby search quickly
      if (results.isEmpty) {
        final nearbyBase = 'https://maps.googleapis.com/maps/api/place/nearbysearch/json';
        final nearbyUrl = '$nearbyBase?location=${location.latitude},${location.longitude}&radius=$radius&type=church&key=$_apiKey${denomination != null && denomination.isNotEmpty ? '&keyword=${Uri.encodeComponent(denomination)}' : ''}';
        final resp = await http.get(Uri.parse(nearbyUrl));
        if (resp.statusCode == 200) {
          final data = json.decode(resp.body);
          if (data['status'] == 'OK' && data['results'] != null) {
            return _attachPhotoUrls(List<Map<String, dynamic>>.from(data['results']));
          }
        }
      }
      return results;
    } catch (e) {
      return [];
    }
  }
  
  static Future<List<Map<String, dynamic>>> searchNearbyChurches({
    required LatLng location,
    String? denomination,
    double radius = 5000,
  }) async {
    if (!_googleEnabled) return [];
    if (ApiConfig.isDummyMode) {
      final baseLat = location.latitude;
      final baseLng = location.longitude;
      final label = denomination != null && denomination.isNotEmpty ? denomination : 'Church';
      return [
        {
          'place_id': 'dummy_n1',
          'name': '$label Near 1',
          'vicinity': 'Near Road',
          'geometry': {
            'location': {'lat': baseLat + 0.004, 'lng': baseLng + 0.003}
          }
        },
        {
          'place_id': 'dummy_n2',
          'name': '$label Near 2',
          'vicinity': 'Close Street',
          'geometry': {
            'location': {'lat': baseLat - 0.003, 'lng': baseLng - 0.002}
          }
        },
      ];
    }
    final base = 'https://maps.googleapis.com/maps/api/place/nearbysearch/json';
    final keyword = denomination != null && denomination.isNotEmpty ? '&keyword=${Uri.encodeComponent(denomination)}' : '';
    final initialUrl = '$base?location=${location.latitude},${location.longitude}&radius=$radius&type=church&key=$_apiKey$keyword';
    try {
      print('Nearby request: lat=${location.latitude}, lng=${location.longitude}, radius=$radius, keyword="${denomination ?? ''}"');
      final results = <Map<String, dynamic>>[];
      String? pageToken;
      for (int i = 0; i < 3; i++) {
        final url = pageToken == null ? initialUrl : '$initialUrl&pagetoken=$pageToken';
        final resp = await http.get(Uri.parse(url));
        if (resp.statusCode != 200) {
          print('Nearby HTTP ${resp.statusCode}');
          throw Exception('Failed to load nearby places');
        }
        final data = json.decode(resp.body);
        if (data['status'] == 'OK' && data['results'] != null) {
          final count = (data['results'] as List).length;
          print('Nearby page OK count=$count nextToken=${data['next_page_token'] != null}');
          results.addAll(_attachPhotoUrls(List<Map<String, dynamic>>.from(data['results'])));
          pageToken = data['next_page_token'];
          if (pageToken == null) break;
          await Future.delayed(const Duration(seconds: 2));
        } else if (data['status'] == 'ZERO_RESULTS') {
          print('Nearby ZERO_RESULTS');
          break;
        } else {
          final status = data['status']?.toString() ?? 'UNKNOWN';
          final err = data['error_message']?.toString();
          print('Nearby status=$status error=${err ?? ''}');
          throw Exception('Places Nearby $status${err != null ? ' - $err' : ''}');
        }
      }
      print('Nearby total results=${results.length}');
      return results;
    } catch (e) {
      print('Error in searchNearbyChurches: $e');
      return [];
    }
  }
  
  static Future<List<Map<String, dynamic>>> searchByQuery({
    required String query,
    LatLng? location,
    double radius = 15000,
  }) async {
    if (!_googleEnabled) return [];
    if (ApiConfig.isDummyMode) {
      final baseLat = (location?.latitude ?? 37.0902);
      final baseLng = (location?.longitude ?? -95.7129);
      final label = query.isNotEmpty ? query : 'Church';
      return [
        {
          'place_id': 'dummy_q1',
          'name': '$label HQ',
          'vicinity': 'Broadway',
          'formatted_address': 'Broadway',
          'geometry': {
            'location': {'lat': baseLat + 0.015, 'lng': baseLng + 0.015}
          }
        },
        {
          'place_id': 'dummy_q2',
          'name': '$label Office',
          'vicinity': 'Market Street',
          'formatted_address': 'Market Street',
          'geometry': {
            'location': {'lat': baseLat - 0.01, 'lng': baseLng + 0.008}
          }
        },
      ];
    }
    final String baseUrl = 'https://maps.googleapis.com/maps/api/place/textsearch/json';
    final String base = '$baseUrl?query=${Uri.encodeComponent(query)}&key=$_apiKey';
    final String initialUrl = location != null
        ? '$base&type=church&location=${location.latitude},${location.longitude}&radius=$radius'
        : '$base&type=church';
    try {
      final locStr = location != null ? 'lat=${location.latitude}, lng=${location.longitude}, radius=$radius' : 'no-location';
      print('Places TextSearch (query) request: query="$query", $locStr');
      final results = <Map<String, dynamic>>[];
      String? pageToken;
      for (int i = 0; i < 2; i++) {
        final url = pageToken == null ? initialUrl : '$initialUrl&pagetoken=$pageToken';
        final response = await http.get(Uri.parse(url));
        if (response.statusCode != 200) break;
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'] != null) {
          results.addAll(_attachPhotoUrls(List<Map<String, dynamic>>.from(data['results'])));
          pageToken = data['next_page_token'];
          if (pageToken == null) break;
          await Future.delayed(const Duration(milliseconds: 500));
        } else break;
      }
      return results;
    } catch (e) {
      print('Error searching by query: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> autocomplete({
    required String input,
    LatLng? locationBias,
  }) async {
    if (!_googleEnabled) return [];
    if (input.isEmpty) return [];
    final base = 'https://maps.googleapis.com/maps/api/place/autocomplete/json';
    final loc = locationBias != null ? '&location=${locationBias.latitude},${locationBias.longitude}&radius=50000' : '';
    final url = '$base?input=${Uri.encodeComponent(input)}$loc&type=church&key=$_apiKey';
    try {
      print('Autocomplete request: "$input" $loc');
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode != 200) {
        print('Autocomplete HTTP ${resp.statusCode}');
        return [];
      }
      final data = json.decode(resp.body);
      if (data['status'] == 'OK' && data['predictions'] != null) {
        final preds = List<Map<String, dynamic>>.from(data['predictions']);
        print('Autocomplete count=${preds.length}');
        return preds;
      } else {
        final status = data['status']?.toString() ?? 'UNKNOWN';
        final err = data['error_message']?.toString();
        print('Autocomplete status=$status error=${err ?? ''}');
        return [];
      }
    } catch (e) {
      print('Autocomplete error: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> placeDetails({
    required String placeId,
    bool includeEditorialSummary = true,
  }) async {
    if (!_googleEnabled) return null;
    const baseFields =
        'name,formatted_address,formatted_phone_number,international_phone_number,website,url,opening_hours,rating,user_ratings_total,reviews,photos,geometry,types,business_status,vicinity';
    final fields = includeEditorialSummary ? '$baseFields,editorial_summary' : baseFields;
    final url =
        'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=$fields&key=$_apiKey';
    try {
      print('Place details for $placeId');
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode != 200) {
        print('Details HTTP ${resp.statusCode}');
        return null;
      }
      final data = json.decode(resp.body);
      if (data['status'] == 'OK' && data['result'] != null) {
        final result = Map<String, dynamic>.from(data['result']);
        result['photo_urls'] = extractAllPhotoUrls(result, maxWidth: 800);
        final photoUrl = result['photo_urls'] is List && (result['photo_urls'] as List).isNotEmpty
            ? (result['photo_urls'] as List).first
            : extractPhotoUrlFromPlace(result, maxWidth: 800);
        if (photoUrl != null) {
          result['church_image_url'] = photoUrl;
        }
        result['description'] = buildDescriptionFromDetails(result);
        return result;
      } else if (data['status'] == 'INVALID_REQUEST' &&
          fields.contains('editorial_summary')) {
        return placeDetails(placeId: placeId, includeEditorialSummary: false);
      } else {
        final status = data['status']?.toString() ?? 'UNKNOWN';
        final err = data['error_message']?.toString();
        print('Details status=$status error=${err ?? ''}');
        return null;
      }
    } catch (e) {
      print('Details error: $e');
      return null;
    }
  }

  static Future<String> reverseGeocodeCity({
    required LatLng location,
  }) async {
    if (!_googleEnabled) {
      return '${location.latitude.toStringAsFixed(2)}, ${location.longitude.toStringAsFixed(2)}';
    }
    final url = 'https://maps.googleapis.com/maps/api/geocode/json?latlng=${location.latitude},${location.longitude}&key=$_apiKey';
    try {
      print('Reverse geocode: ${location.latitude},${location.longitude}');
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode != 200) {
        print('Geocode HTTP ${resp.statusCode}');
        return '${location.latitude.toStringAsFixed(2)}, ${location.longitude.toStringAsFixed(2)}';
      }
      final data = json.decode(resp.body);
      if (data['status'] == 'OK' && data['results'] != null && (data['results'] as List).isNotEmpty) {
        final first = Map<String, dynamic>.from(data['results'][0]);
        final comps = List<Map<String, dynamic>>.from(first['address_components']);
        String? city;
        String? admin;
        for (final c in comps) {
          final types = List<String>.from(c['types']);
          if (types.contains('locality')) {
            city = c['long_name'];
          }
          if (types.contains('administrative_area_level_1')) {
            admin = c['short_name'];
          }
        }
        if (city != null && admin != null) return '$city, $admin';
        if (city != null) return city;
        if (admin != null) return admin;
      } else {
        final status = data['status']?.toString() ?? 'UNKNOWN';
        final err = data['error_message']?.toString();
        print('Geocode status=$status error=${err ?? ''}');
      }
    } catch (e) {
      print('Reverse geocode error: $e');
    }
    return '${location.latitude.toStringAsFixed(2)}, ${location.longitude.toStringAsFixed(2)}';
  }

  // Directions API
  static Future<List<Map<String, dynamic>>?> directions({
    required LatLng origin,
    required LatLng destination,
    String mode = 'driving',
  }) async {
    if (!_googleEnabled) return null;
    final url = 'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${origin.latitude},${origin.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '&mode=$mode'
        '&alternatives=true'
        '&key=$_apiKey';
    try {
      final resp = await http.get(Uri.parse(url));
      print('DEBUG: Directions API status code: ${resp.statusCode}');
      
      if (resp.statusCode != 200) {
        print('DEBUG: Directions API error body: ${resp.body}');
        return null;
      }
      
      final data = json.decode(resp.body);
      if (data['status'] != 'OK') {
        print('DEBUG: Directions API Status: ${data['status']}');
        if (data['error_message'] != null) {
          print('DEBUG: Directions error_message: ${data['error_message']}');
        }
        return null;
      }
      
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return null;

      final List<Map<String, dynamic>> resultList = [];

      for (var routeData in routes) {
        final route = routeData as Map<String, dynamic>;
        final overview = route['overview_polyline']?['points']?.toString();
        final legs = (route['legs'] as List?)?.cast<Map<String, dynamic>>();
        
        String distanceText = '';
        String durationText = '';
        int distanceMeters = 0;
        int durationSeconds = 0;
        if (legs != null && legs.isNotEmpty) {
          distanceText = legs.first['distance']?['text']?.toString() ?? '';
          durationText = legs.first['duration']?['text']?.toString() ?? '';
          distanceMeters = (legs.first['distance']?['value'] as num?)?.toInt() ?? 0;
          durationSeconds = (legs.first['duration']?['value'] as num?)?.toInt() ?? 0;
        }
        
        final points = overview != null ? _decodePolyline(overview) : <LatLng>[];
        
        // Process each step to extract clean distance and duration (keep both formats)
        final processedSteps = <Map<String, dynamic>>[];
        if (legs != null && legs.isNotEmpty && legs.first['steps'] != null) {
          final rawSteps = legs.first['steps'] as List;
          for (var step in rawSteps) {
            if (step is Map) {
              final processedStep = Map<String, dynamic>.from(step);

              final rawInstruction = step['html_instructions']?.toString() ?? '';
              processedStep['instruction'] = stripHtml(rawInstruction);
              processedStep['maneuver'] = step['maneuver']?.toString() ?? '';
              processedStep['start_location'] = step['start_location'];
              processedStep['end_location'] = step['end_location'];
              
              // Extract clean distance (both formats for compatibility)
              if (step['distance'] != null && step['distance'] is Map) {
                processedStep['distance'] = step['distance']; // Keep original map format
                processedStep['distanceText'] = step['distance']['text']?.toString() ?? '';
                processedStep['distanceMeters'] =
                    (step['distance']['value'] as num?)?.toInt() ?? 0;
              } else {
                processedStep['distanceText'] = '';
                processedStep['distanceMeters'] = 0;
              }
              
              // Extract clean duration (both formats for compatibility)
              if (step['duration'] != null && step['duration'] is Map) {
                processedStep['duration'] = step['duration']; // Keep original map format
                processedStep['durationText'] = step['duration']['text']?.toString() ?? '';
                processedStep['durationSeconds'] =
                    (step['duration']['value'] as num?)?.toInt() ?? 0;
              } else {
                processedStep['durationText'] = '';
                processedStep['durationSeconds'] = 0;
              }
              
              processedSteps.add(processedStep);
            }
          }
        }
        final steps = processedSteps;

        resultList.add({
          'points': points,
          'distance': distanceText,
          'total_distance': distanceText,
          'distanceText': distanceText,
          'distanceMeters': distanceMeters,
          'duration': durationText,
          'total_duration': durationText,
          'durationText': durationText,
          'durationSeconds': durationSeconds,
          'steps': steps,
          'summary': {'distance': distanceText, 'duration': durationText},
          'legs': [
            {
              'distance': {'text': distanceText, 'value': distanceMeters},
              'duration': {'text': durationText, 'value': durationSeconds},
              'steps': steps,
            }
          ],
        });
      }
      
      return resultList;
    } catch (e) {
      print('Directions error: $e');
      return null;
    }
  }

  static List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      poly.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return poly;
  }
}
