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

  Future<void> resetPassword(BuildContext context, Function(String, String, {bool isError}) onShowSnackbar) async {
    final otp = otpController.text.trim();
    final newPassword = newPasswordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    if (otp.isEmpty) {
      onShowSnackbar('Error', 'Please enter the OTP sent to your phone/email', isError: true);
      return;
    }

    if (newPassword.isEmpty) {
      onShowSnackbar('Error', 'Please enter a new password', isError: true);
      return;
    }

    if (newPassword.length < 6) {
      onShowSnackbar('Error', 'Password must be at least 6 characters', isError: true);
      return;
    }

    if (newPassword != confirmPassword) {
      onShowSnackbar('Error', 'Passwords do not match', isError: true);
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

      onShowSnackbar('Success', result, isError: false);
      
      // Navigate to login after success
      Future.delayed(const Duration(seconds: 2), () {
        Get.offAllNamed(Routes.LOGIN);
      });
    } on ApiException catch (e) {
      onShowSnackbar('Error', e.message, isError: true);
    } catch (e) {
      onShowSnackbar('Error', 'Something went wrong. Please try again.', isError: true);
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
