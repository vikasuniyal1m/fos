<?php
include './includes/db.php';
header('Content-Type: application/json');

$id = intval($_POST['id'] ?? 0);
$action = $_POST['action'] ?? '';

$response = ['success' => false, 'message' => ''];

if($id > 0 && in_array($action, ['approve', 'block', 'delete'])) {
    try {
        if($action == 'delete') {
            $stmt = $conn->prepare("DELETE FROM users WHERE id = ?");
            $stmt->bind_param("i", $id);
            if($stmt->execute()) {
                $response = ['success' => true, 'message' => 'User deleted successfully'];
            }
        } else {
            $new_status = $action == 'approve' ? 'Active' : 'Inactive';
            $stmt = $conn->prepare("UPDATE users SET status = ? WHERE id = ?");
            $stmt->bind_param("si", $new_status, $id);
            if($stmt->execute()) {
                $response = ['success' => true, 'message' => "User {$action}d successfully"];
            }
        }
    } catch(Exception $e) {
        $response = ['success' => false, 'message' => 'Database error'];
    }
} else {
    $response = ['success' => false, 'message' => 'Invalid request'];
}

echo json_encode($response);
?>