<?php
session_start();
require_once 'includes/db.php';
require_once 'includes/admin-auth.php';
include './partials/layouts/layoutTop.php';

// Get statistics
$users_count = $conn->query("SELECT COUNT(*) as count FROM users")->fetch_assoc()['count'];
$blogs_count = $conn->query("SELECT COUNT(*) as count FROM blogs WHERE status = 'Approved'")->fetch_assoc()['count'];
$prayers_count = $conn->query("SELECT COUNT(*) as count FROM prayer_requests WHERE status = 'Approved'")->fetch_assoc()['count'];
$pending_count = $conn->query("SELECT COUNT(*) as count FROM blogs WHERE status = 'Pending'")->fetch_assoc()['count'] + 
                 $conn->query("SELECT COUNT(*) as count FROM prayer_requests WHERE status = 'Pending'")->fetch_assoc()['count'];

// Get recent users
$recent_users = $conn->query("SELECT name, email, join_date FROM users ORDER BY id DESC LIMIT 5")->fetch_all(MYSQLI_ASSOC);

// Get active users per fruit category
$activeUsersByFruit = [];
$result = $conn->query("
    SELECT f.name, COUNT(uf.user_id) AS active_users
    FROM fruits f
    LEFT JOIN user_fruits uf ON f.id = uf.fruit_id
    LEFT JOIN users u ON u.id = uf.user_id
    WHERE u.status='Active'
    GROUP BY f.id
");
while($row = $result->fetch_assoc()) {
    $activeUsersByFruit[$row['name']] = $row['active_users'];
}
?>

<div class="dashboard-main-body">
    <div class="d-flex flex-wrap align-items-center justify-content-between gap-3 mb-24">
        <h6 class="fw-semibold mb-0">Admin Dashboard</h6>
    </div>

    <!-- Statistics Cards -->
    <div class="row row-cols-1 row-cols-lg-2 row-cols-xxl-4 gy-4 mb-24">
        <div class="col">
            <div class="card shadow-none border h-100 p-20">
                <div class="d-flex align-items-center gap-3">
                    <div class="w-48-px h-48-px bg-primary-50 text-primary-600 rounded-circle d-flex justify-content-center align-items-center">
                        <iconify-icon icon="bi:people-fill" class="icon text-lg"></iconify-icon>
                    </div>
                    <div>
                        <h4 class="fw-semibold mb-0"><?php echo $users_count; ?></h4>
                        <span class="text-secondary-light">Total Users</span>
                    </div>
                </div>
            </div>
        </div>

        <div class="col">
            <div class="card shadow-none border h-100 p-20">
                <div class="d-flex align-items-center gap-3">
                    <div class="w-48-px h-48-px bg-success-50 text-success-600 rounded-circle d-flex justify-content-center align-items-center">
                        <iconify-icon icon="bi:file-text-fill" class="icon text-lg"></iconify-icon>
                    </div>
                    <div>
                        <h4 class="fw-semibold mb-0"><?php echo $blogs_count; ?></h4>
                        <span class="text-secondary-light">Approved Blogs</span>
                    </div>
                </div>
            </div>
        </div>

        <div class="col">
            <div class="card shadow-none border h-100 p-20">
                <div class="d-flex align-items-center gap-3">
                    <div class="w-48-px h-48-px bg-warning-50 text-warning-600 rounded-circle d-flex justify-content-center align-items-center">
                        <iconify-icon icon="bi:heart-fill" class="icon text-lg"></iconify-icon>
                    </div>
                    <div>
                        <h4 class="fw-semibold mb-0"><?php echo $prayers_count; ?></h4>
                        <span class="text-secondary-light">Prayer Requests</span>
                    </div>
                </div>
            </div>
        </div>

        <div class="col">
            <div class="card shadow-none border h-100 p-20">
                <div class="d-flex align-items-center gap-3">
                    <div class="w-48-px h-48-px bg-danger-50 text-danger-600 rounded-circle d-flex justify-content-center align-items-center">
                        <iconify-icon icon="bi:clock-fill" class="icon text-lg"></iconify-icon>
                    </div>
                    <div>
                        <h4 class="fw-semibold mb-0"><?php echo $pending_count; ?></h4>
                        <span class="text-secondary-light">Pending Approvals</span>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <!-- Content -->
    <div class="row gy-4">
        <div class="col-lg-8">
            <div class="card h-100">
                <div class="card-header bg-white">
                    <h6 class="fw-semibold mb-0">Recent Users</h6>
                </div>
                <div class="card-body">
                    <div class="table-responsive">
                        <table class="table table-hover">
                            <thead>
                                <tr>
                                    <th>Name</th>
                                    <th>Email</th>
                                    <th>Join Date</th>
                                </tr>
                            </thead>
                            <tbody>
                                <?php foreach ($recent_users as $user): ?>
                                <tr>
                                    <td><?php echo htmlspecialchars($user['name']); ?></td>
                                    <td><?php echo htmlspecialchars($user['email']); ?></td>
                                    <td><?php echo date('M j, Y', strtotime($user['join_date'])); ?></td>
                                </tr>
                                <?php endforeach; ?>
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>
        </div>
        
        <div class="col-lg-4">
            <div class="card h-100">
                <div class="card-header bg-white">
                    <h6 class="fw-semibold mb-0">Active Users by Fruit</h6>
                </div>
                <div class="card-body">
                    <ul class="list-group list-group-flush">
                        <?php foreach($activeUsersByFruit as $fruit => $count): ?>
                        <li class="list-group-item d-flex justify-content-between align-items-center">
                            <?= htmlspecialchars($fruit) ?>
                            <span class="badge bg-primary rounded-pill"><?= $count ?></span>
                        </li>
                        <?php endforeach; ?>
                    </ul>
                </div>
            </div>
            
            <div class="card mt-4">
                <div class="card-header bg-white">
                    <h6 class="fw-semibold mb-0">Quick Actions</h6>
                </div>
                <div class="card-body">
                    <div class="d-grid gap-2">
                        <a href="admin-users.php" class="btn btn-outline-primary text-start">
                            <iconify-icon icon="bi:people" class="icon me-2"></iconify-icon> Manage Users
                        </a>
                        <a href="admin-blogs.php" class="btn btn-outline-success text-start">
                            <iconify-icon icon="bi:file-text" class="icon me-2"></iconify-icon> Manage Blogs
                        </a>
                        <a href="admin-prayers.php" class="btn btn-outline-warning text-start">
                            <iconify-icon icon="bi:heart" class="icon me-2"></iconify-icon> Prayer Requests
                        </a>
                    </div>
                </div>
            </div>
        </div>
    </div>
</div>

<?php include './partials/layouts/layoutBottom.php'; ?>