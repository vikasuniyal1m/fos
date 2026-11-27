<?php
/**
 * Prayer Reminders Cron Job
 * Run this script every minute via cron job
 * 
 * Cron Setup (Linux):
 * Add to crontab: * * * * * /usr/bin/php /path/to/fruitofthespirit/cron/send_prayer_reminders.php
 * 
 * Or use web-based cron (call via URL):
 * https://your-domain.com/fruitofthespirit/cron/send_prayer_reminders.php
 */

// Set execution time limit
set_time_limit(300); // 5 minutes

// Include required files
require_once '../includes/db.php';
require_once '../includes/notification_service.php';

// Log file path
$log_file = __DIR__ . '/../logs/prayer_reminders.log';

// Log function
function logMessage($message) {
    global $log_file;
    $timestamp = date('Y-m-d H:i:s');
    $log_entry = "[$timestamp] $message\n";
    file_put_contents($log_file, $log_entry, FILE_APPEND);
    echo $log_entry; // Also output for web-based cron
}

logMessage("=== Prayer Reminders Cron Job Started ===");

try {
    // Get current time
    $current_time = date('H:i'); // Format: HH:MM
    logMessage("Current time: $current_time");
    
    // Check if columns exist
    $check_column = @$conn->query("SHOW COLUMNS FROM users LIKE 'prayer_reminder_times'");
    if (!$check_column || $check_column->num_rows === 0) {
        logMessage("ERROR: Prayer reminders feature not set up. Columns missing.");
        exit(1);
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
    $users_checked = 0;
    
    logMessage("Checking users for prayer reminders...");
    
    while ($user = $result->fetch_assoc()) {
        $users_checked++;
        $reminder_times = json_decode($user['prayer_reminder_times'], true);
        
        if (!is_array($reminder_times) || empty($reminder_times)) {
            continue;
        }
        
        // Check if current time matches any reminder time
        foreach ($reminder_times as $reminder_time) {
            // Allow 1 minute window (e.g., 06:00-06:01)
            $time_parts = explode(':', $reminder_time);
            $reminder_hour = intval($time_parts[0]);
            $reminder_minute = intval($time_parts[1]);
            
            $current_parts = explode(':', $current_time);
            $current_hour = intval($current_parts[0]);
            $current_minute = intval($current_parts[1]);
            
            // Check if it's the reminder time (within 1 minute window)
            if ($current_hour == $reminder_hour && abs($current_minute - $reminder_minute) <= 1) {
                // Check if we already sent reminder today for this time
                $today = date('Y-m-d');
                $check_stmt = $conn->prepare("
                    SELECT id FROM notifications 
                    WHERE user_id = ? 
                    AND type = 'prayer_reminder' 
                    AND DATE(created_at) = ? 
                    AND data LIKE ?
                ");
                $time_pattern = '%"' . $reminder_time . '"%';
                $check_stmt->bind_param("iss", $user['id'], $today, $time_pattern);
                $check_stmt->execute();
                
                if ($check_stmt->get_result()->num_rows === 0) {
                    // Send reminder notification
                    $success = createNotification(
                        $user['id'],
                        'prayer_reminder',
                        '⏰ Prayer Time Reminder',
                        "It's time for prayer! ($reminder_time) Take a moment to connect with God.",
                        '',
                        ['reminder_time' => $reminder_time]
                    );
                    
                    if ($success) {
                        $reminders_sent++;
                        logMessage("✅ Reminder sent to User ID: {$user['id']} ({$user['name']}) at $reminder_time");
                    } else {
                        logMessage("❌ Failed to send reminder to User ID: {$user['id']}");
                    }
                } else {
                    logMessage("⏭️ Reminder already sent today to User ID: {$user['id']} for $reminder_time");
                }
            }
        }
    }
    
    logMessage("=== Summary ===");
    logMessage("Users checked: $users_checked");
    logMessage("Reminders sent: $reminders_sent");
    logMessage("=== Prayer Reminders Cron Job Completed ===\n");
    
} catch (Exception $e) {
    logMessage("ERROR: " . $e->getMessage());
    logMessage("Stack trace: " . $e->getTraceAsString());
    exit(1);
}

$conn->close();
?>

