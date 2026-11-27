<?php
include './includes/db.php';
include './includes/admin-auth.php';

header('Content-Type: application/json');

$id = intval($_POST['id'] ?? 0);
$action = $_POST['action'] ?? '';

$allowed = ['reviewed', 'dismissed', 'action_taken'];
if (!$id || !in_array($action, $allowed)) {
    echo json_encode(['success' => false, 'message' => 'Invalid request']);
    exit;
}

$stmt = $conn->prepare("UPDATE short_reports SET status = ? WHERE id = ?");
$stmt->bind_param("si", $action, $id);

if ($stmt->execute()) {
    echo json_encode(['success' => true, 'message' => 'Report updated']);
} else {
    echo json_encode(['success' => false, 'message' => $conn->error]);
}
