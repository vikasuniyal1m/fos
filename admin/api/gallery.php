<?php
/**
 * Gallery/Media API - Social Media Style
 * Handles: List photos, Upload photo, Get photo details, Like/Unlike, Comments
 */

// Start output buffering to prevent any output before JSON
ob_start();

// Suppress warnings for column existence checks
error_reporting(E_ALL & ~E_WARNING & ~E_NOTICE);
ini_set('display_errors', 0);

require_once '../includes/db.php';
require_once '../includes/cors.php';
// Include file upload helper if it exists, otherwise functions are defined at bottom of this file
if (file_exists('../includes/file_upload_helper.php')) {
    require_once '../includes/file_upload_helper.php';
}
require_once 'auth-helper.php';

// Clear any output that might have been generated
ob_clean();

header('Content-Type: application/json; charset=utf-8');

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// Log which file is being executed
error_log('=== GALLERY.PHP EXECUTED ===');
error_log('SCRIPT_NAME: ' . ($_SERVER['SCRIPT_NAME'] ?? 'unknown'));
error_log('REQUEST_URI: ' . ($_SERVER['REQUEST_URI'] ?? 'unknown'));
error_log('REQUEST_METHOD: ' . $method);

try {
    switch ($method) {
        case 'GET':
            $action = $_GET['action'] ?? '';
            if ($action === 'get-comments') {
                handleGetComments($conn);
            } else {
                handleGetGallery($conn);
            }
            break;
        case 'POST':
            // For multipart requests, $_POST might be empty, so check $_REQUEST too
            $action = $_POST['action'] ?? $_REQUEST['action'] ?? '';
            error_log('POST action detected: ' . ($action ?: 'none (will call handleUploadPhoto)'));
            
            if ($action === 'like' || $action === 'unlike') {
                handleToggleLike($conn);
            } elseif ($action === 'add-comment') {
                handleAddComment($conn);
            } elseif ($action === 'like-comment') {
                handleLikeComment($conn);
            } elseif ($action === 'delete-comment') {
                handleDeleteComment($conn);
            } elseif ($action === 'delete') {
                handleDeletePhoto($conn);
            } elseif ($action === 'edit-comment') {
                handleEditComment($conn);
            } else {
                error_log('Calling handleUploadPhoto (no action specified)');
                handleUploadPhoto($conn);
            }
            break;
        default:
            http_response_code(405);
            echo jsonResponse(false, 'Method not allowed');
            break;
    }
} catch (Exception $e) {
    ob_clean();
    error_log("❌ Fatal error in gallery.php: " . $e->getMessage());
    error_log("❌ Stack trace: " . $e->getTraceAsString());
    http_response_code(500);
    echo jsonResponse(false, 'Server error: ' . $e->getMessage());
} catch (Error $e) {
    ob_clean();
    error_log("❌ Fatal PHP error in gallery.php: " . $e->getMessage());
    error_log("❌ Stack trace: " . $e->getTraceAsString());
    http_response_code(500);
    echo jsonResponse(false, 'Server error: ' . $e->getMessage());
}

