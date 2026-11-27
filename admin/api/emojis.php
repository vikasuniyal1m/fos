<?php
set_error_handler(function($errno, $errstr, $errfile, $errline) {
    if (!(error_reporting() & $errno)) {
        return false;
    }
    http_response_code(500);
    error_log("PHP Error: $errstr in $errfile on line $errline");
    echo jsonResponse(false, 'Server error occurred', [
        'error' => $errstr,
        'file' => $errfile,
        'line' => $errline,
        'code' => $errno
    ]);
    exit;
});

set_exception_handler(function($exception) {
    http_response_code(500);
    error_log("PHP Exception: " . $exception->getMessage() . " in " . $exception->getFile() . " on line " . $exception->getLine());
    echo jsonResponse(false, 'Server error occurred', [
        'error' => $exception->getMessage(),
        'file' => $exception->getFile(),
        'line' => $exception->getLine(),
        'code' => $exception->getCode()
    ]);
    exit;
});

/**
 * Emojis API
 * Handles: List emojis, Use emoji (track usage)
 */

require_once '../includes/db.php';
require_once '../includes/config.php';
require_once '../includes/cors.php';
require_once 'auth-helper.php';

// Helper function to parse multipart/form-data
function parseMultipartFormData($input) {
    $data = [];
    $matches = [];
    // Extract boundary from Content-Type header
    preg_match('/boundary=(.*)$/', $_SERVER['CONTENT_TYPE'], $matches);
    $boundary = $matches[1];

    // Split input by boundary
    $parts = explode('--' . $boundary, $input);
    array_pop($parts); // Remove trailing empty part

    foreach ($parts as $part) {
        if (empty($part)) continue;

        // Extract headers and body
        $sub_parts = explode("\r\n\r\n", $part, 2);
        if (count($sub_parts) < 2) continue;

        $headers = $sub_parts[0];
        $body = $sub_parts[1];

        // Extract name from Content-Disposition header
        if (preg_match('/name="([^"]+)"/', $headers, $name_matches)) {
            $name = $name_matches[1];
            // Trim body to remove trailing \r\n
            $data[$name] = rtrim($body, "\r\n");
        }
    }
    return $data;
}

header('Content-Type: application/json');

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'OPTIONS') {
    http_response_code(200);
    exit;
}

switch ($method) {
    case 'GET':
        // Check if requesting user's latest feeling
        if (isset($_GET['user_id']) && isset($_GET['get_latest_feeling']) && $_GET['get_latest_feeling'] === 'true') {
            handleGetUserLatestFeeling($conn);
        } 
        // Check if requesting emoji reactions for a post
        else if (isset($_GET['get_reactions']) && $_GET['get_reactions'] === 'true') {
            handleGetEmojiReactions($conn);
        } 
        else {
            handleGetEmojis($conn);
        }
        break;
    case 'POST':
        handleUseEmoji($conn);
        break;
    default:
        http_response_code(405);
        echo jsonResponse(false, 'Method not allowed');
        break;
}

