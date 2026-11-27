<?php
include './includes/db.php';
include './includes/admin-auth.php';
include './partials/layouts/layoutTop.php';

$group_id = intval($_GET['id'] ?? 0);

// Fetch group details
$group = null;
if($group_id) {
    $stmt = $conn->prepare("SELECT g.*, u.name as created_by_name 
                           FROM `groups` g 
                           LEFT JOIN users u ON g.created_by = u.id 
                           WHERE g.id = ?");
    $stmt->bind_param("i", $group_id);
    $stmt->execute();
    $result = $stmt->get_result();
    $group = $result->fetch_assoc();
}

// Fetch group members
$members = [];
if($group) {
    $stmt = $conn->prepare("SELECT gm.*, u.name, u.email, u.profile_photo 
                           FROM group_members gm 
                           LEFT JOIN users u ON gm.user_id = u.id 
                           WHERE gm.group_id = ? 
                           ORDER BY gm.role DESC, u.name ASC");
    $stmt->bind_param("i", $group_id);
    $stmt->execute();
    $members = $stmt->get_result();
}

if(!$group) {
    echo '<div class="alert alert-danger m-24">Group not found.</div>';
    include './partials/layouts/layoutBottom.php';
    exit;
}
?>

<div class="dashboard-main-body">
    <div class="d-flex flex-wrap align-items-center justify-content-between gap-3 mb-24">
        <h6 class="fw-semibold mb-0">Group Details</h6>
        <ul class="d-flex align-items-center gap-2">
            <li class="fw-medium">
                <a href="index.php" class="d-flex align-items-center gap-1 hover-text-primary">
                    <iconify-icon icon="solar:home-smile-angle-outline" class="icon text-lg"></iconify-icon>
                    Dashboard
                </a>
            </li>
            <li>-</li>
            <li class="fw-medium">
                <a href="groups-list.php" class="hover-text-primary">Groups</a>
            </li>
            <li>-</li>
            <li class="fw-medium"><?php echo htmlspecialchars($group['name']); ?></li>
        </ul>
    </div>

    <div class="row">
        <div class="col-lg-8">
            <!-- Group Information -->
            <div class="card radius-12 mb-24">
                <div class="card-header border-bottom bg-base py-16 px-24">
                    <h6 class="fw-semibold mb-0">Group Information</h6>
                </div>
                <div class="card-body p-24">
                    <div class="row">
                        <div class="col-md-6">
                            <div class="mb-16">
                                <label class="text-muted text-sm mb-4">Group Name</label>
                                <p class="fw-medium"><?php echo htmlspecialchars($group['name']); ?></p>
                            </div>
                        </div>
                        <div class="col-md-6">
                            <div class="mb-16">
                                <label class="text-muted text-sm mb-4">Category</label>
                                <p><span class="badge bg-primary"><?php echo htmlspecialchars($group['category']); ?></span></p>
                            </div>
                        </div>
                        <div class="col-md-6">
                            <div class="mb-16">
                                <label class="text-muted text-sm mb-4">Status</label>
                                <p><span class="badge bg-<?php echo $group['status'] == 'Active' ? 'success' : 'danger'; ?>"><?php echo $group['status']; ?></span></p>
                            </div>
                        </div>
                        <div class="col-md-6">
                            <div class="mb-16">
                                <label class="text-muted text-sm mb-4">Created By</label>
                                <p class="fw-medium"><?php echo htmlspecialchars($group['created_by_name']); ?></p>
                            </div>
                        </div>
                        <div class="col-12">
                            <div class="mb-16">
                                <label class="text-muted text-sm mb-4">Description</label>
                                <p class="fw-medium"><?php echo htmlspecialchars($group['description']); ?></p>
                            </div>
                        </div>
                        <div class="col-md-6">
                            <div class="mb-16">
                                <label class="text-muted text-sm mb-4">Created Date</label>
                                <p class="fw-medium"><?php echo date('M j, Y H:i', strtotime($group['created_at'])); ?></p>
                            </div>
                        </div>
                        <div class="col-md-6">
                            <div class="mb-16">
                                <label class="text-muted text-sm mb-4">Total Members</label>
                                <p class="fw-medium"><?php echo $members->num_rows; ?> members</p>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Group Members -->
            <div class="card radius-12">
                <div class="card-header border-bottom bg-base py-16 px-24 d-flex justify-content-between align-items-center">
                    <h6 class="fw-semibold mb-0">Group Members (<?php echo $members->num_rows; ?>)</h6>
                </div>
                <div class="card-body p-24">
                    <?php if($members->num_rows > 0): ?>
                        <div class="table-responsive">
                            <table class="table bordered-table sm-table mb-0">
                                <thead>
                                    <tr>
                                        <th>Member</th>
                                        <th>Email</th>
                                        <th>Role</th>
                                        <th>Joined</th>
                                        <th class="text-center">Actions</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <?php while($member = $members->fetch_assoc()): ?>
                                        <tr>
                                            <td>
                                                <div class="d-flex align-items-center">
                                                    <?php if($member['profile_photo']): ?>
                                                        <img src="<?php echo $member['profile_photo']; ?>" class="w-40-px h-40-px rounded-circle me-12">
                                                    <?php else: ?>
                                                        <div class="w-40-px h-40-px bg-primary text-white rounded-circle d-flex align-items-center justify-content-center fw-medium me-12">
                                                            <?php echo strtoupper(substr($member['name'], 0, 1)); ?>
                                                        </div>
                                                    <?php endif; ?>
                                                    <div class="fw-medium"><?php echo htmlspecialchars($member['name']); ?></div>
                                                </div>
                                            </td>
                                            <td><?php echo htmlspecialchars($member['email']); ?></td>
                                            <td>
                                                <span class="badge bg-<?php echo $member['role'] == 'Admin' ? 'warning' : 'primary'; ?>">
                                                    <?php echo $member['role']; ?>
                                                </span>
                                            </td>
                                            <td><?php echo date('M j, Y', strtotime($member['joined_at'])); ?></td>
                                            <td class="text-center">
                                                <div class="d-flex gap-10 justify-content-center">
                                                    <?php if($member['role'] != 'Admin'): ?>
                                                        <button class="make-admin bg-success-focus bg-hover-success-200 text-success-600 fw-medium w-40-px h-40-px d-flex justify-content-center align-items-center rounded-circle" 
                                                                data-user-id="<?php echo $member['user_id']; ?>" data-group-id="<?php echo $group_id; ?>" title="Make Admin">
                                                            <iconify-icon icon="mdi:crown" class="icon text-lg"></iconify-icon>
                                                        </button>
                                                        <button class="remove-member bg-danger-focus bg-hover-danger-200 text-danger-600 fw-medium w-40-px h-40-px d-flex justify-content-center align-items-center rounded-circle" 
                                                                data-user-id="<?php echo $member['user_id']; ?>" data-group-id="<?php echo $group_id; ?>" title="Remove Member">
                                                            <iconify-icon icon="mdi:account-remove" class="icon text-lg"></iconify-icon>
                                                        </button>
                                                    <?php else: ?>
                                                        <span class="text-muted text-sm">Group Admin</span>
                                                    <?php endif; ?>
                                                </div>
                                            </td>
                                        </tr>
                                    <?php endwhile; ?>
                                </tbody>
                            </table>
                        </div>
                    <?php else: ?>
                        <div class="text-center py-40">
                            <iconify-icon icon="mdi:account-group" class="icon text-4xl text-muted mb-16"></iconify-icon>
                            <p class="text-muted">No members in this group yet.</p>
                        </div>
                    <?php endif; ?>
                </div>
            </div>
        </div>

        <div class="col-lg-4">
            <!-- Group Actions -->
            <div class="card radius-12 mb-24">
                <div class="card-header border-bottom bg-base py-16 px-24">
                    <h6 class="fw-semibold mb-0">Group Actions</h6>
                </div>
                <div class="card-body p-24">
                    <div class="d-grid gap-12">
                        <a href="edit-group.php?id=<?php echo $group_id; ?>" class="btn btn-primary d-flex align-items-center justify-content-center gap-8 py-10">
                            <iconify-icon icon="mdi:pencil" class="icon text-lg"></iconify-icon>
                            <span class="fw-medium">Edit Group</span>
                        </a>
                        
                        <button class="toggle-status btn btn-<?php echo $group['status'] == 'Active' ? 'warning' : 'success'; ?> d-flex align-items-center justify-content-center gap-8 py-10" 
                                data-id="<?php echo $group_id; ?>">
                            <iconify-icon icon="<?php echo $group['status'] == 'Active' ? 'mdi:pause' : 'mdi:play'; ?>" class="icon text-lg"></iconify-icon>
                            <span class="fw-medium">
                                <?php echo $group['status'] == 'Active' ? 'Deactivate Group' : 'Activate Group'; ?>
                            </span>
                        </button>
                        
                        <button class="delete-group btn btn-outline-danger d-flex align-items-center justify-content-center gap-8 py-10" data-id="<?php echo $group_id; ?>">
                            <iconify-icon icon="mdi:delete" class="icon text-lg"></iconify-icon>
                            <span class="fw-medium">Delete Group</span>
                        </button>
                    </div>
                </div>
            </div>

            <!-- Group Statistics -->
            <div class="card radius-12">
                <div class="card-header border-bottom bg-base py-16 px-24">
                    <h6 class="fw-semibold mb-0">Group Statistics</h6>
                </div>
                <div class="card-body p-24">
                    <div class="d-flex justify-content-between align-items-center mb-16">
                        <span class="text-muted">Total Members:</span>
                        <span class="fw-bold text-primary"><?php echo $members->num_rows; ?></span>
                    </div>
                    <div class="d-flex justify-content-between align-items-center mb-16">
                        <span class="text-muted">Admins:</span>
                        <span class="fw-bold text-warning">
                            <?php 
                            $admin_count = 0;
                            $members->data_seek(0);
                            while($member = $members->fetch_assoc()) {
                                if($member['role'] == 'Admin') $admin_count++;
                            }
                            echo $admin_count;
                            ?>
                        </span>
                    </div>
                    <div class="d-flex justify-content-between align-items-center mb-16">
                        <span class="text-muted">Regular Members:</span>
                        <span class="fw-bold text-info"><?php echo $members->num_rows - $admin_count; ?></span>
                    </div>
                    <div class="d-flex justify-content-between align-items-center">
                        <span class="text-muted">Group Status:</span>
                        <span class="badge bg-<?php echo $group['status'] == 'Active' ? 'success' : 'danger'; ?>">
                            <?php echo $group['status']; ?>
                        </span>
                    </div>
                </div>
            </div>
        </div>
    </div>
</div>

<style>
/* Fix button alignment and icon positioning */
.btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
    min-height: 44px;
    padding: 10px 16px;
    border: 1px solid transparent;
    border-radius: 8px;
    font-weight: 500;
    text-decoration: none;
    transition: all 0.2s ease;
    vertical-align: middle;
    width: 100%;
    text-align: center;
}

.btn .icon {
    font-size: 1.125rem;
    line-height: 1;
    width: 1em;
    height: 1em;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
}

.btn span {
    line-height: 1.2;
    flex: 1;
    text-align: center;
}

/* Fix action buttons in table */
.action-btn {
    width: 40px;
    height: 40px;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    border-radius: 50%;
    border: none;
    transition: all 0.2s ease;
    text-decoration: none;
    flex-shrink: 0;
}

.action-btn .icon {
    font-size: 1.25rem;
    line-height: 1;
}

/* Button colors */
.btn-primary {
    background: #3B82F6;
    border-color: #3B82F6;
    color: white;
}

.btn-warning {
    background: #F59E0B;
    border-color: #F59E0B;
    color: white;
}

.btn-success {
    background: #10B981;
    border-color: #10B981;
    color: white;
}

.btn-outline-danger {
    background: transparent;
    border-color: #EF4444;
    color: #EF4444;
}

.btn-outline-danger:hover {
    background: #EF4444;
    color: white;
}

/* Button group spacing */
.d-grid.gap-12 {
    gap: 12px;
}

/* Table action buttons */
.d-flex.gap-10 {
    gap: 10px;
}

/* Consistent icon sizes */
.icon.text-lg {
    font-size: 1.25rem !important;
}

.icon.text-xl {
    font-size: 1.5rem !important;
}

/* Fix icon alignment globally */
.icon {
    line-height: 1;
    vertical-align: middle;
    display: inline-flex;
    align-items: center;
    justify-content: center;
}

/* Fix table action buttons */
.bg-success-focus,
.bg-danger-focus,
.bg-warning-focus,
.bg-info-focus,
.bg-primary-focus {
    width: 40px;
    height: 40px;
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: 50%;
    transition: all 0.3s ease;
    border: none;
}

.bg-success-focus:hover,
.bg-danger-focus:hover,
.bg-warning-focus:hover,
.bg-info-focus:hover,
.bg-primary-focus:hover {
    transform: scale(1.1);
}

/* Button hover effects */
.bg-hover-success-200:hover {
    background-color: rgba(16, 185, 129, 0.2) !important;
}

.bg-hover-danger-200:hover {
    background-color: rgba(239, 68, 68, 0.2) !important;
}

.bg-hover-warning-200:hover {
    background-color: rgba(245, 158, 11, 0.2) !important;
}

.bg-hover-info-200:hover {
    background-color: rgba(6, 182, 212, 0.2) !important;
}

.bg-hover-primary-200:hover {
    background-color: rgba(59, 130, 246, 0.2) !important;
}

/* Fix table responsive issues */
.table-responsive {
    border-radius: 12px;
}

/* Ensure proper alignment in action cells */
.text-center .d-flex {
    justify-content: center;
    align-items: center;
}

/* Fix button text alignment in grid */
.d-grid .btn {
    display: flex !important;
    align-items: center;
    justify-content: center;
}
</style>

<?php include './partials/layouts/layoutBottom.php'; ?>
<script>
$(document).ready(function() {
    console.log('Group details page loaded');

    // Toggle group status
    $(".toggle-status").on("click", function() {
        var id = $(this).data('id');
        var action = "toggle_status";
        console.log('Toggle status clicked for group:', id);
        
        if(confirm("Are you sure you want to change this group's status?")) {
            $.post("group-action.php", {id: id, action: action}, function(response) {
                console.log('Toggle response:', response);
                if(response.success) {
                    location.reload();
                } else {
                    alert("Error: " + response.message);
                }
            }, "json").fail(function(xhr, status, error) {
                console.error('Toggle failed:', error);
                alert("Request failed. Please try again.");
            });
        }
    });

    // Delete group
    $(".delete-group").on("click", function() {
        var id = $(this).data('id');
        var action = "delete";
        console.log('Delete group clicked:', id);
        
        if(confirm("Are you sure you want to delete this group? This will also remove all group members.")) {
            $.post("group-action.php", {id: id, action: action}, function(response) {
                console.log('Delete response:', response);
                if(response.success) {
                    window.location.href = "groups-list.php";
                } else {
                    alert("Error: " + response.message);
                }
            }, "json").fail(function(xhr, status, error) {
                console.error('Delete failed:', error);
                alert("Request failed. Please try again.");
            });
        }
    });

    // Make member admin
    $(document).on("click", ".make-admin", function() {
        var userId = $(this).data('user-id');
        var groupId = $(this).data('group-id');
        console.log('Make admin clicked - User:', userId, 'Group:', groupId);
        
        if(confirm("Are you sure you want to make this member an admin?")) {
            $.post("group-member-action.php", {user_id: userId, group_id: groupId, action: "make_admin"}, function(response) {
                console.log('Make admin response:', response);
                if(response.success) {
                    location.reload();
                } else {
                    alert("Error: " + response.message);
                }
            }, "json").fail(function(xhr, status, error) {
                console.error('Make admin failed:', error);
                alert("Request failed. Please try again.");
            });
        }
    });

    // Remove member
    $(document).on("click", ".remove-member", function() {
        var userId = $(this).data('user-id');
        var groupId = $(this).data('group-id');
        console.log('Remove member clicked - User:', userId, 'Group:', groupId);
        
        if(confirm("Are you sure you want to remove this member from the group?")) {
            $.post("group-member-action.php", {user_id: userId, group_id: groupId, action: "remove_member"}, function(response) {
                console.log('Remove member response:', response);
                if(response.success) {
                    location.reload();
                } else {
                    alert("Error: " + response.message);
                }
            }, "json").fail(function(xhr, status, error) {
                console.error('Remove member failed:', error);
                alert("Request failed. Please try again.");
            });
        }
    });
});
</script>
