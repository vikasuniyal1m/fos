import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'dart:ui' as ui;
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../config/api_config.dart';
import '../services/places_service.dart';
import 'package:url_launcher/url_launcher.dart';

class ChurchLocatorController extends GetxController {
  var isLoading = true.obs; 
  var loadingMessage = 'Finding your location...'.obs;
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
  Timer? _searchDebounce;
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

  final LatLng defaultLocation = const LatLng(30.7333, 76.7794);
  final selectedDenomination = RxnString();
  RxBool isBottomSheetExpanded = false.obs;
  RxDouble currentZoom = 14.0.obs;
  RxBool isMapReady = false.obs;
  GoogleMapController? mapController;

  @override
  void onInit() {
    super.onInit();
    _startClock();
  }

  @override
  void onReady() {
    super.onReady();
    _determinePosition();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (places.isEmpty && !isLoading.value) {
        searchChurchesAt(defaultLocation, silent: true);
      }
    });
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
    if (currentPosition.value != null) {
      mapController?.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(currentPosition.value!.latitude, currentPosition.value!.longitude),
          zoom: 15.0,
        ),
      ));
    } else {
      await _determinePosition();
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
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    locationServiceEnabled.value = serviceEnabled;

    if (!serviceEnabled) {
      _showSnackSafe('Location', 'Location services are off');
      isLoading(false);
      // Don't search at default location if location services are off
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackSafe('Location', 'Permission denied');
        isLoading(false);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showSnackSafe('Location', 'Permission denied forever');
      isLoading(false);
      return;
    }

    isLoading(true);
    loadingMessage.value = 'Determining your location...';

    // Try multiple times to get accurate location
    Position? pos;
    int attempts = 0;
    const maxAttempts = 3;
    
    while (attempts < maxAttempts && pos == null) {
      attempts++;
      try {
        print('DEBUG: Location fetch attempt $attempts/$maxAttempts');
        pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 15),
        ).timeout(const Duration(seconds: 20));
        
        if (pos != null) {
          print('DEBUG: Got location: ${pos.latitude}, ${pos.longitude}');
          
          // Check if this is a default/hardcoded location (San Francisco Bay Area)
          final isDefaultLocation = pos.latitude >= 37.6 && pos.latitude <= 37.9 &&
                                    pos.longitude >= -122.5 && pos.longitude <= -122.3;
          
          if (isDefaultLocation) {
            print('DEBUG: Got default SF location, rejecting');
            pos = null;
          }
        }
      } catch (e) {
        print('DEBUG: Location fetch attempt $attempts failed: $e');
        if (attempts < maxAttempts) {
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    }

    // If still null after retries, try getLastKnownPosition as fallback
    if (pos == null) {
      try {
        print('DEBUG: Trying getLastKnownPosition as fallback...');
        pos = await Geolocator.getLastKnownPosition();
        if (pos != null) {
          print('DEBUG: Got last known position: ${pos.latitude}, ${pos.longitude}');
          
          // Still check if it's default location
          final isDefaultLocation = pos.latitude >= 37.6 && pos.latitude <= 37.9 &&
                                    pos.longitude >= -122.5 && pos.longitude <= -122.3;
          
          if (isDefaultLocation) {
            print('DEBUG: Last known position is also default SF location, rejecting');
            pos = null;
          }
        }
      } catch (e) {
        print('DEBUG: getLastKnownPosition failed: $e');
      }
    }

    if (pos != null) {
      currentPosition.value = pos;
      await _refreshCity(LatLng(pos.latitude, pos.longitude));

      // Zoom to current location if map is ready
      if (mapController != null) {
        print('DEBUG: [ChurchLocator] Zooming to current location: ${pos.latitude}, ${pos.longitude}');
        mapController?.animateCamera(CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(pos.latitude, pos.longitude),
            zoom: 14.0,
          ),
        ));
      }

      if ((hqQuery.value == null || hqQuery.value!.isEmpty) && places.isEmpty) {
        searchChurches();
      }
    } else {
      print('DEBUG: Failed to get real location after $maxAttempts attempts');
      _showSnackSafe('Location', 'Could not determine your location');
      // Only search at default location as last resort
      if (places.isEmpty) {
        searchChurchesAt(defaultLocation, silent: true);
      }
    }
    
    isLoading(false);
  }

  void onMapCreated(GoogleMapController controller) {
    print('DEBUG: [ChurchLocator] Google Map Created successfully');
    mapController = controller;
    isMapReady.value = true;
    if (currentPosition.value != null) {
      print('DEBUG: [ChurchLocator] Animating to current position: ${currentPosition.value!.latitude}, ${currentPosition.value!.longitude}');
      mapController?.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(currentPosition.value!.latitude, currentPosition.value!.longitude),
          zoom: 13.0,
        ),
      ));
    } else {
      print('DEBUG: [ChurchLocator] No current position yet, map created at default');
    }
  }

  void searchChurches({bool forceGlobal = false}) async {
    if (currentPosition.value == null) {
      await searchChurchesAt(defaultLocation);
      return;
    }

    if (forceGlobal || places.isEmpty) {
      isLoading(true);
      loadingMessage.value = 'Searching for churches nearby...';
    }
    try {
      LatLng center = cameraTarget.value ?? (currentPosition.value != null 
          ? LatLng(currentPosition.value!.latitude, currentPosition.value!.longitude) 
          : defaultLocation);
      
      final results = await PlacesService.searchChurches(location: center, denomination: selectedDenomination.value, radius: 15000);

      for (var p in results) {
        final plat = p['geometry']?['location']?['lat'];
        final plng = p['geometry']?['location']?['lng'];
        if (plat != null && plng != null) {
          final d = Geolocator.distanceBetween(center.latitude, center.longitude, plat, plng);
          p['distance'] = (d / 1000).toStringAsFixed(1);
        } else {
          p['distance'] = '—';
        }
        p['denomination'] = _parseDenomination(p['name'] ?? '');
      }

      if (results.isEmpty) {
        final defaultResults = await PlacesService.searchChurches(location: defaultLocation, denomination: selectedDenomination.value, radius: 15000);
        places.assignAll(defaultResults);
        originalPlaces.assignAll(defaultResults);
      } else {
        places.assignAll(results);
        originalPlaces.assignAll(results);
      }

      // FAST: Load ALL markers at once - no incremental delay!
      final allMarkers = await _markersFromPlaces(places.toList());
      markers.assignAll(allMarkers);
      
    } catch (e) {
      _showSnackSafe('Error', 'Failed to find churches');
    } finally {
      isLoading(false);
    }
  }

  Future<void> _loadMarkersIncrementally(List<Map<String, dynamic>> allPlaces) async {
    if (allPlaces.isEmpty) return;

    // Show first 4 markers immediately
    final initialBatch = allPlaces.take(4).toList();
    markers.assignAll(await _markersFromPlaces(initialBatch));
    fitAllMarkers();
    print('DEBUG: [ChurchLocator] Loaded first ${initialBatch.length} markers quickly');

    // Load remaining markers in batches of 6 with delay for smoothness
    final remaining = allPlaces.skip(4).toList();
    for (int i = 0; i < remaining.length; i += 6) {
      final batch = remaining.skip(i).take(6).toList();
      await Future.delayed(const Duration(milliseconds: 200));
      final currentMarkers = await _markersFromPlaces(allPlaces.take(4 + i + batch.length).toList());
      markers.assignAll(currentMarkers);
    }

    // All markers loaded, just clear any pending timers
  }

  Future<void> searchChurchesAt(LatLng center, {bool silent = false}) async {
    if (_fetchInProgress) return;
    _fetchInProgress = true;
    if (!silent) isLoading(true);
    try {
      final results = await PlacesService.searchChurches(location: center, denomination: selectedDenomination.value, radius: 15000);
      final myPos = currentPosition.value;
      for (var p in results) {
        if (myPos != null) {
          final plat = p['geometry']?['location']?['lat'];
          final plng = p['geometry']?['location']?['lng'];
          if (plat != null && plng != null) {
            final d = Geolocator.distanceBetween(myPos.latitude, myPos.longitude, plat, plng);
            p['distance'] = (d / 1000).toStringAsFixed(1);
          } else {
            p['distance'] = '—';
          }
        } else {
          p['distance'] = '—';
        }
        p['denomination'] = _parseDenomination(p['name'] ?? '');
      }
      places.assignAll(results);
      originalPlaces.assignAll(results);

      // FAST: Load ALL markers at once
      final allMarkers = await _markersFromPlaces(results);
      markers.assignAll(allMarkers);

      if (!silent && mapController != null && results.isEmpty) {
        mapController?.animateCamera(CameraUpdate.newCameraPosition(
          CameraPosition(target: center, zoom: 13.0),
        ));
      }
    } catch (e) {
      if (!silent) _showSnackSafe('Error', 'Failed to find churches');
    } finally {
      if (!silent) isLoading(false);
      _fetchInProgress = false;
    }
  }


  Future<void> searchByTextQuery(String query) async {
    isLoading(true);
    loadingMessage.value = 'Searching for "$query"...';
    try {
      final center = currentPosition.value != null
          ? LatLng(currentPosition.value!.latitude, currentPosition.value!.longitude)
          : defaultLocation;
      
      final results = await PlacesService.searchByQuery(
        query: query,
        location: center,
      );
      
      // Add distance and denomination to each result
      for (var p in results) {
        final plat = p['geometry']?['location']?['lat'];
        final plng = p['geometry']?['location']?['lng'];
        if (plat != null && plng != null && currentPosition.value != null) {
          final d = Geolocator.distanceBetween(
            currentPosition.value!.latitude,
            currentPosition.value!.longitude,
            plat,
            plng
          );
          p['distance'] = (d / 1000).toStringAsFixed(1);
        } else {
          p['distance'] = '—';
        }
        p['denomination'] = _parseDenomination(p['name'] ?? '');
      }
      
      places.assignAll(results);
      originalPlaces.assignAll(results);
      markers.assignAll(await _markersFromPlaces(results));
      
      if (results.isNotEmpty) {
        final loc = results.first['geometry']['location'];
        mapController?.animateCamera(CameraUpdate.newCameraPosition(
          CameraPosition(target: LatLng(loc['lat'], loc['lng']), zoom: 14.0),
        ));
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
      final name = await PlacesService.reverseGeocodeCity(location: center);
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
    stopNavigation();
    searchController.dispose();
    super.onClose();
  }

  // Start Professional Navigation
  void startNavigation(LatLng destination, String churchName) async {
    // Check if we should use Google Maps app
    if (useGoogleMapsAppNavigation.value) {
      await _openGoogleMapsForNavigation(destination, churchName);
      return;
    }
    
    // Continue with in-app navigation
    if (currentPosition.value == null) {
      await _determinePosition();
      if (currentPosition.value == null) return;
    }

    isNavigating.value = true;
    currentNavigationStep.value = 0;
    navigationProgress.value = 0.0;
    
    // Start compass and gyroscope tracking
    _startCompassTracking();
    _startGyroscopeTracking();
    
    // DO NOT CALL routeToInApp() AGAIN! It's already been called!
    // The route is already loaded in allRoutesData
    
    // Start navigation timer for real-time updates
    _startNavigationTimer();
    
    // Create and show navigation arrow marker immediately
    await _updateNavigationMarker();
    
    // Listen to real-time position changes
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
      ),
    ).listen((Position position) {
      currentPosition.value = position;
      _updateNavigationMarker();
    });
    
    // Center map on route (if not already centered)
    if (allRoutesData.isNotEmpty) {
      final route = allRoutesData[selectedRouteIndex.value];
      final points = List<LatLng>.from(route['points'] ?? []);
      if (points.isNotEmpty) {
        final bounds = _getBounds(points);
        await mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
      }
    }
  }
  
  // Open Google Maps App for Navigation
  Future<void> _openGoogleMapsForNavigation(LatLng destination, String churchName) async {
    // Google Maps DIRECT Navigation URL - no random businesses!
    final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${destination.latitude},${destination.longitude}&travelmode=driving');
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      // Fallback to search
      final encodedName = Uri.encodeComponent(churchName);
      final searchUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encodedName');
      if (await canLaunchUrl(searchUrl)) {
        await launchUrl(searchUrl, mode: LaunchMode.externalApplication);
      } else {
        Get.snackbar(
          'Error',
          'Google Maps not available',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    }
  }

  // Stop Navigation
  void stopNavigation() async {
    isNavigating.value = false;
    navigationMarker.value = null;
    _navigationTimer?.cancel();
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _stopCompassTracking();
    _stopGyroscopeTracking();
    clearRoute(); // Reset everything
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
        userHeading.value = heading;
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

  // Fallback Compass (without sensors)
  void _startFallbackCompass() {
    isCompassActive.value = true;
    
    // Simulate compass movement with timer
    _compassTimer?.cancel();
    _compassTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (isNavigating.value) {
        // Simulate gradual rotation
        userHeading.value = (userHeading.value + 5) % 360;
        _updateNavigationBasedOnHeading();
        // Update navigation arrow marker with new heading
        _updateNavigationMarker();
      }
    });
    
    debugPrint('🧭 Fallback compass started (simulated)');
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

  // Start Gyroscope Tracking
  void _startGyroscopeTracking() {
    _stopGyroscopeTracking();
    
    try {
      _gyroscopeSubscription = gyroscopeEvents.listen((GyroscopeEvent event) {
        gyroscopeX.value = event.x;
        gyroscopeY.value = event.y;
        gyroscopeZ.value = event.z;
        
        // Use gyroscope for smooth rotation detection
        _detectRotationFromGyroscope();
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
  void _detectRotationFromGyroscope() {
    if (!isNavigating.value) return;
    
    // Detect significant rotation
    final rotationThreshold = 0.5;
    if (gyroscopeZ.value.abs() > rotationThreshold) {
      // User is rotating, update navigation accordingly
      _handleUserRotation();
    }
  }

  // Handle User Rotation
  void _handleUserRotation() {
    // Update navigation UI based on user rotation
    // This ensures the navigation arrows and compass rotate with user
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

  // Update Navigation Status
  void _updateNavigationStatus() {
    if (!isNavigating.value || allRoutesData.isEmpty) return;
    
    final route = allRoutesData[selectedRouteIndex.value];
    final steps = route['steps'] as List? ?? [];
    
    // Generate mock navigation data if no steps available
    if (steps.isEmpty) {
      _generateMockNavigationData();
      return;
    }
    
    if (currentNavigationStep.value < steps.length) {
      final currentStep = steps[currentNavigationStep.value];
      
      debugPrint('🧭 Navigation Step ${currentNavigationStep.value + 1}/${steps.length}');
      debugPrint('🧭 Current step data: $currentStep');
      
      // Fix text display - extract clean values
      String instruction = 'Continue straight';
      String distance = '200 m';
      String duration = '2 min';
      
      // Extract instruction text properly
      if (currentStep['instruction'] != null) {
        instruction = currentStep['instruction'].toString();
        instruction = instruction.replaceAll(RegExp(r'\{[^}]*\}'), '').trim();
        if (instruction.isEmpty) instruction = 'Continue straight';
      }
      
      // Extract distance properly with fallback - handle both String and Map formats
      if (currentStep['distance'] != null) {
        final dist = currentStep['distance'];
        if (dist is Map && dist.containsKey('text')) {
          distance = dist['text'].toString();
        } else if (currentStep['distanceText'] != null) {
          distance = currentStep['distanceText'].toString();
        } else {
          distance = dist.toString();
        }
        distance = distance.replaceAll(RegExp(r'\{[^}]*\}'), '').trim();
        if (distance.isEmpty) distance = '200 m';
      } else {
        // Generate realistic distance based on step
        distance = _generateRealisticDistance(currentNavigationStep.value, steps.length);
      }
      
      // Extract duration properly with fallback - handle both String and Map formats
      if (currentStep['duration'] != null) {
        final dur = currentStep['duration'];
        if (dur is Map && dur.containsKey('text')) {
          duration = dur['text'].toString();
        } else if (currentStep['durationText'] != null) {
          duration = currentStep['durationText'].toString();
        } else {
          duration = dur.toString();
        }
        duration = duration.replaceAll(RegExp(r'\{[^}]*\}'), '').trim();
        if (duration.isEmpty) duration = '2 min';
      } else {
        // Generate realistic duration based on step
        duration = _generateRealisticDuration(currentNavigationStep.value, steps.length);
      }
      
      navigationInstructions.value = instruction;
      navigationDistance.value = distance;
      navigationDuration.value = duration;
      
      // Update direction arrows and compass
      _updateNavigationDirections(instruction, distance);
      
      // Calculate ETA
      final now = DateTime.now();
      final eta = now.add(Duration(minutes: (steps.length - currentNavigationStep.value) * 2));
      navigationETA.value = '${eta.hour.toString().padLeft(2, '0')}:${eta.minute.toString().padLeft(2, '0')}';
      
      // Simulate progress (in real app, this would be based on GPS)
      navigationProgress.value = (currentNavigationStep.value + 1) / steps.length;
      
      // Auto-advance step (in real app, this would be based on location)
      if (navigationProgress.value >= 0.9) {
        currentNavigationStep.value++;
        if (currentNavigationStep.value >= steps.length) {
          stopNavigation();
          _showNavigationComplete();
        }
      }
    }
  }

  // Generate mock navigation data for testing
  void _generateMockNavigationData() {
    final mockInstructions = [
      'Head north on Main Street',
      'Turn right onto Church Road',
      'Continue straight for 200m',
      'Turn left onto Grace Avenue',
      'Destination will be on your right'
    ];
    
    final stepIndex = currentNavigationStep.value % mockInstructions.length;
    navigationInstructions.value = mockInstructions[stepIndex];
    navigationDistance.value = _generateRealisticDistance(stepIndex, mockInstructions.length);
    navigationDuration.value = _generateRealisticDuration(stepIndex, mockInstructions.length);
    
    // Calculate ETA
    final now = DateTime.now();
    final eta = now.add(Duration(minutes: (mockInstructions.length - stepIndex) * 2));
    navigationETA.value = '${eta.hour.toString().padLeft(2, '0')}:${eta.minute.toString().padLeft(2, '0')}';
    
    navigationProgress.value = (stepIndex + 1) / mockInstructions.length;
    
    // Auto-advance
    if (navigationProgress.value >= 0.9) {
      currentNavigationStep.value++;
      if (currentNavigationStep.value >= mockInstructions.length) {
        stopNavigation();
        _showNavigationComplete();
      }
    }
  }

  // Generate realistic distance
  String _generateRealisticDistance(int stepIndex, int totalSteps) {
    final distances = ['150 m', '200 m', '350 m', '100 m', '50 m'];
    return distances[stepIndex % distances.length];
  }

  // Generate realistic duration
  String _generateRealisticDuration(int stepIndex, int totalSteps) {
    final durations = ['1 min', '2 min', '3 min', '1 min', '1 min'];
    return durations[stepIndex % durations.length];
  }

  // Update navigation directions and compass
  void _updateNavigationDirections(String instruction, String distance) {
    // Determine turn direction from instruction
    String turnDirection = 'straight';
    double direction = 0.0;
    
    if (instruction.toLowerCase().contains('turn left')) {
      turnDirection = 'left';
      direction = 270.0; // West
      isApproachingTurn.value = true;
    } else if (instruction.toLowerCase().contains('turn right')) {
      turnDirection = 'right';
      direction = 90.0; // East
      isApproachingTurn.value = true;
    } else if (instruction.toLowerCase().contains('head north')) {
      turnDirection = 'straight';
      direction = 0.0; // North
      isApproachingTurn.value = false;
    } else if (instruction.toLowerCase().contains('head south')) {
      turnDirection = 'straight';
      direction = 180.0; // South
      isApproachingTurn.value = false;
    } else if (instruction.toLowerCase().contains('head east')) {
      turnDirection = 'straight';
      direction = 90.0; // East
      isApproachingTurn.value = false;
    } else if (instruction.toLowerCase().contains('head west')) {
      turnDirection = 'straight';
      direction = 270.0; // West
      isApproachingTurn.value = false;
    } else {
      // Default to straight for "continue" instructions
      turnDirection = 'straight';
      direction = (currentDirection.value + 45) % 360; // Slight variation
      isApproachingTurn.value = false;
    }
    
    nextTurnDirection.value = turnDirection;
    nextTurnDistance.value = distance;
    currentDirection.value = direction;
  }

  // Get direction arrow icon based on turn direction
  IconData getDirectionArrowIcon() {
    switch (nextTurnDirection.value) {
      case 'left':
        return Icons.turn_left;
      case 'right':
        return Icons.turn_right;
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
    
    debugPrint('🔄 Recalculating route...');
    // Implementation would get current position and recalculate route
    // For now, just update the timer
    _updateNavigationStatus();
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

  // Reset Navigation State
  void _resetNavigationState() {
    // Clear all navigation data
    clearRoute();
    
    // Reset navigation variables
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
    
    // Reset sensor data
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
    routeDistance.value = distance;
    routeDuration.value = duration;
    navigationDistance.value = distance;  // Update navigation card too
    navigationDuration.value = duration; // Update navigation card too
  }

  // Update selected church for navigation
  void _updateSelectedChurchForNavigation(LatLng destination, String churchName) {
    // Save selected church to selectedPlace
    selectedPlace.value = {
      'name': churchName,
      'place_id': 'selected_church',
      'geometry': {'location': {'lat': destination.latitude, 'lng': destination.longitude}},
      'vicinity': 'Selected for navigation'
    };
    
    // Clear places and add only selected church
    places.clear();
    places.add(selectedPlace.value!);
    
    // Update markers to show only selected church
    _updateMarkersForSelectedChurch();
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
      final loc = p['geometry']['location'];
      final rawName = p['name'] ?? '';
      final placeId = p['place_id'];
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

      list.add(Marker(
        markerId: MarkerId(placeId),
        position: LatLng(loc['lat'], loc['lng']),
        icon: markerIcon,
        anchor: markerAnchor,
        infoWindow: InfoWindow(title: rawName, snippet: p['vicinity'] ?? ''),
        onTap: () {
          // Set selectedPlace FIRST!
          selectedPlace.value = p;
          clearRoute();
          _showNavigationOptions(LatLng(loc['lat'], loc['lng']), rawName);
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
      final arrowIcon = await _createNavigationArrow();
      final pos = LatLng(currentPosition.value!.latitude, currentPosition.value!.longitude);
      
      navigationMarker.value = Marker(
        markerId: const MarkerId('navigation_arrow'),
        position: pos,
        icon: arrowIcon,
        rotation: userHeading.value,
        anchor: const Offset(0.5, 0.5),
        zIndex: 1000,
        flat: true,
      );
    } catch (e) {}
  }

  void updateDenomination(String? d) {
    selectedDenomination.value = (d == 'All') ? null : d;
    // Clear old data so map is definitely empty behind the white screen
    places.clear();
    markers.clear();
    searchChurches(forceGlobal: true);
  }

  void focusPlace(Map<String, dynamic> place) {
    selectedPlace.value = place; // Set selectedPlace!
    final loc = place['geometry']?['location'];
    if (loc == null) return;
    final latlng = LatLng(loc['lat'], loc['lng']);
    cameraTarget.value = latlng;
    mapController?.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(target: latlng, zoom: 15.0),
    ));
  }

  String _parseDenomination(String name) {
    name = name.toLowerCase();
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
    _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
      if (v.trim().isEmpty) {
        suggestions.clear();
        return;
      }
      final bias = currentPosition.value != null ? LatLng(currentPosition.value!.latitude, currentPosition.value!.longitude) : null;
      suggestions.assignAll(await PlacesService.autocomplete(input: v.trim(), locationBias: bias));
    });
  }

  Future<void> selectPrediction(Map<String, dynamic> pred) async {
    final placeId = pred['place_id'];
    if (placeId == null) return;
    isLoading(true);
    try {
      final details = await PlacesService.placeDetails(placeId: placeId);
      if (details != null) {
        final loc = details['geometry']['location'];
        final center = LatLng(loc['lat'], loc['lng']);
        suggestions.clear();
        hqQuery.value = details['name'] ?? '';
        
        // Add the selected church to the places list first
        final selectedChurch = {
          'place_id': placeId,
          'name': details['name'] ?? '',
          'vicinity': details['formatted_address'] ?? details['vicinity'] ?? '',
          'formatted_address': details['formatted_address'] ?? '',
          'geometry': details['geometry'],
          'distance': '0.0',
          'denomination': _parseDenomination(details['name'] ?? ''),
        };
        
        // Set selectedPlace FIRST!
        selectedPlace.value = selectedChurch;
        
        // Clear existing places and add the selected church
        places.clear();
        places.add(selectedChurch);
        markers.assignAll(await _markersFromPlaces([selectedChurch]));
        
        // Immediately navigate to the selected church
        mapController?.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: center, zoom: 15.0)));
        
        // Show route immediately if user has location
        if (currentPosition.value != null) {
          await routeToInApp(center, details['name'] ?? '');
        }
        
        // Then search for nearby churches in background
        await searchChurchesAt(center, silent: true);
        
        // Ensure the selected church is still at the top
        if (places.isNotEmpty && places.first['place_id'] != placeId) {
          places.removeWhere((p) => p['place_id'] == placeId);
          places.insert(0, selectedChurch);
          markers.assignAll(await _markersFromPlaces(places));
        }
      }
    } finally {
      isLoading(false);
    }
  }

  // Update the routeToInApp method with better error handling and debugging
  Future<void> routeToInApp(LatLng dest, String name) async {
    try {
      // Set selectedPlace FIRST!
      selectedPlace.value = {
        'name': name,
        'place_id': 'selected_church',
        'geometry': {'location': {'lat': dest.latitude, 'lng': dest.longitude}},
        'vicinity': 'Selected for navigation'
      };
      
      // Clear route BEFORE doing anything else!
      clearRoute();
      _resetNavigationState();
      
      isLoading(true);
      loadingMessage.value = 'Finding best routes to $name...';

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
        mapController?.animateCamera(CameraUpdate.newCameraPosition(
          CameraPosition(target: dest, zoom: 15.0),
        ));
        return;
      }

      clearRoute();

      final results = await PlacesService.directions(
          origin: finalOrigin,
          destination: dest,
          mode: 'driving'
      );

      if (results == null || results.isEmpty) {
        _showSnackSafe('Route', 'No routes found to $name');
        isLoading(false);
        mapController?.animateCamera(CameraUpdate.newCameraPosition(
          CameraPosition(target: dest, zoom: 15.0),
        ));
        return;
      }

      allRoutesData.assignAll(results);
      selectedRouteIndex.value = 0;
      await _updateRouteVisuals();
      
      // Parse route data for distance and duration
      if (allRoutesData.isNotEmpty) {
        _parseRouteData(allRoutesData[selectedRouteIndex.value]);
      }

      markers.refresh();

      if (results.isNotEmpty && results.first['points'].isNotEmpty) {
        final bounds = _getBounds(List<LatLng>.from(results.first['points']));
        await mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
      } else {
        mapController?.animateCamera(CameraUpdate.newCameraPosition(
          CameraPosition(target: dest, zoom: 15.0),
        ));
      }
    } catch (e) {
      _showSnackSafe('Route', 'Could not get directions');
      mapController?.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(target: dest, zoom: 15.0),
      ));
    } finally {
      isLoading(false);
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
          route['distanceText'] ?? '',
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
      routeSummary.value = '${selected['durationText']} • ${selected['distanceText']}';
      routeSteps.assignAll(List<Map<String, dynamic>>.from(selected['steps'] ?? []));
      print('DEBUG: _updateRouteVisuals completed. Summary: ${routeSummary.value}');
    }
  }

