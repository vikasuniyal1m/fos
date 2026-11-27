<?php
session_start();
include './includes/db.php';
include './includes/admin-auth.php';
include './partials/layouts/layoutTop.php';

$id = intval($_GET['id'] ?? 0);
$prayer = null;

if($id > 0){
    $sql = "SELECT pr.*, u.name AS user_name, u.email, u.phone 
            FROM prayer_requests pr 
            LEFT JOIN users u ON pr.user_id = u.id 
            WHERE pr.id=$id LIMIT 1";
    $result = $conn->query($sql);
    $prayer = $result->num_rows ? $result->fetch_assoc() : null;
}

if(!$prayer){
    echo "<div class='alert alert-danger'>Prayer request not found.</div>";
    include './partials/layouts/layoutBottom.php';
    exit;
}
?>

<div class="dashboard-main-body">
    <h6>Prayer Request Details</h6>

    <table class="table table-bordered">
        <tr>
            <th>ID</th>
            <td><?= $prayer['id'] ?></td>
        </tr>
        <tr>
            <th>User Name</th>
            <td><?= htmlspecialchars($prayer['user_name']) ?></td>
        </tr>
        <tr>
            <th>Email</th>
            <td><?= htmlspecialchars($prayer['email']) ?></td>
        </tr>
        <tr>
            <th>Phone</th>
            <td><?= htmlspecialchars($prayer['phone']) ?></td>
        </tr>
        <tr>
            <th>Category</th>
            <td><?= htmlspecialchars($prayer['category']) ?></td>
        </tr>
        <tr>
            <th>Content</th>
            <td><?= nl2br(htmlspecialchars($prayer['content'])) ?></td>
        </tr>
        <tr>
            <th>Status</th>
            <td><?= $prayer['status'] ?></td>
        </tr>
        <tr>
            <th>Created At</th>
            <td><?= date("d M Y, H:i", strtotime($prayer['created_at'])) ?></td>
        </tr>
        <tr>
            <th>Updated At</th>
            <td><?= date("d M Y, H:i", strtotime($prayer['updated_at'])) ?></td>
        </tr>
    </table>

    <a href="prayer-requests.php" class="btn btn-secondary">Back to List</a>
</div>

<?php include './partials/layouts/layoutBottom.php'; ?>
