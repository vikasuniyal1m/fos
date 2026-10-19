<?php
include './includes/db.php';

$id = $_POST['id'] ?? 0;
$action = $_POST['action'] ?? '';

$response = ['success'=>false,'message'=>'Invalid action'];

if($id && $action) {
    if($action=="approve") {
        $stmt = $conn->prepare("UPDATE prayer_requests SET status='Approved' WHERE id=?");
        $stmt->bind_param("i",$id);
        $stmt->execute();
        $response = ['success'=>true,'message'=>'Request approved'];
    } elseif($action=="reject") {
        $stmt = $conn->prepare("UPDATE prayer_requests SET status='Rejected' WHERE id=?");
        $stmt->bind_param("i",$id);
        $stmt->execute();
        $response = ['success'=>true,'message'=>'Request rejected'];
    } elseif($action=="delete") {
        $stmt = $conn->prepare("DELETE FROM prayer_requests WHERE id=?");
        $stmt->bind_param("i",$id);
        $stmt->execute();
        $response = ['success'=>true,'message'=>'Request deleted'];
    }
}

echo json_encode($response);
?>
