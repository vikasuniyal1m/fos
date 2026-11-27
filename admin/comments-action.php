<?php
include './includes/db.php';

header('Content-Type: application/json');

$id = intval($_POST['id'] ?? 0);
$action = $_POST['action'] ?? '';

if(!$id || !in_array($action, ['approve','reject','delete'])){
    echo json_encode(['success'=>false,'message'=>'Invalid request']);
    exit;
}

if($action == 'delete'){
    $stmt = $conn->prepare("DELETE FROM comments WHERE id=?");
    $stmt->bind_param('i', $id);
    if($stmt->execute()){
        echo json_encode(['success'=>true]);
    }else{
        echo json_encode(['success'=>false,'message'=>'Failed to delete comment']);
    }
}else{
    $status = $action=='approve' ? 'approved' : 'rejected';
    $stmt = $conn->prepare("UPDATE comments SET status=? WHERE id=?");
    $stmt->bind_param('si', $status, $id);
    if($stmt->execute()){
        echo json_encode(['success'=>true]);
    }else{
        echo json_encode(['success'=>false,'message'=>'Failed to update status']);
    }
}
