<?php
/**
 * User Authentication API
 * Handles: Login, Register, Forgot Password
 */

// Start output buffering to prevent any whitespace from corrupting JSON
ob_start();

require_once '../includes/db.php';
require_once '../includes/cors.php';
require_once '../includes/email_helper.php';
require_once '../includes/iap_premium_helper.php';
require_once 'auth-helper.php';

function fos_attach_premium_to_user(&$user, $conn) {
    if (empty($user['id'])) {
        return;
    }
    fos_sync_premium_by_email($conn, (int) $user['id']);
    $row = fos_get_user_row($conn, (int) $user['id']);
    if ($row) {
        $user['is_lifetime_premium'] = (int) ($row['is_lifetime_premium'] ?? 0);
        $user['lifetime_purchase_date'] = $row['lifetime_purchase_date'] ?? null;
        $user['iap_purchase_type'] = $row['iap_purchase_type'] ?? null;
        $user['iap_platform'] = $row['iap_platform'] ?? null;
    }
}

// Check for database connection error (from db.php)
if (isset($db_connection_error) && $db_connection_error) {
    if (ob_get_length()) ob_clean();
    http_response_code(500);
    echo jsonResponse(false, 'Database connection failed: ' . $db_connection_error);
    if (ob_get_length()) ob_end_flush();
    exit;
}

header('Content-Type: application/json; charset=utf-8');

$method = $_SERVER['REQUEST_METHOD'];
$action = $_GET['action'] ?? $_POST['action'] ?? '';

