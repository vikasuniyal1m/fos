<?php
include './includes/db.php';
header('Content-Type: application/json');

$user_id = intval($_POST['user_id'] ?? 0);
$group_id = intval($_POST['group_id'] ?? 0);
$action = $_POST['action'] ?? '';

if(!$user_id || !$group_id || !in_array($action, ['make_admin','remove_member'])){
    echo json_encode(['success'=>false,'message'=>'Invalid request']);
    exit;
}

try {
    switch ($action) {
        case "make_admin":
            $stmt = $conn->prepare("UPDATE group_members SET role = 'Admin' WHERE user_id = ? AND group_id = ?");
            $stmt->bind_param("ii", $user_id, $group_id);
            
            if($stmt->execute()) {
                echo json_encode(['success'=>true, 'message'=>'Member promoted to admin successfully']);
            } else {
                echo json_encode(['success'=>false,'message'=>'Failed to promote member']);
            }
            break;
            
        case "remove_member":
            $stmt = $conn->prepare("DELETE FROM group_members WHERE user_id = ? AND group_id = ?");
            $stmt->bind_param("ii", $user_id, $group_id);
            
            if($stmt->execute()) {
                echo json_encode(['success'=>true, 'message'=>'Member removed from group successfully']);
            } else {
                echo json_encode(['success'=>false,'message'=>'Failed to remove member']);
            }
            break;
            
        default:
            echo json_encode(['success'=>false,'message'=>'Unknown action']);
    }
} catch (Exception $e) {
    echo json_encode(['success'=>false,'message'=>'Database error: '.$e->getMessage()]);
}
?>