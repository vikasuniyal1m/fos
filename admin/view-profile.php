<?php
session_start();
require_once 'includes/db.php';

// Check if user is logged in
if (!isset($_SESSION['user_id'])) {
    header("Location: login.php");
    exit;
}

$user_id = $_SESSION['user_id'];

// Fetch user data
$sql = "SELECT * FROM users WHERE id = ?";
$stmt = $conn->prepare($sql);
$stmt->bind_param("i", $user_id);
$stmt->execute();
$result = $stmt->get_result();
$user = $result->fetch_assoc();

if (!$user) {
    die("User not found");
}

// Fetch user's fruits
$fruits_sql = "SELECT f.name 
               FROM user_fruits uf 
               JOIN fruits f ON uf.fruit_id = f.id 
               WHERE uf.user_id = ?";
$fruits_stmt = $conn->prepare($fruits_sql);
$fruits_stmt->bind_param("i", $user_id);
$fruits_stmt->execute();
$fruits_result = $fruits_stmt->get_result();
$user_fruits = [];
while ($fruit = $fruits_result->fetch_assoc()) {
    $user_fruits[] = $fruit['name'];
}

$script = '<script>
    // ======================== Upload Image Start =====================
    function readURL(input) {
        if (input.files && input.files[0]) {
            var reader = new FileReader();
            reader.onload = function(e) {
                $("#imagePreview").css("background-image", "url(" + e.target.result + ")");
                $("#imagePreview").hide();
                $("#imagePreview").fadeIn(650);
            }
            reader.readAsDataURL(input.files[0]);
        }
    }
    $("#imageUpload").change(function() {
        readURL(this);
    });
    // ======================== Upload Image End =====================

    // ================== Password Show Hide Js Start ==========
    function initializePasswordToggle(toggleSelector) {
        $(toggleSelector).on("click", function() {
            $(this).toggleClass("ri-eye-off-line");
            var input = $($(this).attr("data-toggle"));
            if (input.attr("type") === "password") {
                input.attr("type", "text");
            } else {
                input.attr("type", "password");
            }
        });
    }
    // Call the function
    initializePasswordToggle(".toggle-password");
    // ========================= Password Show Hide Js End ===========================

    // Handle profile update form submission
    $("#profileForm").on("submit", function(e) {
        e.preventDefault();
        var formData = new FormData(this);
        
        $.ajax({
            url: "update-profile.php",
            type: "POST",
            data: formData,
            processData: false,
            contentType: false,
            success: function(response) {
                var result = JSON.parse(response);
                if (result.success) {
                    alert("Profile updated successfully!");
                    location.reload();
                } else {
                    alert("Error: " + result.message);
                }
            }
        });
    });

    // Handle password change form submission
    $("#passwordForm").on("submit", function(e) {
        e.preventDefault();
        var formData = $(this).serialize();
        
        $.ajax({
            url: "change-password.php",
            type: "POST",
            data: formData,
            success: function(response) {
                var result = JSON.parse(response);
                if (result.success) {
                    alert("Password changed successfully!");
                    $("#passwordForm")[0].reset();
                } else {
                    alert("Error: " + result.message);
                }
            }
        });
    });
</script>';
?>

<?php include './partials/layouts/layoutTop.php' ?>

