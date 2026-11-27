<?php
/**
 * User Profile API
 * Handles: Get profile, Update profile
 */

require_once '../includes/db.php';
require_once '../includes/cors.php';
require_once 'auth-helper.php';

header('Content-Type: application/json');

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'OPTIONS') {
    http_response_code(200);
    exit;
}

switch ($method) {
    case 'GET':
        handleGetProfile($conn);
        break;
    case 'POST':
        $action = $_POST['action'] ?? '';
        if ($action === 'delete') {
            handleDeleteAccount($conn);
        } else {
            handleUpdateProfile($conn);
        }
        break;
    default:
        http_response_code(405);
        echo jsonResponse(false, 'Method not allowed');
        break;
}

function handleGetProfile($conn) {
    $user_id = intval($_GET['user_id'] ?? 0);
    
    if (!$user_id) {
        http_response_code(400);
        echo jsonResponse(false, 'user_id is required');
        return;
    }
    
    $stmt = $conn->prepare("SELECT id, name, email, phone, role, status, join_date, profile_photo, fruit_category FROM users WHERE id = ? AND status != 'Deleted'");
    $stmt->bind_param("i", $user_id);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows === 0) {
        http_response_code(404);
        echo jsonResponse(false, 'User not found');
        return;
    }
    
    $user = $result->fetch_assoc();
    
    // Get user's selected fruits
    $fruits_stmt = $conn->prepare("
        SELECT f.id, f.name 
        FROM user_fruits uf 
        JOIN fruits f ON uf.fruit_id = f.id 
        WHERE uf.user_id = ?
    ");
    $fruits_stmt->bind_param("i", $user_id);
    $fruits_stmt->execute();
    $fruits_result = $fruits_stmt->get_result();
    $user_fruits = [];
    while ($fruit = $fruits_result->fetch_assoc()) {
        $user_fruits[] = $fruit;
    }
    $user['fruits'] = $user_fruits;
    
    // Get user stats
    $stats = [];
    
    // Blog count
    $blog_stmt = $conn->prepare("SELECT COUNT(*) as count FROM blogs WHERE user_id = ?");
    $blog_stmt->bind_param("i", $user_id);
    $blog_stmt->execute();
    $stats['blogs'] = intval($blog_stmt->get_result()->fetch_assoc()['count']);
    
    // Prayer requests count
    $prayer_stmt = $conn->prepare("SELECT COUNT(*) as count FROM prayer_requests WHERE user_id = ?");
    $prayer_stmt->bind_param("i", $user_id);
    $prayer_stmt->execute();
    $stats['prayers'] = intval($prayer_stmt->get_result()->fetch_assoc()['count']);
    
    // Media count
    $media_stmt = $conn->prepare("SELECT COUNT(*) as count FROM media_items WHERE user_id = ?");
    $media_stmt->bind_param("i", $user_id);
    $media_stmt->execute();
    $stats['media'] = intval($media_stmt->get_result()->fetch_assoc()['count']);
    
    $user['stats'] = $stats;
    
    echo jsonResponse(true, 'Profile retrieved', $user);
}

