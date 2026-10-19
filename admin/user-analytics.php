<?php
include './includes/db.php';
include './includes/admin-auth.php';
include './partials/layouts/layoutTop.php';

// Get user statistics
$totalUsers = $conn->query("SELECT COUNT(*) as count FROM users")->fetch_assoc()['count'];
$activeUsers = $conn->query("SELECT COUNT(*) as count FROM users WHERE status='Active'")->fetch_assoc()['count'];
$bloggers = $conn->query("SELECT COUNT(*) as count FROM users WHERE role='Blogger'")->fetch_assoc()['count'];
$newUsersToday = $conn->query("SELECT COUNT(*) as count FROM users WHERE DATE(join_date) = CURDATE()")->fetch_assoc()['count'];

// User growth data (last 6 months)
$userGrowth = $conn->query("
    SELECT DATE_FORMAT(join_date, '%Y-%m') as month, COUNT(*) as count 
    FROM users 
    WHERE join_date >= DATE_SUB(NOW(), INTERVAL 6 MONTH)
    GROUP BY DATE_FORMAT(join_date, '%Y-%m')
    ORDER BY month
");

$growthData = [];
$growthLabels = [];
while ($row = $userGrowth->fetch_assoc()) {
    $growthLabels[] = date('M Y', strtotime($row['month'] . '-01'));
    $growthData[] = $row['count'];
}

// User role distribution
$roleDistribution = $conn->query("
    SELECT role, COUNT(*) as count 
    FROM users 
    GROUP BY role
");

// User activity by fruit category
$fruitActivity = $conn->query("
    SELECT f.name, COUNT(uf.user_id) as user_count
    FROM fruits f
    LEFT JOIN user_fruits uf ON f.id = uf.fruit_id
    GROUP BY f.id
    ORDER BY user_count DESC
");
?>

<div class="dashboard-main-body">
    <div class="d-flex flex-wrap align-items-center justify-content-between gap-3 mb-24">
        <h6 class="fw-semibold mb-0">User Analytics</h6>
        <ul class="d-flex align-items-center gap-2">
            <li class="fw-medium">
                <a href="index.php" class="d-flex align-items-center gap-1 hover-text-primary">
                    <iconify-icon icon="solar:home-smile-angle-outline" class="icon text-lg"></iconify-icon>
                    Dashboard
                </a>
            </li>
            <li>-</li>
            <li class="fw-medium">User Analytics</li>
        </ul>
    </div>

    <!-- Stats Cards with Light Colors -->
    <div class="row row-cols-1 row-cols-md-2 row-cols-lg-4 g-4 mb-24">
        <div class="col">
            <div class="card border-primary">
                <div class="card-body">
                    <div class="d-flex justify-content-between">
                        <div>
                            <h6 class="card-title text-muted">Total Users</h6>
                            <h2 class="mb-0 text-primary"><?php echo $totalUsers; ?></h2>
                        </div>
                        <div class="align-self-center">
                            <iconify-icon icon="fluent:people-20-regular" class="icon-2xl text-primary"></iconify-icon>
                        </div>
                    </div>
                </div>
            </div>
        </div>
        <div class="col">
            <div class="card border-success">
                <div class="card-body">
                    <div class="d-flex justify-content-between">
                        <div>
                            <h6 class="card-title text-muted">Active Users</h6>
                            <h2 class="mb-0 text-success"><?php echo $activeUsers; ?></h2>
                        </div>
                        <div class="align-self-center">
                            <iconify-icon icon="fluent:person-checkmark-20-regular" class="icon-2xl text-success"></iconify-icon>
                        </div>
                    </div>
                </div>
            </div>
        </div>
        <div class="col">
            <div class="card border-info">
                <div class="card-body">
                    <div class="d-flex justify-content-between">
                        <div>
                            <h6 class="card-title text-muted">Bloggers</h6>
                            <h2 class="mb-0 text-info"><?php echo $bloggers; ?></h2>
                        </div>
                        <div class="align-self-center">
                            <iconify-icon icon="fluent:person-edit-20-regular" class="icon-2xl text-info"></iconify-icon>
                        </div>
                    </div>
                </div>
            </div>
        </div>
        <div class="col">
            <div class="card border-warning">
                <div class="card-body">
                    <div class="d-flex justify-content-between">
                        <div>
                            <h6 class="card-title text-muted">New Today</h6>
                            <h2 class="mb-0 text-warning"><?php echo $newUsersToday; ?></h2>
                        </div>
                        <div class="align-self-center">
                            <iconify-icon icon="fluent:person-add-20-regular" class="icon-2xl text-warning"></iconify-icon>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <!-- Charts -->
    <div class="row gy-4">
        <div class="col-lg-8">
            <div class="card h-100">
                <div class="card-body">
                    <h6 class="fw-semibold mb-16">User Growth (Last 6 Months)</h6>
                    <div style="height: 250px; position: relative;">
                        <canvas id="userGrowthChart"></canvas>
                    </div>
                </div>
            </div>
        </div>
        <div class="col-lg-4">
            <div class="card h-100">
                <div class="card-body">
                    <h6 class="fw-semibold mb-16">User Role Distribution</h6>
                    <div style="height: 250px; position: relative;">
                        <canvas id="roleDistributionChart"></canvas>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <!-- User Activity by Fruit -->
    <div class="row mt-4">
        <div class="col-12">
            <div class="card">
                <div class="card-body">
                    <h6 class="fw-semibold mb-16">User Activity by Fruit Category</h6>
                    <div class="table-responsive">
                        <table class="table">
                            <thead>
                                <tr>
                                    <th class="text-muted">Fruit Category</th>
                                    <th class="text-muted">Active Users</th>
                                    <th class="text-muted">Percentage</th>
                                </tr>
                            </thead>
                            <tbody>
                                <?php 
                                $totalFruitUsers = 0;
                                $fruitData = [];
                                while ($fruit = $fruitActivity->fetch_assoc()) {
                                    $fruitData[] = $fruit;
                                    $totalFruitUsers += $fruit['user_count'];
                                }
                                
                                foreach ($fruitData as $fruit): 
                                    $percentage = $totalFruitUsers > 0 ? round(($fruit['user_count'] / $totalFruitUsers) * 100, 1) : 0;
                                ?>
                                    <tr>
                                        <td>
                                            <span class="fw-medium"><?php echo htmlspecialchars($fruit['name']); ?></span>
                                        </td>
                                        <td class="fw-medium"><?php echo $fruit['user_count']; ?></td>
                                        <td>
                                            <div class="d-flex align-items-center">
                                                <div class="progress flex-grow-1 me-12" style="height: 8px;">
                                                    <div class="progress-bar bg-info" style="width: <?php echo $percentage; ?>%"></div>
                                                </div>
                                                <span class="text-sm text-muted"><?php echo $percentage; ?>%</span>
                                            </div>
                                        </td>
                                    </tr>
                                <?php endforeach; ?>
                            </tbody>
                        </table>
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
    // User Growth Chart with light colors
    const growthCtx = document.getElementById('userGrowthChart').getContext('2d');
    new Chart(growthCtx, {
        type: 'line',
        data: {
            labels: <?php echo json_encode($growthLabels); ?>,
            datasets: [{
                label: 'New Users',
                data: <?php echo json_encode($growthData); ?>,
                borderColor: 'rgba(100, 149, 237, 1)', // Cornflower blue
                backgroundColor: 'rgba(100, 149, 237, 0.1)',
                tension: 0.4,
                fill: true,
                pointBackgroundColor: 'rgba(100, 149, 237, 1)',
                pointBorderColor: '#fff',
                pointBorderWidth: 2
            }]
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
                    grid: {
                        color: 'rgba(0, 0, 0, 0.05)'
                    }
                }
            },
            plugins: {
                legend: {
                    display: false
                }
            }
        }
    });

    // Role Distribution Chart with light colors
    const roleCtx = document.getElementById('roleDistributionChart').getContext('2d');
    new Chart(roleCtx, {
        type: 'doughnut',
        data: {
            labels: [
                <?php 
                $roleData = [];
                while ($role = $roleDistribution->fetch_assoc()) {
                    $roleData[] = $role;
                    echo "'" . $role['role'] . "',";
                }
                ?>
            ],
            datasets: [{
                data: [
                    <?php 
                    foreach ($roleData as $role) {
                        echo $role['count'] . ",";
                    }
                    ?>
                ],
                backgroundColor: [
                    'rgba(100, 149, 237, 0.6)',  // Light blue
                    'rgba(144, 238, 144, 0.6)',  // Light green
                    'rgba(255, 182, 193, 0.6)',  // Light pink
                    'rgba(255, 215, 0, 0.6)',    // Light yellow
                    'rgba(216, 191, 216, 0.6)'   // Light purple
                ],
                borderColor: [
                    'rgba(100, 149, 237, 1)',
                    'rgba(144, 238, 144, 1)',
                    'rgba(255, 182, 193, 1)',
                    'rgba(255, 215, 0, 1)',
                    'rgba(216, 191, 216, 1)'
                ],
                borderWidth: 1
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    position: 'bottom',
                    labels: {
                        usePointStyle: true,
                        padding: 15
                    }
                }
            },
            cutout: '60%'
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
    box-shadow: 0 1px 3px rgba(0,0,0,0.05);
}

.card-body {
    padding: 1.5rem;
}

.stats-card {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
}

.table th {
    border-top: none;
    font-weight: 500;
    font-size: 0.875rem;
}

.table td {
    vertical-align: middle;
    padding: 0.75rem 0.5rem;
}

.progress {
    background-color: #f8f9fa;
    border-radius: 4px;
}

.icon-2xl {
    font-size: 2.5rem;
    opacity: 0.8;
}
</style>

<?php include './partials/layouts/layoutBottom.php'; ?>