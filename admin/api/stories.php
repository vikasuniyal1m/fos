<?php
/**
 * Stories/Testimonies API
 * Handles: List stories, Get story details, Create story, Share stories
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
        handleGetStories($conn);
        break;
    case 'POST':
        $action = $_POST['action'] ?? 'create'; // edit feature
        if ($action === 'edit') { // edit feature
            handleEditStory($conn); // edit feature
        } elseif ($action === 'delete') {
            handleDeleteStory($conn);
        } else { // edit feature
            handleCreateStory($conn);
        }
        break;
    default:
        http_response_code(405);
        echo jsonResponse(false, 'Method not allowed');
        break;
}

function handleGetStories($conn) {
    $story_id = $_GET['id'] ?? null;
    $fruit_tag = $_GET['fruit_tag'] ?? null;
    $user_id = $_GET['user_id'] ?? null;
    $category = $_GET['category'] ?? null; // spiritual, testimony, encouragement, etc.
    $status = $_GET['status'] ?? 'Approved';
    $limit = intval($_GET['limit'] ?? 100); // Increased default limit to get all stories
    $offset = intval($_GET['offset'] ?? 0);
    $current_user_id = intval($_GET['current_user_id'] ?? 0);
    
    if ($story_id) {
        // Get single story with comments
        $story_id = intval($story_id);
        $stmt = $conn->prepare("
            SELECT s.*, u.name as user_name, u.profile_photo,
                   (SELECT COUNT(*) FROM comments WHERE post_type = 'story' AND post_id = s.id AND status = 'approved') as comment_count
            FROM stories s
            JOIN users u ON s.user_id = u.id
            WHERE s.id = ? AND s.status = ?
        ");
        $stmt->bind_param("is", $story_id, $status);
        $stmt->execute();
        $result = $stmt->get_result();
        
        if ($result->num_rows === 0) {
            http_response_code(404);
            echo jsonResponse(false, 'Story not found');
            return;
        }
        
        $story = $result->fetch_assoc();
        
        // Get comments
        $comments_sql = "
            SELECT c.*, u.name as user_name, u.profile_photo
            FROM comments c
            JOIN users u ON c.user_id = u.id
            WHERE c.post_type = 'story' AND c.post_id = ? AND c.status = 'approved'";
            
        // FILTER BLOCKED USERS FROM COMMENTS
        if ($current_user_id > 0) {
            $check_blocks = $conn->query("SHOW TABLES LIKE 'user_blocks'");
            if ($check_blocks && $check_blocks->num_rows > 0) {
                $comments_sql .= " AND c.user_id NOT IN (SELECT blocked_user_id FROM user_blocks WHERE user_id = " . intval($current_user_id) . ")";
            }
        }
        
        $comments_stmt = $conn->prepare($comments_sql . " ORDER BY c.created_at ASC");
        $comments_stmt->bind_param("i", $story_id);
        $comments_stmt->execute();
        $comments_result = $comments_stmt->get_result();
        $comments = [];
        while ($comment = $comments_result->fetch_assoc()) {
            $comments[] = $comment;
        }
        $story['comments'] = $comments;
        
        echo jsonResponse(true, 'Story retrieved', $story);
        return;
    }
    
    // Get multiple stories
    $sql = "SELECT s.*, u.name as user_name, u.profile_photo,
                   (SELECT COUNT(*) FROM comments WHERE post_type = 'story' AND post_id = s.id AND status = 'approved') as comment_count
            FROM stories s
            JOIN users u ON s.user_id = u.id
            WHERE s.status = ?";
    $params = [$status];
    $types = "s";
    
    if ($fruit_tag) {
        // Case-insensitive matching for fruit_tag
        $sql .= " AND LOWER(TRIM(s.fruit_tag)) = LOWER(TRIM(?))";
        $params[] = $fruit_tag;
        $types .= "s";
    }

    // FILTER BLOCKED USERS FROM STORIES
    if ($current_user_id > 0) {
        $check_blocks = $conn->query("SHOW TABLES LIKE 'user_blocks'");
        if ($check_blocks && $check_blocks->num_rows > 0) {
            $sql .= " AND s.user_id NOT IN (SELECT blocked_user_id FROM user_blocks WHERE user_id = ?)";
            $params[] = $current_user_id;
            $types .= "i";
        }
    }
    
    if ($user_id) {
        $user_id = intval($user_id);
        $sql .= " AND s.user_id = ?";
        $params[] = $user_id;
        $types .= "i";
    }
    
    if ($category) {
        $sql .= " AND s.category = ?";
        $params[] = $category;
        $types .= "s";
    }
    
    $sql .= " ORDER BY s.created_at DESC LIMIT ? OFFSET ?";
    $params[] = $limit;
    $params[] = $offset;
    $types .= "ii";
    
    $stmt = $conn->prepare($sql);
    $stmt->bind_param($types, ...$params);
    $stmt->execute();
    $result = $stmt->get_result();
    
    $stories = [];
    while ($row = $result->fetch_assoc()) {
        $stories[] = $row;
    }
    
    echo jsonResponse(true, 'Stories retrieved', $stories);
}

function handleCreateStory($conn) {
    $user_id = intval($_POST['user_id'] ?? 0);
    $title = trim($_POST['title'] ?? '');
    $content = trim($_POST['content'] ?? '');
    $fruit_tag = trim($_POST['fruit_tag'] ?? '');
    $category = trim($_POST['category'] ?? 'testimony'); // testimony, spiritual, encouragement, etc.
    $image_url = trim($_POST['image_url'] ?? '');
    
    if (!$user_id) {
        http_response_code(400);
        echo jsonResponse(false, 'user_id is required');
        return;
    }
    
    if (empty($title) || empty($content)) {
        http_response_code(400);
        echo jsonResponse(false, 'title and content are required');
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
    
    // Handle image upload if provided
    if (isset($_FILES['image']) && $_FILES['image']['error'] === UPLOAD_ERR_OK) {
        $target_dir = "../uploads/";
        if (!is_dir($target_dir)) {
            mkdir($target_dir, 0755, true);
        }
        
        $fileExtension = strtolower(pathinfo($_FILES['image']['name'], PATHINFO_EXTENSION));
        $allowedTypes = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
        
        if (in_array($fileExtension, $allowedTypes)) {
            $maxFileSize = 10 * 1024 * 1024; // 10MB
            if ($_FILES['image']['size'] <= $maxFileSize) {
                $fileName = 'story_' . time() . '_' . uniqid() . '.' . $fileExtension;
                $targetFile = $target_dir . $fileName;
                
                if (move_uploaded_file($_FILES['image']['tmp_name'], $targetFile)) {
                    $image_url = 'uploads/' . $fileName;
                }
            }
        }
    }
    
    // Insert story
    $status = 'Pending'; // Admin approval required
    $stmt = $conn->prepare("
        INSERT INTO stories (user_id, title, content, fruit_tag, category, image_url, status) 
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ");
    $stmt->bind_param("issssss", $user_id, $title, $content, $fruit_tag, $category, $image_url, $status);
    
    if ($stmt->execute()) {
        $story_id = $stmt->insert_id;
        
        // Get created story
        $get_stmt = $conn->prepare("
            SELECT s.*, u.name as user_name, u.profile_photo
            FROM stories s
            JOIN users u ON s.user_id = u.id
            WHERE s.id = ?
        ");
        $get_stmt->bind_param("i", $story_id);
        $get_stmt->execute();
        $story = $get_stmt->get_result()->fetch_assoc();
        
        echo jsonResponse(true, 'Story created successfully. Pending admin approval.', $story);
    } else {
        http_response_code(500);
        echo jsonResponse(false, 'Failed to create story: ' . $stmt->error);
    }
}

// edit feature: Handle edit story with 15-minute window
function handleEditStory($conn) { // edit feature
    $user_id = intval($_POST['user_id'] ?? 0); // edit feature
    $story_id = intval($_POST['story_id'] ?? 0); // edit feature
    $title = trim($_POST['title'] ?? ''); // edit feature
    $content = trim($_POST['content'] ?? ''); // edit feature
    $category = trim($_POST['category'] ?? ''); // edit feature
    
    // edit feature: Log incoming request
    error_log("📥 Edit Story Request: user_id=$user_id, story_id=$story_id"); // edit feature
    
    // edit feature: Validation
    if (!$user_id || !$story_id) { // edit feature
        http_response_code(400); // edit feature
        echo jsonResponse(false, 'user_id and story_id are required'); // edit feature
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
                echo jsonResponse(false, 'Story title violates community guidelines.'); // edit feature
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
    
    // edit feature: Moderate content if provided
    if (!empty($content)) { // edit feature
        $moderation_result = ContentModerationService::checkContent($content, $conn); // edit feature
        switch ($moderation_result['action']) { // edit feature
            case 'block': // edit feature
                http_response_code(400); // edit feature
                echo jsonResponse(false, 'Story content violates community guidelines.'); // edit feature
                return; // edit feature
            case 'quarantine': // edit feature
                http_response_code(400); // edit feature
                echo jsonResponse(false, 'Content cannot be edited due to content policy.'); // edit feature
                return; // edit feature
            case 'warn': // edit feature
                $content = $moderation_result['sanitized_content']; // edit feature
                break; // edit feature
            case 'allow': // edit feature
            default: // edit feature
                break; // edit feature
        } // edit feature
    } // edit feature
    
    // edit feature: Verify user owns the story
    $check_stmt = $conn->prepare("SELECT user_id, created_at FROM stories WHERE id = ?"); // edit feature
    $check_stmt->bind_param("i", $story_id); // edit feature
    $check_stmt->execute(); // edit feature
    $check_result = $check_stmt->get_result(); // edit feature
    
    if ($check_result->num_rows === 0) { // edit feature
        http_response_code(404); // edit feature
        echo jsonResponse(false, 'Story not found'); // edit feature
        return; // edit feature
    } // edit feature
    
    $story_data = $check_result->fetch_assoc(); // edit feature
    
    // edit feature: Check if user owns the story
    if ($story_data['user_id'] != $user_id) { // edit feature
        http_response_code(403); // edit feature
        echo jsonResponse(false, 'You can only edit your own stories'); // edit feature
        return; // edit feature
    } // edit feature
    
    // edit feature: Check if story is within 15-minute window
    $created_at = strtotime($story_data['created_at']); // edit feature
    $now = time(); // edit feature
    $time_diff_minutes = ($now - $created_at) / 60; // edit feature
    
    if ($time_diff_minutes > 15) { // edit feature
        http_response_code(403); // edit feature
        echo jsonResponse(false, 'Stories can only be edited within 15 minutes of posting'); // edit feature
        return; // edit feature
    } // edit feature
    
    // edit feature: Check if edited_at column exists
    $check_column = $conn->query("SHOW COLUMNS FROM stories LIKE 'edited_at'"); // edit feature
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
    
    if (!empty($content)) { // edit feature
        $update_parts[] = "content = ?"; // edit feature
        $params[] = $content; // edit feature
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
    
    $params[] = $story_id; // edit feature
    $types .= "i"; // edit feature
    
    $sql = "UPDATE stories SET " . implode(", ", $update_parts) . " WHERE id = ?"; // edit feature
    $update_stmt = $conn->prepare($sql); // edit feature
    $update_stmt->bind_param($types, ...$params); // edit feature
    
    if ($update_stmt->execute()) { // edit feature
        error_log("✅ Story edited: ID=$story_id, user_id=$user_id"); // edit feature
        echo jsonResponse(true, 'Story edited successfully', [ // edit feature
            'id' => $story_id, // edit feature
            'is_edited' => true // edit feature
        ]); // edit feature
    } else { // edit feature
        error_log("❌ Failed to edit story: " . $update_stmt->error); // edit feature
        http_response_code(500); // edit feature
        echo jsonResponse(false, 'Failed to edit story: ' . $update_stmt->error); // edit feature
    } // edit feature
} // edit feature

function handleDeleteStory($conn) {
    $user_id = intval($_POST['user_id'] ?? 0);
    $story_id = intval($_POST['story_id'] ?? 0);

    if (!$user_id || !$story_id) {
        http_response_code(400);
        echo jsonResponse(false, 'user_id and story_id are required');
        return;
    }

    $check_stmt = $conn->prepare("SELECT user_id, status FROM stories WHERE id = ?");
    $check_stmt->bind_param("i", $story_id);
    $check_stmt->execute();
    $check_result = $check_stmt->get_result();

    if ($check_result->num_rows === 0) {
        http_response_code(404);
        echo jsonResponse(false, 'Story not found');
        return;
    }

    $story_data = $check_result->fetch_assoc();

    if ($story_data['user_id'] != $user_id) {
        http_response_code(403);
        echo jsonResponse(false, 'You can only delete your own stories');
        return;
    }

    if ($story_data['status'] === 'Deleted') {
        http_response_code(404);
        echo jsonResponse(false, 'Story already deleted');
        return;
    }

    $delete_stmt = $conn->prepare("UPDATE stories SET status = 'Deleted' WHERE id = ?");
    $delete_stmt->bind_param("i", $story_id);

    if ($delete_stmt->execute()) {
        echo jsonResponse(true, 'Story deleted successfully', ['id' => $story_id]);
    } else {
        http_response_code(500);
        echo jsonResponse(false, 'Failed to delete story: ' . $delete_stmt->error);
    }
}

$conn->close();
?>