// Handle OPTIONS request
if ($method === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// Route based on action
switch ($action) {
    case 'login':
        handleLogin($conn);
        break;
    case 'register':
        handleRegister($conn);
        break;
    case 'forgot-password':
        handleForgotPassword($conn);
        break;
    case 'verify-otp':
        handleVerifyOTP($conn);
        break;
    case 'google-auth':
        handleGoogleAuth($conn);
        break;
    case 'facebook-auth':
        handleFacebookAuth($conn);
        break;
    case 'phone-otp-login':
        handlePhoneOtpLogin($conn);
        break;
    case 'apple-auth':
        handleAppleAuth($conn);
        break;
    default:
        if ($method === 'POST' && !$action) {
            // Default to login if no action specified
            handleLogin($conn);
        } else {
            http_response_code(400);
            echo jsonResponse(false, 'Invalid action');
        }
        break;
}

function handleLogin($conn) {
    $email = $_POST['email'] ?? '';
    $phone = $_POST['phone'] ?? '';
    $password = $_POST['password'] ?? '';
    $requested_role = trim($_POST['role'] ?? 'User'); // Get requested role from login
    
    if (empty($email) && empty($phone)) {
        http_response_code(400);
        echo jsonResponse(false, 'Email or phone is required');
        return;
    }
    
    if (empty($password)) {
        http_response_code(400);
        echo jsonResponse(false, 'Password is required');
        return;
    }
    
    // Validate requested role
    $valid_roles = ['User', 'Blogger'];
    if (!in_array($requested_role, $valid_roles)) {
        $requested_role = 'User'; // Default to User if invalid role
    }
    
    // Check if login by email or phone (check all statuses first to verify password)
    if (!empty($email)) {
        $stmt = $conn->prepare("SELECT * FROM users WHERE email = ?");
        if (!$stmt) {
            http_response_code(500);
            echo jsonResponse(false, 'Database error: ' . $conn->error);
            return;
        }
        $stmt->bind_param("s", $email);
    } else {
        $stmt = $conn->prepare("SELECT * FROM users WHERE phone = ?");
        if (!$stmt) {
            http_response_code(500);
            echo jsonResponse(false, 'Database error: ' . $conn->error);
            return;
        }
        $stmt->bind_param("s", $phone);
    }
    
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows === 0) {
        http_response_code(401);
        echo jsonResponse(false, 'Invalid credentials');
        return;
    }
    
    $user = $result->fetch_assoc();
    
    // Verify password (MD5 as per existing system)
    if (md5($password) !== $user['password_hash']) {
        http_response_code(401);
        echo jsonResponse(false, 'Invalid credentials');
        return;
    }
    
    // Check if user is Blogger and status is not Active
    // Allow login as Blogger with limited features while waiting for approval
    if ($user['role'] === 'Blogger' && $user['status'] !== 'Active') {
        // If user tries to login as Blogger, allow login but with limited access
        if ($requested_role === 'Blogger') {
            // Allow login as Blogger but with pending status
            // Frontend should handle limited access based on status
            // Continue with login as Blogger (no role override needed)
        }
        // If user tries to login as User, allow it (temporarily override role to User)
        // This allows users to login and use app while waiting for Blogger approval
        if ($requested_role === 'User') {
            $user['role'] = 'User'; // Override role for this session
            // Continue with login as User
        }
    }
    
    // Check if user's role matches requested role
    // Exception: Blogger with Inactive status can login as User (handled above)
    if ($user['role'] !== $requested_role) {
        http_response_code(403);
        echo jsonResponse(false, 'Please select the correct role (' . $user['role'] . ') to login.', [
            'status' => $user['status'],
            'role' => $user['role'],
            'requested_role' => $requested_role,
            'message' => 'Please select the correct role (' . $user['role'] . ') to login.'
        ]);
        return;
    }
    
    // Check if user status is Active (for all roles)
    // Allow login for:
    // 1. Active users (any role)
    // 2. Users with Inactive status (they requested Blogger but registered as User)
    // 3. Bloggers with Pending status (they can login as users while waiting for approval)
    if ($user['status'] !== 'Active') {
        // Allow login for Users with Inactive status
        if ($user['role'] === 'User' && $requested_role === 'User') {
            // Allow login as User even if status is Inactive
            // This happens when user requested Blogger role but is registered as User with Inactive status
        }
        // Allow login for Bloggers with Pending status (they can use app as regular users)
        else if ($user['role'] === 'Blogger' && $user['status'] === 'Pending') {
            // Allow login but treat as user-level access
            // Frontend will handle restricting blogger features
        }
        // Allow login for Bloggers with Inactive status 
        else if ($user['role'] === 'Blogger' && $user['status'] === 'Inactive') {
            // Allow login but treat as user-level access
            // Frontend will handle restricting blogger features
        } else {
            // For other cases, show error
            http_response_code(403);
            echo jsonResponse(false, 'Your account is ' . $user['status'] . '. Please contact admin for approval.', [
                'status' => $user['status'],
                'role' => $user['role'],
                'message' => 'Your account is ' . $user['status'] . '. Please contact admin for approval.'
            ]);
            return;
        }
    }
    
    // Get user's selected fruits
    $fruits_stmt = $conn->prepare("SELECT f.id, f.name FROM user_fruits uf JOIN fruits f ON uf.fruit_id = f.id WHERE uf.user_id = ?");
    if (!$fruits_stmt) {
        // Log error but continue with empty fruits
        error_log("Fruits query failed: " . $conn->error);
        $user_fruits = [];
    } else {
        $fruits_stmt->bind_param("i", $user['id']);
        $fruits_stmt->execute();
        $fruits_result = $fruits_stmt->get_result();
        $user_fruits = [];
        while ($fruit = $fruits_result->fetch_assoc()) {
            $user_fruits[] = $fruit;
        }
    }
    
    // Remove password from response
    unset($user['password_hash']);
    $user['fruits'] = $user_fruits;
    fos_attach_premium_to_user($user, $conn);
    
    echo jsonResponse(true, 'Login successful', $user);
}

