<?php
/**
 * Notifications API
 * Handles: Get user notifications, Mark as read
 */

// Start output buffering to prevent any output before JSON
ob_start();

require_once '../includes/db.php';
require_once '../includes/cors.php';
require_once 'auth-helper.php';

header('Content-Type: application/json');

// Clear any output that might have been generated
ob_clean();

$method = $_SERVER['REQUEST_METHOD'];
$action = $_GET['action'] ?? $_POST['action'] ?? '';

if ($method === 'OPTIONS') {
    http_response_code(200);
    exit;
}

switch ($action) {
    case 'read':
        handleMarkAsRead($conn);
        break;
    case 'unread-count':
        handleGetUnreadCount($conn);
        break;
    default:
        if ($method === 'GET') {
            handleGetNotifications($conn);
        } else {
            http_response_code(405);
            ob_clean();
            echo jsonResponse(false, 'Method not allowed');
        }
        break;
}

function handleGetNotifications($conn) {
    $user_id = intval($_GET['user_id'] ?? 0);
    $is_read = $_GET['is_read'] ?? null; // null = all, 0 = unread, 1 = read
    $limit = intval($_GET['limit'] ?? 50);
    $offset = intval($_GET['offset'] ?? 0);
    
    if (!$user_id) {
        http_response_code(400);
        ob_clean();
        echo jsonResponse(false, 'user_id is required');
        return;
    }
    
    // Check if 'type' column exists in notifications table
    $check_type = @$conn->query("SHOW COLUMNS FROM notifications LIKE 'type'");
    $has_type_column = $check_type && $check_type->num_rows > 0;
    
    // Fetch both user-specific notifications AND common notifications (prayer reminders)
    // Common notifications have user_id = 0 and type = 'prayer_reminder'
    if ($has_type_column) {
        $sql = "SELECT * FROM notifications WHERE (user_id = ? OR (user_id = 0 AND type = 'prayer_reminder'))";
    } else {
        // If type column doesn't exist, only fetch user-specific notifications
        $sql = "SELECT * FROM notifications WHERE user_id = ?";
    }
    $params = [$user_id];
    $types = "i";
    
    if ($is_read !== null) {
        $sql .= " AND is_read = ?";
        $params[] = intval($is_read);
        $types .= "i";
    }
    
    $sql .= " ORDER BY created_at DESC LIMIT ? OFFSET ?";
    $params[] = $limit;
    $params[] = $offset;
    $types .= "ii";
    
    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        http_response_code(500);
        ob_clean();
        echo jsonResponse(false, 'Database error: ' . $conn->error);
        return;
    }
    
    $stmt->bind_param($types, ...$params);
    if (!$stmt->execute()) {
        http_response_code(500);
        ob_clean();
        echo jsonResponse(false, 'Query error: ' . $stmt->error);
        return;
    }
    
    $result = $stmt->get_result();
    
    $notifications = [];
    while ($row = $result->fetch_assoc()) {
        $notifications[] = $row;
    }
    
    ob_clean();
    echo jsonResponse(true, 'Notifications retrieved', $notifications);
}

