import 'package:get/get.dart';
import 'package:fruitsofspirit/services/prayer_reminders_service.dart';
import 'package:fruitsofspirit/services/user_storage.dart';

/// Prayer Reminders Controller
/// Manages prayer time reminder settings
class PrayerRemindersController extends GetxController {
  var reminderTimes = <String>[].obs;
  var enabled = true.obs;
  var isLoading = false.obs;
  var message = ''.obs;
  var userId = 0.obs;

  @override
  void onInit() {
    super.onInit();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    final id = await UserStorage.getUserId();
    if (id != null) {
      userId.value = id;
      await loadReminderSettings();
    }
  }

  /// Load reminder settings
  Future<void> loadReminderSettings() async {
    if (userId.value == 0) {
      await _loadUserId();
    }

    if (userId.value == 0) {
      message.value = 'Please login first';
      return;
    }

    isLoading.value = true;
    message.value = '';

    try {
      final settings = await PrayerRemindersService.getReminderSettings(
        userId: userId.value,
      );

      reminderTimes.value = List<String>.from(settings['reminder_times'] ?? []);
      enabled.value = (settings['enabled'] ?? 1) == 1;
    } catch (e) {
      message.value = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      print('Error loading reminder settings: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Save reminder settings
  Future<bool> saveReminderSettings() async {
    if (userId.value == 0) {
      await _loadUserId();
    }

    if (userId.value == 0) {
      message.value = 'Please login first';
      return false;
    }

    isLoading.value = true;
    message.value = 'Saving...';

    try {
      await PrayerRemindersService.setReminderTimes(
        userId: userId.value,
        reminderTimes: reminderTimes.toList(),
        enabled: enabled.value,
      );

      message.value = 'Prayer reminders saved successfully!';
      return true;
    } catch (e) {
      message.value = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      print('Error saving reminder settings: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Add reminder time
  void addReminderTime(String time) {
    if (!reminderTimes.contains(time)) {
      reminderTimes.add(time);
      reminderTimes.sort();
    }
  }

  /// Remove reminder time
  void removeReminderTime(String time) {
    reminderTimes.remove(time);
  }

  /// Toggle enabled status
  void toggleEnabled() {
    enabled.value = !enabled.value;
  }
}

