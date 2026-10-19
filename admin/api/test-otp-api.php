<?php
/**
 * OTP API Testing Script
 * Use this to test OTP generation and verification
 * 
 * Usage:
 * 1. Open in browser or use Postman
 * 2. Test forgot-password endpoint
 * 3. Check email for OTP
 * 4. Test verify-otp endpoint
 */

require_once '../includes/db.php';
require_once '../includes/email_helper.php';

header('Content-Type: application/json');

// Get action from query parameter
$action = $_GET['action'] ?? '';

// Test email (change this to your test email)
$testEmail = 'test@example.com'; // Change this!

switch ($action) {
    case 'test-forgot-password':
        testForgotPassword($conn, $testEmail);
        break;
    
    case 'check-otp':
        checkOtpInDatabase($conn, $testEmail);
        break;
    
    case 'test-verify-otp':
        $otp = $_GET['otp'] ?? '';
        testVerifyOtp($conn, $testEmail, $otp);
        break;
    
    case 'cleanup':
        cleanupTestOtps($conn, $testEmail);
        break;
    
    default:
        showTestMenu();
        break;
}

function testForgotPassword($conn, $email) {
    echo "<h2>Testing Forgot Password (OTP Generation)</h2>";
    
    // Check if user exists
    $stmt = $conn->prepare("SELECT id FROM users WHERE email = ?");
    $stmt->bind_param("s", $email);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows === 0) {
        echo "<p style='color: red;'>❌ User not found with email: {$email}</p>";
        echo "<p>Please create a user first or use an existing email.</p>";
        return;
    }
    
    echo "<p>✅ User found: {$email}</p>";
    
    // Generate OTP
    $otpCode = str_pad(rand(0, 999999), 6, '0', STR_PAD_LEFT);
    $expiresAt = date('Y-m-d H:i:s', strtotime('+10 minutes'));
    
    // Delete old unused OTPs
    $delete_stmt = $conn->prepare("DELETE FROM otps WHERE email_or_phone = ? AND used_at IS NULL");
    $delete_stmt->bind_param("s", $email);
    $delete_stmt->execute();
    
    // Store OTP
    $insert_stmt = $conn->prepare("INSERT INTO otps (email_or_phone, otp_code, expires_at) VALUES (?, ?, ?)");
    $insert_stmt->bind_param("sss", $email, $otpCode, $expiresAt);
    
    if ($insert_stmt->execute()) {
        echo "<p style='color: green;'>✅ OTP generated and stored in database</p>";
        echo "<p><strong>OTP Code:</strong> <span style='font-size: 24px; color: blue;'>{$otpCode}</span></p>";
        echo "<p><strong>Expires At:</strong> {$expiresAt}</p>";
        
        // Send email
        $emailSent = sendOtpEmail($email, $otpCode);
        if ($emailSent) {
            echo "<p style='color: green;'>✅ OTP email sent successfully</p>";
        } else {
            echo "<p style='color: orange;'>⚠️ Email sending may have failed (check server logs)</p>";
        }
        
        echo "<hr>";
        echo "<p><a href='?action=check-otp&email={$email}'>Check OTP in Database</a></p>";
        echo "<p><a href='?action=test-verify-otp&email={$email}&otp={$otpCode}'>Test OTP Verification</a></p>";
    } else {
        echo "<p style='color: red;'>❌ Failed to generate OTP: " . $insert_stmt->error . "</p>";
    }
}

function checkOtpInDatabase($conn, $email) {
    echo "<h2>Checking OTP in Database</h2>";
    
    $stmt = $conn->prepare("SELECT * FROM otps WHERE email_or_phone = ? ORDER BY created_at DESC LIMIT 5");
    $stmt->bind_param("s", $email);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows === 0) {
        echo "<p style='color: red;'>❌ No OTP found for: {$email}</p>";
        return;
    }
    
    echo "<table border='1' cellpadding='10' style='border-collapse: collapse;'>";
    echo "<tr><th>ID</th><th>Email/Phone</th><th>OTP Code</th><th>Expires At</th><th>Used At</th><th>Created At</th></tr>";
    
    while ($row = $result->fetch_assoc()) {
        $used = $row['used_at'] ? '✅ Used' : '⏳ Active';
        echo "<tr>";
        echo "<td>{$row['id']}</td>";
        echo "<td>{$row['email_or_phone']}</td>";
        echo "<td><strong>{$row['otp_code']}</strong></td>";
        echo "<td>{$row['expires_at']}</td>";
        echo "<td>{$used}</td>";
        echo "<td>{$row['created_at']}</td>";
        echo "</tr>";
    }
    
    echo "</table>";
}

