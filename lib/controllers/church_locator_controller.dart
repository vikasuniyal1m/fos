import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'dart:ui' as ui;
import 'package:android_intent_plus/android_intent.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maps_toolkit/maps_toolkit.dart' as mtk;
import 'package:sensors_plus/sensors_plus.dart';
import '../config/api_config.dart';
import '../services/places_service.dart';
import '../services/church_locator_service.dart';
import '../services/map_launcher_service.dart';
import '../services/hive_cache_service.dart';
import 'package:url_launcher/url_launcher.dart';

class ChurchLocatorController extends GetxController {
  var isLoading = false.obs;
  var loadingMessage = 'Finding churches nearby...'.obs;
  var isFilterLoading = false.obs;
  final markers = <Marker>[].obs;
  final polylines = <Polyline>[].obs;
  final navigationMarker = Rxn<Marker>();
  var currentPosition = Rxn<Position>();
  var places = <Map<String, dynamic>>[].obs;
  var originalPlaces = <Map<String, dynamic>>[].obs;
  final hqQuery = RxnString();
  final autoSearch = false.obs;
  final cameraTarget = Rxn<LatLng>();
  final locationServiceEnabled = false.obs;
  final lastPermission = Rxn<LocationPermission>();

  // NEW: Toggle between in-app navigation and Google Maps app
  final useGoogleMapsAppNavigation = false.obs;
  final selectedPlace = Rxn<Map<String, dynamic>>(); // Track selected church
  bool _fetchInProgress = false;
  double? _lastCameraZoom;
  final currentCity = '—'.obs;
  final currentTime = ''.obs;
  Timer? _clockTimer;
  LatLng? _lastCityCenter;
  bool _labelMode = false;
  final suggestions = <Map<String, dynamic>>[].obs;
  final showExternalMapsOffer = false.obs;
  final externalSearchQuery = ''.obs;
  final searchActive = false.obs;
  Timer? _searchDebounce;
  int _searchSuggestGeneration = 0;
  final Map<String, BitmapDescriptor> _labelIconCache = {};
  final searchController = TextEditingController();
  final routeSummary = RxnString();
  final routeSteps = <Map<String, dynamic>>[].obs;
  final allRoutesData = <Map<String, dynamic>>[].obs;
  final selectedRouteIndex = 0.obs;
  final routeLabelMarkers = <Marker>[].obs;

  // Professional Navigation Features
  final isNavigating = false.obs;
  final currentNavigationStep = 0.obs;
  final navigationInstructions = ''.obs;
  final navigationDistance = ''.obs;
  final navigationDuration = ''.obs;
  final navigationETA = ''.obs;
  final routeDistance = ''.obs; // Store route distance for dialog
  final routeDuration = ''.obs; // Store route duration for dialog
  Timer? _navigationTimer;
  final navigationProgress = 0.0.obs;
  final routeRemainingDistanceMeters = 0.0.obs;
  final isRerouting = false.obs;
  DateTime? _lastRerouteAt;
  bool _isRerouting = false;
  LatLng? _navDestination;
  String _navDestinationName = 'Destination';
  BitmapDescriptor? _cachedNavArrowIcon;
  int _routeDurationSeconds = 0;
  static const double _offRouteToleranceMeters = 35.0;
  static const double _stepAdvanceToleranceMeters = 35.0;
  static const int _rerouteCooldownSeconds = 8;
  DateTime? _lastCameraAnimateAt;
  double? _smoothedCameraBearing;
  LatLng? _lastCameraTarget;
  bool _userControllingCamera = false;
  final isCameraFollowPaused = false.obs;
  int _routeRequestId = 0;

  // Direction and Navigation Visuals
  final currentDirection = 0.0.obs; // Compass direction in degrees
  final nextTurnDirection = ''.obs; // 'left', 'right', 'straight'
  final nextTurnDistance = ''.obs; // Distance to next turn
  final isApproachingTurn = false.obs;
  final compassVisible = true.obs;
  final directionArrowsVisible = true.obs;

  // Sensor-based Navigation
  final userHeading = 0.0.obs; // User's actual heading from magnetometer
  final compassAccuracy = 0.0.obs; // Compass accuracy
  final isCompassActive = false.obs;
  StreamSubscription<MagnetometerEvent>? _magnetometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  StreamSubscription<Position>? _positionStreamSubscription;
  Timer? _compassTimer;
  final gyroscopeX = 0.0.obs;
  final gyroscopeY = 0.0.obs;
  final gyroscopeZ = 0.0.obs;
  final magnetometerX = 0.0.obs;
  final magnetometerY = 0.0.obs;
  final magnetometerZ = 0.0.obs;
  double _smoothedHeading = 0.0;
  double _filteredGyroZ = 0.0;
  DateTime? _lastGyroUpdateAt;

  final LatLng defaultLocation = const LatLng(30.7333, 76.7794);
  final selectedDenomination = RxnString();
  RxBool isBottomSheetExpanded = false.obs;
  RxDouble currentZoom = 14.0.obs;
  RxBool isMapReady = false.obs;
  GoogleMapController? mapController;

  var _allNearbyPlaces = <Map<String, dynamic>>[];
  DateTime? _churchLastSyncedAt;
  var _churchSyncInProgress = false;
  LatLng? _lastSearchCenter;
  bool _pendingFitMarkers = false;
  static const Duration _churchMinSyncInterval = Duration(minutes: 10);
  static const String _churchHiveKey = 'church_nearby_places';
  static const String _churchPositionHiveKey = 'church_last_position';
  int _progressiveDisplayed = 0;
  int _progressiveFetchGen = 0;

  double _metersToMiles(double meters) => meters / 1609.344;

  String _formatMilesFromMeters(double meters) {
    return _metersToMiles(meters).toStringAsFixed(1);
  }

  String _toMilesText(String rawText) {
    final text = rawText.trim();
    if (text.isEmpty) return text;

    final normalized = text
        .replaceAll(RegExp(r'\{[^}]*\}'), '')
        .replaceAll(',', '')
        .trim();

    final milesMatch = RegExp(r'^(\d+(?:\.\d+)?)\s*(mi|mile|miles)\b', caseSensitive: false)
        .firstMatch(normalized);
    if (milesMatch != null) {
      final value = double.tryParse(milesMatch.group(1) ?? '');
      if (value != null) return '${value.toStringAsFixed(1)} mi';
      return normalized;
    }

    final kmMatch = RegExp(r'^(\d+(?:\.\d+)?)\s*km\b', caseSensitive: false).firstMatch(normalized);
    if (kmMatch != null) {
      final km = double.tryParse(kmMatch.group(1) ?? '');
      if (km != null) {
        final miles = km * 0.621371;
        return '${miles.toStringAsFixed(1)} mi';
      }
      return normalized;
    }

    final meterMatch = RegExp(r'^(\d+(?:\.\d+)?)\s*m\b', caseSensitive: false).firstMatch(normalized);
    if (meterMatch != null) {
      final meters = double.tryParse(meterMatch.group(1) ?? '');
      if (meters != null) {
        return '${_metersToMiles(meters).toStringAsFixed(1)} mi';
      }
      return normalized;
    }

    return normalized;
  }

  @override
  void onInit() {
    super.onInit();
    _startClock();
    ChurchLocatorService.resetNominatimCooldown();
    bootstrapChurchesFromHive();
  }

  @override
  void onReady() {
    super.onReady();
    final hasCache = places.isNotEmpty || _allNearbyPlaces.isNotEmpty;
    isLoading(false);
    unawaited(_determinePosition(silent: true));
    if (hasCache) {
      unawaited(_silentRefreshNearby());
    } else {
      unawaited(_bootWithoutCache());
    }
  }

  /// Fresh install: pehle fast GPS, phir churches — galat default city se load nahi.
  Future<void> _bootWithoutCache() async {
    _allNearbyPlaces = [];
    ChurchLocatorService.clearOsmMemoryCache();
    await HiveCacheService.clearKey(_churchHiveKey);
    await _primeLocationFast();
    await searchChurchesAt(_resolveMapCenter(), silent: true);
    unawaited(_refineGpsInBackground());
  }

