<?php
include './includes/db.php';
include './includes/admin-auth.php';
include './partials/layouts/layoutTop.php';

$success = $error = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $name = $conn->real_escape_string($_POST['name']);
    $description = $conn->real_escape_string($_POST['description']);
    $category = $conn->real_escape_string($_POST['category']);
    $created_by = $_SESSION['admin_id'] ?? 1; // Admin user ID
    
    // Check if group with the same name already exists
    $check_sql = "SELECT id FROM `groups` WHERE name = '$name'";
    $check_result = $conn->query($check_sql);
    
    if ($check_result->num_rows > 0) {
        $error = "A group with this name already exists. Please choose a different name.";
    } else {
        // Handle file upload
        $group_image = null;
        if (isset($_FILES['group_image']) && $_FILES['group_image']['error'] === UPLOAD_ERR_OK) {
            $upload_dir = 'uploads/groups/';
            
            // Create directory if it doesn't exist
            if (!is_dir($upload_dir)) {
                mkdir($upload_dir, 0755, true);
            }
            
            $file_name = $_FILES['group_image']['name'];
            $file_tmp = $_FILES['group_image']['tmp_name'];
            $file_size = $_FILES['group_image']['size'];
            $file_error = $_FILES['group_image']['error'];
            
            // Get file extension
            $file_ext = strtolower(pathinfo($file_name, PATHINFO_EXTENSION));
            
            // Allowed extensions
            $allowed_ext = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
            
            // Check if extension is allowed
            if (in_array($file_ext, $allowed_ext)) {
                // Check file size (max 5MB)
                if ($file_size <= 5 * 1024 * 1024) {
                    // Generate unique file name
                    $new_file_name = 'group_' . time() . '_' . uniqid() . '.' . $file_ext;
                    $upload_path = $upload_dir . $new_file_name;
                    
                    // Move uploaded file
                    if (move_uploaded_file($file_tmp, $upload_path)) {
                        $group_image = $upload_path;
                    } else {
                        $error = "Failed to upload image. Please try again.";
                    }
                } else {
                    $error = "File size too large. Maximum size is 5MB.";
                }
            } else {
                $error = "Invalid file type. Allowed types: JPG, JPEG, PNG, GIF, WEBP.";
            }
        }
        
        if (!$error) {
            if ($group_image) {
                $sql = "INSERT INTO `groups` (name, description, category, group_image, created_by) 
                        VALUES ('$name', '$description', '$category', '$group_image', $created_by)";
            } else {
                $sql = "INSERT INTO `groups` (name, description, category, created_by) 
                        VALUES ('$name', '$description', '$category', $created_by)";
            }
            
            if ($conn->query($sql)) {
                $group_id = $conn->insert_id;
                
                // Add creator as admin member of the group
                $member_sql = "INSERT INTO group_members (group_id, user_id, role) VALUES ($group_id, $created_by, 'Admin')";
                $conn->query($member_sql);
                
                $success = "Group created successfully!";
                
                // Clear POST data to prevent resubmission
                $_POST = array();
            } else {
                $error = "Error: " . $conn->error;
            }
        }
    }
}
?>
<div class="dashboard-main-body">
    <div class="d-flex flex-wrap align-items-center justify-content-between gap-3 mb-24">
        <h6 class="fw-semibold mb-0">Create Group</h6>
        <ul class="d-flex align-items-center gap-2">
            <li class="fw-medium">
                <a href="groups-list.php" class="d-flex align-items-center gap-1 hover-text-primary">
                    <iconify-icon icon="solar:home-smile-angle-outline" class="icon text-lg"></iconify-icon>
                    Groups
                </a>
            </li>
            <li>-</li>
            <li class="fw-medium">Create Group</li>
        </ul>
    </div>

    <!-- Error Alert - Only shows when there's an actual error -->
    <?php if (isset($error) && !empty($error)): ?>
        <div class="alert alert-danger d-flex align-items-center gap-2">
            <iconify-icon icon="mdi:alert-circle" class="icon-lg"></iconify-icon>
            <?php echo $error; ?>
        </div>
    <?php endif; ?>
    
    <!-- Success Alert - Only shows when there's success -->
    <?php if (isset($success) && !empty($success)): ?>
        <div class="alert alert-success d-flex align-items-center gap-2">
            <iconify-icon icon="mdi:check-circle" class="icon-lg"></iconify-icon>
            <?php echo $success; ?>
        </div>
    <?php endif; ?>

    <div class="card h-100 p-0 radius-12">
        <div class="card-header border-bottom bg-base py-16 px-24">
            <h6 class="mb-0 fw-semibold">Group Information</h6>
            <p class="text-muted mb-0">Create a new group for your community</p>
        </div>
        
        <div class="card-body p-24">
            <div class="row justify-content-center">
                <div class="col-xxl-6 col-xl-8 col-lg-10">
                    <div class="card border-0 shadow-sm">
                        <div class="card-body p-30">
                            <form method="POST" enctype="multipart/form-data" id="groupForm">
                                <!-- Group Image Upload -->
                                <div class="mb-24">
                                    <label class="form-label fw-semibold text-primary-light text-sm mb-12">Group Image</label>
                                    <div class="image-upload-container">
                                        <div class="image-preview mb-3 text-center">
                                            <div class="preview-placeholder bg-light rounded-12 p-20 border-dashed">
                                                <iconify-icon icon="mdi:image-plus" class="icon-3x text-muted mb-2"></iconify-icon>
                                                <p class="text-muted mb-2">Click to upload group image</p>
                                                <small class="text-muted">JPG, PNG, GIF, WEBP (Max 5MB)</small>
                                            </div>
                                            <img id="previewImage" class="preview-image rounded-12 d-none" style="max-height: 200px;">
                                        </div>
                                        <input type="file" class="form-control d-none" id="group_image" name="group_image" accept="image/*">
                                        <button type="button" class="btn btn-outline-primary w-100" onclick="document.getElementById('group_image').click()">
                                            <iconify-icon icon="mdi:upload" class="me-2"></iconify-icon>
                                            Choose Image
                                        </button>
                                        <div class="form-text text-center mt-2">
                                            Recommended size: 500x500 pixels
                                        </div>
                                    </div>
                                </div>

                                <!-- Group Name -->
                                <div class="mb-20">
                                    <label class="form-label fw-semibold text-primary-light text-sm mb-8">
                                        Group Name <span class="text-danger">*</span>
                                    </label>
                                    <div class="input-group">
                                        <span class="input-group-text bg-light border-end-0">
                                            <iconify-icon icon="mdi:account-group" class="text-muted"></iconify-icon>
                                        </span>
                                        <input type="text" class="form-control radius-8 border-start-0" name="name" placeholder="Enter group name" value="<?php echo isset($_POST['name']) ? htmlspecialchars($_POST['name']) : ''; ?>" required>
                                    </div>
                                    <div class="form-text" id="groupNameStatus"></div>
                                </div>
                                
                                <!-- Category -->
                                <div class="mb-20">
                                    <label class="form-label fw-semibold text-primary-light text-sm mb-8">
                                        Category 
                                        <!--<span class="text-danger">*</span>-->
                                    </label>
                                    <div class="input-group">
                                        <span class="input-group-text bg-light border-end-0">
                                            <iconify-icon icon="mdi:tag-outline" class="text-muted"></iconify-icon>
                                        </span>
                                        <select class="form-control radius-8 border-start-0 form-select" name="category">
                                            <option value="">Select a category</option>
                                            <option value="Love" <?php echo (isset($_POST['category']) && $_POST['category'] == 'Love') ? 'selected' : ''; ?>>Love</option>
                                            <option value="Joy" <?php echo (isset($_POST['category']) && $_POST['category'] == 'Joy') ? 'selected' : ''; ?>>Joy</option>
                                            <option value="Peace" <?php echo (isset($_POST['category']) && $_POST['category'] == 'Peace') ? 'selected' : ''; ?>>Peace</option>
                                            <option value="Patience" <?php echo (isset($_POST['category']) && $_POST['category'] == 'Patience') ? 'selected' : ''; ?>>Patience</option>
                                            <option value="Kindness" <?php echo (isset($_POST['category']) && $_POST['category'] == 'Kindness') ? 'selected' : ''; ?>>Kindness</option>
                                            <option value="Goodness" <?php echo (isset($_POST['category']) && $_POST['category'] == 'Goodness') ? 'selected' : ''; ?>>Goodness</option>
                                            <option value="Faithfulness" <?php echo (isset($_POST['category']) && $_POST['category'] == 'Faithfulness') ? 'selected' : ''; ?>>Faithfulness</option>
                                            <option value="Gentleness" <?php echo (isset($_POST['category']) && $_POST['category'] == 'Gentleness') ? 'selected' : ''; ?>>Gentleness</option>
                                            <option value="Self-Control" <?php echo (isset($_POST['category']) && $_POST['category'] == 'Self-Control') ? 'selected' : ''; ?>>Self-Control</option>
                                            <option value="Praise Report" <?php echo (isset($_POST['category']) && $_POST['category'] == 'Praise Report') ? 'selected' : ''; ?>>Praise Report</option>
                                            <option value="Holidays" <?php echo (isset($_POST['category']) && $_POST['category'] == 'Holidays') ? 'selected' : ''; ?>>Holidays</option>
                                        </select>
                                    </div>
                                </div>
                                
                                <!-- Description -->
                                <div class="mb-24">
                                    <label class="form-label fw-semibold text-primary-light text-sm mb-8">
                                        Description <span class="text-danger">*</span>
                                    </label>
                                    <div class="input-group">
                                        <span class="input-group-text bg-light border-end-0 align-items-start pt-3">
                                            <iconify-icon icon="mdi:text-box-outline" class="text-muted"></iconify-icon>
                                        </span>
                                        <textarea class="form-control radius-8 border-start-0" name="description" rows="4" placeholder="Describe the purpose and focus of this group..." required><?php echo isset($_POST['description']) ? htmlspecialchars($_POST['description']) : ''; ?></textarea>
                                    </div>
                                    <div class="form-text">
                                        Let members know what this group is about and what they can expect.
                                    </div>
                                </div>
                                
                                <!-- Buttons -->
                                <div class="d-flex align-items-center justify-content-center gap-3 pt-4">
                                    <a href="groups-list.php" class="btn btn-outline-danger px-56 py-12 radius-8 d-flex align-items-center gap-2">
                                        <iconify-icon icon="mdi:close"></iconify-icon>
                                        Cancel
                                    </a>
                                    <button type="submit" class="btn btn-primary px-56 py-12 radius-8 d-flex align-items-center gap-2" id="submitBtn">
                                        <iconify-icon icon="mdi:check"></iconify-icon>
                                        Create Group
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

