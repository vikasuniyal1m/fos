<?php
/**
 * Add a comment to a live stream channel. Both host and viewers can add.
 * POST JSON: channel_name, user_id, user_name, text, is_emoji (optional).
 */

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    header('Content-Type: application/json');
    echo json_encode(['success' => false, 'message' => 'Method not allowed.']);
    exit;
}

require_once __DIR__ . '/../../includes/db.php';

if (isset($db_connection_error)) {
    http_response_code(500);
    header('Content-Type: application/json');
    echo json_encode(['success' => false, 'message' => 'Database connection failed.']);
    exit;
}

$input = json_decode(file_get_contents('php://input'), true) ?? [];
$channelName = trim((string) ($input['channel_name'] ?? ''));
$userId = (int) ($input['user_id'] ?? 0);
$userName = trim((string) ($input['user_name'] ?? 'User'));
$text = trim((string) ($input['text'] ?? ''));
$isEmoji = !empty($input['is_emoji']);

if ($channelName === '' || $text === '') {
    http_response_code(400);
    header('Content-Type: application/json');
    echo json_encode(['success' => false, 'message' => 'channel_name and text are required.']);
    exit;
}

if (strlen($text) > 2000) {
    http_response_code(400);
    header('Content-Type: application/json');
    echo json_encode(['success' => false, 'message' => 'Comment too long.']);
    exit;
}

$emojiInt = $isEmoji ? 1 : 0;
$stmt = $conn->prepare(
    'INSERT INTO live_comments (channel_name, user_id, user_name, text, is_emoji) VALUES (?, ?, ?, ?, ?)'
);
if (!$stmt) {
    http_response_code(500);
    header('Content-Type: application/json');
    echo json_encode(['success' => false, 'message' => 'Server error.']);
    exit;
}

$stmt->bind_param('sissi', $channelName, $userId, $userName, $text, $emojiInt);

if ($stmt->execute()) {
    $id = (int) $conn->insert_id;
    header('Content-Type: application/json');
    echo json_encode([
        'success' => true,
        'comment' => [
            'id' => (string) $id,
            'user_name' => $userName,
            'text' => $text,
            'is_emoji' => $isEmoji,
            'created_at' => date('c'),
        ],
    ]);
} else {
    http_response_code(500);
    header('Content-Type: application/json');
    echo json_encode(['success' => false, 'message' => 'Failed to save comment.']);
}

$stmt->close();
$conn->close();