function handleRegister($conn) {
    $name = trim($_POST['name'] ?? '');
    $email = trim($_POST['email'] ?? '');
    $phone = trim($_POST['phone'] ?? '');
    $password = $_POST['password'] ?? '';
    $confirm_password = $_POST['confirm_password'] ?? '';
    $accept_terms = $_POST['accept_terms'] ?? false;
    $requested_role = trim($_POST['requested_role'] ?? 'User'); // User can request role during registration
    
    // Validation
    if (empty($name)) {
        http_response_code(400);
        echo jsonResponse(false, 'Name is required');
        return;
    }
    
    if (empty($email) && empty($phone)) {
        http_response_code(400);
        echo jsonResponse(false, 'Email or phone is required');
        return;
    }
    
    if (!empty($email) && !filter_var($email, FILTER_VALIDATE_EMAIL)) {
        http_response_code(400);
        echo jsonResponse(false, 'Invalid email format');
        return;
    }
    
    if (empty($password)) {
        http_response_code(400);
        echo jsonResponse(false, 'Password is required');
        return;
    }
    
    if (strlen($password) < 6) {
        http_response_code(400);
        echo jsonResponse(false, 'Password must be at least 6 characters');
        return;
    }
    
    if ($password !== $confirm_password) {
        http_response_code(400);
        echo jsonResponse(false, 'Passwords do not match');
        return;
    }
    
    if (!$accept_terms) {
        http_response_code(400);
        echo jsonResponse(false, 'You must accept Terms & Conditions');
        return;
    }
    
    // Check if email already exists
    if (!empty($email)) {
        $check_stmt = $conn->prepare("SELECT id FROM users WHERE email = ?");
        $check_stmt->bind_param("s", $email);
        $check_stmt->execute();
        if ($check_stmt->get_result()->num_rows > 0) {
            http_response_code(400);
            echo jsonResponse(false, 'Email already registered');
            return;
        }
    }
    
    // Check if phone already exists
    if (!empty($phone)) {
        $check_stmt = $conn->prepare("SELECT id FROM users WHERE phone = ?");
        $check_stmt->bind_param("s", $phone);
        $check_stmt->execute();
        if ($check_stmt->get_result()->num_rows > 0) {
            http_response_code(400);
            echo jsonResponse(false, 'Phone already registered');
            return;
        }
    }
    
    // Validate requested role
    $valid_roles = ['User', 'Blogger'];
    if (!in_array($requested_role, $valid_roles)) {
        $requested_role = 'User'; // Default to User if invalid role
    }
    
    // Insert user
    $password_hash = md5($password);
    $join_date = date('Y-m-d');
    
    // If user requests Blogger role, store as Blogger with Pending status
    // User can login as Blogger but with limited access until admin approval
    if ($requested_role === 'Blogger') {
        $role = 'Blogger'; // Store as Blogger role
        $status = 'Pending'; // Pending admin approval
        // Note: User can login but blogging features require approval
    } else {
        $role = 'User';
        $status = 'Active'; // Regular users are active by default
    }
    
    $stmt = $conn->prepare("INSERT INTO users (name, email, phone, password_hash, role, status, join_date) VALUES (?, ?, ?, ?, ?, ?, ?)");
    $stmt->bind_param("sssssss", $name, $email, $phone, $password_hash, $role, $status, $join_date);
    
    if ($stmt->execute()) {
        $user_id = $stmt->insert_id;
        
        // Get created user data
        $user_stmt = $conn->prepare("SELECT id, name, email, phone, role, status, join_date, profile_photo, fruit_category FROM users WHERE id = ?");
        $user_stmt->bind_param("i", $user_id);
        $user_stmt->execute();
        $user = $user_stmt->get_result()->fetch_assoc();
        $user['fruits'] = [];
        fos_attach_premium_to_user($user, $conn);
        
        echo jsonResponse(true, 'Registration successful', $user);
    } else {
        http_response_code(500);
        echo jsonResponse(false, 'Registration failed: ' . $stmt->error);
    }
}

function handleForgotPassword($conn) {
    $email = trim($_POST['email'] ?? '');
    $phone = trim($_POST['phone'] ?? '');
    
    if (empty($email) && empty($phone)) {
        http_response_code(400);
        echo jsonResponse(false, 'Email or phone is required');
        return;
    }
    
    // Check if user exists
    $user = null;
    if (!empty($email)) {
        $stmt = $conn->prepare("SELECT id, email FROM users WHERE email = ?");
        $stmt->bind_param("s", $email);
    } else {
        $stmt = $conn->prepare("SELECT id, phone FROM users WHERE phone = ?");
        $stmt->bind_param("s", $phone);
    }
    
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows === 0) {
        http_response_code(404);
        echo jsonResponse(false, 'User not found');
        return;
    }
    
    $user = $result->fetch_assoc();
    
    // Generate 6-digit numeric OTP
    $otpCode = str_pad(rand(0, 999999), 6, '0', STR_PAD_LEFT);
    $expiresAt = date('Y-m-d H:i:s', strtotime('+10 minutes')); // OTP valid for 10 minutes
    
    $emailOrPhone = !empty($email) ? $email : $phone;
    
    // Delete old unused OTPs for this email/phone
    $delete_stmt = $conn->prepare("DELETE FROM otps WHERE email_or_phone = ? AND used_at IS NULL");
    $delete_stmt->bind_param("s", $emailOrPhone);
    $delete_stmt->execute();
    
    // Store OTP in database
    $insert_stmt = $conn->prepare("INSERT INTO otps (email_or_phone, otp_code, expires_at) VALUES (?, ?, ?)");
    $insert_stmt->bind_param("sss", $emailOrPhone, $otpCode, $expiresAt);
    
    if (!$insert_stmt->execute()) {
        http_response_code(500);
        echo jsonResponse(false, 'Failed to generate OTP');
        return;
    }
    
    // Send OTP via Email
    if (!empty($email)) {
        $emailSent = sendOtpEmail($email, $otpCode);
        if (!$emailSent) {
            // Log error but don't fail the request
            error_log("Failed to send OTP email to: {$email}");
        }
    }
    
    // Send OTP via SMS (if phone provided)
    if (!empty($phone)) {
        sendOtpSms($phone, $otpCode);
    }
    
    echo jsonResponse(true, 'OTP sent successfully. Please check your email/phone.');
}

