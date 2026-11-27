<?php
session_start();
require_once 'includes/db.php';
require_once 'includes/admin-auth.php';
include './partials/layouts/layoutTop.php';

// Get current admin data
$admin_id = $_SESSION['admin_id'];
$sql = "SELECT * FROM admin_users WHERE id = ?";
$stmt = $conn->prepare($sql);
$stmt->bind_param("i", $admin_id);
$stmt->execute();
$result = $stmt->get_result();
$admin = $result->fetch_assoc();

if (!$admin) {
    die("Admin not found");
}

$success = '';
$error = '';

// Handle profile update
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['update_profile'])) {
    $name = trim($_POST['name']);
    $email = trim($_POST['email']);
    
    if (empty($name) || empty($email)) {
        $error = "Name and email are required";
    } else {
        // Check if email already exists (excluding current admin)
        $check_sql = "SELECT id FROM admin_users WHERE email = ? AND id != ?";
        $check_stmt = $conn->prepare($check_sql);
        $check_stmt->bind_param("si", $email, $admin_id);
        $check_stmt->execute();
        $check_result = $check_stmt->get_result();
        
        if ($check_result->num_rows > 0) {
            $error = "Email already exists";
        } else {
            $update_sql = "UPDATE admin_users SET name = ?, email = ? WHERE id = ?";
            $update_stmt = $conn->prepare($update_sql);
            $update_stmt->bind_param("ssi", $name, $email, $admin_id);
            
            if ($update_stmt->execute()) {
                $success = "Profile updated successfully";
                // Update session
                $_SESSION['admin_name'] = $name;
                $_SESSION['admin_email'] = $email;
                // Refresh admin data
                $admin['name'] = $name;
                $admin['email'] = $email;
            } else {
                $error = "Error updating profile";
            }
        }
    }
}

// Handle password change
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['change_password'])) {
    $current_password = $_POST['current_password'];
    $new_password = $_POST['new_password'];
    $confirm_password = $_POST['confirm_password'];
    
    if (empty($current_password) || empty($new_password) || empty($confirm_password)) {
        $error = "All password fields are required";
    } elseif ($new_password !== $confirm_password) {
        $error = "New passwords do not match";
    } elseif (strlen($new_password) < 6) {
        $error = "Password must be at least 6 characters";
    } else {
        // Verify current password
        if (md5($current_password) === $admin['password_hash']) {
            $new_password_hash = md5($new_password);
            $update_sql = "UPDATE admin_users SET password_hash = ? WHERE id = ?";
            $update_stmt = $conn->prepare($update_sql);
            $update_stmt->bind_param("si", $new_password_hash, $admin_id);
            
            if ($update_stmt->execute()) {
                $success = "Password changed successfully";
            } else {
                $error = "Error changing password";
            }
        } else {
            $error = "Current password is incorrect";
        }
    }
}
?>

