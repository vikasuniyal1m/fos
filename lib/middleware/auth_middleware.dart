import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/services/user_storage.dart';
import 'package:fruitsofspirit/routes/routes.dart';

/// Authentication Middleware
/// Protects routes that require authentication
class AuthMiddleware extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    // Routes that don't require authentication
    final publicRoutes = [
      Routes.SPLASH,
      Routes.LOGIN,
      Routes.ONBOARDING,
      Routes.CREATE_ACCOUNT,
      Routes.PHONE_AUTH,
      Routes.FORGOT_PASSWORD,
    ];

    // If route is public, allow access
    if (publicRoutes.contains(route)) {
      return null;
    }

    // Check if user is logged in
    // Note: This is synchronous check, for async we need to handle differently
    // For now, we'll check in the screen itself
    return null; // Allow navigation, screen will check auth
  }

  @override
  GetPage? onPageCalled(GetPage? page) {
    // This is called before the page is built
    // We can add async auth check here if needed
    return page;
  }
}

