<?php
/**
 * Prayer Requests API
 * Handles: Create prayer request, List prayers, Get prayer details, Respond to prayer
 */

// Start output buffering to prevent any output before JSON
if (ob_get_level() == 0) {
    ob_start();
}

// Suppress display of errors but still log them for debugging
error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);
// Use default PHP error log (usually in server error log)
// ini_set('error_log', __DIR__ . '/../logs/php_errors.log');

require_once '../includes/db.php';
require_once '../includes/cors.php';
require_once 'auth-helper.php';

// Clear any output that might have been generated
while (ob_get_level() > 0) {
    ob_end_clean();
}
ob_start();

// Set JSON header
if (!headers_sent()) {
    header('Content-Type: application/json; charset=utf-8');
    header('Cache-Control: no-cache, must-revalidate');
}

// Check database connection
if (!isset($conn)) {
    error_log("ERROR: \$conn variable is not set");
    http_response_code(500);
    if (ob_get_level() > 0) ob_clean();
    if (!headers_sent()) {
        header('Content-Type: application/json; charset=utf-8');
    }
    echo jsonResponse(false, 'Database connection not initialized');
    if (ob_get_level() > 0) ob_end_flush();
    exit;
}

if (isset($db_connection_error) && $db_connection_error) {
    error_log("ERROR: Database connection error: " . $db_connection_error);
    http_response_code(500);
    if (ob_get_level() > 0) ob_clean();
    if (!headers_sent()) {
        header('Content-Type: application/json; charset=utf-8');
    }
    echo jsonResponse(false, 'Database connection failed: ' . $db_connection_error);
    if (ob_get_level() > 0) ob_end_flush();
    exit;
}

if (isset($conn->connect_error) && $conn->connect_error) {
    error_log("ERROR: mysqli connect_error: " . $conn->connect_error);
    http_response_code(500);
    if (ob_get_level() > 0) ob_clean();
    if (!headers_sent()) {
        header('Content-Type: application/json; charset=utf-8');
    }
    echo jsonResponse(false, 'Database connection failed: ' . $conn->connect_error);
    if (ob_get_level() > 0) ob_end_flush();
    exit;
}

// Test connection
if (!$conn->ping()) {
    error_log("ERROR: Database connection ping failed");
    http_response_code(500);
    if (ob_get_level() > 0) ob_clean();
    if (!headers_sent()) {
        header('Content-Type: application/json; charset=utf-8');
    }
    echo jsonResponse(false, 'Database connection is not active');
    if (ob_get_level() > 0) ob_end_flush();
    exit;
}

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'OPTIONS') {
    http_response_code(200);
    exit;
}

try {
    switch ($method) {
        case 'GET':
            handleGetPrayers($conn);
            break;
        case 'POST':
            $action = $_POST['action'] ?? 'create'; // edit feature
            if ($action === 'edit') { // edit feature
                handleEditPrayer($conn); // edit feature
            } elseif ($action === 'delete') {
                handleDeletePrayer($conn);
            } else { // edit feature
                handleCreatePrayer($conn);
            }
            break;
        default:
            http_response_code(405);
            echo jsonResponse(false, 'Method not allowed');
            if (ob_get_level() > 0) ob_end_flush();
            exit;
    }
} catch (Exception $e) {
    // Catch any unexpected errors and return proper JSON response
    http_response_code(500);
    if (ob_get_level() > 0) ob_clean();
    if (!headers_sent()) {
        header('Content-Type: application/json; charset=utf-8');
    }
    // Log detailed error for debugging
    $errorDetails = "Prayers API Error: " . $e->getMessage() . "\n";
    $errorDetails .= "File: " . $e->getFile() . "\n";
    $errorDetails .= "Line: " . $e->getLine() . "\n";
    $errorDetails .= "Stack Trace: " . $e->getTraceAsString() . "\n";
    error_log($errorDetails);
    echo jsonResponse(false, 'Server error. Please try again later.');
    if (ob_get_level() > 0) ob_end_flush();
    exit;
} catch (Error $e) {
    // Catch PHP 7+ errors (fatal errors, type errors, etc.)
    http_response_code(500);
    if (ob_get_level() > 0) ob_clean();
    if (!headers_sent()) {
        header('Content-Type: application/json; charset=utf-8');
    }
    // Log detailed error for debugging
    $errorDetails = "Prayers API Fatal Error: " . $e->getMessage() . "\n";
    $errorDetails .= "File: " . $e->getFile() . "\n";
    $errorDetails .= "Line: " . $e->getLine() . "\n";
    $errorDetails .= "Stack Trace: " . $e->getTraceAsString() . "\n";
    error_log($errorDetails);
    echo jsonResponse(false, 'Server error. Please try again later.');
    if (ob_get_level() > 0) ob_end_flush();
    exit;
}

