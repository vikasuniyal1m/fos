<?php
/**
 * Analytics API
 * Handles: User engagement stats, Popular content, Trending content
 */

require_once '../includes/db.php';
require_once '../includes/cors.php';
require_once 'auth-helper.php';

header('Content-Type: application/json');

$method = $_SERVER['REQUEST_METHOD'];
$action = $_GET['action'] ?? $_POST['action'] ?? '';

if ($method === 'OPTIONS') {
    http_response_code(200);
    exit;
}

if ($method !== 'GET') {
    http_response_code(405);
    echo jsonResponse(false, 'Method not allowed');
    exit;
}

switch ($action) {
    case 'user-stats':
        handleUserStats($conn);
        break;
    case 'popular':
        handlePopularContent($conn);
        break;
    case 'trending':
        handleTrendingContent($conn);
        break;
    case 'engagement':
        handleEngagementStats($conn);
        break;
    default:
        handleGeneralStats($conn);
        break;
}

function handleUserStats($conn) {
    $user_id = intval($_GET['user_id'] ?? 0);
    
    if (!$user_id) {
        http_response_code(400);
        echo jsonResponse(false, 'user_id is required');
        return;
    }
    
    // Get user stats
    $stats = [];
    
    // Blogs count
    $blogs_stmt = $conn->prepare("SELECT COUNT(*) as count FROM blogs WHERE user_id = ? AND status = 'Approved'");
    $blogs_stmt->bind_param("i", $user_id);
    $blogs_stmt->execute();
    $stats['blogs_count'] = intval($blogs_stmt->get_result()->fetch_assoc()['count']);
    
    // Prayers count
    $prayers_stmt = $conn->prepare("SELECT COUNT(*) as count FROM prayer_requests WHERE user_id = ? AND status = 'Approved'");
    $prayers_stmt->bind_param("i", $user_id);
    $prayers_stmt->execute();
    $stats['prayers_count'] = intval($prayers_stmt->get_result()->fetch_assoc()['count']);
    
    // Videos count
    $videos_stmt = $conn->prepare("SELECT COUNT(*) as count FROM media_items WHERE user_id = ? AND type = 'video' AND status = 'Approved'");
    $videos_stmt->bind_param("i", $user_id);
    $videos_stmt->execute();
    $stats['videos_count'] = intval($videos_stmt->get_result()->fetch_assoc()['count']);
    
    // Photos count
    $photos_stmt = $conn->prepare("SELECT COUNT(*) as count FROM media_items WHERE user_id = ? AND type = 'photo' AND status = 'Approved'");
    $photos_stmt->bind_param("i", $user_id);
    $photos_stmt->execute();
    $stats['photos_count'] = intval($photos_stmt->get_result()->fetch_assoc()['count']);
    
    // Stories count
    $stories_stmt = $conn->query("SHOW TABLES LIKE 'stories'");
    if ($stories_stmt->num_rows > 0) {
        $stories_count_stmt = $conn->prepare("SELECT COUNT(*) as count FROM stories WHERE user_id = ? AND status = 'Approved'");
        $stories_count_stmt->bind_param("i", $user_id);
        $stories_count_stmt->execute();
        $stats['stories_count'] = intval($stories_count_stmt->get_result()->fetch_assoc()['count']);
    } else {
        $stats['stories_count'] = 0;
    }
    
    // Total likes received
    $likes_stmt = $conn->prepare("
        SELECT COUNT(*) as count FROM blog_likes bl
        JOIN blogs b ON bl.blog_id = b.id
        WHERE b.user_id = ?
    ");
    $likes_stmt->bind_param("i", $user_id);
    $likes_stmt->execute();
    $stats['total_likes'] = intval($likes_stmt->get_result()->fetch_assoc()['count']);
    
    // Total comments received
    $comments_stmt = $conn->prepare("
        SELECT COUNT(*) as count FROM comments c
        WHERE c.post_id IN (
            SELECT id FROM blogs WHERE user_id = ?
            UNION
            SELECT id FROM prayer_requests WHERE user_id = ?
            UNION
            SELECT id FROM media_items WHERE user_id = ?
        ) AND c.status = 'approved'
    ");
    $comments_stmt->bind_param("iii", $user_id, $user_id, $user_id);
    $comments_stmt->execute();
    $stats['total_comments'] = intval($comments_stmt->get_result()->fetch_assoc()['count']);
    
    echo jsonResponse(true, 'User stats retrieved', $stats);
}

function handlePopularContent($conn) {
    $type = trim($_GET['type'] ?? 'all'); // all, blogs, videos, photos
    $limit = intval($_GET['limit'] ?? 10);
    
    $results = [];
    
    // Popular Blogs (by likes)
    if ($type === 'all' || $type === 'blogs') {
        $blogs_stmt = $conn->prepare("
            SELECT b.*, u.name as user_name, u.profile_photo,
                   (SELECT COUNT(*) FROM blog_likes WHERE blog_id = b.id) as like_count,
                   (SELECT COUNT(*) FROM blog_comments WHERE blog_id = b.id) as comment_count
            FROM blogs b
            JOIN users u ON b.user_id = u.id
            WHERE b.status = 'Approved'
            ORDER BY like_count DESC, comment_count DESC
            LIMIT ?
        ");
        $blogs_stmt->bind_param("i", $limit);
        $blogs_stmt->execute();
        $blogs_result = $blogs_stmt->get_result();
        
        while ($blog = $blogs_result->fetch_assoc()) {
            $results[] = array_merge($blog, ['content_type' => 'blog']);
        }
    }
    
    // Popular Videos (by comments)
    if ($type === 'all' || $type === 'videos') {
        $videos_stmt = $conn->prepare("
            SELECT m.*, u.name as user_name, u.profile_photo,
                   (SELECT COUNT(*) FROM comments WHERE post_type = 'video' AND post_id = m.id AND status = 'approved') as comment_count
            FROM media_items m
            JOIN users u ON m.user_id = u.id
            WHERE m.type = 'video' AND m.status = 'Approved'
            ORDER BY comment_count DESC
            LIMIT ?
        ");
        $videos_stmt->bind_param("i", $limit);
        $videos_stmt->execute();
        $videos_result = $videos_stmt->get_result();
        
        while ($video = $videos_result->fetch_assoc()) {
            $results[] = array_merge($video, ['content_type' => 'video']);
        }
    }
    
    echo jsonResponse(true, 'Popular content retrieved', $results);
}

function handleTrendingContent($conn) {
    $type = trim($_GET['type'] ?? 'all');
    $limit = intval($_GET['limit'] ?? 10);
    $days = intval($_GET['days'] ?? 7); // Trending in last N days
    
    $results = [];
    $date_threshold = date('Y-m-d H:i:s', strtotime("-{$days} days"));
    
    // Trending Blogs (recent + high engagement)
    if ($type === 'all' || $type === 'blogs') {
        $blogs_stmt = $conn->prepare("
            SELECT b.*, u.name as user_name, u.profile_photo,
                   (SELECT COUNT(*) FROM blog_likes WHERE blog_id = b.id) as like_count,
                   (SELECT COUNT(*) FROM blog_comments WHERE blog_id = b.id) as comment_count
            FROM blogs b
            JOIN users u ON b.user_id = u.id
            WHERE b.status = 'Approved' AND b.created_at >= ?
            ORDER BY (like_count * 2 + comment_count) DESC, b.created_at DESC
            LIMIT ?
        ");
        $blogs_stmt->bind_param("si", $date_threshold, $limit);
        $blogs_stmt->execute();
        $blogs_result = $blogs_stmt->get_result();
        
        while ($blog = $blogs_result->fetch_assoc()) {
            $results[] = array_merge($blog, ['content_type' => 'blog']);
        }
    }
    
    echo jsonResponse(true, 'Trending content retrieved', $results);
}

function handleEngagementStats($conn) {
    $fruit_tag = trim($_GET['fruit_tag'] ?? '');
    
    $stats = [];
    
    // Active users per fruit
    $fruits_stmt = $conn->query("
        SELECT f.name, COUNT(uf.user_id) as active_users
        FROM fruits f
        LEFT JOIN user_fruits uf ON f.id = uf.fruit_id
        GROUP BY f.id, f.name
        ORDER BY active_users DESC
    ");
    
    $stats['fruits_engagement'] = [];
    while ($row = $fruits_stmt->fetch_assoc()) {
        $stats['fruits_engagement'][] = $row;
    }
    
    // Top emojis
    $emojis_stmt = $conn->query("
        SELECT name, emoji_char, usage_count
        FROM emojis
        WHERE status = 'Active'
        ORDER BY usage_count DESC
        LIMIT 10
    ");
    
    $stats['top_emojis'] = [];
    while ($row = $emojis_stmt->fetch_assoc()) {
        $stats['top_emojis'][] = $row;
    }
    
    // Content stats
    $stats['total_blogs'] = intval($conn->query("SELECT COUNT(*) as count FROM blogs WHERE status = 'Approved'")->fetch_assoc()['count']);
    $stats['total_prayers'] = intval($conn->query("SELECT COUNT(*) as count FROM prayer_requests WHERE status = 'Approved'")->fetch_assoc()['count']);
    $stats['total_videos'] = intval($conn->query("SELECT COUNT(*) as count FROM media_items WHERE type = 'video' AND status = 'Approved'")->fetch_assoc()['count']);
    $stats['total_photos'] = intval($conn->query("SELECT COUNT(*) as count FROM media_items WHERE type = 'photo' AND status = 'Approved'")->fetch_assoc()['count']);
    
    echo jsonResponse(true, 'Engagement stats retrieved', $stats);
}

function handleGeneralStats($conn) {
    $stats = [
        'total_users' => intval($conn->query("SELECT COUNT(*) as count FROM users WHERE status = 'Active'")->fetch_assoc()['count']),
        'total_blogs' => intval($conn->query("SELECT COUNT(*) as count FROM blogs WHERE status = 'Approved'")->fetch_assoc()['count']),
        'total_prayers' => intval($conn->query("SELECT COUNT(*) as count FROM prayer_requests WHERE status = 'Approved'")->fetch_assoc()['count']),
        'total_videos' => intval($conn->query("SELECT COUNT(*) as count FROM media_items WHERE type = 'video' AND status = 'Approved'")->fetch_assoc()['count']),
        'total_photos' => intval($conn->query("SELECT COUNT(*) as count FROM media_items WHERE type = 'photo' AND status = 'Approved'")->fetch_assoc()['count']),
        'total_groups' => intval($conn->query("SELECT COUNT(*) as count FROM groups WHERE status = 'Active'")->fetch_assoc()['count']),
    ];
    
    echo jsonResponse(true, 'General stats retrieved', $stats);
}

$conn->close();
?>

