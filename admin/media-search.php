<?php
include './includes/db.php';

$search = $_POST['search'] ?? '';
$type   = $_POST['type'] ?? '';
$status = $_POST['status'] ?? '';
$limit  = $_POST['limit'] ?? '10'; // Changed from intval() to accept string 'all'

$sql = "SELECT m.*, u.name AS user_name FROM media_items m
        LEFT JOIN users u ON m.user_id=u.id WHERE 1";
$params = [];
$types = "";

if($search){
    $sql .= " AND u.name LIKE ?";
    $params[] = "%$search%";
    $types .= "s";
}
if($type){
    $sql .= " AND m.type=?";
    $params[] = $type;
    $types .= "s";
}
if($status){
    $sql .= " AND m.status=?";
    $params[] = $status;
    $types .= "s";
}

$sql .= " ORDER BY m.created_at DESC";

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
if($result->num_rows > 0){
    while($row = $result->fetch_assoc()){
        $preview = $row['type']=='photo'
            ? '<img src="'.$row['file_path'].'" class="w-50-px h-50-px rounded">'
            : '<video src="'.$row['file_path'].'" class="w-50-px h-50-px" controls></video>';

        echo '<tr>
            <td>'.$sl++.'</td>
            <td>'.htmlspecialchars($row['user_name']).'</td>
            <td>'.$preview.'</td>
            <td>'.ucfirst($row['type']).'</td>
            <td>'.htmlspecialchars($row['fruit_tag']).'</td>
            <td class="text-center">
                <span class="'.($row['status']=='Approved'?'bg-success-focus':'bg-warning-focus').' px-12 py-4 radius-4 fw-medium text-sm">'.$row['status'].'</span>
            </td>
            <td class="text-center">
                <div class="d-flex gap-10 justify-content-center">';

        // Status buttons
        if($row['status'] == 'Pending'){
            echo '<button type="button" class="change-status bg-success-focus bg-hover-success-200 text-success-600 fw-medium w-40-px h-40-px d-flex justify-content-center align-items-center rounded-circle" data-id="'.$row['id'].'" data-action="approve" title="Approve Media">
                      <iconify-icon icon="mdi:check" class="icon text-xl"></iconify-icon>
                  </button>
                  <button type="button" class="change-status bg-warning-focus bg-hover-warning-200 text-warning-600 fw-medium w-40-px h-40-px d-flex justify-content-center align-items-center rounded-circle" data-id="'.$row['id'].'" data-action="reject" title="Reject Media">
                      <iconify-icon icon="fluent:block-24-regular" class="icon text-xl"></iconify-icon>
                  </button>';
        } elseif($row['status'] == 'Approved'){
            echo '<button type="button" class="change-status bg-warning-focus bg-hover-warning-200 text-warning-600 fw-medium w-40-px h-40-px d-flex justify-content-center align-items-center rounded-circle" data-id="'.$row['id'].'" data-action="reject" title="Reject Media">
                      <iconify-icon icon="fluent:block-24-regular" class="icon text-xl"></iconify-icon>
                  </button>';
        } elseif($row['status'] == 'Rejected'){
            echo '<button type="button" class="change-status bg-success-focus bg-hover-success-200 text-success-600 fw-medium w-40-px h-40-px d-flex justify-content-center align-items-center rounded-circle" data-id="'.$row['id'].'" data-action="approve" title="Approve Media">
                      <iconify-icon icon="mdi:check" class="icon text-xl"></iconify-icon>
                  </button>';
        }

        // View & Delete buttons
        echo '<button class="view-media bg-info-focus bg-hover-info-200 text-info-600 fw-medium w-40-px h-40-px d-flex justify-content-center align-items-center rounded-circle" data-id="'.$row['id'].'" title="View Media">
                  <iconify-icon icon="mdi:eye" class="icon text-xl"></iconify-icon>
              </button>
              <button class="delete-media bg-danger-focus bg-hover-danger-200 text-danger-600 fw-medium w-40-px h-40-px d-flex justify-content-center align-items-center rounded-circle" data-id="'.$row['id'].'" title="Delete Media">
                  <iconify-icon icon="fluent:delete-24-regular" class="icon text-xl"></iconify-icon>
              </button>';

        echo '</div></td></tr>';
    }
} else {
    echo '<tr><td colspan="7" class="text-center">No media found.</td></tr>';
}
?>