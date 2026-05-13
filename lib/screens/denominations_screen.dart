import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controllers/denominations_controller.dart';
import '../routes/app_pages.dart';
import '../widgets/standard_app_bar.dart';
import '../utils/app_theme.dart';

class DenominationsScreen extends StatelessWidget {
  const DenominationsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(DenominationsController());

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const StandardAppBar(showBackButton: true, rightActions: []),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 0),
            child: Text(
              'Spiritual Denominations',
              style: GoogleFonts.poppins(
                color: AppTheme.textPrimary,
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16.w),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search denominations...',
                prefixIcon: Icon(Icons.search, color: AppTheme.iconscolor),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: AppTheme.iconscolor.withOpacity(0.3))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: const BorderSide(color: AppTheme.iconscolor, width: 2)),
                contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              ),
              onChanged: controller.filterDenominations,
            ),
          ),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }

              if (controller.filteredDenominations.isEmpty) {
                return Center(
                  child: Text(
                    'No denominations found',
                    style: GoogleFonts.poppins(fontSize: 16.sp),
                  ),
                );
              }

              return ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                itemCount: controller.filteredDenominations.length +
                          (controller.isLoadingMore.value ? 1 : 0),
                itemBuilder: (context, index) {
                  // Show loading indicator at the bottom
                  if (index >= controller.filteredDenominations.length) {
                    return Padding(
                      padding: EdgeInsets.all(16.h),
                      child: Center(
                        child: SizedBox(
                          width: 24.w,
                          height: 24.h,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.iconscolor),
                          ),
                        ),
                      ),
                    );
                  }

                  final denomination = controller.filteredDenominations[index];
                  return Card(
                    margin: EdgeInsets.only(bottom: 12.h),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: ExpansionTile(
                      title: Text(
                        denomination['name'],
                        style: GoogleFonts.poppins(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      children: [
                        Padding(
                          padding: EdgeInsets.all(16.w),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                denomination['description'] ?? 'No description available.',
                                style: GoogleFonts.poppins(
                                  fontSize: 14.sp,
                                  color: Colors.grey[700],
                                ),
                              ),
                              SizedBox(height: 12.h),
                              if (denomination['website_url'] != null && denomination['website_url'].isNotEmpty)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () async {
                                      var link = denomination['website_url'].toString();
                                      link = link.replaceAll('`', '').replaceAll('"', '').replaceAll("'", '').trim();
                                      if (!link.startsWith('http://') && !link.startsWith('https://')) {
                                        link = 'https://$link';
                                      }
                                      final url = Uri.parse(link);
                                      try {
                                        final canLaunchExternal = await canLaunchUrl(url);
                                        if (canLaunchExternal) {
                                          final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
                                          if (!ok) {
                                            await launchUrl(url, mode: LaunchMode.platformDefault);
                                          }
                                        } else {
                                          await launchUrl(url, mode: LaunchMode.platformDefault);
                                        }
                                      } catch (_) {
                                        Get.snackbar('Link Error', 'Website open nahi ho pa rahi',
                                            snackPosition: SnackPosition.BOTTOM);
                                      }
                                    },
                                    icon: Icon(Icons.language, color: AppTheme.iconscolor, size: 20),
                                    label: Text(
                                      'Visit Website',
                                      style: GoogleFonts.poppins(fontWeight: FontWeight.w500, color: AppTheme.iconscolor),
                                    ),
                                  ),
                                ),
                              
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                    onPressed: () {
                                       // Navigate to locator with this denomination selected
                                       Get.toNamed(Routes.CHURCH_LOCATOR, arguments: {'denomination': denomination['name']});
                                    },
                                    icon: Icon(Icons.location_on, size: 18, color: AppTheme.iconscolor),
                                    label: Text(
                                      'Find Church',
                                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppTheme.iconscolor),
                                    ),
                                  ),
                              ),
                              Divider(height: 1, thickness: 1, color: AppTheme.iconscolor.withOpacity(0.1)),
                              // Align(
                              //   alignment: Alignment.centerRight,
                              //   child: TextButton.icon(
                              //     onPressed: () {
                              //       final q = denomination['name']?.toString() ?? '';
                              //       Get.toNamed(Routes.CHURCH_LOCATOR, arguments: {'hqQuery': q});
                              //     },
                              //     icon: const Icon(Icons.apartment, size: 18, color: AppTheme.iconscolor),
                              //     label: Text(
                              //       'Locate HQ',
                              //       style: GoogleFonts.poppins(fontWeight: FontWeight.w500, color: AppTheme.iconscolor),
                              //     ),
                              //   ),
                              // )
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}
