<?php
/**
 * Apple In-App Purchase Receipt Verification API
 * POST /api/iap-verify.php
 * 
 * Validates App Store receipt with Apple's verifyReceipt endpoint
 * and records the purchase in the database
 * 
 * SECURITY:
 * - Receipt validated server-side with Apple
 * - Purchase status verified before granting access
 * - Duplicate transaction prevention
 */

ob_start();

require_once '../includes/db.php';
require_once '../includes/cors.php';
require_once 'auth-helper.php';

header('Content-Type: application/json; charset=utf-8');

$method = $_SERVER['REQUEST_METHOD'];

// Handle OPTIONS request
if ($method === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// Only accept POST
if ($method !== 'POST') {
    echo jsonResponse(false, 'Method not allowed', null, 405);
    exit;
}

try {
    // Verify user authentication using auth-helper
    $user = requireAuth($conn);
    $userId = $user['id'];
    
    // Get request data
    $data = json_decode(file_get_contents('php://input'), true);
    
    // Required fields
    $receiptData = $data['receipt_data'] ?? null;
    $productId = $data['product_id'] ?? null;
    $transactionId = $data['transaction_id'] ?? null;
    $isSandbox = $data['is_sandbox'] ?? false;
    
    // Validation
    if (!$receiptData) {
        echo jsonResponse(false, 'Receipt data is required', ['field' => 'receipt_data'], 400);
        exit;
    }
    if (!$productId) {
        echo jsonResponse(false, 'Product ID is required', ['field' => 'product_id'], 400);
        exit;
    }
    if (!$transactionId) {
        echo jsonResponse(false, 'Transaction ID is required', ['field' => 'transaction_id'], 400);
        exit;
    }
    
    // Check for duplicate transaction
    $checkStmt = $conn->prepare("SELECT id, status FROM iap_transactions WHERE transaction_id = ? AND platform = 'ios'");
    $checkStmt->bind_param("s", $transactionId);
    $checkStmt->execute();
    $existing = $checkStmt->get_result()->fetch_assoc();
    
    if ($existing) {
        if ($existing['status'] === 'completed') {
            echo jsonResponse(true, 'Purchase already verified', [
                'transaction_id' => $transactionId,
                'status' => 'already_verified',
                'product_id' => $productId
            ]);
            exit;
        }
    }
    
    // Apple App Store endpoints
    $appleUrl = $isSandbox 
        ? 'https://sandbox.itunes.apple.com/verifyReceipt'
        : 'https://buy.itunes.apple.com/verifyReceipt';
    
    // Shared secret from config (if available)
    $sharedSecret = defined('APPLE_SHARED_SECRET') ? APPLE_SHARED_SECRET : '';
    
    // Prepare request to Apple
    $requestData = [
        'receipt-data' => $receiptData,
        'password' => $sharedSecret,
        'exclude-old-transactions' => true
    ];
    
    // Call Apple's verifyReceipt API
    $ch = curl_init($appleUrl);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($requestData));
    curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
    curl_setopt($ch, CURLOPT_TIMEOUT, 30);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, true);
    
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $curlError = curl_error($ch);
    curl_close($ch);
    
    if ($curlError) {
        throw new Exception('Failed to connect to Apple: ' . $curlError);
    }
    
    if ($httpCode !== 200) {
        throw new Exception('Apple server returned error: HTTP ' . $httpCode);
    }
    
    $appleResponse = json_decode($response, true);
    
    if (!$appleResponse) {
        throw new Exception('Invalid response from Apple');
    }
    
    // Check Apple status codes
    $status = $appleResponse['status'] ?? -1;
    
    // Auto-detect sandbox/production mismatch
    if ($status === 21007 && !$isSandbox) {
        $ch = curl_init('https://sandbox.itunes.apple.com/verifyReceipt');
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($requestData));
        curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
        curl_setopt($ch, CURLOPT_TIMEOUT, 30);
        
        $response = curl_exec($ch);
        curl_close($ch);
        
        $appleResponse = json_decode($response, true);
        $status = $appleResponse['status'] ?? -1;
        $isSandbox = true;
    }
    
    // Apple status code meanings
    if ($status !== 0) {
        $errorMessages = [
            21000 => 'App store could not read the JSON object',
            21002 => 'Receipt data property is malformed or missing',
            21003 => 'Receipt could not be authenticated',
            21004 => 'Shared secret does not match',
            21005 => 'Receipt server unavailable',
            21006 => 'Subscription expired (but valid receipt data)',
            21007 => 'Sandbox receipt sent to production',
            21008 => 'Production receipt sent to sandbox',
            21010 => 'Receipt not authorized for production',
            21100 => 'Internal data access error'
        ];
        
        $errorMessage = $errorMessages[$status] ?? 'Unknown error (status: ' . $status . ')';
        
        // Log failed verification
        $logStmt = $conn->prepare("INSERT INTO iap_transactions (user_id, platform, product_id, transaction_id, status, receipt_data, apple_status, error_message, created_at) VALUES (?, 'ios', ?, ?, 'failed', ?, ?, ?, NOW())");
        $logStmt->bind_param("ississ", $userId, $productId, $transactionId, $receiptData, $status, $errorMessage);
        $logStmt->execute();
        
        echo jsonResponse(false, 'Receipt verification failed: ' . $errorMessage, ['apple_status' => $status], 400);
        exit;
    }
    
    // Parse receipt information
    $receiptInfo = $appleResponse['receipt'] ?? [];
    $inAppPurchases = $receiptInfo['in_app'] ?? [];
    
    // Find the specific transaction
    $verifiedPurchase = null;
    foreach ($inAppPurchases as $purchase) {
        if ($purchase['transaction_id'] === $transactionId || $purchase['original_transaction_id'] === $transactionId) {
            $verifiedPurchase = $purchase;
            break;
        }
    }
    
    // Also check latest_receipt_info for subscriptions
    if (!$verifiedPurchase && isset($appleResponse['latest_receipt_info'])) {
        foreach ($appleResponse['latest_receipt_info'] as $purchase) {
            if ($purchase['transaction_id'] === $transactionId || $purchase['original_transaction_id'] === $transactionId) {
                $verifiedPurchase = $purchase;
                break;
            }
        }
    }
    
    if (!$verifiedPurchase) {
        // Log but don't fail
        $logStmt = $conn->prepare("INSERT INTO iap_transactions (user_id, platform, product_id, transaction_id, status, receipt_data, apple_status, created_at) VALUES (?, 'ios', ?, ?, 'pending_review', ?, 0, NOW())");
        $logStmt->bind_param("isss", $userId, $productId, $transactionId, $receiptData);
        $logStmt->execute();
        
        echo jsonResponse(true, 'Receipt valid, purchase pending review', [
            'transaction_id' => $transactionId,
            'status' => 'pending_review',
            'product_id' => $productId
        ]);
        exit;
    }
    
    // Verify product ID matches
    $receiptProductId = $verifiedPurchase['product_id'] ?? '';
    if ($receiptProductId !== $productId) {
        echo jsonResponse(false, 'Product ID mismatch', [
            'expected' => $productId,
            'received' => $receiptProductId
        ], 400);
        exit;
    }
    
    // Record the successful transaction
    $purchaseDate = isset($verifiedPurchase['purchase_date_ms']) 
        ? date('Y-m-d H:i:s', $verifiedPurchase['purchase_date_ms'] / 1000)
        : date('Y-m-d H:i:s');
    
    $expiresDate = null;
    if (isset($verifiedPurchase['expires_date_ms'])) {
        $expiresDate = date('Y-m-d H:i:s', $verifiedPurchase['expires_date_ms'] / 1000);
    }
    
    $insertStmt = $conn->prepare("
        INSERT INTO iap_transactions 
        (user_id, platform, product_id, transaction_id, original_transaction_id, status, 
         receipt_data, purchase_date, expires_date, is_sandbox, apple_status, created_at)
        VALUES (?, 'ios', ?, ?, ?, 'completed', ?, ?, ?, ?, 0, NOW())
        ON DUPLICATE KEY UPDATE
        status = 'completed',
        receipt_data = VALUES(receipt_data),
        updated_at = NOW()
    ");
    
    $originalTransactionId = $verifiedPurchase['original_transaction_id'] ?? $transactionId;
    
    $insertStmt->bind_param(
        "issssssi", 
        $userId, 
        $productId, 
        $transactionId, 
        $originalTransactionId,
        $receiptData,
        $purchaseDate,
        $expiresDate,
        $isSandbox ? 1 : 0
    );
    $insertStmt->execute();
    
    // Update users table for lifetime/premium purchases
    if (strpos($productId, 'lifetime') !== false || strpos($productId, 'premium') !== false) {
        $updateUser = $conn->prepare("
            UPDATE users 
            SET is_lifetime_premium = 1,
                lifetime_purchase_date = NOW(),
                apple_transaction_id = ?,
                apple_product_id = ?
            WHERE id = ?
        ");
        $updateUser->bind_param("ssi", $transactionId, $productId, $userId);
        $updateUser->execute();
    }
    
    // Return success
    echo jsonResponse(true, 'Purchase verified successfully', [
        'transaction_id' => $transactionId,
        'original_transaction_id' => $originalTransactionId,
        'product_id' => $productId,
        'status' => 'completed',
        'purchase_date' => $purchaseDate,
        'expires_date' => $expiresDate,
        'is_sandbox' => $isSandbox,
        'receipt_valid' => true
    ]);
    exit;
    
} catch (Exception $e) {
    echo jsonResponse(false, 'Failed to verify purchase: ' . $e->getMessage());
    exit;
}
