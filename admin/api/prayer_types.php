<?php
/**
 * Prayer Types API
 * Handles: Get prayer types, Add custom prayer type
 */

// Start output buffering to prevent any output before JSON
if (ob_get_level() == 0) {
    ob_start();
}

// Suppress display of errors but still log them for debugging
error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

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
            handleGetPrayerTypes($conn);
            break;
        case 'POST':
            handleAddPrayerType($conn);
            break;
        default:
            http_response_code(405);
            echo jsonResponse(false, 'Method not allowed');
            if (ob_get_level() > 0) ob_end_flush();
            exit;
    }
} catch (Exception $e) {
    http_response_code(500);
    if (ob_get_level() > 0) ob_clean();
    if (!headers_sent()) {
        header('Content-Type: application/json; charset=utf-8');
    }
    error_log("Prayer Types API Error: " . $e->getMessage());
    echo jsonResponse(false, 'Server error. Please try again later.');
    if (ob_get_level() > 0) ob_end_flush();
    exit;
}

function handleGetPrayerTypes($conn) {
    try {
        // Default prayer types that should always be included
        $default_types = [
            'Healing',
            'Peace & Anxiety',
            'Work & Provision',
            'Relationships',
            'Guidance',
            'Strength',
            'Protection',
            'Wisdom',
            'Forgiveness',
            'Financial',
            'Family',
            'Addiction',
            'Grief',
            'Faith',
            'Thanksgiving',
            'Deliverance'
        ];
        
        // Check if prayer_types table exists
        $check_table = $conn->query("SHOW TABLES LIKE 'prayer_types'");
        
        if (!$check_table || $check_table->num_rows === 0) {
            // Table doesn't exist, return default prayer types + 'other'
            $types = [...$default_types, 'other'];
            
            if (ob_get_level() > 0) ob_clean();
            if (!headers_sent()) {
                header('Content-Type: application/json; charset=utf-8');
            }
            echo jsonResponse(true, 'Prayer types retrieved (default)', $types);
            if (ob_get_level() > 0) ob_end_flush();
            exit;
        }
        
        // Table exists, fetch custom types from database
        $stmt = $conn->prepare("SELECT type_name FROM prayer_types WHERE status = 'active' AND type_name != 'other' ORDER BY sort_order ASC, created_at ASC");
        
        if (!$stmt->execute()) {
            // If query fails, return default types
            $types = [...$default_types, 'other'];
            
            if (ob_get_level() > 0) ob_clean();
            if (!headers_sent()) {
                header('Content-Type: application/json; charset=utf-8');
            }
            echo jsonResponse(true, 'Prayer types retrieved (fallback)', $types);
            if (ob_get_level() > 0) ob_end_flush();
            exit;
        }
        
        $result = $stmt->get_result();
        $custom_types = [];
        
        while ($row = $result->fetch_assoc()) {
            $custom_types[] = $row['type_name'];
        }
        
        // Combine default types with custom types (avoid duplicates)
        $types = [...$default_types];
        foreach ($custom_types as $custom_type) {
            if (!in_array($custom_type, $types)) {
                $types[] = $custom_type;
            }
        }
        
        // Always include 'other' at the end
        $types[] = 'other';
        
        if (ob_get_level() > 0) ob_clean();
        if (!headers_sent()) {
            header('Content-Type: application/json; charset=utf-8');
        }
        echo jsonResponse(true, 'Prayer types retrieved', $types);
        if (ob_get_level() > 0) ob_end_flush();
        exit;
    } catch (Exception $e) {
        error_log("handleGetPrayerTypes Exception: " . $e->getMessage());
        
        // On error, return default types
        $default_types = [
            'Healing',
            'Peace & Anxiety',
            'Work & Provision',
            'Relationships',
            'Guidance',
            'Strength',
            'Protection',
            'Wisdom',
            'Forgiveness',
            'Financial',
            'Family',
            'Addiction',
            'Grief',
            'Faith',
            'Thanksgiving',
            'Deliverance',
            'other'
        ];
        
        http_response_code(500);
        if (ob_get_level() > 0) ob_clean();
        if (!headers_sent()) {
            header('Content-Type: application/json; charset=utf-8');
        }
        echo jsonResponse(true, 'Prayer types retrieved (error fallback)', $default_types);
        if (ob_get_level() > 0) ob_end_flush();
        exit;
    }
}

function handleAddPrayerType($conn) {
    $type_name = trim($_POST['type_name'] ?? '');
    $user_id = intval($_POST['user_id'] ?? 0);
    
    if (empty($type_name)) {
        http_response_code(400);
        echo jsonResponse(false, 'type_name is required');
        ob_end_flush();
        return;
    }
    
    if (!$user_id) {
        http_response_code(400);
        echo jsonResponse(false, 'user_id is required');
        ob_end_flush();
        return;
    }
    
    // Check if prayer_types table exists
    $check_table = $conn->query("SHOW TABLES LIKE 'prayer_types'");
    
    if (!$check_table || $check_table->num_rows === 0) {
        // Create table if it doesn't exist
        $create_table = "CREATE TABLE IF NOT EXISTS prayer_types (
            id INT AUTO_INCREMENT PRIMARY KEY,
            type_name VARCHAR(100) NOT NULL UNIQUE,
            created_by INT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            status ENUM('active', 'inactive') DEFAULT 'active',
            sort_order INT DEFAULT 0,
            INDEX idx_status (status),
            INDEX idx_created_by (created_by),
            FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE CASCADE
        )";
        
        if (!$conn->query($create_table)) {
            http_response_code(500);
            echo jsonResponse(false, 'Failed to create prayer_types table: ' . $conn->error);
            ob_end_flush();
            return;
        }
    }
    
    // Check if type already exists
    $check_stmt = $conn->prepare("SELECT id FROM prayer_types WHERE type_name = ?");
    $check_stmt->bind_param("s", $type_name);
    $check_stmt->execute();
    
    if ($check_stmt->get_result()->num_rows > 0) {
        http_response_code(409);
        echo jsonResponse(false, 'Prayer type already exists');
        ob_end_flush();
        return;
    }
    
    // Insert new prayer type
    $stmt = $conn->prepare("INSERT INTO prayer_types (type_name, created_by, sort_order) VALUES (?, ?, (SELECT COALESCE(MAX(sort_order), 0) + 1 FROM prayer_types))");
    $stmt->bind_param("si", $type_name, $user_id);
    
    if ($stmt->execute()) {
        $type_id = $stmt->insert_id;
        echo jsonResponse(true, 'Prayer type added successfully', ['id' => $type_id, 'type_name' => $type_name]);
        ob_end_flush();
    } else {
        http_response_code(500);
        echo jsonResponse(false, 'Failed to add prayer type: ' . $stmt->error);
        ob_end_flush();
    }
}

// Close connection
if (isset($conn) && $conn->ping()) {
    $conn->close();
}

// Clean up output buffers
while (ob_get_level() > 0) {
    ob_end_clean();
}
