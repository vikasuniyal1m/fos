<?php
include './includes/db.php';
include './includes/admin-auth.php';
include './partials/layouts/layoutTop.php';
?>

<div class="dashboard-main-body">
    <div class="d-flex flex-wrap align-items-center justify-content-between gap-3 mb-24">
        <h6 class="fw-semibold mb-0">Media Moderation</h6>
        <ul class="d-flex align-items-center gap-2">
            <li class="fw-medium">
                <a href="index.php" class="d-flex align-items-center gap-1 hover-text-primary">
                    <iconify-icon icon="mdi:home-outline" class="icon text-lg"></iconify-icon>
                    Dashboard
                </a>
            </li>
            <li>-</li>
            <li class="fw-medium">Media Moderation</li>
        </ul>
    </div>

    <div class="card h-100 p-0 radius-12">
        <div class="card-header border-bottom bg-base py-16 px-24 d-flex align-items-center flex-wrap gap-3 justify-content-between">
            <div class="d-flex align-items-center flex-wrap gap-3">
                <span class="text-md fw-medium text-secondary-light mb-0">Show</span>
         <select id="rows-show" class="form-select form-select-sm w-auto ps-12 py-6 radius-12 h-40-px">
    <?php for($i=1;$i<=10;$i++): ?>
        <option value="<?= $i ?>" <?= $i==10?'selected':'' ?>><?= $i ?></option>
    <?php endfor; ?>
    <option value="all">All</option> 
</select>

                <div class="navbar-search position-relative">
                    <input type="text" id="media-search" class="bg-base h-40-px w-auto ps-40" placeholder="Search">
                    <iconify-icon icon="mdi:magnify" class="icon position-absolute" style="left: 10px; top: 50%; transform: translateY(-50%);"></iconify-icon>
                </div>

                <select id="type-filter" class="form-select form-select-sm w-auto ps-12 py-6 radius-12 h-40-px">
                    <option value="">Type</option>
                    <option value="photo">Photo</option>
                    <option value="video">Video</option>
                </select>

                <select id="status-filter" class="form-select form-select-sm w-auto ps-12 py-6 radius-12 h-40-px">
                    <option value="">Status</option>
                    <option value="Pending">Pending</option>
                    <option value="Approved">Approved</option>
                    <option value="Rejected">Rejected</option>
                </select>
            </div>
        </div>

        <div class="card-body p-24">
            <div class="table-responsive scroll-sm">
                <table class="table bordered-table sm-table mb-0">
                    <thead>
                        <tr>
                            <th>S.L</th>
                            <th>User</th>
                            <th>Preview</th>
                            <th>Type</th>
                            <th>Fruit Tag</th>
                            <th class="text-center">Status</th>
                            <th class="text-center">Actions</th>
                        </tr>
                    </thead>
                    <tbody id="media-table-body">
                        <!-- AJAX loaded rows -->
                    </tbody>
                </table>
            </div>
        </div>
    </div>
</div>

<?php include './partials/layouts/layoutBottom.php'; ?>

<script>
$(document).ready(function(){
    function loadMedia() {
        let query = $("#media-search").val();
        let type  = $("#type-filter").val();
        let status= $("#status-filter").val();
        let limit = $("#rows-show").val();

        $.post("media-search.php", {search: query, type: type, status: status, limit: limit}, function(data){
            $("#media-table-body").html(data);
        });
    }

    $("#media-search").on("keyup", loadMedia);
    $("#type-filter, #status-filter, #rows-show").on("change", loadMedia);

    $(document).on("click", ".change-status", function(){
        let id = $(this).data("id");
        let action = $(this).data("action");
        if(confirm(`Are you sure you want to ${action} this media?`)){
            $.post("media-action.php", {id: id, action: action}, function(res){
                if(res.success) loadMedia();
                else alert(res.message);
            }, "json");
        }
    });

    $(document).on("click", ".delete-media", function(){
        let id = $(this).data("id");
        if(confirm("Are you sure you want to delete this media?")){
            $.post("media-action.php", {id: id, action: "delete"}, function(res){
                if(res.success) loadMedia();
                else alert(res.message);
            }, "json");
        }
    });

    $(document).on("click", ".view-media", function(){
        let id = $(this).data("id");
        window.open("view-media.php?id=" + id, "_blank");
    });

    loadMedia();
});
</script>
