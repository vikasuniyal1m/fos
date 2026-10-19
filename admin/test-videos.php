<?php
include './includes/db.php';

$videos = $conn->query("
    SELECT lv.*, u.name as user_name, u.email 
    FROM live_videos lv 
    LEFT JOIN users u ON lv.user_id = u.id 
    ORDER BY lv.created_at DESC
");

echo "Total videos found: " . $videos->num_rows . "<br><br>";

if ($videos->num_rows > 0) {
    while ($video = $videos->fetch_assoc()) {
        echo "ID: " . $video['id'] . " - Title: " . $video['title'] . " - Status: " . $video['status'] . "<br>";
    }
} else {
    echo "No videos found in database";
}
?>