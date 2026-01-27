import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:io' show Platform;
import 'package:fruitsofspirit/utils/responsive_helper.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:fruitsofspirit/services/auth_service.dart';
import 'package:fruitsofspirit/services/user_storage.dart';
import 'package:fruitsofspirit/services/api_service.dart';
import 'package:fruitsofspirit/routes/routes.dart';
import 'package:fruitsofspirit/services/intro_service.dart';

import '../utils/app_theme.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({Key? key}) : super(key: key);

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _agreeToTerms = false;
  bool _isLoading = false;
  String _selectedRole = 'User'; // Default role: User or Blogger
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_agreeToTerms) {
      Get.snackbar(
        'Terms Required',
        'Please accept Terms & Conditions',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange.withOpacity(0.8),
        colorText: Colors.white,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final email = _emailController.text.trim();
      final phone = _phoneController.text.trim();
      
      if (email.isEmpty && phone.isEmpty) {
        throw ApiException('Email or phone is required');
      }

      Map<String, dynamic> user = await AuthService.register(
        name: _nameController.text.trim(),
        email: email.isNotEmpty ? email : null,
        phone: phone.isNotEmpty ? phone : null,
        password: _passwordController.text,
        confirmPassword: _confirmPasswordController.text,
        acceptTerms: _agreeToTerms,
        requestedRole: _selectedRole, // User or Blogger
      );

      // If Blogger role was selected, show approval message
      if (_selectedRole == 'Blogger') {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text(
                  'Registration Successful',
                  style: ResponsiveHelper.textStyle(
                    context,
                    fontSize: ResponsiveHelper.isMobile(context) ? 18 : 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your account has been registered successfully!',
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: ResponsiveHelper.isMobile(context) ? 14 : 16,
                      ),
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(context, 10)),
                    Container(
                      padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 10)),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.orange,
                            size: ResponsiveHelper.iconSize(context, mobile: 20),
                          ),
                          SizedBox(width: ResponsiveHelper.spacing(context, 10)),
                          Expanded(
                            child: Text(
                              'Your Blogger role request is pending admin approval. Please wait for approval before you can login.',
                              style: ResponsiveHelper.textStyle(
                                context,
                                fontSize: ResponsiveHelper.isMobile(context) ? 12 : 14,
                                color: Colors.orange.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Close dialog
                      Get.offAllNamed(Routes.LOGIN); // Go to login page
                    },
                    child: Text(
                      'OK',
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: ResponsiveHelper.isMobile(context) ? 14 : 16,
                        color: const Color(0xFFC79211),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        }
      } else {
        // Regular user - save and go to home
        await UserStorage.saveUser(user);
        if (mounted) {
          Get.offAllNamed(Routes.DASHBOARD);
        }
      }
    } on ApiException catch (e) {
      // Log server error to console (for debugging)
      print('❌ Registration API Error: ${e.message}');
      print('❌ Error Details: ${e.toString()}');
      
      if (mounted) {
        // Parse error message and show professional, user-friendly messages
        String errorTitle = 'Registration Failed';
        String errorMessage = 'Unable to create account. Please try again.';
        
        // Check for specific error types and show appropriate messages
        final errorLower = e.message.toLowerCase();
        
        if (errorLower.contains('email') && (errorLower.contains('already') || errorLower.contains('exists') || errorLower.contains('taken'))) {
          errorTitle = 'Email Already Registered';
          errorMessage = 'This email address is already registered. Please use a different email or try logging in.';
        } else if (errorLower.contains('phone') && (errorLower.contains('already') || errorLower.contains('exists') || errorLower.contains('taken'))) {
          errorTitle = 'Phone Already Registered';
          errorMessage = 'This phone number is already registered. Please use a different phone number or try logging in.';
        } else if (errorLower.contains('password') && (errorLower.contains('weak') || errorLower.contains('short') || errorLower.contains('invalid'))) {
          errorTitle = 'Weak Password';
          errorMessage = 'Password is too weak. Please use a stronger password with at least 6 characters.';
        } else if (errorLower.contains('password') && errorLower.contains('match')) {
          errorTitle = 'Password Mismatch';
          errorMessage = 'Passwords do not match. Please make sure both password fields are the same.';
        } else if (errorLower.contains('name') && (errorLower.contains('required') || errorLower.contains('empty'))) {
          errorTitle = 'Name Required';
          errorMessage = 'Please enter your full name to continue.';
        } else if (errorLower.contains('terms') || errorLower.contains('accept')) {
          errorTitle = 'Terms Required';
          errorMessage = 'Please accept the Terms & Conditions to create an account.';
        } else if (errorLower.contains('validation') || errorLower.contains('invalid')) {
          errorTitle = 'Invalid Information';
          errorMessage = 'Please check all fields and ensure they are filled correctly.';
        } else {
          // Generic error - don't show server message to user
          errorMessage = 'Unable to create account. Please check your information and try again.';
        }
        
        Get.snackbar(
          errorTitle,
          errorMessage,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.withOpacity(0.9),
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
          margin: EdgeInsets.all(ResponsiveHelper.spacing(context, 16)),
          borderRadius: ResponsiveHelper.borderRadius(context, mobile: 12),
          icon: Icon(
            Icons.error_outline,
            color: Colors.white,
            size: ResponsiveHelper.iconSize(context, mobile: 24),
          ),
          shouldIconPulse: true,
          isDismissible: true,
          dismissDirection: DismissDirection.horizontal,
        );
      }
    } on NetworkException catch (e) {
      // Log network error to console
      print('❌ Registration Network Error: ${e.message}');
      
      if (mounted) {
        Get.snackbar(
          'Connection Error',
          'No internet connection. Please check your network settings and try again.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange.withOpacity(0.9),
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
          margin: EdgeInsets.all(ResponsiveHelper.spacing(context, 16)),
          borderRadius: ResponsiveHelper.borderRadius(context, mobile: 12),
          icon: Icon(
            Icons.wifi_off,
            color: Colors.white,
            size: ResponsiveHelper.iconSize(context, mobile: 24),
          ),
          shouldIconPulse: true,
          isDismissible: true,
          dismissDirection: DismissDirection.horizontal,
        );
      }
    } catch (e) {
      // Log unexpected error to console
      print('❌ Registration Unexpected Error: ${e.toString()}');
      print('❌ Error Type: ${e.runtimeType}');
      
      if (mounted) {
        Get.snackbar(
          'Registration Failed',
          'An unexpected error occurred. Please try again. If the problem persists, contact support.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.withOpacity(0.9),
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
          margin: EdgeInsets.all(ResponsiveHelper.spacing(context, 16)),
          borderRadius: ResponsiveHelper.borderRadius(context, mobile: 12),
          icon: Icon(
            Icons.warning_amber_rounded,
            color: Colors.white,
            size: ResponsiveHelper.iconSize(context, mobile: 24),
          ),
          shouldIconPulse: true,
          isDismissible: true,
          dismissDirection: DismissDirection.horizontal,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signInWithApple() async {
    // Check if Sign in with Apple is available (iOS 13+)
    if (!Platform.isIOS) {
      Get.snackbar(
        'Not Available',
        'Sign in with Apple is only available on iOS devices.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange.withOpacity(0.9),
        colorText: Colors.white,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Request Apple Sign In
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      // Extract user information
      final appleId = appleCredential.userIdentifier ?? '';
      final email = appleCredential.email;
      final givenName = appleCredential.givenName;
      final familyName = appleCredential.familyName;
      final fullName = [givenName, familyName]
          .where((name) => name != null && (name as String).isNotEmpty)
          .cast<String>()
          .join(' ');
      final identityToken = appleCredential.identityToken;
      final authorizationCode = appleCredential.authorizationCode;

      if (appleId.isEmpty) {
        throw ApiException('Apple authentication failed: No user ID received');
      }

      // Authenticate with backend
      final user = await AuthService.appleAuth(
        appleId: appleId,
        email: email,
        name: fullName.isNotEmpty ? fullName : null,
        identityToken: identityToken,
        authorizationCode: authorizationCode,
      );

      // Save user data
      await UserStorage.saveUser(user);

      if (mounted) {
               // Show success message
        Get.snackbar(
          'Login Successful',
          'Successfully logged in with Apple',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.withOpacity(0.9),
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
          margin: EdgeInsets.all(ResponsiveHelper.spacing(context, 16)),
          borderRadius: ResponsiveHelper.borderRadius(context, mobile: 12),
          icon: Icon(
            Icons.check_circle_outline,
            color: Colors.white,
            size: ResponsiveHelper.iconSize(context, mobile: 24),
          ),
        );

        // Re-initialize dependencies to ensure all controllers are ready
        InitialBinding().dependencies();
        Get.offAllNamed(Routes.DASHBOARD);
      }
    } on SignInWithAppleAuthorizationException catch (e) {
      // Handle Apple Sign In specific errors
      if (mounted) {
        String errorMessage = 'Sign in with Apple was cancelled.';
        if (e.code == AuthorizationErrorCode.canceled) {
          errorMessage = 'Sign in with Apple was cancelled.';
        } else if (e.code == AuthorizationErrorCode.failed) {
          errorMessage = 'Sign in with Apple failed. Please try again.';
        } else if (e.code == AuthorizationErrorCode.invalidResponse) {
          errorMessage = 'Invalid response from Apple. Please try again.';
        } else if (e.code == AuthorizationErrorCode.notHandled) {
          errorMessage = 'Sign in with Apple is not available.';
        } else if (e.code == AuthorizationErrorCode.unknown) {
          errorMessage = 'An unknown error occurred. Please try again.';
        }

        Get.snackbar(
          'Sign in with Apple',
          errorMessage,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange.withOpacity(0.9),
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      }
    } on ApprovalPendingException catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(
                'Account Approval Pending',
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: ResponsiveHelper.isMobile(context) ? 18 : 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Text(
                e.message,
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: ResponsiveHelper.isMobile(context) ? 14 : 16,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'OK',
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: ResponsiveHelper.isMobile(context) ? 14 : 16,
                      color: const Color(0xFFC79211),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        Get.snackbar(
          'Authentication Failed',
          e.message,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.withOpacity(0.9),
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
        );
      }
    } on NetworkException catch (e) {
      if (mounted) {
        Get.snackbar(
          'Connection Error',
          'No internet connection. Please check your network settings and try again.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange.withOpacity(0.9),
          colorText: Colors.white,
        );
      }
    } catch (e) {
      if (mounted) {
        Get.snackbar(
          'Unexpected Error',
          'An unexpected error occurred. Please try again. If the problem persists, contact support.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.withOpacity(0.9),
          colorText: Colors.white,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    print('🚀 _signInWithGoogle() called');
    
    if (_isLoading) {
      print('⚠️ Already loading, ignoring click');
      return;
    }
    
    setState(() {
      _isLoading = true;
    });

    try {
      print('📱 Initializing Google Sign In...');
      
      // Web Client ID - Used for backend authentication (idToken)
      const String webClientId = '502290384332-79ibsfgk52dd7d9lhvfv9fspn3k26u83.apps.googleusercontent.com';
      
      // Initialize Google Sign In with serverClientId for proper idToken generation
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
        serverClientId: webClientId, // Web Client ID for backend authentication
        // Android OAuth Client ID is automatically matched by package name + SHA-1
        // iOS OAuth Client ID is configured in Info.plist
      );

      // Clear any existing sign-in before attempting new sign-in (prevents cached session issues)
      print('🔵 Clearing any existing Google Sign-In session...');
      try {
        await googleSignIn.signOut();
        await Future.delayed(const Duration(milliseconds: 300));
      } catch (e) {
        print('⚠️ Sign out warning (continuing): $e');
      }

      print('🔐 Calling googleSignIn.signIn()...');
      // Sign in - will show account picker
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      print('✅ Google Sign In response received: ${googleUser != null ? "User selected" : "User cancelled"}');
      
      if (googleUser == null) {
        // User cancelled
        print('❌ User cancelled Google Sign In');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      print('👤 Getting user authentication details...');
      // Get authentication details (includes idToken for backend verification)
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken; // Available when serverClientId is set
      print('✅ Authentication details received');
      print('🔑 idToken: ${idToken != null ? "received" : "null"}');

      // Get user info
      final String googleId = googleUser.id;
      final String email = googleUser.email;
      final String name = googleUser.displayName ?? email.split('@')[0]; // Fallback to email prefix if no name
      final String? profilePicture = googleUser.photoUrl;

      print('📧 User Info:');
      print('   ID: $googleId');
      print('   Email: $email');
      print('   Name: $name');
      
      print('🌐 Authenticating with backend...');
      // Authenticate with backend
      final user = await AuthService.googleAuth(
        googleId: googleId,
        email: email,
        name: name,
        profilePicture: profilePicture,
      );
      print('✅ Backend authentication successful');

      print('💾 Saving user data...');
      // Save user data
      await UserStorage.saveUser(user);
      print('✅ User data saved');

      if (mounted) {
        Get.offAllNamed(Routes.DASHBOARD);
      }
    } on ApprovalPendingException catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(
                'Account Approval Pending',
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: ResponsiveHelper.isMobile(context) ? 18 : 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Text(
                e.message,
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: ResponsiveHelper.isMobile(context) ? 14 : 16,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'OK',
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: ResponsiveHelper.isMobile(context) ? 14 : 16,
                      color: const Color(0xFFC79211),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        Get.snackbar(
          'Google Sign In Failed',
          e.message,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.withOpacity(0.9),
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
          margin: EdgeInsets.all(ResponsiveHelper.spacing(context, 16)),
          borderRadius: ResponsiveHelper.borderRadius(context, mobile: 12),
          icon: Icon(
            Icons.error_outline,
            color: Colors.white,
            size: ResponsiveHelper.iconSize(context, mobile: 24),
          ),
        );
      }
    } on NetworkException catch (e) {
      if (mounted) {
        Get.snackbar(
          'Connection Error',
          'No internet connection. Please check your network settings and try again.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange.withOpacity(0.9),
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e, stackTrace) {
      // Log detailed error for debugging
      print('❌ Google Sign In Error: ${e.toString()}');
      print('❌ Error Type: ${e.runtimeType}');
      print('❌ Stack Trace: $stackTrace');
      
      if (mounted) {
        String errorMessage = 'An error occurred during Google Sign In.';
        String errorTitle = 'Google Sign In Error';
        
        // Provide more specific error messages based on error code
        final errorString = e.toString().toLowerCase();
        
        // Error Code 7: NETWORK_ERROR
        if (errorString.contains('network_error') || errorString.contains('apiException: 7') || errorString.contains('network')) {
          errorTitle = 'Network Error';
          errorMessage = 'Please check your internet connection and make sure Google Play Services is updated. Go to Play Store and update Google Play Services.';
        } 
        // Error Code 10: DEVELOPER_ERROR
        else if (errorString.contains('apiException: 10') || 
                 errorString.contains('ApiException: 10') ||
                 errorString.contains('api_exception: 10') ||
                 errorString.contains('developer_error') ||
                 errorString.contains('DEVELOPER_ERROR') ||
                 (errorString.contains('sign_in_failed') && errorString.contains('10'))) {
          errorTitle = 'Configuration Error';
          errorMessage = 'Google Sign In configuration issue. The SHA-1 fingerprint needs to be added to Firebase Console. Please contact the developer or check Firebase project settings.';
        }
        // Error Code 8: INTERNAL_ERROR
        else if (errorString.contains('apiException: 8') || errorString.contains('internal_error')) {
          errorTitle = 'Internal Error';
          errorMessage = 'An internal error occurred. Please try again later or restart the app.';
        }
        // User cancellation
        else if (errorString.contains('sign_in_canceled') || errorString.contains('cancelled') || errorString.contains('canceled')) {
          // Don't show error for user cancellation
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
          return;
        } 
        // Sign in failed
        else if (errorString.contains('sign_in_failed') || errorString.contains('failed')) {
          errorTitle = 'Sign In Failed';
          errorMessage = 'Google Sign In failed. Please try again.';
        } 
        // Platform not supported
        else if (errorString.contains('platform') || errorString.contains('not supported')) {
          errorTitle = 'Not Supported';
          errorMessage = 'Google Sign In is not supported on this platform.';
        } 
        // Configuration error
        else if (errorString.contains('configuration') || errorString.contains('setup')) {
          errorTitle = 'Configuration Error';
          errorMessage = 'Google Sign In is not properly configured. Please contact support.';
        } 
        // Connection error
        else if (errorString.contains('connection')) {
          errorTitle = 'Connection Error';
          errorMessage = 'Network error. Please check your internet connection.';
        }
        // Default error
        else {
          errorMessage = 'An error occurred: ${e.toString()}';
        }
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && context.mounted) {
            try {
              Get.snackbar(
                errorTitle,
                errorMessage,
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: Colors.red.withOpacity(0.9),
                colorText: Colors.white,
                duration: const Duration(seconds: 6),
                margin: EdgeInsets.all(ResponsiveHelper.spacing(context, 16)),
                borderRadius: ResponsiveHelper.borderRadius(context, mobile: 12),
                icon: Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: ResponsiveHelper.iconSize(context, mobile: 24),
                ),
              );
            } catch (snackbarError) {
              print('⚠️ Could not show snackbar: $snackbarError');
            }
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Professional responsive design for tablets/iPads
    final isTabletDevice = ResponsiveHelper.isTablet(context);
    final double? maxContentWidthValue = isTabletDevice 
        ? (ResponsiveHelper.isLargeTablet(context) ? 1200.0 : 840.0)
        : null;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        top: true,
        bottom: true,
        child: SingleChildScrollView(
          child: Center(
            child: ResponsiveHelper.constrainedContent(
              context: context,
              maxWidth: maxContentWidthValue,
              child: Padding(
                padding: ResponsiveHelper.safePadding(context, horizontal: ResponsiveHelper.isMobile(context) ? 16 : 20),
            child: Form(
              key: _formKey,
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
                        "Create an Account",
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
                      "Sign up to get started",
                      textAlign: TextAlign.center,
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: ResponsiveHelper.fontSize(context, mobile: 13, tablet: 15, desktop: 17),
                        color: Colors.grey[700],
                      ).copyWith(fontFamily: 'MontserratAlternates'),
                    ),
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 16 : 20)),
                  // Full Name Input
                  TextFormField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your name';
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.person, color: AppTheme.iconscolor),
                      hintText: "Full Name",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
                        borderSide: BorderSide(color: Colors.grey.withOpacity(0.3), width: 1.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
                        borderSide: BorderSide(color: Colors.grey.withOpacity(0.3), width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
                        borderSide: BorderSide(color: AppTheme.iconscolor.withOpacity(0.3), width: ResponsiveHelper.spacing(context, 2.5)),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
                        borderSide: const BorderSide(color: Colors.red),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
                        borderSide: BorderSide(color: Colors.red, width: ResponsiveHelper.spacing(context, 2)),
                      ),
                    ),
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 12 : 14)),
                  // Email Input
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      final email = value?.trim() ?? '';
                      final phone = _phoneController.text.trim();
                      if (email.isEmpty && phone.isEmpty) {
                        return 'Please enter email or phone';
                      }

                        if (phone.isNotEmpty) {
                        if (!phone.startsWith('+')) {
                          return 'Start with country code (e.g. +1)';
                        }
                        
                        // Remove '+' for digit counting
                        final digitsOnly = phone.replaceAll(RegExp(r'[^0-9]'), '');
                        
                        // Check if total digits are enough (Country Code + 10 digits)
                        // Minimum valid length is usually 11 digits (1 digit CC + 10 digit number)
                        if (digitsOnly.length < 11) {
                          return 'Enter valid number (Country Code + 10 digits)';
                        }
                        
                        if (!RegExp(r'^\+[0-9]+$').hasMatch(phone)) {
                          return 'Only numbers and + allowed';
                        }
                      }
                      
                      if (email.isNotEmpty && !GetUtils.isEmail(email)) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.email, color: AppTheme.iconscolor),
                      hintText: "Email (Optional if phone provided)",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
                        borderSide: BorderSide(color: Colors.grey.withOpacity(0.3), width: 1.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
                        borderSide: BorderSide(color: Colors.grey.withOpacity(0.3), width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
                        borderSide: BorderSide(color: AppTheme.iconscolor.withOpacity(0.3), width: ResponsiveHelper.spacing(context, 2.5)),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
                        borderSide: const BorderSide(color: Colors.red),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
                        borderSide: BorderSide(color: Colors.red, width: ResponsiveHelper.spacing(context, 2)),
                      ),
                    ),
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 12 : 14)),
                  // Phone Input
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      final phone = value?.trim() ?? '';
                      final email = _emailController.text.trim();
                      if (email.isEmpty && phone.isEmpty) {
                        return 'Please enter email or phone';
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.phone, color: AppTheme.iconscolor),
                      hintText: "Phone (Optional if email provided)",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
                        borderSide: BorderSide(color: Colors.grey.withOpacity(0.3), width: 1.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
                        borderSide: BorderSide(color: Colors.grey.withOpacity(0.3), width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
                        borderSide: BorderSide(color: AppTheme.iconscolor.withOpacity(0.3), width: ResponsiveHelper.spacing(context, 2.5)),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
                        borderSide: const BorderSide(color: Colors.red),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
                        borderSide: BorderSide(color: Colors.red, width: ResponsiveHelper.spacing(context, 2)),
                      ),
                    ),
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 12 : 14)),
                  // Password Input
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      prefixIcon:  Icon(Icons.lock, color: AppTheme.iconscolor),
                      hintText: "Password",
                      filled: true,
                      fillColor: Colors.white,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                          color:  AppTheme.iconscolor,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
                        borderSide: BorderSide(color: AppTheme.iconscolor.withOpacity(0.3), width: 1.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
                        borderSide: BorderSide(color: AppTheme.iconscolor.withOpacity(0.3), width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
                        borderSide: BorderSide(color: AppTheme.iconscolor.withOpacity(0.3), width: ResponsiveHelper.spacing(context, 2.5)),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
                        borderSide: const BorderSide(color: Colors.red),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
                        borderSide: BorderSide(color: Colors.red, width: ResponsiveHelper.spacing(context, 2)),
                      ),
                    ),
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 12 : 14)),
                  // Confirm Password Input
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: !_isConfirmPasswordVisible,
                    textInputAction: TextInputAction.done,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm password';
                      }
                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => _createAccount(),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock, color: AppTheme.iconscolor),
                      hintText: "Confirm Password",
                      filled: true,
                      fillColor: Colors.white,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                          color: AppTheme.iconscolor,
                        ),
                        onPressed: () {
                          setState(() {
                            _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
                        borderSide: BorderSide(color: AppTheme.iconscolor.withOpacity(0.3), width: 1.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
                        borderSide: BorderSide(color: AppTheme.iconscolor.withOpacity(0.3), width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
                        borderSide: BorderSide(color: AppTheme.iconscolor.withOpacity(0.3), width: ResponsiveHelper.spacing(context, 2.5)),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
                        borderSide: const BorderSide(color: Colors.red),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
                        borderSide: BorderSide(color: Colors.red, width: ResponsiveHelper.spacing(context, 2)),
                      ),
                    ),
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 12 : 14)),
                  // Role Selection Dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedRole,
                    isExpanded: true, // Prevent overflow
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select a role';
                      }
                      if (value != 'User' && value != 'Blogger') {
                        return 'Please select a valid role (User or Blogger)';
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.person_outline, color: AppTheme.iconscolor),
                      labelText: "Select Role",
                      hintText: "Choose your role",
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: ResponsiveHelper.safePadding(context, all: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
                        borderSide: BorderSide(color: AppTheme.iconscolor.withOpacity(0.3), width: 1.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
                        borderSide: BorderSide(color: AppTheme.iconscolor.withOpacity(0.3), width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
                        borderSide: BorderSide(color: AppTheme.iconscolor.withOpacity(0.3), width: ResponsiveHelper.spacing(context, 2.5)),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
                        borderSide: const BorderSide(color: Colors.red),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
                        borderSide: BorderSide(color: Colors.red, width: ResponsiveHelper.spacing(context, 2)),
                      ),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'User',
                        child: Text(
                          'User',
                          style: ResponsiveHelper.textStyle(
                            context,
                            fontSize: ResponsiveHelper.isMobile(context) ? 14 : 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'Blogger',
                        child: Text(
                          'Blogger (Requires Admin Approval)',
                          style: ResponsiveHelper.textStyle(
                            context,
                            fontSize: ResponsiveHelper.isMobile(context) ? 14 : 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedRole = newValue;
                        });
                      }
                    },
                  ),
                  if (_selectedRole == 'Blogger')
                    Padding(
                      padding: EdgeInsets.only(top: ResponsiveHelper.spacing(context, 8)),
                      child: Container(
                        padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 10)),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 8)),
                          border: Border.all(color: Colors.orange.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.orange,
                              size: ResponsiveHelper.iconSize(context, mobile: 20),
                            ),
                            SizedBox(width: ResponsiveHelper.spacing(context, 10)),
                            Expanded(
                              child: Text(
                                'Blogger role requires admin approval. You will be registered as User initially.',
                                style: ResponsiveHelper.textStyle(
                                  context,
                                  fontSize: ResponsiveHelper.fontSize(context, mobile: 12, tablet: 13, desktop: 14),
                                  color: Colors.orange.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                SizedBox(height: ResponsiveHelper.spacing(context, 20)),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Checkbox(
                      value: _agreeToTerms,
                      onChanged: (bool? newValue) {
                        setState(() {
                          _agreeToTerms = newValue ?? false;
                        });
                      },
                      activeColor: AppTheme.iconscolor,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            "I agree ",
                            style: ResponsiveHelper.textStyle(
                              context,
                              fontSize: ResponsiveHelper.fontSize(context, mobile: 13, tablet: 14, desktop: 15),
                              color: Colors.black,
                            ).copyWith(fontFamily: 'MontserratAlternates'),
                          ),
                          GestureDetector(
                            onTap: () {
                              Get.toNamed('/terms');
                            },
                            child: Text(
                              "Terms And Conditions",
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: ResponsiveHelper.fontSize(context, mobile: 13, tablet: 14, desktop: 15),
                                fontWeight: FontWeight.bold,
                                fontFamily: 'MontserratAlternates',
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                  SizedBox(height: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 16 : 20)),
                  // Create Account Button
                SizedBox(
                  width: double.infinity,
                  height: ResponsiveHelper.buttonHeight(
                    context,
                    mobile: 65,
                    tablet: 65,  // Taller for tablets
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _createAccount,
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
                    child: _isLoading
                        ? SizedBox(
                            height: ResponsiveHelper.iconSize(context, mobile: 20),
                            width: ResponsiveHelper.iconSize(context, mobile: 20),
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            "Create Account",
                            style: ResponsiveHelper.textStyle(
                              context,
                              fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 18, desktop: 20),
                              fontWeight: FontWeight.bold,
                            ).copyWith(fontFamily: 'MontserratAlternates'),
                          ),
                  ),
                ),
                  SizedBox(height: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 16 : 20)),
                  // Divider with OR text
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: Colors.grey[300],
                          thickness: 1,
                        ),
                      ),
                      Padding(
                        padding: ResponsiveHelper.padding(context, horizontal: 12),
                        child: Text(
                          "OR",
                          style: ResponsiveHelper.textStyle(
                            context,
                            fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 16, desktop: 18),
                            color: const Color(0xFF5C4033),
                          ).copyWith(fontFamily: 'MontserratAlternates'),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: Colors.grey[300],
                          thickness: 1,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 16 : 20)),
                  // Sign in with Apple Button (iOS only) - Official Apple Button
                  if (Platform.isIOS)
                    SizedBox(
                      width: double.infinity,
                      height: ResponsiveHelper.buttonHeight(
                        context, 
                        mobile: 50,
                        tablet: 56,
                      ),
                      child: SignInWithAppleButton(
                        onPressed: () {
                          if (!_isLoading) {
                            _signInWithApple();
                          }
                        },
                        text: 'Sign up with Apple',
                        height: ResponsiveHelper.buttonHeight(
                          context, 
                          mobile: 50,
                          tablet: 56,
                        ),
                      ),
                    ),
                  if (Platform.isIOS)
                    SizedBox(height: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 16 : 20)),
                  // Google Sign In Button - Full Width for Better UX (Always Visible)
                  SizedBox(
                    width: double.infinity,
                    height: ResponsiveHelper.buttonHeight(
                      context,
                      mobile: 50,
                      tablet: 75,
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : () async {
                        print('🔵🔵🔵 Google Sign In button TAPPED!');
                        print('📊 Current loading state: $_isLoading');
                        print('📊 Mounted: $mounted');
                        
                        try {
                          print('🚀 About to call _signInWithGoogle()...');
                          await _signInWithGoogle();
                          print('✅ _signInWithGoogle() completed');
                        } catch (e, stackTrace) {
                          print('❌❌❌ Error in button tap handler: $e');
                          print('❌ Stack Trace: $stackTrace');
                          if (mounted) {
                            setState(() {
                              _isLoading = false;
                            });
                            // Only show snackbar if context is available and widget is mounted
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted && context.mounted) {
                                try {
                                  Get.snackbar(
                                    'Error',
                                    'Failed to start Google Sign In: ${e.toString()}',
                                    snackPosition: SnackPosition.BOTTOM,
                                    backgroundColor: Colors.red.withOpacity(0.9),
                                    colorText: Colors.white,
                                    duration: const Duration(seconds: 5),
                                  );
                                } catch (snackbarError) {
                                  print('⚠️ Could not show snackbar: $snackbarError');
                                }
                              }
                            });
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isLoading ? Colors.grey[200] : Colors.white, // Visible even when loading
                        foregroundColor: _isLoading ? Colors.grey[600] : Colors.black87, // Visible text
                        elevation: 2,
                        shadowColor: Colors.grey.withOpacity(0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                          side: BorderSide(color: Colors.grey[300]!, width: 1),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: ResponsiveHelper.spacing(context, 16),
                          vertical: ResponsiveHelper.spacing(context, 12),
                        ),
                      ),
                      icon: Image.asset(
                        'assets/google.png',
                        width: ResponsiveHelper.iconSize(context, mobile: 24),
                        height: ResponsiveHelper.iconSize(context, mobile: 24),
                        errorBuilder: (context, error, stackTrace) {
                          print('❌ Google image failed to load: $error');
                          return Icon(
                            Icons.login,
                            color: Colors.grey[700],
                            size: ResponsiveHelper.iconSize(context, mobile: 24),
                          );
                        },
                      ),
                      label: Text(
                        'Sign up with Google',
                        style: ResponsiveHelper.textStyle(
                          context,
                          fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 18),
                          fontWeight: FontWeight.w500,
                        ).copyWith(fontFamily: 'MontserratAlternates'),
                      ),
                    ),
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 16 : 20)),
                  // Facebook Button (Optional)
                  // Center(
                  //   child: GestureDetector(
                  //     onTap: () {
                  //       // Handle Facebook login
                  //     },
                  //     child: Container(
                  //       width: ResponsiveHelper.isMobile(context) ? 50 : ResponsiveHelper.isTablet(context) ? 55 : 60,
                  //       height: ResponsiveHelper.isMobile(context) ? 50 : ResponsiveHelper.isTablet(context) ? 55 : 60,
                  //       padding: ResponsiveHelper.padding(context, all: 8),
                  //       decoration: BoxDecoration(
                  //         color: Colors.white,
                  //         borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                  //         border: Border.all(
                  //           color: Colors.grey[300]!,
                  //           width: 1,
                  //         ),
                  //         boxShadow: [
                  //           BoxShadow(
                  //             color: Colors.grey.withOpacity(0.2),
                  //             blurRadius: 4,
                  //             offset: const Offset(0, 2),
                  //           ),
                  //         ],
                  //       ),
                  //       child: Image.asset(
                  //         'assets/facebook.png',
                  //         fit: BoxFit.contain,
                  //         errorBuilder: (context, error, stackTrace) {
                  //           return Icon(
                  //             Icons.facebook,
                  //             color: Colors.blue[700],
                  //             size: ResponsiveHelper.iconSize(context, mobile: 24),
                  //           );
                  //         },
                  //       ),
                  //     ),
                  //   ),
                  // ),
                  SizedBox(height: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 16 : 20)),
                  // Already have account link
                  Center(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          "Already have an account? ",
                          style: ResponsiveHelper.textStyle(
                            context,
                            fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 16, desktop: 18),
                            color: Colors.black,
                          ).copyWith(fontFamily: 'MontserratAlternates'),
                        ),
                        GestureDetector(
                          onTap: () {
                            // Use offNamed instead of back to avoid snackbar controller error
                            try {
                              Get.offNamed(Routes.LOGIN);
                            } catch (e) {
                              // Fallback to Navigator if Get fails
                              Navigator.of(context).pop();
                            }
                          },
                          child: Text(
                            "Login",
                            style: TextStyle(
                              color: const Color(0xFF5C4033),
                              fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 16, desktop: 18),
                              fontWeight: FontWeight.bold,
                              fontFamily: 'MontserratAlternates',
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 20 : 24)),
                ],
              ),
            ),
          ),
        ),
      ),
    )
      )
    );
  }
}
