<?php
include './includes/db.php';
include './includes/admin-auth.php';
include './partials/layouts/layoutTop.php';

$success = '';
$error = '';

// Handle form submission
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['add_emoji'])) {
    $name = $conn->real_escape_string($_POST['name']);
    $description = $conn->real_escape_string($_POST['description']);
    $category = $conn->real_escape_string($_POST['category']);
    $image_url = ''; // Initialize empty
    
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
    } else {
        $error = "Please select an emoji image to upload.";
    }
    
    if (empty($error)) {
        $sql = "INSERT INTO emojis (name, description, category, image_url) 
                VALUES ('$name', '$description', '$category', '$image_url')";
        
        if ($conn->query($sql)) {
            $success = "Emoji added successfully!";
            // Clear form fields
            $_POST = array();
        } else {
            $error = "Error: " . $conn->error;
        }
    }
}
?>

<div class="dashboard-main-body">
    <div class="d-flex flex-wrap align-items-center justify-content-between gap-3 mb-24">
        <h6 class="fw-semibold mb-0">Add Emoji</h6>
        <ul class="d-flex align-items-center gap-2">
            <li class="fw-medium">
                <a href="emojis-list.php" class="d-flex align-items-center gap-1 hover-text-primary">
                    <iconify-icon icon="solar:home-smile-angle-outline" class="icon text-lg"></iconify-icon>
                    Emojis
                </a>
            </li>
            <li>-</li>
            <li class="fw-medium">Add Emoji</li>
        </ul>
    </div>

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
                            <form method="POST" enctype="multipart/form-data">
                                <div class="mb-20">
                                    <label class="form-label fw-semibold text-primary-light text-sm mb-8">Emoji Name</label>
                                    <input type="text" class="form-control radius-8" name="name" 
                                           value="<?php echo htmlspecialchars($_POST['name'] ?? ''); ?>" required>
                                </div>
                                
                                <div class="mb-20">
                                    <label class="form-label fw-semibold text-primary-light text-sm mb-8">Emoji Image</label>
                                    <input type="file" class="form-control radius-8" name="emoji_image" 
                                           accept=".jpg,.jpeg,.png,.gif,.webp,.svg" required>
                                    <small class="text-muted">Upload emoji image (JPG, PNG, GIF, WEBP, SVG, max 1MB)</small>
                                </div>
                                
                                <div class="mb-20">
                                    <label class="form-label fw-semibold text-primary-light text-sm mb-8">Category</label>
                                    <select class="form-control radius-8 form-select" name="category" required>
                                        <option value="Love" <?php echo ($_POST['category'] ?? '') == 'Love' ? 'selected' : ''; ?>>Love</option>
                                        <option value="Joy" <?php echo ($_POST['category'] ?? '') == 'Joy' ? 'selected' : ''; ?>>Joy</option>
                                        <option value="Peace" <?php echo ($_POST['category'] ?? '') == 'Peace' ? 'selected' : ''; ?>>Peace</option>
                                        <option value="Patience" <?php echo ($_POST['category'] ?? '') == 'Patience' ? 'selected' : ''; ?>>Patience</option>
                                        <option value="Kindness" <?php echo ($_POST['category'] ?? '') == 'Kindness' ? 'selected' : ''; ?>>Kindness</option>
                                        <option value="Goodness" <?php echo ($_POST['category'] ?? '') == 'Goodness' ? 'selected' : ''; ?>>Goodness</option>
                                        <option value="Faithfulness" <?php echo ($_POST['category'] ?? '') == 'Faithfulness' ? 'selected' : ''; ?>>Faithfulness</option>
                                        <option value="Gentleness" <?php echo ($_POST['category'] ?? '') == 'Gentleness' ? 'selected' : ''; ?>>Gentleness</option>
                                        <option value="Self-Control" <?php echo ($_POST['category'] ?? '') == 'Self-Control' ? 'selected' : ''; ?>>Self-Control</option>
                                    </select>
                                </div>
                                
                                <div class="mb-20">
                                    <label class="form-label fw-semibold text-primary-light text-sm mb-8">Description</label>
                                    <textarea class="form-control radius-8" name="description" rows="3"><?php echo htmlspecialchars($_POST['description'] ?? ''); ?></textarea>
                                </div>
                                
                                <div class="d-flex align-items-center justify-content-center gap-3">
                                    <a href="emojis-list.php" class="border border-danger-600 bg-hover-danger-200 text-danger-600 text-md px-56 py-11 radius-8 text-decoration-none">
                                        Cancel
                                    </a>
                                    <button type="submit" name="add_emoji" class="btn btn-primary border border-primary-600 text-md px-56 py-12 radius-8">
                                        Add Emoji
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