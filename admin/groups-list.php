<?php
include './includes/db.php';
include './includes/admin-auth.php';

// Debug: Check for database errors
if (isset($db_connection_error)) {
    echo '<div style="background:red;color:white;padding:20px;margin:20px;">Database Connection Failed: ' . htmlspecialchars($db_connection_error) . '</div>';
    exit;
}

include './partials/layouts/layoutTop.php';

// Check if 'groups' table exists
$groups_table_check = $conn->query("SHOW TABLES LIKE 'groups'");
if (!$groups_table_check || $groups_table_check->num_rows == 0) {
    echo '<div class="alert alert-warning m-24">Groups table does not exist in database. Please create the table first.</div>';
    include './partials/layouts/layoutBottom.php';
    exit;
}

// Check if group_chat_messages table exists
$table_check = $conn->query("SHOW TABLES LIKE 'group_chat_messages'");
$has_chat_table = ($table_check && $table_check->num_rows > 0);

// Simplified query that works with or without chat messages table
if ($has_chat_table) {
    $sql = "SELECT g.*,
               COUNT(DISTINCT gm.user_id) as member_count,
               u.name as created_by_name,
               COUNT(DISTINCT CASE WHEN m.status = 'active' THEN m.id END) as active_messages,
               COUNT(DISTINCT CASE WHEN m.status = 'blocked' THEN m.id END) as blocked_messages,
               MAX(m.created_at) as last_message_time
        FROM `groups` g
        LEFT JOIN group_members gm ON g.id = gm.group_id
        LEFT JOIN users u ON g.created_by = u.id
        LEFT JOIN group_chat_messages m ON g.id = m.group_id AND m.status != 'deleted'
        GROUP BY g.id
        ORDER BY last_message_time DESC, g.created_at DESC";
} else {
    $sql = "SELECT g.*,
               COUNT(DISTINCT gm.user_id) as member_count,
               u.name as created_by_name
        FROM `groups` g
        LEFT JOIN group_members gm ON g.id = gm.group_id
        LEFT JOIN users u ON g.created_by = u.id
        GROUP BY g.id
        ORDER BY g.created_at DESC";
}

$groups = $conn->query($sql);

// Show error if query fails and stop
if (!$groups) {
    echo '<div class="alert alert-danger m-24">Database Error: ' . $conn->error . '</div>';
    include './partials/layouts/layoutBottom.php';
    exit;
}

?>

