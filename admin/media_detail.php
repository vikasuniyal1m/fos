<?php
include './partials/layouts/layoutTop.php';
include './includes/db.php';

$media_id = $_GET['id'] ?? 0;
if(!$media_id) {
    die("Invalid media ID");
}

// Fetch media with user info
$stmt = $conn->prepare("
    SELECT m.*, u.name AS user_name, u.email, u.role, u.status AS user_status, u.join_date
    FROM media_items m
    LEFT JOIN users u ON m.user_id = u.id
    WHERE m.id = ?
");
$stmt->bind_param("i", $media_id);
$stmt->execute();
$result = $stmt->get_result();
$media = $result->fetch_assoc();

if(!$media) {
    die("Media not found");
}

// Handle action buttons
if($_SERVER['REQUEST_METHOD'] === 'POST') {
    $action = $_POST['action'];
    if($action === 'approve') {
        $conn->query("UPDATE media_items SET status='Approved' WHERE id=".$media_id);
        $media['status'] = 'Approved';
    } elseif($action === 'reject') {
        $conn->query("UPDATE media_items SET status='Rejected' WHERE id=".$media_id);
        $media['status'] = 'Rejected';
    } elseif($action === 'block_user') {
        $conn->query("UPDATE users SET status='Inactive' WHERE id=".$media['user_id']);
        $media['user_status'] = 'Inactive';
    }
}
?>

<div class="dashboard-main-body p-24">
    <h4>Media Detail</h4>
    <div class="card radius-12 p-24 mt-3">
        <div class="media-preview mb-4">
            <?php if($media['type'] == 'photo'): ?>
                <img src="<?= $media['file_path'] ?>" alt="" class="w-100">
            <?php else: ?>
                <video class="w-100" controls>
                    <source src="<?= $media['file_path'] ?>" type="video/mp4">
                </video>
            <?php endif; ?>
        </div>

        <div class="media-info mb-4">
            <p><strong>Fruit Tag:</strong> <?= htmlspecialchars($media['fruit_tag']) ?></p>
            <p><strong>Status:</strong> <?= $media['status'] ?></p>
            <p><strong>Uploaded On:</strong> <?= date('d M Y', strtotime($media['created_at'])) ?></p>
            <hr>
            <h5>User Details</h5>
            <p><strong>Name:</strong> <?= htmlspecialchars($media['user_name']) ?></p>
            <p><strong>Email:</strong> <?= htmlspecialchars($media['email']) ?></p>
            <p><strong>Role:</strong> <?= $media['role'] ?></p>
            <p><strong>Status:</strong> <?= $media['user_status'] ?></p>
            <p><strong>Join Date:</strong> <?= date('d M Y', strtotime($media['join_date'])) ?></p>
        </div>

        <form method="post">
            <button type="submit" name="action" value="approve" class="btn btn-success me-2">Approve</button>
            <button type="submit" name="action" value="reject" class="btn btn-danger me-2">Reject</button>
            <button type="submit" name="action" value="block_user" class="btn btn-warning">Block User</button>
        </form>
    </div>
</div>

<?php include './partials/layouts/layoutBottom.php'; ?>
