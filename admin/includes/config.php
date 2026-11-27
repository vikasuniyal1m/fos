<?php
// Define APP_DEBUG for conditional error reporting
define('APP_DEBUG', true);

// Public media/uploads base (images, chat files, emojis)
if (!defined('FOS_MEDIA_BASE_URL')) {
    define('FOS_MEDIA_BASE_URL', 'https://admin.fosmessenger.com/');
}

// Define STREAM_KEY_PREFIX for live stream keys
define('STREAM_KEY_PREFIX', 'live_');

// Define RTMP and HLS server URLs for live streaming
define('RTMP_SERVER_URL', 'rtmp://localhost/live');
define('HLS_SERVER_URL', 'http://localhost:8080/hls');

// Define Stream API Base URL
define('STREAM_API_BASE_URL', 'https://video.stream-io-api.com');

// Agora (keys only on server; Flutter gets token from PHP)
// 1) Set env vars AGORA_APP_ID and AGORA_APP_CERTIFICATE on server, OR
// 2) Put includes/agora_env.php (copy from agora_env.sample.php) with your keys, OR
// Keep credentials outside source control.
$agoraAppId = getenv('AGORA_APP_ID') ?: '';
$agoraCert  = getenv('AGORA_APP_CERTIFICATE') ?: '';
if ($agoraAppId === '' || $agoraCert === '') {
    $agoraEnvPath = __DIR__ . DIRECTORY_SEPARATOR . 'agora_env.php';
    if (file_exists($agoraEnvPath)) {
        $env = require $agoraEnvPath;
        $agoraAppId = $agoraAppId ?: ($env['AGORA_APP_ID'] ?? '');
        $agoraCert  = $agoraCert ?: ($env['AGORA_APP_CERTIFICATE'] ?? '');
    }
}
define('AGORA_APP_ID', trim($agoraAppId));
define('AGORA_APP_CERTIFICATE', trim($agoraCert));

// Stripe (payment) – configure with environment variables or stripe_env.php.
$stripeEnvPath = __DIR__ . DIRECTORY_SEPARATOR . 'stripe_env.php';
$stripeEnv = file_exists($stripeEnvPath) ? (require $stripeEnvPath) : [];

$stripeSecret = getenv('STRIPE_SECRET_KEY');
if ($stripeSecret === false || $stripeSecret === null || trim((string) $stripeSecret) === '') {
    $stripeSecret = $stripeEnv['STRIPE_SECRET_KEY'] ?? '';
}
define('STRIPE_SECRET_KEY', trim((string) $stripeSecret));

$stripePublishable = getenv('STRIPE_PUBLISHABLE_KEY');
if ($stripePublishable === false || $stripePublishable === null || trim((string) $stripePublishable) === '') {
    $stripePublishable = $stripeEnv['STRIPE_PUBLISHABLE_KEY'] ?? '';
}
define('STRIPE_PUBLISHABLE_KEY', trim((string) $stripePublishable));

// Translation (Google Translate API) – set GOOGLE_TRANSLATE_API_KEY in env or leave empty to disable
$googleTranslateKey = getenv('GOOGLE_TRANSLATE_API_KEY');
if ($googleTranslateKey === false || $googleTranslateKey === null || trim((string) $googleTranslateKey) === '') {
    $googleTranslateKey = '';
}
define('GOOGLE_TRANSLATE_API_KEY', trim((string) $googleTranslateKey));
define('GOOGLE_TRANSLATE_API_URL', 'https://translation.googleapis.com/language/translate/v2');
define('TRANSLATION_ENABLED', GOOGLE_TRANSLATE_API_KEY !== '');
?>