import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controllers/church_locator_controller.dart';
import '../controllers/denominations_controller.dart';
import '../routes/app_pages.dart';
import '../widgets/standard_app_bar.dart';
import '../utils/app_theme.dart';

class DenominationsScreen extends StatelessWidget {
  const DenominationsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<DenominationsController>()
        ? Get.find<DenominationsController>()
        : Get.put(DenominationsController());

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
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(
                    color: AppTheme.iconscolor.withOpacity(0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: const BorderSide(
                    color: AppTheme.iconscolor,
                    width: 2,
                  ),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16.w,
                  vertical: 12.h,
                ),
              ),
              onChanged: controller.filterDenominations,
            ),
          ),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value &&
                  controller.filteredDenominations.isEmpty) {
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

              return RefreshIndicator(
                color: AppTheme.iconscolor,
                onRefresh: controller.refresh,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  itemCount: controller.filteredDenominations.length,
                  itemBuilder: (context, index) {
                    final denomination =
                        controller.filteredDenominations[index];
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
                                  denomination['description'] ??
                                      'No description available.',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14.sp,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                SizedBox(height: 12.h),
                                if (denomination['website_url'] != null &&
                                    denomination['website_url']
                                        .toString()
                                        .isNotEmpty)
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      onPressed: () async {
                                        var link = denomination['website_url']
                                            .toString();
                                        link = link
                                            .replaceAll('`', '')
                                            .replaceAll('"', '')
                                            .replaceAll("'", '')
                                            .trim();
                                        if (!link.startsWith('http://') &&
                                            !link.startsWith('https://')) {
                                          link = 'https://$link';
                                        }
                                        final url = Uri.parse(link);
                                        try {
                                          final canLaunchExternal =
                                              await canLaunchUrl(url);
                                          if (canLaunchExternal) {
                                            final ok = await launchUrl(
                                              url,
                                              mode: LaunchMode
                                                  .externalApplication,
                                            );
                                            if (!ok) {
                                              await launchUrl(
                                                url,
                                                mode: LaunchMode.platformDefault,
                                              );
                                            }
                                          } else {
                                            await launchUrl(
                                              url,
                                              mode: LaunchMode.platformDefault,
                                            );
                                          }
                                        } catch (_) {
                                          Get.snackbar(
                                            'Link Error',
                                            'Website open nahi ho pa rahi',
                                            snackPosition: SnackPosition.BOTTOM,
                                          );
                                        }
                                      },
                                      icon: Icon(
                                        Icons.language,
                                        color: AppTheme.iconscolor,
                                        size: 20,
                                      ),
                                      label: Text(
                                        'Visit Website',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w500,
                                          color: AppTheme.iconscolor,
                                        ),
                                      ),
                                    ),
                                  ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () {
                                      final name = denomination['name']
                                          ?.toString()
                                          .trim();
                                      if (Get.isRegistered<
                                          ChurchLocatorController>()) {
                                        final locator =
                                            Get.find<ChurchLocatorController>();
                                        locator.prepareChurchLocator(
                                          denomination: name,
                                        );
                                        if (name != null && name.isNotEmpty) {
                                          locator.applyDenominationFilter(name);
                                        }
                                      }
                                      Get.toNamed(
                                        Routes.CHURCH_LOCATOR,
                                        arguments: {
                                          if (name != null && name.isNotEmpty)
                                            'denomination': name,
                                        },
                                      );
                                    },
                                    icon: Icon(
                                      Icons.location_on,
                                      size: 18,
                                      color: AppTheme.iconscolor,
                                    ),
                                    label: Text(
                                      'Find Church',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.iconscolor,
                                      ),
                                    ),
                                  ),
                                ),
                                Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: AppTheme.iconscolor.withOpacity(0.1),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
