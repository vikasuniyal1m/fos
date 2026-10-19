<?php
include './includes/db.php';
include './includes/admin-auth.php';
include './partials/layouts/layoutTop.php';

// Handle form submission
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $title = $conn->real_escape_string($_POST['title']);
    $body = $conn->real_escape_string($_POST['body']);
    $category = $conn->real_escape_string($_POST['category']);
    $language = $conn->real_escape_string($_POST['language']);
    $admin_id = intval($_SESSION['admin_id'] ?? 0); // Get logged in admin ID
    $user_id = intval($_POST['blogger_id'] ?? 0); // Selected blogger (0 means admin post)
    
    // Handle featured media upload (image or video)
    $image_url = null;
    if (isset($_FILES['image']) && $_FILES['image']['error'] === UPLOAD_ERR_OK) {
        $uploadDir = 'uploads/blogs/';
        if (!is_dir($uploadDir)) {
            mkdir($uploadDir, 0755, true);
        }
        
        $fileExtension = strtolower(pathinfo($_FILES['image']['name'], PATHINFO_EXTENSION));
        $fileName = 'blog_' . time() . '_' . uniqid() . '.' . $fileExtension;
        $filePath = $uploadDir . $fileName;
        
        $allowedImageTypes = ['jpg', 'jpeg', 'png', 'gif'];
        $allowedVideoTypes = ['mp4', 'mov', 'avi', 'wmv', 'flv', 'webm'];
        if (in_array($fileExtension, $allowedImageTypes)) {
            if (move_uploaded_file($_FILES['image']['tmp_name'], $filePath)) {
                $image_url = $filePath;
            }
        } elseif (in_array($fileExtension, $allowedVideoTypes)) {
            if (move_uploaded_file($_FILES['image']['tmp_name'], $filePath)) {
                $image_url = $filePath;
            }
        }
    }
    
    // Insert blog - if blogger selected, use that user_id, otherwise admin post
    if ($user_id > 0) {
        // Posting as a blogger
        $sql = "INSERT INTO blogs (user_id, admin_id, title, category, body, language, image_url, status)
                VALUES ($user_id, $admin_id, '$title', '$category', '$body', '$language', '$image_url', 'Approved')";
    } else {
        // Admin's own post
        $sql = "INSERT INTO blogs (user_id, admin_id, title, category, body, language, image_url, status)
                VALUES (NULL, $admin_id, '$title', '$category', '$body', '$language', '$image_url', 'Approved')";
    }
    
    if ($conn->query($sql)) {
        $success = "Blog created successfully!";
        // Clear form
        $_POST = array();
    } else {
        $error = "Error: " . $conn->error;
    }
}
?>