function handleVerifyOTP($conn) {
    $email = trim($_POST['email'] ?? '');
    $phone = trim($_POST['phone'] ?? '');
    $otp = trim($_POST['otp'] ?? '');
    $new_password = $_POST['new_password'] ?? '';
    
    if (empty($otp)) {
        http_response_code(400);
        echo jsonResponse(false, 'OTP is required');
        return;
    }
    
    if (empty($new_password)) {
        http_response_code(400);
        echo jsonResponse(false, 'New password is required');
        return;
    }
    
    if (strlen($new_password) < 6) {
        http_response_code(400);
        echo jsonResponse(false, 'Password must be at least 6 characters');
        return;
    }
    
    $emailOrPhone = !empty($email) ? $email : $phone;
    
    // Verify OTP from database
    $stmt = $conn->prepare("SELECT * FROM otps WHERE email_or_phone = ? AND otp_code = ? AND expires_at > NOW() AND used_at IS NULL ORDER BY created_at DESC LIMIT 1");
    $stmt->bind_param("ss", $emailOrPhone, $otp);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows === 0) {
        http_response_code(400);
        echo jsonResponse(false, 'Invalid or expired OTP');
        return;
    }
    
    $otpRecord = $result->fetch_assoc();
    
    // Mark OTP as used
    $update_stmt = $conn->prepare("UPDATE otps SET used_at = NOW() WHERE id = ?");
    $update_stmt->bind_param("i", $otpRecord['id']);
    $update_stmt->execute();
    
    // Update password
    $password_hash = md5($new_password);
    
    if (!empty($email)) {
        $update_user_stmt = $conn->prepare("UPDATE users SET password_hash = ? WHERE email = ?");
        $update_user_stmt->bind_param("ss", $password_hash, $email);
    } else {
        $update_user_stmt = $conn->prepare("UPDATE users SET password_hash = ? WHERE phone = ?");
        $update_user_stmt->bind_param("ss", $password_hash, $phone);
    }
    
    if ($update_user_stmt->execute()) {
        echo jsonResponse(true, 'Password reset successful');
    } else {
        http_response_code(500);
        echo jsonResponse(false, 'Password reset failed');
    }
}

