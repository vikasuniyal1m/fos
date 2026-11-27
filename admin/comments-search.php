<?php
include './includes/db.php';

$search    = $_POST['search'] ?? '';
$status    = $_POST['status'] ?? '';
$limit     = $_POST['limit'] ?? '10'; // Changed from intval() to accept string 'all'
$post_type = $_POST['post_type'] ?? '';

$sql = "SELECT c.*, u.name AS user_name 
        FROM comments c 
        LEFT JOIN users u ON c.user_id = u.id 
        WHERE 1";

$params = [];
$types = "";

if($search) {
    $sql .= " AND (c.content LIKE ? OR u.name LIKE ?)";
    $like = "%$search%";
    $params[] = $like;
    $params[] = $like;
    $types .= "ss";
}

if($status) {
    $sql .= " AND c.status = ?";
    $params[] = $status;
    $types .= "s";
}

if($post_type) {
    $sql .= " AND c.post_type = ?";
    $params[] = $post_type;
    $types .= "s";
}

$sql .= " ORDER BY c.created_at DESC";

// Only add LIMIT if $limit is not 'all' and is numeric
if ($limit !== 'all' && is_numeric($limit)) {
    $limit_value = intval($limit);
    if ($limit_value > 0) {
        $sql .= " LIMIT ?";
        $params[] = $limit_value;
        $types .= "i";
    }
}

$stmt = $conn->prepare($sql);
if(!empty($params)){
    $stmt->bind_param($types, ...$params);
}
$stmt->execute();
$result = $stmt->get_result();

$sl = 1;
if($result->num_rows > 0) {
    while($row = $result->fetch_assoc()) {
        echo '<tr>
            <td>'.$sl++.'</td>
            <td>'.date("d M Y H:i", strtotime($row['created_at'])).'</td>
            <td>'.htmlspecialchars($row['user_name'] ?? "Guest").'</td>
            <td>'.ucfirst($row['post_type']).'</td>
            <td>'.htmlspecialchars($row['content']).'</td>
            <td class="text-center">'.
                ($row['status']=='approved'
                    ? '<span class="bg-success-focus text-success-600 border border-success-main px-24 py-4 radius-4 fw-medium text-sm">Approved</span>'
                    : ($row['status']=='rejected'
                        ? '<span class="bg-danger-focus text-danger-600 border border-danger-main px-24 py-4 radius-4 fw-medium text-sm">Rejected</span>'
                        : '<span class="bg-neutral-200 text-neutral-600 border border-neutral-400 px-24 py-4 radius-4 fw-medium text-sm">Pending</span>')
                ).'</td>
            <td class="text-center">
                <div class="d-flex align-items-center gap-10 justify-content-center">'.
                    ($row['status']!='approved'
                        ? '<button type="button" class="change-status bg-success-focus bg-hover-success-200 text-success-600 fw-medium w-40-px h-40-px d-flex justify-content-center align-items-center rounded-circle" data-id="'.$row['id'].'" data-action="approve" title="Approve Comment"><iconify-icon icon="mdi:check" class="icon text-xl"></iconify-icon></button>'
                        : '').
                    ($row['status']!='rejected'
                        ? '<button type="button" class="change-status bg-warning-focus bg-hover-warning-200 text-warning-600 fw-medium w-40-px h-40-px d-flex justify-content-center align-items-center rounded-circle" data-id="'.$row['id'].'" data-action="reject" title="Reject Comment"><iconify-icon icon="fluent:block-24-regular" class="icon text-xl"></iconify-icon></button>'
                        : '').
                    '<button type="button" class="delete-comment bg-danger-focus bg-hover-danger-200 text-danger-600 fw-medium w-40-px h-40-px d-flex justify-content-center align-items-center rounded-circle" data-id="'.$row['id'].'" title="Delete Comment"><iconify-icon icon="fluent:delete-24-regular" class="icon text-xl"></iconify-icon></button>
                </div>
            </td>
        </tr>';
    }
} else {
    echo '<tr><td colspan="7" class="text-center">No comments found.</td></tr>';
}
?>