<?php
session_start();
include './includes/db.php';
header('Content-Type: application/json');

$name = trim($_POST['name'] ?? '');
$email = trim($_POST['email'] ?? '');
$phone = trim($_POST['phone'] ?? '');
$password = $_POST['password'] ?? '';
$request_blogger = isset($_POST['request_blogger']) ? true : false;

// Validation
if(empty($name) || empty($email) || empty($password)) {
    echo json_encode(['success' => false, 'message' => 'Name, email, and password are required']);
    exit;
}

// Check if email exists
$check_sql = "SELECT id FROM users WHERE email = ?";
$check_stmt = $conn->prepare($check_sql);
$check_stmt->bind_param("s", $email);
$check_stmt->execute();
$check_result = $check_stmt->get_result();

if($check_result->num_rows > 0) {
    echo json_encode(['success' => false, 'message' => 'Email already exists']);
    exit;
}

// Hash password
$hashed_password = password_hash($password, PASSWORD_DEFAULT);

// Set role based on blogger request
$role = $request_blogger ? 'PendingBlogger' : 'User';

// Insert user
$sql = "INSERT INTO users (name, email, phone, password_hash, role, status, join_date) 
        VALUES (?, ?, ?, ?, ?, 'Active', CURDATE())";
$stmt = $conn->prepare($sql);
$stmt->bind_param("sssss", $name, $email, $phone, $hashed_password, $role);

if($stmt->execute()) {
    $user_id = $conn->insert_id;
    
    $message = $request_blogger 
        ? "Account created! Your blogger request has been submitted for admin approval." 
        : "Account created successfully!";
    
    echo json_encode(['success' => true, 'message' => $message, 'user_id' => $user_id]);
} else {
    echo json_encode(['success' => false, 'message' => 'Registration failed. Please try again.']);
}
?>