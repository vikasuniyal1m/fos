import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/services/auth_service.dart';
import 'package:fruitsofspirit/services/api_service.dart';
import 'package:fruitsofspirit/routes/routes.dart';
import 'package:fruitsofspirit/screens/reset_password_screen.dart';

class ForgotPasswordController extends GetxController {
  final TextEditingController emailPhoneController = TextEditingController();
  var isLoading = false.obs;
  var message = ''.obs;

  void submitForgotPassword() async {
    if (emailPhoneController.text.trim().isEmpty) {
      message.value = 'Please enter your email or phone number.';
      return;
    }

    isLoading.value = true;
    message.value = '';

    try {
      final input = emailPhoneController.text.trim();
      final isEmail = input.contains('@');

      String successMessage;
      if (isEmail) {
        successMessage = await AuthService.forgotPassword(email: input);
      } else {
        successMessage = await AuthService.forgotPassword(phone: input);
      }

      message.value = successMessage;
      Get.snackbar(
        'Success',
        successMessage,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.withOpacity(0.8),
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );

      // Navigate to ResetPasswordScreen immediately
      print('🚀 Navigating to ResetPasswordScreen with: $input');
      Get.toNamed(Routes.RESET_PASSWORD, arguments: input);
    } on ApiException catch (e) {
      message.value = e.message;
      Get.snackbar(
        'Error',
        e.message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      message.value = 'Something went wrong. Please try again.';
      Get.snackbar(
        'Error',
        'Something went wrong. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    emailPhoneController.dispose();
    super.onClose();
  }
}
