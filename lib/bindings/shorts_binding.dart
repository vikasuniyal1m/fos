import 'package:get/get.dart';
import 'package:fruitsofspirit/controllers/shorts_controller.dart';

class ShortsBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<ShortsController>()) {
      Get.lazyPut(() => ShortsController(), fenix: true);
    }
  }
}