function handleGetGallery($conn) {
    $media_id = $_GET['id'] ?? null;
    $fruit_tag = $_GET['fruit_tag'] ?? null;
    $user_id = $_GET['user_id'] ?? null;
    $status = $_GET['status'] ?? 'Approved';
    $limit = intval($_GET['limit'] ?? 20);
    $offset = intval($_GET['offset'] ?? 0);
    $current_user_id = intval($_GET['current_user_id'] ?? 0);
    
    if ($media_id) {
        // Get single media item
        $media_id = intval($media_id);
        
        // Check if media_likes table exists
        $check_likes_table = @$conn->query("SHOW TABLES LIKE 'media_likes'");
        $has_likes_table = $check_likes_table && $check_likes_table->num_rows > 0;
        
        $like_count_sql = $has_likes_table ? "(SELECT COUNT(*) FROM media_likes WHERE media_id = m.id)" : "0";
        $is_liked_sql = ($has_likes_table && $current_user_id > 0) ? "(SELECT COUNT(*) FROM media_likes WHERE media_id = m.id AND user_id = ?)" : "0";
        
        $stmt = $conn->prepare("
            SELECT m.*, u.name as user_name, u.profile_photo,
                   $like_count_sql as like_count,
                   $is_liked_sql as is_liked
            FROM media_items m
            JOIN users u ON m.user_id = u.id AND u.status != 'Deleted'
            WHERE m.id = ? AND m.type = 'photo' AND m.status != 'Deleted'
        ");
        if ($current_user_id > 0 && $has_likes_table) {
            $stmt->bind_param("ii", $current_user_id, $media_id);
        } else {
            $stmt->bind_param("i", $media_id);
        }
        $stmt->execute();
        $result = $stmt->get_result();
        
        if ($result->num_rows === 0) {
            http_response_code(404);
            echo jsonResponse(false, 'Photo not found');
            return;
        }
        
        $photo = $result->fetch_assoc();
        
        // Try to get comments from gallery_comments table first, fallback to comments table
        // Return comments with nested replies structure (same as handleGetComments)
        $comments = [];
        try {
            // Check if gallery_comments table exists
            $check_gallery_comments = @$conn->query("SHOW TABLES LIKE 'gallery_comments'");
            $has_gallery_comments = $check_gallery_comments && $check_gallery_comments->num_rows > 0;
            
            // Check if gallery_comment_likes table exists for is_liked check
            $check_likes_table = @$conn->query("SHOW TABLES LIKE 'gallery_comment_likes'");
            $has_likes_table = $check_likes_table && $check_likes_table->num_rows > 0;
            
            if ($has_gallery_comments) {
                // Use new gallery_comments table with nested replies structure
                // Get top-level comments (parent_comment_id IS NULL)
                $top_level_sql = "SELECT gc.*, u.name as user_name, u.profile_photo";
                if ($has_likes_table && $current_user_id > 0) {
                    $top_level_sql .= ", (SELECT COUNT(*) FROM gallery_comment_likes WHERE comment_id = gc.id AND user_id = ?) as is_liked";
                } else {
                    $top_level_sql .= ", 0 as is_liked";
                }
                $top_level_sql .= " FROM gallery_comments gc
                    JOIN users u ON gc.user_id = u.id AND u.status != 'Deleted'
                    WHERE gc.photo_id = ? AND gc.is_deleted = 0 AND gc.parent_comment_id IS NULL
                    ORDER BY gc.created_at DESC";
                
                $top_level_stmt = $conn->prepare($top_level_sql);
                if ($has_likes_table && $current_user_id > 0) {
                    $top_level_stmt->bind_param("ii", $current_user_id, $media_id);
                } else {
                    $top_level_stmt->bind_param("i", $media_id);
                }
                $top_level_stmt->execute();
                $top_level_result = $top_level_stmt->get_result();
                
                while ($comment = $top_level_result->fetch_assoc()) {
                    // Get replies for this comment
                    $reply_sql = "SELECT gc.*, u.name as user_name, u.profile_photo";
                    if ($has_likes_table && $current_user_id > 0) {
                        $reply_sql .= ", (SELECT COUNT(*) FROM gallery_comment_likes WHERE comment_id = gc.id AND user_id = ?) as is_liked";
                    } else {
                        $reply_sql .= ", 0 as is_liked";
                    }
                    $reply_sql .= " FROM gallery_comments gc
                        JOIN users u ON gc.user_id = u.id AND u.status != 'Deleted'
                        WHERE gc.parent_comment_id = ? AND gc.is_deleted = 0
                        ORDER BY gc.created_at ASC";
                    
                    $reply_stmt = $conn->prepare($reply_sql);
                    if ($has_likes_table && $current_user_id > 0) {
                        $reply_stmt->bind_param("ii", $current_user_id, $comment['id']);
                    } else {
                        $reply_stmt->bind_param("i", $comment['id']);
                    }
                    $reply_stmt->execute();
                    $reply_result = $reply_stmt->get_result();
                    
                    $replies = [];
                    while ($reply = $reply_result->fetch_assoc()) {
                        $replies[] = $reply;
                    }
                    $comment['replies'] = $replies;
                    $comments[] = $comment;
                }
            } else {
                // Fallback to old comments table (flat structure)
                $comments_stmt = $conn->prepare("
                    SELECT c.*, u.name as user_name, u.profile_photo
                    FROM comments c
                    JOIN users u ON c.user_id = u.id AND u.status != 'Deleted'
                    WHERE c.post_type = 'gallery' AND c.post_id = ? AND c.status = 'approved' AND c.is_deleted = 0
                    ORDER BY c.created_at ASC
                ");
                $comments_stmt->bind_param("i", $media_id);
                $comments_stmt->execute();
                $comments_result = $comments_stmt->get_result();
                while ($comment = $comments_result->fetch_assoc()) {
                    $comments[] = $comment;
                }
            }
        } catch (Exception $e) {
            error_log("Error fetching comments: " . $e->getMessage());
        }
        $photo['comments'] = $comments;
        
        echo jsonResponse(true, 'Photo retrieved', $photo);
    } else {
        // Get list of photos
        // Check if media_likes table exists
        $check_likes_table = @$conn->query("SHOW TABLES LIKE 'media_likes'");
        $has_likes_table = $check_likes_table && $check_likes_table->num_rows > 0;
        
        // Check if gallery_comments table exists for comment count
        $check_gallery_comments = @$conn->query("SHOW TABLES LIKE 'gallery_comments'");
        $has_gallery_comments = $check_gallery_comments && $check_gallery_comments->num_rows > 0;
        
        $like_count_sql = $has_likes_table ? "(SELECT COUNT(*) FROM media_likes WHERE media_id = m.id)" : "0";
        $is_liked_sql = ($has_likes_table && $current_user_id > 0) ? "(SELECT COUNT(*) FROM media_likes WHERE media_id = m.id AND user_id = ?)" : "0";
        
        // Use gallery_comments if exists, otherwise fallback to comments table
        $comment_count_sql = $has_gallery_comments 
            ? "(SELECT COUNT(*) FROM gallery_comments WHERE photo_id = m.id AND is_deleted = 0)"
            : "(SELECT COUNT(*) FROM comments WHERE post_type = 'gallery' AND post_id = m.id AND status = 'approved')";
        
        $sql = "SELECT m.*, u.name as user_name, u.profile_photo,
                       $like_count_sql as like_count,
                       $is_liked_sql as is_liked,
                       $comment_count_sql as comment_count
                FROM media_items m
                JOIN users u ON m.user_id = u.id AND u.status != 'Deleted'
                WHERE m.type = 'photo' AND m.status != 'Deleted'";
        $params = [];
        $types = "";
        
        // FILTER BLOCKED USERS
        if ($current_user_id > 0) {
            $check_blocks = $conn->query("SHOW TABLES LIKE 'user_blocks'");
            if ($check_blocks->num_rows > 0) {
                // We use subquery for blocked users, query is getting complex but we will bind this ID
                // Note: The param order matters!! We are pushing to $params[] which goes AFTER the SELECT args? NO
                // wait, bind_param order relies on where the ? is.
                // The current strategy is to build sql with ? and append params. A proper way.
                
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
            // Case-insensitive matching for fruit_tag
            $sql .= " AND LOWER(TRIM(m.fruit_tag)) = LOWER(TRIM(?))";
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
        
        // Add current_user_id for like check if needed
        if ($current_user_id > 0 && $has_likes_table) {
            array_unshift($params, $current_user_id);
            $types = "i" . $types;
        }
        
        $stmt = $conn->prepare($sql);
        if (!empty($params)) {
            $stmt->bind_param($types, ...$params);
        }
        $stmt->execute();
        $result = $stmt->get_result();
        
        $photos = [];
        while ($row = $result->fetch_assoc()) {
            $photos[] = $row;
        }
        
        echo jsonResponse(true, 'Gallery photos retrieved', $photos);
    }
}

// =====================================================
// NEW: Handle Get Comments (GET: action=get-comments)
// =====================================================
function handleGetComments($conn) {
    if (!isset($_GET['photo_id'])) {
        http_response_code(400);
        echo jsonResponse(false, 'photo_id is required');
        return;
    }
    
    $photo_id = intval($_GET['photo_id']);
    $current_user_id = isset($_GET['user_id']) ? intval($_GET['user_id']) : 0;
    
    // Check if gallery_comments table exists, if not create it
    $check_table = @$conn->query("SHOW TABLES LIKE 'gallery_comments'");
    $has_gallery_comments = $check_table && $check_table->num_rows > 0;
    
    if (!$has_gallery_comments) {
        // Create gallery_comments table
        $create_table = "CREATE TABLE IF NOT EXISTS gallery_comments (
            id INT AUTO_INCREMENT PRIMARY KEY,
            photo_id INT NOT NULL,
            user_id INT NOT NULL,
            content TEXT NOT NULL,
            parent_comment_id INT NULL DEFAULT NULL,
            like_count INT DEFAULT 0,
            reply_count INT DEFAULT 0,
            is_deleted TINYINT(1) DEFAULT 0,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            INDEX idx_photo_id (photo_id),
            INDEX idx_user_id (user_id),
            INDEX idx_parent_comment_id (parent_comment_id),
            INDEX idx_created_at (created_at),
            INDEX idx_is_deleted (is_deleted)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci";
        if (!$conn->query($create_table)) {
            error_log("Failed to create gallery_comments table: " . $conn->error);
            http_response_code(500);
            echo jsonResponse(false, 'Failed to create gallery comments table: ' . $conn->error);
            return;
        }
        $has_gallery_comments = true;
    }
    
    // Also ensure gallery_comment_likes table exists for is_liked check
    $check_likes_table = @$conn->query("SHOW TABLES LIKE 'gallery_comment_likes'");
    $has_likes_table = $check_likes_table && $check_likes_table->num_rows > 0;
    
    if (!$has_likes_table) {
        // Create gallery_comment_likes table
        $create_likes_table = "CREATE TABLE IF NOT EXISTS gallery_comment_likes (
            id INT AUTO_INCREMENT PRIMARY KEY,
            comment_id INT NOT NULL,
            user_id INT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UNIQUE KEY unique_comment_like (comment_id, user_id),
            INDEX idx_comment_id (comment_id),
            INDEX idx_user_id (user_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci";
        if (!$conn->query($create_likes_table)) {
            error_log("Failed to create gallery_comment_likes table: " . $conn->error);
            // Continue anyway, is_liked will just be 0
        }
    }
    
    // Get top-level comments with user info
    $sql = "SELECT gc.*, u.name as user_name, u.profile_photo,
            (SELECT COUNT(*) FROM gallery_comment_likes WHERE comment_id = gc.id AND user_id = ?) as is_liked
            FROM gallery_comments gc
            JOIN users u ON gc.user_id = u.id
            WHERE gc.photo_id = ? AND gc.is_deleted = 0 AND gc.parent_comment_id IS NULL
            ORDER BY gc.created_at DESC";
    
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("ii", $current_user_id, $photo_id);
    $stmt->execute();
    $result = $stmt->get_result();
    
    $comments = [];
    while ($comment = $result->fetch_assoc()) {
        // Get replies for this comment
        $replySql = "SELECT gc.*, u.name as user_name, u.profile_photo,
                     (SELECT COUNT(*) FROM gallery_comment_likes WHERE comment_id = gc.id AND user_id = ?) as is_liked
                     FROM gallery_comments gc
                     JOIN users u ON gc.user_id = u.id
                     WHERE gc.parent_comment_id = ? AND gc.is_deleted = 0
                     ORDER BY gc.created_at ASC";
        $replyStmt = $conn->prepare($replySql);
        $replyStmt->bind_param("ii", $current_user_id, $comment['id']);
        $replyStmt->execute();
        $replyResult = $replyStmt->get_result();
        
        $replies = [];
        while ($reply = $replyResult->fetch_assoc()) {
            $replies[] = $reply;
        }
        $comment['replies'] = $replies;
        $comments[] = $comment;
    }
    
    echo jsonResponse(true, 'Comments retrieved successfully', $comments);
}

// =====================================================
// NEW: Handle Add Comment (POST: action=add-comment)
// =====================================================
function handleAddComment($conn) {
    if (!isset($_POST['photo_id']) || !isset($_POST['user_id']) || !isset($_POST['content'])) {
        http_response_code(400);
        echo jsonResponse(false, 'Missing required fields: photo_id, user_id, content');
        return;
    }
    
    $photo_id = intval($_POST['photo_id']);
    $user_id = intval($_POST['user_id']);
    $content = trim($_POST['content']);
    $parent_comment_id = isset($_POST['parent_comment_id']) && $_POST['parent_comment_id'] > 0 
        ? intval($_POST['parent_comment_id']) 
        : null;
    
    if (empty($content)) {
        http_response_code(400);
        echo jsonResponse(false, 'Comment content cannot be empty');
        return;
    }
    
    // Check if gallery_comments table exists, if not create it
    $check_table = @$conn->query("SHOW TABLES LIKE 'gallery_comments'");
    $has_gallery_comments = $check_table && $check_table->num_rows > 0;
    
    if (!$has_gallery_comments) {
        // Create gallery_comments table
        $create_table = "CREATE TABLE IF NOT EXISTS gallery_comments (
            id INT AUTO_INCREMENT PRIMARY KEY,
            photo_id INT NOT NULL,
            user_id INT NOT NULL,
            content TEXT NOT NULL,
            parent_comment_id INT NULL DEFAULT NULL,
            like_count INT DEFAULT 0,
            reply_count INT DEFAULT 0,
            is_deleted TINYINT(1) DEFAULT 0,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            INDEX idx_photo_id (photo_id),
            INDEX idx_user_id (user_id),
            INDEX idx_parent_comment_id (parent_comment_id),
            INDEX idx_created_at (created_at),
            INDEX idx_is_deleted (is_deleted)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci";
        if (!$conn->query($create_table)) {
            error_log("Failed to create gallery_comments table: " . $conn->error);
            http_response_code(500);
            echo jsonResponse(false, 'Failed to create gallery comments table: ' . $conn->error);
            return;
        }
        $has_gallery_comments = true;
    }
    
    // Check if photo exists (using media_items table - photo_id maps to media_items.id)
    // Allow comments on photos regardless of status (Approved, Pending, etc.)
    $checkPhoto = $conn->prepare("SELECT id FROM media_items WHERE id = ? AND type = 'photo'");
    $checkPhoto->bind_param("i", $photo_id);
    $checkPhoto->execute();
    $photoResult = $checkPhoto->get_result();
    
    if ($photoResult->num_rows == 0) {
        http_response_code(404);
        echo jsonResponse(false, 'Photo not found');
        return;
    }
    
    // If it's a reply, check if parent comment exists
    if ($parent_comment_id !== null) {
        $checkParent = $conn->prepare("SELECT id FROM gallery_comments WHERE id = ? AND photo_id = ? AND is_deleted = 0");
        $checkParent->bind_param("ii", $parent_comment_id, $photo_id);
        $checkParent->execute();
        $parentResult = $checkParent->get_result();
        
        if ($parentResult->num_rows == 0) {
            http_response_code(404);
            echo jsonResponse(false, 'Parent comment not found');
            return;
        }
    }
    
    // Insert comment
    if ($parent_comment_id !== null) {
        $sql = "INSERT INTO gallery_comments (photo_id, user_id, content, parent_comment_id) VALUES (?, ?, ?, ?)";
        $stmt = $conn->prepare($sql);
        $stmt->bind_param("iisi", $photo_id, $user_id, $content, $parent_comment_id);
    } else {
        $sql = "INSERT INTO gallery_comments (photo_id, user_id, content) VALUES (?, ?, ?)";
        $stmt = $conn->prepare($sql);
        $stmt->bind_param("iis", $photo_id, $user_id, $content);
    }
    
    if ($stmt->execute()) {
        $comment_id = $stmt->insert_id;
        
        // Update reply_count if it's a reply
        if ($parent_comment_id !== null) {
            $updateReplyCount = $conn->prepare("UPDATE gallery_comments SET reply_count = reply_count + 1 WHERE id = ?");
            $updateReplyCount->bind_param("i", $parent_comment_id);
            $updateReplyCount->execute();
        }
        
        echo jsonResponse(true, 'Comment added successfully', [
            'id' => $comment_id,
            'comment_id' => $comment_id,
            'is_reply' => $parent_comment_id !== null
        ]);
    } else {
        http_response_code(500);
        echo jsonResponse(false, 'Failed to add comment: ' . $stmt->error);
    }
}

// =====================================================
// NEW: Handle Like Comment (POST: action=like-comment)
// =====================================================
function handleLikeComment($conn) {
    if (!isset($_POST['comment_id']) || !isset($_POST['user_id'])) {
        http_response_code(400);
        echo jsonResponse(false, 'comment_id and user_id are required');
        return;
    }
    
    $comment_id = intval($_POST['comment_id']);
    $user_id = intval($_POST['user_id']);
    
    // Check if gallery_comment_likes table exists, if not create it
    $check_table = @$conn->query("SHOW TABLES LIKE 'gallery_comment_likes'");
    $has_likes_table = $check_table && $check_table->num_rows > 0;
    
    if (!$has_likes_table) {
        // Create gallery_comment_likes table
        $create_table = "CREATE TABLE IF NOT EXISTS gallery_comment_likes (
            id INT AUTO_INCREMENT PRIMARY KEY,
            comment_id INT NOT NULL,
            user_id INT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UNIQUE KEY unique_comment_like (comment_id, user_id),
            INDEX idx_comment_id (comment_id),
            INDEX idx_user_id (user_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci";
        if (!$conn->query($create_table)) {
            error_log("Failed to create gallery_comment_likes table: " . $conn->error);
            http_response_code(500);
            echo jsonResponse(false, 'Failed to create gallery comment likes table: ' . $conn->error);
            return;
        }
        $has_likes_table = true;
    }
    
    // Check if comment exists
    $checkComment = $conn->prepare("SELECT id, like_count FROM gallery_comments WHERE id = ? AND is_deleted = 0");
    $checkComment->bind_param("i", $comment_id);
    $checkComment->execute();
    $commentResult = $checkComment->get_result();
    
    if ($commentResult->num_rows == 0) {
        http_response_code(404);
        echo jsonResponse(false, 'Comment not found');
        return;
    }
    
    // Check if already liked
    $checkLike = $conn->prepare("SELECT id FROM gallery_comment_likes WHERE comment_id = ? AND user_id = ?");
    $checkLike->bind_param("ii", $comment_id, $user_id);
    $checkLike->execute();
    $likeResult = $checkLike->get_result();
    $isLiked = $likeResult->num_rows > 0;
    
    if ($isLiked) {
        // Unlike: Remove from likes table
        $deleteLike = $conn->prepare("DELETE FROM gallery_comment_likes WHERE comment_id = ? AND user_id = ?");
        $deleteLike->bind_param("ii", $comment_id, $user_id);
        $deleteLike->execute();
        
        // Update like_count
        $updateCount = $conn->prepare("UPDATE gallery_comments SET like_count = GREATEST(like_count - 1, 0) WHERE id = ?");
        $updateCount->bind_param("i", $comment_id);
        $updateCount->execute();
        
        echo jsonResponse(true, 'Comment unliked', ['liked' => false]);
    } else {
        // Like: Add to likes table
        $insertLike = $conn->prepare("INSERT INTO gallery_comment_likes (comment_id, user_id) VALUES (?, ?)");
        $insertLike->bind_param("ii", $comment_id, $user_id);
        $insertLike->execute();
        
        // Update like_count
        $updateCount = $conn->prepare("UPDATE gallery_comments SET like_count = like_count + 1 WHERE id = ?");
        $updateCount->bind_param("i", $comment_id);
        $updateCount->execute();
        
        echo jsonResponse(true, 'Comment liked', ['liked' => true]);
    }
}

// Handle Delete Photo (POST: action=delete)
function handleDeletePhoto($conn) {
    $user_id = intval($_POST['user_id'] ?? 0);
    $media_id = intval($_POST['media_id'] ?? 0);

    if (!$user_id || !$media_id) {
        http_response_code(400);
        echo jsonResponse(false, 'user_id and media_id are required');
        return;
    }

    $check_stmt = $conn->prepare("SELECT user_id, status FROM media_items WHERE id = ? AND type = 'photo'");
    $check_stmt->bind_param("i", $media_id);
    $check_stmt->execute();
    $check_result = $check_stmt->get_result();

    if ($check_result->num_rows === 0) {
        http_response_code(404);
        echo jsonResponse(false, 'Photo not found');
        return;
    }

    $photo_data = $check_result->fetch_assoc();

    if ($photo_data['user_id'] != $user_id) {
        http_response_code(403);
        echo jsonResponse(false, 'You can only delete your own photos');
        return;
    }

    if ($photo_data['status'] === 'Deleted') {
        http_response_code(404);
        echo jsonResponse(false, 'Photo already deleted');
        return;
    }

    $delete_stmt = $conn->prepare("UPDATE media_items SET status = 'Deleted' WHERE id = ? AND type = 'photo'");
    $delete_stmt->bind_param("i", $media_id);

    if ($delete_stmt->execute()) {
        echo jsonResponse(true, 'Photo deleted successfully', ['id' => $media_id]);
    } else {
        http_response_code(500);
        echo jsonResponse(false, 'Failed to delete photo: ' . $delete_stmt->error);
    }
}

// =====================================================
// NEW: Handle Delete Comment (POST: action=delete-comment) - Optional
// =====================================================
function handleDeleteComment($conn) {
    if (!isset($_POST['comment_id']) || !isset($_POST['user_id'])) {
        http_response_code(400);
        echo jsonResponse(false, 'comment_id and user_id are required');
        return;
    }
    
    $comment_id = intval($_POST['comment_id']);
    $user_id = intval($_POST['user_id']);
    
    // Check if user owns the comment
    $checkOwner = $conn->prepare("SELECT user_id FROM gallery_comments WHERE id = ? AND is_deleted = 0");
    $checkOwner->bind_param("i", $comment_id);
    $checkOwner->execute();
    $ownerResult = $checkOwner->get_result();
    $comment = $ownerResult->fetch_assoc();
    
    if (!$comment) {
        http_response_code(404);
        echo jsonResponse(false, 'Comment not found');
        return;
    }
    
    // Check if user is owner (add admin check as needed)
    if ($comment['user_id'] != $user_id) {
        http_response_code(403);
        echo jsonResponse(false, 'You can only delete your own comments');
        return;
    }
    
    // Soft delete
    $deleteStmt = $conn->prepare("UPDATE gallery_comments SET is_deleted = 1 WHERE id = ?");
    $deleteStmt->bind_param("i", $comment_id);
    
    if ($deleteStmt->execute()) {
        echo jsonResponse(true, 'Comment deleted successfully');
    } else {
        http_response_code(500);
        echo jsonResponse(false, 'Failed to delete comment: ' . $deleteStmt->error);
    }
}

function handleUploadPhoto($conn) {
    // Set error handler to catch fatal errors
    set_error_handler(function($errno, $errstr, $errfile, $errline) {
        error_log("UPLOAD ERROR [$errno]: $errstr in $errfile on line $errline");
        return false;
    });
    
    // Log for debugging
    error_log('handleUploadPhoto called - POST data: ' . print_r($_POST, true));
    error_log('handleUploadPhoto called - FILES data: ' . print_r($_FILES, true));
    error_log('handleUploadPhoto called - REQUEST_METHOD: ' . $_SERVER['REQUEST_METHOD']);
    error_log('handleUploadPhoto called - CONTENT_TYPE: ' . ($_SERVER['CONTENT_TYPE'] ?? 'not set'));
    error_log('handleUploadPhoto called - SCRIPT_NAME: ' . ($_SERVER['SCRIPT_NAME'] ?? 'not set'));
    error_log('handleUploadPhoto called - conn exists: ' . (isset($conn) ? 'yes' : 'no'));
    
    $user_id = intval($_POST['user_id'] ?? $_REQUEST['user_id'] ?? 0);
    $fruit_tag = trim($_POST['fruit_tag'] ?? $_REQUEST['fruit_tag'] ?? '');
    $testimony = trim($_POST['testimony'] ?? $_REQUEST['testimony'] ?? ''); // Story/testimony behind the image
    $feeling_tags = trim($_POST['feeling_tags'] ?? $_REQUEST['feeling_tags'] ?? ''); // Comma-separated feeling tags
    $hashtags = trim($_POST['hashtags'] ?? $_REQUEST['hashtags'] ?? ''); // Comma-separated hashtags
    $allow_comments = isset($_POST['allow_comments']) ? (intval($_POST['allow_comments']) == 1 ? 1 : 0) : (isset($_REQUEST['allow_comments']) ? (intval($_REQUEST['allow_comments']) == 1 ? 1 : 0) : 1); // Default: allow comments
    
    error_log("handleUploadPhoto parsed: user_id=$user_id, fruit_tag='$fruit_tag', testimony length=" . strlen($testimony));
    
    // ===== CONTENT MODERATION FOR TESTIMONY =====
    if (!empty($testimony) && file_exists('../includes/ContentModerationService.php')) {
        require_once '../includes/ContentModerationService.php';
        
        $moderation_result = ContentModerationService::checkContent($testimony, $conn);
        
        switch ($moderation_result['action']) {
            case 'block':
                http_response_code(400);
                echo jsonResponse(false, 'Photo description violates community guidelines.');
                return;
                
            case 'quarantine':
                $testimony = $moderation_result['sanitized_content'];
                break;
                
            case 'warn':
                $testimony = $moderation_result['sanitized_content'];
                break;
                
            case 'allow':
            default:
                break;
        }
    }
    // ===== CONTENT MODERATION END =====
    
    if (!$user_id) {
        http_response_code(400);
        error_log('handleUploadPhoto: user_id is missing');
        echo jsonResponse(false, 'user_id is required');
        return;
    }
    
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
    if (!isset($_FILES['photo']) || $_FILES['photo']['error'] !== UPLOAD_ERR_OK) {
        http_response_code(400);
        echo jsonResponse(false, 'Photo file is required');
        return;
    }
    
    $target_dir = "../uploads/";
    if (!is_dir($target_dir)) {
        mkdir($target_dir, 0755, true);
    }
    
    $fileExtension = strtolower(pathinfo($_FILES['photo']['name'], PATHINFO_EXTENSION));
    $allowedTypes = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
    
    if (!in_array($fileExtension, $allowedTypes)) {
        http_response_code(400);
        echo jsonResponse(false, 'Invalid image format. Allowed: jpg, jpeg, png, gif, webp');
        return;
    }
    
    $maxFileSize = 10 * 1024 * 1024; // 10MB
    if ($_FILES['photo']['size'] > $maxFileSize) {
        http_response_code(400);
        echo jsonResponse(false, 'Image size must be less than 10MB');
        return;
    }
    
    $fileName = 'photo_' . time() . '_' . uniqid() . '.' . $fileExtension;
    $target_file = $target_dir . $fileName;
    
    if (move_uploaded_file($_FILES['photo']['tmp_name'], $target_file)) {
        $compressedPath = null;
        $file_path = "uploads/" . $fileName;
        $thumbnailUrl = null;
        $thumbnailPath = null;
        
        try {
            // Compress image
            $compressedPath = @compressImage($target_file, null, 85, 1920, 1080);
            if ($compressedPath) {
                $file_path = str_replace('../uploads/', 'uploads/', $compressedPath);
                // Delete original if compressed version created
                if ($compressedPath !== $target_file && file_exists($target_file)) {
                    @unlink($target_file);
                }
            }
        } catch (Exception $e) {
            error_log("❌ Error compressing image: " . $e->getMessage());
            // Continue with original file
        }
        
        try {
            // Generate thumbnail
            $thumbnailName = 'thumb_' . $fileName;
            $thumbnailPath = $target_dir . $thumbnailName;
            $thumbnailGenerated = @generateThumbnail($compressedPath ?: $target_file, $thumbnailPath, 300, 300);
            $thumbnailUrl = $thumbnailGenerated ? 'uploads/' . $thumbnailName : null;
        } catch (Exception $e) {
            error_log("❌ Error generating thumbnail: " . $e->getMessage());
            // Continue without thumbnail
            $thumbnailUrl = null;
        }
        
        // Check if media_items table exists
        $check_table = @$conn->query("SHOW TABLES LIKE 'media_items'");
        if (!$check_table || $check_table->num_rows === 0) {
            error_log("❌ media_items table does not exist");
            @unlink($target_file);
            if (file_exists($compressedPath ?? '')) {
                @unlink($compressedPath);
            }
            if (file_exists($thumbnailPath ?? '')) {
                @unlink($thumbnailPath);
            }
            http_response_code(500);
            echo jsonResponse(false, 'Database table media_items not found');
            return;
        }
        
        // Check if media_items table has new columns
        $check_thumbnail = @$conn->query("SHOW COLUMNS FROM media_items LIKE 'thumbnail_path'");
        $has_thumbnail_path = $check_thumbnail && $check_thumbnail->num_rows > 0;
        
        $check_columns = @$conn->query("SHOW COLUMNS FROM media_items LIKE 'feeling_tags'");
        $has_feeling_tags = $check_columns && $check_columns->num_rows > 0;
        
        $check_hashtags = @$conn->query("SHOW COLUMNS FROM media_items LIKE 'hashtags'");
        $has_hashtags = $check_hashtags && $check_hashtags->num_rows > 0;
        
        $check_allow_comments = @$conn->query("SHOW COLUMNS FROM media_items LIKE 'allow_comments'");
        $has_allow_comments = $check_allow_comments && $check_allow_comments->num_rows > 0;
        
        // Build INSERT statement dynamically based on which columns exist
        $columns = ['user_id', 'type', 'file_path'];
        $values = ['?', "'photo'", '?'];
        $params = [$user_id, $file_path];
        $types = 'is';
        
        // Add thumbnail_path if column exists
        if ($has_thumbnail_path) {
            $columns[] = 'thumbnail_path';
            $values[] = '?';
            $params[] = $thumbnailUrl ?? '';
            $types .= 's';
        }
        
        $columns[] = 'status';
        $values[] = "'Pending'";
        
        // Check if fruit_tag column exists
        $check_fruit_tag = @$conn->query("SHOW COLUMNS FROM media_items LIKE 'fruit_tag'");
        $has_fruit_tag = $check_fruit_tag && $check_fruit_tag->num_rows > 0;
        
        // Add fruit_tag if column exists (always include, even if empty)
        if ($has_fruit_tag) {
            $columns[] = 'fruit_tag';
            $values[] = '?';
            $params[] = $fruit_tag ?? '';
            $types .= 's';
        }
        
        // Add feeling_tags if column exists and value provided
        if ($has_feeling_tags && !empty($feeling_tags)) {
            $columns[] = 'feeling_tags';
            $values[] = '?';
            $params[] = $feeling_tags;
            $types .= 's';
        }
        
        // Add hashtags if column exists and value provided
        if ($has_hashtags && !empty($hashtags)) {
            $columns[] = 'hashtags';
            $values[] = '?';
            $params[] = $hashtags;
            $types .= 's';
        }
        
        // Add allow_comments if column exists
        if ($has_allow_comments) {
            $columns[] = 'allow_comments';
            $values[] = '?';
            $params[] = $allow_comments;
            $types .= 'i';
        }
        
        // Build and execute INSERT statement
        $columnsStr = implode(', ', $columns);
        $valuesStr = implode(', ', $values);
        $sql = "INSERT INTO media_items ($columnsStr) VALUES ($valuesStr)";
        
        error_log("📝 SQL: $sql");
        error_log("📝 Types: $types");
        error_log("📝 Params: " . print_r($params, true));
        error_log("📝 Params count: " . count($params));
        error_log("📝 Types length: " . strlen($types));
        
        try {
            $stmt = $conn->prepare($sql);
            if ($stmt) {
                if (!empty($params)) {
                    $stmt->bind_param($types, ...$params);
                }
            } else {
                error_log("❌ Prepare failed: " . $conn->error);
            }
        } catch (Exception $e) {
            error_log("❌ SQL Exception during prepare: " . $e->getMessage());
            $stmt = false;
        }
        
        if (!$stmt) {
            @unlink($target_file);
            if (file_exists($compressedPath ?? '')) {
                @unlink($compressedPath);
            }
            if (file_exists($thumbnailPath ?? '')) {
                @unlink($thumbnailPath);
            }
            error_log("❌ Failed to prepare statement: " . $conn->error);
            http_response_code(500);
            echo jsonResponse(false, 'Failed to prepare database statement: ' . $conn->error);
            return;
        }
        
        if ($stmt->execute()) {
            $media_id = $stmt->insert_id;
            
            // If testimony provided, add as comment (if allow_comments is true)
            if (!empty($testimony) && $allow_comments) {
                // Check if gallery_comments table exists, use it if available
                $check_gallery_comments = @$conn->query("SHOW TABLES LIKE 'gallery_comments'");
                $has_gallery_comments = $check_gallery_comments && $check_gallery_comments->num_rows > 0;
                
                if ($has_gallery_comments) {
                    $comment_stmt = $conn->prepare("INSERT INTO gallery_comments (photo_id, user_id, content) VALUES (?, ?, ?)");
                    $comment_stmt->bind_param("iis", $media_id, $user_id, $testimony);
                    $comment_stmt->execute();
                } else {
                    // Fallback to old comments table
                    $comment_stmt = $conn->prepare("INSERT INTO comments (post_type, post_id, user_id, content, status) VALUES ('gallery', ?, ?, ?, 'approved')");
                    $comment_stmt->bind_param("iss", $media_id, $user_id, $testimony);
                    $comment_stmt->execute();
                }
            }
            
            echo jsonResponse(true, 'Photo uploaded successfully. Waiting for admin approval.', [
                'id' => $media_id, 
                'file_path' => $file_path,
                'thumbnail_path' => $thumbnailUrl
            ]);
        } else {
            @unlink($target_file);
            if (file_exists($compressedPath ?? '')) {
                @unlink($compressedPath);
            }
            http_response_code(500);
            echo jsonResponse(false, 'Failed to save photo: ' . $stmt->error);
        }
    } else {
        http_response_code(500);
        echo jsonResponse(false, 'Failed to upload photo');
    }
}

function handleToggleLike($conn) {
    $user_id = intval($_POST['user_id'] ?? 0);
    $media_id = intval($_POST['media_id'] ?? 0);
    $action = $_POST['action'] ?? 'like';
    
    if (!$user_id || !$media_id) {
        http_response_code(400);
        echo jsonResponse(false, 'user_id and media_id are required');
        return;
    }
    
    // Check if media_likes table exists, if not create it
    $check_table = @$conn->query("SHOW TABLES LIKE 'media_likes'");
    if (!$check_table || $check_table->num_rows === 0) {
        // Create media_likes table
        $create_table = "CREATE TABLE IF NOT EXISTS media_likes (
            id INT AUTO_INCREMENT PRIMARY KEY,
            media_id INT NOT NULL,
            user_id INT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UNIQUE KEY unique_like (media_id, user_id),
            FOREIGN KEY (media_id) REFERENCES media_items(id) ON DELETE CASCADE,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        )";
        if (!$conn->query($create_table)) {
            error_log("Failed to create media_likes table: " . $conn->error);
        }
    }
    
    if ($action === 'like') {
        // Check if already liked
        $check_stmt = $conn->prepare("SELECT id FROM media_likes WHERE media_id = ? AND user_id = ?");
        $check_stmt->bind_param("ii", $media_id, $user_id);
        $check_stmt->execute();
        $result = $check_stmt->get_result();
        
        if ($result->num_rows === 0) {
            // Add like
            $stmt = $conn->prepare("INSERT INTO media_likes (media_id, user_id) VALUES (?, ?)");
            $stmt->bind_param("ii", $media_id, $user_id);
            if ($stmt->execute()) {
                // Get updated like count
                $count_stmt = $conn->prepare("SELECT COUNT(*) as count FROM media_likes WHERE media_id = ?");
                $count_stmt->bind_param("i", $media_id);
                $count_stmt->execute();
                $count_result = $count_stmt->get_result();
                $count = $count_result->fetch_assoc()['count'];
                
                echo jsonResponse(true, 'Photo liked', ['liked' => true, 'like_count' => $count]);
            } else {
                http_response_code(500);
                echo jsonResponse(false, 'Failed to like photo: ' . $stmt->error);
            }
        } else {
            echo jsonResponse(true, 'Already liked', ['liked' => true, 'like_count' => 0]);
        }
    } else {
        // Unlike
        $stmt = $conn->prepare("DELETE FROM media_likes WHERE media_id = ? AND user_id = ?");
        $stmt->bind_param("ii", $media_id, $user_id);
        if ($stmt->execute()) {
            // Get updated like count
            $count_stmt = $conn->prepare("SELECT COUNT(*) as count FROM media_likes WHERE media_id = ?");
            $count_stmt->bind_param("i", $media_id);
            $count_stmt->execute();
            $count_result = $count_stmt->get_result();
            $count = $count_result->fetch_assoc()['count'];
            
            echo jsonResponse(true, 'Photo unliked', ['liked' => false, 'like_count' => $count]);
        } else {
            http_response_code(500);
            echo jsonResponse(false, 'Failed to unlike photo: ' . $stmt->error);
        }
    }
}

// =====================================================
// Handle Edit Comment (POST: action=edit-comment)
// =====================================================
function handleEditComment($conn) {
    $user_id = intval($_POST['user_id'] ?? 0);
    $comment_id = intval($_POST['comment_id'] ?? 0);
    $content = trim($_POST['content'] ?? '');
    $photo_id = intval($_POST['photo_id'] ?? 0);
    
    error_log("📥 Edit Gallery Comment: user_id=$user_id, comment_id=$comment_id, photo_id=$photo_id");
    
    // Validation
    if (!$user_id || !$comment_id || empty($content)) {
        http_response_code(400);
        echo jsonResponse(false, 'user_id, comment_id, and content are required');
        return;
    }
    
    // Check if gallery_comments table exists
    $check_table = @$conn->query("SHOW TABLES LIKE 'gallery_comments'");
    $has_gallery_comments = $check_table && $check_table->num_rows > 0;
    
    if (!$has_gallery_comments) {
        http_response_code(404);
        echo jsonResponse(false, 'Gallery comments table not found');
        return;
    }
    
    // Verify user owns the comment
    $check_stmt = $conn->prepare("SELECT user_id, created_at, photo_id FROM gallery_comments WHERE id = ? AND is_deleted = 0");
    $check_stmt->bind_param("i", $comment_id);
    $check_stmt->execute();
    $check_result = $check_stmt->get_result();
    
    if ($check_result->num_rows === 0) {
        http_response_code(404);
        echo jsonResponse(false, 'Comment not found');
        return;
    }
    
    $comment_data = $check_result->fetch_assoc();
    
    // Check if user owns the comment
    if ($comment_data['user_id'] != $user_id) {
        http_response_code(403);
        echo jsonResponse(false, 'You can only edit your own comments');
        return;
    }
    
    $created_at = $comment_data['created_at'];
    
    // Calculate time difference (15-minute edit window)
    $created_at_dt = new DateTime($created_at);
    $created_at_dt = $created_at_dt->add(new DateInterval('PT4H')); // 4-hour fix like frontend
    
    $now_dt = new DateTime('now', new DateTimeZone('UTC'));
    $now_dt = $now_dt->add(new DateInterval('PT4H'));
    
    $timestamp1 = $created_at_dt->getTimestamp();
    $timestamp2 = $now_dt->getTimestamp();
    $minutes_diff = abs(($timestamp2 - $timestamp1) / 60);
    
    error_log("🕐 Edit window check: minutes_diff=$minutes_diff, limit=15");
    
    if ($minutes_diff > 15) {
        http_response_code(403);
        echo jsonResponse(false, 'Comments can only be edited within 15 minutes of posting');
        return;
    }
    
    // Check if edited_at column exists
    $check_column = $conn->query("SHOW COLUMNS FROM gallery_comments LIKE 'edited_at'");
    $has_edited_at = $check_column && $check_column->num_rows > 0;
    
    // Build update query
    if ($has_edited_at) {
        $update_stmt = $conn->prepare("UPDATE gallery_comments SET content = ?, edited_at = NOW(), is_edited = 1 WHERE id = ?");
        $update_stmt->bind_param("si", $content, $comment_id);
    } else {
        $update_stmt = $conn->prepare("UPDATE gallery_comments SET content = ? WHERE id = ?");
        $update_stmt->bind_param("si", $content, $comment_id);
    }
    
    if ($update_stmt->execute()) {
        error_log("✅ Gallery comment edited: ID=$comment_id, user_id=$user_id");
        echo jsonResponse(true, 'Comment edited successfully', [
            'id' => $comment_id,
            'content' => $content,
            'is_edited' => true
        ]);
    } else {
        error_log("❌ Failed to edit gallery comment: " . $update_stmt->error);
        http_response_code(500);
        echo jsonResponse(false, 'Failed to edit comment: ' . $update_stmt->error);
    }
}

$conn->close();

// =====================================================
// IMAGE UPLOAD HELPERS (defined here if not in separate file)
// =====================================================

if (!function_exists('compressImage')) {
    /**
     * Compress an image while maintaining aspect ratio
     */
    function compressImage($source, $destination = null, $quality = 85, $maxWidth = 1920, $maxHeight = 1080) {
        if ($destination === null) {
            $destination = $source;
        }
        
        $info = getimagesize($source);
        if ($info === false) {
            error_log("compressImage: Failed to get image info for $source");
            return null;
        }
        
        $width = $info[0];
        $height = $info[1];
        $mime = $info['mime'];
        
        // Calculate new dimensions
        $newWidth = $width;
        $newHeight = $height;
        
        if ($width > $maxWidth || $height > $maxHeight) {
            $ratio = min($maxWidth / $width, $maxHeight / $height);
            $newWidth = round($width * $ratio);
            $newHeight = round($height * $ratio);
        }
        
        // Create source image
        $srcImage = null;
        switch ($mime) {
            case 'image/jpeg':
                $srcImage = @imagecreatefromjpeg($source);
                break;
            case 'image/png':
                $srcImage = @imagecreatefrompng($source);
                break;
            case 'image/gif':
                $srcImage = @imagecreatefromgif($source);
                break;
            case 'image/webp':
                $srcImage = @imagecreatefromwebp($source);
                break;
            default:
                return null;
        }
        
        if (!$srcImage) {
            return null;
        }
        
        $dstImage = imagecreatetruecolor($newWidth, $newHeight);
        
        if ($mime === 'image/png') {
            imagealphablending($dstImage, false);
            imagesavealpha($dstImage, true);
            $transparent = imagecolorallocatealpha($dstImage, 255, 255, 255, 127);
            imagefilledrectangle($dstImage, 0, 0, $newWidth, $newHeight, $transparent);
        }
        
        imagecopyresampled($dstImage, $srcImage, 0, 0, 0, 0, $newWidth, $newHeight, $width, $height);
        
        $success = false;
        switch ($mime) {
            case 'image/jpeg':
                $success = imagejpeg($dstImage, $destination, $quality);
                break;
            case 'image/png':
                $success = imagepng($dstImage, $destination, round($quality / 10));
                break;
            case 'image/gif':
                $success = imagegif($dstImage, $destination);
                break;
            case 'image/webp':
                $success = imagewebp($dstImage, $destination, $quality);
                break;
        }
        
        imagedestroy($srcImage);
        imagedestroy($dstImage);
        
        return $success ? $destination : null;
    }
}

if (!function_exists('generateThumbnail')) {
    /**
     * Generate a thumbnail from an image
     */
    function generateThumbnail($source, $destination, $thumbWidth = 300, $thumbHeight = 300) {
        $info = getimagesize($source);
        if ($info === false) {
            return false;
        }
        
        $width = $info[0];
        $height = $info[1];
        $mime = $info['mime'];
        
        // Calculate crop dimensions
        $sourceRatio = $width / $height;
        $thumbRatio = $thumbWidth / $thumbHeight;
        
        if ($sourceRatio > $thumbRatio) {
            $newHeight = $height;
            $newWidth = round($height * $thumbRatio);
            $srcX = round(($width - $newWidth) / 2);
            $srcY = 0;
        } else {
            $newWidth = $width;
            $newHeight = round($width / $thumbRatio);
            $srcX = 0;
            $srcY = round(($height - $newHeight) / 2);
        }
        
        // Create source image
        $srcImage = null;
        switch ($mime) {
            case 'image/jpeg':
                $srcImage = @imagecreatefromjpeg($source);
                break;
            case 'image/png':
                $srcImage = @imagecreatefrompng($source);
                break;
            case 'image/gif':
                $srcImage = @imagecreatefromgif($source);
                break;
            case 'image/webp':
                $srcImage = @imagecreatefromwebp($source);
                break;
            default:
                return false;
        }
        
        if (!$srcImage) {
            return false;
        }
        
        $dstImage = imagecreatetruecolor($thumbWidth, $thumbHeight);
        
        if ($mime === 'image/png') {
            imagealphablending($dstImage, false);
            imagesavealpha($dstImage, true);
            $transparent = imagecolorallocatealpha($dstImage, 255, 255, 255, 127);
            imagefilledrectangle($dstImage, 0, 0, $thumbWidth, $thumbHeight, $transparent);
        }
        
        imagecopyresampled($dstImage, $srcImage, 0, 0, $srcX, $srcY, $thumbWidth, $thumbHeight, $newWidth, $newHeight);
        
        $success = false;
        switch ($mime) {
            case 'image/jpeg':
                $success = imagejpeg($dstImage, $destination, 85);
                break;
            case 'image/png':
                $success = imagepng($dstImage, $destination, 6);
                break;
            case 'image/gif':
                $success = imagegif($dstImage, $destination);
                break;
            case 'image/webp':
                $success = imagewebp($dstImage, $destination, 85);
                break;
        }
        
        imagedestroy($srcImage);
        imagedestroy($dstImage);
        
        return $success;
    }
}

?>

