<?php
include './includes/db.php';
header('Content-Type: application/json');

$id     = $_POST['id'] ?? 0;
$action = $_POST['action'] ?? '';

if (!$id || !$action) {
    echo json_encode(["success" => false, "message" => "Invalid request"]);
    exit;
}

$id = (int)$id;

switch ($action) {
    case "approve":
        $sql = "UPDATE blogs SET status='Approved' WHERE id=$id";
        break;

    case "reject":
        $sql = "UPDATE blogs SET status='Rejected' WHERE id=$id";
        break;

    case "delete":
        $sql = "DELETE FROM blogs WHERE id=$id";
        break;

    default:
        echo json_encode(["success" => false, "message" => "Unknown action"]);
        exit;
}

if ($conn->query($sql)) {
    echo json_encode(["success" => true]);
} else {
    echo json_encode(["success" => false, "message" => $conn->error]);
}
?>
