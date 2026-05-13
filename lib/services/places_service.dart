import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../config/api_config.dart'; // Ensure you have your Places API Key here or in a secure place

class PlacesService {
  static final String _apiKey = ApiConfig.googleMapsApiKey;

  static Future<List<Map<String, dynamic>>> searchChurches({
    required LatLng location,
    String? denomination,
    double radius = 5000, // 5km radius
  }) async {
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

    final String initialUrl = '$baseUrl?query=$query&type=church&location=${location.latitude},${location.longitude}&radius=$radius&key=$_apiKey';

    try {
      // Only 1 page for maximum speed
      final results = <Map<String, dynamic>>[];
      
      final response = await http.get(Uri.parse(initialUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'] != null) {
          results.addAll(List<Map<String, dynamic>>.from(data['results']));
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
            return List<Map<String, dynamic>>.from(data['results']);
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
          results.addAll(List<Map<String, dynamic>>.from(data['results']));
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
          results.addAll(List<Map<String, dynamic>>.from(data['results']));
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
  }) async {
    final url = 'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=geometry,name,formatted_address&key=$_apiKey';
    try {
      print('Place details for $placeId');
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode != 200) {
        print('Details HTTP ${resp.statusCode}');
        return null;
      }
      final data = json.decode(resp.body);
      if (data['status'] == 'OK' && data['result'] != null) {
        return Map<String, dynamic>.from(data['result']);
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
        if (legs != null && legs.isNotEmpty) {
          distanceText = legs.first['distance']?['text']?.toString() ?? '';
          durationText = legs.first['duration']?['text']?.toString() ?? '';
        }
        
        final points = overview != null ? _decodePolyline(overview) : <LatLng>[];
        
        // Process each step to extract clean distance and duration (keep both formats)
        final processedSteps = <Map<String, dynamic>>[];
        if (legs != null && legs.isNotEmpty && legs.first['steps'] != null) {
          final rawSteps = legs.first['steps'] as List;
          for (var step in rawSteps) {
            if (step is Map) {
              final processedStep = Map<String, dynamic>.from(step);
              
              // Extract clean distance (both formats for compatibility)
              if (step['distance'] != null && step['distance'] is Map) {
                processedStep['distance'] = step['distance']; // Keep original map format
                processedStep['distanceText'] = step['distance']['text']?.toString() ?? '';
              } else {
                processedStep['distanceText'] = '';
              }
              
              // Extract clean duration (both formats for compatibility)
              if (step['duration'] != null && step['duration'] is Map) {
                processedStep['duration'] = step['duration']; // Keep original map format
                processedStep['durationText'] = step['duration']['text']?.toString() ?? '';
              } else {
                processedStep['durationText'] = '';
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
          'duration': durationText,
          'total_duration': durationText,
          'durationText': durationText,
          'steps': steps,
          'summary': {'distance': distanceText, 'duration': durationText},
          'legs': [
            {
              'distance': {'text': distanceText},
              'duration': {'text': durationText},
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
