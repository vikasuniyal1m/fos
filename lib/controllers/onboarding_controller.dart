import 'package:get/get.dart';

class OnboardingController extends GetxController {
  var currentPage = 0.obs;

  void nextPage() {
    if (currentPage.value < 3) { // Assuming 4 onboarding pages (0-3)
      currentPage.value++;
    }
  }

  void previousPage() {
    if (currentPage.value > 0) {
      currentPage.value--;
    }
  }

  void skipOnboarding() {
    // Navigate to login or home page
    Get.offAllNamed('/login'); // Or '/home' depending on the flow
  }

  void getStarted() {
    // Navigate to login or home page after onboarding is complete
    Get.offAllNamed('/login'); // Or '/home'
  }
}