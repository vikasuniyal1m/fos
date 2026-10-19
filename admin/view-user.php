<?php
include './includes/db.php';
include './includes/admin-auth.php';
include './partials/layouts/layoutTop.php';

// Get user ID
if (!isset($_GET['id']) || !is_numeric($_GET['id'])) {
    echo "Invalid user ID.";
    exit;
}
$id = intval($_GET['id']);

// Fetch user data
$stmt = $conn->prepare("SELECT * FROM users WHERE id = ?");
$stmt->bind_param("i", $id);
$stmt->execute();
$result = $stmt->get_result();
$user = $result->fetch_assoc();

if (!$user) {
    echo "User not found.";
    exit;
}
?>

<div class="dashboard-main-body">
    <div class="d-flex flex-wrap align-items-center justify-content-between gap-3 mb-24">
        <h6 class="fw-semibold mb-0">User Profile</h6>
        <ul class="d-flex align-items-center gap-2">
            <li class="fw-medium">
                <a href="index.php" class="d-flex align-items-center gap-1 hover-text-primary">
                    <iconify-icon icon="solar:home-smile-angle-outline" class="icon text-lg"></iconify-icon>
                    Dashboard
                </a>
            </li>
            <li>-</li>
            <li class="fw-medium">User Profile</li>
        </ul>
    </div>

    <div class="card h-100 p-0 radius-12">
        <div class="card-body p-24">
            <div class="d-flex gap-24 flex-wrap mb-24">
                <div>
                    <img src="<?= $user['profile_photo'] ?: 'assets/images/default-avatar.png' ?>" alt="" class="w-120-px h-120-px rounded-circle overflow-hidden">
                </div>
                <div class="flex-grow-1">
                    <h4 class="fw-semibold mb-8"><?= htmlspecialchars($user['name']) ?></h4>
                    <p class="mb-4"><strong>Email:</strong> <?= htmlspecialchars($user['email']) ?></p>
                    <p class="mb-4"><strong>Phone:</strong> <?= htmlspecialchars($user['phone']) ?></p>
                    <p class="mb-4"><strong>Role:</strong> <?= htmlspecialchars($user['role']) ?></p>
                    <p class="mb-4"><strong>Status:</strong> 
                        <?= $user['status'] == 'Active' 
                            ? '<span class="bg-success-focus text-success-600 px-12 py-4 radius-4 fw-medium">Active</span>'
                            : '<span class="bg-neutral-200 text-neutral-600 px-12 py-4 radius-4 fw-medium">Inactive</span>'; ?>
                    </p>
                    <p class="mb-4"><strong>Join Date:</strong> <?= date("d M Y", strtotime($user['join_date'])) ?></p>
                </div>
            </div>

            <div class="mt-24">
                <a href="users-list.php" class="btn btn-outline-primary">Back to Users</a>
            </div>
        </div>
    </div>
</div>

<?php include './partials/layouts/layoutBottom.php'; ?>

\\