function testVerifyOtp($conn, $email, $otp) {
    echo "<h2>Testing OTP Verification</h2>";
    
    if (empty($otp)) {
        echo "<p style='color: red;'>❌ OTP is required</p>";
        return;
    }
    
    // Verify OTP
    $stmt = $conn->prepare("SELECT * FROM otps WHERE email_or_phone = ? AND otp_code = ? AND expires_at > NOW() AND used_at IS NULL ORDER BY created_at DESC LIMIT 1");
    $stmt->bind_param("ss", $email, $otp);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows === 0) {
        echo "<p style='color: red;'>❌ Invalid or expired OTP</p>";
        echo "<p>Please check:</p>";
        echo "<ul>";
        echo "<li>OTP code is correct</li>";
        echo "<li>OTP is not expired (10 minutes)</li>";
        echo "<li>OTP is not already used</li>";
        echo "</ul>";
        return;
    }
    
    $otpRecord = $result->fetch_assoc();
    
    // Mark as used
    $update_stmt = $conn->prepare("UPDATE otps SET used_at = NOW() WHERE id = ?");
    $update_stmt->bind_param("i", $otpRecord['id']);
    $update_stmt->execute();
    
    echo "<p style='color: green;'>✅ OTP verified successfully!</p>";
    echo "<p><strong>OTP ID:</strong> {$otpRecord['id']}</p>";
    echo "<p><strong>Marked as used at:</strong> " . date('Y-m-d H:i:s') . "</p>";
    echo "<p><em>Note: In real scenario, password would be reset here.</em></p>";
}

function cleanupTestOtps($conn, $email) {
    echo "<h2>Cleaning Up Test OTPs</h2>";
    
    $stmt = $conn->prepare("DELETE FROM otps WHERE email_or_phone = ?");
    $stmt->bind_param("s", $email);
    
    if ($stmt->execute()) {
        echo "<p style='color: green;'>✅ All OTPs deleted for: {$email}</p>";
    } else {
        echo "<p style='color: red;'>❌ Failed to cleanup</p>";
    }
}

function showTestMenu() {
    ?>
    <!DOCTYPE html>
    <html>
    <head>
        <title>OTP API Testing</title>
        <style>
            body { font-family: Arial, sans-serif; padding: 20px; }
            .menu { background: #f5f5f5; padding: 20px; border-radius: 8px; }
            .menu a { display: block; padding: 10px; margin: 5px 0; background: #007bff; color: white; text-decoration: none; border-radius: 4px; }
            .menu a:hover { background: #0056b3; }
            .info { background: #e7f3ff; padding: 15px; border-left: 4px solid #2196F3; margin: 20px 0; }
        </style>
    </head>
    <body>
        <h1>🔧 OTP API Testing Tool</h1>
        
        <div class="info">
            <strong>⚠️ Important:</strong> Change the test email in the PHP file before testing!
            <br>File: <code>api/test-otp-api.php</code> (line 15)
        </div>
        
        <div class="menu">
            <h2>Test Options:</h2>
            <a href="?action=test-forgot-password">1. Test Forgot Password (Generate OTP)</a>
            <a href="?action=check-otp">2. Check OTP in Database</a>
            <a href="?action=cleanup">3. Cleanup Test OTPs</a>
        </div>
        
        <div style="margin-top: 30px;">
            <h3>Manual Testing:</h3>
            <p>For OTP verification, use:</p>
            <code>?action=test-verify-otp&email=YOUR_EMAIL&otp=OTP_CODE</code>
        </div>
    </body>
    </html>
    <?php
}

$conn->close();
?>

