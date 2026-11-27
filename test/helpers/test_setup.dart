import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fruitsofspirit/services/hive_cache_service.dart';

/// Test setup helper — Hive cache + SharedPreferences mock
Future<void> setupTestEnvironment() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  Hive.init('./test/.hive_test');
  await HiveCacheService.init();
}
