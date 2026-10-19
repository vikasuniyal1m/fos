import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../config/api_config.dart';
import 'hive_cache_service.dart';

/// Progressive UI — har batch ke baad call (2 → 4 → 8 …).
typedef ChurchNearbyProgressCallback = void Function(
  List<Map<String, dynamic>> accumulated, {
  required bool done,
});

/// Google API fail hone par — OpenStreetMap se live nearby churches fetch.
/// Koi hardcoded list nahi; user ki location ke hisaab se data aata hai.
class ChurchLocatorService {
  static const String _hiveKey = 'church_nearby_places';
  static const List<String> _overpassUrls = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
  ];
  static DateTime? _lastOverpassCallAt;
  static const Duration _overpassMinGap = Duration(milliseconds: 1200);
  static DateTime? _lastNominatimCallAt;
  static DateTime? _nominatimCooldownUntil;
  static const Duration _nominatimMinGap = Duration(milliseconds: 2500);
  static String? _cityCacheLabel;
  static LatLng? _cityCacheCenter;
  static DateTime? _cityCacheAt;

  /// Nominatim 429 ke baad — aur calls skip.
  static bool get isNominatimPaused {
    if (_nominatimCooldownUntil == null) return false;
    if (DateTime.now().isBefore(_nominatimCooldownUntil!)) return true;
    _nominatimCooldownUntil = null;
    return false;
  }

  static void _nominatimRateLimited() {
    _nominatimCooldownUntil = DateTime.now().add(const Duration(seconds: 45));
    print('[ChurchLocator][Nominatim] rate limited — pause 45s');
  }

  static bool _isValidCityLabel(String city) {
    final s = city.trim();
    if (s.isEmpty) return false;
    if (RegExp(r'^-?\d').hasMatch(s)) return false;
    return !s.contains(RegExp(r'^\d+\.\d+'));
  }
  static const String _nominatimUrl = 'https://nominatim.openstreetmap.org/search';
  static const String _userAgent = 'FOSMessenger/ChurchLocator';

  static List<Map<String, dynamic>>? _osmCache;
  static LatLng? _osmCacheCenter;
  static DateTime? _osmCacheAt;
  static const Duration _osmCacheTtl = Duration(minutes: 8);
  static const int _minAcceptableNearby = 12;
  static const int _minOsmCacheCount = 2;

  static void clearOsmMemoryCache() {
    _osmCache = null;
    _osmCacheCenter = null;
    _osmCacheAt = null;
  }

  /// App open / fresh search — purana Nominatim cooldown hatao.
  static void resetNominatimCooldown() {
    _nominatimCooldownUntil = null;
  }

  /// 10 km — is radius ke andar ke SAARE churches dikhao (5–10 km user range).
  static const double nearbyRadiusMeters = 10000;

  static double haversineMeters(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) * math.cos(_toRad(lat2)) * math.sin(dLon / 2) * math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _toRad(double deg) => deg * math.pi / 180.0;

  /// Last fetch stats — console report ke liye.
  static int lastOverpassElements = 0;
  static int lastOsmParsed = 0;
  static int lastOsmRejected = 0;
  static int lastNominatimCount = 0;
  static int lastWithinRadius = 0;
  static int lastMergedTotal = 0;

  static List<Map<String, dynamic>> _finalizeChristianNearby(
    Map<String, Map<String, dynamic>> merged,
    LatLng center,
    double radiusMeters,
  ) {
    return filterWithinRadius(
      merged.values
          .where((p) => !isExplicitlyNonChristian(p) && _looksLikeChristianPlace(p))
          .toList(),
      center,
      radiusMeters,
    );
  }

  /// Sirf OSM fetch — hive skip, markers ke liye fast path.
  static Future<List<Map<String, dynamic>>> fetchOsmNearby(
    LatLng center, {
    double radiusMeters = nearbyRadiusMeters,
    ChurchNearbyProgressCallback? onProgress,
  }) async {
    lastOverpassElements = 0;
    lastOsmParsed = 0;
    lastOsmRejected = 0;
    lastNominatimCount = 0;
    lastWithinRadius = 0;
    lastMergedTotal = 0;

    final merged = <String, Map<String, dynamic>>{};
    var lastEmitted = 0;

    void emit({required bool done}) {
      final raw = _finalizeChristianNearby(merged, center, radiusMeters);
      if (raw.length != lastEmitted || done) {
        lastEmitted = raw.length;
        onProgress?.call(List<Map<String, dynamic>>.from(raw), done: done);
      }
    }

    void mergePlace(Map<String, dynamic> p) {
      if (isExplicitlyNonChristian(p)) return;
      final pid = p['place_id']?.toString() ?? '';
      final fromOsm = pid.startsWith('osm_');
      if (!fromOsm && !_looksLikeChristianPlace(p)) return;
      if (fromOsm &&
          !_looksLikeChristianPlace(p) &&
          !isChristianChurch(p) &&
          (p['religion']?.toString().toLowerCase() ?? '') != 'christian') {
        return;
      }
      final id = _dedupeKey(p);
      if (id.isEmpty) return;
      final isNew = !merged.containsKey(id);
      merged[id] = p;
      if (isNew) emit(done: false);
    }

    // Pehle Overpass — Nominatim 429 pe bhi churches aayen
    final fromOsm = await _fetchNearbyFromOsm(
      center,
      radiusMeters: radiusMeters,
      onBatch: (batch) {
        for (final p in batch) {
          mergePlace(p);
        }
      },
    );
    print('[ChurchLocator][OSM] Overpass parsed: ${fromOsm.length} '
        '@ ${center.latitude},${center.longitude} r=${radiusMeters.round()}m');
    for (final p in fromOsm) {
      mergePlace(p);
    }
    emit(done: false);

    if (!isNominatimPaused) {
      final nomCount = await _nearbyFromNominatim(
        center,
        radiusMeters: radiusMeters,
        onPlace: mergePlace,
        onBatch: () => emit(done: false),
      );
      lastNominatimCount = nomCount;
      print('[ChurchLocator][Nominatim] added: $nomCount');
      emit(done: false);
    } else {
      print('[ChurchLocator][Nominatim] skipped — rate limit cooldown');
    }

    if (merged.length < _minAcceptableNearby) {
      final photon = await _nearbyFromPhoton(center, radiusMeters: radiusMeters);
      print('[ChurchLocator][Photon] added: ${photon.length}');
      for (final p in photon) {
        mergePlace(p);
      }
    }

    if (ApiConfig.churchesRemoteJsonUrl.isNotEmpty) {
      final remote = await _fetchRemoteJsonChurches(center, radiusMeters);
      print('[ChurchLocator][RemoteJSON] ${remote.length} from ${ApiConfig.churchesRemoteJsonUrl}');
      for (final p in remote) {
        mergePlace(p);
      }
      emit(done: false);
    }

    final raw = _finalizeChristianNearby(merged, center, radiusMeters);
    lastWithinRadius = raw.length;
    lastMergedTotal = raw.length;
    onProgress?.call(List<Map<String, dynamic>>.from(raw), done: true);
    _printChurchSample('merged nearby', raw);
    printPipelineReport(displayed: raw.length);
    return raw;
  }

  /// Optional hosted churches.json — world-wide ek file nahi, tumhara URL ho to merge.
  static Future<List<Map<String, dynamic>>> _fetchRemoteJsonChurches(
    LatLng center,
    double radiusMeters,
  ) async {
    final url = ApiConfig.churchesRemoteJsonUrl.trim();
    if (url.isEmpty) return [];
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': _userAgent, 'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return [];

      final data = json.decode(response.body);
      final list = data is List
          ? data
          : (data is Map && data['churches'] is List)
              ? data['churches'] as List
              : <dynamic>[];
      final out = <Map<String, dynamic>>[];
      for (final item in list) {
        if (item is! Map) continue;
        final m = Map<String, dynamic>.from(item);
        final lat = m['lat'] ?? m['latitude'] ?? m['geometry']?['location']?['lat'];
        final lng = m['lng'] ?? m['lon'] ?? m['longitude'] ?? m['geometry']?['location']?['lng'];
        if (lat is! num || lng is! num) continue;
        final dist = haversineMeters(center.latitude, center.longitude, lat.toDouble(), lng.toDouble());
        if (dist > radiusMeters) continue;
        out.add({
          'place_id': m['place_id']?.toString() ?? 'json_${lat}_$lng',
          'name': m['name']?.toString() ?? 'Church',
          'vicinity': m['vicinity'] ?? m['address'] ?? '',
          'formatted_address': m['formatted_address'] ?? m['address'] ?? '',
          'denomination': m['denomination']?.toString() ?? _denominationFromName(m['name']?.toString() ?? ''),
          'religion': 'christian',
          'geometry': {'location': {'lat': lat.toDouble(), 'lng': lng.toDouble()}},
        });
      }
      return out;
    } catch (e) {
      print('[ChurchLocator][RemoteJSON] error: $e');
      return [];
    }
  }

  static void printPipelineReport({int displayed = 0}) {
    print('');
    print('╔══════════════════════════════════════════╗');
    print('║       CHURCH LOCATOR — PIPELINE REPORT   ║');
    print('╠══════════════════════════════════════════╣');
    print('║ 1) OSM Overpass raw elements : $lastOverpassElements');
    print('║ 2) OSM parsed (named)        : $lastOsmParsed');
    print('║ 3) OSM rejected (filtered)   : $lastOsmRejected');
    print('║ 4) Nominatim extra           : $lastNominatimCount');
    print('║ 5) Within 10km radius        : $lastWithinRadius');
    print('║ 6) DISPLAY on map + list     : $displayed');
    print('╚══════════════════════════════════════════╝');
    print('');
  }

  /// Radius ke andar + distance sort — koi count cap nahi.
  static List<Map<String, dynamic>> filterWithinRadius(
    List<Map<String, dynamic>> places,
    LatLng center,
    double radiusMeters,
  ) {
    final out = <Map<String, dynamic>>[];
    for (final p in places) {
      final loc = p['geometry']?['location'];
      if (loc is! Map || loc['lat'] is! num || loc['lng'] is! num) continue;
      final dist = haversineMeters(
        center.latitude,
        center.longitude,
        (loc['lat'] as num).toDouble(),
        (loc['lng'] as num).toDouble(),
      );
      if (dist > radiusMeters) continue;
      final copy = Map<String, dynamic>.from(p);
      copy['_distance_meters'] = dist;
      out.add(copy);
    }
    out.sort((a, b) {
      final da = (a['_distance_meters'] as num?)?.toDouble() ?? double.infinity;
      final db = (b['_distance_meters'] as num?)?.toDouble() ?? double.infinity;
      return da.compareTo(db);
    });
    return out;
  }

  static void _printChurchSample(String label, List<Map<String, dynamic>> list) {
    print('[ChurchLocator][$label] total=${list.length}');
    for (var i = 0; i < list.length && i < 15; i++) {
      final p = list[i];
      final loc = p['geometry']?['location'];
      print('[ChurchLocator]  ${i + 1}. ${p['name']} '
          '(${loc?['lat']}, ${loc?['lng']}) id=${p['place_id']}');
    }
    if (list.length > 15) {
      print('[ChurchLocator]  ... +${list.length - 15} more churches');
    }
  }

  static Future<int> _nearbyFromNominatim(
    LatLng center, {
    double radiusMeters = nearbyRadiusMeters,
    void Function(Map<String, dynamic> place)? onPlace,
    void Function()? onBatch,
  }) async {
    var count = 0;
    if (isNominatimPaused) return 0;

    final city = await reverseGeocodeCity(center);
    final cityShort =
        _isValidCityLabel(city) ? city.split(',').first.trim() : '';

    void absorb(List<Map<String, dynamic>> batch) {
      var added = false;
      for (final p in batch) {
        if (isExplicitlyNonChristian(p)) continue;
        if (!_nominatimAcceptForNearby(p)) continue;
        final loc = p['geometry']?['location'];
        if (loc is! Map || loc['lat'] is! num || loc['lng'] is! num) continue;
        final dist = haversineMeters(
          center.latitude,
          center.longitude,
          (loc['lat'] as num).toDouble(),
          (loc['lng'] as num).toDouble(),
        );
        if (dist > radiusMeters) continue;
        onPlace?.call(p);
        count++;
        added = true;
      }
      if (added) onBatch?.call();
    }

    // Kam queries — 429 avoid (max ~1 req / 2.5s)
    final queries = <String>[
      'st mary',
      if (cityShort.isNotEmpty) 'church $cityShort',
      if (cityShort.isNotEmpty) 'christian church $cityShort',
      'baptist church',
      'catholic church',
      'christ king',
      'orthodox church',
    ];

    for (final q in queries) {
      if (isNominatimPaused) break;
      absorb(await _searchFromNominatim(q, bias: center, limit: 10));
      if (count >= 12) break;
    }

    print('[ChurchLocator][Nominatim] unique nearby churches: $count');
    return count;
  }

  /// Nominatim — sirf naam/address me Christian church signal ho to accept.
  static bool _nominatimAcceptForNearby(Map<String, dynamic> place) {
    if (isExplicitlyNonChristian(place)) return false;
    return _looksLikeChristianPlace(place);
  }

  static bool _looksLikeChristianPlace(Map<String, dynamic> place) {
    final name = (place['name'] ?? '').toString().toLowerCase();
    final vicinity =
        (place['vicinity'] ?? place['formatted_address'] ?? '').toString().toLowerCase();
    final text = '$name $vicinity';
    if (text.trim().isEmpty) return false;

    const keys = [
      'church', 'chapel', 'cathedral', 'parish', 'baptist', 'catholic',
      'christian', 'orthodox', 'methodist', 'presbyterian', 'lutheran',
      'anglican', 'pentecostal', 'evangelical', 'adventist', 'mar thoma',
      'syrian', 'congregation', 'basilica', 'abbey', 'mission',
      'st.', 'st ', 'saint', 'holy', 'sacred', 'christ', 'bethel',
      'trinity', 'zion', 'calvary', 'protestant', 'episcopal',
    ];
    return keys.any(text.contains);
  }

  static Future<List<Map<String, dynamic>>> _nearbyFromPhoton(
    LatLng center, {
    double radiusMeters = nearbyRadiusMeters,
  }) async {
    final merged = <String, Map<String, dynamic>>{};
    for (final q in const ['church', 'chapel', 'cathedral', 'christian church']) {
      try {
        final uri = Uri.parse('https://photon.komoot.io/api/').replace(
          queryParameters: {
            'q': q,
            'lat': center.latitude.toString(),
            'lon': center.longitude.toString(),
            'limit': '40',
            'osm_tag': 'amenity:place_of_worship',
          },
        );
        final response = await http.get(
          uri,
          headers: {'User-Agent': _userAgent},
        ).timeout(const Duration(seconds: 8));
        if (response.statusCode != 200) continue;

        final data = json.decode(response.body);
        final features = data is Map ? data['features'] : null;
        if (features is! List) continue;

        for (final f in features) {
          if (f is! Map) continue;
          final props = f['properties'];
          final geom = f['geometry'];
          if (props is! Map || geom is! Map) continue;
          final coords = geom['coordinates'];
          if (coords is! List || coords.length < 2) continue;
          final lng = (coords[0] as num).toDouble();
          final lat = (coords[1] as num).toDouble();
          final dist = haversineMeters(center.latitude, center.longitude, lat, lng);
          if (dist > radiusMeters) continue;

          final name = props['name']?.toString().trim() ?? '';
          if (name.isEmpty) continue;
          final place = {
            'place_id': 'photon_${props['osm_type']}_${props['osm_id']}',
            'name': name,
            'vicinity': [
              props['street'],
              props['city'],
              props['state'],
              props['country'],
            ].whereType<String>().where((s) => s.isNotEmpty).join(', '),
            'formatted_address': props['country']?.toString() ?? '',
            'denomination': _denominationFromName(name),
            'geometry': {
              'location': {'lat': lat, 'lng': lng},
            },
          };
          if (isExplicitlyNonChristian(place)) continue;
          if (!_looksLikeChristianPlace(place)) continue;
          merged[_dedupeKey(place)] = place;
        }
      } catch (e) {
        print('[ChurchLocator][Photon] error: $e');
      }
      await Future.delayed(const Duration(milliseconds: 200));
    }
    return merged.values.toList();
  }

  /// Google empty/fail → OSM live fetch + Hive cache merge.
  static Future<List<Map<String, dynamic>>> nearbyFromLocal({
    required LatLng center,
    double radiusMeters = nearbyRadiusMeters,
    String? denomination,
    String? query,
    int? limit,
  }) async {
    final merged = <String, Map<String, dynamic>>{};

    for (final p in await _loadHiveCached()) {
      if (!isChristianChurch(p)) continue;
      final id = _placeKey(p);
      if (id.isNotEmpty) merged[id] = p;
    }

    for (final p in await fetchOsmNearby(center, radiusMeters: radiusMeters)) {
      if (!isChristianChurch(p)) continue;
      final id = _placeKey(p);
      if (id.isNotEmpty) merged[id] = p;
    }

    final filtered = <Map<String, dynamic>>[];
    for (final p in merged.values) {
      if (!isChristianChurch(p)) continue;
      final loc = p['geometry']?['location'];
      if (loc is! Map) continue;
      final lat = loc['lat'];
      final lng = loc['lng'];
      if (lat is! num || lng is! num) continue;

      final dist = haversineMeters(
        center.latitude,
        center.longitude,
        lat.toDouble(),
        lng.toDouble(),
      );
      if (dist > radiusMeters) continue;
      if (denomination != null && denomination.isNotEmpty && !_matchesDenomination(p, denomination)) {
        continue;
      }
      if (query != null && query.trim().isNotEmpty && !_matchesQuery(p, query.trim())) continue;

      final copy = Map<String, dynamic>.from(p);
      copy['_distance_meters'] = dist;
      filtered.add(copy);
    }

    filtered.sort((a, b) {
      final da = (a['_distance_meters'] as num?)?.toDouble() ?? double.infinity;
      final db = (b['_distance_meters'] as num?)?.toDouble() ?? double.infinity;
      return da.compareTo(db);
    });

    if (limit != null && limit > 0 && filtered.length > limit) {
      return filtered.take(limit).toList();
    }
    return filtered;
  }

  /// Church name se exact location resolve — OSM coords galat hon to Nominatim se fix.
  static Future<Map<String, dynamic>> resolvePlaceLocation(Map<String, dynamic> place) async {
    final name = place['name']?.toString().trim();
    if (name == null || name.isEmpty) return place;

    final loc = place['geometry']?['location'];
    if (loc is! Map || loc['lat'] is! num || loc['lng'] is! num) return place;
    final bias = LatLng((loc['lat'] as num).toDouble(), (loc['lng'] as num).toDouble());

    final target = name.toLowerCase();
    final candidates = await _searchFromNominatim(name, bias: bias, limit: 10, suffixChurch: false);
    if (candidates.isEmpty) return place;

    Map<String, dynamic>? best;
    var bestScore = 0;
    for (final c in candidates) {
      final cName = (c['name'] ?? '').toString().toLowerCase();
      var score = 0;
      if (cName == target) {
        score = 100;
      } else if (cName.contains(target) || target.contains(cName)) {
        score = 80;
      } else {
        final targetWords = target.split(RegExp(r'\s+')).where((w) => w.length > 2).toList();
        if (targetWords.isNotEmpty && targetWords.every((w) => cName.contains(w))) {
          score = 70;
        }
      }
      if (score > bestScore) {
        bestScore = score;
        best = c;
      }
    }

    if (best == null || bestScore < 70) return place;

    return {
      ...place,
      'name': place['name'] ?? best['name'],
      'vicinity': best['vicinity'] ?? place['vicinity'],
      'formatted_address': best['formatted_address'] ?? place['formatted_address'],
      'geometry': best['geometry'] ?? place['geometry'],
      'place_id': place['place_id'] ?? best['place_id'],
      'denomination': place['denomination'] ?? best['denomination'],
    };
  }

  /// Memory se instant filter — typing pe 0ms, network nahi.
  static List<Map<String, dynamic>> filterCachedPlaces({
    required List<Map<String, dynamic>> cached,
    required String input,
    LatLng? locationBias,
    double maxRadiusMeters = nearbyRadiusMeters,
    int limit = 20,
  }) {
    final q = input.trim().toLowerCase();
    if (q.isEmpty || cached.isEmpty) return [];

    final matches = <Map<String, dynamic>>[];
    for (final p in cached) {
      if (!isChristianChurch(p)) continue;
      if (!_matchesQuery(p, q)) continue;
      final copy = Map<String, dynamic>.from(p);
      if (locationBias != null) {
        final loc = copy['geometry']?['location'];
        if (loc is Map && loc['lat'] is num && loc['lng'] is num) {
          final dist = haversineMeters(
            locationBias.latitude,
            locationBias.longitude,
            (loc['lat'] as num).toDouble(),
            (loc['lng'] as num).toDouble(),
          );
          if (dist > maxRadiusMeters) continue;
          copy['_distance_meters'] = dist;
        }
      }
      final name = copy['name']?.toString() ?? 'Church';
      final addr = (copy['vicinity'] ?? copy['formatted_address'] ?? '').toString();
      copy['description'] = addr.isNotEmpty ? '$name — $addr' : name;
      matches.add(copy);
    }

    matches.sort((a, b) {
      final da = (a['_distance_meters'] as num?)?.toDouble() ?? double.infinity;
      final db = (b['_distance_meters'] as num?)?.toDouble() ?? double.infinity;
      return da.compareTo(db);
    });

    return matches.length > limit ? matches.take(limit).toList() : matches;
  }

  /// Cache me exact naam — bina network ke.
  static Map<String, dynamic>? findInCache(
    List<Map<String, dynamic>> cached,
    String query, {
    LatLng? center,
    double maxRadiusMeters = nearbyRadiusMeters,
  }) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return null;

    Map<String, dynamic>? best;
    var bestScore = 0;
    for (final p in cached) {
      if (!isChristianChurch(p)) continue;
      if (center != null) {
        final loc = p['geometry']?['location'];
        if (loc is Map && loc['lat'] is num && loc['lng'] is num) {
          final dist = haversineMeters(
            center.latitude,
            center.longitude,
            (loc['lat'] as num).toDouble(),
            (loc['lng'] as num).toDouble(),
          );
          if (dist > maxRadiusMeters) continue;
        }
      }
      final name = (p['name'] ?? '').toString().toLowerCase();
      var score = 0;
      if (name == q) {
        score = 100;
      } else if (name.contains(q) || q.contains(name)) {
        score = 85;
      } else {
        final words = q.split(RegExp(r'\s+')).where((w) => w.length > 2).toList();
        if (words.isNotEmpty && words.every((w) => name.contains(w))) score = 75;
      }
      if (score > bestScore) {
        bestScore = score;
        best = p;
      }
    }
    return bestScore >= 75 ? best : null;
  }

  /// Same name search — pehle cache, phir sirf Nominatim (Overpass skip = fast).
  static Future<Map<String, dynamic>?> findChurchByName({
    required String query,
    required LatLng center,
    List<Map<String, dynamic>>? cachedPlaces,
  }) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return null;

    final cache = cachedPlaces ?? <Map<String, dynamic>>[];
    final fromCache = findInCache(cache, q, center: center);
    if (fromCache != null) return resolvePlaceLocation(fromCache);

    final nearby = filterCachedPlaces(
      cached: cache,
      input: q,
      locationBias: center,
      maxRadiusMeters: nearbyRadiusMeters,
      limit: 30,
    );
    Map<String, dynamic>? best;
    var bestScore = 0;
    for (final p in nearby) {
      final name = (p['name'] ?? '').toString().toLowerCase();
      var score = 0;
      if (name == q) {
        score = 100;
      } else if (name.contains(q) || q.contains(name)) {
        score = 85;
      } else {
        final words = q.split(RegExp(r'\s+')).where((w) => w.length > 2).toList();
        if (words.isNotEmpty && words.every((w) => name.contains(w))) score = 75;
      }
      if (score > bestScore) {
        bestScore = score;
        best = p;
      }
    }
    if (best != null && bestScore >= 75) {
      return resolvePlaceLocation(best);
    }

    final nom = filterWithinRadius(
      await _searchFromNominatim(query, bias: center, limit: 15, suffixChurch: true),
      center,
      nearbyRadiusMeters,
    );
    for (final p in nom) {
      final name = (p['name'] ?? '').toString().toLowerCase();
      if (name == q || name.contains(q) || q.contains(name)) {
        return resolvePlaceLocation(p);
      }
    }
    return nom.isNotEmpty ? resolvePlaceLocation(nom.first) : null;
  }

  /// Fast suggestions — cache pehle, network sirf zarurat par.
  static Future<List<Map<String, dynamic>>> localSuggestions({
    required String input,
    LatLng? locationBias,
    double maxRadiusMeters = nearbyRadiusMeters,
    int limit = 20,
    List<Map<String, dynamic>>? cachedPlaces,
    bool fetchNetwork = true,
  }) async {
    final q = input.trim();
    if (q.isEmpty) return [];

    final merged = <String, Map<String, dynamic>>{};

    if (cachedPlaces != null && cachedPlaces.isNotEmpty) {
      for (final p in filterCachedPlaces(
        cached: cachedPlaces,
        input: q,
        locationBias: locationBias,
        maxRadiusMeters: maxRadiusMeters,
        limit: limit,
      )) {
        merged[_placeKey(p)] = p;
      }
    }

    if (fetchNetwork &&
        !isNominatimPaused &&
        merged.length < limit &&
        locationBias != null) {
      final remote = filterWithinRadius(
        await _searchFromNominatim(q, bias: locationBias, limit: limit, suffixChurch: true),
        locationBias,
        maxRadiusMeters,
      );
      for (final p in remote) {
        if (!isChristianChurch(p)) continue;
        final id = _placeKey(p);
        if (id.isNotEmpty) merged[id] = p;
      }
    }

    final matches = merged.values.where(isChristianChurch).map((p) {
      final copy = Map<String, dynamic>.from(p);
      if (locationBias != null) {
        final loc = copy['geometry']?['location'];
        if (loc is Map && loc['lat'] is num && loc['lng'] is num) {
          copy['_distance_meters'] = haversineMeters(
            locationBias.latitude,
            locationBias.longitude,
            (loc['lat'] as num).toDouble(),
            (loc['lng'] as num).toDouble(),
          );
        }
      }
      final name = copy['name']?.toString() ?? 'Church';
      final addr = (copy['vicinity'] ?? copy['formatted_address'] ?? '').toString();
      copy['description'] = addr.isNotEmpty ? '$name — $addr' : name;
      return copy;
    }).toList();

    final within = locationBias != null
        ? filterWithinRadius(matches, locationBias, maxRadiusMeters)
        : matches;

    return within.length > limit ? within.take(limit).toList() : within;
  }

  /// Sirf Christian church — religion/denomination/community se bhi pehchan.
  static bool isChristianWorshipPlace(Map<String, dynamic> place) {
    if (isExplicitlyNonChristian(place)) return false;

    final religion = (place['religion'] ?? place['osm_religion'] ?? '').toString().toLowerCase();
    if (religion == 'christian') return true;

    final denom = (place['denomination'] ?? '').toString().toLowerCase();
    if (denom.isNotEmpty && isChristianOsmDenomination(denom)) return true;

    if (isChristianChurch(place)) return true;

    final community = (place['community'] ?? place['operator'] ?? '').toString();
    if (community.isNotEmpty && isChristianChurch({'name': community})) return true;

    return false;
  }

  /// OSM denomination=* values — Christian only (wiki.openstreetmap.org/wiki/Key:denomination).
  static const Set<String> _christianOsmDenominationTags = {
    'catholic', 'armenian_catholic', 'chaldean_catholic', 'coptic_catholic',
    'eritrean_catholic', 'ethiopian_catholic', 'greek_catholic', 'maronite',
    'polish_catholic', 'roman_catholic', 'romanian_catholic', 'syriac_catholic',
    'syro-malabar_catholic', 'ukrainian_greek_catholic', 'liberal_catholic',
    'old_catholic', 'catholic_mariavite', 'mariavite', 'polish_national_catholic',
    'orthodox', 'albanian_orthodox', 'antiochian_orthodox', 'armenian_apostolic',
    'bulgarian_orthodox', 'eritrean_orthodox', 'ethiopian_orthodox', 'coptic_orthodox',
    'georgian_orthodox', 'greek_orthodox', 'macedonian_orthodox', 'old_believers',
    'polish_orthodox', 'romanian_orthodox', 'russian_orthodox', 'serbian_orthodox',
    'syriac_orthodox', 'ukrainian_orthodox', 'protestant', 'adventist',
    'seventh_day_adventist', 'anabaptist', 'anglican', 'baptist', 'strict_baptist',
    'welsh_baptist', 'disciples_of_christ', 'episcopal', 'scottish_episcopal',
    'evangelical', 'evangelical_covenant', 'evangelical_free_church_of_america',
    'evangelical_lutheran', 'evangelical_free_church_of_france', 'exclusive_brethren',
    'lutheran', 'mennonite', 'methodist', 'united_methodist', 'african_methodist_episcopal',
    'african_methodist_episcopal_zion', 'calvinistic_methodist', 'moravian',
    'pentecostal', 'foursquare', 'presbyterian', 'orthodox_presbyterian_church',
    'presbyterian_church_usa', 'presbyterian_church_in_america', 'church_of_scotland',
    'free_church_of_scotland', 'united_free_church_of_scotland', 'dutch_reformed',
    'quaker', 'reformed', 'united_reformed', 'uniting', 'united', 'united_church_of_christ',
    'pkn', 'remonstrant', 'apostolic', 'assyrian', 'bosnian_church', 'charismatic',
    'christian_community', 'christ_scientist', 'church_of_christ', 'churches_of_christ',
    'congregational', 'ecumenical', 'fsspx', 'harrist', 'iglesia_ni_cristo',
    'jehovahs_witness', 'kimbanguist', 'la_luz_del_mundo', 'messianic_jewish',
    'new_apostolic', 'nondenominational', 'philippine_independent', 'shizmatic',
    'simultaneum', 'spiritist', 'mormon', 'nazarene', 'salvation_army',
    'alliance', 'apostolic_faith', 'assemblies_of_god', 'brethren_in_christ',
    'catholic_apostolic', 'church_of_god_in_christ', 'czechoslovak_hussite',
    'living_waters_church', 'mission_covenant_church_of_sweden', 'new_frontiers',
    'temple_society_australia', 'welsh_independent',
  };

  static String _normalizeOsmDenomination(String raw) =>
      raw.toLowerCase().trim().replaceAll('-', '_');

  static bool isChristianOsmDenomination(String? raw) {
    if (raw == null || raw.isEmpty) return false;
    final d = _normalizeOsmDenomination(raw);
    if (_christianOsmDenominationTags.contains(d)) return true;
    final dHyph = d.replaceAll('_', '-');
    if (_christianOsmDenominationTags.contains(dHyph)) return true;
    for (final tag in _christianOsmDenominationTags) {
      if (d.contains(tag) || dHyph.contains(tag.replaceAll('_', '-'))) return true;
    }
    return _christianDenominationTag(d);
  }

  static bool _christianDenominationTag(String denom) {
    const tags = [
      'catholic', 'baptist', 'protestant', 'orthodox', 'anglican', 'methodist',
      'presbyterian', 'lutheran', 'pentecostal', 'evangelical', 'adventist',
      'mormon', 'jehovah', 'quaker', 'mennonite', 'nondenominational',
      'maronite', 'coptic', 'episcopal', 'wesleyan', 'congregational',
      'mar thoma', 'syrian', 'brethren', 'assembly of god', 'csi', 'cni',
      'malankara', 'malabar', 'syro', 'mar_thoma',
    ];
    final d = denom.toLowerCase();
    return tags.any((t) => d.contains(t));
  }

  /// OSM tags se Christian church pehchan — religion, building, denomination.
  static bool isChristianOsmElement(Map<String, dynamic> tags) {
    final religion = tags['religion']?.toString().toLowerCase() ?? '';
    if (religion == 'christian') return true;

    final building = tags['building']?.toString().toLowerCase() ?? '';
    if (building == 'church' || building == 'chapel' || building == 'cathedral') {
      return true;
    }

    final amenity = tags['amenity']?.toString().toLowerCase() ?? '';
    final denom = tags['denomination']?.toString();
    if (amenity == 'place_of_worship' && isChristianOsmDenomination(denom)) {
      return true;
    }

    return false;
  }

  static String osmDenominationToLabel(String? rawTag) {
    if (rawTag == null || rawTag.isEmpty) return 'Church';
    final d = _normalizeOsmDenomination(rawTag);

    if (d.contains('nondenominational')) return 'Non-denominational';
    if (d.contains('jehovah')) return "Jehovah's Witness";
    if (d.contains('mormon')) return 'Mormon';
    if (d.contains('salvation_army')) return 'Salvation Army';
    if (d.contains('seventh_day') || d.contains('adventist')) return 'Adventist';
    if (d.contains('pentecostal') || d.contains('assemblies_of_god') || d.contains('foursquare')) {
      return 'Pentecostal';
    }
    if (d.contains('baptist')) return 'Baptist';
    if (d.contains('methodist')) return 'Methodist';
    if (d.contains('lutheran')) return 'Lutheran';
    if (d.contains('presbyterian') || d.contains('reformed') || d.contains('church_of_scotland')) {
      return 'Presbyterian';
    }
    if (d.contains('anglican') || d.contains('episcopal')) return 'Anglican';
    if (d.contains('catholic') || d.contains('maronite') || d.contains('syro') || d.contains('malabar')) {
      return 'Catholic';
    }
    if (d.contains('orthodox') || d.contains('coptic') || d.contains('mar_thoma') || d.contains('syrian')) {
      return 'Orthodox';
    }
    if (d.contains('evangelical')) return 'Evangelical';
    if (d.contains('protestant') || d.contains('congregational') || d.contains('brethren')) {
      return 'Protestant';
    }
    if (d.contains('quaker')) return 'Quaker';
    if (d.contains('mennonite') || d.contains('anabaptist')) return 'Mennonite';
    if (d.contains('moravian')) return 'Moravian';
    if (d.contains('charismatic')) return 'Charismatic';
    if (d.contains('nazarene')) return 'Nazarene';

    return rawTag
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  static String _denominationFromOsmTags(Map<String, dynamic> tags, String fallbackName) {
    final raw = tags['denomination']?.toString();
    if (raw != null && raw.isNotEmpty && isChristianOsmDenomination(raw)) {
      return osmDenominationToLabel(raw);
    }
    return _denominationFromName(fallbackName);
  }

  /// Mandir/masjid etc — sirf inhe reject.
  static bool isExplicitlyNonChristian(Map<String, dynamic> place) {
    final religion = (place['religion'] ?? place['osm_religion'] ?? '').toString().toLowerCase();
    if (religion == 'christian') return false;

    // Sirf raw OSM tag — parsed label "Church" galat match deta tha (catholic⊃church).
    final osmDenomRaw = place['osm_denomination']?.toString();
    if (osmDenomRaw != null &&
        osmDenomRaw.isNotEmpty &&
        isChristianOsmDenomination(osmDenomRaw)) {
      return false;
    }

    final building = (place['building'] ?? '').toString().toLowerCase();
    if (building == 'church' || building == 'chapel' || building == 'cathedral') {
      return false;
    }

    final name = (place['name'] ?? '').toString().toLowerCase();
    final vicinity =
        (place['vicinity'] ?? place['formatted_address'] ?? '').toString().toLowerCase();
    final denomination = (place['denomination'] ?? '').toString().toLowerCase();
    final combined = '$name $vicinity $denomination';

    const nonChristianReligions = [
      'hindu', 'muslim', 'islam', 'sikh', 'buddhist', 'buddhism', 'jain',
      'jewish', 'judaism', 'bahai', 'taoist', 'shinto', 'pagan', 'multifaith',
    ];
    if (nonChristianReligions.any((r) => religion == r || religion.contains(r))) {
      return true;
    }

    const excludeKeywords = [
      'mandir', 'madir', 'masjid', 'maszid', 'mosque', 'gurdwara', 'gurudwara',
      'synagogue', 'pagoda', 'dargah', 'derasar', 'jama masjid', 'hanuman',
      'shiva', 'durga', 'lakshmi', 'kali temple', 'jain temple', 'hindu temple',
      'buddhist', 'vihara', 'stupa', 'sanatan', 'dharam', 'bhawan', 'akshardham',
      'iskcon', 'isckon', 'gurmat', 'satsang', 'radha', 'krishna', 'gugga',
      'sankat mochan', 'math mandir', 'nada sahib',
    ];
    if (excludeKeywords.any(combined.contains)) return true;

    if (RegExp(r'\broad\b|\bsector\b|\bblock\b').hasMatch(combined) &&
        !combined.contains('church') &&
        !combined.contains('chapel')) {
      return true;
    }

    if (combined.contains('temple') &&
        !combined.contains('christ') &&
        !combined.contains('church')) {
      return true;
    }
    return false;
  }

  /// OpenStreetMap Overpass — amenity=place_of_worship around user location.
  static Future<List<Map<String, dynamic>>> _fetchNearbyFromOsm(
    LatLng center, {
    double radiusMeters = nearbyRadiusMeters,
    void Function(List<Map<String, dynamic>> batch)? onBatch,
  }) async {
    if (_osmCache != null &&
        _osmCache!.length >= _minOsmCacheCount &&
        _osmCacheCenter != null &&
        _osmCacheAt != null &&
        DateTime.now().difference(_osmCacheAt!) < _osmCacheTtl &&
        haversineMeters(
              _osmCacheCenter!.latitude,
              _osmCacheCenter!.longitude,
              center.latitude,
              center.longitude,
            ) <
            2000) {
      print('[ChurchLocator][Overpass] memory cache hit: ${_osmCache!.length}');
      lastOsmParsed = _osmCache!.length;
      return List<Map<String, dynamic>>.from(_osmCache!);
    }

    final radius = radiusMeters.round().clamp(500, nearbyRadiusMeters.round());
    final lat = center.latitude;
    final lng = center.longitude;

    final overpassQuery = '''
[out:json][timeout:14];
(
  node["amenity"="place_of_worship"]["religion"="christian"](around:$radius,$lat,$lng);
  way["amenity"="place_of_worship"]["religion"="christian"](around:$radius,$lat,$lng);
  node["building"~"church|chapel|cathedral",i](around:$radius,$lat,$lng);
  way["building"~"church|chapel|cathedral",i](around:$radius,$lat,$lng);
);
out center tags 60;
''';

    final merged = <String, Map<String, dynamic>>{};
    var totalElements = 0;
    var rejectedNonChristian = 0;
    var rejectedNoName = 0;

    for (final baseUrl in _overpassUrls) {
      final elements = await _runOverpassQuery(baseUrl, overpassQuery);
      if (elements == null || elements.isEmpty) continue;

      totalElements = elements.length;
      print('[ChurchLocator][Overpass] elements: ${elements.length} from $baseUrl');

      final stepPlaces = <Map<String, dynamic>>[];
      for (final el in elements) {
        if (el is! Map) continue;
        final result = _osmElementToPlaceWithReason(Map<String, dynamic>.from(el));
        if (result.place != null) {
          merged[_dedupeKey(result.place!)] = result.place!;
          stepPlaces.add(result.place!);
        } else if (result.reason == 'non_christian') {
          rejectedNonChristian++;
        } else {
          rejectedNoName++;
        }
      }
      if (stepPlaces.isNotEmpty) onBatch?.call(stepPlaces);
      if (merged.isNotEmpty) break;
    }

    lastOverpassElements = totalElements;
    lastOsmParsed = merged.length;
    lastOsmRejected = rejectedNonChristian + rejectedNoName;
    print('[ChurchLocator][Overpass] TOTAL parsed=${merged.length} '
        'rejected_non_christian=$rejectedNonChristian rejected_no_name=$rejectedNoName '
        'elements=$totalElements');

    if (merged.isEmpty) return [];

    final places = merged.values.toList();
    if (places.length >= _minOsmCacheCount) {
      _osmCache = places;
      _osmCacheCenter = center;
      _osmCacheAt = DateTime.now();
    } else {
      clearOsmMemoryCache();
    }
    return places;
  }

  static Future<void> _nominatimThrottle() async {
    if (_lastNominatimCallAt != null) {
      final gap = DateTime.now().difference(_lastNominatimCallAt!);
      if (gap < _nominatimMinGap) {
        await Future.delayed(_nominatimMinGap - gap);
      }
    }
    _lastNominatimCallAt = DateTime.now();
  }

  static String _nominatimQueryText(String query, {bool suffixChurch = false}) {
    final q = query.trim();
    if (q.isEmpty) return q;
    if (!suffixChurch) return q;
    final lower = q.toLowerCase();
    if (lower.contains('church') ||
        lower.contains('chapel') ||
        lower.contains('cathedral') ||
        lower.contains('parish')) {
      return q;
    }
    return '$q church';
  }

  /// Nominatim search — jsonv2 + viewbox (https://nominatim.openstreetmap.org/search?q=st+mary&format=jsonv2)
  static Future<List<Map<String, dynamic>>> _searchFromNominatim(
    String query, {
    LatLng? bias,
    int limit = 12,
    bool worshipOnly = false,
    bool suffixChurch = false,
  }) async {
    if (isNominatimPaused) return [];
    await _nominatimThrottle();

    final params = <String, String>{
      'q': _nominatimQueryText(query, suffixChurch: suffixChurch),
      'format': 'jsonv2',
      'limit': '$limit',
      'addressdetails': '1',
    };

    if (worshipOnly) {
      params['category'] = 'amenity';
      params['type'] = 'place_of_worship';
    }

    if (bias != null) {
      final delta = 0.12;
      params['viewbox'] =
          '${bias.longitude - delta},${bias.latitude + delta},${bias.longitude + delta},${bias.latitude - delta}';
      params['bounded'] = '1';
    }

    try {
      final uri = Uri.parse(_nominatimUrl).replace(queryParameters: params);
      print('[ChurchLocator][Nominatim] → ${uri.query}');
      final response = await http.get(
        uri,
        headers: {'User-Agent': _userAgent, 'Accept-Language': 'en'},
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 429) {
        _nominatimRateLimited();
        return [];
      }
      if (response.statusCode != 200) return [];

      final data = json.decode(response.body);
      if (data is! List) return [];

      final results = <Map<String, dynamic>>[];
      for (final item in data) {
        if (item is! Map) continue;
        final place = _nominatimToPlace(Map<String, dynamic>.from(item));
        if (place != null) results.add(place);
      }
      return results;
    } catch (e) {
      print('[ChurchLocator][Nominatim] error: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> _loadHiveCached() async {
    final list = HiveCacheService.getCachedList(_hiveKey);
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// Sirf Christian church — mandir, masjid, gurdwara etc. reject.
  static bool isChristianChurch(Map<String, dynamic> place) {
    final name = (place['name'] ?? '').toString().toLowerCase();
    final vicinity =
        (place['vicinity'] ?? place['formatted_address'] ?? '').toString().toLowerCase();
    final religion = (place['religion'] ?? place['osm_religion'] ?? '').toString().toLowerCase();
    final denomination = (place['denomination'] ?? '').toString().toLowerCase();
    final combined = '$name $vicinity $denomination';

    const nonChristianReligions = [
      'hindu',
      'muslim',
      'islam',
      'sikh',
      'buddhist',
      'buddhism',
      'jain',
      'jewish',
      'judaism',
      'bahai',
      'taoist',
      'shinto',
      'pagan',
      'multifaith',
    ];
    if (nonChristianReligions.any((r) => religion == r || religion.contains(r))) {
      return false;
    }

    const excludeKeywords = [
      'mandir', 'madir', 'masjid', 'maszid', 'mosque', 'gurdwara', 'gurudwara',
      'synagogue', 'pagoda', 'dargah', 'derasar', 'jama masjid', 'hanuman',
      'shiva', 'durga', 'lakshmi', 'kali temple', 'jain temple', 'hindu temple',
      'buddhist', 'vihara', 'stupa', 'sanatan', 'dharam', 'bhawan', 'akshardham',
      'iskcon', 'isckon', 'gurmat', 'satsang', 'radha', 'krishna', 'gugga',
    ];
    if (excludeKeywords.any(combined.contains)) return false;

    if (combined.contains('temple') &&
        !combined.contains('christ') &&
        !combined.contains('church')) {
      return false;
    }

    if (religion == 'christian') return true;

    const christianDenoms = [
      'catholic',
      'baptist',
      'protestant',
      'orthodox',
      'anglican',
      'methodist',
      'presbyterian',
      'lutheran',
      'pentecostal',
      'evangelical',
      'adventist',
      'mormon',
      'jehovah',
      'quaker',
      'mennonite',
      'nondenominational',
      'maronite',
      'coptic',
      'episcopal',
      'wesleyan',
      'congregational',
    ];
    if (christianDenoms.any((d) => denomination.contains(d))) return true;

    const churchKeywords = [
      'church',
      'chapel',
      'cathedral',
      'parish',
      'congregation',
      'fellowship',
      'christian',
      'gospel',
      'ministry',
      'basilica',
      'abbey',
      'mission',
      'st ',
      'st.',
      'saint',
      'holy ',
      'sacred',
      'our lady',
      'christ',
      'bethel',
      'calvary',
      'zion',
      'trinity',
      'immaculate',
      'redemption',
      'catholic',
      'baptist',
      'methodist',
      'presbyterian',
      'lutheran',
      'pentecostal',
      'anglican',
      'orthodox',
      'episcopal',
      'wesleyan',
      'evangelical',
      'adventist',
    ];
    if (churchKeywords.any((k) => name.contains(k))) return true;
    if (churchKeywords.any((k) => vicinity.contains(k))) return true;

    final types = place['types'];
    if (types is List) {
      final typeStr = types.map((e) => e.toString().toLowerCase()).toList();
      if (typeStr.contains('church')) return true;
      if (typeStr.contains('place_of_worship') && religion.isEmpty && name.isNotEmpty) {
        return churchKeywords.any((k) => name.contains(k));
      }
    }

    return false;
  }

  /// OSM me aksar church ka naam nahi — community/operator/denomination se naam banao.
  static String _resolveOsmDisplayName(Map<String, dynamic> tags) {
    for (final key in [
      'name', 'official_name', 'alt_name', 'short_name', 'loc_name',
    ]) {
      final v = tags[key]?.toString().trim();
      if (v != null && v.isNotEmpty) return v;
    }
    for (final key in [
      'community', 'operator', 'brand', 'parish', 'congregation',
    ]) {
      final v = tags[key]?.toString().trim();
      if (v != null && v.isNotEmpty) return v;
    }
    final denom = tags['denomination']?.toString().trim();
    if (denom != null && denom.isNotEmpty && isChristianOsmDenomination(denom)) {
      final label = osmDenominationToLabel(denom);
      return '$label Church';
    }
    final building = tags['building']?.toString().toLowerCase() ?? '';
    if (building.contains('church') || building.contains('chapel') || building.contains('cathedral')) {
      final addr = _addressFromOsmTags(tags);
      if (addr.isNotEmpty) return 'Church — $addr';
      return 'Church';
    }
    if (tags['religion']?.toString().toLowerCase() == 'christian') {
      final addr = _addressFromOsmTags(tags);
      return addr.isNotEmpty ? 'Church — $addr' : 'Christian Church';
    }
    if (tags['amenity']?.toString().toLowerCase() == 'place_of_worship') {
      final addr = _addressFromOsmTags(tags);
      return addr.isNotEmpty ? 'Church — $addr' : 'Church';
    }
    return '';
  }

  static Future<List<dynamic>?> _runOverpassQuery(String baseUrl, String query) async {
    if (_lastOverpassCallAt != null) {
      final gap = DateTime.now().difference(_lastOverpassCallAt!);
      if (gap < _overpassMinGap) {
        await Future.delayed(_overpassMinGap - gap);
      }
    }
    try {
      _lastOverpassCallAt = DateTime.now();
      print('[ChurchLocator][Overpass] → $baseUrl');
      final response = await http
          .post(
            Uri.parse(baseUrl),
            headers: {'User-Agent': _userAgent},
            body: {'data': query},
          )
          .timeout(const Duration(seconds: 18));

      if (response.statusCode == 429) {
        print('[ChurchLocator][Overpass] HTTP 429 — try next mirror');
        return null;
      }
      if (response.statusCode != 200) {
        print('[ChurchLocator][Overpass] HTTP ${response.statusCode}');
        return null;
      }
      final data = json.decode(response.body);
      final elements = data['elements'];
      if (elements is List) return elements;
      return null;
    } catch (e) {
      print('[ChurchLocator][Overpass] error: $e');
      return null;
    }
  }

  static ({Map<String, dynamic>? place, String? reason}) _osmElementToPlaceWithReason(
    Map<String, dynamic> el,
  ) {
    final tags = el['tags'];
    if (tags is! Map) return (place: null, reason: 'no_tags');

    double? lat;
    double? lng;
    if (el['lat'] != null && el['lon'] != null) {
      lat = (el['lat'] as num).toDouble();
      lng = (el['lon'] as num).toDouble();
    } else if (el['center'] is Map) {
      final c = el['center'] as Map;
      lat = (c['lat'] as num?)?.toDouble();
      lng = (c['lon'] as num?)?.toDouble();
    }
    if (lat == null || lng == null) return (place: null, reason: 'no_coords');

    final place = _osmElementToPlace(el);
    if (place != null) return (place: place, reason: null);

    final tagMap = Map<String, dynamic>.from(tags);
    final displayName = _resolveOsmDisplayName(tagMap);
    if (displayName.isEmpty) return (place: null, reason: 'no_name');
    final candidate = {
      'name': displayName,
      'religion': tagMap['religion'],
      'denomination': tagMap['denomination'],
      'vicinity': _addressFromOsmTags(tagMap),
    };
    if (isExplicitlyNonChristian(candidate)) {
      return (place: null, reason: 'non_christian');
    }
    return (place: null, reason: 'filtered');
  }

  static Map<String, dynamic>? _osmElementToPlace(Map<String, dynamic> el) {
    final tags = el['tags'];
    if (tags is! Map) return null;

    final tagMap = Map<String, dynamic>.from(tags);

    double? lat;
    double? lng;
    if (el['lat'] != null && el['lon'] != null) {
      lat = (el['lat'] as num).toDouble();
      lng = (el['lon'] as num).toDouble();
    } else if (el['center'] is Map) {
      final c = el['center'] as Map;
      lat = (c['lat'] as num?)?.toDouble();
      lng = (c['lon'] as num?)?.toDouble();
    }
    if (lat == null || lng == null) return null;

    var displayName = _resolveOsmDisplayName(tagMap);
    if (displayName.isEmpty && isChristianOsmElement(tagMap)) {
      displayName = 'Christian Church';
    }
    if (displayName.isEmpty) return null;

    final address = _addressFromOsmTags(tagMap);
    final candidate = {
      'name': displayName,
      'religion': tagMap['religion'],
      'denomination': tagMap['denomination'],
      'operator': tagMap['operator'],
      'community': tagMap['community'],
      'vicinity': address,
    };
    if (isExplicitlyNonChristian(candidate)) return null;
    if (!isChristianOsmElement(tagMap) &&
        !isChristianChurch(candidate) &&
        !_looksLikeChristianPlace(candidate)) {
      return null;
    }

    final type = el['type']?.toString() ?? 'node';
    final id = el['id'];
    final osmDenomRaw = tagMap['denomination']?.toString() ?? '';
    final denomination = _denominationFromOsmTags(tagMap, displayName);

    return {
      'place_id': 'osm_${type}_$id',
      'name': displayName,
      'vicinity': address,
      'formatted_address': address,
      'denomination': denomination,
      'osm_denomination': osmDenomRaw,
      'religion': tagMap['religion']?.toString() ?? 'christian',
      'building': tagMap['building']?.toString(),
      'operator': tagMap['operator']?.toString(),
      'community': tagMap['community']?.toString(),
      'geometry': {
        'location': {'lat': lat, 'lng': lng},
      },
    };
  }

  static Map<String, dynamic>? _nominatimToPlace(Map<String, dynamic> item) {
    final lat = double.tryParse(item['lat']?.toString() ?? '');
    final lon = double.tryParse(item['lon']?.toString() ?? '');
    if (lat == null || lon == null) return null;

    final category = item['category']?.toString() ?? '';
    final osmType = item['type']?.toString() ?? '';
    final name = item['name']?.toString().trim() ?? '';
    final displayName = item['display_name']?.toString() ?? name;
    final resolvedName = name.isNotEmpty ? name : displayName.split(',').first.trim();
    if (resolvedName.isEmpty) return null;

    final nameLower = resolvedName.toLowerCase();
    if (nameLower.contains('school') || nameLower.contains('college')) return null;
    if (category == 'amenity' && osmType != 'place_of_worship') {
      if (!nameLower.contains('church') &&
          !nameLower.contains('chapel') &&
          !nameLower.contains('cathedral')) {
        return null;
      }
    }

    final types = <String>[
      if (osmType.isNotEmpty) osmType,
      if (category.isNotEmpty) category,
    ];

    final place = {
      'name': resolvedName,
      'vicinity': displayName,
      'formatted_address': displayName,
      'types': types,
      'osm_category': category,
      'osm_type': osmType,
    };
    if (isExplicitlyNonChristian(place)) return null;
    if (!_looksLikeChristianPlace(place)) return null;

    final osmId = item['osm_id']?.toString() ?? item['place_id']?.toString() ?? '${lat}_$lon';
    final denom = _denominationFromName(resolvedName);

    return {
      'place_id': 'osm_nom_$osmId',
      'name': resolvedName,
      'vicinity': displayName,
      'formatted_address': displayName,
      'denomination': denom,
      'types': types,
      'geometry': {
        'location': {'lat': lat, 'lng': lon},
      },
    };
  }

  static String _addressFromOsmTags(Map<String, dynamic> tags) {
    final parts = <String>[
      if (tags['addr:housenumber'] != null) tags['addr:housenumber'].toString(),
      if (tags['addr:street'] != null) tags['addr:street'].toString(),
      if (tags['addr:city'] != null) tags['addr:city'].toString(),
      if (tags['addr:state'] != null) tags['addr:state'].toString(),
    ].where((s) => s.isNotEmpty).toList();

    if (parts.isNotEmpty) return parts.join(', ');
    if (tags['addr:full'] != null) return tags['addr:full'].toString();
    return '';
  }

  static String _denominationFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('non-denominational') || lower.contains('nondenominational')) {
      return 'Non-denominational';
    }
    if (lower.contains('catholic')) return 'Catholic';
    if (lower.contains('baptist')) return 'Baptist';
    if (lower.contains('pentecost')) return 'Pentecostal';
    if (lower.contains('lutheran')) return 'Lutheran';
    if (lower.contains('methodist')) return 'Methodist';
    if (lower.contains('presbyterian')) return 'Presbyterian';
    if (lower.contains('orthodox') || lower.contains('mar thoma') || lower.contains('syrian')) {
      return 'Orthodox';
    }
    if (lower.contains('anglican') || lower.contains('cni') || lower.contains('csi')) {
      return 'Anglican';
    }
    if (lower.contains('adventist')) return 'Adventist';
    if (lower.contains('protestant')) return 'Protestant';
    if (lower.contains('evangelical')) return 'Evangelical';
    if (lower.contains('brethren')) return 'Brethren';
    if (lower.contains('assembly of god')) return 'Pentecostal';
    return 'Church';
  }

  /// User ki denomination filter — name, community, operator, OSM denomination tag.
  static bool matchesDenomination(Map<String, dynamic> place, String keyword) {
    final kw = keyword.toLowerCase().trim();
    if (kw.isEmpty || kw == 'all') return true;

    final name = (place['name'] ?? '').toString().toLowerCase();
    final denom = (place['denomination'] ?? '').toString().toLowerCase();
    final operator = (place['operator'] ?? '').toString().toLowerCase();
    final community = (place['community'] ?? '').toString().toLowerCase();
    final vicinity =
        (place['vicinity'] ?? place['formatted_address'] ?? '').toString().toLowerCase();
    final combined = '$name $denom $operator $community $vicinity';

    if (kw == 'non-denominational' || kw == 'nondenominational') {
      return combined.contains('non-denominational') ||
          combined.contains('nondenominational') ||
          combined.contains('interdenominational');
    }

    final osmDenom = (place['osm_denomination'] ?? '').toString().toLowerCase();
    if (osmDenom.isNotEmpty && isChristianOsmDenomination(osmDenom)) {
      final label = osmDenominationToLabel(osmDenom).toLowerCase();
      if (label.contains(kw) || kw.contains(label)) return true;
    }

    const synonyms = <String, List<String>>{
      'catholic': [
        'catholic', 'roman catholic', 'roman_catholic', 'maronite', 'coptic',
        'greek_catholic', 'syro-malabar', 'syro_malabar', 'ukrainian_greek_catholic',
      ],
      'baptist': ['baptist', 'southern baptist', 'strict_baptist'],
      'methodist': ['methodist', 'wesleyan', 'united methodist', 'united_methodist', 'ame'],
      'presbyterian': ['presbyterian', 'reformed', 'church_of_scotland', 'dutch_reformed'],
      'lutheran': ['lutheran', 'evangelical_lutheran'],
      'pentecostal': [
        'pentecostal', 'pentecost', 'assemblies of god', 'assemblies_of_god',
        'foursquare', 'church_of_god',
      ],
      'orthodox': [
        'orthodox', 'mar thoma', 'syrian', 'coptic', 'greek_orthodox',
        'russian_orthodox', 'serbian_orthodox', 'malankara',
      ],
      'anglican': ['anglican', 'episcopal', 'church of england', 'csi', 'cni', 'scottish_episcopal'],
      'adventist': ['adventist', 'seventh-day', 'seventh_day_adventist'],
      'protestant': ['protestant', 'congregational', 'brethren', 'evangelical'],
      'evangelical': ['evangelical', 'evangelist', 'evangelical_covenant'],
      'mormon': ['mormon', 'latter-day'],
      'jehovah': ['jehovah', 'jehovahs_witness'],
    };

    if (combined.contains(kw)) return true;

    for (final entry in synonyms.entries) {
      final keys = [entry.key, ...entry.value];
      if (keys.any((k) => kw.contains(k) || k.contains(kw))) {
        if (keys.any((k) => combined.contains(k))) return true;
      }
    }

    final parsed = _denominationFromName(place['name']?.toString() ?? '').toLowerCase();
    if (parsed == kw || parsed.contains(kw) || kw.contains(parsed)) return true;

    final words = kw.split(RegExp(r'\s+')).where((w) => w.length > 2).toList();
    if (words.isNotEmpty && words.every((w) => combined.contains(w))) return true;

    return false;
  }

  static String _placeKey(Map<String, dynamic> p) {
    final id = p['place_id']?.toString();
    if (id != null && id.isNotEmpty) return id;
    return _dedupeKey(p);
  }

  /// Same church OSM+Nominatim duplicate hatane — ~50m + naam.
  static String _dedupeKey(Map<String, dynamic> p) {
    final loc = p['geometry']?['location'];
    if (loc is Map && loc['lat'] is num && loc['lng'] is num) {
      final lat = ((loc['lat'] as num).toDouble() * 1000).round();
      final lng = ((loc['lng'] as num).toDouble() * 1000).round();
      final name = (p['name'] ?? '')
          .toString()
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]'), '');
      return '${lat}_${lng}_$name';
    }
    final id = p['place_id']?.toString();
    if (id != null && id.isNotEmpty) return id;
    return p['name']?.toString() ?? '';
  }

  static bool _matchesQuery(Map<String, dynamic> p, String q) {
    final lower = q.toLowerCase();
    final name = (p['name'] ?? '').toString().toLowerCase();
    final addr = (p['vicinity'] ?? p['formatted_address'] ?? '').toString().toLowerCase();
    final denom = (p['denomination'] ?? '').toString().toLowerCase();
    return name.contains(lower) || addr.contains(lower) || denom.contains(lower);
  }

  static bool _matchesDenomination(Map<String, dynamic> p, String denomination) {
    final keyword = denomination.toLowerCase().trim();
    final name = (p['name'] ?? '').toString().toLowerCase();
    final vicinity = (p['vicinity'] ?? p['formatted_address'] ?? '').toString().toLowerCase();
    final parsed = (p['denomination'] ?? '').toString().toLowerCase();
    return name.contains(keyword) || vicinity.contains(keyword) || parsed == keyword;
  }

  /// Nominatim reverse — Google Geocode ki jagah (free).
  static Future<String> reverseGeocodeCity(LatLng location) async {
    if (_cityCacheLabel != null &&
        _cityCacheCenter != null &&
        _cityCacheAt != null &&
        DateTime.now().difference(_cityCacheAt!) < const Duration(hours: 2) &&
        haversineMeters(
              _cityCacheCenter!.latitude,
              _cityCacheCenter!.longitude,
              location.latitude,
              location.longitude,
            ) <
            5000) {
      return _cityCacheLabel!;
    }
    if (isNominatimPaused) return '';

    try {
      await _nominatimThrottle();
      final uri = Uri.parse('https://nominatim.openstreetmap.org/reverse').replace(
        queryParameters: {
          'lat': location.latitude.toString(),
          'lon': location.longitude.toString(),
          'format': 'json',
          'addressdetails': '1',
        },
      );
      final response = await http.get(
        uri,
        headers: {'User-Agent': _userAgent, 'Accept-Language': 'en'},
      ).timeout(const Duration(seconds: 4));
      if (response.statusCode == 429) {
        _nominatimRateLimited();
        return '';
      }
      if (response.statusCode != 200) return '';
      final data = json.decode(response.body);
      final addr = data['address'];
      if (addr is Map) {
        final city = addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['suburb'] ?? addr['county'];
        final state = addr['state'];
        String? label;
        if (city != null && state != null) {
          label = '$city, $state';
        } else if (city != null) {
          label = city.toString();
        } else if (state != null) {
          label = state.toString();
        }
        if (label != null && _isValidCityLabel(label)) {
          _cityCacheLabel = label;
          _cityCacheCenter = location;
          _cityCacheAt = DateTime.now();
          return label;
        }
      }
    } catch (_) {}
    return '';
  }

  /// OSRM driving routes — Google Directions ki jagah (free).
  static Future<List<Map<String, dynamic>>?> directions({
    required LatLng origin,
    required LatLng destination,
  }) async {
    try {
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${origin.longitude},${origin.latitude};'
        '${destination.longitude},${destination.latitude}'
        '?overview=full&geometries=geojson&alternatives=true&steps=true',
      );
      final response = await http.get(
        uri,
        headers: {'User-Agent': _userAgent},
      ).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return null;

      final data = json.decode(response.body);
      if (data['code']?.toString() != 'Ok') return null;
      final routes = data['routes'];
      if (routes is! List || routes.isEmpty) return null;

      final resultList = <Map<String, dynamic>>[];
      for (final route in routes) {
        if (route is! Map) continue;

        final points = <LatLng>[];
        final geom = route['geometry'];
        if (geom is Map && geom['coordinates'] is List) {
          for (final c in geom['coordinates'] as List) {
            if (c is List && c.length >= 2) {
              points.add(LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()));
            }
          }
        }

        final distanceMeters = ((route['distance'] as num?) ?? 0).round();
        final durationSeconds = ((route['duration'] as num?) ?? 0).round();
        final distanceText = _formatRouteDistance(distanceMeters);
        final durationText = _formatRouteDuration(durationSeconds);

        final steps = <Map<String, dynamic>>[];
        final legs = route['legs'];
        if (legs is List && legs.isNotEmpty && legs.first is Map) {
          final legSteps = legs.first['steps'];
          if (legSteps is List) {
            for (final step in legSteps) {
              if (step is! Map) continue;
              final maneuver = step['maneuver'];
              var instruction = 'Continue';
              var maneuverType = '';
              if (maneuver is Map) {
                maneuverType = maneuver['type']?.toString() ?? '';
                final modifier = maneuver['modifier']?.toString();
                instruction = modifier != null && modifier.isNotEmpty
                    ? '${_capitalize(maneuverType)} $modifier'
                    : _capitalize(maneuverType);
              }
              final stepDist = ((step['distance'] as num?) ?? 0).round();
              final stepDur = ((step['duration'] as num?) ?? 0).round();
              steps.add({
                'instruction': instruction,
                'maneuver': maneuverType,
                'distanceText': _formatRouteDistance(stepDist),
                'distanceMeters': stepDist,
                'durationText': _formatRouteDuration(stepDur),
                'durationSeconds': stepDur,
              });
            }
          }
        }

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
      return resultList.isEmpty ? null : resultList;
    } catch (_) {
      return null;
    }
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).replaceAll('_', ' ');
  }

  static String _formatRouteDistance(int meters) {
    final miles = meters / 1609.344;
    if (miles < 0.1) return '${(meters * 3.28084).round()} ft';
    return '${miles.toStringAsFixed(1)} mi';
  }

  static String _formatRouteDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final mins = seconds ~/ 60;
    if (mins < 60) return '$mins min';
    final hrs = mins ~/ 60;
    final rem = mins % 60;
    return rem > 0 ? '$hrs hr $rem min' : '$hrs hr';
  }
}
