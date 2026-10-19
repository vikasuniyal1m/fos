<?php 
include './includes/db.php';
include './includes/admin-auth.php';
include './partials/layouts/layoutTop.php';

// Fetch all tags dynamically from media_items
$tagQuery = "SELECT DISTINCT fruit_tag FROM media_items";
$tagResult = $conn->query($tagQuery);

$tags = ['All']; // Default tab
while ($row = $tagResult->fetch_assoc()) {
    if ($row['fruit_tag']) $tags[] = $row['fruit_tag'];
}

// Fetch media with user info
$mediaQuery = "
    SELECT m.*, u.name AS user_name
    FROM media_items m
    LEFT JOIN users u ON m.user_id = u.id
    ORDER BY m.created_at DESC
";
$mediaResult = $conn->query($mediaQuery);

// Organize media by tag
$mediaByTag = [];
while ($media = $mediaResult->fetch_assoc()) {
    $tag = $media['fruit_tag'] ?? 'Others';
    $mediaByTag[$tag][] = $media;
    $mediaByTag['All'][] = $media; // Also store for 'All' tab
}
?>

<div class="dashboard-main-body">
    <div class="d-flex flex-wrap align-items-center justify-content-between gap-3 mb-24">
        <h6 class="fw-semibold mb-0">Media</h6>
        <ul class="d-flex align-items-center gap-2">
            <li class="fw-medium">
                <a href="index.php" class="d-flex align-items-center gap-1 hover-text-primary">
                    <iconify-icon icon="solar:home-smile-angle-outline" class="icon text-lg"></iconify-icon>
                    Dashboard
                </a>
            </li>
            <li>-</li>
            <li class="fw-medium">Media</li>
        </ul>
    </div>

    <div class="card h-100 p-0 radius-12 overflow-hidden">
        <div class="card-header border-bottom-0 pb-0 pt-0 px-0">
            <ul class="nav border-gradient-tab nav-pills mb-0 border-top-0" id="pills-tab" role="tablist">
                <?php foreach($tags as $i => $tag): ?>
                    <li class="nav-item" role="presentation">
                        <button class="nav-link <?= $i==0?'active':'' ?>" id="pills-<?= strtolower(str_replace(' ', '-', $tag)) ?>-tab" data-bs-toggle="pill" data-bs-target="#pills-<?= strtolower(str_replace(' ', '-', $tag)) ?>" type="button" role="tab" aria-controls="pills-<?= strtolower(str_replace(' ', '-', $tag)) ?>" aria-selected="<?= $i==0?'true':'false' ?>">
                            <?= $tag ?>
                        </button>
                    </li>
                <?php endforeach; ?>
            </ul>
        </div>
        <div class="card-body p-24">
            <div class="tab-content" id="pills-tabContent">
                <?php foreach($tags as $i => $tag): ?>
                    <div class="tab-pane fade <?= $i==0?'show active':'' ?>" id="pills-<?= strtolower(str_replace(' ', '-', $tag)) ?>" role="tabpanel" aria-labelledby="pills-<?= strtolower(str_replace(' ', '-', $tag)) ?>-tab">
                        <div class="row gy-4">
                            <?php if(isset($mediaByTag[$tag])): ?>
                                <?php foreach($mediaByTag[$tag] as $media): ?>
                                    <div class="col-xxl-3 col-md-4 col-sm-6">
                                        <a href="media_detail.php?id=<?= $media['id'] ?>" class="text-decoration-none">
                                            <div class="hover-scale-img border radius-16 overflow-hidden">
                                                <div class="max-h-266-px overflow-hidden">
                                                    <?php if($media['type'] == 'photo'): ?>
                                                        <img src="<?= $media['file_path'] ?>" alt="" class="hover-scale-img__img w-100 h-100 object-fit-cover">
                                                    <?php else: ?>
                                                        <video class="w-100 h-100 object-fit-cover" controls>
                                                            <source src="<?= $media['file_path'] ?>" type="video/mp4">
                                                            Your browser does not support the video tag.
                                                        </video>
                                                    <?php endif; ?>
                                                </div>
                                                <div class="py-16 px-24">
                                                    <h6 class="mb-4"><?= htmlspecialchars($media['fruit_tag'] ?? 'No Tag') ?></h6>
                                                    <p class="mb-0 text-sm text-secondary-light">
                                                        Uploaded by: <?= htmlspecialchars($media['user_name']) ?> <br>
                                                        <?= date('d M Y', strtotime($media['created_at'])) ?>
                                                    </p>
                                                </div>
                                            </div>
                                        </a>
                                    </div>
                                <?php endforeach; ?>
                            <?php else: ?>
                                <p class="text-center">No media found in this category.</p>
                            <?php endif; ?>
                        </div>
                    </div>
                <?php endforeach; ?>
            </div>
        </div>
    </div>
</div>

<?php include './partials/layouts/layoutBottom.php'; ?>
