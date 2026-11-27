<?php
session_start();
include './includes/db.php';
include './includes/admin-auth.php';
include './partials/layouts/layoutTop.php';

$id = intval($_GET['id'] ?? 0);

// Dummy categories
$categories = [
    ['name'=>'Technology'], ['name'=>'Health'], ['name'=>'Lifestyle'], ['name'=>'Education']
];

// Fetch blog if editing
$blog = null;
if($id > 0){
    $sql = "SELECT b.*, u.name AS author_name, au.name AS admin_name FROM blogs b LEFT JOIN users u ON b.user_id=u.id LEFT JOIN admin_users au ON b.admin_id=au.id WHERE b.id=$id LIMIT 1";
    $result = $conn->query($sql);
    $blog = $result && $result->num_rows > 0 ? $result->fetch_assoc() : null;
}

// Fetch all users for blogger dropdown
$users_query = $conn->query("SELECT id, name FROM users WHERE status = 'Active' ORDER BY name");
$users_list = [];
while($u = $users_query->fetch_assoc()) {
    $users_list[] = $u;
}

// Handle POST
if($_SERVER['REQUEST_METHOD']==='POST'){
    $id = intval($_POST['id'] ?? 0);
    $title = $_POST['title'] ?? '';
    $category = $_POST['category'] ?? '';
    $body = $_POST['body'] ?? ''; // plain text now
    $existingThumbnail = $_POST['existing_thumbnail'] ?? null;
    $thumbnailFile = $_FILES['thumbnail'] ?? null;

    // Handle featured media upload (image or video)
    if($thumbnailFile && isset($thumbnailFile['name']) && $thumbnailFile['name']!=''){
        $ext = strtolower(pathinfo($thumbnailFile['name'], PATHINFO_EXTENSION));
        $allowedImageTypes = ['jpg', 'jpeg', 'png', 'gif'];
        $allowedVideoTypes = ['mp4', 'mov', 'avi', 'wmv', 'flv', 'webm'];
        if(in_array($ext, array_merge($allowedImageTypes, $allowedVideoTypes))) {
            $filename = 'uploads/blog_'.time().'.'.$ext;
            if(!is_dir('uploads')) mkdir('uploads', 0777, true);
            move_uploaded_file($thumbnailFile['tmp_name'], __DIR__.'/'.$filename);

            if($existingThumbnail && file_exists(__DIR__.'/'.$existingThumbnail)){
                unlink(__DIR__.'/'.$existingThumbnail);
            }
            $thumbnailPath = $filename;
        } else {
            $thumbnailPath = $existingThumbnail;
        }
    } else {
        $thumbnailPath = $existingThumbnail;
    }

    $blogger_id = intval($_POST['blogger_id'] ?? 0);
    $admin_id = intval($_SESSION['admin_id'] ?? 0);

    if($id > 0){
        // Update blog with user_id/admin_id logic
        if($blogger_id > 0) {
            $stmt = $conn->prepare("UPDATE blogs SET title=?, category=?, body=?, image_url=?, user_id=?, admin_id=? WHERE id=?");
            $stmt->bind_param("sssssii", $title, $category, $body, $thumbnailPath, $blogger_id, $admin_id, $id);
        } else {
            $stmt = $conn->prepare("UPDATE blogs SET title=?, category=?, body=?, image_url=?, user_id=NULL, admin_id=? WHERE id=?");
            $stmt->bind_param("sssssi", $title, $category, $body, $thumbnailPath, $admin_id, $id);
        }
        $stmt->execute();
        $stmt->close();
        $msg = "Blog updated successfully!";
    } else {
        // Create new blog
        if($blogger_id > 0) {
            $stmt = $conn->prepare("INSERT INTO blogs (title, category, body, image_url, user_id, admin_id, created_at, status) VALUES (?,?,?,?,?,?,NOW(),'Approved')");
            $stmt->bind_param("sssssi", $title, $category, $body, $thumbnailPath, $blogger_id, $admin_id);
        } else {
            $stmt = $conn->prepare("INSERT INTO blogs (title, category, body, image_url, user_id, admin_id, created_at, status) VALUES (?,?,?,?,NULL,?,NOW(),'Approved')");
            $stmt->bind_param("sssss", $title, $category, $body, $thumbnailPath, $admin_id);
        }
        $stmt->execute();
        $stmt->close();
        $msg = "Blog added successfully!";
    }

    echo "<script>alert('".$msg."'); window.location='blogs-list.php';</script>";
    exit;
}
?>

<div class="dashboard-main-body">
<div class="d-flex flex-wrap align-items-center justify-content-between gap-3 mb-24">
<h6 class="fw-semibold mb-0"><?= $blog?"Edit Blog":"Add Blog" ?></h6>
<ul class="d-flex align-items-center gap-2">
<li class="fw-medium"><a href="blogs-list.php" class="d-flex align-items-center gap-1 hover-text-primary">
<iconify-icon icon="solar:home-smile-angle-outline" class="icon text-lg"></iconify-icon> Blogs Grid</a></li>
<li>-</li>
<li class="fw-medium"><?= $blog?"Edit Blog":"Add Blog" ?></li>
</ul>
</div>

<div class="card h-100 p-0 radius-12">
<div class="card-body p-24">
<form method="post" enctype="multipart/form-data" class="d-flex flex-column gap-20">
<input type="hidden" name="id" value="<?= $blog['id'] ?? 0 ?>">
<input type="hidden" name="existing_thumbnail" value="<?= $blog['image_url'] ?? '' ?>">

