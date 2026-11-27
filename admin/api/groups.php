<?php
/**
 * Groups API
 * Handles: List groups, Get group details, Join group, Create group
 */

require_once '../includes/db.php';
require_once '../includes/cors.php';
require_once 'auth-helper.php';

// Global error handler
set_error_handler(function($errno, $errstr, $errfile, $errline) {
    // This error code is not included in error_reporting
    if (!(error_reporting() & $errno)) {
        return false;
    }

    http_response_code(500);
    error_log("PHP Error: $errstr in $errfile on line $errline");
    echo jsonResponse(false, 'Server error occurred', [
        'error' => $errstr,
        'file' => $errfile,
        'line' => $errline,
        'code' => $errno
    ]);
    exit;
});

// Global exception handler
set_exception_handler(function($e) {
    http_response_code(500);
    error_log("PHP Exception: " . $e->getMessage() . " in " . $e->getFile() . " on line " . $e->getLine());
    echo jsonResponse(false, 'Server error occurred', [
        'error' => $e->getMessage(),
        'file' => $e->getFile(),
        'line' => $e->getLine()
    ]);
    exit;
});

header('Content-Type: application/json');

$method = $_SERVER['REQUEST_METHOD'];

// Get action from multiple sources (for multipart requests, $_POST is more reliable)
$action = '';
if (!empty($_POST['action'])) {
    $action = trim($_POST['action']);
} elseif (!empty($_GET['action'])) {
    $action = trim($_GET['action']);
} else {
    // Fallback: Parse from query string manually
    $queryString = $_SERVER['QUERY_STRING'] ?? '';
    if (preg_match('/action=([^&]+)/', $queryString, $matches)) {
        $action = trim($matches[1]);
    }
}

// Action parameter parsing (debug logging removed for production)

if ($method === 'OPTIONS') {
    http_response_code(200);
    exit;
}

switch ($action) {
    case 'join':
        handleJoinGroup($conn);
        break;
    case 'leave':
        handleLeaveGroup($conn);
        break;
    case 'remove-member':
        handleRemoveMember($conn);
        break;
    case 'members':
        handleGetGroupMembers($conn);
        break;
    case 'posts':
        if ($method === 'GET') {
            handleGetGroupPosts($conn);
        } elseif ($method === 'POST') {
            handleCreateGroupPost($conn);
        } else {
            http_response_code(405);
            echo jsonResponse(false, 'Method not allowed');
        }
        break;
    case 'posts-feed':
        if ($method === 'GET') {
            handleGetGroupPostsFeed($conn);
        } else {
            http_response_code(405);
            echo jsonResponse(false, 'Method not allowed');
        }
        break;
    case 'react':
        handleReactToPost($conn);
        break;
    case 'reactions':
        handleGetPostReactions($conn);
        break;
    case 'messages':
        if ($method === 'GET') {
            handleGetChatMessages($conn);
        } elseif ($method === 'POST') {
            handleSendChatMessage($conn);
        } else {
            http_response_code(405);
            echo jsonResponse(false, 'Method not allowed');
        }
        break;
    case 'edit-message': // edit feature
        handleEditChatMessage($conn); // edit feature
        break; // edit feature
    case 'edit-post': // edit feature
        handleEditGroupPost($conn); // edit feature
        break; // edit feature
    case 'delete-post':
        handleDeleteGroupPost($conn);
        break;
    case 'delete-message':
        handleDeleteChatMessage($conn);
        break;
    default:
        if ($method === 'GET') {
            handleGetGroups($conn);
        } elseif ($method === 'POST') {
            handleCreateGroup($conn);
        } else {
            http_response_code(405);
            echo jsonResponse(false, 'Method not allowed');
        }
        break;
}

