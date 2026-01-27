import 'package:fruitsofspirit/controllers/gallery_controller.dart';
import 'package:fruitsofspirit/controllers/profile_controller.dart';
import 'package:fruitsofspirit/controllers/videos_controller.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/controllers/home_controller.dart';
import 'package:fruitsofspirit/controllers/fruits_controller.dart';
import 'package:fruitsofspirit/controllers/blogs_controller.dart';
import 'package:fruitsofspirit/controllers/prayers_controller.dart';
import 'package:fruitsofspirit/controllers/groups_controller.dart';
import 'package:fruitsofspirit/controllers/notifications_controller.dart';
import 'package:fruitsofspirit/controllers/main_dashboard_controller.dart';
import 'package:fruitsofspirit/services/jingle_service.dart';

// New Imports
import 'package:fruitsofspirit/controllers/group_chat_controller.dart';
import 'package:fruitsofspirit/controllers/group_posts_controller.dart';
import 'package:fruitsofspirit/controllers/prayer_reminders_controller.dart';
import 'package:fruitsofspirit/controllers/onboarding_controller.dart';
import 'package:fruitsofspirit/controllers/phone_auth_controller.dart';
import 'package:fruitsofspirit/controllers/forgot_password_controller.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    // Making ALL core controllers permanent to prevent "not found" errors
    // throughout the app lifecycle.

    // 1. Core Controllers
    if (!Get.isRegistered<HomeController>()) {
      Get.put(HomeController(), permanent: true);
    }
    if (!Get.isRegistered<MainDashboardController>()) {
      Get.put(MainDashboardController(), permanent: true);
    }
    if (!Get.isRegistered<NotificationsController>()) {
      Get.put(NotificationsController(), permanent: true);
    }
    if (!Get.isRegistered<ProfileController>()) {
      Get.put(ProfileController(), permanent: true);
    }

    // 2. Feature Controllers
    if (!Get.isRegistered<PrayersController>()) {
      Get.put(PrayersController(), permanent: true);
    }
    if (!Get.isRegistered<PrayerRemindersController>()) {
      Get.put(PrayerRemindersController(), permanent: true);
    }
    if (!Get.isRegistered<GroupsController>()) {
      Get.put(GroupsController(), permanent: true);
    }
    if (!Get.isRegistered<GroupChatController>()) {
      Get.put(GroupChatController(), permanent: true);
    }
    if (!Get.isRegistered<GroupPostsController>()) {
      Get.put(GroupPostsController(), permanent: true);
    }
    if (!Get.isRegistered<FruitsController>()) {
      Get.put(FruitsController(), permanent: true);
    }
    if (!Get.isRegistered<BlogsController>()) {
      Get.put(BlogsController(), permanent: true);
    }
    if (!Get.isRegistered<VideosController>()) {
      Get.put(VideosController(), permanent: true);
    }
    if (!Get.isRegistered<GalleryController>()) {
      Get.put(GalleryController(), permanent: true);
    }

    // 3. Auth & Onboarding Controllers
    if (!Get.isRegistered<OnboardingController>()) {
      Get.put(OnboardingController(), permanent: true);
    }
    if (!Get.isRegistered<PhoneAuthController>()) {
      Get.put(PhoneAuthController(), permanent: true);
    }
    if (!Get.isRegistered<ForgotPasswordController>()) {
      Get.put(ForgotPasswordController(), permanent: true);
    }

    // Voice Over Service
    if (!Get.isRegistered<JingleService>()) {
      Get.put(JingleService(), permanent: true);
    }
  }
}