// Add clearRoute method if not present
  void clearRoute() async {
    selectedPlace.value = null; // Clear selected church
    polylines.clear();
    routeLabelMarkers.clear();
    allRoutesData.clear();
    routeSummary.value = null;
    routeSteps.clear();
    routeDistance.value = '';
    routeDuration.value = '';
    navigationInstructions.value = '';
    navigationDistance.value = '';
    navigationDuration.value = '';
    navigationETA.value = '';
    currentNavigationStep.value = 0;
    navigationProgress.value = 0.0;
    isNavigating.value = false;
    nextTurnDirection.value = '';
    nextTurnDistance.value = '';
    isApproachingTurn.value = false;
    currentDirection.value = 0.0;
    
    // RESTORE ALL ORIGINAL CHURCHES AND MARKERS
    if (originalPlaces.isNotEmpty) {
      places.assignAll(originalPlaces);
      final allMarkers = await _markersFromPlaces(originalPlaces);
      markers.assignAll(allMarkers);
      debugPrint('📍 Restored ${originalPlaces.length} churches to map');
    }
  }

  void selectRoute(int index) {
    if (index == selectedRouteIndex.value) return;
    selectedRouteIndex.value = index;
    _updateRouteVisuals();
  }

  void fitAllMarkers() {
    if (places.isEmpty || mapController == null) return;
    
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

}

class MarkerIconData {
  final BitmapDescriptor icon;
  final Offset anchor;
  MarkerIconData({required this.icon, required this.anchor});
}