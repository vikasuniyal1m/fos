import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

class IntroService {
  static const String _kLaunchCountKey = 'launch_count';
  static const String _kSkipIntroKey = 'skip_intro';
  static const String _kHasWatchedIntroKey = 'has_watched_intro'; // New key
  static const String _kVideoPlayCountKey = 'video_play_count';

  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    print('IntroService: SharedPreferences initialized.');
  }

  static Future<void> incrementLaunchCount() async {
    int launchCount = _prefs.getInt(_kLaunchCountKey) ?? 0;
    await _prefs.setInt(_kLaunchCountKey, launchCount + 1);
  }

  static int getLaunchCount() {
    return _prefs.getInt(_kLaunchCountKey) ?? 0;
  }

  static bool getSkipIntroPermanently() {
    return _prefs.getBool(_kSkipIntroKey) ?? false;
  }

  static bool shouldShowIntroOverlay() {
    final bool skipIntroPermanently = _prefs.getBool(_kSkipIntroKey) ?? false;
    debugPrint('IntroService: shouldShowIntroOverlay - skipIntroPermanently: $skipIntroPermanently');
    debugPrint('IntroService: shouldShowIntroOverlay - returning: ${!skipIntroPermanently}');
    return !skipIntroPermanently;
  }

  static Future<void> setSkipIntroPermanently(bool value) async {
    await _prefs.setBool(_kSkipIntroKey, value);
  }

  static bool getHasWatchedIntro() {
    return _prefs.getBool(_kHasWatchedIntroKey) ?? false;
  }

  static Future<void> setHasWatchedIntro(bool value) async {
    await _prefs.setBool(_kHasWatchedIntroKey, value);
  }

  // For testing/resetting purposes
  static Future<void> resetIntroSettings() async {
    await _prefs.remove(_kLaunchCountKey);
    await _prefs.remove(_kSkipIntroKey);
    await _prefs.remove(_kHasWatchedIntroKey); // Reset new key
    await _prefs.remove(_kVideoPlayCountKey); // Reset video play count
  }

  static Future<void> incrementVideoPlayCount() async {
    int videoPlayCount = _prefs.getInt(_kVideoPlayCountKey) ?? 0;
    videoPlayCount++;
    await _prefs.setInt(_kVideoPlayCountKey, videoPlayCount);
    print('IntroService: Video play count incremented to $videoPlayCount');
  }

  static int getVideoPlayCount() {
    final int count = _prefs.getInt(_kVideoPlayCountKey) ?? 0;
    print('IntroService: Current video play count is $count');
    return count;
  }

  static bool shouldShowCheckbox() {
    final bool show = getVideoPlayCount() >= 3;
    print('IntroService: Should show checkbox: $show (play count: ${getVideoPlayCount()})');
    return show;
  }
}
