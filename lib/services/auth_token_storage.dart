import 'package:shared_preferences/shared_preferences.dart';

class AuthTokenStorage {
  static const String _authTokenKey = 'auth_token';
  static Future<void> saveAuthToken(String token) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_authTokenKey, token);
    print('Auth token saved: \$token');
  }

  static Future<String?> getAuthToken() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString(_authTokenKey);
    print('Auth token retrieved: \$token');
    return token;
  }

  static Future<void> deleteAuthToken() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_authTokenKey);
    print('Auth token deleted.');
  }
}
