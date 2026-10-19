<?php
include './includes/db.php';

$search = $_POST['search'] ?? '';
$status = $_POST['status'] ?? '';
$limit  = $_POST['limit'] ?? '20';

$sql = "SELECT s.*, u.name AS user_name,
        (SELECT COUNT(*) FROM short_reports r WHERE r.short_id = s.id AND r.status = 'pending') AS report_count
        FROM shorts s
        LEFT JOIN users u ON s.user_id = u.id
        WHERE 1";
$params = [];
$types = "";

if ($search) {
    $sql .= " AND (s.title LIKE ? OR u.name LIKE ?)";
    $like = "%$search%";
    $params[] = $like;
    $params[] = $like;
    $types .= "ss";
}
if ($status) {
    $sql .= " AND s.status = ?";
    $params[] = $status;
    $types .= "s";
}

$sql .= " ORDER BY s.created_at DESC";

if ($limit !== 'all' && is_numeric($limit)) {
    $sql .= " LIMIT ?";
    $params[] = intval($limit);
    $types .= "i";
}

$stmt = $conn->prepare($sql);
if (!empty($params)) {
    $stmt->bind_param($types, ...$params);
}
$stmt->execute();
$result = $stmt->get_result();

$baseUrl = 'https://admin.fosmessenger.com/';
$sl = 1;

if ($result->num_rows > 0) {
    while ($row = $result->fetch_assoc()) {
        $thumb = $row['thumbnail_url']
            ? '<img src="'.$baseUrl.$row['thumbnail_url'].'" class="w-50-px h-50-px rounded object-fit-cover">'
            : '<span class="text-secondary-light">No thumb</span>';

        $statusClass = 'bg-warning-focus';
        if ($row['status'] === 'Approved') $statusClass = 'bg-success-focus';
        if (in_array($row['status'], ['Rejected', 'Deleted'])) $statusClass = 'bg-danger-focus';

        echo '<tr>
            <td>'.$sl++.'</td>
            <td>'.$thumb.'</td>
            <td>'.htmlspecialchars($row['user_name'] ?? 'Unknown').'</td>
            <td>'.htmlspecialchars($row['title'] ?: '(No title)').'</td>
            <td><span class="'.$statusClass.' px-12 py-4 radius-4 fw-medium text-sm">'.$row['status'].'</span></td>
            <td>'.intval($row['total_views']).'</td>
            <td>'.intval($row['total_likes']).'</td>
            <td>'.intval($row['total_comments']).'</td>
            <td>'.intval($row['total_shares']).'</td>
            <td>'.intval($row['report_count']).'</td>
            <td>'.date('M j, Y', strtotime($row['created_at'])).'</td>
            <td class="text-center">
                <div class="d-flex gap-8 justify-content-center flex-wrap">';

        if ($row['status'] === 'Pending') {
            echo '<button class="short-action btn btn-sm btn-success" data-id="'.$row['id'].'" data-action="approve">Approve</button>
                  <button class="short-action btn btn-sm btn-warning" data-id="'.$row['id'].'" data-action="reject">Reject</button>';
        }
        if ($row['status'] === 'Approved') {
            echo '<button class="short-action btn btn-sm btn-secondary" data-id="'.$row['id'].'" data-action="hide">Hide</button>';
        }
        if (in_array($row['status'], ['Hidden', 'Rejected'])) {
            echo '<button class="short-action btn btn-sm btn-info" data-id="'.$row['id'].'" data-action="restore">Restore</button>';
        }
        if ($row['status'] !== 'Deleted') {
            echo '<button class="short-action btn btn-sm btn-danger" data-id="'.$row['id'].'" data-action="delete">Delete</button>';
        }

        echo '</div></td></tr>';
    }
} else {
    echo '<tr><td colspan="12" class="text-center py-24">No shorts found</td></tr>';
}