function handleGetGroups($conn) {
    $group_id = $_GET['id'] ?? null;
    $category = $_GET['category'] ?? null;
    $user_id = $_GET['user_id'] ?? null; // Get groups user is member of
    $status = $_GET['status'] ?? 'Active';
    // Pagination limits: max 100 items, max offset 10000
    $limit = min(intval($_GET['limit'] ?? 20), 100);
    $offset = min(intval($_GET['offset'] ?? 0), 10000);
    
    if ($group_id) {
        // Get single group with members
        $group_id = intval($group_id);
        $stmt = $conn->prepare("
            SELECT g.*, u.name as creator_name, u.profile_photo as creator_photo
            FROM `groups` g
            LEFT JOIN users u ON g.created_by = u.id
            WHERE g.id = ?
        ");
        $stmt->bind_param("i", $group_id);
        $stmt->execute();
        $result = $stmt->get_result();
        
        if ($result->num_rows === 0) {
            http_response_code(404);
            echo jsonResponse(false, 'Group not found');
            return;
        }
        
        $group = $result->fetch_assoc();
        
        // Get members count
        $members_stmt = $conn->prepare("
            SELECT COUNT(*) as member_count 
            FROM group_members 
            WHERE group_id = ?
        ");
        $members_stmt->bind_param("i", $group_id);
        $members_stmt->execute();
        $members_result = $members_stmt->get_result();
        $member_count = $members_result->fetch_assoc();
        $group['member_count'] = intval($member_count['member_count']);
        
        echo jsonResponse(true, 'Group retrieved', $group);
    } else {
        // Get list of groups
        $sql = "SELECT g.*, u.name as creator_name,
                       (SELECT COUNT(*) FROM group_members WHERE group_id = g.id) as member_count
                FROM `groups` g
                LEFT JOIN users u ON g.created_by = u.id
                WHERE g.status = ?";
        $params = [$status];
        $types = "s";
        
        if ($category) {
            $sql .= " AND g.category = ?";
            $params[] = $category;
            $types .= "s";
        }
        
        if ($user_id) {
            // Get groups user is member of
            $sql = "SELECT g.*, u.name as creator_name,
                           (SELECT COUNT(*) FROM group_members WHERE group_id = g.id) as member_count,
                           gm.role as user_role
                    FROM `groups` g
                    LEFT JOIN users u ON g.created_by = u.id
                    JOIN group_members gm ON g.id = gm.group_id
                    WHERE g.status = ? AND gm.user_id = ?";
            $params = [$status, intval($user_id)];
            $types = "si";
        }
        
        $sql .= " ORDER BY g.created_at DESC LIMIT ? OFFSET ?";
        $params[] = $limit;
        $params[] = $offset;
        $types .= "ii";
        
        $stmt = $conn->prepare($sql);
        $stmt->bind_param($types, ...$params);
        $stmt->execute();
        $result = $stmt->get_result();
        
        $groups = [];
        while ($row = $result->fetch_assoc()) {
            $groups[] = $row;
        }
        
        echo jsonResponse(true, 'Groups retrieved', $groups);
    }
}

function handleCreateGroup($conn) {
    // Start transaction for atomicity
    $conn->begin_transaction();
    
    try {
        // Log all POST data for debugging
        error_log('handleCreateGroup - POST data: ' . print_r($_POST, true));
        error_log('handleCreateGroup - FILES data: ' . print_r($_FILES, true));
        error_log('handleCreateGroup - REQUEST_METHOD: ' . $_SERVER['REQUEST_METHOD']);
        error_log('handleCreateGroup - CONTENT_TYPE: ' . ($_SERVER['CONTENT_TYPE'] ?? 'not set'));
        
        // For multipart/form-data, $_POST should be populated, but sometimes it's not
        // Try to get values from $_POST first, then fallback to parsing if needed
        $user_id = intval($_POST['user_id'] ?? $_REQUEST['user_id'] ?? 0);
        $name = trim($_POST['name'] ?? $_POST['group_name'] ?? $_REQUEST['name'] ?? $_REQUEST['group_name'] ?? '');
        $description = trim($_POST['description'] ?? $_REQUEST['description'] ?? '');
        $category = trim($_POST['category'] ?? $_REQUEST['category'] ?? '');
        
        // If name is still empty, try to parse from raw input (for debugging)
        if (empty($name)) {
            $rawInput = file_get_contents('php://input');
            error_log('handleCreateGroup - Raw input (first 500 chars): ' . substr($rawInput, 0, 500));
            
            // Try to parse multipart data manually if $_POST is empty
            if (empty($_POST) && !empty($rawInput)) {
                // Parse multipart form data manually
                $boundary = null;
                if (isset($_SERVER['CONTENT_TYPE'])) {
                    preg_match('/boundary=(.*)$/i', $_SERVER['CONTENT_TYPE'], $matches);
                    if (isset($matches[1])) {
                        $boundary = $matches[1];
                    }
                }
                
                if ($boundary) {
                    $parts = explode('--' . $boundary, $rawInput);
                    foreach ($parts as $part) {
                        if (preg_match('/name="([^"]+)"/', $part, $nameMatch)) {
                            $fieldName = $nameMatch[1];
                            if (preg_match('/\r\n\r\n(.*?)\r\n--/s', $part, $valueMatch)) {
                                $fieldValue = trim($valueMatch[1]);
                                if ($fieldName === 'name' && empty($name)) {
                                    $name = $fieldValue;
                                } elseif ($fieldName === 'user_id' && $user_id == 0) {
                                    $user_id = intval($fieldValue);
                                } elseif ($fieldName === 'description' && empty($description)) {
                                    $description = $fieldValue;
                                } elseif ($fieldName === 'category' && $category === 'Love') {
                                    $category = $fieldValue;
                                }
                            }
                        }
                    }
                }
            }
        }
        
        error_log("Parsed values: user_id=$user_id, name='$name', description='$description', category='$category'");
        
        // Validate user_id
        if (!$user_id) {
            http_response_code(400);
            echo jsonResponse(false, 'user_id is required');
            $conn->rollback();
            return;
        }
        
        // Validate group name length (min 3, max 100 characters)
        if (empty($name)) {
            http_response_code(400);
            error_log('Group name validation failed - name is empty');
            echo jsonResponse(false, 'Group name is required');
            $conn->rollback();
            return;
        }
        
        $nameLength = mb_strlen($name, 'UTF-8');
        if ($nameLength < 3 || $nameLength > 100) {
            http_response_code(400);
            echo jsonResponse(false, 'Group name must be between 3 and 100 characters');
            $conn->rollback();
            return;
        }
        
        // Validate description length (max 1000 characters)
        $descriptionLength = mb_strlen($description, 'UTF-8');
        if ($descriptionLength > 1000) {
            http_response_code(400);
            echo jsonResponse(false, 'Description must not exceed 1000 characters');
            $conn->rollback();
            return;
        }
        // Sanitize inputs (XSS protection)
        $name = htmlspecialchars($name, ENT_QUOTES, 'UTF-8');
        $description = htmlspecialchars($description, ENT_QUOTES, 'UTF-8');
        
        // Verify user exists
        $user_stmt = $conn->prepare("SELECT id FROM users WHERE id = ? AND status = 'Active'");
        $user_stmt->bind_param("i", $user_id);
        $user_stmt->execute();
        if ($user_stmt->get_result()->num_rows === 0) {
            http_response_code(404);
            echo jsonResponse(false, 'User not found');
            $conn->rollback();
            return;
        }
        
        // Check for duplicate group name (case-insensitive)
        $duplicate_stmt = $conn->prepare("SELECT id FROM `groups` WHERE LOWER(name) = LOWER(?) AND status = 'Active'");
        $duplicate_stmt->bind_param("s", $name);
        $duplicate_stmt->execute();
        if ($duplicate_stmt->get_result()->num_rows > 0) {
            http_response_code(400);
            echo jsonResponse(false, 'A group with this name already exists');
            $conn->rollback();
            return;
        }
        
        // Handle group image upload if present
        $group_image = null;
        if (isset($_FILES['group_image']) && $_FILES['group_image']['error'] === UPLOAD_ERR_OK) {
            // File size validation (max 5MB)
            $maxFileSize = 5 * 1024 * 1024; // 5MB in bytes
            $fileSize = $_FILES['group_image']['size'];
            
            if ($fileSize > $maxFileSize) {
                http_response_code(400);
                echo jsonResponse(false, 'Image size must not exceed 5MB');
                $conn->rollback();
                return;
            }
            
            $target_dir = "../uploads/";
            if (!is_dir($target_dir)) {
                mkdir($target_dir, 0755, true);
            }
            
            $fileExtension = strtolower(pathinfo($_FILES['group_image']['name'], PATHINFO_EXTENSION));
            $allowedTypes = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
            
            // Validate MIME type for additional security
            $finfo = finfo_open(FILEINFO_MIME_TYPE);
            $mimeType = finfo_file($finfo, $_FILES['group_image']['tmp_name']);
            $allowedMimeTypes = ['image/jpeg', 'image/png', 'image/gif', 'image/webp'];
            
            if (in_array($fileExtension, $allowedTypes) && in_array($mimeType, $allowedMimeTypes)) {
                $fileName = 'group_' . time() . '_' . uniqid() . '.' . $fileExtension;
                $target_file = $target_dir . $fileName;
                
                if (move_uploaded_file($_FILES['group_image']['tmp_name'], $target_file)) {
                    $group_image = "uploads/" . $fileName;
                } else {
                    http_response_code(500);
                    echo jsonResponse(false, 'Failed to upload image');
                    $conn->rollback();
                    return;
                }
            } else {
                http_response_code(400);
                echo jsonResponse(false, 'Invalid file type. Allowed types: JPG, JPEG, PNG, GIF, WEBP');
                $conn->rollback();
                return;
            }
            finfo_close($finfo);
        }
        
        // Insert group
        $stmt = $conn->prepare("INSERT INTO `groups` (name, description, category, group_image, created_by, status) VALUES (?, ?, ?, ?, ?, 'Active')");
        $stmt->bind_param("ssssi", $name, $description, $category, $group_image, $user_id);
        
        if ($stmt->execute()) {
            $group_id = $stmt->insert_id;
            
            // Add creator as admin member
            $member_stmt = $conn->prepare("INSERT INTO group_members (group_id, user_id, role) VALUES (?, ?, 'Admin')");
            $member_stmt->bind_param("ii", $group_id, $user_id);
            
            if (!$member_stmt->execute()) {
                throw new Exception('Failed to add creator as admin');
            }
            
            // Commit transaction
            $conn->commit();
            echo jsonResponse(true, 'Group created successfully', ['id' => $group_id]);
        } else {
            throw new Exception('Failed to create group');
        }
    } catch (Exception $e) {
        $conn->rollback();
        http_response_code(500);
        // Log error internally, don't expose to user
        error_log("Group creation error: " . $e->getMessage());
        echo jsonResponse(false, 'Failed to create group. Please try again.');
    }
}

function handleJoinGroup($conn) {
    $user_id = intval($_POST['user_id'] ?? 0);
    $group_id = intval($_POST['group_id'] ?? 0);
    
    if (!$user_id || !$group_id) {
        http_response_code(400);
        echo jsonResponse(false, 'user_id and group_id are required');
        return;
    }
    
    // Check if group exists and is active
    $group_stmt = $conn->prepare("SELECT id, status FROM `groups` WHERE id = ?");
    $group_stmt->bind_param("i", $group_id);
    $group_stmt->execute();
    $group_result = $group_stmt->get_result();
    
    if ($group_result->num_rows === 0) {
        http_response_code(404);
        echo jsonResponse(false, 'Group not found');
        return;
    }
    
    $group = $group_result->fetch_assoc();
    if ($group['status'] !== 'Active') {
        http_response_code(403);
        echo jsonResponse(false, 'This group is not available');
        return;
    }
    
    // Check if already a member
    $check_stmt = $conn->prepare("SELECT id FROM group_members WHERE group_id = ? AND user_id = ?");
    $check_stmt->bind_param("ii", $group_id, $user_id);
    $check_stmt->execute();
    if ($check_stmt->get_result()->num_rows > 0) {
        http_response_code(400);
        echo jsonResponse(false, 'Already a member of this group');
        return;
    }
    
    // Add member
    $stmt = $conn->prepare("INSERT INTO group_members (group_id, user_id, role) VALUES (?, ?, 'Member')");
    $stmt->bind_param("ii", $group_id, $user_id);
    
    if ($stmt->execute()) {
        echo jsonResponse(true, 'Joined group successfully');
    } else {
        http_response_code(500);
        // Log error internally
        error_log("Join group error: " . $stmt->error);
        echo jsonResponse(false, 'Failed to join group. Please try again.');
    }
}

function handleRemoveMember($conn) {
    $requester_id = intval($_POST['user_id'] ?? 0);
    $group_id = intval($_POST['group_id'] ?? 0);
    $member_id = intval($_POST['member_id'] ?? 0);

    if (!$requester_id || !$group_id || !$member_id) {
        http_response_code(400);
        echo jsonResponse(false, 'user_id, group_id, and member_id are required');
        return;
    }

    if ($requester_id === $member_id) {
        http_response_code(400);
        echo jsonResponse(false, 'Use leave group to remove yourself');
        return;
    }

    $group_stmt = $conn->prepare("SELECT created_by FROM `groups` WHERE id = ? AND status = 'Active'");
    $group_stmt->bind_param("i", $group_id);
    $group_stmt->execute();
    $group_result = $group_stmt->get_result();

    if ($group_result->num_rows === 0) {
        http_response_code(404);
        echo jsonResponse(false, 'Group not found');
        return;
    }

    $group = $group_result->fetch_assoc();
    $owner_id = intval($group['created_by']);

    if ($requester_id !== $owner_id) {
        http_response_code(403);
        echo jsonResponse(false, 'Only the group owner can remove members');
        return;
    }

    if ($member_id === $owner_id) {
        http_response_code(403);
        echo jsonResponse(false, 'Cannot remove the group owner');
        return;
    }

    $member_stmt = $conn->prepare("SELECT role FROM group_members WHERE group_id = ? AND user_id = ?");
    $member_stmt->bind_param("ii", $group_id, $member_id);
    $member_stmt->execute();
    $member_result = $member_stmt->get_result();

    if ($member_result->num_rows === 0) {
        http_response_code(404);
        echo jsonResponse(false, 'User is not a member of this group');
        return;
    }

    $stmt = $conn->prepare("DELETE FROM group_members WHERE group_id = ? AND user_id = ?");
    $stmt->bind_param("ii", $group_id, $member_id);

    if ($stmt->execute() && $stmt->affected_rows > 0) {
        echo jsonResponse(true, 'Member removed successfully');
    } else {
        http_response_code(500);
        error_log("Remove member error: " . $stmt->error);
        echo jsonResponse(false, 'Failed to remove member. Please try again.');
    }
}

function handleLeaveGroup($conn) {
    $user_id = intval($_POST['user_id'] ?? 0);
    $group_id = intval($_POST['group_id'] ?? 0);
    
    if (!$user_id || !$group_id) {
        http_response_code(400);
        echo jsonResponse(false, 'user_id and group_id are required');
        return;
    }
    
    // Check if user is member and get their role
    $member_stmt = $conn->prepare("SELECT role FROM group_members WHERE group_id = ? AND user_id = ?");
    $member_stmt->bind_param("ii", $group_id, $user_id);
    $member_stmt->execute();
    $member_result = $member_stmt->get_result();
    
    if ($member_result->num_rows === 0) {
        http_response_code(404);
        echo jsonResponse(false, 'Not a member of this group');
        return;
    }
    
    $member = $member_result->fetch_assoc();
    $user_role = $member['role'];
    
    // If user is Admin, check if they are the last admin
    if ($user_role === 'Admin') {
        $admin_count_stmt = $conn->prepare("SELECT COUNT(*) as admin_count FROM group_members WHERE group_id = ? AND role = 'Admin'");
        $admin_count_stmt->bind_param("i", $group_id);
        $admin_count_stmt->execute();
        $admin_count_result = $admin_count_stmt->get_result();
        $admin_count = $admin_count_result->fetch_assoc()['admin_count'];
        
        if ($admin_count <= 1) {
            http_response_code(403);
            echo jsonResponse(false, 'Cannot leave group. You are the only admin. Please assign another admin first.');
            return;
        }
    }
    
    // Remove member
    $stmt = $conn->prepare("DELETE FROM group_members WHERE group_id = ? AND user_id = ?");
    $stmt->bind_param("ii", $group_id, $user_id);
    
    if ($stmt->execute() && $stmt->affected_rows > 0) {
        echo jsonResponse(true, 'Left group successfully');
    } else {
        http_response_code(500);
        // Log error internally
        error_log("Leave group error: " . $stmt->error);
        echo jsonResponse(false, 'Failed to leave group. Please try again.');
    }
}

function handleGetGroupMembers($conn) {
    $group_id = intval($_GET['group_id'] ?? 0);
    
    if (!$group_id) {
        http_response_code(400);
        echo jsonResponse(false, 'group_id is required');
        return;
    }
    
    $stmt = $conn->prepare("
        SELECT gm.*, u.name, u.profile_photo, u.email
        FROM group_members gm
        JOIN users u ON gm.user_id = u.id
        WHERE gm.group_id = ?
        ORDER BY gm.role DESC, gm.joined_at ASC
    ");
    $stmt->bind_param("i", $group_id);
    $stmt->execute();
    $result = $stmt->get_result();
    
    $members = [];
    while ($row = $result->fetch_assoc()) {
        $members[] = $row;
    }
    
    echo jsonResponse(true, 'Group members retrieved', $members);
}

function handleGetGroupPosts($conn) {
    $group_id = intval($_GET['group_id'] ?? 0);
    $user_id = intval($_GET['user_id'] ?? 0); // For checking reactions
    // Pagination limits: max 100 items, max offset 10000
    $limit = min(intval($_GET['limit'] ?? 20), 100);
    $offset = min(intval($_GET['offset'] ?? 0), 10000);
    
    if (!$group_id) {
        http_response_code(400);
        echo jsonResponse(false, 'group_id is required');
        return;
    }
    
    // Check if group_posts table exists
    $check_table = @$conn->query("SHOW TABLES LIKE 'group_posts'");
    if (!$check_table || $check_table->num_rows === 0) {
        http_response_code(501);
        echo jsonResponse(false, 'Group posts feature not available. Please run database migration.');
        return;
    }
    
    // Get posts with user info, comment count, and reaction counts
    $reaction_count_sql = "(SELECT COUNT(*) FROM group_post_reactions WHERE post_id = gp.id)";
    $user_reaction_sql = ($user_id > 0) ? "(SELECT emoji_code FROM group_post_reactions WHERE post_id = gp.id AND user_id = ? LIMIT 1)" : "NULL";
    
    if ($user_id > 0) {
        $stmt = $conn->prepare("
            SELECT gp.*, 
                   u.name as user_name, 
                   u.profile_photo,
                   $reaction_count_sql as reaction_count,
                   $user_reaction_sql as user_reaction,
                   (SELECT COUNT(*) FROM comments WHERE post_type = 'group_post' AND post_id = gp.id AND status = 'approved' AND is_deleted = 0) as comment_count
            FROM group_posts gp
            JOIN users u ON gp.user_id = u.id AND u.status != 'Deleted'
            WHERE gp.group_id = ? AND gp.status = 'Active'
            ORDER BY gp.created_at DESC
            LIMIT ? OFFSET ?
        ");
        $stmt->bind_param("iiii", $user_id, $group_id, $limit, $offset);
    } else {
        $stmt = $conn->prepare("
            SELECT gp.*, 
                   u.name as user_name, 
                   u.profile_photo,
                   $reaction_count_sql as reaction_count,
                   NULL as user_reaction,
                   (SELECT COUNT(*) FROM comments WHERE post_type = 'group_post' AND post_id = gp.id AND status = 'approved' AND is_deleted = 0) as comment_count
            FROM group_posts gp
            JOIN users u ON gp.user_id = u.id AND u.status != 'Deleted'
            WHERE gp.group_id = ? AND gp.status = 'Active'
            ORDER BY gp.created_at DESC
            LIMIT ? OFFSET ?
        ");
        $stmt->bind_param("iii", $group_id, $limit, $offset);
    }
    
    $stmt->execute();
    $result = $stmt->get_result();
    
    $posts = [];
    while ($row = $result->fetch_assoc()) {
        // Get reaction breakdown (count by emoji)
        $reaction_stmt = $conn->prepare("
            SELECT emoji_code, COUNT(*) as count
            FROM group_post_reactions
            WHERE post_id = ?
            GROUP BY emoji_code
        ");
        $reaction_stmt->bind_param("i", $row['id']);
        $reaction_stmt->execute();
        $reaction_result = $reaction_stmt->get_result();
        $reactions = [];
        while ($reaction_row = $reaction_result->fetch_assoc()) {
            $reactions[] = $reaction_row;
        }
        $row['reactions'] = $reactions;
        
        // Add base URL for images
        if ($row['image_path']) {
            $row['image_url'] = 'http://admin.fosmessenger.com/' . $row['image_path'];
        }
        
        $posts[] = $row;
    }
    
    echo jsonResponse(true, 'Group posts retrieved', $posts);
}

function handleGetGroupPostsFeed($conn) {
    $user_id = intval($_GET['user_id'] ?? 0);
    $limit = min(intval($_GET['limit'] ?? 10), 50);
    $offset = min(intval($_GET['offset'] ?? 0), 10000);

    if (!$user_id) {
        http_response_code(400);
        echo jsonResponse(false, 'user_id is required');
        return;
    }

    $check_table = @$conn->query("SHOW TABLES LIKE 'group_posts'");
    if (!$check_table || $check_table->num_rows === 0) {
        http_response_code(501);
        echo jsonResponse(false, 'Group posts feature not available. Please run database migration.');
        return;
    }

    $stmt = $conn->prepare("
        SELECT gp.*,
               u.name as user_name,
               u.profile_photo,
               g.name as group_name,
               (SELECT COUNT(*) FROM group_post_reactions WHERE post_id = gp.id) as reaction_count,
               (SELECT COUNT(*) FROM comments WHERE post_type = 'group_post' AND post_id = gp.id AND status = 'approved' AND is_deleted = 0) as comment_count
        FROM group_posts gp
        JOIN users u ON gp.user_id = u.id AND u.status != 'Deleted'
        JOIN `groups` g ON gp.group_id = g.id AND g.status = 'Active'
        JOIN group_members gm ON gm.group_id = g.id AND gm.user_id = ?
        WHERE gp.status = 'Active'
        ORDER BY gp.created_at DESC
        LIMIT ? OFFSET ?
    ");
    $stmt->bind_param("iii", $user_id, $limit, $offset);
    $stmt->execute();
    $result = $stmt->get_result();

    $posts = [];
    while ($row = $result->fetch_assoc()) {
        if ($row['image_path']) {
            $row['image_url'] = 'http://admin.fosmessenger.com/' . $row['image_path'];
        }
        $posts[] = $row;
    }

    echo jsonResponse(true, 'Group posts feed retrieved', $posts);
}

function handleCreateGroupPost($conn) {
    // Try to get values from $_POST first, then $_REQUEST
    $user_id = intval($_POST['user_id'] ?? $_REQUEST['user_id'] ?? 0);
    $group_id = intval($_POST['group_id'] ?? $_REQUEST['group_id'] ?? 0);
    $content = trim($_POST['content'] ?? $_REQUEST['content'] ?? '');
    $post_type = trim($_POST['post_type'] ?? $_REQUEST['post_type'] ?? 'text');
    $event_date = !empty($_POST['event_date']) ? $_POST['event_date'] : (!empty($_REQUEST['event_date']) ? $_REQUEST['event_date'] : null);
    
    // If critical fields are missing, try parsing raw input (for multipart/form-data)
    if (!$user_id || !$group_id) {
        $rawInput = file_get_contents('php://input');
        
        if (!empty($rawInput)) {
            $boundary = null;
            if (isset($_SERVER['CONTENT_TYPE'])) {
                if (preg_match('/boundary=(.*)$/i', $_SERVER['CONTENT_TYPE'], $matches)) {
                    $boundary = $matches[1];
                }
            }
            
            if ($boundary) {
                $parts = explode('--' . $boundary, $rawInput);
                foreach ($parts as $part) {
                    if (preg_match('/name="([^"]+)"/', $part, $nameMatch)) {
                        $fieldName = $nameMatch[1];
                        if (preg_match('/\r\n\r\n(.*?)\r\n--/s', $part, $valueMatch)) {
                            $fieldValue = trim($valueMatch[1]);
                            
                            if ($fieldName === 'user_id' && !$user_id) {
                                $user_id = intval($fieldValue);
                            } elseif ($fieldName === 'group_id' && !$group_id) {
                                $group_id = intval($fieldValue);
                            } elseif ($fieldName === 'content' && empty($content)) {
                                $content = $fieldValue;
                            } elseif ($fieldName === 'post_type' && $post_type === 'text') {
                                $post_type = $fieldValue;
                            } elseif ($fieldName === 'event_date' && empty($event_date)) {
                                $event_date = $fieldValue;
                            }
                        }
                    }
                }
            }
        }
    }
    
    if (!$user_id || !$group_id) {
        http_response_code(400);
        // Debug info
        $debug_info = [
            'post_user_id' => $_POST['user_id'] ?? 'null',
            'post_group_id' => $_POST['group_id'] ?? 'null',
            'parsed_user_id' => $user_id,
            'parsed_group_id' => $group_id
        ];
        error_log('handleCreateGroupPost failed: ' . json_encode($debug_info));
        echo jsonResponse(false, 'user_id and group_id are required');
        return;
    }
    
    // Sanitize content (XSS protection)
    $content = htmlspecialchars($content, ENT_QUOTES, 'UTF-8');
    
    if (empty($content)) {
        http_response_code(400);
        echo jsonResponse(false, 'Post content is required');
        return;
    }
    
    // Validate content length (max 5000 characters)
    $contentLength = mb_strlen($content, 'UTF-8');
    if ($contentLength > 5000) {
        http_response_code(400);
        echo jsonResponse(false, 'Post content must not exceed 5000 characters');
        return;
    }
    
    // ===== CONTENT MODERATION FOR GROUP POST =====
    require_once '../includes/ContentModerationService.php';
    
    $moderation_result = ContentModerationService::checkContent($content, $conn);
    
    switch ($moderation_result['action']) {
        case 'block':
            http_response_code(400);
            echo jsonResponse(false, 'Post content violates community guidelines.');
            return;
            
        case 'quarantine':
        case 'warn':
            $content = $moderation_result['sanitized_content'];
            break;
    }
    // ===== CONTENT MODERATION END =====
    
    // Check user role and status - only approved Bloggers can create posts
    $user_stmt = $conn->prepare("SELECT role, status FROM users WHERE id = ?");
    $user_stmt->bind_param("i", $user_id);
    $user_stmt->execute();
    $user_result = $user_stmt->get_result();
    
    if ($user_result->num_rows === 0) {
        http_response_code(404);
        echo jsonResponse(false, 'User not found');
        return;
    }
    
    $user = $user_result->fetch_assoc();
    $user_role = $user['role'];
    $user_status = $user['status'];
    
    // Check if user is approved Blogger (role=Blogger, status=Active)
    if ($user_role !== 'Blogger' || $user_status !== 'Active') {
        // If user has pending Blogger request (role=Blogger, status=Inactive)
        if ($user_role === 'Blogger' && $user_status !== 'Active') {
            http_response_code(403);
            echo jsonResponse(false, 'Waiting for approval from admin. You cannot create posts until your blogger request is approved.');
            return;
        }
        // If user is regular User, show message to become Blogger
        http_response_code(403);
        echo jsonResponse(false, 'Only approved bloggers can create posts. Please request to become a blogger.');
        return;
    }
    
    // Check if user is member of group
    $member_stmt = $conn->prepare("SELECT id FROM group_members WHERE group_id = ? AND user_id = ?");
    $member_stmt->bind_param("ii", $group_id, $user_id);
    $member_stmt->execute();
    if ($member_stmt->get_result()->num_rows === 0) {
        http_response_code(403);
        echo jsonResponse(false, 'You must be a member of this group to post');
        return;
    }
    
    // Check if group_posts table exists
    $check_table = @$conn->query("SHOW TABLES LIKE 'group_posts'");
    if (!$check_table || $check_table->num_rows === 0) {
        http_response_code(501);
        echo jsonResponse(false, 'Group posts feature not available. Please run database migration.');
        return;
    }
    
    // Handle image upload if present
    $image_path = null;
    if (isset($_FILES['image']) && $_FILES['image']['error'] === UPLOAD_ERR_OK) {
        // File size validation (max 5MB)
        $maxFileSize = 5 * 1024 * 1024; // 5MB in bytes
        $fileSize = $_FILES['image']['size'];
        
        if ($fileSize > $maxFileSize) {
            http_response_code(400);
            echo jsonResponse(false, 'Image size must not exceed 5MB');
            return;
        }
        
        $target_dir = "../uploads/";
        if (!is_dir($target_dir)) {
            mkdir($target_dir, 0755, true);
        }
        
        $fileExtension = strtolower(pathinfo($_FILES['image']['name'], PATHINFO_EXTENSION));
        $allowedTypes = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
        
        // Validate MIME type for additional security
        $finfo = finfo_open(FILEINFO_MIME_TYPE);
        $mimeType = finfo_file($finfo, $_FILES['image']['tmp_name']);
        $allowedMimeTypes = ['image/jpeg', 'image/png', 'image/gif', 'image/webp'];
        
        if (in_array($fileExtension, $allowedTypes) && in_array($mimeType, $allowedMimeTypes)) {
            $fileName = 'group_post_' . time() . '_' . uniqid() . '.' . $fileExtension;
            $target_file = $target_dir . $fileName;
            
            if (move_uploaded_file($_FILES['image']['tmp_name'], $target_file)) {
                $image_path = "uploads/" . $fileName;
            } else {
                http_response_code(500);
                echo jsonResponse(false, 'Failed to upload image');
                finfo_close($finfo);
                return;
            }
        } else {
            http_response_code(400);
            echo jsonResponse(false, 'Invalid file type. Allowed types: JPG, JPEG, PNG, GIF, WEBP');
            finfo_close($finfo);
            return;
        }
        finfo_close($finfo);
    }
    
    // Validate post_type
    $allowed_types = ['text', 'prayer', 'event', 'update'];
    if (!in_array($post_type, $allowed_types)) {
        $post_type = 'text';
    }
    
    // Insert post
    if ($event_date && $post_type === 'event') {
        $stmt = $conn->prepare("INSERT INTO group_posts (group_id, user_id, content, post_type, image_path, event_date, status) VALUES (?, ?, ?, ?, ?, ?, 'Active')");
        $stmt->bind_param("iissss", $group_id, $user_id, $content, $post_type, $image_path, $event_date);
    } else {
        $stmt = $conn->prepare("INSERT INTO group_posts (group_id, user_id, content, post_type, image_path, status) VALUES (?, ?, ?, ?, ?, 'Active')");
        $stmt->bind_param("iisss", $group_id, $user_id, $content, $post_type, $image_path);
    }
    
    if ($stmt->execute()) {
        $post_id = $stmt->insert_id;
        
        // Get created post with user info
        $post_stmt = $conn->prepare("
            SELECT gp.*, u.name as user_name, u.profile_photo
            FROM group_posts gp
            JOIN users u ON gp.user_id = u.id AND u.status != 'Deleted'
            WHERE gp.id = ? AND gp.status != 'Deleted'
        ");
        $post_stmt->bind_param("i", $post_id);
        $post_stmt->execute();
        $post_result = $post_stmt->get_result();
        $post = $post_result->fetch_assoc();
        
        if ($post['image_path']) {
            $post['image_url'] = 'https://admin.fosmessenger.com/' . $post['image_path'];
        }
        $post['reaction_count'] = 0;
        $post['comment_count'] = 0;
        $post['reactions'] = [];
        $post['user_reaction'] = null;
        
        echo jsonResponse(true, 'Post created successfully', $post);
    } else {
        http_response_code(500);
        echo jsonResponse(false, 'Failed to create post: ' . $stmt->error);
    }
}

function handleReactToPost($conn) {
    $user_id = intval($_POST['user_id'] ?? 0);
    $post_id = intval($_POST['post_id'] ?? 0);
    $emoji_code = trim($_POST['emoji_code'] ?? '');
    
    if (!$user_id || !$post_id || empty($emoji_code)) {
        http_response_code(400);
        echo jsonResponse(false, 'user_id, post_id, and emoji_code are required');
        return;
    }
    
    // Check if group_post_reactions table exists
    $check_table = @$conn->query("SHOW TABLES LIKE 'group_post_reactions'");
    if (!$check_table || $check_table->num_rows === 0) {
        http_response_code(501);
        echo jsonResponse(false, 'Reactions feature not available. Please run database migration.');
        return;
    }
    
    // Check if post exists and user is member of the group
    $post_stmt = $conn->prepare("
        SELECT gp.id, gp.group_id 
        FROM group_posts gp
        WHERE gp.id = ? AND gp.status = 'Active'
    ");
    $post_stmt->bind_param("i", $post_id);
    $post_stmt->execute();
    $post_result = $post_stmt->get_result();
    if ($post_result->num_rows === 0) {
        http_response_code(404);
        echo jsonResponse(false, 'Post not found');
        return;
    }
    $post_data = $post_result->fetch_assoc();
    
    // Check if user is member
    $member_stmt = $conn->prepare("SELECT id FROM group_members WHERE group_id = ? AND user_id = ?");
    $member_stmt->bind_param("ii", $post_data['group_id'], $user_id);
    $member_stmt->execute();
    if ($member_stmt->get_result()->num_rows === 0) {
        http_response_code(403);
        echo jsonResponse(false, 'You must be a member of this group to react');
        return;
    }
    
    // Check if already reacted with this emoji
    $check_stmt = $conn->prepare("SELECT id FROM group_post_reactions WHERE post_id = ? AND user_id = ? AND emoji_code = ?");
    $check_stmt->bind_param("iis", $post_id, $user_id, $emoji_code);
    $check_stmt->execute();
    
    if ($check_stmt->get_result()->num_rows > 0) {
        // Remove reaction (toggle off)
        $stmt = $conn->prepare("DELETE FROM group_post_reactions WHERE post_id = ? AND user_id = ? AND emoji_code = ?");
        $stmt->bind_param("iis", $post_id, $user_id, $emoji_code);
        $stmt->execute();
        
        // Get updated reaction counts
        $count_stmt = $conn->prepare("
            SELECT emoji_code, COUNT(*) as count
            FROM group_post_reactions
            WHERE post_id = ?
            GROUP BY emoji_code
        ");
        $count_stmt->bind_param("i", $post_id);
        $count_stmt->execute();
        $count_result = $count_stmt->get_result();
        $reactions = [];
        while ($row = $count_result->fetch_assoc()) {
            $reactions[] = $row;
        }
        
        echo jsonResponse(true, 'Reaction removed', [
            'reacted' => false,
            'emoji_code' => $emoji_code,
            'reactions' => $reactions
        ]);
    } else {
        // Add reaction
        // Get emoji_id if emoji_code matches an emoji in emojis table
        $emoji_id = null;
        $emoji_stmt = $conn->prepare("SELECT id FROM emojis WHERE emoji_code = ? OR name = ? LIMIT 1");
        $emoji_stmt->bind_param("ss", $emoji_code, $emoji_code);
        $emoji_stmt->execute();
        $emoji_result = $emoji_stmt->get_result();
        if ($emoji_result->num_rows > 0) {
            $emoji_data = $emoji_result->fetch_assoc();
            $emoji_id = $emoji_data['id'];
        }
        
        $stmt = $conn->prepare("INSERT INTO group_post_reactions (post_id, user_id, emoji_id, emoji_code) VALUES (?, ?, ?, ?)");
        $stmt->bind_param("iiis", $post_id, $user_id, $emoji_id, $emoji_code);
        $stmt->execute();
        
        // Get updated reaction counts
        $count_stmt = $conn->prepare("
            SELECT emoji_code, COUNT(*) as count
            FROM group_post_reactions
            WHERE post_id = ?
            GROUP BY emoji_code
        ");
        $count_stmt->bind_param("i", $post_id);
        $count_stmt->execute();
        $count_result = $count_stmt->get_result();
        $reactions = [];
        while ($row = $count_result->fetch_assoc()) {
            $reactions[] = $row;
        }
        
        echo jsonResponse(true, 'Reaction added', [
            'reacted' => true,
            'emoji_code' => $emoji_code,
            'reactions' => $reactions
        ]);
    }
}

function handleGetPostReactions($conn) {
    $post_id = intval($_GET['post_id'] ?? 0);
    
    if (!$post_id) {
        http_response_code(400);
        echo jsonResponse(false, 'post_id is required');
        return;
    }
    
    // Check if group_post_reactions table exists
    $check_table = @$conn->query("SHOW TABLES LIKE 'group_post_reactions'");
    if (!$check_table || $check_table->num_rows === 0) {
        http_response_code(501);
        echo jsonResponse(false, 'Reactions feature not available. Please run database migration.');
        return;
    }
    
    $stmt = $conn->prepare("
        SELECT gpr.*, u.name as user_name, u.profile_photo
        FROM group_post_reactions gpr
        JOIN users u ON gpr.user_id = u.id
        WHERE gpr.post_id = ?
        ORDER BY gpr.created_at DESC
    ");
    $stmt->bind_param("i", $post_id);
    $stmt->execute();
    $result = $stmt->get_result();
    
    $reactions = [];
    while ($row = $result->fetch_assoc()) {
        $reactions[] = $row;
    }
    
    echo jsonResponse(true, 'Post reactions retrieved', $reactions);
}

/**
 * Get Chat Messages (Real-time chat like WhatsApp)
 */
function handleGetChatMessages($conn) {
    // Helper function to generate a unique ID for messages within messages_list
    function generateUniqueMessageId() {
        return uniqid('', true); // Generates a unique ID based on the current time in microseconds
    }
    $group_id = intval($_GET['group_id'] ?? 0);
    $user_id = intval($_GET['user_id'] ?? 0);
    // Pagination limits: max 100 items, max offset 10000
    $limit = min(intval($_GET['limit'] ?? 50), 100);
    $offset = min(intval($_GET['offset'] ?? 0), 10000);
    $last_message_id = intval($_GET['last_message_id'] ?? 0); // For pagination
    
    // Debug logging
    error_log("handleGetChatMessages called: group_id=$group_id, user_id=$user_id, limit=$limit, offset=$offset");
    
    if (!$group_id) {
        error_log("ERROR: group_id is missing");
        http_response_code(400);
        echo jsonResponse(false, 'group_id is required');
        return;
    }
    
    // Check if user is member (but don't block if user_id is 0 - allow viewing for non-logged users)
    if ($user_id > 0) {
        $member_stmt = $conn->prepare("SELECT id FROM group_members WHERE group_id = ? AND user_id = ?");
        $member_stmt->bind_param("ii", $group_id, $user_id);
        $member_stmt->execute();
        $member_result = $member_stmt->get_result();
        $is_member = $member_result->num_rows > 0;
        error_log("Membership check: user_id=$user_id, group_id=$group_id, is_member=" . ($is_member ? 'YES' : 'NO'));
        
        if (!$is_member) {
            error_log("ERROR: User $user_id is not a member of group $group_id");
            http_response_code(403);
            echo jsonResponse(false, 'You must be a member of this group to view messages');
            return;
        }
    } else {
        error_log("WARNING: user_id is 0, skipping membership check");
    }
    
    // Check if group_chat_messages table exists, create if not
    $check_table = @$conn->query("SHOW TABLES LIKE 'group_chat_messages'");
    if (!$check_table || $check_table->num_rows === 0) {
        $create_table = "CREATE TABLE IF NOT EXISTS group_chat_messages (
            id INT AUTO_INCREMENT PRIMARY KEY,
            group_id INT NOT NULL,
            user_id INT NOT NULL,
            message TEXT NOT NULL,
            message_type VARCHAR(20) DEFAULT 'text',
            file_path VARCHAR(500) NULL,
            messages_list TEXT NULL,
            status VARCHAR(20) DEFAULT 'active',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
            INDEX idx_group_created (group_id, created_at),
            INDEX idx_status (status)
        )";
        $conn->query($create_table);
    } else {
        $check_column = @$conn->query("SHOW COLUMNS FROM group_chat_messages LIKE 'messages_list'");
        if (!$check_column || $check_column->num_rows === 0) {
            $conn->query("ALTER TABLE group_chat_messages ADD COLUMN messages_list TEXT NULL AFTER file_path");
        }
        $check_status_column = @$conn->query("SHOW COLUMNS FROM group_chat_messages LIKE 'status'");
        if (!$check_status_column || $check_status_column->num_rows === 0) {
            $conn->query("ALTER TABLE group_chat_messages ADD COLUMN status VARCHAR(20) DEFAULT 'active' AFTER messages_list");
        }
    }
    
    // Check if we need to fetch new messages (after last_message_id) or older messages (before last_message_id)
    $after_id = intval($_GET['after_id'] ?? 0); // For syncing new messages
    
    if ($after_id > 0) {
        $stmt = $conn->prepare("
            SELECT m.*, u.name as user_name, u.profile_photo
            FROM group_chat_messages m
            JOIN users u ON m.user_id = u.id AND u.status != 'Deleted'
            WHERE m.group_id = ? AND m.status = 'active' AND m.id > ?
            ORDER BY m.created_at ASC
            LIMIT ?
        ");
        error_log("DEBUG: handleGetChatMessages - Fetching NEW messages. Params: group_id=$group_id, after_id=$after_id, limit=$limit");
        $stmt->bind_param("iii", $group_id, $after_id, $limit);
    } elseif ($last_message_id > 0) {
        $stmt = $conn->prepare("
            SELECT m.*, u.name as user_name, u.profile_photo
            FROM group_chat_messages m
            JOIN users u ON m.user_id = u.id AND u.status != 'Deleted'
            WHERE m.group_id = ? AND m.status = 'active' AND m.id < ?
            ORDER BY m.created_at DESC
            LIMIT ? OFFSET ?
        ");
        error_log("DEBUG: handleGetChatMessages - Loading older messages. Params: group_id=$group_id, last_message_id=$last_message_id, limit=$limit, offset=$offset");
        $stmt->bind_param("iiii", $group_id, $last_message_id, $limit, $offset);
    } else {
        $stmt = $conn->prepare("
            SELECT m.*, u.name as user_name, u.profile_photo
            FROM group_chat_messages m
            JOIN users u ON m.user_id = u.id AND u.status != 'Deleted'
            WHERE m.group_id = ? AND m.status = 'active'
            ORDER BY m.created_at ASC
            LIMIT ? OFFSET ?
        ");
        error_log("DEBUG: handleGetChatMessages - Loading latest messages. Params: group_id=$group_id, limit=$limit, offset=$offset");
        $stmt->bind_param("iii", $group_id, $limit, $offset);
    }
    
    $stmt->execute();
    $result = $stmt->get_result();
    
    // Debug: Check how many rows were found
    $row_count = $result->num_rows;
    error_log("SQL query returned $row_count rows for group_id: $group_id");
    
    $messages = [];
    $user_ids_found = [];
    while ($row = $result->fetch_assoc()) {
        // Ensure message field is always a string (never null)
        if ($row['message'] === null || $row['message'] === false) {
            $row['message'] = '';
        } else {
            // Ensure it's a string type
            $row['message'] = (string)$row['message'];
        }
        // Ensure group_id is always an integer (not string)
        $row['group_id'] = intval($row['group_id']);
        $row['user_id'] = intval($row['user_id']);
        $row['id'] = intval($row['id']);
        
        // Ensure message_type is always a string
        if ($row['message_type'] === null) {
            $row['message_type'] = 'text';
        } else {
            $row['message_type'] = (string)$row['message_type'];
        }
        
        // Parse messages_list JSON if it exists
        if (!empty($row['messages_list'])) {
            $messages_list = json_decode($row['messages_list'], true);
            if (is_array($messages_list)) {
                // Process each message in the list to add file_url if needed
                foreach ($messages_list as &$msg_item) {
                    if (isset($msg_item['file_url']) && $msg_item['file_url'] && !str_starts_with($msg_item['file_url'], 'http')) {
                        $msg_item['file_url'] = 'https://admin.fosmessenger.com/' . $msg_item['file_url'];
                    }
                }
                $row['messages_list'] = $messages_list;
            } else {
                $row['messages_list'] = [];
            }
        } else {
            // If no messages_list, create one from the single message (backward compatibility)
            $row['messages_list'] = [
                [
                    'msg_id' => generateUniqueMessageId(), // Generate a unique ID for this individual message
                    'text' => $row['message'],
                    'time' => $row['created_at'],
                    'message_type' => $row['message_type'],
                    'file_url' => $row['file_path'] ? 'https://admin.fosmessenger.com/' . $row['file_path'] : null
                ]
            ];
        }
        
        // Track user IDs
        $user_ids_found[] = $row['user_id'];
        
        // Add base URL for images (for backward compatibility)
        if ($row['file_path']) {
            $row['file_url'] = 'https://admin.fosmessenger.com/' . $row['file_path'];
        }
        
        // Calculate latest message time from messages_list for sorting
        $latest_message_time = $row['created_at']; // Default to row's created_at
        if (!empty($row['messages_list']) && is_array($row['messages_list'])) {
            $latest_time = null;
            foreach ($row['messages_list'] as $msg_item) {
                if (isset($msg_item['time'])) {
                    $msg_time = strtotime($msg_item['time']);
                    if ($msg_time && (!$latest_time || $msg_time > $latest_time)) {
                        $latest_time = $msg_time;
                        $latest_message_time = $msg_item['time'];
                    }
                }
            }
        }
        $row['_sort_time'] = $latest_message_time; // Temporary field for sorting
        
        $messages[] = $row;
    }
    
    // Sort messages by latest message time from messages_list (chronological order)
    usort($messages, function($a, $b) {
        $time_a = strtotime($a['_sort_time'] ?? $a['created_at']);
        $time_b = strtotime($b['_sort_time'] ?? $b['created_at']);
        return $time_a <=> $time_b; // Ascending order (oldest first)
    });
    
    // Remove temporary sort field
    foreach ($messages as &$msg) {
        unset($msg['_sort_time']);
    }
    
    // Reverse to show oldest first (like WhatsApp) - but not for new messages (after_id)
    // New messages are already in ASC order, so don't reverse them
    if ($after_id == 0) {
        // Already sorted oldest first, no need to reverse
    }
    
    // Debug: Log message count and user distribution
    error_log("Retrieved " . count($messages) . " messages for group_id: $group_id");
    if (count($messages) > 0) {
        $unique_user_ids = array_unique($user_ids_found);
        error_log("Messages from user_ids: " . implode(', ', $unique_user_ids));
        error_log("Total unique users: " . count($unique_user_ids));
        error_log("Requesting user_id: $user_id");
        error_log("First message: id=" . $messages[0]['id'] . ", group_id=" . $messages[0]['group_id'] . ", user_id=" . $messages[0]['user_id'] . ", text_length=" . strlen($messages[0]['message']));
        error_log("First message data: " . json_encode($messages[0]));
        
        // Check if we're only getting messages from requesting user
        if (count($unique_user_ids) == 1 && $unique_user_ids[0] == $user_id) {
            error_log("⚠️ WARNING: Only messages from requesting user found! This suggests a filtering issue.");
            // Check database directly
            $check_all_stmt = $conn->prepare("SELECT user_id, COUNT(*) as count FROM group_chat_messages WHERE group_id = ? GROUP BY user_id");
            $check_all_stmt->bind_param("i", $group_id);
            $check_all_stmt->execute();
            $check_all_result = $check_all_stmt->get_result();
            error_log("All user_ids with messages in DB for group $group_id:");
            while ($check_row = $check_all_result->fetch_assoc()) {
                error_log("   user_id: " . $check_row['user_id'] . ", message_count: " . $check_row['count']);
            }
        }
    } else {
        error_log("WARNING: No messages found for group_id: $group_id");
        // Check if group exists and has any messages
        $check_stmt = $conn->prepare("SELECT COUNT(*) as total, GROUP_CONCAT(DISTINCT user_id) as user_ids FROM group_chat_messages WHERE group_id = ?");
        $check_stmt->bind_param("i", $group_id);
        $check_stmt->execute();
        $check_result = $check_stmt->get_result();
        $check_row = $check_result->fetch_assoc();
        error_log("Total messages in DB for group $group_id: " . $check_row['total']);
        error_log("User IDs who sent messages: " . ($check_row['user_ids'] ?? 'none'));
    }
    
    // Ensure response is properly formatted
    $response = jsonResponse(true, 'Chat messages retrieved', $messages);
    error_log("Response length: " . strlen($response));
    error_log("Response preview: " . substr($response, 0, 500));
    
    // Debug: Log full response structure
    $response_array = [
        'success' => true,
        'message' => 'Chat messages retrieved',
        'data' => $messages
    ];
    error_log("Response structure: success=" . ($response_array['success'] ? 'true' : 'false') . ", message_count=" . count($messages));
    if (count($messages) > 0) {
        error_log("Sample message structure: " . json_encode($messages[0]));
    }
    
    echo $response;
}

/**
 * Send Chat Message (Real-time chat like WhatsApp)
 */
function handleSendChatMessage($conn) {
    // Helper function to generate a unique ID for messages within messages_list
    function generateUniqueMessageId() {
        return uniqid('', true); // Generates a unique ID based on the current time in microseconds
    }
    // Try to get values from $_POST first, then $_REQUEST
    $user_id = intval($_POST['user_id'] ?? $_REQUEST['user_id'] ?? 0);
    $group_id = intval($_POST['group_id'] ?? $_REQUEST['group_id'] ?? 0);
    $message = trim($_POST['message'] ?? $_REQUEST['message'] ?? '');
    $message_type = trim($_POST['message_type'] ?? $_REQUEST['message_type'] ?? 'text');
    
    // If critical fields are missing, try parsing raw input (for multipart/form-data)
    if (!$user_id || !$group_id) {
        $rawInput = file_get_contents('php://input');
        
        if (!empty($rawInput)) {
            $boundary = null;
            if (isset($_SERVER['CONTENT_TYPE'])) {
                if (preg_match('/boundary=(.*)$/i', $_SERVER['CONTENT_TYPE'], $matches)) {
                    $boundary = $matches[1];
                }
            }
            
            if ($boundary) {
                $parts = explode('--' . $boundary, $rawInput);
                foreach ($parts as $part) {
                    if (preg_match('/name="([^"]+)"/', $part, $nameMatch)) {
                        $fieldName = $nameMatch[1];
                        if (preg_match('/\r\n\r\n(.*?)\r\n--/s', $part, $valueMatch)) {
                            $fieldValue = trim($valueMatch[1]);
                            
                            if ($fieldName === 'user_id' && !$user_id) {
                                $user_id = intval($fieldValue);
                            } elseif ($fieldName === 'group_id' && !$group_id) {
                                $group_id = intval($fieldValue);
                            } elseif ($fieldName === 'message' && empty($message)) {
                                $message = $fieldValue;
                            } elseif ($fieldName === 'message_type' && $message_type === 'text') {
                                $message_type = $fieldValue;
                            }
                        }
                    }
                }
            }
        }
    }
    
    if (!$user_id || !$group_id) {
        http_response_code(400);
        // Debug info to help identify why it failed
        $debug_info = [
            'post_user_id' => $_POST['user_id'] ?? 'null',
            'post_group_id' => $_POST['group_id'] ?? 'null',
            'request_user_id' => $_REQUEST['user_id'] ?? 'null',
            'request_group_id' => $_REQUEST['group_id'] ?? 'null',
            'parsed_user_id' => $user_id,
            'parsed_group_id' => $group_id,
            'content_type' => $_SERVER['CONTENT_TYPE'] ?? 'null'
        ];
        error_log('handleSendChatMessage failed: ' . json_encode($debug_info));
        echo jsonResponse(false, 'user_id and group_id are required');
        return;
    }
    
    // Sanitize message (XSS protection)
    $message = htmlspecialchars($message, ENT_QUOTES, 'UTF-8');
    
    if (empty($message) && $message_type === 'text') {
        http_response_code(400);
        echo jsonResponse(false, 'Message is required');
        return;
    }
    
    // Validate message length (max 2000 characters)
    $messageLength = mb_strlen($message, 'UTF-8');
    if ($messageLength > 2000) {
        http_response_code(400);
        echo jsonResponse(false, 'Message must not exceed 2000 characters');
        return;
    }
    
    // ===== CONTENT MODERATION FOR CHAT MESSAGE =====
    if ($message_type === 'text' && !empty($message)) {
        require_once '../includes/ContentModerationService.php';
        
        $moderation_result = ContentModerationService::checkContent($message, $conn);
        
        switch ($moderation_result['action']) {
            case 'block':
                http_response_code(400);
                echo jsonResponse(false, 'Message violates community guidelines.');
                return;
                
            case 'quarantine':
            case 'warn':
                $message = $moderation_result['sanitized_content'];
                break;
        }
    }
    // ===== CONTENT MODERATION END =====
    
    // Check if user is member
    $member_stmt = $conn->prepare("SELECT id FROM group_members WHERE group_id = ? AND user_id = ?");
    $member_stmt->bind_param("ii", $group_id, $user_id);
    $member_stmt->execute();
    if ($member_stmt->get_result()->num_rows === 0) {
        http_response_code(403);
        echo jsonResponse(false, 'You must be a member of this group');
        return;
    }
    
    // Check if group_chat_messages table exists, create if not
    $check_table = @$conn->query("SHOW TABLES LIKE 'group_chat_messages'");
    if (!$check_table || $check_table->num_rows === 0) {
        $create_table = "CREATE TABLE IF NOT EXISTS group_chat_messages (
            id INT AUTO_INCREMENT PRIMARY KEY,
            group_id INT NOT NULL,
            user_id INT NOT NULL,
            message TEXT NOT NULL,
            message_type VARCHAR(20) DEFAULT 'text',
            file_path VARCHAR(500) NULL,
            messages_list TEXT NULL,
            status VARCHAR(20) DEFAULT 'active',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
            INDEX idx_group_created (group_id, created_at),
            INDEX idx_status (status)
        )";
        $conn->query($create_table);
    } else {
        $check_type_column = @$conn->query("SHOW COLUMNS FROM group_chat_messages LIKE 'message_type'");
        if (!$check_type_column || $check_type_column->num_rows === 0) {
            $conn->query("ALTER TABLE group_chat_messages ADD COLUMN message_type VARCHAR(20) DEFAULT 'text' AFTER message");
        }
        $check_column = @$conn->query("SHOW COLUMNS FROM group_chat_messages LIKE 'messages_list'");
        if (!$check_column || $check_column->num_rows === 0) {
            $conn->query("ALTER TABLE group_chat_messages ADD COLUMN messages_list TEXT NULL AFTER file_path");
        }
        $check_status_column = @$conn->query("SHOW COLUMNS FROM group_chat_messages LIKE 'status'");
        if (!$check_status_column || $check_status_column->num_rows === 0) {
            $conn->query("ALTER TABLE group_chat_messages ADD COLUMN status VARCHAR(20) DEFAULT 'active' AFTER messages_list");
        }
    }
    
    // Handle file upload if present
    $file_path = null;
    if (isset($_FILES['file']) && $_FILES['file']['error'] === UPLOAD_ERR_OK) {
        // File size validation (max 10MB for files, 5MB for images)
        $fileSize = $_FILES['file']['size'];
        $fileExtension = strtolower(pathinfo($_FILES['file']['name'], PATHINFO_EXTENSION));
        $isImage = in_array($fileExtension, ['jpg', 'jpeg', 'png', 'gif', 'webp']);
        $maxFileSize = $isImage ? (5 * 1024 * 1024) : (10 * 1024 * 1024); // 5MB for images, 10MB for files
        
        if ($fileSize > $maxFileSize) {
            http_response_code(400);
            echo jsonResponse(false, 'File size must not exceed ' . ($isImage ? '5MB' : '10MB'));
            return;
        }
        
        $target_dir = "../uploads/";
        if (!is_dir($target_dir)) {
            mkdir($target_dir, 0755, true);
        }
        
        $allowedTypes = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'mp4', 'pdf', 'doc', 'docx'];
        
        // Validate MIME type for additional security
        $finfo = finfo_open(FILEINFO_MIME_TYPE);
        $mimeType = finfo_file($finfo, $_FILES['file']['tmp_name']);
        $allowedMimeTypes = [
            'image/jpeg', 'image/png', 'image/gif', 'image/webp',
            'video/mp4', 'application/pdf', 'application/msword', 
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
        ];
        
        if (in_array($fileExtension, $allowedTypes) && in_array($mimeType, $allowedMimeTypes)) {
            $fileName = 'chat_' . time() . '_' . uniqid() . '.' . $fileExtension;
            $target_file = $target_dir . $fileName;
            
            if (move_uploaded_file($_FILES['file']['tmp_name'], $target_file)) {
                $file_path = "uploads/" . $fileName;
                $message_type = $isImage ? 'image' : 'file';
            } else {
                http_response_code(500);
                echo jsonResponse(false, 'Failed to upload file');
                finfo_close($finfo);
                return;
            }
        } else {
            http_response_code(400);
            echo jsonResponse(false, 'Invalid file type');
            finfo_close($finfo);
            return;
        }
        finfo_close($finfo);
    }
    
    // Ensure message is not empty for text messages (should already be validated, but double-check)
    if ($message_type === 'text' && empty($message)) {
        http_response_code(400);
        echo jsonResponse(false, 'Message text cannot be empty for text messages');
        return;
    }
    
    // For non-text messages (image/file), allow empty message text
    // But ensure it's at least an empty string, not NULL
    if ($message === null) {
        $message = '';
    }
    
    // Check if there's already a row for this user in this group (for grouping - one row per user)
    $check_user_row = $conn->prepare("
        SELECT id, user_id, message, message_type, file_path, messages_list, created_at 
        FROM group_chat_messages 
        WHERE group_id = ? AND user_id = ? 
        ORDER BY created_at DESC, id DESC 
        LIMIT 1
    ");
    $check_user_row->bind_param("ii", $group_id, $user_id);
    $check_user_row->execute();
    $user_row_result = $check_user_row->get_result();
    $user_row = $user_row_result->fetch_assoc();
    
    $should_group = false;
    $group_row_id = null;
    $existing_messages_list = [];
    
    if ($user_row) {
        // Legacy support: we could migrate old grouped rows here if needed.
        // For now, always insert a new row per message to ensure
        // real-time chat and full history work correctly.
        $should_group = false;
        $group_row_id = null;
        $existing_messages_list = [];
    }
    
    if ($should_group && $group_row_id) {
        // Add new message to existing group's messages_list
        $new_message_item = [
            'msg_id' => generateUniqueMessageId(), // Generate a unique ID for this individual message
            'text' => $message,
            'time' => date('Y-m-d H:i:s'),
            'message_type' => $message_type,
            'file_url' => $file_path ? 'https://admin.fosmessenger.com/' . $file_path : null
        ];
        
        $existing_messages_list[] = $new_message_item;
        $messages_list_json = json_encode($existing_messages_list, JSON_UNESCAPED_SLASHES);
        
        // Update the existing row with new message in messages_list
        // Also update the message field with the latest message text (for backward compatibility)
        // Update created_at to latest message time for proper sorting
        $latest_time = date('Y-m-d H:i:s');
        
        // Check if updated_at column exists
        $check_updated_at = @$conn->query("SHOW COLUMNS FROM group_chat_messages LIKE 'updated_at'");
        $has_updated_at = $check_updated_at && $check_updated_at->num_rows > 0;
        
        if ($has_updated_at) {
            $update_stmt = $conn->prepare("
                UPDATE group_chat_messages 
                SET message = ?, messages_list = ?, created_at = ?, updated_at = CURRENT_TIMESTAMP 
                WHERE id = ?
            ");
            $update_stmt->bind_param("sssi", $message, $messages_list_json, $latest_time, $group_row_id);
        } else {
            $update_stmt = $conn->prepare("
                UPDATE group_chat_messages 
                SET message = ?, messages_list = ?, created_at = ? 
                WHERE id = ?
            ");
            $update_stmt->bind_param("sssi", $message, $messages_list_json, $latest_time, $group_row_id);
        }
        
        if ($update_stmt->execute()) {
            // Get the updated row
            $msg_stmt = $conn->prepare("
                SELECT m.*, u.name as user_name, u.profile_photo
                FROM group_chat_messages m
                JOIN users u ON m.user_id = u.id
                WHERE m.id = ?
            ");
            $msg_stmt->bind_param("i", $group_row_id);
            $msg_stmt->execute();
            $msg_result = $msg_stmt->get_result();
            $msg_data = $msg_result->fetch_assoc();
            $message_id = $group_row_id;
        } else {
            // If update fails, fall back to inserting new row
            $should_group = false;
        }
    }
    
    if (!$should_group) {
        // Insert new message row (different user or first message)
        $stmt = $conn->prepare("INSERT INTO group_chat_messages (group_id, user_id, message, message_type, file_path, messages_list) VALUES (?, ?, ?, ?, ?, NULL)");
        $stmt->bind_param("iisss", $group_id, $user_id, $message, $message_type, $file_path);
        
        if ($stmt->execute()) {
            $message_id = $stmt->insert_id;
            
            $updated_messages_list = [
                [
                    'msg_id' => generateUniqueMessageId(), // Generate a unique ID for this individual message
                    'text' => $message,
                    'time' => date('Y-m-d H:i:s'),
                    'message_type' => $message_type,
                    'file_url' => $file_path ? 'https://admin.fosmessenger.com/' . $file_path : null
                ]
            ];
            $messages_list_json_updated = json_encode($updated_messages_list, JSON_UNESCAPED_SLASHES);

            // Update messages_list with actual msg_id
            $update_msg_list = $conn->prepare("
                UPDATE group_chat_messages 
                SET messages_list = ? 
                WHERE id = ?
            ");
            $update_msg_list->bind_param("si", $messages_list_json_updated, $message_id);
            $update_msg_list->execute();
            
            // Get created message with user info
            $msg_stmt = $conn->prepare("
                SELECT m.*, u.name as user_name, u.profile_photo
                FROM group_chat_messages m
                JOIN users u ON m.user_id = u.id
                WHERE m.id = ?
            ");
            $msg_stmt->bind_param("i", $message_id);
            $msg_stmt->execute();
            $msg_result = $msg_stmt->get_result();
            $msg_data = $msg_result->fetch_assoc();
        } else {
            http_response_code(500);
            echo jsonResponse(false, 'Failed to send message');
            return;
        }
    } else {
        // Already got msg_data from update query above
        // Update the last message's msg_id in messages_list
        $last_item_index = count($existing_messages_list) - 1;
        $new_msg_id = $group_row_id; // Use the group row id
        
        // Get the latest message_id from messages_list to use as msg_id
        // Actually, we need to track individual message IDs differently
        // For now, use the row id as msg_id for the last item
        $updated_messages_list = $existing_messages_list;
        if (isset($updated_messages_list[$last_item_index])) {
            $updated_messages_list[$last_item_index]['msg_id'] = $new_msg_id;
        }
        $messages_list_json = json_encode($updated_messages_list, JSON_UNESCAPED_SLASHES);
        
        $update_msg_list = $conn->prepare("
            UPDATE group_chat_messages 
            SET messages_list = ? 
            WHERE id = ?
        ");
        $update_msg_list->bind_param("si", $messages_list_json, $group_row_id);
        $update_msg_list->execute();
        
        // Re-fetch to get updated data
        $msg_stmt = $conn->prepare("
            SELECT m.*, u.name as user_name, u.profile_photo
            FROM group_chat_messages m
            JOIN users u ON m.user_id = u.id
            WHERE m.id = ?
        ");
        $msg_stmt->bind_param("i", $group_row_id);
        $msg_stmt->execute();
        $msg_result = $msg_stmt->get_result();
        $msg_data = $msg_result->fetch_assoc();
    }
    
    if (isset($msg_data) && $msg_data) {
        // Ensure message field is always a string (never null)
        if ($msg_data['message'] === null || $msg_data['message'] === false) {
            $msg_data['message'] = '';
        } else {
            // Ensure it's a string type
            $msg_data['message'] = (string)$msg_data['message'];
        }
        
        // Ensure message_type is always a string
        if ($msg_data['message_type'] === null) {
            $msg_data['message_type'] = 'text';
        } else {
            $msg_data['message_type'] = (string)$msg_data['message_type'];
        }
        
        // Ensure IDs are integers (not strings)
        $msg_data['group_id'] = intval($msg_data['group_id']);
        $msg_data['user_id'] = intval($msg_data['user_id']);
        $msg_data['id'] = intval($msg_data['id']);
        
        // Parse messages_list JSON if it exists
        if (!empty($msg_data['messages_list'])) {
            $messages_list = json_decode($msg_data['messages_list'], true);
            if (is_array($messages_list)) {
                // Process each message in the list to add file_url if needed
                foreach ($messages_list as &$msg_item) {
                    if (isset($msg_item['file_url']) && $msg_item['file_url'] && !str_starts_with($msg_item['file_url'], 'http')) {
                        $msg_item['file_url'] = 'https://admin.fosmessenger.com/' . $msg_item['file_url'];
                    }
                }
                $msg_data['messages_list'] = $messages_list;
            } else {
                $msg_data['messages_list'] = [];
            }
        } else {
            // If no messages_list, create one from the single message (backward compatibility)
            $msg_data['messages_list'] = [
                [
                    'msg_id' => $msg_data['id'],
                    'text' => $msg_data['message'],
                    'time' => $msg_data['created_at'],
                    'message_type' => $msg_data['message_type'],
                    'file_url' => $msg_data['file_path'] ? 'https://admin.fosmessenger.com/' . $msg_data['file_path'] : null
                ]
            ];
        }
        
        if ($msg_data['file_path']) {
            $msg_data['file_url'] = 'https://admin.fosmessenger.com/' . $msg_data['file_path'];
        }
        
        // Send push notifications to other group members
        require_once '../includes/notification_service.php';
        
        // EULA/Blocking Check: Don't notify users who have blocked the sender
        // Check if user_blocks table exists first
        $check_blocks_table = $conn->query("SHOW TABLES LIKE 'user_blocks'");
        if ($check_blocks_table && $check_blocks_table->num_rows > 0) {
            // Select members who are NOT in the list of people who blocked this sender
            // ub.user_id is the blocker, ub.blocked_user_id is the blocked person (sender)
            $members_stmt = $conn->prepare("
                SELECT gm.user_id 
                FROM group_members gm
                WHERE gm.group_id = ? 
                AND gm.user_id != ?
                AND NOT EXISTS (
                    SELECT 1 FROM user_blocks ub 
                    WHERE ub.user_id = gm.user_id 
                    AND ub.blocked_user_id = ?
                )
            ");
            $members_stmt->bind_param("iii", $group_id, $user_id, $user_id);
        } else {
            $members_stmt = $conn->prepare("SELECT user_id FROM group_members WHERE group_id = ? AND user_id != ?");
            $members_stmt->bind_param("ii", $group_id, $user_id);
        }

        $members_stmt->execute();
        $members_result = $members_stmt->get_result();
        
        $user_stmt = $conn->prepare("SELECT name FROM users WHERE id = ?");
        $user_stmt->bind_param("i", $user_id);
        $user_stmt->execute();
        $user_result = $user_stmt->get_result();
        $sender = $user_result->fetch_assoc();
        $sender_name = $sender['name'] ?? 'Someone';
        
        // Send notifications to other group members (non-blocking)
        // If notification fails, don't fail the entire message send
        while ($member = $members_result->fetch_assoc()) {
            try {
                @createNotification(
                    $member['user_id'],
                    'group_message',
                    'New message in group',
                    $sender_name . ': ' . (strlen($message) > 50 ? substr($message, 0, 50) . '...' : $message),
                    '',
                    ['group_id' => $group_id, 'message_id' => $message_id]
                );
            } catch (Exception $e) {
                // Log but don't fail - notification is optional
                error_log("Failed to send notification to user {$member['user_id']}: " . $e->getMessage());
            }
        }
        
        $new_message_data = end($msg_data['messages_list']);
        if (is_array($new_message_data)) {
            if (!isset($new_message_data['message']) || $new_message_data['message'] === null || $new_message_data['message'] === '') {
                if (isset($new_message_data['text']) && $new_message_data['text'] !== null && $new_message_data['text'] !== '') {
                    $new_message_data['message'] = $new_message_data['text'];
                } else {
                    $new_message_data['message'] = '';
                }
            }
            if (!isset($new_message_data['created_at']) || $new_message_data['created_at'] === null || $new_message_data['created_at'] === '') {
                if (isset($new_message_data['time']) && $new_message_data['time'] !== null && $new_message_data['time'] !== '') {
                    $new_message_data['created_at'] = $new_message_data['time'];
                } else {
                    $new_message_data['created_at'] = date('Y-m-d H:i:s');
                }
            }
        }
        echo jsonResponse(true, 'Message sent successfully', $new_message_data);
    } else {
        http_response_code(500);
        // Log error internally
        error_log("Send message error: " . $stmt->error);
        echo jsonResponse(false, 'Failed to send message. Please try again.');
    }
}

// edit feature: Handle edit chat message request with 15-minute window
function handleEditChatMessage($conn) { // edit feature
    $user_id = intval($_POST['user_id'] ?? 0); // edit feature
    $message_id = intval($_POST['message_id'] ?? 0); // edit feature
    $message = trim($_POST['message'] ?? ''); // edit feature
    $group_id = intval($_POST['group_id'] ?? 0); // edit feature
    
    // edit feature: Log incoming request
    error_log("📥 Edit Chat Message Request: user_id=$user_id, message_id=$message_id, group_id=$group_id"); // edit feature
    
    // edit feature: Validation
    if (!$user_id || !$message_id || empty($message)) { // edit feature
        http_response_code(400); // edit feature
        echo jsonResponse(false, 'user_id, message_id, and message are required'); // edit feature
        return; // edit feature
    } // edit feature
    
    // edit feature: Content moderation check
    require_once '../includes/ContentModerationService.php'; // edit feature
    $moderation_result = ContentModerationService::checkContent($message, $conn); // edit feature
    
    // edit feature: Handle moderation result
    switch ($moderation_result['action']) { // edit feature
        case 'block': // edit feature
            http_response_code(400); // edit feature
            echo jsonResponse(false, 'Message violates community guidelines.'); // edit feature
            return; // edit feature
        case 'quarantine': // edit feature
            http_response_code(400); // edit feature
            echo jsonResponse(false, 'Message cannot be edited due to content policy.'); // edit feature
            return; // edit feature
        case 'warn': // edit feature
            $message = $moderation_result['sanitized_content']; // edit feature
            break; // edit feature
        case 'allow': // edit feature
        default: // edit feature
            break; // edit feature
    } // edit feature
    
    // edit feature: Verify user owns the message
    $check_stmt = $conn->prepare("SELECT user_id, created_at FROM group_chat_messages WHERE id = ?"); // edit feature
    $check_stmt->bind_param("i", $message_id); // edit feature
    $check_stmt->execute(); // edit feature
    $check_result = $check_stmt->get_result(); // edit feature
    
    if ($check_result->num_rows === 0) { // edit feature
        http_response_code(404); // edit feature
        echo jsonResponse(false, 'Message not found'); // edit feature
        return; // edit feature
    } // edit feature
    
    $message_data = $check_result->fetch_assoc(); // edit feature
    
    // edit feature: Check if user owns the message
    if ($message_data['user_id'] != $user_id) { // edit feature
        http_response_code(403); // edit feature
        echo jsonResponse(false, 'You can only edit your own messages'); // edit feature
        return; // edit feature
    } // edit feature
    
    // edit feature: Check if message is within 15-minute window
    $created_at = strtotime($message_data['created_at']); // edit feature
    $now = time(); // edit feature
    $time_diff_minutes = ($now - $created_at) / 60; // edit feature
    
    if ($time_diff_minutes > 15) { // edit feature
        http_response_code(403); // edit feature
        echo jsonResponse(false, 'Messages can only be edited within 15 minutes of sending'); // edit feature
        return; // edit feature
    } // edit feature
    
    // edit feature: Check if edited_at column exists
    $check_column = $conn->query("SHOW COLUMNS FROM group_chat_messages LIKE 'edited_at'"); // edit feature
    $has_edited_at = $check_column && $check_column->num_rows > 0; // edit feature
    
    // edit feature: Sanitize message
    $message = htmlspecialchars($message, ENT_QUOTES, 'UTF-8'); // edit feature
    
    // edit feature: Build update query
    if ($has_edited_at) { // edit feature
        $update_stmt = $conn->prepare("UPDATE group_chat_messages SET message = ?, edited_at = NOW(), is_edited = 1 WHERE id = ?"); // edit feature
        $update_stmt->bind_param("si", $message, $message_id); // edit feature
    } else { // edit feature
        $update_stmt = $conn->prepare("UPDATE group_chat_messages SET message = ? WHERE id = ?"); // edit feature
        $update_stmt->bind_param("si", $message, $message_id); // edit feature
    } // edit feature
    
    if ($update_stmt->execute()) { // edit feature
        error_log("✅ Chat message edited: ID=$message_id, user_id=$user_id"); // edit feature
        echo jsonResponse(true, 'Message edited successfully', [ // edit feature
            'id' => $message_id, // edit feature
            'message' => $message, // edit feature
            'is_edited' => true // edit feature
        ]); // edit feature
    } else { // edit feature
        error_log("❌ Failed to edit message: " . $update_stmt->error); // edit feature
        http_response_code(500); // edit feature
        echo jsonResponse(false, 'Failed to edit message: ' . $update_stmt->error); // edit feature
    } // edit feature
} // edit feature

// edit feature: Handle edit group post with 15-minute window
function handleEditGroupPost($conn) { // edit feature
    $user_id = intval($_POST['user_id'] ?? 0); // edit feature
    $post_id = intval($_POST['post_id'] ?? 0); // edit feature
    $content = trim($_POST['content'] ?? ''); // edit feature
    $title = trim($_POST['title'] ?? ''); // edit feature
    
    // edit feature: Log incoming request
    error_log("📥 Edit Group Post Request: user_id=$user_id, post_id=$post_id"); // edit feature
    
    // edit feature: Validation
    if (!$user_id || !$post_id) { // edit feature
        http_response_code(400); // edit feature
        echo jsonResponse(false, 'user_id and post_id are required'); // edit feature
        return; // edit feature
    } // edit feature
    
    // edit feature: Content moderation check
    require_once '../includes/ContentModerationService.php'; // edit feature
    
    // edit feature: Moderate content if provided
    if (!empty($content)) { // edit feature
        $moderation_result = ContentModerationService::checkContent($content, $conn); // edit feature
        switch ($moderation_result['action']) { // edit feature
            case 'block': // edit feature
                http_response_code(400); // edit feature
                echo jsonResponse(false, 'Post content violates community guidelines.'); // edit feature
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
    
    // edit feature: Moderate title if provided
    if (!empty($title)) { // edit feature
        $moderation_result = ContentModerationService::checkContent($title, $conn); // edit feature
        switch ($moderation_result['action']) { // edit feature
            case 'block': // edit feature
                http_response_code(400); // edit feature
                echo jsonResponse(false, 'Post title violates community guidelines.'); // edit feature
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
    
    // edit feature: Verify user owns the group post
    $check_stmt = $conn->prepare("SELECT user_id, created_at FROM group_posts WHERE id = ?"); // edit feature
    $check_stmt->bind_param("i", $post_id); // edit feature
    $check_stmt->execute(); // edit feature
    $check_result = $check_stmt->get_result(); // edit feature
    
    if ($check_result->num_rows === 0) { // edit feature
        http_response_code(404); // edit feature
        echo jsonResponse(false, 'Group post not found'); // edit feature
        return; // edit feature
    } // edit feature
    
    $post_data = $check_result->fetch_assoc(); // edit feature
    
    // edit feature: Check if user owns the group post
    if ($post_data['user_id'] != $user_id) { // edit feature
        http_response_code(403); // edit feature
        echo jsonResponse(false, 'You can only edit your own group posts'); // edit feature
        return; // edit feature
    } // edit feature
    
    // edit feature: Check if group post is within 15-minute window
    $created_at = strtotime($post_data['created_at']); // edit feature
    $now = time(); // edit feature
    $time_diff_minutes = ($now - $created_at) / 60; // edit feature
    
    if ($time_diff_minutes > 15) { // edit feature
        http_response_code(403); // edit feature
        echo jsonResponse(false, 'Group posts can only be edited within 15 minutes of posting'); // edit feature
        return; // edit feature
    } // edit feature
    
    // edit feature: Check if edited_at column exists
    $check_column = $conn->query("SHOW COLUMNS FROM group_posts LIKE 'edited_at'"); // edit feature
    $has_edited_at = $check_column && $check_column->num_rows > 0; // edit feature
    
    // edit feature: Build update query
    $update_parts = []; // edit feature
    $types = ""; // edit feature
    $params = []; // edit feature
    
    if (!empty($content)) { // edit feature
        $update_parts[] = "content = ?"; // edit feature
        $params[] = $content; // edit feature
        $types .= "s"; // edit feature
    } // edit feature
    
    if (!empty($title)) { // edit feature
        $update_parts[] = "title = ?"; // edit feature
        $params[] = $title; // edit feature
        $types .= "s"; // edit feature
    } // edit feature
    
    if ($has_edited_at) { // edit feature
        $update_parts[] = "edited_at = NOW()"; // edit feature
        $update_parts[] = "is_edited = 1"; // edit feature
    } // edit feature
    
    $params[] = $post_id; // edit feature
    $types .= "i"; // edit feature
    
    $sql = "UPDATE group_posts SET " . implode(", ", $update_parts) . " WHERE id = ?"; // edit feature
    $update_stmt = $conn->prepare($sql); // edit feature
    $update_stmt->bind_param($types, ...$params); // edit feature
    
    if ($update_stmt->execute()) { // edit feature
        error_log("✅ Group post edited: ID=$post_id, user_id=$user_id"); // edit feature
        echo jsonResponse(true, 'Group post edited successfully', [ // edit feature
            'id' => $post_id, // edit feature
            'is_edited' => true // edit feature
        ]); // edit feature
    } else { // edit feature
        error_log("❌ Failed to edit group post: " . $update_stmt->error); // edit feature
        http_response_code(500); // edit feature
        echo jsonResponse(false, 'Failed to edit group post: ' . $update_stmt->error); // edit feature
    } // edit feature
} // edit feature

function handleDeleteGroupPost($conn) {
    $user_id = intval($_POST['user_id'] ?? 0);
    $post_id = intval($_POST['post_id'] ?? 0);

    if (!$user_id || !$post_id) {
        http_response_code(400);
        echo jsonResponse(false, 'user_id and post_id are required');
        return;
    }

    $check_stmt = $conn->prepare("SELECT user_id, status FROM group_posts WHERE id = ?");
    $check_stmt->bind_param("i", $post_id);
    $check_stmt->execute();
    $check_result = $check_stmt->get_result();

    if ($check_result->num_rows === 0) {
        http_response_code(404);
        echo jsonResponse(false, 'Group post not found');
        return;
    }

    $post_data = $check_result->fetch_assoc();

    if ($post_data['user_id'] != $user_id) {
        http_response_code(403);
        echo jsonResponse(false, 'You can only delete your own group posts');
        return;
    }

    if ($post_data['status'] === 'Deleted') {
        http_response_code(404);
        echo jsonResponse(false, 'Group post already deleted');
        return;
    }

    $delete_stmt = $conn->prepare("UPDATE group_posts SET status = 'Deleted' WHERE id = ?");
    $delete_stmt->bind_param("i", $post_id);

    if ($delete_stmt->execute()) {
        echo jsonResponse(true, 'Group post deleted successfully', ['id' => $post_id]);
    } else {
        http_response_code(500);
        echo jsonResponse(false, 'Failed to delete group post: ' . $delete_stmt->error);
    }
}

function handleDeleteChatMessage($conn) {
    $user_id = intval($_POST['user_id'] ?? 0);
    $message_id = intval($_POST['message_id'] ?? 0);

    if (!$user_id || !$message_id) {
        http_response_code(400);
        echo jsonResponse(false, 'user_id and message_id are required');
        return;
    }

    $check_stmt = $conn->prepare("SELECT user_id, status FROM group_chat_messages WHERE id = ?");
    $check_stmt->bind_param("i", $message_id);
    $check_stmt->execute();
    $check_result = $check_stmt->get_result();

    if ($check_result->num_rows === 0) {
        http_response_code(404);
        echo jsonResponse(false, 'Message not found');
        return;
    }

    $message_data = $check_result->fetch_assoc();

    if ($message_data['user_id'] != $user_id) {
        http_response_code(403);
        echo jsonResponse(false, 'You can only delete your own messages');
        return;
    }

    if ($message_data['status'] === 'deleted') {
        http_response_code(404);
        echo jsonResponse(false, 'Message already deleted');
        return;
    }

    $delete_stmt = $conn->prepare("UPDATE group_chat_messages SET status = 'deleted' WHERE id = ?");
    $delete_stmt->bind_param("i", $message_id);

    if ($delete_stmt->execute()) {
        echo jsonResponse(true, 'Message deleted successfully', ['id' => $message_id]);
    } else {
        http_response_code(500);
        echo jsonResponse(false, 'Failed to delete message: ' . $delete_stmt->error);
    }
}

$conn->close();
?>