<div class="dashboard-main-body">
    <div class="d-flex flex-wrap align-items-center justify-content-between gap-3 mb-24">
        <h6 class="fw-semibold mb-0">Add New Blog</h6>
        <ul class="d-flex align-items-center gap-2">
            <li class="fw-medium">
                <a href="blogs-list.php" class="d-flex align-items-center gap-1 hover-text-primary">
                    <iconify-icon icon="solar:home-smile-angle-outline" class="icon text-lg"></iconify-icon>
                    Blogs
                </a>
            </li>
            <li>-</li>
            <li class="fw-medium">Add Blog</li>
        </ul>
    </div>

    <?php if (isset($error)): ?>
        <div class="alert alert-danger"><?php echo $error; ?></div>
    <?php endif; ?>
    <?php if (isset($success)): ?>
        <div class="alert alert-success"><?php echo $success; ?></div>
    <?php endif; ?>

    <div class="card h-100 p-0 radius-12">
        <div class="card-body p-24">
            <form method="POST" enctype="multipart/form-data">
                <div class="row">
                    <div class="col-lg-8">
                        <div class="card border">
                            <div class="card-body">
                                <div class="mb-20">
                                    <label class="form-label fw-semibold text-primary-light text-sm mb-8">Blog Title</label>
                                    <input type="text" class="form-control radius-8" name="title" value="<?php echo htmlspecialchars($_POST['title'] ?? ''); ?>" required>
                                </div>
                                
                                <div class="mb-20">
                                    <label class="form-label fw-semibold text-primary-light text-sm mb-8">Blog Content</label>
                                    <textarea class="form-control radius-8" name="body" rows="12" required><?php echo htmlspecialchars($_POST['body'] ?? ''); ?></textarea>
                                </div>
                            </div>
                        </div>
                    </div>
                    
                    <div class="col-lg-4">
                        <div class="card border">
                            <div class="card-body">
                                <h6 class="text-md text-primary-light mb-16">Blog Settings</h6>
                                
                                <div class="mb-20">
                                    <label class="form-label fw-semibold text-primary-light text-sm mb-8">Category</label>
                                    <select class="form-control radius-8 form-select" name="category" required>
                                        <option value="">Select Category</option>
                                        <option value="Love" <?php echo ($_POST['category'] ?? '') == 'Love' ? 'selected' : ''; ?>>Love</option>
                                        <option value="Joy" <?php echo ($_POST['category'] ?? '') == 'Joy' ? 'selected' : ''; ?>>Joy</option>
                                        <option value="Peace" <?php echo ($_POST['category'] ?? '') == 'Peace' ? 'selected' : ''; ?>>Peace</option>
                                        <option value="Patience" <?php echo ($_POST['category'] ?? '') == 'Patience' ? 'selected' : ''; ?>>Patience</option>
                                        <option value="Kindness" <?php echo ($_POST['category'] ?? '') == 'Kindness' ? 'selected' : ''; ?>>Kindness</option>
                                        <option value="Goodness" <?php echo ($_POST['category'] ?? '') == 'Goodness' ? 'selected' : ''; ?>>Goodness</option>
                                        <option value="Faithfulness" <?php echo ($_POST['category'] ?? '') == 'Faithfulness' ? 'selected' : ''; ?>>Faithfulness</option>
                                        <option value="Gentleness" <?php echo ($_POST['category'] ?? '') == 'Gentleness' ? 'selected' : ''; ?>>Gentleness</option>
                                        <option value="Self-Control" <?php echo ($_POST['category'] ?? '') == 'Self-Control' ? 'selected' : ''; ?>>Self-Control</option>
                                        <option value="Testimony" <?php echo ($_POST['category'] ?? '') == 'Testimony' ? 'selected' : ''; ?>>Testimony</option>
                                        <option value="Teaching" <?php echo ($_POST['category'] ?? '') == 'Teaching' ? 'selected' : ''; ?>>Teaching</option>
                                    </select>
                                </div>

                                <?php
                                // Fetch all users for blogger dropdown
                                $users_query = $conn->query("SELECT id, name FROM users WHERE status = 'Active' ORDER BY name");
                                $users_list = [];
                                while($u = $users_query->fetch_assoc()) {
                                    $users_list[] = $u;
                                }
                                ?>
                                <div class="mb-20">
                                    <label class="form-label fw-semibold text-primary-light text-sm mb-8">Post As</label>
                                    <select class="form-control radius-8 form-select" name="blogger_id">
                                        <option value="0">Admin (<?php echo htmlspecialchars($_SESSION['admin_name'] ?? 'Admin'); ?>)</option>
                                        <option value="" disabled>--- Bloggers ---</option>
                                        <?php foreach($users_list as $user): ?>
                                            <option value="<?php echo $user['id']; ?>" <?php echo ($_POST['blogger_id'] ?? '') == $user['id'] ? 'selected' : ''; ?>>
                                                <?php echo htmlspecialchars($user['name']); ?>
                                            </option>
                                        <?php endforeach; ?>
                                    </select>
                                    <small class="text-muted">Select who will be shown as the blog author</small>
                                </div>

                                <div class="mb-20">
                                    <label class="form-label fw-semibold text-primary-light text-sm mb-8">Language</label>
                                    <select class="form-control radius-8 form-select" name="language" required>
                                        <option value="en" <?php echo ($_POST['language'] ?? '') == 'en' ? 'selected' : ''; ?>>English</option>
                                        <option value="es" <?php echo ($_POST['language'] ?? '') == 'es' ? 'selected' : ''; ?>>Spanish</option>
                                        <option value="fr" <?php echo ($_POST['language'] ?? '') == 'fr' ? 'selected' : ''; ?>>French</option>
                                    </select>
                                </div>
                                
                                <div class="mb-20">
                                    <label class="form-label fw-semibold text-primary-light text-sm mb-8">Featured Media</label>
                                    <input type="file" class="form-control radius-8" name="image" accept="image/*,video/*">
                                    <small class="text-muted">Upload an image or a video file. Recommended image size: 800x400 pixels.</small>
                                </div>
                                
                                <div class="form-check form-switch mb-20">
                                    <input class="form-check-input" type="checkbox" name="is_featured" id="is_featured" <?php echo isset($_POST['is_featured']) ? 'checked' : ''; ?>>
                                    <label class="form-check-label" for="is_featured">Feature this blog</label>
                                </div>
                                
                                <div class="form-check form-switch mb-20">
                                    <input class="form-check-input" type="checkbox" name="is_trending" id="is_trending" <?php echo isset($_POST['is_trending']) ? 'checked' : ''; ?>>
                                    <label class="form-check-label" for="is_trending">Mark as trending</label>
                                </div>
                            </div>
                        </div>
                        
                        <div class="d-flex align-items-center justify-content-center gap-3 mt-24">
                            <a href="blogs-list.php" class="border border-danger-600 bg-hover-danger-200 text-danger-600 text-md px-56 py-11 radius-8 text-decoration-none">
                                Cancel
                            </a>
                            <button type="submit" class="btn btn-primary border border-primary-600 text-md px-56 py-12 radius-8">
                                Publish Blog
                            </button>
                        </div>
                    </div>
                </div>
            </form>
        </div>
    </div>
</div>

<?php include './partials/layouts/layoutBottom.php'; ?>