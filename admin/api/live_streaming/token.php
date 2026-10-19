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

// Assuming a config file exists or environment variables are used for API keys
// For now, we'll use placeholders. You'll need to replace these with your actual Stream API keys.
// It's highly recommended to load these from environment variables or a secure config file.
$streamApiKey = getenv('STREAM_API_KEY') ?: 'YOUR_STREAM_API_KEY'; // Replace with your Stream API Key
$streamApiSecret = getenv('STREAM_API_SECRET') ?: 'YOUR_STREAM_API_SECRET'; // Replace with your Stream API Secret

// Get user ID from the request (e.g., from POST data or authenticated session)
// For this example, we'll assume it's sent in the POST body.
$input = json_decode(file_get_contents('php://input'), true);
$userId = $input['user_id'] ?? null;

if (!$userId) {
    http_response_code(400); // Bad Request
    echo json_encode(['error' => 'User ID is required.']);
    exit();
}

// Instantiate StreamApiHelper
$streamApi = new StreamApiHelper($streamApiKey, $streamApiSecret);

// Generate the token using the helper
$response = $streamApi->generateToken($userId);

if (!$response['success']) {
    http_response_code($response['http_code'] ?? 500);
    echo json_encode(['error' => $response['error'], 'details' => $response['details'] ?? null]);
    exit();
}

$token = $response['data']['token'] ?? null;

if (!$token) {
    http_response_code(500);
    echo json_encode(['error' => 'Failed to retrieve token from Stream API response.']);
    exit();
}

// Return the token
header('Content-Type: application/json');
echo json_encode(['token' => $token]);

?>