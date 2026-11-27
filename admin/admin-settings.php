<?php
session_start();
require_once 'includes/db.php';
require_once 'includes/admin-auth.php';
include './partials/layouts/layoutTop.php';

// Get current settings
$settings_sql = "SELECT * FROM system_settings LIMIT 1";
$settings_result = $conn->query($settings_sql);
$settings = $settings_result->fetch_assoc();

if (!$settings) {
    // Create default settings if not exists
    $insert_sql = "INSERT INTO system_settings (app_name, support_email, default_language, blog_auto_approve, email_verification) VALUES ('Fruit of the Spirit', 'support@fruitofthespirit.com', 'en', 0, 0)";
    $conn->query($insert_sql);
    $settings_result = $conn->query($settings_sql);
    $settings = $settings_result->fetch_assoc();
}

$success = '';
$error = '';

// Handle settings update
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $app_name = trim($_POST['app_name']);
    $support_email = trim($_POST['support_email']);
    $default_language = $_POST['default_language'];
    $blog_auto_approve = isset($_POST['blog_auto_approve']) ? 1 : 0;
    $email_verification = isset($_POST['email_verification']) ? 1 : 0;
    
    if (empty($app_name) || empty($support_email)) {
        $error = "App name and support email are required";
    } else {
        $update_sql = "UPDATE system_settings SET 
                      app_name = ?, 
                      support_email = ?, 
                      default_language = ?, 
                      blog_auto_approve = ?, 
                      email_verification = ? 
                      WHERE id = ?";
        $update_stmt = $conn->prepare($update_sql);
        $update_stmt->bind_param("sssiii", $app_name, $support_email, $default_language, $blog_auto_approve, $email_verification, $settings['id']);
        
        if ($update_stmt->execute()) {
            $success = "Settings updated successfully";
            // Refresh settings
            $settings_result = $conn->query($settings_sql);
            $settings = $settings_result->fetch_assoc();
        } else {
            $error = "Error updating settings";
        }
    }
}
?>

<div class="dashboard-main-body">
    <div class="d-flex flex-wrap align-items-center justify-content-between gap-3 mb-24">
        <h6 class="fw-semibold mb-0">System Settings</h6>
    </div>

    <?php if ($success): ?>
        <div class="alert alert-success alert-dismissible fade show mb-4">
            <iconify-icon icon="bi:check-circle-fill" class="icon me-2"></iconify-icon>
            <?php echo $success; ?>
            <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
        </div>
    <?php endif; ?>
    
    <?php if ($error): ?>
        <div class="alert alert-danger alert-dismissible fade show mb-4">
            <iconify-icon icon="bi:exclamation-triangle-fill" class="icon me-2"></iconify-icon>
            <?php echo $error; ?>
            <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
        </div>
    <?php endif; ?>

    <div class="row gy-4">
        <div class="col-lg-8">
            <div class="card">
                <div class="card-header bg-white">
                    <h6 class="fw-semibold mb-0">General Settings</h6>
                </div>
                <div class="card-body">
                    <form method="POST" action="">
                        <div class="row">
                            <div class="col-md-6">
                                <div class="mb-3">
                                    <label class="form-label">Application Name</label>
                                    <input type="text" class="form-control" name="app_name" 
                                           value="<?php echo htmlspecialchars($settings['app_name']); ?>" required>
                                </div>
                            </div>
                            <div class="col-md-6">
                                <div class="mb-3">
                                    <label class="form-label">Support Email</label>
                                    <input type="email" class="form-control" name="support_email" 
                                           value="<?php echo htmlspecialchars($settings['support_email']); ?>" required>
                                </div>
                            </div>
                        </div>
                        
                        <div class="row">
                            <div class="col-md-6">
                                <div class="mb-3">
                                    <label class="form-label">Default Language</label>
                                    <select class="form-control" name="default_language">
                                        <option value="en" <?php echo $settings['default_language'] == 'en' ? 'selected' : ''; ?>>English</option>
                                        <option value="es" <?php echo $settings['default_language'] == 'es' ? 'selected' : ''; ?>>Spanish</option>
                                        <option value="fr" <?php echo $settings['default_language'] == 'fr' ? 'selected' : ''; ?>>French</option>
                                    </select>
                                </div>
                            </div>
                        </div>
                        
                        <div class="row">
                            <div class="col-md-6">
                                <div class="form-check form-switch mb-3">
                                    <input class="form-check-input" type="checkbox" name="blog_auto_approve" 
                                           <?php echo $settings['blog_auto_approve'] ? 'checked' : ''; ?>>
                                    <label class="form-check-label">Auto-approve blog posts</label>
                                </div>
                            </div>
                            <div class="col-md-6">
                                <div class="form-check form-switch mb-3">
                                    <input class="form-check-input" type="checkbox" name="email_verification" 
                                           <?php echo $settings['email_verification'] ? 'checked' : ''; ?>>
                                    <label class="form-check-label">Require email verification</label>
                                </div>
                            </div>
                        </div>
                        
                        <button type="submit" class="btn btn-primary">Save Settings</button>
                    </form>
                </div>
            </div>
        </div>
        
        <div class="col-lg-4">
            <div class="card">
                <div class="card-header bg-white">
                    <h6 class="fw-semibold mb-0">System Information</h6>
                </div>
                <div class="card-body">
                    <div class="mb-3">
                        <strong>PHP Version:</strong> <?php echo phpversion(); ?>
                    </div>
                    <div class="mb-3">
                        <strong>Database:</strong> MySQL
                    </div>
                    <div class="mb-3">
                        <strong>Server Software:</strong> <?php echo $_SERVER['SERVER_SOFTWARE']; ?>
                    </div>
                    <div class="mb-3">
                        <strong>Last Updated:</strong> <?php echo date('M j, Y g:i A'); ?>
                    </div>
                </div>
            </div>
        </div>
    </div>
</div>

<?php include './partials/layouts/layoutBottom.php'; ?>