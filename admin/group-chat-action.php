<?php
include './includes/db.php';

header('Content-Type: application/json');

// Check admin authentication
session_start();
if (!isset($_SESSION['admin_id'])) {
    echo json_encode(['success' => false, 'message' => 'Unauthorized access']);
    exit;
}

$admin_id = $_SESSION['admin_id'];
$action = $_POST['action'] ?? '';

// Verify admin exists
$admin_check = $conn->prepare("SELECT name FROM admin_users WHERE id = ?");
$admin_check->bind_param("i", $admin_id);
$admin_check->execute();
$admin_result = $admin_check->get_result();

if ($admin_result->num_rows === 0) {
    echo json_encode(['success' => false, 'message' => 'Admin not found']);
    exit;
}

$admin = $admin_result->fetch_assoc();

switch ($action) {
    case 'block_message':
        blockMessage();
        break;
    case 'unblock_message':
        unblockMessage();
        break;
    case 'delete_message':
        deleteMessage();
        break;
    default:
        echo json_encode(['success' => false, 'message' => 'Invalid action requested']);
}

function blockMessage() {
    global $conn, $admin_id;
    
    $message_id = intval($_POST['message_id']);
    $block_reason = trim($_POST['block_reason']);
    
    if (empty($block_reason)) {
        echo json_encode(['success' => false, 'message' => 'Block reason is required']);
        return;
    }
    
    // Check if message exists and get details
    $check_stmt = $conn->prepare("SELECT group_id, user_id FROM group_chat_messages WHERE id = ?");
    $check_stmt->bind_param("i", $message_id);
    $check_stmt->execute();
    $check_result = $check_stmt->get_result();
    
    if ($check_result->num_rows === 0) {
        echo json_encode(['success' => false, 'message' => 'Message not found']);
        return;
    }
    
    $stmt = $conn->prepare("UPDATE group_chat_messages SET status = 'blocked', blocked_by = ?, block_reason = ?, blocked_at = NOW() WHERE id = ?");
    $stmt->bind_param("isi", $admin_id, $block_reason, $message_id);
    
    if ($stmt->execute()) {
        echo json_encode(['success' => true, 'message' => 'Message has been blocked successfully']);
    } else {
        echo json_encode(['success' => false, 'message' => 'Database error: Failed to block message']);
    }
}

function unblockMessage() {
    global $conn;
    
    $message_id = intval($_POST['message_id']);
    
    $stmt = $conn->prepare("UPDATE group_chat_messages SET status = 'active', blocked_by = NULL, block_reason = NULL, blocked_at = NULL WHERE id = ?");
    $stmt->bind_param("i", $message_id);
    
    if ($stmt->execute()) {
        echo json_encode(['success' => true, 'message' => 'Message has been unblocked successfully']);
    } else {
        echo json_encode(['success' => false, 'message' => 'Database error: Failed to unblock message']);
    }
}

function deleteMessage() {
    global $conn;
    
    $message_id = intval($_POST['message_id']);
    
    $stmt = $conn->prepare("UPDATE group_chat_messages SET status = 'deleted' WHERE id = ?");
    $stmt->bind_param("i", $message_id);
    
    if ($stmt->execute()) {
        echo json_encode(['success' => true, 'message' => 'Message has been deleted successfully']);
    } else {
        echo json_encode(['success' => false, 'message' => 'Database error: Failed to delete message']);
    }
}
?>