<?php

// Skip authentication for API requests (use strpos for PHP 7.x — str_contains is PHP 8+)
$requestUri = isset($_SERVER['REQUEST_URI']) ? (string) $_SERVER['REQUEST_URI'] : '';
if (strpos($requestUri, '/api/') !== false) {
    return;
}

// Start session if not already started
if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

// Check if admin is logged in
if (!isset($_SESSION['admin_logged_in']) || $_SESSION['admin_logged_in'] !== true) {
    header("Location: login.php");
    exit;
}

// Optional: Add session security checks
function validateAdminSession() {
    if (!isset($_SESSION['admin_id']) || !isset($_SESSION['admin_email'])) {
        header("Location: login.php");
        exit;
    }
}

// Call validation (optional but recommended)
validateAdminSession();
?>