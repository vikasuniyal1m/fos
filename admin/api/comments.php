
<?php
/**
 * Comments API
 * Handles: Add comment, List comments, Like/React to posts
 */

// Start output buffering to prevent any output before JSON
ob_start();

// Suppress warnings for column existence checks
error_reporting(E_ALL & ~E_WARNING & ~E_NOTICE);
ini_set('display_errors', 0);

require_once '../includes/db.php';
require_once '../includes/cors.php';
require_once 'auth-helper.php';

// Clear any output that might have been generated
ob_clean();

header('Content-Type: application/json; charset=utf-8');

$method = $_SERVER['REQUEST_METHOD'];
$action = $_GET['action'] ?? $_POST['action'] ?? '';

if ($method === 'OPTIONS') {
    http_response_code(200);
    exit;
}

try {
    switch ($action) {
        case 'like':
            handleLikeBlog($conn);
            break;
        case 'like-comment':
            handleLikeComment($conn);
            break;
        case 'report':
            handleReportComment($conn);
            break;
        case 'edit': // edit feature
            handleEditComment($conn); // edit feature
            break; // edit feature
        case 'delete':
            handleDeleteComment($conn);
            break;
        default:
            if ($method === 'GET') {
                handleGetComments($conn);
            } elseif ($method === 'POST') {
                handleAddComment($conn);
            } else {
                http_response_code(405);
                echo jsonResponse(false, 'Method not allowed');
            }
            break;
    }
} catch (Exception $e) {
    ob_clean();
    error_log("❌ Fatal error in comments.php: " . $e->getMessage());
    error_log("❌ Stack trace: " . $e->getTraceAsString());
    http_response_code(500);
    echo jsonResponse(false, 'Server error: ' . $e->getMessage());
} catch (Error $e) {
    ob_clean();
    error_log("❌ Fatal PHP error in comments.php: " . $e->getMessage());
    error_log("❌ Stack trace: " . $e->getTraceAsString());
    http_response_code(500);
    echo jsonResponse(false, 'Server error: ' . $e->getMessage());
}

