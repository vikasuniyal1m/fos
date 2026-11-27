<?php
/**
 * Register that an Agora live stream has started (broadcaster went live).
 * Saves to DB so get_all_streams returns it and users can see "who is live" and join.
 */

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    header('Content-Type: application/json');
    echo json_encode(['success' => false, 'message' => 'Method not allowed.']);
    exit;
}

require_once __DIR__ . '/../../includes/db.php';
require_once __DIR__ . '/../../includes/LiveStreamModel.php';

if (isset($db_connection_error)) {
    http_response_code(500);
    header('Content-Type: application/json');
    echo json_encode(['success' => false, 'message' => 'Database connection failed.']);
    exit;
}

$input = json_decode(file_get_contents('php://input'), true) ?? [];
$streamId = trim((string) ($input['stream_id'] ?? $input['channel_name'] ?? ''));
$userId = isset($input['user_id']) ? (string) $input['user_id'] : '';
$title = trim((string) ($input['title'] ?? 'Live'));
$description = trim((string) ($input['description'] ?? ''));

if ($streamId === '' || $userId === '') {
    http_response_code(400);
    header('Content-Type: application/json');
    echo json_encode(['success' => false, 'message' => 'stream_id (or channel_name) and user_id are required.']);
    exit;
}

try {
    $model = new LiveStreamModel($conn);
    $result = $model->startAgoraLive($streamId, $userId, $title, $description);
    if (!empty($result['success'])) {
        header('Content-Type: application/json');
        echo json_encode(['success' => true, 'message' => 'Live stream registered.', 'stream_id' => $streamId]);
    } else {
        http_response_code(500);
        header('Content-Type: application/json');
        echo json_encode(['success' => false, 'message' => $result['error'] ?? 'Failed to register live stream.']);
    }
} catch (Throwable $e) {
    http_response_code(500);
    header('Content-Type: application/json');
    echo json_encode(['success' => false, 'message' => 'Server error.']);
}
