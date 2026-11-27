<?php
/**
 * Videos API
 * Handles: List videos, Upload video, Get video details, Live videos
 */

// Suppress any output before JSON
error_reporting(E_ALL);
ini_set('display_errors', 0);
ob_start();

require_once '../includes/db.php';
require_once '../includes/cors.php';
require_once '../includes/file_upload_helper.php';
require_once '../includes/config.php';
require_once 'auth-helper.php';

// Clear any output buffer
ob_clean();

header('Content-Type: application/json; charset=utf-8');

$method = $_SERVER['REQUEST_METHOD'];
$action = $_GET['action'] ?? $_POST['action'] ?? '';

if ($method === 'OPTIONS') {
    http_response_code(200);
    exit;
}

switch ($action) {
    case 'live':
        handleLiveVideos($conn);
        break;
    default:
        if ($method === 'GET') {
            handleGetVideos($conn);
        } elseif ($method === 'POST') {
            // Check if it's a PUT request disguised as POST
            if (isset($_POST['_method']) && $_POST['_method'] === 'PUT') {
                // Handle as PUT request
                if ($action === 'live') {
                    handleLiveVideos($conn);
                } else {
                    http_response_code(405);
                    echo jsonResponse(false, 'Method not allowed');
                }
            } else {
                $action = $_POST['action'] ?? 'upload';
                if ($action === 'edit') {
                    handleEditVideo($conn);
                } elseif ($action === 'delete') {
                    handleDeleteVideo($conn);
                } else {
                    handleUploadVideo($conn);
                }
            }
        } else {
            http_response_code(405);
            echo jsonResponse(false, 'Method not allowed');
        }
        break;
}