function handleGetUserLatestFeeling($conn) {
    // Start output buffering to prevent any accidental output
    ob_start();
    
    // Suppress error display
    $old_error_reporting = error_reporting(E_ALL);
    $old_display_errors = ini_get('display_errors');
    ini_set('display_errors', '0');
    
    try {
        $user_id = isset($_GET['user_id']) ? intval($_GET['user_id']) : 0;
        
        if ($user_id <= 0) {
            ob_clean();
            error_reporting($old_error_reporting);
            if ($old_display_errors !== false) {
                ini_set('display_errors', $old_display_errors);
            }
            http_response_code(400);
            header('Content-Type: application/json; charset=utf-8');
            echo jsonResponse(false, 'user_id is required');
            if (ob_get_level() > 0) {
                ob_end_flush();
            }
            return;
        }
    
    // Get user's latest emoji from user_emoji_usage table
    // Order by id DESC to get the most recent one
    $stmt = $conn->prepare("SELECT ueu.emoji, ueu.count, u.name as user_name 
                            FROM user_emoji_usage ueu 
                            INNER JOIN users u ON ueu.user_id = u.id 
                            WHERE ueu.user_id = ? 
                            ORDER BY ueu.id DESC 
                            LIMIT 1");
    $stmt->bind_param("i", $user_id);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows > 0) {
        $row = $result->fetch_assoc();
        $stored_emoji = $row['emoji'];
        
        // Get emoji details from emojis table (include description for feeling display)
        // The stored_emoji could be:
        // 1. An emoji character (like 😊)
        // 2. An image URL (like https://.../uploads/emojis/Kindness_Peach%20(2).png)
        // 3. A relative path (like uploads/emojis/Kindness_Peach%20(2).png)
        
        $emoji_data = null;
        
        // Strategy 0: Check if stored_emoji is an emoji ID (numeric string like "212")
        // This is the NEW preferred method - emoji ID is stored instead of URL/path
        if (!empty($stored_emoji) && is_numeric($stored_emoji)) {
            $emoji_id_from_storage = intval($stored_emoji);
            $id_stmt = $conn->prepare("SELECT id, name, emoji_char, image_url, description FROM emojis WHERE id = ? LIMIT 1");
            $id_stmt->bind_param("i", $emoji_id_from_storage);
            $id_stmt->execute();
            $id_result = $id_stmt->get_result();
            
            if ($id_result->num_rows > 0) {
                $emoji_data = $id_result->fetch_assoc();
                error_log("✅ FOUND by emoji ID: [" . $stored_emoji . "] -> emoji_id: " . $emoji_data['id']);
            }
        }
        
        // Strategy 1: Try to find by emoji_char first (for emoji-based emojis)
        // Check if it's NOT a URL or path (it's an emoji character)
        if ($emoji_data === null && !empty($stored_emoji) && strpos($stored_emoji, 'http') === false && strpos($stored_emoji, 'uploads/') === false && !is_numeric($stored_emoji)) {
            $emoji_stmt = $conn->prepare("SELECT id, name, emoji_char, image_url, description FROM emojis WHERE emoji_char = ? LIMIT 1");
            $emoji_stmt->bind_param("s", $stored_emoji);
            $emoji_stmt->execute();
            $emoji_result = $emoji_stmt->get_result();
            
            if ($emoji_result->num_rows > 0) {
                $emoji_data = $emoji_result->fetch_assoc();
            }
        }
        
        // Strategy 2: If not found and it looks like an image URL/path, try to find by image_url
        // Handle both full paths and just filenames (in case database column truncated it)
        if ($emoji_data === null && !empty($stored_emoji)) {
            // First, try to extract relative path if it's a full path
            $relative_path = $stored_emoji;
            if (strpos($stored_emoji, 'uploads/emojis/') !== false) {
                $pos = strpos($stored_emoji, 'uploads/emojis/');
                $relative_path = substr($stored_emoji, $pos);
            } elseif (strpos($stored_emoji, 'emojis/') !== false && strpos($stored_emoji, 'uploads/emojis/') === false) {
                $pos = strpos($stored_emoji, 'emojis/');
                $relative_path = 'uploads/' . substr($stored_emoji, $pos);
            }
            
            // Try exact match with relative path
            if ($relative_path !== $stored_emoji || strpos($stored_emoji, 'uploads/') !== false || strpos($stored_emoji, 'emojis/') !== false || strpos($stored_emoji, '.png') !== false) {
                $image_stmt = $conn->prepare("SELECT id, name, emoji_char, image_url, description FROM emojis WHERE image_url = ? LIMIT 1");
                $image_stmt->bind_param("s", $relative_path);
                $image_stmt->execute();
                $image_result = $image_stmt->get_result();
                
                if ($image_result->num_rows > 0) {
                    $emoji_data = $image_result->fetch_assoc();
                }
            }
            
            // If still not found, try LIKE match with filename (handles truncated values like "uploads/em" or just filenames)
            if ($emoji_data === null) {
                // Extract filename from stored value (might be truncated path or just filename)
                $filename = basename($stored_emoji);
                
                // Build search patterns
                $search_patterns = [];
                
                // Pattern 1: If stored value is just a filename (has extension), try exact filename match
                if (!empty($filename) && (strpos($filename, '.png') !== false || strpos($filename, '.jpg') !== false || strpos($filename, '.jpeg') !== false)) {
                    // Try exact filename match first
                    $exact_filename_stmt = $conn->prepare("SELECT id, name, emoji_char, image_url, description FROM emojis WHERE image_url LIKE ? LIMIT 1");
                    $exact_pattern = '%/' . $conn->real_escape_string($filename);
                    $exact_filename_stmt->bind_param("s", $exact_pattern);
                    $exact_filename_stmt->execute();
                    $exact_filename_result = $exact_filename_stmt->get_result();
                    
                    if ($exact_filename_result->num_rows > 0) {
                        $emoji_data = $exact_filename_result->fetch_assoc();
                    }
                }
                
                // Pattern 2: LIKE match with filename (handles any position in path)
                if ($emoji_data === null && !empty($filename) && $filename !== $stored_emoji) {
                    $search_patterns[] = '%' . $conn->real_escape_string($filename) . '%';
                }
                
                // Pattern 3: If stored value looks like a partial path, try it
                if ($emoji_data === null && (strpos($stored_emoji, 'uploads/') !== false || strpos($stored_emoji, 'emojis/') !== false || strpos($stored_emoji, '.png') !== false || strpos($stored_emoji, '.jpg') !== false)) {
                    $search_patterns[] = '%' . $conn->real_escape_string($stored_emoji) . '%';
                }
                
                // Pattern 4: If stored value is just a filename, try it directly
                if ($emoji_data === null && !empty($stored_emoji) && (strpos($stored_emoji, '/') === false) && (strpos($stored_emoji, '.png') !== false || strpos($stored_emoji, '.jpg') !== false)) {
                    $search_patterns[] = '%' . $conn->real_escape_string($stored_emoji) . '%';
                }
                
                // Execute LIKE searches
                foreach ($search_patterns as $pattern) {
                    $like_stmt = $conn->prepare("SELECT id, name, emoji_char, image_url, description FROM emojis WHERE image_url LIKE ? LIMIT 1");
                    $like_stmt->bind_param("s", $pattern);
                    $like_stmt->execute();
                    $like_result = $like_stmt->get_result();
                    
                    if ($like_result->num_rows > 0) {
                        $emoji_data = $like_result->fetch_assoc();
                        break;
                    }
                }
            }
        }
        
        // Clear any output
        ob_clean();
        
        // Restore error settings
        error_reporting($old_error_reporting);
        if ($old_display_errors !== false) {
            ini_set('display_errors', $old_display_errors);
        }
        
        header('Content-Type: application/json; charset=utf-8');
        echo json_encode([
            'success' => true,
            'message' => 'User feeling retrieved',
            'data' => [
                'user_id' => $user_id,
                'user_name' => $row['user_name'],
                'emoji' => $row['emoji'],
                'count' => intval($row['count']),
                'emoji_details' => $emoji_data,
            ]
        ], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        
        if (ob_get_level() > 0) {
            ob_end_flush();
        }
    } else {
        // No feeling recorded yet
        // Clear any output
        ob_clean();
        
        // Restore error settings
        error_reporting($old_error_reporting);
        if ($old_display_errors !== false) {
            ini_set('display_errors', $old_display_errors);
        }
        
        header('Content-Type: application/json; charset=utf-8');
        echo json_encode([
            'success' => true,
            'message' => 'No feeling recorded',
            'data' => null
        ], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        
        if (ob_get_level() > 0) {
            ob_end_flush();
        }
    }
    
    } catch (Exception $e) {
        // Clear any output
        ob_clean();
        
        // Restore error settings
        error_reporting($old_error_reporting);
        if ($old_display_errors !== false) {
            ini_set('display_errors', $old_display_errors);
        }
        
        // Log the error
        error_log("❌ EXCEPTION in handleGetUserLatestFeeling: " . $e->getMessage());
        error_log("Stack trace: " . $e->getTraceAsString());
        
        // Return error response
        http_response_code(500);
        header('Content-Type: application/json; charset=utf-8');
        echo jsonResponse(false, 'An error occurred while retrieving user feeling: ' . $e->getMessage());
        
        if (ob_get_level() > 0) {
            ob_end_flush();
        }
    }
}

/**
 * Handle Get Emoji Reactions
 * Returns emoji reactions from emoji_usage table for a specific post
 * Query params: get_reactions=true&post_type=photo&post_id=123
 */
function handleGetEmojiReactions($conn) {
    $post_type = $_GET['post_type'] ?? '';
    $post_id = isset($_GET['post_id']) ? intval($_GET['post_id']) : 0;
    
    if (empty($post_type) || $post_id <= 0) {
        http_response_code(400);
        header('Content-Type: application/json; charset=utf-8');
        echo jsonResponse(false, 'post_type and post_id are required');
        return;
    }
    
    // Check if emoji_usage table exists
    $check_table = @$conn->query("SHOW TABLES LIKE 'emoji_usage'");
    if (!$check_table || $check_table->num_rows === 0) {
        http_response_code(501);
        header('Content-Type: application/json; charset=utf-8');
        echo jsonResponse(false, 'Emoji reactions feature not available. Please run database migration.');
        return;
    }
    
    // Get emoji reactions from emoji_usage table with user info
    error_log("🔍 Fetching emoji reactions from emoji_usage table:");
    error_log("   - post_type: '$post_type'");
    error_log("   - post_id: $post_id");
    
    // First check if table exists
    $check_table = @$conn->query("SHOW TABLES LIKE 'emoji_usage'");
    if (!$check_table || $check_table->num_rows === 0) {
        error_log("❌ ERROR: emoji_usage table does not exist!");
        http_response_code(501);
        header('Content-Type: application/json; charset=utf-8');
        echo jsonResponse(false, 'Emoji reactions feature not available. Please run database migration.');
        return;
    }
    
    // Debug: Check total records before filtering
    $count_stmt = $conn->prepare("SELECT COUNT(*) as total FROM emoji_usage WHERE post_type = ? AND post_id = ?");
    $count_stmt->bind_param("si", $post_type, $post_id);
    $count_stmt->execute();
    $count_result = $count_stmt->get_result();
    if ($count_row = $count_result->fetch_assoc()) {
        error_log("📊 Total records in emoji_usage for post_type='$post_type', post_id=$post_id: " . $count_row['total']);
    }
    
    // Debug: Check all records with this post_type and post_id (without user join first)
    $debug_stmt = $conn->prepare("SELECT id, user_id, emoji, post_type, post_id, created_at FROM emoji_usage WHERE post_type = ? AND post_id = ? ORDER BY created_at ASC");
    $debug_stmt->bind_param("si", $post_type, $post_id);
    $debug_stmt->execute();
    $debug_result = $debug_stmt->get_result();
    error_log("📋 Raw records from emoji_usage table:");
    $raw_count = 0;
    while ($debug_row = $debug_result->fetch_assoc()) {
        $raw_count++;
        error_log("   Record $raw_count: id={$debug_row['id']}, user_id={$debug_row['user_id']}, emoji=[{$debug_row['emoji']}], post_type={$debug_row['post_type']}, post_id={$debug_row['post_id']}");
    }
    error_log("   Total raw records found: $raw_count");
    
    $sql = "SELECT eu.*, u.name as user_name, u.profile_photo
            FROM emoji_usage eu
            JOIN users u ON eu.user_id = u.id
            WHERE eu.post_type = ? AND eu.post_id = ?
            ORDER BY eu.created_at ASC";
    
    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        error_log("❌ ERROR: Failed to prepare SELECT statement - " . $conn->error);
        http_response_code(500);
        header('Content-Type: application/json; charset=utf-8');
        echo jsonResponse(false, 'Database error: ' . $conn->error);
        return;
    }
    
    $stmt->bind_param("si", $post_type, $post_id);
    if (!$stmt->execute()) {
        error_log("❌ ERROR: Failed to execute SELECT - " . $stmt->error);
        http_response_code(500);
        header('Content-Type: application/json; charset=utf-8');
        echo jsonResponse(false, 'Database error: ' . $stmt->error);
        return;
    }
    $result = $stmt->get_result();
    
    $reactions = [];
    $baseUrl = 'http://admin.fosmessenger.com/';
    
    while ($row = $result->fetch_assoc()) {
        $stored_emoji = $row['emoji']; // This could be emoji_id, URL, or emoji_char
        $emoji_value = $stored_emoji; // Default to stored value
        
        // Try to resolve emoji_id to image_url
        if (is_numeric($stored_emoji)) {
            // Stored value is numeric (emoji_id), resolve it to image_url
            $emoji_id = intval($stored_emoji);
            $emoji_resolve_stmt = $conn->prepare("SELECT image_url, emoji_char FROM emojis WHERE id = ?");
            $emoji_resolve_stmt->bind_param("i", $emoji_id);
            $emoji_resolve_stmt->execute();
            $emoji_resolve_result = $emoji_resolve_stmt->get_result();
            if ($emoji_resolve_row = $emoji_resolve_result->fetch_assoc()) {
                // Priority: image_url > emoji_char
                if (!empty($emoji_resolve_row['image_url'])) {
                    $emoji_value = $emoji_resolve_row['image_url'];
                    // If it's a relative path, make it full URL
                    if (!preg_match('/^https?:\/\//', $emoji_value)) {
                        $emoji_value = $baseUrl . ltrim($emoji_value, '/');
                    }
                } else if (!empty($emoji_resolve_row['emoji_char'])) {
                    $emoji_value = $emoji_resolve_row['emoji_char'];
                }
                error_log("✅ Resolved emoji_id=$emoji_id to: $emoji_value");
            } else {
                error_log("⚠️ Could not resolve emoji_id=$emoji_id - emoji not found in emojis table");
            }
        } else if (!preg_match('/^https?:\/\//', $stored_emoji) && (strpos($stored_emoji, 'uploads/') !== false || strpos($stored_emoji, 'emojis/') !== false)) {
            // If it's a relative path, make it full URL
            $emoji_value = $baseUrl . ltrim($stored_emoji, '/');
            error_log("✅ Converted relative path to full URL: $emoji_value");
        } else if (strlen($stored_emoji) <= 4) {
            // It's likely an emoji character, use as is
            $emoji_value = $stored_emoji;
            error_log("✅ Using emoji character: $emoji_value");
        }
        
        // Map emoji field to 'emoji' key for consistency
        $reaction = [
            'id' => intval($row['id']),
            'user_id' => intval($row['user_id']),
            'user_name' => $row['user_name'],
            'profile_photo' => $row['profile_photo'],
            'emoji' => $emoji_value, // Resolved emoji URL/image/character
            'emoji_value' => $emoji_value, // Alias for compatibility
            'post_type' => $row['post_type'],
            'post_id' => intval($row['post_id']),
            'created_at' => $row['created_at'],
        ];
        $reactions[] = $reaction;
    }
    
    error_log("✅ Get Emoji Reactions: Found " . count($reactions) . " reactions for post_type='$post_type', post_id=$post_id");
    
    // Debug: Log first few reactions
    if (count($reactions) > 0) {
        error_log("📋 Sample reaction: " . json_encode($reactions[0]));
    } else {
        error_log("⚠️ No reactions found in emoji_usage table for post_type='$post_type', post_id=$post_id");
        // Debug: Check if any records exist at all
        $debug_stmt = $conn->prepare("SELECT COUNT(*) as total FROM emoji_usage WHERE post_type = ? AND post_id = ?");
        $debug_stmt->bind_param("si", $post_type, $post_id);
        $debug_stmt->execute();
        $debug_result = $debug_stmt->get_result();
        if ($debug_row = $debug_result->fetch_assoc()) {
            error_log("🔍 Debug: Total records in emoji_usage: " . $debug_row['total']);
        }
    }
    
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode([
        'success' => true,
        'message' => 'Emoji reactions retrieved',
        'data' => $reactions
    ], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
}

function handleGetEmojis($conn) {
    // Check if requesting single emoji by ID
    if (isset($_GET['id']) && is_numeric($_GET['id'])) {
        $emojiId = intval($_GET['id']);
        $stmt = $conn->prepare("SELECT * FROM emojis WHERE id = ? AND status = 'Active' LIMIT 1");
        $stmt->bind_param("i", $emojiId);
        $stmt->execute();
        $result = $stmt->get_result();

        if ($row = $result->fetch_assoc()) {
            // Use image_url from database but clean common formatting issues
            $imageUrl = isset($row['image_url']) ? trim($row['image_url']) : '';
            $imageUrl = rtrim($imageUrl, ", \t\n\r\0\x0B");
            if (empty($imageUrl)) {
                $baseUrl = 'http://admin.fosmessenger.com/';
                $imageUrl = $baseUrl . 'uploads/emojis/' . urlencode($row['code'] ?? '') . '.png';
            } else if (!preg_match('/^https?:\/\//', $imageUrl)) {
                $baseUrl = 'http://admin.fosmessenger.com/';
                $imageUrl = $baseUrl . ltrim($imageUrl, '/');
            }

            $emoji_data = [
                'id' => intval($row['id']),
                'name' => $row['name'],
                'emoji_char' => $row['emoji_char'] ?? '',
                'code' => $row['code'] ?? '',
                'image_url' => $imageUrl,
                'description' => $row['description'] ?? '',
                'category' => $row['category'] ?? '',
                'usage_count' => intval($row['usage_count'] ?? 0),
                'status' => $row['status'] ?? 'Active',
                'created_at' => $row['created_at'] ?? '',
            ];

            echo jsonResponse(true, 'Emoji found', $emoji_data);
            return;
        } else {
            http_response_code(404);
            echo jsonResponse(false, 'Emoji not found', null);
            return;
        }
    }

    // Check if user wants to read from folder instead of database
    $source = $_GET['source'] ?? 'database';

    if ($source === 'folder') {
        handleGetEmojisFromFolder();
        return;
    }

    $category = $_GET['category'] ?? null;
    $status = $_GET['status'] ?? 'Active';
    $limit = isset($_GET['limit']) ? intval($_GET['limit']) : null;
    // Default sorting: ORDER BY emojis.image_url ASC (as per user requirement)
    $sortBy = $_GET['sort_by'] ?? 'image_url';
    $order = strtoupper($_GET['order'] ?? 'ASC');
    $mainFruitsOnly = isset($_GET['main_fruits_only']) ? filter_var($_GET['main_fruits_only'], FILTER_VALIDATE_BOOLEAN) : false;
    
    // Validate order
    if ($order !== 'ASC' && $order !== 'DESC') {
        $order = 'ASC'; // Default to ASC
    }
    
    // Validate sort_by field - added 'image_url' as allowed field
    $allowedSortFields = ['image_url', 'usage_count', 'name', 'created_at', 'id'];
    if (!in_array($sortBy, $allowedSortFields)) {
        $sortBy = 'image_url'; // Default to image_url
    }
    
    $sql = "SELECT * FROM emojis WHERE status = ?";
    $params = [$status];
    $types = "s";
    
    // If main_fruits_only is true, filter to only main fruit emojis (category = 'Fruit of Spirit')
    // This returns all variants of main fruits (8 fruits × 3 variants = 24, plus 9th if ready)
    if ($mainFruitsOnly) {
        $sql .= " AND category = 'Fruit of Spirit'";
        // Allow up to 30 to show all variants (8 fruits × 3 variants = 24, plus 9th if ready)
        if ($limit === null) {
            $limit = 30;
        }
    } else if ($category) {
        $sql .= " AND category = ?";
        $params[] = $category;
        $types .= "s";
    }
    
    // Order by specified field - default is image_url ASC
    $sql .= " ORDER BY emojis.$sortBy $order";
    // Secondary sort by name for consistent ordering when image_url is same
    if ($sortBy !== 'name') {
        $sql .= ", emojis.name ASC";
    }
    
    if ($limit !== null && $limit > 0) {
        $sql .= " LIMIT ?";
        $params[] = $limit;
        $types .= "i";
    }
    
    $stmt = $conn->prepare($sql);
    if (!empty($params)) {
        $stmt->bind_param($types, ...$params);
    }
    $stmt->execute();
    $result = $stmt->get_result();
    
    $emojis = [];
    while ($row = $result->fetch_assoc()) {
        // Use image_url from database but clean common formatting issues (trailing commas, spaces)
        // If image_url is empty, construct it from base URL + uploads path
        $imageUrl = isset($row['image_url']) ? trim($row['image_url']) : '';
        // Remove any trailing commas or whitespace characters that might have been stored in DB
        $imageUrl = rtrim($imageUrl, ", \t\n\r\0\x0B");
        if (empty($imageUrl)) {
            // Fallback: construct URL if image_url is empty
            $baseUrl = 'http://admin.fosmessenger.com/';
            $imageUrl = $baseUrl . 'uploads/emojis/' . urlencode($row['code'] ?? '') . '.png';
        } else if (!preg_match('/^https?:\/\//', $imageUrl)) {
            // If image_url is relative path, prepend base URL
            $baseUrl = 'http://admin.fosmessenger.com/';
            $imageUrl = $baseUrl . ltrim($imageUrl, '/');
        }
        
        $emoji_data = [
            'id' => intval($row['id']),
            'name' => $row['name'],
            'emoji_char' => $row['emoji_char'] ?? '', // Can be empty for image-based emojis
            'code' => $row['code'] ?? '',
            'image_url' => $imageUrl, // Use image_url from database
            'description' => $row['description'] ?? '',
            'category' => $row['category'] ?? '',
            'usage_count' => intval($row['usage_count'] ?? 0),
            'status' => $row['status'] ?? 'Active',
            'created_at' => $row['created_at'] ?? '',
        ];
        
        $emojis[] = $emoji_data;
    }
    
    // Log for debugging
    error_log("GET Emojis: Found " . count($emojis) . " emojis with status='$status'");
    if (count($emojis) > 0) {
        error_log("First emoji: ID=" . $emojis[0]['id'] . ", name=" . $emojis[0]['name'] . ", emoji_char=[" . $emojis[0]['emoji_char'] . "]");
    }
    
    // Use JSON_UNESCAPED_UNICODE to preserve emoji characters
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode([
        'success' => true,
        'message' => 'Emojis retrieved',
        'data' => $emojis
    ], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
}

function handleUseEmoji($conn) {
    // Start output buffering to prevent any accidental output
    ob_start();
    
    // Suppress error display (errors will still be logged)
    $old_error_reporting = error_reporting(E_ALL);
    $old_display_errors = ini_get('display_errors');
    ini_set('display_errors', '0');
    
    // Helper function to clean up and send response
    $cleanupAndRespond = function($success, $message, $code = 200, $data = null) use (&$old_error_reporting, &$old_display_errors) {
        ob_clean();
        error_reporting($old_error_reporting);
        if ($old_display_errors !== false) {
            ini_set('display_errors', $old_display_errors);
        }
        if (ob_get_level() > 0) {
            ob_end_flush();
        }
        http_response_code($code);
        if ($data !== null) {
            echo jsonResponse($success, $message, $data);
        } else {
            echo jsonResponse($success, $message);
        }
    };
    
    try {
        // Log incoming request for debugging
        error_log("=== EMOJI POST REQUEST ===");
        error_log("POST data: " . print_r($_POST, true));
        error_log("Raw input: " . file_get_contents('php://input'));
        error_log("Content-Type: " . ($_SERVER['CONTENT_TYPE'] ?? 'not set'));
    
    // Try to get data from POST first, then from JSON input, then from multipart
    $user_id = 0;
    $emoji = '';
    $post_type = '';
    $post_id = 0;
    
    $contentType = $_SERVER['CONTENT_TYPE'] ?? '';
    
    if (strpos($contentType, 'application/json') !== false) {
        $json = json_decode(file_get_contents('php://input'), true);
        if ($json) {
            $user_id = intval($json['user_id'] ?? $json['userId'] ?? 0);
            $emoji = trim($json['emoji'] ?? '');
            $post_type = trim($json['post_type'] ?? $json['postType'] ?? '');
            $post_id = intval($json['post_id'] ?? $json['postId'] ?? 0);
            error_log("✅ Parsed from JSON: user_id=$user_id, emoji=[$emoji], post_type='$post_type', post_id=$post_id");
        }
    } elseif (strpos($contentType, 'multipart/form-data') !== false) {
        // Handle multipart/form-data
        $raw_input = file_get_contents('php://input');
        $multipart_data = parseMultipartFormData($raw_input);
        error_log("DEBUG: Raw multipart data: " . print_r($multipart_data, true));
        
        $user_id = intval($multipart_data['user_id'] ?? $_REQUEST['user_id'] ?? 0);
        $emoji = trim($multipart_data['emoji'] ?? $_REQUEST['emoji'] ?? '');
        $post_type = trim($multipart_data['post_type'] ?? $_REQUEST['post_type'] ?? '');
        $post_id = intval($multipart_data['post_id'] ?? $_REQUEST['post_id'] ?? 0);
        error_log("✅ Parsed from MULTIPART: user_id=$user_id, emoji=[$emoji], post_type='$post_type', post_id=$post_id");
    } else {
        // Fallback to $_POST for application/x-www-form-urlencoded or other simple form data
        $user_id = intval($_POST['user_id'] ?? 0);
        $emoji = trim($_POST['emoji'] ?? '');
        $post_type = trim($_POST['post_type'] ?? '');
        $post_id = intval($_POST['post_id'] ?? 0);
        error_log("✅ Parsed from POST (fallback): user_id=$user_id, emoji=[$emoji], post_type='$post_type', post_id=$post_id");
    }
    
    // Decode URL-encoded emoji if needed
    if (!empty($emoji) && preg_match('/%[0-9A-F]{2}/i', $emoji)) {
        $emoji = urldecode($emoji);
        error_log("✅ URL decoded emoji: [$emoji]");
    }
    
    // Ensure proper UTF-8 encoding
    $emoji = mb_convert_encoding($emoji, 'UTF-8', 'UTF-8');
    $emoji = trim($emoji);
    
    error_log("Final values: user_id=$user_id, emoji=[$emoji] (length: " . strlen($emoji) . ", hex: " . bin2hex($emoji) . "), post_type=$post_type, post_id=$post_id");
    
    if (!$user_id || empty($emoji)) {
        error_log("❌ Validation failed: user_id=$user_id, emoji empty=" . (empty($emoji) ? 'yes' : 'no'));
        $cleanupAndRespond(false, 'user_id and emoji are required', 400);
        return;
    }
    
    // Verify user exists
    $user_stmt = $conn->prepare("SELECT id FROM users WHERE id = ? AND status = 'Active'");
    $user_stmt->bind_param("i", $user_id);
    $user_stmt->execute();
    if ($user_stmt->get_result()->num_rows === 0) {
        $cleanupAndRespond(false, 'User not found', 404);
        return;
    }
    
    // Check if emoji exists in emojis table
    // Handle encoding issues - normalize emoji first
    $emoji_id = null;
    $current_count = 0;
    
    // Normalize emoji - remove variation selectors and normalize encoding
    $normalized_emoji = $emoji;
    // Remove variation selector (FE0F) if present
    $normalized_emoji = preg_replace('/\x{FE0F}/u', '', $normalized_emoji);
    // Trim whitespace
    $normalized_emoji = trim($normalized_emoji);
            error_log("Normalized emoji after trim: [" . $normalized_emoji . "] (length: " . strlen($normalized_emoji) . ", hex: " . bin2hex($normalized_emoji) . ")");
    
    // Log what we're searching for
    error_log("=== EMOJI UPDATE DEBUG ===");
    error_log("Original emoji: [" . $emoji . "] (length: " . strlen($emoji) . ", hex: " . bin2hex($emoji) . ")");
    error_log("Normalized emoji after trim: [" . $normalized_emoji . "] (length: " . strlen($normalized_emoji) . ", hex: " . bin2hex($normalized_emoji) . ")");
            
            // Try multiple matching strategies - improved for better emoji matching
            error_log("Attempting Strategy 0: Direct comparison with all active emojis (character match)");
            // Strategy 0: Direct comparison with all active emojis (most reliable, try first)
    $all_active_stmt = $conn->query("SELECT id, emoji_char, usage_count, HEX(emoji_char) as emoji_hex FROM emojis WHERE status = 'Active'");
    $found_direct = false;
    
    while ($active_row = $all_active_stmt->fetch_assoc()) {
        // Compare by exact character match
        if ($active_row['emoji_char'] === $emoji) {
            $emoji_id = $active_row['id'];
            $current_count = $active_row['usage_count'];
            $found_direct = true;
            error_log("✅ FOUND by direct character comparison - ID: " . $emoji_id . ", emoji_char: [" . $active_row['emoji_char'] . "], hex: " . $active_row['emoji_hex'] . ", current_count: " . $current_count);
            break;
        }
        
        // Also compare by hex (case-insensitive)
        $db_hex = strtoupper($active_row['emoji_hex'] ?? '');
        $sent_hex = strtoupper(bin2hex($emoji));
        if ($db_hex === $sent_hex) {
            $emoji_id = $active_row['id'];
            $current_count = $active_row['usage_count'];
            $found_direct = true;
            error_log("✅ FOUND by direct hex comparison (Strategy 0) - ID: " . $emoji_id . ", emoji_char: [" . $active_row['emoji_char'] . "], hex: " . $active_row['emoji_hex'] . ", current_count: " . $current_count);
            break;
        }
    }
    
    if (!$found_direct) {
        error_log("Attempting Strategy 1: Exact match with original emoji (binary comparison via SQL)");
        // Strategy 1: Exact match with original emoji (binary comparison via SQL)
        $emoji_stmt = $conn->prepare("SELECT id, emoji_char, usage_count, HEX(emoji_char) as emoji_hex FROM emojis WHERE emoji_char = ?");
        $emoji_stmt->bind_param("s", $emoji);
        $emoji_stmt->execute();
        $emoji_result = $emoji_stmt->get_result();
        
        if ($emoji_result->num_rows > 0) {
            // Found by exact match
            $emoji_data = $emoji_result->fetch_assoc();
            $emoji_id = $emoji_data['id'];
            $current_count = $emoji_data['usage_count'];
            
            error_log("✅ FOUND by exact match - ID: " . $emoji_id . ", emoji_char: [" . $emoji_data['emoji_char'] . "], hex: " . $emoji_data['emoji_hex'] . ", current_count: " . $current_count);
        } else {
            // Strategy 2: Try hex comparison (most reliable for emojis)
            $emoji_hex = bin2hex($emoji);
            $emoji_hex_upper = strtoupper($emoji_hex);
            
            // Try both lowercase and uppercase hex
            $hex_stmt = $conn->prepare("SELECT id, emoji_char, usage_count, HEX(emoji_char) as emoji_hex FROM emojis WHERE HEX(emoji_char) = ? OR HEX(emoji_char) = ?");
            $hex_stmt->bind_param("ss", $emoji_hex, $emoji_hex_upper);
            $hex_stmt->execute();
            $hex_result = $hex_stmt->get_result();
            
            if ($hex_result->num_rows > 0) {
                $emoji_data = $hex_result->fetch_assoc();
                $emoji_id = $emoji_data['id'];
                $current_count = $emoji_data['usage_count'];
                
                error_log("✅ FOUND by hex match - ID: " . $emoji_id . ", emoji_char: [" . $emoji_data['emoji_char'] . "], hex: " . $emoji_data['emoji_hex'] . ", current_count: " . $current_count);
            } else {
                // Strategy 2b: Try case-insensitive hex comparison using UPPER()
                $hex_upper_stmt = $conn->prepare("SELECT id, emoji_char, usage_count, HEX(emoji_char) as emoji_hex FROM emojis WHERE UPPER(HEX(emoji_char)) = ?");
                $hex_upper_stmt->bind_param("s", $emoji_hex_upper);
                $hex_upper_stmt->execute();
                $hex_upper_result = $hex_upper_stmt->get_result();
                
                if ($hex_upper_result->num_rows > 0) {
                    $emoji_data = $hex_upper_result->fetch_assoc();
                    $emoji_id = $emoji_data['id'];
                    $current_count = $emoji_data['usage_count'];
                    
                    error_log("✅ FOUND by UPPER hex match - ID: " . $emoji_id . ", emoji_char: [" . $emoji_data['emoji_char'] . "], hex: " . $emoji_data['emoji_hex'] . ", current_count: " . $current_count);
                } else {
                    // Strategy 3: Try normalized emoji match (remove variation selectors)
                    $normalized_stmt = $conn->prepare("SELECT id, emoji_char, usage_count, HEX(emoji_char) as emoji_hex FROM emojis WHERE emoji_char = ? OR HEX(emoji_char) = ?");
                    $normalized_hex = bin2hex($normalized_emoji);
                    $normalized_stmt->bind_param("ss", $normalized_emoji, $normalized_hex);
                    $normalized_stmt->execute();
                    $normalized_result = $normalized_stmt->get_result();
                    
                    if ($normalized_result->num_rows > 0) {
                        $emoji_data = $normalized_result->fetch_assoc();
                        $emoji_id = $emoji_data['id'];
                        $current_count = $emoji_data['usage_count'];
                        
                        error_log("✅ FOUND by normalized match - ID: " . $emoji_id . ", emoji_char: [" . $emoji_data['emoji_char'] . "], hex: " . $emoji_data['emoji_hex'] . ", current_count: " . $current_count);
                    } else {
                        // Strategy 4: Try LIKE match (partial match)
                        $like_pattern = '%' . $emoji . '%';
                        $like_stmt = $conn->prepare("SELECT id, emoji_char, usage_count, HEX(emoji_char) as emoji_hex FROM emojis WHERE emoji_char LIKE ?");
                        $like_stmt->bind_param("s", $like_pattern);
                        $like_stmt->execute();
                        $like_result = $like_stmt->get_result();
                        
                        if ($like_result->num_rows > 0) {
                            $emoji_data = $like_result->fetch_assoc();
                            $emoji_id = $emoji_data['id'];
                            $current_count = $emoji_data['usage_count'];
                            
                            error_log("✅ FOUND by LIKE match - ID: " . $emoji_id . ", emoji_char: [" . $emoji_data['emoji_char'] . "], hex: " . $emoji_data['emoji_hex'] . ", current_count: " . $current_count);
                        } else {
                            error_log("❌ NOT FOUND in database - tried all strategies");
                            error_log("   Searched for: [" . $emoji . "] (hex: " . bin2hex($emoji) . ", length: " . strlen($emoji) . ")");
                            
                            // Show all database emojis for debugging
                            $debug_stmt = $conn->query("SELECT id, name, HEX(emoji_char) as hex FROM emojis WHERE status = 'Active' LIMIT 10");
                            error_log("   Available emojis in database:");
                            while ($debug_row = $debug_stmt->fetch_assoc()) {
                                error_log("     ID " . $debug_row['id'] . ": " . $debug_row['name'] . " (hex: " . $debug_row['hex'] . ")");
                            }
                        }
                    }
                }
            }
        }
    }
    
    // If emoji not found by emoji_char, try to find by name pattern or image_url
    // This handles cases where fruit name (like "goodness") or image URL is sent instead of emoji_char
    if ($emoji_id === null) {
        error_log("⚠️ Emoji not found by emoji_char, trying to find by name pattern or image_url: [" . $emoji . "]");
        
        // First, check if it's an image URL - try to find by image_url
        if (strpos($emoji, 'uploads/emojis/') !== false || strpos($emoji, 'emojis/') !== false || strpos($emoji, '.png') !== false || strpos($emoji, '.jpg') !== false) {
            error_log("   Detected image URL, extracting filename...");
            
            // Normalize the input: decode URL encoding first
            $normalized_emoji = urldecode($emoji);
            
            // Extract filename from URL (handle both full URL and relative path)
            $filename = basename($normalized_emoji);  // Kindness_Peach (3).png (decoded)
            $filename_encoded = basename($emoji);  // Kindness_Peach%20(3).png (original encoding)
            
            // Remove extension for pattern matching
            $filename_without_ext = preg_replace('/\.(png|jpg|jpeg|gif|webp|svg)$/i', '', $filename);  // Kindness_Peach (3)
            $filename_encoded_without_ext = preg_replace('/\.(png|jpg|jpeg|gif|webp|svg)$/i', '', $filename_encoded);  // Kindness_Peach%20(3)
            
            // Extract relative path from full URL - try multiple methods
            $relative_paths = [];
            
            // Method 1: Extract from original (encoded) URL
            if (strpos($emoji, 'uploads/emojis/') !== false) {
                $pos = strpos($emoji, 'uploads/emojis/');
                $relative_paths[] = substr($emoji, $pos);  // Keep original encoding
            }
            
            // Method 2: Extract from normalized (decoded) URL
            if (strpos($normalized_emoji, 'uploads/emojis/') !== false) {
                $pos = strpos($normalized_emoji, 'uploads/emojis/');
                $relative_paths[] = substr($normalized_emoji, $pos);  // Decoded version
            }
            
            // Method 3: Construct from filename (if path extraction failed)
            if (empty($relative_paths)) {
                $relative_paths[] = 'uploads/emojis/' . $filename_encoded;  // With encoding
                $relative_paths[] = 'uploads/emojis/' . $filename;  // Without encoding
            }
            
            // Method 4: Handle case where emojis/ is in path but not uploads/emojis/
            if (strpos($emoji, 'emojis/') !== false && strpos($emoji, 'uploads/emojis/') === false) {
                $pos = strpos($emoji, 'emojis/');
                $relative_paths[] = 'uploads/' . substr($emoji, $pos);
            }
            
            // Remove duplicates
            $relative_paths = array_unique($relative_paths);
            
            error_log("   Extracted filename (decoded): [" . $filename . "]");
            error_log("   Extracted filename (encoded): [" . $filename_encoded . "]");
            error_log("   Relative paths to try: " . print_r($relative_paths, true));
            
            // Strategy 0: Direct filename match in image_url (most reliable for exact matches)
            // This handles cases where the filename appears anywhere in the image_url
            if ($emoji_id === null && !empty($filename_encoded)) {
                error_log("   Strategy 0: Trying direct filename match with: [" . $filename_encoded . "]");
                // Try exact filename match (with %20 encoding)
                $filename_match_stmt = $conn->prepare("SELECT id, name, emoji_char, usage_count, image_url FROM emojis WHERE image_url LIKE ? AND status = 'Active' LIMIT 1");
                $filename_pattern = '%' . $conn->real_escape_string($filename_encoded) . '%';
                $filename_match_stmt->bind_param("s", $filename_pattern);
                $filename_match_stmt->execute();
                $filename_match_result = $filename_match_stmt->get_result();
                
                if ($filename_match_result->num_rows > 0) {
                    $filename_match_data = $filename_match_result->fetch_assoc();
                    $emoji_id = $filename_match_data['id'];
                    $current_count = $filename_match_data['usage_count'];
                    error_log("✅ FOUND by direct filename match - ID: " . $emoji_id . ", name: [" . $filename_match_data['name'] . "], image_url: [" . $filename_match_data['image_url'] . "], current_count: " . $current_count);
                }
            }
            
            // Strategy 1: Try exact match with all relative path variations
            if ($emoji_id === null) {
                foreach ($relative_paths as $relative_path) {
                    if ($emoji_id !== null) break;  // Already found
                    
                    if (!empty($relative_path)) {
                        error_log("   Strategy 1: Trying exact match with relative path: [" . $relative_path . "]");
                        $relative_exact_stmt = $conn->prepare("SELECT id, name, emoji_char, usage_count, image_url FROM emojis WHERE image_url = ? AND status = 'Active' LIMIT 1");
                        $relative_exact_stmt->bind_param("s", $relative_path);
                        $relative_exact_stmt->execute();
                        $relative_exact_result = $relative_exact_stmt->get_result();
                        
                        if ($relative_exact_result->num_rows > 0) {
                            $relative_exact_data = $relative_exact_result->fetch_assoc();
                            $emoji_id = $relative_exact_data['id'];
                            $current_count = $relative_exact_data['usage_count'];
                            error_log("✅ FOUND by exact image_url match (relative path: $relative_path) - ID: " . $emoji_id . ", name: [" . $relative_exact_data['name'] . "], image_url: [" . $relative_exact_data['image_url'] . "], current_count: " . $current_count);
                            break;
                        } else {
                            error_log("   ❌ No match found for relative path: [" . $relative_path . "]");
                        }
                    }
                }
            }
            
            // Strategy 2: Try exact match with full URL (in case database has full URLs)
            if ($emoji_id === null) {
                error_log("   Strategy 2: Trying exact match with full URL");
                $image_exact_stmt = $conn->prepare("SELECT id, name, emoji_char, usage_count, image_url FROM emojis WHERE image_url = ? AND status = 'Active' LIMIT 1");
                $image_exact_stmt->bind_param("s", $emoji);
                $image_exact_stmt->execute();
                $image_exact_result = $image_exact_stmt->get_result();
                
                if ($image_exact_result->num_rows > 0) {
                    $image_exact_data = $image_exact_result->fetch_assoc();
                    $emoji_id = $image_exact_data['id'];
                    $current_count = $image_exact_data['usage_count'];
                    error_log("✅ FOUND by exact image_url match (full URL) - ID: " . $emoji_id . ", name: [" . $image_exact_data['name'] . "], current_count: " . $current_count);
                } else {
                    error_log("   ❌ No match found for full URL");
                }
            }
            
            // Strategy 2b: Try LIKE match with full URL (in case of slight differences)
            if ($emoji_id === null) {
                error_log("   Strategy 2b: Trying LIKE match with full URL");
                $url_like_pattern = '%' . $conn->real_escape_string($filename_encoded) . '%';
                $url_like_stmt = $conn->prepare("SELECT id, name, emoji_char, usage_count, image_url FROM emojis WHERE image_url LIKE ? AND status = 'Active' LIMIT 1");
                $url_like_stmt->bind_param("s", $url_like_pattern);
                $url_like_stmt->execute();
                $url_like_result = $url_like_stmt->get_result();
                
                if ($url_like_result->num_rows > 0) {
                    $url_like_data = $url_like_result->fetch_assoc();
                    $emoji_id = $url_like_data['id'];
                    $current_count = $url_like_data['usage_count'];
                    error_log("✅ FOUND by LIKE match with full URL - ID: " . $emoji_id . ", name: [" . $url_like_data['name'] . "], image_url: [" . $url_like_data['image_url'] . "], current_count: " . $current_count);
                }
            }
            
            // Strategy 3: Try LIKE match with filename patterns (handles URL encoding differences)
            if ($emoji_id === null && !empty($filename)) {
                // Try multiple patterns: with %20, with space, with decoded filename, with encoded filename
                $patterns = [];
                
                if (!empty($filename)) {
                    $patterns[] = '%' . $conn->real_escape_string($filename) . '%';  // Kindness_Peach (3).png (decoded)
                }
                if (!empty($filename_encoded)) {
                    $patterns[] = '%' . $conn->real_escape_string($filename_encoded) . '%';  // Kindness_Peach%20(3).png (encoded)
                }
                if (!empty($filename_without_ext)) {
                    $patterns[] = '%' . $conn->real_escape_string($filename_without_ext) . '%';  // Kindness_Peach (3) (decoded, no ext)
                }
                if (!empty($filename_encoded_without_ext)) {
                    $patterns[] = '%' . $conn->real_escape_string($filename_encoded_without_ext) . '%';  // Kindness_Peach%20(3) (encoded, no ext)
                }
                
                // Also try with just the base name (without variant number)
                if (!empty($filename_without_ext)) {
                    $base_name = preg_replace('/\s*\(\d+\)\s*$/i', '', $filename_without_ext);  // Kindness_Peach
                    if (!empty($base_name)) {
                        $patterns[] = '%' . $conn->real_escape_string($base_name) . '%';
                    }
                }
                if (!empty($filename_encoded_without_ext)) {
                    $base_name_encoded = preg_replace('/%20\(\d+\)/i', '', $filename_encoded_without_ext);  // Kindness_Peach
                    if (!empty($base_name_encoded)) {
                        $patterns[] = '%' . $conn->real_escape_string($base_name_encoded) . '%';
                    }
                }
                
                // Remove duplicates and empty values
                $patterns = array_filter(array_unique($patterns));
                
                // Only execute query if we have patterns
                if (!empty($patterns) && count($patterns) > 0) {
                    try {
                        // Build query with dynamic number of placeholders
                        $placeholders = str_repeat('?,', count($patterns));
                        $placeholders = rtrim($placeholders, ',');
                        
                        $sql = "SELECT id, name, emoji_char, usage_count, image_url FROM emojis WHERE (image_url LIKE " . $placeholders . ") AND status = 'Active' ORDER BY usage_count DESC LIMIT 1";
                        $image_like_stmt = $conn->prepare($sql);
                        
                        if ($image_like_stmt) {
                            // Build bind_param types string
                            $types = str_repeat('s', count($patterns));
                            $image_like_stmt->bind_param($types, ...$patterns);
                            
                            if ($image_like_stmt->execute()) {
                                $image_like_result = $image_like_stmt->get_result();
                                
                                if ($image_like_result && $image_like_result->num_rows > 0) {
                                    $image_like_data = $image_like_result->fetch_assoc();
                                    $emoji_id = $image_like_data['id'];
                                    $current_count = $image_like_data['usage_count'];
                                    error_log("✅ FOUND by image_url LIKE match - ID: " . $emoji_id . ", name: [" . $image_like_data['name'] . "], image_url: [" . $image_like_data['image_url'] . "], current_count: " . $current_count);
                                }
                            } else {
                                error_log("⚠️ LIKE query execute failed: " . $image_like_stmt->error);
                            }
                        } else {
                            error_log("⚠️ LIKE query prepare failed: " . $conn->error);
                        }
                    } catch (Exception $e) {
                        error_log("⚠️ Exception in LIKE query: " . $e->getMessage());
                    }
                }
            }
            
            // Strategy 3.5: Manual comparison - get all emojis and compare filenames
            // This is a fallback that should definitely work
            if ($emoji_id === null && !empty($filename_encoded)) {
                error_log("   Strategy 3.5: Manual comparison - fetching all active emojis to compare filenames");
                $all_emojis_stmt = $conn->query("SELECT id, name, emoji_char, usage_count, image_url FROM emojis WHERE status = 'Active'");
                
                if ($all_emojis_stmt) {
                    while ($emoji_row = $all_emojis_stmt->fetch_assoc()) {
                        $db_image_url = $emoji_row['image_url'];
                        
                        // Extract filename from database image_url
                        $db_filename = basename($db_image_url);
                        
                        // Compare filenames (both encoded and decoded versions)
                        if ($db_filename === $filename_encoded || $db_filename === $filename || 
                            basename(urldecode($db_image_url)) === $filename ||
                            basename(urldecode($db_image_url)) === basename(urldecode($emoji))) {
                            $emoji_id = $emoji_row['id'];
                            $current_count = $emoji_row['usage_count'];
                            error_log("✅ FOUND by manual filename comparison - ID: " . $emoji_id . ", name: [" . $emoji_row['name'] . "], db_image_url: [" . $db_image_url . "], db_filename: [" . $db_filename . "], current_count: " . $current_count);
                            break;
                        }
                        
                        // Also try comparing the full paths
                        if (strpos($db_image_url, $filename_encoded) !== false || 
                            strpos($db_image_url, $filename) !== false ||
                            strpos($emoji, $db_filename) !== false) {
                            $emoji_id = $emoji_row['id'];
                            $current_count = $emoji_row['usage_count'];
                            error_log("✅ FOUND by manual path comparison - ID: " . $emoji_id . ", name: [" . $emoji_row['name'] . "], db_image_url: [" . $db_image_url . "], current_count: " . $current_count);
                            break;
                        }
                    }
                }
            }
            
            // Strategy 4: Extract emoji name from filename and try to match by name
            // Example: "Kindness_Peach (3).png" -> "Kindness Peach 3"
            // Example: "Self-Control_apple (2).png" -> "Self-Control Apple 2"
            if ($emoji_id === null && !empty($filename_without_ext)) {
                // Convert filename to emoji name format
                // "Kindness_Peach (3)" -> "Kindness Peach 3"
                $extracted_name = str_replace('_', ' ', $filename_without_ext);
                // Handle both "Kindness_Peach (3)" and "Kindness_Peach%20(3)" formats
                $extracted_name = str_replace('%20', ' ', $extracted_name);
                
                // Extract variant number from parentheses: "(2)" -> "2"
                $variant_number = '';
                if (preg_match('/\((\d+)\)/', $extracted_name, $matches)) {
                    $variant_number = $matches[1];
                    // Remove parentheses: "Self-Control apple (2)" -> "Self-Control apple 2"
                    $extracted_name = preg_replace('/\s*\(\d+\)\s*/', ' ' . $variant_number, $extracted_name);
                }
                
                // Split by spaces and capitalize each word properly
                $words = explode(' ', $extracted_name);
                $capitalized_words = [];
                foreach ($words as $word) {
                    // Handle hyphenated words like "Self-Control"
                    if (strpos($word, '-') !== false) {
                        $parts = explode('-', $word);
                        $capitalized_parts = array_map('ucfirst', array_map('strtolower', $parts));
                        $capitalized_words[] = implode('-', $capitalized_parts);
                    } else {
                        $capitalized_words[] = ucfirst(strtolower($word));
                    }
                }
                $extracted_name = implode(' ', $capitalized_words);
                
                // Clean up multiple spaces
                $extracted_name = preg_replace('/\s+/', ' ', trim($extracted_name));
                
                error_log("   Strategy 4: Extracted name from filename: [" . $extracted_name . "]");
                
                // Try exact name match first
                $name_exact_stmt = $conn->prepare("SELECT id, name, emoji_char, usage_count FROM emojis WHERE name = ? AND status = 'Active' LIMIT 1");
                $name_exact_stmt->bind_param("s", $extracted_name);
                $name_exact_stmt->execute();
                $name_exact_result = $name_exact_stmt->get_result();
                
                if ($name_exact_result->num_rows > 0) {
                    $name_exact_data = $name_exact_result->fetch_assoc();
                    $emoji_id = $name_exact_data['id'];
                    $current_count = $name_exact_data['usage_count'];
                    error_log("✅ FOUND by exact name match (extracted from filename) - ID: " . $emoji_id . ", name: [" . $name_exact_data['name'] . "], current_count: " . $current_count);
                } else {
                    // Try case-insensitive match
                    $name_ci_stmt = $conn->prepare("SELECT id, name, emoji_char, usage_count FROM emojis WHERE LOWER(name) = LOWER(?) AND status = 'Active' LIMIT 1");
                    $name_ci_stmt->bind_param("s", $extracted_name);
                    $name_ci_stmt->execute();
                    $name_ci_result = $name_ci_stmt->get_result();
                    
                    if ($name_ci_result->num_rows > 0) {
                        $name_ci_data = $name_ci_result->fetch_assoc();
                        $emoji_id = $name_ci_data['id'];
                        $current_count = $name_ci_data['usage_count'];
                        error_log("✅ FOUND by case-insensitive name match (extracted from filename) - ID: " . $emoji_id . ", name: [" . $name_ci_data['name'] . "], current_count: " . $current_count);
                    }
                }
            }
        }
        
        // If still not found, try to find by name pattern (case-insensitive)
        if ($emoji_id === null) {
            $emoji_lower = strtolower($emoji);
            $name_pattern = '%' . $emoji_lower . '%';
            
            // First try exact match in name (e.g., "Goodness Banana 1" contains "goodness")
            $name_stmt = $conn->prepare("SELECT id, name, emoji_char, usage_count FROM emojis WHERE LOWER(name) LIKE ? AND status = 'Active' ORDER BY usage_count DESC LIMIT 1");
            $name_stmt->bind_param("s", $name_pattern);
            $name_stmt->execute();
            $name_result = $name_stmt->get_result();
            
            if ($name_result->num_rows > 0) {
                $name_data = $name_result->fetch_assoc();
                $emoji_id = $name_data['id'];
                $current_count = $name_data['usage_count'];
                error_log("✅ FOUND by name pattern - ID: " . $emoji_id . ", name: [" . $name_data['name'] . "], current_count: " . $current_count);
            } else {
                // Try to find by first word of name (e.g., "goodness" matches "Goodness Banana 1")
                $first_word_stmt = $conn->prepare("SELECT id, name, emoji_char, usage_count FROM emojis WHERE LOWER(SUBSTRING_INDEX(name, ' ', 1)) = ? AND status = 'Active' ORDER BY usage_count DESC LIMIT 1");
                $first_word_stmt->bind_param("s", $emoji_lower);
                $first_word_stmt->execute();
                $first_word_result = $first_word_stmt->get_result();
                
                if ($first_word_result->num_rows > 0) {
                    $first_word_data = $first_word_result->fetch_assoc();
                    $emoji_id = $first_word_data['id'];
                    $current_count = $first_word_data['usage_count'];
                    error_log("✅ FOUND by first word match - ID: " . $emoji_id . ", name: [" . $first_word_data['name'] . "], current_count: " . $current_count);
                } else {
                    // Still not found - return error instead of inserting
                    error_log("❌ ERROR: Emoji not found in database - [" . $emoji . "]");
                    error_log("   Tried: emoji_char exact match, hex match, image_url match, name pattern match, first word match");
                    $cleanupAndRespond(false, 'Emoji not found. Please select a valid fruit from the list.', 404);
                    return;
                }
            }
        }
    }
    
    // Update usage count if emoji was found (either by emoji_char or by name pattern)
    if ($emoji_id !== null) {
        // Emoji exists, update usage count
        // Use direct SQL query to ensure it works (prepared statements sometimes have issues with emojis)
        $update_sql = "UPDATE emojis SET usage_count = usage_count + 1 WHERE id = " . intval($emoji_id);
        
        error_log("Executing UPDATE: " . $update_sql);
        
        if ($conn->query($update_sql)) {
            // Verify the update worked
            $verify_stmt = $conn->prepare("SELECT usage_count FROM emojis WHERE id = ?");
            $verify_stmt->bind_param("i", $emoji_id);
            $verify_stmt->execute();
            $verify_result = $verify_stmt->get_result();
            if ($verify_row = $verify_result->fetch_assoc()) {
                $new_count = $verify_row['usage_count'];
                error_log("✅ SUCCESS: Updated emoji ID " . $emoji_id . " - old: " . $current_count . ", new: " . $new_count);
            } else {
                error_log("⚠️ WARNING: Update executed but verification failed");
            }
        } else {
            error_log("❌ ERROR: Failed to update - " . $conn->error);
        }
    }
    
    error_log("=== END DEBUG ===");
    
    // Determine what to store in user_emoji_usage table
    // BEST APPROACH: Store emoji ID as string (short, unique, no truncation issues)
    // Fallback to emoji_char if available, then filename
    $original_emoji = $emoji; // Keep original before any processing
    $emoji_to_store = null;
    
    if ($emoji_id !== null) {
        // BEST: Store emoji ID as string (e.g., "212" for "Kindness Peach 3")
        // This is short, unique, and won't be truncated
        $emoji_to_store = strval($emoji_id);
        error_log("✅ Storing emoji ID in user_emoji_usage: [" . $emoji_to_store . "] (emoji_id: $emoji_id)");
    } else {
        // Fallback: If emoji_id not found, try other methods
        // Get emoji data to find the best identifier to store
        if (strpos($emoji, 'http') !== false || strpos($emoji, 'uploads/') !== false) {
            // It's a URL/path - try to find the emoji by the URL
            // We already tried to find emoji_id above, so if we're here, emoji wasn't found
            // Store filename as fallback
            $filename = basename($original_emoji);
            if (!empty($filename) && (strpos($filename, '.png') !== false || strpos($filename, '.jpg') !== false)) {
                $emoji_to_store = $filename;
                error_log("⚠️ Emoji not found in database, storing filename as fallback: [" . $emoji_to_store . "]");
            } else {
                // Last resort: store original emoji (might get truncated)
                $emoji_to_store = $original_emoji;
                error_log("⚠️ Storing original emoji (may be truncated): [" . $emoji_to_store . "]");
            }
        } else {
            // It's an emoji character - store as is
            $emoji_to_store = $original_emoji;
            error_log("✅ Storing emoji_char in user_emoji_usage: [" . $emoji_to_store . "]");
        }
    }
    
    // Final safety: If value is too long, truncate to 50 chars max
    if (strlen($emoji_to_store) > 50) {
        $emoji_to_store = substr($emoji_to_store, 0, 50);
        error_log("⚠️ Truncated emoji_to_store to 50 chars: [" . $emoji_to_store . "]");
    }
    
    // Log final value to be stored
    error_log("📝 Final emoji_to_store for user_emoji_usage: [" . $emoji_to_store . "] (length: " . strlen($emoji_to_store) . ")");
    
    // Track user emoji usage - use the shorter identifier
    $check_stmt = $conn->prepare("SELECT id, count FROM user_emoji_usage WHERE user_id = ? AND emoji = ?");
    $check_stmt->bind_param("is", $user_id, $emoji_to_store);
    $check_stmt->execute();
    $check_result = $check_stmt->get_result();
    
    if ($check_result->num_rows > 0) {
        // Update existing usage
        $existing = $check_result->fetch_assoc();
        $new_count = $existing['count'] + 1;
        $update_stmt = $conn->prepare("UPDATE user_emoji_usage SET count = ? WHERE id = ?");
        $update_stmt->bind_param("ii", $new_count, $existing['id']);
        $update_stmt->execute();
        error_log("✅ Updated user_emoji_usage: count = " . $new_count);
    } else {
        // Insert new usage
        $insert_stmt = $conn->prepare("INSERT INTO user_emoji_usage (user_id, emoji, count) VALUES (?, ?, 1)");
        $insert_stmt->bind_param("is", $user_id, $emoji_to_store);
        $insert_stmt->execute();
        error_log("✅ Inserted new user_emoji_usage record with emoji: [" . $emoji_to_store . "]");
    }
    
    // Save emoji reaction to emoji_usage table AND comments table if post_type and post_id are provided
    // TOGGLE FUNCTIONALITY: If user already reacted, remove it. Otherwise, add it.
    // This allows reactions to persist and be loaded later
    // Frontend will filter emoji reactions from text comments when displaying
    error_log("=== EMOJI REACTION SAVE CHECK ===");
    error_log("post_type: '$post_type', post_id: $post_id");
    
    if (!empty($post_type) && $post_id > 0) {
        // Determine emoji value to store (prefer emoji_id, fallback to emoji URL/character)
        $emoji_value_to_store = $emoji; // Default to original emoji
        if ($emoji_id !== null) {
            // Store emoji_id as string (most reliable)
            $emoji_value_to_store = strval($emoji_id);
            error_log("✅ Storing emoji_id in emoji_usage: $emoji_value_to_store (original emoji: [$emoji])");
        } else {
            error_log("✅ Storing emoji value in emoji_usage: [$emoji] (no emoji_id found)");
        }
        
        // Check if emoji_usage table exists
        $check_emoji_usage_table = @$conn->query("SHOW TABLES LIKE 'emoji_usage'");
        $has_emoji_usage_table = $check_emoji_usage_table && $check_emoji_usage_table->num_rows > 0;
        
        // Check if user already reacted with this emoji on this post in emoji_usage table
        $existing_emoji_usage = null;
        if ($has_emoji_usage_table) {
            $check_emoji_usage_stmt = $conn->prepare("SELECT id FROM emoji_usage WHERE post_type = ? AND post_id = ? AND user_id = ? AND emoji = ?");
            $check_emoji_usage_stmt->bind_param("siis", $post_type, $post_id, $user_id, $emoji_value_to_store);
            $check_emoji_usage_stmt->execute();
            $emoji_usage_result = $check_emoji_usage_stmt->get_result();
            if ($emoji_usage_result->num_rows > 0) {
                $existing_emoji_usage = $emoji_usage_result->fetch_assoc();
                error_log("✅ Found existing reaction in emoji_usage table by emoji: [$emoji_value_to_store]");
            }
        }
        
        // Also check comments table for backward compatibility
        $existing_comment_reaction = null;
        $emoji_id_str = ($emoji_id !== null) ? strval($emoji_id) : null;
        
        // Strategy 1: If we found emoji_id, check by emoji_id stored in content
        if ($emoji_id_str !== null) {
            $check_reaction_stmt = $conn->prepare("SELECT id FROM comments WHERE post_type = ? AND post_id = ? AND user_id = ? AND content = ?");
            $check_reaction_stmt->bind_param("siis", $post_type, $post_id, $user_id, $emoji_id_str);
            $check_reaction_stmt->execute();
            $reaction_result = $check_reaction_stmt->get_result();
            if ($reaction_result->num_rows > 0) {
                $existing_comment_reaction = $reaction_result->fetch_assoc();
                error_log("✅ Found existing reaction in comments table by emoji_id: $emoji_id_str");
            }
        }
        
        // Strategy 2: If not found, check by emoji value (for backward compatibility)
        if ($existing_comment_reaction === null) {
            $check_reaction_stmt = $conn->prepare("SELECT id FROM comments WHERE post_type = ? AND post_id = ? AND user_id = ? AND content = ?");
            $check_reaction_stmt->bind_param("siis", $post_type, $post_id, $user_id, $emoji);
            $check_reaction_stmt->execute();
            $reaction_result = $check_reaction_stmt->get_result();
            if ($reaction_result->num_rows > 0) {
                $existing_comment_reaction = $reaction_result->fetch_assoc();
                error_log("✅ Found existing reaction in comments table by emoji value: [$emoji]");
            }
        }
        
        // If reaction exists in either table, REMOVE it (toggle off)
        if ($existing_emoji_usage !== null || $existing_comment_reaction !== null) {
            // Remove from emoji_usage table
            if ($existing_emoji_usage !== null && $has_emoji_usage_table) {
                $delete_emoji_usage_stmt = $conn->prepare("DELETE FROM emoji_usage WHERE id = ?");
                $delete_emoji_usage_stmt->bind_param("i", $existing_emoji_usage['id']);
                if ($delete_emoji_usage_stmt->execute()) {
                    error_log("✅ SUCCESS: Emoji reaction REMOVED from emoji_usage table (ID: {$existing_emoji_usage['id']})");
                } else {
                    error_log("❌ ERROR: Failed to remove from emoji_usage - " . $delete_emoji_usage_stmt->error);
                }
            }
            
            // Remove from comments table
            if ($existing_comment_reaction !== null) {
                $delete_stmt = $conn->prepare("DELETE FROM comments WHERE id = ?");
                $delete_stmt->bind_param("i", $existing_comment_reaction['id']);
                if ($delete_stmt->execute()) {
                    error_log("✅ SUCCESS: Emoji reaction REMOVED from comments table (ID: {$existing_comment_reaction['id']})");
                } else {
                    error_log("❌ ERROR: Failed to remove from comments - " . $delete_stmt->error);
                }
            }
            
            $cleanupAndRespond(true, 'Emoji reaction removed', 200, [
                'removed' => true, 
                'emoji' => $emoji,
                'id' => $existing_emoji_usage['id'] ?? null,
                'user_id' => $user_id,
                'post_type' => $post_type,
                'post_id' => $post_id,
                'created_at' => date('Y-m-d H:i:s')
            ]);
            return; // Exit early - reaction removed
        } else {
            // User hasn't reacted yet - ADD the reaction (toggle on)
            $content_to_store = $emoji_value_to_store; // Use same value for comments table
            
            // Save to emoji_usage table (PRIMARY - for get_reactions endpoint)
            if ($has_emoji_usage_table) {
                error_log("📝 Attempting to INSERT into emoji_usage table:");
                error_log("   - user_id: $user_id");
                error_log("   - emoji: [$emoji_value_to_store]");
                error_log("   - post_type: $post_type");
                error_log("   - post_id: $post_id");
                
                $emoji_usage_stmt = $conn->prepare("INSERT INTO emoji_usage (user_id, emoji, post_type, post_id) VALUES (?, ?, ?, ?)");
                if (!$emoji_usage_stmt) {
                    error_log("❌ ERROR: Failed to prepare INSERT statement - " . $conn->error);
                } else {
                    $emoji_usage_stmt->bind_param("issi", $user_id, $emoji_value_to_store, $post_type, $post_id);
                    if ($emoji_usage_stmt->execute()) {
                        $emoji_usage_id = $emoji_usage_stmt->insert_id;
                        error_log("✅ SUCCESS: Emoji reaction saved to emoji_usage table with ID: $emoji_usage_id");
                        error_log("   - Saved emoji value: [$emoji_value_to_store]");
                        error_log("   - post_type: $post_type, post_id: $post_id");
                        
                        // Verify the save by querying it back
                        $verify_stmt = $conn->prepare("SELECT id, user_id, emoji, post_type, post_id FROM emoji_usage WHERE id = ?");
                        $verify_stmt->bind_param("i", $emoji_usage_id);
                        $verify_stmt->execute();
                        $verify_result = $verify_stmt->get_result();
                        if ($verify_row = $verify_result->fetch_assoc()) {
                            error_log("✅ VERIFIED: Record exists in emoji_usage table:");
                            error_log("   - id: {$verify_row['id']}");
                            error_log("   - user_id: {$verify_row['user_id']}");
                            error_log("   - emoji: [{$verify_row['emoji']}]");
                            error_log("   - post_type: {$verify_row['post_type']}");
                            error_log("   - post_id: {$verify_row['post_id']}");
                        } else {
                            error_log("⚠️ WARNING: Record saved but could not verify!");
                        }
                    } else {
                        error_log("❌ ERROR: Failed to execute INSERT - " . $emoji_usage_stmt->error);
                        error_log("   - Error code: " . $emoji_usage_stmt->errno);
                    }
                }
            } else {
                error_log("⚠️ WARNING: emoji_usage table does not exist - reactions won't be saved!");
                error_log("   - Attempting to create table...");
                // Try to create the table
                $create_table = "CREATE TABLE IF NOT EXISTS emoji_usage (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    user_id INT NOT NULL,
                    emoji VARCHAR(255) NOT NULL,
                    post_type VARCHAR(50) NULL DEFAULT NULL,
                    post_id INT(11) NULL DEFAULT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                    INDEX idx_user_id (user_id),
                    INDEX idx_created_at (created_at),
                    INDEX idx_post (post_type, post_id)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4";
                if ($conn->query($create_table)) {
                    error_log("✅ Created emoji_usage table successfully");
                    $has_emoji_usage_table = true;
                    // Retry insert
                    $emoji_usage_stmt = $conn->prepare("INSERT INTO emoji_usage (user_id, emoji, post_type, post_id) VALUES (?, ?, ?, ?)");
                    $emoji_usage_stmt->bind_param("issi", $user_id, $emoji_value_to_store, $post_type, $post_id);
                    if ($emoji_usage_stmt->execute()) {
                        $emoji_usage_id = $emoji_usage_stmt->insert_id;
                        error_log("✅ SUCCESS: Emoji reaction saved to newly created emoji_usage table with ID: $emoji_usage_id");
                    }
                } else {
                    error_log("❌ ERROR: Failed to create emoji_usage table - " . $conn->error);
                }
            }
            
            // Also save to comments table (for backward compatibility and comment filtering)
            error_log("✅ Saving emoji reaction to comments table: post_type='$post_type', post_id=$post_id, content=[$content_to_store]");
            $comment_stmt = $conn->prepare("INSERT INTO comments (post_type, post_id, user_id, content, status) VALUES (?, ?, ?, ?, 'approved')");
            $comment_stmt->bind_param("siis", $post_type, $post_id, $user_id, $content_to_store);
            if ($comment_stmt->execute()) {
                $comment_id = $comment_stmt->insert_id;
                error_log("✅ SUCCESS: Emoji reaction saved to comments table with ID: $comment_id, content: [$content_to_store]");
            } else {
                error_log("❌ ERROR: Failed to save emoji reaction to comments - " . $comment_stmt->error);
            }
            
            // Return success with data
            $cleanupAndRespond(true, 'Emoji reaction added', 200, [
                'id' => $emoji_usage_id ?? null,
                'user_id' => $user_id,
                'emoji' => $emoji_value_to_store,
                'post_type' => $post_type,
                'post_id' => $post_id,
                'created_at' => date('Y-m-d H:i:s')
            ]);
            return; // Exit early - reaction added
        }
    } else {
        error_log("⚠️ NOT saving to emoji_usage/comments (home screen emoji click - no post_type/post_id)");
    }
    error_log("=== END EMOJI REACTION CHECK ===");
    
    // Use helper function to clean up and respond
    $cleanupAndRespond(true, 'Emoji used successfully');
    
    } catch (Exception $e) {
        // Clear any output
        ob_clean();
        
        // Restore error settings
        error_reporting($old_error_reporting);
        if ($old_display_errors !== false) {
            ini_set('display_errors', $old_display_errors);
        }
        
        // Log the error
        error_log("❌ EXCEPTION in handleUseEmoji: " . $e->getMessage());
        error_log("Stack trace: " . $e->getTraceAsString());
        
        // Return error response
        http_response_code(500);
        echo jsonResponse(false, 'An error occurred while processing the emoji request: ' . $e->getMessage());
    } finally {
        // Ensure output buffer is ended
        if (ob_get_level() > 0) {
            ob_end_flush();
        }
    }
}

/**
 * Get emojis directly from uploads/emojis folder
 * This reads all image files from the folder and returns them as emoji list
 */
function handleGetEmojisFromFolder() {
    // Base path for emoji images
    $basePath = dirname(__DIR__) . '/uploads/emojis/';
    $baseUrl = 'http://admin.fosmessenger.com/emojis/';
    
    // Allowed image extensions
    $allowedExtensions = ['png', 'jpg', 'jpeg', 'gif', 'webp', 'svg'];
    
    $emojis = [];
    
    // Check if folder exists
    if (!is_dir($basePath)) {
        header('Content-Type: application/json; charset=utf-8');
        echo json_encode([
            'success' => false,
            'message' => 'Emojis folder not found',
            'data' => []
        ], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        return;
    }
    
    // Scan folder for image files
    $files = scandir($basePath);
    
    if ($files === false) {
        header('Content-Type: application/json; charset=utf-8');
        echo json_encode([
            'success' => false,
            'message' => 'Error reading emojis folder',
            'data' => []
        ], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        return;
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
        $emojiName = ucwords(str_replace('_', ' ', $fileName));
        
        // Build emoji data
        $emojiData = [
            'id' => 0, // No database ID for folder-based emojis
            'name' => $emojiName,
            'emoji_char' => '', // Will be empty for folder-based emojis
            'code' => $fileName,
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
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode([
        'success' => true,
        'message' => 'Emojis retrieved from folder',
        'data' => $emojis,
        'count' => count($emojis)
    ], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
}

$conn->close();
?>
