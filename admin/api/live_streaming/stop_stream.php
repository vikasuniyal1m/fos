<?php
/**
 * Stop live stream: mark as ended in DB (status = 'ended', end_time = NOW) so it no longer shows in the LIVE list.
 * Optionally notifies external Stream API if this stream was created there (e.g. GetStream); Agora-only streams are only updated in DB.
 */

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    header('Content-Type: application/json');
    echo json_encode(['error' => 'Method not allowed.']);
    exit();
}

require_once __DIR__ . '/../../includes/config.php';
require_once __DIR__ . '/../../includes/db.php';
require_once __DIR__ . '/../../includes/LiveStreamModel.php';

if (isset($db_connection_error)) {
    http_response_code(500);
    header('Content-Type: application/json');
    echo json_encode(['error' => 'Database connection failed: ' . $db_connection_error]);
    exit();
}

$input = json_decode(file_get_contents('php://input'), true);
$streamId = $input['stream_id'] ?? null;
$userId = isset($input['user_id']) ? (string) $input['user_id'] : '';

if (!$streamId) {
    http_response_code(400);
    header('Content-Type: application/json');
    echo json_encode(['error' => 'Stream ID is required.']);
    exit();
}

if ($userId === '') {
    http_response_code(400);
    header('Content-Type: application/json');
    echo json_encode(['success' => false, 'error' => 'user_id is required.']);
    exit();
}

$liveStreamModel = new LiveStreamModel($conn);
$stream = $liveStreamModel->getLiveStreamById($streamId);

if (!$stream) {
    http_response_code(404);
    header('Content-Type: application/json');
    echo json_encode(['success' => false, 'error' => 'Stream not found.']);
    exit();
}

$streamOwnerId = (string) ($stream['user_id'] ?? '');
if ($streamOwnerId !== $userId) {
    $roleStmt = $conn->prepare("SELECT role FROM users WHERE id = ? AND status = 'Active'");
    $roleStmt->bind_param("s", $userId);
    $roleStmt->execute();
    $roleResult = $roleStmt->get_result();
    $roleRow = $roleResult->fetch_assoc();
    $isAdmin = isset($roleRow['role']) && $roleRow['role'] === 'Admin';

    if (!$isAdmin) {
        http_response_code(403);
        header('Content-Type: application/json');
        echo json_encode(['success' => false, 'error' => 'Only the stream owner or an admin can stop this stream.']);
        exit();
    }
}

// Always mark stream as ended in our DB first (status = 'ended', end_time = NOW).
// This ensures the stream disappears from the "live" list even when using Agora (no external Stream API).
$db_result = $liveStreamModel->endLiveStream($streamId);

if (!$db_result['success']) {
    error_log("Stop stream DB error: " . ($db_result['error'] ?? 'unknown'));
    http_response_code(500);
    header('Content-Type: application/json');
    echo json_encode(['success' => false, 'error' => $db_result['error'] ?? 'Failed to end stream.']);
    exit();
}

// Optionally stop on external Stream API (e.g. GetStream). If not used (Agora-only), ignore failure.
$response_data = null;
if (file_exists(__DIR__ . '/../../includes/stream_api_helper.php')) {
    require_once __DIR__ . '/../../includes/stream_api_helper.php';
    $streamApiKey = getenv('STREAM_API_KEY') ?: '';
    $streamApiSecret = getenv('STREAM_API_SECRET') ?: '';
    if ($streamApiKey !== '' && $streamApiSecret !== '') {
        $streamApi = new StreamApiHelper($streamApiKey, $streamApiSecret);
        $response = $streamApi->stopStream($streamId);
        if ($response['success'] && isset($response['data'])) {
            $response_data = $response['data'];
        }
    }
}

header('Content-Type: application/json');
echo json_encode(['success' => true, 'message' => 'Stream stopped successfully.', 'data' => $response_data]);