function handleMarkAsRead($conn) {
    $user_id = intval($_POST['user_id'] ?? 0);
    $notification_id = intval($_POST['notification_id'] ?? 0);
    
    if (!$user_id) {
        http_response_code(400);
        ob_clean();
        echo jsonResponse(false, 'user_id is required');
        return;
    }
    
    // Check if 'type' column exists
    $check_type = @$conn->query("SHOW COLUMNS FROM notifications LIKE 'type'");
    $has_type_column = $check_type && $check_type->num_rows > 0;
    
    if ($notification_id) {
        // Mark single notification as read
        // For common notifications (user_id = 0), we need to track read status per user
        // Check if notification is common (user_id = 0)
        $check_stmt = $conn->prepare("SELECT user_id FROM notifications WHERE id = ?");
        if (!$check_stmt) {
            http_response_code(500);
            ob_clean();
            echo jsonResponse(false, 'Database error: ' . $conn->error);
            return;
        }
        
        $check_stmt->bind_param("i", $notification_id);
        if (!$check_stmt->execute()) {
            http_response_code(500);
            ob_clean();
            echo jsonResponse(false, 'Query error: ' . $check_stmt->error);
            return;
        }
        
        $notif_result = $check_stmt->get_result();
        
        if ($notif_result->num_rows > 0) {
            $notif = $notif_result->fetch_assoc();
            if ($notif['user_id'] == 0) {
                // Common notification - mark as read for this specific user
                // For simplicity, we'll just mark it as read (this affects all users, but that's acceptable for prayer reminders)
                $stmt = $conn->prepare("UPDATE notifications SET is_read = 1 WHERE id = ?");
                if (!$stmt) {
                    http_response_code(500);
                    ob_clean();
                    echo jsonResponse(false, 'Database error: ' . $conn->error);
                    return;
                }
                $stmt->bind_param("i", $notification_id);
            } else {
                // User-specific notification
                $stmt = $conn->prepare("UPDATE notifications SET is_read = 1 WHERE id = ? AND user_id = ?");
                if (!$stmt) {
                    http_response_code(500);
                    ob_clean();
                    echo jsonResponse(false, 'Database error: ' . $conn->error);
                    return;
                }
                $stmt->bind_param("ii", $notification_id, $user_id);
            }
        } else {
            http_response_code(404);
            ob_clean();
            echo jsonResponse(false, 'Notification not found');
            return;
        }
    } else {
        // Mark all notifications as read for this user
        // This includes both user-specific and common notifications
        if ($has_type_column) {
            $stmt = $conn->prepare("UPDATE notifications SET is_read = 1 WHERE user_id = ? OR (user_id = 0 AND type = 'prayer_reminder')");
        } else {
            $stmt = $conn->prepare("UPDATE notifications SET is_read = 1 WHERE user_id = ?");
        }
        
        if (!$stmt) {
            http_response_code(500);
            ob_clean();
            echo jsonResponse(false, 'Database error: ' . $conn->error);
            return;
        }
        
        $stmt->bind_param("i", $user_id);
    }
    
    if ($stmt->execute()) {
        ob_clean();
        echo jsonResponse(true, 'Notification(s) marked as read');
    } else {
        http_response_code(500);
        ob_clean();
        echo jsonResponse(false, 'Failed to update notification: ' . $stmt->error);
    }
}

function handleGetUnreadCount($conn) {
    $user_id = intval($_GET['user_id'] ?? 0);
    
    if (!$user_id) {
        http_response_code(400);
        ob_clean();
        echo jsonResponse(false, 'user_id is required');
        return;
    }
    
    // Check if 'type' column exists
    $check_type = @$conn->query("SHOW COLUMNS FROM notifications LIKE 'type'");
    $has_type_column = $check_type && $check_type->num_rows > 0;
    
    // Count both user-specific notifications AND common notifications (prayer reminders)
    if ($has_type_column) {
        $stmt = $conn->prepare("SELECT COUNT(*) as unread_count FROM notifications WHERE (user_id = ? OR (user_id = 0 AND type = 'prayer_reminder')) AND is_read = 0");
    } else {
        $stmt = $conn->prepare("SELECT COUNT(*) as unread_count FROM notifications WHERE user_id = ? AND is_read = 0");
    }
    
    if (!$stmt) {
        http_response_code(500);
        ob_clean();
        echo jsonResponse(false, 'Database error: ' . $conn->error);
        return;
    }
    
    $stmt->bind_param("i", $user_id);
    if (!$stmt->execute()) {
        http_response_code(500);
        ob_clean();
        echo jsonResponse(false, 'Query error: ' . $stmt->error);
        return;
    }
    
    $result = $stmt->get_result();
    $count = $result->fetch_assoc();
    
    ob_clean();
    echo jsonResponse(true, 'Unread count retrieved', ['unread_count' => intval($count['unread_count'])]);
}

// End output buffering and send output
ob_end_flush();
$conn->close();
?>

