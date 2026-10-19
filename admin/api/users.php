<?php
/**
 * Users API
 * Handles: Search users, Get user list for tagging
 */

require_once '../includes/db.php';
require_once '../includes/cors.php';
require_once 'auth-helper.php';

header('Content-Type: application/json; charset=utf-8');

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'OPTIONS') {
    http_response_code(200);
    exit;
}

switch ($method) {
    case 'GET':
        handleGetUsers($conn);
        break;
    default:
        http_response_code(405);
        echo jsonResponse(false, 'Method not allowed');
        break;
}

function handleGetUsers($conn) {
    $search = trim($_GET['search'] ?? '');
    $status = trim($_GET['status'] ?? 'Active');
    $limit = intval($_GET['limit'] ?? 50);
    $offset = intval($_GET['offset'] ?? 0);
    
    $sql = "SELECT id, name, email, phone, profile_photo, status 
            FROM users 
            WHERE status = ?";
    $params = [$status];
    $types = "s";
    
    if (!empty($search)) {
        $sql .= " AND (name LIKE ? OR email LIKE ? OR phone LIKE ?)";
        $searchTerm = '%' . $search . '%';
        $params[] = $searchTerm;
        $params[] = $searchTerm;
        $params[] = $searchTerm;
        $types .= "sss";
    }
    
    $sql .= " ORDER BY name ASC LIMIT ? OFFSET ?";
    $params[] = $limit;
    $params[] = $offset;
    $types .= "ii";
    
    $stmt = $conn->prepare($sql);
    $stmt->bind_param($types, ...$params);
    $stmt->execute();
    $result = $stmt->get_result();
    
    $users = [];
    while ($row = $result->fetch_assoc()) {
        $users[] = $row;
    }
    
    echo jsonResponse(true, 'Users retrieved', $users);
}

$conn->close();
?>

