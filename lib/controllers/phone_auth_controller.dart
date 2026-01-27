import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../routes/app_pages.dart';
import '../services/auth_service.dart';
import '../services/user_storage.dart';

class PhoneAuthController extends GetxController {
  final TextEditingController emailOrPhoneController = TextEditingController();
  final TextEditingController otpController = TextEditingController();

  var otpSent = false.obs;
  var isLoading = false.obs;
  var message = ''.obs;

  @override
  void onClose() {
    emailOrPhoneController.dispose();
    otpController.dispose();
    super.onClose();
  }

  /// Check if input is email or phone
  bool _isEmail(String input) {
    return input.contains('@') && input.contains('.');
  }

  /// Send OTP to email or phone number
  Future<void> verifyPhoneNumber() async {
    if (emailOrPhoneController.text.trim().isEmpty) {
      message.value = 'Please enter your email or phone number';
      return;
    }

    isLoading.value = true;
    message.value = '';

    try {
      final input = emailOrPhoneController.text.trim();
      final isEmail = _isEmail(input);
      
      if (isEmail) {
        await AuthService.forgotPassword(email: input);
      } else {
        await AuthService.forgotPassword(phone: input);
      }
      
      otpSent.value = true;
      isLoading.value = false;
      message.value = 'OTP sent to ${emailOrPhoneController.text}';
    } catch (e) {
      isLoading.value = false;
      message.value = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      print('OTP Send Error: $e');
    }
  }

  /// Verify OTP and login/register
  Future<void> signInWithPhoneNumber() async {
    if (otpController.text.trim().isEmpty) {
      message.value = 'Please enter the OTP';
      return;
    }

    if (otpController.text.trim().length != 6) {
      message.value = 'OTP must be 6 digits';
      return;
    }

    isLoading.value = true;
    message.value = '';

    try {
      final input = emailOrPhoneController.text.trim();
      final isEmail = _isEmail(input);
      
      // Verify OTP and login/register
      final user = await AuthService.phoneOtpLogin(
        email: isEmail ? input : null,
        phone: isEmail ? null : input,
        otp: otpController.text.trim(),
      );

      // Save user data
      await UserStorage.saveUser(user);

      isLoading.value = false;
      message.value = 'Authentication successful!';
      
      // Navigate to home
      Get.offAllNamed(Routes.DASHBOARD);
    } catch (e) {
      isLoading.value = false;
      message.value = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      print('OTP Login Error: $e');
    }
  }
}
