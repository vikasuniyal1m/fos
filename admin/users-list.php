<?php 
include './includes/db.php';
include './includes/admin-auth.php';
include './partials/layouts/layoutTop.php'; 
?>

<div class="dashboard-main-body">
    <div class="d-flex flex-wrap align-items-center justify-content-between gap-3 mb-24">
        <h6 class="fw-semibold mb-0">Users Grid</h6>
        <ul class="d-flex align-items-center gap-2">
            <li class="fw-medium">
                <a href="index.php" class="d-flex align-items-center gap-1 hover-text-primary">
                    <iconify-icon icon="solar:home-smile-angle-outline" class="icon text-lg"></iconify-icon>
                    Dashboard
                </a>
            </li>
            <li>-</li>
            <li class="fw-medium">Users Grid</li>
        </ul>
    </div>

    <div class="card h-100 p-0 radius-12">
        <div class="card-header border-bottom bg-base py-16 px-24 d-flex align-items-center flex-wrap gap-3 justify-content-between">
            <div class="d-flex align-items-center flex-wrap gap-3">
                <span class="text-md fw-medium text-secondary-light mb-0">Show</span>
               <select id="rows-show" class="form-select form-select-sm w-auto ps-12 py-6 radius-12 h-40-px">
    <option value="10">10</option>
    <option value="25">25</option>
    <option value="50">50</option>
    <option value="100">100</option>
    <option value="all">All</option>
</select>

                <div class="navbar-search position-relative">
                    <input type="text" id="user-search" class="bg-base h-40-px w-auto ps-40" placeholder="Search">
                    <iconify-icon icon="mdi:magnify" class="icon position-absolute" style="left: 10px; top: 50%; transform: translateY(-50%);"></iconify-icon>
                </div>

                <select id="status-filter" class="form-select form-select-sm w-auto ps-12 py-6 radius-12 h-40-px">
                    <option value="">Status</option>
                    <option value="Active">Active</option>
                    <option value="Inactive">Inactive</option>
                </select>
            </div>
            <a href="add-user.php" class="btn btn-primary text-sm btn-sm px-12 py-12 radius-8 d-flex align-items-center gap-2">
                <iconify-icon icon="ic:baseline-plus" class="icon text-xl line-height-1"></iconify-icon>
                Add New User
            </a>
        </div>

        <div class="card-body p-24">
            <div class="table-responsive scroll-sm">
                <table class="table bordered-table sm-table mb-0">
                    <thead>
                        <tr>
                            <th>S.L</th>
                            <th>Join Date</th>
                            <th>Name</th>
                            <th>Email</th>
                            <th>Phone</th>
                            <th>Role</th>
                            <th class="text-center">Status</th>
                            <th class="text-center">Actions</th>
                        </tr>
                    </thead>
                    <tbody id="users-table-body">
                        <!-- AJAX loaded rows -->
                    </tbody>
                </table>
            </div>
        </div>
    </div>
</div>

<style>
.object-fit-cover {
    object-fit: cover;
}
</style>

<?php include './partials/layouts/layoutBottom.php'; ?>

<script>
$(document).ready(function(){
    function loadUsers() {
        let query = $("#user-search").val();
        let status = $("#status-filter").val();
        let limit = $("#rows-show").val();

        $.post("users-search.php", {search: query, status: status, limit: limit}, function(data){
            $("#users-table-body").html(data);
        });
    }

    $("#user-search").on("keyup", loadUsers);
    $("#status-filter, #rows-show").on("change", loadUsers);

    $(document).on("click", ".change-status", function(){
        let id = $(this).data("id");
        let action = $(this).data("action");
        if(confirm(`Are you sure you want to ${action} this user?`)){
            $.post("users-action.php", {id: id, action: action}, function(res){
                if(res.success) loadUsers();
                else alert(res.message);
            }, "json");
        }
    });

    $(document).on("click", ".delete-user", function(){
        let id = $(this).data("id");
        if(confirm("Are you sure you want to delete this user?")){
            $.post("users-action.php", {id: id, action: "delete"}, function(res){
                if(res.success) loadUsers();
                else alert(res.message);
            }, "json");
        }
    });

    $(document).on("click", ".view-user", function(){
        let id = $(this).data("id");
        window.open("view-user.php?id=" + id, "_blank");
    });

    loadUsers();
});
</script>