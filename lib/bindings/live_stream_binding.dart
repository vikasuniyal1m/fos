import 'package:get/get.dart';
import 'package:fruitsofspirit/controllers/live_stream_controller.dart';

class LiveStreamBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<LiveStreamController>(LiveStreamController(), permanent: false);
  }
}
