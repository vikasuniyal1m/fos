<?php
include './includes/db.php';
include './includes/admin-auth.php';
include './partials/layouts/layoutTop.php';

$group_id = intval($_GET['id'] ?? 0);

// Fetch group details
$group = null;
if($group_id) {
    $stmt = $conn->prepare("SELECT * FROM `groups` WHERE id = ?");
    $stmt->bind_param("i", $group_id);
    $stmt->execute();
    $result = $stmt->get_result();
    $group = $result->fetch_assoc();
}

// Handle form submission
if($_SERVER['REQUEST_METHOD'] == 'POST') {
    $name = $conn->real_escape_string($_POST['name']);
    $description = $conn->real_escape_string($_POST['description']);
    $category = $conn->real_escape_string($_POST['category']);
    $status = $conn->real_escape_string($_POST['status']);

    // Handle image upload
    $group_image = $group['group_image']; // Keep existing image by default
    
    if(isset($_FILES['group_image']) && $_FILES['group_image']['error'] === UPLOAD_ERR_OK) {
        $upload_dir = 'uploads/groups/';
        
        // Create directory if it doesn't exist
        if (!is_dir($upload_dir)) {
            mkdir($upload_dir, 0755, true);
        }
        
        $file_name = $_FILES['group_image']['name'];
        $file_tmp = $_FILES['group_image']['tmp_name'];
        $file_size = $_FILES['group_image']['size'];
        $file_ext = strtolower(pathinfo($file_name, PATHINFO_EXTENSION));
        
        // Allowed extensions
        $allowed_ext = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
        
        if (in_array($file_ext, $allowed_ext)) {
            if ($file_size <= 5 * 1024 * 1024) { // 5MB max
                // Generate unique file name
                $new_file_name = 'group_' . $group_id . '_' . time() . '.' . $file_ext;
                $upload_path = $upload_dir . $new_file_name;
                
                // Delete old image if exists
                if (!empty($group['group_image']) && file_exists($group['group_image'])) {
                    unlink($group['group_image']);
                }
                
                if (move_uploaded_file($file_tmp, $upload_path)) {
                    $group_image = $upload_path;
                }
            }
        }
    }

    // Handle image removal
    if(isset($_POST['remove_image']) && $_POST['remove_image'] == '1') {
        if (!empty($group['group_image']) && file_exists($group['group_image'])) {
            unlink($group['group_image']);
        }
        $group_image = NULL;
    }

    $stmt = $conn->prepare("UPDATE `groups` SET name = ?, description = ?, category = ?, status = ?, group_image = ? WHERE id = ?");
    $stmt->bind_param("sssssi", $name, $description, $category, $status, $group_image, $group_id);
    
    if($stmt->execute()) {
        echo '<script>alert("Group updated successfully!"); window.location.href = "group-details.php?id='.$group_id.'";</script>';
    } else {
        echo '<script>alert("Error updating group!");</script>';
    }
}

if(!$group) {
    echo '<div class="alert alert-danger m-24">Group not found.</div>';
    include './partials/layouts/layoutBottom.php';
    exit;
}
?>

