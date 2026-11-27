<?php
/**
 * Decrement viewer count when a viewer leaves a stream
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

$input = json_decode(file_get_contents('php://input'), true);
$stream_id = $input['stream_id'] ?? '';

if ($stream_id === '') {
    http_response_code(400);
    header('Content-Type: application/json');
    echo json_encode(['success' => false, 'message' => 'stream_id is required.']);
    exit;
}

try {
    $liveStreamModel = new LiveStreamModel($conn);
    $result = $liveStreamModel->decrementViewerCount($stream_id);

    header('Content-Type: application/json');
    echo json_encode($result);
} catch (Throwable $e) {
    error_log("Error in decrement_viewer.php: " . $e->getMessage());
    http_response_code(500);
    header('Content-Type: application/json');
    echo json_encode(['success' => false, 'message' => 'Server error.']);
}
