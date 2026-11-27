import 'package:get/get.dart';
import '../services/christian_calendar_service.dart';

/// Controller for Calendar Banner Widget
/// Manages upcoming festival data and countdown
class CalendarBannerController extends GetxController {
  // Observable data
  final RxList<Map<String, dynamic>> upcomingEvents = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> todayEvents = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchUpcomingEvents();
    startCountdownTimer();
  }

  @override
  void onClose() {
    super.onClose();
  }

  /// Start countdown timer that updates every second
  void startCountdownTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (Get.isRegistered<CalendarBannerController>()) {
        update(); // Trigger UI update
        return true;
      }
      return false;
    });
  }

  /// Fetch upcoming events from API
  Future<void> fetchUpcomingEvents() async {
    isLoading.value = true;
    print('CalendarBannerController: Fetching events...');
    try {
      final events = await ChristianCalendarService.getUpcomingEvents(limit: 30);
      print('CalendarBannerController: Got ${events.length} events');
      
      // Separate today's events from upcoming
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      final List<Map<String, dynamic>> todayList = [];
      final List<Map<String, dynamic>> upcomingList = [];
      
      for (final event in events) {
        final dateStr = event['date']?.toString();
        if (dateStr != null && dateStr.isNotEmpty) {
          try {
            final eventDate = DateTime.parse(dateStr);
            final eventDay = DateTime(eventDate.year, eventDate.month, eventDate.day);
            
            if (eventDay.isAtSameMomentAs(today)) {
              todayList.add(event);
            } else if (eventDay.isAfter(today)) {
              upcomingList.add(event);
            }
          } catch (e) {
            // Invalid date format, treat as upcoming
            upcomingList.add(event);
          }
        } else {
          upcomingList.add(event);
        }
      }
      
      todayEvents.value = todayList;
      upcomingEvents.value = upcomingList;
      
      print('CalendarBannerController: Today: ${todayList.length}, Upcoming: ${upcomingList.length}');
    } catch (e) {
      print('CalendarBannerController: Error fetching events: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Get event icon
  String getEventIcon(String? category, String? title) {
    return ChristianCalendarService.getEventIcon(category ?? '', title ?? '');
  }

  /// Get event color
  int getEventColor(String? category, String? title) {
    return ChristianCalendarService.getEventColor(category ?? '', title ?? '');
  }

  /// Format date for display
  String formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${date.day} ${months[date.month - 1]}, ${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  /// Check if has any events to show (today or upcoming)
  bool get hasAnyEvents => todayEvents.isNotEmpty || upcomingEvents.isNotEmpty;
}
