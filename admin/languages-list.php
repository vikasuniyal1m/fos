<?php
include './includes/db.php';
include './includes/admin-auth.php';
include './partials/layouts/layoutTop.php';

// Handle actions
if (isset($_POST['action'])) {
    $id = intval($_POST['id']);
    $action = $conn->real_escape_string($_POST['action']);
    
    if ($action == 'delete') {
        $conn->query("DELETE FROM languages WHERE id = $id");
    } elseif ($action == 'toggle_status') {
        $current = $conn->query("SELECT status FROM languages WHERE id = $id")->fetch_assoc();
        $new_status = $current['status'] == 'Active' ? 'Inactive' : 'Active';
        $conn->query("UPDATE languages SET status = '$new_status' WHERE id = $id");
    } elseif ($action == 'set_default') {
        // Remove default from all languages
        $conn->query("UPDATE languages SET is_default = 0");
        // Set new default
        $conn->query("UPDATE languages SET is_default = 1 WHERE id = $id");
    }
}

// Get all languages
$languages = $conn->query("SELECT * FROM languages ORDER BY is_default DESC, name");
?>

<div class="dashboard-main-body">
    <div class="d-flex flex-wrap align-items-center justify-content-between gap-3 mb-24">
        <h6 class="fw-semibold mb-0">Language Management</h6>
        <ul class="d-flex align-items-center gap-2">
            <li class="fw-medium">
                <a href="index.php" class="d-flex align-items-center gap-1 hover-text-primary">
                    <iconify-icon icon="solar:home-smile-angle-outline" class="icon text-lg"></iconify-icon>
                    Dashboard
                </a>
            </li>
            <li>-</li>
            <li class="fw-medium">Languages</li>
        </ul>
    </div>

    <div class="card h-100 p-0 radius-12">
        <div class="card-header border-bottom bg-base py-16 px-24 d-flex align-items-center flex-wrap gap-3 justify-content-between">
            <div class="d-flex align-items-center flex-wrap gap-3">
                <form class="navbar-search">
                    <input type="text" id="language-search" class="bg-base h-40-px w-auto" placeholder="Search languages">
                    <iconify-icon icon="ion:search-outline" class="icon"></iconify-icon>
                </form>
                
                <select id="status-filter" class="form-select form-select-sm w-auto ps-12 py-6 radius-12 h-40-px">
                    <option value="">All Status</option>
                    <option value="Active">Active</option>
                    <option value="Inactive">Inactive</option>
                </select>
            </div>
            <a href="add-language.php" class="btn btn-primary text-sm btn-sm px-12 py-12 radius-8 d-flex align-items-center gap-2">
                <iconify-icon icon="ic:baseline-plus" class="icon text-xl line-height-1"></iconify-icon>
                Add Language
            </a>
        </div>

        <div class="card-body p-24">
            <div class="table-responsive scroll-sm">
                <table class="table bordered-table sm-table mb-0">
                    <thead>
                        <tr>
                            <th>ID</th>
                            <th>Language</th>
                            <th>Code</th>
                            <th>Native Name</th>
                            <th>Translation Progress</th>
                            <th>Status</th>
                            <th>Default</th>
                            <th class="text-center">Actions</th>
                        </tr>
                    </thead>
                    <tbody id="languages-table-body">
                        <?php if ($languages->num_rows > 0): ?>
                            <?php while ($language = $languages->fetch_assoc()): ?>
                                <tr>
                                    <td><?php echo $language['id']; ?></td>
                                    <td>
                                        <div class="d-flex align-items-center">
                                            <?php if (!empty($language['flag_icon'])): ?>
                                                <img src="<?php echo $language['flag_icon']; ?>" class="w-30-px h-20-px me-12">
                                            <?php endif; ?>
                                            <div class="fw-medium"><?php echo htmlspecialchars($language['name']); ?></div>
                                        </div>
                                    </td>
                                    <td>
                                        <code><?php echo htmlspecialchars($language['code']); ?></code>
                                    </td>
                                    <td><?php echo htmlspecialchars($language['native_name']); ?></td>
                                    <td>
                                        <div class="d-flex align-items-center">
                                            <div class="progress flex-grow-1 me-12" style="height: 8px;">
                                                <div class="progress-bar" style="width: <?php echo $language['translation_progress']; ?>%"></div>
                                            </div>
                                            <span class="text-sm"><?php echo $language['translation_progress']; ?>%</span>
                                        </div>
                                    </td>
                                    <td>
                                        <span class="badge bg-<?php echo $language['status'] == 'Active' ? 'success' : 'danger'; ?>">
                                            <?php echo $language['status']; ?>
                                        </span>
                                    </td>
                                    <td>
                                        <?php if ($language['is_default']): ?>
                                            <span class="badge bg-primary">Default</span>
                                        <?php else: ?>
                                            <span class="text-muted">-</span>
                                        <?php endif; ?>
                                    </td>
                                    <td class="text-center">
                                        <div class="d-flex align-items-center gap-10 justify-content-center">
                                            <a href="translations.php?lang=<?php echo $language['code']; ?>" class="bg-info-focus bg-hover-info-200 text-info-600 fw-medium w-40-px h-40-px d-flex justify-content-center align-items-center rounded-circle" title="Manage Translations">
                                                <iconify-icon icon="mdi:translate" class="icon text-xl"></iconify-icon>
                                            </a>
                                            
                                            <a href="edit-language.php?id=<?php echo $language['id']; ?>" class="bg-primary-focus bg-hover-primary-200 text-primary-600 fw-medium w-40-px h-40-px d-flex justify-content-center align-items-center rounded-circle" title="Edit Language">
                                                <iconify-icon icon="mdi:pencil-outline" class="icon text-xl"></iconify-icon>
                                            </a>
                                            
                                            <?php if (!$language['is_default']): ?>
                                                <button type="button" class="set-default bg-success-focus bg-hover-success-200 text-success-600 fw-medium w-40-px h-40-px d-flex justify-content-center align-items-center rounded-circle" 
                                                        data-id="<?php echo $language['id']; ?>" title="Set as Default">
                                                    <iconify-icon icon="mdi:star" class="icon text-xl"></iconify-icon>
                                                </button>
                                            <?php endif; ?>
                                            
                                            <button type="button" class="toggle-status bg-<?php echo $language['status'] == 'Active' ? 'warning' : 'success'; ?>-focus bg-hover-<?php echo $language['status'] == 'Active' ? 'warning' : 'success'; ?>-200 text-<?php echo $language['status'] == 'Active' ? 'warning' : 'success'; ?>-600 fw-medium w-40-px h-40-px d-flex justify-content-center align-items-center rounded-circle" 
                                                    data-id="<?php echo $language['id']; ?>" title="<?php echo $language['status'] == 'Active' ? 'Deactivate' : 'Activate'; ?>">
                                                <iconify-icon icon="<?php echo $language['status'] == 'Active' ? 'fluent:block-24-regular' : 'mdi:check'; ?>" class="icon text-xl"></iconify-icon>
                                            </button>
                                            
                                            <?php if (!$language['is_default']): ?>
                                                <button type="button" class="delete-language bg-danger-focus bg-hover-danger-200 text-danger-600 fw-medium w-40-px h-40-px d-flex justify-content-center align-items-center rounded-circle" 
                                                        data-id="<?php echo $language['id']; ?>" title="Delete Language">
                                                    <iconify-icon icon="fluent:delete-24-regular" class="icon text-xl"></iconify-icon>
                                                </button>
                                            <?php endif; ?>
                                        </div>
                                    </td>
                                </tr>
                            <?php endwhile; ?>
                        <?php else: ?>
                            <tr>
                                <td colspan="8" class="text-center">No languages found.</td>
                            </tr>
                        <?php endif; ?>
                    </tbody>
                </table>
            </div>
        </div>
    </div>
