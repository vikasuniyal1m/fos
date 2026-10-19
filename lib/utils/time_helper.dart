/// TimeHelper — DB time unchanged (UTC). UI shows relative time in device timezone.
class TimeHelper {
  static const int editWindowMinutes = 15;

  /// MySQL `YYYY-MM-DD HH:MM:SS` or ISO `...Z` → device local [DateTime].
  static DateTime? toDeviceLocal(String? dateString) {
    if (dateString == null || dateString.isEmpty) return null;

    try {
      final value = dateString.trim();
      final DateTime utcInstant;

      if (value.endsWith('Z')) {
        utcInstant = DateTime.parse(value).toUtc();
      } else if (RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(value)) {
        utcInstant = DateTime.parse(value).toUtc();
      } else if (value.contains('T')) {
        utcInstant = DateTime.parse('${value}Z').toUtc();
      } else {
        // MySQL datetime from server — stored as UTC, not modified in DB
        utcInstant = DateTime.parse('${value.replaceAll(' ', 'T')}Z');
      }

      return utcInstant.toLocal();
    } catch (_) {
      return null;
    }
  }

  static Duration? _elapsed(String? dateString) {
    final eventLocal = toDeviceLocal(dateString);
    if (eventLocal == null) return null;

    final now = DateTime.now();
    var compare = eventLocal;
    if (eventLocal.isAfter(now)) {
      compare = now.subtract(const Duration(seconds: 1));
    }
    return now.difference(compare);
  }

  /// 15-minute edit window — timezone-safe (same instant math as getTimeAgo).
  static bool isWithinEditWindow(
    dynamic createdAt, {
    int windowMinutes = editWindowMinutes,
  }) {
    final elapsed = _elapsed(createdAt?.toString());
    if (elapsed == null) return false;
    return elapsed.inMinutes < windowMinutes;
  }

  static String getTimeAgo(String? dateString) {
    final elapsed = _elapsed(dateString);
    if (elapsed == null) return '';

    try {
      if (elapsed.inSeconds < 30) return 'Just now';

      final minutes = elapsed.inMinutes;
      if (minutes < 60) {
        return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
      }
      if (elapsed.inHours < 24) {
        final hours = elapsed.inHours;
        return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
      }
      if (elapsed.inDays < 30) {
        final days = elapsed.inDays;
        return '$days ${days == 1 ? 'day' : 'days'} ago';
      }
      if (elapsed.inDays < 365) {
        final months = (elapsed.inDays / 30).floor();
        return '$months ${months == 1 ? 'month' : 'months'} ago';
      }
      final years = (elapsed.inDays / 365).floor();
      return '$years ${years == 1 ? 'year' : 'years'} ago';
    } catch (_) {
      return 'Just now';
    }
  }
}
