<?php
include './includes/db.php';
include './includes/admin-auth.php';

header('Content-Type: application/json');

$id = intval($_POST['id'] ?? 0);
$action = $_POST['action'] ?? '';

if (!$id || !$action) {
    echo json_encode(['success' => false, 'message' => 'Invalid request']);
    exit;
}

$statusMap = [
    'approve' => 'Approved',
    'reject'  => 'Rejected',
    'hide'    => 'Hidden',
    'restore' => 'Approved',
    'delete'  => 'Deleted',
];

if (!isset($statusMap[$action])) {
    echo json_encode(['success' => false, 'message' => 'Unknown action']);
    exit;
}

$newStatus = $statusMap[$action];

if ($action === 'delete') {
    $stmt = $conn->prepare("UPDATE shorts SET status = 'Deleted', deleted_at = NOW() WHERE id = ?");
    $stmt->bind_param("i", $id);
} else {
    $stmt = $conn->prepare("UPDATE shorts SET status = ?, deleted_at = NULL WHERE id = ?");
    $stmt->bind_param("si", $newStatus, $id);
}

if ($stmt->execute()) {
    echo json_encode(['success' => true, 'message' => 'Short updated']);
} else {
    echo json_encode(['success' => false, 'message' => $conn->error]);
}