function handleGoogleAuth($conn) {
    $googleId = trim($_POST['google_id'] ?? '');
    $email = trim($_POST['email'] ?? '');
    $name = trim($_POST['name'] ?? '');
    $profilePicture = trim($_POST['profile_picture'] ?? '');
    
    if (empty($googleId)) {
        http_response_code(400);
        echo jsonResponse(false, 'Google ID is required');
        return;
    }
    
    if (empty($email)) {
        http_response_code(400);
        echo jsonResponse(false, 'Email is required');
        return;
    }
    
    if (empty($name)) {
        http_response_code(400);
        echo jsonResponse(false, 'Name is required');
        return;
    }
    
    // Check if user exists by Google ID first
    $stmt = $conn->prepare("SELECT * FROM users WHERE google_id = ?");
    $stmt->bind_param("s", $googleId);
    $stmt->execute();
    $result = $stmt->get_result();
    $user = $result->fetch_assoc();
    
    if ($user) {
        // User exists, update profile picture if provided and not set
        if (!empty($profilePicture) && empty($user['profile_photo'])) {
            $update_stmt = $conn->prepare("UPDATE users SET profile_photo = ? WHERE id = ?");
            $update_stmt->bind_param("si", $profilePicture, $user['id']);
            $update_stmt->execute();
            
            // Refresh user data
            $stmt = $conn->prepare("SELECT * FROM users WHERE id = ?");
            $stmt->bind_param("i", $user['id']);
            $stmt->execute();
            $result = $stmt->get_result();
            $user = $result->fetch_assoc();
        }
        
        // Check if Blogger and not active
        if ($user['role'] === 'Blogger' && $user['status'] !== 'Active') {
            http_response_code(403);
            echo jsonResponse(false, 'Your Blogger account is pending admin approval. Please wait for approval.');
            return;
        }
    } else {
        // User doesn't exist, check by email if provided
        $stmt = $conn->prepare("SELECT * FROM users WHERE email = ?");
        $stmt->bind_param("s", $email);
        $stmt->execute();
        $result = $stmt->get_result();
        $existingUser = $result->fetch_assoc();
        
        if ($existingUser) {
            // Link Google ID to existing account
            $update_stmt = $conn->prepare("UPDATE users SET google_id = ?, profile_photo = ? WHERE id = ?");
            $update_stmt->bind_param("ssi", $googleId, $profilePicture, $existingUser['id']);
            $update_stmt->execute();
            
            // Refresh user data
            $stmt = $conn->prepare("SELECT * FROM users WHERE id = ?");
            $stmt->bind_param("i", $existingUser['id']);
            $stmt->execute();
            $result = $stmt->get_result();
            $user = $result->fetch_assoc();
            
            // Check if Blogger and not active
            if ($user['role'] === 'Blogger' && $user['status'] !== 'Active') {
                http_response_code(403);
                echo jsonResponse(false, 'Your Blogger account is pending admin approval. Please wait for approval.');
                return;
            }
        } else {
            // Create new user
            $joinDate = date('Y-m-d');
            $role = 'User';
            $status = 'Active';
            $passwordHash = md5(uniqid(rand(), true)); // Random password for social login
            
            $insert_stmt = $conn->prepare("INSERT INTO users (name, email, google_id, password_hash, role, status, join_date, profile_photo) VALUES (?, ?, ?, ?, ?, ?, ?, ?)");
            $insert_stmt->bind_param("ssssssss", $name, $email, $googleId, $passwordHash, $role, $status, $joinDate, $profilePicture);
            
            if (!$insert_stmt->execute()) {
                http_response_code(500);
                echo jsonResponse(false, 'Registration failed: ' . $insert_stmt->error);
                return;
            }
            
            $userId = $insert_stmt->insert_id;
            
            // Get created user
            $user_stmt = $conn->prepare("SELECT * FROM users WHERE id = ?");
            $user_stmt->bind_param("i", $userId);
            $user_stmt->execute();
            $user = $user_stmt->get_result()->fetch_assoc();
        }
    }
    
    // Get user's selected fruits
    $fruits_stmt = $conn->prepare("SELECT f.id, f.name FROM user_fruits uf JOIN fruits f ON uf.fruit_id = f.id WHERE uf.user_id = ?");
    $fruits_stmt->bind_param("i", $user['id']);
    $fruits_stmt->execute();
    $fruits_result = $fruits_stmt->get_result();
    $userFruits = [];
    while ($fruit = $fruits_result->fetch_assoc()) {
        $userFruits[] = $fruit;
    }
    
    unset($user['password_hash']);
    $user['fruits'] = $userFruits;
    fos_attach_premium_to_user($user, $conn);
    
    echo jsonResponse(true, 'Google authentication successful', $user);
}

