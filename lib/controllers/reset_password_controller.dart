import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/services/auth_service.dart';
import 'package:fruitsofspirit/services/api_service.dart';
import 'package:fruitsofspirit/routes/routes.dart';

class ResetPasswordController extends GetxController {
  final TextEditingController otpController = TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  
  var isLoading = false.obs;
  var obscureNewPassword = true.obs;
  var obscureConfirmPassword = true.obs;
  
  String get emailOrPhone => Get.arguments ?? '';

  void resetPassword() async {
    final otp = otpController.text.trim();
    final newPassword = newPasswordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    if (otp.isEmpty) {
      Get.snackbar('Error', 'Please enter the OTP sent to your phone/email', 
        snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red.withOpacity(0.8), colorText: Colors.white);
      return;
    }

    if (newPassword.isEmpty) {
      Get.snackbar('Error', 'Please enter a new password', 
        snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red.withOpacity(0.8), colorText: Colors.white);
      return;
    }

    if (newPassword.length < 6) {
      Get.snackbar('Error', 'Password must be at least 6 characters', 
        snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red.withOpacity(0.8), colorText: Colors.white);
      return;
    }

    if (newPassword != confirmPassword) {
      Get.snackbar('Error', 'Passwords do not match', 
        snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red.withOpacity(0.8), colorText: Colors.white);
      return;
    }

    isLoading.value = true;

    try {
      final isEmail = emailOrPhone.contains('@');
      String result;
      
      if (isEmail) {
        result = await AuthService.verifyOtpAndResetPassword(
          email: emailOrPhone,
          otp: otp,
          newPassword: newPassword,
        );
      } else {
        result = await AuthService.verifyOtpAndResetPassword(
          phone: emailOrPhone,
          otp: otp,
          newPassword: newPassword,
        );
      }

      Get.snackbar('Success', result, 
        snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.green.withOpacity(0.8), colorText: Colors.white);
      
      // Navigate to login after success
      Future.delayed(const Duration(seconds: 2), () {
        Get.offAllNamed(Routes.LOGIN);
      });
    } on ApiException catch (e) {
      Get.snackbar('Error', e.message, 
        snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red.withOpacity(0.8), colorText: Colors.white);
    } catch (e) {
      Get.snackbar('Error', 'Something went wrong. Please try again.', 
        snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red.withOpacity(0.8), colorText: Colors.white);
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    otpController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }
}
