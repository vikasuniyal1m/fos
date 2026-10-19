<?php
/**
 * Search API
 * Handles: Full-text search across blogs, prayers, videos, photos, stories
 */

error_reporting(E_ALL);
ini_set('display_errors', 0);
ob_start();

require_once '../includes/db.php';
require_once '../includes/cors.php';
require_once 'auth-helper.php';

header('Content-Type: application/json; charset=utf-8');

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'OPTIONS') {
    http_response_code(200);
    exit;
}

if ($method !== 'GET') {
    http_response_code(405);
    echo jsonResponse(false, 'Method not allowed');
    exit;
}

function handleSearch($conn) {
    // Require authentication
    $user = requireAuth($conn);
    
    $query = trim($_GET['q'] ?? '');
    $type = trim($_GET['type'] ?? 'all'); // all, blogs, prayers, videos, photos, stories
    $fruit_tag = trim($_GET['fruit_tag'] ?? '');
    $limit = intval($_GET['limit'] ?? 20);
    $offset = intval($_GET['offset'] ?? 0);
    
    $results = [
        'blogs' => [],
        'prayers' => [],
        'videos' => [],
        'photos' => [],
        'stories' => []
    ];
    
    // If query is empty, return all content (for initial load)
    // Otherwise, filter by search term
    $searchTerm = empty($query) ? '%' : '%' . $query . '%';
    
    // Search Blogs
    if ($type === 'all' || $type === 'blogs') {
        $sql = "SELECT b.id, b.title, b.body, b.category, b.language, b.status, b.created_at,
                       b.image_url,
                       u.name as user_name, u.profile_photo,
                       (SELECT COUNT(*) FROM blog_comments WHERE blog_id = b.id) as comment_count,
                       (SELECT COUNT(*) FROM blog_likes WHERE blog_id = b.id) as like_count,
                       'blog' as result_type
                FROM blogs b
                JOIN users u ON b.user_id = u.id
                WHERE b.status = 'Approved'";
        
        $params = [];
        $types = "";
        
        // Add search condition only if query is not empty
        if (!empty($query)) {
            $sql .= " AND (b.title LIKE ? OR b.body LIKE ?)";
            $params[] = $searchTerm;
            $params[] = $searchTerm;
            $types = "ss";
        }
        
        if ($fruit_tag) {
            // Blogs don't have fruit_tag, but we can search by category
            $sql .= " AND b.category LIKE ?";
            $params[] = '%' . $fruit_tag . '%';
            $types .= "s";
        }
        
        $sql .= " ORDER BY b.created_at DESC LIMIT ? OFFSET ?";
        $params[] = $limit;
        $params[] = $offset;
        $types .= "ii";
        
        $stmt = $conn->prepare($sql);
        // We always have limit and offset, so always bind parameters
        $stmt->bind_param($types, ...$params);
        $stmt->execute();
        $result = $stmt->get_result();
        
        while ($row = $result->fetch_assoc()) {
            $results['blogs'][] = $row;
        }
        $stmt->close();
    }
    
    // Search Prayers
    if ($type === 'all' || $type === 'prayers') {
        $sql = "SELECT pr.id, pr.content, pr.category, pr.status, pr.created_at, pr.is_anonymous,
                       u.name as user_name, u.profile_photo,
                       (SELECT COUNT(*) FROM comments WHERE post_type = 'prayer' AND post_id = pr.id AND status = 'approved') as response_count,
                       'prayer' as result_type
                FROM prayer_requests pr
                JOIN users u ON pr.user_id = u.id
                WHERE pr.status = 'Approved'";
        
        $params = [];
        $types = "";
        
        // Add search condition only if query is not empty
        if (!empty($query)) {
            $sql .= " AND (pr.content LIKE ? OR pr.category LIKE ?)";
            $params[] = $searchTerm;
            $params[] = $searchTerm;
            $types = "ss";
        }
        
        if ($fruit_tag) {
            $sql .= " AND pr.category LIKE ?";
            $params[] = '%' . $fruit_tag . '%';
            $types .= "s";
        }
        
        $sql .= " ORDER BY pr.created_at DESC LIMIT ? OFFSET ?";
        $params[] = $limit;
        $params[] = $offset;
        $types .= "ii";
        
        $stmt = $conn->prepare($sql);
        // We always have limit and offset, so always bind parameters
        $stmt->bind_param($types, ...$params);
        $stmt->execute();
        $result = $stmt->get_result();
        
        while ($row = $result->fetch_assoc()) {
            $results['prayers'][] = $row;
        }
        $stmt->close();
    }
    
    // Search Videos
    if ($type === 'all' || $type === 'videos') {
        $sql = "SELECT m.id, m.title, m.description, m.file_path, m.fruit_tag, m.status, m.created_at,
                       u.name as user_name, u.profile_photo,
                       (SELECT COUNT(*) FROM comments WHERE post_type = 'video' AND post_id = m.id AND status = 'approved') as comment_count,
                       'video' as result_type
                FROM media_items m
                JOIN users u ON m.user_id = u.id
                WHERE m.type = 'video' AND m.status = 'Approved'";
        
        $params = [];
        $types = "";
        
        // Add search condition only if query is not empty
        if (!empty($query)) {
            $sql .= " AND (m.title LIKE ? OR m.description LIKE ?)";
            $params = [$searchTerm, $searchTerm];
            $types = "ss";
        }
        
        if ($fruit_tag) {
            $sql .= " AND m.fruit_tag = ?";
            $params[] = $fruit_tag;
            $types .= "s";
        }
        
        $sql .= " ORDER BY m.created_at DESC LIMIT ? OFFSET ?";
        $params[] = $limit;
        $params[] = $offset;
        $types .= "ii";
        
        $stmt = $conn->prepare($sql);
        // We always have limit and offset, so always bind parameters
        $stmt->bind_param($types, ...$params);
        $stmt->execute();
        $result = $stmt->get_result();
        
        while ($row = $result->fetch_assoc()) {
            $results['videos'][] = $row;
        }
        $stmt->close();
    }
    
    // Search Photos
    if ($type === 'all' || $type === 'photos') {
        $sql = "SELECT m.id, m.title, m.description, m.file_path, m.fruit_tag, m.status, m.created_at,
                       u.name as user_name, u.profile_photo,
                       (SELECT COUNT(*) FROM comments WHERE post_type = 'gallery' AND post_id = m.id AND status = 'approved') as comment_count,
                       'photo' as result_type
                FROM media_items m
                JOIN users u ON m.user_id = u.id
                WHERE m.type = 'photo' AND m.status = 'Approved'";
        
        $params = [];
        $types = "";
        
        // Add search condition only if query is not empty
        if (!empty($query)) {
            $sql .= " AND (m.title LIKE ? OR m.description LIKE ?)";
            $params = [$searchTerm, $searchTerm];
            $types = "ss";
        }
        
        if ($fruit_tag) {
            $sql .= " AND m.fruit_tag = ?";
            $params[] = $fruit_tag;
            $types .= "s";
        }
        
        $sql .= " ORDER BY m.created_at DESC LIMIT ? OFFSET ?";
        $params[] = $limit;
        $params[] = $offset;
        $types .= "ii";
        
        $stmt = $conn->prepare($sql);
        // We always have limit and offset, so always bind parameters
        $stmt->bind_param($types, ...$params);
        $stmt->execute();
        $result = $stmt->get_result();
        
        while ($row = $result->fetch_assoc()) {
            $results['photos'][] = $row;
        }
        $stmt->close();
    }
    
    // Search Stories
    if ($type === 'all' || $type === 'stories') {
        // Check if stories table exists
        $table_check = $conn->query("SHOW TABLES LIKE 'stories'");
        if ($table_check->num_rows > 0) {
            $sql = "SELECT s.id, s.title, s.content, s.fruit_tag, s.category, s.status, s.created_at,
                           u.name as user_name, u.profile_photo,
                           (SELECT COUNT(*) FROM comments WHERE post_type = 'story' AND post_id = s.id AND status = 'approved') as comment_count,
                           'story' as result_type
                    FROM stories s
                    JOIN users u ON s.user_id = u.id
                    WHERE s.status = 'Approved'";
            
            $params = [];
            $types = "";
            
            // Add search condition only if query is not empty
            if (!empty($query)) {
                $sql .= " AND (s.title LIKE ? OR s.content LIKE ?)";
                $params[] = $searchTerm;
                $params[] = $searchTerm;
                $types = "ss";
            }
            
            if ($fruit_tag) {
                $sql .= " AND s.fruit_tag = ?";
                $params[] = $fruit_tag;
                $types .= "s";
            }
            
            $sql .= " ORDER BY s.created_at DESC LIMIT ? OFFSET ?";
            $params[] = $limit;
            $params[] = $offset;
            $types .= "ii";
            
            $stmt = $conn->prepare($sql);
            // We always have limit and offset, so always bind parameters
            $stmt->bind_param($types, ...$params);
            $stmt->execute();
            $result = $stmt->get_result();
            
            while ($row = $result->fetch_assoc()) {
                $results['stories'][] = $row;
            }
            $stmt->close();
        }
    }
    
    // Calculate totals
    $total = count($results['blogs']) + count($results['prayers']) + 
             count($results['videos']) + count($results['photos']) + 
             count($results['stories']);
    
    ob_clean();
    echo jsonResponse(true, "Found {$total} results", [
        'query' => $query,
        'type' => $type,
        'total' => $total,
        'results' => $results
    ]);
}

try {
    handleSearch($conn);
} catch (Exception $e) {
    ob_clean();
    http_response_code(500);
    error_log('Search error: ' . $e->getMessage());
    echo jsonResponse(false, 'Search failed: ' . $e->getMessage());
} catch (Error $e) {
    ob_clean();
    http_response_code(500);
    error_log('Search fatal error: ' . $e->getMessage());
    echo jsonResponse(false, 'Search failed: ' . $e->getMessage());
}

$conn->close();