<?php include './partials/layouts/layoutBottom.php'; ?>

<script>
document.addEventListener('DOMContentLoaded', function() {
    const fileInput = document.getElementById('group_image');
    const previewImage = document.getElementById('previewImage');
    const previewPlaceholder = document.querySelector('.preview-placeholder');
    const groupNameInput = document.querySelector('input[name="name"]');
    const groupNameStatus = document.getElementById('groupNameStatus');
    const form = document.getElementById('groupForm');
    const submitBtn = document.getElementById('submitBtn');
    
    let isCheckingName = false;
    let nameCheckTimeout;
    
    // Real-time group name availability check
    groupNameInput.addEventListener('input', function() {
        clearTimeout(nameCheckTimeout);
        const groupName = this.value.trim();
        
        if (groupName.length < 3) {
            groupNameStatus.innerHTML = '<span class="text-warning">Group name must be at least 3 characters long</span>';
            return;
        }
        
        nameCheckTimeout = setTimeout(function() {
            checkGroupNameAvailability(groupName);
        }, 500);
    });
    
    function checkGroupNameAvailability(name) {
        if (isCheckingName) return;
        
        isCheckingName = true;
        groupNameStatus.innerHTML = '<span class="text-info">Checking availability...</span>';
        
        // Create AJAX request to check if group name exists
        const xhr = new XMLHttpRequest();
        xhr.open('POST', 'check-group-name.php', true);
        xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
        
        xhr.onload = function() {
            isCheckingName = false;
            if (this.status === 200) {
                const response = JSON.parse(this.responseText);
                if (response.exists) {
                    groupNameStatus.innerHTML = '<span class="text-danger">❌ This group name is already taken</span>';
                    submitBtn.disabled = true;
                } else {
                    groupNameStatus.innerHTML = '<span class="text-success">✓ Group name is available</span>';
                    submitBtn.disabled = false;
                }
            }
        };
        
        xhr.send('name=' + encodeURIComponent(name));
    }
    
    fileInput.addEventListener('change', function() {
        const file = this.files[0];
        
        if (file) {
            // Check file size (5MB max)
            if (file.size > 5 * 1024 * 1024) {
                showAlert('File size too large. Maximum size is 5MB.', 'error');
                this.value = '';
                return;
            }
            
            // Check file type
            const validTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp'];
            if (!validTypes.includes(file.type)) {
                showAlert('Invalid file type. Please select an image file (JPG, PNG, GIF, WEBP).', 'error');
                this.value = '';
                return;
            }
            
            const reader = new FileReader();
            
            reader.addEventListener('load', function() {
                previewImage.src = reader.result;
                previewImage.classList.remove('d-none');
                previewPlaceholder.classList.add('d-none');
            });
            
            reader.readAsDataURL(file);
        } else {
            previewImage.classList.add('d-none');
            previewPlaceholder.classList.remove('d-none');
        }
    });
    
    // Allow clicking on preview to trigger file input
    document.getElementById('imagePreview').addEventListener('click', function() {
        fileInput.click();
    });
});

