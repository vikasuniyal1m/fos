<?php
/**
 * Terms & Conditions API
 * Handles: Get terms content, Update terms (admin only)
 */

require_once '../includes/db.php';
require_once '../includes/cors.php';
require_once 'auth-helper.php';

header('Content-Type: application/json');

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'OPTIONS') {
    http_response_code(200);
    exit;
}

switch ($method) {
    case 'GET':
        handleGetTerms($conn);
        break;
    case 'POST':
        handleUpdateTerms($conn);
        break;
    default:
        http_response_code(405);
        echo jsonResponse(false, 'Method not allowed');
        break;
}

/**
 * Get Terms & Conditions Content
 * Public endpoint - no authentication required
 */
function handleGetTerms($conn) {
    // Check if terms table exists, if not create it
    $checkTable = $conn->query("SHOW TABLES LIKE 'terms_conditions'");
    if ($checkTable->num_rows === 0) {
        // Create table if doesn't exist
        $createTable = "CREATE TABLE IF NOT EXISTS terms_conditions (
            id INT AUTO_INCREMENT PRIMARY KEY,
            content TEXT NOT NULL,
            version VARCHAR(50) DEFAULT '1.0',
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )";
        
        if ($conn->query($createTable)) {
            // Insert default terms
            $defaultTerms = "By using this application, you agree to the following terms and conditions:

1. Acceptance of Terms
   - By accessing and using this application, you accept and agree to be bound by these terms and conditions.

2. User Conduct
   - You agree to use this application in a respectful and appropriate manner.
   - You will not post inappropriate, offensive, or harmful content.
   - You will respect other users' privacy and rights.

3. Content Guidelines
   - All content must be appropriate and aligned with the spiritual purpose of this application.
   - Content that is offensive, discriminatory, or violates any laws is prohibited.

4. Privacy
   - Your personal information will be handled according to our Privacy Policy.
   - We respect your privacy and will not share your information without consent.

5. Account Responsibility
   - You are responsible for maintaining the confidentiality of your account.
   - You are responsible for all activities that occur under your account.

6. Intellectual Property
   - All content in this application is protected by copyright and other intellectual property laws.
   - You may not reproduce, distribute, or create derivative works without permission.

7. Modifications
   - We reserve the right to modify these terms at any time.
   - Continued use of the application after changes constitutes acceptance of new terms.

8. Termination
   - We reserve the right to terminate or suspend accounts that violate these terms.

9. Disclaimer
   - This application is provided 'as is' without warranties of any kind.
   - We are not responsible for any damages resulting from use of this application.

10. Contact
    - For questions about these terms, please contact our support team.

Last Updated: " . date('F j, Y');
            
            $stmt = $conn->prepare("INSERT INTO terms_conditions (content, version) VALUES (?, '1.0')");
            $stmt->bind_param("s", $defaultTerms);
            $stmt->execute();
        }
    }
    
    // Get latest terms
    $result = $conn->query("SELECT content, version, updated_at FROM terms_conditions ORDER BY id DESC LIMIT 1");
    
    if ($result->num_rows > 0) {
        $terms = $result->fetch_assoc();
        echo jsonResponse(true, 'Terms retrieved successfully', $terms);
    } else {
        // Return default terms if none found
        $defaultTerms = [
            'content' => 'Terms & Conditions content will be available soon.',
            'version' => '1.0',
            'updated_at' => date('Y-m-d H:i:s')
        ];
        echo jsonResponse(true, 'Terms retrieved successfully', $defaultTerms);
    }
}

/**
 * Update Terms & Conditions (Admin Only)
 * Requires admin authentication
 */
function handleUpdateTerms($conn) {
    // Check authentication
    $user = getAuthenticatedUser($conn);
    if (!$user) {
        http_response_code(401);
        echo jsonResponse(false, 'Authentication required');
        return;
    }
    
    // Check if user is admin
    if ($user['role'] !== 'Admin') {
        http_response_code(403);
        echo jsonResponse(false, 'Admin access required');
        return;
    }
    
    $content = $_POST['content'] ?? '';
    $version = $_POST['version'] ?? '1.0';
    
    if (empty($content)) {
        http_response_code(400);
        echo jsonResponse(false, 'Content is required');
        return;
    }
    
    // Check if terms table exists
    $checkTable = $conn->query("SHOW TABLES LIKE 'terms_conditions'");
    if ($checkTable->num_rows === 0) {
        // Create table if doesn't exist
        $createTable = "CREATE TABLE IF NOT EXISTS terms_conditions (
            id INT AUTO_INCREMENT PRIMARY KEY,
            content TEXT NOT NULL,
            version VARCHAR(50) DEFAULT '1.0',
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )";
        $conn->query($createTable);
    }
    
    // Check if terms already exist
    $check = $conn->query("SELECT id FROM terms_conditions ORDER BY id DESC LIMIT 1");
    
    if ($check->num_rows > 0) {
        // Update existing terms
        $existing = $check->fetch_assoc();
        $stmt = $conn->prepare("UPDATE terms_conditions SET content = ?, version = ? WHERE id = ?");
        $stmt->bind_param("ssi", $content, $version, $existing['id']);
    } else {
        // Insert new terms
        $stmt = $conn->prepare("INSERT INTO terms_conditions (content, version) VALUES (?, ?)");
        $stmt->bind_param("ss", $content, $version);
    }
    
    if ($stmt->execute()) {
        echo jsonResponse(true, 'Terms updated successfully');
    } else {
        http_response_code(500);
        echo jsonResponse(false, 'Failed to update terms: ' . $stmt->error);
    }
}

$conn->close();
?>

