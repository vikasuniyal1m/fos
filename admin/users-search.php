<?php
include './includes/db.php';

// Get POST values safely
$search = trim($_POST['search'] ?? '');
$status = trim($_POST['status'] ?? '');
$limit  = $_POST['limit'] ?? '10';

// Base query
$sql = "SELECT * FROM users WHERE 1=1";
$params = [];
$types = "";

// Add search filter
if ($search) {
    $sql .= " AND (name LIKE ? OR email LIKE ? OR phone LIKE ?)";
    $like = "%$search%";
    $params[] = $like;
    $params[] = $like;
    $params[] = $like;
    $types .= "sss";
}

// Add status filter
if ($status) {
    $sql .= " AND status = ?";
    $params[] = $status;
    $types .= "s";
}

// Append order
$sql .= " ORDER BY join_date DESC";

// Add LIMIT only if it's not 'all'
if ($limit !== 'all') {
    $sql .= " LIMIT ?";
    $params[] = intval($limit);
    $types .= "i";
}

// Prepare statement
$stmt = $conn->prepare($sql);

// Bind parameters dynamically if there are any
if (!empty($params)) {
    $stmt->bind_param($types, ...$params);
}

$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows > 0) {
    $sl = 1;
    while ($row = $result->fetch_assoc()) {
        $statusBadge = $row['status'] == 'Active'
            ? '<span class="bg-success-focus text-success-600 border border-success-main px-24 py-4 radius-4 fw-medium text-sm">Active</span>'
            : '<span class="bg-neutral-200 text-neutral-600 border border-neutral-400 px-24 py-4 radius-4 fw-medium text-sm">Inactive</span>';

        $actionBtn = $row['status'] == 'Active'
            ? '<button type="button" class="change-status bg-warning-focus bg-hover-warning-200 text-warning-600 fw-medium w-40-px h-40-px d-flex justify-content-center align-items-center rounded-circle" data-id="'.$row['id'].'" data-action="block" title="Block User"><iconify-icon icon="fluent:block-24-regular" class="icon text-xl"></iconify-icon></button>'
            : '<button type="button" class="change-status bg-success-focus bg-hover-success-200 text-success-600 fw-medium w-40-px h-40-px d-flex justify-content-center align-items-center rounded-circle" data-id="'.$row['id'].'" data-action="approve" title="Approve User"><iconify-icon icon="mdi:check" class="icon text-xl"></iconify-icon></button>';

        echo '<tr>
            <td>'.$sl++.'</td>
            <td>'.date("d M Y", strtotime($row['join_date'])).'</td>
            <td>
                <div class="d-flex align-items-center">
                    <img src="'.($row['profile_photo'] ?: 'assets/images/default-avatar.png').'" alt="" class="w-40-px h-40-px rounded-circle flex-shrink-0 me-12 overflow-hidden">
                    <div class="flex-grow-1">
                        <a href="view-user.php?id='.$row['id'].'" class="text-md mb-0 fw-normal text-secondary-light">'.htmlspecialchars($row['name']).'</a>
                    </div>
                </div>
            </td>
            <td>'.htmlspecialchars($row['email']).'</td>
            <td>'.htmlspecialchars($row['phone']).'</td>
            <td>'.htmlspecialchars($row['role']).'</td>
            <td class="text-center">'.$statusBadge.'</td>
            <td class="text-center">
                <div class="d-flex align-items-center gap-10 justify-content-center">
                    '.$actionBtn.'
                    <button type="button" class="delete-user bg-danger-focus bg-hover-danger-200 text-danger-600 fw-medium w-40-px h-40-px d-flex justify-content-center align-items-center rounded-circle" data-id="'.$row['id'].'" title="Delete User"><iconify-icon icon="fluent:delete-24-regular" class="icon text-xl"></iconify-icon></button>
                </div>
            </td>
        </tr>';
    }
} else {
    echo '<tr><td colspan="8" class="text-center">No users found.</td></tr>';
}
?>