<div class="dashboard-main-body">
    <div class="d-flex flex-wrap align-items-center justify-content-between gap-3 mb-24">
        <h6 class="fw-semibold mb-0">Group Management</h6>
        <ul class="d-flex align-items-center gap-2">
            <li class="fw-medium">
                <a href="index.php" class="d-flex align-items-center gap-1 hover-text-primary">
                    <iconify-icon icon="solar:home-smile-angle-outline" class="icon text-lg"></iconify-icon>
                    Dashboard
                </a>
            </li>
            <li>-</li>
            <li class="fw-medium">Groups</li>
        </ul>
    </div>

    <div class="card h-100 p-0 radius-12">
        <div class="card-header border-bottom bg-base py-16 px-24 d-flex align-items-center flex-wrap gap-3 justify-content-between">
            <div class="d-flex align-items-center flex-wrap gap-3">
                <div class="navbar-search position-relative">
                    <input type="text" id="group-search" class="bg-base h-40-px w-auto ps-40" placeholder="Search groups">
                    <iconify-icon icon="mdi:magnify" class="icon position-absolute" style="left: 10px; top: 50%; transform: translateY(-50%);"></iconify-icon>
                </div>
                
                <select id="status-filter" class="form-select form-select-sm w-auto ps-12 py-6 radius-12 h-40-px">
                    <option value="">All Status</option>
                    <option value="Active">Active</option>
                    <option value="Inactive">Inactive</option>
                </select>
            </div>
            <a href="add-group.php" class="btn btn-primary text-sm btn-sm px-12 py-12 radius-8 d-flex align-items-center gap-2">
                <iconify-icon icon="ic:baseline-plus" class="icon text-xl line-height-1"></iconify-icon>
                Create Group
            </a>
        </div>

        <div class="card-body p-24">
            <div class="table-responsive scroll-sm">
                <table class="table bordered-table sm-table mb-0">
                    <thead>
                        <tr>
                            <th>ID</th>
                            <th>Group Name</th>
                            <th>Category</th>
                            <th>Members</th>
                            <th>Chat Activity</th>
                            <th>Blocked</th>
                            <th>Last Active</th>
                            <th>Created By</th>
                            <th>Status</th>
                            <th>Created</th>
                            <th class="text-center">Actions</th>
                        </tr>
                    </thead>
                    <tbody id="groups-table-body">
                        <?php if ($groups && $groups->num_rows > 0): ?>
                            <?php while ($group = $groups->fetch_assoc()): ?>
                                <?php
                                $lastActive = $group['last_message_time'] ? date('M j, Y g:i A', strtotime($group['last_message_time'])) : 'No activity';
                                $timeAgo = $group['last_message_time'] ? time_elapsed_string($group['last_message_time']) : 'Never';
                                ?>
                                <tr>
                                    <td><?php echo $group['id']; ?></td>
                                    <td>
                                        <div class="d-flex align-items-center">
                                            <?php if (!empty($group['group_image'])): ?>
                                                <img src="<?php echo $group['group_image']; ?>" class="w-40-px h-40-px rounded-circle me-12">
                                            <?php endif; ?>
                                            <div>
                                                <div class="fw-medium"><?php echo htmlspecialchars($group['name']); ?></div>
                                                <small class="text-muted"><?php echo htmlspecialchars($group['description']); ?></small>
                                            </div>
                                        </div>
                                    </td>
                                    <td>
                                        <span class="badge bg-primary"><?php echo htmlspecialchars($group['category']); ?></span>
                                    </td>
                                    <td>
                                        <span class="fw-medium"><?php echo $group['member_count']; ?> members</span>
                                    </td>
                                    <td>
                                        <div class="d-flex align-items-center gap-2">
                                            <iconify-icon icon="mdi:message-text" class="text-success"></iconify-icon>
                                            <span class="fw-medium"><?php echo $group['active_messages']; ?> messages</span>
                                        </div>
                                    </td>
                                    <td>
                                        <?php if ($group['blocked_messages'] > 0): ?>
                                            <span class="badge bg-danger">
                                                <iconify-icon icon="mdi:block-helper"></iconify-icon>
                                                <?php echo $group['blocked_messages']; ?> blocked
                                            </span>
                                        <?php else: ?>
                                            <span class="text-muted">None</span>
                                        <?php endif; ?>
                                    </td>
                                    <td>
                                        <div class="text-sm">
                                            <div><?php echo $lastActive; ?></div>
                                            <small class="text-muted"><?php echo $timeAgo; ?></small>
                                        </div>
                                    </td>
                                    <td><?php echo htmlspecialchars($group['created_by_name']); ?></td>
                                    <td>
                                        <span class="badge bg-<?php echo $group['status'] == 'Active' ? 'success' : 'danger'; ?>">
                                            <?php echo $group['status']; ?>
                                        </span>
                                    </td>
                                    <td><?php echo date('M j, Y', strtotime($group['created_at'])); ?></td>
                                    <td class="text-center">
                                        <div class="d-flex align-items-center gap-10 justify-content-center">
                                            <a href="group-details.php?id=<?php echo $group['id']; ?>" class="bg-info-focus bg-hover-info-200 text-info-600 fw-medium w-40-px h-40-px d-flex justify-content-center align-items-center rounded-circle" title="View Group">
                                                <iconify-icon icon="mdi:eye-outline" class="icon text-xl"></iconify-icon>
                                            </a>
                                            
                                            <a href="group-chat.php?id=<?php echo $group['id']; ?>" class="bg-success-focus bg-hover-success-200 text-success-600 fw-medium w-40-px h-40-px d-flex justify-content-center align-items-center rounded-circle" title="View Group Chat">
                                                <iconify-icon icon="mdi:chat-outline" class="icon text-xl"></iconify-icon>
                                            </a>
                                            
                                            <a href="edit-group.php?id=<?php echo $group['id']; ?>" class="bg-primary-focus bg-hover-primary-200 text-primary-600 fw-medium w-40-px h-40-px d-flex justify-content-center align-items-center rounded-circle" title="Edit Group">
                                                <iconify-icon icon="mdi:pencil-outline" class="icon text-xl"></iconify-icon>
                                            </a>
                                            
                                            <button type="button" class="toggle-status bg-<?php echo $group['status'] == 'Active' ? 'warning' : 'success'; ?>-focus bg-hover-<?php echo $group['status'] == 'Active' ? 'warning' : 'success'; ?>-200 text-<?php echo $group['status'] == 'Active' ? 'warning' : 'success'; ?>-600 fw-medium w-40-px h-40-px d-flex justify-content-center align-items-center rounded-circle" 
                                                    data-id="<?php echo $group['id']; ?>" title="<?php echo $group['status'] == 'Active' ? 'Deactivate' : 'Activate'; ?>">
                                                <iconify-icon icon="<?php echo $group['status'] == 'Active' ? 'fluent:block-24-regular' : 'mdi:check'; ?>" class="icon text-xl"></iconify-icon>
                                            </button>
                                            
                                            <button type="button" class="delete-group bg-danger-focus bg-hover-danger-200 text-danger-600 fw-medium w-40-px h-40-px d-flex justify-content-center align-items-center rounded-circle" 
                                                    data-id="<?php echo $group['id']; ?>" title="Delete Group">
                                                <iconify-icon icon="fluent:delete-24-regular" class="icon text-xl"></iconify-icon>
                                            </button>
                                        </div>
                                    </td>
                                </tr>
                            <?php endwhile; ?>
                        <?php else: ?>
                            <tr>
                                <td colspan="11" class="text-center">No groups found.</td>
                            </tr>
                        <?php endif; ?>
                    </tbody>
                </table>
            </div>
        </div>
    </div>
