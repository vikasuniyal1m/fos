<?php
include './includes/db.php';
include './includes/admin-auth.php';
include './partials/layouts/layoutTop.php';
?>

<div class="dashboard-main-body">
    <div class="d-flex flex-wrap align-items-center justify-content-between gap-3 mb-24">
        <h6 class="fw-semibold mb-0">Shorts Moderation</h6>
        <ul class="d-flex align-items-center gap-2">
            <li class="fw-medium">
                <a href="index.php" class="d-flex align-items-center gap-1 hover-text-primary">
                    <iconify-icon icon="mdi:home-outline" class="icon text-lg"></iconify-icon>
                    Dashboard
                </a>
            </li>
            <li>-</li>
            <li class="fw-medium">Shorts</li>
        </ul>
    </div>

    <div class="card h-100 p-0 radius-12">
        <div class="card-header border-bottom bg-base py-16 px-24 d-flex align-items-center flex-wrap gap-3 justify-content-between">
            <div class="d-flex align-items-center flex-wrap gap-3">
                <span class="text-md fw-medium text-secondary-light mb-0">Show</span>
                <select id="rows-show" class="form-select form-select-sm w-auto ps-12 py-6 radius-12 h-40-px">
                    <?php for($i=10;$i<=50;$i+=10): ?>
                        <option value="<?= $i ?>" <?= $i==20?'selected':'' ?>><?= $i ?></option>
                    <?php endfor; ?>
                    <option value="all">All</option>
                </select>
                <div class="navbar-search position-relative">
                    <input type="text" id="shorts-search" class="bg-base h-40-px w-auto ps-40" placeholder="Search title or creator">
                    <iconify-icon icon="mdi:magnify" class="icon position-absolute" style="left: 10px; top: 50%; transform: translateY(-50%);"></iconify-icon>
                </div>
                <select id="status-filter" class="form-select form-select-sm w-auto ps-12 py-6 radius-12 h-40-px">
                    <option value="">Status</option>
                    <option value="Pending">Pending</option>
                    <option value="Approved">Approved</option>
                    <option value="Rejected">Rejected</option>
                    <option value="Hidden">Hidden</option>
                    <option value="Deleted">Deleted</option>
                </select>
            </div>
            <a href="shorts-analytics.php" class="btn btn-sm btn-primary">Analytics</a>
        </div>
        <div class="card-body p-24">
            <div class="table-responsive scroll-sm">
                <table class="table bordered-table sm-table mb-0">
                    <thead>
                        <tr>
                            <th>S.L</th>
                            <th>Thumbnail</th>
                            <th>Creator</th>
                            <th>Title</th>
                            <th>Status</th>
                            <th>Views</th>
                            <th>Likes</th>
                            <th>Comments</th>
                            <th>Shares</th>
                            <th>Reports</th>
                            <th>Created</th>
                            <th class="text-center">Actions</th>
                        </tr>
                    </thead>
                    <tbody id="shorts-table-body"></tbody>
                </table>
            </div>
        </div>
    </div>
</div>

<?php include './partials/layouts/layoutBottom.php'; ?>

<script>
$(document).ready(function(){
    function loadShorts() {
        $.post("shorts-search.php", {
            search: $("#shorts-search").val(),
            status: $("#status-filter").val(),
            limit: $("#rows-show").val()
        }, function(data){
            $("#shorts-table-body").html(data);
        });
    }

    $("#shorts-search").on("keyup", loadShorts);
    $("#status-filter, #rows-show").on("change", loadShorts);
    loadShorts();

    $(document).on("click", ".short-action", function(){
        let id = $(this).data("id");
        let action = $(this).data("action");
        if(confirm("Are you sure you want to " + action + " this short?")){
            $.post("shorts-action.php", {id: id, action: action}, function(res){
                if(res.success) loadShorts();
                else alert(res.message);
            }, "json");
        }
    });
});
</script>
