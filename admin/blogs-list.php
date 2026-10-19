<?php 
include './includes/db.php';
include './includes/admin-auth.php';
include './partials/layouts/layoutTop.php'; 

// Initial fetch (will be replaced by AJAX)
// Show user name if blogger selected, otherwise show admin name
$sql = "
    SELECT b.*,
           CASE
               WHEN b.user_id IS NOT NULL THEN u.name
               ELSE au.name
           END AS blogger_name,
           CASE WHEN b.user_id IS NULL THEN 'Admin' ELSE 'Blogger' END AS author_type
    FROM blogs b
    LEFT JOIN users u ON b.user_id = u.id
    LEFT JOIN admin_users au ON b.admin_id = au.id
    ORDER BY b.created_at DESC
    LIMIT 10
";
$result = $conn->query($sql);
?>

<div class="dashboard-main-body">
    <div class="d-flex flex-wrap align-items-center justify-content-between gap-3 mb-24">
        <h6 class="fw-semibold mb-0">Blogs Management</h6>
        <ul class="d-flex align-items-center gap-2">
            <li class="fw-medium">
                <a href="index.php" class="d-flex align-items-center gap-1 hover-text-primary">
                    <iconify-icon icon="solar:home-smile-angle-outline" class="icon text-lg"></iconify-icon>
                    Dashboard
                </a>
            </li>
            <li>-</li>
            <li class="fw-medium">Blogs</li>
        </ul>
    </div>

    <div class="card h-100 p-0 radius-12">
        <div class="card-header border-bottom bg-base py-16 px-24 d-flex align-items-center flex-wrap gap-3 justify-content-between">
            <div class="d-flex align-items-center flex-wrap gap-3">
                <span class="text-md fw-medium text-secondary-light mb-0">Show</span>
             <select id="rows-show" class="form-select form-select-sm w-auto ps-12 py-6 radius-12 h-40-px">
    <?php for($i=5;$i<=20;$i+=5): ?>
        <option value="<?= $i ?>" <?= $i==10 ? 'selected':'' ?>><?= $i ?></option>
    <?php endfor; ?>
    <option value="all">All</option> <!-- Add this line -->
