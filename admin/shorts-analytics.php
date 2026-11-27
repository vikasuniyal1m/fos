<?php
include './includes/db.php';
include './includes/admin-auth.php';
include './partials/layouts/layoutTop.php';

$stats = [
    'total_shorts' => 0,
    'total_views' => 0,
    'total_likes' => 0,
    'total_comments' => 0,
    'total_shares' => 0,
    'total_saves' => 0,
];

$res = @$conn->query("SHOW TABLES LIKE 'shorts'");
if ($res && $res->num_rows > 0) {
    $queries = [
        'total_shorts' => "SELECT COUNT(*) AS c FROM shorts WHERE deleted_at IS NULL",
        'total_views' => "SELECT COALESCE(SUM(total_views),0) AS c FROM shorts",
        'total_likes' => "SELECT COALESCE(SUM(total_likes),0) AS c FROM shorts",
        'total_comments' => "SELECT COALESCE(SUM(total_comments),0) AS c FROM shorts",
        'total_shares' => "SELECT COALESCE(SUM(total_shares),0) AS c FROM shorts",
        'total_saves' => "SELECT COALESCE(SUM(total_saves),0) AS c FROM shorts",
    ];
    foreach ($queries as $key => $sql) {
        $r = $conn->query($sql);
        if ($r) $stats[$key] = intval($r->fetch_assoc()['c']);
    }
}
?>

<div class="dashboard-main-body">
    <div class="d-flex flex-wrap align-items-center justify-content-between gap-3 mb-24">
        <h6 class="fw-semibold mb-0">Shorts Analytics</h6>
        <a href="shorts-moderation.php" class="btn btn-sm btn-outline-primary">Back to Shorts</a>
    </div>

    <div class="row g-3">
        <?php
        $cards = [
            ['label' => 'Total Shorts', 'value' => $stats['total_shorts'], 'icon' => 'mdi:video-outline', 'color' => 'primary'],
            ['label' => 'Total Views', 'value' => number_format($stats['total_views']), 'icon' => 'mdi:eye-outline', 'color' => 'info'],
            ['label' => 'Total Likes', 'value' => number_format($stats['total_likes']), 'icon' => 'mdi:heart-outline', 'color' => 'danger'],
            ['label' => 'Total Comments', 'value' => number_format($stats['total_comments']), 'icon' => 'mdi:comment-outline', 'color' => 'warning'],
            ['label' => 'Total Shares', 'value' => number_format($stats['total_shares']), 'icon' => 'mdi:share-outline', 'color' => 'success'],
            ['label' => 'Total Saves', 'value' => number_format($stats['total_saves']), 'icon' => 'mdi:bookmark-outline', 'color' => 'secondary'],
        ];
        foreach ($cards as $card):
        ?>
        <div class="col-md-4 col-sm-6">
            <div class="card p-24 radius-12">
                <div class="d-flex align-items-center gap-3">
                    <div class="w-48-px h-48-px bg-<?= $card['color'] ?>-100 text-<?= $card['color'] ?>-600 d-flex justify-content-center align-items-center rounded-circle">
                        <iconify-icon icon="<?= $card['icon'] ?>" class="text-xl"></iconify-icon>
                    </div>
                    <div>
                        <p class="text-secondary-light mb-4"><?= $card['label'] ?></p>
                        <h5 class="mb-0"><?= $card['value'] ?></h5>
                    </div>
                </div>
            </div>
        </div>
        <?php endforeach; ?>
    </div>
</div>

<?php include './partials/layouts/layoutBottom.php'; ?>
