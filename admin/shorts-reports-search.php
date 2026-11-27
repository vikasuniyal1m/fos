<?php
include './includes/db.php';

$status = $_POST['status'] ?? '';

$sql = "SELECT r.*, s.title AS short_title, s.thumbnail_url,
        u.name AS reporter_name, su.name AS creator_name
        FROM short_reports r
        JOIN shorts s ON r.short_id = s.id
        JOIN users u ON r.reported_by = u.id
        LEFT JOIN users su ON s.user_id = su.id
        WHERE 1";
$params = [];
$types = "";

if ($status) {
    $sql .= " AND r.status = ?";
    $params[] = $status;
    $types .= "s";
}

$sql .= " ORDER BY r.created_at DESC LIMIT 100";

$stmt = $conn->prepare($sql);
if (!empty($params)) {
    $stmt->bind_param($types, ...$params);
}
$stmt->execute();
$result = $stmt->get_result();

$baseUrl = 'https://admin.fosmessenger.com/';

if ($result->num_rows > 0) {
    while ($row = $result->fetch_assoc()) {
        $thumb = $row['thumbnail_url']
            ? '<img src="'.$baseUrl.$row['thumbnail_url'].'" class="w-40-px h-40-px rounded">'
            : '-';

        echo '<tr>
            <td>'.$row['id'].'</td>
            <td>'.$thumb.' '.htmlspecialchars($row['short_title'] ?: 'Short #'.$row['short_id']).'<br><small>By '.htmlspecialchars($row['creator_name'] ?? '').'</small></td>
            <td>'.htmlspecialchars($row['reporter_name']).'</td>
            <td>'.htmlspecialchars($row['reason']).'</td>
            <td>'.htmlspecialchars(substr($row['description'] ?? '', 0, 80)).'</td>
            <td>'.$row['status'].'</td>
            <td>'.date('M j, Y', strtotime($row['created_at'])).'</td>
            <td>
                <button class="report-action btn btn-sm btn-success" data-id="'.$row['id'].'" data-action="action_taken">Take Action</button>
                <button class="report-action btn btn-sm btn-secondary" data-id="'.$row['id'].'" data-action="dismissed">Dismiss</button>
                <button class="report-action btn btn-sm btn-info" data-id="'.$row['id'].'" data-action="reviewed">Mark Reviewed</button>
            </td>
        </tr>';
    }
} else {
    echo '<tr><td colspan="8" class="text-center py-24">No reports found</td></tr>';
}