</select>

                <form class="navbar-search">
                    <input type="text" id="blog-search" class="bg-base h-40-px w-auto" name="search" placeholder="Search Blogs">
                    <iconify-icon icon="ion:search-outline" class="icon"></iconify-icon>
                </form>

                <select id="status-filter" class="form-select form-select-sm w-auto ps-12 py-6 radius-12 h-40-px">
                    <option value="">All Status</option>
                    <option value="Pending">Pending</option>
                    <option value="Approved">Approved</option>
                    <option value="Rejected">Rejected</option>
                </select>
            </div>
            <a href="add-blog.php" class="btn btn-primary text-sm btn-sm px-12 py-12 radius-8 d-flex align-items-center gap-2">
                <iconify-icon icon="ic:baseline-plus" class="icon text-xl line-height-1"></iconify-icon>
                Add New Blog
            </a>
        </div>

        <div class="card-body p-24">
            <div class="table-responsive scroll-sm">
                <table class="table bordered-table sm-table mb-0">
                    <thead>
                        <tr>
                            <th>S.L</th>
                            <th>Created</th>
                            <th>Title</th>
                            <th>Blogger</th>
                            <th>Status</th>
                            <th class="text-center">Action</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php if($result->num_rows > 0): ?>
                            <?php $sl=1; while($row = $result->fetch_assoc()): ?>
                                <tr>
                                    <td><?= $sl++ ?></td>
                                    <td><?= date("d M Y", strtotime($row['created_at'])) ?></td>
                                    <td>
                                        <a href="blog-view.php?id=<?= $row['id'] ?>" class="text-primary fw-medium">
                                            <?= htmlspecialchars($row['title']) ?>
                                        </a>
                                    </td>
                                    <td>
                                        <?= htmlspecialchars($row['blogger_name'] ?? 'Unknown') ?>
                                        <?php if($row['author_type'] == 'Admin'): ?>
                                            <span class="badge bg-primary ms-1">Admin</span>
                                        <?php else: ?>
                                            <span class="badge bg-info ms-1">Blogger</span>
                                        <?php endif; ?>
                                    </td>
                                    <td>
                                        <?php if($row['status']=='Approved'): ?>
                                            <span class="bg-success-focus text-success-600 border border-success-main px-24 py-4 radius-4 fw-medium text-sm">Approved</span>
                                        <?php elseif($row['status']=='Rejected'): ?>
                                            <span class="bg-danger-focus text-danger-600 border border-danger-main px-24 py-4 radius-4 fw-medium text-sm">Rejected</span>
                                        <?php else: ?>
                                            <span class="bg-warning-focus text-warning-600 border border-warning-main px-24 py-4 radius-4 fw-medium text-sm">Pending</span>
                                        <?php endif; ?>
                                    </td>
                                    <td class="text-center">
    <div class="d-flex align-items-center gap-10 justify-content-center">
        <?php if($row['status']!='Approved'): ?>
            <button type="button" 
                    class="change-status bg-success-focus bg-hover-success-200 text-success-600 fw-medium w-40-px h-40-px d-flex justify-content-center align-items-center rounded-circle"
                    data-id="<?= $row['id'] ?>" data-action="approve" title="Approve Blog">
                <iconify-icon icon="mdi:check" class="icon text-xl"></iconify-icon>
            </button>
        <?php endif; ?>

        <?php if($row['status']!='Rejected'): ?>
            <button type="button" 
                    class="change-status bg-warning-focus bg-hover-warning-200 text-warning-600 fw-medium w-40-px h-40-px d-flex justify-content-center align-items-center rounded-circle"
                    data-id="<?= $row['id'] ?>" data-action="reject" title="Reject Blog">
                <iconify-icon icon="fluent:block-24-regular" class="icon text-xl"></iconify-icon>
            </button>
        <?php endif; ?>

        <!-- View Blog -->
        <a href="blog-view.php?id=<?= $row['id'] ?>" 
           class="bg-info-focus bg-hover-info-200 text-info-600 fw-medium w-40-px h-40-px d-flex justify-content-center align-items-center rounded-circle"
           title="View Blog">
            <iconify-icon icon="mdi:eye-outline" class="icon text-xl"></iconify-icon>
        </a>

        <!-- ✏️ Edit Blog -->
        <a href="edit-blog.php?id=<?= $row['id'] ?>" 
           class="bg-primary-focus bg-hover-primary-200 text-primary-600 fw-medium w-40-px h-40-px d-flex justify-content-center align-items-center rounded-circle"
           title="Edit Blog">
            <iconify-icon icon="mdi:pencil-outline" class="icon text-xl"></iconify-icon>
        </a>

        <!-- Delete Blog -->
        <button type="button" 
                class="delete-blog bg-danger-focus bg-hover-danger-200 text-danger-600 fw-medium w-40-px h-40-px d-flex justify-content-center align-items-center rounded-circle"
                data-id="<?= $row['id'] ?>" title="Delete Blog">
            <iconify-icon icon="fluent:delete-24-regular" class="icon text-xl"></iconify-icon>
        </button>
    </div>
</td>

                                    
                                </tr>
                            <?php endwhile; ?>
                        <?php else: ?>
                            <tr><td colspan="6" class="text-center">No blogs found.</td></tr>
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
    function loadBlogs() {
        let query = $("#blog-search").val();
        let status = $("#status-filter").val();
        let limit  = $("#rows-show").val();

        $.post("blogs-search.php", {search: query, status: status, limit: limit}, function(data) {
            $("table tbody").html(data);
        });
    }

    $("#blog-search").on("keyup", loadBlogs);
    $("#status-filter").on("change", loadBlogs);
    $("#rows-show").on("change", loadBlogs);

    $(document).on("click", ".change-status", function() {
        let id = $(this).data("id");
        let action = $(this).data("action");
        if(confirm(`Are you sure you want to ${action} this blog?`)) {
            $.post("blogs-action.php", {id: id, action: action}, function(res) {
                if(res.success) loadBlogs();
                else alert(res.message);
            }, "json");
        }
    });

    $(document).on("click", ".delete-blog", function() {
        let id = $(this).data("id");
        if(confirm("Are you sure you want to delete this blog?")) {
            $.post("blogs-action.php", {id: id, action: "delete"}, function(res) {
                if(res.success) loadBlogs();
                else alert(res.message);
            }, "json");
        }
    });

    loadBlogs();
});
</script>
