<?php
include './includes/db.php';
include './includes/admin-auth.php';
include './partials/layouts/layoutTop.php';

// Handle form submission
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $name = $_POST['name'] ?? '';
    $email = $_POST['email'] ?? '';
    $phone = $_POST['phone'] ?? '';
    $password = $_POST['password'] ?? '';
    $role = $_POST['role'] ?? 'User';
    $status = $_POST['status'] ?? 'Active';
    
    $errors = [];
    
    // Validation
    if (empty($name)) $errors[] = "Name is required";
    if (empty($email)) $errors[] = "Email is required";
    if (empty($password)) $errors[] = "Password is required";
    
    // Check if email already exists
    $checkStmt = $conn->prepare("SELECT id FROM users WHERE email = ?");
    $checkStmt->bind_param("s", $email);
    $checkStmt->execute();
    $checkStmt->store_result();
    
    if ($checkStmt->num_rows > 0) {
        $errors[] = "Email already exists";
    }
    $checkStmt->close();
    
    // Handle image upload
    $profile_photo = 'assets/images/default-avatar.png';
    
    if (isset($_FILES['profile_photo']) && $_FILES['profile_photo']['error'] === UPLOAD_ERR_OK) {
        $uploadDir = 'assets/images/';
        
        // Create directory if it doesn't exist
        if (!is_dir($uploadDir)) {
            mkdir($uploadDir, 0755, true);
        }
        
        $fileName = $_FILES['profile_photo']['name'];
        $fileTmpName = $_FILES['profile_photo']['tmp_name'];
        $fileSize = $_FILES['profile_photo']['size'];
        $fileError = $_FILES['profile_photo']['error'];
        
        $fileExt = strtolower(pathinfo($fileName, PATHINFO_EXTENSION));
        $allowed = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
        
        if (in_array($fileExt, $allowed)) {
            if ($fileError === 0) {
                if ($fileSize <= 5000000) {
                    $newFileName = 'user_' . uniqid() . '_' . time() . '.' . $fileExt;
                    $fileDestination = $uploadDir . $newFileName;
                    
                    if (move_uploaded_file($fileTmpName, $fileDestination)) {
                        $profile_photo = $fileDestination;
                    } else {
                        $errors[] = "Failed to upload image file";
                    }
                } else {
                    $errors[] = "File size too large. Maximum 5MB allowed";
                }
            } else {
                $errors[] = "File upload error: " . $fileError;
            }
        } else {
            $errors[] = "Invalid file type. Allowed: JPG, JPEG, PNG, GIF, WEBP";
        }
    }
    
    // If no errors, insert user
    if (empty($errors)) {
        $password_hash = md5($password);
        $join_date = date('Y-m-d H:i:s');
        
        $stmt = $conn->prepare("INSERT INTO users (name, email, phone, password_hash, role, status, join_date, profile_photo) VALUES (?, ?, ?, ?, ?, ?, ?, ?)");
        $stmt->bind_param("ssssssss", $name, $email, $phone, $password_hash, $role, $status, $join_date, $profile_photo);
        
        if ($stmt->execute()) {
            $success = "User added successfully!";
            if ($profile_photo !== 'assets/images/default-avatar.png') {
                $success .= " Profile image uploaded successfully!";
            }
            
            // Clear form
            $_POST = array();
        } else {
            $errors[] = "Failed to add user: " . $stmt->error;
        }
        $stmt->close();
    }
}

$preview_image = 'assets/images/default-avatar.png';
?>