function handleGetVideos($conn) {
    $video_id = $_GET['id'] ?? null;
    $fruit_tag = $_GET['fruit_tag'] ?? null;
    $user_id = $_GET['user_id'] ?? null;
    $status = $_GET['status'] ?? 'Approved';
    $limit = intval($_GET['limit'] ?? 20);
    $offset = intval($_GET['offset'] ?? 0);
    $current_user_id = intval($_GET['current_user_id'] ?? 0);
    
    if ($video_id) {
        // Get single video
        $video_id = intval($video_id);
        $stmt = $conn->prepare("
            SELECT m.*, u.name as user_name, u.profile_photo
            FROM media_items m
            JOIN users u ON m.user_id = u.id
            WHERE m.id = ? AND m.type = 'video'
        ");
        $stmt->bind_param("i", $video_id);
        $stmt->execute();
        $result = $stmt->get_result();
        
        if ($result->num_rows === 0) {
            http_response_code(404);
            echo jsonResponse(false, 'Video not found');
            return;
        }
        
        $video = $result->fetch_assoc();
        
        // Get comments
        $comments_stmt = $conn->prepare("
            SELECT c.*, u.name as user_name, u.profile_photo
            FROM comments c
            JOIN users u ON c.user_id = u.id
            WHERE c.post_type = 'video' AND c.post_id = ? AND c.status = 'approved'
            ORDER BY c.created_at ASC
        ");
        $comments_stmt->bind_param("i", $video_id);
        $comments_stmt->execute();
        $comments_result = $comments_stmt->get_result();
        $comments = [];
        while ($comment = $comments_result->fetch_assoc()) {
            $comments[] = $comment;
        }
        $video['comments'] = $comments;
        
        echo jsonResponse(true, 'Video retrieved', $video);
    } else {
        // Get list of videos
        $sql = "SELECT m.*, u.name as user_name, u.profile_photo,
                       (SELECT COUNT(*) FROM comments WHERE post_type = 'video' AND post_id = m.id AND status = 'approved') as comment_count
                FROM media_items m
                JOIN users u ON m.user_id = u.id
                WHERE m.type = 'video'";
        $params = [];
        $types = "";
        
        // FILTER BLOCKED USERS
        if ($current_user_id) {
            $check_blocks = $conn->query("SHOW TABLES LIKE 'user_blocks'");
            if ($check_blocks->num_rows > 0) {
                $sql .= " AND m.user_id NOT IN (SELECT blocked_user_id FROM user_blocks WHERE user_id = ?)";
                $params[] = $current_user_id;
                $types .= "i";
            }
        }
        
        if ($status) {
            if (strpos($status, ',') !== false) {
                $status_list = explode(',', $status);
                $placeholders = implode(',', array_fill(0, count($status_list), '?'));
                $sql .= " AND m.status IN ($placeholders)";
                foreach ($status_list as $s) {
                    $params[] = trim($s);
                    $types .= "s";
                }
            } else {
                $sql .= " AND m.status = ?";
                $params[] = $status;
                $types .= "s";
            }
        }
        
        if ($fruit_tag) {
            $sql .= " AND m.fruit_tag = ?";
            $params[] = $fruit_tag;
            $types .= "s";
        }
        
        if ($user_id) {
            $sql .= " AND m.user_id = ?";
            $params[] = intval($user_id);
            $types .= "i";
        }
        
        $sql .= " ORDER BY m.created_at DESC LIMIT ? OFFSET ?";
        $params[] = $limit;
        $params[] = $offset;
        $types .= "ii";
        
        $stmt = $conn->prepare($sql);
        if (!empty($params)) {
            $stmt->bind_param($types, ...$params);
        }
        $stmt->execute();
        $result = $stmt->get_result();
        
        $videos = [];
        while ($row = $result->fetch_assoc()) {
            $videos[] = $row;
        }
        
        echo jsonResponse(true, 'Videos retrieved', $videos);
    }
}

function handleUploadVideo($conn) {
    try {
        // Clear any output
        ob_clean();
        
        // Log request for debugging
        error_log('Video upload request received');
        error_log('POST data: ' . print_r($_POST, true));
        error_log('FILES data: ' . print_r($_FILES, true));
        error_log('FILES keys: ' . implode(', ', array_keys($_FILES)));
        if (isset($_FILES['thumbnail'])) {
            error_log('Thumbnail file received: ' . $_FILES['thumbnail']['name'] . ' (' . $_FILES['thumbnail']['size'] . ' bytes)');
        } else {
            error_log('No thumbnail file in request');
        }
        
        $user_id = intval($_POST['user_id'] ?? 0);
        $fruit_tag = trim($_POST['fruit_tag'] ?? '');
        $title = trim($_POST['title'] ?? '');
        $description = trim($_POST['description'] ?? '');
        $category = trim($_POST['category'] ?? '');
        
        error_log("Parsed: user_id=$user_id, fruit_tag=$fruit_tag, title=$title, description=$description, category=$category");
        
        if (!$user_id) {
            http_response_code(400);
            echo jsonResponse(false, 'user_id is required');
            return;
        }
        
        // ===== CONTENT MODERATION FOR TITLE AND DESCRIPTION =====
        require_once '../includes/ContentModerationService.php';
        
        // Moderate title if provided
        if (!empty($title)) {
            $moderation_result = ContentModerationService::checkContent($title, $conn);
            
            switch ($moderation_result['action']) {
                case 'block':
                    http_response_code(400);
                    echo jsonResponse(false, 'Video title violates community guidelines.');
                    return;
                    
                case 'quarantine':
                case 'warn':
                    $title = $moderation_result['sanitized_content'];
                    break;
            }
        }
        
        // Moderate description if provided
        if (!empty($description)) {
            $moderation_result = ContentModerationService::checkContent($description, $conn);
            
            switch ($moderation_result['action']) {
                case 'block':
                    http_response_code(400);
                    echo jsonResponse(false, 'Video description violates community guidelines.');
                    return;
                    
                case 'quarantine':
                case 'warn':
                    $description = $moderation_result['sanitized_content'];
                    break;
            }
        }
        // ===== CONTENT MODERATION END =====
        
        // Verify user exists
        $user_stmt = $conn->prepare("SELECT id FROM users WHERE id = ? AND status = 'Active'");
        $user_stmt->bind_param("i", $user_id);
        $user_stmt->execute();
        if ($user_stmt->get_result()->num_rows === 0) {
            http_response_code(404);
            echo jsonResponse(false, 'User not found');
            return;
        }
        
        // Handle file upload
        if (!isset($_FILES['video'])) {
            http_response_code(400);
            echo jsonResponse(false, 'Video file is required');
            return;
        }
        
        $uploadError = $_FILES['video']['error'] ?? UPLOAD_ERR_NO_FILE;
        if ($uploadError !== UPLOAD_ERR_OK) {
            $errorMessages = [
                UPLOAD_ERR_INI_SIZE => 'File exceeds upload_max_filesize',
                UPLOAD_ERR_FORM_SIZE => 'File exceeds MAX_FILE_SIZE',
                UPLOAD_ERR_PARTIAL => 'File was only partially uploaded',
                UPLOAD_ERR_NO_FILE => 'No file was uploaded',
                UPLOAD_ERR_NO_TMP_DIR => 'Missing temporary folder',
                UPLOAD_ERR_CANT_WRITE => 'Failed to write file to disk',
                UPLOAD_ERR_EXTENSION => 'File upload stopped by extension',
            ];
            $errorMsg = $errorMessages[$uploadError] ?? 'Unknown upload error';
            http_response_code(400);
            echo jsonResponse(false, 'Upload error: ' . $errorMsg);
            return;
        }
        
        $target_dir = "../uploads/";
        if (!is_dir($target_dir)) {
            mkdir($target_dir, 0755, true);
        }
        
        $fileExtension = strtolower(pathinfo($_FILES['video']['name'], PATHINFO_EXTENSION));
        $allowedTypes = ['mp4', 'mov', 'avi', 'wmv', 'flv', 'webm'];
        
        if (!in_array($fileExtension, $allowedTypes)) {
            http_response_code(400);
            ob_clean();
            echo jsonResponse(false, 'Invalid video format. Allowed: mp4, mov, avi, wmv, flv, webm');
            return;
        }
        
        $maxFileSize = 100 * 1024 * 1024; // 100MB
        if ($_FILES['video']['size'] > $maxFileSize) {
            http_response_code(400);
            ob_clean();
            echo jsonResponse(false, 'Video size must be less than 100MB');
            return;
        }
        
        $fileName = 'video_' . time() . '_' . uniqid() . '.' . $fileExtension;
        $target_file = $target_dir . $fileName;
        
        error_log("Attempting to move file from {$_FILES['video']['tmp_name']} to $target_file");
        
        if (move_uploaded_file($_FILES['video']['tmp_name'], $target_file)) {
            error_log("File moved successfully to $target_file");
            $file_path = "uploads/" . $fileName;
            
            // Handle thumbnail - Priority: 1) Uploaded thumbnail, 2) Generate from video
            $thumbnailUrl = null;
            
            // Check if thumbnail was uploaded from frontend
            if (isset($_FILES['thumbnail']) && $_FILES['thumbnail']['error'] === UPLOAD_ERR_OK) {
                error_log("Thumbnail file detected in upload");
                error_log("Thumbnail file name: " . $_FILES['thumbnail']['name']);
                error_log("Thumbnail file size: " . $_FILES['thumbnail']['size']);
                error_log("Thumbnail file type: " . $_FILES['thumbnail']['type']);
                
                $thumbnailExtension = strtolower(pathinfo($_FILES['thumbnail']['name'], PATHINFO_EXTENSION));
                $allowedThumbnailTypes = ['jpg', 'jpeg', 'png', 'webp'];
                
                error_log("Detected thumbnail extension: $thumbnailExtension");
                
                if (in_array($thumbnailExtension, $allowedThumbnailTypes)) {
                    $thumbnailName = 'thumb_' . pathinfo($fileName, PATHINFO_FILENAME) . '.' . $thumbnailExtension;
                    $thumbnailPath = $target_dir . $thumbnailName;
                    
                    error_log("Attempting to move thumbnail from {$_FILES['thumbnail']['tmp_name']} to $thumbnailPath");
                    
                    if (move_uploaded_file($_FILES['thumbnail']['tmp_name'], $thumbnailPath)) {
                        $thumbnailUrl = 'uploads/' . $thumbnailName;
                        error_log("✅ Thumbnail uploaded successfully from frontend: $thumbnailUrl");
                    } else {
                        $moveError = error_get_last();
                        error_log("❌ Failed to move uploaded thumbnail file. Error: " . ($moveError ? $moveError['message'] : 'Unknown'));
                    }
                } else {
                    error_log("❌ Invalid thumbnail format: $thumbnailExtension. Allowed: " . implode(', ', $allowedThumbnailTypes));
                }
            } else {
                if (isset($_FILES['thumbnail'])) {
                    error_log("Thumbnail file has upload error: " . ($_FILES['thumbnail']['error'] ?? 'unknown'));
                }
            }
            
            // If no thumbnail was uploaded, try to generate one from video
            if (!$thumbnailUrl && function_exists('generateVideoThumbnail')) {
                try {
                    $thumbnailName = 'thumb_' . pathinfo($fileName, PATHINFO_FILENAME) . '.jpg';
                    $thumbnailPath = $target_dir . $thumbnailName;
                    $thumbnailGenerated = @generateVideoThumbnail($target_file, $thumbnailPath, 1);
                    if ($thumbnailGenerated) {
                        $thumbnailUrl = 'uploads/' . $thumbnailName;
                        error_log("Thumbnail generated from video: $thumbnailUrl");
                    }
                } catch (Exception $e) {
                    // Thumbnail generation failed, but continue without it
                    error_log('Thumbnail generation failed: ' . $e->getMessage());
                }
            }
            
            // Insert into database
            // Use basic columns that should always exist
            // Note: thumbnail_path column may not exist in all database schemas
            error_log("Preparing database insert: user_id=$user_id, file_path=$file_path, thumbnail=$thumbnailUrl, fruit_tag=$fruit_tag");
            
            // Check which columns exist
            $hasThumbnailColumn = false;
            $hasTitleColumn = false;
            $hasDescriptionColumn = false;
            $hasCategoryColumn = false;
            
            $checkThumbnail = $conn->query("SHOW COLUMNS FROM media_items LIKE 'thumbnail_path'");
            if ($checkThumbnail && $checkThumbnail->num_rows > 0) {
                $hasThumbnailColumn = true;
            }
            
            $checkTitle = $conn->query("SHOW COLUMNS FROM media_items LIKE 'title'");
            if ($checkTitle && $checkTitle->num_rows > 0) {
                $hasTitleColumn = true;
            }
            
            $checkDescription = $conn->query("SHOW COLUMNS FROM media_items LIKE 'description'");
            if ($checkDescription && $checkDescription->num_rows > 0) {
                $hasDescriptionColumn = true;
            }
            
            $checkCategory = $conn->query("SHOW COLUMNS FROM media_items LIKE 'category'");
            if ($checkCategory && $checkCategory->num_rows > 0) {
                $hasCategoryColumn = true;
            }
            
            // Build INSERT query based on available columns
            $columns = ['user_id', 'type', 'file_path', 'status', 'fruit_tag'];
            $placeholders = ['?', "'video'", '?', "'Pending'", '?'];
            $params = [$user_id, $file_path, $fruit_tag];
            $types = 'iss';
            
            if ($hasThumbnailColumn && $thumbnailUrl) {
                $columns[] = 'thumbnail_path';
                $placeholders[] = '?';
                $params[] = $thumbnailUrl;
                $types .= 's';
            }
            
            if ($hasTitleColumn && !empty($title)) {
                $columns[] = 'title';
                $placeholders[] = '?';
                $params[] = $title;
                $types .= 's';
            }
            
            if ($hasDescriptionColumn && !empty($description)) {
                $columns[] = 'description';
                $placeholders[] = '?';
                $params[] = $description;
                $types .= 's';
            }
            
            if ($hasCategoryColumn && !empty($category)) {
                $columns[] = 'category';
                $placeholders[] = '?';
                $params[] = $category;
                $types .= 's';
            }
            
            $sql = "INSERT INTO media_items (" . implode(', ', $columns) . ") VALUES (" . implode(', ', $placeholders) . ")";
            error_log("Insert SQL: $sql");
            error_log("Params: " . print_r($params, true));
            
            $stmt = $conn->prepare($sql);
            if (!$stmt) {
                error_log("Prepare failed: " . $conn->error);
                throw new Exception("Database prepare failed: " . $conn->error);
            }
            
            $stmt->bind_param($types, ...$params);
            
            if ($stmt->execute()) {
                $video_id = $stmt->insert_id;
                error_log("Video inserted successfully with ID: $video_id, title: $title, description: $description, category: $category");
                
                ob_clean(); // Clear any output before JSON
                $responseData = [
                    'id' => $video_id,
                    'file_path' => $file_path,
                ];
                if ($thumbnailUrl) {
                    $responseData['thumbnail_path'] = $thumbnailUrl;
                }
                $response = jsonResponse(true, 'Video uploaded successfully. Waiting for admin approval.', $responseData);
                error_log("Sending success response with thumbnail: " . ($thumbnailUrl ? $thumbnailUrl : 'none'));
                echo $response;
            } else {
                @unlink($target_file);
                if ($thumbnailUrl && file_exists($target_dir . basename($thumbnailUrl))) {
                    @unlink($target_dir . basename($thumbnailUrl));
                }
                http_response_code(500);
                ob_clean();
                $errorMsg = $stmt->error ?: $conn->error;
                error_log('Database insert error: ' . $errorMsg);
                error_log('SQL Error: ' . $stmt->error);
                error_log('Connection Error: ' . $conn->error);
                $response = jsonResponse(false, 'Failed to save video: ' . $errorMsg);
                echo $response;
            }
            $stmt->close();
        } else {
            http_response_code(500);
            ob_clean();
            $moveError = error_get_last();
            error_log('Failed to move uploaded file. Source: ' . $_FILES['video']['tmp_name']);
            error_log('Destination: ' . $target_file);
            error_log('Error: ' . ($moveError ? $moveError['message'] : 'Unknown error'));
            error_log('File permissions: ' . (file_exists($target_dir) ? 'Directory exists' : 'Directory missing'));
            error_log('Directory writable: ' . (is_writable($target_dir) ? 'Yes' : 'No'));
            echo jsonResponse(false, 'Failed to move uploaded file. Check server permissions. Error: ' . ($moveError ? $moveError['message'] : 'Unknown'));
        }
    } catch (Exception $e) {
        http_response_code(500);
        ob_clean();
        $errorMsg = $e->getMessage();
        $errorFile = $e->getFile();
        $errorLine = $e->getLine();
        error_log('Video upload error: ' . $errorMsg);
        error_log('Error in file: ' . $errorFile . ' on line ' . $errorLine);
        error_log('Stack trace: ' . $e->getTraceAsString());
        // Return more detailed error for debugging
        $detailedError = 'Upload failed: ' . $errorMsg;
        echo jsonResponse(false, $detailedError);
    } catch (Error $e) {
        http_response_code(500);
        ob_clean();
        $errorMsg = $e->getMessage();
        $errorFile = $e->getFile();
        $errorLine = $e->getLine();
        error_log('Video upload fatal error: ' . $errorMsg);
        error_log('Error in file: ' . $errorFile . ' on line ' . $errorLine);
        error_log('Stack trace: ' . $e->getTraceAsString());
        $detailedError = 'Upload failed: ' . $errorMsg;
        echo jsonResponse(false, $detailedError);
    } catch (Throwable $e) {
        http_response_code(500);
        ob_clean();
        $errorMsg = $e->getMessage();
        error_log('Video upload throwable error: ' . $errorMsg);
        echo jsonResponse(false, 'Upload failed: ' . $errorMsg);
    }
}

function handleLiveVideos($conn) {
    $method = $_SERVER['REQUEST_METHOD'];
    
    if ($method === 'GET') {
        // Get live videos
        $status = $_GET['status'] ?? 'Live';
        $video_id = $_GET['id'] ?? null;
        
        if ($video_id) {
            // Get single live video with stream details
            $video_id = intval($video_id);
            $stmt = $conn->prepare("
                SELECT lv.*, u.name as user_name, u.profile_photo
                FROM live_videos lv
                JOIN users u ON lv.user_id = u.id
                WHERE lv.id = ?
            ");
            $stmt->bind_param("i", $video_id);
            $stmt->execute();
            $result = $stmt->get_result();
            
            if ($result->num_rows === 0) {
                http_response_code(404);
                echo jsonResponse(false, 'Live video not found');
                return;
            }
            
            $video = $result->fetch_assoc();
            
            // Add streaming URLs if stream key exists
            if (!empty($video['stream_key'])) {
                $video['rtmp_url'] = RTMP_SERVER_URL . '/' . $video['stream_key'];
                $video['hls_url'] = HLS_SERVER_URL . '/' . $video['stream_key'] . '/index.m3u8';
            }
            
            echo jsonResponse(true, 'Live video retrieved', $video);
        } else {
            // Get list of live videos
            $stmt = $conn->prepare("
                SELECT lv.*, u.name as user_name, u.profile_photo
                FROM live_videos lv
                JOIN users u ON lv.user_id = u.id
                WHERE lv.status = ?
                ORDER BY lv.created_at DESC
            ");
            $stmt->bind_param("s", $status);
            $stmt->execute();
            $result = $stmt->get_result();
            
            $videos = [];
            while ($row = $result->fetch_assoc()) {
                // Add streaming URLs if stream key exists
                if (!empty($row['stream_key'])) {
                    $row['rtmp_url'] = RTMP_SERVER_URL . '/' . $row['stream_key'];
                    $row['hls_url'] = HLS_SERVER_URL . '/' . $row['stream_key'] . '/index.m3u8';
                }
                $videos[] = $row;
            }
            
            echo jsonResponse(true, 'Live videos retrieved', $videos);
        }
    } elseif ($method === 'POST') {
        // Check if it's a PUT request disguised as POST
        if (isset($_POST['_method']) && $_POST['_method'] === 'PUT') {
            // Update live stream status
            handleUpdateLiveStream($conn);
        } else {
            // Create live video session with stream key
            handleCreateLiveStream($conn);
        }
    } elseif ($method === 'PUT') {
        // Update live stream status
        handleUpdateLiveStream($conn);
    }
}

/**
 * Create live video stream with stream key
 */
function handleCreateLiveStream($conn) {
    if (!LIVE_STREAMING_ENABLED) {
        http_response_code(503);
        echo jsonResponse(false, 'Live streaming is currently disabled');
        return;
    }
    
    $user_id = intval($_POST['user_id'] ?? 0);
    $title = trim($_POST['title'] ?? 'Live Stream');
    $description = trim($_POST['description'] ?? '');
    $fruit_tag = trim($_POST['fruit_tag'] ?? '');
    
    if (!$user_id) {
        http_response_code(400);
        echo jsonResponse(false, 'user_id is required');
        return;
    }
    
    // Verify user exists and is active
    $user_stmt = $conn->prepare("SELECT id, role, status FROM users WHERE id = ?");
    $user_stmt->bind_param("i", $user_id);
    $user_stmt->execute();
    $user_result = $user_stmt->get_result();
    
    if ($user_result->num_rows === 0) {
        http_response_code(404);
        echo jsonResponse(false, 'User not found');
        return;
    }
    
    $user = $user_result->fetch_assoc();
    
    // Check if user is Blogger or Admin (only they can create live streams)
    if ($user['role'] !== 'Blogger' && $user['role'] !== 'Admin') {
        http_response_code(403);
        echo jsonResponse(false, 'Only approved bloggers and admins can create live streams');
        return;
    }
    
    // Generate unique stream key
    $stream_key = STREAM_KEY_PREFIX . $user_id . '_' . time() . '_' . bin2hex(random_bytes(8));
    
    // Check if live_videos table has stream_key column, if not add it
    $check_column = $conn->query("SHOW COLUMNS FROM live_videos LIKE 'stream_key'");
    if ($check_column->num_rows == 0) {
        $conn->query("ALTER TABLE live_videos ADD COLUMN stream_key VARCHAR(255) NULL AFTER status");
        $conn->query("ALTER TABLE live_videos ADD COLUMN rtmp_url VARCHAR(500) NULL AFTER stream_key");
        $conn->query("ALTER TABLE live_videos ADD COLUMN hls_url VARCHAR(500) NULL AFTER rtmp_url");
    }
    
    // Insert live video record
    $stmt = $conn->prepare("
        INSERT INTO live_videos (user_id, title, description, fruit_tag, status, stream_key, created_at) 
        VALUES (?, ?, ?, ?, 'Pending', ?, NOW())
    ");
    $stmt->bind_param("issss", $user_id, $title, $description, $fruit_tag, $stream_key);
    
    if ($stmt->execute()) {
        $live_video_id = $stmt->insert_id;
        
        // Update URLs
        $rtmp_url = RTMP_SERVER_URL . '/' . $stream_key;
        $hls_url = HLS_SERVER_URL . '/' . $stream_key . '/index.m3u8';
        
        $update_stmt = $conn->prepare("
            UPDATE live_videos SET rtmp_url = ?, hls_url = ? WHERE id = ?
        ");
        $update_stmt->bind_param("ssi", $rtmp_url, $hls_url, $live_video_id);
        $update_stmt->execute();
        
        echo jsonResponse(true, 'Live stream created successfully. Waiting for admin approval.', [
            'id' => $live_video_id,
            'stream_key' => $stream_key,
            'rtmp_url' => $rtmp_url,
            'hls_url' => $hls_url,
            'status' => 'Pending'
        ]);
    } else {
        http_response_code(500);
        echo jsonResponse(false, 'Failed to create live stream: ' . $stmt->error);
    }
}

/**
 * Update live stream status
 */
function handleUpdateLiveStream($conn) {
    $stream_id = intval($_POST['stream_id'] ?? 0);
    $status = trim($_POST['status'] ?? '');
    
    if (!$stream_id || empty($status)) {
        http_response_code(400);
        echo jsonResponse(false, 'stream_id and status are required');
        return;
    }
    
    $valid_statuses = ['Pending', 'Live', 'Ended', 'Blocked'];
    if (!in_array($status, $valid_statuses)) {
        http_response_code(400);
        echo jsonResponse(false, 'Invalid status. Valid statuses: ' . implode(', ', $valid_statuses));
        return;
    }
    
    $stmt = $conn->prepare("UPDATE live_videos SET status = ? WHERE id = ?");
    $stmt->bind_param("si", $status, $stream_id);
    
    if ($stmt->execute()) {
        echo jsonResponse(true, 'Live stream status updated', [
            'id' => $stream_id,
            'status' => $status
        ]);
    } else {
        http_response_code(500);
        echo jsonResponse(false, 'Failed to update live stream: ' . $stmt->error);
    }
}

// edit feature: Handle edit video with 15-minute window
function handleEditVideo($conn) { // edit feature
    $user_id = intval($_POST['user_id'] ?? 0); // edit feature
    $video_id = intval($_POST['video_id'] ?? 0); // edit feature
    $title = trim($_POST['title'] ?? ''); // edit feature
    $description = trim($_POST['description'] ?? ''); // edit feature
    $category = trim($_POST['category'] ?? ''); // edit feature
    
    // edit feature: Log incoming request
    error_log("📥 Edit Video Request: user_id=$user_id, video_id=$video_id"); // edit feature
    
    // edit feature: Validation
    if (!$user_id || !$video_id) { // edit feature
        http_response_code(400); // edit feature
        echo jsonResponse(false, 'user_id and video_id are required'); // edit feature
        return; // edit feature
    } // edit feature
    
    // edit feature: Content moderation check
    require_once '../includes/ContentModerationService.php'; // edit feature
    
    // edit feature: Moderate title if provided
    if (!empty($title)) { // edit feature
        $moderation_result = ContentModerationService::checkContent($title, $conn); // edit feature
        switch ($moderation_result['action']) { // edit feature
            case 'block': // edit feature
                http_response_code(400); // edit feature
                echo jsonResponse(false, 'Video title violates community guidelines.'); // edit feature
                return; // edit feature
            case 'quarantine': // edit feature
                http_response_code(400); // edit feature
                echo jsonResponse(false, 'Content cannot be edited due to content policy.'); // edit feature
                return; // edit feature
            case 'warn': // edit feature
                $title = $moderation_result['sanitized_content']; // edit feature
                break; // edit feature
            case 'allow': // edit feature
            default: // edit feature
                break; // edit feature
        } // edit feature
    } // edit feature
    
    // edit feature: Moderate description if provided
    if (!empty($description)) { // edit feature
        $moderation_result = ContentModerationService::checkContent($description, $conn); // edit feature
        switch ($moderation_result['action']) { // edit feature
            case 'block': // edit feature
                http_response_code(400); // edit feature
                echo jsonResponse(false, 'Video description violates community guidelines.'); // edit feature
                return; // edit feature
            case 'quarantine': // edit feature
                http_response_code(400); // edit feature
                echo jsonResponse(false, 'Content cannot be edited due to content policy.'); // edit feature
                return; // edit feature
            case 'warn': // edit feature
                $description = $moderation_result['sanitized_content']; // edit feature
                break; // edit feature
            case 'allow': // edit feature
            default: // edit feature
                break; // edit feature
        } // edit feature
    } // edit feature
    
    // edit feature: Verify user owns the video
    $check_stmt = $conn->prepare("SELECT user_id, created_at FROM media_items WHERE id = ? AND type = 'video'"); // edit feature
    $check_stmt->bind_param("i", $video_id); // edit feature
    $check_stmt->execute(); // edit feature
    $check_result = $check_stmt->get_result(); // edit feature
    
    if ($check_result->num_rows === 0) { // edit feature
        http_response_code(404); // edit feature
        echo jsonResponse(false, 'Video not found'); // edit feature
        return; // edit feature
    } // edit feature
    
    $video_data = $check_result->fetch_assoc(); // edit feature
    
    // edit feature: Check if user owns the video
    if ($video_data['user_id'] != $user_id) { // edit feature
        http_response_code(403); // edit feature
        echo jsonResponse(false, 'You can only edit your own videos'); // edit feature
        return; // edit feature
    } // edit feature
    
    // edit feature: Check if video is within 15-minute window
    $created_at = strtotime($video_data['created_at']); // edit feature
    $now = time(); // edit feature
    $time_diff_minutes = ($now - $created_at) / 60; // edit feature
    
    if ($time_diff_minutes > 15) { // edit feature
        http_response_code(403); // edit feature
        echo jsonResponse(false, 'Videos can only be edited within 15 minutes of posting'); // edit feature
        return; // edit feature
    } // edit feature
    
    // edit feature: Check if edited_at column exists
    $check_column = $conn->query("SHOW COLUMNS FROM media_items LIKE 'edited_at'"); // edit feature
    $has_edited_at = $check_column && $check_column->num_rows > 0; // edit feature
    
    // edit feature: Build update query
    $update_parts = []; // edit feature
    $types = ""; // edit feature
    $params = []; // edit feature
    
    if (!empty($title)) { // edit feature
        $update_parts[] = "title = ?"; // edit feature
        $params[] = $title; // edit feature
        $types .= "s"; // edit feature
    } // edit feature
    
    if (!empty($description)) { // edit feature
        $update_parts[] = "description = ?"; // edit feature
        $params[] = $description; // edit feature
        $types .= "s"; // edit feature
    } // edit feature
    
    if (!empty($category)) { // edit feature
        $update_parts[] = "category = ?"; // edit feature
        $params[] = $category; // edit feature
        $types .= "s"; // edit feature
    } // edit feature
    
    if ($has_edited_at) { // edit feature
        $update_parts[] = "edited_at = NOW()"; // edit feature
        $update_parts[] = "is_edited = 1"; // edit feature
    } // edit feature
    
    $params[] = $video_id; // edit feature
    $types .= "i"; // edit feature
    
    $sql = "UPDATE media_items SET " . implode(", ", $update_parts) . " WHERE id = ? AND type = 'video'"; // edit feature
    $update_stmt = $conn->prepare($sql); // edit feature
    $update_stmt->bind_param($types, ...$params); // edit feature
    
    if ($update_stmt->execute()) { // edit feature
        error_log("✅ Video edited: ID=$video_id, user_id=$user_id"); // edit feature
        echo jsonResponse(true, 'Video edited successfully', [ // edit feature
            'id' => $video_id, // edit feature
            'is_edited' => true // edit feature
        ]); // edit feature
    } else { // edit feature
        error_log("❌ Failed to edit video: " . $update_stmt->error); // edit feature
        http_response_code(500); // edit feature
        echo jsonResponse(false, 'Failed to edit video: ' . $update_stmt->error); // edit feature
    } // edit feature
} // edit feature

function handleDeleteVideo($conn) {
    $user_id = intval($_POST['user_id'] ?? 0);
    $video_id = intval($_POST['video_id'] ?? 0);

    if (!$user_id || !$video_id) {
        http_response_code(400);
        echo jsonResponse(false, 'user_id and video_id are required');
        return;
    }

    $check_stmt = $conn->prepare("SELECT user_id, status FROM media_items WHERE id = ? AND type = 'video'");
    $check_stmt->bind_param("i", $video_id);
    $check_stmt->execute();
    $check_result = $check_stmt->get_result();

    if ($check_result->num_rows === 0) {
        http_response_code(404);
        echo jsonResponse(false, 'Video not found');
        return;
    }

    $video_data = $check_result->fetch_assoc();

    if ($video_data['user_id'] != $user_id) {
        http_response_code(403);
        echo jsonResponse(false, 'You can only delete your own videos');
        return;
    }

    if ($video_data['status'] === 'Deleted') {
        http_response_code(404);
        echo jsonResponse(false, 'Video already deleted');
        return;
    }

    $delete_stmt = $conn->prepare("UPDATE media_items SET status = 'Deleted' WHERE id = ? AND type = 'video'");
    $delete_stmt->bind_param("i", $video_id);

    if ($delete_stmt->execute()) {
        echo jsonResponse(true, 'Video deleted successfully', ['id' => $video_id]);
    } else {
        http_response_code(500);
        echo jsonResponse(false, 'Failed to delete video: ' . $delete_stmt->error);
    }
}

// Don't close connection here - let it close automatically
// Remove closing PHP tag to prevent any whitespace output