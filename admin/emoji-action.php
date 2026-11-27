<?php
include './includes/db.php';
header('Content-Type: application/json');

$id = intval($_POST['id']);
$action = $conn->real_escape_string($_POST['action']);

$response = ['success' => false, 'message' => 'Invalid action'];

try {
    switch ($action) {
        case "toggle_status":
            $current = $conn->query("SELECT status FROM emojis WHERE id = $id")->fetch_assoc();
            $new_status = $current['status'] == 'Active' ? 'Inactive' : 'Active';
            $conn->query("UPDATE emojis SET status = '$new_status' WHERE id = $id");
            $response = ['success' => true, 'message' => 'Status updated'];
            break;
            
        case "delete":
            // Get emoji data before deleting to remove image file
            $emoji_data = $conn->query("SELECT image_url FROM emojis WHERE id = $id")->fetch_assoc();
            
            // Delete uploaded image file if exists
            if (!empty($emoji_data['image_url']) && strpos($emoji_data['image_url'], './uploads/emojis/') === 0) {
                $file_path = $emoji_data['image_url'];
                if (file_exists($file_path)) {
                    unlink($file_path);
                }
            }
            
            $conn->query("DELETE FROM emojis WHERE id = $id");
            $response = ['success' => true, 'message' => 'Emoji deleted'];
            break;
            
        default:
            $response = ['success' => false, 'message' => 'Unknown action'];
    }
} catch (Exception $e) {
    $response = ['success' => false, 'message' => 'Database error: ' . $e->getMessage()];
}

echo json_encode($response);
?>