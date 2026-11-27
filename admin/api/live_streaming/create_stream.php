<?php

// Ensure this file is accessed via POST request and has necessary parameters
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
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

// Get stream details from the request body
$input = json_decode(file_get_contents('php://input'), true);
$streamId = $input['stream_id'] ?? null;
$userId = $input['user_id'] ?? null;
$title = $input['title'] ?? 'Untitled Stream'; // Placeholder
$description = $input['description'] ?? 'No description provided.'; // Placeholder
$options = $input['options'] ?? []; // Additional options for stream creation

if (!$streamId || !$userId) {
    http_response_code(400); // Bad Request
    echo json_encode(['error' => 'Stream ID and User ID are required.']);
    exit();
}

// Instantiate StreamApiHelper
$streamApi = new StreamApiHelper($streamApiKey, $streamApiSecret);

// Create the stream using the helper
$response = $streamApi->createStream($streamId, $userId, $options);

if (!$response['success']) {
    http_response_code($response['http_code'] ?? 500);
    echo json_encode(['error' => $response['error'], 'details' => $response['details'] ?? null]);
    exit();
}

// Extract stream_url and thumbnail_url from the Stream API response if available
$stream_url = $response['data']['stream_url'] ?? 'N/A'; // Assuming Stream API returns this
$thumbnail_url = $response['data']['thumbnail_url'] ?? 'N/A'; // Assuming Stream API returns this

// Store stream details in the database
$db_insert_result = $liveStreamModel->createLiveStream(
    $streamId,
    $userId,
    $title,
    $description,
    'created', // Initial status
    $stream_url,
    $thumbnail_url
);

if (!$db_insert_result['success']) {
    // Log the database error but still return success for Stream API creation
    error_log("Database error storing live stream: " . $db_insert_result['error']);
    // Optionally, you might want to delete the stream from Stream API if DB insert fails critically
}

// Return the created stream information
header('Content-Type: application/json');
echo json_encode(['success' => true, 'data' => $response['data']]);

?>