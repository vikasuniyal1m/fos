/// TimeHelper utility for consistent time formatting across all screens
/// Provides reusable time formatting functions for relative time display
class TimeHelper {
  /// Format time ago - FIXED for proper relative time display
  /// FIXED to handle UTC backend times correctly and use DEVICE's CURRENT timezone
  /// Automatically detects user's current timezone regardless of device settings
  // static String getTimeAgo(String? dateString) {
  //   if (dateString == null || dateString.isEmpty) return '';
  //
  //   try {
  //     DateTime backendTime;
  //     print('🔍 TimeHelper.getTimeAgo parsing date: $dateString');
  //
  //     // CRITICAL FIX: Backend timestamps are in UTC
  //     // Convert them properly to DateTime objects
  //     if (dateString.contains('T')) {
  //       // ISO 8601 format
  //       if (dateString.endsWith('Z')) {
  //         backendTime = DateTime.parse(dateString); // Already UTC
  //       } else {
  //         // Treat non-Z ISO as UTC
  //         backendTime = DateTime.parse('${dateString}Z');
  //       }
  //     } else {
  //       // MySQL datetime format - treat as UTC (server stores UTC)
  //       // Parse as UTC by appending 'Z' or using toUtc()
  //       backendTime = DateTime.parse(dateString).toUtc();
  //     }
  //
  //     print('🔍 TimeHelper.getTimeAgo backend time (UTC): ${backendTime.toUtc()}');
  //
  //     // CRITICAL FIX: Get current time in device's ACTUAL timezone
  //     // This automatically detects user's current location timezone
  //     final nowDevice = DateTime.now();
  //     print('🕐 TimeHelper.getTimeAgo Current DEVICE time: ${nowDevice.toString()}');
  //     print('🌍 TimeHelper.getTimeAgo Device timezone: ${nowDevice.timeZoneName}');
  //     print('🌍 TimeHelper.getTimeAgo Timezone offset: ${nowDevice.timeZoneOffset}');
  //
  //     // Convert backend time to device's current timezone for accurate comparison
  //     final backendTimeDevice = backendTime.toLocal();
  //     print('🔍 TimeHelper.getTimeAgo backend time (DEVICE): ${backendTimeDevice.toString()}');
  //
  //     // Ensure date is not in future (compare with device time)
  //     var compareTime = backendTimeDevice;
  //     if (backendTimeDevice.isAfter(nowDevice)) {
  //       print('⚠️ TimeHelper.getTimeAgo Future timestamp detected, clamping to now');
  //       compareTime = nowDevice.subtract(const Duration(seconds: 1));
  //     }
  //
  //     final difference = nowDevice.difference(compareTime);
  //     final minutes = difference.inMinutes;
  //     print('🔍 TimeHelper.getTimeAgo difference: $minutes minutes (${difference.inHours} hours, ${difference.inDays} days)');
  //     print('🌍 TimeHelper.getTimeAgo User is in timezone: ${nowDevice.timeZoneName} (${nowDevice.timeZoneOffset.inHours} hours from UTC)');
  //
  //     String result;
  //     if (minutes < 1) {
  //       result = 'Just now';
  //     } else if (minutes < 60) {
  //       result = '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
  //     } else if (difference.inHours < 24) {
  //       final hours = difference.inHours;
  //       result = '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
  //     } else if (difference.inDays < 30) {
  //       final days = difference.inDays;
  //       result = '$days ${days == 1 ? 'day' : 'days'} ago';
  //     } else if (difference.inDays < 365) {
  //       final months = (difference.inDays / 30).floor();
  //       result = '$months ${months == 1 ? 'month' : 'months'} ago';
  //     } else {
  //       final years = (difference.inDays / 365).floor();
  //       result = '$years ${years == 1 ? 'year' : 'years'} ago';
  //     }
  //
  //     print('🔍 TimeHelper.getTimeAgo FINAL RESULT: $result');
  //     return result;
  //   } catch (e) {
  //     print('❌ TimeHelper.getTimeAgo error: $e');
  //     return 'Just now';
  //   }
  // }

  static String getTimeAgo(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '';

    try {
      String formattedDate = dateString;
      if (!dateString.contains('Z') && !dateString.contains('+')) {
        formattedDate = dateString.replaceAll(' ', 'T') + 'Z';
      }

      DateTime serverTimeUtc = DateTime.parse(formattedDate).toUtc();
      DateTime nowUtc = DateTime.now().toUtc();

      // --- FIX START ---
      // Agar server hamesha 4 ghante piche hai, toh usmein 4 hours add karo
      // Isse server ka time aapke phone ke time ke barabar aa jayega
      serverTimeUtc = serverTimeUtc.add(const Duration(hours: 4));
      // --- FIX END ---

      final difference = nowUtc.difference(serverTimeUtc);

      // Agar difference negative hai (future time), toh 'Just now' dikhao
      if (difference.isNegative || difference.inSeconds < 30) return 'Just now';

      int minutes = difference.inMinutes;
      if (minutes < 60) return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';

      int hours = difference.inHours;
      if (hours < 24) return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';

      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';

    } catch (e) {
      return 'Just now';
    }
  }
  /// Get India time (IST) from timestamp
  /// Converts UTC timestamp to India Standard Time (UTC+5:30)
/*  static String getIndiaTime(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '';

    try {
      DateTime date;
      // Handle different timestamp formats
      if (dateString.contains('T')) {
        // ISO 8601 format
        date = DateTime.parse(dateString);
      } else {
        // Try parsing as standard MySQL datetime format
        date = DateTime.parse('${dateString}Z');
      }

      // Convert to India time (IST = UTC+5:30)
      final indiaTimeZone = Duration(hours: 5, minutes: 30);
      final indiaTime = date.toUtc().add(indiaTimeZone);

      // Format as HH:MM AM/PM
      final hour = indiaTime.hour;
      final minute = indiaTime.minute;
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      final displayMinute = minute.toString().padLeft(2, '0');

      return '$displayHour:$displayMinute $period IST';
    } catch (e) {
      print('❌ TimeHelper.getIndiaTime error: $e');
      return '';
    }
  }*/
}
