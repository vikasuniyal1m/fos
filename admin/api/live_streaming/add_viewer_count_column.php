<?php
/**
 * Migration script to add viewer_count column to live_streams table
 * Run this once to add the column if it doesn't exist
 */

require_once __DIR__ . '/../../includes/db.php';

if (isset($db_connection_error)) {
    header('Content-Type: application/json');
    echo json_encode(['success' => false, 'message' => 'Database connection failed: ' . $db_connection_error]);
    exit;
}

// Check if viewer_count column exists
$checkColumn = "SHOW COLUMNS FROM live_streams LIKE 'viewer_count'";
$result = $conn->query($checkColumn);

if ($result && $result->num_rows > 0) {
    header('Content-Type: application/json');
    echo json_encode(['success' => true, 'message' => 'viewer_count column already exists']);
    exit;
}

// Add viewer_count column
$sql = "ALTER TABLE live_streams ADD COLUMN viewer_count INT DEFAULT 0";

if ($conn->query($sql) === TRUE) {
    header('Content-Type: application/json');
    echo json_encode(['success' => true, 'message' => 'viewer_count column added successfully']);
} else {
    header('Content-Type: application/json');
    echo json_encode(['success' => false, 'message' => 'Error adding column: ' . $conn->error]);
}