function handleUpdateProfile($conn) {
    $user_id = intval($_POST['user_id'] ?? 0);
    $name = trim($_POST['name'] ?? '');
    $email = trim($_POST['email'] ?? '');
    $phone = trim($_POST['phone'] ?? '');
    $password = trim($_POST['password'] ?? '');
    $fruit_category = trim($_POST['fruit_category'] ?? '');
    
    if (!$user_id) {
        http_response_code(400);
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
    
    // Build update query
    $updates = [];
    $params = [];
    $types = "";
    
    if (!empty($name)) {
        $updates[] = "name = ?";
        $params[] = $name;
        $types .= "s";
    }
    
    if (!empty($email)) {
        // Validate email format
        if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
            http_response_code(400);
            echo jsonResponse(false, 'Invalid email format');
            return;
        }
        // Check if email already exists for another user
        $email_check = $conn->prepare("SELECT id FROM users WHERE email = ? AND id != ?");
        $email_check->bind_param("si", $email, $user_id);
        $email_check->execute();
        if ($email_check->get_result()->num_rows > 0) {
            http_response_code(400);
            echo jsonResponse(false, 'Email already exists');
            return;
        }
        $updates[] = "email = ?";
        $params[] = $email;
        $types .= "s";
    }
    
    if (!empty($phone)) {
        $updates[] = "phone = ?";
        $params[] = $phone;
        $types .= "s";
    }
    
    if (!empty($password)) {
        // Validate password length
        if (strlen($password) < 6) {
            http_response_code(400);
            echo jsonResponse(false, 'Password must be at least 6 characters');
            return;
        }
        // Hash password using MD5 (matching the existing system)
        $password_hash = md5($password);
        $updates[] = "password_hash = ?";
        $params[] = $password_hash;
        $types .= "s";
    }
    
    if (!empty($fruit_category)) {
        $updates[] = "fruit_category = ?";
        $params[] = $fruit_category;
        $types .= "s";
    }
    
    // Handle profile photo upload
    if (isset($_FILES['profile_photo']) && $_FILES['profile_photo']['error'] === UPLOAD_ERR_OK) {
        $target_dir = "../uploads/";
        if (!is_dir($target_dir)) {
            mkdir($target_dir, 0755, true);
        }
        
        $fileExtension = strtolower(pathinfo($_FILES['profile_photo']['name'], PATHINFO_EXTENSION));
        $allowedTypes = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
        
        if (in_array($fileExtension, $allowedTypes)) {
            $fileName = 'profile_' . $user_id . '_' . time() . '.' . $fileExtension;
            $target_file = $target_dir . $fileName;
            
            if (move_uploaded_file($_FILES['profile_photo']['tmp_name'], $target_file)) {
                $profile_photo = "uploads/" . $fileName;
                $updates[] = "profile_photo = ?";
                $params[] = $profile_photo;
                $types .= "s";
            }
        }
    }
    
    if (empty($updates)) {
        http_response_code(400);
        echo jsonResponse(false, 'No fields to update');
        return;
    }
    
    $params[] = $user_id;
    $types .= "i";
    
    $sql = "UPDATE users SET " . implode(", ", $updates) . " WHERE id = ?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param($types, ...$params);
    
    if ($stmt->execute()) {
        echo jsonResponse(true, 'Profile updated successfully');
    } else {
        http_response_code(500);
        echo jsonResponse(false, 'Failed to update profile: ' . $stmt->error);
    }
}

