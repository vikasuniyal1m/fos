<?php
include './includes/db.php';
include './includes/admin-auth.php';
include './partials/layouts/layoutTop.php';

// Handle form submission
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $app_name = $conn->real_escape_string($_POST['app_name']);
    $support_email = $conn->real_escape_string($_POST['support_email']);
    $default_language = $conn->real_escape_string($_POST['default_language']);
    $prayer_notifications = isset($_POST['prayer_notifications']) ? 1 : 0;
    $blog_auto_approve = isset($_POST['blog_auto_approve']) ? 1 : 0;
    
    // Update settings in database (you might want to create a settings table)
    $conn->query("UPDATE system_settings SET 
        app_name = '$app_name',
        support_email = '$support_email', 
        default_language = '$default_language',
        prayer_notifications = $prayer_notifications,
        blog_auto_approve = $blog_auto_approve 
        WHERE id = 1");
    
    $success = "Settings updated successfully!";
}

// Get current settings
$settings = $conn->query("SELECT * FROM system_settings WHERE id = 1")->fetch_assoc();
if (!$settings) {
    // Insert default settings if not exists
    $conn->query("INSERT INTO system_settings (app_name, support_email, default_language) VALUES ('Fruit of the Spirit', 'support@fruitofthespirit.com', 'en')");
    $settings = $conn->query("SELECT * FROM system_settings WHERE id = 1")->fetch_assoc();
}
?>

<div class="dashboard-main-body">
    <div class="d-flex flex-wrap align-items-center justify-content-between gap-3 mb-24">
        <h6 class="fw-semibold mb-0">System Settings</h6>
        <ul class="d-flex align-items-center gap-2">
            <li class="fw-medium">
                <a href="index.php" class="d-flex align-items-center gap-1 hover-text-primary">
                    <iconify-icon icon="solar:home-smile-angle-outline" class="icon text-lg"></iconify-icon>
                    Dashboard
                </a>
            </li>
            <li>-</li>
            <li class="fw-medium">System Settings</li>
        </ul>
    </div>

    <?php if (isset($success)): ?>
        <div class="alert alert-success"><?php echo $success; ?></div>
    <?php endif; ?>

    <div class="card h-100 p-0 radius-12">
        <div class="card-body p-24">
            <form method="POST">
                <div class="row">
                    <div class="col-md-6">
                        <h6 class="text-md text-primary-light mb-16">General Settings</h6>
                        
                        <div class="mb-20">
                            <label class="form-label fw-semibold text-primary-light text-sm mb-8">App Name</label>
                            <input type="text" class="form-control radius-8" name="app_name" value="<?php echo htmlspecialchars($settings['app_name']); ?>" required>
                        </div>
                        
                        <div class="mb-20">
                            <label class="form-label fw-semibold text-primary-light text-sm mb-8">Support Email</label>
                            <input type="email" class="form-control radius-8" name="support_email" value="<?php echo htmlspecialchars($settings['support_email']); ?>" required>
                        </div>
                        
                        <div class="mb-20">
                            <label class="form-label fw-semibold text-primary-light text-sm mb-8">Default Language</label>
                            <select class="form-control radius-8 form-select" name="default_language">
                                <option value="en" <?php echo $settings['default_language'] == 'en' ? 'selected' : ''; ?>>English</option>
                                <option value="es" <?php echo $settings['default_language'] == 'es' ? 'selected' : ''; ?>>Spanish</option>
                                <option value="fr" <?php echo $settings['default_language'] == 'fr' ? 'selected' : ''; ?>>French</option>
                            </select>
                        </div>
                    </div>
                    
                    <div class="col-md-6">
                        <h6 class="text-md text-primary-light mb-16">Feature Settings</h6>
                        
                        <div class="form-check form-switch mb-20">
                            <input class="form-check-input" type="checkbox" name="prayer_notifications" id="prayer_notifications" <?php echo $settings['prayer_notifications'] ? 'checked' : ''; ?>>
                            <label class="form-check-label" for="prayer_notifications">Prayer Notifications</label>
                        </div>
                        
                        <div class="form-check form-switch mb-20">
                            <input class="form-check-input" type="checkbox" name="blog_auto_approve" id="blog_auto_approve" <?php echo $settings['blog_auto_approve'] ? 'checked' : ''; ?>>
                            <label class="form-check-label" for="blog_auto_approve">Auto-approve Blogs</label>
                        </div>
                        
                        <div class="form-check form-switch mb-20">
                            <input class="form-check-input" type="checkbox" name="email_verification" id="email_verification" <?php echo $settings['email_verification'] ? 'checked' : ''; ?>>
                            <label class="form-check-label" for="email_verification">Email Verification</label>
                        </div>
                    </div>
                </div>
                
                <div class="d-flex align-items-center justify-content-center gap-3 mt-24">
                    <button type="reset" class="border border-danger-600 bg-hover-danger-200 text-danger-600 text-md px-56 py-11 radius-8">
                        Reset
                    </button>
                    <button type="submit" class="btn btn-primary border border-primary-600 text-md px-56 py-12 radius-8">
                        Save Settings
                    </button>
                </div>
            </form>
        </div>
    </div>
</div>

<?php include './partials/layouts/layoutBottom.php'; ?>