<div class="dashboard-main-body">
    <div class="d-flex flex-wrap align-items-center justify-content-between gap-3 mb-24">
        <h6 class="fw-semibold mb-0">Edit Group</h6>
        <ul class="d-flex align-items-center gap-2">
            <li class="fw-medium">
                <a href="index.php" class="d-flex align-items-center gap-1 hover-text-primary">
                    <iconify-icon icon="solar:home-smile-angle-outline" class="icon text-lg"></iconify-icon>
                    Dashboard
                </a>
            </li>
            <li>-</li>
            <li class="fw-medium">
                <a href="groups-list.php" class="hover-text-primary">Groups</a>
            </li>
            <li>-</li>
            <li class="fw-medium">Edit Group</li>
        </ul>
    </div>

    <div class="row">
        <div class="col-lg-8">
            <div class="card radius-12">
                <div class="card-header border-bottom bg-base py-16 px-24">
                    <h6 class="fw-semibold mb-0">Edit Group Information</h6>
                </div>
                <div class="card-body p-24">
                    <form method="POST" id="editGroupForm" enctype="multipart/form-data">
                        <div class="row">
                            <!-- Group Image Upload -->
                            <div class="col-12">
                                <div class="mb-24">
                                    <label class="form-label text-sm mb-4">Group Profile Image</label>
                                    <div class="image-upload-container">
                                        <div class="image-preview mb-3 text-center">
                                            <?php if(!empty($group['group_image'])): ?>
                                                <div class="position-relative d-inline-block">
                                                    <img src="<?php echo $group['group_image']; ?>" class="preview-image rounded-12" style="max-height: 200px;" id="previewImage">
                                                    <button type="button" class="btn btn-danger btn-sm position-absolute top-0 end-0 m-2" onclick="removeImage()" title="Remove image">
                                                        <iconify-icon icon="mdi:close"></iconify-icon>
                                                    </button>
                                                </div>
                                                <div class="mt-2">
                                                    <small class="text-muted">Current group image</small>
                                                </div>
                                            <?php else: ?>
                                                <div class="preview-placeholder bg-light rounded-12 p-20 border-dashed">
                                                    <iconify-icon icon="mdi:camera-plus" class="icon-3x text-muted mb-2"></iconify-icon>
                                                    <p class="text-muted mb-2">Click to upload group image</p>
                                                    <small class="text-muted">JPG, PNG, GIF, WEBP (Max 5MB)</small>
                                                </div>
                                            <?php endif; ?>
                                        </div>
                                        <input type="file" class="form-control d-none" id="group_image" name="group_image" accept="image/*">
                                        <input type="hidden" name="remove_image" id="remove_image" value="0">
                                        <div class="d-flex gap-2">
                                            <button type="button" class="btn btn-outline-primary flex-fill" onclick="document.getElementById('group_image').click()">
                                                <iconify-icon icon="mdi:upload" class="me-2"></iconify-icon>
                                                <?php echo empty($group['group_image']) ? 'Upload Image' : 'Change Image'; ?>
                                            </button>
                                            <?php if(!empty($group['group_image'])): ?>
                                                <button type="button" class="btn btn-outline-danger" onclick="removeImage()">
                                                    <iconify-icon icon="mdi:delete" class="me-2"></iconify-icon>
                                                    Remove
                                                </button>
                                            <?php endif; ?>
                                        </div>
                                        <div class="form-text text-center mt-2">
                                            Recommended size: 500x500 pixels. Max file size: 5MB
                                        </div>
                                    </div>
                                </div>
                            </div>

                            <div class="col-md-6">
                                <div class="mb-16">
                                    <label class="form-label text-sm mb-4">Group Name <span class="text-danger">*</span></label>
                                    <div class="input-group">
                                        <span class="input-group-text bg-light">
                                            <iconify-icon icon="mdi:account-group"></iconify-icon>
                                        </span>
                                        <input type="text" class="form-control" name="name" value="<?php echo htmlspecialchars($group['name']); ?>" required>
                                    </div>
                                </div>
                            </div>
                            <div class="col-md-6">
                                <div class="mb-16">
                                    <label class="form-label text-sm mb-4">Category <span class="text-danger">*</span></label>
                                    <div class="input-group">
                                        <span class="input-group-text bg-light">
                                            <iconify-icon icon="mdi:tag"></iconify-icon>
                                        </span>
                                        <select class="form-select" name="category" required>
                                            <option value="">Select Category</option>
                                            <option value="Prayer" <?php echo $group['category'] == 'Prayer' ? 'selected' : ''; ?>>Prayer</option>
                                            <option value="Love" <?php echo $group['category'] == 'Love' ? 'selected' : ''; ?>>Love</option>
                                            <option value="Joy" <?php echo $group['category'] == 'Joy' ? 'selected' : ''; ?>>Joy</option>
                                            <option value="Peace" <?php echo $group['category'] == 'Peace' ? 'selected' : ''; ?>>Peace</option>
                                            <option value="Patience" <?php echo $group['category'] == 'Patience' ? 'selected' : ''; ?>>Patience</option>
                                            <option value="Kindness" <?php echo $group['category'] == 'Kindness' ? 'selected' : ''; ?>>Kindness</option>
                                            <option value="Goodness" <?php echo $group['category'] == 'Goodness' ? 'selected' : ''; ?>>Goodness</option>
                                            <option value="Faithfulness" <?php echo $group['category'] == 'Faithfulness' ? 'selected' : ''; ?>>Faithfulness</option>
                                            <option value="Gentleness" <?php echo $group['category'] == 'Gentleness' ? 'selected' : ''; ?>>Gentleness</option>
                                            <option value="Self-control" <?php echo $group['category'] == 'Self-control' ? 'selected' : ''; ?>>Self-control</option>
                                            <option value="Fellowship" <?php echo $group['category'] == 'Fellowship' ? 'selected' : ''; ?>>Fellowship</option>
                                            <option value="Bible Study" <?php echo $group['category'] == 'Bible Study' ? 'selected' : ''; ?>>Bible Study</option>
                                        </select>
                                    </div>
                                </div>
                            </div>
                            <div class="col-12">
                                <div class="mb-16">
                                    <label class="form-label text-sm mb-4">Description</label>
                                    <div class="input-group">
                                        <span class="input-group-text bg-light align-items-start">
                                            <iconify-icon icon="mdi:text"></iconify-icon>
                                        </span>
                                        <textarea class="form-control" name="description" rows="4" placeholder="Enter group description..."><?php echo htmlspecialchars($group['description']); ?></textarea>
                                    </div>
                                </div>
                            </div>
                            <div class="col-md-6">
                                <div class="mb-16">
                                    <label class="form-label text-sm mb-4">Status</label>
                                    <div class="input-group">
                                        <span class="input-group-text bg-light">
                                            <iconify-icon icon="mdi:status"></iconify-icon>
                                        </span>
                                        <select class="form-select" name="status">
                                            <option value="Active" <?php echo $group['status'] == 'Active' ? 'selected' : ''; ?>>Active</option>
                                            <option value="Inactive" <?php echo $group['status'] == 'Inactive' ? 'selected' : ''; ?>>Inactive</option>
                                        </select>
                                    </div>
                                </div>
                            </div>
                        </div>
                        
                        <div class="d-flex gap-12 mt-24">
                            <button type="submit" class="btn btn-primary d-flex align-items-center gap-2">
                                <iconify-icon icon="mdi:check"></iconify-icon>
                                Update Group
                            </button>
                            <a href="group-details.php?id=<?php echo $group_id; ?>" class="btn btn-outline-secondary d-flex align-items-center gap-2">
                                <iconify-icon icon="mdi:close"></iconify-icon>
                                Cancel
                            </a>
                        </div>
                    </form>
                </div>
            </div>
        </div>
        
        <div class="col-lg-4">
            <!-- Group Information -->
            <div class="card radius-12 mb-24">
                <div class="card-header border-bottom bg-base py-16 px-24">
                    <h6 class="fw-semibold mb-0">Group Information</h6>
                </div>
                <div class="card-body p-24">
                    <div class="text-center mb-16">
                        <?php if(!empty($group['group_image'])): ?>
                            <img src="<?php echo $group['group_image']; ?>" class="rounded-12 w-100 mb-3" style="max-height: 150px; object-fit: cover;">
                        <?php else: ?>
                            <div class="bg-light rounded-12 p-4 mb-3">
                                <iconify-icon icon="mdi:account-group" class="icon-3x text-muted"></iconify-icon>
                            </div>
                        <?php endif; ?>
                    </div>
                    <div class="d-flex justify-content-between mb-12">
                        <span class="text-muted">Group ID:</span>
                        <span class="fw-medium">#<?php echo $group['id']; ?></span>
                    </div>
                    <div class="d-flex justify-content-between mb-12">
                        <span class="text-muted">Created:</span>
                        <span class="fw-medium"><?php echo date('M j, Y', strtotime($group['created_at'])); ?></span>
                    </div>
                    <div class="d-flex justify-content-between mb-12">
                        <span class="text-muted">Members:</span>
                        <span class="fw-medium">
                            <?php 
                            $member_count = $conn->query("SELECT COUNT(*) as count FROM group_members WHERE group_id = $group_id")->fetch_assoc()['count'];
                            echo $member_count; 
                            ?>
                        </span>
                    </div>
                    <div class="d-flex justify-content-between">
                        <span class="text-muted">Current Status:</span>
                        <span class="badge bg-<?php echo $group['status'] == 'Active' ? 'success' : 'danger'; ?>">
                            <?php echo $group['status']; ?>
                        </span>
                    </div>
                </div>
            </div>

            <!-- Quick Actions -->
            <div class="card radius-12">
                <div class="card-header border-bottom bg-base py-16 px-24">
                    <h6 class="fw-semibold mb-0">Quick Actions</h6>
                </div>
                <div class="card-body p-24">
                    <div class="d-grid gap-2">
                        <a href="group-chat.php?id=<?php echo $group_id; ?>" class="btn btn-outline-info btn-sm d-flex align-items-center gap-2">
                            <iconify-icon icon="mdi:chat"></iconify-icon>
                            View Group Chat
                        </a>
                        <a href="group-members.php?id=<?php echo $group_id; ?>" class="btn btn-outline-primary btn-sm d-flex align-items-center gap-2">
                            <iconify-icon icon="mdi:account-group"></iconify-icon>
                            Manage Members
                        </a>
                    </div>
                </div>
            </div>
        </div>
    </div>