function handleGetPrayers($conn) {
    try {
        $prayer_id = $_GET['id'] ?? null;
        $category = $_GET['category'] ?? null;
        $status = $_GET['status'] ?? 'Approved'; // Only show approved by default
        $user_id = $_GET['user_id'] ?? null;
        $limit = intval($_GET['limit'] ?? 20);
        $offset = intval($_GET['offset'] ?? 0);
        
        $current_user_id = intval($_GET['current_user_id'] ?? 0);
        
        // Check if is_deleted column exists in comments table
        $check_is_deleted = $conn->query("SHOW COLUMNS FROM comments LIKE 'is_deleted'");
        $has_is_deleted = $check_is_deleted && $check_is_deleted->num_rows > 0;
        
        // Log request for debugging
        error_log("handleGetPrayers called: prayer_id=$prayer_id, status=$status, category=$category, user_id=$user_id, limit=$limit, offset=$offset, has_is_deleted=$has_is_deleted");
    
    if ($prayer_id) {
        // ... (single prayer logic remains same)
        // Get single prayer with responses
        $prayer_id = intval($prayer_id);
        $stmt = $conn->prepare("
            SELECT pr.*, u.name as user_name, u.profile_photo
            FROM prayer_requests pr
            JOIN users u ON pr.user_id = u.id AND u.status != 'Deleted'
            WHERE pr.id = ? AND pr.status != 'Deleted'
        ");
        $stmt->bind_param("i", $prayer_id);
        
        if (!$stmt->execute()) {
            http_response_code(500);
            if (ob_get_level() > 0) ob_clean();
            if (!headers_sent()) {
                header('Content-Type: application/json; charset=utf-8');
            }
            echo jsonResponse(false, 'Database error: ' . $stmt->error);
            if (ob_get_level() > 0) ob_end_flush();
            exit;
        }
        
        $result = $stmt->get_result();
        
        if ($result->num_rows === 0) {
            http_response_code(404);
            if (ob_get_level() > 0) ob_clean();
            if (!headers_sent()) {
                header('Content-Type: application/json; charset=utf-8');
            }
            echo jsonResponse(false, 'Prayer request not found');
            if (ob_get_level() > 0) ob_end_flush();
            exit;
        }
        
        $prayer = $result->fetch_assoc();
        
        // Get responses (comments on this prayer)
        $comments_where = "c.post_type = 'prayer' AND c.post_id = ? AND c.status = 'approved'";
        if ($has_is_deleted) {
            $comments_where .= " AND c.is_deleted = 0";
        }
        
        // FILTER BLOCKED USERS FROM COMMENTS
        if ($current_user_id) {
            // Check if user_blocks table exists
            $check_blocks = $conn->query("SHOW TABLES LIKE 'user_blocks'");
            if ($check_blocks->num_rows > 0) {
                $comments_where .= " AND c.user_id NOT IN (SELECT blocked_user_id FROM user_blocks WHERE user_id = $current_user_id)";
            }
        }
        
        $comments_stmt = $conn->prepare("
            SELECT c.*, u.name as user_name, u.profile_photo
            FROM comments c
            JOIN users u ON c.user_id = u.id AND u.status != 'Deleted'
            WHERE $comments_where
            ORDER BY c.created_at ASC
        ");
        $comments_stmt->bind_param("i", $prayer_id);
        
        if (!$comments_stmt->execute()) {
            // If comments query fails, just return prayer without responses
            $prayer['responses'] = [];
            if (ob_get_level() > 0) ob_clean();
            if (!headers_sent()) {
                header('Content-Type: application/json; charset=utf-8');
            }
            echo jsonResponse(true, 'Prayer request retrieved', $prayer);
            if (ob_get_level() > 0) ob_end_flush();
            exit;
        }
        
        $comments_result = $comments_stmt->get_result();
        $responses = [];
        while ($comment = $comments_result->fetch_assoc()) {
            $responses[] = $comment;
        }
        $prayer['responses'] = $responses;
        
        if (ob_get_level() > 0) ob_clean();
        if (!headers_sent()) {
            header('Content-Type: application/json; charset=utf-8');
        }
        echo jsonResponse(true, 'Prayer request retrieved', $prayer);
        if (ob_get_level() > 0) ob_end_flush();
        exit;
    } else {
        // Get list of prayers
        // First check if tables exist
        $check_tables = $conn->query("SHOW TABLES LIKE 'prayer_requests'");
        if (!$check_tables || $check_tables->num_rows === 0) {
            error_log("ERROR: prayer_requests table does not exist");
            http_response_code(500);
            if (ob_get_level() > 0) ob_clean();
            if (!headers_sent()) {
                header('Content-Type: application/json; charset=utf-8');
            }
            echo jsonResponse(false, 'Database table not found. Please contact administrator.');
            if (ob_get_level() > 0) ob_end_flush();
            exit;
        }
        
        // Build response_count subquery based on whether is_deleted column exists
        $response_count_where = "post_type = 'prayer' AND post_id = pr.id AND status = 'approved'";
        if ($has_is_deleted) {
            $response_count_where .= " AND is_deleted = 0";
        }
        
        $sql = "SELECT pr.*, u.name as user_name, u.profile_photo,
                       (SELECT COUNT(*) FROM comments WHERE $response_count_where) as response_count
                FROM prayer_requests pr
                JOIN users u ON pr.user_id = u.id AND u.status != 'Deleted'
                WHERE pr.status != 'Deleted'";
                
        $params = [];
        $types = "";
        
        // FILTER BLOCKED USERS
        if ($current_user_id) {
            // Check if user_blocks table exists
            $check_blocks = $conn->query("SHOW TABLES LIKE 'user_blocks'");
            if ($check_blocks->num_rows > 0) {
                // We use subquery for blocked users, but need to bind the user_id
                $sql .= " AND pr.user_id NOT IN (SELECT blocked_user_id FROM user_blocks WHERE user_id = ?)";
                $params[] = $current_user_id;
                $types .= "i";
            }
        }
        
        if ($status) {
            if (strpos($status, ',') !== false) {
                $status_list = explode(',', $status);
                $placeholders = implode(',', array_fill(0, count($status_list), '?'));
                $sql .= " AND pr.status IN ($placeholders)";
                foreach ($status_list as $s) {
                    $params[] = trim($s);
                    $types .= "s";
                }
            } else {
                $sql .= " AND pr.status = ?";
                $params[] = $status;
                $types .= "s";
            }

        }
        
        if ($category) {
            $sql .= " AND pr.category = ?";
            $params[] = $category;
            $types .= "s";
        }
        
        if ($user_id) {
            $sql .= " AND pr.user_id = ?";
            $params[] = intval($user_id);
            $types .= "i";
        }
        
        $sql .= " ORDER BY pr.created_at DESC LIMIT ? OFFSET ?";
        $params[] = $limit;
        $params[] = $offset;
        $types .= "ii";
        
        error_log("Executing SQL: $sql with params: " . json_encode($params));
        
        $stmt = $conn->prepare($sql);
        if (!$stmt) {
            $error_msg = $conn->error ? $conn->error : 'Failed to prepare statement';
            error_log("ERROR preparing statement: $error_msg");
            http_response_code(500);
            if (ob_get_level() > 0) ob_clean();
            if (!headers_sent()) {
                header('Content-Type: application/json; charset=utf-8');
            }
            echo jsonResponse(false, 'Database error: ' . $error_msg);
            if (ob_get_level() > 0) ob_end_flush();
            exit;
        }
        
        if (!empty($params)) {
            $bind_result = $stmt->bind_param($types, ...$params);
            if (!$bind_result) {
                error_log("ERROR binding parameters: " . $stmt->error);
                http_response_code(500);
                if (ob_get_level() > 0) ob_clean();
                if (!headers_sent()) {
                    header('Content-Type: application/json; charset=utf-8');
                }
                echo jsonResponse(false, 'Database error: Failed to bind parameters');
                if (ob_get_level() > 0) ob_end_flush();
                exit;
            }
        }
        
        if (!$stmt->execute()) {
            $error_msg = $stmt->error ? $stmt->error : 'Failed to execute query';
            error_log("ERROR executing statement: $error_msg");
            http_response_code(500);
            if (ob_get_level() > 0) ob_clean();
            if (!headers_sent()) {
                header('Content-Type: application/json; charset=utf-8');
            }
            echo jsonResponse(false, 'Database error: ' . $error_msg);
            if (ob_get_level() > 0) ob_end_flush();
            exit;
        }
        
        $result = $stmt->get_result();
        if (!$result) {
            error_log("ERROR getting result: " . $stmt->error);
            http_response_code(500);
            if (ob_get_level() > 0) ob_clean();
            if (!headers_sent()) {
                header('Content-Type: application/json; charset=utf-8');
            }
            echo jsonResponse(false, 'Database error: Failed to get result');
            if (ob_get_level() > 0) ob_end_flush();
            exit;
        }
        
        $prayers = [];
        while ($row = $result->fetch_assoc()) {
            $prayers[] = $row;
        }
        
        error_log("Successfully retrieved " . count($prayers) . " prayers");
        
        // Ensure we always return valid JSON, even if prayers array is empty
        // Clear any output before sending JSON
        if (ob_get_level() > 0) {
            ob_clean();
        }
        
        // Set header again to ensure it's set
        if (!headers_sent()) {
            header('Content-Type: application/json; charset=utf-8');
        }
        
        // Output JSON response
        echo jsonResponse(true, 'Prayer requests retrieved', $prayers);
        
        // Flush output buffer
        if (ob_get_level() > 0) {
            ob_end_flush();
        }
        exit; // Stop execution after sending response
    }
    } catch (Exception $e) {
        // Log the error
        error_log("handleGetPrayers Exception: " . $e->getMessage() . " in " . $e->getFile() . ":" . $e->getLine());
        http_response_code(500);
        if (ob_get_level() > 0) ob_clean();
        if (!headers_sent()) {
            header('Content-Type: application/json; charset=utf-8');
        }
        echo jsonResponse(false, 'Database error: ' . $e->getMessage());
        if (ob_get_level() > 0) ob_end_flush();
        exit;
    } catch (Error $e) {
        // Log fatal errors
        error_log("handleGetPrayers Fatal Error: " . $e->getMessage() . " in " . $e->getFile() . ":" . $e->getLine());
        http_response_code(500);
        if (ob_get_level() > 0) ob_clean();
        if (!headers_sent()) {
            header('Content-Type: application/json; charset=utf-8');
        }
        echo jsonResponse(false, 'Server error. Please try again later.');
        if (ob_get_level() > 0) ob_end_flush();
        exit;
    }
}

function handleCreatePrayer($conn) {
    $user_id = intval($_POST['user_id'] ?? 0);
    $category = trim($_POST['category'] ?? '');
    $content = trim($_POST['content'] ?? '');
    $prayer_for = trim($_POST['prayer_for'] ?? 'Me');
    $allow_encouragement = intval($_POST['allow_encouragement'] ?? 1);
    $is_anonymous = intval($_POST['is_anonymous'] ?? 0);
    $shared_with = trim($_POST['shared_with'] ?? '');
    $tagged_user_id = !empty($_POST['tagged_user_id']) ? intval($_POST['tagged_user_id']) : null;
    $tagged_group_id = !empty($_POST['tagged_group_id']) ? intval($_POST['tagged_group_id']) : null;
    
    if (!$user_id) {
        http_response_code(400);
        echo jsonResponse(false, 'user_id is required');
        ob_end_flush();
        return;
    }
    
    if (empty($content)) {
        http_response_code(400);
        echo jsonResponse(false, 'Content is required');
        ob_end_flush();
        return;
    }
    
    // ===== CONTENT MODERATION START =====
    require_once '../includes/ContentModerationService.php';
    
    $moderation_result = ContentModerationService::checkContent($content, $conn);
    
    // Handle moderation action
    switch ($moderation_result['action']) {
        case 'block':
            http_response_code(400);
            echo jsonResponse(false, 'Content violates community guidelines. Please review our Terms & Conditions.');
            ob_end_flush();
            return;
            
        case 'quarantine':
            // Will be saved with moderation_status='pending' for manual review
            $moderation_status = 'pending';
            $content = $moderation_result['sanitized_content'];
            $moderation_notes = 'Auto-flagged: ' . implode(', ', array_column($moderation_result['matched_keywords'], 'keyword'));
            break;
            
        case 'warn':
            // Sanitize content but allow posting
            $content = $moderation_result['sanitized_content'];
            $moderation_status = 'approved';
            $moderation_notes = 'Auto-sanitized: ' . implode(', ', array_column($moderation_result['matched_keywords'], 'keyword'));
            break;
            
        case 'allow':
        default:
            $moderation_status = 'approved';
            $moderation_notes = null;
            break;
    }
    // ===== CONTENT MODERATION END =====
    
    // Verify user exists (allow Inactive status too - users can create prayers even if they requested Blogger)
    $user_stmt = $conn->prepare("SELECT id, status FROM users WHERE id = ?");
    $user_stmt->bind_param("i", $user_id);
    $user_stmt->execute();
    $user_result = $user_stmt->get_result();
    if ($user_result->num_rows === 0) {
        http_response_code(404);
        echo jsonResponse(false, 'User not found');
        ob_end_flush();
        return;
    }
    
    // Allow prayer creation for all users (Active or Inactive status)
    // Users with Inactive status can still create prayers while waiting for Blogger approval
    
    // Check if new columns exist
    $check_prayer_for = $conn->query("SHOW COLUMNS FROM prayer_requests LIKE 'prayer_for'");
    $check_tagged_user = $conn->query("SHOW COLUMNS FROM prayer_requests LIKE 'tagged_user_id'");
    $check_tagged_group = $conn->query("SHOW COLUMNS FROM prayer_requests LIKE 'tagged_group_id'");
    
    $has_prayer_for = $check_prayer_for->num_rows > 0;
    $has_tagged_user = $check_tagged_user->num_rows > 0;
    $has_tagged_group = $check_tagged_group->num_rows > 0;
    
    if ($has_prayer_for && $has_tagged_user && $has_tagged_group) {
        // Insert with all new fields including tagging and moderation
        $stmt = $conn->prepare("INSERT INTO prayer_requests (user_id, category, content, prayer_for, allow_encouragement, is_anonymous, shared_with, tagged_user_id, tagged_group_id, status, moderation_status, moderation_notes) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'Pending', ?, ?)");
        $stmt->bind_param("issiissiiss", $user_id, $category, $content, $prayer_for, $allow_encouragement, $is_anonymous, $shared_with, $tagged_user_id, $tagged_group_id, $moderation_status, $moderation_notes);
    } else if ($has_prayer_for) {
        // Insert with prayer_for but without tagging columns
        $stmt = $conn->prepare("INSERT INTO prayer_requests (user_id, category, content, prayer_for, allow_encouragement, is_anonymous, shared_with, status) VALUES (?, ?, ?, ?, ?, ?, ?, 'Pending')");
        $stmt->bind_param("issiiss", $user_id, $category, $content, $prayer_for, $allow_encouragement, $is_anonymous, $shared_with);
    } else {
        // Fallback to basic insert (for backward compatibility)
        $stmt = $conn->prepare("INSERT INTO prayer_requests (user_id, category, content, status) VALUES (?, ?, ?, 'Pending')");
        $stmt->bind_param("iss", $user_id, $category, $content);
    }
    
    if ($stmt->execute()) {
        $prayer_id = $stmt->insert_id;
        
        // Send notifications to users the prayer was shared with (non-blocking)
        if (!empty($shared_with)) {
            try {
                require_once '../includes/notification_service.php';
                $shared_user_ids = array_map('intval', explode(',', $shared_with));
                
                // Get the prayer creator's name
                $user_stmt = $conn->prepare("SELECT name FROM users WHERE id = ?");
                $user_stmt->bind_param("i", $user_id);
                $user_stmt->execute();
                $user_result = $user_stmt->get_result();
                $user_data = $user_result->fetch_assoc();
                $creator_name = $user_data['name'] ?? 'Someone';
                
                // Send notifications to all shared users
                foreach ($shared_user_ids as $shared_user_id) {
                    if ($shared_user_id != $user_id) { // Don't notify yourself
                        @createNotification(
                            $shared_user_id,
                            'prayer_shared',
                            'Prayer Shared with You',
                            "$creator_name shared a prayer request with you",
                            '',
                            ['prayer_id' => $prayer_id]
                        );
                    }
                }
            } catch (Exception $e) {
                error_log("Error sending shared notifications: " . $e->getMessage());
                // Continue with submission even if notification fails
            }
        }
        
        // Send notifications to group members if tagged to a group (non-blocking)
        if (!empty($tagged_group_id)) {
            try {
                require_once '../includes/notification_service.php';
                
                // Get group members
                $group_members_stmt = $conn->prepare("SELECT user_id FROM group_members WHERE group_id = ? AND status = 'active'");
                $group_members_stmt->bind_param("i", $tagged_group_id);
                $group_members_stmt->execute();
                $group_members_result = $group_members_stmt->get_result();
                
                // Get the prayer creator's name
                $user_stmt = $conn->prepare("SELECT name FROM users WHERE id = ?");
                $user_stmt->bind_param("i", $user_id);
                $user_stmt->execute();
                $user_result = $user_stmt->get_result();
                $user_data = $user_result->fetch_assoc();
                $creator_name = $user_data['name'] ?? 'Someone';
                
                // Get group name
                $group_stmt = $conn->prepare("SELECT name FROM `groups` WHERE id = ?");
                $group_stmt->bind_param("i", $tagged_group_id);
                $group_stmt->execute();
                $group_result = $group_stmt->get_result();
                $group_data = $group_result->fetch_assoc();
                $group_name = $group_data['name'] ?? 'Group';
                
                // Send notifications to all group members
                while ($member = $group_members_result->fetch_assoc()) {
                    $member_user_id = $member['user_id'];
                    if ($member_user_id != $user_id) { // Don't notify yourself
                        @createNotification(
                            $member_user_id,
                            'prayer_tagged_group',
                            'Prayer Tagged to Your Group',
                            "$creator_name tagged a prayer to $group_name",
                            '',
                            ['prayer_id' => $prayer_id, 'group_id' => $tagged_group_id]
                        );
                    }
                }
            } catch (Exception $e) {
                error_log("Error sending group notifications: " . $e->getMessage());
                // Continue with submission even if notification fails
            }
        }
        
        // Send notification to tagged user if tagged to someone (non-blocking)
        if (!empty($tagged_user_id)) {
            try {
                require_once '../includes/notification_service.php';
                
                // Get the prayer creator's name
                $user_stmt = $conn->prepare("SELECT name FROM users WHERE id = ?");
                $user_stmt->bind_param("i", $user_id);
                $user_stmt->execute();
                $user_result = $user_stmt->get_result();
                $user_data = $user_result->fetch_assoc();
                $creator_name = $user_data['name'] ?? 'Someone';
                
                // Send notification to tagged user
                if ($tagged_user_id != $user_id) { // Don't notify yourself
                    @createNotification(
                        $tagged_user_id,
                        'prayer_tagged_user',
                        'Prayer Tagged to You',
                        "$creator_name tagged a prayer request for you",
                        '',
                        ['prayer_id' => $prayer_id, 'tagged_by' => $user_id]
                    );
                }
            } catch (Exception $e) {
                error_log("Error sending tagged user notification: " . $e->getMessage());
                // Continue with submission even if notification fails
            }
        }
        
        echo jsonResponse(true, 'Prayer request submitted successfully. Waiting for admin approval.', ['id' => $prayer_id]);
        ob_end_flush();
    } else {
        http_response_code(500);
        echo jsonResponse(false, 'Failed to create prayer request: ' . $stmt->error);
        ob_end_flush();
    }
}

// edit feature: Handle edit prayer request with 15-minute window
function handleEditPrayer($conn) { // edit feature
    $user_id = intval($_POST['user_id'] ?? 0); // edit feature
    $prayer_id = intval($_POST['prayer_id'] ?? 0); // edit feature
    $content = trim($_POST['content'] ?? ''); // edit feature
    $category = trim($_POST['category'] ?? ''); // edit feature
    
    // edit feature: Log incoming request
    error_log("📥 Edit Prayer Request: user_id=$user_id, prayer_id=$prayer_id"); // edit feature
    
    // edit feature: Validation
    if (!$user_id || !$prayer_id) { // edit feature
        http_response_code(400); // edit feature
        echo jsonResponse(false, 'user_id and prayer_id are required'); // edit feature
        ob_end_flush(); // edit feature
        return; // edit feature
    } // edit feature
    
    // edit feature: Content moderation check
    require_once '../includes/ContentModerationService.php'; // edit feature
    $moderation_result = ContentModerationService::checkContent($content, $conn); // edit feature
    
    // edit feature: Handle moderation result
    switch ($moderation_result['action']) { // edit feature
        case 'block': // edit feature
            http_response_code(400); // edit feature
            echo jsonResponse(false, 'Content violates community guidelines.'); // edit feature
            ob_end_flush(); // edit feature
            return; // edit feature
        case 'quarantine': // edit feature
            http_response_code(400); // edit feature
            echo jsonResponse(false, 'Content cannot be edited due to content policy.'); // edit feature
            ob_end_flush(); // edit feature
            return; // edit feature
        case 'warn': // edit feature
            $content = $moderation_result['sanitized_content']; // edit feature
            break; // edit feature
        case 'allow': // edit feature
        default: // edit feature
            break; // edit feature
    } // edit feature
    
    // edit feature: Verify user owns the prayer
    $check_stmt = $conn->prepare("SELECT user_id, created_at FROM prayer_requests WHERE id = ?"); // edit feature
    $check_stmt->bind_param("i", $prayer_id); // edit feature
    $check_stmt->execute(); // edit feature
    $check_result = $check_stmt->get_result(); // edit feature
    
    if ($check_result->num_rows === 0) { // edit feature
        http_response_code(404); // edit feature
        echo jsonResponse(false, 'Prayer not found'); // edit feature
        ob_end_flush(); // edit feature
        return; // edit feature
    } // edit feature
    
    $prayer_data = $check_result->fetch_assoc(); // edit feature
    
    // edit feature: Check if user owns the prayer
    if ($prayer_data['user_id'] != $user_id) { // edit feature
        http_response_code(403); // edit feature
        echo jsonResponse(false, 'You can only edit your own prayers'); // edit feature
        ob_end_flush(); // edit feature
        return; // edit feature
    } // edit feature
    
    // edit feature: Check if prayer is within 15-minute window
    $created_at = strtotime($prayer_data['created_at']); // edit feature
    $now = time(); // edit feature
    $time_diff_minutes = ($now - $created_at) / 60; // edit feature
    
    if ($time_diff_minutes > 15) { // edit feature
        http_response_code(403); // edit feature
        echo jsonResponse(false, 'Prayers can only be edited within 15 minutes of posting'); // edit feature
        ob_end_flush(); // edit feature
        return; // edit feature
    } // edit feature
    
    // edit feature: Check if edited_at column exists
    $check_column = $conn->query("SHOW COLUMNS FROM prayer_requests LIKE 'edited_at'"); // edit feature
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
    
    if (!empty($category)) { // edit feature
        $update_parts[] = "category = ?"; // edit feature
        $params[] = $category; // edit feature
        $types .= "s"; // edit feature
    } // edit feature
    
    if ($has_edited_at) { // edit feature
        $update_parts[] = "edited_at = NOW()"; // edit feature
        $update_parts[] = "is_edited = 1"; // edit feature
    } // edit feature
    
    $params[] = $prayer_id; // edit feature
    $types .= "i"; // edit feature
    
    $sql = "UPDATE prayer_requests SET " . implode(", ", $update_parts) . " WHERE id = ?"; // edit feature
    $update_stmt = $conn->prepare($sql); // edit feature
    $update_stmt->bind_param($types, ...$params); // edit feature
    
    if ($update_stmt->execute()) { // edit feature
        error_log("✅ Prayer edited: ID=$prayer_id, user_id=$user_id"); // edit feature
        echo jsonResponse(true, 'Prayer edited successfully', [ // edit feature
            'id' => $prayer_id, // edit feature
            'is_edited' => true // edit feature
        ]); // edit feature
        ob_end_flush(); // edit feature
    } else { // edit feature
        error_log("❌ Failed to edit prayer: " . $update_stmt->error); // edit feature
        http_response_code(500); // edit feature
        echo jsonResponse(false, 'Failed to edit prayer: ' . $update_stmt->error); // edit feature
        ob_end_flush(); // edit feature
    } // edit feature
} // edit feature

function handleDeletePrayer($conn) {
    $user_id = intval($_POST['user_id'] ?? 0);
    $prayer_id = intval($_POST['prayer_id'] ?? 0);

    if (!$user_id || !$prayer_id) {
        http_response_code(400);
        echo jsonResponse(false, 'user_id and prayer_id are required');
        ob_end_flush();
        return;
    }

    $check_stmt = $conn->prepare("SELECT user_id, status FROM prayer_requests WHERE id = ?");
    $check_stmt->bind_param("i", $prayer_id);
    $check_stmt->execute();
    $check_result = $check_stmt->get_result();

    if ($check_result->num_rows === 0) {
        http_response_code(404);
        echo jsonResponse(false, 'Prayer not found');
        ob_end_flush();
        return;
    }

    $prayer_data = $check_result->fetch_assoc();

    if ($prayer_data['user_id'] != $user_id) {
        http_response_code(403);
        echo jsonResponse(false, 'You can only delete your own prayers');
        ob_end_flush();
        return;
    }

    if ($prayer_data['status'] === 'Deleted') {
        http_response_code(404);
        echo jsonResponse(false, 'Prayer already deleted');
        ob_end_flush();
        return;
    }

    $delete_stmt = $conn->prepare("UPDATE prayer_requests SET status = 'Deleted' WHERE id = ?");
    $delete_stmt->bind_param("i", $prayer_id);

    if ($delete_stmt->execute()) {
        echo jsonResponse(true, 'Prayer deleted successfully', ['id' => $prayer_id]);
        ob_end_flush();
    } else {
        http_response_code(500);
        echo jsonResponse(false, 'Failed to delete prayer: ' . $delete_stmt->error);
        ob_end_flush();
    }
}

// Close connection (only if not already closed)
if (isset($conn) && $conn->ping()) {
    $conn->close();
}

// Clean up any remaining output buffers
while (ob_get_level() > 0) {
    ob_end_clean();
}