function handleFacebookAuth($conn) {
    $facebookId = trim($_POST['facebook_id'] ?? '');
    $email = trim($_POST['email'] ?? '');
    $name = trim($_POST['name'] ?? '');
    $profilePicture = trim($_POST['profile_picture'] ?? '');
    
    if (empty($facebookId)) {
        http_response_code(400);
        echo jsonResponse(false, 'Facebook ID is required');
        return;
    }
    
    if (empty($email)) {
        http_response_code(400);
        echo jsonResponse(false, 'Email is required');
        return;
    }
    
    if (empty($name)) {
        http_response_code(400);
        echo jsonResponse(false, 'Name is required');
        return;
    }
    
    // Check if user exists by email
    $stmt = $conn->prepare("SELECT * FROM users WHERE email = ?");
    $stmt->bind_param("s", $email);
    $stmt->execute();
    $result = $stmt->get_result();
    $user = $result->fetch_assoc();
    
    if ($user) {
        // User exists, update Facebook ID if not set
        if (empty($user['facebook_id'])) {
            $update_stmt = $conn->prepare("UPDATE users SET facebook_id = ?, profile_photo = ? WHERE id = ?");
            $update_stmt->bind_param("ssi", $facebookId, $profilePicture, $user['id']);
            $update_stmt->execute();
        }
        
        // Check if Blogger and not active
        if ($user['role'] === 'Blogger' && $user['status'] !== 'Active') {
            http_response_code(403);
            echo jsonResponse(false, 'Your Blogger account is pending admin approval. Please wait for approval.');
            return;
        }
    } else {
        // Create new user
        $joinDate = date('Y-m-d');
        $role = 'User';
        $status = 'Active';
        $passwordHash = md5(uniqid(rand(), true)); // Random password for social login
        
        $insert_stmt = $conn->prepare("INSERT INTO users (name, email, facebook_id, password_hash, role, status, join_date, profile_photo) VALUES (?, ?, ?, ?, ?, ?, ?, ?)");
        $insert_stmt->bind_param("ssssssss", $name, $email, $facebookId, $passwordHash, $role, $status, $joinDate, $profilePicture);
        
        if (!$insert_stmt->execute()) {
            http_response_code(500);
            echo jsonResponse(false, 'Registration failed: ' . $insert_stmt->error);
            return;
        }
        
        $userId = $insert_stmt->insert_id;
        
        // Get created user
        $user_stmt = $conn->prepare("SELECT * FROM users WHERE id = ?");
        $user_stmt->bind_param("i", $userId);
        $user_stmt->execute();
        $user = $user_stmt->get_result()->fetch_assoc();
    }
    
    // Get user's selected fruits
    $fruits_stmt = $conn->prepare("SELECT f.id, f.name FROM user_fruits uf JOIN fruits f ON uf.fruit_id = f.id WHERE uf.user_id = ?");
    $fruits_stmt->bind_param("i", $user['id']);
    $fruits_stmt->execute();
    $fruits_result = $fruits_stmt->get_result();
    $userFruits = [];
    while ($fruit = $fruits_result->fetch_assoc()) {
        $userFruits[] = $fruit;
    }
    
    unset($user['password_hash']);
    $user['fruits'] = $userFruits;
    fos_attach_premium_to_user($user, $conn);
    
    echo jsonResponse(true, 'Facebook authentication successful', $user);
}

function handlePhoneOtpLogin($conn) {
    $email = trim($_POST['email'] ?? '');
    $phone = trim($_POST['phone'] ?? '');
    $otp = trim($_POST['otp'] ?? '');
    
    if (empty($email) && empty($phone)) {
        http_response_code(400);
        echo jsonResponse(false, 'Email or phone is required');
        return;
    }
    
    if (empty($otp)) {
        http_response_code(400);
        echo jsonResponse(false, 'OTP is required');
        return;
    }
    
    $emailOrPhone = !empty($email) ? $email : $phone;
    
    // Verify OTP from database
    $stmt = $conn->prepare("SELECT * FROM otps WHERE email_or_phone = ? AND otp_code = ? AND expires_at > NOW() AND used_at IS NULL ORDER BY created_at DESC LIMIT 1");
    $stmt->bind_param("ss", $emailOrPhone, $otp);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows === 0) {
        http_response_code(400);
        echo jsonResponse(false, 'Invalid or expired OTP');
        return;
    }
    
    $otpRecord = $result->fetch_assoc();
    
    // Mark OTP as used
    $update_stmt = $conn->prepare("UPDATE otps SET used_at = NOW() WHERE id = ?");
    $update_stmt->bind_param("i", $otpRecord['id']);
    $update_stmt->execute();
    
    // Check if user exists
    $user = null;
    if (!empty($email)) {
        $user_stmt = $conn->prepare("SELECT * FROM users WHERE email = ?");
        $user_stmt->bind_param("s", $email);
    } else {
        $user_stmt = $conn->prepare("SELECT * FROM users WHERE phone = ?");
        $user_stmt->bind_param("s", $phone);
    }
    
    $user_stmt->execute();
    $user_result = $user_stmt->get_result();
    $user = $user_result->fetch_assoc();
    
    if (!$user) {
        // User doesn't exist, create new user
        $joinDate = date('Y-m-d');
        $role = 'User';
        $status = 'Active';
        $passwordHash = md5(uniqid(rand(), true)); // Random password for OTP login
        
        // Generate a default name
        $name = !empty($email) ? explode('@', $email)[0] : 'User ' . substr($phone, -4);
        
        if (!empty($email)) {
            $insert_stmt = $conn->prepare("INSERT INTO users (name, email, password_hash, role, status, join_date) VALUES (?, ?, ?, ?, ?, ?)");
            $insert_stmt->bind_param("ssssss", $name, $email, $passwordHash, $role, $status, $joinDate);
        } else {
            $insert_stmt = $conn->prepare("INSERT INTO users (name, phone, password_hash, role, status, join_date) VALUES (?, ?, ?, ?, ?, ?)");
            $insert_stmt->bind_param("ssssss", $name, $phone, $passwordHash, $role, $status, $joinDate);
        }
        
        if (!$insert_stmt->execute()) {
            http_response_code(500);
            echo jsonResponse(false, 'Registration failed: ' . $insert_stmt->error);
            return;
        }
        
        $userId = $insert_stmt->insert_id;
        
        // Get created user
        $user_stmt = $conn->prepare("SELECT * FROM users WHERE id = ?");
        $user_stmt->bind_param("i", $userId);
        $user_stmt->execute();
        $user = $user_stmt->get_result()->fetch_assoc();
    } else {
        // Check if Blogger and not active
        if ($user['role'] === 'Blogger' && $user['status'] !== 'Active') {
            http_response_code(403);
            echo jsonResponse(false, 'Your Blogger account is pending admin approval. Please wait for approval.');
            return;
        }
    }
    
    // Get user's selected fruits
    $fruits_stmt = $conn->prepare("SELECT f.id, f.name FROM user_fruits uf JOIN fruits f ON uf.fruit_id = f.id WHERE uf.user_id = ?");
    $fruits_stmt->bind_param("i", $user['id']);
    $fruits_stmt->execute();
    $fruits_result = $fruits_stmt->get_result();
    $userFruits = [];
    while ($fruit = $fruits_result->fetch_assoc()) {
        $userFruits[] = $fruit;
    }
    
    unset($user['password_hash']);
    $user['fruits'] = $userFruits;
    fos_attach_premium_to_user($user, $conn);
    
    echo jsonResponse(true, 'OTP login successful', $user);
}

