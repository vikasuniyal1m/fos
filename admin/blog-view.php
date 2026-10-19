<?php
include './includes/db.php';
include './partials/layouts/layoutTop.php';

$id = $_GET['id'] ?? 0;
$id = (int)$id;

$sql = "SELECT b.*, u.name AS author 
        FROM blogs b 
        LEFT JOIN users u ON b.user_id = u.id 
        WHERE b.id=$id LIMIT 1";

$result = $conn->query($sql);
$blog = $result && $result->num_rows > 0 ? $result->fetch_assoc() : null;
?>

<div class="dashboard-main-body">
    <div class="d-flex flex-wrap align-items-center justify-content-between gap-3 mb-24">
        <h6 class="fw-semibold mb-0">Blog Details</h6>
        <ul class="d-flex align-items-center gap-2">
            <li class="fw-medium">
                <a href="blogs-grid.php" class="d-flex align-items-center gap-1 hover-text-primary">
                    <iconify-icon icon="solar:home-smile-angle-outline" class="icon text-lg"></iconify-icon>
                    Blogs Grid
                </a>
            </li>
            <li>-</li>
            <li class="fw-medium">Blog Details</li>
        </ul>
    </div>

    <div class="card h-100 p-0 radius-12">
        <div class="card-body p-24">
            <?php if ($blog): ?>
                <h3 class="fw-bold mb-3"><?= htmlspecialchars($blog['title']) ?></h3>
                <div class="mb-3 text-muted">
                    <span>By <?= htmlspecialchars($blog['author'] ?? "Unknown") ?></span> |
                    <span><?= date("d M Y", strtotime($blog['created_at'])) ?></span> |
                    <span>Status: <?= htmlspecialchars($blog['status']) ?></span>
                </div>

                <?php if (!empty($blog['image_url'])): ?>
                    <?php $extension = strtolower(pathinfo($blog['image_url'], PATHINFO_EXTENSION)); ?>
                    <?php $videoExtensions = ['mp4', 'mov', 'avi', 'wmv', 'flv', 'webm']; ?>
                    <?php $isVideo = in_array($extension, $videoExtensions); ?>
                    <div class="mb-3">
                        <span class="badge bg-secondary"><?= $isVideo ? 'Featured Video' : 'Featured Image' ?></span>
                    </div>
                    <?php if ($isVideo): ?>
                        <video controls class="w-100 mb-3 radius-12">
                            <source src="<?= htmlspecialchars($blog['image_url']) ?>" type="video/<?= htmlspecialchars($extension) ?>">
                            Your browser does not support the video tag.
                        </video>
                    <?php else: ?>
                        <img src="<?= htmlspecialchars($blog['image_url']) ?>" 
                             alt="Blog Image" 
                             class="img-fluid mb-3 radius-12">
                    <?php endif; ?>
                <?php endif; ?>

                <div class="blog-content text-md">
                    <?= nl2br(htmlspecialchars($blog['body'])) ?>
                </div>
            <?php else: ?>
                <p class="text-danger">Blog not found.</p>
            <?php endif; ?>
        </div>
    </div>
</div>

<?php include './partials/layouts/layoutBottom.php'; ?>