</div>

<script>
document.addEventListener('DOMContentLoaded', function() {
    const fileInput = document.getElementById('group_image');
    const previewImage = document.getElementById('previewImage');
    const previewPlaceholder = document.querySelector('.preview-placeholder');
    
    fileInput.addEventListener('change', function() {
        const file = this.files[0];
        
        if (file) {
            // Check file size (5MB max)
            if (file.size > 5 * 1024 * 1024) {
                alert('File size too large. Maximum size is 5MB.');
                this.value = '';
                return;
            }
            
            // Check file type
            const validTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp'];
            if (!validTypes.includes(file.type)) {
                alert('Invalid file type. Please select an image file (JPG, PNG, GIF, WEBP).');
                this.value = '';
                return;
            }
            
            const reader = new FileReader();
            
            reader.addEventListener('load', function() {
                if (previewImage) {
                    previewImage.src = reader.result;
                } else {
                    // Create new preview image
                    const imagePreview = document.getElementById('imagePreview');
                    imagePreview.innerHTML = `
                        <div class="position-relative d-inline-block">
                            <img src="${reader.result}" class="preview-image rounded-12" style="max-height: 200px;" id="previewImage">
                            <button type="button" class="btn btn-danger btn-sm position-absolute top-0 end-0 m-2" onclick="removeImage()">
                                <iconify-icon icon="mdi:close"></iconify-icon>
                            </button>
                        </div>
                        <div class="mt-2">
                            <small class="text-muted">New image preview</small>
                        </div>
                    `;
                }
                document.getElementById('remove_image').value = '0';
            });
            
            reader.readAsDataURL(file);
        }
    });
    
    // Allow clicking on preview to trigger file input
    document.getElementById('imagePreview').addEventListener('click', function(e) {
        if (e.target.classList.contains('preview-placeholder')) {
            fileInput.click();
        }
    });
});