<div class="dashboard-main-body">
    <div class="d-flex flex-wrap align-items-center justify-content-between gap-3 mb-24">
        <h6 class="fw-semibold mb-0">Admin Profile</h6>
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
        <div class="col-lg-4">
            <div class="card h-100">
                <div class="card-body text-center">
                    <div class="avatar-initial mb-3 mx-auto" style="width: 80px; height: 80px; background: linear-gradient(135deg, #e74c3c 0%, #f39c12 100%); color: white; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-weight: 600; font-size: 32px;">
                        <?php echo strtoupper(substr($admin['name'], 0, 1)); ?>
                    </div>
                    <h5><?php echo htmlspecialchars($admin['name']); ?></h5>
                    <p class="text-muted">Administrator</p>
                    <div class="text-start mt-4">
                        <p><strong>Email:</strong> <?php echo htmlspecialchars($admin['email']); ?></p>
                        <p><strong>Status:</strong> <span class="badge bg-success"><?php echo $admin['status']; ?></span></p>
                        <p><strong>Last Login:</strong> <?php echo $admin['last_login'] ? date('M j, Y g:i A', strtotime($admin['last_login'])) : 'Never'; ?></p>
                        <p><strong>Member Since:</strong> <?php echo date('M j, Y', strtotime($admin['created_at'])); ?></p>
                    </div>
                </div>
            </div>
        </div>
        
        <div class="col-lg-8">
            <!-- Profile Update Form -->
            <div class="card mb-4">
                <div class="card-header bg-white">
                    <h6 class="fw-semibold mb-0">Update Profile</h6>
                </div>
                <div class="card-body">
                    <form method="POST" action="">
                        <input type="hidden" name="update_profile" value="1">
                        <div class="row">
                            <div class="col-md-6">
                                <div class="mb-3">
                                    <label class="form-label">Full Name</label>
                                    <input type="text" class="form-control" name="name" 
                                           value="<?php echo htmlspecialchars($admin['name']); ?>" required>
                                </div>
                            </div>
                            <div class="col-md-6">
                                <div class="mb-3">
                                    <label class="form-label">Email Address</label>
                                    <input type="email" class="form-control" name="email" 
                                           value="<?php echo htmlspecialchars($admin['email']); ?>" required>
                                </div>
                            </div>
                        </div>
                        <button type="submit" class="btn btn-primary">Update Profile</button>
                    </form>
                </div>
            </div>

            <!-- Password Change Form -->
            <div class="card">
                <div class="card-header bg-white">
                    <h6 class="fw-semibold mb-0">Change Password</h6>
                </div>
                <div class="card-body">
                    <form method="POST" action="">
                        <input type="hidden" name="change_password" value="1">
                        <div class="mb-3">
                            <label class="form-label">Current Password</label>
                            <div class="position-relative">
                                <input type="password" class="form-control" id="admin_current_password" name="current_password" required style="padding-right: 2.75rem;">
                                <button type="button" class="border-0 bg-transparent position-absolute top-50 end-0 translate-middle-y me-2 text-secondary admin-pw-toggle" data-target="#admin_current_password" aria-label="Show password"><i class="ri-eye-line"></i></button>
                            </div>
                        </div>
                        <div class="mb-3">
                            <label class="form-label">New Password</label>
                            <div class="position-relative">
                                <input type="password" class="form-control" id="admin_new_password" name="new_password" required style="padding-right: 2.75rem;">
                                <button type="button" class="border-0 bg-transparent position-absolute top-50 end-0 translate-middle-y me-2 text-secondary admin-pw-toggle" data-target="#admin_new_password" aria-label="Show password"><i class="ri-eye-line"></i></button>
                            </div>
                        </div>
                        <div class="mb-3">
                            <label class="form-label">Confirm New Password</label>
                            <div class="position-relative">
                                <input type="password" class="form-control" id="admin_confirm_password" name="confirm_password" required style="padding-right: 2.75rem;">
                                <button type="button" class="border-0 bg-transparent position-absolute top-50 end-0 translate-middle-y me-2 text-secondary admin-pw-toggle" data-target="#admin_confirm_password" aria-label="Show password"><i class="ri-eye-line"></i></button>
                            </div>
                        </div>
                        <button type="submit" class="btn btn-primary">Change Password</button>
                    </form>
                </div>
            </div>
        </div>
    </div>
</div>

<script>
document.querySelectorAll('.admin-pw-toggle').forEach(function (btn) {
    btn.addEventListener('click', function () {
        var sel = btn.getAttribute('data-target');
        var input = document.querySelector(sel);
        if (!input) return;
        var show = input.type === 'password';
        input.type = show ? 'text' : 'password';
        btn.setAttribute('aria-label', show ? 'Hide password' : 'Show password');
        var icon = btn.querySelector('i');
        if (icon) icon.className = show ? 'ri-eye-off-line' : 'ri-eye-line';
    });
});
</script>

<?php include './partials/layouts/layoutBottom.php'; ?>