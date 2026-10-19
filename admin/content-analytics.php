<?php
include './includes/db.php';
include './includes/admin-auth.php';
include './partials/layouts/layoutTop.php';

// Get content statistics
$totalBlogs = $conn->query("SELECT COUNT(*) as count FROM blogs")->fetch_assoc()['count'];
$approvedBlogs = $conn->query("SELECT COUNT(*) as count FROM blogs WHERE status='Approved'")->fetch_assoc()['count'];
$totalPrayers = $conn->query("SELECT COUNT(*) as count FROM prayer_requests")->fetch_assoc()['count'];
$totalComments = $conn->query("SELECT COUNT(*) as count FROM comments")->fetch_assoc()['count'];
$totalMedia = $conn->query("SELECT COUNT(*) as count FROM media_items")->fetch_assoc()['count'];

// Content growth data (last 6 months) - FIXED QUERY
$contentGrowth = $conn->query("
    SELECT 
        DATE_FORMAT(created_at, '%Y-%m') as month,
        COUNT(*) as blogs,
        0 as prayers,
        0 as media
    FROM blogs
    WHERE created_at >= DATE_SUB(NOW(), INTERVAL 6 MONTH)
    GROUP BY DATE_FORMAT(created_at, '%Y-%m')
    
    UNION ALL
    
    SELECT 
        DATE_FORMAT(created_at, '%Y-%m') as month,
        0 as blogs,
        COUNT(*) as prayers,
        0 as media
    FROM prayer_requests
    WHERE created_at >= DATE_SUB(NOW(), INTERVAL 6 MONTH)
    GROUP BY DATE_FORMAT(created_at, '%Y-%m')
    
    UNION ALL
    
    SELECT 
        DATE_FORMAT(created_at, '%Y-%m') as month,
        0 as blogs,
        0 as prayers,
        COUNT(*) as media
    FROM media_items
    WHERE created_at >= DATE_SUB(NOW(), INTERVAL 6 MONTH)
    GROUP BY DATE_FORMAT(created_at, '%Y-%m')
    ORDER BY month
");

// Process growth data
$growthData = [];
while ($row = $contentGrowth->fetch_assoc()) {
    $month = $row['month'];
    if (!isset($growthData[$month])) {
        $growthData[$month] = [
            'blogs' => 0,
            'prayers' => 0,
            'media' => 0
        ];
    }
    $growthData[$month]['blogs'] += $row['blogs'];
    $growthData[$month]['prayers'] += $row['prayers'];
    $growthData[$month]['media'] += $row['media'];
}

// Sort by month and prepare chart data
ksort($growthData);
$growthLabels = [];
$blogData = [];
$prayerData = [];
$mediaData = [];

foreach ($growthData as $month => $data) {
    $growthLabels[] = date('M Y', strtotime($month . '-01'));
    $blogData[] = $data['blogs'];
    $prayerData[] = $data['prayers'];
    $mediaData[] = $data['media'];
}

// Most active bloggers
$topBloggers = $conn->query("
    SELECT u.name, COUNT(b.id) as blog_count
    FROM users u
    JOIN blogs b ON u.id = b.user_id
    WHERE b.status = 'Approved'
    GROUP BY u.id
    ORDER BY blog_count DESC
    LIMIT 5
");

// Popular prayer categories
$prayerCategories = $conn->query("
    SELECT category, COUNT(*) as count
    FROM prayer_requests
    WHERE status = 'Approved'
    GROUP BY category
    ORDER BY count DESC
");

// Content engagement (likes, comments, etc.)
$engagementStats = $conn->query("
    SELECT 
        (SELECT COUNT(*) FROM blog_likes) as blog_likes,
        (SELECT COUNT(*) FROM blog_comments) as blog_comments,
        (SELECT COUNT(*) FROM comments WHERE post_type = 'prayer') as prayer_comments,
        (SELECT COUNT(*) FROM user_emoji_usage) as emoji_usage
")->fetch_assoc();
?>

<div class="dashboard-main-body">
    <div class="d-flex flex-wrap align-items-center justify-content-between gap-3 mb-24">
        <h6 class="fw-semibold mb-0">Content Analytics</h6>
        <ul class="d-flex align-items-center gap-2">
            <li class="fw-medium">
                <a href="index.php" class="d-flex align-items-center gap-1 hover-text-primary">
                    <iconify-icon icon="solar:home-smile-angle-outline" class="icon text-lg"></iconify-icon>
                    Dashboard
                </a>
            </li>
            <li>-</li>
            <li class="fw-medium">Content Analytics</li>
        </ul>
    </div>

    <!-- Stats Cards with Light Colors -->
    <div class="row row-cols-1 row-cols-md-2 row-cols-lg-5 g-4 mb-24">
        <div class="col">
            <div class="card border-primary">
                <div class="card-body text-center">
                    <h2 class="mb-1 text-primary"><?php echo $totalBlogs; ?></h2>
                    <small class="text-muted">Total Blogs</small>
                </div>
            </div>
        </div>
        <div class="col">
            <div class="card border-success">
                <div class="card-body text-center">
                    <h2 class="mb-1 text-success"><?php echo $approvedBlogs; ?></h2>
                    <small class="text-muted">Approved Blogs</small>
                </div>
            </div>
        </div>
        <div class="col">
            <div class="card border-info">
                <div class="card-body text-center">
                    <h2 class="mb-1 text-info"><?php echo $totalPrayers; ?></h2>
                    <small class="text-muted">Prayer Requests</small>
                </div>
            </div>
        </div>
        <div class="col">
            <div class="card border-warning">
                <div class="card-body text-center">
                    <h2 class="mb-1 text-warning"><?php echo $totalComments; ?></h2>
                    <small class="text-muted">Total Comments</small>
                </div>
            </div>
        </div>
        <div class="col">
            <div class="card border-secondary">
                <div class="card-body text-center">
                    <h2 class="mb-1 text-secondary"><?php echo $totalMedia; ?></h2>
                    <small class="text-muted">Media Items</small>
                </div>
            </div>
        </div>
    </div>

    <!-- Content Growth Chart -->
    <div class="row">
        <div class="col-12">
            <div class="card h-100">
                <div class="card-body">
                    <h6 class="fw-semibold mb-16">Content Growth (Last 6 Months)</h6>
                    <div style="height: 300px; position: relative;">
                        <canvas id="contentGrowthChart"></canvas>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <!-- Additional Analytics -->
    <div class="row mt-4">
        <div class="col-md-6">
            <div class="card h-100">
                <div class="card-body">
                    <h6 class="fw-semibold mb-16">Top Bloggers</h6>
                    <div class="table-responsive">
                        <table class="table table-sm">
                            <thead>
                                <tr>
                                    <th>Blogger</th>
                                    <th>Blogs</th>
                                </tr>
                            </thead>
                            <tbody>
                                <?php if ($topBloggers->num_rows > 0): ?>
                                    <?php while ($blogger = $topBloggers->fetch_assoc()): ?>
                                        <tr>
                                            <td><?php echo htmlspecialchars($blogger['name']); ?></td>
                                            <td>
                                                <span class="badge bg-light text-primary border"><?php echo $blogger['blog_count']; ?></span>
                                            </td>
                                        </tr>
                                    <?php endwhile; ?>
                                <?php else: ?>
                                    <tr>
                                        <td colspan="2" class="text-center text-muted">No bloggers found</td>
                                    </tr>
                                <?php endif; ?>
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>
        </div>
        
        <div class="col-md-6">
            <div class="card h-100">
                <div class="card-body">
                    <h6 class="fw-semibold mb-16">Popular Prayer Categories</h6>
                    <div class="table-responsive">
                        <table class="table table-sm">
                            <thead>
                                <tr>
                                    <th>Category</th>
                                    <th>Requests</th>
                                </tr>
                            </thead>
                            <tbody>
                                <?php if ($prayerCategories->num_rows > 0): ?>
                                    <?php while ($category = $prayerCategories->fetch_assoc()): ?>
                                        <tr>
                                            <td><?php echo htmlspecialchars($category['category']); ?></td>
                                            <td>
                                                <span class="badge bg-light text-info border"><?php echo $category['count']; ?></span>
                                            </td>
                                        </tr>
                                    <?php endwhile; ?>
                                <?php else: ?>
                                    <tr>
                                        <td colspan="2" class="text-center text-muted">No prayer categories found</td>
                                    </tr>
                                <?php endif; ?>
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <!-- Engagement Stats -->
    <div class="row mt-4">
        <div class="col-12">
            <div class="card">
                <div class="card-body">
                    <h6 class="fw-semibold mb-16">Engagement Statistics</h6>
                    <div class="row text-center">
                        <div class="col-3">
                            <h4 class="text-primary"><?php echo $engagementStats['blog_likes']; ?></h4>
                            <small class="text-muted">Blog Likes</small>
                        </div>
                        <div class="col-3">
                            <h4 class="text-success"><?php echo $engagementStats['blog_comments']; ?></h4>
                            <small class="text-muted">Blog Comments</small>
                        </div>
                        <div class="col-3">
                            <h4 class="text-info"><?php echo $engagementStats['prayer_comments']; ?></h4>
                            <small class="text-muted">Prayer Comments</small>
                        </div>
                        <div class="col-3">
                            <h4 class="text-warning"><?php echo $engagementStats['emoji_usage']; ?></h4>
                            <small class="text-muted">Emoji Reactions</small>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
</div>

<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
<script>
// Wait for DOM to be fully loaded
document.addEventListener('DOMContentLoaded', function() {
    // Content Growth Chart with light colors
    const contentCtx = document.getElementById('contentGrowthChart').getContext('2d');
    new Chart(contentCtx, {
        type: 'bar',
        data: {
            labels: <?php echo json_encode($growthLabels); ?>,
            datasets: [
                {
                    label: 'Blogs',
                    data: <?php echo json_encode($blogData); ?>,
                    backgroundColor: 'rgba(100, 149, 237, 0.3)', // Light cornflower blue
                    borderColor: 'rgba(100, 149, 237, 1)',
                    borderWidth: 1
                },
                {
                    label: 'Prayers',
                    data: <?php echo json_encode($prayerData); ?>,
                    backgroundColor: 'rgba(144, 238, 144, 0.3)', // Light green
                    borderColor: 'rgba(144, 238, 144, 1)',
                    borderWidth: 1
                },
                {
                    label: 'Media',
                    data: <?php echo json_encode($mediaData); ?>,
                    backgroundColor: 'rgba(255, 182, 193, 0.3)', // Light pink
                    borderColor: 'rgba(255, 182, 193, 1)',
                    borderWidth: 1
                }
            ]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            scales: {
                x: {
                    grid: {
                        display: false
                    }
                },
                y: {
                    beginAtZero: true,
                    ticks: {
                        stepSize: 1
                    },
                    grid: {
                        color: 'rgba(0, 0, 0, 0.05)'
                    }
                }
            },
            plugins: {
                legend: {
                    position: 'top',
                }
            }
        }
    });
});
</script>

<style>
.dashboard-main-body {
    overflow: hidden;
}

.card {
    border: 1px solid #e0e0e0;
    border-radius: 8px;
    background: #fff;
}

#contentGrowthChart {
    width: 100% !important;
    height: 300px !important;
}

.table-responsive {
    max-height: 300px;
    overflow-y: auto;
}

.badge.bg-light {
    background-color: #f8f9fa !important;
    border: 1px solid #dee2e6;
}

.stats-card {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
}
</style>

<?php include './partials/layouts/layoutBottom.php'; ?>