function handleDeleteAccount($conn) {
    $user_id = intval($_POST['user_id'] ?? 0);
    
    if (!$user_id) {
        http_response_code(400);
        echo jsonResponse(false, 'user_id is required');
        return;
    }
    
    // Verify user exists
    $user_stmt = $conn->prepare("SELECT id, email FROM users WHERE id = ? AND status != 'Deleted'");
    $user_stmt->bind_param("i", $user_id);
    $user_stmt->execute();
    $user_result = $user_stmt->get_result();
    
    if ($user_result->num_rows === 0) {
        http_response_code(404);
        echo jsonResponse(false, 'User not found or already deleted');
        return;
    }
    
    $user = $user_result->fetch_assoc();
    
    // Start transaction for data consistency
    $conn->begin_transaction();
    
    try {
        // 1. Soft delete user: Set status to 'Deleted' and anonymize email
        $deleted_email = $user['email'] . '_deleted_' . time();
        $stmt = $conn->prepare("UPDATE users SET status = 'Deleted', email = ?, phone = NULL, name = 'Deleted User', profile_photo = NULL WHERE id = ?");
        $stmt->bind_param("si", $deleted_email, $user_id);
        $stmt->execute();
        
        // 2. Mark all user's blogs as deleted
        $stmt = $conn->prepare("UPDATE blogs SET status = 'Deleted' WHERE user_id = ?");
        $stmt->bind_param("i", $user_id);
        $stmt->execute();
        
        // 3. Mark all user's prayer requests as deleted
        $stmt = $conn->prepare("UPDATE prayer_requests SET status = 'Deleted' WHERE user_id = ?");
        $stmt->bind_param("i", $user_id);
        $stmt->execute();
        
        // 4. Mark all user's media items (photos/videos) as deleted
        $stmt = $conn->prepare("UPDATE media_items SET status = 'Deleted' WHERE user_id = ?");
        $stmt->bind_param("i", $user_id);
        $stmt->execute();
        
        // 5. Mark all user's comments as deleted
        $stmt = $conn->prepare("UPDATE comments SET is_deleted = 1 WHERE user_id = ?");
        $stmt->bind_param("i", $user_id);
        $stmt->execute();
        
        // 6. Mark all user's gallery comments as deleted
        $stmt = $conn->prepare("UPDATE gallery_comments SET is_deleted = 1 WHERE user_id = ?");
        $stmt->bind_param("i", $user_id);
        $stmt->execute();
        
        // 7. Delete user's group memberships
        $stmt = $conn->prepare("DELETE FROM group_members WHERE user_id = ?");
        $stmt->bind_param("i", $user_id);
        $stmt->execute();
        
        // 8. Mark user's group posts as deleted
        $stmt = $conn->prepare("UPDATE group_posts SET status = 'Deleted' WHERE user_id = ?");
        $stmt->bind_param("i", $user_id);
        $stmt->execute();
        
        // 9. Delete user's group post reactions
        $stmt = $conn->prepare("DELETE FROM group_post_reactions WHERE user_id = ?");
        $stmt->bind_param("i", $user_id);
        $stmt->execute();
        
        // 10. Mark user's group chat messages as deleted
        $stmt = $conn->prepare("UPDATE group_chat_messages SET status = 'deleted' WHERE user_id = ?");
        $stmt->bind_param("i", $user_id);
        $stmt->execute();
        
        // 11. Delete user's emoji usage data
        $stmt = $conn->prepare("DELETE FROM emoji_usage WHERE user_id = ?");
        $stmt->bind_param("i", $user_id);
        $stmt->execute();
        
        // 12. Delete user's emoji usage stats
        $stmt = $conn->prepare("DELETE FROM user_emoji_usage WHERE user_id = ?");
        $stmt->bind_param("i", $user_id);
        $stmt->execute();
        
        // 13. Delete user's fruit selections
        $stmt = $conn->prepare("DELETE FROM user_fruits WHERE user_id = ?");
        $stmt->bind_param("i", $user_id);
        $stmt->execute();
        
        // 14. Delete user's media likes
        $stmt = $conn->prepare("DELETE FROM media_likes WHERE user_id = ?");
        $stmt->bind_param("i", $user_id);
        $stmt->execute();
        
        // 15. Delete user's gallery comment likes
        $stmt = $conn->prepare("DELETE FROM gallery_comment_likes WHERE user_id = ?");
        $stmt->bind_param("i", $user_id);
        $stmt->execute();
        
        // 16. Delete user's comment likes (if table exists)
        $check_stmt = $conn->query("SHOW TABLES LIKE 'comment_likes'");
        if ($check_stmt && $check_stmt->num_rows > 0) {
            $stmt = $conn->prepare("DELETE FROM comment_likes WHERE user_id = ?");
            $stmt->bind_param("i", $user_id);
            $stmt->execute();
        }
        
        // 17. Delete user's stories (if table exists)
        $check_stmt = $conn->query("SHOW TABLES LIKE 'stories'");
        if ($check_stmt && $check_stmt->num_rows > 0) {
            $stmt = $conn->prepare("UPDATE stories SET status = 'Deleted' WHERE user_id = ?");
            $stmt->bind_param("i", $user_id);
            $stmt->execute();
        }
        
        // 18. Delete user's follows/followers (if tables exist)
        $check_stmt = $conn->query("SHOW TABLES LIKE 'user_follows'");
        if ($check_stmt && $check_stmt->num_rows > 0) {
            $stmt = $conn->prepare("DELETE FROM user_follows WHERE follower_id = ? OR following_id = ?");
            $stmt->bind_param("ii", $user_id, $user_id);
            $stmt->execute();
        }
        
        // 19. Delete user's blocks (if table exists)
        $check_stmt = $conn->query("SHOW TABLES LIKE 'user_blocks'");
        if ($check_stmt && $check_stmt->num_rows > 0) {
            $stmt = $conn->prepare("DELETE FROM user_blocks WHERE user_id = ? OR blocked_user_id = ?");
            $stmt->bind_param("ii", $user_id, $user_id);
            $stmt->execute();
        }
        
        // 20. Delete user's saved content (if table exists)
        $check_stmt = $conn->query("SHOW TABLES LIKE 'saved_content'");
        if ($check_stmt && $check_stmt->num_rows > 0) {
            $stmt = $conn->prepare("DELETE FROM saved_content WHERE user_id = ?");
            $stmt->bind_param("i", $user_id);
            $stmt->execute();
        }
        
        // 21. Delete user's notifications (if table exists)
        $check_stmt = $conn->query("SHOW TABLES LIKE 'notifications'");
        if ($check_stmt && $check_stmt->num_rows > 0) {
            $stmt = $conn->prepare("DELETE FROM notifications WHERE user_id = ?");
            $stmt->bind_param("ii", $user_id);
            $stmt->execute();
        }
        
        // Commit transaction
        $conn->commit();
        
        echo jsonResponse(true, 'Account and all related data deleted successfully');
        
    } catch (Exception $e) {
        // Rollback on error
        $conn->rollback();
        error_log("Error deleting account for user_id $user_id: " . $e->getMessage());
        http_response_code(500);
        echo jsonResponse(false, 'Failed to delete account: ' . $e->getMessage());
    }
}

$conn->close();
?>

