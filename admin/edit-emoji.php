<?php
include './includes/db.php';
include './includes/admin-auth.php';
include './partials/layouts/layoutTop.php';

$id = isset($_GET['id']) ? intval($_GET['id']) : 0;
$emoji = null;
$success = '';
$error = '';

// Fetch emoji data
if ($id > 0) {
    $result = $conn->query("SELECT * FROM emojis WHERE id = $id");
    if ($result->num_rows > 0) {
        $emoji = $result->fetch_assoc();
    } else {
        $error = "Emoji not found!";
    }
}

// Handle form submission
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['update_emoji'])) {
    $name = $conn->real_escape_string($_POST['name']);
    $description = $conn->real_escape_string($_POST['description']);
    $category = $conn->real_escape_string($_POST['category']);
    $status = $conn->real_escape_string($_POST['status']);
    
    // Use existing image_url by default
    $image_url = $emoji['image_url'] ?? '';
    
    // Handle image file upload
    if (isset($_FILES['emoji_image']) && $_FILES['emoji_image']['error'] === UPLOAD_ERR_OK) {
        $upload_dir = './uploads/emojis/';
        if (!is_dir($upload_dir)) {
            mkdir($upload_dir, 0777, true);
        }
        
        $file_extension = pathinfo($_FILES['emoji_image']['name'], PATHINFO_EXTENSION);
        $allowed_extensions = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg'];
        
        if (in_array(strtolower($file_extension), $allowed_extensions)) {
            // Check file size (limit to 1MB)
            if ($_FILES['emoji_image']['size'] <= 1048576) {
                // Delete old image if exists
                if (!empty($emoji['image_url']) && strpos($emoji['image_url'], './uploads/emojis/') === 0) {
                    $old_file_path = $emoji['image_url'];
                    if (file_exists($old_file_path)) {
                        unlink($old_file_path);
                    }
                }
                
                // Generate unique filename
                $uploaded_file_name = 'emoji_' . time() . '_' . uniqid() . '.' . $file_extension;
                $upload_path = $upload_dir . $uploaded_file_name;
                
                if (move_uploaded_file($_FILES['emoji_image']['tmp_name'], $upload_path)) {
                    // Automatically use the uploaded file path
                    $image_url = './uploads/emojis/' . $uploaded_file_name;
                } else {
                    $error = "Failed to upload image file.";
                }
            } else {
                $error = "Image file size must be less than 1MB.";
            }
        } else {
            $error = "Only JPG, JPEG, PNG, GIF, WEBP, and SVG files are allowed.";
        }
    }
    
    if (empty($error)) {
        $sql = "UPDATE emojis SET 
                name = '$name', 
                description = '$description', 
                category = '$category',
                image_url = '$image_url',
                status = '$status'
                WHERE id = $id";
        
        if ($conn->query($sql)) {
            $success = "Emoji updated successfully!";
            // Refresh emoji data
            $result = $conn->query("SELECT * FROM emojis WHERE id = $id");
            $emoji = $result->fetch_assoc();
        } else {
            $error = "Error: " . $conn->error;
        }
    }
}

// If emoji not found, redirect back
if (!$emoji && $id > 0) {
    header('Location: emojis-list.php');
    exit();
}
?>

