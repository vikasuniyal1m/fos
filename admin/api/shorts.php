<?php
/**
 * Shorts API — standalone module
 * Handles: list, upload, like, save, comment, share, report, view, delete
 */

error_reporting(E_ALL);
ini_set('display_errors', 0);
ob_start();

require_once '../includes/db.php';
require_once '../includes/cors.php';
require_once '../includes/file_upload_helper.php';
require_once '../includes/config.php';
require_once '../includes/ContentModerationService.php';
require_once 'auth-helper.php';

ob_clean();
header('Content-Type: application/json; charset=utf-8');

$method = $_SERVER['REQUEST_METHOD'];
$action = $_GET['action'] ?? $_POST['action'] ?? '';

if ($method === 'OPTIONS') {
    http_response_code(200);
    exit;
}

ensureShortsTables($conn);

switch ($action) {
    case 'like':
        handleToggleLike($conn);
        break;
    case 'save':
        handleToggleSave($conn);
        break;
    case 'share':
        handleShare($conn);
        break;
    case 'report':
        handleReport($conn);
        break;
    case 'view':
        handleView($conn);
        break;
    case 'delete':
        handleDelete($conn);
        break;
    case 'comments':
        if ($method === 'GET') {
            handleGetComments($conn);
        } else {
            handleAddComment($conn);
        }
        break;
    case 'comment-reaction':
        handleCommentReaction($conn);
        break;
    case 'delete-comment':
        handleDeleteComment($conn);
        break;
    case 'edit-comment':
        handleEditComment($conn);
        break;
    case 'report-comment':
        handleReportComment($conn);
        break;
    case 'saved':
        handleGetSaved($conn);
        break;
    case 'counts':
        handleGetCounts($conn);
        break;
    case 'analytics':
        handleAnalytics($conn);
        break;
    case 'upload':
        handleUpload($conn);
        break;
    default:
        if ($method === 'GET') {
            handleGetShorts($conn);
        } elseif ($method === 'POST') {
            $postAction = $_POST['action'] ?? 'upload';
            switch ($postAction) {
                case 'like': handleToggleLike($conn); break;
                case 'save': handleToggleSave($conn); break;
                case 'share': handleShare($conn); break;
                case 'report': handleReport($conn); break;
                case 'view': handleView($conn); break;
                case 'delete': handleDelete($conn); break;
                case 'comments': handleAddComment($conn); break;
                case 'comment-reaction': handleCommentReaction($conn); break;
                case 'delete-comment': handleDeleteComment($conn); break;
                case 'edit-comment': handleEditComment($conn); break;
                case 'report-comment': handleReportComment($conn); break;
                default: handleUpload($conn); break;
            }
        } else {
            http_response_code(405);
            echo jsonResponse(false, 'Method not allowed');
        }
        break;
}

