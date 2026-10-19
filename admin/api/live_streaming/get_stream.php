<?php

// Ensure this file is accessed via GET request and has necessary parameters
if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405); // Method Not Allowed
    echo json_encode(['error' => 'Method not allowed.']);
    exit();
}

// Include necessary configuration and helper functions
require_once '../../includes/config.php'; // For STREAM_API_BASE_URL
require_once '../../includes/stream_api_helper.php'; // For StreamApiHelper class
require_once '../../includes/db.php'; // For database connection
require_once '../../includes/LiveStreamModel.php'; // For LiveStreamModel class

// Check for database connection error
if (isset($db_connection_error)) {
    http_response_code(500);
    echo json_encode(['error' => 'Database connection failed: ' . $db_connection_error]);
    exit();
}

// Instantiate LiveStreamModel
$liveStreamModel = new LiveStreamModel($conn);

// Assuming a config file exists or environment variables are used for API keys
$streamApiKey = getenv('STREAM_API_KEY') ?: 'YOUR_STREAM_API_KEY'; // Replace with your Stream API Key
$streamApiSecret = getenv('STREAM_API_SECRET') ?: 'YOUR_STREAM_API_SECRET'; // Replace with your Stream API Secret

// Get stream ID from the request (e.g., from GET parameters)
$streamId = $_GET['stream_id'] ?? null;

if (!$streamId) {
    http_response_code(400); // Bad Request
    echo json_encode(['error' => 'Stream ID is required.']);
    exit();
}

// First, try to get stream details from the local database
$localStream = $liveStreamModel->getLiveStreamById($streamId);

if ($localStream) {
    // If found in local DB, return it
    header('Content-Type: application/json');
    echo json_encode(['success' => true, 'data' => $localStream]);
    exit();
}

// If not found in local DB, then query the Stream API
// Instantiate StreamApiHelper
$streamApi = new StreamApiHelper($streamApiKey, $streamApiSecret);

// Get the stream information using the helper
$response = $streamApi->getStream($streamId);

if (!$response['success']) {
    http_response_code($response['http_code'] ?? 500);
    echo json_encode(['error' => $response['error'], 'details' => $response['details'] ?? null]);
    exit();
}

// Return the stream information from Stream API
header('Content-Type: application/json');
echo json_encode(['success' => true, 'data' => $response['data']]);

?>