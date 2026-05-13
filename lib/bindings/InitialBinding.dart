import 'package:fruitsofspirit/controllers/gallery_controller.dart';
import 'package:fruitsofspirit/controllers/profile_controller.dart';
import 'package:fruitsofspirit/controllers/videos_controller.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/controllers/home_controller.dart';
import 'package:fruitsofspirit/controllers/fruit_controller.dart';
import 'package:fruitsofspirit/controllers/blogs_controller.dart';
import 'package:fruitsofspirit/controllers/prayers_controller.dart';
import 'package:fruitsofspirit/controllers/groups_controller.dart';
import 'package:fruitsofspirit/controllers/notifications_controller.dart';
import 'package:fruitsofspirit/controllers/main_dashboard_controller.dart';
import 'package:fruitsofspirit/controllers/banners_controller.dart';
import 'package:fruitsofspirit/services/jingle_service.dart';
import 'package:fruitsofspirit/controllers/group_chat_controller.dart';
import 'package:fruitsofspirit/controllers/group_posts_controller.dart';
import 'package:fruitsofspirit/controllers/prayer_reminders_controller.dart';
import 'package:fruitsofspirit/controllers/onboarding_controller.dart';
import 'package:fruitsofspirit/controllers/phone_auth_controller.dart';
import 'package:fruitsofspirit/controllers/forgot_password_controller.dart';
import 'package:fruitsofspirit/controllers/reset_password_controller.dart';
import 'package:fruitsofspirit/controllers/church_locator_controller.dart';
import 'package:fruitsofspirit/controllers/denominations_controller.dart';
import 'package:fruitsofspirit/controllers/live_stream_controller.dart';
import 'package:fruitsofspirit/services/iap_service.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    // 1. Core Controllers
    if (!Get.isRegistered<HomeController>()) {
      Get.put(HomeController(), permanent: true);
    }
    if (!Get.isRegistered<MainDashboardController>()) {
      Get.put(MainDashboardController(), permanent: true);
    }
    if (!Get.isRegistered<ProfileController>()) {
      Get.put(ProfileController(), permanent: true);
    }

    // 2. Feature Controllers (Lazy loading with fenix:true for auto-recreation after deletion)
    if (!Get.isRegistered<NotificationsController>()) {
      Get.lazyPut(() => NotificationsController(), fenix: true);
    }
    if (!Get.isRegistered<PrayersController>()) {
      Get.lazyPut(() => PrayersController(), fenix: true);
    }
    if (!Get.isRegistered<PrayerRemindersController>()) {
      Get.lazyPut(() => PrayerRemindersController(), fenix: true);
    }
    if (!Get.isRegistered<GroupsController>()) {
      Get.lazyPut(() => GroupsController(), fenix: true);
    }
    if (!Get.isRegistered<GroupChatController>()) {
      Get.lazyPut(() => GroupChatController(), fenix: true);
    }
    if (!Get.isRegistered<GroupPostsController>()) {
      Get.lazyPut(() => GroupPostsController(), fenix: true);
    }
    if (!Get.isRegistered<FruitController>()) {
      Get.lazyPut(() => FruitController(), fenix: true);
    }
    if (!Get.isRegistered<BlogsController>()) {
      Get.lazyPut(() => BlogsController(), fenix: true);
    }
    if (!Get.isRegistered<VideosController>()) {
      Get.lazyPut(() => VideosController(), fenix: true);
    }
    if (!Get.isRegistered<GalleryController>()) {
      Get.lazyPut(() => GalleryController(), fenix: true);
    }
    if (!Get.isRegistered<BannersController>()) {
      Get.put(BannersController(), permanent: true);
    }

    // 3. Auth & Onboarding Controllers
    if (!Get.isRegistered<OnboardingController>()) {
      Get.lazyPut(() => OnboardingController(), fenix: true);
    }
    if (!Get.isRegistered<PhoneAuthController>()) {
      Get.lazyPut(() => PhoneAuthController(), fenix: true);
    }
    if (!Get.isRegistered<ForgotPasswordController>()) {
      Get.lazyPut(() => ForgotPasswordController(), fenix: true);
    }
    if (!Get.isRegistered<ResetPasswordController>()) {
      Get.lazyPut(() => ResetPasswordController(), fenix: true);
    }

    // 4. Additional Feature Controllers
    if (!Get.isRegistered<ChurchLocatorController>()) {
      Get.lazyPut(() => ChurchLocatorController(), fenix: true);
    }
    if (!Get.isRegistered<DenominationsController>()) {
      Get.lazyPut(() => DenominationsController(), fenix: true);
    }
    if (!Get.isRegistered<LiveStreamController>()) {
      Get.lazyPut(() => LiveStreamController(), fenix: true);
    }

    // 5. Services
    if (!Get.isRegistered<JingleService>()) {
      Get.put(JingleService(), permanent: true);
    }

    final iap = Get.isRegistered<IAPService>()
        ? Get.find<IAPService>()
        : Get.put(IAPService(), permanent: true);
    iap.initialize();
  }
}
