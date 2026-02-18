/// Content Moderation Service
/// Provides client-side content filtering for inappropriate words
class ContentModerationService {
  // List of inappropriate words/phrases (case-insensitive)
  // Note: This is a basic filter. Backend should also validate.
  static final List<String> _bannedWords = [
    // Hate speech & offensive terms
    'hate', 'kill', 'die', 'stupid', 'idiot', 'dumb', 'loser', 'trash',
    // Profanity (common examples - add more as needed)
    'fuck', 'shit', 'damn', 'hell', 'ass', 'bitch', 'bastard', 'crap',
    // Bullying terms
    'ugly', 'fat', 'retard', 'moron', 'pathetic', 'worthless', 'useless',
    // Sexual content
    'sex', 'porn', 'nude', 'naked', 'xxx',
    // Violence & Threats
    'murder', 'rape', 'abuse', 'torture', 'harm', 'hurt', 'attack', 
    'threat', 'destroy', 'beat', 'punch', 'slap', 'stab', 'shoot',
    'bomb', 'terrorist', 'violence', 'weapon', 'gun', 'knife',
    // Discrimination
    'racist', 'sexist', 'homophobic', 'nigger', 'faggot',
    // Self-harm
    'suicide', 'kms', 'cutting', 'overdose',
    // Drugs
    'cocaine', 'heroin', 'meth', 'weed', 'marijuana', 'drug dealer',
  ];

  /// Check if text contains inappropriate content
  /// Returns true if content is clean, false if it contains banned words
  static bool isContentClean(String text) {
    if (text.trim().isEmpty) return true;
    
    final lowerText = text.toLowerCase();
    
    // Check for banned words
    for (final word in _bannedWords) {
      // Use word boundaries to avoid false positives
      // e.g., "hello" shouldn't match "hell"
      final pattern = RegExp(r'\b' + RegExp.escape(word) + r'\b', caseSensitive: false);
      if (pattern.hasMatch(lowerText)) {
        return false;
      }
    }
    
    return true;
  }

  /// Get censored version of text (replace bad words with ****)
  static String censorText(String text) {
    if (text.trim().isEmpty) return text;
    
    String censoredText = text;
    
    for (final word in _bannedWords) {
      final pattern = RegExp(r'\b' + RegExp.escape(word) + r'\b', caseSensitive: false);
      censoredText = censoredText.replaceAllMapped(pattern, (match) {
        return '*' * match.group(0)!.length;
      });
    }
    
    return censoredText;
  }

  /// Check and get result with details
  /// Returns a map with 'isClean' and 'message' keys
  static Map<String, dynamic> checkContent(String text) {
    if (text.trim().isEmpty) {
      return {'isClean': true, 'message': ''};
    }
    
    final isClean = isContentClean(text);
    
    if (!isClean) {
      return {
        'isClean': false,
        'message': 'Your message contains inappropriate content that violates our community guidelines. Please revise your message.',
      };
    }
    
    return {'isClean': true, 'message': ''};
  }
}
