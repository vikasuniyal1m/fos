import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/controllers/forgot_password_controller.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';

class ForgotPasswordScreen extends GetView<ForgotPasswordController> {
  const ForgotPasswordScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        top: true,
        bottom: true,
        child: SingleChildScrollView(
          child: Padding(
            padding: ResponsiveHelper.safePadding(context, horizontal: ResponsiveHelper.isMobile(context) ? 16 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 12 : 16)),
                // Centered Title
                Center(
                  child: ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [const Color(0xFF8B4513), const Color(0xFFC79211)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                    child: Text(
                      "Forgot Password?",
                      textAlign: TextAlign.center,
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: ResponsiveHelper.fontSize(context, mobile: 26, tablet: 30, desktop: 34),
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ).copyWith(fontFamily: 'MontserratAlternates'),
                    ),
                  ),
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 4 : 6)),
                // Subtitle
                Center(
                  child: Text(
                    "Enter your email or phone to reset password",
                    textAlign: TextAlign.center,
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: ResponsiveHelper.fontSize(context, mobile: 13, tablet: 15, desktop: 17),
                      color: Colors.grey[700],
                    ).copyWith(fontFamily: 'MontserratAlternates'),
                  ),
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 24 : 30)),
                // Email/Phone Input
                TextFormField(
                  controller: controller.emailPhoneController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    hintText: "Email or Phone Number",
                    prefixIcon: const Icon(Icons.email, color: Color(0xFFC79211)),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
                      borderSide: BorderSide(color: const Color(0xFFC79211).withOpacity(0.3), width: 1.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
                      borderSide: BorderSide(color: const Color(0xFFC79211).withOpacity(0.3), width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
                      borderSide: BorderSide(color: const Color(0xFFC79211), width: ResponsiveHelper.spacing(context, 2.5)),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
                      borderSide: const BorderSide(color: Colors.red, width: 1.5),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
                      borderSide: BorderSide(color: Colors.red, width: ResponsiveHelper.spacing(context, 2.5)),
                    ),
                  ),
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 8 : 10)),
                // Info Text
                Text(
                  '* We will send you a message to set or reset your new password',
                  style: ResponsiveHelper.textStyle(
                    context,
                    fontSize: ResponsiveHelper.fontSize(context, mobile: 12, tablet: 13, desktop: 14),
                    color: Colors.grey[600],
                  ).copyWith(fontFamily: 'MontserratAlternates'),
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 24 : 28)),
                // Submit Button
                Obx(
                  () => SizedBox(
                    width: double.infinity,
                    height: ResponsiveHelper.buttonHeight(context, mobile: 48),
                    child: ElevatedButton(
                      onPressed: controller.isLoading.value
                          ? null
                          : () => controller.submitForgotPassword(),
                      style: ResponsiveHelper.adaptiveButtonStyle(
                        context,
                        backgroundColor: const Color(0xFF9F9467),
                        foregroundColor: Colors.white,
                      ).copyWith(
                        backgroundColor: MaterialStateProperty.resolveWith((states) {
                          if (states.contains(MaterialState.disabled)) {
                            return Colors.grey;
                          }
                          return const Color(0xFF9F9467);
                        }),
                        elevation: MaterialStateProperty.all(4),
                        shadowColor: MaterialStateProperty.all(const Color(0xFF9F9467).withOpacity(0.4)),
                        shape: MaterialStateProperty.all(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
                          ),
                        ),
                      ),
                      child: controller.isLoading.value
                          ? SizedBox(
                              height: ResponsiveHelper.iconSize(context, mobile: 20),
                              width: ResponsiveHelper.iconSize(context, mobile: 20),
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              "Submit",
                              style: ResponsiveHelper.textStyle(
                                context,
                                fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 18, desktop: 20),
                                fontWeight: FontWeight.bold,
                              ).copyWith(fontFamily: 'MontserratAlternates'),
                            ),
                    ),
                  ),
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 16 : 20)),
                // Message Display
                Obx(
                  () => controller.message.value.isNotEmpty
                      ? Container(
                          padding: ResponsiveHelper.padding(context, all: 12),
                          decoration: BoxDecoration(
                            color: controller.message.value.contains('sent')
                                ? Colors.green.withOpacity(0.1)
                                : Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                            border: Border.all(
                              color: controller.message.value.contains('sent')
                                  ? Colors.green.withOpacity(0.3)
                                  : Colors.red.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            controller.message.value,
                            textAlign: TextAlign.center,
                            style: ResponsiveHelper.textStyle(
                              context,
                              fontSize: ResponsiveHelper.fontSize(context, mobile: 13, tablet: 14, desktop: 15),
                              color: controller.message.value.contains('sent')
                                  ? Colors.green.shade800
                                  : Colors.red.shade800,
                            ).copyWith(fontFamily: 'MontserratAlternates'),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 16 : 20)),
                // Back to Login Link
                Center(
                  child: GestureDetector(
                    onTap: () {
                      Get.back(); // Navigate back to Login screen
                    },
                    child: Text(
                      "Back to Login",
                      style: TextStyle(
                        color: const Color(0xFF5C4033),
                        fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 16, desktop: 18),
                        fontWeight: FontWeight.bold,
                        fontFamily: 'MontserratAlternates',
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 16 : 20)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}