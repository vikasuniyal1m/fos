<?php
/**
 * Gallery Comments API
 * Handles comments for gallery photos using gallery_comments table
 * 
 * Endpoints:
 * - POST: action=add-comment (Add comment or reply)
 * - GET: action=get-comments (Get comments for a photo)
 * - POST: action=like-comment (Like/unlike a comment)
 * - POST: action=delete-comment (Delete a comment - optional)
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-API-Key');

// Handle preflight requests
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

require_once '../config/database.php'; // Adjust path as needed

try {
    $pdo = new PDO(
        "mysql:host=$db_host;dbname=$db_name;charset=utf8mb4",
        $db_user,
        $db_pass,
        [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC
        ]
    );
} catch (PDOException $e) {
    echo json_encode([
        'success' => false,
        'message' => 'Database connection failed'
    ]);
    exit;
}

// Get action from POST or GET
$action = $_POST['action'] ?? $_GET['action'] ?? '';

// =====================================================
// 1. ADD COMMENT (POST: action=add-comment)
// =====================================================
if ($action == 'add-comment') {
    // Validate required fields
    if (!isset($_POST['photo_id']) || !isset($_POST['user_id']) || !isset($_POST['content'])) {
        echo json_encode([
            'success' => false,
            'message' => 'Missing required fields: photo_id, user_id, content'
        ]);
        exit;
    }
    
    $photo_id = intval($_POST['photo_id']);
    $user_id = intval($_POST['user_id']);
    $content = trim($_POST['content']);
    $parent_comment_id = isset($_POST['parent_comment_id']) && $_POST['parent_comment_id'] > 0 
        ? intval($_POST['parent_comment_id']) 
        : null;
    
    // Validate content is not empty
    if (empty($content)) {
        echo json_encode([
            'success' => false,
            'message' => 'Comment content cannot be empty'
        ]);
        exit;
    }
    
    // Check if photo exists
    $checkPhoto = $pdo->prepare("SELECT id FROM gallery_photos WHERE id = ? AND status = 'Approved'");
    $checkPhoto->execute([$photo_id]);
    if ($checkPhoto->rowCount() == 0) {
        echo json_encode([
            'success' => false,
            'message' => 'Photo not found or not approved'
        ]);
        exit;
    }
    
    // If it's a reply, check if parent comment exists
    if ($parent_comment_id !== null) {
        $checkParent = $pdo->prepare("SELECT id FROM gallery_comments WHERE id = ? AND photo_id = ? AND is_deleted = 0");
        $checkParent->execute([$parent_comment_id, $photo_id]);
        if ($checkParent->rowCount() == 0) {
            echo json_encode([
                'success' => false,
                'message' => 'Parent comment not found'
            ]);
            exit;
        }
    }
    
    // Insert comment
    $sql = "INSERT INTO gallery_comments (photo_id, user_id, content, parent_comment_id) 
            VALUES (?, ?, ?, ?)";
    $stmt = $pdo->prepare($sql);
    $stmt->execute([$photo_id, $user_id, $content, $parent_comment_id]);
    
    $comment_id = $pdo->lastInsertId();
    
    // Update reply_count if it's a reply
    if ($parent_comment_id !== null) {
        $updateReplyCount = $pdo->prepare("
            UPDATE gallery_comments 
            SET reply_count = reply_count + 1 
            WHERE id = ?
        ");
        $updateReplyCount->execute([$parent_comment_id]);
    }
    
    // Return success with comment ID
    echo json_encode([
        'success' => true,
        'message' => 'Comment added successfully',
        'data' => [
            'id' => $comment_id,
            'comment_id' => $comment_id,
            'is_reply' => $parent_comment_id !== null
        ]
    ]);
    exit;
}

// =====================================================
// 2. GET COMMENTS (GET: action=get-comments)
// =====================================================
if ($action == 'get-comments') {
    if (!isset($_GET['photo_id'])) {
        echo json_encode([
            'success' => false,
            'message' => 'photo_id is required'
        ]);
        exit;
    }
    
    $photo_id = intval($_GET['photo_id']);
    $current_user_id = isset($_GET['user_id']) ? intval($_GET['user_id']) : null;
    
    // Get top-level comments with user info
    $sql = "
        SELECT 
            gc.id,
            gc.photo_id,
            gc.user_id,
            gc.content,
            gc.parent_comment_id,
            gc.like_count,
            gc.reply_count,
            gc.is_deleted,
            gc.created_at,
            gc.updated_at,
            u.name as user_name,
            u.profile_photo,
            CASE 
                WHEN ? IS NOT NULL THEN (
                    SELECT COUNT(*) 
                    FROM gallery_comment_likes gcl 
                    WHERE gcl.comment_id = gc.id AND gcl.user_id = ?
                )
                ELSE 0
            END as is_liked
        FROM gallery_comments gc
        JOIN users u ON gc.user_id = u.id
        WHERE gc.photo_id = ? 
            AND gc.is_deleted = 0 
            AND gc.parent_comment_id IS NULL
        ORDER BY gc.created_at DESC
    ";
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute([$current_user_id, $current_user_id, $photo_id]);
    $comments = $stmt->fetchAll();
    
    // Get replies for each comment
    foreach ($comments as &$comment) {
        $replySql = "
            SELECT 
                gc.id,
                gc.photo_id,
                gc.user_id,
                gc.content,
                gc.parent_comment_id,
                gc.like_count,
                gc.reply_count,
                gc.is_deleted,
                gc.created_at,
                gc.updated_at,
                u.name as user_name,
                u.profile_photo,
                CASE 
                    WHEN ? IS NOT NULL THEN (
                        SELECT COUNT(*) 
                        FROM gallery_comment_likes gcl 
                        WHERE gcl.comment_id = gc.id AND gcl.user_id = ?
                    )
                    ELSE 0
                END as is_liked
            FROM gallery_comments gc
            JOIN users u ON gc.user_id = u.id
            WHERE gc.parent_comment_id = ? 
                AND gc.is_deleted = 0
            ORDER BY gc.created_at ASC
        ";
        
        $replyStmt = $pdo->prepare($replySql);
        $replyStmt->execute([$current_user_id, $current_user_id, $comment['id']]);
        $comment['replies'] = $replyStmt->fetchAll();
    }
    
    echo json_encode([
        'success' => true,
        'message' => 'Comments retrieved successfully',
        'data' => $comments
    ]);
    exit;
}

// =====================================================
// 3. LIKE/UNLIKE COMMENT (POST: action=like-comment)
// =====================================================
if ($action == 'like-comment') {
    if (!isset($_POST['comment_id']) || !isset($_POST['user_id'])) {
        echo json_encode([
            'success' => false,
            'message' => 'comment_id and user_id are required'
        ]);
        exit;
    }
    
    $comment_id = intval($_POST['comment_id']);
    $user_id = intval($_POST['user_id']);
    
    // Check if comment exists
    $checkComment = $pdo->prepare("SELECT id, like_count FROM gallery_comments WHERE id = ? AND is_deleted = 0");
    $checkComment->execute([$comment_id]);
    if ($checkComment->rowCount() == 0) {
        echo json_encode([
            'success' => false,
            'message' => 'Comment not found'
        ]);
        exit;
    }
    
    // Check if already liked
    $checkLike = $pdo->prepare("SELECT id FROM gallery_comment_likes WHERE comment_id = ? AND user_id = ?");
    $checkLike->execute([$comment_id, $user_id]);
    $isLiked = $checkLike->rowCount() > 0;
    
    if ($isLiked) {
        // Unlike: Remove from likes table
        $deleteLike = $pdo->prepare("DELETE FROM gallery_comment_likes WHERE comment_id = ? AND user_id = ?");
        $deleteLike->execute([$comment_id, $user_id]);
        
        // Update like_count
        $updateCount = $pdo->prepare("UPDATE gallery_comments SET like_count = GREATEST(like_count - 1, 0) WHERE id = ?");
        $updateCount->execute([$comment_id]);
        
        echo json_encode([
            'success' => true,
            'message' => 'Comment unliked',
            'data' => ['liked' => false]
        ]);
    } else {
        // Like: Add to likes table
        $insertLike = $pdo->prepare("INSERT INTO gallery_comment_likes (comment_id, user_id) VALUES (?, ?)");
        $insertLike->execute([$comment_id, $user_id]);
        
        // Update like_count
        $updateCount = $pdo->prepare("UPDATE gallery_comments SET like_count = like_count + 1 WHERE id = ?");
        $updateCount->execute([$comment_id]);
        
        echo json_encode([
            'success' => true,
            'message' => 'Comment liked',
            'data' => ['liked' => true]
        ]);
    }
    exit;
}

// =====================================================
// 4. DELETE COMMENT (POST: action=delete-comment) - Optional
// =====================================================
if ($action == 'delete-comment') {
    if (!isset($_POST['comment_id']) || !isset($_POST['user_id'])) {
        echo json_encode([
            'success' => false,
            'message' => 'comment_id and user_id are required'
        ]);
        exit;
    }
    
    $comment_id = intval($_POST['comment_id']);
    $user_id = intval($_POST['user_id']);
    
    // Check if user owns the comment or is admin
    $checkOwner = $pdo->prepare("SELECT user_id FROM gallery_comments WHERE id = ? AND is_deleted = 0");
    $checkOwner->execute([$comment_id]);
    $comment = $checkOwner->fetch();
    
    if (!$comment) {
        echo json_encode([
            'success' => false,
            'message' => 'Comment not found'
        ]);
        exit;
    }
    
    // Check if user is owner (add admin check as needed)
    if ($comment['user_id'] != $user_id) {
        echo json_encode([
            'success' => false,
            'message' => 'You can only delete your own comments'
        ]);
        exit;
    }
    
    // Soft delete
    $deleteStmt = $pdo->prepare("UPDATE gallery_comments SET is_deleted = 1 WHERE id = ?");
    $deleteStmt->execute([$comment_id]);
    
    echo json_encode([
        'success' => true,
        'message' => 'Comment deleted successfully'
    ]);
    exit;
}

// =====================================================
// Invalid action
// =====================================================
echo json_encode([
    'success' => false,
    'message' => 'Invalid action. Supported actions: add-comment, get-comments, like-comment, delete-comment'
]);
?>