function removeImage() {
    if (confirm('Are you sure you want to remove the group image?')) {
        document.getElementById('remove_image').value = '1';
        const imagePreview = document.getElementById('imagePreview');
        imagePreview.innerHTML = `
            <div class="preview-placeholder bg-light rounded-12 p-20 border-dashed">
                <iconify-icon icon="mdi:camera-plus" class="icon-3x text-muted mb-2"></iconify-icon>
                <p class="text-muted mb-2">Click to upload group image</p>
                <small class="text-muted">JPG, PNG, GIF, WEBP (Max 5MB)</small>
            </div>
        `;
    }
}

// Form validation
document.getElementById('editGroupForm').addEventListener('submit', function(e) {
    const name = document.querySelector('input[name="name"]').value.trim();
    const category = document.querySelector('select[name="category"]').value;
    
    if (!name) {
        e.preventDefault();
        alert('Group name is required!');
        return;
    }
    
    if (!category) {
        e.preventDefault();
        alert('Category is required!');
        return;
    }
});
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
}

.border-dashed {
    border: 2px dashed #dee2e6 !important;
}

.input-group-text {
    background-color: #f8f9fa !important;
    border-color: #dee2e6 !important;
}

.icon-3x {
    font-size: 3rem;
}

.card {
    transition: transform 0.2s ease, box-shadow 0.2s ease;
}

.card:hover {
    transform: translateY(-2px);
    box-shadow: 0 0.5rem 1rem rgba(0, 0, 0, 0.1) !important;
}
</style>

<?php include './partials/layouts/layoutBottom.php'; ?>