<?php
/**
 * Agora RTC token endpoint.
 * Keys (App ID + Certificate) stay in PHP; Flutter only receives token + app_id.
 * Set AGORA_APP_ID and AGORA_APP_CERTIFICATE in environment (or .env).
 */

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    header('Content-Type: application/json');
    echo json_encode(['success' => false, 'message' => 'Method not allowed.']);
    exit;
}

require_once __DIR__ . '/../../includes/config.php';
require_once __DIR__ . '/../../includes/agora/RtcTokenBuilder2.php';

$appId = trim((string) AGORA_APP_ID);
$appCertificate = trim((string) AGORA_APP_CERTIFICATE);

if ($appId === '' || $appCertificate === '') {
    http_response_code(500);
    header('Content-Type: application/json');
    echo json_encode([
        'success' => false,
        'message' => 'Agora is not configured. Set AGORA_APP_ID and AGORA_APP_CERTIFICATE.',
    ]);
    exit;
}

$input = json_decode(file_get_contents('php://input'), true) ?? [];
$channelName = trim((string) ($input['channel_name'] ?? ''));
$userId = isset($input['user_id']) ? (string) $input['user_id'] : '';
$role = isset($input['role']) ? (int) $input['role'] : 2; // 1 = publisher, 2 = subscriber
$tokenExpire = isset($input['token_expire']) ? (int) $input['token_expire'] : 3600;

if ($channelName === '') {
    http_response_code(400);
    header('Content-Type: application/json');
    echo json_encode(['success' => false, 'message' => 'channel_name is required.']);
    exit;
}

if ($userId === '') {
    http_response_code(400);
    header('Content-Type: application/json');
    echo json_encode(['success' => false, 'message' => 'user_id is required.']);
    exit;
}

if ($role !== 1 && $role !== 2) {
    $role = 2;
}
if ($tokenExpire < 60) {
    $tokenExpire = 3600;
}
if ($tokenExpire > 86400) {
    $tokenExpire = 86400;
}

// Check if stream is still live (for viewers - role = 2)
// Hosts (role = 1) can always get token to start/stop
if ($role === 2) {
    require_once __DIR__ . '/../../includes/db.php';
    require_once __DIR__ . '/../../includes/LiveStreamModel.php';

    $liveStreamModel = new LiveStreamModel($conn);
    $stream = $liveStreamModel->getLiveStreamById($channelName);

    if (!$stream) {
        http_response_code(404);
        header('Content-Type: application/json');
        echo json_encode([
            'success' => false,
            'message' => 'Live stream not found or has ended.',
        ]);
        exit;
    }

    $stream_status = strtolower(trim($stream['status'] ?? ''));
    if ($stream_status !== 'live') {
        http_response_code(403);
        header('Content-Type: application/json');
        echo json_encode([
            'success' => false,
            'message' => 'This live stream has ended.',
            'stream_status' => $stream_status,
        ]);
        exit;
    }
}

$token = RtcTokenBuilder2::buildTokenWithUserAccount(
    $appId,
    $appCertificate,
    $channelName,
    $userId,
    $role,
    $tokenExpire,
    $tokenExpire
);

if ($token === '') {
    http_response_code(500);
    header('Content-Type: application/json');
    echo json_encode([
        'success' => false,
        'message' => 'Failed to generate token. Use App ID and Primary Certificate (32 hex chars each) from the SAME project at console.agora.io in includes/agora_env.php.',
    ]);
    exit;
}

header('Content-Type: application/json');
echo json_encode([
    'success' => true,
    'token'   => $token,
    'app_id'  => $appId,
    'channel_name' => $channelName,
    'expire_seconds' => $tokenExpire,
]);
