/// API Configuration
/// Base URL and API endpoints configuration
class ApiConfig {
  // Base URL for PHP Backend
  static const String baseUrl = 'https://fruitofthespirit.templateforwebsites.com/api';
  
  // API Endpoints
  static const String auth = '$baseUrl/auth.php';
  static const String fruits = '$baseUrl/fruits.php';
  static const String prayers = '$baseUrl/prayers.php';
  static const String blogs = '$baseUrl/blogs.php';
  static const String videos = '$baseUrl/videos.php';
  static const String gallery = '$baseUrl/gallery.php';
  static const String emojis = '$baseUrl/emojis.php';
  static const String groups = '$baseUrl/groups.php';
  static const String comments = '$baseUrl/comments.php';
  static const String notifications = '$baseUrl/notifications.php';
  static const String profile = '$baseUrl/profile.php';
  static const String users = '$baseUrl/users.php';
  
  // New API Endpoints
  static const String stories = '$baseUrl/stories.php';
  static const String search = '$baseUrl/search.php';
  static const String analytics = '$baseUrl/analytics.php';
  static const String advanced = '$baseUrl/advanced.php';
  static const String translate = '$baseUrl/translate.php';
  static const String terms = '$baseUrl/terms.php';
  static const String ecommerce = '$baseUrl/ecommerce.php';
  static const String prayerReminders = '$baseUrl/prayer_reminders.php';
  static const String deleteAccount = '$baseUrl/profile.php'; // Account deletion endpoint
  static const String contact = '$baseUrl/contact.php'; // Contact information endpoint
  static const String report = '$baseUrl/report.php';
  static const String blockUser = '$baseUrl/block_user.php';

  // Live Streaming Endpoints
  static const String liveStreamingToken = '$baseUrl/live_streaming/token.php';
  static const String liveStreamingCreate = '$baseUrl/live_streaming/create_stream.php';
  static const String liveStreamingGet = '$baseUrl/live_streaming/get_stream.php';
  static const String liveStreamingStop = '$baseUrl/live_streaming/stop_stream.php';
  static const String liveStreamingGetAll = '$baseUrl/live_streaming/get_all_streams.php';
  /// Agora token from PHP (keys stay on server)
  static const String liveStreamingAgoraToken = '$baseUrl/live_streaming/agora_token.php';
  /// Register Agora live started (so users see stream in list)
  static const String liveStreamingAgoraStartLive = '$baseUrl/live_streaming/agora_start_live.php';
  /// Live comments (host + viewers see same list via API)
  static const String liveStreamingAddComment = '$baseUrl/live_streaming/add_live_comment.php';
  static const String liveStreamingGetComments = '$baseUrl/live_streaming/get_live_comments.php';

  // Request timeout
  static const Duration timeout = Duration(seconds: 60);
  static const Duration mediaTimeout = Duration(minutes: 5);

  
  // Headers
  static Map<String, String> get headers => {
    'Content-Type': 'application/x-www-form-urlencoded',
    'Accept': 'application/json',
  };
  
  static Map<String, String> get jsonHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
}

