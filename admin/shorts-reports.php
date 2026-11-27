<?php
include './includes/db.php';
include './includes/admin-auth.php';
include './partials/layouts/layoutTop.php';
?>

<div class="dashboard-main-body">
    <div class="d-flex flex-wrap align-items-center justify-content-between gap-3 mb-24">
        <h6 class="fw-semibold mb-0">Shorts Reports</h6>
        <ul class="d-flex align-items-center gap-2">
            <li class="fw-medium"><a href="shorts-moderation.php">Shorts List</a></li>
            <li>-</li>
            <li class="fw-medium">Reports</li>
        </ul>
    </div>

    <div class="card h-100 p-0 radius-12">
        <div class="card-header border-bottom bg-base py-16 px-24 d-flex align-items-center flex-wrap gap-3">
            <select id="status-filter" class="form-select form-select-sm w-auto">
                <option value="">All Status</option>
                <option value="pending" selected>Pending</option>
                <option value="reviewed">Reviewed</option>
                <option value="dismissed">Dismissed</option>
                <option value="action_taken">Action Taken</option>
            </select>
        </div>
        <div class="card-body p-24">
            <div class="table-responsive scroll-sm">
                <table class="table bordered-table sm-table mb-0">
                    <thead>
                        <tr>
                            <th>ID</th>
                            <th>Short</th>
                            <th>Reporter</th>
                            <th>Reason</th>
                            <th>Description</th>
                            <th>Status</th>
                            <th>Date</th>
                            <th>Actions</th>
                        </tr>
                    </thead>
                    <tbody id="reports-table-body"></tbody>
                </table>
            </div>
        </div>
    </div>
</div>

<?php include './partials/layouts/layoutBottom.php'; ?>

<script>
$(document).ready(function(){
    function loadReports() {
        $.post("shorts-reports-search.php", { status: $("#status-filter").val() }, function(data){
            $("#reports-table-body").html(data);
        });
    }
    $("#status-filter").on("change", loadReports);
    loadReports();

    $(document).on("click", ".report-action", function(){
        let id = $(this).data("id");
        let action = $(this).data("action");
        $.post("shorts-reports-action.php", { id: id, action: action }, function(res){
            if(res.success) loadReports();
            else alert(res.message);
        }, "json");
    });
});
</script>
