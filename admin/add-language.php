<?php
include './includes/db.php';
include './includes/admin-auth.php';
include './partials/layouts/layoutTop.php';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $code = $conn->real_escape_string($_POST['code']);
    $name = $conn->real_escape_string($_POST['name']);
    $native_name = $conn->real_escape_string($_POST['native_name']);
    
    $sql = "INSERT INTO languages (code, name, native_name) 
            VALUES ('$code', '$name', '$native_name')";
    
    if ($conn->query($sql)) {
        $success = "Language added successfully!";
    } else {
        $error = "Error: " . $conn->error;
    }
}
?>

<div class="dashboard-main-body">
    <div class="d-flex flex-wrap align-items-center justify-content-between gap-3 mb-24">
        <h6 class="fw-semibold mb-0">Add Language</h6>
        <ul class="d-flex align-items-center gap-2">
            <li class="fw-medium">
                <a href="languages-list.php" class="d-flex align-items-center gap-1 hover-text-primary">
                    <iconify-icon icon="solar:home-smile-angle-outline" class="icon text-lg"></iconify-icon>
                    Languages
                </a>
            </li>
            <li>-</li>
            <li class="fw-medium">Add Language</li>
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
            <div class="row justify-content-center">
                <div class="col-xxl-6 col-xl-8 col-lg-10">
                    <div class="card border">
                        <div class="card-body">
                            <form method="POST">
                                <div class="mb-20">
                                    <label class="form-label fw-semibold text-primary-light text-sm mb-8">Language Code</label>
                                    <input type="text" class="form-control radius-8" name="code" required maxlength="5" placeholder="en">
                                </div>
                                
                                <div class="mb-20">
                                    <label class="form-label fw-semibold text-primary-light text-sm mb-8">Language Name</label>
                                    <input type="text" class="form-control radius-8" name="name" required placeholder="English">
                                </div>
                                
                                <div class="mb-20">
                                    <label class="form-label fw-semibold text-primary-light text-sm mb-8">Native Name</label>
                                    <input type="text" class="form-control radius-8" name="native_name" required placeholder="English">
                                </div>
                                
                                <div class="d-flex align-items-center justify-content-center gap-3">
                                    <a href="languages-list.php" class="border border-danger-600 bg-hover-danger-200 text-danger-600 text-md px-56 py-11 radius-8 text-decoration-none">
                                        Cancel
                                    </a>
                                    <button type="submit" class="btn btn-primary border border-primary-600 text-md px-56 py-12 radius-8">
                                        Add Language
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