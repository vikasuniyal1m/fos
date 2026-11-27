<?php
require_once 'includes/db.php';

$query = $_GET['q'] ?? '';

if (strlen($query) < 2) {
    echo '<div class="p-2 text-muted">Enter at least 2 characters</div>';
    exit;
}

// Check if MySQLi connection exists
if (!isset($conn) || $conn->connect_error) {
    echo '<div class="p-2 text-muted">Database connection error</div>';
    exit;
}

try {
    $results = [];

    // Search users
    $stmt = $conn->prepare("
        SELECT id, name, email, profile_photo, 'user' as type 
        FROM users 
        WHERE name LIKE ? OR email LIKE ?
        LIMIT 5
    ");
    $searchTerm = "%$query%";
    $stmt->bind_param("ss", $searchTerm, $searchTerm);
    $stmt->execute();
    $users = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $results = array_merge($results, $users);
    $stmt->close();

    // Search blogs
    $stmt = $conn->prepare("
        SELECT id, title, body as content, 'blog' as type 
        FROM blogs 
        WHERE (title LIKE ? OR body LIKE ?) 
        AND status = 'Approved'
        LIMIT 5
    ");
    $stmt->bind_param("ss", $searchTerm, $searchTerm);
    $stmt->execute();
    $blogs = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $results = array_merge($results, $blogs);
    $stmt->close();

    // Search prayer requests
    $stmt = $conn->prepare("
        SELECT id, content, 'prayer' as type 
        FROM prayer_requests 
        WHERE content LIKE ? 
        AND status = 'Approved'
        LIMIT 5
    ");
    $stmt->bind_param("s", $searchTerm);
    $stmt->execute();
    $prayers = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $results = array_merge($results, $prayers);
    $stmt->close();

    if (empty($results)) {
        echo '<div class="p-2 text-muted">No results found</div>';
        exit;
    }

    foreach ($results as $result) {
        $image = 'assets/images/user.png';
        $title = '';
        $subtitle = '';
        $link = '#';
        
        switch ($result['type']) {
            case 'user':
                $image = $result['profile_photo'] ?: 'assets/images/user.png';
                $title = $result['name'];
                $subtitle = 'User';
                $link = 'view-profile.php?id=' . $result['id'];
                break;
            case 'blog':
                $image = 'assets/images/blog-icon.png';
                $title = $result['title'];
                $subtitle = substr(strip_tags($result['content']), 0, 50) . '...';
                $link = 'blog-details.php?id=' . $result['id'];
                break;
            case 'prayer':
                $image = 'assets/images/prayer-icon.png';
                $title = 'Prayer Request';
                $subtitle = substr(strip_tags($result['content']), 0, 50) . '...';
                $link = 'prayer-details.php?id=' . $result['id'];
                break;
        }

        echo "
        <a href='$link' class='result-item'>
            <img src='$image' alt='$title'>
            <div class='result-text'>
                <div class='title'>$title</div>
                <div class='subtitle'>$subtitle</div>
            </div>
        </a>";
    }

} catch (Exception $e) {
    echo '<div class="p-2 text-muted">Error searching</div>';
    error_log("Search error: " . $e->getMessage());
}
?>