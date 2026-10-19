<?php
include './includes/db.php';

$search = $_POST['search'] ?? '';
$status = $_POST['status'] ?? '';

$sql = "SELECT g.*, 
               COUNT(gm.user_id) as member_count,
               u.name as created_by_name
        FROM `groups` g 
        LEFT JOIN group_members gm ON g.id = gm.group_id 
        LEFT JOIN users u ON g.created_by = u.id
        WHERE 1";

$params = [];
$types = "";

if($search) {
    $sql .= " AND (g.name LIKE ? OR g.description LIKE ? OR g.category LIKE ? OR u.name LIKE ?)";
    $like = "%$search%";
    $params = [$like, $like, $like, $like];
    $types = "ssss";
}

if($status) {
    $sql .= " AND g.status = ?";
    $params[] = $status;
    $types .= "s";
}

$sql .= " GROUP BY g.id ORDER BY g.created_at DESC";

$stmt = $conn->prepare($sql);
if($params) {
    $stmt->bind_param($types, ...$params);
}
$stmt->execute();
$result = $stmt->get_result();

if($result->num_rows > 0) {
    while($group = $result->fetch_assoc()) {
        echo '<tr>
            <td>'.$group['id'].'</td>
            <td>
                <div class="d-flex align-items-center">
                    '.($group['group_image'] ? '<img src="'.$group['group_image'].'" class="w-40-px h-40-px rounded-circle me-12">' : '').'
                    <div>
                        <div class="fw-medium">'.htmlspecialchars($group['name']).'</div>
                        <small class="text-muted">'.htmlspecialchars($group['description']).'</small>
                    </div>
                </div>
            </td>
            <td>
                <span class="badge bg-primary">'.htmlspecialchars($group['category']).'</span>
            </td>
            <td>
                <span class="fw-medium">'.$group['member_count'].' members</span>
            </td>
            <td>'.htmlspecialchars($group['created_by_name']).'</td>
            <td>
                <span class="badge bg-'.($group['status'] == 'Active' ? 'success' : 'danger').'">
                    '.$group['status'].'
                </span>
            </td>
            <td>'.date('M j, Y', strtotime($group['created_at'])).'</td>
            <td class="text-center">
                <div class="d-flex align-items-center gap-10 justify-content-center">
                    <a href="group-details.php?id='.$group['id'].'" class="bg-info-focus bg-hover-info-200 text-info-600 fw-medium w-40-px h-40-px d-flex justify-content-center align-items-center rounded-circle" title="View Group">
                        <iconify-icon icon="mdi:eye-outline" class="icon text-xl"></iconify-icon>
                    </a>
                    
                    <a href="edit-group.php?id='.$group['id'].'" class="bg-primary-focus bg-hover-primary-200 text-primary-600 fw-medium w-40-px h-40-px d-flex justify-content-center align-items-center rounded-circle" title="Edit Group">
                        <iconify-icon icon="mdi:pencil-outline" class="icon text-xl"></iconify-icon>
                    </a>
                    
                    <button type="button" class="toggle-status bg-'.($group['status'] == 'Active' ? 'warning' : 'success').'-focus bg-hover-'.($group['status'] == 'Active' ? 'warning' : 'success').'-200 text-'.($group['status'] == 'Active' ? 'warning' : 'success').'-600 fw-medium w-40-px h-40-px d-flex justify-content-center align-items-center rounded-circle" 
                            data-id="'.$group['id'].'" title="'.($group['status'] == 'Active' ? 'Deactivate' : 'Activate').'">
                        <iconify-icon icon="'.($group['status'] == 'Active' ? 'fluent:block-24-regular' : 'mdi:check').'" class="icon text-xl"></iconify-icon>
                    </button>
                    
                    <button type="button" class="delete-group bg-danger-focus bg-hover-danger-200 text-danger-600 fw-medium w-40-px h-40-px d-flex justify-content-center align-items-center rounded-circle" 
                            data-id="'.$group['id'].'" title="Delete Group">
                        <iconify-icon icon="fluent:delete-24-regular" class="icon text-xl"></iconify-icon>
                    </button>
                </div>
            </td>
        </tr>';
    }
} else {
    echo '<tr><td colspan="8" class="text-center">No groups found.</td></tr>';
}
?>