<?php
include './includes/db.php';
include './partials/layouts/layoutTop.php';

// Check if system_settings table has the required columns, if not create them
$checkColumns = $conn->query("SHOW COLUMNS FROM system_settings LIKE 'prayer_notifications'");
if ($checkColumns->num_rows == 0) {
    // Add missing columns to system_settings table
    $conn->query("ALTER TABLE system_settings 
        ADD COLUMN prayer_notifications TINYINT DEFAULT 1,
        ADD COLUMN blog_notifications TINYINT DEFAULT 1,
        ADD COLUMN comment_notifications TINYINT DEFAULT 1,
        ADD COLUMN group_notifications TINYINT DEFAULT 1,
        ADD COLUMN email_notifications TINYINT DEFAULT 1,
        ADD COLUMN push_notifications TINYINT DEFAULT 1,
        ADD COLUMN notification_frequency VARCHAR(20) DEFAULT 'instant'");
}

// Handle form submission
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $prayer_notifications = isset($_POST['prayer_notifications']) ? 1 : 0;
    $blog_notifications = isset($_POST['blog_notifications']) ? 1 : 0;
    $comment_notifications = isset($_POST['comment_notifications']) ? 1 : 0;
    $group_notifications = isset($_POST['group_notifications']) ? 1 : 0;
    $email_notifications = isset($_POST['email_notifications']) ? 1 : 0;
    $push_notifications = isset($_POST['push_notifications']) ? 1 : 0;
    $notification_frequency = $conn->real_escape_string($_POST['notification_frequency']);
    
    // Update settings
    $conn->query("UPDATE system_settings SET 
        prayer_notifications = $prayer_notifications,
        blog_notifications = $blog_notifications,
        comment_notifications = $comment_notifications,
        group_notifications = $group_notifications,
        email_notifications = $email_notifications,
        push_notifications = $push_notifications,
        notification_frequency = '$notification_frequency'
        WHERE id = 1");
    
    $success = "Notification settings updated successfully!";
}

// Get current settings with safe defaults
$settings = $conn->query("SELECT * FROM system_settings WHERE id = 1")->fetch_assoc();
if (!$settings) {
    // Insert default settings if not exists
    $conn->query("INSERT INTO system_settings (app_name, support_email, default_language) VALUES ('Fruit of the Spirit', 'support@fruitofthespirit.com', 'en')");
    $settings = $conn->query("SELECT * FROM system_settings WHERE id = 1")->fetch_assoc();
}

// Set safe defaults for notification settings
$prayer_notifications = isset($settings['prayer_notifications']) ? $settings['prayer_notifications'] : 1;
$blog_notifications = isset($settings['blog_notifications']) ? $settings['blog_notifications'] : 1;
$comment_notifications = isset($settings['comment_notifications']) ? $settings['comment_notifications'] : 1;
$group_notifications = isset($settings['group_notifications']) ? $settings['group_notifications'] : 1;
$email_notifications = isset($settings['email_notifications']) ? $settings['email_notifications'] : 1;
$push_notifications = isset($settings['push_notifications']) ? $settings['push_notifications'] : 1;
$notification_frequency = isset($settings['notification_frequency']) ? $settings['notification_frequency'] : 'instant';
?>

<div class="dashboard-main-body">
    <div class="d-flex flex-wrap align-items-center justify-content-between gap-3 mb-24">
        <h6 class="fw-semibold mb-0">Notification Settings</h6>
        <ul class="d-flex align-items-center gap-2">
            <li class="fw-medium">
                <a href="index.php" class="d-flex align-items-center gap-1 hover-text-primary">
                    <iconify-icon icon="solar:home-smile-angle-outline" class="icon text-lg"></iconify-icon>
                    Dashboard
                </a>
            </li>
            <li>-</li>
            <li class="fw-medium">Notification Settings</li>
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
                        <h6 class="text-md text-primary-light mb-16">Notification Types</h6>
                        
                        <div class="form-check form-switch mb-20">
                            <input class="form-check-input" type="checkbox" name="prayer_notifications" id="prayer_notifications" <?php echo $prayer_notifications ? 'checked' : ''; ?>>
                            <label class="form-check-label" for="prayer_notifications">Prayer Request Notifications</label>
                        </div>
                        
                        <div class="form-check form-switch mb-20">
                            <input class="form-check-input" type="checkbox" name="blog_notifications" id="blog_notifications" <?php echo $blog_notifications ? 'checked' : ''; ?>>
                            <label class="form-check-label" for="blog_notifications">New Blog Post Notifications</label>
                        </div>
                        
                        <div class="form-check form-switch mb-20">
                            <input class="form-check-input" type="checkbox" name="comment_notifications" id="comment_notifications" <?php echo $comment_notifications ? 'checked' : ''; ?>>
                            <label class="form-check-label" for="comment_notifications">Comment Notifications</label>
                        </div>
                        
                        <div class="form-check form-switch mb-20">
                            <input class="form-check-input" type="checkbox" name="group_notifications" id="group_notifications" <?php echo $group_notifications ? 'checked' : ''; ?>>
                            <label class="form-check-label" for="group_notifications">Group Activity Notifications</label>
                        </div>
                    </div>
                    
                    <div class="col-md-6">
                        <h6 class="text-md text-primary-light mb-16">Delivery Methods</h6>
                        
                        <div class="form-check form-switch mb-20">
                            <input class="form-check-input" type="checkbox" name="email_notifications" id="email_notifications" <?php echo $email_notifications ? 'checked' : ''; ?>>
                            <label class="form-check-label" for="email_notifications">Email Notifications</label>
                        </div>
                        
                        <div class="form-check form-switch mb-20">
                            <input class="form-check-input" type="checkbox" name="push_notifications" id="push_notifications" <?php echo $push_notifications ? 'checked' : ''; ?>>
                            <label class="form-check-label" for="push_notifications">Push Notifications</label>
                        </div>
                        
                        <div class="mb-20">
                            <label class="form-label fw-semibold text-primary-light text-sm mb-8">Notification Frequency</label>
                            <select class="form-control radius-8 form-select" name="notification_frequency">
                                <option value="instant" <?php echo $notification_frequency == 'instant' ? 'selected' : ''; ?>>Instant</option>
                                <option value="hourly" <?php echo $notification_frequency == 'hourly' ? 'selected' : ''; ?>>Hourly Digest</option>
                                <option value="daily" <?php echo $notification_frequency == 'daily' ? 'selected' : ''; ?>>Daily Digest</option>
                            </select>
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