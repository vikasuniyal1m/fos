import 'dart:io';

import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fruitsofspirit/controllers/church_locator_controller.dart';
import 'package:fruitsofspirit/config/api_config.dart';
import 'package:fruitsofspirit/widgets/cached_image.dart';
import 'package:url_launcher/url_launcher.dart';

class ChurchLocatorScreen extends StatefulWidget {
  const ChurchLocatorScreen({Key? key}) : super(key: key);

  @override
  State<ChurchLocatorScreen> createState() => _ChurchLocatorScreenState();
}

class _ChurchLocatorScreenState extends State<ChurchLocatorScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = Get.arguments as Map<String, dynamic>?;
      final controller = Get.find<ChurchLocatorController>();
      final initialDenomination = args?['denomination']?.toString().trim();
      final hqQuery = args?['hqQuery']?.toString().trim();

      if (hqQuery != null && hqQuery.isNotEmpty) {
        controller.hqQuery.value = hqQuery;
      }

      if (initialDenomination != null &&
          initialDenomination.isNotEmpty &&
          controller.selectedDenomination.value != initialDenomination) {
        controller.applyDenominationFilter(initialDenomination);
      }

      controller.ensureMapDataLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ChurchLocatorController>();

    return WillPopScope(
      onWillPop: () async {
        if (controller.isBottomSheetExpanded.value) {
          controller.toggleBottomSheet();
          return false;
        }
        return true;
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Stack(
            children: [
              // Map Background
              ApiConfig.isDummyMode
                  ? _buildDummyMap()
                  : _buildGoogleMap(controller),
              // Gradient overlay
              _buildGradientOverlay(),
              // Custom App Bar
              _buildCustomAppBar(controller),
              // Search Section
              _buildSearchSection(controller),
              // Location Permission Prompt
              _buildLocationPermissionPrompt(controller),
              // Bottom Sheet
              _buildBottomSheet(controller),
              // My Location Button
              _buildMyLocationButton(controller),
              // Selected Church map preview card (image + details)
              _buildSelectedChurchPreviewCard(controller),
              // Route Directions Card
              _buildRouteDirectionsCard(controller),
              // Professional Navigation UI
              _buildNavigationUI(controller),
              // Start Navigation Dialog
              _buildStartNavigationDialog(controller),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchThisAreaButton(ChurchLocatorController controller) {
    return const SizedBox.shrink();
  }

  Widget _buildSelectedChurchPreviewCard(ChurchLocatorController controller) {
    return Obx(() {
      if (controller.selectedPlace.value == null ||
          controller.isNavigating.value ||
          controller.allRoutesData.isNotEmpty) {
        return const SizedBox.shrink();
      }

      final place = controller.selectedPlace.value!;
      final imageUrl = place['church_image_url']?.toString();
      final name = place['name']?.toString() ?? 'Church';
      final address = (place['vicinity'] ?? place['formatted_address'] ?? '').toString();
      final bottomOffset = controller.isBottomSheetExpanded.value ? 420.h : 150.h;

      return Positioned(
        left: 12.w,
        right: 12.w,
        bottom: bottomOffset,
        child: Container(
          padding: EdgeInsets.all(10.r),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8.r),
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? CachedImage(
                        imageUrl: imageUrl,
                        width: 58.w,
                        height: 58.h,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 58.w,
                        height: 58.h,
                        color: const Color(0xFF8B4513).withOpacity(0.08),
                        child: Icon(
                          Icons.church_outlined,
                          size: 24.r,
                          color: const Color(0xFF8B4513),
                        ),
                      ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.poppins(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2C3E50),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      address.isEmpty ? 'Location details available on map' : address,
                      style: GoogleFonts.poppins(
                        fontSize: 11.sp,
                        color: Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  // Professional Navigation UI
  // Format navigation text to remove object-like formatting
  String _formatNavigationText(String text, String fallback) {
    if (text.isEmpty) return fallback;
    
    // Remove any object-like formatting {text: xxx, value: xxx}
    String cleaned = text.replaceAll(RegExp(r'\{[^}]*\}'), '').trim();
    
    // If still empty or contains problematic characters, use fallback
    if (cleaned.isEmpty || cleaned.contains('{') || cleaned.contains('}')) {
      return fallback;
    }
    
    return cleaned;
  }

  String _distanceToMilesText(String text, String fallback) {
    final raw = text.trim().isEmpty ? fallback : text.trim();
    final cleaned = raw.replaceAll(RegExp(r'\{[^}]*\}'), '').replaceAll(',', '').trim();

    final milesMatch = RegExp(r'^(\d+(?:\.\d+)?)\s*(mi|mile|miles)\b', caseSensitive: false).firstMatch(cleaned);
    if (milesMatch != null) {
      final value = double.tryParse(milesMatch.group(1) ?? '');
      if (value != null) return '${value.toStringAsFixed(1)} mi';
      return cleaned;
    }

    final kmMatch = RegExp(r'^(\d+(?:\.\d+)?)\s*km\b', caseSensitive: false).firstMatch(cleaned);
    if (kmMatch != null) {
      final km = double.tryParse(kmMatch.group(1) ?? '');
      if (km != null) return '${(km * 0.621371).toStringAsFixed(1)} mi';
      return cleaned;
    }

    final meterMatch = RegExp(r'^(\d+(?:\.\d+)?)\s*m\b', caseSensitive: false).firstMatch(cleaned);
    if (meterMatch != null) {
      final meters = double.tryParse(meterMatch.group(1) ?? '');
      if (meters != null) return '${(meters / 1609.344).toStringAsFixed(1)} mi';
      return cleaned;
    }

    return cleaned;
  }

  // Build Start Navigation Dialog
  Widget _buildStartNavigationDialog(ChurchLocatorController controller) {
    return Obx(() {
      if (controller.isNavigating.value ||
          controller.allRoutesData.isEmpty ||
          controller.routeDistance.value.isEmpty ||
          controller.routeDuration.value.isEmpty) {
        return const SizedBox.shrink();
      }

      final place = controller.selectedPlace.value;
      final loc = place?['geometry']?['location'];
      if (loc == null) return const SizedBox.shrink();

      final destination = LatLng(loc['lat'], loc['lng']);
      String currentChurchName = place?['name']?.toString() ?? 'Church';
      final distance = controller.routeDistance.value;
      final duration = controller.routeDuration.value;

      return Positioned(
        bottom: 100.h,
        left: 16.w,
        right: 16.w,
        child: Container(
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      currentChurchName,
                      style: GoogleFonts.poppins(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF2C3E50),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: controller.dismissRouteAndNavigation,
                    icon: Icon(Icons.close, size: 20.r, color: Colors.grey[600]),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              Container(
                padding: EdgeInsets.all(12.r),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Icon(Icons.directions, color: Colors.blue, size: 20.r),
                        SizedBox(height: 4.h),
                        Text(
                          distance,
                          style: GoogleFonts.poppins(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Icon(Icons.access_time, color: Colors.blue, size: 20.r),
                        SizedBox(height: 4.h),
                        Text(
                          duration,
                          style: GoogleFonts.poppins(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _showChurchDetailsSheet(
                        controller,
                        fallbackChurchName: currentChurchName,
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF2196F3)),
                        foregroundColor: const Color(0xFF2196F3),
                        padding: EdgeInsets.symmetric(vertical: 12.r),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.info_outline, size: 18.r),
                          SizedBox(width: 6.w),
                          Text(
                            'View Details',
                            style: GoogleFonts.poppins(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => controller.startNavigation(destination, currentChurchName),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2196F3),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12.r),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        elevation: 4,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.navigation, size: 18.r),
                          SizedBox(width: 6.w),
                          Text(
                            'Start Nav',
                            style: GoogleFonts.poppins(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildNavigationUI(ChurchLocatorController controller) {
    return Obx(() {
      if (!controller.isNavigating.value) return const SizedBox.shrink();
      
      return Positioned(
        top: MediaQuery.of(Get.context!).padding.top + 60.h,
        left: 16.w,
        right: 16.w,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (controller.isRerouting.value)
              Container(
                margin: EdgeInsets.only(bottom: 8.h),
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 14.r,
                      height: 14.r,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'Recalculating route...',
                      style: GoogleFonts.poppins(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            Container(
          height: 70.h,
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Compact Direction Arrow
              Obx(() => Container(
                width: 40.r,
                height: 40.r,
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Transform.rotate(
                  angle: controller.userHeading.value * (3.14159 / 180),
                  child: Icon(
                    controller.getDirectionArrowIcon(),
                    color: Colors.white,
                    size: 20.r,
                  ),
                ),
              )),
              
              SizedBox(width: 12.w),
              
              // Compact Instruction
              Expanded(
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatNavigationText(controller.navigationInstructions.value, 'Continue straight'),
                        style: GoogleFonts.poppins(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        'In ${controller.nextTurnDistance.value} • ${controller.navigationDuration.value}',
                        style: GoogleFonts.poppins(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w400,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Compact Info
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Distance
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Text(
                      _distanceToMilesText(controller.navigationDistance.value, '0.0 mi'),
                      style: GoogleFonts.poppins(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                  
                  SizedBox(width: 6.w),
                  
                  // ETA
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Text(
                      controller.navigationETA.value.isNotEmpty 
                          ? controller.navigationETA.value
                          : 'Now',
                      style: GoogleFonts.poppins(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                  
                  SizedBox(width: 6.w),
                  
                  // Close Button
                  GestureDetector(
                    onTap: () => controller.dismissRouteAndNavigation(),
                    child: Container(
                      width: 32.r,
                      height: 32.r,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      child: Icon(
                        Icons.close,
                        color: Colors.grey[600],
                        size: 16.r,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
          ],
        ),
      );
    });
  }

  Widget _buildGradientOverlay() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 120.h,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.4),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomAppBar(ChurchLocatorController controller) {
    return Positioned(
      top: MediaQuery.of(Get.context!).padding.top,
      left: 16.w,
      right: 16.w,
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.of(Get.context!).pop(),
              borderRadius: BorderRadius.circular(20.r),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20.r),
                  color: Colors.black.withOpacity(0.6),
                ),
                child: Row(
                  children: [
                    Icon(Icons.arrow_back_ios_new_rounded, size: 16.r, color: Colors.white),
                    SizedBox(width: 4.w),
                    Text(
                      'Back',
                      style: GoogleFonts.poppins(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Spacer(),
          // Church Locator Title
          ClipRRect(
            borderRadius: BorderRadius.circular(20.r),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                color: Colors.black.withOpacity(0.6),
                child: Row(
                  children: [
                    Icon(Icons.church_outlined, size: 16.r, color: Colors.white),
                    SizedBox(width: 6.w),
                    Text(
                      'Church Locator',
                      style: GoogleFonts.poppins(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSection(ChurchLocatorController controller) {
    return Positioned(
      top: MediaQuery.of(Get.context!).padding.top + 40.h,
      left: 14.w,
      right: 14.w,
      child: Column(
        children: [
          // Main Search Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: controller.searchController,
              decoration: InputDecoration(
                hintText: 'Search churches, denominations...',
                hintStyle: GoogleFonts.poppins(
                  fontSize: 13.sp,
                  color: Colors.grey[400],
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 20.r,
                  color: const Color(0xFF8B4513),
                ),
                suffixIcon: Obx(() {
                  final showClear = controller.searchActive.value ||
                      (controller.hqQuery.value != null &&
                          controller.hqQuery.value!.isNotEmpty) ||
                      controller.selectedPlace.value != null ||
                      controller.allRoutesData.isNotEmpty ||
                      controller.suggestions.isNotEmpty;
                  if (!showClear) return const SizedBox.shrink();
                  return IconButton(
                    icon: Icon(Icons.close_rounded, size: 20.r, color: Colors.grey[600]),
                    onPressed: controller.resetSearchAndSelection,
                  );
                }),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20.r),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 8.h),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (value) {
                final query = value.trim();
                if (query.isNotEmpty) {
                  controller.hqQuery.value = query;
                  controller.searchByTextQuery(query);
                }
              },
              onChanged: controller.onSearchInputChanged,
            ),
          ),

          // External maps — in-app me suggestion na aaye
          Obx(() {
            if (!controller.showExternalMapsOffer.value) return const SizedBox.shrink();
            if (controller.suggestions.isNotEmpty) return const SizedBox.shrink();
            final q = controller.externalSearchQuery.value;
            if (q.isEmpty) return const SizedBox.shrink();
            return _buildExternalMapsOffer(controller, q);
          }),

          // Suggestions Dropdown
          Obx(() {
            if (controller.suggestions.isEmpty) return const SizedBox.shrink();
            return Container(
              margin: EdgeInsets.only(top: 8.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              constraints: BoxConstraints(maxHeight: 200.h),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16.r),
                child: ListView.builder(
                  padding: EdgeInsets.symmetric(vertical: 4.h),
                  shrinkWrap: true,
                  itemCount: controller.suggestions.length,
                  itemBuilder: (context, i) {
                    final suggestion = controller.suggestions[i];
                    final name = suggestion['name']?.toString() ??
                        suggestion['structured_formatting']?['main_text']?.toString() ??
                        suggestion['description']?.toString() ??
                        '';
                    final address = (suggestion['vicinity'] ??
                            suggestion['formatted_address'] ??
                            suggestion['structured_formatting']?['secondary_text'] ??
                            '')
                        .toString();
                    final distM = suggestion['_distance_meters'];
                    final distLabel = distM is num
                        ? '${(distM / 1609.344).toStringAsFixed(1)} mi'
                        : null;
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.location_on_outlined,
                        size: 16.r,
                        color: const Color(0xFF8B4513),
                      ),
                      title: Text(
                        name,
                        style: GoogleFonts.poppins(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: (address.isNotEmpty || distLabel != null)
                          ? Text(
                              [if (distLabel != null) distLabel, if (address.isNotEmpty) address]
                                  .join(' • '),
                              style: GoogleFonts.poppins(fontSize: 10.sp, color: Colors.grey[600]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          : null,
                      onTap: () => controller.selectPrediction(suggestion),
                    );
                  },
                ),
              ),
            );
          }),
        ],
      ),
    );
  }


  Widget _buildExternalMapsOffer(
    ChurchLocatorController controller,
    String query, {
    bool compact = false,
  }) {
    if (compact) {
      return Material(
        color: const Color(0xFFF5F8FF),
        borderRadius: BorderRadius.circular(12.r),
        child: InkWell(
          borderRadius: BorderRadius.circular(12.r),
          onTap: () => controller.openExternalMapsSearchDialog(query),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: const Color(0xFF2196F3).withOpacity(0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.map_outlined, size: 18.r, color: const Color(0xFF1565C0)),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'Search "$query" in Maps',
                    style: GoogleFonts.poppins(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1565C0),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.chevron_right, size: 18.r, color: Colors.grey[500]),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      margin: EdgeInsets.only(top: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8FF),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFF2196F3).withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Not in app? Search in Maps',
            style: GoogleFonts.poppins(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1565C0),
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            '"$query"',
            style: GoogleFonts.poppins(fontSize: 11.sp, color: Colors.grey[700]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => controller.openGoogleMapsSearchExternal(query),
                  icon: Icon(Icons.map_outlined, size: 16.r),
                  label: Text(
                    'Google Maps',
                    style: GoogleFonts.poppins(fontSize: 11.sp, fontWeight: FontWeight.w500),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2196F3),
                    side: const BorderSide(color: Color(0xFF2196F3)),
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                  ),
                ),
              ),
              if (Platform.isIOS) ...[
                SizedBox(width: 8.w),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => controller.openAppleMapsSearchExternal(query),
                    icon: Icon(Icons.apple, size: 16.r),
                    label: Text(
                      'Apple Maps',
                      style: GoogleFonts.poppins(fontSize: 11.sp, fontWeight: FontWeight.w500),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black87,
                      side: BorderSide(color: Colors.grey.shade400),
                      padding: EdgeInsets.symmetric(vertical: 8.h),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSheet(ChurchLocatorController controller) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Obx(() {
        final media = MediaQuery.of(Get.context!);
        final collapsedHeight = (media.size.height * 0.16).clamp(104.0, 168.0);
        final expandedHeight = media.size.height * 0.75;
        final isExpanded = controller.isBottomSheetExpanded.value;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          height: isExpanded ? expandedHeight : collapsedHeight,
          child: GestureDetector(
            onTap: () {
              if (!controller.isBottomSheetExpanded.value) {
                controller.toggleBottomSheet();
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: ClipRect(
                child: Column(
                  children: [
                  // Drag Handle - Fixed to toggle properly
                  GestureDetector(
                    onTap: controller.toggleBottomSheet,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: isExpanded ? 6.h : 4.h),
                      width: double.infinity,
                      child: Center(
                        child: Container(
                          width: 30.w,
                          height: 3.h,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(1.5.r),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Header (always visible)
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: isExpanded ? 12.h : 6.h,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.church_rounded,
                          size: 16.r,
                          color: const Color(0xFF8B4513),
                        ),
                        SizedBox(width: 8.w),
                        Obx(() {
                          String headerText = 'Churches Near You';
                          if (controller.selectedPlace.value != null &&
                              controller.allRoutesData.isNotEmpty) {
                            final name = controller.selectedPlace.value!['name']?.toString();
                            if (name != null && name.isNotEmpty) {
                              headerText = name;
                            }
                          }
                          return Expanded(
                            child: Text(
                              headerText,
                              style: GoogleFonts.poppins(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF2C3E50),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }),
                        GestureDetector(
                          onTap: controller.toggleBottomSheet,
                          child: Obx(() => Icon(
                            controller.isBottomSheetExpanded.value
                                ? Icons.keyboard_arrow_down_rounded
                                : Icons.keyboard_arrow_up_rounded,
                            size: 18.r,
                            color: Colors.grey[400],
                          )),
                        ),
                        SizedBox(width: 12.w),
                        _buildFilterIcon(controller),
                      ],
                    ),
                  ),

                  // Content (visible only when expanded)
                  if (isExpanded) ...[
                    // Denomination Quick Filters
                    Padding(
                      padding: EdgeInsets.only(left: 16.w, right: 16.w, bottom: 12.h),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip('All', controller),
                            _buildFilterChip('Catholic', controller),
                            _buildFilterChip('Baptist', controller),
                            _buildFilterChip('Pentecostal', controller),
                            _buildFilterChip('Anglican', controller),
                            _buildFilterChip('Orthodox', controller),
                            _buildFilterChip('Methodist', controller),
                            _buildFilterChip('Presbyterian', controller),
                            _buildFilterChip('Lutheran', controller),
                            _buildFilterChip('Adventist', controller),
                            _buildFilterChip('Protestant', controller),
                          ],
                        ),
                      ),
                    ),

                    // Churches List
                    Expanded(
                      child: Obx(() {
                        if (controller.isLoading.value) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    const Color(0xFF8B4513),
                                  ),
                                ),
                                SizedBox(height: 16.h),
                                Text(
                                  'Connecting...',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13.sp,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        if (controller.places.isEmpty) {
                          final q = controller.externalSearchQuery.value.isNotEmpty
                              ? controller.externalSearchQuery.value
                              : controller.searchController.text.trim();
                          return Center(
                            child: SingleChildScrollView(
                              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.church_outlined,
                                    size: 48.r,
                                    color: Colors.grey[300],
                                  ),
                                  SizedBox(height: 8.h),
                                  Text(
                                    'No churches found',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14.sp,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                  SizedBox(height: 4.h),
                                  Text(
                                    'Try adjusting your search or filters',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12.sp,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                  if (q.isNotEmpty) ...[
                                    SizedBox(height: 16.h),
                                    _buildExternalMapsOffer(controller, q, compact: true),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          controller: ScrollController(),
                          padding: EdgeInsets.symmetric(horizontal: 16.w),
                          itemCount: controller.places.length,
                          itemBuilder: (context, index) {
                            final place = controller.places[index];
                            final name = place['name'] ?? '';
                            final address = place['vicinity'] ??
                                (place['formatted_address'] ?? '');
                            final distance = place['distance'] ?? (index * 0.5 + 1.5).toStringAsFixed(1);
                            final distanceLabel = distance == '—' ? '—' : '$distance mi';
                            final imageUrl = place['church_image_url']?.toString();

                            return Container(
                              margin: EdgeInsets.only(bottom: 8.h),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10.r),
                                border: Border.all(color: Colors.grey[100]!),
                              ),
                              child: ListTile(
                                onTap: () {
                                  if (controller.isBottomSheetExpanded.value) {
                                    controller.toggleBottomSheet();
                                  }
                                  controller.selectChurchAndShowRoute(place);
                                },
                                isThreeLine: true,
                                visualDensity: VisualDensity.compact,
                                contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                                leading: imageUrl != null && imageUrl.isNotEmpty
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8.r),
                                        child: CachedImage(
                                          imageUrl: imageUrl,
                                          width: 38.w,
                                          height: 38.h,
                                          fit: BoxFit.cover,
                                          errorWidget: Container(
                                            width: 38.w,
                                            height: 38.h,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF8B4513).withOpacity(0.08),
                                              borderRadius: BorderRadius.circular(8.r),
                                            ),
                                            child: Icon(
                                              Icons.church_outlined,
                                              size: 18.r,
                                              color: const Color(0xFF8B4513),
                                            ),
                                          ),
                                        ),
                                      )
                                    : Container(
                                        width: 38.w,
                                        height: 38.h,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF8B4513).withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(8.r),
                                        ),
                                        child: Icon(
                                          Icons.church_outlined,
                                          size: 18.r,
                                          color: const Color(0xFF8B4513),
                                        ),
                                      ),
                                title: Text(
                                  name,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF2C3E50),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  [
                                    if (address.isNotEmpty) address,
                                    '$distanceLabel • ${place['denomination'] ?? 'Church'}',
                                  ].join('\n'),
                                  style: GoogleFonts.poppins(
                                    fontSize: 11.sp,
                                    color: Colors.grey[600],
                                    height: 1.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Icon(
                                  Icons.chevron_right_rounded,
                                  size: 18.r,
                                  color: Colors.grey[400],
                                ),
                              ),
                            );
                          },
                        );
                      }),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ));
      }),
    );
  }

  Widget _buildFilterLoadingIndicator(ChurchLocatorController controller) {
    return Obx(() {
      if (!controller.isFilterLoading.value) return const SizedBox.shrink();
      return Positioned(
        top: MediaQuery.of(Get.context!).size.height * 0.3,
        left: 0,
        right: 0,
        child: Center(
          child: Container(
            padding: EdgeInsets.all(16.r),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 20.r,
                  height: 20.r,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      const Color(0xFF8B4513),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Text(
                  'Filtering churches...',
                  style: GoogleFonts.poppins(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF2C3E50),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildGlobalLoadingIndicator(ChurchLocatorController controller) {
    return Obx(() {
      if (!controller.isLoading.value || controller.places.isNotEmpty) {
        return const SizedBox.shrink();
      }
      return Positioned.fill(
        child: Container(
          color: Colors.transparent,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(
              color: Colors.black.withOpacity(0.1),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 45.r,
                      height: 45.r,
                      child: CircularProgressIndicator(
                        strokeWidth: 3.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          const Color(0xFFE53935),
                        ),
                      ),
                    ),
                    SizedBox(height: 24.h),
                    Text(
                      controller.loadingMessage.value,
                      style: GoogleFonts.poppins(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        shadows: [Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 4)],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildMyLocationButton(ChurchLocatorController controller) {
    return Positioned(
      bottom: controller.isBottomSheetExpanded.value ? 20.h : 140.h,
      right: 14.w,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            IconButton(
              onPressed: controller.zoomIn,
              icon: Icon(Icons.add, size: 20.r, color: const Color(0xFF8B4513)),
              constraints: BoxConstraints(minWidth: 40.w, minHeight: 40.h),
              padding: EdgeInsets.zero,
            ),
            Container(height: 1, width: 30.w, color: Colors.grey[200]),
            IconButton(
              onPressed: controller.zoomOut,
              icon: Icon(Icons.remove, size: 20.r, color: const Color(0xFF8B4513)),
              constraints: BoxConstraints(minWidth: 40.w, minHeight: 40.h),
              padding: EdgeInsets.zero,
            ),
            Container(height: 1, width: 30.w, color: Colors.grey[200]),
            IconButton(
              onPressed: controller.goToMyLocation,
              icon: Icon(Icons.my_location_rounded, size: 18.r, color: const Color(0xFF8B4513)),
              constraints: BoxConstraints(minWidth: 40.w, minHeight: 40.h),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, ChurchLocatorController controller) {
    return Obx(() {
      final isSelected = (label == 'All' &&
          (controller.selectedDenomination.value == null ||
              controller.selectedDenomination.value!.isEmpty)) ||
          (controller.selectedDenomination.value == label);

      return GestureDetector(
        onTap: () => controller.updateDenomination(label == 'All' ? null : label),
        child: Container(
          margin: EdgeInsets.only(right: 8.w),
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF8B4513) : Colors.grey[100],
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: isSelected ? const Color(0xFF8B4513) : Colors.grey[300]!,
              width: 0.5,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11.sp,
              fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
              color: isSelected ? Colors.white : Colors.grey[700],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildFilterIcon(ChurchLocatorController controller) {
    return GestureDetector(
      onTap: () => _showFilterDialog(controller),
      child: Container(
        padding: EdgeInsets.all(6.r),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: Colors.grey[300]!, width: 0.5),
        ),
        child: Icon(Icons.tune_rounded, size: 16.r, color: const Color(0xFF2C3E50)),
      ),
    );
  }

  Widget _buildGoogleMap(ChurchLocatorController controller) {
    return Stack(
      children: [
        Obx(() {
          final markerList = controller.markers.toList();
          final routeLabels = controller.routeLabelMarkers.toList();
          final navMarker = controller.navigationMarker.value;
          return GoogleMap(
          onMapCreated: (GoogleMapController mapController) {
            controller.onMapCreated(mapController);
          },
          onCameraMove: controller.onCameraMove,
          onCameraIdle: controller.onCameraIdle,
          onCameraMoveStarted: controller.onCameraMoveStarted,
          initialCameraPosition: CameraPosition(
            target: controller.defaultLocation,
            zoom: 12.0,
          ),
          myLocationEnabled: !controller.isNavigating.value,
          myLocationButtonEnabled: false,
          markers: <Marker>{
            ...markerList,
            ...routeLabels,
            if (navMarker != null) navMarker,
          },
          polylines: Set<Polyline>.from(controller.polylines),
          padding: EdgeInsets.only(
            bottom: controller.isBottomSheetExpanded.value
                ? MediaQuery.of(Get.context!).size.height * 0.45
                : MediaQuery.of(Get.context!).size.height * 0.15,
          ),
          compassEnabled: true,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          buildingsEnabled: true,
          indoorViewEnabled: true,
          trafficEnabled: controller.isNavigating.value,
          rotateGesturesEnabled: true,
          scrollGesturesEnabled: true,
          tiltGesturesEnabled: true,
          zoomGesturesEnabled: true,
          minMaxZoomPreference: const MinMaxZoomPreference(3.0, 20.0),
        );
        }),
        // Map Loading Blur Overlay
        Obx(() {
          if (controller.isMapReady.value) return const SizedBox.shrink();
          return Positioned.fill(
            child: Container(
              color: Colors.transparent,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  color: Colors.white.withOpacity(0.2),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: const Color(0xFFE53935),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDummyMap() {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(20.r),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(Icons.map_outlined, size: 48.r, color: const Color(0xFF8B4513)),
            ),
            SizedBox(height: 16.h),
            Text(
              'Map unavailable',
              style: GoogleFonts.poppins(
                fontSize: 16.sp,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationPermissionPrompt(ChurchLocatorController controller) {
    return Obx(() {
      final needPrompt = controller.currentPosition.value == null &&
          !controller.isLoading.value;
      if (!needPrompt) return const SizedBox.shrink();

      return Positioned(
        top: MediaQuery.of(Get.context!).padding.top + 100.h,
        left: 16.w,
        right: 16.w,
        child: Container(
          padding: EdgeInsets.all(12.r),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(6.r),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B4513).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(Icons.location_on_rounded, color: const Color(0xFF8B4513), size: 16.r),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enable location',
                      style: GoogleFonts.poppins(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2C3E50),
                      ),
                    ),
                    Text(
                      'Find churches near you',
                      style: GoogleFonts.poppins(
                        fontSize: 11.sp,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: controller.retryLocation,
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFF8B4513),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  minimumSize: Size.zero,
                ),
                child: Text(
                  'Enable',
                  style: GoogleFonts.poppins(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  void _showFilterDialog(ChurchLocatorController controller) {
    final options = [
      'All',
      'Catholic',
      'Protestant',
      'Pentecostal',
      'Orthodox',
      'Baptist',
      'Lutheran',
      'Anglican',
      'Methodist',
      'Presbyterian',
      'Non-denominational',
    ];

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        child: Container(
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.filter_list_rounded, size: 18.r, color: const Color(0xFF8B4513)),
                  SizedBox(width: 8.w),
                  Text(
                    'Filter by Denomination',
                    style: GoogleFonts.poppins(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2C3E50),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              SizedBox(
                height: 280.h,
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 2.8,
                    crossAxisSpacing: 8.w,
                    mainAxisSpacing: 8.h,
                  ),
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final option = options[index];
                    return Obx(() {
                      final isSelected = (option == 'All' &&
                          (controller.selectedDenomination.value == null ||
                              controller.selectedDenomination.value!.isEmpty)) ||
                          (controller.selectedDenomination.value == option);
                      return FilterChip(
                        label: Text(
                          option,
                          style: GoogleFonts.poppins(
                            fontSize: 11.sp,
                            color: isSelected ? Colors.white : const Color(0xFF2C3E50),
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (_) {
                          controller.updateDenomination(option == 'All' ? null : option);
                        },
                        backgroundColor: Colors.grey[100],
                        selectedColor: const Color(0xFF8B4513),
                        checkmarkColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                        labelPadding: EdgeInsets.symmetric(horizontal: 4.w),
                      );
                    });
                  },
                ),
              ),
              SizedBox(height: 16.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      controller.updateDenomination(null);
                      Get.back();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[600],
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                    ),
                    child: Text('Clear All', style: GoogleFonts.poppins(fontSize: 12.sp)),
                  ),
                  SizedBox(width: 8.w),
                  ElevatedButton(
                    onPressed: () => Get.back(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B4513),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                    ),
                    child: Text(
                      'Apply',
                      style: GoogleFonts.poppins(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRouteDirectionsCard(ChurchLocatorController controller) {
    return Obx(() {
      if (controller.isNavigating.value || controller.routeSummary.value == null) {
        return const SizedBox.shrink();
      }

      final firstStep = controller.routeSteps.isNotEmpty ? controller.routeSteps.first : null;
      final instruction = firstStep != null
          ? (firstStep['html_instructions'] ?? '').toString().replaceAll(RegExp(r'<[^>]*>'), '')
          : 'Head to destination';

      return Positioned(
        top: MediaQuery.of(Get.context!).padding.top + 38.h,
        left: 12.w,
        right: 12.w,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: const Color(0xFF1976D2),
            borderRadius: BorderRadius.circular(10.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.navigation_rounded, color: Colors.white, size: 20.r),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      instruction,
                      style: GoogleFonts.poppins(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            controller.routeSummary.value!,
                            style: GoogleFonts.poppins(
                              fontSize: 11.sp,
                              color: Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (controller.routeSteps.length > 1) ...[
                          SizedBox(width: 8.w),
                          GestureDetector(
                            onTap: () => _showDirectionsSheet(controller),
                            child: Text(
                              '• View Details',
                              style: GoogleFonts.poppins(
                                fontSize: 11.sp,
                                color: Colors.white70,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, color: Colors.white70, size: 20.r),
                onPressed: () {
                  controller.dismissRouteAndNavigation();
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      );
    });
  }

  void _showDirectionsSheet(ChurchLocatorController controller) {
    Get.bottomSheet(
      Container(
        height: Get.height * 0.7,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        ),
        child: Obx(() { // Use Obx to reactively update the sheet
          // If no route data, show loading or nothing
          if (controller.allRoutesData.isEmpty || controller.routeSteps.isEmpty) {
            return const Center(
              child: Text('No directions available'),
            );
          }
          
          return Column(
            children: [
              if (controller.selectedPlace.value != null) ...[
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Container(
                    padding: EdgeInsets.all(10.r),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8.r),
                          child: (() {
                            final imageUrl = controller.selectedPlace.value!['church_image_url']?.toString();
                            if (imageUrl != null && imageUrl.isNotEmpty) {
                              return CachedImage(
                                imageUrl: imageUrl,
                                width: 56.w,
                                height: 56.h,
                                fit: BoxFit.cover,
                              );
                            }
                            return Container(
                              width: 56.w,
                              height: 56.h,
                              color: const Color(0xFF8B4513).withOpacity(0.08),
                              child: Icon(
                                Icons.church_outlined,
                                size: 22.r,
                                color: const Color(0xFF8B4513),
                              ),
                            );
                          })(),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Text(
                            controller.selectedPlace.value!['name']?.toString() ?? 'Church',
                            style: GoogleFonts.poppins(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF2C3E50),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 10.h),
              ],
              Container(
                margin: EdgeInsets.symmetric(vertical: 12.h),
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Row(
                  children: [
                    Text(
                      'Directions',
                      style: GoogleFonts.poppins(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      controller.routeSummary.value ?? '',
                      style: GoogleFonts.poppins(
                        fontSize: 14.sp,
                        color: const Color(0xFF1E88E5),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                  itemCount: controller.routeSteps.length,
                  separatorBuilder: (_, __) => Divider(height: 24.h, color: Colors.grey[100]),
                  itemBuilder: (context, index) {
                    final step = controller.routeSteps[index];
                    final instruction = (step['html_instructions'] ?? '').toString()
                        .replaceAll(RegExp(r'<[^>]*>'), '');

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 24.w,
                          height: 24.w,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: GoogleFonts.poppins(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 16.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                instruction,
                                style: GoogleFonts.poppins(
                                  fontSize: 14.sp,
                                  color: const Color(0xFF2C3E50),
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                '${_distanceToMilesText(step['distance']?['text']?.toString() ?? '', '0.0 mi')} • ${step['duration']?['text'] ?? ''}',
                                style: GoogleFonts.poppins(
                                  fontSize: 12.sp,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        }),
      ),
      isScrollControlled: true,
    );
  }

  void _showChurchDetailsSheet(
    ChurchLocatorController controller, {
    String? fallbackChurchName,
  }) {
    Map<String, dynamic>? place = controller.selectedPlace.value;
    if (place == null && controller.places.isNotEmpty) {
      if (fallbackChurchName != null && fallbackChurchName.trim().isNotEmpty) {
        for (final p in controller.places) {
          final name = p['name']?.toString() ?? '';
          if (name.toLowerCase() == fallbackChurchName.toLowerCase()) {
            place = p;
            break;
          }
        }
      }
      place ??= controller.places.first;
    }
    if (place == null) {
      Get.snackbar(
        'Details',
        'Church details not available yet. Please select a church again.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    Get.bottomSheet(
      _ChurchDetailsSheet(
        controller: controller,
        initialPlace: Map<String, dynamic>.from(place),
      ),
      isScrollControlled: true,
    );
  }
}

class _ChurchDetailsSheet extends StatefulWidget {
  final ChurchLocatorController controller;
  final Map<String, dynamic> initialPlace;

  const _ChurchDetailsSheet({
    required this.controller,
    required this.initialPlace,
  });

  @override
  State<_ChurchDetailsSheet> createState() => _ChurchDetailsSheetState();
}

class _ChurchDetailsSheetState extends State<_ChurchDetailsSheet> {
  late Map<String, dynamic> _place;
  bool _loading = true;
  String? _error;
  int _selectedPhotoIndex = 0;

  @override
  void initState() {
    super.initState();
    _place = Map<String, dynamic>.from(widget.initialPlace);
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final enriched = await widget.controller.fetchChurchDetails(_place);
      if (!mounted) return;
      setState(() {
        _place = enriched;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load full church details.';
      });
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _callPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone.replaceAll(' ', ''));
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  List<String> get _photoUrls {
    final fromList = _place['photo_urls'];
    if (fromList is List && fromList.isNotEmpty) {
      return fromList.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    final single = _place['church_image_url']?.toString();
    if (single != null && single.isNotEmpty) return [single];
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final name = _place['name']?.toString() ?? 'Church';
    final address = (_place['formatted_address'] ?? _place['vicinity'] ?? 'Address not available').toString();
    final distance = _place['distance']?.toString() ?? '—';
    final denomination = _place['denomination']?.toString() ?? 'Church';
    final description = _place['description']?.toString() ?? '';
    final phone = (_place['formatted_phone_number'] ?? _place['international_phone_number'])?.toString();
    final website = _place['website']?.toString();
    final rating = _place['rating'];
    final ratingsTotal = _place['user_ratings_total'];
    final openingHours = _place['opening_hours'];
    final businessStatus = _place['business_status']?.toString();
    final photos = _photoUrls;

    return Container(
      height: Get.height * 0.82,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              margin: EdgeInsets.only(top: 10.h, bottom: 10.h),
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Church Details',
                    style: GoogleFonts.poppins(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF2C3E50),
                    ),
                  ),
                ),
                if (_loading)
                  SizedBox(
                    width: 18.r,
                    height: 18.r,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          SizedBox(height: 10.h),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12.r),
                    child: photos.isNotEmpty
                        ? CachedImage(
                            imageUrl: photos[_selectedPhotoIndex.clamp(0, photos.length - 1)],
                            width: double.infinity,
                            height: 190.h,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: double.infinity,
                            height: 190.h,
                            color: const Color(0xFF8B4513).withOpacity(0.08),
                            child: Icon(
                              Icons.church_outlined,
                              size: 56.r,
                              color: const Color(0xFF8B4513),
                            ),
                          ),
                  ),
                  if (photos.length > 1) ...[
                    SizedBox(height: 8.h),
                    SizedBox(
                      height: 56.h,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: photos.length,
                        separatorBuilder: (_, __) => SizedBox(width: 8.w),
                        itemBuilder: (_, index) {
                          final selected = index == _selectedPhotoIndex;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedPhotoIndex = index),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8.r),
                                border: Border.all(
                                  color: selected ? const Color(0xFF2196F3) : Colors.grey[300]!,
                                  width: selected ? 2 : 1,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(7.r),
                                child: CachedImage(
                                  imageUrl: photos[index],
                                  width: 56.w,
                                  height: 56.h,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  SizedBox(height: 14.h),
                  Text(
                    name,
                    style: GoogleFonts.poppins(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF2C3E50),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  if (rating != null)
                    Row(
                      children: [
                        ...List.generate(5, (index) {
                          final value = (rating is num) ? rating.toDouble() : double.tryParse('$rating') ?? 0;
                          return Icon(
                            index < value.round() ? Icons.star_rounded : Icons.star_border_rounded,
                            size: 18.r,
                            color: const Color(0xFFFFB300),
                          );
                        }),
                        SizedBox(width: 6.w),
                        Text(
                          '$rating${ratingsTotal != null ? ' ($ratingsTotal reviews)' : ''}',
                          style: GoogleFonts.poppins(fontSize: 12.sp, color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  SizedBox(height: 10.h),
                  Wrap(
                    spacing: 8.w,
                    runSpacing: 8.h,
                    children: [
                      _infoChip(
                        distance == '—' ? 'Distance: —' : 'Distance: $distance mi',
                        Icons.directions_walk_rounded,
                      ),
                      _infoChip(denomination, Icons.church_outlined),
                      if (businessStatus != null && businessStatus.isNotEmpty)
                        _infoChip(
                          businessStatus.replaceAll('_', ' '),
                          Icons.storefront_outlined,
                        ),
                    ],
                  ),
                  SizedBox(height: 14.h),
                  _detailRow(Icons.location_on_outlined, address),
                  if (phone != null && phone.isNotEmpty) ...[
                    SizedBox(height: 10.h),
                    GestureDetector(
                      onTap: () => _callPhone(phone),
                      child: _detailRow(Icons.phone_outlined, phone, linkStyle: true),
                    ),
                  ],
                  if (website != null && website.isNotEmpty) ...[
                    SizedBox(height: 10.h),
                    GestureDetector(
                      onTap: () => _openUrl(website),
                      child: _detailRow(Icons.language_outlined, website, linkStyle: true),
                    ),
                  ],
                  if (openingHours is Map) ...[
                    SizedBox(height: 14.h),
                    Text(
                      'Opening Hours',
                      style: GoogleFonts.poppins(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2C3E50),
                      ),
                    ),
                    SizedBox(height: 6.h),
                    if (openingHours['open_now'] != null)
                      Text(
                        openingHours['open_now'] == true ? 'Open now' : 'Closed now',
                        style: GoogleFonts.poppins(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: openingHours['open_now'] == true ? Colors.green[700] : Colors.red[700],
                        ),
                      ),
                    if (openingHours['weekday_text'] is List) ...[
                      SizedBox(height: 6.h),
                      ...List<Widget>.from(
                        (openingHours['weekday_text'] as List).map(
                          (day) => Padding(
                            padding: EdgeInsets.only(bottom: 4.h),
                            child: Text(
                              day.toString(),
                              style: GoogleFonts.poppins(fontSize: 12.sp, color: Colors.grey[700]),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                  SizedBox(height: 14.h),
                  Text(
                    'About this church',
                    style: GoogleFonts.poppins(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2C3E50),
                    ),
                  ),
                  SizedBox(height: 6.h),
                  if (_loading)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.h),
                      child: Text(
                        'Loading church information from Google Maps...',
                        style: GoogleFonts.poppins(fontSize: 12.sp, color: Colors.grey[600]),
                      ),
                    )
                  else
                    Text(
                      description.isNotEmpty
                          ? description
                          : 'No description available for this church yet.',
                      style: GoogleFonts.poppins(
                        fontSize: 13.sp,
                        height: 1.45,
                        color: Colors.grey[800],
                      ),
                    ),
                  if (_error != null) ...[
                    SizedBox(height: 10.h),
                    Text(
                      _error!,
                      style: GoogleFonts.poppins(fontSize: 12.sp, color: Colors.orange[800]),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Get.back();
                  final loc = _place['geometry']?['location'];
                  if (loc != null) {
                    widget.controller.startNavigation(
                      LatLng(loc['lat'], loc['lng']),
                      name,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 13.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: Text(
                  'Start Navigation',
                  style: GoogleFonts.poppins(fontSize: 15.sp, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(String label, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.r, color: const Color(0xFF2C3E50)),
          SizedBox(width: 4.w),
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 11.sp, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String text, {bool linkStyle = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18.r, color: linkStyle ? const Color(0xFF2196F3) : Colors.grey[700]),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 13.sp,
              color: linkStyle ? const Color(0xFF2196F3) : Colors.grey[800],
              decoration: linkStyle ? TextDecoration.underline : null,
            ),
          ),
        ),
      ],
    );
  }
}
