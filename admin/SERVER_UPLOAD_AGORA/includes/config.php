<?php
// Define APP_DEBUG for conditional error reporting
define('APP_DEBUG', true);

// Define STREAM_KEY_PREFIX for live stream keys
define('STREAM_KEY_PREFIX', 'live_');

// Define RTMP and HLS server URLs for live streaming
define('RTMP_SERVER_URL', 'rtmp://localhost/live');
define('HLS_SERVER_URL', 'http://localhost:8080/hls');

// Define Stream API Base URL
define('STREAM_API_BASE_URL', 'https://video.stream-io-api.com');

// Agora (keys only on server; Flutter gets token from PHP)
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
?>
