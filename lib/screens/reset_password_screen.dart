import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/controllers/reset_password_controller.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';

class ResetPasswordScreen extends StatelessWidget {
  const ResetPasswordScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Ensure fresh controller with arguments
    final controller = Get.put(ResetPasswordController());

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
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF8B4513), Color(0xFFC79211)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                    child: Text(
                      "Reset Password",
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
                    "Enter the OTP sent and your new password",
                    textAlign: TextAlign.center,
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: ResponsiveHelper.fontSize(context, mobile: 13, tablet: 15, desktop: 17),
                      color: Colors.grey[700],
                    ).copyWith(fontFamily: 'MontserratAlternates'),
                  ),
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 24 : 30)),
                
                // OTP Input
                TextFormField(
                  controller: controller.otpController,
                  keyboardType: TextInputType.number,
                  decoration: _buildInputDecoration(context, "OTP Code", Icons.lock_clock),
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                
                // New Password Input
                Obx(() => TextFormField(
                  controller: controller.newPasswordController,
                  obscureText: controller.obscureNewPassword.value,
                  decoration: _buildInputDecoration(
                    context, 
                    "New Password", 
                    Icons.lock_outline,
                    isPassword: true,
                    isObscured: controller.obscureNewPassword.value,
                    onToggle: () => controller.obscureNewPassword.toggle(),
                  ),
                )),
                SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                
                // Confirm Password Input
                Obx(() => TextFormField(
                  controller: controller.confirmPasswordController,
                  obscureText: controller.obscureConfirmPassword.value,
                  decoration: _buildInputDecoration(
                    context, 
                    "Confirm New Password", 
                    Icons.check_circle_outline,
                    isPassword: true,
                    isObscured: controller.obscureConfirmPassword.value,
                    onToggle: () => controller.obscureConfirmPassword.toggle(),
                  ),
                )),
                
                SizedBox(height: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 32 : 40)),
                
                // Reset Button
                Obx(
                  () => SizedBox(
                    width: double.infinity,
                    height: ResponsiveHelper.buttonHeight(context, mobile: 48),
                    child: ElevatedButton(
                      onPressed: controller.isLoading.value
                          ? null
                          : () => controller.resetPassword(),
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
                        shape: MaterialStateProperty.all(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
                          ),
                        ),
                      ),
                      child: controller.isLoading.value
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              "Reset Password",
                              style: ResponsiveHelper.textStyle(
                                context,
                                fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 18, desktop: 20),
                                fontWeight: FontWeight.bold,
                              ).copyWith(fontFamily: 'MontserratAlternates'),
                            ),
                    ),
                  ),
                ),
                SizedBox(height: ResponsiveHelper.spacing(context, 20)),
                // Back to Login Link
                Center(
                  child: TextButton(
                    onPressed: () => Get.back(),
                    child: Text(
                      "Back",
                      style: TextStyle(
                        color: const Color(0xFF5C4033),
                        fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 16, desktop: 18),
                        fontWeight: FontWeight.bold,
                        fontFamily: 'MontserratAlternates',
                      ),
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

  InputDecoration _buildInputDecoration(BuildContext context, String hint, IconData icon, {bool isPassword = false, bool isObscured = true, VoidCallback? onToggle}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: const Color(0xFFC79211)),
      suffixIcon: isPassword ? IconButton(
        icon: Icon(isObscured ? Icons.visibility_off : Icons.visibility, color: const Color(0xFFC79211)),
        onPressed: onToggle,
      ) : null,
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
        borderSide: const BorderSide(color: Color(0xFFC79211), width: 2.5),
      ),
    );
  }
}
