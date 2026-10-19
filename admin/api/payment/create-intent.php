<?php
/**
 * Create a Stripe Payment Intent for $0.99 (99 cents).
 * POST with authenticated user. Returns client_secret for Flutter Stripe SDK.
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

// Optional: check if already paid (avoid creating duplicate intents)
$stmt = $conn->prepare("SELECT has_paid FROM user_payment_status WHERE user_id = ?");
$stmt->bind_param("i", $user_id);
$stmt->execute();
$row = $stmt->get_result()->fetch_assoc();
if ($row && !empty($row['has_paid'])) {
    header('Content-Type: application/json');
    echo json_encode(['success' => true, 'already_paid' => true, 'message' => 'User has already paid.']);
    exit();
}

$autoload = __DIR__ . '/../../vendor/autoload.php';
if (!file_exists($autoload)) {
    header('Content-Type: application/json');
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Stripe SDK not installed. On server run: cd fruitofthespirit && composer require stripe/stripe-php']);
    exit();
}
require_once $autoload;
\Stripe\Stripe::setApiKey(STRIPE_SECRET_KEY);

$amount = 99; // $0.99 in cents
$currency = 'usd';

try {
    $intent = \Stripe\PaymentIntent::create([
        'amount' => $amount,
        'currency' => $currency,
        'automatic_payment_methods' => ['enabled' => true],
        'metadata' => ['user_id' => (string) $user_id],
    ]);
} catch (\Exception $e) {
    error_log('Stripe PaymentIntent create error: ' . $e->getMessage());
    http_response_code(500);
    header('Content-Type: application/json');
    echo json_encode(['success' => false, 'message' => 'Could not create payment intent.', 'error' => $e->getMessage()]);
    exit();
}

header('Content-Type: application/json');
echo json_encode([
    'success' => true,
    'client_secret' => $intent->client_secret,
    'payment_intent_id' => $intent->id,
]);
