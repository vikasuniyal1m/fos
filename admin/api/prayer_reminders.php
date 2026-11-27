<?php
/**
 * Prayer Reminders API
 * Handles: Set prayer reminder times, Get user reminders, Send reminders to all users
 */

require_once '../includes/db.php';
require_once '../includes/cors.php';
require_once '../includes/notification_service.php';
require_once 'auth-helper.php';

header('Content-Type: application/json');

$method = $_SERVER['REQUEST_METHOD'];
$action = $_GET['action'] ?? $_POST['action'] ?? '';

if ($method === 'OPTIONS') {
    http_response_code(200);
    exit;
}

switch ($action) {
    case 'set':
        handleSetReminder($conn);
        break;
    case 'get':
        handleGetReminder($conn);
        break;
    case 'send':
        handleSendReminders($conn);
        break;
    default:
        http_response_code(400);
        echo jsonResponse(false, 'Invalid action');
        break;
}

/**
 * Set Prayer Reminder Time for User
 */
function handleSetReminder($conn) {
    $user_id = intval($_POST['user_id'] ?? 0);
    $reminder_times = $_POST['reminder_times'] ?? ''; // JSON array of times like ["06:00", "12:00", "18:00"]
    $enabled = intval($_POST['enabled'] ?? 1);
    
    if (!$user_id) {
        http_response_code(400);
        echo jsonResponse(false, 'user_id is required');
        return;
    }
    
    // Verify user exists
    $user_stmt = $conn->prepare("SELECT id FROM users WHERE id = ?");
    $user_stmt->bind_param("i", $user_id);
    $user_stmt->execute();
    if ($user_stmt->get_result()->num_rows === 0) {
        http_response_code(404);
        echo jsonResponse(false, 'User not found');
        return;
    }
    
    // Check if prayer_reminder_times column exists, if not add it
    $check_column = @$conn->query("SHOW COLUMNS FROM users LIKE 'prayer_reminder_times'");
    if (!$check_column || $check_column->num_rows === 0) {
        $conn->query("ALTER TABLE users ADD COLUMN prayer_reminder_times TEXT NULL AFTER fruit_category");
    }
    
    // Check if prayer_reminders_enabled column exists, if not add it
    $check_enabled = @$conn->query("SHOW COLUMNS FROM users LIKE 'prayer_reminders_enabled'");
    if (!$check_enabled || $check_enabled->num_rows === 0) {
        $conn->query("ALTER TABLE users ADD COLUMN prayer_reminders_enabled TINYINT DEFAULT 1 AFTER prayer_reminder_times");
    }
    
    // Validate reminder times format
    if (!empty($reminder_times)) {
        $times_array = json_decode($reminder_times, true);
        if (!is_array($times_array)) {
            http_response_code(400);
            echo jsonResponse(false, 'Invalid reminder_times format. Expected JSON array.');
            return;
        }
        
        // Validate time format (HH:MM)
        foreach ($times_array as $time) {
            if (!preg_match('/^([01]?[0-9]|2[0-3]):[0-5][0-9]$/', $time)) {
                http_response_code(400);
                echo jsonResponse(false, "Invalid time format: $time. Use HH:MM format (e.g., 06:00, 12:30)");
                return;
            }
        }
        
        // Sort times
        sort($times_array);
        $reminder_times = json_encode($times_array);
    } else {
        $reminder_times = null;
    }
    
    // Update user reminder settings
    $stmt = $conn->prepare("UPDATE users SET prayer_reminder_times = ?, prayer_reminders_enabled = ? WHERE id = ?");
    $stmt->bind_param("sii", $reminder_times, $enabled, $user_id);
    
    if ($stmt->execute()) {
        echo jsonResponse(true, 'Prayer reminder settings updated successfully', [
            'reminder_times' => $reminder_times ? json_decode($reminder_times, true) : [],
            'enabled' => $enabled
        ]);
    } else {
        http_response_code(500);
        echo jsonResponse(false, 'Failed to update reminder settings: ' . $stmt->error);
    }
}

/**
 * Get Prayer Reminder Time for User
 */
