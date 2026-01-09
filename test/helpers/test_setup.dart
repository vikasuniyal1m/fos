import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Test setup helper
/// Initializes test environment with SharedPreferences mock
Future<void> setupTestEnvironment() async {
  // Initialize Flutter binding for SharedPreferences
  TestWidgetsFlutterBinding.ensureInitialized();
  
  // Set up SharedPreferences mock with empty initial values
  // This allows SharedPreferences to work in tests
  SharedPreferences.setMockInitialValues({});
}