  Future<bool> _primeLocationFast() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return false;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return false;
      }
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null && !_isRejectedDefaultLocation(last)) {
          currentPosition.value = last;
          _cacheLastPosition(last);
          return true;
        }
      } catch (_) {}
      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 2),
        ).timeout(const Duration(seconds: 3));
        if (!_isRejectedDefaultLocation(pos)) {
          currentPosition.value = pos;
          _cacheLastPosition(pos);
          return true;
        }
      } catch (_) {}
    } catch (_) {}
    return false;
  }

  /// Screen open par — onReady miss ho to bhi churches + markers load.
  void ensureMapDataLoaded() {
    if (markers.isEmpty && places.isNotEmpty) {
      _setDefaultMarkersFast(List<Map<String, dynamic>>.from(places));
    }
    if (places.isNotEmpty) {
      markers.refresh();
      fitAllMarkers();
      isLoading(false);
      _logNearbyData('ensureMapDataLoaded (cached UI)', places.toList());
    }
    if (_fetchInProgress) return;
    if (places.isEmpty) {
      isLoading(false);
      unawaited(_bootWithoutCache());
    } else {
      // Cache me kam churches hon (e.g. 3) → hamesha fresh OSM fetch
      unawaited(searchChurchesAt(_resolveMapCenter(), silent: true));
    }
  }

  void _logNearbyData(String stage, List<Map<String, dynamic>> data) {
    print('[ChurchLocator][$stage] count=${data.length} '
        'markers=${markers.length} denomination=${selectedDenomination.value ?? "All"}');
    for (var i = 0; i < data.length && i < 15; i++) {
      final p = data[i];
      final loc = p['geometry']?['location'];
      print('[ChurchLocator]  ${i + 1}. ${p['name']} '
          'dist=${p['distance'] ?? "?"} (${loc?['lat']}, ${loc?['lng']})');
    }
    if (data.length > 15) {
      print('[ChurchLocator]  ... +${data.length - 15} more');
    }
  }

  /// Pre-warm before navigation (denominations, home, etc.).
  void prepareChurchLocator({String? denomination}) {
    if (denomination != null && denomination.isNotEmpty) {
      selectedDenomination.value = denomination == 'All' ? null : denomination;
      _syncDenominationSearchBar(selectedDenomination.value);
    }
    bootstrapChurchesFromHive();
  }

  bool bootstrapChurchesFromHive() {
    if (_allNearbyPlaces.isNotEmpty) return places.isNotEmpty;

    _restoreCachedPosition();

    final cached = HiveCacheService.getCachedList(_churchHiveKey);
    if (cached.isEmpty) return false;

    _allNearbyPlaces = _filterChristianChurchesOnly(List<Map<String, dynamic>>.from(cached));
    print('[ChurchLocator][Hive] loaded ${_allNearbyPlaces.length} churches from cache');
    if (_allNearbyPlaces.length < 12) {
      print('[ChurchLocator][Hive] cache small (${_allNearbyPlaces.length}) — '
          'pehle dikhao, background me refresh');
      if (_allNearbyPlaces.isNotEmpty) {
        final filtered = _filterResultsByDenomination(
          _allNearbyPlaces,
          selectedDenomination.value,
        );
        final center = _resolveMapCenter();
        unawaited(_assignPlacesFromResults(filtered, center, silent: true));
        isLoading(false);
      }
      return false;
    }
    _logNearbyData('bootstrapChurchesFromHive', _allNearbyPlaces);
    final filtered = _filterResultsByDenomination(
      _allNearbyPlaces,
      selectedDenomination.value,
    );
    final center = _resolveMapCenter();
    unawaited(_assignPlacesFromResults(filtered, center, silent: true));
    isLoading(false);
    return true;
  }

  void _restoreCachedPosition() {
    if (currentPosition.value != null) return;
    final posCache = HiveCacheService.getCachedMap(_churchPositionHiveKey);
    final lat = posCache['lat'];
    final lng = posCache['lng'];
    if (lat is num && lng is num) {
      cameraTarget.value = LatLng(lat.toDouble(), lng.toDouble());
    }
  }

  LatLng _resolveMapCenter() {
    if (currentPosition.value != null) {
      return LatLng(
        currentPosition.value!.latitude,
        currentPosition.value!.longitude,
      );
    }
    return cameraTarget.value ?? defaultLocation;
  }

  void _cacheLastPosition(Position pos) {
    unawaited(
      HiveCacheService.cacheMap(
        _churchPositionHiveKey,
        {'lat': pos.latitude, 'lng': pos.longitude},
        expiryHours: 48,
      ),
    );
    cameraTarget.value = LatLng(pos.latitude, pos.longitude);
  }

  Future<void> _silentRefreshNearby() async {
    if (_allNearbyPlaces.isEmpty) return;
    final center = _resolveMapCenter();
    await searchChurchesAt(center, silent: true);
  }

  double _distanceToCenterMeters(Map<String, dynamic> place, LatLng center) {
    final loc = place['geometry']?['location'];
    if (loc is! Map || loc['lat'] is! num || loc['lng'] is! num) {
      return double.infinity;
    }
    return ChurchLocatorService.haversineMeters(
      center.latitude,
      center.longitude,
      (loc['lat'] as num).toDouble(),
      (loc['lng'] as num).toDouble(),
    );
  }

  List<Map<String, dynamic>> _sortPlacesNearest(
    List<Map<String, dynamic>> list,
    LatLng center,
  ) {
    final copy = list.map((p) => Map<String, dynamic>.from(p)).toList();
    copy.sort(
      (a, b) => _distanceToCenterMeters(a, center).compareTo(_distanceToCenterMeters(b, center)),
    );
    return copy;
  }

  Future<void> _applyProgressiveChurches(
    List<Map<String, dynamic>> accumulated,
    LatLng center, {
    required bool done,
    required bool silent,
    required int generation,
  }) async {
    if (generation != _progressiveFetchGen) return;

    final master = _filterChristianChurchesOnly(
      ChurchLocatorService.filterWithinRadius(
        accumulated,
        center,
        ChurchLocatorService.nearbyRadiusMeters,
      ),
    );
    _allNearbyPlaces = master;
    final results = _sortPlacesNearest(
      _filterResultsByDenomination(master, selectedDenomination.value),
      center,
    );

    if (results.isEmpty) {
      if (done) _handleNearbySearchMiss();
      return;
    }

    // Pehla mile turant dikhao; har naya church +1 list/map pe.
    if (!done && results.length <= _progressiveDisplayed) return;
    final toShow = results.length;
    _progressiveDisplayed = toShow;

    print('[ChurchLocator][progressive] show=$toShow total=${results.length} done=$done');
    await _assignPlacesFromResults(
      results.take(toShow).toList(),
      center,
      silent: silent || toShow > 0,
    );
  }

  Future<void> _refreshNearbyMaster(
    LatLng center, {
    bool silent = false,
    ChurchNearbyProgressCallback? onProgress,
  }) async {
    if (_churchSyncInProgress) return;
    if (silent &&
        _churchLastSyncedAt != null &&
        DateTime.now().difference(_churchLastSyncedAt!) < _churchMinSyncInterval &&
        _allNearbyPlaces.length >= 30) {
      print('[ChurchLocator] skip refresh — synced recently (${_allNearbyPlaces.length} cached)');
      return;
    }

    _churchSyncInProgress = true;
    try {
      if (ApiConfig.useGoogleMapsWebServices) {
        unawaited(
          PlacesService.searchChurches(
            location: center,
            denomination: null,
            radius: ChurchLocatorService.nearbyRadiusMeters,
          ).timeout(
            const Duration(seconds: 3),
            onTimeout: () => <Map<String, dynamic>>[],
          ).then((google) {
            if (google.isEmpty) return;
            final merged = <String, Map<String, dynamic>>{};
            for (final p in _filterChristianChurchesOnly(google)) {
              final id = p['place_id']?.toString() ?? p['name']?.toString() ?? '';
              if (id.isNotEmpty) merged[id] = p;
            }
            for (final p in _allNearbyPlaces) {
              final id = p['place_id']?.toString() ?? p['name']?.toString() ?? '';
              if (id.isNotEmpty) merged[id] = p;
            }
            if (merged.isEmpty) return;
            _allNearbyPlaces = merged.values.toList();
            unawaited(
              HiveCacheService.cacheList(
                _churchHiveKey,
                List<Map<String, dynamic>>.from(_allNearbyPlaces),
                expiryHours: 24,
              ),
            );
            final filtered = _filterResultsByDenomination(
              _allNearbyPlaces,
              selectedDenomination.value,
            );
            unawaited(_assignPlacesFromResults(filtered, center, silent: true));
          }),
        );
      }

      var rawResults = await ChurchLocatorService.fetchOsmNearby(
        center,
        radiusMeters: ChurchLocatorService.nearbyRadiusMeters,
        onProgress: onProgress,
      );
      if (rawResults.isEmpty && ApiConfig.useGoogleMapsWebServices) {
        try {
          rawResults = _filterChristianChurchesOnly(
            await PlacesService.searchChurches(
              location: center,
              denomination: null,
              radius: ChurchLocatorService.nearbyRadiusMeters,
            ).timeout(
              const Duration(seconds: 3),
              onTimeout: () => <Map<String, dynamic>>[],
            ),
          );
        } catch (_) {}
      }
      rawResults = ChurchLocatorService.filterWithinRadius(
        rawResults,
        center,
        ChurchLocatorService.nearbyRadiusMeters,
      );
      if (rawResults.isEmpty) {
        print('[ChurchLocator][_refreshNearbyMaster] OSM+Google empty @ '
            '${center.latitude},${center.longitude}');
        return;
      }

      rawResults = _filterChristianChurchesOnly(rawResults);
      print('[ChurchLocator][_refreshNearbyMaster] storing ${rawResults.length} churches '
          'within ${(ChurchLocatorService.nearbyRadiusMeters / 1000).toStringAsFixed(0)}km');
      _logNearbyData('_refreshNearbyMaster raw', rawResults);
      _allNearbyPlaces = rawResults;
      _churchLastSyncedAt = DateTime.now();
      unawaited(
        HiveCacheService.cacheList(
          _churchHiveKey,
          List<Map<String, dynamic>>.from(rawResults),
          expiryHours: 24,
        ),
      );
    } finally {
      _churchSyncInProgress = false;
    }
  }

  Future<void> _assignPlacesFromResults(
    List<Map<String, dynamic>> results,
    LatLng center, {
    bool silent = false,
  }) async {
    final myPos = currentPosition.value;
    for (var p in results) {
      final plat = p['geometry']?['location']?['lat'];
      final plng = p['geometry']?['location']?['lng'];
      if (plat != null && plng != null) {
        final refLat = myPos?.latitude ?? center.latitude;
        final refLng = myPos?.longitude ?? center.longitude;
        final d = Geolocator.distanceBetween(refLat, refLng, plat, plng);
        p['distance'] = _formatMilesFromMeters(d);
      } else {
        p['distance'] = '—';
      }
      final existingDenom = p['denomination']?.toString().trim();
      p['denomination'] = (existingDenom != null && existingDenom.isNotEmpty && existingDenom != 'Church')
          ? existingDenom
          : _parseDenomination(p['name'] ?? '');
    }

    print('[ChurchLocator][_assignPlacesFromResults] assigning ${results.length} → map+list '
        'denom=${selectedDenomination.value ?? "All"}');
    _logNearbyData('_assignPlacesFromResults', results);
    places.assignAll(results);
    originalPlaces.assignAll(results);
    _setDefaultMarkersFast(results);
    markers.refresh();
    print('[ChurchLocator][_assignPlacesFromResults] markers on map: ${markers.length}');
    unawaited(_loadMarkersIncrementally(results.toList()));
    if (results.isNotEmpty) isLoading(false);

    if (!silent && mapController != null && results.isEmpty) {
      mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: center, zoom: 13.0),
        ),
      );
    }
  }

  void toggleBottomSheet() {
    isBottomSheetExpanded.value = !isBottomSheetExpanded.value;
  }

  void zoomIn() {
    currentZoom.value = (currentZoom.value + 0.5).clamp(3.0, 20.0);
    mapController?.animateCamera(CameraUpdate.zoomIn());
  }

  void zoomOut() {
    currentZoom.value = (currentZoom.value - 0.5).clamp(3.0, 20.0);
    mapController?.animateCamera(CameraUpdate.zoomOut());
  }

  void goToMyLocation() async {
    if (isNavigating.value) {
      _userControllingCamera = false;
      isCameraFollowPaused.value = false;
      if (currentPosition.value != null && allRoutesData.isNotEmpty) {
        final route = allRoutesData[selectedRouteIndex.value];
        final points = List<LatLng>.from(route['points'] ?? []);
        if (points.isNotEmpty) {
          _followUserWithCamera(
            LatLng(currentPosition.value!.latitude, currentPosition.value!.longitude),
            points,
            force: true,
          );
          return;
        }
      }
    }

    if (currentPosition.value != null) {
      mapController?.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(currentPosition.value!.latitude, currentPosition.value!.longitude),
          zoom: 15.0,
        ),
      ));
    } else {
      await _determinePosition(silent: places.isNotEmpty);
      if (currentPosition.value != null) {
        mapController?.animateCamera(CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(currentPosition.value!.latitude, currentPosition.value!.longitude),
            zoom: 15.0,
          ),
        ));
      }
    }
  }

  void onCameraMoveStarted() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (isNavigating.value) {
      _userControllingCamera = true;
      isCameraFollowPaused.value = true;
    }
  }

  Future<void> _determinePosition({bool silent = false}) async {
    final hasCachedData = places.isNotEmpty || _allNearbyPlaces.isNotEmpty;

    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    locationServiceEnabled.value = serviceEnabled;

    if (!serviceEnabled) {
      if (!silent) _showSnackSafe('Location', 'Location services are off');
      if (Platform.isAndroid && !silent) {
        try {
          const intent = AndroidIntent(action: 'android.settings.LOCATION_SOURCE_SETTINGS');
          await intent.launch();
        } catch (_) {}
      }
      if (places.isEmpty && !_fetchInProgress) {
        unawaited(searchChurchesAt(defaultLocation, silent: true));
      }
      isLoading(false);
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (!silent) _showSnackSafe('Location', 'Permission denied');
        if (places.isEmpty && !_fetchInProgress) {
          unawaited(searchChurchesAt(defaultLocation, silent: true));
        }
        isLoading(false);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (!silent) _showSnackSafe('Location', 'Permission denied forever');
      if (places.isEmpty && !_fetchInProgress) {
        unawaited(searchChurchesAt(defaultLocation, silent: true));
      }
      isLoading(false);
      return;
    }

    // Last known = instant — GPS refine background me
    Position? pos;
    try {
      pos = await Geolocator.getLastKnownPosition();
      if (pos != null && _isRejectedDefaultLocation(pos)) pos = null;
    } catch (_) {}

    if (pos != null) {
      _applyPositionAndRefreshChurches(pos, hasCachedData: hasCachedData);
      isLoading(false);
      unawaited(_refineGpsInBackground());
      return;
    }

    try {
      pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 3),
      ).timeout(const Duration(seconds: 4));
      if (pos != null && _isRejectedDefaultLocation(pos)) pos = null;
    } catch (_) {
      pos = null;
    }

    if (pos != null) {
      _applyPositionAndRefreshChurches(pos, hasCachedData: hasCachedData);
    } else if (places.isEmpty && !_fetchInProgress) {
      unawaited(searchChurchesAt(_resolveMapCenter(), silent: true));
    }

    isLoading(false);
  }

  void _applyPositionAndRefreshChurches(Position pos, {required bool hasCachedData}) {
    currentPosition.value = pos;
    _cacheLastPosition(pos);
    unawaited(_refreshCity(LatLng(pos.latitude, pos.longitude)));

    if (mapController != null) {
      mapController?.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(pos.latitude, pos.longitude),
          zoom: 14.0,
        ),
      ));
    }

    if (hqQuery.value != null && hqQuery.value!.isNotEmpty) return;

    final center = LatLng(pos.latitude, pos.longitude);
    final movedFar = _lastSearchCenter == null ||
        Geolocator.distanceBetween(
          _lastSearchCenter!.latitude,
          _lastSearchCenter!.longitude,
          center.latitude,
          center.longitude,
        ) > 1500;
    if ((places.isEmpty || movedFar) && !_fetchInProgress) {
      unawaited(searchChurchesAt(center, silent: hasCachedData));
    } else if (_allNearbyPlaces.isNotEmpty) {
      unawaited(_silentRefreshNearby());
    }
  }

  Future<void> _refineGpsInBackground() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      ).timeout(const Duration(seconds: 6));
      if (pos == null || _isRejectedDefaultLocation(pos)) return;
      final prev = currentPosition.value;
      currentPosition.value = pos;
      _cacheLastPosition(pos);
      if (prev != null) {
        final moved = Geolocator.distanceBetween(
          prev.latitude, prev.longitude, pos.latitude, pos.longitude,
        );
        if (moved < 800) return;
      }
      if (hqQuery.value == null || hqQuery.value!.isEmpty) {
        unawaited(searchChurchesAt(
          LatLng(pos.latitude, pos.longitude),
          silent: true,
        ));
      }
    } catch (_) {}
  }

  bool _isRejectedDefaultLocation(Position pos) {
    return pos.latitude >= 37.6 &&
        pos.latitude <= 37.9 &&
        pos.longitude >= -122.5 &&
        pos.longitude <= -122.3;
  }

  void onMapCreated(GoogleMapController controller) {
    print('DEBUG: [ChurchLocator] Google Map Created successfully');
    mapController = controller;
    isMapReady.value = true;
    final center = _resolveMapCenter();
    mapController?.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(target: center, zoom: 13.0),
    ));
    if (places.isNotEmpty || _pendingFitMarkers) {
      fitAllMarkers();
      markers.refresh();
    } else if (_allNearbyPlaces.isEmpty && !_fetchInProgress) {
      unawaited(searchChurchesAt(center, silent: true));
    }
  }

  void searchChurches({bool forceGlobal = false}) async {
    if (currentPosition.value == null) {
      await searchChurchesAt(defaultLocation);
      return;
    }

    final center = cameraTarget.value ??
        (currentPosition.value != null
            ? LatLng(
                currentPosition.value!.latitude,
                currentPosition.value!.longitude,
              )
            : defaultLocation);

    if (_allNearbyPlaces.isNotEmpty && !forceGlobal) {
      final filtered = _filterResultsByDenomination(
        List<Map<String, dynamic>>.from(_allNearbyPlaces),
        selectedDenomination.value,
      );
      await _assignPlacesFromResults(filtered, center, silent: true);
      if (filtered.isEmpty && selectedDenomination.value != null) {
        _handleDenominationSearchMiss(_denominationSearchQuery(selectedDenomination.value));
      }
      unawaited(_refreshNearbyMaster(center, silent: true));
      return;
    }

    try {
      await _refreshNearbyMaster(center, silent: true);
      var results = _filterResultsByDenomination(
        _allNearbyPlaces,
        selectedDenomination.value,
      );

      if (results.isEmpty && _allNearbyPlaces.isNotEmpty) {
        results = _filterResultsByDenomination(
          _allNearbyPlaces,
          selectedDenomination.value,
        );
      }

      if (results.isEmpty) {
        await _refreshNearbyMaster(defaultLocation, silent: true);
        results = _filterResultsByDenomination(
          _allNearbyPlaces,
          selectedDenomination.value,
        );
      }

      await _assignPlacesFromResults(results, center, silent: true);
      if (results.isEmpty) {
        _handleNearbySearchMiss();
      } else {
        _setExternalMapsOffer('', show: false);
      }
    } catch (e) {
      _showSnackSafe('Error', 'Failed to find churches');
      _handleNearbySearchMiss();
    } finally {
      isFilterLoading.value = false;
      isLoading(false);
    }
  }

  int _markerLoadGeneration = 0;

  /// Turant red pins — custom icons baad me load honge.
  void _setDefaultMarkersFast(List<Map<String, dynamic>> allPlaces) {
    if (allPlaces.isEmpty) {
      markers.clear();
      return;
    }
    final list = <Marker>[];
    for (final p in allPlaces) {
      final loc = p['geometry']?['location'];
      if (loc is! Map) continue;
      final lat = loc['lat'];
      final lng = loc['lng'];
      if (lat is! num || lng is! num) continue;
      final placeId = p['place_id']?.toString() ?? '${lat}_${lng}_${p['name']}';
      final place = p;
      list.add(Marker(
        markerId: MarkerId(placeId),
        position: LatLng(lat.toDouble(), lng.toDouble()),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: p['name']?.toString() ?? 'Church',
          snippet: p['vicinity']?.toString() ?? '',
        ),
        onTap: () {
          selectedPlace.value = place;
          selectChurchAndShowRoute(place);
        },
      ));
    }
    if (list.isNotEmpty) {
      markers.assignAll(list);
      fitAllMarkers();
    }
  }

  Future<void> _loadMarkersIncrementally(List<Map<String, dynamic>> allPlaces) async {
    if (allPlaces.isEmpty) return;

    final generation = ++_markerLoadGeneration;
    try {
      if (allPlaces.length <= 30) {
        final built = await _markersFromPlaces(allPlaces);
        if (generation != _markerLoadGeneration || built.isEmpty) return;
        markers.assignAll(built);
        markers.refresh();
        fitAllMarkers();
        return;
      }

      final initialBatch = allPlaces.take(12).toList();
      final initialMarkers = await _markersFromPlaces(initialBatch);
      if (generation != _markerLoadGeneration || initialMarkers.isEmpty) return;
      markers.assignAll(initialMarkers);
      markers.refresh();

      final remaining = allPlaces.skip(12).toList();
      if (remaining.isEmpty) {
        fitAllMarkers();
        return;
      }

      final built = List<Marker>.from(markers);
      for (var i = 0; i < remaining.length; i += 10) {
        if (generation != _markerLoadGeneration) return;
        final batch = remaining.skip(i).take(10).toList();
        final batchMarkers = await _markersFromPlaces(batch);
        if (generation != _markerLoadGeneration) return;
        built.addAll(batchMarkers);
        markers.assignAll(List<Marker>.from(built));
        markers.refresh();
        await Future.delayed(const Duration(milliseconds: 30));
      }
      fitAllMarkers();
    } catch (_) {
      if (markers.isEmpty) _setDefaultMarkersFast(allPlaces);
    }
  }

  Future<void> searchChurchesAt(LatLng center, {bool silent = false}) async {
    if (_fetchInProgress) {
      if (!silent) {
        await Future.delayed(const Duration(milliseconds: 400));
      } else {
        return;
      }
    }
    if (_fetchInProgress) return;
    _fetchInProgress = true;
    _lastSearchCenter = center;
    try {
      if (!silent) ChurchLocatorService.clearOsmMemoryCache();
      bootstrapChurchesFromHive();

      if (places.isNotEmpty && _allNearbyPlaces.isNotEmpty) {
        final cached = _filterResultsByDenomination(
          _filterChristianChurchesOnly(List<Map<String, dynamic>>.from(_allNearbyPlaces)),
          selectedDenomination.value,
        );
        await _assignPlacesFromResults(cached, center, silent: true);
        isLoading(false);
      }

      final gen = ++_progressiveFetchGen;
      _progressiveDisplayed = 0;
      unawaited(() async {
        try {
          await _refreshNearbyMaster(
            center,
            silent: silent && _allNearbyPlaces.isNotEmpty,
            onProgress: (accumulated, {required bool done}) {
              unawaited(
                _applyProgressiveChurches(
                  accumulated,
                  center,
                  done: done,
                  silent: silent,
                  generation: gen,
                ),
              );
            },
          );
          print('[ChurchLocator][searchChurchesAt] master=${_allNearbyPlaces.length} '
              'displayed=${places.length} silent=$silent');
          ChurchLocatorService.printPipelineReport(displayed: places.length);
          print('[ChurchLocator] ✅ FINAL displayed: places=${places.length} markers=${markers.length}');
          if (places.isEmpty) _handleNearbySearchMiss();
        } catch (e) {
          if (!silent) _showSnackSafe('Error', 'Failed to find churches');
          _handleNearbySearchMiss();
        } finally {
          isLoading(false);
          _fetchInProgress = false;
        }
      }());
    } catch (e) {
      if (!silent) _showSnackSafe('Error', 'Failed to find churches');
      _fetchInProgress = false;
      if (!silent) isLoading(false);
    }
  }


  List<Map<String, dynamic>> _cachedPlacesForSearch() {
    if (_allNearbyPlaces.isNotEmpty) {
      return List<Map<String, dynamic>>.from(_allNearbyPlaces);
    }
    if (places.isNotEmpty) return List<Map<String, dynamic>>.from(places);
    return [];
  }

  /// Search X / clear — route card + selection hatao, nearby list wapas.
  void _setExternalMapsOffer(String query, {required bool show}) {
    if (show && query.trim().length >= 2) {
      externalSearchQuery.value = query.trim();
      showExternalMapsOffer.value = true;
    } else {
      showExternalMapsOffer.value = false;
      externalSearchQuery.value = '';
    }
  }

  void openExternalMapsSearchDialog([String? query]) {
    final q = (query ?? externalSearchQuery.value).trim();
    if (q.isEmpty) return;
    final center = _resolveMapCenter();
    MapLauncherService.showExternalSearchDialog(
      query: q,
      lat: center.latitude,
      lng: center.longitude,
    );
  }

  Future<void> openGoogleMapsSearchExternal([String? query]) async {
    final q = (query ?? externalSearchQuery.value).trim();
    if (q.isEmpty) return;
    final center = _resolveMapCenter();
    await MapLauncherService.openGoogleMapsSearch(
      q,
      lat: center.latitude,
      lng: center.longitude,
    );
  }

  Future<void> openAppleMapsSearchExternal([String? query]) async {
    final q = (query ?? externalSearchQuery.value).trim();
    if (q.isEmpty) return;
    final center = _resolveMapCenter();
    await MapLauncherService.openAppleMapsSearch(
      q,
      lat: center.latitude,
      lng: center.longitude,
    );
  }

  Future<void> openExternalMapsSearchDirect([String? query]) async {
    final q = (query ?? externalSearchQuery.value).trim();
    if (q.isEmpty) return;
    final center = _resolveMapCenter();
    await MapLauncherService.openExternalMapsSearchAuto(
      q,
      lat: center.latitude,
      lng: center.longitude,
    );
  }

  String _defaultNearbyMapsQuery() {
    final d = selectedDenomination.value;
    if (d != null && d.isNotEmpty) return _denominationSearchQuery(d);
    return 'church';
  }

  void _handleNearbySearchMiss([String? query]) {
    _offerExternalMapsSearch(query ?? _defaultNearbyMapsQuery(), openDialog: false);
  }

  Future<void> resetSearchAndSelection() async {
    _searchSuggestGeneration++;
    _searchDebounce?.cancel();
    hqQuery.value = null;
    searchController.clear();
    searchActive.value = false;
    suggestions.clear();
    _setExternalMapsOffer('', show: false);
    await dismissRouteAndNavigation();

    final center = _resolveMapCenter();
    if (_allNearbyPlaces.isNotEmpty) {
      final filtered = _filterResultsByDenomination(
        _filterChristianChurchesOnly(List<Map<String, dynamic>>.from(_allNearbyPlaces)),
        selectedDenomination.value,
      );
      await _assignPlacesFromResults(filtered, center, silent: true);
    } else {
      await searchChurchesAt(center, silent: true);
    }
  }

  Future<void> searchByTextQuery(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      await resetSearchAndSelection();
      return;
    }

    final matchedSuggestion = _matchSuggestionForQuery(q);
    if (matchedSuggestion != null) {
      await selectPrediction(matchedSuggestion);
      return;
    }

    final center = _resolveMapCenter();
    final cache = _cachedPlacesForSearch();

    if (cache.isEmpty && _allNearbyPlaces.isEmpty) {
      await searchChurchesAt(center, silent: true);
    }
    final searchCache = _cachedPlacesForSearch();

    final cacheHit = ChurchLocatorService.findInCache(searchCache, q, center: center);
    if (cacheHit != null && _churchNameMatchScore(cacheHit, q) >= 100) {
      await selectChurchAndShowRoute(cacheHit);
      return;
    }

    final instantHits = ChurchLocatorService.filterCachedPlaces(
      cached: searchCache,
      input: q,
      locationBias: center,
      maxRadiusMeters: ChurchLocatorService.nearbyRadiusMeters,
      limit: 20,
    );

    // Ek word + search → Maps (denomination/keyword jaisa)
    if (_isSingleWordQuery(q)) {
      if (instantHits.length == 1 && _churchNameMatchScore(instantHits.first, q) >= 100) {
        await selectChurchAndShowRoute(instantHits.first);
        return;
      }
      hqQuery.value = q;
      _offerExternalMapsSearch(_denominationSearchQuery(q));
      return;
    }

    if (instantHits.length > 1) {
      await _showSearchSuggestionResults(instantHits, q);
      return;
    }
    if (instantHits.length == 1 ||
        (instantHits.isNotEmpty && _churchNameMatchScore(instantHits.first, q) >= 90)) {
      await selectChurchAndShowRoute(instantHits.first);
      return;
    }

    try {
      final exactChurch = await ChurchLocatorService.findChurchByName(
        query: q,
        center: center,
        cachedPlaces: searchCache,
      );
      if (exactChurch != null) {
        await selectChurchAndShowRoute(exactChurch);
        return;
      }

      var results = <Map<String, dynamic>>[];
      if (ApiConfig.useGoogleMapsWebServices) {
        try {
          results = await PlacesService.searchByQuery(
            query: q,
            location: center,
          ).timeout(const Duration(seconds: 3));
        } catch (_) {}
      }

      if (results.isEmpty) {
        results = await ChurchLocatorService.localSuggestions(
          input: q,
          locationBias: center,
          maxRadiusMeters: ChurchLocatorService.nearbyRadiusMeters,
          limit: 30,
          cachedPlaces: searchCache,
          fetchNetwork: true,
        );
      }

      results = ChurchLocatorService.filterWithinRadius(
        _filterChristianChurchesOnly(List<Map<String, dynamic>>.from(results)),
        center,
        ChurchLocatorService.nearbyRadiusMeters,
      );
      results.sort((a, b) => _churchNameMatchScore(b, q).compareTo(_churchNameMatchScore(a, q)));

      for (var p in results) {
        await _enrichPlaceForMap(p);
      }

      hqQuery.value = q;

      if (results.isEmpty) {
        _offerExternalMapsSearch(q);
        return;
      }

      if (results.length > 1 && _churchNameMatchScore(results.first, q) < 85) {
        await _showSearchSuggestionResults(results, q);
        return;
      }

      places.assignAll(results);
      originalPlaces.assignAll(results);
      markers.assignAll(await _markersFromPlaces(results));
      suggestions.clear();
      _setExternalMapsOffer('', show: false);

      if (_churchNameMatchScore(results.first, q) >= 85) {
        await selectChurchAndShowRoute(results.first);
      } else {
        selectedPlace.value = Map<String, dynamic>.from(results.first);
        searchController.text = _displayNameForPlace(results.first);
        focusPlace(results.first);
      }
    } catch (e) {
      _showSnackSafe('Error', 'Search failed');
    } finally {
      isLoading(false);
    }
  }

  void onCameraMove(CameraPosition position) {
    cameraTarget.value = position.target;
    _lastCameraZoom = position.zoom;
    currentZoom.value = position.zoom;
    final newLabelMode = position.zoom >= 13.5;
    if (newLabelMode != _labelMode) {
      _labelMode = newLabelMode;
      _applyMarkersForCurrentPlaces();
    }
  }

  void onCameraIdle() {
    if (hqQuery.value != null && hqQuery.value!.isNotEmpty) return;
    if (cameraTarget.value != null && (_lastCityCenter == null ||
        Geolocator.distanceBetween(
          _lastCityCenter!.latitude,
          _lastCityCenter!.longitude,
          cameraTarget.value!.latitude,
          cameraTarget.value!.longitude,
        ) > 3000)) {
      _refreshCity(cameraTarget.value!);
    }
  }

  void retryLocation() {
    _determinePosition();
  }

  void _showSnackSafe(String title, String message) {
    // Controller has no BuildContext — only log here.
    // The screen layer should handle user-facing messages.
    print('ChurchLocator [$title]: $message');
  }

  void _startClock() {
    void tick() {
      final now = DateTime.now();
      final h = now.hour % 12 == 0 ? 12 : now.hour % 12;
      final m = now.minute.toString().padLeft(2, '0');
      final ap = now.hour >= 12 ? 'PM' : 'AM';
      currentTime.value = '$h:$m $ap';
    }
    tick();
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) => tick());
  }

  Future<void> _refreshCity(LatLng center) async {
    _lastCityCenter = center;
    try {
      final name = ApiConfig.useGoogleMapsWebServices
          ? await PlacesService.reverseGeocodeCity(location: center)
          : await ChurchLocatorService.reverseGeocodeCity(center);
      currentCity.value = name;
    } catch (_) {}
  }

  @override
  void onClose() {
    _clockTimer?.cancel();
    _searchDebounce?.cancel();
    _navigationTimer?.cancel();
    _stopCompassTracking();
    _stopGyroscopeTracking();
    clearRoute();
    searchController.dispose();
    super.onClose();
  }

  /// Start Nav button — pehle Google Maps vs in-app pucho.
  void startNavigation(LatLng destination, String churchName) {
    MapLauncherService.showNavigationChoiceDialog(
      name: churchName,
      lat: destination.latitude,
      lng: destination.longitude,
      onInAppNavigation: () => _startInAppNavigation(destination, churchName),
    );
  }

  Future<void> _startInAppNavigation(LatLng destination, String churchName) async {
    if (currentPosition.value == null) {
      await _determinePosition();
      if (currentPosition.value == null) return;
    }

    _navDestination = destination;
    _navDestinationName = churchName;

    isNavigating.value = true;
    currentNavigationStep.value = 0;
    navigationProgress.value = 0.0;
    _userControllingCamera = false;
    isCameraFollowPaused.value = false;

    // Start compass and gyroscope tracking
    _startCompassTracking();
    _startGyroscopeTracking();

    // Start navigation timer for ETA updates
    _startNavigationTimer();

    // Create and show navigation arrow marker immediately
    await _updateNavigationMarker();

    // Listen to real-time position changes
    await _positionStreamSubscription?.cancel();
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: Platform.isAndroid
          ? AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 4,
        intervalDuration: const Duration(milliseconds: 900),
      )
          : AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 4,
        activityType: ActivityType.automotiveNavigation,
      ),
    ).listen((Position position) {
      currentPosition.value = position;
      _updateHeadingFromPosition(position);
      _processLiveNavigationPosition(position);
      _updateNavigationMarker();
    }, onError: (error) {
      // Fallback without Android foreground-service mode if device/OS rejects it.
      _positionStreamSubscription?.cancel();
      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 5,
        ),
      ).listen((Position position) {
        currentPosition.value = position;
        _updateHeadingFromPosition(position);
        _processLiveNavigationPosition(position);
        _updateNavigationMarker();
      });
    });

    // Switch to navigation camera immediately
    if (currentPosition.value != null && allRoutesData.isNotEmpty) {
      final route = allRoutesData[selectedRouteIndex.value];
      final points = List<LatLng>.from(route['points'] ?? []);
      if (points.isNotEmpty) {
        _followUserWithCamera(
          LatLng(currentPosition.value!.latitude, currentPosition.value!.longitude),
          points,
          force: true,
        );
      }
    }
  }

  // Open Google Maps — church naam + exact coordinates dono bhejo
  Future<void> _openGoogleMapsForNavigation(LatLng destination, String churchName) async {
    try {
      await MapLauncherService.openGoogleMaps(
        destination.latitude,
        destination.longitude,
        churchName,
      );
    } catch (_) {
      Get.snackbar(
        'Error',
        'Google Maps not available',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  // Stop Navigation and dismiss route preview UI completely.
  Future<void> dismissRouteAndNavigation() async {
    _routeRequestId++;
    stopNavigation();
    selectedPlace.value = null;
    _navDestination = null;
    _navDestinationName = 'Destination';
    navigationInstructions.value = '';
    navigationDistance.value = '';
    navigationDuration.value = '';
    navigationETA.value = '';
    routeDistance.value = '';
    routeDuration.value = '';
    currentNavigationStep.value = 0;
    navigationProgress.value = 0.0;
    nextTurnDirection.value = '';
    nextTurnDistance.value = '';
    isApproachingTurn.value = false;
    currentDirection.value = 0.0;
    _isRerouting = false;
    isRerouting.value = false;
    await _restoreAllChurches();
  }

  Future<void> _restoreAllChurches() async {
    if (originalPlaces.isNotEmpty) {
      places.assignAll(originalPlaces);
      markers.assignAll(await _markersFromPlaces(originalPlaces));
      debugPrint('📍 Restored ${originalPlaces.length} churches to bottom list');
      return;
    }
    if (places.length <= 1) {
      searchChurches();
    }
  }

  void _ensureSelectedPlaceForRoute(LatLng dest, String name, {Map<String, dynamic>? sourcePlace}) {
    if (sourcePlace != null) {
      selectedPlace.value = Map<String, dynamic>.from(sourcePlace);
      return;
    }

    if (selectedPlace.value != null) {
      final existing = selectedPlace.value!;
      final loc = existing['geometry']?['location'];
      if (loc is Map) {
        final lat = loc['lat'];
        final lng = loc['lng'];
        if (lat != null && lng != null) {
          final d = Geolocator.distanceBetween(dest.latitude, dest.longitude, lat, lng);
          if (d < 120) return;
        }
      }
    }

    for (final p in [...places, ...originalPlaces]) {
      final loc = p['geometry']?['location'];
      if (loc is! Map) continue;
      final lat = loc['lat'];
      final lng = loc['lng'];
      if (lat == null || lng == null) continue;
      final d = Geolocator.distanceBetween(dest.latitude, dest.longitude, lat, lng);
      final pname = p['name']?.toString().toLowerCase() ?? '';
      if (d < 80 || pname == name.toLowerCase()) {
        selectedPlace.value = Map<String, dynamic>.from(p);
        return;
      }
    }

    selectedPlace.value = {
      'name': name,
      'geometry': {'location': {'lat': dest.latitude, 'lng': dest.longitude}},
      'vicinity': '',
      'formatted_address': '',
    };
  }

  /// Church tap — Google API jaisa: pehle map + details, phir route preview.
  Future<void> selectChurchAndShowRoute(Map<String, dynamic> place) async {
    final loc = place['geometry']?['location'];
    if (loc == null) return;
    final rawLat = loc['lat'];
    final rawLng = loc['lng'];
    if (rawLat == null || rawLng == null) return;

    if (isNavigating.value) stopNavigation();

    var resolved = Map<String, dynamic>.from(place);
    final pid = place['place_id']?.toString() ?? '';
    if (pid.startsWith('osm_') || pid.startsWith('local_')) {
      resolved = await ChurchLocatorService.resolvePlaceLocation(resolved);
    }

    final enriched = await _enrichPlaceForMap(resolved);
    final name = _displayNameForPlace(enriched);
    final rLoc = enriched['geometry']?['location'];
    if (rLoc is! Map || rLoc['lat'] == null || rLoc['lng'] == null) return;

    final lat = (rLoc['lat'] as num).toDouble();
    final lng = (rLoc['lng'] as num).toDouble();

    hqQuery.value = name;
    searchController.text = name;
    suggestions.clear();
    selectedPlace.value = enriched;
    _upsertPlaceInList(enriched);
    markers.assignAll(await _markersFromPlaces(places.toList()));
    focusPlace(enriched);

    await routeToInApp(LatLng(lat, lng), name, sourcePlace: enriched);
  }

  /// Search/suggestion se church map par set karo (route alag se).
  Future<void> applyChurchToMap(
    Map<String, dynamic> place, {
    String? searchQuery,
  }) async {
    final enriched = await _enrichPlaceForMap(place);
    final loc = enriched['geometry']?['location'];
    if (loc is! Map || loc['lat'] == null || loc['lng'] == null) return;

    final name = _displayNameForPlace(enriched);
    hqQuery.value = searchQuery ?? name;
    searchController.text = name;
    suggestions.clear();
    selectedPlace.value = enriched;
    _upsertPlaceInList(enriched);
    markers.assignAll(await _markersFromPlaces(places.toList()));
    focusPlace(enriched);
  }

  String _displayNameForPlace(Map<String, dynamic> place) {
    final name = place['name']?.toString();
    if (name != null && name.trim().isNotEmpty) return name.trim();
    final main = place['structured_formatting']?['main_text']?.toString();
    if (main != null && main.trim().isNotEmpty) return main.trim();
    final desc = place['description']?.toString() ?? '';
    if (desc.contains('—')) return desc.split('—').first.trim();
    return desc.trim().isNotEmpty ? desc.trim() : 'Church';
  }

  Map<String, dynamic>? _matchSuggestionForQuery(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty || suggestions.isEmpty) return null;

    Map<String, dynamic>? best;
    var bestScore = 0;
    for (final s in suggestions) {
      final score = _churchNameMatchScore(s, q);
      if (score > bestScore) {
        bestScore = score;
        best = s;
      }
    }
    return bestScore >= 60 ? best : null;
  }

  int _churchNameMatchScore(Map<String, dynamic> place, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return 0;
    final name = _displayNameForPlace(place).toLowerCase();
    final desc = (place['description'] ?? '').toString().toLowerCase();
    if (name == q) return 100;
    if (name.startsWith(q)) return 85;
    if (name.contains(q)) return 70;
    if (desc.contains(q)) return 60;
    return 0;
  }

  Future<Map<String, dynamic>> _enrichPlaceForMap(Map<String, dynamic> place) async {
    final copy = Map<String, dynamic>.from(place);
    if (copy['name'] == null || copy['name'].toString().trim().isEmpty) {
      copy['name'] = _displayNameForPlace(copy);
    }
    final loc = copy['geometry']?['location'];
    if (loc is Map) {
      final plat = loc['lat'];
      final plng = loc['lng'];
      if (plat is num && plng is num && currentPosition.value != null) {
        final d = Geolocator.distanceBetween(
          currentPosition.value!.latitude,
          currentPosition.value!.longitude,
          plat.toDouble(),
          plng.toDouble(),
        );
        copy['distance'] = _formatMilesFromMeters(d);
      } else if (copy['distance'] == null) {
        copy['distance'] = '—';
      }
    }
    copy['denomination'] = (copy['denomination']?.toString().isNotEmpty == true)
        ? copy['denomination']
        : _parseDenomination(copy['name']?.toString() ?? '');
    return copy;
  }

  void _upsertPlaceInList(Map<String, dynamic> place) {
    final idx = places.indexWhere((p) => _isSameChurch(p, place));
    if (idx >= 0) {
      places[idx] = place;
      final oIdx = originalPlaces.indexWhere((p) => _isSameChurch(p, place));
      if (oIdx >= 0) originalPlaces[oIdx] = place;
    } else {
      places.insert(0, place);
      originalPlaces.insert(0, place);
    }
    places.refresh();
    originalPlaces.refresh();
  }

  bool _isSameChurch(Map<String, dynamic> a, Map<String, dynamic> b) {
    final idA = a['place_id']?.toString();
    final idB = b['place_id']?.toString();
    if (idA != null && idB != null && idA.isNotEmpty && idA == idB) return true;

    final nameA = _displayNameForPlace(a).toLowerCase();
    final nameB = _displayNameForPlace(b).toLowerCase();
    final locA = a['geometry']?['location'];
    final locB = b['geometry']?['location'];
    if (locA is Map && locB is Map && locA['lat'] is num && locB['lat'] is num) {
      final d = Geolocator.distanceBetween(
        (locA['lat'] as num).toDouble(),
        (locA['lng'] as num).toDouble(),
        (locB['lat'] as num).toDouble(),
        (locB['lng'] as num).toDouble(),
      );
      if (d < 80 && nameA == nameB) return true;
    }
    return nameA.isNotEmpty && nameA == nameB;
  }

  // Stop active navigation tracking (keeps route preview unless dismissed separately).
  void stopNavigation() async {
    await _softResetMapCamera();
    isNavigating.value = false;
    navigationMarker.value = null;
    _navigationTimer?.cancel();
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _stopCompassTracking();
    _stopGyroscopeTracking();
    _navDestination = null;
    _navDestinationName = 'Destination';
    _userControllingCamera = false;
    isCameraFollowPaused.value = false;
    _clearRouteOverlays();
    debugPrint('🧭 Navigation stopped');
  }

  // Start Compass Tracking
  void _startCompassTracking() {
    _stopCompassTracking();

    // Try to start magnetometer, but have fallback
    try {
      _magnetometerSubscription = magnetometerEvents.listen((MagnetometerEvent event) {
        magnetometerX.value = event.x;
        magnetometerY.value = event.y;
        magnetometerZ.value = event.z;

        // Calculate heading from magnetometer data
        final heading = _calculateHeadingFromMagnetometer(event.x, event.y, event.z);
        _smoothedHeading = _blendAngles(_smoothedHeading, heading, 0.12);
        userHeading.value = _smoothedHeading;
        isCompassActive.value = true;

        // Update navigation based on user's actual heading
        _updateNavigationBasedOnHeading();

        // Update navigation arrow marker with new heading
        if (isNavigating.value) {
          _updateNavigationMarker();
        }
      });

      debugPrint('🧭 Magnetometer tracking started');
    } catch (e) {
      debugPrint('🧭 Error starting magnetometer: $e');
      debugPrint('🧭 Using fallback navigation without sensors');

      // Fallback: Use simulated compass
      _startFallbackCompass();
    }
  }

  // Fallback Compass (without sensors) — use GPS course, not fake rotation
  void _startFallbackCompass() {
    isCompassActive.value = false;
    debugPrint('🧭 No magnetometer — using GPS course for heading');
  }

  /// Prefer GPS course when moving; fuse with compass when slow/stationary.
  void _updateHeadingFromPosition(Position position) {
    final hasGpsHeading = position.heading >= 0 && !position.heading.isNaN;
    final speedMps = position.speed.isFinite && position.speed > 0 ? position.speed : 0.0;

    if (hasGpsHeading && speedMps > 1.5) {
      // GPS course is reliable above ~5 km/h
      _smoothedHeading = _blendAngles(_smoothedHeading, position.heading, 0.45);
      userHeading.value = _smoothedHeading;
      currentDirection.value = _smoothedHeading;
      isCompassActive.value = true;
    } else if (!isCompassActive.value && allRoutesData.isNotEmpty) {
      // Derive bearing from route when stationary and no compass
      final route = allRoutesData[selectedRouteIndex.value];
      final points = List<LatLng>.from(route['points'] ?? <LatLng>[]);
      if (points.length >= 2) {
        final current = LatLng(position.latitude, position.longitude);
        final idx = _nearestPointIndex(current, points);
        final nextIdx = (idx + 1).clamp(0, points.length - 1);
        final bearing = Geolocator.bearingBetween(
          current.latitude, current.longitude,
          points[nextIdx].latitude, points[nextIdx].longitude,
        );
        _smoothedHeading = _blendAngles(_smoothedHeading, bearing, 0.2);
        userHeading.value = _smoothedHeading;
        currentDirection.value = _smoothedHeading;
      }
    }
  }

  // Stop Compass Tracking
  void _stopCompassTracking() {
    _magnetometerSubscription?.cancel();
    _magnetometerSubscription = null;
    _compassTimer?.cancel();
    _compassTimer = null;
    isCompassActive.value = false;
    debugPrint('🧭 Compass tracking stopped');
  }

  // Calculate Heading from Magnetometer
  double _calculateHeadingFromMagnetometer(double x, double y, double z) {
    // Simple heading calculation from magnetometer data
    // This is a basic implementation - in production, you'd want more sophisticated calculations
    double heading = (math.atan2(y, x) * 180 / math.pi);

    // Normalize to 0-360 degrees
    if (heading < 0) {
      heading += 360;
    }

    return heading;
  }

  double _blendAngles(double previousDeg, double targetDeg, double alpha) {
    var delta = targetDeg - previousDeg;
    while (delta > 180) delta -= 360;
    while (delta < -180) delta += 360;
    final blended = previousDeg + delta * alpha;
    return (blended % 360 + 360) % 360;
  }

  // Start Gyroscope Tracking
  void _startGyroscopeTracking() {
    _stopGyroscopeTracking();

    try {
      _gyroscopeSubscription = gyroscopeEvents.listen((GyroscopeEvent event) {
        gyroscopeX.value = event.x;
        gyroscopeY.value = event.y;
        gyroscopeZ.value = event.z;

        final now = DateTime.now();
        final dt = _lastGyroUpdateAt == null
            ? 0.1
            : (now.difference(_lastGyroUpdateAt!).inMilliseconds / 1000.0).clamp(0.01, 0.25);
        _lastGyroUpdateAt = now;

        // Low-pass filter to reduce jitter/noise in angular velocity.
        _filteredGyroZ = (_filteredGyroZ * 0.82) + (event.z * 0.18);
        _detectRotationFromGyroscope(dt);
      });

      debugPrint('🌀 Gyroscope tracking started');
    } catch (e) {
      debugPrint('🌀 Error starting gyroscope: $e');
      debugPrint('🌀 Using fallback navigation without gyroscope');
    }
  }

  // Stop Gyroscope Tracking
  void _stopGyroscopeTracking() {
    _gyroscopeSubscription?.cancel();
    _gyroscopeSubscription = null;
    _lastGyroUpdateAt = null;
    _filteredGyroZ = 0.0;
    debugPrint('🌀 Gyroscope tracking stopped');
  }

  // Update Navigation Based on User Heading
  void _updateNavigationBasedOnHeading() {
    if (!isNavigating.value) return;

    // Update current direction based on user's actual heading
    currentDirection.value = userHeading.value;

    // Update navigation instructions based on where user is facing
    _updateNavigationInstructionsBasedOnHeading();
  }

  // Detect Rotation from Gyroscope
  void _detectRotationFromGyroscope(double dtSeconds) {
    if (!isNavigating.value) return;

    // Ignore very tiny angular velocity to prevent micro-jitter.
    if (_filteredGyroZ.abs() < 0.03) return;

    _handleUserRotation(dtSeconds);
  }

  // Handle User Rotation — fuse gyro delta with compass/GPS heading
  void _handleUserRotation(double dtSeconds) {
    final deltaDegrees = _filteredGyroZ * dtSeconds * (180.0 / math.pi);
    _smoothedHeading = _blendAngles(_smoothedHeading, _smoothedHeading + deltaDegrees, 0.35);
    userHeading.value = _smoothedHeading;
    currentDirection.value = userHeading.value;
  }

  // Update Navigation Instructions Based on Heading
  void _updateNavigationInstructionsBasedOnHeading() {
    if (!isNavigating.value || allRoutesData.isEmpty) return;

    final route = allRoutesData[selectedRouteIndex.value];
    final steps = route['steps'] as List? ?? [];

    if (steps.isNotEmpty && currentNavigationStep.value < steps.length) {
      final currentStep = steps[currentNavigationStep.value];
      String instruction = currentStep['instruction'] ?? 'Continue straight';

      // Adjust instruction based on user's current heading
      instruction = _adjustInstructionForHeading(instruction, userHeading.value);

      navigationInstructions.value = instruction;
    }
  }

  // Adjust Instruction Based on User Heading
  String _adjustInstructionForHeading(String instruction, double heading) {
    // This would adjust the instruction based on where user is currently facing
    // For now, return the original instruction
    // In a real implementation, this would calculate relative directions
    return instruction;
  }

  // Navigation Timer for Real-time Updates
  void _startNavigationTimer() {
    _navigationTimer?.cancel();
    _navigationTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (isNavigating.value) {
        _updateNavigationStatus();
      }
    });
  }

  // Update Navigation Status — ETA only; live position drives turn instructions
  void _updateNavigationStatus() {
    if (!isNavigating.value || allRoutesData.isEmpty) return;

    final route = allRoutesData[selectedRouteIndex.value];
    final steps = route['steps'] as List? ?? [];
    if (steps.isEmpty) return;

    _updateNavigationETA(route, steps);
  }

  void _updateNavigationETA(Map<String, dynamic> route, List steps) {
    final remainingMeters = routeRemainingDistanceMeters.value;
    navigationDistance.value = _toMilesText('${remainingMeters.toStringAsFixed(0)} m');

    final speedMps = currentPosition.value?.speed ?? 0;
    final speedKmh = (speedMps.isFinite && speedMps > 0) ? speedMps * 3.6 : 0.0;

    int etaSeconds;
    if (speedKmh >= 8) {
      etaSeconds = (remainingMeters / (speedKmh / 3.6)).round();
    } else if (_routeDurationSeconds > 0 && route['distanceMeters'] is int) {
      final totalMeters = (route['distanceMeters'] as int).toDouble();
      if (totalMeters > 0) {
        etaSeconds = (_routeDurationSeconds * (remainingMeters / totalMeters)).round();
      } else {
        etaSeconds = _routeDurationSeconds;
      }
    } else {
      // Sum remaining step durations
      etaSeconds = 0;
      for (int i = currentNavigationStep.value; i < steps.length; i++) {
        final step = steps[i];
        if (step is Map) {
          etaSeconds += (step['durationSeconds'] as int?) ?? 0;
        }
      }
    }

    etaSeconds = etaSeconds.clamp(0, 86400);
    final eta = DateTime.now().add(Duration(seconds: etaSeconds));
    navigationETA.value =
    '${eta.hour.toString().padLeft(2, '0')}:${eta.minute.toString().padLeft(2, '0')}';

    if (etaSeconds >= 60) {
      navigationDuration.value = '${(etaSeconds / 60).ceil()} min';
    } else {
      navigationDuration.value = '$etaSeconds sec';
    }
  }

  // Update navigation directions and compass from instruction or Google maneuver
  void _updateNavigationDirections(String instruction, String distance, {String? maneuver}) {
    String turnDirection = 'straight';
    double direction = currentDirection.value;

    final m = (maneuver ?? '').toLowerCase();
    if (m.contains('left') || instruction.toLowerCase().contains('turn left')) {
      turnDirection = 'left';
      direction = 270.0;
      isApproachingTurn.value = true;
    } else if (m.contains('right') || instruction.toLowerCase().contains('turn right')) {
      turnDirection = 'right';
      direction = 90.0;
      isApproachingTurn.value = true;
    } else if (m.contains('uturn') || instruction.toLowerCase().contains('u-turn')) {
      turnDirection = 'uturn';
      direction = 180.0;
      isApproachingTurn.value = true;
    } else if (m.contains('roundabout') || instruction.toLowerCase().contains('roundabout')) {
      turnDirection = 'roundabout';
      isApproachingTurn.value = true;
    } else if (instruction.toLowerCase().contains('merge')) {
      turnDirection = 'merge';
      isApproachingTurn.value = true;
    } else if (instruction.toLowerCase().contains('head north')) {
      direction = 0.0;
      isApproachingTurn.value = false;
    } else if (instruction.toLowerCase().contains('head south')) {
      direction = 180.0;
      isApproachingTurn.value = false;
    } else if (instruction.toLowerCase().contains('head east')) {
      direction = 90.0;
      isApproachingTurn.value = false;
    } else if (instruction.toLowerCase().contains('head west')) {
      direction = 270.0;
      isApproachingTurn.value = false;
    } else {
      isApproachingTurn.value = false;
    }

    nextTurnDirection.value = turnDirection;
    nextTurnDistance.value = distance;
    if (!isCompassActive.value) {
      currentDirection.value = direction;
    }
  }

  // Get direction arrow icon based on turn direction / Google maneuver
  IconData getDirectionArrowIcon() {
    switch (nextTurnDirection.value) {
      case 'left':
      case 'turn-slight-left':
      case 'turn-sharp-left':
        return Icons.turn_left;
      case 'right':
      case 'turn-slight-right':
      case 'turn-sharp-right':
        return Icons.turn_right;
      case 'uturn':
        return Icons.u_turn_left;
      case 'roundabout':
        return Icons.roundabout_left;
      case 'merge':
        return Icons.merge;
      case 'straight':
      default:
        return Icons.arrow_upward;
    }
  }

  // Get compass direction text
  String getCompassDirection() {
    final degree = currentDirection.value;
    if (degree >= 337.5 || degree < 22.5) return 'N';
    if (degree >= 22.5 && degree < 67.5) return 'NE';
    if (degree >= 67.5 && degree < 112.5) return 'E';
    if (degree >= 112.5 && degree < 157.5) return 'SE';
    if (degree >= 157.5 && degree < 202.5) return 'S';
    if (degree >= 202.5 && degree < 247.5) return 'SW';
    if (degree >= 247.5 && degree < 292.5) return 'W';
    return 'NW';
  }

  // Show Navigation Complete
  void _showNavigationComplete() {
    debugPrint('🎉 Navigation completed! Arrived at destination.');
    // You can show a dialog or snackbar here
  }

  // Get Navigation Summary
  Map<String, dynamic> getNavigationSummary() {
    if (allRoutesData.isEmpty) return {};

    final route = allRoutesData[selectedRouteIndex.value];

    // Clean up total distance
    String totalDistance = 'Unknown';
    if (route['total_distance'] != null) {
      totalDistance = route['total_distance'].toString();
      totalDistance = totalDistance.replaceAll(RegExp(r'\{[^}]*\}'), '').trim();
      if (totalDistance.isEmpty) totalDistance = 'Unknown';
    }

    // Clean up total duration
    String totalDuration = 'Unknown';
    if (route['total_duration'] != null) {
      totalDuration = route['total_duration'].toString();
      totalDuration = totalDuration.replaceAll(RegExp(r'\{[^}]*\}'), '').trim();
      if (totalDuration.isEmpty) totalDuration = 'Unknown';
    }

    return {
      'totalDistance': totalDistance,
      'totalDuration': totalDuration,
      'steps': route['steps'] ?? [],
      'currentStep': currentNavigationStep.value,
      'progress': navigationProgress.value,
    };
  }

  // Recalculate Route
  Future<void> recalculateRoute() async {
    if (!isNavigating.value) return;
    await _rerouteFromCurrentPosition();
  }

  // Show Navigation Options
  Future<void> _showNavigationOptions(LatLng destination, String churchName) async {
    // Focus on the destination first
    mapController?.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(target: destination, zoom: 15.0),
    ));

    // Clear ALL existing data and reset navigation state
    _resetNavigationState();

    // Update current selected church for navigation FIRST
    _updateSelectedChurchForNavigation(destination, churchName);

    // Show new route immediately
    await routeToInApp(destination, churchName);

    // Parse route data for distance and duration
    debugPrint('📍 About to parse route data - allRoutesData length: ${allRoutesData.length}');
    if (allRoutesData.isNotEmpty) {
      debugPrint('📍 Calling _parseRouteData with route index: ${selectedRouteIndex.value}');
      _parseRouteData(allRoutesData[selectedRouteIndex.value]);
    } else {
      debugPrint('📍 No route data available to parse');
    }

    // Force UI update - Obx will handle automatically

    // Show navigation options dialog instead of auto-starting
    _showNavigationDialog(destination, churchName);
  }

  // Reset Navigation State (preserves selected church)
  void _resetNavigationState() {
    _clearRouteOverlays();

    isNavigating.value = false;
    currentNavigationStep.value = 0;
    navigationProgress.value = 0.0;
    navigationInstructions.value = '';
    navigationDistance.value = '';
    navigationDuration.value = '';
    navigationETA.value = '';
    routeDistance.value = '';
    routeDuration.value = '';
    currentDirection.value = 0.0;
    nextTurnDirection.value = '';
    nextTurnDistance.value = '';
    isApproachingTurn.value = false;
    isRerouting.value = false;
    _isRerouting = false;
    _lastRerouteAt = null;
    _routeDurationSeconds = 0;

    userHeading.value = 0.0;
    compassAccuracy.value = 0.0;
    isCompassActive.value = false;

    debugPrint('🔄 Navigation state reset');
  }

  // Parse Route Data and Extract Distance/Duration
  void _parseRouteData(Map<String, dynamic> route) {
    debugPrint('📍 Full route API response: $route');
    debugPrint('📍 Route keys available: ${route.keys.toList()}');

    String distance = 'Calculating...';
    String duration = 'Calculating...';

    try {
      // Extract distance - check direct keys first (actual API format)
      if (route['distance'] != null && route['distance'].toString().isNotEmpty) {
        distance = route['distance'].toString();
        debugPrint('📍 Found distance in "distance": $distance');
      } else if (route['total_distance'] != null && route['total_distance'].toString().isNotEmpty) {
        distance = route['total_distance'].toString();
        debugPrint('📍 Found distance in "total_distance": $distance');
      } else if (route['summary'] != null && route['summary'] is Map) {
        final summary = route['summary'] as Map;
        debugPrint('📍 Summary keys: ${summary.keys.toList()}');
        if (summary['distance'] != null && summary['distance'].toString().isNotEmpty) {
          distance = summary['distance'].toString();
          debugPrint('📍 Found distance in "summary.distance": $distance');
        }
      } else if (route['legs'] != null && route['legs'] is List && (route['legs'] as List).isNotEmpty) {
        // Google Maps format - safe array access
        final legs = route['legs'] as List;
        debugPrint('📍 Legs array length: ${legs.length}');
        if (legs.isNotEmpty) {
          final leg = legs[0];
          debugPrint('📍 Leg keys: ${leg.keys.toList()}');
          if (leg is Map && leg['distance'] != null && leg['distance'] is Map) {
            final distanceObj = leg['distance'] as Map;
            debugPrint('📍 Distance object keys: ${distanceObj.keys.toList()}');
            if (distanceObj['text'] != null && distanceObj['text'].toString().isNotEmpty) {
              distance = distanceObj['text'].toString();
              debugPrint('📍 Found distance in "legs[0].distance.text": $distance');
            }
          }
        }
      } else {
        debugPrint('📍 No distance found in route data');
      }

      // Extract duration - check direct keys first (actual API format)
      if (route['duration'] != null && route['duration'].toString().isNotEmpty) {
        duration = route['duration'].toString();
        debugPrint('📍 Found duration in "duration": $duration');
      } else if (route['total_duration'] != null && route['total_duration'].toString().isNotEmpty) {
        duration = route['total_duration'].toString();
        debugPrint('📍 Found duration in "total_duration": $duration');
      } else if (route['summary'] != null && route['summary'] is Map) {
        final summary = route['summary'] as Map;
        if (summary['duration'] != null && summary['duration'].toString().isNotEmpty) {
          duration = summary['duration'].toString();
          debugPrint('📍 Found duration in "summary.duration": $duration');
        }
      } else if (route['legs'] != null && route['legs'] is List && (route['legs'] as List).isNotEmpty) {
        // Google Maps format - safe array access
        final legs = route['legs'] as List;
        if (legs.isNotEmpty) {
          final leg = legs[0];
          if (leg is Map && leg['duration'] != null && leg['duration'] is Map) {
            final durationObj = leg['duration'] as Map;
            if (durationObj['text'] != null && durationObj['text'].toString().isNotEmpty) {
              duration = durationObj['text'].toString();
              debugPrint('📍 Found duration in "legs[0].duration.text": $duration');
            }
          }
        }
      } else {
        debugPrint('📍 No duration found in route data');
      }

    } catch (e) {
      debugPrint('📍 Error parsing route data: $e');
      distance = 'Error';
      duration = 'Error';
    }

    // Update ALL route variables to ensure consistency
    routeDistance.value = _toMilesText(distance);
    routeDuration.value = duration;
    navigationDistance.value = _toMilesText(distance);  // Update navigation card too
    navigationDuration.value = duration; // Update navigation card too
  }

  // Update selected church for navigation (does NOT remove other churches from list).
  void _updateSelectedChurchForNavigation(LatLng destination, String churchName, {Map<String, dynamic>? sourcePlace}) {
    _ensureSelectedPlaceForRoute(destination, churchName, sourcePlace: sourcePlace);
  }

  // Update markers for selected church
  Future<void> _updateMarkersForSelectedChurch() async {
    if (places.isNotEmpty) {
      // Clear existing markers first
      markers.clear();

      // Add new marker for selected church
      final newMarkers = await _markersFromPlaces(places);
      markers.assignAll(newMarkers);

      // Force UI update - Obx will handle automatically

      debugPrint('📍 Updated markers for selected church: ${places.length} markers');
    }
  }

  // Show Navigation Dialog with Start Button
  void _showNavigationDialog(LatLng destination, String churchName) {
    // This will be handled in the UI layer
    // For now, auto-start after showing route
    Future.delayed(const Duration(milliseconds: 500), () {
      if (currentPosition.value != null) {
        // Don't auto-start, let user click "Start Navigation" button
        debugPrint('🧭 Ready to start navigation to $churchName');
      }
    });
  }

  Future<List<Marker>> _markersFromPlaces(List<Map<String, dynamic>> items) async {
    final List<Marker> list = [];
    Set<String> labelIds = {};
    final zoom = _lastCameraZoom ?? 13.0;

    // Create a copy of the items list to avoid concurrent modification
    final List<Map<String, dynamic>> itemsCopy = List.from(items);

    if (_labelMode && itemsCopy.isNotEmpty) {
      final center = cameraTarget.value ?? (currentPosition.value != null ? LatLng(currentPosition.value!.latitude, currentPosition.value!.longitude) : defaultLocation);
      final scored = <MapEntry<String, double>>[];
      for (final p in itemsCopy) {
        final loc = p['geometry']?['location'];
        if (loc == null) continue;
        final d = Geolocator.distanceBetween(center.latitude, center.longitude, loc['lat'], loc['lng']);
        scored.add(MapEntry(p['place_id'], d));
      }
      scored.sort((a, b) => a.value.compareTo(b.value));
      int maxLabels = zoom >= 17 ? 60 : (zoom >= 16 ? 40 : (zoom >= 15 ? 25 : 15));
      labelIds = scored.take(maxLabels).map((e) => e.key).toSet();
    }

    for (final p in itemsCopy) {
      final loc = p['geometry']?['location'];
      if (loc is! Map || loc['lat'] is! num || loc['lng'] is! num) continue;
      final rawName = p['name'] ?? '';
      final lat = loc['lat'];
      final lng = loc['lng'];
      final placeId = p['place_id']?.toString() ??
          '${lat}_${lng}_${rawName.hashCode}';
      final shouldLabel = _labelMode && labelIds.contains(placeId);
      final displayText = shouldLabel ? _compactName(rawName) : rawName;

      BitmapDescriptor? markerIcon;
      Offset? markerAnchor;

      try {
        final iconData = await _labelIcon(displayText, showText: shouldLabel);
        markerIcon = iconData.icon;
        markerAnchor = iconData.anchor;
      } catch (e) {
        print('Error generating custom marker icon for $rawName: $e');
        // Fallback to default marker
        markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
        markerAnchor = const Offset(0.5, 1.0);
      }

      final mLat = (loc['lat'] as num).toDouble();
      final mLng = (loc['lng'] as num).toDouble();
      list.add(Marker(
        markerId: MarkerId(placeId),
        position: LatLng(mLat, mLng),
        icon: markerIcon,
        anchor: markerAnchor,
        infoWindow: InfoWindow(title: rawName, snippet: p['vicinity'] ?? ''),
        onTap: () {
          // Set selectedPlace FIRST!
          selectedPlace.value = p;
          selectChurchAndShowRoute(p);
        },
      ));
    }
    return list;
  }

  Future<void> _applyMarkersForCurrentPlaces() async {
    if (places.isEmpty) return;
    markers.assignAll(await _markersFromPlaces(places));
  }

  Future<MarkerIconData> _labelIcon(String text, {bool showText = true}) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final pinSize = 80.0;
    final innerCircleSize = 58.0;

    TextPainter? tp;
    if (showText) {
      tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(color: const Color(0xFF333333), fontSize: 24.0, fontWeight: FontWeight.w900, shadows: [ui.Shadow(blurRadius: 4.0, color: Colors.white)]),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 2,
      );
      tp.layout(maxWidth: 300);
    }

    final w = pinSize + (tp != null ? (tp.width + 12) : 6);
    final h = (tp != null && tp.height > pinSize ? (tp.height + 10) : pinSize) + 15;

    final shadowPaint = Paint()..color = Colors.black.withOpacity(0.2)..maskFilter = const MaskFilter.blur(ui.BlurStyle.normal, 3);
    canvas.drawCircle(Offset(pinSize / 2, pinSize / 2 + 2), pinSize / 2, shadowPaint);

    final outerPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(pinSize / 2, pinSize / 2), pinSize / 2, outerPaint);

    final pointerPath = ui.Path();
    pointerPath.moveTo(pinSize * 0.15, pinSize * 0.75);
    pointerPath.lineTo(pinSize * 0.5, pinSize * 1.05);
    pointerPath.lineTo(pinSize * 0.85, pinSize * 0.75);
    pointerPath.close();
    canvas.drawPath(pointerPath, outerPaint);

    final innerPaint = Paint()..color = const Color(0xFFE53935);
    canvas.drawCircle(Offset(pinSize / 2, pinSize / 2), innerCircleSize / 2, innerPaint);

    final crossPaint = Paint()..color = Colors.white..strokeWidth = 5.0..strokeCap = ui.StrokeCap.round;
    canvas.drawLine(Offset(pinSize / 2, pinSize / 2 - 14), Offset(pinSize / 2, pinSize / 2 + 14), crossPaint);
    canvas.drawLine(Offset(pinSize / 2 - 10, pinSize / 2 - 4), Offset(pinSize / 2 + 10, pinSize / 2 - 4), crossPaint);

    if (tp != null) {
      tp.paint(canvas, ui.Offset(pinSize + 6, (pinSize/2 - tp.height/2).clamp(0, h)));
    }

    final img = await recorder.endRecording().toImage(w.ceil(), h.ceil());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return MarkerIconData(icon: BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List()), anchor: Offset((pinSize * 0.5) / w, (pinSize * 1.05) / h));
  }

  String _compactName(String name) {
    if (name.length > 35) return '${name.substring(0, 35)}…';
    return name;
  }

  // Create custom navigation arrow marker
  Future<BitmapDescriptor> _createNavigationArrow() async {
    const int arrowSize = 120;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const w = arrowSize;
    const h = arrowSize;

    // Draw blue circle background
    final bgPaint = Paint()..color = const Color(0xFF2196F3);
    canvas.drawCircle(const Offset(w/2, h/2), 40, bgPaint);

    // Draw white circle border
    final borderPaint = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 4;
    canvas.drawCircle(const Offset(w/2, h/2), 40, borderPaint);

    // Draw navigation arrow (white)
    final arrowPaint = Paint()..color = Colors.white..style = PaintingStyle.fill;
    final arrowPath = ui.Path();

    // Arrow pointing up (will rotate with heading)
    arrowPath.moveTo(w/2, h/2 - 30);
    arrowPath.lineTo(w/2 - 18, h/2 + 20);
    arrowPath.lineTo(w/2, h/2 + 8);
    arrowPath.lineTo(w/2 + 18, h/2 + 20);
    arrowPath.close();

    canvas.drawPath(arrowPath, arrowPaint);

    final img = await recorder.endRecording().toImage(w, h);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  // Update navigation marker with current position and heading
  Future<void> _updateNavigationMarker() async {
    if (!isNavigating.value || currentPosition.value == null) {
      navigationMarker.value = null;
      return;
    }

    try {
      _cachedNavArrowIcon ??= await _createNavigationArrow();
      final pos = LatLng(currentPosition.value!.latitude, currentPosition.value!.longitude);

      navigationMarker.value = Marker(
        markerId: const MarkerId('navigation_arrow'),
        position: pos,
        icon: _cachedNavArrowIcon!,
        rotation: userHeading.value,
        anchor: const Offset(0.5, 0.5),
        zIndex: 1000,
        flat: true,
      );
    } catch (e) {}
  }

  void applyDenominationFilter(String denomination) {
    isBottomSheetExpanded.value = true;
    updateDenomination(denomination);
  }

  String _denominationSearchQuery(String? denomination) {
    final d = denomination?.trim() ?? '';
    if (d.isEmpty) return '';
    final lower = d.toLowerCase();
    if (lower.contains('church') || lower.contains('chapel') || lower.contains('cathedral')) {
      return d;
    }
    return '$d church';
  }

  void _syncDenominationSearchBar(String? denomination) {
    if (denomination == null || denomination.isEmpty) {
      searchController.clear();
      searchActive.value = false;
      hqQuery.value = null;
      suggestions.clear();
      _setExternalMapsOffer('', show: false);
      return;
    }
    final q = _denominationSearchQuery(denomination);
    searchController.text = q;
    searchActive.value = true;
    hqQuery.value = q;
    unawaited(onSearchInputChanged(q));
  }

  DateTime? _lastExternalMapsPromptAt;
  String? _lastExternalMapsPromptQuery;

  bool _isSingleWordQuery(String query) {
    final t = query.trim();
    return t.isNotEmpty && !t.contains(RegExp(r'\s'));
  }

  void _offerExternalMapsSearch(String query, {bool openDialog = false}) {
    final q = query.trim();
    if (q.length < 2) return;
    final now = DateTime.now();
    if (_lastExternalMapsPromptQuery == q &&
        _lastExternalMapsPromptAt != null &&
        now.difference(_lastExternalMapsPromptAt!) < const Duration(seconds: 8)) {
      if (openDialog) {
        _setExternalMapsOffer(q, show: true);
        openExternalMapsSearchDialog(q);
      } else {
        unawaited(openExternalMapsSearchDirect(q));
      }
      return;
    }
    _lastExternalMapsPromptQuery = q;
    _lastExternalMapsPromptAt = now;
    if (openDialog) {
      _setExternalMapsOffer(q, show: true);
      openExternalMapsSearchDialog(q);
    } else {
      _setExternalMapsOffer('', show: false);
      unawaited(openExternalMapsSearchDirect(q));
    }
  }

  void _handleDenominationSearchMiss(String query) {
    _offerExternalMapsSearch(query, openDialog: false);
  }

  Future<void> _showSearchSuggestionResults(
    List<Map<String, dynamic>> results,
    String q,
  ) async {
    hqQuery.value = q;
    suggestions.assignAll(results);
    for (final p in results) {
      await _enrichPlaceForMap(p);
    }
    places.assignAll(results);
    originalPlaces.assignAll(results);
    markers.assignAll(await _markersFromPlaces(results));
    _setExternalMapsOffer('', show: false);
    isLoading(false);
  }

  void updateDenomination(String? d) {
    selectedDenomination.value = (d == 'All') ? null : d;
    _syncDenominationSearchBar(selectedDenomination.value);

    if (_allNearbyPlaces.isNotEmpty) {
      final center = _resolveMapCenter();
      final filtered = _filterResultsByDenomination(
        List<Map<String, dynamic>>.from(_allNearbyPlaces),
        selectedDenomination.value,
      );
      unawaited(
        _assignPlacesFromResults(filtered, center, silent: true).then((_) {
          if (filtered.isEmpty && selectedDenomination.value != null) {
            _handleDenominationSearchMiss(_denominationSearchQuery(selectedDenomination.value));
          } else if (filtered.isNotEmpty) {
            _setExternalMapsOffer('', show: false);
          }
        }),
      );
      return;
    }

    searchChurches(forceGlobal: true);
  }

  List<Map<String, dynamic>> _filterChristianChurchesOnly(List<Map<String, dynamic>> results) {
    return results
        .where((p) => !ChurchLocatorService.isExplicitlyNonChristian(p))
        .where(ChurchLocatorService.isChristianChurch)
        .toList();
  }

  List<Map<String, dynamic>> _filterResultsByDenomination(
      List<Map<String, dynamic>> results,
      String? denomination,
      ) {
    if (denomination == null || denomination.isEmpty) return results;

    final keyword = denomination.toLowerCase().trim();
    return results.where((place) => _placeMatchesDenomination(place, keyword)).toList();
  }

  bool _placeMatchesDenomination(Map<String, dynamic> place, String keyword) {
    return ChurchLocatorService.matchesDenomination(place, keyword);
  }

  void focusPlace(Map<String, dynamic> place) {
    selectedPlace.value = place;
    final loc = place['geometry']?['location'];
    if (loc == null) return;
    final lat = loc['lat'];
    final lng = loc['lng'];
    if (lat is! num || lng is! num) return;
    final latlng = LatLng(lat.toDouble(), lng.toDouble());
    cameraTarget.value = latlng;
    mapController?.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(target: latlng, zoom: 15.0),
    ));
  }

  Future<Map<String, dynamic>> fetchChurchDetails(Map<String, dynamic> place) async {
    final enriched = ApiConfig.useGoogleMapsWebServices
        ? await PlacesService.resolvePlaceDetails(place)
        : await ChurchLocatorService.resolvePlaceLocation(place);
    _applyEnrichedPlaceToLists(enriched);
    return enriched;
  }

  void _applyEnrichedPlaceToLists(Map<String, dynamic> enriched) {
    final enrichedId = enriched['place_id']?.toString();
    final enrichedName = enriched['name']?.toString().toLowerCase() ?? '';

    if (selectedPlace.value != null) {
      final selectedId = selectedPlace.value!['place_id']?.toString();
      final selectedName = selectedPlace.value!['name']?.toString().toLowerCase() ?? '';
      if ((enrichedId != null && enrichedId == selectedId) ||
          (enrichedName.isNotEmpty && enrichedName == selectedName)) {
        selectedPlace.value = enriched;
      }
    }

    for (int i = 0; i < places.length; i++) {
      final p = places[i];
      final pid = p['place_id']?.toString();
      final pname = p['name']?.toString().toLowerCase() ?? '';
      if ((enrichedId != null && pid == enrichedId) || (enrichedName.isNotEmpty && pname == enrichedName)) {
        places[i] = {...p, ...enriched};
      }
    }
    places.refresh();
  }

  String _parseDenomination(String name) {
    name = name.toLowerCase();
    if (name.contains('non-denominational') || name.contains('nondenominational')) {
      return 'Non-denominational';
    }
    if (name.contains('catholic')) return 'Catholic';
    if (name.contains('baptist')) return 'Baptist';
    if (name.contains('pentecost')) return 'Pentecostal';
    if (name.contains('lutheran')) return 'Lutheran';
    if (name.contains('anglican')) return 'Anglican';
    if (name.contains('protestant')) return 'Protestant';
    if (name.contains('orthodox')) return 'Orthodox';
    if (name.contains('methodist')) return 'Methodist';
    if (name.contains('presbyterian')) return 'Presbyterian';
    if (name.contains('adventist')) return 'Adventist';
    return 'Church';
  }

  Future<void> onSearchInputChanged(String v) async {
    _searchDebounce?.cancel();
    final q = v.trim();
    searchActive.value = q.isNotEmpty;

    if (q.isEmpty) {
      _searchSuggestGeneration++;
      suggestions.clear();
      _setExternalMapsOffer('', show: false);
      return;
    }

    final bias = _resolveMapCenter();
    final cache = _cachedPlacesForSearch();

    // Instant — loaded churches se filter (0ms)
    if (cache.isEmpty &&
        _allNearbyPlaces.isEmpty &&
        !_churchSyncInProgress &&
        !_fetchInProgress) {
      unawaited(searchChurchesAt(bias, silent: true));
    }
    final searchCache = _cachedPlacesForSearch();

    final instant = ChurchLocatorService.filterCachedPlaces(
      cached: searchCache,
      input: q,
      locationBias: bias,
      maxRadiusMeters: ChurchLocatorService.nearbyRadiusMeters,
      limit: 20,
    );
    suggestions.assignAll(instant);
    if (instant.isNotEmpty) {
      suggestions.refresh();
      _setExternalMapsOffer('', show: false);
    } else if (_isSingleWordQuery(q) && q.length >= 2) {
      _setExternalMapsOffer(_denominationSearchQuery(q), show: true);
    }

    if (instant.length >= 8) return;

    final gen = ++_searchSuggestGeneration;
    _searchDebounce = Timer(const Duration(milliseconds: 80), () async {
      if (gen != _searchSuggestGeneration) return;

      final merged = <String, Map<String, dynamic>>{};
      for (final p in instant) {
        final id = p['place_id']?.toString() ?? p['name']?.toString() ?? '';
        if (id.isNotEmpty) merged[id] = p;
      }

      if (merged.length < 15) {
        final remote = await ChurchLocatorService.localSuggestions(
          input: q,
          locationBias: bias,
          maxRadiusMeters: ChurchLocatorService.nearbyRadiusMeters,
          limit: 20,
          cachedPlaces: searchCache,
          fetchNetwork: merged.isEmpty,
        );
        if (gen != _searchSuggestGeneration) return;
        for (final p in remote) {
          final id = p['place_id']?.toString() ?? p['name']?.toString() ?? '';
          if (id.isNotEmpty) merged[id] = p;
        }
      }

      if (merged.isEmpty && ApiConfig.useGoogleMapsWebServices) {
        try {
          final google = await PlacesService.autocomplete(
            input: q,
            locationBias: bias,
          ).timeout(const Duration(seconds: 2));
          if (gen != _searchSuggestGeneration) return;
          for (final p in google) {
            final label = p['description']?.toString() ??
                p['structured_formatting']?['main_text']?.toString() ??
                '';
            if (ChurchLocatorService.isChristianChurch({'name': label})) {
              final id = p['place_id']?.toString() ?? label;
              merged[id] = p;
            }
          }
        } catch (_) {}
      }

      if (gen != _searchSuggestGeneration) return;
      final within = ChurchLocatorService.filterWithinRadius(
        merged.values.toList(),
        bias,
        ChurchLocatorService.nearbyRadiusMeters,
      );
      suggestions.assignAll(within.take(20).toList());
      if (within.isEmpty) {
        if (_isSingleWordQuery(q) && q.length >= 2) {
          _setExternalMapsOffer(_denominationSearchQuery(q), show: true);
        } else if (q.length >= 3) {
          _setExternalMapsOffer(q, show: true);
        }
      } else {
        _setExternalMapsOffer('', show: false);
      }
    });
  }

  Future<void> selectPrediction(Map<String, dynamic> pred) async {
    final placeId = pred['place_id']?.toString();
    if (placeId == null || placeId.isEmpty) return;

    final localLoc = pred['geometry']?['location'];
    if (localLoc is Map && localLoc['lat'] != null && localLoc['lng'] != null) {
      await selectChurchAndShowRoute(pred);
      return;
    }

    if (!ApiConfig.useGoogleMapsWebServices || placeId.startsWith('osm_')) {
      final name = _displayNameForPlace(pred);
      final found = await ChurchLocatorService.findChurchByName(
        query: name,
        center: _resolveMapCenter(),
        cachedPlaces: _cachedPlacesForSearch(),
      );
      if (found != null) {
        await selectChurchAndShowRoute(found);
      }
      return;
    }

    final blockUi = places.isEmpty;
    if (blockUi) isLoading(true);
    try {
      final details = await PlacesService.placeDetails(placeId: placeId);
      if (details != null) {
        final selectedChurch = {
          'place_id': placeId,
          'name': details['name'] ?? _displayNameForPlace(pred),
          'vicinity': details['formatted_address'] ?? details['vicinity'] ?? '',
          'formatted_address': details['formatted_address'] ?? '',
          'geometry': details['geometry'],
          'photos': details['photos'],
          'church_image_url':
              details['church_image_url'] ?? PlacesService.extractPhotoUrlFromPlace(details),
          'denomination': _parseDenomination(details['name'] ?? ''),
        };
        await selectChurchAndShowRoute(selectedChurch);
      }
    } finally {
      if (blockUi) isLoading(false);
    }
  }

  /// Fetch and display route. Set [isReroute] when recalculating during active navigation.
  Future<void> routeToInApp(LatLng dest, String name, {bool isReroute = false, Map<String, dynamic>? sourcePlace}) async {
    final requestId = ++_routeRequestId;
    try {
      if (!isReroute) {
        _resetNavigationState();
        _ensureSelectedPlaceForRoute(dest, name, sourcePlace: sourcePlace);
      }

      _navDestination = dest;
      _navDestinationName = name;

      if (!isReroute) {
        isLoading(true);
        loadingMessage.value = 'Finding best routes to $name...';
      } else {
        isRerouting.value = true;
      }

      if (currentPosition.value == null) {
        Position? pos;
        try {
          pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 10),
          );
        } catch (e) {}
        if (pos != null) currentPosition.value = pos;
      }

      if (currentPosition.value == null) {
        _showSnackSafe('Location', 'Please enable location to see routes');
        isLoading(false);
        isRerouting.value = false;
        mapController?.animateCamera(CameraUpdate.newCameraPosition(
          CameraPosition(target: dest, zoom: 15.0),
        ));
        return;
      }

      final origin = LatLng(currentPosition.value!.latitude, currentPosition.value!.longitude);

      final isDefaultLocation = origin.latitude >= 37.6 && origin.latitude <= 37.9 &&
          origin.longitude >= -122.5 && origin.longitude <= -122.3;

      if (isDefaultLocation) {
        Position? pos;
        try {
          pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 10),
          );
        } catch (e) {}
        if (pos != null) {
          currentPosition.value = pos;
        }
      }

      final finalOrigin = LatLng(currentPosition.value!.latitude, currentPosition.value!.longitude);

      final distance = Geolocator.distanceBetween(
          finalOrigin.latitude, finalOrigin.longitude,
          dest.latitude, dest.longitude
      );

      if (distance > 5000000) {
        _showSnackSafe('Route', 'Distance too far for route calculation');
        isLoading(false);
        isRerouting.value = false;
        mapController?.animateCamera(CameraUpdate.newCameraPosition(
          CameraPosition(target: dest, zoom: 15.0),
        ));
        return;
      }

      if (!isReroute) {
        _clearRouteOverlays();
      }

      List<Map<String, dynamic>>? results;
      if (ApiConfig.useGoogleMapsWebServices) {
        results = await PlacesService.directions(
          origin: finalOrigin,
          destination: dest,
          mode: 'driving',
        );
      }
      results ??= await ChurchLocatorService.directions(
        origin: finalOrigin,
        destination: dest,
      );

      if (requestId != _routeRequestId) return;

      if (results == null || results.isEmpty) {
        // Directions API fail → external maps open karo
        if (!isReroute) {
          MapLauncherService.showMapOptionsDialog(
            name: name,
            lat: dest.latitude,
            lng: dest.longitude,
          );
        } else {
          _showSnackSafe('Route', 'Could not recalculate route');
        }
        isLoading(false);
        isRerouting.value = false;
        if (!isReroute) {
          mapController?.animateCamera(CameraUpdate.newCameraPosition(
            CameraPosition(target: dest, zoom: 15.0),
          ));
        }
        return;
      }

      if (requestId != _routeRequestId) return;

      allRoutesData.assignAll(results);
      selectedRouteIndex.value = 0;
      await _updateRouteVisuals();

      if (allRoutesData.isNotEmpty) {
        _parseRouteData(allRoutesData[selectedRouteIndex.value]);
        _routeDurationSeconds =
            (allRoutesData[selectedRouteIndex.value]['durationSeconds'] as int?) ?? 0;
      }

      markers.refresh();

      if (!isReroute && results.isNotEmpty && results.first['points'].isNotEmpty) {
        final bounds = _getBounds(List<LatLng>.from(results.first['points']));
        await mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
      } else if (!isReroute) {
        mapController?.animateCamera(CameraUpdate.newCameraPosition(
          CameraPosition(target: dest, zoom: 15.0),
        ));
      }
    } catch (e) {
      // API error → external maps fallback
      if (!isReroute) {
        MapLauncherService.showMapOptionsDialog(
          name: name,
          lat: dest.latitude,
          lng: dest.longitude,
        );
      } else {
        _showSnackSafe('Route', 'Could not get directions');
      }
      if (!isReroute) {
        mapController?.animateCamera(CameraUpdate.newCameraPosition(
          CameraPosition(target: dest, zoom: 15.0),
        ));
      }
    } finally {
      isLoading(false);
      isRerouting.value = false;
    }
  }

