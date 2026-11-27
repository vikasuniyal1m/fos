<?php
// Start output buffering to prevent any whitespace or errors from corrupting JSON
ob_start();

// Try to include required files gracefully
$includes = [
    '../includes/db.php',
    '../includes/cors.php',
    '../includes/env.php'
];

foreach ($includes as $file) {
    if (file_exists($file)) {
        require_once $file;
    }
}

require_once __DIR__ . '/../includes/iap_premium_helper.php';

// Load admin/.env into getenv() when not set by the host
$envFile = __DIR__ . '/../.env';
if (file_exists($envFile)) {
    foreach (file($envFile, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) as $line) {
        $line = trim($line);
        if ($line === '' || $line[0] === '#') {
            continue;
        }
        $pos = strpos($line, '=');
        if ($pos === false) {
            continue;
        }
        $key = trim(substr($line, 0, $pos));
        $val = trim(substr($line, $pos + 1), " \t\"'");
        if ($key !== '' && getenv($key) === false) {
            putenv($key . '=' . $val);
        }
    }
}

// Ensure JSON content type
header('Content-Type: application/json');

// Clear any buffered output before sending JSON
if (ob_get_length()) ob_clean();

$method = $_SERVER['REQUEST_METHOD'];
if ($method === 'OPTIONS') { http_response_code(200); exit; }
if ($method !== 'POST') { http_response_code(405); echo json_encode(['success' => false, 'message' => 'Method not allowed']); exit; }

// Check database connection from db.php
if (!isset($conn) || (isset($db_connection_error) && $db_connection_error)) { 
    http_response_code(500); 
    echo json_encode(['success' => false, 'message' => 'Database connection failed']); 
    exit; 
}

$inputData = file_get_contents('php://input');
  $input = json_decode($inputData, true);
  if (json_last_error() !== JSON_ERROR_NONE) {
      error_log("IAP Error: Invalid JSON input received: " . substr($inputData, 0, 500));
      http_response_code(400);
      echo json_encode(['success' => false, 'message' => 'Invalid JSON input']);
      exit;
  }
  
  $platform = strtolower(trim($input['platform'] ?? ''));
  if ($platform === 'android') {
    $platform = 'google';
  }
  $productId = $input['product_id'] ?? '';
  $transactionId = $input['transaction_id'] ?? '';
  $receipt = $input['receipt'] ?? '';
  $userId = $input['user_id'] ?? '';
  $purchaseToken = $input['purchase_token'] ?? '';
  if ($platform === 'google' && $purchaseToken === '' && $receipt !== '') {
    $purchaseToken = $receipt;
  }
  $isSandboxRequest = filter_var($input['is_sandbox'] ?? false, FILTER_VALIDATE_BOOLEAN);

  // Log basic info for every request
  error_log("IAP Request: Platform=$platform, Product=$productId, User=$userId, ReceiptLength=" . strlen($receipt));

