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

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    // Making ALL core controllers permanent to prevent "not found" errors
    // throughout the app lifecycle.
    Get.put(HomeController(), permanent: true);
    Get.put(PrayersController(), permanent: true);
    Get.put(GroupsController(), permanent: true);
    Get.put(NotificationsController(), permanent: true);
    Get.put(ProfileController(), permanent: true);
    Get.put(FruitsController(), permanent: true);
    Get.put(BlogsController(), permanent: true);
    Get.put(VideosController(), permanent: true);
    Get.put(GalleryController(), permanent: true);
    Get.put(MainDashboardController(), permanent: true);

    // Voice Over Service
    Get.put(JingleService(), permanent: true);
  }
}
