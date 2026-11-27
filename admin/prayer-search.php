<?php
include './includes/db.php';

$search = $_POST['search'] ?? '';
$status = $_POST['status'] ?? '';
$limit  = $_POST['limit'] ?? '10'; // Changed from intval() to accept string 'all'

$sql = "SELECT pr.*, u.name AS user_name FROM prayer_requests pr 
        LEFT JOIN users u ON pr.user_id=u.id WHERE 1";

$params = [];
$types = "";

if($search) {
    $sql .= " AND (pr.content LIKE ? OR pr.category LIKE ? OR u.name LIKE ?)";
    $like = "%$search%";
    $params = [$like, $like, $like];
    $types = "sss";
}

if($status) {
    $sql .= " AND pr.status=?";
    $params[] = $status;
    $types .= "s";
}

$sql .= " ORDER BY pr.created_at DESC";

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

if($params) {
    $stmt->bind_param($types, ...$params);
}

$stmt->execute();
$result = $stmt->get_result();

$sl = 1;
while($row = $result->fetch_assoc()) {
    echo '<tr>
        <td>'.$sl++.'</td>
        <td>'.date("d M Y", strtotime($row['created_at'])).'</td>
        <td>'.htmlspecialchars($row['user_name']).'</td>
        <td>'.htmlspecialchars($row['category']).'</td>
        <td>'.nl2br(htmlspecialchars(substr($row['content'],0,50))).'...</td>
        <td class="text-center">'
            .($row['status']=="Approved" ? '<span class="bg-success-focus text-success-600 border border-success-main px-24 py-4 radius-4 fw-medium text-sm">Approved</span>'
            : ($row['status']=="Rejected" ? '<span class="bg-danger-focus text-danger-600 border border-danger-main px-24 py-4 radius-4 fw-medium text-sm">Rejected</span>'
            : '<span class="bg-warning-focus text-warning-600 border border-warning-main px-24 py-4 radius-4 fw-medium text-sm">Pending</span>'))
        .'</td>
        <td class="text-center">
            <div class="d-flex gap-10 justify-content-center">';
                
                // View button
                echo '<button class="view-request bg-info-focus bg-hover-info-200 text-info-600 fw-medium w-40-px h-40-px d-flex justify-content-center align-items-center rounded-circle" data-id="'.$row['id'].'" title="View Request">
                        <iconify-icon icon="mdi:eye" class="icon text-xl"></iconify-icon>
                      </button>';

                // Approve / Reject toggle
                if($row['status']=="Pending") {
                    echo '<button class="change-status bg-success-focus bg-hover-success-200 text-success-600 fw-medium w-40-px h-40-px d-flex justify-content-center align-items-center rounded-circle" data-id="'.$row['id'].'" data-action="approve" title="Approve">
                            <iconify-icon icon="mdi:check" class="icon text-xl"></iconify-icon>
                          </button>';
                    echo '<button class="change-status bg-warning-focus bg-hover-warning-200 text-warning-600 fw-medium w-40-px h-40-px d-flex justify-content-center align-items-center rounded-circle" data-id="'.$row['id'].'" data-action="reject" title="Reject">
                            <iconify-icon icon="fluent:block-24-regular" class="icon text-xl"></iconify-icon>
                          </button>';
                } elseif($row['status']=="Approved") {
                    echo '<button class="change-status bg-warning-focus bg-hover-warning-200 text-warning-600 fw-medium w-40-px h-40-px d-flex justify-content-center align-items-center rounded-circle" data-id="'.$row['id'].'" data-action="reject" title="Reject">
                            <iconify-icon icon="fluent:block-24-regular" class="icon text-xl"></iconify-icon>
                          </button>';
                } else { // Rejected
                    echo '<button class="change-status bg-success-focus bg-hover-success-200 text-success-600 fw-medium w-40-px h-40-px d-flex justify-content-center align-items-center rounded-circle" data-id="'.$row['id'].'" data-action="approve" title="Approve">
                            <iconify-icon icon="mdi:check" class="icon text-xl"></iconify-icon>
                          </button>';
                }

                // Delete button
                echo '<button class="delete-request bg-danger-focus bg-hover-danger-200 text-danger-600 fw-medium w-40-px h-40-px d-flex justify-content-center align-items-center rounded-circle" data-id="'.$row['id'].'" title="Delete">
                        <iconify-icon icon="fluent:delete-24-regular" class="icon text-xl"></iconify-icon>
                      </button>';

    echo '</div>
        </td>
    </tr>';
}
if($result->num_rows==0){
    echo '<tr><td colspan="7" class="text-center">No prayer requests found.</td></tr>';
}
?>