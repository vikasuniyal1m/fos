<?php
include './includes/db.php';
header('Content-Type: application/json');

$id = intval($_POST['id'] ?? 0);
$action = $_POST['action'] ?? '';

if(!$id || !in_array($action, ['approve','block','delete'])){
    echo json_encode(['success'=>false,'message'=>'Invalid request']);
    exit;
}

if($action == 'delete'){
    $stmt = $conn->prepare("DELETE FROM live_videos WHERE id=?");
    $stmt->bind_param('i', $id);
    if($stmt->execute()){
        echo json_encode(['success'=>true]);
    }else{
        echo json_encode(['success'=>false,'message'=>'Failed to delete video: '.$conn->error]);
    }
}else{
    // Simple mapping: approve → Live, block → Blocked
    $status = ($action == 'approve') ? 'Live' : 'Blocked';
    
    $stmt = $conn->prepare("UPDATE live_videos SET status=? WHERE id=?");
    $stmt->bind_param('si', $status, $id);
    if($stmt->execute()){
        echo json_encode(['success'=>true, 'status'=>$status]);
    }else{
        echo json_encode(['success'=>false,'message'=>'Failed to update status: '.$conn->error]);
    }
}
?>