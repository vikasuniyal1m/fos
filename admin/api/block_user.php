<?php
/**
 * Block User API
 * Handles user blocking and crowd-sourced moderation
 */

require_once '../includes/db.php';
require_once '../includes/cors.php';
require_once '../includes/ContentModerationService.php';
require_once 'auth-helper.php';

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'OPTIONS') {
    http_response_code(200);
    exit;
}

if ($method === 'POST') {
    $action = $_POST['action'] ?? 'block';
    
    if ($action === 'block') {
        handleBlockUser($conn);
    } elseif ($action === 'unblock') {
        handleUnblockUser($conn);
    } elseif ($action === 'list') {
        handleListBlockedUsers($conn);
    } else {
        http_response_code(400);
        echo jsonResponse(false, 'Invalid action');
    }
} elseif ($method === 'GET') {
    handleListBlockedUsers($conn);
} else {
    http_response_code(405);
    echo jsonResponse(false, 'Method not allowed');
}

function handleBlockUser($conn) {
    $user_id = intval($_POST['user_id'] ?? 0);
    $blocked_user_id = intval($_POST['blocked_user_id'] ?? 0);
    $reason = trim($_POST['reason'] ?? 'Other');
    
    if (!$user_id || !$blocked_user_id) {
        http_response_code(400);
        echo jsonResponse(false, 'Missing user_id or blocked_user_id');
        return;
    }
    
    if ($user_id === $blocked_user_id) {
        http_response_code(400);
        echo jsonResponse(false, 'You cannot block yourself');
        return;
    }
    
    // Check if user_blocks table exists
    $check_table = $conn->query("SHOW TABLES LIKE 'user_blocks'");
    if ($check_table->num_rows === 0) {
        $create_table = "CREATE TABLE user_blocks (
            id INT AUTO_INCREMENT PRIMARY KEY,
            user_id INT NOT NULL,
            blocked_user_id INT NOT NULL,
            reason VARCHAR(100) NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UNIQUE KEY unique_block (user_id, blocked_user_id),
            INDEX idx_blocker (user_id),
            INDEX idx_blocked (blocked_user_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci";
        $conn->query($create_table);
    }
    
    // Check if already blocked
    $check_block = $conn->prepare("SELECT id FROM user_blocks WHERE user_id = ? AND blocked_user_id = ?");
    $check_block->bind_param("ii", $user_id, $blocked_user_id);
    $check_block->execute();
    if ($check_block->get_result()->num_rows > 0) {
        http_response_code(400);
        echo jsonResponse(false, 'User is already blocked');
        return;
    }
    
    
    // Check if reason column exists in user_blocks table
    $reason_col_check = $conn->query("SHOW COLUMNS FROM user_blocks LIKE 'reason'");
    $has_reason_column = ($reason_col_check && $reason_col_check->num_rows > 0);
    
    // Insert block (with or without reason depending on table structure)
    if ($has_reason_column) {
        $stmt = $conn->prepare("INSERT INTO user_blocks (user_id, blocked_user_id, reason) VALUES (?, ?, ?)");
        $stmt->bind_param("iis", $user_id, $blocked_user_id, $reason);
    } else {
        $stmt = $conn->prepare("INSERT INTO user_blocks (user_id, blocked_user_id) VALUES (?, ?)");
        $stmt->bind_param("ii", $user_id, $blocked_user_id);
    }
    
    if ($stmt->execute()) {
        // CROWD SOURCED MODERATION
        // Increment flag count on recent content (last 24 hours) from this user
        // This effectively "flags" their content if enough people block them
        
        $tables = [
            'prayer_requests', 'comments', 'blog_comments', 'gallery_comments',
            'group_posts', 'group_chat_messages', 'media_items'
        ];
        
        foreach ($tables as $table) {
            // Check if table has flag_count column
            $col_check = $conn->query("SHOW COLUMNS FROM {$table} LIKE 'flag_count'");
            if ($col_check->num_rows > 0) {
                $user_col = ($table === 'media_items') ? 'user_id' : 'user_id'; // Default to user_id
                
                // Verify user column exists before updating to prevent 500 error
                $user_col_check = $conn->query("SHOW COLUMNS FROM {$table} LIKE '{$user_col}'");
                if ($user_col_check->num_rows > 0) {
                    // Update flag count for recent items
                    $flag_sql = "UPDATE {$table} 
                                 SET flag_count = flag_count + 1 
                                 WHERE {$user_col} = ? 
                                 AND created_at > DATE_SUB(NOW(), INTERVAL 24 HOUR)";
                    
                    $flag_stmt = $conn->prepare($flag_sql);
                    $flag_stmt->bind_param("i", $blocked_user_id);
                    $flag_stmt->execute();
                }
            }
        }
        
        // NOTIFY DEVELOPER
        // Insert a report into content_reports to notify admin/developer of the block and potential abuse
        $report_content_type = 'user';
        $report_description = "User was blocked. Reason: $reason";
        $report_stmt = $conn->prepare("INSERT INTO content_reports (reporter_user_id, content_type, content_id, reason, description) VALUES (?, ?, ?, ?, ?)");
        $report_stmt->bind_param("isiss", $user_id, $report_content_type, $blocked_user_id, $reason, $report_description);
        $report_stmt->execute();

        echo jsonResponse(true, 'User blocked successfully. The community moderation team has been notified.');
    } else {
        http_response_code(500);
        echo jsonResponse(false, 'Failed to block user');
    }
}

function handleUnblockUser($conn) {
    if ($_SERVER['REQUEST_METHOD'] === 'GET') {
        $user_id = intval($_GET['user_id'] ?? 0);
        $blocked_user_id = intval($_GET['blocked_user_id'] ?? 0);
    } else {
        $user_id = intval($_POST['user_id'] ?? 0);
        $blocked_user_id = intval($_POST['blocked_user_id'] ?? 0);
    }
    
    if (!$user_id || !$blocked_user_id) {
        http_response_code(400);
        echo jsonResponse(false, 'Missing user_id or blocked_user_id');
        return;
    }
    
    $stmt = $conn->prepare("DELETE FROM user_blocks WHERE user_id = ? AND blocked_user_id = ?");
    $stmt->bind_param("ii", $user_id, $blocked_user_id);
    
    if ($stmt->execute()) {
        echo jsonResponse(true, 'User unblocked successfully');
    } else {
        http_response_code(500);
        echo jsonResponse(false, 'Failed to unblock user');
    }
}

function handleListBlockedUsers($conn) {
    $user_id = intval($_GET['user_id'] ?? $_POST['user_id'] ?? 0);
    
    if (!$user_id) {
        http_response_code(400);
        echo jsonResponse(false, 'user_id is required');
        return;
    }
    
    // Check if user_blocks table exists first
    $check_table = $conn->query("SHOW TABLES LIKE 'user_blocks'");
    if ($check_table->num_rows === 0) {
        echo jsonResponse(true, 'No blocked users', []);
        return;
    }
    
    $sql = "SELECT ub.id, ub.blocked_user_id, ub.created_at, u.name, u.profile_photo 
            FROM user_blocks ub
            JOIN users u ON ub.blocked_user_id = u.id
            WHERE ub.user_id = ?";
            
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("i", $user_id);
    $stmt->execute();
    $result = $stmt->get_result();
    
    $blocked_users = [];
    while ($row = $result->fetch_assoc()) {
        $blocked_users[] = $row;
    }
    
    echo jsonResponse(true, 'Blocked users retrieved', $blocked_users);
}
?>
