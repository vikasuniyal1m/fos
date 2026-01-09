import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';
import 'package:fruitsofspirit/controllers/phone_auth_controller.dart';

class PhoneAuthScreen extends StatelessWidget {
  const PhoneAuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final PhoneAuthController controller = Get.put(PhoneAuthController());

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: SafeArea(
        top: true,
        bottom: true,
        child: SingleChildScrollView(
          child: Padding(
            padding: ResponsiveHelper.safePadding(context, horizontal: 16, vertical: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: ResponsiveHelper.spacing(context, 20)),
                Text(
                  "OTP Authentication",
                  style: ResponsiveHelper.textStyle(
                    context,
                    fontSize: ResponsiveHelper.isMobile(context) ? 32 : 36,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF5C4033),
                  ).copyWith(fontFamily: 'MontserratAlternates'),
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, 10)),
                Obx(
                  () => Text(
                    controller.otpSent.value
                        ? "Please enter the 6-digit code sent to your email/phone."
                        : "Enter your email or phone number to receive a verification code.",
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: ResponsiveHelper.isMobile(context) ? 14 : 16,
                      color: Colors.grey,
                    ).copyWith(fontFamily: 'MontserratAlternates'),
                  ),
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, 40)),
                Obx(
                  () => controller.otpSent.value
                      ? Column(
                          children: [
                            TextFormField(
                              controller: controller.otpController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              decoration: InputDecoration(
                                hintText: 'Enter OTP',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 10)),
                                  borderSide: const BorderSide(color: Color(0xFFC79211)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 10)),
                                  borderSide: const BorderSide(color: Color(0xFFC79211)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 10)),
                                  borderSide: BorderSide(color: const Color(0xFFC79211), width: ResponsiveHelper.spacing(context, 2)),
                                ),
                              ),
                            ),
                            SizedBox(height: ResponsiveHelper.spacing(context, 40)),
                            SizedBox(
                              width: double.infinity,
                              height: ResponsiveHelper.buttonHeight(context, mobile: 50),
                              child: ElevatedButton(
                                onPressed: controller.isLoading.value ? null : controller.signInWithPhoneNumber,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: controller.isLoading.value ? Colors.grey : const Color(0xFF9F9467),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 10)),
                                  ),
                                ),
                                child: controller.isLoading.value
                                    ? const CircularProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      )
                                    : Text(
                                        'Verify OTP',
                                        style: ResponsiveHelper.textStyle(
                                          context,
                                          fontSize: ResponsiveHelper.isMobile(context) ? 16 : 18,
                                        ).copyWith(fontFamily: 'MontserratAlternates'),
                                      ),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            TextFormField(
                              controller: controller.emailOrPhoneController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                hintText: 'Email or Phone (e.g., user@example.com or +15551234567)',
                                prefixIcon: const Icon(Icons.email, color: Color(0xFFC79211)),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 10)),
                                  borderSide: const BorderSide(color: Color(0xFFC79211)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 10)),
                                  borderSide: const BorderSide(color: Color(0xFFC79211)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 10)),
                                  borderSide: BorderSide(color: const Color(0xFFC79211), width: ResponsiveHelper.spacing(context, 2)),
                                ),
                              ),
                            ),
                            SizedBox(height: ResponsiveHelper.spacing(context, 40)),
                            SizedBox(
                              width: double.infinity,
                              height: ResponsiveHelper.buttonHeight(context, mobile: 50),
                              child: ElevatedButton(
                                onPressed: controller.isLoading.value ? null : controller.verifyPhoneNumber,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: controller.isLoading.value ? Colors.grey : const Color(0xFF9F9467),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 10)),
                                  ),
                                ),
                                child: controller.isLoading.value
                                    ? const CircularProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      )
                                    : Text(
                                        'Send OTP',
                                        style: ResponsiveHelper.textStyle(
                                          context,
                                          fontSize: ResponsiveHelper.isMobile(context) ? 16 : 18,
                                        ).copyWith(fontFamily: 'MontserratAlternates'),
                                      ),
                              ),
                            ),
                          ],
                        ),
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, 20)),
                Obx(
                  () => Center(
                    child: Text(
                      controller.message.value,
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: ResponsiveHelper.isMobile(context) ? 14 : 16,
                        color: controller.message.value.startsWith('Error') || controller.message.value.startsWith('Verification Failed') || controller.message.value.startsWith('Sign In Failed')
                            ? Colors.red
                            : Colors.green,
                      ).copyWith(fontFamily: 'MontserratAlternates'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}