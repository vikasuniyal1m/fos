import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/calendar_banner_controller.dart';
import '../utils/app_theme.dart';
import '../utils/responsive_helper.dart';
import 'dart:async';

/// Calendar Banner Widget
/// Displays upcoming festival with countdown
/// Place this below the main banner carousel in HomeScreen
class CalendarBannerWidget extends StatefulWidget {
  const CalendarBannerWidget({Key? key}) : super(key: key);

  @override
  State<CalendarBannerWidget> createState() => _CalendarBannerWidgetState();
}

class _CalendarBannerWidgetState extends State<CalendarBannerWidget> {
  Timer? _countdownTimer;
  Map<String, String> _countdowns = {};

  @override
  void initState() {
    super.initState();
    _startCountdownTimer();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _updateCountdowns();
        });
      }
    });
  }

  void _updateCountdowns() {
    final controller = Get.find<CalendarBannerController>();
    final now = DateTime.now();
    final allEvents = [
      ...controller.todayEvents,
      ...controller.upcomingEvents,
    ];

    for (var event in allEvents) {
      final dateStr = event['date']?.toString();
      if (dateStr != null && dateStr.isNotEmpty) {
        try {
          final eventDate = DateTime.parse(dateStr);
          final today = DateTime(now.year, now.month, now.day);
          final isToday = eventDate.toLocal().isAtSameMomentAs(today);

          if (isToday) {
            _countdowns[dateStr] = 'TODAY';
          } else {
            final difference = eventDate.difference(now);
            if (difference.inDays > 0) {
              _countdowns[dateStr] = '${difference.inDays}d';
            } else if (difference.inHours > 0) {
              _countdowns[dateStr] = '${difference.inHours}h';
            } else if (difference.inMinutes > 0) {
              _countdowns[dateStr] = '${difference.inMinutes}m';
            } else if (difference.inSeconds > 0) {
              _countdowns[dateStr] = '${difference.inSeconds}s';
            }
          }
        } catch (e) {
          // Invalid date
        }
      }
    }
  }

  String _getCountdown(String dateStr) {
    return _countdowns[dateStr] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<CalendarBannerController>(
      init: CalendarBannerController(),
      builder: (controller) => Obx(() {
        // Show loading or empty placeholder to verify widget is rendering
        if (controller.isLoading.value) {
          return Container(
            margin: ResponsiveHelper.padding(context, horizontal: 8, vertical: 6),
            padding: ResponsiveHelper.padding(context, all: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
            ),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        
        // Don't show if no events at all (today or upcoming)
        if (!controller.hasAnyEvents) {
          // Return a placeholder to show widget is working
          return Container(
            margin: ResponsiveHelper.padding(context, horizontal: 8, vertical: 6),
            padding: ResponsiveHelper.padding(context, all: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.event_busy, 
                      color: Colors.grey.shade400,
                      size: ResponsiveHelper.iconSize(context, mobile: 24),
                    ),
                    SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                    Text(
                      'No upcoming festivals',
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, 8)),
                Text(
                  'Check back later for Christian feasts and holidays',
                  style: ResponsiveHelper.textStyle(
                    context,
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          );
        }

        // Combine today and upcoming events
        final allEvents = [...controller.todayEvents, ...controller.upcomingEvents];
        
        // Update countdowns initially
        _updateCountdowns();
        
        return Container(
          margin: ResponsiveHelper.padding(context, horizontal: 8, vertical: 6),
          child: _buildCompactCarousel(allEvents, controller),
        );
      }),
    );
  }

  /// Build compact horizontal carousel
  Widget _buildCompactCarousel(
    List<Map<String, dynamic>> events,
    CalendarBannerController controller,
  ) {
    return SizedBox(
      height: ResponsiveHelper.dim(context, mobile: 280, tablet: 340, desktop: 380),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: events.length,
        itemBuilder: (context, index) {
          final event = events[index];
          return _buildSimpleCard(event, controller);
        },
      ),
    );
  }

  /// Build beautiful card like reference image
  Widget _buildSimpleCard(
    Map<String, dynamic> event,
    CalendarBannerController controller,
  ) {
    final title = event['title']?.toString() ?? 'Festival';
    final date = event['date']?.toString() ?? '';
    final category = event['category']?.toString() ?? '';
    final isChristian = category == 'christian';
    
    // Theme colors - alternating between warm and cool tones
    final primaryColor = isChristian 
        ? const Color(0xFFE85D5D) // Warm pink/red for Christian
        : const Color(0xFF4ECDC4); // Cool teal for secular
    final lightColor = isChristian
        ? const Color(0xFFFFF0F0) // Very light pink
        : const Color(0xFFE8F8F5); // Very light teal
    final iconBgColor = isChristian
        ? const Color(0xFFFFE4E4) // Light pink
        : const Color(0xFFD4F1F4); // Light blue

    // Get live countdown from timer
    final countdownText = _getCountdown(date);
    final isToday = countdownText == 'TODAY';

    return Container(
      width: ResponsiveHelper.dim(context, mobile: 220, tablet: 280, desktop: 320),
      margin: EdgeInsets.only(right: ResponsiveHelper.spacing(context, 12)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            lightColor,
            Colors.white,
          ],
        ),
        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 20)),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.15),
            blurRadius: ResponsiveHelper.dim(context, mobile: 12),
            offset: Offset(0, ResponsiveHelper.dim(context, mobile: 4)),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: ResponsiveHelper.padding(context, all: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Church/Icon at top
            Container(
              width: ResponsiveHelper.dim(context, mobile: 48, tablet: 54),
              height: ResponsiveHelper.dim(context, mobile: 48, tablet: 54),
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  isChristian ? Icons.church : Icons.celebration,
                  color: primaryColor,
                  size: ResponsiveHelper.iconSize(context, mobile: 24, tablet: 28),
                ),
              ),
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 12)),
            
            // Festival name
            Text(
              title,
              style: ResponsiveHelper.textStyle(
                context,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2D3436),
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 6)),
            
            // Date with pin icon
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  size: ResponsiveHelper.iconSize(context, mobile: 14),
                  color: primaryColor.withOpacity(0.7),
                ),
                SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                Text(
                  controller.formatDate(date),
                  style: ResponsiveHelper.textStyle(
                    context,
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            
            const Spacer(),
            
            // Bottom section - Countdown badge
            Container(
              padding: ResponsiveHelper.padding(context, horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isChristian 
                    ? const Color(0xFFFFF5F5) 
                    : const Color(0xFFF0F9F7),
                borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12, tablet: 16)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: ResponsiveHelper.iconSize(context, mobile: 16, tablet: 20),
                    color: primaryColor,
                  ),
                  const Spacer(),
                  Container(
                    padding: ResponsiveHelper.padding(context, horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isToday 
                          ? const Color(0xFF00B894)
                          : primaryColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8, tablet: 10)),
                    ),
                    child: Text(
                      countdownText.isNotEmpty ? countdownText : 'SOON',
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: ResponsiveHelper.fontSize(context, mobile: 11, tablet: 13, desktop: 15),
                        fontWeight: FontWeight.bold,
                        color: isToday ? Colors.white : primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
