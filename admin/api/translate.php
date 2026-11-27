<?php
/**
 * Translation API
 * Handles: Multi-language support using Google Translate API
 */

require_once '../includes/db.php';
require_once '../includes/cors.php';
require_once '../includes/config.php';
require_once 'auth-helper.php';

// Fallback if config.php does not define translation constants (e.g. old server config)
if (!defined('GOOGLE_TRANSLATE_API_KEY')) {
    define('GOOGLE_TRANSLATE_API_KEY', getenv('GOOGLE_TRANSLATE_API_KEY') ?: '');
}
if (!defined('GOOGLE_TRANSLATE_API_URL')) {
    define('GOOGLE_TRANSLATE_API_URL', 'https://translation.googleapis.com/language/translate/v2');
}
if (!defined('TRANSLATION_ENABLED')) {
    define('TRANSLATION_ENABLED', GOOGLE_TRANSLATE_API_KEY !== '');
}

header('Content-Type: application/json');

$method = $_SERVER['REQUEST_METHOD'];
$action = $_GET['action'] ?? $_POST['action'] ?? '';

if ($method === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// Check if translation is enabled
if (!TRANSLATION_ENABLED) {
    http_response_code(503);
    echo jsonResponse(false, 'Translation service is currently disabled');
    exit;
}

switch ($action) {
    case 'translate':
        handleTranslate($conn);
        break;
    case 'detect':
        handleDetectLanguage($conn);
        break;
    case 'languages':
        handleGetLanguages($conn);
        break;
    default:
        http_response_code(400);
        echo jsonResponse(false, 'Invalid action');
        break;
}

/**
 * Translate text using Google Translate API
 */
function handleTranslate($conn) {
    $text = trim($_POST['text'] ?? $_GET['text'] ?? '');
    $target_language = trim($_POST['target'] ?? $_GET['target'] ?? 'en');
    $source_language = trim($_POST['source'] ?? $_GET['source'] ?? '');
    
    if (empty($text)) {
        http_response_code(400);
        echo jsonResponse(false, 'Text to translate is required');
        return;
    }
    
    if (empty(GOOGLE_TRANSLATE_API_KEY)) {
        http_response_code(500);
        echo jsonResponse(false, 'Google Translate API key not configured');
        return;
    }
    
    // Prepare API request
    $url = GOOGLE_TRANSLATE_API_URL . '?key=' . urlencode(GOOGLE_TRANSLATE_API_KEY);
    
    $data = [
        'q' => $text,
        'target' => $target_language
    ];
    
    if (!empty($source_language)) {
        $data['source'] = $source_language;
    }
    
    // Make API request
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Content-Type: application/json'
    ]);
    
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    
    if ($httpCode !== 200) {
        http_response_code(500);
        echo jsonResponse(false, 'Translation API error');
        return;
    }
    
    $result = json_decode($response, true);
    
    if (isset($result['data']['translations'][0])) {
        $translation = $result['data']['translations'][0];
        echo jsonResponse(true, 'Translation successful', [
            'original_text' => $text,
            'translated_text' => $translation['translatedText'],
            'source_language' => $translation['detectedSourceLanguage'] ?? $source_language,
            'target_language' => $target_language
        ]);
    } else {
        http_response_code(500);
        echo jsonResponse(false, 'Translation failed');
    }
}

/**
 * Detect language of text
 */
function handleDetectLanguage($conn) {
    $text = trim($_POST['text'] ?? $_GET['text'] ?? '');
    
    if (empty($text)) {
        http_response_code(400);
        echo jsonResponse(false, 'Text is required');
        return;
    }
    
    if (empty(GOOGLE_TRANSLATE_API_KEY)) {
        http_response_code(500);
        echo jsonResponse(false, 'Google Translate API key not configured');
        return;
    }
    
    // Use Google Translate detect API
    $url = 'https://translation.googleapis.com/language/translate/v2/detect?key=' . urlencode(GOOGLE_TRANSLATE_API_KEY);
    
    $data = [
        'q' => $text
    ];
    
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Content-Type: application/json'
    ]);
    
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    
    if ($httpCode !== 200) {
        http_response_code(500);
        echo jsonResponse(false, 'Language detection error');
        return;
    }
    
    $result = json_decode($response, true);
    
    if (isset($result['data']['detections'][0][0])) {
        $detection = $result['data']['detections'][0][0];
        echo jsonResponse(true, 'Language detected', [
            'language' => $detection['language'],
            'confidence' => $detection['confidence'] ?? 1.0
        ]);
    } else {
        http_response_code(500);
        echo jsonResponse(false, 'Language detection failed');
    }
}

/**
 * Get supported languages
 */
function handleGetLanguages($conn) {
    // Common languages for Fruits of Spirit app
    $languages = [
        ['code' => 'en', 'name' => 'English'],
        ['code' => 'es', 'name' => 'Spanish'],
        ['code' => 'fr', 'name' => 'French'],
        ['code' => 'de', 'name' => 'German'],
        ['code' => 'it', 'name' => 'Italian'],
        ['code' => 'pt', 'name' => 'Portuguese'],
        ['code' => 'ru', 'name' => 'Russian'],
        ['code' => 'zh', 'name' => 'Chinese'],
        ['code' => 'ja', 'name' => 'Japanese'],
        ['code' => 'ko', 'name' => 'Korean'],
        ['code' => 'ar', 'name' => 'Arabic'],
        ['code' => 'hi', 'name' => 'Hindi'],
    ];
    
    echo jsonResponse(true, 'Languages retrieved', $languages);
}

$conn->close();
?>