<div>
<label class="form-label fw-bold text-neutral-900">Post Title:</label>
<input type="text" name="title" class="form-control border border-neutral-200 radius-8"
value="<?= htmlspecialchars($blog['title'] ?? '') ?>" required>
</div>

<div>
<label class="form-label fw-bold text-neutral-900">Post Category:</label>
<select name="category" class="form-control border border-neutral-200 radius-8">
<option value="">-- Select Category --</option>
<?php foreach($categories as $cat): ?>
<option value="<?= htmlspecialchars($cat['name']) ?>" <?= ($blog['category'] ?? '')==$cat['name']?'selected':'' ?>><?= htmlspecialchars($cat['name']) ?></option>
<?php endforeach; ?>
</select>
</div>

<?php if($blog): ?>
<div>
<label class="form-label fw-bold text-neutral-900">Post As:</label>
<select name="blogger_id" class="form-control border border-neutral-200 radius-8">
    <option value="0" <?= ($blog['user_id'] ?? null) === null ? 'selected' : '' ?>>Admin (<?= htmlspecialchars($_SESSION['admin_name'] ?? 'Admin') ?>)</option>
    <option value="" disabled>--- Bloggers ---</option>
    <?php foreach($users_list as $user): ?>
        <option value="<?= $user['id'] ?>" <?= ($blog['user_id'] ?? 0) == $user['id'] ? 'selected' : '' ?>>
            <?= htmlspecialchars($user['name']); ?>
        </option>
    <?php endforeach; ?>
</select>
<small class="text-muted">Select who will be shown as the blog author</small>
</div>
<?php endif; ?>

<div>
<label class="form-label fw-bold text-neutral-900">Post Description:</label>
<textarea name="body" class="form-control border border-neutral-200 radius-8" rows="6" required><?= htmlspecialchars($blog['body'] ?? '') ?></textarea>
</div>

<div>
<label class="form-label fw-bold text-neutral-900">Upload Featured Media:</label>
<div class="upload-image-wrapper">
<?php
$existingMediaUrl = $blog['image_url'] ?? '';
$existingMediaExt = strtolower(pathinfo($existingMediaUrl, PATHINFO_EXTENSION));
$existingVideoTypes = ['mp4', 'mov', 'avi', 'wmv', 'flv', 'webm'];
?>
<div class="uploaded-img <?= !empty($existingMediaUrl) ? '' : 'd-none' ?> position-relative h-160-px w-100 border input-form-light radius-8 overflow-hidden border-dashed bg-neutral-50">
<button type="button" class="uploaded-img__remove position-absolute top-0 end-0 z-1 text-2xxl line-height-1 me-8 mt-8 d-flex bg-danger-600 w-40-px h-40-px justify-content-center align-items-center rounded-circle">
<iconify-icon icon="radix-icons:cross-2" class="text-2xl text-white"></iconify-icon>
</button>
<?php if (!empty($existingMediaUrl) && in_array($existingMediaExt, $existingVideoTypes)): ?>
    <video id="uploaded-video__preview" class="w-100 h-100 object-fit-cover" controls>
        <source src="<?= htmlspecialchars($existingMediaUrl) ?>" type="video/<?= htmlspecialchars($existingMediaExt) ?>">
        Your browser does not support the video tag.
    </video>
    <img id="uploaded-img__preview" class="w-100 h-100 object-fit-cover d-none" src="assets/images/user.png" alt="image">
<?php else: ?>
    <img id="uploaded-img__preview" class="w-100 h-100 object-fit-cover" src="<?= htmlspecialchars($existingMediaUrl ?: 'assets/images/user.png') ?>" alt="image">
    <video id="uploaded-video__preview" class="w-100 h-100 object-fit-cover d-none" controls></video>
<?php endif; ?>
</div>
<label class="upload-file h-160-px w-100 border input-form-light radius-8 overflow-hidden border-dashed bg-neutral-50 bg-hover-neutral-200 d-flex align-items-center flex-column justify-content-center gap-1" for="upload-file">
<iconify-icon icon="solar:camera-outline" class="text-xl text-secondary-light"></iconify-icon>
<span class="fw-semibold text-secondary-light">Upload</span>
<input id="upload-file" name="thumbnail" type="file" accept="image/*,video/*" hidden>
</label>
<small class="text-muted">Upload an image or video file to use as featured blog media.</small>
</div>
</div>

<button type="submit" class="btn btn-primary-600 radius-8"><?= $blog?"Update Blog":"Add Blog" ?></button>
</form>
</div>
</div>
</div>

<?php include './partials/layouts/layoutBottom.php'; ?>

<script>
// Thumbnail logic
const fileInput = document.getElementById('upload-file');
const imagePreview = document.getElementById('uploaded-img__preview');
const videoPreview = document.getElementById('uploaded-video__preview');
const uploadedImgContainer = document.querySelector('.uploaded-img');
const removeButton = document.querySelector('.uploaded-img__remove');

fileInput.addEventListener('change', e=>{
  if(e.target.files.length){
    const file = e.target.files[0];
    const url = URL.createObjectURL(file);
    const isVideo = file.type.startsWith('video/');

    if (isVideo) {
      videoPreview.src = url;
      videoPreview.classList.remove('d-none');
      imagePreview.classList.add('d-none');
    } else {
      imagePreview.src = url;
      imagePreview.classList.remove('d-none');
      videoPreview.classList.add('d-none');
    }

    uploadedImgContainer.classList.remove('d-none');
  }
});

removeButton.addEventListener('click', ()=>{
  imagePreview.src='';
  videoPreview.src='';
  uploadedImgContainer.classList.add('d-none');
  fileInput.value='';
});
</script>
