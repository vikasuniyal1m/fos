<?php
/**
 * Check if the current user has already paid the one-time $0.99.
 * GET or POST with authenticated user (Bearer token or user_id).
 */

if ($_SERVER['REQUEST_METHOD'] !== 'GET' && $_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    header('Content-Type: application/json');
    echo json_encode(['success' => false, 'message' => 'Method not allowed.']);
    exit();
}

require_once __DIR__ . '/../../includes/config.php';
require_once __DIR__ . '/../../includes/db.php';
require_once __DIR__ . '/../auth-helper.php';

if (isset($db_connection_error) && $db_connection_error) {
    http_response_code(500);
    header('Content-Type: application/json');
    echo json_encode(['success' => false, 'message' => 'Database connection failed.']);
    exit();
}

$user = requireAuth($conn);
$user_id = (int) $user['id'];

$stmt = $conn->prepare("SELECT has_paid, payment_date, transaction_id FROM user_payment_status WHERE user_id = ?");
$stmt->bind_param("i", $user_id);
$stmt->execute();
$result = $stmt->get_result();
$row = $result->fetch_assoc();

$has_paid = false;
$payment_date = null;
$transaction_id = null;
if ($row) {
    $has_paid = (bool) $row['has_paid'];
    $payment_date = $row['payment_date'];
    $transaction_id = $row['transaction_id'];
}

header('Content-Type: application/json');
echo json_encode([
    'success' => true,
    'has_paid' => $has_paid,
    'payment_date' => $payment_date,
    'transaction_id' => $transaction_id,
]);