// Form validation
document.querySelector('form').addEventListener('submit', function(e) {
    const name = document.querySelector('input[name="name"]').value.trim();
    const category = document.querySelector('select[name="category"]').value;
    const description = document.querySelector('textarea[name="description"]').value.trim();
    const statusMessage = document.getElementById('groupNameStatus').innerHTML;
    
    if (!name) {
        e.preventDefault();
        showAlert('Please enter a group name.', 'error');
        return;
    }
    
    if (name.length < 3) {
        e.preventDefault();
        showAlert('Group name must be at least 3 characters long.', 'error');
        return;
    }
    
    // if (!category) {
    //     e.preventDefault();
    //     showAlert('Please select a category.', 'error');
    //     return;
    // }
    
    if (!description) {
        e.preventDefault();
        showAlert('Please enter a group description.', 'error');
        return;
    }
    
    if (description.length < 10) {
        e.preventDefault();
        showAlert('Description must be at least 10 characters long.', 'error');
        return;
    }
    
    // Check if group name is taken (based on the status message)
    if (statusMessage.includes('already taken')) {
        e.preventDefault();
        showAlert('This group name is already taken. Please choose a different name.', 'error');
        return;
    }
});

function showAlert(message, type = 'info') {
    const alert = document.createElement('div');
    alert.className = `alert alert-${type === 'error' ? 'danger' : type} alert-dismissible fade show position-fixed`;
    alert.style.cssText = 'top: 20px; right: 20px; z-index: 9999; min-width: 300px;';
    alert.innerHTML = `
        <div class="d-flex align-items-center gap-2">
            <iconify-icon icon="mdi:${type === 'error' ? 'alert-circle' : 'information'}"></iconify-icon>
            ${message}
        </div>
        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    `;
    document.body.appendChild(alert);
    
    setTimeout(() => {
        if (alert.parentNode) {
            alert.remove();
        }
    }, 5000);
}
</script>

