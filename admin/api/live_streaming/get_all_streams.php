<?php
/**
 * Get all active live streams (for app listing).
 * Returns only streams with status 'live'. Ended streams are not shown
 * (host must upload the recording for it to appear elsewhere).
 */

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    header('Content-Type: application/json');
    echo json_encode(['success' => false, 'message' => 'Method not allowed.']);
    exit;
}

require_once __DIR__ . '/../../includes/db.php';
require_once __DIR__ . '/../../includes/LiveStreamModel.php';

if (isset($db_connection_error)) {
    http_response_code(500);
    header('Content-Type: application/json');
    echo json_encode(['success' => false, 'message' => 'Database connection failed.', 'data' => []]);
    exit;
}

try {
    $liveStreamModel = new LiveStreamModel($conn);
    $streams = $liveStreamModel->getAllActiveLiveStreams();
    
    error_log("getAllActiveLiveStreams returned " . count($streams) . " streams");
    foreach ($streams as $s) {
        error_log("  - Stream: {$s['stream_id']}, status: {$s['status']}");
    }
    
    // Additional filter: double-check status in PHP to ensure ended streams are never returned
    $streams = array_filter($streams, function($s) {
        $status = trim(strtolower($s['status'] ?? ''));
        $isLive = $status === 'live';
        if (!$isLive) {
            error_log("  - FILTERED OUT: {$s['stream_id']} has status '{$s['status']}'");
        }
        return $isLive;
    });
    
    error_log("After filtering, returning " . count($streams) . " live streams");
    
} catch (Throwable $e) {
    error_log("Error in get_all_streams.php: " . $e->getMessage());
    $streams = [];
}

// Map for Flutter: stream_id as channel_name for Agora join
$data = array_map(function ($row) {
    return [
        'stream_id'    => $row['stream_id'] ?? '',
        'channel_name'=> $row['stream_id'] ?? '',
        'user_id'      => $row['user_id'] ?? '',
        'title'        => $row['title'] ?? 'Untitled',
        'description'  => $row['description'] ?? '',
        'status'       => $row['status'] ?? 'live',
        'stream_url'   => $row['stream_url'] ?? null,
        'thumbnail_url'=> $row['thumbnail_url'] ?? null,
        'viewer_count' => $row['viewer_count'] ?? 0,
    ];
}, $streams);

header('Content-Type: application/json');
echo json_encode(['success' => true, 'data' => $data]);
