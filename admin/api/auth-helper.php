<?php
/**
 * User Authentication Helper for API
 * This file provides helper functions for user authentication in APIs
 */

require_once __DIR__ . '/../includes/db.php';
require_once __DIR__ . '/../includes/cors.php';

/**
 * Get user from token or session
 * Returns user data if authenticated, null otherwise
 */
function getAuthenticatedUser($conn) {
    // Check for Bearer token in Authorization header
    $headers = getallheaders();
    $token = null;
    
    if (isset($headers['Authorization'])) {
        $authHeader = $headers['Authorization'];
        if (preg_match('/Bearer\s+(.*)$/i', $authHeader, $matches)) {
            $token = $matches[1];
        }
    }
    
    // If no token, check for user_id in request
    if (!$token && isset($_POST['user_id'])) {
        $user_id = intval($_POST['user_id']);
        $stmt = $conn->prepare("SELECT * FROM users WHERE id = ? AND status = 'Active'");
        $stmt->bind_param("i", $user_id);
        $stmt->execute();
        $result = $stmt->get_result();
        if ($result->num_rows > 0) {
            return $result->fetch_assoc();
        }
    }
    
    // If no token, check GET parameter
    if (!$token && isset($_GET['user_id'])) {
        $user_id = intval($_GET['user_id']);
        $stmt = $conn->prepare("SELECT * FROM users WHERE id = ? AND status = 'Active'");
        $stmt->bind_param("i", $user_id);
        $stmt->execute();
        $result = $stmt->get_result();
        if ($result->num_rows > 0) {
            return $result->fetch_assoc();
        }
    }
    
    // TODO: Implement token-based authentication if needed
    // For now, return null if no user_id provided
    return null;
}

/**
 * Check if user is authenticated
 */
function isUserAuthenticated($conn) {
    return getAuthenticatedUser($conn) !== null;
}

/**
 * Require authentication - sends 401 if not authenticated
 */
function requireAuth($conn) {
    $user = getAuthenticatedUser($conn);
    if (!$user) {
        http_response_code(401);
        echo json_encode(['success' => false, 'message' => 'Authentication required']);
        exit;
    }
    return $user;
}

/**
 * Check if user is a blogger or admin
 */
function isBlogger($conn, $user_id) {
    $stmt = $conn->prepare("SELECT role FROM users WHERE id = ? AND (role = 'Blogger' OR role = 'Admin')");
    $stmt->bind_param("i", $user_id);
    $stmt->execute();
    $result = $stmt->get_result();
    return $result->num_rows > 0;
}

/**
 * Standard JSON response helper
 */
function jsonResponse($success, $message = '', $data = null) {
    // Only set headers if they haven't been sent yet
    if (!headers_sent()) {
        header('Content-Type: application/json; charset=utf-8');
    }
    $response = ['success' => $success];
    if ($message) $response['message'] = $message;
    
    // Conditionally add error details if APP_DEBUG is true and it's an error response
    if (defined('APP_DEBUG') && APP_DEBUG === true && $success === false && is_array($data) && isset($data['error'])) {
        $response['error_details'] = [
            'error' => $data['error'],
            'file' => $data['file'] ?? 'N/A',
            'line' => $data['line'] ?? 'N/A',
            'code' => $data['code'] ?? 'N/A'
        ];
        // Remove these from the main data array if they were there
        unset($data['error']);
        unset($data['file']);
        unset($data['line']);
        unset($data['code']);
    }

    if ($data !== null) $response['data'] = $data;
    // Use JSON_UNESCAPED_UNICODE to preserve emoji characters
    return json_encode($response, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
}