<style>
.image-upload-container {
    border: 2px dashed #dee2e6;
    border-radius: 12px;
    padding: 20px;
    transition: all 0.3s ease;
    background: #fafafa;
}

.image-upload-container:hover {
    border-color: #007bff;
    background: #f8f9fa;
}

.image-upload-container.dragover {
    border-color: #007bff;
    background: #e7f3ff;
}

.preview-placeholder {
    cursor: pointer;
    transition: all 0.3s ease;
}

.preview-placeholder:hover {
    background: #e9ecef;
}

.preview-image {
    max-width: 100%;
    height: auto;
    cursor: pointer;
    transition: transform 0.3s ease;
}

.preview-image:hover {
    transform: scale(1.02);
}

.border-dashed {
    border: 2px dashed #dee2e6 !important;
}

.input-group-text {
    background-color: #f8f9fa !important;
    border-color: #dee2e6 !important;
}

.form-control:focus {
    border-color: #007bff;
    box-shadow: 0 0 0 0.2rem rgba(0, 123, 255, 0.1);
}

.card {
    transition: transform 0.2s ease, box-shadow 0.2s ease;
}

.card:hover {
    transform: translateY(-2px);
    box-shadow: 0 0.5rem 1rem rgba(0, 0, 0, 0.1) !important;
}

.icon-3x {
    font-size: 3rem;
}

.icon-lg {
    font-size: 1.25rem;
}

#groupNameStatus {
    min-height: 24px;
    font-size: 0.875rem;
}

.text-success {
    color: #28a745 !important;
}

.text-danger {
    color: #dc3545 !important;
}

.text-warning {
    color: #ffc107 !important;
}

.text-info {
    color: #17a2b8 !important;
}

/* Responsive adjustments */
@media (max-width: 768px) {
    .d-flex.justify-content-center.gap-3 {
        flex-direction: column;
    }
    
    .btn {
        width: 100%;
        justify-content: center;
    }
}
</style>