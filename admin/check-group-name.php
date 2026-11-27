<?php
include './includes/db.php';

if (isset($_POST['name'])) {
    $name = $conn->real_escape_string($_POST['name']);
    
    $sql = "SELECT id FROM `groups` WHERE name = '$name'";
    $result = $conn->query($sql);
    
    if ($result->num_rows > 0) {
        echo json_encode(['exists' => true]);
    } else {
        echo json_encode(['exists' => false]);
    }
} else {
    echo json_encode(['error' => 'No name provided']);
}
?>