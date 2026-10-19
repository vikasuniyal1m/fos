<?php
// sidebar.php - Add session_start() here since it's included in all pages
if (session_status() === PHP_SESSION_NONE) {
    session_start();
}
?>
<aside class="sidebar">
    <button type="button" class="sidebar-close-btn">
        <iconify-icon icon="radix-icons:cross-2"></iconify-icon>
    </button>
    <div>
        <a href="index.php" class="sidebar-logo">
            <img src="assets/images/logo.png" alt="site logo" class="light-logo">
            <img src="assets/images/logo-light.png" alt="site logo" class="dark-logo">
            <img src="assets/images/logo-icon.png" alt="site logo" class="logo-icon">
        </a>
    </div>
    <div class="sidebar-menu-area">
        <ul class="sidebar-menu" id="sidebar-menu">
            <li class="dropdown">
                <a href="javascript:void(0)">
                    <iconify-icon icon="solar:home-smile-angle-outline" class="menu-icon"></iconify-icon>
                    <span>Dashboard</span>
                </a>
                <ul class="sidebar-submenu">
                    <li>
                        <a href="index.php"><i class="ri-circle-fill circle-icon text-primary-600 w-auto"></i> Analytics Dashboard</a>
                    </li>
                </ul>
            </li>
            
            <li class="sidebar-menu-group-title">Overview</li>
            
            <li class="dropdown">
                <a href="javascript:void(0)">
                    <iconify-icon icon="flowbite:users-group-outline" class="menu-icon"></iconify-icon>
                    <span>Users</span>
                </a>
                <ul class="sidebar-submenu">
                    <li>
                        <a href="users-list.php"><i class="ri-circle-fill circle-icon text-primary-600 w-auto"></i> Users List</a>
                    </li>
                    <li>
                        <a href="add-user.php"><i class="ri-circle-fill circle-icon text-success-main w-auto"></i> Add User</a>
                    </li>
                </ul>
            </li>
            
            <li class="dropdown">
                <a href="javascript:void(0)">
                    <iconify-icon icon="solar:document-text-outline" class="menu-icon"></iconify-icon>
                    <span>Blogs</span>
                </a>
                <ul class="sidebar-submenu">
                    <li>
                        <a href="blogs-list.php"><i class="ri-circle-fill circle-icon text-primary-600 w-auto"></i> Blogs List</a>
                    </li>
                   
                </ul>
            </li>
            
            <li class="dropdown">
                <a href="javascript:void(0)">
                    <iconify-icon icon="heroicons:document" class="menu-icon"></iconify-icon>
                    <span>Prayer Requests</span>
                </a>
                <ul class="sidebar-submenu">
                    <li>
                        <a href="prayer-requests.php"><i class="ri-circle-fill circle-icon text-primary-600 w-auto"></i> View All Prayers</a>
                    </li>
                </ul>
            </li>
            
            <li class="dropdown">
                <a href="javascript:void(0)">
                    <iconify-icon icon="mingcute:storage-line" class="menu-icon"></iconify-icon>
                    <span>Media Management</span>
                </a>
                <ul class="sidebar-submenu">
                    <li>
                        <a href="media-moderation.php"><i class="ri-circle-fill circle-icon text-primary-600 w-auto"></i> Media Moderation</a>
                    </li>
                    <li>
                        <a href="live-videos.php"><i class="ri-circle-fill circle-icon text-danger-main w-auto"></i> Live Videos</a>
                    </li>
                </ul>
            </li>

            <li class="dropdown">
                <a href="javascript:void(0)">
                    <iconify-icon icon="mdi:play-box-multiple-outline" class="menu-icon"></iconify-icon>
                    <span>Shorts</span>
                </a>
                <ul class="sidebar-submenu">
                    <li>
                        <a href="shorts-moderation.php"><i class="ri-circle-fill circle-icon text-primary-600 w-auto"></i> Shorts Listing</a>
                    </li>
                    <li>
                        <a href="shorts-reports.php"><i class="ri-circle-fill circle-icon text-warning-main w-auto"></i> Reports</a>
                    </li>
                    <li>
                        <a href="shorts-analytics.php"><i class="ri-circle-fill circle-icon text-success-main w-auto"></i> Analytics</a>
                    </li>
                </ul>
            </li>
            
            <li>
                <a href="comments-moderation.php">
                    <iconify-icon icon="fe:vector" class="menu-icon"></iconify-icon>
                    <span>Comments Moderation</span>
                </a>
            </li>

            <li class="sidebar-menu-group-title">Community</li>
            
            <li class="dropdown">
                <a href="javascript:void(0)">
                    <iconify-icon icon="fluent:people-community-20-regular" class="menu-icon"></iconify-icon>
                    <span>Groups</span>
                </a>
                <ul class="sidebar-submenu">
                    <li>
                        <a href="groups-list.php"><i class="ri-circle-fill circle-icon text-primary-600 w-auto"></i> Groups List</a>
                    </li>
                    <li>
                        <a href="add-group.php"><i class="ri-circle-fill circle-icon text-success-main w-auto"></i> Create Group</a>
                    </li>
                </ul>
            </li>

            <li class="sidebar-menu-group-title">Content Management</li>

            <li class="dropdown">
                <a href="javascript:void(0)">
                    <iconify-icon icon="solar:gallery-wide-outline" class="menu-icon"></iconify-icon>
                    <span>Banners</span>
                </a>
                <ul class="sidebar-submenu">
                    <li>
                        <a href="banners-manage.php"><i class="ri-circle-fill circle-icon text-primary-600 w-auto"></i> Manage banners</a>
                    </li>
                </ul>
            </li>

            <li>
                <a href="christian-calendar.php">
                    <iconify-icon icon="solar:calendar-minimalistic-outline" class="menu-icon"></iconify-icon>
                    <span>Christian &amp; holiday calendar</span>
                </a>
            </li>
            
            <li class="dropdown">
                <a href="javascript:void(0)">
                    <iconify-icon icon="fluent:emoji-24-regular" class="menu-icon"></iconify-icon>
                    <span>Emoji System</span>
                </a>
                <ul class="sidebar-submenu">
                    <li>
                        <a href="emojis-list.php"><i class="ri-circle-fill circle-icon text-primary-600 w-auto"></i> Emojis List</a>
                    </li>
                    <li>
                        <a href="add-emoji.php"><i class="ri-circle-fill circle-icon text-success-main w-auto"></i> Add Emoji</a>
                    </li>
                </ul>
            </li>
            
            <!--<li class="dropdown">-->
            <!--    <a href="javascript:void(0)">-->
            <!--        <iconify-icon icon="mdi:translate" class="menu-icon"></iconify-icon>-->
            <!--        <span>Languages</span>-->
            <!--    </a>-->
            <!--    <ul class="sidebar-submenu">-->
            <!--        <li>-->
            <!--            <a href="languages-list.php"><i class="ri-circle-fill circle-icon text-primary-600 w-auto"></i> Languages List</a>-->
            <!--        </li>-->
            <!--        <li>-->
            <!--            <a href="add-language.php"><i class="ri-circle-fill circle-icon text-success-main w-auto"></i> Add Language</a>-->
            <!--        </li>-->
            <!--        <li>-->
            <!--            <a href="translations.php"><i class="ri-circle-fill circle-icon text-warning-main w-auto"></i> Translations</a>-->
            <!--        </li>-->
            <!--    </ul>-->
            <!--</li>-->

            <li class="sidebar-menu-group-title">System</li>
            
            <li>
                <a href="system-settings.php">
                    <iconify-icon icon="icon-park-outline:setting-two" class="menu-icon"></iconify-icon>
                    <span>System Settings</span>
                </a>
            </li>
            
            <li class="dropdown">
                <a href="javascript:void(0)">
                    <iconify-icon icon="solar:pie-chart-outline" class="menu-icon"></iconify-icon>
                    <span>Analytics</span>
                </a>
                <ul class="sidebar-submenu">
                    <li>
                        <a href="index.php"><i class="ri-circle-fill circle-icon text-primary-600 w-auto"></i> Dashboard Analytics</a>
                    </li>
                    <li>
                        <a href="user-analytics.php"><i class="ri-circle-fill circle-icon text-info-main w-auto"></i> User Analytics</a>
                    </li>
                    <li>
                        <a href="content-analytics.php"><i class="ri-circle-fill circle-icon text-success-main w-auto"></i> Content Analytics</a>
                    </li>
                </ul>
            </li>
            
            <li class="dropdown">
                <a href="javascript:void(0)">
                    <iconify-icon icon="solar:pie-chart-outline" class="menu-icon"></iconify-icon>
                    <span>Notifications</span>
                </a>
                <ul class="sidebar-submenu">
                    <li>
                        <a href="notifications-settings.php"><i class="ri-circle-fill circle-icon text-primary-600 w-auto"></i> Notification Settings</a>
                    </li>
                    <li>
                        <a href="push-notifications.php"><i class="ri-circle-fill circle-icon text-warning-main w-auto"></i> Push Notifications</a>
                    </li>
                </ul>
            </li>
            <li class="nav-item">
    <a class="nav-link hover-text-primary <?php echo basename($_SERVER['PHP_SELF']) == 'terms-management.php' ? 'active' : ''; ?>" 
       href="terms-management.php">
        <iconify-icon icon="mdi:file-document-edit" class="icon text-lg"></iconify-icon>
        <span>Terms & Conditions</span>
    </a>
     <a class="nav-link hover-text-primary <?php echo basename($_SERVER['PHP_SELF']) == 'privacy-policy.php' ? 'active' : ''; ?>" 
       href="privacy-policy.php">
        <iconify-icon icon="mdi:file-document-edit" class="icon text-lg"></iconify-icon>
        <span>Privacy Policy</span>
    </a>
</li>

            <!-- Future Features (Commented out for now) -->
            <!--
            <li class="sidebar-menu-group-title">E-commerce</li>
            
            <li class="dropdown">
                <a href="javascript:void(0)">
                    <iconify-icon icon="hugeicons:money-send-square" class="menu-icon"></iconify-icon>
                    <span>Store Management</span>
                </a>
                <ul class="sidebar-submenu">
                    <li>
                        <a href="products-list.php"><i class="ri-circle-fill circle-icon text-primary-600 w-auto"></i> Products</a>
                    </li>
                    <li>
                        <a href="orders-list.php"><i class="ri-circle-fill circle-icon text-warning-main w-auto"></i> Orders</a>
                    </li>
                    <li>
                        <a href="inventory.php"><i class="ri-circle-fill circle-icon text-info-main w-auto"></i> Inventory</a>
                    </li>
                </ul>
            </li>
            -->
        </ul>
    </div>
</aside>