<div class="dashboard-main-body">
    <div class="d-flex flex-wrap align-items-center justify-content-between gap-3 mb-24">
        <h6 class="fw-semibold mb-0">Edit Emoji</h6>
        <ul class="d-flex align-items-center gap-2">
            <li class="fw-medium">
                <a href="emojis-list.php" class="d-flex align-items-center gap-1 hover-text-primary">
                    <iconify-icon icon="solar:home-smile-angle-outline" class="icon text-lg"></iconify-icon>
                    Emojis
                </a>
            </li>
            <li>-</li>
            <li class="fw-medium">Edit Emoji</li>
        </ul>
    </div>

    <!-- Only show messages when they have content -->
    <?php if ($error !== ''): ?>
        <div class="alert alert-danger"><?php echo $error; ?></div>
    <?php endif; ?>
    <?php if ($success !== ''): ?>
        <div class="alert alert-success"><?php echo $success; ?></div>
    <?php endif; ?>

    <div class="card h-100 p-0 radius-12">
        <div class="card-body p-24">
            <div class="row justify-content-center">
                <div class="col-xxl-6 col-xl-8 col-lg-10">
                    <div class="card border">
                        <div class="card-body">
                            <!-- Emoji Preview Section -->
                            <?php if (!empty($emoji['image_url'])): ?>
                            <div class="text-center mb-24">
                                <div class="emoji-preview bg-light radius-12 p-20 d-inline-block">
                                    <img src="<?php echo htmlspecialchars($emoji['image_url']); ?>" 
                                         class="w-80-px h-80-px object-fit-contain" 
                                         alt="<?php echo htmlspecialchars($emoji['name']); ?>">
                                    <div class="text-muted mt-8">Current Emoji Image</div>
                                </div>
                            </div>
                            <?php endif; ?>

                            <form method="POST" enctype="multipart/form-data">
                                <div class="mb-20">
                                    <label class="form-label fw-semibold text-primary-light text-sm mb-8">Emoji Name</label>
                                    <input type="text" class="form-control radius-8" name="name" 
                                           value="<?php echo htmlspecialchars($emoji['name'] ?? ''); ?>" required>
                                </div>
                                
                                <div class="mb-20">
                                    <label class="form-label fw-semibold text-primary-light text-sm mb-8">Emoji Image</label>
                                    <input type="file" class="form-control radius-8" name="emoji_image" 
                                           accept=".jpg,.jpeg,.png,.gif,.webp,.svg">
                                    <small class="text-muted">Upload emoji image (JPG, PNG, GIF, WEBP, SVG, max 1MB)</small>
                                    <?php if (!empty($emoji['image_url'])): ?>
                                        <div class="form-text text-success">Current image: <?php echo basename($emoji['image_url']); ?></div>
                                    <?php endif; ?>
                                </div>
                                
                                <div class="mb-20">
                                    <label class="form-label fw-semibold text-primary-light text-sm mb-8">Category</label>
                                    <select class="form-control radius-8 form-select" name="category" required>
                                        <option value="Love" <?php echo ($emoji['category'] ?? '') == 'Love' ? 'selected' : ''; ?>>Love</option>
                                        <option value="Joy" <?php echo ($emoji['category'] ?? '') == 'Joy' ? 'selected' : ''; ?>>Joy</option>
                                        <option value="Peace" <?php echo ($emoji['category'] ?? '') == 'Peace' ? 'selected' : ''; ?>>Peace</option>
                                        <option value="Patience" <?php echo ($emoji['category'] ?? '') == 'Patience' ? 'selected' : ''; ?>>Patience</option>
                                        <option value="Kindness" <?php echo ($emoji['category'] ?? '') == 'Kindness' ? 'selected' : ''; ?>>Kindness</option>
                                        <option value="Goodness" <?php echo ($emoji['category'] ?? '') == 'Goodness' ? 'selected' : ''; ?>>Goodness</option>
                                        <option value="Faithfulness" <?php echo ($emoji['category'] ?? '') == 'Faithfulness' ? 'selected' : ''; ?>>Faithfulness</option>
                                        <option value="Gentleness" <?php echo ($emoji['category'] ?? '') == 'Gentleness' ? 'selected' : ''; ?>>Gentleness</option>
                                        <option value="Self-Control" <?php echo ($emoji['category'] ?? '') == 'Self-Control' ? 'selected' : ''; ?>>Self-Control</option>
                                    </select>
                                </div>
                                
                                <div class="mb-20">
                                    <label class="form-label fw-semibold text-primary-light text-sm mb-8">Status</label>
                                    <select class="form-control radius-8 form-select" name="status" required>
                                        <option value="Active" <?php echo ($emoji['status'] ?? 'Active') == 'Active' ? 'selected' : ''; ?>>Active</option>
                                        <option value="Inactive" <?php echo ($emoji['status'] ?? '') == 'Inactive' ? 'selected' : ''; ?>>Inactive</option>
                                    </select>
                                </div>
                                
                                <div class="mb-20">
                                    <label class="form-label fw-semibold text-primary-light text-sm mb-8">Description</label>
                                    <textarea class="form-control radius-8" name="description" rows="3"><?php echo htmlspecialchars($emoji['description'] ?? ''); ?></textarea>
                                </div>
                                
                                <div class="d-flex align-items-center justify-content-center gap-3">
                                    <a href="emojis-list.php" class="border border-danger-600 bg-hover-danger-200 text-danger-600 text-md px-56 py-11 radius-8 text-decoration-none">
                                        Cancel
                                    </a>
                                    <button type="submit" name="update_emoji" class="btn btn-primary border border-primary-600 text-md px-56 py-12 radius-8">
                                        Update Emoji
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