function ensureShortsTables($conn) {
    static $checked = false;
    if ($checked) return;
    $checked = true;

    $createShorts = "CREATE TABLE IF NOT EXISTS shorts (
        id INT AUTO_INCREMENT PRIMARY KEY,
        uuid VARCHAR(36) NOT NULL UNIQUE,
        user_id INT NOT NULL,
        title VARCHAR(255) DEFAULT NULL,
        description TEXT DEFAULT NULL,
        video_url VARCHAR(500) NOT NULL,
        thumbnail_url VARCHAR(500) DEFAULT NULL,
        duration INT DEFAULT 0,
        visibility ENUM('public','private','followers') DEFAULT 'public',
        status ENUM('Pending','Approved','Rejected','Hidden','Deleted') DEFAULT 'Pending',
        total_views INT DEFAULT 0,
        total_likes INT DEFAULT 0,
        total_comments INT DEFAULT 0,
        total_shares INT DEFAULT 0,
        total_saves INT DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        deleted_at TIMESTAMP NULL DEFAULT NULL,
        INDEX idx_user_id (user_id),
        INDEX idx_status (status),
        INDEX idx_created_at (created_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4";

    $tables = [
        'shorts' => $createShorts,
        'short_likes' => "CREATE TABLE IF NOT EXISTS short_likes (
            id INT AUTO_INCREMENT PRIMARY KEY,
            short_id INT NOT NULL,
            user_id INT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UNIQUE KEY uniq_short_user (short_id, user_id),
            INDEX idx_short_id (short_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4",
        'short_comments' => "CREATE TABLE IF NOT EXISTS short_comments (
            id INT AUTO_INCREMENT PRIMARY KEY,
            short_id INT NOT NULL,
            user_id INT NOT NULL,
            comment TEXT NOT NULL,
            parent_comment_id INT NULL DEFAULT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            deleted_at TIMESTAMP NULL DEFAULT NULL,
            INDEX idx_short_id (short_id),
            INDEX idx_parent_comment_id (parent_comment_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4",
        'short_comment_reactions' => "CREATE TABLE IF NOT EXISTS short_comment_reactions (
            id INT AUTO_INCREMENT PRIMARY KEY,
            comment_id INT NOT NULL,
            user_id INT NOT NULL,
            emoji VARCHAR(50) NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_comment_id (comment_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4",
        'short_comment_reports' => "CREATE TABLE IF NOT EXISTS short_comment_reports (
            id INT AUTO_INCREMENT PRIMARY KEY,
            comment_id INT NOT NULL,
            reported_by INT NOT NULL,
            reason VARCHAR(100) NOT NULL,
            description TEXT DEFAULT NULL,
            status ENUM('pending','reviewed','dismissed','action_taken') DEFAULT 'pending',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UNIQUE KEY uniq_comment_reporter (comment_id, reported_by),
            INDEX idx_comment_id (comment_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4",
        'short_reports' => "CREATE TABLE IF NOT EXISTS short_reports (
            id INT AUTO_INCREMENT PRIMARY KEY,
            short_id INT NOT NULL,
            reported_by INT NOT NULL,
            reason VARCHAR(100) NOT NULL,
            description TEXT DEFAULT NULL,
            status ENUM('pending','reviewed','dismissed','action_taken') DEFAULT 'pending',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_short_id (short_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4",
        'short_views' => "CREATE TABLE IF NOT EXISTS short_views (
            id INT AUTO_INCREMENT PRIMARY KEY,
            short_id INT NOT NULL,
            user_id INT NOT NULL,
            viewed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_short_id (short_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4",
        'short_shares' => "CREATE TABLE IF NOT EXISTS short_shares (
            id INT AUTO_INCREMENT PRIMARY KEY,
            short_id INT NOT NULL,
            user_id INT NOT NULL,
            share_type VARCHAR(50) DEFAULT 'native',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_short_id (short_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4",
        'short_saves' => "CREATE TABLE IF NOT EXISTS short_saves (
            id INT AUTO_INCREMENT PRIMARY KEY,
            short_id INT NOT NULL,
            user_id INT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UNIQUE KEY uniq_short_user (short_id, user_id),
            INDEX idx_short_id (short_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4",
    ];

    foreach ($tables as $sql) {
        @$conn->query($sql);
    }

    if (tableExists($conn, 'short_comments') && !columnExists($conn, 'short_comments', 'deleted_at')) {
        @$conn->query("ALTER TABLE short_comments ADD COLUMN deleted_at TIMESTAMP NULL DEFAULT NULL");
    }
    if (tableExists($conn, 'short_comments') && !columnExists($conn, 'short_comments', 'parent_comment_id')) {
        @$conn->query("ALTER TABLE short_comments ADD COLUMN parent_comment_id INT NULL DEFAULT NULL");
        @$conn->query("ALTER TABLE short_comments ADD INDEX idx_parent_comment_id (parent_comment_id)");
    }

    $uploadDir = __DIR__ . '/../uploads/shorts';
    if (!is_dir($uploadDir)) {
        @mkdir($uploadDir, 0755, true);
    }
}

function tableExists($conn, $table) {
    $table = $conn->real_escape_string($table);
    $res = $conn->query("SHOW TABLES LIKE '$table'");
    return $res && $res->num_rows > 0;
}

function columnExists($conn, $table, $column) {
    $table = $conn->real_escape_string($table);
    $column = $conn->real_escape_string($column);
    $res = $conn->query("SHOW COLUMNS FROM `$table` LIKE '$column'");
    return $res && $res->num_rows > 0;
}

function generateUuid() {
    return sprintf('%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
        mt_rand(0, 0xffff), mt_rand(0, 0xffff),
        mt_rand(0, 0xffff),
        mt_rand(0, 0x0fff) | 0x4000,
        mt_rand(0, 0x3fff) | 0x8000,
        mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff)
    );
}

function resolveMediaUrl($path) {
    if (empty($path)) return '';
    if (strpos($path, 'http') === 0) return $path;
    return rtrim(FOS_MEDIA_BASE_URL, '/') . '/' . ltrim($path, '/');
}

function formatShortRow($row, $currentUserId = 0, $conn = null) {
    $row['video_url_full'] = resolveMediaUrl($row['video_url']);
    $row['thumbnail_url_full'] = resolveMediaUrl($row['thumbnail_url'] ?? '');
    $row['is_liked'] = false;
    $row['is_saved'] = false;
    if ($currentUserId > 0 && $conn) {
        $sid = intval($row['id']);
        if (tableExists($conn, 'short_likes')) {
            $stmt = $conn->prepare("SELECT id FROM short_likes WHERE short_id = ? AND user_id = ? LIMIT 1");
            if ($stmt) {
                $stmt->bind_param("ii", $sid, $currentUserId);
                $stmt->execute();
                $row['is_liked'] = $stmt->get_result()->num_rows > 0;
            }
        }
        if (tableExists($conn, 'short_saves')) {
            $stmt2 = $conn->prepare("SELECT id FROM short_saves WHERE short_id = ? AND user_id = ? LIMIT 1");
            if ($stmt2) {
                $stmt2->bind_param("ii", $sid, $currentUserId);
                $stmt2->execute();
                $row['is_saved'] = $stmt2->get_result()->num_rows > 0;
            }
        }
    }
    return $row;
}

function handleGetShorts($conn) {
    $short_id = intval($_GET['id'] ?? 0);
    $uuid = trim($_GET['uuid'] ?? '');
    $user_id = intval($_GET['user_id'] ?? 0);
    $status = $_GET['status'] ?? 'Approved';
    $limit = min(intval($_GET['limit'] ?? 20), 50);
    $offset = intval($_GET['offset'] ?? 0);
    $cursor = intval($_GET['cursor'] ?? 0);
    $current_user_id = intval($_GET['current_user_id'] ?? 0);

    if ($short_id || $uuid) {
        $sql = "SELECT s.*, u.name AS user_name, u.profile_photo
                FROM shorts s
                JOIN users u ON s.user_id = u.id
                WHERE s.deleted_at IS NULL";
        if ($short_id) {
            $sql .= " AND s.id = ?";
            $stmt = $conn->prepare($sql);
            $stmt->bind_param("i", $short_id);
        } else {
            $sql .= " AND s.uuid = ?";
            $stmt = $conn->prepare($sql);
            $stmt->bind_param("s", $uuid);
        }
        $stmt->execute();
        $result = $stmt->get_result();
        if ($result->num_rows === 0) {
            http_response_code(404);
            echo jsonResponse(false, 'Short not found');
            return;
        }
        $short = formatShortRow($result->fetch_assoc(), $current_user_id, $conn);
        echo jsonResponse(true, 'Short retrieved', $short);
        return;
    }

    $sql = "SELECT s.*, u.name AS user_name, u.profile_photo
            FROM shorts s
            JOIN users u ON s.user_id = u.id
            WHERE s.deleted_at IS NULL";
    $params = [];
    $types = "";

    if ($current_user_id) {
        $check = $conn->query("SHOW TABLES LIKE 'user_blocks'");
        if ($check && $check->num_rows > 0) {
            $sql .= " AND s.user_id NOT IN (SELECT blocked_user_id FROM user_blocks WHERE user_id = ?)";
            $params[] = $current_user_id;
            $types .= "i";
        }
    }

    if ($status) {
        if (strpos($status, ',') !== false) {
            $parts = explode(',', $status);
            $ph = implode(',', array_fill(0, count($parts), '?'));
            $sql .= " AND s.status IN ($ph)";
            foreach ($parts as $p) {
                $params[] = trim($p);
                $types .= "s";
            }
        } else {
            $sql .= " AND s.status = ?";
            $params[] = $status;
            $types .= "s";
        }
    }

    if ($user_id) {
        $sql .= " AND s.user_id = ?";
        $params[] = $user_id;
        $types .= "i";
    }

    if ($cursor > 0) {
        $sql .= " AND s.id < ?";
        $params[] = $cursor;
        $types .= "i";
    }

    $sql .= " ORDER BY s.created_at DESC LIMIT ?";
    $params[] = $limit;
    $types .= "i";

    $stmt = $conn->prepare($sql);
    if (!empty($params)) {
        $stmt->bind_param($types, ...$params);
    }
    $stmt->execute();
    $result = $stmt->get_result();
    $shorts = [];
    $nextCursor = null;
    while ($row = $result->fetch_assoc()) {
        $shorts[] = formatShortRow($row, $current_user_id, $conn);
        $nextCursor = intval($row['id']);
    }

    echo jsonResponse(true, 'Shorts retrieved', [
        'items' => $shorts,
        'next_cursor' => $nextCursor,
        'has_more' => count($shorts) >= $limit,
    ]);
}

function handleUpload($conn) {
    try {
        ob_clean();

        $user_id = intval($_POST['user_id'] ?? 0);
        $title = trim($_POST['title'] ?? '');
        $description = trim($_POST['description'] ?? '');
        $visibility = trim($_POST['visibility'] ?? 'public');
        $duration = intval($_POST['duration'] ?? 0);

        if ($duration > 30) {
            http_response_code(400);
            echo jsonResponse(false, 'Shorts must be 30 seconds or less.');
            return;
        }

        if (!$user_id) {
            http_response_code(400);
            echo jsonResponse(false, 'user_id is required');
            return;
        }

        if (!in_array($visibility, ['public', 'private', 'followers'])) {
            $visibility = 'public';
        }

        if (!empty($title)) {
            $mod = ContentModerationService::checkContent($title, $conn);
            if ($mod['action'] === 'block') {
                http_response_code(400);
                echo jsonResponse(false, 'Title violates community guidelines.');
                return;
            }
            if (in_array($mod['action'], ['warn', 'quarantine'])) {
                $title = $mod['sanitized_content'];
            }
        }

        if (!empty($description)) {
            $mod = ContentModerationService::checkContent($description, $conn);
            if ($mod['action'] === 'block') {
                http_response_code(400);
                echo jsonResponse(false, 'Description violates community guidelines.');
                return;
            }
            if (in_array($mod['action'], ['warn', 'quarantine'])) {
                $description = $mod['sanitized_content'];
            }
        }

        $user_stmt = $conn->prepare("SELECT id FROM users WHERE id = ? AND status = 'Active'");
        if (!$user_stmt) {
            throw new Exception('Database prepare failed: ' . $conn->error);
        }
        $user_stmt->bind_param("i", $user_id);
        $user_stmt->execute();
        if ($user_stmt->get_result()->num_rows === 0) {
            http_response_code(404);
            echo jsonResponse(false, 'User not found');
            return;
        }

        if (!isset($_FILES['video']) || $_FILES['video']['error'] !== UPLOAD_ERR_OK) {
            $uploadErr = $_FILES['video']['error'] ?? UPLOAD_ERR_NO_FILE;
            http_response_code(400);
            echo jsonResponse(false, 'Video file is required (upload error code: ' . $uploadErr . ')');
            return;
        }

        $target_dir = __DIR__ . '/../uploads/shorts/';
        if (!is_dir($target_dir)) {
            if (!mkdir($target_dir, 0755, true)) {
                throw new Exception('Could not create upload directory');
            }
        }

        $ext = strtolower(pathinfo($_FILES['video']['name'], PATHINFO_EXTENSION));
        $allowed = ['mp4', 'mov', 'avi', 'wmv', 'flv', 'webm'];
        if (!in_array($ext, $allowed)) {
            http_response_code(400);
            echo jsonResponse(false, 'Invalid video format. Allowed: mp4, mov, avi, wmv, flv, webm');
            return;
        }

        $maxSize = 100 * 1024 * 1024;
        if ($_FILES['video']['size'] > $maxSize) {
            http_response_code(400);
            echo jsonResponse(false, 'Video exceeds 100MB limit');
            return;
        }

        $filename = 'short_' . time() . '_' . uniqid() . '.' . $ext;
        $filepath = $target_dir . $filename;
        if (!move_uploaded_file($_FILES['video']['tmp_name'], $filepath)) {
            http_response_code(500);
            echo jsonResponse(false, 'Failed to save video file');
            return;
        }

        $video_url = 'uploads/shorts/' . $filename;
        $thumbnail_url = '';

        if (isset($_FILES['thumbnail']) && $_FILES['thumbnail']['error'] === UPLOAD_ERR_OK) {
            $thumbExt = strtolower(pathinfo($_FILES['thumbnail']['name'], PATHINFO_EXTENSION));
            $allowedThumb = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
            if (in_array($thumbExt, $allowedThumb) && $_FILES['thumbnail']['size'] <= 10 * 1024 * 1024) {
                $thumbName = 'thumb_' . pathinfo($filename, PATHINFO_FILENAME) . '.jpg';
                $thumbPath = $target_dir . $thumbName;
                if (move_uploaded_file($_FILES['thumbnail']['tmp_name'], $thumbPath)) {
                    $thumbnail_url = 'uploads/shorts/' . $thumbName;
                }
            }
        }

        if ($thumbnail_url === '' && function_exists('generateVideoThumbnail')) {
            try {
                $thumbName = 'thumb_' . pathinfo($filename, PATHINFO_FILENAME) . '.jpg';
                $thumbPath = $target_dir . $thumbName;
                $generated = @generateVideoThumbnail($filepath, $thumbPath, 1);
                if ($generated && file_exists($thumbPath)) {
                    $thumbnail_url = 'uploads/shorts/' . $thumbName;
                }
            } catch (Exception $e) {
                error_log('Shorts thumbnail generation failed: ' . $e->getMessage());
            }
        }

        $uuid = generateUuid();
        $status = 'Pending';

        $stmt = $conn->prepare("INSERT INTO shorts (uuid, user_id, title, description, video_url, thumbnail_url, duration, visibility, status)
                                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)");
        if (!$stmt) {
            @unlink($filepath);
            throw new Exception('Insert prepare failed: ' . $conn->error);
        }

        $stmt->bind_param("sissssiss", $uuid, $user_id, $title, $description, $video_url, $thumbnail_url, $duration, $visibility, $status);

        if (!$stmt->execute()) {
            @unlink($filepath);
            http_response_code(500);
            echo jsonResponse(false, 'Database error: ' . $stmt->error);
            return;
        }

        $newId = $conn->insert_id;
        $get = $conn->prepare("SELECT s.*, u.name AS user_name, u.profile_photo FROM shorts s JOIN users u ON s.user_id = u.id WHERE s.id = ?");
        if (!$get) {
            echo jsonResponse(true, 'Short uploaded successfully. Pending approval.', ['id' => $newId]);
            return;
        }
        $get->bind_param("i", $newId);
        $get->execute();
        $row = $get->get_result()->fetch_assoc();
        $short = formatShortRow($row, $user_id, $conn);
        echo jsonResponse(true, 'Short uploaded successfully. Pending approval.', $short);
    } catch (Throwable $e) {
        error_log('Shorts upload error: ' . $e->getMessage());
        ob_clean();
        http_response_code(500);
        echo jsonResponse(false, 'Upload failed: ' . $e->getMessage());
    }
}

function handleToggleLike($conn) {
    $short_id = intval($_POST['short_id'] ?? $_GET['short_id'] ?? 0);
    $user_id = intval($_POST['user_id'] ?? $_GET['user_id'] ?? 0);

    if (!$short_id || !$user_id) {
        http_response_code(400);
        echo jsonResponse(false, 'short_id and user_id required');
        return;
    }

    $check = $conn->prepare("SELECT id FROM short_likes WHERE short_id = ? AND user_id = ?");
    $check->bind_param("ii", $short_id, $user_id);
    $check->execute();
    $liked = $check->get_result()->num_rows > 0;

    if ($liked) {
        $del = $conn->prepare("DELETE FROM short_likes WHERE short_id = ? AND user_id = ?");
        $del->bind_param("ii", $short_id, $user_id);
        $del->execute();
        $conn->query("UPDATE shorts SET total_likes = GREATEST(0, total_likes - 1) WHERE id = $short_id");
        $isLiked = false;
    } else {
        $ins = $conn->prepare("INSERT INTO short_likes (short_id, user_id) VALUES (?, ?)");
        $ins->bind_param("ii", $short_id, $user_id);
        $ins->execute();
        $conn->query("UPDATE shorts SET total_likes = total_likes + 1 WHERE id = $short_id");
        $isLiked = true;
    }

    $countRes = $conn->query("SELECT total_likes FROM shorts WHERE id = $short_id");
    $count = $countRes ? intval($countRes->fetch_assoc()['total_likes']) : 0;

    echo jsonResponse(true, $isLiked ? 'Liked' : 'Unliked', [
        'is_liked' => $isLiked,
        'total_likes' => $count,
        'short_id' => $short_id,
    ]);
}

function handleToggleSave($conn) {
    $short_id = intval($_POST['short_id'] ?? 0);
    $user_id = intval($_POST['user_id'] ?? 0);

    if (!$short_id || !$user_id) {
        http_response_code(400);
        echo jsonResponse(false, 'short_id and user_id required');
        return;
    }

    $check = $conn->prepare("SELECT id FROM short_saves WHERE short_id = ? AND user_id = ?");
    $check->bind_param("ii", $short_id, $user_id);
    $check->execute();
    $saved = $check->get_result()->num_rows > 0;

    if ($saved) {
        $del = $conn->prepare("DELETE FROM short_saves WHERE short_id = ? AND user_id = ?");
        $del->bind_param("ii", $short_id, $user_id);
        $del->execute();
        $conn->query("UPDATE shorts SET total_saves = GREATEST(0, total_saves - 1) WHERE id = $short_id");
        $isSaved = false;
    } else {
        $ins = $conn->prepare("INSERT INTO short_saves (short_id, user_id) VALUES (?, ?)");
        $ins->bind_param("ii", $short_id, $user_id);
        $ins->execute();
        $conn->query("UPDATE shorts SET total_saves = total_saves + 1 WHERE id = $short_id");
        $isSaved = true;
    }

    $countRes = $conn->query("SELECT total_saves FROM shorts WHERE id = $short_id");
    $count = $countRes ? intval($countRes->fetch_assoc()['total_saves']) : 0;

    echo jsonResponse(true, $isSaved ? 'Saved' : 'Unsaved', [
        'is_saved' => $isSaved,
        'total_saves' => $count,
        'short_id' => $short_id,
    ]);
}

function handleShare($conn) {
    $short_id = intval($_POST['short_id'] ?? 0);
    $user_id = intval($_POST['user_id'] ?? 0);
    $share_type = trim($_POST['share_type'] ?? 'native');

    if (!$short_id) {
        http_response_code(400);
        echo jsonResponse(false, 'short_id required');
        return;
    }

    if ($user_id) {
        $ins = $conn->prepare("INSERT INTO short_shares (short_id, user_id, share_type) VALUES (?, ?, ?)");
        $ins->bind_param("iis", $short_id, $user_id, $share_type);
        $ins->execute();
    }
    $conn->query("UPDATE shorts SET total_shares = total_shares + 1 WHERE id = $short_id");

    $countRes = $conn->query("SELECT total_shares FROM shorts WHERE id = $short_id");
    $count = $countRes ? intval($countRes->fetch_assoc()['total_shares']) : 0;

    echo jsonResponse(true, 'Share tracked', [
        'total_shares' => $count,
        'short_id' => $short_id,
    ]);
}

function handleReport($conn) {
    $short_id = intval($_POST['short_id'] ?? 0);
    $reported_by = intval($_POST['user_id'] ?? 0);
    $reason = trim($_POST['reason'] ?? '');
    $description = trim($_POST['description'] ?? '');

    $allowed = ['Spam', 'Harassment', 'Inappropriate Content', 'Copyright', 'Other'];
    if (!$short_id || !$reported_by || !in_array($reason, $allowed)) {
        http_response_code(400);
        echo jsonResponse(false, 'Invalid report data');
        return;
    }

    $stmt = $conn->prepare("INSERT INTO short_reports (short_id, reported_by, reason, description) VALUES (?, ?, ?, ?)");
    $stmt->bind_param("iiss", $short_id, $reported_by, $reason, $description);
    if ($stmt->execute()) {
        echo jsonResponse(true, 'Report submitted');
    } else {
        http_response_code(500);
        echo jsonResponse(false, 'Failed to submit report');
    }
}

function handleView($conn) {
    $short_id = intval($_POST['short_id'] ?? $_GET['short_id'] ?? 0);
    $user_id = intval($_POST['user_id'] ?? $_GET['user_id'] ?? 0);

    if (!$short_id) {
        http_response_code(400);
        echo jsonResponse(false, 'short_id required');
        return;
    }

    if ($user_id) {
        $ins = $conn->prepare("INSERT INTO short_views (short_id, user_id) VALUES (?, ?)");
        $ins->bind_param("ii", $short_id, $user_id);
        @$ins->execute();
    }
    $conn->query("UPDATE shorts SET total_views = total_views + 1 WHERE id = $short_id");

    echo jsonResponse(true, 'View recorded');
}

function handleDelete($conn) {
    $short_id = intval($_POST['short_id'] ?? 0);
    $user_id = intval($_POST['user_id'] ?? 0);

    if (!$short_id || !$user_id) {
        http_response_code(400);
        echo jsonResponse(false, 'short_id and user_id required');
        return;
    }

    $stmt = $conn->prepare("SELECT user_id FROM shorts WHERE id = ? AND deleted_at IS NULL");
    $stmt->bind_param("i", $short_id);
    $stmt->execute();
    $res = $stmt->get_result();
    if ($res->num_rows === 0) {
        http_response_code(404);
        echo jsonResponse(false, 'Short not found');
        return;
    }
    $owner = intval($res->fetch_assoc()['user_id']);
    if ($owner !== $user_id) {
        http_response_code(403);
        echo jsonResponse(false, 'Unauthorized');
        return;
    }

    $upd = $conn->prepare("UPDATE shorts SET status = 'Deleted', deleted_at = NOW() WHERE id = ?");
    $upd->bind_param("i", $short_id);
    if ($upd->execute()) {
        echo jsonResponse(true, 'Short deleted');
    } else {
        http_response_code(500);
        echo jsonResponse(false, 'Delete failed');
    }
}

function isShortVisualComment($comment) {
    $comment = trim((string)$comment);
    if ($comment === '') return false;
    if (preg_match('/^:sticker_\d+:$/', $comment)) return true;
    if (preg_match('/^:emoji_\d+:$/', $comment)) return true;
    if (preg_match('/^https?:\/\/.+\.(png|jpe?g|webp)(\?.*)?$/i', $comment)) return true;
    return false;
}

/** DB keeps MySQL datetime; API sends UTC ISO so Flutter can convert to user timezone. */
function formatUtcIsoTimestamp($mysqlDatetime) {
    if ($mysqlDatetime === null || $mysqlDatetime === '') {
        return $mysqlDatetime;
    }
    try {
        $dt = new DateTime((string)$mysqlDatetime, new DateTimeZone('UTC'));
        return $dt->format('Y-m-d\TH:i:s\Z');
    } catch (Throwable $e) {
        return $mysqlDatetime;
    }
}

function formatShortCommentForApi(array $row) {
    if (!empty($row['created_at'])) {
        $row['created_at'] = formatUtcIsoTimestamp($row['created_at']);
    }
    if (!isset($row['replies'])) {
        $row['replies'] = [];
    }
    return $row;
}

function buildShortCommentTree(array $rows) {
    $indexed = [];
    foreach ($rows as $row) {
        $row = formatShortCommentForApi($row);
        $row['replies'] = [];
        $indexed[intval($row['id'])] = $row;
    }
    $roots = [];
    foreach ($indexed as $id => &$row) {
        $parentId = intval($row['parent_comment_id'] ?? 0);
        if ($parentId > 0 && isset($indexed[$parentId])) {
            $indexed[$parentId]['replies'][] = &$row;
        } else {
            $roots[] = &$row;
        }
    }
    unset($row);
    return array_values($roots);
}

function shortCommentSelectSql() {
    return "c.id, c.short_id, c.user_id, c.comment, c.parent_comment_id, c.created_at,
            COALESCE(NULLIF(TRIM(u.name), ''), 'User') AS user_name,
            u.profile_photo";
}

function handleGetComments($conn) {
    $short_id = intval($_GET['short_id'] ?? 0);
    if (!$short_id) {
        http_response_code(400);
        echo jsonResponse(false, 'short_id required');
        return;
    }

    $deletedFilter = columnExists($conn, 'short_comments', 'deleted_at')
        ? ' AND c.deleted_at IS NULL'
        : '';

    $stmt = $conn->prepare("
        SELECT " . shortCommentSelectSql() . "
        FROM short_comments c
        LEFT JOIN users u ON c.user_id = u.id
        WHERE c.short_id = ?{$deletedFilter}
        ORDER BY c.created_at ASC
    ");
    $stmt->bind_param("i", $short_id);
    $stmt->execute();
    $result = $stmt->get_result();
    $rows = [];
    while ($row = $result->fetch_assoc()) {
        $rows[] = $row;
    }
    echo jsonResponse(true, 'Comments retrieved', buildShortCommentTree($rows));
}

function handleAddComment($conn) {
    $short_id = intval($_POST['short_id'] ?? 0);
    $user_id = intval($_POST['user_id'] ?? 0);
    $comment = trim($_POST['comment'] ?? '');
    $parent_comment_id = !empty($_POST['parent_comment_id']) ? intval($_POST['parent_comment_id']) : 0;

    if (!$short_id || !$user_id || $comment === '') {
        http_response_code(400);
        echo jsonResponse(false, 'short_id, user_id, and comment required');
        return;
    }

    if ($parent_comment_id > 0) {
        $parentStmt = $conn->prepare("SELECT short_id FROM short_comments WHERE id = ? AND deleted_at IS NULL");
        $parentStmt->bind_param("i", $parent_comment_id);
        $parentStmt->execute();
        $parentRes = $parentStmt->get_result();
        if ($parentRes->num_rows === 0) {
            http_response_code(400);
            echo jsonResponse(false, 'Parent comment not found');
            return;
        }
        $parentRow = $parentRes->fetch_assoc();
        if (intval($parentRow['short_id']) !== $short_id) {
            http_response_code(400);
            echo jsonResponse(false, 'Invalid parent comment');
            return;
        }
    }

    if (!isShortVisualComment($comment)) {
        $mod = ContentModerationService::checkContent($comment, $conn);
        if ($mod['action'] === 'block') {
            http_response_code(400);
            echo jsonResponse(false, 'Comment violates community guidelines.');
            return;
        }
        if (in_array($mod['action'], ['warn', 'quarantine'])) {
            $comment = $mod['sanitized_content'];
        }
    }

    if ($parent_comment_id > 0) {
        $stmt = $conn->prepare("INSERT INTO short_comments (short_id, user_id, comment, parent_comment_id) VALUES (?, ?, ?, ?)");
        $stmt->bind_param("iisi", $short_id, $user_id, $comment, $parent_comment_id);
    } else {
        $stmt = $conn->prepare("INSERT INTO short_comments (short_id, user_id, comment) VALUES (?, ?, ?)");
        $stmt->bind_param("iis", $short_id, $user_id, $comment);
    }
    if ($stmt->execute()) {
        $conn->query("UPDATE shorts SET total_comments = total_comments + 1 WHERE id = $short_id");
        $newId = $conn->insert_id;
        $get = $conn->prepare("
            SELECT " . shortCommentSelectSql() . "
            FROM short_comments c
            LEFT JOIN users u ON c.user_id = u.id
            WHERE c.id = ?
        ");
        $get->bind_param("i", $newId);
        $get->execute();
        $row = formatShortCommentForApi($get->get_result()->fetch_assoc());
        $row['reactions'] = [];
        $countRes = $conn->query("SELECT total_comments FROM shorts WHERE id = $short_id");
        $totalComments = $countRes ? intval($countRes->fetch_assoc()['total_comments']) : 0;
        echo jsonResponse(true, 'Comment added', [
            'comment' => $row,
            'total_comments' => $totalComments,
        ]);
    } else {
        http_response_code(500);
        echo jsonResponse(false, 'Failed to add comment');
    }
}

function handleCommentReaction($conn) {
    $comment_id = intval($_POST['comment_id'] ?? 0);
    $user_id = intval($_POST['user_id'] ?? 0);
    $emoji = trim($_POST['emoji'] ?? '');

    if (!$comment_id || !$user_id || $emoji === '') {
        http_response_code(400);
        echo jsonResponse(false, 'comment_id, user_id, and emoji required');
        return;
    }

    $check = $conn->prepare("SELECT id FROM short_comment_reactions WHERE comment_id = ? AND user_id = ? AND emoji = ?");
    $check->bind_param("iis", $comment_id, $user_id, $emoji);
    $check->execute();
    if ($check->get_result()->num_rows > 0) {
        $del = $conn->prepare("DELETE FROM short_comment_reactions WHERE comment_id = ? AND user_id = ? AND emoji = ?");
        $del->bind_param("iis", $comment_id, $user_id, $emoji);
        $del->execute();
        $added = false;
    } else {
        $ins = $conn->prepare("INSERT INTO short_comment_reactions (comment_id, user_id, emoji) VALUES (?, ?, ?)");
        $ins->bind_param("iis", $comment_id, $user_id, $emoji);
        $ins->execute();
        $added = true;
    }

    echo jsonResponse(true, $added ? 'Reaction added' : 'Reaction removed', ['added' => $added]);
}

function handleDeleteComment($conn) {
    $comment_id = intval($_POST['comment_id'] ?? 0);
    $user_id = intval($_POST['user_id'] ?? 0);

    if (!$comment_id || !$user_id) {
        http_response_code(400);
        echo jsonResponse(false, 'comment_id and user_id required');
        return;
    }

    $stmt = $conn->prepare("SELECT user_id, short_id FROM short_comments WHERE id = ? AND deleted_at IS NULL");
    $stmt->bind_param("i", $comment_id);
    $stmt->execute();
    $res = $stmt->get_result();
    if ($res->num_rows === 0) {
        http_response_code(404);
        echo jsonResponse(false, 'Comment not found');
        return;
    }
    $row = $res->fetch_assoc();
    if (intval($row['user_id']) !== $user_id) {
        http_response_code(403);
        echo jsonResponse(false, 'Unauthorized');
        return;
    }

    $upd = $conn->prepare("UPDATE short_comments SET deleted_at = NOW() WHERE id = ?");
    $upd->bind_param("i", $comment_id);
    $upd->execute();
    $sid = intval($row['short_id']);
    $conn->query("UPDATE shorts SET total_comments = GREATEST(0, total_comments - 1) WHERE id = $sid");

    echo jsonResponse(true, 'Comment deleted');
}

function handleEditComment($conn) {
    $comment_id = intval($_POST['comment_id'] ?? 0);
    $user_id = intval($_POST['user_id'] ?? 0);
    $comment = trim($_POST['comment'] ?? '');

    if (!$comment_id || !$user_id || $comment === '') {
        http_response_code(400);
        echo jsonResponse(false, 'comment_id, user_id, and comment required');
        return;
    }

    $stmt = $conn->prepare("SELECT user_id, short_id, created_at FROM short_comments WHERE id = ? AND deleted_at IS NULL");
    $stmt->bind_param("i", $comment_id);
    $stmt->execute();
    $res = $stmt->get_result();
    if ($res->num_rows === 0) {
        http_response_code(404);
        echo jsonResponse(false, 'Comment not found');
        return;
    }
    $row = $res->fetch_assoc();
    if (intval($row['user_id']) !== $user_id) {
        http_response_code(403);
        echo jsonResponse(false, 'You can only edit your own comments');
        return;
    }

    $created_at = new DateTime($row['created_at'], new DateTimeZone('UTC'));
    $now = new DateTime('now', new DateTimeZone('UTC'));
    $minutes = ($now->getTimestamp() - $created_at->getTimestamp()) / 60;
    if ($minutes >= 15) {
        http_response_code(403);
        echo jsonResponse(false, 'Edit window expired (15 minutes)');
        return;
    }

    if (!isShortVisualComment($comment)) {
        $mod = ContentModerationService::checkContent($comment, $conn);
        if ($mod['action'] === 'block') {
            http_response_code(400);
            echo jsonResponse(false, 'Comment violates community guidelines.');
            return;
        }
        if (in_array($mod['action'], ['warn', 'quarantine'])) {
            $comment = $mod['sanitized_content'];
        }
    }

    $upd = $conn->prepare("UPDATE short_comments SET comment = ?, updated_at = NOW() WHERE id = ?");
    $upd->bind_param("si", $comment, $comment_id);
    if (!$upd->execute()) {
        http_response_code(500);
        echo jsonResponse(false, 'Failed to update comment');
        return;
    }

    $get = $conn->prepare("
        SELECT " . shortCommentSelectSql() . "
        FROM short_comments c
        LEFT JOIN users u ON c.user_id = u.id
        WHERE c.id = ?
    ");
    $get->bind_param("i", $comment_id);
    $get->execute();
    $updated = formatShortCommentForApi($get->get_result()->fetch_assoc());
    $updated['replies'] = [];
    echo jsonResponse(true, 'Comment updated', ['comment' => $updated]);
}

function handleReportComment($conn) {
    $comment_id = intval($_POST['comment_id'] ?? 0);
    $user_id = intval($_POST['user_id'] ?? 0);
    $reason = trim($_POST['reason'] ?? 'General concern');
    $description = trim($_POST['description'] ?? '');

    if (!$comment_id || !$user_id) {
        http_response_code(400);
        echo jsonResponse(false, 'comment_id and user_id required');
        return;
    }

    $check = $conn->prepare("SELECT id FROM short_comments WHERE id = ? AND deleted_at IS NULL");
    $check->bind_param("i", $comment_id);
    $check->execute();
    if ($check->get_result()->num_rows === 0) {
        http_response_code(404);
        echo jsonResponse(false, 'Comment not found');
        return;
    }

    $dup = $conn->prepare("SELECT id FROM short_comment_reports WHERE comment_id = ? AND reported_by = ?");
    $dup->bind_param("ii", $comment_id, $user_id);
    $dup->execute();
    if ($dup->get_result()->num_rows > 0) {
        echo jsonResponse(true, 'Already reported');
        return;
    }

    $stmt = $conn->prepare("INSERT INTO short_comment_reports (comment_id, reported_by, reason, description) VALUES (?, ?, ?, ?)");
    $stmt->bind_param("iiss", $comment_id, $user_id, $reason, $description);
    if ($stmt->execute()) {
        echo jsonResponse(true, 'Comment reported');
    } else {
        http_response_code(500);
        echo jsonResponse(false, 'Failed to submit report');
    }
}

function handleGetSaved($conn) {
    $user_id = intval($_GET['user_id'] ?? 0);
    $limit = min(intval($_GET['limit'] ?? 20), 50);
    $offset = intval($_GET['offset'] ?? 0);

    if (!$user_id) {
        http_response_code(400);
        echo jsonResponse(false, 'user_id required');
        return;
    }

    $stmt = $conn->prepare("
        SELECT s.*, u.name AS user_name, u.profile_photo
        FROM short_saves sv
        JOIN shorts s ON sv.short_id = s.id
        JOIN users u ON s.user_id = u.id
        WHERE sv.user_id = ? AND s.deleted_at IS NULL AND s.status = 'Approved'
        ORDER BY sv.created_at DESC
        LIMIT ? OFFSET ?
    ");
    $stmt->bind_param("iii", $user_id, $limit, $offset);
    $stmt->execute();
    $result = $stmt->get_result();
    $items = [];
    while ($row = $result->fetch_assoc()) {
        $items[] = formatShortRow($row, $user_id, $conn);
    }
    echo jsonResponse(true, 'Saved shorts retrieved', $items);
}

function handleGetCounts($conn) {
    $ids = trim($_GET['ids'] ?? '');
    if (empty($ids)) {
        http_response_code(400);
        echo jsonResponse(false, 'ids required (comma-separated)');
        return;
    }
    $idList = array_filter(array_map('intval', explode(',', $ids)));
    if (empty($idList)) {
        echo jsonResponse(true, 'Counts retrieved', []);
        return;
    }
    $ph = implode(',', $idList);
    $result = $conn->query("SELECT id, total_likes, total_comments, total_shares, total_saves, total_views FROM shorts WHERE id IN ($ph)");
    $counts = [];
    while ($row = $result->fetch_assoc()) {
        $counts[$row['id']] = [
            'total_likes' => intval($row['total_likes']),
            'total_comments' => intval($row['total_comments']),
            'total_shares' => intval($row['total_shares']),
            'total_saves' => intval($row['total_saves']),
            'total_views' => intval($row['total_views']),
        ];
    }
    echo jsonResponse(true, 'Counts retrieved', $counts);
}

function handleAnalytics($conn) {
    $stats = [];
    $tables = [
        'total_shorts' => "SELECT COUNT(*) AS c FROM shorts WHERE deleted_at IS NULL",
        'total_views' => "SELECT COALESCE(SUM(total_views),0) AS c FROM shorts",
        'total_likes' => "SELECT COALESCE(SUM(total_likes),0) AS c FROM shorts",
        'total_comments' => "SELECT COALESCE(SUM(total_comments),0) AS c FROM shorts",
        'total_shares' => "SELECT COALESCE(SUM(total_shares),0) AS c FROM shorts",
        'total_saves' => "SELECT COALESCE(SUM(total_saves),0) AS c FROM shorts",
    ];
    foreach ($tables as $key => $sql) {
        $res = $conn->query($sql);
        $stats[$key] = $res ? intval($res->fetch_assoc()['c']) : 0;
    }
    echo jsonResponse(true, 'Analytics retrieved', $stats);
}
