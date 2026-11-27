<?php
/**
 * One-time migration for user delete feature.
 * Run once in browser: https://admin.fosmessenger.com/api/migrate_delete_feature.php
 * Or execute the SQL below manually in phpMyAdmin.
 */

require_once '../includes/db.php';
require_once '../includes/cors.php';

header('Content-Type: application/json; charset=utf-8');

$results = [];

function columnExists($conn, $table, $column) {
    $table = $conn->real_escape_string($table);
    $column = $conn->real_escape_string($column);
    $res = $conn->query("SHOW COLUMNS FROM `$table` LIKE '$column'");
    return $res && $res->num_rows > 0;
}

function addDeletedToStatusEnum($conn, $table) {
    if (!columnExists($conn, $table, 'status')) {
        return "SKIP $table.status — column not found";
    }

    $res = $conn->query("SHOW COLUMNS FROM `$table` LIKE 'status'");
    $row = $res->fetch_assoc();
    $type = $row['Type'] ?? '';

    if (stripos($type, 'enum') === false) {
        return "OK $table.status — not ENUM ($type), no change needed";
    }

    preg_match_all("/'([^']+)'/", $type, $matches);
    $values = $matches[1] ?? [];
    if (in_array('Deleted', $values, true)) {
        return "OK $table.status — 'Deleted' already exists";
    }

    $values[] = 'Deleted';
    $enum = "'" . implode("','", $values) . "'";
    $default = $row['Default'] ?? ($values[0] ?? 'Pending');
    $sql = "ALTER TABLE `$table` MODIFY COLUMN status ENUM($enum) DEFAULT '$default'";

    if ($conn->query($sql)) {
        return "FIXED $table.status — added 'Deleted' to ENUM";
    }
    return "ERROR $table.status — " . $conn->error;
}

try {
    // 1. comments.is_deleted (soft delete for prayer/video/story/group comments)
    if (!columnExists($conn, 'comments', 'is_deleted')) {
        $sql = "ALTER TABLE comments ADD COLUMN is_deleted TINYINT(1) NOT NULL DEFAULT 0";
        if ($conn->query($sql)) {
            $results[] = "FIXED comments — added is_deleted column";
            @$conn->query("ALTER TABLE comments ADD INDEX idx_is_deleted (is_deleted)");
        } else {
            $results[] = "ERROR comments.is_deleted — " . $conn->error;
        }
    } else {
        $results[] = "OK comments.is_deleted — already exists";
    }

    // 2. Add 'Deleted' to status ENUM on content tables
    foreach (['prayer_requests', 'blogs', 'stories', 'media_items'] as $table) {
        $check = @$conn->query("SHOW TABLES LIKE '$table'");
        if ($check && $check->num_rows > 0) {
            $results[] = addDeletedToStatusEnum($conn, $table);
        } else {
            $results[] = "SKIP $table — table not found";
        }
    }

    // 3. group_posts — uses Active / Deleted
    if (columnExists($conn, 'group_posts', 'status')) {
        $results[] = addDeletedToStatusEnum($conn, 'group_posts');
    } else {
        $results[] = "OK group_posts — table exists (verify status column manually)";
    }

    // 4. group_chat_messages.status for message delete
    if (columnExists($conn, 'group_chat_messages', 'status')) {
        $results[] = "OK group_chat_messages.status — exists (uses VARCHAR 'deleted')";
    } else {
        $results[] = "WARN group_chat_messages.status — missing; chat delete may fail";
    }

    echo json_encode([
        'success' => true,
        'message' => 'Delete feature migration completed. Review results below.',
        'results' => $results,
    ], JSON_PRETTY_PRINT);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage(),
        'results' => $results,
    ], JSON_PRETTY_PRINT);
}
