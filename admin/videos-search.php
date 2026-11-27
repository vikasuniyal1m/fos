<?php
include './includes/db.php';

$search = $_POST['search'] ?? '';
$status = $_POST['status'] ?? '';
$limit  = $_POST['limit'] ?? '10'; // Changed from intval() to accept string 'all'

$sql = "SELECT lv.*, u.name AS user_name FROM live_videos lv
        LEFT JOIN users u ON lv.user_id=u.id WHERE 1";
$params = [];
$types = "";

if($search){
    $sql .= " AND (lv.title LIKE ? OR u.name LIKE ?)";
    $params[] = "%$search%";
    $params[] = "%$search%";
    $types .= "ss";
}
if($status){
    $sql .= " AND lv.status=?";
    $params[] = $status;
    $types .= "s";
}

$sql .= " ORDER BY lv.created_at DESC";

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
if ($types) {
    $stmt->bind_param($types, ...$params);
}
$stmt->execute();
$result = $stmt->get_result();

$sl = 1;
if($result->num_rows > 0){
    while($row = $result->fetch_assoc()){
        // Status badge - SIMPLE 3 states only
        $statusBadge = '';
        if($row['status'] == 'Live') {
            $statusBadge = '<span class="bg-success-focus px-12 py-4 radius-4 fw-medium text-sm">Live</span>';
        } elseif($row['status'] == 'Blocked') {
            $statusBadge = '<span class="bg-danger-focus px-12 py-4 radius-4 fw-medium text-sm">Blocked</span>';
        } else {
            // Default to Pending
            $statusBadge = '<span class="bg-warning-focus px-12 py-4 radius-4 fw-medium text-sm">Pending</span>';
        }

        echo '<tr>
            <td>'.$sl++.'</td>
            <td>
                <div class="fw-medium">'.htmlspecialchars($row['title']).'</div>
                <small class="text-muted">'.htmlspecialchars(substr($row['description'] ?? '', 0, 50)).'...</small>
            </td>
            <td>'.htmlspecialchars($row['user_name']).'</td>
            <td>
                <span class="bg-primary-focus px-12 py-2 radius-4 fw-medium text-sm">'.htmlspecialchars($row['fruit_tag']).'</span>
            </td>
            <td class="text-center">'.$statusBadge.'</td>
            <td>
                <span class="fw-medium">'.$row['viewer_count'].' viewers</span>
            </td>
            <td>'.date('M j, H:i', strtotime($row['started_at'])).'</td>
            <td class="text-center">
                <div class="d-flex gap-10 justify-content-center">';

        // Watch button - Only for Live videos
        if($row['status'] == 'Live'){
            echo '<a href="watch-live.php?id='.$row['id'].'" target="_blank" class="bg-info-focus bg-hover-info-200 text-info-600 fw-medium w-40-px h-40-px d-flex justify-content-center align-items-center rounded-circle" title="Watch Live">
                      <iconify-icon icon="mdi:play" class="icon text-xl"></iconify-icon>
                  </a>';
        }

        // Status buttons - SIMPLE LOGIC
        if($row['status'] == 'Pending') {
            // Pending: Show both Approve and Block buttons
            echo '<button type="button" class="change-status bg-success-focus bg-hover-success-200 text-success-600 fw-medium w-40-px h-40-px d-flex justify-content-center align-items-center rounded-circle" data-id="'.$row['id'].'" data-action="approve" title="Approve Video">
                      <iconify-icon icon="mdi:check" class="icon text-xl"></iconify-icon>
                  </button>';
            echo '<button type="button" class="change-status bg-warning-focus bg-hover-warning-200 text-warning-600 fw-medium w-40-px h-40-px d-flex justify-content-center align-items-center rounded-circle" data-id="'.$row['id'].'" data-action="block" title="Block Video">
                      <iconify-icon icon="fluent:block-24-regular" class="icon text-xl"></iconify-icon>
                  </button>';
        } elseif($row['status'] == 'Live') {
            // Live: Show only Block button
            echo '<button type="button" class="change-status bg-warning-focus bg-hover-warning-200 text-warning-600 fw-medium w-40-px h-40-px d-flex justify-content-center align-items-center rounded-circle" data-id="'.$row['id'].'" data-action="block" title="Block Video">
                      <iconify-icon icon="fluent:block-24-regular" class="icon text-xl"></iconify-icon>
                  </button>';
        } elseif($row['status'] == 'Blocked') {
            // Blocked: Show only Approve button
            echo '<button type="button" class="change-status bg-success-focus bg-hover-success-200 text-success-600 fw-medium w-40-px h-40-px d-flex justify-content-center align-items-center rounded-circle" data-id="'.$row['id'].'" data-action="approve" title="Approve Video">
                      <iconify-icon icon="mdi:check" class="icon text-xl"></iconify-icon>
                  </button>';
        }

        // Delete button
        echo '<button class="delete-video bg-danger-focus bg-hover-danger-200 text-danger-600 fw-medium w-40-px h-40-px d-flex justify-content-center align-items-center rounded-circle" data-id="'.$row['id'].'" title="Delete Video">
                  <iconify-icon icon="fluent:delete-24-regular" class="icon text-xl"></iconify-icon>
              </button>';

        echo '</div></td></tr>';
    }
} else {
    echo '<tr><td colspan="8" class="text-center">No live videos found.</td></tr>';
}
?>