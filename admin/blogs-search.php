<?php
include './includes/db.php';

$search = $_POST['search'] ?? '';
$status = $_POST['status'] ?? '';
$limit  = $_POST['limit'] ?? '10'; // Changed from intval() to accept string 'all'

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
    WHERE 1
";

if ($search) {
    $sql .= " AND (b.title LIKE '%".$conn->real_escape_string($search)."%'
               OR u.name LIKE '%".$conn->real_escape_string($search)."%'
               OR au.name LIKE '%".$conn->real_escape_string($search)."%')";
}

if ($status) {
    $sql .= " AND b.status = '".$conn->real_escape_string($status)."'";
}

$sql .= " ORDER BY b.created_at DESC";

// Only add LIMIT if $limit is not 'all' and is numeric
if ($limit !== 'all' && is_numeric($limit)) {
    $limit_value = intval($limit);
    if ($limit_value > 0) {
        $sql .= " LIMIT $limit_value";
    }
}

$result = $conn->query($sql);

if($result->num_rows > 0) {
    $sl=1;
    while($row = $result->fetch_assoc()) {
        ?>
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
                    <?php if($row['status'] != 'Approved'): ?>
                        <button type="button" 
                                class="change-status bg-success-focus bg-hover-success-200 text-success-600 fw-medium w-40-px h-40-px d-flex justify-content-center align-items-center rounded-circle"
                                data-id="<?= $row['id'] ?>" data-action="approve" title="Approve Blog">
                            <iconify-icon icon="mdi:check" class="icon text-xl"></iconify-icon>
                        </button>
                    <?php endif; ?>

                    <?php if($row['status'] != 'Rejected'): ?>
                        <button type="button" 
                                class="change-status bg-warning-focus bg-hover-warning-200 text-warning-600 fw-medium w-40-px h-40-px d-flex justify-content-center align-items-center rounded-circle"
                                data-id="<?= $row['id'] ?>" data-action="reject" title="Reject Blog">
                            <iconify-icon icon="mdi:close" class="icon text-xl"></iconify-icon>
                        </button>
                    <?php endif; ?>

                    <!-- View Blog -->
                    <a href="blog-view.php?id=<?= $row['id'] ?>" 
                       class="bg-info-focus bg-hover-info-200 text-info-600 fw-medium w-40-px h-40-px d-flex justify-content-center align-items-center rounded-circle"
                       title="View Blog">
                        <iconify-icon icon="mdi:eye-outline" class="icon text-xl"></iconify-icon>
                    </a>

                    <!-- Edit Blog -->
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
        <?php
    }
} else {
    echo '<tr><td colspan="6" class="text-center">No blogs found.</td></tr>';
}