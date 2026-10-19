<?php
include './includes/db.php';
header('Content-Type: application/json');

$id = intval($_POST['id'] ?? 0);
$action = $_POST['action'] ?? '';

if(!$id || !in_array($action, ['toggle_status','delete'])){
    echo json_encode(['success'=>false,'message'=>'Invalid request']);
    exit;
}

try {
    switch ($action) {
        case "toggle_status":
            // Get current status
            $stmt = $conn->prepare("SELECT status FROM `groups` WHERE id = ?");
            $stmt->bind_param("i", $id);
            $stmt->execute();
            $result = $stmt->get_result();
            $current = $result->fetch_assoc();
            
            if(!$current) {
                echo json_encode(['success'=>false,'message'=>'Group not found']);
                exit;
            }
            
            $new_status = $current['status'] == 'Active' ? 'Inactive' : 'Active';
            
            // Update status
            $stmt = $conn->prepare("UPDATE `groups` SET status = ? WHERE id = ?");
            $stmt->bind_param("si", $new_status, $id);
            
            if($stmt->execute()) {
                echo json_encode(['success'=>true, 'message'=>'Status updated successfully']);
            } else {
                echo json_encode(['success'=>false,'message'=>'Failed to update status']);
            }
            break;
            
        case "delete":
            // Delete group members first
            $stmt = $conn->prepare("DELETE FROM group_members WHERE group_id = ?");
            $stmt->bind_param("i", $id);
            $stmt->execute();
            
            // Then delete group
            $stmt = $conn->prepare("DELETE FROM `groups` WHERE id = ?");
            $stmt->bind_param("i", $id);
            
            if($stmt->execute()) {
                echo json_encode(['success'=>true, 'message'=>'Group deleted successfully']);
            } else {
                echo json_encode(['success'=>false,'message'=>'Failed to delete group']);
            }
            break;
            
        default:
            echo json_encode(['success'=>false,'message'=>'Unknown action']);
    }
} catch (Exception $e) {
    echo json_encode(['success'=>false,'message'=>'Database error']);
}
?>