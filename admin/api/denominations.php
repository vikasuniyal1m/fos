<?php
/**
 * Denominations API
 * Handles: Fetching list of denominations
 */

require_once '../includes/db.php';
require_once '../includes/cors.php';

header('Content-Type: application/json; charset=utf-8');

$method = $_SERVER['REQUEST_METHOD'];
$action = $_GET['action'] ?? '';

// Handle OPTIONS request
if ($method === 'OPTIONS') {
    http_response_code(200);
    exit;
}

if ($method === 'GET') {
    if ($action === 'get_all') {
        handleGetAllDenominations($conn);
    } else {
        // Default to get all if no specific action
        handleGetAllDenominations($conn);
    }
} else {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Method not allowed']);
}

function handleGetAllDenominations($conn) {
    $sql = "SELECT * FROM denominations ORDER BY name ASC";
    $result = $conn->query($sql);

    if ($result) {
        $denominations = [];
        while ($row = $result->fetch_assoc()) {
            $denominations[] = $row;
        }
        
        echo json_encode(['success' => true, 'data' => $denominations]);
    } else {
        http_response_code(500);
        echo json_encode(['success' => false, 'message' => 'Failed to fetch denominations']);
    }
}

$conn->close();
?>
