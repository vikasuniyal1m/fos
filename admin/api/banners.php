<?php
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-API-Key');
header('Content-Type: application/json; charset=utf-8');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Method not allowed']);
    exit;
}

// Database connection
require_once __DIR__ . '/../includes/db.php';

// Get limit from query parameter (default: show all)
$limit = isset($_GET['limit']) ? (int)$_GET['limit'] : 0;

// Check if requesting all banners (including inactive) for admin
$fetchAll = isset($_GET['all']) && $_GET['all'] === 'true';

if ($fetchAll) {
    // Fetch all banners for admin management
    $allSql = "
        SELECT id, title, file_path, original_filename, mime_type, starts_at, ends_at, sort_order, status
        FROM banners
        ORDER BY sort_order ASC, id DESC
    " . ($limit > 0 ? " LIMIT $limit" : "");

    $allResult = $conn->query($allSql);
    $allBanners = [];
    if ($allResult) {
        while ($row = $allResult->fetch_assoc()) {
            $row['id'] = (int) $row['id'];
            $row['sort_order'] = (int) $row['sort_order'];
            $allBanners[] = $row;
        }
    }

    echo json_encode([
        'success' => true,
        'message' => 'All banners loaded',
        'data' => ['banners' => $allBanners]
    ]);
    exit;
}

// Fetch active banners (currently running - within date window)
$activeSql = "
    SELECT id, title, file_path, original_filename, mime_type, starts_at, ends_at, sort_order, status
    FROM banners
    WHERE status = 'Active'
      AND starts_at <= NOW()
      AND ends_at >= NOW()
    ORDER BY sort_order ASC, id ASC
" . ($limit > 0 ? " LIMIT $limit" : "");

$activeResult = $conn->query($activeSql);
$activeBanners = [];
if ($activeResult) {
    while ($row = $activeResult->fetch_assoc()) {
        $row['id'] = (int) $row['id'];
        $row['sort_order'] = (int) $row['sort_order'];
        $activeBanners[] = $row;
    }
}

// Fetch upcoming banners (not started yet)
$upcomingSql = "
    SELECT id, title, file_path, original_filename, mime_type, starts_at, ends_at, sort_order, status
    FROM banners
    WHERE status = 'Active'
      AND starts_at > NOW()
    ORDER BY starts_at ASC, sort_order ASC
" . ($limit > 0 ? " LIMIT $limit" : "");

$upcomingResult = $conn->query($upcomingSql);
$upcomingBanners = [];
if ($upcomingResult) {
    while ($row = $upcomingResult->fetch_assoc()) {
        $row['id'] = (int) $row['id'];
        $row['sort_order'] = (int) $row['sort_order'];
        $upcomingBanners[] = $row;
    }
}

// Calculate countdown for first upcoming banner
$countdown = null;
if (!empty($upcomingBanners)) {
    $now = new DateTime();
    $startsAt = new DateTime($upcomingBanners[0]['starts_at']);
    $interval = $now->diff($startsAt);
    
    $countdown = [
        'days' => (int)$interval->format('%a'),
        'hours' => (int)$interval->format('%h'),
        'minutes' => (int)$interval->format('%i'),
        'seconds' => (int)$interval->format('%s'),
        'total_seconds' => $startsAt->getTimestamp() - $now->getTimestamp()
    ];
}

echo json_encode([
    'success' => true,
    'message' => 'Banners loaded',
    'data' => [
        'active_banners' => $activeBanners,
        'upcoming_banners' => $upcomingBanners,
        'countdown' => $countdown,
    ]
]);
