<?php
// Start session
if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

// Destroy all session data
$_SESSION = array();

// Finally, destroy the session
session_destroy();

// Redirect to login page
header("Location: login.php");
exit;
?>