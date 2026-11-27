<?php 
include './includes/db.php';
include './includes/admin-auth.php';
$script = ''; // optional, you already use layoutTop
include './partials/layouts/layoutTop.php'; 
?>

<div class="dashboard-main-body">
    <div class="d-flex flex-wrap align-items-center justify-content-between gap-3 mb-24">
        <h6 class="fw-semibold mb-0">Comments</h6>
        <ul class="d-flex align-items-center gap-2">
            <li class="fw-medium">
                <a href="index.php" class="d-flex align-items-center gap-1 hover-text-primary">
                    <iconify-icon icon="solar:home-smile-angle-outline" class="icon text-lg"></iconify-icon>
                    Dashboard
                </a>
            </li>
            <li>-</li>
            <li class="fw-medium">Comments</li>
        </ul>
    </div>

    <div class="card h-100 p-0 radius-12">
        <div class="card-header border-bottom bg-base py-16 px-24 d-flex align-items-center flex-wrap gap-3 justify-content-between">
            <div class="d-flex align-items-center flex-wrap gap-3">
                <span class="text-md fw-medium text-secondary-light mb-0">Show</span>
              <select id="rows-show" class="form-select form-select-sm w-auto ps-12 py-6 radius-12 h-40-px">
    <?php for($i=1;$i<=10;$i++): ?>
        <option value="<?= $i ?>" <?= $i == 10 ? 'selected' : '' ?>><?= $i ?></option>
    <?php endfor; ?>
    <option value="all">All</option> 
</select>

                <form class="navbar-search">
                    <input type="text" id="comment-search" class="bg-base h-40-px w-auto" name="search" placeholder="Search comment or user">
                    <iconify-icon icon="ion:search-outline" class="icon"></iconify-icon>
                </form>

                <select id="status-filter" class="form-select form-select-sm w-auto ps-12 py-6 radius-12 h-40-px">
                    <option value="">Status</option>
                    <option value="pending">Pending</option>
                    <option value="approved">Approved</option>
                    <option value="rejected">Rejected</option>
                </select>

                <select id="posttype-filter" class="form-select form-select-sm w-auto ps-12 py-6 radius-12 h-40-px">
                    <option value="">Post Type</option>
                    <option value="prayer">Prayer</option>
                    <option value="blog">Blog</option>
                    <option value="video">Video</option>
                    <option value="gallery">Gallery</option>
                    <option value="story">Story</option>
                </select>
            </div>
        </div>

        <div class="card-body p-24">
            <div class="table-responsive scroll-sm">
                <table class="table bordered-table sm-table mb-0">
                    <thead>
                        <tr>
                            <th>S.L</th>
                            <th>Date</th>
                            <th>User</th>
                            <th>Post Type</th>
                            <th>Comment</th>
                            <th class="text-center">Status</th>
                            <th class="text-center">Action</th>
                        </tr>
                    </thead>
                    <tbody id="comments-table-body">
                        <!-- Loaded via AJAX -->
                    </tbody>
                </table>
            </div>
        </div>
    </div>
</div>

<?php include './partials/layouts/layoutBottom.php'; ?>

<script>
$(document).ready(function() {
    function loadComments() {
        let query   = $("#comment-search").val();
        let status  = $("#status-filter").val();
        let limit   = $("#rows-show").val();
        let postType= $("#posttype-filter").val();

        $.post("comments-search.php", {search: query, status: status, limit: limit, post_type: postType}, function(data) {
            $("#comments-table-body").html(data);
        });
    }

    // Filters
    $("#comment-search").on("keyup", loadComments);
    $("#status-filter").on("change", loadComments);
    $("#rows-show").on("change", loadComments);
    $("#posttype-filter").on("change", loadComments);

    // Approve / Reject / Delete
    $(document).on("click", ".change-status", function() {
        let id = $(this).data("id");
        let action = $(this).data("action");
        if(confirm(`Are you sure you want to ${action} this comment?`)) {
            $.post("comments-action.php", {id: id, action: action}, function(res) {
                if(res.success) loadComments();
                else alert(res.message);
            }, "json");
        }
    });

    $(document).on("click", ".delete-comment", function() {
        let id = $(this).data("id");
        if(confirm("Are you sure you want to delete this comment?")) {
            $.post("comments-action.php", {id: id, action: "delete"}, function(res) {
                if(res.success) loadComments();
                else alert(res.message);
            }, "json");
        }
    });

    // Initial load
    loadComments();
});
</script>
