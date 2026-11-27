<?php
/**
 * One-time migration for Shorts module tables.
 * Run once: https://admin.fosmessenger.com/api/migrate_shorts.php
 */

require_once '../includes/db.php';
require_once '../includes/cors.php';

header('Content-Type: application/json; charset=utf-8');

$results = [];

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

try {
    $uploadDir = __DIR__ . '/../uploads/shorts';
    if (!is_dir($uploadDir)) {
        if (mkdir($uploadDir, 0755, true)) {
            $results[] = 'CREATED uploads/shorts directory';
        } else {
            $results[] = 'ERROR could not create uploads/shorts directory';
        }
    } else {
        $results[] = 'OK uploads/shorts directory exists';
    }

    if (!tableExists($conn, 'shorts')) {
        $sql = "CREATE TABLE shorts (
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
            INDEX idx_created_at (created_at),
            INDEX idx_deleted_at (deleted_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4";
        $results[] = $conn->query($sql) ? 'CREATED shorts table' : 'ERROR shorts — ' . $conn->error;
    } else {
        $results[] = 'OK shorts table exists';
    }

    if (!tableExists($conn, 'short_likes')) {
        $sql = "CREATE TABLE short_likes (
            id INT AUTO_INCREMENT PRIMARY KEY,
            short_id INT NOT NULL,
            user_id INT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UNIQUE KEY uniq_short_user (short_id, user_id),
            INDEX idx_short_id (short_id),
            INDEX idx_user_id (user_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4";
        $results[] = $conn->query($sql) ? 'CREATED short_likes table' : 'ERROR short_likes — ' . $conn->error;
    } else {
        $results[] = 'OK short_likes table exists';
    }

    if (!tableExists($conn, 'short_comments')) {
        $sql = "CREATE TABLE short_comments (
            id INT AUTO_INCREMENT PRIMARY KEY,
            short_id INT NOT NULL,
            user_id INT NOT NULL,
            comment TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            deleted_at TIMESTAMP NULL DEFAULT NULL,
            parent_comment_id INT NULL DEFAULT NULL,
            INDEX idx_short_id (short_id),
            INDEX idx_user_id (user_id),
            INDEX idx_parent_comment_id (parent_comment_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4";
        $results[] = $conn->query($sql) ? 'CREATED short_comments table' : 'ERROR short_comments — ' . $conn->error;
    } else {
        $results[] = 'OK short_comments table exists';
        if (!columnExists($conn, 'short_comments', 'parent_comment_id')) {
            $alter = "ALTER TABLE short_comments ADD COLUMN parent_comment_id INT NULL DEFAULT NULL, ADD INDEX idx_parent_comment_id (parent_comment_id)";
            $results[] = $conn->query($alter) ? 'ADDED parent_comment_id to short_comments' : 'ERROR parent_comment_id — ' . $conn->error;
        }
    }

    if (!tableExists($conn, 'short_comment_reactions')) {
        $sql = "CREATE TABLE short_comment_reactions (
            id INT AUTO_INCREMENT PRIMARY KEY,
            comment_id INT NOT NULL,
            user_id INT NOT NULL,
            emoji VARCHAR(50) NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_comment_id (comment_id),
            INDEX idx_user_id (user_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4";
        $results[] = $conn->query($sql) ? 'CREATED short_comment_reactions table' : 'ERROR short_comment_reactions — ' . $conn->error;
    } else {
        $results[] = 'OK short_comment_reactions table exists';
    }

    if (!tableExists($conn, 'short_reports')) {
        $sql = "CREATE TABLE short_reports (
            id INT AUTO_INCREMENT PRIMARY KEY,
            short_id INT NOT NULL,
            reported_by INT NOT NULL,
            reason VARCHAR(100) NOT NULL,
            description TEXT DEFAULT NULL,
            status ENUM('pending','reviewed','dismissed','action_taken') DEFAULT 'pending',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_short_id (short_id),
            INDEX idx_status (status)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4";
        $results[] = $conn->query($sql) ? 'CREATED short_reports table' : 'ERROR short_reports — ' . $conn->error;
    } else {
        $results[] = 'OK short_reports table exists';
    }

    if (!tableExists($conn, 'short_views')) {
        $sql = "CREATE TABLE short_views (
            id INT AUTO_INCREMENT PRIMARY KEY,
            short_id INT NOT NULL,
            user_id INT NOT NULL,
            viewed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_short_id (short_id),
            INDEX idx_user_id (user_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4";
        $results[] = $conn->query($sql) ? 'CREATED short_views table' : 'ERROR short_views — ' . $conn->error;
    } else {
        $results[] = 'OK short_views table exists';
    }

    if (!tableExists($conn, 'short_shares')) {
        $sql = "CREATE TABLE short_shares (
            id INT AUTO_INCREMENT PRIMARY KEY,
            short_id INT NOT NULL,
            user_id INT NOT NULL,
            share_type VARCHAR(50) DEFAULT 'native',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_short_id (short_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4";
        $results[] = $conn->query($sql) ? 'CREATED short_shares table' : 'ERROR short_shares — ' . $conn->error;
    } else {
        $results[] = 'OK short_shares table exists';
    }

    if (!tableExists($conn, 'short_saves')) {
        $sql = "CREATE TABLE short_saves (
            id INT AUTO_INCREMENT PRIMARY KEY,
            short_id INT NOT NULL,
            user_id INT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UNIQUE KEY uniq_short_user (short_id, user_id),
            INDEX idx_short_id (short_id),
            INDEX idx_user_id (user_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4";
        $results[] = $conn->query($sql) ? 'CREATED short_saves table' : 'ERROR short_saves — ' . $conn->error;
    } else {
        $results[] = 'OK short_saves table exists';
    }

    echo json_encode(['success' => true, 'results' => $results]);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => $e->getMessage(), 'results' => $results]);
}