function handleGetReminder($conn) {
    $user_id = intval($_GET['user_id'] ?? 0);
    
    if (!$user_id) {
        http_response_code(400);
        echo jsonResponse(false, 'user_id is required');
        return;
    }
    
    // Check if columns exist, if not return defaults
    $check_column = @$conn->query("SHOW COLUMNS FROM users LIKE 'prayer_reminder_times'");
    if (!$check_column || $check_column->num_rows === 0) {
        echo jsonResponse(true, 'Reminder settings retrieved', [
            'reminder_times' => [],
            'enabled' => 1
        ]);
        return;
    }
    
    $stmt = $conn->prepare("SELECT prayer_reminder_times, prayer_reminders_enabled FROM users WHERE id = ?");
    $stmt->bind_param("i", $user_id);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows === 0) {
        http_response_code(404);
        echo jsonResponse(false, 'User not found');
        return;
    }
    
    $user = $result->fetch_assoc();
    $reminder_times = $user['prayer_reminder_times'];
    $enabled = intval($user['prayer_reminders_enabled'] ?? 1);
    
    if ($reminder_times) {
        $times_array = json_decode($reminder_times, true);
        if (!is_array($times_array)) {
            $times_array = [];
        }
    } else {
        $times_array = [];
    }
    
    echo jsonResponse(true, 'Reminder settings retrieved', [
        'reminder_times' => $times_array,
        'enabled' => $enabled
    ]);
}

/**
 * Send Prayer Reminders to All Users (Called by Cron Job)
 * This function sends reminders to all users who have reminders enabled
 */
function handleSendReminders($conn) {
    // This should be called by cron job, but can also be called manually
    // Get current time
    $current_time = date('H:i'); // Format: HH:MM
    
    // Check if columns exist
    $check_column = @$conn->query("SHOW COLUMNS FROM users LIKE 'prayer_reminder_times'");
    if (!$check_column || $check_column->num_rows === 0) {
        echo jsonResponse(false, 'Prayer reminders feature not set up');
        return;
    }
    
    // Get all users with reminders enabled
    $stmt = $conn->prepare("
        SELECT id, name, email, prayer_reminder_times, prayer_reminders_enabled 
        FROM users 
        WHERE prayer_reminders_enabled = 1 
        AND prayer_reminder_times IS NOT NULL 
        AND prayer_reminder_times != ''
        AND status = 'Active'
    ");
    $stmt->execute();
    $result = $stmt->get_result();
    
    $reminders_sent = 0;
    $users_notified = [];
    $today = date('Y-m-d');
    
    // Collect all unique reminder times from all users
    $all_reminder_times = [];
    while ($user = $result->fetch_assoc()) {
        $reminder_times = json_decode($user['prayer_reminder_times'], true);
        
        if (!is_array($reminder_times)) {
            continue;
        }
        
        // Add all reminder times to the collection
        foreach ($reminder_times as $reminder_time) {
            if (!in_array($reminder_time, $all_reminder_times)) {
                $all_reminder_times[] = $reminder_time;
            }
        }
    }
    
    // Check each unique reminder time
    foreach ($all_reminder_times as $reminder_time) {
        // Allow 1 minute window (e.g., 06:00-06:01)
        $time_parts = explode(':', $reminder_time);
        $reminder_hour = intval($time_parts[0]);
        $reminder_minute = intval($time_parts[1]);
        
        $current_parts = explode(':', $current_time);
        $current_hour = intval($current_parts[0]);
        $current_minute = intval($current_parts[1]);
        
        // Check if it's the reminder time (within 1 minute window)
        if ($current_hour == $reminder_hour && abs($current_minute - $reminder_minute) <= 1) {
            // Check if we already sent common reminder today for this time
            $check_common_stmt = $conn->prepare("
                SELECT id FROM notifications 
                WHERE user_id = 0 
                AND type = 'prayer_reminder' 
                AND DATE(created_at) = ? 
                AND data LIKE ?
            ");
            $time_pattern = '%"' . $reminder_time . '"%';
            $check_common_stmt->bind_param("ss", $today, $time_pattern);
            $check_common_stmt->execute();
            
            if ($check_common_stmt->get_result()->num_rows === 0) {
                // Create ONE COMMON notification (user_id = 0) for this prayer reminder time
                // This will be visible to ALL users
                createNotification(
                    0, // user_id = 0 means common notification for all users
                    'prayer_reminder',
                    '⏰ Prayer Time Reminder',
                    "It's time for prayer! ($reminder_time) Take a moment to connect with God.",
                    '',
                    ['reminder_time' => $reminder_time]
                );
                
                $reminders_sent++;
                $users_notified[] = [
                    'user_id' => 0, // Common notification
                    'name' => 'All Users',
                    'time' => $reminder_time
                ];
            }
        }
    }
    
    echo jsonResponse(true, "Prayer reminders sent", [
        'reminders_sent' => $reminders_sent,
        'users_notified' => $users_notified,
        'current_time' => $current_time
    ]);
}

$conn->close();
?>

