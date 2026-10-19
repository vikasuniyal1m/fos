<?php
/**
 * Confirm payment: verify Stripe PaymentIntent and mark user as paid.
 * POST body: { "payment_intent_id": "pi_xxx" } (and optionally transaction_id).
 */

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
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

if (!defined('STRIPE_SECRET_KEY') || STRIPE_SECRET_KEY === '') {
    http_response_code(500);
    header('Content-Type: application/json');
    echo json_encode(['success' => false, 'message' => 'Stripe is not configured.']);
    exit();
}

$user = requireAuth($conn);
$user_id = (int) $user['id'];

$payment_intent_id = trim($_POST['payment_intent_id'] ?? '');
$transaction_id = trim($_POST['transaction_id'] ?? '');
if ($transaction_id === '') {
    $transaction_id = 'txn_' . $user_id . '_' . time();
}

if ($payment_intent_id === '') {
    http_response_code(400);
    header('Content-Type: application/json');
    echo json_encode(['success' => false, 'message' => 'payment_intent_id is required.']);
    exit();
}

$autoload = __DIR__ . '/../../vendor/autoload.php';
if (!file_exists($autoload)) {
    header('Content-Type: application/json');
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Stripe SDK not installed. Run: cd fruitofthespirit && composer require stripe/stripe-php']);
    exit();
}
require_once $autoload;
\Stripe\Stripe::setApiKey(STRIPE_SECRET_KEY);

try {
    $intent = \Stripe\PaymentIntent::retrieve($payment_intent_id);
} catch (\Exception $e) {
    error_log('Stripe PaymentIntent retrieve error: ' . $e->getMessage());
    http_response_code(400);
    header('Content-Type: application/json');
    echo json_encode(['success' => false, 'message' => 'Invalid payment intent.']);
    exit();
}

if ($intent->status !== 'succeeded') {
    http_response_code(400);
    header('Content-Type: application/json');
    echo json_encode(['success' => false, 'message' => 'Payment has not succeeded.', 'status' => $intent->status]);
    exit();
}

if (isset($intent->metadata->user_id) && (int) $intent->metadata->user_id !== $user_id) {
    http_response_code(403);
    header('Content-Type: application/json');
    echo json_encode(['success' => false, 'message' => 'Payment does not belong to this user.']);
    exit();
}

$amount = $intent->amount / 100; // cents to dollars

// Insert transaction record
$stmt = $conn->prepare("INSERT INTO payment_transactions (user_id, transaction_id, stripe_payment_intent_id, amount, currency, status) VALUES (?, ?, ?, ?, 'USD', 'succeeded')");
$stmt->bind_param("issd", $user_id, $transaction_id, $payment_intent_id, $amount);
$stmt->execute();

// Upsert user_payment_status
$stmt = $conn->prepare("INSERT INTO user_payment_status (user_id, has_paid, payment_date, transaction_id) VALUES (?, 1, NOW(), ?) ON DUPLICATE KEY UPDATE has_paid = 1, payment_date = NOW(), transaction_id = ?");
$stmt->bind_param("iss", $user_id, $transaction_id, $transaction_id);
$stmt->execute();

header('Content-Type: application/json');
echo json_encode([
    'success' => true,
    'message' => 'Payment confirmed.',
    'transaction_id' => $transaction_id,
]);
