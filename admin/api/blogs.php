<?php
/**
 * Blogs API
 * Handles: List approved blogs, Get blog details, Create blog (for bloggers only)
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
        handleGetBlogs($conn);
        break;
    case 'POST':
        $action = $_POST['action'] ?? 'create';
        if ($action === 'request-blogger') {
            handleRequestBlogger($conn);
        } elseif ($action === 'edit') {
            handleEditBlog($conn);
        } elseif ($action === 'delete') {
            handleDeleteBlog($conn);
        } else {
            handleCreateBlog($conn);
        }
        break;
    default:
        http_response_code(405);
        echo jsonResponse(false, 'Method not allowed');
        break;
}

function handleGetBlogs($conn) {
    $blog_id = $_GET['id'] ?? null;
    $category = $_GET['category'] ?? null;
    $language = $_GET['language'] ?? null;
    $user_id = $_GET['user_id'] ?? null;
    $status = $_GET['status'] ?? 'Approved'; // Only show Approved blogs
    $is_featured = $_GET['is_featured'] ?? null;
    $is_trending = $_GET['is_trending'] ?? null;
    $limit = intval($_GET['limit'] ?? 20);
    $offset = intval($_GET['offset'] ?? 0);
    $current_user_id = intval($_GET['current_user_id'] ?? 0);
    
    if ($blog_id) {
        // Get single blog with comments and likes
        $blog_id = intval($blog_id);
        $stmt = $conn->prepare("
            SELECT b.*,
                   COALESCE(u.name, a.name) as user_name,
                   u.profile_photo,
                   COALESCE(u.role, 'Admin') as user_role,
                   COALESCE(cc.cnt, 0) as comment_count,
                   COALESCE(lc.cnt, 0) as like_count
            FROM blogs b
            LEFT JOIN users u ON b.user_id = u.id
            LEFT JOIN admin_users a ON b.admin_id = a.id
            LEFT JOIN (
                SELECT blog_id, COUNT(*) as cnt
                FROM blog_comments
                GROUP BY blog_id
            ) cc ON cc.blog_id = b.id
            LEFT JOIN (
                SELECT blog_id, COUNT(*) as cnt
                FROM blog_likes
                GROUP BY blog_id
            ) lc ON lc.blog_id = b.id
            WHERE b.id = ?
        ");
        $stmt->bind_param("i", $blog_id);
        $stmt->execute();
        $result = $stmt->get_result();
        
        if ($result->num_rows === 0) {
            http_response_code(404);
            echo jsonResponse(false, 'Blog not found');
            return;
        }
        
        $blog = $result->fetch_assoc();
        
        // Ensure like_count and comment_count are integers
        $blog['like_count'] = intval($blog['like_count'] ?? 0);
        $blog['comment_count'] = intval($blog['comment_count'] ?? 0);
        
        // Add 'image' field for app compatibility
        $blog['image'] = $blog['image_url'] ?? null;
        
        // Get comments
        $comments_sql = "
            SELECT bc.*, u.name as user_name, u.profile_photo
            FROM blog_comments bc
            JOIN users u ON bc.user_id = u.id
            WHERE bc.blog_id = ?";
            
        // FILTER BLOCKED USERS FROM COMMENTS
        if ($current_user_id > 0) {
            $check_blocks = $conn->query("SHOW TABLES LIKE 'user_blocks'");
            if ($check_blocks && $check_blocks->num_rows > 0) {
                $comments_sql .= " AND bc.user_id NOT IN (SELECT blocked_user_id FROM user_blocks WHERE user_id = " . intval($current_user_id) . ")";
            }
        }
        
        $comments_stmt = $conn->prepare($comments_sql . " ORDER BY bc.created_at ASC");
        $comments_stmt->bind_param("i", $blog_id);
        $comments_stmt->execute();
        $comments_result = $comments_stmt->get_result();
        $comments = [];
        while ($comment = $comments_result->fetch_assoc()) {
            $comments[] = $comment;
        }
        $blog['comments'] = $comments;
        
        echo jsonResponse(true, 'Blog retrieved', $blog);
    } else {
        // Get list of blogs
        $sql = "SELECT b.*,
                       COALESCE(u.name, a.name) as user_name,
                       u.profile_photo,
                       COALESCE(u.role, 'Admin') as user_role,
                       COALESCE(cc.cnt, 0) as comment_count,
                       COALESCE(lc.cnt, 0) as like_count
                FROM blogs b
                LEFT JOIN users u ON b.user_id = u.id
                LEFT JOIN admin_users a ON b.admin_id = a.id
                LEFT JOIN (
                    SELECT blog_id, COUNT(*) as cnt
                    FROM blog_comments
                    GROUP BY blog_id
                ) cc ON cc.blog_id = b.id
                LEFT JOIN (
                    SELECT blog_id, COUNT(*) as cnt
                    FROM blog_likes
                    GROUP BY blog_id
                ) lc ON lc.blog_id = b.id
                WHERE 1=1";
        $params = [];
        $types = "";
        
        // FILTER BLOCKED USERS
        if ($current_user_id) {
            $check_blocks = $conn->query("SHOW TABLES LIKE 'user_blocks'");
            if ($check_blocks->num_rows > 0) {
                $sql .= " AND (b.user_id NOT IN (SELECT blocked_user_id FROM user_blocks WHERE user_id = ?) OR b.user_id IS NULL)";
                $params[] = $current_user_id;
                $types .= "i";
            }
        }
        
        if ($status) {
            if (strpos($status, ',') !== false) {
                $status_list = explode(',', $status);
                $placeholders = implode(',', array_fill(0, count($status_list), '?'));
                $sql .= " AND b.status IN ($placeholders)";
                foreach ($status_list as $s) {
                    $params[] = trim($s);
                    $types .= "s";
                }
            } else {
                $sql .= " AND b.status = ?";
                $params[] = $status;
                $types .= "s";
            }
        }
        
        if ($category) {
            $sql .= " AND b.category = ?";
            $params[] = $category;
            $types .= "s";
        }
        
        if ($language) {
            $sql .= " AND b.language = ?";
            $params[] = $language;
            $types .= "s";
        }
        
        if ($user_id) {
            $sql .= " AND (b.user_id = ? OR b.admin_id = ?)";
            $params[] = intval($user_id);
            $params[] = intval($user_id);
            $types .= "ii";
        }
        
        if ($is_featured !== null) {
            $sql .= " AND b.is_featured = ?";
            $params[] = intval($is_featured);
            $types .= "i";
        }
        
        if ($is_trending !== null) {
            $sql .= " AND b.is_trending = ?";
            $params[] = intval($is_trending);
            $types .= "i";
        }
        
        $sql .= " ORDER BY b.created_at DESC LIMIT ? OFFSET ?";
        $params[] = $limit;
        $params[] = $offset;
        $types .= "ii";
        
        $stmt = $conn->prepare($sql);
        if (!empty($params)) {
            $stmt->bind_param($types, ...$params);
        }
        $stmt->execute();
        $result = $stmt->get_result();
        
        $blogs = [];
        while ($row = $result->fetch_assoc()) {
            // Add 'image' field for app compatibility
            $row['image'] = $row['image_url'] ?? null;
            $blogs[] = $row;
        }
        
        echo jsonResponse(true, 'Blogs retrieved', $blogs);
    }
}

function handleCreateBlog($conn) {
    $user_id = intval($_POST['user_id'] ?? 0);
    $title = trim($_POST['title'] ?? '');
    $body = trim($_POST['body'] ?? '');
    $category = trim($_POST['category'] ?? '');
    $language = trim($_POST['language'] ?? 'en');
    
    if (!$user_id) {
        http_response_code(400);
        echo jsonResponse(false, 'user_id is required');
        return;
    }
    
    // Check if user is a blogger
    if (!isBlogger($conn, $user_id)) {
        http_response_code(403);
        echo jsonResponse(false, 'Only approved bloggers can create blogs');
        return;
    }
    
    if (empty($title) || empty($body) || empty($category)) {
        http_response_code(400);
        echo jsonResponse(false, 'Title, body, and category are required');
        return;
    }
    
    $image_url = null;
    
    // Handle image or video upload if present
    if (isset($_FILES['image']) && $_FILES['image']['error'] === UPLOAD_ERR_OK) {
        $target_dir = "../uploads/";
        if (!is_dir($target_dir)) {
            mkdir($target_dir, 0755, true);
        }
        
        $image_name = 'blog_' . time() . '_' . uniqid() . '_' . basename($_FILES["image"]["name"]);
        $target_file = $target_dir . $image_name;
        $imageFileType = strtolower(pathinfo($_FILES["image"]["name"], PATHINFO_EXTENSION));
        
        $allowedImageTypes = ['jpg', 'jpeg', 'png', 'gif'];
        $allowedVideoTypes = ['mp4', 'mov', 'avi', 'wmv', 'flv', 'webm'];

        if (in_array($imageFileType, $allowedImageTypes)) {
            $check = getimagesize($_FILES["image"]["tmp_name"]);
            if($check === false) {
                http_response_code(400);
                echo jsonResponse(false, 'File is not an image');
                return;
            }
        } elseif (!in_array($imageFileType, $allowedVideoTypes)) {
            http_response_code(400);
            echo jsonResponse(false, 'Invalid file format. Allowed: JPG, JPEG, PNG, GIF, MP4, MOV, AVI, WMV, FLV, WEBM');
            return;
        }

        if (!move_uploaded_file($_FILES["image"]["tmp_name"], $target_file)) {
            http_response_code(500);
            echo jsonResponse(false, 'Error uploading file');
            return;
        }

        $image_url = "uploads/" . $image_name;
    }
    
    // Check if user is admin
    $user_stmt = $conn->prepare("SELECT role FROM users WHERE id = ?");
    $user_stmt->bind_param("i", $user_id);
    $user_stmt->execute();
    $user_result = $user_stmt->get_result();
    $is_admin = false;
    if ($user_result->num_rows > 0) {
        $user = $user_result->fetch_assoc();
        $is_admin = $user['role'] === 'Admin';
    }
    
    // Insert blog: Approved for admins, Pending for bloggers
    $status = $is_admin ? 'Approved' : 'Pending';
    $stmt = $conn->prepare("INSERT INTO blogs (user_id, title, category, body, language, image_url, status) VALUES (?, ?, ?, ?, ?, ?, ?)");
    $stmt->bind_param("issssss", $user_id, $title, $category, $body, $language, $image_url, $status);
    
    if ($stmt->execute()) {
        $blog_id = $stmt->insert_id;
        $message = $is_admin ? 'Blog post created successfully.' : 'Blog post created successfully. Waiting for admin approval.';
        echo jsonResponse(true, $message, ['id' => $blog_id]);
    } else {
        http_response_code(500);
        echo jsonResponse(false, 'Failed to create blog: ' . $stmt->error);
    }
}

function handleRequestBlogger($conn) {
    $user_id = intval($_POST['user_id'] ?? 0);
    
    if (!$user_id) {
        http_response_code(400);
        echo jsonResponse(false, 'user_id is required');
        return;
    }
    
    // Check if user exists
    $user_stmt = $conn->prepare("SELECT id, role, status FROM users WHERE id = ?");
    $user_stmt->bind_param("i", $user_id);
    $user_stmt->execute();
    $user_result = $user_stmt->get_result();
    
    if ($user_result->num_rows === 0) {
        http_response_code(404);
        echo jsonResponse(false, 'User not found');
        return;
    }
    
    $user = $user_result->fetch_assoc();
    
    // If already a blogger
    if ($user['role'] === 'Blogger') {
        if ($user['status'] === 'Active') {
            echo jsonResponse(true, 'You are already an approved blogger');
        } else {
            echo jsonResponse(true, 'Your blogger request is pending approval');
        }
        return;
    }
    
    // Update user role to Blogger and status to Inactive (pending approval)
    $update_stmt = $conn->prepare("UPDATE users SET role = 'Blogger', status = 'Inactive' WHERE id = ?");
    $update_stmt->bind_param("i", $user_id);
    
    if ($update_stmt->execute()) {
        echo jsonResponse(true, 'Request sent successfully. Admin will review your request.');
    } else {
        http_response_code(500);
        echo jsonResponse(false, 'Failed to send request: ' . $update_stmt->error);
    }
}

// edit feature: Handle edit blog post request with 15-minute window
function handleEditBlog($conn) { // edit feature
    $user_id = intval($_POST['user_id'] ?? 0); // edit feature
    $blog_id = intval($_POST['blog_id'] ?? 0); // edit feature
    $title = trim($_POST['title'] ?? ''); // edit feature
    $body = trim($_POST['body'] ?? ''); // edit feature
    $category = trim($_POST['category'] ?? ''); // edit feature
    
    // edit feature: Log incoming request
    error_log("📥 Edit Blog Request: user_id=$user_id, blog_id=$blog_id"); // edit feature
    
    // edit feature: Validation
    if (!$user_id || !$blog_id) { // edit feature
        http_response_code(400); // edit feature
        echo jsonResponse(false, 'user_id and blog_id are required'); // edit feature
        return; // edit feature
    } // edit feature
    
    // edit feature: Content moderation check for body
    require_once '../includes/ContentModerationService.php'; // edit feature
    $moderation_result = ContentModerationService::checkContent($body, $conn); // edit feature
    
    // edit feature: Handle moderation result
    switch ($moderation_result['action']) { // edit feature
        case 'block': // edit feature
            http_response_code(400); // edit feature
            echo jsonResponse(false, 'Content violates community guidelines.'); // edit feature
            return; // edit feature
        case 'quarantine': // edit feature
            http_response_code(400); // edit feature
            echo jsonResponse(false, 'Content cannot be edited due to content policy.'); // edit feature
            return; // edit feature
        case 'warn': // edit feature
            $body = $moderation_result['sanitized_content']; // edit feature
            break; // edit feature
        case 'allow': // edit feature
        default: // edit feature
            break; // edit feature
    } // edit feature
    
    // edit feature: Verify user owns the blog
    $check_stmt = $conn->prepare("SELECT user_id, created_at FROM blogs WHERE id = ?"); // edit feature
    $check_stmt->bind_param("i", $blog_id); // edit feature
    $check_stmt->execute(); // edit feature
    $check_result = $check_stmt->get_result(); // edit feature
    
    if ($check_result->num_rows === 0) { // edit feature
        http_response_code(404); // edit feature
        echo jsonResponse(false, 'Blog not found'); // edit feature
        return; // edit feature
    } // edit feature
    
    $blog_data = $check_result->fetch_assoc(); // edit feature
    
    // edit feature: Check if user owns the blog
    if ($blog_data['user_id'] != $user_id) { // edit feature
        http_response_code(403); // edit feature
        echo jsonResponse(false, 'You can only edit your own blogs'); // edit feature
        return; // edit feature
    } // edit feature
    
    // edit feature: Check if blog is within 15-minute window
    $created_at = strtotime($blog_data['created_at']); // edit feature
    $now = time(); // edit feature
    $time_diff_minutes = ($now - $created_at) / 60; // edit feature
    
    if ($time_diff_minutes > 15) { // edit feature
        http_response_code(403); // edit feature
        echo jsonResponse(false, 'Blogs can only be edited within 15 minutes of posting'); // edit feature
        return; // edit feature
    } // edit feature
    
    // edit feature: Check if edited_at column exists
    $check_column = $conn->query("SHOW COLUMNS FROM blogs LIKE 'edited_at'"); // edit feature
    $has_edited_at = $check_column && $check_column->num_rows > 0; // edit feature
    
    // edit feature: Build update query
    if ($has_edited_at) { // edit feature
        $update_parts = []; // edit feature
        $types = ""; // edit feature
        $params = []; // edit feature
        
        if (!empty($title)) { // edit feature
            $update_parts[] = "title = ?"; // edit feature
            $params[] = $title; // edit feature
            $types .= "s"; // edit feature
        } // edit feature
        
        if (!empty($body)) { // edit feature
            $update_parts[] = "body = ?"; // edit feature
            $params[] = $body; // edit feature
            $types .= "s"; // edit feature
        } // edit feature
        
        if (!empty($category)) { // edit feature
            $update_parts[] = "category = ?"; // edit feature
            $params[] = $category; // edit feature
            $types .= "s"; // edit feature
        } // edit feature
        
        $update_parts[] = "edited_at = NOW()"; // edit feature
        $update_parts[] = "is_edited = 1"; // edit feature
        
        $params[] = $blog_id; // edit feature
        $types .= "i"; // edit feature
        
        $sql = "UPDATE blogs SET " . implode(", ", $update_parts) . " WHERE id = ?"; // edit feature
        $update_stmt = $conn->prepare($sql); // edit feature
        $update_stmt->bind_param($types, ...$params); // edit feature
    } else { // edit feature
        $update_parts = []; // edit feature
        $types = ""; // edit feature
        $params = []; // edit feature
        
        if (!empty($title)) { // edit feature
            $update_parts[] = "title = ?"; // edit feature
            $params[] = $title; // edit feature
            $types .= "s"; // edit feature
        } // edit feature
        
        if (!empty($body)) { // edit feature
            $update_parts[] = "body = ?"; // edit feature
            $params[] = $body; // edit feature
            $types .= "s"; // edit feature
        } // edit feature
        
        if (!empty($category)) { // edit feature
            $update_parts[] = "category = ?"; // edit feature
            $params[] = $category; // edit feature
            $types .= "s"; // edit feature
        } // edit feature
        
        $params[] = $blog_id; // edit feature
        $types .= "i"; // edit feature
        
        $sql = "UPDATE blogs SET " . implode(", ", $update_parts) . " WHERE id = ?"; // edit feature
        $update_stmt = $conn->prepare($sql); // edit feature
        $update_stmt->bind_param($types, ...$params); // edit feature
    } // edit feature
    
    if ($update_stmt->execute()) { // edit feature
        error_log("✅ Blog edited: ID=$blog_id, user_id=$user_id"); // edit feature
        echo jsonResponse(true, 'Blog edited successfully', [ // edit feature
            'id' => $blog_id, // edit feature
            'is_edited' => true // edit feature
        ]); // edit feature
    } else { // edit feature
        error_log("❌ Failed to edit blog: " . $update_stmt->error); // edit feature
        http_response_code(500); // edit feature
        echo jsonResponse(false, 'Failed to edit blog: ' . $update_stmt->error); // edit feature
    } // edit feature
} // edit feature

function handleDeleteBlog($conn) {
    $user_id = intval($_POST['user_id'] ?? 0);
    $blog_id = intval($_POST['blog_id'] ?? 0);

    if (!$user_id || !$blog_id) {
        http_response_code(400);
        echo jsonResponse(false, 'user_id and blog_id are required');
        return;
    }

    $check_stmt = $conn->prepare("SELECT user_id, status FROM blogs WHERE id = ?");
    $check_stmt->bind_param("i", $blog_id);
    $check_stmt->execute();
    $check_result = $check_stmt->get_result();

    if ($check_result->num_rows === 0) {
        http_response_code(404);
        echo jsonResponse(false, 'Blog not found');
        return;
    }

    $blog_data = $check_result->fetch_assoc();

    if ($blog_data['user_id'] != $user_id) {
        http_response_code(403);
        echo jsonResponse(false, 'You can only delete your own blogs');
        return;
    }

    if ($blog_data['status'] === 'Deleted') {
        http_response_code(404);
        echo jsonResponse(false, 'Blog already deleted');
        return;
    }

    $delete_stmt = $conn->prepare("UPDATE blogs SET status = 'Deleted' WHERE id = ?");
    $delete_stmt->bind_param("i", $blog_id);

    if ($delete_stmt->execute()) {
        echo jsonResponse(true, 'Blog deleted successfully', ['id' => $blog_id]);
    } else {
        http_response_code(500);
        echo jsonResponse(false, 'Failed to delete blog: ' . $delete_stmt->error);
    }
}

$conn->close();
?>