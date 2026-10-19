<?php
include './includes/db.php';

// Start session and get dynamic user ID
session_start();
$userId = $_SESSION['admin_id'] ?? 1; // Fallback to admin user for now

try {
    // Check if notifications table exists, if not create it
    $tableCheck = $conn->query("SHOW TABLES LIKE 'notifications'");
    if ($tableCheck->num_rows == 0) {
        // Create notifications table if it doesn't exist
        $conn->query("
            CREATE TABLE IF NOT EXISTS notifications (
                id INT PRIMARY KEY AUTO_INCREMENT,
                user_id INT,
                title VARCHAR(255) NOT NULL,
                message TEXT NOT NULL,
                is_read TINYINT DEFAULT 0,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (user_id) REFERENCES users(id)
            )
        ");
        
        // Insert sample notifications
        $conn->query("
            INSERT INTO notifications (user_id, title, message) VALUES 
            (1, 'Welcome!', 'Welcome to the Fruit of the Spirit Admin Panel'),
            (1, 'System Update', 'New features have been added to the admin panel'),
            (1, 'New User Registered', 'A new user has registered on the platform')
        ");
    }

    // Get notifications for the user
    $stmt = $conn->prepare("SELECT id, title, message, is_read, created_at FROM notifications WHERE user_id=? ORDER BY created_at DESC LIMIT 10");
    $stmt->bind_param("i", $userId);
    $stmt->execute();
    $result = $stmt->get_result();

    $notifications = [];
    $unreadCount = 0;

    while ($row = $result->fetch_assoc()) {
        $notifications[] = $row;
        if ($row['is_read'] == 0) $unreadCount++;
    }

    $stmt->close();

} catch (Exception $e) {
    // If there's an error, return empty data
    $notifications = [];
    $unreadCount = 0;
}

// Return JSON
header('Content-Type: application/json');
echo json_encode([
    'unreadCount' => $unreadCount,
    'notifications' => $notifications
]);
?>