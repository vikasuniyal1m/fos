<?php
// Include admin authentication
include './includes/admin-auth.php';

include './includes/db.php';
include './partials/layouts/layoutTop.php';

// -----------------------------
// 1. Active Users per Fruit Category
// -----------------------------
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

// -----------------------------
// 2. Top Emojis Used (Updated to only use emojis table)
// -----------------------------
$topEmojis = [];
$result = $conn->query("
    SELECT name, image_url, usage_count 
    FROM emojis 
    WHERE status = 'Active'
    ORDER BY usage_count DESC 
    LIMIT 10
");
while($row = $result->fetch_assoc()) {
    $topEmojis[] = [
        'name' => $row['name'],
        'image_url' => $row['image_url'],
        'usage_count' => $row['usage_count']
    ];
}

// -----------------------------
// 3. Engagement Stats
// -----------------------------
$engagementStats = [];
$engagementStats['blogs'] = $conn->query("SELECT COUNT(*) FROM blogs")->fetch_row()[0];
$engagementStats['videos'] = $conn->query("SELECT COUNT(*) FROM media_items WHERE type='video'")->fetch_row()[0];
$engagementStats['photos'] = $conn->query("SELECT COUNT(*) FROM media_items WHERE type='photo'")->fetch_row()[0];
$engagementStats['prayers'] = $conn->query("SELECT COUNT(*) FROM prayer_requests")->fetch_row()[0];
$engagementStats['comments'] = $conn->query("SELECT COUNT(*) FROM comments")->fetch_row()[0];
$engagementStats['users'] = $conn->query("SELECT COUNT(*) FROM users")->fetch_row()[0];
$engagementStats['emojis'] = $conn->query("SELECT COUNT(*) FROM emojis WHERE status='Active'")->fetch_row()[0];

// -----------------------------
// 4. Quick Stats
// -----------------------------
$quickStats = [];
$quickStats['total_users'] = $conn->query("SELECT COUNT(*) FROM users")->fetch_row()[0];
$quickStats['active_users'] = $conn->query("SELECT COUNT(*) FROM users WHERE status='Active'")->fetch_row()[0];
$quickStats['new_today'] = $conn->query("SELECT COUNT(*) FROM users WHERE DATE(join_date) = CURDATE()")->fetch_row()[0];
$quickStats['total_emojis'] = $conn->query("SELECT COUNT(*) FROM emojis WHERE status='Active'")->fetch_row()[0];

// -----------------------------
// 5. User Growth for Chart (last 6 months)
// -----------------------------
$userGrowth = [];
$result = $conn->query("
    SELECT DATE_FORMAT(join_date,'%Y-%m') as month, 
           COUNT(*) as users 
    FROM users 
    WHERE join_date >= DATE_SUB(NOW(), INTERVAL 6 MONTH)
    GROUP BY DATE_FORMAT(join_date,'%Y-%m')
    ORDER BY month ASC
");
while($row = $result->fetch_assoc()) {
    $userGrowth[date('M Y', strtotime($row['month'] . '-01'))] = (int)$row['users'];
}

// If no data, create sample data for demo
if(empty($userGrowth)) {
    $userGrowth = [
        'Jan 2024' => 15,
        'Feb 2024' => 28,
        'Mar 2024' => 42,
        'Apr 2024' => 35,
        'May 2024' => 50,
        'Jun 2024' => 65
    ];
}

// -----------------------------
// 6. Content Engagement Chart (last 6 months)
// -----------------------------
$contentGrowth = [];
$result = $conn->query("
    SELECT 
        DATE_FORMAT(created_at,'%Y-%m') as month,
        SUM(type = 'blog') as blogs,
        SUM(type = 'video') as videos,
        SUM(type = 'photo') as photos
    FROM (
        SELECT created_at, 'blog' as type FROM blogs
        UNION ALL 
        SELECT created_at, 'video' as type FROM media_items WHERE type='video'
        UNION ALL 
        SELECT created_at, 'photo' as type FROM media_items WHERE type='photo'
    ) as content
    WHERE created_at >= DATE_SUB(NOW(), INTERVAL 6 MONTH)
    GROUP BY DATE_FORMAT(created_at,'%Y-%m')
    ORDER BY month ASC
");

while($row = $result->fetch_assoc()) {
    $monthKey = date('M Y', strtotime($row['month'] . '-01'));
    $contentGrowth[$monthKey] = [
        'blogs' => (int)$row['blogs'],
        'videos' => (int)$row['videos'],
        'photos' => (int)$row['photos']
    ];
}

// If no data, create sample data for demo
if(empty($contentGrowth)) {
    $contentGrowth = [
        'Jan 2024' => ['blogs' => 12, 'videos' => 8, 'photos' => 15],
        'Feb 2024' => ['blogs' => 18, 'videos' => 12, 'photos' => 22],
        'Mar 2024' => ['blogs' => 25, 'videos' => 15, 'photos' => 30],
        'Apr 2024' => ['blogs' => 22, 'videos' => 18, 'photos' => 28],
        'May 2024' => ['blogs' => 30, 'videos' => 20, 'photos' => 35],
        'Jun 2024' => ['blogs' => 35, 'videos' => 25, 'photos' => 40]
    ];
}

// -----------------------------
// 7. Recent Activity
// -----------------------------
$recentActivity = $conn->query("
    (SELECT 'blog' as type, title as content, created_at, user_id FROM blogs ORDER BY created_at DESC LIMIT 3)
    UNION ALL
    (SELECT 'prayer' as type, 
            CONCAT(SUBSTRING(content, 1, 50), '...') as content, 
            created_at, 
            user_id 
     FROM prayer_requests 
     ORDER BY created_at DESC LIMIT 3)
    UNION ALL
    (SELECT 'media' as type, 
            CONCAT(type, ' - ', COALESCE(fruit_tag, 'No tag')) as content, 
            created_at, 
            user_id 
     FROM media_items 
     ORDER BY created_at DESC LIMIT 2)
    ORDER BY created_at DESC 
    LIMIT 5
");

// -----------------------------
// 8. Blog Status Distribution
// -----------------------------
$blogStatus = [];
$result = $conn->query("
    SELECT status, COUNT(*) as count 
    FROM blogs 
    GROUP BY status
");
while($row = $result->fetch_assoc()) {
    $blogStatus[$row['status']] = $row['count'];
}

// -----------------------------
// 9. Prayer Categories
// -----------------------------
$prayerCategories = [];
$result = $conn->query("
    SELECT category, COUNT(*) as count 
    FROM prayer_requests 
    GROUP BY category
");
while($row = $result->fetch_assoc()) {
    $prayerCategories[$row['category']] = $row['count'];
}

// -----------------------------
// 10. Emoji Categories Distribution
// -----------------------------
$emojiCategories = [];
$result = $conn->query("
    SELECT category, COUNT(*) as count 
    FROM emojis 
    WHERE status = 'Active'
    GROUP BY category
");
while($row = $result->fetch_assoc()) {
    $emojiCategories[$row['category']] = $row['count'];
}
?>

<div class="dashboard-main-body">
    <div class="d-flex flex-wrap align-items-center justify-content-between gap-3 mb-24">
        <h4 class="fw-bold mb-0 text-primary">Dashboard</h4>
        <div class="d-flex gap-2">
            <button class="btn btn-outline-primary btn-sm" onclick="refreshDashboard()">
                <iconify-icon icon="mdi:refresh" class="me-1"></iconify-icon>
                Refresh
            </button>
            <div class="dropdown">
                <button class="btn btn-outline-secondary btn-sm dropdown-toggle" type="button" data-bs-toggle="dropdown">
                    <iconify-icon icon="mdi:filter" class="me-1"></iconify-icon>
                    Filter
                </button>
                <ul class="dropdown-menu">
                    <li><a class="dropdown-item" href="#" onclick="filterData('7days')">Last 7 Days</a></li>
                    <li><a class="dropdown-item" href="#" onclick="filterData('30days')">Last 30 Days</a></li>
                    <li><a class="dropdown-item" href="#" onclick="filterData('6months')">Last 6 Months</a></li>
                </ul>
            </div>
        </div>
    </div>

    <!-- Overview Stats -->
    <div class="row mb-24">
        <div class="col-12">
            <div class="card">
                <div class="card-header bg-transparent border-bottom-0 py-3">
                    <h6 class="fw-semibold mb-0">Overview</h6>
                </div>
                <div class="card-body">
                    <div class="row text-center">
                        <div class="col-6 col-md-4 col-lg-2 mb-3">
                            <div class="p-3 rounded bg-light stat-card hover-lift">
                                <h4 class="text-primary mb-1"><?= $engagementStats['blogs'] ?></h4>
                                <small class="text-muted">Blogs</small>
                            </div>
                        </div>
                        <div class="col-6 col-md-4 col-lg-2 mb-3">
                            <div class="p-3 rounded bg-light stat-card hover-lift">
                                <h4 class="text-success mb-1"><?= $engagementStats['videos'] ?></h4>
                                <small class="text-muted">Videos</small>
                            </div>
                        </div>
                        <div class="col-6 col-md-4 col-lg-2 mb-3">
                            <div class="p-3 rounded bg-light stat-card hover-lift">
                                <h4 class="text-info mb-1"><?= $engagementStats['photos'] ?></h4>
                                <small class="text-muted">Photos</small>
                            </div>
                        </div>
                        <div class="col-6 col-md-4 col-lg-2 mb-3">
                            <div class="p-3 rounded bg-light stat-card hover-lift">
                                <h4 class="text-warning mb-1"><?= $engagementStats['prayers'] ?></h4>
                                <small class="text-muted">Prayers</small>
                            </div>
                        </div>
                        <div class="col-6 col-md-4 col-lg-2 mb-3">
                            <div class="p-3 rounded bg-light stat-card hover-lift">
                                <h4 class="text-danger mb-1"><?= $engagementStats['comments'] ?></h4>
                                <small class="text-muted">Comments</small>
                            </div>
                        </div>
                        <div class="col-6 col-md-4 col-lg-2 mb-3">
                            <div class="p-3 rounded bg-light stat-card hover-lift">
                                <h4 class="text-secondary mb-1"><?= $engagementStats['emojis'] ?></h4>
                                <small class="text-muted">Emojis</small>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <!-- Four Column Cards -->
    <div class="row row-cols-1 row-cols-lg-2 row-cols-xxl-4 gy-4 mb-24">
        <!-- Active Users per Fruit -->
        <div class="col">
            <div class="card border h-100">
                <div class="card-header bg-transparent border-bottom-0 py-3">
                    <h6 class="fw-semibold mb-0 d-flex align-items-center">
                        <iconify-icon icon="mdi:fruit-cherries" class="text-primary me-2"></iconify-icon>
                        Active Users by Fruit
                    </h6>
                </div>
                <div class="card-body p-3">
                    <ul class="list-group list-group-flush">
                        <?php foreach($activeUsersByFruit as $fruit => $count): ?>
                        <li class="list-group-item d-flex justify-content-between align-items-center border-0 px-0 py-2">
                            <span class="text-muted d-flex align-items-center">
                                <iconify-icon icon="mdi:circle-small" class="text-primary me-2"></iconify-icon>
                                <?= htmlspecialchars($fruit) ?>
                            </span>
                            <span class="badge bg-light text-primary border rounded-pill"><?= $count ?></span>
                        </li>
                        <?php endforeach; ?>
                    </ul>
                </div>
            </div>
        </div>

        <!-- Top Emojis -->
        <div class="col">
            <div class="card border h-100">
                <div class="card-header bg-transparent border-bottom-0 py-3">
                    <h6 class="fw-semibold mb-0 d-flex align-items-center">
                        <iconify-icon icon="mdi:emoticon" class="text-success me-2"></iconify-icon>
                        Most Used Emojis
                    </h6>
                </div>
                <div class="card-body p-3">
                    <ul class="list-group list-group-flush">
                        <?php if (!empty($topEmojis)): ?>
                            <?php foreach($topEmojis as $emoji): ?>
                            <li class="list-group-item d-flex justify-content-between align-items-center border-0 px-0 py-2">
                                <span class="text-muted d-flex align-items-center">
                                    <?php if (!empty($emoji['image_url'])): ?>
                                        <img src="<?= htmlspecialchars($emoji['image_url']) ?>" 
                                             class="w-24-px h-24-px object-fit-contain me-2" 
                                             alt="<?= htmlspecialchars($emoji['name']) ?>"
                                             onerror="this.style.display='none'">
                                    <?php else: ?>
                                        <iconify-icon icon="mdi:emoticon-outline" class="me-2 text-muted"></iconify-icon>
                                    <?php endif; ?>
                                    <?= htmlspecialchars($emoji['name']) ?>
                                </span>
                                <span class="badge bg-light text-success border rounded-pill"><?= $emoji['usage_count'] ?></span>
                            </li>
                            <?php endforeach; ?>
                        <?php else: ?>
                            <li class="list-group-item text-center text-muted border-0 py-3">
                                No emoji usage data
                            </li>
                        <?php endif; ?>
                    </ul>
                </div>
            </div>
        </div>

        <!-- Blog Status Distribution -->
        <div class="col">
            <div class="card border h-100">
                <div class="card-header bg-transparent border-bottom-0 py-3">
                    <h6 class="fw-semibold mb-0 d-flex align-items-center">
                        <iconify-icon icon="mdi:chart-pie" class="text-info me-2"></iconify-icon>
                        Blog Status Distribution
                    </h6>
                </div>
                <div class="card-body p-3">
                    <ul class="list-group list-group-flush">
                        <?php if (!empty($blogStatus)): ?>
                            <?php foreach($blogStatus as $status => $count): 
                                $color = $status == 'Approved' ? 'success' : ($status == 'Pending' ? 'warning' : 'danger');
                            ?>
                            <li class="list-group-item d-flex justify-content-between align-items-center border-0 px-0 py-2">
                                <span class="text-muted d-flex align-items-center">
                                    <iconify-icon icon="mdi:circle-small" class="text-<?= $color ?> me-2"></iconify-icon>
                                    <?= htmlspecialchars($status) ?>
                                </span>
                                <span class="badge bg-light text-<?= $color ?> border rounded-pill"><?= $count ?></span>
                            </li>
                            <?php endforeach; ?>
                        <?php else: ?>
                            <li class="list-group-item text-center text-muted border-0 py-3">
                                No blog data
                            </li>
                        <?php endif; ?>
                    </ul>
                </div>
            </div>
        </div>

        <!-- Emoji Categories Distribution -->
        <div class="col">
            <div class="card border h-100">
                <div class="card-header bg-transparent border-bottom-0 py-3">
                    <h6 class="fw-semibold mb-0 d-flex align-items-center">
                        <iconify-icon icon="mdi:tag-multiple" class="text-warning me-2"></iconify-icon>
                        Emoji Categories
                    </h6>
                </div>
                <div class="card-body p-3">
                    <ul class="list-group list-group-flush">
                        <?php if (!empty($emojiCategories)): ?>
                            <?php foreach($emojiCategories as $category => $count): ?>
                            <li class="list-group-item d-flex justify-content-between align-items-center border-0 px-0 py-2">
                                <span class="text-muted d-flex align-items-center">
                                    <iconify-icon icon="mdi:tag-outline" class="text-warning me-2"></iconify-icon>
                                    <?= htmlspecialchars($category) ?>
                                </span>
                                <span class="badge bg-light text-warning border rounded-pill"><?= $count ?></span>
                            </li>
                            <?php endforeach; ?>
                        <?php else: ?>
                            <li class="list-group-item text-center text-muted border-0 py-3">
                                No emoji categories
                            </li>
                        <?php endif; ?>
                    </ul>
                </div>
            </div>
        </div>
    </div>

    <!-- Charts -->
    <div class="row gy-4 mb-24">
        <div class="col-xxl-6">
            <div class="card h-100">
                <div class="card-header bg-transparent border-bottom-0 py-3">
                    <h6 class="fw-semibold mb-0">User Growth Chart</h6>
                </div>
                <div class="card-body pt-0">
                    <div id="userGrowthChart" style="height:300px"></div>
                </div>
            </div>
        </div>
        <div class="col-xxl-6">
            <div class="card h-100">
                <div class="card-header bg-transparent border-bottom-0 py-3">
                    <h6 class="fw-semibold mb-0">Content Engagement Chart</h6>
                </div>
                <div class="card-body pt-0">
                    <div id="contentEngagementChart" style="height:300px"></div>
                </div>
            </div>
        </div>
    </div>

    <!-- Additional Stats -->
    <div class="row gy-4">
        <div class="col-md-6">
            <div class="card h-100">
                <div class="card-header bg-transparent border-bottom-0 py-3">
                    <h6 class="fw-semibold mb-0">Recent Activity</h6>
                </div>
                <div class="card-body p-3">
                    <div class="activity-feed">
                        <?php if($recentActivity && $recentActivity->num_rows > 0): ?>
                            <?php while($activity = $recentActivity->fetch_assoc()): ?>
                                <div class="activity-item d-flex align-items-start mb-3">
                                    <div class="activity-icon me-3">
                                        <?php if($activity['type'] == 'blog'): ?>
                                            <iconify-icon icon="mdi:post" class="text-primary"></iconify-icon>
                                        <?php elseif($activity['type'] == 'prayer'): ?>
                                            <iconify-icon icon="mdi:hands-pray" class="text-success"></iconify-icon>
                                        <?php else: ?>
                                            <iconify-icon icon="mdi:image" class="text-warning"></iconify-icon>
                                        <?php endif; ?>
                                    </div>
                                    <div class="activity-content flex-grow-1">
                                        <p class="mb-1 small"><?= htmlspecialchars($activity['content']) ?></p>
                                        <small class="text-muted"><?= date('M j, g:i A', strtotime($activity['created_at'])) ?></small>
                                    </div>
                                </div>
                            <?php endwhile; ?>
                        <?php else: ?>
                            <p class="text-muted text-center">No recent activity</p>
                        <?php endif; ?>
                    </div>
                </div>
            </div>
        </div>
        
        <div class="col-md-6">
            <div class="card h-100">
                <div class="card-header bg-transparent border-bottom-0 py-3">
                    <h6 class="fw-semibold mb-0">Prayer Categories</h6>
                </div>
                <div class="card-body p-3">
                    <ul class="list-group list-group-flush">
                        <?php if (!empty($prayerCategories)): ?>
                            <?php foreach($prayerCategories as $category => $count): ?>
                            <li class="list-group-item d-flex justify-content-between align-items-center border-0 px-0 py-2">
                                <span class="text-muted d-flex align-items-center">
                                    <iconify-icon icon="mdi:tag" class="text-info me-2"></iconify-icon>
                                    <?= htmlspecialchars($category) ?>
                                </span>
                                <span class="badge bg-light text-info border rounded-pill"><?= $count ?></span>
                            </li>
                            <?php endforeach; ?>
                        <?php else: ?>
                            <li class="list-group-item text-center text-muted border-0 py-3">
                                No prayer categories found
                            </li>
                        <?php endif; ?>
                    </ul>
                </div>
            </div>
        </div>
    </div>
</div>

<script src="https://cdn.jsdelivr.net/npm/apexcharts"></script>
<script>
// Initialize charts when DOM is loaded
document.addEventListener('DOMContentLoaded', function() {
    initializeCharts();
});

function initializeCharts() {
    // User Growth Chart
    var userGrowthData = <?= json_encode(array_values($userGrowth)) ?>;
    var userGrowthLabels = <?= json_encode(array_keys($userGrowth)) ?>;
    
    var userGrowthOptions = {
        chart: { 
            type: 'line', 
            height: 300,
            toolbar: { show: true },
            zoom: { enabled: true },
            animations: { enabled: true }
        },
        series: [{ 
            name: 'New Users', 
            data: userGrowthData
        }],
        xaxis: { 
            categories: userGrowthLabels,
            labels: { style: { colors: '#6c757d' } }
        },
        yaxis: {
            labels: { style: { colors: '#6c757d' } },
            min: 0
        },
        colors: ['#6495ED'],
        stroke: { curve: 'smooth', width: 3 },
        markers: { size: 5 },
        fill: {
            type: 'gradient',
            gradient: {
                shadeIntensity: 1,
                opacityFrom: 0.7,
                opacityTo: 0.1,
                stops: [0, 90, 100]
            }
        },
        grid: { 
            borderColor: '#f8f9fa',
            padding: { top: 0, right: 0, bottom: 0, left: 0 }
        },
        tooltip: {
            theme: 'light',
            y: {
                formatter: function(val) {
                    return val + ' users'
                }
            }
        }
    };
    
    var userGrowthChart = new ApexCharts(document.querySelector("#userGrowthChart"), userGrowthOptions);
    userGrowthChart.render();

    // Content Engagement Chart
    var contentData = <?= json_encode($contentGrowth) ?>;
    var contentLabels = Object.keys(contentData);
    var blogData = Object.values(contentData).map(d => d.blogs);
    var videoData = Object.values(contentData).map(d => d.videos);
    var photoData = Object.values(contentData).map(d => d.photos);
    
    var contentOptions = {
        chart: { 
            type: 'bar', 
            height: 300,
            toolbar: { show: true },
            zoom: { enabled: true },
            animations: { enabled: true }
        },
        series: [
            { name: 'Blogs', data: blogData },
            { name: 'Videos', data: videoData },
            { name: 'Photos', data: photoData }
        ],
        xaxis: { 
            categories: contentLabels,
            labels: { style: { colors: '#6c757d' } }
        },
        yaxis: {
            labels: { style: { colors: '#6c757d' } },
            min: 0
        },
        colors: ['#6495ED', '#90EE90', '#FFB6C1'],
        grid: { 
            borderColor: '#f8f9fa',
            padding: { top: 0, right: 0, bottom: 0, left: 0 }
        },
        plotOptions: {
            bar: {
                borderRadius: 4,
                columnWidth: '55%',
                dataLabels: { position: 'top' }
            }
        },
        dataLabels: {
            enabled: false
        },
        tooltip: {
            theme: 'light'
        }
    };
    
    var contentChart = new ApexCharts(document.querySelector("#contentEngagementChart"), contentOptions);
    contentChart.render();
}

// Interactive functions
function refreshDashboard() {
    const btn = event.target.closest('button');
    const originalText = btn.innerHTML;
    btn.innerHTML = '<iconify-icon icon="mdi:loading" class="spin me-1"></iconify-icon> Refreshing...';
    btn.disabled = true;
    
    // Simulate refresh
    setTimeout(() => {
        location.reload();
    }, 1000);
}

function filterData(range) {
    const filterText = range === '7days' ? 'Last 7 Days' : 
                      range === '30days' ? 'Last 30 Days' : 'Last 6 Months';
    
    // Show loading state
    const charts = document.querySelectorAll('#userGrowthChart, #contentEngagementChart');
    charts.forEach(chart => {
        chart.innerHTML = '<div class="text-center py-5"><div class="spinner-border text-primary"></div><p class="mt-2 text-muted">Loading data...</p></div>';
    });
    
    // Simulate filter change
    setTimeout(() => {
        initializeCharts();
        showNotification(`Data filtered to ${filterText}`, 'success');
    }, 1500);
}

function showNotification(message, type) {
    // Create notification element
    const notification = document.createElement('div');
    notification.className = `alert alert-${type} alert-dismissible fade show position-fixed`;
    notification.style.cssText = 'top: 20px; right: 20px; z-index: 9999; min-width: 300px;';
    notification.innerHTML = `
        ${message}
        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    `;
    document.body.appendChild(notification);
    
    // Auto remove after 3 seconds
    setTimeout(() => {
        if (notification.parentNode) {
            notification.remove();
        }
    }, 3000);
}
</script>

<style>
.dashboard-main-body {
    overflow: hidden;
}

.card {
    border: 1px solid #e0e0e0;
    border-radius: 12px;
    background: #fff;
    box-shadow: 0 2px 4px rgba(0,0,0,0.04);
    transition: all 0.3s ease;
}

.card:hover {
    box-shadow: 0 4px 12px rgba(0,0,0,0.08);
}

.stat-card {
    transition: transform 0.2s ease;
}

.stat-card.hover-lift:hover {
    transform: translateY(-5px);
}

.w-24-px {
    width: 24px;
}

.h-24-px {
    height: 24px;
}

.list-group-item {
    background: transparent;
    padding: 0.75rem 0;
    transition: background-color 0.2s ease;
}

.list-group-item:hover {
    background-color: #f8f9fa;
}

.badge.bg-light {
    background-color: #f8f9fa !important;
    border: 1px solid #dee2e6;
    font-weight: 500;
    transition: all 0.2s ease;
}

.badge.bg-light:hover {
    transform: scale(1.05);
}

.text-muted {
    color: #6c757d !important;
}

.fw-semibold {
    font-weight: 600;
}

.mb-24 {
    margin-bottom: 1.5rem;
}

.spin {
    animation: spin 1s linear infinite;
}

@keyframes spin {
    from { transform: rotate(0deg); }
    to { transform: rotate(360deg); }
}

.activity-item {
    border-left: 2px solid #e9ecef;
    padding-left: 1rem;
    transition: border-color 0.3s ease;
}

.activity-item:hover {
    border-left-color: #6495ED;
}

.object-fit-contain {
    object-fit: contain;
}

/* Consistent spacing */
.row {
    margin-bottom: 1.5rem;
}

.row:last-child {
    margin-bottom: 0;
}

.gy-4 {
    --bs-gutter-y: 1.5rem;
}

.row-cols-xxl-4 > * {
    flex: 0 0 auto;
    width: 25%;
}

@media (max-width: 1399.98px) {
    .row-cols-xxl-4 > * {
        width: 50%;
    }
}

@media (max-width: 767.98px) {
    .row-cols-xxl-4 > * {
        width: 100%;
    }
}
</style>

<?php include './partials/layouts/layoutBottom.php'; ?>