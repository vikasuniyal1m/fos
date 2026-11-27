<?php
/**
 * E-Commerce API
 * Returns e-commerce store URL/link configuration
 */

require_once '../includes/db.php';
require_once '../includes/cors.php';
require_once '../includes/config.php';

header('Content-Type: application/json');

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'OPTIONS') {
    http_response_code(200);
    exit;
}

if ($method === 'GET') {
    // Get e-commerce URL from system settings or config
    $ecommerce_url = '';
    
    // Check if ecommerce_url exists in system_settings table
    $check_column = @$conn->query("SHOW COLUMNS FROM system_settings LIKE 'ecommerce_url'");
    if ($check_column && $check_column->num_rows > 0) {
        $stmt = $conn->prepare("SELECT ecommerce_url FROM system_settings WHERE id = 1");
        $stmt->execute();
        $result = $stmt->get_result();
        if ($result->num_rows > 0) {
            $row = $result->fetch_assoc();
            $ecommerce_url = $row['ecommerce_url'] ?? '';
        }
    }
    
    // If not in database, use config constant (if defined)
    if (empty($ecommerce_url) && defined('ECOMMERCE_URL')) {
        $ecommerce_url = ECOMMERCE_URL;
    }
    
    // Default fallback
    if (empty($ecommerce_url)) {
        $ecommerce_url = 'https://your-ecommerce-app-url.com';
    }
    
    echo json_encode([
        'success' => true,
        'data' => [
            'url' => $ecommerce_url,
            'type' => 'web', // 'web', 'deep_link', 'play_store', 'app_store'
            'message' => 'E-commerce URL retrieved'
        ]
    ]);
} else {
    http_response_code(405);
    echo json_encode([
        'success' => false,
        'message' => 'Method not allowed'
    ]);
}

$conn->close();
?>