</div>

<?php 
function time_elapsed_string($datetime, $full = false) {
    $now = new DateTime;
    $ago = new DateTime($datetime);
    $diff = $now->diff($ago);

    $weeks = floor($diff->d / 7);
    $diff->d -= $weeks * 7;

    $string = array(
        'y' => 'year',
        'm' => 'month',
        'w' => 'week',
        'd' => 'day',
        'h' => 'hour',
        'i' => 'minute',
        's' => 'second',
    );
    foreach ($string as $k => &$v) {
        $val = ($k === 'w') ? $weeks : $diff->$k;
        if ($val) {
            $v = $val . ' ' . $v . ($val > 1 ? 's' : '');
        } else {
            unset($string[$k]);
        }
    }

    if (!$full) $string = array_slice($string, 0, 1);
    return $string ? implode(', ', $string) . ' ago' : 'just now';
}

include './partials/layouts/layoutBottom.php'; 
?>

<script>
$(document).ready(function() {
    function loadGroups() {
        let query = $("#group-search").val();
        let status = $("#status-filter").val();

        $.post("groups-search.php", {search: query, status: status}, function(data) {
            $("#groups-table-body").html(data);
        });
    }

    // Search functionality
    $("#group-search").on("keyup", function() {
        loadGroups();
    });

    // Status filter
    $("#status-filter").on("change", function() {
        loadGroups();
    });

    // Toggle status
    $(document).on("click", ".toggle-status", function() {
        let id = $(this).data("id");
        let action = "toggle_status";
        
        if(confirm("Are you sure you want to change this group's status?")) {
            $.post("group-action.php", {id: id, action: action}, function(res) {
                if(res.success) {
                    loadGroups();
                } else {
                    alert(res.message || "Action failed");
                }
            }, "json").fail(function() {
                alert("Request failed. Please try again.");
            });
        }
    });

    // Delete group
    $(document).on("click", ".delete-group", function() {
        let id = $(this).data("id");
        let action = "delete";
        
        if(confirm("Are you sure you want to delete this group? This will also remove all group members and chat messages.")) {
            $.post("group-action.php", {id: id, action: action}, function(res) {
                if(res.success) {
                    loadGroups();
                } else {
                    alert(res.message || "Delete failed");
                }
            }, "json").fail(function() {
                alert("Request failed. Please try again.");
            });
        }
    });
});
</script>