<?php
/**
 * List Emojis from Folder API
 * Reads all emoji images from uploads/emojis folder
 * Returns list of emoji files with their URLs
 */

require_once '../includes/cors.php';
require_once '../includes/db.php';

header('Content-Type: application/json; charset=utf-8');

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'OPTIONS') {
    http_response_code(200);
    exit;
}

if ($method !== 'GET') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Method not allowed']);
    exit;
}

// Base path for emoji images
$basePath = dirname(__DIR__) . '/uploads/emojis/';
$baseUrl = 'http://admin.fosmessenger.com/uploads/emojis/';

// Allowed image extensions
$allowedExtensions = ['png', 'jpg', 'jpeg', 'gif', 'webp', 'svg'];

$emojis = [];

// Check if folder exists
if (!is_dir($basePath)) {
    echo json_encode([
        'success' => false,
        'message' => 'Emojis folder not found',
        'data' => []
    ], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

// Scan folder for image files
$files = scandir($basePath);

if ($files === false) {
    echo json_encode([
        'success' => false,
        'message' => 'Error reading emojis folder',
        'data' => []
    ], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

foreach ($files as $file) {
    // Skip hidden files and directories
    if ($file === '.' || $file === '..' || is_dir($basePath . $file)) {
        continue;
    }
    
    // Check if file has allowed extension
    $extension = strtolower(pathinfo($file, PATHINFO_EXTENSION));
    if (!in_array($extension, $allowedExtensions)) {
        continue;
    }
    
    $filePath = $basePath . $file;
    
    // Skip if not a valid file
    if (!is_file($filePath)) {
        continue;
    }
    
    // Get file info
    $fileSize = filesize($filePath);
    $fileName = pathinfo($file, PATHINFO_FILENAME);
    
    // Extract emoji name from filename
    // Examples: joy_pineapple_01.png, peace_watermelon_02.png
    $emojiName = $fileName;
    
    // Try to extract emoji character from database if possible
    $emojiChar = '';
    $emojiCode = '';
    
    // Try to find matching emoji in database by filename pattern
    // Remove variant numbers (01, 02, 03) and size suffixes
    $baseName = preg_replace('/_\d+(_\d+)?$/', '', $fileName);
    
    // Query database for matching emoji
    $stmt = $conn->prepare("SELECT emoji_char, code, name FROM emojis WHERE code LIKE ? OR name LIKE ? LIMIT 1");
    $searchPattern = '%' . $baseName . '%';
    $stmt->bind_param("ss", $searchPattern, $searchPattern);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows > 0) {
        $row = $result->fetch_assoc();
        $emojiChar = $row['emoji_char'] ?? '';
        $emojiCode = $row['code'] ?? '';
        $emojiName = $row['name'] ?? $emojiName;
    }
    
    // Build emoji data
    $emojiData = [
        'id' => 0, // No database ID for folder-based emojis
        'name' => ucwords(str_replace('_', ' ', $emojiName)),
        'emoji_char' => $emojiChar,
        'code' => $emojiCode ?: $baseName,
        'image_url' => $baseUrl . urlencode($file),
        'filename' => $file,
        'file_size' => $fileSize,
        'category' => 'Folder Emojis',
        'status' => 'Active',
        'usage_count' => 0,
        'created_at' => date('Y-m-d H:i:s', filemtime($filePath)),
    ];
    
    $emojis[] = $emojiData;
}

// Sort by filename
usort($emojis, function($a, $b) {
    return strcmp($a['filename'], $b['filename']);
});

// Return response
echo json_encode([
    'success' => true,
    'message' => 'Emojis retrieved from folder',
    'data' => $emojis,
    'count' => count($emojis)
], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);

$conn->close();
?>

