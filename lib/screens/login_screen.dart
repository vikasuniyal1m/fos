import 'package:flutter/material.dart';
import 'package:fruitsofspirit/utils/app_theme.dart';
import 'package:get/get.dart';
import 'dart:io' show Platform;
import 'package:fruitsofspirit/routes/routes.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';
import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:fruitsofspirit/services/auth_service.dart';
import 'package:fruitsofspirit/services/user_storage.dart';
import 'package:fruitsofspirit/services/api_service.dart' show ApprovalPendingException, ApiException, NetworkException, RoleMismatchException;
import 'package:fruitsofspirit/services/intro_service.dart';
import 'package:fruitsofspirit/controllers/home_controller.dart';
import 'package:fruitsofspirit/controllers/prayers_controller.dart';
import 'package:fruitsofspirit/controllers/groups_controller.dart';
import 'package:fruitsofspirit/controllers/notifications_controller.dart';
import 'package:fruitsofspirit/controllers/profile_controller.dart';
import 'package:fruitsofspirit/controllers/fruits_controller.dart';
import 'package:fruitsofspirit/controllers/blogs_controller.dart';
import 'package:fruitsofspirit/controllers/videos_controller.dart';
import 'package:fruitsofspirit/controllers/gallery_controller.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String _selectedRole = 'User'; // Default role: User or Blogger
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _loginError; // Store login error message

  void _reinitializeControllers() {
    InitialBinding().dependencies();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    // Clear previous error
    setState(() {
      _loginError = null;
    });
    
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _loginError = null; // Clear error when starting login
    });

    try {
      // Check if input is email or phone
      final input = _emailController.text.trim();
      final isEmail = input.contains('@');
      
      Map<String, dynamic> user;
      if (isEmail) {
        user = await AuthService.login(
          email: input,
          password: _passwordController.text,
          role: _selectedRole,
        );
      } else {
        user = await AuthService.login(
          phone: input,
          password: _passwordController.text,
          role: _selectedRole,
        );
      }

      // Save user data in SharedPreferences
      await UserStorage.saveUser(user);

      // Re-initialize controllers to load new user data
      _reinitializeControllers();

      if (mounted) {
        Get.offAllNamed(Routes.DASHBOARD);
      }
    } on ApprovalPendingException catch (e) {
      if (mounted) {
        // Show popup dialog for approval pending
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
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.message,
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
                            'Status: ${e.status}\nRole: ${e.role}\n\nYou can login as User while waiting for approval.',
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
                  onPressed: () async {
                    Navigator.of(context).pop(); // Close dialog
                    
                    // Automatically login as User
                    if (mounted) {
                      setState(() {
                        _selectedRole = 'User';
                        _isLoading = true;
                        _loginError = null;
                      });
                      
                      try {
                        final input = _emailController.text.trim();
                        final isEmail = input.contains('@');
                        
                        Map<String, dynamic> user;
                        if (isEmail) {
                          user = await AuthService.login(
                            email: input,
                            password: _passwordController.text,
                            role: 'User', // Force User role
                          );
                        } else {
                          user = await AuthService.login(
                            phone: input,
                            password: _passwordController.text,
                            role: 'User', // Force User role
                          );
                        }
                        
                        // Save user data
                        await UserStorage.saveUser(user);
                        
                        // Re-initialize controllers
                        _reinitializeControllers();

                        if (mounted) {
                          Get.offAllNamed(Routes.DASHBOARD);
                        }
                      } catch (loginError) {
                        if (mounted) {
                          setState(() {
                            _isLoading = false;
                          });
                          
                          // Show error if login fails
                          if (loginError is ApiException) {
                            final errorLower = loginError.message.toLowerCase();
                            String errorMessage = 'Email and password wrong';
                            
                            if (errorLower.contains('invalid credentials') || errorLower.contains('invalid credential')) {
                              errorMessage = 'Email and password wrong';
                            }
                            
                            setState(() {
                              _loginError = errorMessage;
                            });
                            _formKey.currentState?.validate();
                          }
                        }
                      }
                    }
                  },
                  child: Text(
                    'Login as User',
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
    } on RoleMismatchException catch (e) {
      // Auto-select correct role when role mismatch occurs
      if (mounted) {
        setState(() {
          _selectedRole = e.correctRole;
          _loginError = null; // Clear error since we're auto-fixing
        });
        
        // Show message that role was auto-selected
        Get.snackbar(
          'Role Updated',
          'Your role has been automatically set to ${e.correctRole}. Please try logging in again.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.blue.withOpacity(0.9),
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
          margin: EdgeInsets.all(ResponsiveHelper.spacing(context, 16)),
          borderRadius: ResponsiveHelper.borderRadius(context, mobile: 12),
          icon: Icon(
            Icons.info_outline,
            color: Colors.white,
            size: ResponsiveHelper.iconSize(context, mobile: 24),
          ),
        );
      }
    } on ApiException catch (e) {
      // Log server error to console (for debugging)
      print('❌ Login API Error: ${e.message}');
      print('❌ Error Details: ${e.toString()}');
      
      if (mounted) {
        // Check for specific error types and set appropriate error message
        final errorLower = e.message.toLowerCase();
        String errorMessage;
        
        if (errorLower.contains('invalid credentials') || errorLower.contains('invalid credential')) {
          errorMessage = 'Email and password wrong';
        } else if (errorLower.contains('password') || errorLower.contains('incorrect password') || errorLower.contains('wrong password') || errorLower.contains('invalid password')) {
          errorMessage = 'Email and password wrong';
        } else if (errorLower.contains('email') && (errorLower.contains('not found') || errorLower.contains('invalid') || errorLower.contains('wrong') || errorLower.contains('does not exist'))) {
          errorMessage = 'Email and password wrong';
        } else if (errorLower.contains('phone') && (errorLower.contains('not found') || errorLower.contains('invalid') || errorLower.contains('wrong') || errorLower.contains('does not exist'))) {
          errorMessage = 'Email and password wrong';
        } else if (errorLower.contains('role') || errorLower.contains('incorrect role') || errorLower.contains('wrong role') || errorLower.contains('select the correct role')) {
          errorMessage = 'Please select the correct role';
        } else if (errorLower.contains('account') && (errorLower.contains('inactive') || errorLower.contains('suspended') || errorLower.contains('disabled'))) {
          errorMessage = 'Your account is currently inactive. Please contact support.';
        } else {
          // Default error message
          errorMessage = 'Email and password wrong';
        }
        
        // Set error message to show in form field
        setState(() {
          _loginError = errorMessage;
        });
        
        // Trigger form validation to show error
        _formKey.currentState?.validate();
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

      // Re-initialize controllers
      _reinitializeControllers();

      if (mounted) {
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

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Get.snackbar(
              'Sign in with Apple',
              errorMessage,
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: Colors.orange.withOpacity(0.9),
              colorText: Colors.white,
              duration: const Duration(seconds: 3),
            );
          }
        });
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
        WidgetsBinding.instance.addPostFrameCallback((_) {
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
        });
      }
    } on NetworkException catch (e) {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Get.snackbar(
              'Connection Error',
              'No internet connection. Please check your network settings and try again.',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: Colors.orange.withOpacity(0.9),
              colorText: Colors.white,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Get.snackbar(
              'Unexpected Error',
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
      // Get this from Google Cloud Console -> Credentials -> Web Client ID
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

      // Save user data
      await UserStorage.saveUser(user);

      // Re-initialize controllers
      _reinitializeControllers();

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
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && context.mounted) {
            try {
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
            } catch (snackbarError) {
              print('⚠️ Could not show snackbar: $snackbarError');
            }
          }
        });
      }
    } on NetworkException catch (e) {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && context.mounted) {
            try {
              Get.snackbar(
                'Connection Error',
                'No internet connection. Please check your network settings and try again.',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: Colors.orange.withOpacity(0.9),
                colorText: Colors.white,
                duration: const Duration(seconds: 4),
              );
            } catch (snackbarError) {
              print('⚠️ Could not show snackbar: $snackbarError');
            }
          }
        });
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
    // Mobile: Keep original behavior (don't touch)
    final isTabletDevice = ResponsiveHelper.isTablet(context);
    // Get max content width for tablets (840px for small tablets, 1200px for large tablets)
    final double? maxContentWidthValue = isTabletDevice 
        ? (ResponsiveHelper.isLargeTablet(context) 
            ? 1200.0 
            : 840.0)
        : null;
    
    return PopScope(
      canPop: false, // Prevent going back after login - professional practice
      child: Scaffold(
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
                  padding: ResponsiveHelper.safePadding(
                    context, 
                    horizontal: isTabletDevice ? ResponsiveHelper.contentPadding(context) : 20,
                    vertical: isTabletDevice ? ResponsiveHelper.contentVerticalPadding(context) : 0,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                  SizedBox(height: ResponsiveHelper.spacing(
                    context, 
                    isTabletDevice ? 60 : 50  // More top spacing for tablets
                  )),
                  Center(
                    child: ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [const Color(0xFF8B4513), const Color(0xFFC79211)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds),
                      child: Text(
                        "Welcome Back!",
                        style: ResponsiveHelper.textStyle(
                          context,
                          fontSize: ResponsiveHelper.fontSize(context, mobile: 32, tablet: 36, desktop: 40),
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ).copyWith(fontFamily: 'MontserratAlternates'),
                      ),
                    ),
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(
                    context, 
                    isTabletDevice ? 16 : 10  // More spacing for tablets
                  )),
                  Center(
                    child: Text(
                      "Sign in to continue",
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 18, desktop: 20),
                        color: Colors.grey[700],
                      ).copyWith(fontFamily: 'MontserratAlternates'),
                    ),
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(
                    context, 
                    isTabletDevice ? 50 : 40  // More spacing for tablets
                  )),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 17, desktop: 18),
                    ),
                    validator: (value) {
                      // Show login error if exists
                      if (_loginError != null) {
                        return _loginError;
                      }
                      
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter email or phone number';
                      }
                      final input = value.trim();
                      // Check if it's an email (contains @)
                      if (input.contains('@')) {
                        // Validate email format
                        if (!GetUtils.isEmail(input)) {
                          return 'Please enter a valid email address';
                        }
                      } else {
                        // Validate phone format (basic check - at least 10 digits)
                        final phoneDigits = input.replaceAll(RegExp(r'[^0-9]'), '');
                        if (phoneDigits.length < 10) {
                          return 'Please enter a valid phone number (at least 10 digits)';
                        }
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      hintText: "Email or Phone Number",
                      prefixIcon: Icon(
                        Icons.person, 
                        color: AppTheme.iconscolor,
                        size: ResponsiveHelper.iconSize(context, mobile: 24, tablet: 26),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: ResponsiveHelper.safePadding(
                        context,
                        vertical: isTabletDevice ? 18 : 16,
                        horizontal: isTabletDevice ? 20 : 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16, tablet: 18)),
                        borderSide: BorderSide(color: AppTheme.iconscolor.withOpacity(0.3), width: 1.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16, tablet: 18)),
                        borderSide: BorderSide(color: AppTheme.iconscolor.withOpacity(0.3), width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16, tablet: 18)),
                        borderSide: BorderSide(color: AppTheme.iconscolor.withOpacity(0.3), width: ResponsiveHelper.spacing(context, 2.5)),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16, tablet: 18)),
                        borderSide: const BorderSide(color: Colors.red, width: 1.5),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16, tablet: 18)),
                        borderSide: BorderSide(color: Colors.red, width: ResponsiveHelper.spacing(context, 2.5)),
                      ),
                    ),
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(
                    context, 
                    isTabletDevice ? 24 : 20  // More spacing for tablets
                  )),
                  // Role Selection Dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedRole,
                    isExpanded: true, // Prevent overflow
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 17, desktop: 18),
                      color: Colors.black,  // Black color for selected value visibility
                    ),
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
                      prefixIcon: Icon(
                        Icons.person_outline, 
                        color: AppTheme.iconscolor,
                        size: ResponsiveHelper.iconSize(context, mobile: 24, tablet: 26),
                      ),
                      labelText: "Select Role",
                      hintText: "Choose your role",
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: ResponsiveHelper.safePadding(
                        context,
                        vertical: isTabletDevice ? 18 : 16,
                        horizontal: isTabletDevice ? 20 : 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16, tablet: 18)),
                        borderSide: BorderSide(color: AppTheme.iconscolor.withOpacity(0.3), width: 1.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16, tablet: 18)),
                        borderSide: BorderSide(color: AppTheme.iconscolor.withOpacity(0.3), width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16, tablet: 18)),
                        borderSide: BorderSide(color: AppTheme.iconscolor.withOpacity(0.3), width: ResponsiveHelper.spacing(context, 2.5)),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16, tablet: 18)),
                        borderSide: const BorderSide(color: Colors.red, width: 1.5),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16, tablet: 18)),
                        borderSide: BorderSide(color: Colors.red, width: ResponsiveHelper.spacing(context, 2.5)),
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
                            color: Colors.black,  // Black color for visibility
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'Blogger',
                        child: Text(
                          'Blogger',
                          style: ResponsiveHelper.textStyle(
                            context,
                            fontSize: ResponsiveHelper.isMobile(context) ? 14 : 16,
                            color: Colors.black,  // Black color for visibility
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
                  SizedBox(height: ResponsiveHelper.spacing(
                    context, 
                    isTabletDevice ? 24 : 20  // More spacing for tablets
                  )),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    textInputAction: TextInputAction.done,
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 17, desktop: 18),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => _login(),
                    decoration: InputDecoration(
                      hintText: "Password",
                      prefixIcon: Icon(
                        Icons.lock, 
                        color: AppTheme.iconscolor,
                        size: ResponsiveHelper.iconSize(context, mobile: 24, tablet: 26),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: ResponsiveHelper.safePadding(
                        context,
                        vertical: isTabletDevice ? 18 : 16,
                        horizontal: isTabletDevice ? 20 : 16,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                          color: AppTheme.iconscolor,
                          size: ResponsiveHelper.iconSize(context, mobile: 24, tablet: 26),
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16, tablet: 18)),
                        borderSide: BorderSide(color: AppTheme.iconscolor.withOpacity(0.3), width: 1.2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16, tablet: 18)),
                        borderSide: BorderSide(color: AppTheme.iconscolor.withOpacity(0.3), width: 1.2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16, tablet: 18)),
                        borderSide: BorderSide(color: AppTheme.iconscolor.withOpacity(0.3), width: ResponsiveHelper.spacing(context, 2.5)),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16, tablet: 18)),
                        borderSide: const BorderSide(color: Colors.red, width: 1.5),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16, tablet: 18)),
                        borderSide: BorderSide(color: Colors.red, width: ResponsiveHelper.spacing(context, 2.5)),
                      ),
                    ),
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(
                    context, 
                    isTabletDevice ? 36 : 30  // More spacing for tablets
                  )),
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () {
                        Get.toNamed(Routes.FORGOT_PASSWORD);
                      },
                      child: Text(
                        "Forgot Password?",
                        style: ResponsiveHelper.textStyle(
                          context,
                          fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 16, desktop: 18),
                          color: const Color(0xFF5C4033),
                        ).copyWith(fontFamily: 'MontserratAlternates'),
                      ),
                    ),
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(
                    context, 
                    isTabletDevice ? 36 : 30  // More spacing for tablets
                  )),
                  SizedBox(
                    width: double.infinity,
                    height: ResponsiveHelper.buttonHeight(
                      context, 
                      mobile: 50,
                      tablet: 56,  // Taller for tablets
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
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
                        padding: MaterialStateProperty.all(
                          EdgeInsets.symmetric(
                            vertical: isTabletDevice ? 16 : 14,
                            horizontal: 24,
                          ),
                        ),
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
                            "Login",
                            style: ResponsiveHelper.textStyle(
                              context,
                              fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 18, desktop: 20),
                              fontWeight: FontWeight.w600,
                            ).copyWith(fontFamily: 'MontserratAlternates'),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.visible,
                          ),
                    ),
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(context, 30)),
                  // Login with OTP Button
                  SizedBox(
                    width: double.infinity,
                    height: ResponsiveHelper.buttonHeight(
                      context, 
                      mobile: 50,
                      tablet: 56,  // Taller for tablets
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        Get.toNamed(Routes.PHONE_AUTH);
                      }, // Navigate to PhoneAuthScreen
                      style: ResponsiveHelper.adaptiveButtonStyle(
                        context,
                        backgroundColor: const Color(0xFF9F9467).withOpacity(0.8),
                        foregroundColor: Colors.white,
                      ).copyWith(
                        padding: MaterialStateProperty.all(
                          EdgeInsets.symmetric(
                            vertical: isTabletDevice ? 16 : 14,
                            horizontal: 24,
                          ),
                        ),
                        shape: MaterialStateProperty.all(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 16)),
                          ),
                        ),
                      ),
                      child: Text(
                        "Login With OTP",
                        style: ResponsiveHelper.textStyle(
                          context,
                          fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 18, desktop: 20),
                          fontWeight: FontWeight.w600,
                        ).copyWith(fontFamily: 'MontserratAlternates'),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.visible,
                      ),
                    ),
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(context, 30)),
                  Center(
                    child: Text(
                      "- OR Continue with -",
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 16, desktop: 18),
                        color: const Color(0xFF5C4033),
                      ).copyWith(fontFamily: 'MontserratAlternates'),
                    ),
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
                        text: 'Sign in with Apple',
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
                        width: ResponsiveHelper.iconSize(context, mobile: 24, tablet: 28, desktop: 32),
                        height: ResponsiveHelper.iconSize(context, mobile: 24, tablet: 28, desktop: 32),
                        errorBuilder: (context, error, stackTrace) {
                          print('❌ Google image failed to load: $error');
                          return Icon(
                            Icons.login,
                            color: Colors.grey[700],
                            size: ResponsiveHelper.iconSize(context, mobile: 24, tablet: 28, desktop: 32),
                          );
                        },
                      ),
                      label: Text(
                        'Sign in with Google',
                        style: ResponsiveHelper.textStyle(
                          context,
                          fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 18, desktop: 20),
                          fontWeight: FontWeight.w500,
                        ).copyWith(fontFamily: 'MontserratAlternates'),
                      ),
                    ),
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(context, ResponsiveHelper.isMobile(context) ? 16 : 20)),
                  // Facebook Button (Optional - can be removed if not needed)
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
                  SizedBox(height: ResponsiveHelper.spacing(context, 30)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Create An Account ",
                        style: ResponsiveHelper.textStyle(
                          context,
                          fontSize: ResponsiveHelper.fontSize(context, mobile: 14, tablet: 16, desktop: 18),
                          color: Colors.black,
                        ).copyWith(fontFamily: 'MontserratAlternates'),
                      ),
                      GestureDetector(
                        onTap: () {
                          Get.toNamed(Routes.CREATE_ACCOUNT); // Navigate to Create Account screen
                        },
                        child: Text(
                          "Sign Up",
                          style: TextStyle(
                            color: const Color(0xFF5C4033), // Changed to darker brown
                            fontSize: ResponsiveHelper.fontSize(context, mobile: 16, tablet: 18, desktop: 20),
                            fontWeight: FontWeight.bold,
                            fontFamily: 'MontserratAlternates',
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(
                    context, 
                    isTabletDevice ? 40 : 30  // Bottom spacing for tablets
                  )),
                ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