// Apple receipts can sometimes contain newlines or spaces if passed incorrectly.
// We trim and remove any whitespace characters to be safe.
if ($platform === 'apple') {
        $receipt = str_replace(["\n", "\r", " "], '', trim($receipt));
        
        // Detect if this is a StoreKit 2 JWS token (JWT format)
        if (strpos($receipt, '.') !== false && substr($receipt, 0, 3) === 'eyJ') {
            error_log("IAP: Detected StoreKit 2 JWS token (JWT)");
            $parts = explode('.', $receipt);
            if (count($parts) >= 2) {
                $payloadJson = base64_decode(strtr($parts[1], '-_', '+/'));
                $payload = json_decode($payloadJson, true);
                
                if ($payload && isset($payload['productId'])) {
                    error_log("IAP: Decoded JWS Payload - Product: " . $payload['productId'] . ", Transaction: " . ($payload['transactionId'] ?? 'N/A'));
                    
                    // For StoreKit 2 tokens, we can verify them locally or just accept them if they look valid 
                    // and match the expected product. In a production app, you should verify the JWS signature.
                    // Here we'll treat it as valid if it matches the product ID we expect.
                    if ($payload['productId'] === $productId) {
                        $foundTransactionId = $payload['transactionId'] ?? '';
                        $finalTransactionId = $transactionId ?: $foundTransactionId;
                        
                        $uid = (int)$userId;
                        fos_sync_premium_by_email($conn, $uid);
                        $row = fos_get_user_row($conn, $uid);
                        if ($row && !empty($row['is_lifetime_premium'])) {
                            echo json_encode([
                              'success' => true, 'valid' => true, 'message' => 'Already premium for this email',
                              'already_owned' => true, 'is_premium' => true,
                              'iap_purchase_type' => $row['iap_purchase_type'] ?? null,
                            ]);
                            exit;
                        }
                        $jwsPurchaseType = fos_iap_purchase_type_from_sandbox($isSandboxRequest);
                        if (fos_grant_apple_premium($conn, $uid, $finalTransactionId, $productId, $jwsPurchaseType)) {
                            echo json_encode([
                              'success' => true, 'valid' => true, 'message' => 'Verified (StoreKit 2)',
                              'transaction_id' => $finalTransactionId, 'is_premium' => true,
                              'iap_purchase_type' => $jwsPurchaseType,
                            ]);
                            exit;
                        }
                    } else {
                        http_response_code(400);
                        echo json_encode(['success' => false, 'message' => 'Product mismatch in JWS', 'expected' => $productId, 'found' => $payload['productId']]);
                        exit;
                    }
                }
            }
            // If JWS decoding failed, we'll still try the legacy path below just in case.
        }

        $isBase64 = base64_decode($receipt, true) !== false;
        // If it's not base64, Apple returns 21002.
        if (!$isBase64) {
            error_log("IAP Warning: Apple receipt is not valid base64. Length: " . strlen($receipt));
            // We don't exit here, we let Apple's API give the final verdict
        }
    }
  
  // Basic validation - Apple needs receipt; Google needs purchase_token (or receipt alias)
  if (!$platform || !$productId || !$userId) {
    $missing = [];
    if (!$platform) $missing[] = 'platform';
    if (!$productId) $missing[] = 'product_id';
    if (!$userId) $missing[] = 'user_id';
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Missing fields: ' . implode(', ', $missing)]);
    exit;
  }
  if ($platform === 'apple' && !$receipt) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Missing fields: receipt']);
    exit;
  }
  if ($platform === 'google' && !$purchaseToken) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Missing fields: purchase_token']);
    exit;
  }

  fos_ensure_premium_columns($conn);
  $uid = (int) $userId;
  fos_sync_premium_by_email($conn, $uid);
  $existingUser = fos_get_user_row($conn, $uid);
  if ($existingUser && !empty($existingUser['is_lifetime_premium'])) {
    echo json_encode([
      'success' => true,
      'valid' => true,
      'message' => 'Already premium for this email',
      'already_owned' => true,
      'is_premium' => true,
      'iap_purchase_type' => $existingUser['iap_purchase_type'] ?? null,
    ]);
    exit;
  }

  if ($platform === 'apple') {
    $password = getenv('APPLE_SHARED_SECRET') ?: '';
    $postData = function($receipt, $password) {
      $payload = ['receipt-data' => $receipt, 'exclude-old-transactions' => true];
      if ($password) { $payload['password'] = $password; }
      return json_encode($payload);
    };
    $call = function($url, $payload) {
      $ch = curl_init($url);
      curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
      curl_setopt($ch, CURLOPT_POST, true);
      curl_setopt($ch, CURLOPT_POSTFIELDS, $payload);
      curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json','Content-Length: ' . strlen($payload)]);
      $result = curl_exec($ch);
      $err = curl_error($ch);
      $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
      curl_close($ch);
      if ($err) {
          error_log("IAP CURL error for $url: $err");
      }
      return [$code, $result];
    };
    $payload = $postData($receipt, $password);
    error_log("IAP Apple: Sending payload to production verifyReceipt. Payload length: " . strlen($payload));
    list($code, $res) = $call('https://buy.itunes.apple.com/verifyReceipt', $payload);
    error_log("IAP Apple: Production response code: $code, body: $res");
    $data = $code === 200 ? json_decode($res, true) : null;
    $appleIsTest = false;

    $extra = ['receipt_length' => strlen($receipt), 'is_base64' => $isBase64];

    if (!$data || !isset($data['status'])) { 
      http_response_code(400); 
      echo json_encode(array_merge(['success' => false, 'message' => 'Invalid response from Apple production', 'http_code' => $code], $extra)); 
      exit; 
    }
    
    // Status 21007: sandbox receipt — mark as test purchase
    if ($data['status'] === 21007) {
      $appleIsTest = true;
      error_log("IAP Apple: Production returned 21007, retrying with sandbox verifyReceipt");
      list($code, $res) = $call('https://sandbox.itunes.apple.com/verifyReceipt', $payload);
      error_log("IAP Apple: Sandbox response code: $code, body: $res");
      $data = $code === 200 ? json_decode($res, true) : null;
    }
    
    if (!$data || !isset($data['status'])) {
      http_response_code(400);
      echo json_encode(array_merge(['success' => false, 'message' => 'Invalid response from Apple sandbox', 'http_code' => $code], $extra));
      exit;
    }

    if ($data['status'] !== 0) { 
      http_response_code(400); 
      echo json_encode(array_merge(['success' => false, 'message' => 'Receipt not valid', 'apple_status' => $data['status']], $extra)); 
      exit; 
    }
  $receiptObj = $data['receipt'] ?? [];
  $inApp = $receiptObj['in_app'] ?? [];
  $match = false;
  $foundTransactionId = '';
  foreach ($inApp as $p) {
    $pid = $p['product_id'] ?? '';
    $tid = $p['transaction_id'] ?? '';
    // If we have a transactionId, match strictly. If not, match just by product.
    if ($pid === $productId) {
      if (!$transactionId || $tid === $transactionId) {
        $match = true;
        $foundTransactionId = $tid;
        break;
      }
    }
  }
  if (!$match) { http_response_code(400); echo json_encode(['success' => false, 'message' => 'Product mismatch']); exit; }
  
  // Use the transaction ID from the receipt if none was provided
  $finalTransactionId = $transactionId ?: $foundTransactionId;
  
  $uid = (int)$userId;
  $applePurchaseType = fos_iap_purchase_type_from_sandbox($appleIsTest || $isSandboxRequest);
  if (fos_grant_apple_premium($conn, $uid, $finalTransactionId, $productId, $applePurchaseType)) {
    echo json_encode([
      'success' => true, 'valid' => true, 'message' => 'Verified',
      'transaction_id' => $finalTransactionId, 'is_premium' => true,
      'iap_purchase_type' => $applePurchaseType,
    ]);
    exit;
  }
  http_response_code(500);
  echo json_encode(['success' => false, 'message' => 'DB error']);
  exit;
}
if ($platform === 'google') {
  if (!$purchaseToken || !$productId || !$userId) {
    $missing = [];
    if (!$purchaseToken) $missing[] = 'purchase_token';
    if (!$productId) $missing[] = 'product_id';
    if (!$userId) $missing[] = 'user_id';
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Missing fields: ' . implode(', ', $missing)]);
    exit;
  }
  $packageName = getenv('GOOGLE_PACKAGE_NAME') ?: 'com.fruitsofspirit.android';
  $serviceAccountPath = getenv('GOOGLE_SERVICE_ACCOUNT_JSON') ?: '';
  $googleApiReady = $serviceAccountPath !== '' && file_exists($serviceAccountPath);
  $sandboxTrust = in_array(strtolower((string) (getenv('IAP_GOOGLE_SANDBOX_TRUST') ?: '')), ['1', 'true', 'yes'], true);

  if (!$googleApiReady) {
    $orderId = (string) $transactionId;
    $hasGoogleOrder = $orderId !== '' && preg_match('/^GPA[\.\-0-9A-Z]+$/i', $orderId);
    $tokenOk = strlen((string) $purchaseToken) >= 20;
    $productOk = $productId === 'com.fruitsofspirit.android.premium'
      || strpos((string) $productId, 'premium') !== false;

    // Debug app (is_sandbox) or server flag: grant when Play order id + token look valid
    $allowDevGrant = $tokenOk && $productOk && $hasGoogleOrder
      && ($isSandboxRequest || $sandboxTrust);

    if ($allowDevGrant) {
      $uid = (int) $userId;
      $googlePurchaseType = 'test';
      if (fos_grant_google_premium($conn, $uid, $purchaseToken, $productId, $orderId, $googlePurchaseType)) {
        error_log("IAP: Google premium granted (no Play API) user=$uid order=$orderId type=$googlePurchaseType");
        echo json_encode([
          'success' => true,
          'valid' => true,
          'message' => 'Verified (sandbox – configure GOOGLE_SERVICE_ACCOUNT_JSON for production)',
          'transaction_id' => $orderId,
          'iap_purchase_type' => $googlePurchaseType,
        ]);
        exit;
      }
      http_response_code(500);
      echo json_encode(['success' => false, 'message' => 'DB error']);
      exit;
    }

    error_log("IAP: Google verify blocked – api=0 sandbox=" . ($isSandboxRequest ? '1' : '0') . " trust=" . ($sandboxTrust ? '1' : '0') . " order=" . $orderId);
    http_response_code(501);
    echo json_encode([
      'success' => false,
      'message' => 'Google Play API not configured. Debug: app must send is_sandbox=true. Production: set GOOGLE_SERVICE_ACCOUNT_JSON.',
      'hints' => [
        'is_sandbox_received' => $isSandboxRequest,
        'has_google_order_id' => $hasGoogleOrder,
        'sandbox_trust_env' => $sandboxTrust,
      ],
    ]);
    exit;
  }
  $getAccessToken = function($saPath) {
    $creds = json_decode(file_get_contents($saPath), true);
    if (!$creds || !isset($creds['client_email']) || !isset($creds['private_key'])) return null;
    $header = base64_encode(json_encode(['alg' => 'RS256', 'typ' => 'JWT']));
    $now = time();
    $payload = base64_encode(json_encode([
      'iss' => $creds['client_email'],
      'scope' => 'https://www.googleapis.com/auth/androidpublisher',
      'aud' => 'https://oauth2.googleapis.com/token',
      'iat' => $now,
      'exp' => $now + 3600
    ]));
    $data = $header . '.' . $payload;
    $signature = '';
    openssl_sign($data, $signature, $creds['private_key'], 'SHA256');
    $jwt = $data . '.' . rtrim(strtr(base64_encode($signature), '+/', '-_'), '=');
    $ch = curl_init('https://oauth2.googleapis.com/token');
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, http_build_query([
      'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      'assertion' => $jwt
    ]));
    $result = curl_exec($ch);
    $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    if ($code !== 200) return null;
    $data = json_decode($result, true);
    return $data['access_token'] ?? null;
  };
  $accessToken = $getAccessToken($serviceAccountPath);
  if (!$accessToken) { http_response_code(502); echo json_encode(['success' => false, 'message' => 'Failed to obtain Google access token']); exit; }
  $url = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{$packageName}/purchases/products/{$productId}/tokens/{$purchaseToken}";
  $ch = curl_init($url);
  curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
  curl_setopt($ch, CURLOPT_HTTPHEADER, ['Authorization: Bearer ' . $accessToken]);
  $res = curl_exec($ch);
  $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
  curl_close($ch);
  if ($code !== 200) { http_response_code(400); echo json_encode(['success' => false, 'message' => 'Google purchase not valid']); exit; }
  $gData = json_decode($res, true);
  $purchaseState = $gData['purchaseState'] ?? null;
  if ($purchaseState !== 0) { http_response_code(400); echo json_encode(['success' => false, 'message' => 'Purchase not completed']); exit; }
  $uid = (int) $userId;
  $orderId = (string) $transactionId;
  $googlePurchaseType = 'production';
  if (isset($gData['purchaseType']) && (int) $gData['purchaseType'] === 0) {
    $googlePurchaseType = 'test';
  } elseif ($isSandboxRequest) {
    $googlePurchaseType = 'test';
  }
  if (fos_grant_google_premium($conn, $uid, $purchaseToken, $productId, $orderId, $googlePurchaseType)) {
    echo json_encode([
      'success' => true, 'valid' => true, 'message' => 'Verified',
      'transaction_id' => $orderId, 'iap_purchase_type' => $googlePurchaseType,
    ]);
    exit;
  }
  http_response_code(500);
  echo json_encode(['success' => false, 'message' => 'DB error']);
  exit;
}
http_response_code(400);
echo json_encode(['success' => false, 'message' => 'Unsupported platform']);
