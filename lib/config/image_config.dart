class ImageConfig {
  // Base URL for images on Hostinger
  // Direct uploads folder (all images directly in uploads/)
  static const String baseUrl = 'https://fruitofthespirit.templateforwebsites.com/uploads/';
  
  // App Images - Network URLs (with proper URL encoding for spaces)
  static String notification = '${baseUrl}images/notification.png';
  static String pray = '${baseUrl}images/Pray.png';
  static String userGroups = '${baseUrl}images/User%20Groups.png'; // URL encoded for spaces
  static String strawberry = '${baseUrl}images/Strawberry.png';
  static String dove = '${baseUrl}images/dove.png';
  // static String logo = '${baseUrl}images/logo%201.png'; // URL encoded for space
  static String logo = '${baseUrl}images/logo_png.png'; // URL encoded for space
  static String onboardingFirst = '${baseUrl}images/onboardingfirst.png';
  static String onboardingThird = '${baseUrl}images/onboardingthird.png';
  static String onboardingFourth = '${baseUrl}images/onboardingfourth.png';
  static String splash = '${baseUrl}images/splash1.png';
  static String grow = '${baseUrl}images/grow.png';
  static String videoThumbnail = '${baseUrl}images/videothumbnail.png';
  
  // Fruits of the Spirit Images Base URL
  // Original URL provided by user
  static const String fruitsBaseUrl = 'https://fruitofthespirit.templateforwebsites.com/uploads/fruitofspirit/';
  
  // Helper method to get fruit image URL based on fruit name
  // Based on website reference: https://fosmessenger.com/fruit-of-the-spirit/
  // Mapping: Love→Strawberry, Joy→Pineapple, Peace→Watermelon, Patience→Banana,
  // Kindness→Orange, Goodness→Kiwi, Faithfulness→Cherry, Gentleness→Grapes, Self-Control→Apple
  // Actual files in uploads/fruitofspirit/ folder
  static String getFruitImageUrl(String fruitName) {
    // Normalize fruit name (trim and lowercase for matching)
    final normalizedName = fruitName.trim().toLowerCase();
    
    // Map fruit names to actual image filenames in uploads/fruitofspirit/ folder
    // Using -01 versions as default (each fruit has -01, -02, -03 variants)
    final fruitImageMap = {
      'love': strawberry,                     // Strawberry - use existing images/Strawberry.png
      'joy': '${fruitsBaseUrl}pineapple-01.png',             // Pineapple
      'peace': '${fruitsBaseUrl}watermelon-01.png',          // Watermelon
      'patience': '${fruitsBaseUrl}pa-01.png',               // Patience (pa = patience abbreviation)
      'kindness': '${fruitsBaseUrl}Orange-01.png',           // Orange (capital O)
      'goodness': '${fruitsBaseUrl}ad-01.png',               // Goodness (ad = abbreviation)
      'faithfulness': '${fruitsBaseUrl}banana-01.png',       // Faithfulness - using banana as fallback (cherry not found)
      'gentleness': '${fruitsBaseUrl}Graps%20-01.png',      // Grapes (Meekness) - note space in filename
      'meekness': '${fruitsBaseUrl}Graps%20-01.png',         // Grapes (alternative name)
      'self-control': '${fruitsBaseUrl}Green-apple-01.png',  // Apple
      'self control': '${fruitsBaseUrl}Green-apple-01.png',  // Alternative name
      'discipline': '${fruitsBaseUrl}Green-apple-01.png',    // Alternative name for Self-Control
    };
    
    // Get image URL - if it's already a full URL (strawberry), return it directly
    // Otherwise, it's already a full URL from the map
    final imageUrl = fruitImageMap[normalizedName];
    
    if (imageUrl != null) {
      // Debug: Print for troubleshooting
      print('Fruit: $fruitName -> URL: $imageUrl');
      return imageUrl;
    }
    
    // Default fallback
    final defaultUrl = '${fruitsBaseUrl}pineapple-01.png';
    print('Fruit: $fruitName -> Default URL: $defaultUrl');
    return defaultUrl;
  }
  
  // Helper method to get physical fruit name for display
  // Based on website reference mapping
  static String getPhysicalFruitName(String spiritualFruitName) {
    final normalizedName = spiritualFruitName.trim().toLowerCase();
    final physicalFruitMap = {
      'love': 'Strawberry',
      'joy': 'Pineapple',
      'peace': 'Watermelon',
      'patience': 'Banana',
      'kindness': 'Orange',
      'goodness': 'Kiwi',
      'faithfulness': 'Cherry',
      'gentleness': 'Grapes',
      'meekness': 'Grapes',
      'self-control': 'Apple',
      'self control': 'Apple',
      'discipline': 'Apple',
    };
    return physicalFruitMap[normalizedName] ?? 'Fruit';
  }
  
  // Helper method to get image URL with error handling
  // For images in uploads/images/ folder
  static String getImageUrl(String imageName) {
    // Replace spaces with %20 for URL encoding
    String encodedName = imageName.replaceAll(' ', '%20');
    return '${baseUrl}images/$encodedName';
  }
  
  // Helper method to convert asset path to network URL
  // Converts: assets/images/notification.png -> uploads/images/notification.png
  static String assetPathToNetworkUrl(String assetPath) {
    // Remove 'assets/images/' prefix and convert to network URL
    String imageName = assetPath.replaceAll('assets/images/', '');
    // Add 'images/' prefix to match server structure
    return '${baseUrl}images/$imageName';
  }
  
  // Helper method to get image URL from filename (for direct server images)
  // For images in uploads/images/ folder
  static String getServerImageUrl(String imageName) {
    // Replace spaces with %20 for URL encoding
    String encodedName = imageName.replaceAll(' ', '%20');
    return '${baseUrl}images/$encodedName';
  }
  
  // Fallback to asset if network image fails
  static String getAssetPath(String imageName) {
    return 'assets/images/$imageName';
  }

  // PHP endpoint for emoji images (from uploads/emojis folder)
  static const String emojiImageApiUrl = 'https://fruitofthespirit.templateforwebsites.com/api/get-emoji-image.php';

  // Fruit reaction images base URLs (from uploads/images/128-128 and 256-256) - DEPRECATED
  // Now using PHP endpoint from uploads/emojis folder
  static const String fruitReactions128Url = '${baseUrl}images/128-128/';
  static const String fruitReactions256Url = '${baseUrl}images/256-256/';

  /// Get fruit reaction image URL from emoji character
  /// Maps emoji characters to fruit images via PHP endpoint (from uploads/emojis folder)
  /// Returns null if emoji character not found
  /// 
  /// Parameters:
  /// - emojiChar: Emoji character (e.g., '😊', '☮️', '🙏')
  /// - size: Image size in pixels (passed to PHP endpoint)
  /// - variant: Image variant (01, 02, 03) - defaults to 01
  static String? getFruitReactionImageUrl(String emojiChar, {double? size, int variant = 1}) {
    // Map emoji characters to verify it's a valid emoji
    final emojiToFruitMap = {
      '😊': 'joy_pineapple',           // Joy
      '☮️': 'peace_watermelon',        // Peace
      '⏳': 'patience_orange',         // Patience
      '🤗': 'kindness_orange',         // Kindness
      '✨': 'goodness_mango',          // Goodness
      '🙏': 'faithfulness_cherry',     // Faithfulness
      '🕊️': 'gentleness_grapes',      // Gentleness/Meekness
      '🎯': 'self_control_apple',      // Self-Control
      '❤️': 'joy_pineapple',           // Love (maps to joy for now)
      '⭐': 'goodness_mango',          // Star (maps to goodness)
      '👏': 'joy_pineapple',          // Clap (maps to joy)
    };
    
    // Check if emoji is valid
    if (!emojiToFruitMap.containsKey(emojiChar)) {
      return null;
    }
    
    // Build URL with PHP endpoint - encode emoji character for URL
    final encodedEmoji = Uri.encodeComponent(emojiChar);
    final sizeParam = size != null ? '&size=${size.toInt()}' : '';
    return '$emojiImageApiUrl?emoji_char=$encodedEmoji&variant=$variant$sizeParam';
  }

  /// Get fruit reaction image URL from fruit name
  /// Maps fruit names to emoji characters, then uses PHP endpoint (from uploads/emojis folder)
  static String? getFruitReactionImageUrlByName(String fruitName, {double? size, int variant = 1}) {
    // Map fruit names to emoji characters
    final fruitNameToEmojiMap = {
      'joy': '😊',
      'peace': '☮️',
      'patience': '⏳',
      'kindness': '🤗',
      'goodness': '✨',
      'faithfulness': '🙏',
      'gentleness': '🕊️',
      'meekness': '🕊️',
      'self-control': '🎯',
      'self control': '🎯',
      'discipline': '🎯',
      'love': '❤️',
    };
    
    final normalizedName = fruitName.toLowerCase().trim();
    final emojiChar = fruitNameToEmojiMap[normalizedName];
    if (emojiChar == null) {
      return null;
    }
    
    // Use the emoji-based function
    return getFruitReactionImageUrl(emojiChar, size: size, variant: variant);
  }
}

