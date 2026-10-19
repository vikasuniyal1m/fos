<?php
/**
 * Email Helper Functions
 * Handles sending emails (OTP, notifications, etc.)
 * Uses PHP mail() function for sending emails
 */

// Email configuration - You can change these values
if (!defined('EMAIL_FROM_ADDRESS')) define('EMAIL_FROM_ADDRESS', 'info@fruitofthespirit.templateforwebsites.com');
if (!defined('EMAIL_FROM_NAME')) define('EMAIL_FROM_NAME', 'FOS Messenger');
if (!defined('EMAIL_REPLY_TO')) define('EMAIL_REPLY_TO', 'info@fruitofthespirit.templateforwebsites.com');

// SMTP Configuration (set credentials in the environment to enable SMTP)
if (!defined('USE_SMTP')) define('USE_SMTP', filter_var(getenv('USE_SMTP') ?: 'false', FILTER_VALIDATE_BOOLEAN));
if (!defined('SMTP_HOST')) define('SMTP_HOST', 'smtp.hostinger.com'); // Hostinger SMTP
if (!defined('SMTP_PORT')) define('SMTP_PORT', 465); // SSL port
if (!defined('SMTP_USERNAME')) define('SMTP_USERNAME', 'info@fruitofthespirit.templateforwebsites.com');
if (!defined('SMTP_PASSWORD')) define('SMTP_PASSWORD', getenv('SMTP_PASSWORD') ?: '');
if (!defined('SMTP_ENCRYPTION')) define('SMTP_ENCRYPTION', 'ssl'); // 'ssl' for port 465

// Twilio Configuration
if (!defined('TWILIO_SID')) define('TWILIO_SID', getenv('TWILIO_SID') ?: '');
if (!defined('TWILIO_TOKEN')) define('TWILIO_TOKEN', getenv('TWILIO_TOKEN') ?: '');
if (!defined('TWILIO_FROM')) define('TWILIO_FROM', getenv('TWILIO_FROM') ?: '');

/**
 * Send OTP via Email
 * 
 * @param string $to Email address
 * @param string $otpCode 6-digit OTP code
 * @return bool Success status
 */
