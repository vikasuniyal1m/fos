<?php
include './includes/db.php';
header('Content-Type: application/json');

$id = intval($_POST['id']);
$action = $conn->real_escape_string($_POST['action']);

$response = ['success' => false, 'message' => 'Invalid action'];

try {
    switch ($action) {
        case "toggle_status":
            $current = $conn->query("SELECT status FROM languages WHERE id = $id")->fetch_assoc();
            $new_status = $current['status'] == 'Active' ? 'Inactive' : 'Active';
            $conn->query("UPDATE languages SET status = '$new_status' WHERE id = $id");
            $response = ['success' => true, 'message' => 'Status updated'];
            break;
            
        case "set_default":
            $conn->query("UPDATE languages SET is_default = 0");
            $conn->query("UPDATE languages SET is_default = 1 WHERE id = $id");
            $response = ['success' => true, 'message' => 'Default language set'];
            break;
            
        case "delete":
            $conn->query("DELETE FROM languages WHERE id = $id");
            $response = ['success' => true, 'message' => 'Language deleted'];
            break;
            
        default:
            $response = ['success' => false, 'message' => 'Unknown action'];
    }
} catch (Exception $e) {
    $response = ['success' => false, 'message' => 'Database error'];
}

echo json_encode($response);
?>