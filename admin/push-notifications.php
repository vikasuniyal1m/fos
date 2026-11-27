<?php
include './includes/db.php';
include './includes/admin-auth.php';
include './partials/layouts/layoutTop.php';

// Handle sending push notification
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $title = $conn->real_escape_string($_POST['title']);
    $message = $conn->real_escape_string($_POST['message']);
    $target_users = $conn->real_escape_string($_POST['target_users']);
    
    // Save notification to database
    $sql = "INSERT INTO push_notifications (title, message, target_users, sent_by) 
            VALUES ('$title', '$message', '$target_users', 1)";
    
    if ($conn->query($sql)) {
        $success = "Push notification scheduled successfully!";
        
        // In a real app, you would integrate with Firebase Cloud Messaging or similar service here
    } else {
        $error = "Error: " . $conn->error;
    }
}

// Get sent notifications
$notifications = $conn->query("
    SELECT pn.*, u.name as sent_by_name 
    FROM push_notifications pn 
    LEFT JOIN users u ON pn.sent_by = u.id 
    ORDER BY pn.created_at DESC 
    LIMIT 10
");
?>

<div class="dashboard-main-body">
    <div class="d-flex flex-wrap align-items-center justify-content-between gap-3 mb-24">
        <h6 class="fw-semibold mb-0">Push Notifications</h6>
        <ul class="d-flex align-items-center gap-2">
            <li class="fw-medium">
                <a href="index.php" class="d-flex align-items-center gap-1 hover-text-primary">
                    <iconify-icon icon="solar:home-smile-angle-outline" class="icon text-lg"></iconify-icon>
                    Dashboard
                </a>
            </li>
            <li>-</li>
            <li class="fw-medium">Push Notifications</li>
        </ul>
    </div>

    <?php if (isset($error)): ?>
        <div class="alert alert-danger"><?php echo $error; ?></div>
    <?php endif; ?>
    <?php if (isset($success)): ?>
        <div class="alert alert-success"><?php echo $success; ?></div>
    <?php endif; ?>

    <div class="row">
        <div class="col-lg-6">
            <div class="card h-100 radius-12">
                <div class="card-header border-bottom bg-base py-16 px-24">
                    <h6 class="fw-semibold mb-0">Send Push Notification</h6>
                </div>
                <div class="card-body p-24">
                    <form method="POST">
                        <div class="mb-20">
                            <label class="form-label fw-semibold text-primary-light text-sm mb-8">Notification Title</label>
                            <input type="text" class="form-control radius-8" name="title" required placeholder="Enter notification title">
                        </div>
                        
                        <div class="mb-20">
                            <label class="form-label fw-semibold text-primary-light text-sm mb-8">Message</label>
                            <textarea class="form-control radius-8" name="message" rows="4" required placeholder="Enter notification message"></textarea>
                        </div>
                        
                        <div class="mb-20">
                            <label class="form-label fw-semibold text-primary-light text-sm mb-8">Target Users</label>
                            <select class="form-control radius-8 form-select" name="target_users" required>
                                <option value="all">All Users</option>
                                <option value="bloggers">Bloggers Only</option>
                                <option value="active">Active Users Only</option>
                                <option value="inactive">Inactive Users Only</option>
                            </select>
                        </div>
                        
                        <button type="submit" class="btn btn-primary w-100 border border-primary-600 text-md py-12 radius-8">
                            Send Push Notification
                        </button>
                    </form>
                </div>
            </div>
        </div>
        
        <div class="col-lg-6">
            <div class="card h-100 radius-12">
                <div class="card-header border-bottom bg-base py-16 px-24">
                    <h6 class="fw-semibold mb-0">Recent Notifications</h6>
                </div>
                <div class="card-body p-24">
                    <div class="table-responsive">
                        <table class="table table-sm">
                            <thead>
                                <tr>
                                    <th>Title</th>
                                    <th>Target</th>
                                    <th>Sent</th>
                                </tr>
                            </thead>
                            <tbody>
                                <?php if ($notifications->num_rows > 0): ?>
                                    <?php while ($notification = $notifications->fetch_assoc()): ?>
                                        <tr>
                                            <td>
                                                <div class="fw-medium"><?php echo htmlspecialchars($notification['title']); ?></div>
                                                <small class="text-muted"><?php echo htmlspecialchars(substr($notification['message'], 0, 50)); ?>...</small>
                                            </td>
                                            <td>
                                                <span class="badge bg-primary"><?php echo ucfirst($notification['target_users']); ?></span>
                                            </td>
                                            <td>
                                                <small><?php echo date('M j, H:i', strtotime($notification['created_at'])); ?></small>
                                            </td>
                                        </tr>
                                    <?php endwhile; ?>
                                <?php else: ?>
                                    <tr>
                                        <td colspan="3" class="text-center text-muted">No notifications sent yet</td>
                                    </tr>
                                <?php endif; ?>
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>
        </div>
    </div>
</div>

<?php include './partials/layouts/layoutBottom.php'; ?>