</div>

<script>
$(document).ready(function() {
    // Search functionality
    $("#language-search").on("keyup", function() {
        var value = $(this).val().toLowerCase();
        $("#languages-table-body tr").filter(function() {
            $(this).toggle($(this).text().toLowerCase().indexOf(value) > -1)
        });
    });

    // Status filter
    $("#status-filter").on("change", function() {
        var value = $(this).val().toLowerCase();
        $("#languages-table-body tr").filter(function() {
            if (value === "") {
                $(this).show();
            } else {
                $(this).toggle($(this).find('td:eq(5)').text().toLowerCase().indexOf(value) > -1);
            }
        });
    });

    // Set as default
    $(document).on("click", ".set-default", function() {
        var id = $(this).data('id');
        if (confirm("Are you sure you want to set this as the default language?")) {
            $.post("language-action.php", {id: id, action: "set_default"}, function(response) {
                if (response.success) {
                    location.reload();
                } else {
                    alert("Error: " + response.message);
                }
            }, "json");
        }
    });

    // Toggle status
    $(document).on("click", ".toggle-status", function() {
        var id = $(this).data('id');
        if (confirm("Are you sure you want to change this language's status?")) {
            $.post("language-action.php", {id: id, action: "toggle_status"}, function(response) {
                if (response.success) {
                    location.reload();
                } else {
                    alert("Error: " + response.message);
                }
            }, "json");
        }
    });

    // Delete language
    $(document).on("click", ".delete-language", function() {
        var id = $(this).data('id');
        if (confirm("Are you sure you want to delete this language?")) {
            $.post("language-action.php", {id: id, action: "delete"}, function(response) {
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

<?php include './partials/layouts/layoutBottom.php'; ?>