<div class="dashboard-main-body">
    <div class="d-flex flex-wrap align-items-center justify-content-between gap-3 mb-24">
        <h6 class="fw-semibold mb-0">View Profile</h6>
        <ul class="d-flex align-items-center gap-2">
            <li class="fw-medium">
                <a href="index.php" class="d-flex align-items-center gap-1 hover-text-primary">
                    <iconify-icon icon="solar:home-smile-angle-outline" class="icon text-lg"></iconify-icon>
                    Dashboard
                </a>
            </li>
            <li>-</li>
            <li class="fw-medium">View Profile</li>
        </ul>
    </div>

    <div class="row gy-4">
        <div class="col-lg-4">
            <div class="user-grid-card position-relative border radius-16 overflow-hidden bg-base h-100">
                <img src="assets/images/user-grid/user-grid-bg1.png" alt="" class="w-100 object-fit-cover">
                <div class="pb-24 ms-16 mb-24 me-16 mt--100">
                    <div class="text-center border border-top-0 border-start-0 border-end-0">
                        <img src="<?php echo htmlspecialchars($user['profile_photo'] ?: 'assets/images/user.png'); ?>" 
                             alt="<?php echo htmlspecialchars($user['name']); ?>" 
                             class="border br-white border-width-2-px w-200-px h-200-px rounded-circle object-fit-cover">
                        <h6 class="mb-0 mt-16"><?php echo htmlspecialchars($user['name']); ?></h6>
                        <span class="text-secondary-light mb-16"><?php echo htmlspecialchars($user['email']); ?></span>
                        <?php if (!empty($user_fruits)): ?>
                            <div class="mt-2">
                                <small class="text-primary">Fruits: <?php echo htmlspecialchars(implode(', ', $user_fruits)); ?></small>
                            </div>
                        <?php endif; ?>
                    </div>
                    <div class="mt-24">
                        <h6 class="text-xl mb-16">Personal Info</h6>
                        <ul>
                            <li class="d-flex align-items-center gap-1 mb-12">
                                <span class="w-30 text-md fw-semibold text-primary-light">Full Name</span>
                                <span class="w-70 text-secondary-light fw-medium">: <?php echo htmlspecialchars($user['name']); ?></span>
                            </li>
                            <li class="d-flex align-items-center gap-1 mb-12">
                                <span class="w-30 text-md fw-semibold text-primary-light">Email</span>
                                <span class="w-70 text-secondary-light fw-medium">: <?php echo htmlspecialchars($user['email']); ?></span>
                            </li>
                            <li class="d-flex align-items-center gap-1 mb-12">
                                <span class="w-30 text-md fw-semibold text-primary-light">Phone Number</span>
                                <span class="w-70 text-secondary-light fw-medium">: <?php echo htmlspecialchars($user['phone'] ?: 'Not provided'); ?></span>
                            </li>
                            <li class="d-flex align-items-center gap-1 mb-12">
                                <span class="w-30 text-md fw-semibold text-primary-light">Role</span>
                                <span class="w-70 text-secondary-light fw-medium">: <?php echo htmlspecialchars($user['role']); ?></span>
                            </li>
                            <li class="d-flex align-items-center gap-1 mb-12">
                                <span class="w-30 text-md fw-semibold text-primary-light">Status</span>
                                <span class="w-70 text-secondary-light fw-medium">: <span class="badge bg-<?php echo $user['status'] == 'Active' ? 'success' : 'danger'; ?>"><?php echo htmlspecialchars($user['status']); ?></span></span>
                            </li>
                            <li class="d-flex align-items-center gap-1 mb-12">
                                <span class="w-30 text-md fw-semibold text-primary-light">Join Date</span>
                                <span class="w-70 text-secondary-light fw-medium">: <?php echo date('M j, Y', strtotime($user['join_date'])); ?></span>
                            </li>
                            <?php if (!empty($user_fruits)): ?>
                            <li class="d-flex align-items-center gap-1">
                                <span class="w-30 text-md fw-semibold text-primary-light">Fruits</span>
                                <span class="w-70 text-secondary-light fw-medium">: <?php echo htmlspecialchars(implode(', ', $user_fruits)); ?></span>
                            </li>
                            <?php endif; ?>
                        </ul>
                    </div>
                </div>
            </div>
        </div>
        <div class="col-lg-8">
            <div class="card h-100">
                <div class="card-body p-24">
                    <ul class="nav border-gradient-tab nav-pills mb-20 d-inline-flex" id="pills-tab" role="tablist">
                        <li class="nav-item" role="presentation">
                            <button class="nav-link d-flex align-items-center px-24 active" id="pills-edit-profile-tab" data-bs-toggle="pill" data-bs-target="#pills-edit-profile" type="button" role="tab" aria-controls="pills-edit-profile" aria-selected="true">
                                Edit Profile
                            </button>
                        </li>
                        <li class="nav-item" role="presentation">
                            <button class="nav-link d-flex align-items-center px-24" id="pills-change-passwork-tab" data-bs-toggle="pill" data-bs-target="#pills-change-passwork" type="button" role="tab" aria-controls="pills-change-passwork" aria-selected="false" tabindex="-1">
                                Change Password
                            </button>
                        </li>
                        <li class="nav-item" role="presentation">
                            <button class="nav-link d-flex align-items-center px-24" id="pills-notification-tab" data-bs-toggle="pill" data-bs-target="#pills-notification" type="button" role="tab" aria-controls="pills-notification" aria-selected="false" tabindex="-1">
                                Notification Settings
                            </button>
                        </li>
                    </ul>

                    <div class="tab-content" id="pills-tabContent">
                        <div class="tab-pane fade show active" id="pills-edit-profile" role="tabpanel" aria-labelledby="pills-edit-profile-tab" tabindex="0">
                            <h6 class="text-md text-primary-light mb-16">Profile Image</h6>
                            <!-- Upload Image Start -->
                            <div class="mb-24 mt-16">
                                <div class="avatar-upload">
                                    <div class="avatar-edit position-absolute bottom-0 end-0 me-24 mt-16 z-1 cursor-pointer">
                                        <input type='file' id="imageUpload" name="profile_photo" accept=".png, .jpg, .jpeg" hidden>
                                        <label for="imageUpload" class="w-32-px h-32-px d-flex justify-content-center align-items-center bg-primary-50 text-primary-600 border border-primary-600 bg-hover-primary-100 text-lg rounded-circle">
                                            <iconify-icon icon="solar:camera-outline" class="icon"></iconify-icon>
                                        </label>
                                    </div>
                                    <div class="avatar-preview">
                                        <div id="imagePreview" style="background-image: url('<?php echo htmlspecialchars($user['profile_photo'] ?: 'assets/images/user.png'); ?>');">
                                        </div>
                                    </div>
                                </div>
                            </div>
                            <!-- Upload Image End -->
                            <form id="profileForm" enctype="multipart/form-data">
                                <div class="row">
                                    <div class="col-sm-6">
                                        <div class="mb-20">
                                            <label for="name" class="form-label fw-semibold text-primary-light text-sm mb-8">Full Name <span class="text-danger-600">*</span></label>
                                            <input type="text" class="form-control radius-8" id="name" name="name" value="<?php echo htmlspecialchars($user['name']); ?>" placeholder="Enter Full Name" required>
                                        </div>
                                    </div>
                                    <div class="col-sm-6">
                                        <div class="mb-20">
                                            <label for="email" class="form-label fw-semibold text-primary-light text-sm mb-8">Email <span class="text-danger-600">*</span></label>
                                            <input type="email" class="form-control radius-8" id="email" name="email" value="<?php echo htmlspecialchars($user['email']); ?>" placeholder="Enter email address" required>
                                        </div>
                                    </div>
                                    <div class="col-sm-6">
                                        <div class="mb-20">
                                            <label for="phone" class="form-label fw-semibold text-primary-light text-sm mb-8">Phone</label>
                                            <input type="tel" class="form-control radius-8" id="phone" name="phone" value="<?php echo htmlspecialchars($user['phone'] ?: ''); ?>" placeholder="Enter phone number">
                                        </div>
                                    </div>
                                    <div class="col-sm-6">
                                        <div class="mb-20">
                                            <label for="fruit_category" class="form-label fw-semibold text-primary-light text-sm mb-8">Primary Fruit</label>
                                            <select class="form-control radius-8 form-select" id="fruit_category" name="fruit_category">
                                                <option value="">Select Fruit</option>
                                                <?php
                                                $fruits_sql = "SELECT * FROM fruits";
                                                $fruits_result = $conn->query($fruits_sql);
                                                while ($fruit = $fruits_result->fetch_assoc()) {
                                                    $selected = ($user['fruit_category'] == $fruit['name']) ? 'selected' : '';
                                                    echo "<option value='" . htmlspecialchars($fruit['name']) . "' $selected>" . htmlspecialchars($fruit['name']) . "</option>";
                                                }
                                                ?>
                                            </select>
                                        </div>
                                    </div>
                                </div>
                                <div class="d-flex align-items-center justify-content-center gap-3">
                                    <button type="button" class="border border-danger-600 bg-hover-danger-200 text-danger-600 text-md px-56 py-11 radius-8" onclick="location.reload()">
                                        Cancel
                                    </button>
                                    <button type="submit" class="btn btn-primary border border-primary-600 text-md px-56 py-12 radius-8">
                                        Save Changes
                                    </button>
                                </div>
                            </form>
                        </div>

                        <div class="tab-pane fade" id="pills-change-passwork" role="tabpanel" aria-labelledby="pills-change-passwork-tab" tabindex="0">
                            <form id="passwordForm">
                                <div class="mb-20">
                                    <label for="current_password" class="form-label fw-semibold text-primary-light text-sm mb-8">Current Password <span class="text-danger-600">*</span></label>
                                    <div class="position-relative">
                                        <input type="password" class="form-control radius-8" id="current_password" name="current_password" placeholder="Enter Current Password" required>
                                        <span class="toggle-password ri-eye-line cursor-pointer position-absolute end-0 top-50 translate-middle-y me-16 text-secondary-light" data-toggle="#current_password"></span>
                                    </div>
                                </div>
                                <div class="mb-20">
                                    <label for="new_password" class="form-label fw-semibold text-primary-light text-sm mb-8">New Password <span class="text-danger-600">*</span></label>
                                    <div class="position-relative">
                                        <input type="password" class="form-control radius-8" id="new_password" name="new_password" placeholder="Enter New Password" required>
                                        <span class="toggle-password ri-eye-line cursor-pointer position-absolute end-0 top-50 translate-middle-y me-16 text-secondary-light" data-toggle="#new_password"></span>
                                    </div>
                                </div>
                                <div class="mb-20">
                                    <label for="confirm_password" class="form-label fw-semibold text-primary-light text-sm mb-8">Confirm Password <span class="text-danger-600">*</span></label>
                                    <div class="position-relative">
                                        <input type="password" class="form-control radius-8" id="confirm_password" name="confirm_password" placeholder="Confirm Password" required>
                                        <span class="toggle-password ri-eye-line cursor-pointer position-absolute end-0 top-50 translate-middle-y me-16 text-secondary-light" data-toggle="#confirm_password"></span>
                                    </div>
                                </div>
                                <div class="d-flex align-items-center justify-content-center gap-3">
                                    <button type="submit" class="btn btn-primary border border-primary-600 text-md px-56 py-12 radius-8">
                                        Change Password
                                    </button>
                                </div>
                            </form>
                        </div>

                        <div class="tab-pane fade" id="pills-notification" role="tabpanel" aria-labelledby="pills-notification-tab" tabindex="0">
                            <?php
                            // Fetch notification settings
                            $settings_sql = "SELECT * FROM system_settings LIMIT 1";
                            $settings_result = $conn->query($settings_sql);
                            $settings = $settings_result->fetch_assoc();
                            ?>
                            <form id="notificationForm">
                                <div class="form-switch switch-primary py-12 px-16 border radius-8 position-relative mb-16">
                                    <label for="prayer_notifications" class="position-absolute w-100 h-100 start-0 top-0"></label>
                                    <div class="d-flex align-items-center gap-3 justify-content-between">
                                        <span class="form-check-label line-height-1 fw-medium text-secondary-light">Prayer Notifications</span>
                                        <input class="form-check-input" type="checkbox" role="switch" id="prayer_notifications" name="prayer_notifications" <?php echo $settings['prayer_notifications'] ? 'checked' : ''; ?>>
                                    </div>
                                </div>
                                <div class="form-switch switch-primary py-12 px-16 border radius-8 position-relative mb-16">
                                    <label for="blog_notifications" class="position-absolute w-100 h-100 start-0 top-0"></label>
                                    <div class="d-flex align-items-center gap-3 justify-content-between">
                                        <span class="form-check-label line-height-1 fw-medium text-secondary-light">Blog Notifications</span>
                                        <input class="form-check-input" type="checkbox" role="switch" id="blog_notifications" name="blog_notifications" <?php echo $settings['blog_notifications'] ? 'checked' : ''; ?>>
                                    </div>
                                </div>
                                <div class="form-switch switch-primary py-12 px-16 border radius-8 position-relative mb-16">
                                    <label for="comment_notifications" class="position-absolute w-100 h-100 start-0 top-0"></label>
                                    <div class="d-flex align-items-center gap-3 justify-content-between">
                                        <span class="form-check-label line-height-1 fw-medium text-secondary-light">Comment Notifications</span>
                                        <input class="form-check-input" type="checkbox" role="switch" id="comment_notifications" name="comment_notifications" <?php echo $settings['comment_notifications'] ? 'checked' : ''; ?>>
                                    </div>
                                </div>
                                <div class="form-switch switch-primary py-12 px-16 border radius-8 position-relative mb-16">
                                    <label for="email_notifications" class="position-absolute w-100 h-100 start-0 top-0"></label>
                                    <div class="d-flex align-items-center gap-3 justify-content-between">
                                        <span class="form-check-label line-height-1 fw-medium text-secondary-light">Email Notifications</span>
                                        <input class="form-check-input" type="checkbox" role="switch" id="email_notifications" name="email_notifications" <?php echo $settings['email_notifications'] ? 'checked' : ''; ?>>
                                    </div>
                                </div>
                                <div class="form-switch switch-primary py-12 px-16 border radius-8 position-relative mb-16">
                                    <label for="push_notifications" class="position-absolute w-100 h-100 start-0 top-0"></label>
                                    <div class="d-flex align-items-center gap-3 justify-content-between">
                                        <span class="form-check-label line-height-1 fw-medium text-secondary-light">Push Notifications</span>
                                        <input class="form-check-input" type="checkbox" role="switch" id="push_notifications" name="push_notifications" <?php echo $settings['push_notifications'] ? 'checked' : ''; ?>>
                                    </div>
                                </div>
                                <div class="d-flex align-items-center justify-content-center gap-3">
                                    <button type="submit" class="btn btn-primary border border-primary-600 text-md px-56 py-12 radius-8">
                                        Save Settings
                                    </button>
                                </div>
                            </form>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
</div>

<?php include './partials/layouts/layoutBottom.php' ?>