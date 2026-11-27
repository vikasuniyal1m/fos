<?php
// Don't start session here if it's already started in the main file
// Just check if session variables are set

require_once 'includes/db.php';

// Get current admin data
$current_admin = null;
if (isset($_SESSION['admin_logged_in']) && $_SESSION['admin_logged_in'] === true && isset($_SESSION['admin_id'])) {
    $admin_id = $_SESSION['admin_id'];
    $sql = "SELECT * FROM admin_users WHERE id = ?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("i", $admin_id);
    $stmt->execute();
    $result = $stmt->get_result();
    $current_admin = $result->fetch_assoc();
}

// Get first letter of admin name for avatar
$admin_initial = '';
if ($current_admin && isset($current_admin['name'])) {
    $admin_initial = strtoupper(substr($current_admin['name'], 0, 1));
}
?>

<style>
.search-results {
    position: absolute;
    top: 100%;
    left: 0;
    width: 100%;
    max-height: 350px;
    overflow-y: auto;
    background: #fff;
    border: 1px solid #ddd;
    border-radius: 8px;
    box-shadow: 0 4px 12px rgba(0,0,0,0.1);
    z-index: 9999;
}

.search-results .result-item {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 10px 12px;
    cursor: pointer;
    transition: background 0.2s;
}

.search-results .result-item:hover {
    background-color: #f5f5f5;
}

.search-results .result-item img {
    width: 40px;
    height: 40px;
    border-radius: 50%;
    object-fit: cover;
}

.search-results .result-text {
    flex: 1;
    display: flex;
    flex-direction: column;
}

.search-results .result-text .title {
    font-weight: 600;
    font-size: 14px;
    color: #333;
}

.search-results .result-text .subtitle {
    font-size: 12px;
    color: #777;
    margin-top: 2px;
}

.search-results::-webkit-scrollbar {
    width: 6px;
}
.search-results::-webkit-scrollbar-thumb {
    background-color: rgba(0,0,0,0.2);
    border-radius: 3px;
}

.avatar-initial {
    width: 40px;
    height: 40px;
    border-radius: 50%;
    background: linear-gradient(135deg, #e74c3c 0%, #f39c12 100%);
    color: white;
    display: flex;
    align-items: center;
    justify-content: center;
    font-weight: 600;
    font-size: 16px;
}

.admin-login-btn {
    background: linear-gradient(135deg, #e74c3c 0%, #f39c12 100%);
    border: none;
    padding: 8px 20px;
    border-radius: 8px;
    color: white;
    font-weight: 600;
    text-decoration: none;
    transition: all 0.3s ease;
    display: flex;
    align-items: center;
    gap: 8px;
}

.admin-login-btn:hover {
    transform: translateY(-2px);
    box-shadow: 0 4px 15px rgba(231, 76, 60, 0.3);
    color: white;
}

.logout-btn {
    background: transparent;
    border: 1px solid #e74c3c;
    padding: 8px 20px;
    border-radius: 8px;
    color: #e74c3c;
    font-weight: 600;
    text-decoration: none;
    transition: all 0.3s ease;
    display: flex;
    align-items: center;
    gap: 8px;
}

.logout-btn:hover {
    background: #e74c3c;
    color: white;
    transform: translateY(-2px);
    box-shadow: 0 4px 15px rgba(231, 76, 60, 0.3);
}
</style>

<div class="navbar-header">
    <div class="row align-items-center justify-content-between">
        <div class="col-auto">
            <div class="d-flex flex-wrap align-items-center gap-4">
                <button type="button" class="sidebar-toggle">
                    <iconify-icon icon="heroicons:bars-3-solid" class="icon text-2xl non-active"></iconify-icon>
                    <iconify-icon icon="iconoir:arrow-right" class="icon text-2xl active"></iconify-icon>
                </button>
                <button type="button" class="sidebar-mobile-toggle">
                    <iconify-icon icon="heroicons:bars-3-solid" class="icon"></iconify-icon>
                </button>
                
                <div class="navbar-search position-relative">
                    <input type="text" id="searchInput" placeholder="Search anything..." autocomplete="off" class="form-control">
                    <iconify-icon icon="ion:search-outline" class="icon"></iconify-icon>
                    <div id="searchResults" class="search-results" style="display:none;"></div>
                </div>
            </div>
        </div>
        
        <div class="col-auto">
            <div class="d-flex flex-wrap align-items-center gap-3">
                <button type="button" data-theme-toggle class="w-40-px h-40-px bg-neutral-200 rounded-circle d-flex justify-content-center align-items-center"></button>
                
               

                <!-- Admin Login/Logout Section -->
                <?php if (isset($_SESSION['admin_logged_in']) && $_SESSION['admin_logged_in'] === true && $current_admin): ?>
                    <!-- Admin is logged in - Show Simple Logout Button -->
                    <a href="logout.php" class="logout-btn">
                        <iconify-icon icon="lucide:power" class="icon"></iconify-icon>
                        Logout
                    </a>
                <?php else: ?>
                    <!-- Admin is not logged in - Show Login Button -->
                    <a href="login.php" class="admin-login-btn">
                        <iconify-icon icon="solar:login-3-linear" class="icon"></iconify-icon>
                        Admin Login
                    </a>
                <?php endif; ?>
            </div>
        </div>
    </div>
</div>

<script>
const searchInput = document.getElementById('searchInput');
const searchResults = document.getElementById('searchResults');

// Search functionality
searchInput.addEventListener('input', function() {
    const query = this.value.trim();
    if (query.length < 1) {
        searchResults.style.display = 'none';
        searchResults.innerHTML = '';
        return;
    }
    
    fetch(`./search.php?q=${encodeURIComponent(query)}`)
        .then(res => res.text())
        .then(html => {
            searchResults.innerHTML = html;
            searchResults.style.display = 'block';
        })
        .catch(err => {
            console.error(err);
            searchResults.innerHTML = '<div class="p-2 text-muted">Error fetching results</div>';
            searchResults.style.display = 'block';
        });
});

// Hide search dropdown when clicking outside
document.addEventListener('click', function(e) {
    if (!searchResults.contains(e.target) && e.target !== searchInput) {
        searchResults.style.display = 'none';
    }
});
</script>