<?php
include './includes/db.php';

$id = $_GET['id'] ?? 0;

if ($id) {
    $stmt = $conn->prepare("UPDATE notifications SET is_read = 1 WHERE id = ?");
    $stmt->bind_param("i", $id);
    $stmt->execute();
    
    echo "Notification marked as read";
} else {
    echo "Invalid notification ID";
}
?>