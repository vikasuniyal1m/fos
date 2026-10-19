<?php
/**
 * Get Emoji Image API
 * Redirects to the correct image URL based on emoji character
 */

// Allow CORS
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET");

require_once __DIR__ . '/../includes/config.php';

// Base URLs — must match live uploads on admin.fosmessenger.com
$baseUrl = defined('FOS_MEDIA_BASE_URL') ? FOS_MEDIA_BASE_URL : 'https://admin.fosmessenger.com/';
$fruitBaseUrl = $baseUrl . 'uploads/fruitofspirit/';
$imagesBaseUrl = $baseUrl . 'uploads/images/';

$emoji_char = $_GET['emoji_char'] ?? '';
$variant = isset($_GET['variant']) ? intval($_GET['variant']) : 1;

if (empty($emoji_char)) {
    http_response_code(400);
    die('Missing emoji_char');
}

// Map Emojis to File Paths (matching ImageConfig.dart)
$map = [
    // Joy -> Pineapple
    '😊' => $fruitBaseUrl . 'pineapple-01.png',
    
    // Peace -> Watermelon
    '☮️' => $fruitBaseUrl . 'watermelon-01.png',
    
    // Patience -> Banana (ImageConfig has pa-01.png)
    '⏳' => $fruitBaseUrl . 'pa-01.png',
    
    // Kindness -> Orange
    '🤗' => $fruitBaseUrl . 'Orange-01.png',
    
    // Goodness -> Kiwi (ImageConfig has ad-01.png)
    '✨' => $fruitBaseUrl . 'ad-01.png',
    
    // Faithfulness -> Cherry (ImageConfig uses banana as fallback: banana-01.png)
    '🙏' => $fruitBaseUrl . 'banana-01.png',
    
    // Gentleness/Meekness -> Grapes
    '🕊️' => $fruitBaseUrl . 'Graps%20-01.png',
    
    // Self-Control -> Apple
    '🎯' => $fruitBaseUrl . 'Green-apple-01.png',
    
    // Love -> Strawberry (Special path)
    '❤️' => $imagesBaseUrl . 'Strawberry.png',
    
    // Secondary mappings
    '⭐' => $fruitBaseUrl . 'ad-01.png',           // Star -> Goodness
    '👏' => $fruitBaseUrl . 'pineapple-01.png',    // Clap -> Joy
];

$redirectUrl = null;

// Clean up input emoji (sometimes spaces or encoding issues)
$emoji_char = trim($emoji_char);

if (isset($map[$emoji_char])) {
    $redirectUrl = $map[$emoji_char];
    
    // Handle variants (01, 02, 03)
    // Only applies to files provided with -01 pattern
    if ($variant > 1 && strpos($redirectUrl, '-01.png') !== false) {
         $suffix = str_pad($variant, 2, '0', STR_PAD_LEFT);
         $redirectUrl = str_replace('-01.png', "-$suffix.png", $redirectUrl);
    }
} else {
    // Try to handle URL encoded values just in case
    $decoded = urldecode($emoji_char);
    if (isset($map[$decoded])) {
        $redirectUrl = $map[$decoded];
    }
}

if ($redirectUrl) {
    header("Location: $redirectUrl");
    exit;
}

// Log 404 for debugging
error_log("get-emoji-image.php: No image found for emoji: " . bin2hex($emoji_char));

http_response_code(404);
echo "Image not found for emoji";
