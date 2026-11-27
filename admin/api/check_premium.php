<?php
/**
 * Check User Premium Status API
 * GET /api/check_premium.php
 * 
 * Returns whether a user has premium status from database
 */

require_once __DIR__ . '/../includes/db.php';
require_once __DIR__ . '/../includes/cors.php';
require_once __DIR__ . '/auth-helper.php';
require_once __DIR__ . '/../includes/iap_premium_helper.php';

header('Content-Type: application/json; charset=utf-8');

$method = $_SERVER['REQUEST_METHOD'];

// Handle OPTIONS request
if ($method === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// Only accept GET
if ($method !== 'GET') {
    http_response_code(405);
    echo jsonResponse(false, 'Method not allowed');
    exit;
}

try {
    // Get user_id from query parameter (no auth required for premium check)
    $userId = $_GET['user_id'] ?? null;
    
    if (!$userId || !is_numeric($userId)) {
        http_response_code(400);
        echo jsonResponse(false, 'User ID is required');
        exit;
    }
    
    // Sync premium by email (paid on Android → free on iOS, same email)
    fos_sync_premium_by_email($conn, (int) $userId);

    $stmt = $conn->prepare("SELECT is_lifetime_premium, lifetime_purchase_date, email, iap_purchase_type, iap_platform FROM users WHERE id = ?");
    $stmt->bind_param("i", $userId);
    $stmt->execute();
    $result = $stmt->get_result()->fetch_assoc();
    
    if ($result) {
        $isPremium = (bool)($result['is_lifetime_premium'] ?? 0);
        $purchaseDate = $result['lifetime_purchase_date'] ?? null;
        
        echo jsonResponse(true, 'Premium status retrieved', [
            'is_premium' => $isPremium,
            'purchase_date' => $purchaseDate,
            'iap_purchase_type' => $result['iap_purchase_type'] ?? null,
            'iap_platform' => $result['iap_platform'] ?? null,
            'email_linked' => fos_normalize_email($result['email'] ?? '') !== '',
        ]);
    } else {
        http_response_code(404);
        echo jsonResponse(false, 'User not found');
    }
} catch (Exception $e) {
    http_response_code(500);
    echo jsonResponse(false, 'Failed to check premium status: ' . $e->getMessage());
    exit;
}
?>