<div class="dashboard-main-body">
    <div class="d-flex flex-wrap align-items-center justify-content-between gap-3 mb-24">
        <h6 class="fw-semibold mb-0">Add User</h6>
        <ul class="d-flex align-items-center gap-2">
            <li class="fw-medium">
                <a href="index.php" class="d-flex align-items-center gap-1 hover-text-primary">
                    <iconify-icon icon="solar:home-smile-angle-outline" class="icon text-lg"></iconify-icon>
                    Dashboard
                </a>
            </li>
            <li>-</li>
            <li class="fw-medium">Add User</li>
        </ul>
    </div>

    <!-- Display Messages -->
    <?php if (!empty($errors)): ?>
        <div class="alert alert-danger">
            <h6>Please fix the following errors:</h6>
            <ul class="mb-0">
                <?php foreach ($errors as $error): ?>
                    <li><?php echo htmlspecialchars($error); ?></li>
                <?php endforeach; ?>
            </ul>
        </div>
    <?php endif; ?>
    
    <?php if (isset($success)): ?>
        <div class="alert alert-success">
            <?php echo htmlspecialchars($success); ?>
        </div>
    <?php endif; ?>

    <div class="card h-100 p-0 radius-12">
        <div class="card-body p-24">
            <div class="row justify-content-center">
                <div class="col-xxl-6 col-xl-8 col-lg-10">
                    <div class="card border">
                        <div class="card-body">
                            <form method="POST" enctype="multipart/form-data" id="userForm">
                                <h6 class="text-md text-primary-light mb-16">Profile Image</h6>

                                <!-- Upload Image Start -->
                                <div class="mb-24 mt-16 text-center">
                                    <div class="avatar-upload d-inline-block position-relative">
                                        <div class="avatar-edit position-absolute bottom-0 end-0 me-0 mb-0 z-1 cursor-pointer">
                                            <input type='file' id="imageUpload" name="profile_photo" accept=".png, .jpg, .jpeg, .gif, .webp" style="position: absolute; opacity: 0; width: 32px; height: 32px; cursor: pointer;">
                                            <label for="imageUpload" class="w-32-px h-32-px d-flex justify-content-center align-items-center bg-primary-50 text-primary-600 border border-primary-600 bg-hover-primary-100 text-lg rounded-circle" style="cursor: pointer;">
                                                <iconify-icon icon="solar:camera-outline" class="icon"></iconify-icon>
                                            </label>
                                        </div>
                                        <div class="avatar-preview">
                                            <div id="imagePreview" style="background-image: url('<?php echo $preview_image; ?>'); 
                                                width: 120px; height: 120px; border-radius: 50%; background-size: cover; background-position: center; border: 2px solid #e9ecef; display: inline-block;">
                                            </div>
                                        </div>
                                    </div>
                                    <div id="fileInfo" class="text-center mt-2">
                                        <small class="text-muted">Click camera icon to upload image (Max: 5MB)</small>
                                    </div>
                                </div>
                                <!-- Upload Image End -->

                                <div class="mb-20">
                                    <label for="name" class="form-label fw-semibold text-primary-light text-sm mb-8">Full Name <span class="text-danger-600">*</span></label>
                                    <input type="text" class="form-control radius-8" id="name" name="name" placeholder="Enter Full Name" value="<?php echo htmlspecialchars($_POST['name'] ?? ''); ?>" required>
                                </div>
                                
                                <div class="mb-20">
                                    <label for="email" class="form-label fw-semibold text-primary-light text-sm mb-8">Email <span class="text-danger-600">*</span></label>
                                    <input type="email" class="form-control radius-8" id="email" name="email" placeholder="Enter email address" value="<?php echo htmlspecialchars($_POST['email'] ?? ''); ?>" required>
                                </div>
                                
                                <div class="mb-20">
                                    <label for="phone" class="form-label fw-semibold text-primary-light text-sm mb-8">Phone</label>
                                    <input type="tel" class="form-control radius-8" id="phone" name="phone" placeholder="Enter phone number" value="<?php echo htmlspecialchars($_POST['phone'] ?? ''); ?>">
                                </div>
                                
                                <div class="mb-20">
                                    <label for="password" class="form-label fw-semibold text-primary-light text-sm mb-8">Password <span class="text-danger-600">*</span></label>
                                    <div class="position-relative">
                                        <input type="password" class="form-control radius-8" id="password" name="password" placeholder="Enter password" required style="padding-right: 2.75rem;">
                                        <button type="button" class="border-0 bg-transparent position-absolute top-50 end-0 translate-middle-y me-12 text-secondary-light add-user-pw-toggle" data-target="#password" aria-label="Show password" style="line-height:0;">
                                            <i class="ri-eye-line text-lg"></i>
                                        </button>
                                    </div>
                                </div>
                                
                                <div class="mb-20">
                                    <label for="role" class="form-label fw-semibold text-primary-light text-sm mb-8">Role <span class="text-danger-600">*</span></label>
                                    <select class="form-control radius-8 form-select" id="role" name="role" required>
                                        <option value="User" <?php echo ($_POST['role'] ?? '') === 'User' ? 'selected' : ''; ?>>User</option>
                                        <option value="Blogger" <?php echo ($_POST['role'] ?? '') === 'Blogger' ? 'selected' : ''; ?>>Blogger</option>
                                    </select>
                                </div>
                                
                                <div class="mb-20">
                                    <label for="status" class="form-label fw-semibold text-primary-light text-sm mb-8">Status <span class="text-danger-600">*</span></label>
                                    <select class="form-control radius-8 form-select" id="status" name="status" required>
                                        <option value="Active" <?php echo ($_POST['status'] ?? '') === 'Active' ? 'selected' : ''; ?>>Active</option>
                                        <option value="Inactive" <?php echo ($_POST['status'] ?? '') === 'Inactive' ? 'selected' : ''; ?>>Inactive</option>
                                    </select>
                                </div>
                                
                                <div class="d-flex align-items-center justify-content-center gap-3">
                                    <a href="users-grid.php" class="border border-danger-600 bg-hover-danger-200 text-danger-600 text-md px-56 py-11 radius-8 text-decoration-none">
                                        Cancel
                                    </a>
                                    <button type="submit" class="btn btn-primary border border-primary-600 text-md px-56 py-12 radius-8">
                                        Save User
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

<script>
function readURL(input) {
    if (input.files && input.files[0]) {
        var reader = new FileReader();
        reader.onload = function(e) {
            $("#imagePreview").css("background-image", "url(" + e.target.result + ")");
            $("#fileInfo").html('<small class="text-success">✓ Selected: ' + input.files[0].name + ' (' + Math.round(input.files[0].size/1024) + ' KB)</small>');
            $("#imagePreview").hide();
            $("#imagePreview").fadeIn(650);
        }
        reader.readAsDataURL(input.files[0]);
    }
}

$(document).ready(function() {
    $("#imageUpload").change(function() {
        readURL(this);
    });
    $(".add-user-pw-toggle").on("click", function () {
        var sel = $(this).data("target");
        var $inp = $(sel);
        var show = $inp.attr("type") === "password";
        $inp.attr("type", show ? "text" : "password");
        $(this).attr("aria-label", show ? "Hide password" : "Show password");
        $(this).find("i").attr("class", show ? "ri-eye-off-line text-lg" : "ri-eye-line text-lg");
    });
});
</script>