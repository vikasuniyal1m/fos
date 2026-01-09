import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/controllers/prayer_reminders_controller.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';
import 'package:fruitsofspirit/widgets/cached_image.dart';
import 'package:fruitsofspirit/widgets/standard_app_bar.dart';
import 'package:fruitsofspirit/config/image_config.dart';
import 'package:fruitsofspirit/utils/app_theme.dart';

/// Prayer Reminders Screen
/// Users can set prayer reminder times
/// Theme matches home page
class PrayerRemindersScreen extends StatelessWidget {
  const PrayerRemindersScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(PrayerRemindersController());

    return Scaffold(
      backgroundColor: AppTheme.themeColor, // Match other pages - beige background
      appBar: StandardAppBar(
        showBackButton: true,
        rightActions: [], // No icons
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.reminderTimes.isEmpty) {
          return Center(
            child: CircularProgressIndicator(
              color: AppTheme.iconscolor,
            ),
          );
        }

        return SingleChildScrollView(
          padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info Card
              Container(
                padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 16)),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.accentColor,
                      AppTheme.iconscolor.withOpacity(0.3),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(
                    ResponsiveHelper.borderRadius(context, mobile: 16),
                  ),
                  border: Border.all(
                    color: AppTheme.iconscolor.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 12)),
                      decoration: BoxDecoration(
                        color: AppTheme.iconscolor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.access_time_rounded,
                        color: AppTheme.iconscolor,
                        size: ResponsiveHelper.iconSize(context, mobile: 24),
                      ),
                    ),
                    SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Set Prayer Reminders',
                            style: ResponsiveHelper.textStyle(
                              context,
                              fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          SizedBox(height: ResponsiveHelper.spacing(context, 4)),
                          Text(
                            'Get notified at your preferred prayer times. You can set multiple reminders throughout the day.',
                            style: ResponsiveHelper.textStyle(
                              context,
                              fontSize: ResponsiveHelper.fontSize(context, mobile: 13),
                              color: Colors.grey[700],
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: ResponsiveHelper.spacing(context, 24)),

              // Enable/Disable Toggle
              Container(
                padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 16)),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(
                    ResponsiveHelper.borderRadius(context, mobile: 16),
                  ),
                  border: Border.all(
                    color: Colors.grey[200]!.withOpacity(0.5),
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      spreadRadius: 0,
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.notifications_active_rounded,
                          color: AppTheme.iconscolor,
                          size: ResponsiveHelper.iconSize(context, mobile: 24),
                        ),
                        SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Enable Reminders',
                              style: ResponsiveHelper.textStyle(
                                context,
                                fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(height: ResponsiveHelper.spacing(context, 2)),
                            Text(
                              controller.enabled.value
                                  ? 'You will receive prayer reminders'
                                  : 'Reminders are disabled',
                              style: ResponsiveHelper.textStyle(
                                context,
                                fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Switch(
                      value: controller.enabled.value,
                      onChanged: (value) {
                        controller.toggleEnabled();
                      },
                      activeColor: AppTheme.iconscolor,
                    ),
                  ],
                ),
              ),
              SizedBox(height: ResponsiveHelper.spacing(context, 24)),

              // Reminder Times List
              if (controller.enabled.value) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Prayer Times',
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: ResponsiveHelper.fontSize(context, mobile: 18),
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF5F4628),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _showAddTimeDialog(context, controller),
                      icon: Icon(
                        Icons.add_circle_outline,
                        color: AppTheme.iconscolor,
                        size: ResponsiveHelper.iconSize(context, mobile: 20),
                      ),
                      label: Text(
                        'Add Time',
                        style: ResponsiveHelper.textStyle(
                          context,
                          fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                          fontWeight: FontWeight.w600,
                          color: AppTheme.iconscolor,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, 12)),

                Obx(() {
                  if (controller.reminderTimes.isEmpty) {
                    return Container(
                      padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 24)),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(
                          ResponsiveHelper.borderRadius(context, mobile: 12),
                        ),
                        border: Border.all(
                          color: Colors.grey[200]!,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            spreadRadius: 0,
                            blurRadius: 8,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.schedule_outlined,
                            size: ResponsiveHelper.iconSize(context, mobile: 48),
                            color: Colors.grey[400],
                          ),
                          SizedBox(height: ResponsiveHelper.spacing(context, 12)),
                          Text(
                            'No prayer times set',
                            style: ResponsiveHelper.textStyle(
                              context,
                              fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(height: ResponsiveHelper.spacing(context, 4)),
                          Text(
                            'Add your preferred prayer times',
                            style: ResponsiveHelper.textStyle(
                              context,
                              fontSize: ResponsiveHelper.fontSize(context, mobile: 13),
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: controller.reminderTimes.map((time) {
                      return _buildTimeCard(context, controller, time);
                    }).toList(),
                  );
                }),
              ],

              SizedBox(height: ResponsiveHelper.spacing(context, 32)),

              // Save Button
              Obx(() {
                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: controller.isLoading.value
                        ? null
                        : () async {
                            final success = await controller.saveReminderSettings();
                            if (success) {
                              Get.snackbar(
                                'Success',
                                controller.message.value,
                                backgroundColor: Colors.green,
                                colorText: Colors.white,
                                snackPosition: SnackPosition.BOTTOM,
                              );
                            } else {
                              Get.snackbar(
                                'Error',
                                controller.message.value,
                                backgroundColor: Colors.red,
                                colorText: Colors.white,
                                snackPosition: SnackPosition.BOTTOM,
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.iconscolor,
                      padding: EdgeInsets.symmetric(
                        vertical: ResponsiveHelper.spacing(context, 16),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          ResponsiveHelper.borderRadius(context, mobile: 12),
                        ),
                      ),
                      elevation: 2,
                    ),
                    child: controller.isLoading.value
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            'Save Reminders',
                            style: ResponsiveHelper.textStyle(
                              context,
                              fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                );
              }),

              SizedBox(height: ResponsiveHelper.spacing(context, 16)),

              // Info Text
              Container(
                padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 12)),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(
                    ResponsiveHelper.borderRadius(context, mobile: 8),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: ResponsiveHelper.iconSize(context, mobile: 18),
                      color: Colors.blue[700],
                    ),
                    SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                    Expanded(
                      child: Text(
                        'Reminders will be sent to all users at their set prayer times. Make sure to save your settings.',
                        style: ResponsiveHelper.textStyle(
                          context,
                          fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                          color: Colors.blue[900],
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildTimeCard(
    BuildContext context,
    PrayerRemindersController controller,
    String time,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: ResponsiveHelper.spacing(context, 12)),
      padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 16)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          ResponsiveHelper.borderRadius(context, mobile: 12),
        ),
        border: Border.all(
          color: Colors.grey[200]!.withOpacity(0.5),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 10)),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.iconscolor,
                      AppTheme.iconscolor.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(
                    ResponsiveHelper.borderRadius(context, mobile: 8),
                  ),
                ),
                child: Icon(
                  Icons.access_time_rounded,
                  color: Colors.white,
                  size: ResponsiveHelper.iconSize(context, mobile: 20),
                ),
              ),
              SizedBox(width: ResponsiveHelper.spacing(context, 12)),
              Text(
                time,
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: ResponsiveHelper.fontSize(context, mobile: 18),
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          IconButton(
            icon: Icon(
              Icons.delete_outline,
              color: Colors.red[400],
              size: ResponsiveHelper.iconSize(context, mobile: 22),
            ),
            onPressed: () {
              controller.removeReminderTime(time);
            },
          ),
        ],
      ),
    );
  }

  void _showAddTimeDialog(
    BuildContext context,
    PrayerRemindersController controller,
  ) {
    TimeOfDay selectedTime = TimeOfDay.now();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            ResponsiveHelper.borderRadius(context, mobile: 16),
          ),
        ),
        title: Text(
          'Add Prayer Time',
          style: ResponsiveHelper.textStyle(
            context,
            fontSize: ResponsiveHelper.fontSize(context, mobile: 18),
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        content: SizedBox(
          height: 200,
          child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.time,
            initialDateTime: DateTime.now(),
            onDateTimeChanged: (DateTime dateTime) {
              selectedTime = TimeOfDay.fromDateTime(dateTime);
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final timeString =
                  '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';
              controller.addReminderTime(timeString);
              Get.back();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.iconscolor,
            ),
            child: const Text(
              'Add',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

