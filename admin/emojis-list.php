<?php
include './includes/db.php';
include './includes/admin-auth.php';
include './partials/layouts/layoutTop.php';

// Handle actions
if (isset($_POST['action'])) {
    $id = intval($_POST['id']);
    $action = $conn->real_escape_string($_POST['action']);
    
    if ($action == 'delete') {
        // Get emoji data before deleting to remove image file
        $emoji_data = $conn->query("SELECT image_url FROM emojis WHERE id = $id")->fetch_assoc();
        
        // Delete uploaded image file if exists
        if (!empty($emoji_data['image_url']) && strpos($emoji_data['image_url'], './uploads/emojis/') === 0) {
            $file_path = $emoji_data['image_url'];
            if (file_exists($file_path)) {
                unlink($file_path);
            }
        }
        
        $conn->query("DELETE FROM emojis WHERE id = $id");
    } elseif ($action == 'toggle_status') {
        $current = $conn->query("SELECT status FROM emojis WHERE id = $id")->fetch_assoc();
        $new_status = $current['status'] == 'Active' ? 'Inactive' : 'Active';
        $conn->query("UPDATE emojis SET status = '$new_status' WHERE id = $id");
    }
}

// Get all emojis
$emojis = $conn->query("SELECT * FROM emojis ORDER BY category, name");
?>

<div class="dashboard-main-body">
    <div class="d-flex flex-wrap align-items-center justify-content-between gap-3 mb-24">
        <h6 class="fw-semibold mb-0">Emoji Management</h6>
        <ul class="d-flex align-items-center gap-2">
            <li class="fw-medium">
                <a href="index.php" class="d-flex align-items-center gap-1 hover-text-primary">
                    <iconify-icon icon="solar:home-smile-angle-outline" class="icon text-lg"></iconify-icon>
                    Dashboard
                </a>
            </li>
            <li>-</li>
            <li class="fw-medium">Emojis</li>
        </ul>
    </div>

    <div class="card h-100 p-0 radius-12">
        <div class="card-header border-bottom bg-base py-16 px-24 d-flex align-items-center flex-wrap gap-3 justify-content-between">
            <div class="d-flex align-items-center flex-wrap gap-3">
                <form class="navbar-search">
                    <input type="text" id="emoji-search" class="bg-base h-40-px w-auto" placeholder="Search emojis">
                    <iconify-icon icon="ion:search-outline" class="icon"></iconify-icon>
                </form>
                
                <select id="category-filter" class="form-select form-select-sm w-auto ps-12 py-6 radius-12 h-40-px">
                    <option value="">All Categories</option>
                    <option value="Love">Love</option>
                    <option value="Joy">Joy</option>
                    <option value="Peace">Peace</option>
                    <option value="Patience">Patience</option>
                    <option value="Kindness">Kindness</option>
                    <option value="Goodness">Goodness</option>
                    <option value="Faithfulness">Faithfulness</option>
                    <option value="Gentleness">Gentleness</option>
                    <option value="Self-Control">Self-Control</option>
                </select>
            </div>
            <a href="add-emoji.php" class="btn btn-primary text-sm btn-sm px-12 py-12 radius-8 d-flex align-items-center gap-2">
                <iconify-icon icon="ic:baseline-plus" class="icon text-xl line-height-1"></iconify-icon>
                Add Emoji
            </a>
        </div>

        <div class="card-body p-24">
            <div class="table-responsive scroll-sm">
                <table class="table bordered-table sm-table mb-0">
                    <thead>
                        <tr>
                            <th>ID</th>
                            <th>Image</th>
                            <th>Name</th>
                            <th>Category</th>
                            <th>Usage Count</th>
                            <th>Status</th>
                            <th>Created</th>
                            <th class="text-center">Actions</th>
                        </tr>
                    </thead>
                    <tbody id="emojis-table-body">
                        <?php if ($emojis->num_rows > 0): ?>
                            <?php while ($emoji = $emojis->fetch_assoc()): ?>
                                <tr>
                                    <td><?php echo $emoji['id']; ?></td>
                                    <td>
                                        <?php if (!empty($emoji['image_url'])): ?>
                                            <img src="<?php echo htmlspecialchars($emoji['image_url']); ?>" 
                                                 class="w-40-px h-40-px object-fit-contain" 
                                                 alt="<?php echo htmlspecialchars($emoji['name']); ?>"
                                                 onerror="this.style.display='none'">
                                        <?php else: ?>
                                            <div class="w-40-px h-40-px bg-light rounded d-flex align-items-center justify-content-center">
                                                <iconify-icon icon="mdi:emoticon-outline" class="text-muted"></iconify-icon>
                                            </div>
                                        <?php endif; ?>
                                    </td>
                                    <td>
                                        <div class="fw-medium"><?php echo htmlspecialchars($emoji['name']); ?></div>
                                        <?php if (!empty($emoji['description'])): ?>
                                            <small class="text-muted"><?php echo htmlspecialchars($emoji['description']); ?></small>
                                        <?php endif; ?>
                                    </td>
                                    <td>
                                        <span class="badge bg-primary"><?php echo htmlspecialchars($emoji['category']); ?></span>
                                    </td>
                                    <td>
                                        <span class="fw-medium"><?php echo $emoji['usage_count']; ?> times</span>
                                    </td>
                                    <td>
                                        <span class="badge bg-<?php echo $emoji['status'] == 'Active' ? 'success' : 'danger'; ?>">
                                            <?php echo $emoji['status']; ?>
                                        </span>
                                    </td>
                                    <td><?php echo date('M j, Y', strtotime($emoji['created_at'])); ?></td>
                                    <td class="text-center">
                                        <div class="d-flex align-items-center gap-10 justify-content-center">
                                            <a href="edit-emoji.php?id=<?php echo $emoji['id']; ?>" class="bg-primary-focus bg-hover-primary-200 text-primary-600 fw-medium w-40-px h-40-px d-flex justify-content-center align-items-center rounded-circle" title="Edit Emoji">
                                                <iconify-icon icon="mdi:pencil-outline" class="icon text-xl"></iconify-icon>
                                            </a>
                                            
                                            <button type="button" class="toggle-status bg-<?php echo $emoji['status'] == 'Active' ? 'warning' : 'success'; ?>-focus bg-hover-<?php echo $emoji['status'] == 'Active' ? 'warning' : 'success'; ?>-200 text-<?php echo $emoji['status'] == 'Active' ? 'warning' : 'success'; ?>-600 fw-medium w-40-px h-40-px d-flex justify-content-center align-items-center rounded-circle" 
                                                    data-id="<?php echo $emoji['id']; ?>" title="<?php echo $emoji['status'] == 'Active' ? 'Deactivate' : 'Activate'; ?>">
                                                <iconify-icon icon="<?php echo $emoji['status'] == 'Active' ? 'fluent:block-24-regular' : 'mdi:check'; ?>" class="icon text-xl"></iconify-icon>
                                            </button>
                                            
                                            <button type="button" class="delete-emoji bg-danger-focus bg-hover-danger-200 text-danger-600 fw-medium w-40-px h-40-px d-flex justify-content-center align-items-center rounded-circle" 
                                                    data-id="<?php echo $emoji['id']; ?>" title="Delete Emoji">
                                                <iconify-icon icon="fluent:delete-24-regular" class="icon text-xl"></iconify-icon>
                                            </button>
                                        </div>
                                    </td>
                                </tr>
                            <?php endwhile; ?>
                        <?php else: ?>
                            <tr>
                                <td colspan="8" class="text-center py-40">
                                    <div class="text-muted">No emojis found.</div>
                                    <a href="add-emoji.php" class="btn btn-primary btn-sm mt-12">Add Your First Emoji</a>
                                </td>
                            </tr>
                        <?php endif; ?>
                    </tbody>
                </table>
            </div>
        </div>
    </div>
