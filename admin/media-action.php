<?php
include './includes/db.php';
header('Content-Type: application/json');

$id = intval($_POST['id'] ?? 0);
$action = $_POST['action'] ?? '';

if (!$id || !$action) {
    echo json_encode(['success' => false, 'message' => 'Invalid request']);
    exit;
}

// Map action to display status text
$statusMap = [
    'approve' => 'Approved',
    'reject'  => 'Rejected'
];

switch ($action) {
    case 'approve':
    case 'reject':
        $statusText = $statusMap[$action];
        $stmt = $conn->prepare("UPDATE media_items SET status=? WHERE id=?");
        $stmt->bind_param("si", $statusText, $id);
        $stmt->execute();
        break;

    case 'delete':
        // Optional: remove file from server
        $stmt = $conn->prepare("SELECT file_path FROM media_items WHERE id=?");
        $stmt->bind_param("i", $id);
        $stmt->execute();
        $res = $stmt->get_result()->fetch_assoc();
        if ($res && file_exists($res['file_path'])) {
            unlink($res['file_path']);
        }

        $stmt = $conn->prepare("DELETE FROM media_items WHERE id=?");
        $stmt->bind_param("i", $id);
        $stmt->execute();
        break;

    default:
        echo json_encode(['success' => false, 'message' => 'Invalid action']);
        exit;
}

echo json_encode(['success' => true, 'status' => $statusText ?? null]);
?>