// Update _updateRouteVisuals method with more robust error handling
  Future<void> _updateRouteVisuals() async {
    if (allRoutesData.isEmpty) {
      print('DEBUG: _updateRouteVisuals aborted - no route data');
      return;
    }

    final List<Polyline> newPolylines = [];
    final List<Marker> newLabels = [];

    for (int i = 0; i < allRoutesData.length; i++) {
      final isSelected = i == selectedRouteIndex.value;
      final route = allRoutesData[i];
      final points = route['points'] as List?;

      if (points == null || points.isEmpty) {
        print('DEBUG: Route $i has 0 points - skipping');
        continue;
      }

      // Convert points to LatLng if they aren't already
      final List<LatLng> latLngPoints = [];
      for (var point in points) {
        if (point is LatLng) {
          latLngPoints.add(point);
        } else if (point is Map) {
          // If points are stored as maps with lat/lng
          latLngPoints.add(LatLng(point['lat'], point['lng']));
        }
      }

      if (latLngPoints.isEmpty) {
        print('DEBUG: Route $i has no valid LatLng points');
        continue;
      }
      route['points'] = latLngPoints;

      print('DEBUG: Adding polyline for route $i with ${latLngPoints.length} points');

      newPolylines.add(Polyline(
        polylineId: PolylineId('route_$i'),
        points: latLngPoints,
        color: isSelected ? const Color(0xFF2196F3) : const Color(0xFF90CAF9),
        width: isSelected ? 5 : 4,
        zIndex: isSelected ? 100 : 50,
        consumeTapEvents: true,
        onTap: () => selectRoute(i),
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        patterns: isSelected ? [] : [PatternItem.dash(20), PatternItem.gap(10)], // Dotted look for alternates
      ));

      // Add floating label at 40%
      final labelPos = latLngPoints[(latLngPoints.length * 0.4).floor()];
      final labelIcon = await _createRouteLabel(
          route['durationText'] ?? '',
          _toMilesText(route['distanceText']?.toString() ?? ''),
          isSelected: isSelected
      );

      newLabels.add(Marker(
        markerId: MarkerId('label_$i'),
        position: labelPos,
        icon: labelIcon,
        anchor: const Offset(0.5, 1.0),
        onTap: () => selectRoute(i),
        zIndex: isSelected ? 101 : 51,
        visible: true, // Explicitly set visible
      ));
    }

    print('DEBUG: Updating polylines (${newPolylines.length}) and label markers (${newLabels.length})');
    polylines.assignAll(newPolylines);
    routeLabelMarkers.assignAll(newLabels);

    if (allRoutesData.isNotEmpty && selectedRouteIndex.value < allRoutesData.length) {
      final selected = allRoutesData[selectedRouteIndex.value];
      routeSummary.value = '${selected['durationText']} • ${_toMilesText(selected['distanceText']?.toString() ?? '')}';
      routeSteps.assignAll(List<Map<String, dynamic>>.from(selected['steps'] ?? []));
      routeRemainingDistanceMeters.value =
          _sumPolylineDistanceMeters(List<LatLng>.from(selected['points'] ?? <LatLng>[]));
      print('DEBUG: _updateRouteVisuals completed. Summary: ${routeSummary.value}');
    }
  }

  /// Clear route polylines and data only (keeps selected church).
  void _clearRouteOverlays() {
    polylines.clear();
    routeLabelMarkers.clear();
    allRoutesData.clear();
    routeSummary.value = null;
    routeSteps.clear();
    routeDistance.value = '';
    routeDuration.value = '';
    routeRemainingDistanceMeters.value = 0.0;
    _routeDurationSeconds = 0;
    _lastRerouteAt = null;
    _lastCameraAnimateAt = null;
    _smoothedCameraBearing = null;
    _lastCameraTarget = null;
    _userControllingCamera = false;
    isCameraFollowPaused.value = false;
  }

  /// Full route clear including selected church — used when user dismisses route.
  Future<void> clearRoute() async {
    await dismissRouteAndNavigation();
  }

  void selectRoute(int index) {
    if (index == selectedRouteIndex.value) return;
    selectedRouteIndex.value = index;
    _updateRouteVisuals();
  }

  void fitAllMarkers() {
    if (places.isEmpty) return;
    if (mapController == null) {
      _pendingFitMarkers = true;
      return;
    }
    _pendingFitMarkers = false;

    final List<LatLng> coords = [];
    for (var p in places) {
      final loc = p['geometry']?['location'];
      if (loc != null) {
        coords.add(LatLng(loc['lat'], loc['lng']));
      }
    }

    if (coords.isEmpty) return;

    // Also include user position in bounds if available
    if (currentPosition.value != null) {
      coords.add(LatLng(currentPosition.value!.latitude, currentPosition.value!.longitude));
    }

    final bounds = _getBounds(coords);
    mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
  }

  LatLngBounds _getBounds(List<LatLng> points) {
    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng));
  }

  Future<BitmapDescriptor> _createRouteLabel(String time, String dist, {required bool isSelected}) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    const double width = 140.0;
    const double height = 80.0;
    const double arrowSize = 12.0;

    final Paint paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    // Draw shadow
    canvas.drawRRect(RRect.fromLTRBR(4, 4, width - 4, height - arrowSize - 2, const Radius.circular(12)), shadowPaint);

    // Draw bubble
    canvas.drawRRect(RRect.fromLTRBR(0, 0, width, height - arrowSize, const Radius.circular(12)), paint);

    // Draw arrow
    final Path path = Path();
    path.moveTo(width / 2 - arrowSize, height - arrowSize);
    path.lineTo(width / 2, height);
    path.lineTo(width / 2 + arrowSize, height - arrowSize);
    path.close();
    canvas.drawPath(path, paint);

    // Draw Texts
    final timePainter = TextPainter(
      text: TextSpan(
        text: time,
        style: TextStyle(
          color: isSelected ? const Color(0xFF2E7D32) : Colors.black87,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final distPainter = TextPainter(
      text: TextSpan(
        text: dist,
        style: const TextStyle(
          color: Colors.black54,
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    timePainter.paint(canvas, Offset((width - timePainter.width) / 2, 8));
    distPainter.paint(canvas, Offset((width - distPainter.width) / 2, 36));

    final img = await recorder.endRecording().toImage(width.toInt(), height.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  void _processLiveNavigationPosition(Position position) {
    if (!isNavigating.value || allRoutesData.isEmpty || _isRerouting) return;
    if (selectedRouteIndex.value < 0 || selectedRouteIndex.value >= allRoutesData.length) return;

    final route = allRoutesData[selectedRouteIndex.value];
    final points = List<LatLng>.from(route['points'] ?? <LatLng>[]);
    if (points.length < 2) return;

    final current = LatLng(position.latitude, position.longitude);
    _followUserWithCamera(current, points);

    final speedMps = (position.speed.isFinite && position.speed > 0) ? position.speed : 0.0;
    final dynamicTolerance = (speedMps > 16)
        ? 50.0
        : (speedMps > 8 ? 42.0 : _offRouteToleranceMeters);
    if (!_isOnRoutePath(current, points, toleranceMeters: dynamicTolerance)) {
      final now = DateTime.now();
      final canReroute = _lastRerouteAt == null ||
          now.difference(_lastRerouteAt!).inSeconds >= _rerouteCooldownSeconds;
      if (canReroute) {
        _rerouteFromCurrentPosition();
      }
      return;
    }

    final nearestIndex = _nearestPointIndex(current, points);

    if (nearestIndex > 0 && nearestIndex < points.length - 1) {
      final trimmed = <LatLng>[current, ...points.sublist(nearestIndex + 1)];
      route['points'] = trimmed;
      allRoutesData[selectedRouteIndex.value] = route;
      _refreshSelectedPolyline(trimmed);
      routeRemainingDistanceMeters.value = _sumPolylineDistanceMeters(trimmed);
    } else {
      routeRemainingDistanceMeters.value = _sumPolylineDistanceMeters(points);
    }

    _syncLiveTurnGuidance(current, route['steps'] as List? ?? []);
    _advanceStepIfNeeded(current, route['steps'] as List? ?? []);
  }

  Future<void> _rerouteFromCurrentPosition() async {
    if (_isRerouting || !isNavigating.value || currentPosition.value == null) {
      return;
    }

    LatLng? destination = _navDestination;
    String churchName = _navDestinationName;

    if (destination == null && selectedPlace.value != null) {
      final loc = selectedPlace.value!['geometry']?['location'];
      if (loc != null) {
        destination = LatLng(loc['lat'], loc['lng']);
        churchName = selectedPlace.value!['name']?.toString() ?? churchName;
      }
    }
    if (destination == null) return;

    _isRerouting = true;
    _lastRerouteAt = DateTime.now();
    try {
      await routeToInApp(destination, churchName, isReroute: true);
      if (allRoutesData.isNotEmpty) {
        isNavigating.value = true;
        currentNavigationStep.value = 0;
        navigationProgress.value = 0.0;
        _updateNavigationStatus();
      }
    } finally {
      _isRerouting = false;
    }
  }

  void _advanceStepIfNeeded(LatLng current, List steps) {
    if (steps.isEmpty || currentNavigationStep.value >= steps.length) return;
    final currentStepData = steps[currentNavigationStep.value];
    if (currentStepData is! Map) return;

    final end = currentStepData['end_location'];
    if (end is! Map) return;
    final endLat = end['lat'];
    final endLng = end['lng'];
    if (endLat == null || endLng == null) return;

    final distanceToStepEnd = Geolocator.distanceBetween(
      current.latitude,
      current.longitude,
      endLat,
      endLng,
    );
    if (distanceToStepEnd > _stepAdvanceToleranceMeters) return;

    currentNavigationStep.value++;
    if (currentNavigationStep.value >= steps.length) {
      navigationProgress.value = 1.0;
      stopNavigation();
      _showNavigationComplete();
      return;
    }
    navigationProgress.value = (currentNavigationStep.value / steps.length).clamp(0.0, 1.0);
  }

  void _syncLiveTurnGuidance(LatLng current, List steps) {
    if (steps.isEmpty || currentNavigationStep.value >= steps.length) return;
    final currentStepData = steps[currentNavigationStep.value];
    if (currentStepData is! Map) return;

    final end = currentStepData['end_location'];
    if (end is! Map) return;
    final endLat = end['lat'];
    final endLng = end['lng'];
    if (endLat == null || endLng == null) return;

    final distanceToTurnMeters = Geolocator.distanceBetween(
      current.latitude,
      current.longitude,
      endLat,
      endLng,
    );

    final instructionRaw = currentStepData['instruction']?.toString() ?? 'Continue straight';
    final instruction = instructionRaw.replaceAll(RegExp(r'\{[^}]*\}'), '').trim();
    final maneuver = currentStepData['maneuver']?.toString();
    final bucketDistanceText = _distanceBucketText(distanceToTurnMeters);
    final bucketInstruction = _instructionForDistanceBucket(instruction, distanceToTurnMeters);

    nextTurnDistance.value = bucketDistanceText;
    navigationDistance.value = _toMilesText('${routeRemainingDistanceMeters.value.toStringAsFixed(0)} m');
    navigationInstructions.value = bucketInstruction;
    _updateNavigationDirections(bucketInstruction, bucketDistanceText, maneuver: maneuver);
    isApproachingTurn.value = distanceToTurnMeters <= 200;
    _updateNavigationETA(allRoutesData[selectedRouteIndex.value], steps);
  }

  String _distanceBucketText(double meters) {
    if (meters <= 30) return 'now';
    if (meters <= 80) return 'in 50 m';
    if (meters <= 150) return 'in 100 m';
    if (meters <= 300) return 'in 200 m';
    if (meters <= 600) return 'in 500 m';
    return 'in ${meters.round()} m';
  }

  String _instructionForDistanceBucket(String baseInstruction, double meters) {
    final clean = baseInstruction.isEmpty ? 'Continue straight' : baseInstruction;
    if (meters <= 30) return clean;
    if (meters <= 120 && (clean.toLowerCase().contains('turn') || clean.toLowerCase().contains('merge'))) {
      return 'Prepare: $clean';
    }
    return clean;
  }

  bool _isOnRoutePath(LatLng current, List<LatLng> points, {required double toleranceMeters}) {
    if (points.length < 2) return true;
    final mtkPath = points.map((p) => mtk.LatLng(p.latitude, p.longitude)).toList();
    final mtkCurrent = mtk.LatLng(current.latitude, current.longitude);
    final index = mtk.PolygonUtil.locationIndexOnPath(
      mtkCurrent,
      mtkPath,
      true,
      tolerance: toleranceMeters,
    );
    return index != -1;
  }

  void _followUserWithCamera(LatLng current, List<LatLng> points, {bool force = false}) {
    if (mapController == null || points.length < 2) return;
    if (!force && _userControllingCamera) return;
    final now = DateTime.now();
    if (!force && _lastCameraAnimateAt != null) {
      final elapsed = now.difference(_lastCameraAnimateAt!).inMilliseconds;
      if (elapsed < 700) return;
    }

    if (!force && _lastCameraTarget != null) {
      final moveMeters = Geolocator.distanceBetween(
        _lastCameraTarget!.latitude,
        _lastCameraTarget!.longitude,
        current.latitude,
        current.longitude,
      );
      if (moveMeters < 3.0) return;
    }

    final nearestIndex = _nearestPointIndex(current, points);
    final nextIndex = (nearestIndex + 1).clamp(0, points.length - 1);
    final nextPoint = points[nextIndex];
    final rawBearing = Geolocator.bearingBetween(
      current.latitude,
      current.longitude,
      nextPoint.latitude,
      nextPoint.longitude,
    );
    // Prefer GPS heading when moving, else route bearing
    final speedMps = (currentPosition.value?.speed ?? 0).clamp(0.0, 35.0);
    final speedKmh = speedMps * 3.6;
    final hasGpsHeading = currentPosition.value != null &&
        currentPosition.value!.heading >= 0 &&
        speedMps > 1.5;
    final cameraBearing = hasGpsHeading
        ? _smoothBearing(currentPosition.value!.heading)
        : _smoothBearing(rawBearing);
    final zoom = speedKmh >= 80
        ? 16.0
        : (speedKmh >= 50 ? 16.5 : 17.2);
    final tilt = speedKmh >= 80
        ? 62.0
        : (speedKmh >= 40 ? 56.0 : 48.0);
    final leadMeters = speedKmh >= 80
        ? 60.0
        : (speedKmh >= 40 ? 35.0 : 18.0);
    final leadTarget = _offsetCoordinate(current, cameraBearing, leadMeters);

    mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: leadTarget,
          zoom: zoom,
          tilt: tilt,
          bearing: cameraBearing,
        ),
      ),
    );
    _lastCameraAnimateAt = now;
    _lastCameraTarget = current;
  }

  double _smoothBearing(double newBearing) {
    if (_smoothedCameraBearing == null) {
      _smoothedCameraBearing = newBearing;
      return newBearing;
    }

    final previous = _smoothedCameraBearing!;
    var delta = newBearing - previous;
    while (delta > 180) delta -= 360;
    while (delta < -180) delta += 360;

    final alpha = 0.25;
    final smoothed = (previous + delta * alpha + 360) % 360;
    _smoothedCameraBearing = smoothed;
    return smoothed;
  }

  LatLng _offsetCoordinate(LatLng start, double bearingDegrees, double distanceMeters) {
    const earthRadius = 6378137.0;
    final bearingRad = bearingDegrees * math.pi / 180.0;
    final lat1 = start.latitude * math.pi / 180.0;
    final lon1 = start.longitude * math.pi / 180.0;
    final angularDistance = distanceMeters / earthRadius;

    final lat2 = math.asin(
      math.sin(lat1) * math.cos(angularDistance) +
          math.cos(lat1) * math.sin(angularDistance) * math.cos(bearingRad),
    );
    final lon2 = lon1 +
        math.atan2(
          math.sin(bearingRad) * math.sin(angularDistance) * math.cos(lat1),
          math.cos(angularDistance) - math.sin(lat1) * math.sin(lat2),
        );

    return LatLng(lat2 * 180.0 / math.pi, lon2 * 180.0 / math.pi);
  }

  Future<void> _softResetMapCamera() async {
    final pos = currentPosition.value;
    if (mapController == null || pos == null) return;
    try {
      await mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(pos.latitude, pos.longitude),
            zoom: 15.0,
            tilt: 0.0,
            bearing: 0.0,
          ),
        ),
      );
    } catch (_) {}
  }

  int _nearestPointIndex(LatLng current, List<LatLng> points) {
    int nearest = 0;
    double minDistance = double.infinity;
    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final d = Geolocator.distanceBetween(
        current.latitude,
        current.longitude,
        p.latitude,
        p.longitude,
      );
      if (d < minDistance) {
        minDistance = d;
        nearest = i;
      }
    }
    return nearest;
  }

  double _sumPolylineDistanceMeters(List<LatLng> points) {
    if (points.length < 2) return 0;
    double total = 0;
    for (int i = 1; i < points.length; i++) {
      total += Geolocator.distanceBetween(
        points[i - 1].latitude,
        points[i - 1].longitude,
        points[i].latitude,
        points[i].longitude,
      );
    }
    return total;
  }

  void _refreshSelectedPolyline(List<LatLng> points) {
    final idx = selectedRouteIndex.value;
    final updated = polylines.map((polyline) {
      if (polyline.polylineId.value == 'route_$idx') {
        return polyline.copyWith(
          pointsParam: points,
          zIndexParam: 100,
          colorParam: const Color(0xFF2196F3),
          widthParam: 5,
        );
      }
      return polyline;
    }).toList();
    polylines.assignAll(updated);
  }

}

class MarkerIconData {
  final BitmapDescriptor icon;
  final Offset anchor;
  MarkerIconData({required this.icon, required this.anchor});
}