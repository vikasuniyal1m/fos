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

  Future<void> submitForgotPassword() async {
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
      
      // Wait for 5 seconds as requested by the user
      await Future.delayed(const Duration(seconds: 5));

      // Navigate to ResetPasswordScreen
      print('🚀 Navigating to ResetPasswordScreen with: $input');
      Get.toNamed(Routes.RESET_PASSWORD, arguments: input);
    } on ApiException catch (e) {
      message.value = e.message;
    } catch (e) {
      message.value = 'Something went wrong. Please try again.';
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