function sendOtpEmail($to, $otpCode) {
    $subject = "Your OTP for Password Reset - FOS Messenger";
    
    $message = "
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset='utf-8'>
        <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f9f9f9; border-radius: 10px; }
            .header { text-align: center; margin-bottom: 30px; }
            .header h1 { color: #8B4513; margin: 0; }
            .otp-box { background-color: #fff; border: 2px dashed #8B4513; border-radius: 8px; padding: 20px; text-align: center; margin: 30px 0; }
            .otp-code { font-size: 32px; font-weight: bold; color: #8B4513; letter-spacing: 5px; margin: 10px 0; }
            .footer { margin-top: 30px; padding-top: 20px; border-top: 1px solid #ddd; font-size: 12px; color: #666; text-align: center; }
            .warning { background-color: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; margin: 20px 0; border-radius: 4px; }
        </style>
    </head>
    <body>
        <div class='container'>
            <div class='header'>
                <h1>FOS Messenger</h1>
            </div>
            
            <h2>Password Reset OTP</h2>
            
            <p>Hello,</p>
            
            <p> Please use the following OTP (One-Time Password) to complete the process:</p>
            
            <div class='otp-box'>
                <div class='otp-code'>{$otpCode}</div>
            </div>
            
            <div class='warning'>
                <strong>⚠️ Important:</strong>
                <ul style='margin: 10px 0; padding-left: 20px;'>
                    <li>This OTP is valid for <strong>10 minutes</strong> only</li>
                    <li>Do not share this OTP with anyone</li>
                    <li>If you did not request this, please ignore this email</li>
                </ul>
            </div>
                        
            <div class='footer'>
                <p>© " . date('Y') . " FOS Productions All rights reserved.</p>
                <p>This is an automated email, please do not reply.</p>
            </div>
        </div>
    </body>
    </html>
    ";
    
    // Email headers
    $fromName = defined('EMAIL_FROM_NAME') ? EMAIL_FROM_NAME : 'FOS Messenger';
    $fromAddress = defined('EMAIL_FROM_ADDRESS') ? EMAIL_FROM_ADDRESS : 'noreply@fruitofthespirit.templateforwebsites.com';
    $replyTo = defined('EMAIL_REPLY_TO') ? EMAIL_REPLY_TO : 'noreply@fruitofthespirit.templateforwebsites.com';
    
    $headers = "MIME-Version: 1.0" . "\r\n";
    $headers .= "Content-type:text/html;charset=UTF-8" . "\r\n";
    $headers .= "From: {$fromName} <{$fromAddress}>" . "\r\n";
    $headers .= "Reply-To: {$replyTo}" . "\r\n";
    $headers .= "X-Mailer: PHP/" . phpversion() . "\r\n";
    
    // Check if SMTP is enabled
    $useSmtp = defined('USE_SMTP') && USE_SMTP === true;
    
    if ($useSmtp) {
        // Use SMTP (Native PHP - No PHPMailer needed)
        return sendOtpEmailSmtp($to, $otpCode, $subject, $message);
    }
    
    // Send email using PHP mail() function
    // Clear any previous errors
    error_clear_last();
    
    // Try to send email
    $oldErrorReporting = error_reporting(0);
    $success = mail($to, $subject, $message, $headers);
    error_reporting($oldErrorReporting);
    
    // Get any errors that occurred
    $lastError = error_get_last();
    $hasError = false;
    $errorMsg = '';
    
    // Check if mail() returned false or if there was an error
    if (!$success) {
        $hasError = true;
        if ($lastError) {
            $errorMsg = $lastError['message'];
        } else {
            $errorMsg = 'mail() function returned false - check server mail configuration';
        }
    }
    
    // Additional check: verify mail function is available
    if (!function_exists('mail')) {
        $hasError = true;
        $errorMsg = 'mail() function is not available on this server';
    }
    
    // Log email sending with details
    if ($success && !$hasError) {
        error_log("✅ OTP email sent successfully to: {$to} | OTP: {$otpCode}");
        return true;
    } else {
        // Detailed error logging
        $detailedError = "❌ Failed to send OTP email to: {$to} | OTP: {$otpCode} | Error: {$errorMsg}";
        error_log($detailedError);
        
        // Also log to a file for debugging
        $logFile = __DIR__ . '/../logs/email_errors.log';
        $logDir = dirname($logFile);
        if (!is_dir($logDir)) {
            @mkdir($logDir, 0755, true);
        }
        $logMessage = date('Y-m-d H:i:s') . " - Failed to send email to: {$to} | Error: {$errorMsg} | From: {$fromAddress}\n";
        @file_put_contents($logFile, $logMessage, FILE_APPEND);
        
        return false;
    }
}

/**
 * Send OTP Email via SMTP using Native PHP (No PHPMailer needed)
 * 
 * @param string $to Email address
 * @param string $otpCode 6-digit OTP code
 * @param string $subject Email subject
 * @param string $message Email message (HTML)
 * @return bool Success status
 */
function sendOtpEmailSmtp($to, $otpCode, $subject, $message) {
    $smtpHost = defined('SMTP_HOST') ? SMTP_HOST : 'smtp.hostinger.com';
    $smtpPort = defined('SMTP_PORT') ? SMTP_PORT : 465;
    $smtpUsername = defined('SMTP_USERNAME') ? SMTP_USERNAME : '';
    $smtpPassword = defined('SMTP_PASSWORD') ? SMTP_PASSWORD : '';
    $smtpEncryption = defined('SMTP_ENCRYPTION') ? SMTP_ENCRYPTION : 'ssl';
    
    $fromName = defined('EMAIL_FROM_NAME') ? EMAIL_FROM_NAME : 'FOS Messenger';
    $fromAddress = defined('EMAIL_FROM_ADDRESS') ? EMAIL_FROM_ADDRESS : 'info@fruitofthespirit.templateforwebsites.com';
    $replyTo = defined('EMAIL_REPLY_TO') ? EMAIL_REPLY_TO : 'info@fruitofthespirit.templateforwebsites.com';
    
    // Determine if we need SSL
    $useSSL = ($smtpEncryption === 'ssl');
    $host = $useSSL ? 'ssl://' . $smtpHost : $smtpHost;
    
    // Create socket connection
    $socket = @fsockopen($host, $smtpPort, $errno, $errstr, 30);
    
    if (!$socket) {
        error_log("❌ SMTP Connection failed: {$errstr} ({$errno})");
        return false;
    }
    
    // Set timeout
    stream_set_timeout($socket, 30);
    
    // Read server response
    $response = fgets($socket, 515);
    if (substr($response, 0, 3) !== '220') {
        error_log("❌ SMTP Server error: {$response}");
        fclose($socket);
        return false;
    }
    
    // Send EHLO
    fputs($socket, "EHLO " . $smtpHost . "\r\n");
    $response = '';
    while ($line = fgets($socket, 515)) {
        $response .= $line;
        if (substr($line, 3, 1) === ' ') break;
    }
    
    // Start TLS if needed (for port 587)
    if ($smtpEncryption === 'tls' && strpos($response, 'STARTTLS') !== false) {
        fputs($socket, "STARTTLS\r\n");
        $response = fgets($socket, 515);
        if (substr($response, 0, 3) !== '220') {
            error_log("❌ STARTTLS failed: {$response}");
            fclose($socket);
            return false;
        }
        
        // Enable crypto
        if (!stream_socket_enable_crypto($socket, true, STREAM_CRYPTO_METHOD_TLS_CLIENT)) {
            error_log("❌ TLS encryption failed");
            fclose($socket);
            return false;
        }
        
        // Send EHLO again after TLS
        fputs($socket, "EHLO " . $smtpHost . "\r\n");
        $response = '';
        while ($line = fgets($socket, 515)) {
            $response .= $line;
            if (substr($line, 3, 1) === ' ') break;
        }
    }
    
    // Authenticate
    fputs($socket, "AUTH LOGIN\r\n");
    $response = fgets($socket, 515);
    if (substr($response, 0, 3) !== '334') {
        error_log("❌ AUTH LOGIN failed: {$response}");
        fclose($socket);
        return false;
    }
    
    // Send username
    fputs($socket, base64_encode($smtpUsername) . "\r\n");
    $response = fgets($socket, 515);
    if (substr($response, 0, 3) !== '334') {
        error_log("❌ Username authentication failed: {$response}");
        fclose($socket);
        return false;
    }
    
    // Send password
    fputs($socket, base64_encode($smtpPassword) . "\r\n");
    $response = fgets($socket, 515);
    if (substr($response, 0, 3) !== '235') {
        error_log("❌ Password authentication failed: {$response}");
        fclose($socket);
        return false;
    }
    
    // Send MAIL FROM
    fputs($socket, "MAIL FROM: <{$fromAddress}>\r\n");
    $response = fgets($socket, 515);
    if (substr($response, 0, 3) !== '250') {
        error_log("❌ MAIL FROM failed: {$response}");
        fclose($socket);
        return false;
    }
    
    // Send RCPT TO
    fputs($socket, "RCPT TO: <{$to}>\r\n");
    $response = fgets($socket, 515);
    if (substr($response, 0, 3) !== '250') {
        error_log("❌ RCPT TO failed: {$response}");
        fclose($socket);
        return false;
    }
    
    // Send DATA
    fputs($socket, "DATA\r\n");
    $response = fgets($socket, 515);
    if (substr($response, 0, 3) !== '354') {
        error_log("❌ DATA command failed: {$response}");
        fclose($socket);
        return false;
    }
    
    // Prepare email headers and body
    $emailHeaders = "From: {$fromName} <{$fromAddress}>\r\n";
    $emailHeaders .= "Reply-To: {$replyTo}\r\n";
    $emailHeaders .= "To: <{$to}>\r\n";
    $emailHeaders .= "Subject: {$subject}\r\n";
    $emailHeaders .= "MIME-Version: 1.0\r\n";
    $emailHeaders .= "Content-Type: text/html; charset=UTF-8\r\n";
    $emailHeaders .= "X-Mailer: PHP/" . phpversion() . "\r\n";
    $emailHeaders .= "\r\n";
    
    // Send email
    fputs($socket, $emailHeaders . $message . "\r\n.\r\n");
    $response = fgets($socket, 515);
    if (substr($response, 0, 3) !== '250') {
        error_log("❌ Email sending failed: {$response}");
        fclose($socket);
        return false;
    }
    
    // Quit
    fputs($socket, "QUIT\r\n");
    fclose($socket);
    
    error_log("✅ OTP email sent via SMTP to: {$to} | OTP: {$otpCode}");
    return true;
}

/**
 * Send SMS OTP (Placeholder - requires SMS service integration)
 * 
 * @param string $phone Phone number
 * @param string $otpCode 6-digit OTP code
 * @return bool Success status
 */
function sendOtpSms($phone, $otpCode) {
    $sid = TWILIO_SID;
    $token = TWILIO_TOKEN;
    $from = TWILIO_FROM;

    if ($sid === '' || $token === '' || $from === '') {
        error_log('Twilio OTP is not configured; set TWILIO_SID, TWILIO_TOKEN, and TWILIO_FROM.');
        return false;
    }
    
    // Ensure phone number is in E.164 format (e.g., +918126666331)
    if (substr($phone, 0, 1) !== '+') {
        // Default to India (+91) if no country code provided. 
        // Better fix: pass country code from frontend.
        $phone = '+91' . ltrim($phone, '0'); 
    }

    $message = "Your FOS Messages OTP is: " . $otpCode . ". Valid for 10 minutes.";
    
    $url = "https://api.twilio.com/2010-04-01/Accounts/$sid/Messages.json";
    
    $data = array(
        'From' => $from,
        'To' => $phone,
        'Body' => $message
    );
    
    $postBody = http_build_query($data);
    
    $ch = curl_init($url);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_USERPWD, "$sid:$token");
    curl_setopt($ch, CURLOPT_HTTPAUTH, CURLAUTH_BASIC);
    curl_setopt($ch, CURLOPT_POSTFIELDS, $postBody);
    
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    
    if ($httpCode == 201) {
        error_log("✅ Twilio OTP sent successfully to: {$phone}");
        return true;
    } else {
        error_log("❌ Twilio Error ($httpCode): " . $response);
        return false;
    }
}