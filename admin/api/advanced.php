<?php
/**
 * Advanced Features API
 * Handles: Report content, Block user, Follow/Unfollow, Share content, Save/Bookmark
 */

require_once '../includes/db.php';
require_once '../includes/cors.php';
require_once 'auth-helper.php';

header('Content-Type: application/json');

$method = $_SERVER['REQUEST_METHOD'];
$action = $_GET['action'] ?? $_POST['action'] ?? '';

if ($method === 'OPTIONS') {
    http_response_code(200);
    exit;
}

switch ($action) {
    case 'report':
        handleReportContent($conn);
        break;
    case 'block':
        handleBlockUser($conn);
        break;
    case 'unblock':
        handleUnblockUser($conn);
        break;
    case 'follow':
        handleFollowUser($conn);
        break;
    case 'unfollow':
        handleUnfollowUser($conn);
        break;
    case 'share':
        handleShareContent($conn);
        break;
    case 'save':
        handleSaveContent($conn);
        break;
    case 'unsave':
        handleUnsaveContent($conn);
        break;
    case 'saved':
        handleGetSavedContent($conn);
        break;
    default:
        http_response_code(400);
        echo jsonResponse(false, 'Invalid action');
        break;
}

function handleReportContent($conn) {
    $user_id = intval($_POST['user_id'] ?? 0);
    $content_type = trim($_POST['content_type'] ?? ''); // blog, prayer, video, photo, story
    $content_id = intval($_POST['content_id'] ?? 0);
    $reason = trim($_POST['reason'] ?? '');
    $description = trim($_POST['description'] ?? '');
    
    if (!$user_id || empty($content_type) || !$content_id) {
        http_response_code(400);
        echo jsonResponse(false, 'user_id, content_type, and content_id are required');
        return;
    }
    
    // Check if already reported
    $check_stmt = $conn->prepare("SELECT id FROM content_reports WHERE reporter_user_id = ? AND content_type = ? AND content_id = ?");
    $check_stmt->bind_param("isi", $user_id, $content_type, $content_id);
    $check_stmt->execute();
    
    if ($check_stmt->get_result()->num_rows > 0) {
        http_response_code(400);
        echo jsonResponse(false, 'Content already reported');
        return;
    }
    
    // Insert report
    $status = 'Pending';
    $stmt = $conn->prepare("
        INSERT INTO content_reports (reporter_user_id, content_type, content_id, reason, description, status, created_at) 
        VALUES (?, ?, ?, ?, ?, ?, NOW())
    ");
    $stmt->bind_param("isisss", $user_id, $content_type, $content_id, $reason, $description, $status);
    
    if ($stmt->execute()) {
        echo jsonResponse(true, 'Content reported successfully. Admin will review it.');
    } else {
        http_response_code(500);
        echo jsonResponse(false, 'Failed to report content: ' . $stmt->error);
    }
}

function handleBlockUser($conn) {
    $user_id = intval($_POST['user_id'] ?? 0);
    $blocked_user_id = intval($_POST['blocked_user_id'] ?? 0);
    
    if (!$user_id || !$blocked_user_id || $user_id === $blocked_user_id) {
        http_response_code(400);
        echo jsonResponse(false, 'Invalid user IDs');
        return;
    }
    
    // Check if already blocked
    $check_stmt = $conn->prepare("SELECT id FROM user_blocks WHERE user_id = ? AND blocked_user_id = ?");
    $check_stmt->bind_param("ii", $user_id, $blocked_user_id);
    $check_stmt->execute();
    
    if ($check_stmt->get_result()->num_rows > 0) {
        http_response_code(400);
        echo jsonResponse(false, 'User already blocked');
        return;
    }
    
    // Insert block
    $stmt = $conn->prepare("INSERT INTO user_blocks (user_id, blocked_user_id, created_at) VALUES (?, ?, NOW())");
    $stmt->bind_param("ii", $user_id, $blocked_user_id);
    
    if ($stmt->execute()) {
        echo jsonResponse(true, 'User blocked successfully');
    } else {
        http_response_code(500);
        echo jsonResponse(false, 'Failed to block user');
    }
}

function handleUnblockUser($conn) {
    $user_id = intval($_POST['user_id'] ?? 0);
    $blocked_user_id = intval($_POST['blocked_user_id'] ?? 0);
    
    if (!$user_id || !$blocked_user_id) {
        http_response_code(400);
        echo jsonResponse(false, 'user_id and blocked_user_id are required');
        return;
    }
    
    $stmt = $conn->prepare("DELETE FROM user_blocks WHERE user_id = ? AND blocked_user_id = ?");
    $stmt->bind_param("ii", $user_id, $blocked_user_id);
    
    if ($stmt->execute() && $stmt->affected_rows > 0) {
        echo jsonResponse(true, 'User unblocked successfully');
    } else {
        http_response_code(404);
        echo jsonResponse(false, 'User not found in blocked list');
    }
}

function handleFollowUser($conn) {
    $user_id = intval($_POST['user_id'] ?? 0);
    $follow_user_id = intval($_POST['follow_user_id'] ?? 0);
    
    if (!$user_id || !$follow_user_id || $user_id === $follow_user_id) {
        http_response_code(400);
        echo jsonResponse(false, 'Invalid user IDs');
        return;
    }
    
    // Check if already following
    $check_stmt = $conn->prepare("SELECT id FROM user_follows WHERE user_id = ? AND follow_user_id = ?");
    $check_stmt->bind_param("ii", $user_id, $follow_user_id);
    $check_stmt->execute();
    
    if ($check_stmt->get_result()->num_rows > 0) {
        http_response_code(400);
        echo jsonResponse(false, 'Already following this user');
        return;
    }
    
    // Check for block relationship before allowing follow
    $check_blocks_table = $conn->query("SHOW TABLES LIKE 'user_blocks'");
    if ($check_blocks_table && $check_blocks_table->num_rows > 0) {
        $block_check = $conn->prepare("SELECT id FROM user_blocks WHERE (user_id = ? AND blocked_user_id = ?) OR (user_id = ? AND blocked_user_id = ?)");
        $block_check->bind_param("iiii", $user_id, $follow_user_id, $follow_user_id, $user_id);
        $block_check->execute();
        if ($block_check->get_result()->num_rows > 0) {
            http_response_code(403);
            echo jsonResponse(false, 'Cannot follow this user due to blocking settings');
            return;
        }
    }
    
    // Insert follow
    $stmt = $conn->prepare("INSERT INTO user_follows (user_id, follow_user_id, created_at) VALUES (?, ?, NOW())");
    $stmt->bind_param("ii", $user_id, $follow_user_id);
    
    if ($stmt->execute()) {
        // Create notification for followed user
        require_once '../includes/notification_service.php';
        $followed_user_stmt = $conn->prepare("SELECT name FROM users WHERE id = ?");
        $followed_user_stmt->bind_param("i", $follow_user_id);
        $followed_user_stmt->execute();
        $followed_user = $followed_user_stmt->get_result()->fetch_assoc();
        
        if ($followed_user) {
            $follower_stmt = $conn->prepare("SELECT name FROM users WHERE id = ?");
            $follower_stmt->bind_param("i", $user_id);
            $follower_stmt->execute();
            $follower = $follower_stmt->get_result()->fetch_assoc();
            
            if ($follower) {
                createNotification($follow_user_id, 'user_followed', 'New Follower', $follower['name'] . ' started following you', '');
            }
        }
        
        echo jsonResponse(true, 'User followed successfully');
    } else {
        http_response_code(500);
        echo jsonResponse(false, 'Failed to follow user');
    }
}

function handleUnfollowUser($conn) {
    $user_id = intval($_POST['user_id'] ?? 0);
    $follow_user_id = intval($_POST['follow_user_id'] ?? 0);
    
    if (!$user_id || !$follow_user_id) {
        http_response_code(400);
        echo jsonResponse(false, 'user_id and follow_user_id are required');
        return;
    }
    
    $stmt = $conn->prepare("DELETE FROM user_follows WHERE user_id = ? AND follow_user_id = ?");
    $stmt->bind_param("ii", $user_id, $follow_user_id);
    
    if ($stmt->execute() && $stmt->affected_rows > 0) {
        echo jsonResponse(true, 'User unfollowed successfully');
    } else {
        http_response_code(404);
        echo jsonResponse(false, 'Not following this user');
    }
}

function handleShareContent($conn) {
    $user_id = intval($_POST['user_id'] ?? 0);
    $content_type = trim($_POST['content_type'] ?? '');
    $content_id = intval($_POST['content_id'] ?? 0);
    $platform = trim($_POST['platform'] ?? ''); // facebook, twitter, whatsapp, etc.
    
    if (!$user_id || empty($content_type) || !$content_id) {
        http_response_code(400);
        echo jsonResponse(false, 'user_id, content_type, and content_id are required');
        return;
    }
    
    // Track share
    $stmt = $conn->prepare("
        INSERT INTO content_shares (user_id, content_type, content_id, platform, created_at) 
        VALUES (?, ?, ?, ?, NOW())
    ");
    $stmt->bind_param("isis", $user_id, $content_type, $content_id, $platform);
    
    if ($stmt->execute()) {
        // Generate shareable link
        $base_url = 'http://admin.fosmessenger.com';
        $share_link = "{$base_url}/share/{$content_type}/{$content_id}";
        
        echo jsonResponse(true, 'Content shared', ['share_link' => $share_link]);
    } else {
        http_response_code(500);
        echo jsonResponse(false, 'Failed to track share');
    }
}

function handleSaveContent($conn) {
    $user_id = intval($_POST['user_id'] ?? 0);
    $content_type = trim($_POST['content_type'] ?? '');
    $content_id = intval($_POST['content_id'] ?? 0);
    
    if (!$user_id || empty($content_type) || !$content_id) {
        http_response_code(400);
        echo jsonResponse(false, 'user_id, content_type, and content_id are required');
        return;
    }
    
    // Check if already saved
    $check_stmt = $conn->prepare("SELECT id FROM saved_content WHERE user_id = ? AND content_type = ? AND content_id = ?");
    $check_stmt->bind_param("isi", $user_id, $content_type, $content_id);
    $check_stmt->execute();
    
    if ($check_stmt->get_result()->num_rows > 0) {
        http_response_code(400);
        echo jsonResponse(false, 'Content already saved');
        return;
    }
    
    // Insert save
    $stmt = $conn->prepare("INSERT INTO saved_content (user_id, content_type, content_id, created_at) VALUES (?, ?, ?, NOW())");
    $stmt->bind_param("isi", $user_id, $content_type, $content_id);
    
    if ($stmt->execute()) {
        echo jsonResponse(true, 'Content saved successfully');
    } else {
        http_response_code(500);
        echo jsonResponse(false, 'Failed to save content');
    }
}

function handleUnsaveContent($conn) {
    $user_id = intval($_POST['user_id'] ?? 0);
    $content_type = trim($_POST['content_type'] ?? '');
    $content_id = intval($_POST['content_id'] ?? 0);
    
    if (!$user_id || empty($content_type) || !$content_id) {
        http_response_code(400);
        echo jsonResponse(false, 'user_id, content_type, and content_id are required');
        return;
    }
    
    $stmt = $conn->prepare("DELETE FROM saved_content WHERE user_id = ? AND content_type = ? AND content_id = ?");
    $stmt->bind_param("isi", $user_id, $content_type, $content_id);
    
    if ($stmt->execute() && $stmt->affected_rows > 0) {
        echo jsonResponse(true, 'Content unsaved successfully');
    } else {
        http_response_code(404);
        echo jsonResponse(false, 'Content not found in saved list');
    }
}

function handleGetSavedContent($conn) {
    $user_id = intval($_GET['user_id'] ?? 0);
    $content_type = trim($_GET['content_type'] ?? 'all');
    $limit = intval($_GET['limit'] ?? 20);
    $offset = intval($_GET['offset'] ?? 0);
    
    if (!$user_id) {
        http_response_code(400);
        echo jsonResponse(false, 'user_id is required');
        return;
    }
    
    $sql = "SELECT * FROM saved_content WHERE user_id = ?";
    $params = [$user_id];
    $types = "i";
    
    if ($content_type !== 'all') {
        $sql .= " AND content_type = ?";
        $params[] = $content_type;
        $types .= "s";
    }
    
    $sql .= " ORDER BY created_at DESC LIMIT ? OFFSET ?";
    $params[] = $limit;
    $params[] = $offset;
    $types .= "ii";
    
    $stmt = $conn->prepare($sql);
    $stmt->bind_param($types, ...$params);
    $stmt->execute();
    $result = $stmt->get_result();
    
    $saved = [];
    while ($row = $result->fetch_assoc()) {
        $saved[] = $row;
    }
    
    echo jsonResponse(true, 'Saved content retrieved', $saved);
}

$conn->close();
?>

