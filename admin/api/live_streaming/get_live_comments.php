<?php
/**
 * Get comments for a live stream channel. Used by host and viewers (poll).
 * GET: channel_name (required), limit (optional, default 80).
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Method not allowed.']);
    exit;
}

require_once __DIR__ . '/../../includes/db.php';

if (isset($db_connection_error)) {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Database connection failed.']);
    exit;
}

$channelName = trim((string) ($_GET['channel_name'] ?? ''));
$limit = (int) ($_GET['limit'] ?? 80);
if ($limit < 1 || $limit > 200) {
    $limit = 80;
}

if ($channelName === '') {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'channel_name is required.']);
    exit;
}

$safeLimit = (int) $limit;
$stmt = $conn->prepare(
    "SELECT id, channel_name, user_id, user_name, text, is_emoji, created_at FROM live_comments WHERE channel_name = ? ORDER BY created_at DESC LIMIT $safeLimit"
);
if (!$stmt) {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Server error.']);
    exit;
}

$stmt->bind_param('s', $channelName);

if (!$stmt->execute()) {
    $stmt->close();
    $conn->close();
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Query failed.']);
    exit;
}

$result = $stmt->get_result();
$rows = [];
while ($row = $result->fetch_assoc()) {
    $rows[] = [
        'id' => (string) $row['id'],
        'user_id' => (int) $row['user_id'],
        'user_name' => $row['user_name'],
        'text' => $row['text'],
        'is_emoji' => (int) $row['is_emoji'] === 1,
        'created_at' => $row['created_at'],
    ];
}
$stmt->close();
$conn->close();

echo json_encode([
    'success' => true,
    'data' => array_reverse($rows),
]);
