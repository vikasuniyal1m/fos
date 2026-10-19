<?php
/**
 * Fruits of the Spirit API
 * Handles: List all fruits, Get user fruits, Select/Add fruits, Remove fruits
 */

require_once '../includes/db.php';
require_once '../includes/cors.php';
require_once 'auth-helper.php';

header('Content-Type: application/json');

$method = $_SERVER['REQUEST_METHOD'];

// Handle OPTIONS request
if ($method === 'OPTIONS') {
    http_response_code(200);
    exit;
}

switch ($method) {
    case 'GET':
        handleGetFruits($conn);
        break;
    case 'POST':
        handleAddFruit($conn);
        break;
    case 'DELETE':
        handleRemoveFruit($conn);
        break;
    default:
        http_response_code(405);
        echo jsonResponse(false, 'Method not allowed');
        break;
}

function handleGetFruits($conn) {
    $user_id = $_GET['user_id'] ?? null;
    
    if ($user_id) {
        // Get specific user's fruits
        $user_id = intval($user_id);
        $stmt = $conn->prepare("
            SELECT f.id, f.name, f.active_users, 
                   CASE WHEN uf.user_id IS NOT NULL THEN 1 ELSE 0 END as is_selected
            FROM fruits f
            LEFT JOIN user_fruits uf ON f.id = uf.fruit_id AND uf.user_id = ?
            ORDER BY f.id
        ");
        $stmt->bind_param("i", $user_id);
        $stmt->execute();
        $result = $stmt->get_result();
        
        $fruits = [];
        while ($row = $result->fetch_assoc()) {
            $fruits[] = $row;
        }
        
        echo jsonResponse(true, 'User fruits retrieved', $fruits);
    } else {
        // Get all fruits with active users count
        $stmt = $conn->prepare("
            SELECT f.id, f.name, f.active_users,
                   COUNT(uf.user_id) as total_selections
            FROM fruits f
            LEFT JOIN user_fruits uf ON f.id = uf.fruit_id
            GROUP BY f.id, f.name, f.active_users
            ORDER BY f.id
        ");
        $stmt->execute();
        $result = $stmt->get_result();
        
        $fruits = [];
        while ($row = $result->fetch_assoc()) {
            $fruits[] = [
                'id' => $row['id'],
                'name' => $row['name'],
                'active_users' => intval($row['active_users']),
                'total_selections' => intval($row['total_selections'])
            ];
        }
        
        echo jsonResponse(true, 'Fruits retrieved', $fruits);
    }
}

function handleAddFruit($conn) {
    $user_id = intval($_POST['user_id'] ?? 0);
    $fruit_id = intval($_POST['fruit_id'] ?? 0);
    
    if (!$user_id || !$fruit_id) {
        http_response_code(400);
        echo jsonResponse(false, 'user_id and fruit_id are required');
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
    
    // Verify fruit exists
    $fruit_stmt = $conn->prepare("SELECT id FROM fruits WHERE id = ?");
    $fruit_stmt->bind_param("i", $fruit_id);
    $fruit_stmt->execute();
    if ($fruit_stmt->get_result()->num_rows === 0) {
        http_response_code(404);
        echo jsonResponse(false, 'Fruit not found');
        return;
    }
    
    // Check if already selected
    $check_stmt = $conn->prepare("SELECT id FROM user_fruits WHERE user_id = ? AND fruit_id = ?");
    $check_stmt->bind_param("ii", $user_id, $fruit_id);
    $check_stmt->execute();
    if ($check_stmt->get_result()->num_rows > 0) {
        http_response_code(400);
        echo jsonResponse(false, 'Fruit already selected');
        return;
    }
    
    // Add fruit to user
    $stmt = $conn->prepare("INSERT INTO user_fruits (user_id, fruit_id) VALUES (?, ?)");
    $stmt->bind_param("ii", $user_id, $fruit_id);
    
    if ($stmt->execute()) {
        // Update active_users count in fruits table
        $update_stmt = $conn->prepare("UPDATE fruits SET active_users = active_users + 1 WHERE id = ?");
        $update_stmt->bind_param("i", $fruit_id);
        $update_stmt->execute();
        
        echo jsonResponse(true, 'Fruit added successfully');
    } else {
        http_response_code(500);
        echo jsonResponse(false, 'Failed to add fruit: ' . $stmt->error);
    }
}

function handleRemoveFruit($conn) {
    // For DELETE, we'll use POST with action=remove or parse from URL
    $user_id = intval($_POST['user_id'] ?? $_GET['user_id'] ?? 0);
    $fruit_id = intval($_POST['fruit_id'] ?? $_GET['fruit_id'] ?? 0);
    
    if (!$user_id || !$fruit_id) {
        http_response_code(400);
        echo jsonResponse(false, 'user_id and fruit_id are required');
        return;
    }
    
    // Remove fruit from user
    $stmt = $conn->prepare("DELETE FROM user_fruits WHERE user_id = ? AND fruit_id = ?");
    $stmt->bind_param("ii", $user_id, $fruit_id);
    
    if ($stmt->execute() && $stmt->affected_rows > 0) {
        // Update active_users count in fruits table
        $update_stmt = $conn->prepare("UPDATE fruits SET active_users = GREATEST(active_users - 1, 0) WHERE id = ?");
        $update_stmt->bind_param("i", $fruit_id);
        $update_stmt->execute();
        
        echo jsonResponse(true, 'Fruit removed successfully');
    } else {
        http_response_code(404);
        echo jsonResponse(false, 'Fruit not found in user selection');
    }
}

$conn->close();
?>

