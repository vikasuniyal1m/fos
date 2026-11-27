<?php
include_once __DIR__ . '/../includes/db.php';

// $conn is already created in db.php
if (isset($db_connection_error)) {
    die("Connection failed: " . $db_connection_error);
}

// Add columns if they don't exist
$result = $conn->query("SHOW COLUMNS FROM live_videos LIKE 'channel_name'");
if ($result->num_rows == 0) {
    $conn->query("ALTER TABLE live_videos ADD COLUMN channel_name VARCHAR(255) NULL AFTER stream_key");
    echo "Added channel_name column\n";
}

$result = $conn->query("SHOW COLUMNS FROM live_videos LIKE 'agora_token'");
if ($result->num_rows == 0) {
    $conn->query("ALTER TABLE live_videos ADD COLUMN agora_token TEXT NULL AFTER channel_name");
    echo "Added agora_token column\n";
}

echo "Database migration completed!";
?>