function handleGetComments($conn) {
    $post_type = $_GET['post_type'] ?? ''; // prayer, blog, video, gallery, story
    $post_id = intval($_GET['post_id'] ?? 0);
    $current_user_id = intval($_GET['user_id'] ?? 0); // For checking if user liked/reported
    
    // Check if comment_likes table exists (will be used later)
    $check_likes_table = @$conn->query("SHOW TABLES LIKE 'comment_likes'");
    $has_likes_table = $check_likes_table && $check_likes_table->num_rows > 0;
    
    if (empty($post_type) || !$post_id) {
        http_response_code(400);
        echo jsonResponse(false, 'post_type and post_id are required');
        return;
    }
    
    // Validate post_type
    $allowed_types = ['prayer', 'blog', 'video', 'gallery', 'story', 'thread', 'group_post'];
    if (!in_array($post_type, $allowed_types)) {
        http_response_code(400);
        echo jsonResponse(false, 'Invalid post_type');
        return;
    }

    // Soft-deleted comments must not be returned in lists
    $comments_deleted_filter = '';
    $comments_deleted_filter_sub = '';
    $check_is_deleted_col = @$conn->query("SHOW COLUMNS FROM comments LIKE 'is_deleted'");
    if ($check_is_deleted_col && $check_is_deleted_col->num_rows > 0) {
        $comments_deleted_filter = ' AND (COALESCE(c.is_deleted, 0) = 0)';
        $comments_deleted_filter_sub = ' AND (COALESCE(is_deleted, 0) = 0)';
    }
    
    // Get comments based on post type
    if ($post_type === 'blog') {
        // Check if blog_comments table has parent_comment_id column (check once, use everywhere)
        $check_blog_column = @$conn->query("SHOW COLUMNS FROM blog_comments LIKE 'parent_comment_id'");
        $has_blog_parent_column = $check_blog_column && $check_blog_column->num_rows > 0;
        
        // Check if comment_likes table exists for blog comments
        $check_likes_table = @$conn->query("SHOW TABLES LIKE 'comment_likes'");
        $has_likes_table = $check_likes_table && $check_likes_table->num_rows > 0;
        
        error_log("🔍 Blog Comments Check: has_parent_column=" . ($has_blog_parent_column ? 'YES' : 'NO') . ", has_likes_table=" . ($has_likes_table ? 'YES' : 'NO'));
        
        if ($has_blog_parent_column) {
            // Get ALL blog comments (including replies) to build nested structure
            $like_count_sql = $has_likes_table ? "(SELECT COUNT(*) FROM comment_likes WHERE comment_id = bc.id)" : "0";
            $is_liked_sql = ($has_likes_table && $current_user_id > 0) ? "(SELECT COUNT(*) FROM comment_likes WHERE comment_id = bc.id AND user_id = ?)" : "0";
            
            // Fetch ALL comments first (including replies) to build nested structure
            // IMPORTANT: Also include emoji reactions from 'comments' table (UNION with blog_comments)
            // Emoji reactions are stored in 'comments' table with post_type='blog', not in 'blog_comments' table
            // CRITICAL: Both SELECT statements must have the SAME number of columns in the SAME order
            $comments_sql = "
                SELECT bc.id,
                       bc.blog_id,
                       bc.user_id,
                       bc.comment,
                       bc.created_at,
                       bc.parent_comment_id,
                       u.name as user_name,
                       u.profile_photo,
                       $like_count_sql as like_count,
                       (SELECT COUNT(*) FROM blog_comments WHERE parent_comment_id = bc.id) as reply_count,
                       $is_liked_sql as is_liked
                FROM blog_comments bc
                JOIN users u ON bc.user_id = u.id
                WHERE bc.blog_id = ?";
            error_log("📖 Fetching blog comments for blog_id=$post_id");
            
            // FILTER BLOCKED USERS FROM BLOG COMMENTS
            if ($current_user_id > 0) {
                $check_blocks = $conn->query("SHOW TABLES LIKE 'user_blocks'");
                if ($check_blocks && $check_blocks->num_rows > 0) {
                    $comments_sql .= " AND bc.user_id NOT IN (SELECT blocked_user_id FROM user_blocks WHERE user_id = " . intval($current_user_id) . ")";
                }
            }

            // Emoji comments are stored in blog_comments table - no UNION needed
            
            $stmt = $conn->prepare($comments_sql . " ORDER BY created_at ASC");
            if (!$stmt) {
                error_log("❌ Failed to prepare statement: " . $conn->error);
                http_response_code(500);
                echo jsonResponse(false, 'Database error: ' . $conn->error);
                return;
            }
            if ($current_user_id > 0) {
                $stmt->bind_param("ii", $current_user_id, $post_id);
            } else {
                $stmt->bind_param("i", $post_id);
            }
        } else {
            // Fallback: Get all blog comments without nested structure
            $stmt = $conn->prepare("
                SELECT bc.*, u.name as user_name, u.profile_photo
                FROM blog_comments bc
                JOIN users u ON bc.user_id = u.id
                WHERE bc.blog_id = ?
                ORDER BY bc.created_at ASC
            ");
            $stmt->bind_param("i", $post_id);
        }
    } else {
        // Get comments with like counts and reply counts
        // Check if parent_comment_id column exists - try multiple methods
        $has_parent_column = false;
        
        // Method 1: Check with SHOW COLUMNS (suppress warnings)
        $check_column = @$conn->query("SHOW COLUMNS FROM comments LIKE 'parent_comment_id'");
        if ($check_column && !$conn->error && $check_column->num_rows > 0) {
            $has_parent_column = true;
        } else {
            // Method 2: Try to describe the table (suppress warnings)
            $desc_result = @$conn->query("DESCRIBE comments");
            if ($desc_result && !$conn->error) {
                while ($col = $desc_result->fetch_assoc()) {
                    if ($col['Field'] === 'parent_comment_id') {
                        $has_parent_column = true;
                        break;
                    }
                }
            }
        }
        
        // Method 3: Try a test query to see if column exists (most reliable)
        // This is the definitive check - if this fails, column doesn't exist
        $test_query = @$conn->query("SELECT parent_comment_id FROM comments LIMIT 1");
        $test_error = $conn->error;
        if ($test_query !== false && empty($test_error)) {
            $has_parent_column = true;
            error_log("✅ parent_comment_id column exists (verified by test query)");
        } else {
            // Column definitely doesn't exist - reset to false
            $has_parent_column = false;
            error_log("❌ parent_comment_id column does NOT exist - will use fallback query. Error: " . ($test_error ?: 'Unknown'));
        }
        
        if ($has_parent_column) {
            // Check if comment_likes table exists
            $check_likes_table = @$conn->query("SHOW TABLES LIKE 'comment_likes'");
            $has_likes_table = $check_likes_table && $check_likes_table->num_rows > 0;
            
            // Get comments with nested structure, likes, and replies
            // Use COALESCE to handle NULL values properly
            $like_count_sql = $has_likes_table ? "(SELECT COUNT(*) FROM comment_likes WHERE comment_id = c.id)" : "0";
            $is_liked_sql = ($has_likes_table && $current_user_id > 0) ? "(SELECT COUNT(*) FROM comment_likes WHERE comment_id = c.id AND user_id = ?)" : "0";
            
            // Build WHERE clause with blocked user filtering
            $comments_where = "c.post_type = ? AND c.post_id = ? AND c.status = 'approved' AND (COALESCE(c.parent_comment_id, 0) = 0)" . $comments_deleted_filter;
            if ($current_user_id > 0) {
                $check_blocks = $conn->query("SHOW TABLES LIKE 'user_blocks'");
                if ($check_blocks->num_rows > 0) {
                    $comments_where .= " AND c.user_id NOT IN (SELECT blocked_user_id FROM user_blocks WHERE user_id = " . intval($current_user_id) . ")";
                }
            }
            
            $stmt = $conn->prepare("
                SELECT c.*, 
                       u.name as user_name, 
                       u.profile_photo,
                       $like_count_sql as like_count,
                       (SELECT COUNT(*) FROM comments WHERE parent_comment_id = c.id AND status = 'approved'{$comments_deleted_filter_sub}) as reply_count,
                       $is_liked_sql as is_liked
                FROM comments c
                JOIN users u ON c.user_id = u.id
                WHERE $comments_where
                ORDER BY c.created_at ASC
            ");
            if (!$stmt) {
                error_log("❌ Failed to prepare statement: " . $conn->error);
                http_response_code(500);
                echo jsonResponse(false, 'Database error: ' . $conn->error);
                return;
            }
            if ($current_user_id > 0) {
                $stmt->bind_param("isi", $current_user_id, $post_type, $post_id);
            } else {
                $stmt->bind_param("si", $post_type, $post_id);
            }
        } else {
            // Fallback for old structure - get all comments without parent_comment_id column
            
            // Build WHERE clause with blocked user filtering
            $comments_where = "c.post_type = ? AND c.post_id = ? AND c.status = 'approved'" . $comments_deleted_filter;
            if ($current_user_id > 0) {
                $check_blocks = $conn->query("SHOW TABLES LIKE 'user_blocks'");
                if ($check_blocks->num_rows > 0) {
                    $comments_where .= " AND c.user_id NOT IN (SELECT blocked_user_id FROM user_blocks WHERE user_id = " . intval($current_user_id) . ")";
                }
            }
            
            $stmt = $conn->prepare("
                SELECT c.*, 
                       u.name as user_name, 
                       u.profile_photo
                FROM comments c
                JOIN users u ON c.user_id = u.id
                WHERE $comments_where
                ORDER BY c.created_at ASC
            ");
            if (!$stmt) {
                error_log("❌ Failed to prepare statement: " . $conn->error);
                http_response_code(500);
                echo jsonResponse(false, 'Database error: ' . $conn->error);
                return;
            }
            $stmt->bind_param("si", $post_type, $post_id);
        }
    }
    
    try {
        if (!$stmt->execute()) {
            error_log("❌ Query execution failed: " . $stmt->error);
            http_response_code(500);
            echo jsonResponse(false, 'Database query failed: ' . $stmt->error);
            return;
        }
        
        $result = $stmt->get_result();
        
        if (!$result) {
            error_log("❌ Failed to get result: " . $stmt->error);
            http_response_code(500);
            echo jsonResponse(false, 'Database query failed: ' . $stmt->error);
            return;
        }
        
        $comments = [];
        $all_comments = [];
        
        // Handle blog comments differently
        if ($post_type === 'blog') {
            // Use the same $has_blog_parent_column and $has_likes_table from above (don't check again)
            if ($has_blog_parent_column) {
                // Fetch all blog comments first (including replies)
                $all_blog_comments = [];
                while ($row = $result->fetch_assoc()) {
                    error_log("📖 Blog comment from DB: id={$row['id']}, comment=\"" . ($row['comment'] ?? 'NULL') . "\"");
                    $all_blog_comments[] = $row;
                }
                
                // Emoji comments are now stored in blog_comments table with comment_type='emoji'
                // No need for separate emoji reactions query - they're included in main query
                
                error_log("📦 Fetched " . count($all_blog_comments) . " total blog comments (including replies and emoji reactions)");
                
                // Process top-level comments and build nested structure
                foreach ($all_blog_comments as $row) {
                    $comment_id = $row['id'];
                    $parent_id = isset($row['parent_comment_id']) ? intval($row['parent_comment_id']) : 0;
                    
                    // Only process top-level comments (parent_comment_id is NULL or 0)
                    if ($parent_id == 0) {
                        // Get replies recursively for this comment
                        $replies = getNestedBlogReplies($conn, $comment_id, $has_likes_table, $current_user_id, $all_blog_comments);
                        
                        $row['replies'] = $replies;
                        error_log("📝 Blog Comment ID=$comment_id has " . count($replies) . " direct replies");
                        $comments[] = $row;
                    }
                }
                
                error_log("✅ Processed " . count($comments) . " top-level blog comments with nested structure");
            } else {
                // No nested structure - return flat list
                error_log("⚠️ Blog comments: parent_comment_id column not found, returning flat list");
                
                // Emoji comments are stored in blog_comments table - no separate query needed
                
                while ($row = $result->fetch_assoc()) {
                    $row['replies'] = [];
                    $comments[] = $row;
                }
            }
        } else {
            // For other post types (prayers, videos, etc.)
            // First, fetch all comments (including replies) if column doesn't exist
            if (!$has_parent_column) {
                while ($row = $result->fetch_assoc()) {
                    $all_comments[] = $row;
                }
                // Re-execute to get all comments for filtering
                $stmt->execute();
                $result = $stmt->get_result();
            }
            
            while ($row = $result->fetch_assoc()) {
                $comment_id = $row['id'];
                $parent_id = isset($row['parent_comment_id']) ? intval($row['parent_comment_id']) : 0;
                
                // Only process top-level comments (parent_comment_id is NULL or 0)
                if ($parent_id == 0) {
                    // Get replies recursively for this comment
                    $replies = getNestedReplies($conn, $comment_id, $has_parent_column, $has_likes_table, $current_user_id, $all_comments, $comments_deleted_filter);
                    
                    $row['replies'] = $replies;
                    error_log("📝 Comment ID=$comment_id has " . count($replies) . " direct replies");
                    $comments[] = $row;
                }
            }
        }
    } catch (Exception $e) {
        error_log("❌ Error in handleGetComments: " . $e->getMessage());
        http_response_code(500);
        echo jsonResponse(false, 'Error fetching comments: ' . $e->getMessage());
        return;
    }
    
    error_log("✅ Returning " . count($comments) . " top-level comments");
    
    echo jsonResponse(true, 'Comments retrieved', $comments);
}

/**
 * Recursively fetch nested replies for a comment
 * Supports unlimited nesting levels
 */
function getNestedReplies($conn, $parent_id, $has_parent_column, $has_likes_table, $current_user_id, $all_comments = [], $deleted_filter = '') {
    $replies = [];
    
    if (!$has_parent_column) {
        // If column doesn't exist, filter from all_comments
        foreach ($all_comments as $all_comment) {
            if (isset($all_comment['is_deleted']) && intval($all_comment['is_deleted']) === 1) {
                continue;
            }
            $all_parent_id = isset($all_comment['parent_comment_id']) ? intval($all_comment['parent_comment_id']) : 0;
            if ($all_parent_id == $parent_id) {
                // Recursively get nested replies for this reply
                $nested_replies = getNestedReplies($conn, $all_comment['id'], $has_parent_column, $has_likes_table, $current_user_id, $all_comments, $deleted_filter);
                $all_comment['replies'] = $nested_replies;
                $replies[] = $all_comment;
            }
        }
        return $replies;
    }
    
    // Fetch direct replies
    $reply_like_count_sql = $has_likes_table ? "(SELECT COUNT(*) FROM comment_likes WHERE comment_id = c.id)" : "0";
    $reply_is_liked_sql = ($has_likes_table && $current_user_id > 0) ? "(SELECT COUNT(*) FROM comment_likes WHERE comment_id = c.id AND user_id = ?)" : "0";
    
    if ($current_user_id > 0 && $has_likes_table) {
        $reply_stmt = $conn->prepare("
            SELECT c.*, 
                   u.name as user_name, 
                   u.profile_photo,
                   $reply_like_count_sql as like_count,
                   $reply_is_liked_sql as is_liked
            FROM comments c
            JOIN users u ON c.user_id = u.id
            WHERE c.parent_comment_id = ? AND c.status = 'approved'{$deleted_filter}
            ORDER BY c.created_at ASC
        ");
        if ($reply_stmt) {
            $reply_stmt->bind_param("ii", $current_user_id, $parent_id);
            if ($reply_stmt->execute()) {
                $reply_result = $reply_stmt->get_result();
                if ($reply_result) {
                    while ($reply_row = $reply_result->fetch_assoc()) {
                        $reply_id = $reply_row['id'];
                        // Recursively get nested replies for this reply
                        $nested_replies = getNestedReplies($conn, $reply_id, $has_parent_column, $has_likes_table, $current_user_id, $all_comments, $deleted_filter);
                        $reply_row['replies'] = $nested_replies;
                        $replies[] = $reply_row;
                    }
                }
            }
            $reply_stmt->close();
        }
    } else {
        $reply_stmt = $conn->prepare("
            SELECT c.*, 
                   u.name as user_name, 
                   u.profile_photo,
                   $reply_like_count_sql as like_count,
                   0 as is_liked
            FROM comments c
            JOIN users u ON c.user_id = u.id
            WHERE c.parent_comment_id = ? AND c.status = 'approved'{$deleted_filter}
            ORDER BY c.created_at ASC
        ");
        if ($reply_stmt) {
            $reply_stmt->bind_param("i", $parent_id);
            if ($reply_stmt->execute()) {
                $reply_result = $reply_stmt->get_result();
                if ($reply_result) {
                    while ($reply_row = $reply_result->fetch_assoc()) {
                        $reply_id = $reply_row['id'];
                        // Recursively get nested replies for this reply
                        $nested_replies = getNestedReplies($conn, $reply_id, $has_parent_column, $has_likes_table, $current_user_id, $all_comments, $deleted_filter);
                        $reply_row['replies'] = $nested_replies;
                        $replies[] = $reply_row;
                    }
                }
            }
            $reply_stmt->close();
        }
    }
    
    return $replies;
}

/**
 * Recursively fetch nested replies for blog comments
 * Supports unlimited nesting levels for blog_comments table
 */
function getNestedBlogReplies($conn, $parent_id, $has_likes_table, $current_user_id, $all_blog_comments = []) {
    $replies = [];
    
    // Filter from all_blog_comments array
    foreach ($all_blog_comments as $blog_comment) {
        $blog_parent_id = isset($blog_comment['parent_comment_id']) ? intval($blog_comment['parent_comment_id']) : 0;
        if ($blog_parent_id == $parent_id) {
            // Recursively get nested replies for this reply
            $nested_replies = getNestedBlogReplies($conn, $blog_comment['id'], $has_likes_table, $current_user_id, $all_blog_comments);
            $blog_comment['replies'] = $nested_replies;
            $replies[] = $blog_comment;
            error_log("  ↳ Reply ID={$blog_comment['id']} has " . count($nested_replies) . " nested replies");
        }
    }
    
    return $replies;
}

function handleAddComment($conn) {
    $user_id = intval($_POST['user_id'] ?? 0);
    $post_type = trim($_POST['post_type'] ?? '');
    $post_id = intval($_POST['post_id'] ?? 0);
    $content = trim($_POST['content'] ?? '');
    $parent_comment_id = !empty($_POST['parent_comment_id']) ? intval($_POST['parent_comment_id']) : null;
    
    // Log incoming request for debugging
    error_log("📥 Add Comment Request: user_id=$user_id, post_type=$post_type, post_id=$post_id, content_length=" . strlen($content) . ", parent_comment_id=" . ($parent_comment_id ?? 'null'));
    error_log("📥 Add Comment Content: \"$content\"");
    
    if (!$user_id) {
        error_log("❌ Validation failed: user_id is missing or 0");
        http_response_code(400);
        echo jsonResponse(false, 'user_id is required');
        return;
    }
    
    if (empty($post_type) || !$post_id) {
        error_log("❌ Validation failed: post_type='$post_type', post_id=$post_id");
        http_response_code(400);
        echo jsonResponse(false, 'post_type and post_id are required');
        return;
    }
    
    if (empty($content)) {
        error_log("❌ Validation failed: content is empty");
        http_response_code(400);
        echo jsonResponse(false, 'Comment content is required');
        return;
    }
    
    // ===== CONTENT MODERATION START =====
    require_once '../includes/ContentModerationService.php';
    
    $moderation_result = ContentModerationService::checkContent($content, $conn);
    
    switch ($moderation_result['action']) {
        case 'block':
            http_response_code(400);
            echo jsonResponse(false, 'Comment violates community guidelines.');
            return;
            
        case 'quarantine':
            $comment_status = 'pending';
            $content = $moderation_result['sanitized_content'];
            $moderation_notes = 'Auto-flagged: ' . implode(', ', array_column($moderation_result['matched_keywords'], 'keyword'));
            break;
            
        case 'warn':
            $content = $moderation_result['sanitized_content'];
            $comment_status = 'approved';
            $moderation_notes = 'Auto-sanitized';
            break;
            
        case 'allow':
        default:
            $comment_status = 'approved';
            $moderation_notes = null;
            break;
    }
    // ===== CONTENT MODERATION END =====
    
    // Validate post_type
    $allowed_types = ['prayer', 'blog', 'video', 'gallery', 'story', 'thread', 'group_post'];
    if (!in_array($post_type, $allowed_types)) {
        error_log("❌ Validation failed: Invalid post_type='$post_type'");
        http_response_code(400);
        echo jsonResponse(false, 'Invalid post_type');
        return;
    }
    
    // Verify user exists
    $user_stmt = $conn->prepare("SELECT id, status FROM users WHERE id = ?");
    $user_stmt->bind_param("i", $user_id);
    $user_stmt->execute();
    $user_result = $user_stmt->get_result();
    if ($user_result->num_rows === 0) {
        error_log("❌ User not found: user_id=$user_id");
        http_response_code(404);
        echo jsonResponse(false, 'User not found');
        return;
    }
    $user_data = $user_result->fetch_assoc();
    if ($user_data['status'] !== 'Active') {
        error_log("❌ User not active: user_id=$user_id, status=" . $user_data['status']);
        http_response_code(404);
        echo jsonResponse(false, 'User account is not active');
        return;
    }
    
    // Verify the post (blog/prayer/video/etc.) exists before adding comment
    if ($post_type === 'blog') {
        // Verify blog exists - allow comments on any blog that exists (not just approved)
        // If user can see the blog, they should be able to comment on it
        $post_stmt = $conn->prepare("SELECT id, status FROM blogs WHERE id = ?");
        $post_stmt->bind_param("i", $post_id);
        $post_stmt->execute();
        $post_result = $post_stmt->get_result();
        if ($post_result->num_rows === 0) {
            error_log("❌ Blog not found: blog_id=$post_id");
            http_response_code(404);
            echo jsonResponse(false, 'Blog not found');
            return;
        }
        $blog_data = $post_result->fetch_assoc();
        error_log("✅ Blog verified: blog_id=$post_id, status=" . $blog_data['status']);
    } else {
        // Verify other post types exist
        $post_table = '';
        $post_where = '';
        switch ($post_type) {
            case 'prayer':
                $post_table = 'prayer_requests';
                $post_where = 'id = ?';
                break;
            case 'video':
                $post_table = 'media_items';
                $post_where = 'id = ? AND type = \'video\'';
                break;
            case 'gallery':
                $post_table = 'media_items';
                $post_where = 'id = ? AND type = \'image\'';
                break;
            case 'story':
                $post_table = 'stories';
                $post_where = 'id = ?';
                break;
            case 'group_post':
                $post_table = 'group_posts';
                $post_where = 'id = ?';
                break;
            default:
                error_log("❌ Invalid post_type: $post_type");
                http_response_code(400);
                echo jsonResponse(false, 'Invalid post_type');
                return;
        }
        
        if (!empty($post_table)) {
            $post_stmt = $conn->prepare("SELECT id FROM $post_table WHERE $post_where");
            $post_stmt->bind_param("i", $post_id);
            $post_stmt->execute();
            $post_result = $post_stmt->get_result();
            if ($post_result->num_rows === 0) {
                error_log("❌ $post_type not found: post_id=$post_id");
                http_response_code(404);
                echo jsonResponse(false, ucfirst($post_type) . ' not found');
                return;
            }
            error_log("✅ $post_type verified: post_id=$post_id");
        }
    }
    
    // Check if parent_comment_id column exists (for non-blog comments)
    $check_column = $conn->query("SHOW COLUMNS FROM comments LIKE 'parent_comment_id'");
    $has_parent_column = $check_column->num_rows > 0;
    
    // If parent_comment_id is provided, verify it exists
    if ($parent_comment_id !== null) {
        if ($post_type === 'blog') {
            // For blogs, check blog_comments table
            $parent_stmt = $conn->prepare("SELECT id FROM blog_comments WHERE id = ? AND blog_id = ?");
            $parent_stmt->bind_param("ii", $parent_comment_id, $post_id);
        } else {
            // For other post types, check comments table
            $parent_stmt = $conn->prepare("SELECT id FROM comments WHERE id = ? AND post_type = ? AND post_id = ?");
            $parent_stmt->bind_param("isi", $parent_comment_id, $post_type, $post_id);
        }
        $parent_stmt->execute();
        if ($parent_stmt->get_result()->num_rows === 0) {
            http_response_code(404);
            echo jsonResponse(false, 'Parent comment not found');
            return;
        }
    }
    
    // Insert comment based on post type
    if ($post_type === 'blog') {
        // Check if blog_comments table has parent_comment_id column
        $check_blog_column = $conn->query("SHOW COLUMNS FROM blog_comments LIKE 'parent_comment_id'");
        $has_blog_parent_column = $check_blog_column && $check_blog_column->num_rows > 0;
        
        if ($has_blog_parent_column && $parent_comment_id !== null) {
            // Check if content is emoji URL
            $comment_type = 'text';
            if (filter_var($content, FILTER_VALIDATE_URL) && (
                strpos($content, 'uploads/emojis/') !== false || 
                strpos($content, '/emojis/') !== false ||
                preg_match('/\.(png|jpg|jpeg)$/i', $content)
            )) {
                $comment_type = 'emoji';
                error_log("🎯 Detected emoji URL: $content");
            }
            
            // Insert reply to blog comment
            $stmt = $conn->prepare("INSERT INTO blog_comments (blog_id, user_id, comment, parent_comment_id, comment_type) VALUES (?, ?, ?, ?, ?)");
            if (!$stmt) {
                error_log("❌ Failed to prepare statement for blog reply: " . $conn->error);
                http_response_code(500);
                echo jsonResponse(false, 'Database error: ' . $conn->error);
                return;
            }
            $stmt->bind_param("iisis", $post_id, $user_id, $content, $parent_comment_id, $comment_type);
            error_log("📝 Inserting blog reply: blog_id=$post_id, user_id=$user_id, parent_comment_id=$parent_comment_id, type=$comment_type");
        } else {
            // Check if content is emoji URL
            $comment_type = 'text';
            if (filter_var($content, FILTER_VALIDATE_URL) && (
                strpos($content, 'uploads/emojis/') !== false || 
                strpos($content, '/emojis/') !== false ||
                preg_match('/\.(png|jpg|jpeg)$/i', $content)
            )) {
                $comment_type = 'emoji';
                error_log("🎯 Detected emoji URL: $content");
            }
            
            // Insert top-level blog comment
            $stmt = $conn->prepare("INSERT INTO blog_comments (blog_id, user_id, comment, comment_type) VALUES (?, ?, ?, ?)");
            if (!$stmt) {
                error_log("❌ Failed to prepare statement for blog comment: " . $conn->error);
                http_response_code(500);
                echo jsonResponse(false, 'Database error: ' . $conn->error);
                return;
            }
            $stmt->bind_param("iiss", $post_id, $user_id, $content, $comment_type);
            error_log("📝 Inserting blog comment: blog_id=$post_id, user_id=$user_id, content=\"$content\", type=$comment_type");
        }
    } else {
        // For prayers, videos, etc. - auto-approve comments (status = 'approved')
        if ($has_parent_column && $parent_comment_id !== null) {
            $stmt = $conn->prepare("INSERT INTO comments (post_type, post_id, user_id, content, parent_comment_id, status) VALUES (?, ?, ?, ?, ?, 'approved')");
            if (!$stmt) {
                error_log("❌ Failed to prepare statement for reply: " . $conn->error);
                http_response_code(500);
                echo jsonResponse(false, 'Database error: ' . $conn->error);
                return;
            }
            $stmt->bind_param("siisi", $post_type, $post_id, $user_id, $content, $parent_comment_id);
            error_log("📝 Inserting reply: post_type=$post_type, post_id=$post_id, user_id=$user_id, parent_comment_id=$parent_comment_id");
        } else {
            $stmt = $conn->prepare("INSERT INTO comments (post_type, post_id, user_id, content, status, moderation_notes, created_at) VALUES (?, ?, ?, ?, ?, ?, NOW())");
            if (!$stmt) {
                error_log("❌ Failed to prepare statement for comment: " . $conn->error);
                http_response_code(500);
                echo jsonResponse(false, 'Database error: ' . $conn->error);
                return;
            }
            $stmt->bind_param("siisss", $post_type, $post_id, $user_id, $content, $comment_status, $moderation_notes);
            error_log("📝 Inserting comment: post_type=$post_type, post_id=$post_id, user_id=$user_id");
        }
    }
    
    if ($stmt->execute()) {
        $comment_id = $stmt->insert_id;
        $is_reply = ($parent_comment_id !== null && $parent_comment_id > 0);
        error_log("✅ Comment added: ID=$comment_id, post_type=$post_type, post_id=$post_id, user_id=$user_id, parent_id=" . ($parent_comment_id ?? 'null') . ", is_reply=" . ($is_reply ? 'YES' : 'NO'));
        
        // Return comment data with unique ID and post identification
        $response_data = [
            'id' => $comment_id,
            'post_type' => $post_type,
            'post_id' => $post_id,
            'user_id' => $user_id,
            'content' => $content,
            'created_at' => date('Y-m-d H:i:s'), // Server local time (IST)
            'debug' => [
                'received_content' => $content,
                'content_length' => strlen($content)
            ]
        ];
        
        if ($is_reply) {
            $response_data['parent_comment_id'] = $parent_comment_id;
            $response_data['is_reply'] = true;
        }
        
        echo jsonResponse(true, $is_reply ? 'Reply added successfully' : 'Comment added successfully', $response_data);
    } else {
        error_log("❌ Failed to add comment: " . $stmt->error);
        error_log("❌ SQL Error: " . $conn->error);
        http_response_code(500);
        echo jsonResponse(false, 'Failed to add comment: ' . $stmt->error);
    }
}

function handleLikeBlog($conn) {
    $user_id = intval($_POST['user_id'] ?? 0);
    $blog_id = intval($_POST['blog_id'] ?? 0);
    
    if (!$user_id || !$blog_id) {
        http_response_code(400);
        echo jsonResponse(false, 'user_id and blog_id are required');
        return;
    }
    
    // Check if already liked
    $check_stmt = $conn->prepare("SELECT id FROM blog_likes WHERE blog_id = ? AND user_id = ?");
    $check_stmt->bind_param("ii", $blog_id, $user_id);
    $check_stmt->execute();
    
    if ($check_stmt->get_result()->num_rows > 0) {
        // Unlike - remove like
        $stmt = $conn->prepare("DELETE FROM blog_likes WHERE blog_id = ? AND user_id = ?");
        $stmt->bind_param("ii", $blog_id, $user_id);
        $stmt->execute();
        echo jsonResponse(true, 'Blog unliked', ['liked' => false]);
    } else {
        // Like - add like
        $stmt = $conn->prepare("INSERT INTO blog_likes (blog_id, user_id) VALUES (?, ?)");
        $stmt->bind_param("ii", $blog_id, $user_id);
        $stmt->execute();
        echo jsonResponse(true, 'Blog liked', ['liked' => true]);
    }
}

function handleLikeComment($conn) {
    $user_id = intval($_POST['user_id'] ?? 0);
    $comment_id = intval($_POST['comment_id'] ?? 0);
    
    if (!$user_id || !$comment_id) {
        http_response_code(400);
        echo jsonResponse(false, 'user_id and comment_id are required');
        return;
    }
    
    // Check if comment_likes table exists
    $check_table = $conn->query("SHOW TABLES LIKE 'comment_likes'");
    if ($check_table->num_rows === 0) {
        http_response_code(501);
        echo jsonResponse(false, 'Comment likes feature not available');
        return;
    }
    
    // Check if already liked
    $check_stmt = $conn->prepare("SELECT id FROM comment_likes WHERE comment_id = ? AND user_id = ?");
    $check_stmt->bind_param("ii", $comment_id, $user_id);
    $check_stmt->execute();
    
    if ($check_stmt->get_result()->num_rows > 0) {
        // Unlike - remove like
        $stmt = $conn->prepare("DELETE FROM comment_likes WHERE comment_id = ? AND user_id = ?");
        $stmt->bind_param("ii", $comment_id, $user_id);
        $stmt->execute();
        
        // Get updated like count
        $count_stmt = $conn->prepare("SELECT COUNT(*) as count FROM comment_likes WHERE comment_id = ?");
        $count_stmt->bind_param("i", $comment_id);
        $count_stmt->execute();
        $count_result = $count_stmt->get_result();
        $count_row = $count_result->fetch_assoc();
        
        echo jsonResponse(true, 'Comment unliked', [
            'liked' => false,
            'like_count' => intval($count_row['count'])
        ]);
    } else {
        // Like - add like
        $stmt = $conn->prepare("INSERT INTO comment_likes (comment_id, user_id) VALUES (?, ?)");
        $stmt->bind_param("ii", $comment_id, $user_id);
        $stmt->execute();
        
        // Get updated like count
        $count_stmt = $conn->prepare("SELECT COUNT(*) as count FROM comment_likes WHERE comment_id = ?");
        $count_stmt->bind_param("i", $comment_id);
        $count_stmt->execute();
        $count_result = $count_stmt->get_result();
        $count_row = $count_result->fetch_assoc();
        
        echo jsonResponse(true, 'Comment liked', [
            'liked' => true,
            'like_count' => intval($count_row['count'])
        ]);
    }
}

function handleReportComment($conn) {
    $user_id = intval($_POST['user_id'] ?? 0);
    $comment_id = intval($_POST['comment_id'] ?? 0);
    $reason = trim($_POST['reason'] ?? '');
    $description = trim($_POST['description'] ?? $reason); // Use reason as description if description not provided
    
    if (!$user_id || !$comment_id) {
        http_response_code(400);
        echo jsonResponse(false, 'user_id and comment_id are required');
        return;
    }
    
    // Check if content_reports table exists
    $check_table = $conn->query("SHOW TABLES LIKE 'content_reports'");
    if ($check_table->num_rows === 0) {
        http_response_code(501);
        echo jsonResponse(false, 'Comment reports feature not available');
        return;
    }
    
    // Check if user already reported this comment
    $check_stmt = $conn->prepare("SELECT id FROM content_reports WHERE content_type = 'comment' AND content_id = ? AND user_id = ?");
    $check_stmt->bind_param("ii", $comment_id, $user_id);
    $check_stmt->execute();
    
    if ($check_stmt->get_result()->num_rows > 0) {
        http_response_code(400);
        echo jsonResponse(false, 'You have already reported this comment');
        return;
    }
    
    // Verify comment exists
    $comment_stmt = $conn->prepare("SELECT id FROM comments WHERE id = ?");
    $comment_stmt->bind_param("i", $comment_id);
    $comment_stmt->execute();
    if ($comment_stmt->get_result()->num_rows === 0) {
        http_response_code(404);
        echo jsonResponse(false, 'Comment not found');
        return;
    }
    
    // Insert report into content_reports table
    // content_type = 'comment', content_id = comment_id
    $stmt = $conn->prepare("INSERT INTO content_reports (user_id, content_type, content_id, reason, description, status) VALUES (?, 'comment', ?, ?, ?, 'Pending')");
    $stmt->bind_param("iiss", $user_id, $comment_id, $reason, $description);
    
    if ($stmt->execute()) {
        echo jsonResponse(true, 'Comment reported successfully. Our team will review it.', ['id' => $stmt->insert_id]);
    } else {
        http_response_code(500);
        echo jsonResponse(false, 'Failed to report comment: ' . $stmt->error);
    }
}

// edit feature: Handle edit comment request with 15-minute window
function handleEditComment($conn) { // edit feature
    // CRITICAL FIX: Add authentication check before processing
    $user_id = intval($_POST['user_id'] ?? 0); // edit feature
    $comment_id = intval($_POST['comment_id'] ?? 0); // edit feature
    $content = trim($_POST['content'] ?? ''); // edit feature
    $post_type = trim($_POST['post_type'] ?? ''); // edit feature
    $post_id = intval($_POST['post_id'] ?? 0); // edit feature
    
    // Authentication check - verify user exists and is active
    if ($user_id > 0) {
        $auth_check = $conn->prepare("SELECT id FROM users WHERE id = ? AND status = 'Active'");
        $auth_check->bind_param("i", $user_id);
        $auth_check->execute();
        if ($auth_check->get_result()->num_rows === 0) {
            http_response_code(401);
            echo jsonResponse(false, 'Unauthorized: User not found or inactive');
            return;
        }
    }
    
    // edit feature: Log incoming request
    error_log("📥 Edit Comment Request: user_id=$user_id, comment_id=$comment_id, post_type=$post_type, post_id=$post_id"); // edit feature
    
    // edit feature: Validation
    if (!$user_id || !$comment_id || empty($content)) { // edit feature
        http_response_code(400); // edit feature
        echo jsonResponse(false, 'user_id, comment_id, and content are required'); // edit feature
        return; // edit feature
    } // edit feature
    
    // edit feature: Content moderation check
    require_once '../includes/ContentModerationService.php'; // edit feature
    $moderation_result = ContentModerationService::checkContent($content, $conn); // edit feature
    
    // edit feature: Handle moderation result
    switch ($moderation_result['action']) { // edit feature
        case 'block': // edit feature
            http_response_code(400); // edit feature
            echo jsonResponse(false, 'Comment violates community guidelines.'); // edit feature
            return; // edit feature
        case 'quarantine': // edit feature
            http_response_code(400); // edit feature
            echo jsonResponse(false, 'Comment cannot be edited due to content policy.'); // edit feature
            return; // edit feature
        case 'warn': // edit feature
            $content = $moderation_result['sanitized_content']; // edit feature
            break; // edit feature
        case 'allow': // edit feature
        default: // edit feature
            break; // edit feature
    } // edit feature
    
    // edit feature: Determine table based on post_type
    if ($post_type === 'blog') { // edit feature
        $table = 'blog_comments'; // edit feature
        $content_field = 'comment'; // edit feature
        $id_field = 'blog_id'; // edit feature
    } else { // edit feature
        $table = 'comments'; // edit feature
        $content_field = 'content'; // edit feature
        $id_field = 'post_id'; // edit feature
    } // edit feature
    
    // edit feature: Verify user owns the comment
    $check_stmt = $conn->prepare("SELECT user_id, created_at, $id_field as post_id FROM $table WHERE id = ?"); // edit feature
    $check_stmt->bind_param("i", $comment_id); // edit feature
    $check_stmt->execute(); // edit feature
    $check_result = $check_stmt->get_result(); // edit feature
    
    if ($check_result->num_rows === 0) { // edit feature
        http_response_code(404); // edit feature
        echo jsonResponse(false, 'Comment not found'); // edit feature
        return; // edit feature
    } // edit feature
    
    $comment_data = $check_result->fetch_assoc(); // edit feature
    
    // edit feature: Check if user owns the comment
    if ($comment_data['user_id'] != $user_id) { // edit feature
        http_response_code(403); // edit feature
        echo jsonResponse(false, 'You can only edit your own comments'); // edit feature
        return; // edit feature
    } // edit feature
    
    $created_at = $comment_data['created_at']; // edit feature
    
    // DEBUG: Log timezone information for troubleshooting
    error_log("🔍 EDIT DEBUG - START ANALYSIS"); // debug
    error_log("🔍 COMMENT ID $comment_id ANALYSIS"); // debug
    error_log("🔍 Raw created_at from DB: '$created_at'"); // debug
    error_log("🔍 User timezone offset: " . ($_POST['timezone_offset'] ?? 'not sent')); // debug
    
    // FIXED: Use same timezone logic as frontend edit button check
    // Apply same 4-hour fix as TimeHelper.getTimeAgo
    $created_at_dt = new DateTime($created_at);
    $created_at_dt = $created_at_dt->add(new DateInterval('PT4H')); // 4-hour fix
    error_log("🔍 Created at with 4-hour fix: " . $created_at_dt->format('Y-m-d H:i:s')); // debug
    
    // Get current time in UTC and apply same 4-hour fix as frontend
    $now_dt = new DateTime('now', new DateTimeZone('UTC'));
    $now_dt = $now_dt->add(new DateInterval('PT4H')); // 4-hour fix - same as TimeHelper
    error_log("🔍 Current UTC (with 4hr fix): " . $now_dt->format('Y-m-d H:i:s UTC')); // debug
    
    // CRITICAL FIX: Calculate difference like TimeHelper (simple UTC difference)
    // Same logic as TimeHelper.getTimeAgo in Flutter
    $timestamp1 = $created_at_dt->getTimestamp();
    $timestamp2 = $now_dt->getTimestamp();
    $minutes_diff = abs(($timestamp2 - $timestamp1) / 60);
    
    // DEBUG: Show timestamp values
    error_log("🔍 TIMESTAMP ANALYSIS:"); // debug
    error_log("🔍   Created timestamp: $timestamp1"); // debug
    error_log("🔍   Current timestamp: $timestamp2"); // debug
    error_log("🔍   Timestamp difference: " . ($timestamp2 - $timestamp1)); // debug
    error_log("🔍   Minutes calculated: $minutes_diff"); // debug
    
    // DEBUG: Show detailed interval calculation
    error_log("🔍 INTERVAL ANALYSIS:"); // debug
    error_log("🔍   Interval invert: " . ($interval_diff->invert ? '1' : '0')); // debug
    error_log("🔍   Interval days: " . $interval_diff->days); // debug
    error_log("🔍   Interval hours: " . $interval_diff->h); // debug
    error_log("🔍   Interval minutes: " . $interval_diff->i); // debug
    error_log("🔍   Raw minutes calculation: (" . $interval_diff->days . " * 24 * 60) + (" . $interval_diff->h . " * 60) + " . $interval_diff->i . " = " . $minutes_diff); // debug
    
    error_log("🔍 Time difference calculation:"); // debug
    error_log("🔍   Created: " . $created_at_dt->format('Y-m-d H:i:s UTC')); // debug
    error_log("🔍   Now: " . $now_dt->format('Y-m-d H:i:s UTC')); // debug
    error_log("🔍   Days: {$interval_diff->days}, Hours: {$interval_diff->h}, Minutes: {$interval_diff->i}"); // debug
    error_log("�   Total minutes difference: $minutes_diff"); // debug
    error_log("🕐 Edit window check: minutes_diff=$minutes_diff, limit=15"); // debug
    error_log("🔍 EDIT DEBUG - Can edit: " . ($minutes_diff <= 15 ? 'YES' : 'NO')); // debug
    error_log("🔍 EDIT DEBUG - END ANALYSIS"); // debug
    
    if ($minutes_diff > 15) { // edit feature
        // Calculate timeAgo string for better debugging
        $time_ago = '';
        if ($interval_diff->y > 0) {
            $time_ago = $interval_diff->y . ' year' . ($interval_diff->y > 1 ? 's' : '') . ' ago';
        } elseif ($interval_diff->m > 0) {
            $time_ago = $interval_diff->m . ' month' . ($interval_diff->m > 1 ? 's' : '') . ' ago';
        } elseif ($interval_diff->d > 0) {
            $time_ago = $interval_diff->d . ' day' . ($interval_diff->d > 1 ? 's' : '') . ' ago';
        } elseif ($interval_diff->h > 0) {
            $time_ago = $interval_diff->h . ' hour' . ($interval_diff->h > 1 ? 's' : '') . ' ago';
        } elseif ($interval_diff->i > 0) {
            $time_ago = $interval_diff->i . ' minute' . ($interval_diff->i > 1 ? 's' : '') . ' ago';
        } else {
            $time_ago = 'Just now';
        }
        
        // Include debug info in response for frontend analysis
        $debug_info = [
            'created_at' => $created_at,
            'created_at_fixed' => $created_at_dt->format('Y-m-d H:i:s'),
            'current_utc' => $now_dt->format('Y-m-d H:i:s UTC'),
            'minutes_diff' => $minutes_diff,
            'created_timestamp' => $timestamp1,
            'current_timestamp' => $timestamp2,
            'timestamp_diff' => ($timestamp2 - $timestamp1),
            'timestamp_calculation' => "abs(($timestamp2 - $timestamp1) / 60) = $minutes_diff",
            'time_ago' => $time_ago,
            'timezone_offset' => $_POST['timezone_offset'] ?? 'not sent',
            'logic_used' => 'Same as TimeHelper.getTimeAgo (timestamp difference)',
            'debug_timestamp' => date('Y-m-d H:i:s')
        ];
        
        http_response_code(403); // edit feature
        echo jsonResponse(false, 'Comments can only be edited within 15 minutes of posting', $debug_info); // edit feature
        return; // edit feature
    } // edit feature
    
    // edit feature: Check if edited_at column exists
    $check_column = $conn->query("SHOW COLUMNS FROM $table LIKE 'edited_at'"); // edit feature
    $has_edited_at = $check_column && $check_column->num_rows > 0; // edit feature
    
    // edit feature: Build update query
    if ($has_edited_at) { // edit feature
        $update_stmt = $conn->prepare("UPDATE $table SET $content_field = ?, edited_at = NOW(), is_edited = 1 WHERE id = ?"); // edit feature
        $update_stmt->bind_param("si", $content, $comment_id); // edit feature
    } else { // edit feature
        $update_stmt = $conn->prepare("UPDATE $table SET $content_field = ? WHERE id = ?"); // edit feature
        $update_stmt->bind_param("si", $content, $comment_id); // edit feature
    } // edit feature
    
    if ($update_stmt->execute()) { // edit feature
        error_log("✅ Comment edited: ID=$comment_id, user_id=$user_id"); // edit feature
        echo jsonResponse(true, 'Comment edited successfully', [ // edit feature
            'id' => $comment_id, // edit feature
            'content' => $content, // edit feature
            'is_edited' => true // edit feature
        ]); // edit feature
    } else { // edit feature
        error_log("❌ Failed to edit comment: " . $update_stmt->error); // edit feature
        http_response_code(500); // edit feature
        echo jsonResponse(false, 'Failed to edit comment: ' . $update_stmt->error); // edit feature
    } // edit feature
} // edit feature

function handleDeleteComment($conn) {
    $user_id = intval($_POST['user_id'] ?? 0);
    $comment_id = intval($_POST['comment_id'] ?? 0);
    $post_type = trim($_POST['post_type'] ?? '');

    if (!$user_id || !$comment_id) {
        http_response_code(400);
        echo jsonResponse(false, 'user_id and comment_id are required');
        return;
    }

    if ($post_type === 'blog') {
        $check_stmt = $conn->prepare("SELECT user_id FROM blog_comments WHERE id = ?");
        $check_stmt->bind_param("i", $comment_id);
        $check_stmt->execute();
        $check_result = $check_stmt->get_result();

        if ($check_result->num_rows === 0) {
            http_response_code(404);
            echo jsonResponse(false, 'Comment not found');
            return;
        }

        $comment_data = $check_result->fetch_assoc();

        if ($comment_data['user_id'] != $user_id) {
            http_response_code(403);
            echo jsonResponse(false, 'You can only delete your own comments');
            return;
        }

        $delete_stmt = $conn->prepare("DELETE FROM blog_comments WHERE id = ?");
        $delete_stmt->bind_param("i", $comment_id);
    } else {
        $check_is_deleted = $conn->query("SHOW COLUMNS FROM comments LIKE 'is_deleted'");
        $has_is_deleted = $check_is_deleted && $check_is_deleted->num_rows > 0;

        $select_sql = $has_is_deleted
            ? "SELECT user_id FROM comments WHERE id = ? AND is_deleted = 0"
            : "SELECT user_id FROM comments WHERE id = ?";
        $check_stmt = $conn->prepare($select_sql);
        $check_stmt->bind_param("i", $comment_id);
        $check_stmt->execute();
        $check_result = $check_stmt->get_result();

        if ($check_result->num_rows === 0) {
            http_response_code(404);
            echo jsonResponse(false, 'Comment not found');
            return;
        }

        $comment_data = $check_result->fetch_assoc();

        if ($comment_data['user_id'] != $user_id) {
            http_response_code(403);
            echo jsonResponse(false, 'You can only delete your own comments');
            return;
        }

        if ($has_is_deleted) {
            $delete_stmt = $conn->prepare("UPDATE comments SET is_deleted = 1 WHERE id = ?");
        } else {
            $delete_stmt = $conn->prepare("DELETE FROM comments WHERE id = ?");
        }
        $delete_stmt->bind_param("i", $comment_id);
    }

    if ($delete_stmt->execute()) {
        echo jsonResponse(true, 'Comment deleted successfully', ['id' => $comment_id]);
    } else {
        http_response_code(500);
        echo jsonResponse(false, 'Failed to delete comment: ' . $delete_stmt->error);
    }
}

$conn->close();

// End output buffering and send response
ob_end_flush();