</div>

<?php include './partials/layouts/layoutBottom.php'; ?>

<script>
$(document).ready(function() {
    // Search functionality
    $("#emoji-search").on("keyup", function() {
        var value = $(this).val().toLowerCase();
        $("#emojis-table-body tr").filter(function() {
            $(this).toggle($(this).text().toLowerCase().indexOf(value) > -1)
        });
    });

    // Category filter
    $("#category-filter").on("change", function() {
        var value = $(this).val().toLowerCase();
        $("#emojis-table-body tr").filter(function() {
            if (value === "") {
                $(this).show();
            } else {
                $(this).toggle($(this).find('td:eq(3)').text().toLowerCase().indexOf(value) > -1);
            }
        });
    });

    // Toggle status
    $(document).on("click", ".toggle-status", function() {
        var id = $(this).data('id');
        if (confirm("Are you sure you want to change this emoji's status?")) {
            $.post("emoji-action.php", {id: id, action: "toggle_status"}, function(response) {
                if (response.success) {
                    location.reload();
                } else {
                    alert("Error: " + response.message);
                }
            }, "json");
        }
    });

    // Delete emoji
    $(document).on("click", ".delete-emoji", function() {
        var id = $(this).data('id');
        if (confirm("Are you sure you want to delete this emoji? This action cannot be undone.")) {
            $.post("emoji-action.php", {id: id, action: "delete"}, function(response) {
                if (response.success) {
                    location.reload();
                } else {
                    alert("Error: " + response.message);
                }
            }, "json");
        }
    });
});
</script>