function handleAppleAuth($conn) {
    $appleId = trim($_POST['apple_id'] ?? '');
    $email = trim($_POST['email'] ?? '');
    $name = trim($_POST['name'] ?? '');
    $identityToken = trim($_POST['identity_token'] ?? '');
    $authorizationCode = trim($_POST['authorization_code'] ?? '');
    
    if (empty($appleId)) {
        http_response_code(400);
        echo jsonResponse(false, 'Apple ID is required');
        return;
    }
    
    // Note: Email may be null if user chose to hide it (private relay)
    // Name may be null on subsequent logins (only provided first time)
    
    // Check if user exists by Apple ID first
    $stmt = $conn->prepare("SELECT * FROM users WHERE apple_id = ?");
    $stmt->bind_param("s", $appleId);
    $stmt->execute();
    $result = $stmt->get_result();
    $user = $result->fetch_assoc();
    
    if ($user) {
        // User exists, update email/name if provided and not set
        $updateFields = [];
        $updateValues = [];
        $updateTypes = '';
        
        if (!empty($email) && empty($user['email'])) {
            $updateFields[] = "email = ?";
            $updateValues[] = $email;
            $updateTypes .= 's';
        }
        
        if (!empty($name) && empty($user['name'])) {
            $updateFields[] = "name = ?";
            $updateValues[] = $name;
            $updateTypes .= 's';
        }
        
        if (!empty($updateFields)) {
            $updateValues[] = $user['id'];
            $updateTypes .= 'i';
            $updateSql = "UPDATE users SET " . implode(", ", $updateFields) . " WHERE id = ?";
            $update_stmt = $conn->prepare($updateSql);
            $update_stmt->bind_param($updateTypes, ...$updateValues);
            $update_stmt->execute();
            
            // Refresh user data
            $stmt = $conn->prepare("SELECT * FROM users WHERE id = ?");
            $stmt->bind_param("i", $user['id']);
            $stmt->execute();
            $result = $stmt->get_result();
            $user = $result->fetch_assoc();
        }
        
        // Check if Blogger and not active
        if ($user['role'] === 'Blogger' && $user['status'] !== 'Active') {
            http_response_code(403);
            echo jsonResponse(false, 'Your Blogger account is pending admin approval. Please wait for approval.');
            return;
        }
    } else {
        // User doesn't exist, check by email if provided
        if (!empty($email)) {
            $stmt = $conn->prepare("SELECT * FROM users WHERE email = ?");
            $stmt->bind_param("s", $email);
            $stmt->execute();
            $result = $stmt->get_result();
            $existingUser = $result->fetch_assoc();
            
            if ($existingUser) {
                // Link Apple ID to existing account
                $update_stmt = $conn->prepare("UPDATE users SET apple_id = ? WHERE id = ?");
                $update_stmt->bind_param("si", $appleId, $existingUser['id']);
                $update_stmt->execute();
                
                // Refresh user data
                $stmt = $conn->prepare("SELECT * FROM users WHERE id = ?");
                $stmt->bind_param("i", $existingUser['id']);
                $stmt->execute();
                $result = $stmt->get_result();
                $user = $result->fetch_assoc();
                
                // Check if Blogger and not active
                if ($user['role'] === 'Blogger' && $user['status'] !== 'Active') {
                    http_response_code(403);
                    echo jsonResponse(false, 'Your Blogger account is pending admin approval. Please wait for approval.');
                    return;
                }
            } else {
                // Create new user
                $joinDate = date('Y-m-d');
                $role = 'User';
                $status = 'Active';
                $passwordHash = md5(uniqid(rand(), true)); // Random password for Apple login
                
                // Use provided name or generate default
                $userName = !empty($name) ? $name : (!empty($email) ? explode('@', $email)[0] : 'Apple User');
                
                // Use email if provided, otherwise use a placeholder (private relay)
                $userEmail = !empty($email) ? $email : ($appleId . '@privaterelay.appleid.com');
                
                $insert_stmt = $conn->prepare("INSERT INTO users (name, email, password_hash, role, status, join_date, apple_id) VALUES (?, ?, ?, ?, ?, ?, ?)");
                $insert_stmt->bind_param("sssssss", $userName, $userEmail, $passwordHash, $role, $status, $joinDate, $appleId);
                
                if ($insert_stmt->execute()) {
                    $userId = $conn->insert_id;
                    
                    // Fetch the newly created user
                    $stmt = $conn->prepare("SELECT * FROM users WHERE id = ?");
                    $stmt->bind_param("i", $userId);
                    $stmt->execute();
                    $result = $stmt->get_result();
                    $user = $result->fetch_assoc();
                } else {
                    http_response_code(500);
                    echo jsonResponse(false, 'Failed to create user account');
                    return;
                }
            }
        } else {
            // No email provided (private relay), create new user with Apple ID only
            $joinDate = date('Y-m-d');
            $role = 'User';
            $status = 'Active';
            $passwordHash = md5(uniqid(rand(), true));
            $userName = !empty($name) ? $name : 'Apple User';
            $userEmail = $appleId . '@privaterelay.appleid.com';
            
            $insert_stmt = $conn->prepare("INSERT INTO users (name, email, password_hash, role, status, join_date, apple_id) VALUES (?, ?, ?, ?, ?, ?, ?)");
            $insert_stmt->bind_param("sssssss", $userName, $userEmail, $passwordHash, $role, $status, $joinDate, $appleId);
            
            if ($insert_stmt->execute()) {
                $userId = $conn->insert_id;
                
                // Fetch the newly created user
                $stmt = $conn->prepare("SELECT * FROM users WHERE id = ?");
                $stmt->bind_param("i", $userId);
                $stmt->execute();
                $result = $stmt->get_result();
                $user = $result->fetch_assoc();
            } else {
                http_response_code(500);
                echo jsonResponse(false, 'Failed to create user account');
                return;
            }
        }
    }
    
    // Get user's selected fruits
    $fruits_stmt = $conn->prepare("SELECT f.* FROM fruits f INNER JOIN user_fruits uf ON f.id = uf.fruit_id WHERE uf.user_id = ?");
    $fruits_stmt->bind_param("i", $user['id']);
    $fruits_stmt->execute();
    $fruits_result = $fruits_stmt->get_result();
    $userFruits = [];
    while ($fruit = $fruits_result->fetch_assoc()) {
        $userFruits[] = $fruit;
    }
    
    // Remove sensitive data
    unset($user['password_hash']);
    $user['fruits'] = $userFruits;
    fos_attach_premium_to_user($user, $conn);
    
    echo jsonResponse(true, 'Apple authentication successful', $user);
}

$conn->close();

// Clean output buffer and send response
ob_end_flush();