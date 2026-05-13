import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fruitsofspirit/controllers/church_locator_controller.dart';
import 'package:fruitsofspirit/config/api_config.dart';

class ChurchLocatorScreen extends StatelessWidget {
  const ChurchLocatorScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final args = Get.arguments as Map<String, dynamic>?;
    final String? initialDenomination = args?['denomination'];
    final String? hqQuery = args?['hqQuery'];

    // Controller should be registered in InitialBinding
    final controller = Get.find<ChurchLocatorController>();

    if (initialDenomination != null) {
      controller.selectedDenomination.value = initialDenomination;
    }
    if (hqQuery != null && hqQuery.isNotEmpty) {
      controller.hqQuery.value = hqQuery;
    }

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
        body: Stack(
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
            // Filter Loading Indicator
            _buildFilterLoadingIndicator(controller),
            // Global Loading Indicator
            _buildGlobalLoadingIndicator(controller),
            // Route Directions Card
            _buildRouteDirectionsCard(controller),
            // Professional Navigation UI
            _buildNavigationUI(controller),
            // Start Navigation Dialog
            _buildStartNavigationDialog(controller, 
              LatLng(30.7333, 76.7794), // Default destination, will be updated dynamically
              'Church' // Default name, will be updated dynamically
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchThisAreaButton(ChurchLocatorController controller) {
    return const SizedBox.shrink();
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

  // Build Start Navigation Dialog
  Widget _buildStartNavigationDialog(ChurchLocatorController controller, LatLng destination, String churchName) {
    return Obx(() {
      String currentChurchName = churchName;
      // Use selectedPlace FIRST, then fallback
      if (controller.selectedPlace.value != null) {
        currentChurchName = controller.selectedPlace.value!['name']?.toString() ?? churchName;
      } else if (controller.places.isNotEmpty) {
        currentChurchName = controller.places[0]['name']?.toString() ?? churchName;
      }
      
      String distance = controller.routeDistance.value.isNotEmpty 
          ? controller.routeDistance.value 
          : '2.5 km';
      String duration = controller.routeDuration.value.isNotEmpty 
          ? controller.routeDuration.value 
          : '8 min';
      
      if (!controller.isNavigating.value && 
      controller.allRoutesData.isNotEmpty && 
      controller.routeDistance.value.isNotEmpty && 
      controller.routeDuration.value.isNotEmpty) {
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
              children: [
                // Church Info
                /*Row(
                  children: [
                    Icon(
                      Icons.church,
                      color: const Color(0xFF8B4513),
                      size: 24.r,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        currentChurchName,
                        style: GoogleFonts.poppins(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF8B4513),
                        ),
                      ),
                    ),
                  ],
                ),*/
                SizedBox(height: 12.h),
                
                // Route Summary
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
                
                // Start Navigation Button
                SizedBox(
                  width: double.infinity,
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
                        Icon(Icons.navigation, size: 20.r),
                        SizedBox(width: 8.w),
                        Text(
                          'Start Navigation',
                          style: GoogleFonts.poppins(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return const SizedBox.shrink();
    });
  }

  Widget _buildNavigationUI(ChurchLocatorController controller) {
    return Obx(() {
      if (!controller.isNavigating.value) return const SizedBox.shrink();
      
      return Positioned(
        top: MediaQuery.of(Get.context!).padding.top + 60.h,
        left: 16.w,
        right: 16.w,
        child: Container(
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
                      _formatNavigationText(controller.navigationDistance.value, '0.0 km'),
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
                    onTap: () => controller.stopNavigation(),
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
                  if (controller.hqQuery.value != null && controller.hqQuery.value!.isNotEmpty) {
                    return IconButton(
                      icon: Icon(Icons.close_rounded, size: 20.r, color: Colors.grey[600]),
                      onPressed: () {
                        controller.hqQuery.value = null;
                        controller.searchController.clear();
                        controller.searchChurches();
                      },
                    );
                  }
                  return const SizedBox(width: 0);
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
                    final description = suggestion['description']?.toString() ?? '';
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.location_on_outlined,
                        size: 16.r,
                        color: const Color(0xFF8B4513),
                      ),
                      title: Text(
                        description,
                        style: GoogleFonts.poppins(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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


  Widget _buildBottomSheet(ChurchLocatorController controller) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Obx(() {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          height: controller.isBottomSheetExpanded.value
              ? MediaQuery.of(Get.context!).size.height * 0.75
              : 120.h,
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
              child: Column(
                children: [
                  // Drag Handle - Fixed to toggle properly
                  GestureDetector(
                    onTap: controller.toggleBottomSheet,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 6.h),
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
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                    child: Row(
                      children: [
                        Icon(
                          Icons.church_rounded,
                          size: 16.r,
                          color: const Color(0xFF8B4513),
                        ),
                        SizedBox(width: 8.w),
                        Obx(() {
                          // Show selected church name if available, else "Churches Near You"
                          String headerText = 'Churches Near You';
                          if (controller.selectedPlace.value != null) {
                            final name = controller.selectedPlace.value!['name']?.toString();
                            if (name != null && name.isNotEmpty) {
                              headerText = name;
                            }
                          }
                          return Text(
                            headerText,
                            style: GoogleFonts.poppins(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF2C3E50),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          );
                        }),
                        const Spacer(),
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
                  if (controller.isBottomSheetExpanded.value) ...[
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
                          return Center(
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
                              ],
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
                                  controller.clearRoute();
                                  controller.focusPlace(place);
                                  final lat = place['geometry']['location']['lat'];
                                  final lng = place['geometry']['location']['lng'];
                                  controller.routeToInApp(LatLng(lat, lng), place['name'] ?? '');
                                },
                                contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                                leading: Container(
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
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(height: 2.h),
                                    Text(
                                      address,
                                      style: GoogleFonts.poppins(
                                        fontSize: 11.sp,
                                        color: Colors.grey[600],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: 4.h),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.near_me_outlined,
                                          size: 10.r,
                                          color: const Color(0xFF8B4513),
                                        ),
                                        SizedBox(width: 4.w),
                                        Text(
                                          '$distance km',
                                          style: GoogleFonts.poppins(
                                            fontSize: 10.sp,
                                            color: const Color(0xFF8B4513),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        SizedBox(width: 12.w),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 6.w,
                                            vertical: 2.h,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[100],
                                            borderRadius: BorderRadius.circular(4.r),
                                          ),
                                          child: Text(
                                            place['denomination'] ?? 'Church',
                                            style: GoogleFonts.poppins(
                                              fontSize: 9.sp,
                                              fontWeight: FontWeight.w600,
                                              color: (place['denomination']?.toString().toLowerCase() ?? '').contains('catholic') ? Colors.blue[700] : const Color(0xFF8B4513).withOpacity(0.8),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
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
        );
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
      if (!controller.isLoading.value) return const SizedBox.shrink();
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
        Obx(() => GoogleMap(
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
            ...controller.markers,
            ...controller.routeLabelMarkers,
            if (controller.navigationMarker.value != null) controller.navigationMarker.value!,
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
          trafficEnabled: false,
          rotateGesturesEnabled: true,
          scrollGesturesEnabled: true,
          tiltGesturesEnabled: true,
          zoomGesturesEnabled: true,
          minMaxZoomPreference: const MinMaxZoomPreference(3.0, 20.0),
        )),
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
      if (controller.routeSummary.value == null) return const SizedBox.shrink();

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
                        Text(
                          controller.routeSummary.value!,
                          style: GoogleFonts.poppins(
                            fontSize: 11.sp,
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w500,
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
                  controller.stopNavigation();
                  controller.clearRoute();
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
                                '${step['distance']?['text'] ?? ''} • ${step['duration']?['text'] ?? ''}',
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
}
