import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/calendar_banner_controller.dart';
import '../utils/app_theme.dart';
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
        // Debug prints
        print('Calendar Banner Debug:');
        print('  hasAnyEvents: ${controller.hasAnyEvents}');
        print('  todayEvents: ${controller.todayEvents.length}');
        print('  upcomingEvents: ${controller.upcomingEvents.length}');
        print('  isLoading: ${controller.isLoading.value}');
        
        // Show loading or empty placeholder to verify widget is rendering
        if (controller.isLoading.value) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
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
          print('  -> No events to show, showing placeholder');
          // Return a placeholder to show widget is working
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.event_busy, color: Colors.grey.shade400),
                    const SizedBox(width: 8),
                    Text(
                      'No upcoming festivals',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Check back later for Christian feasts and holidays',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        }
        print('  -> Showing calendar banner!');

        // Combine today and upcoming events
        final allEvents = [...controller.todayEvents, ...controller.upcomingEvents];
        
        // Update countdowns initially
        _updateCountdowns();
        
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      height: 240,
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
      width: 200,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            lightColor,
            Colors.white,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Church/Icon at top
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  isChristian ? Icons.church : Icons.celebration,
                  color: primaryColor,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(height: 12),
            
            // Festival name
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2D3436),
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            
            // Date with pin icon
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  size: 14,
                  color: primaryColor.withOpacity(0.7),
                ),
                const SizedBox(width: 4),
                Text(
                  controller.formatDate(date),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            
            const Spacer(),
            
            // Bottom section - Countdown badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isChristian 
                    ? const Color(0xFFFFF5F5) 
                    : const Color(0xFFF0F9F7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 16,
                    color: primaryColor,
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isToday 
                          ? const Color(0xFF00B894)
                          : primaryColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      countdownText.isNotEmpty ? countdownText : 'SOON',
                      style: TextStyle(
                        fontSize: 11,
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
