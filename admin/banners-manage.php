<?php
require_once __DIR__ . '/includes/admin-auth.php';
require_once __DIR__ . '/includes/db.php';

$tableCheck = $conn->query("SHOW TABLES LIKE 'banners'");
$tableOk = ($tableCheck && $tableCheck->num_rows > 0);

$success = $_SESSION['banner_success'] ?? '';
$error = $_SESSION['banner_error'] ?? '';
// Clear session messages after reading
unset($_SESSION['banner_success'], $_SESSION['banner_error']);

$allowedExt = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg', 'bmp', 'mp4', 'webm', 'mov', 'avi', 'mkv', 'mp3', 'wav', 'ogg', 'm4a', 'aac', 'flac', 'pdf'];
$maxBytes = 100 * 1024 * 1024;

/**
 * @param string $s
 * @return string
 */
function banner_normalize_datetime($s) {
    $s = trim(str_replace('T', ' ', $s));
    if (preg_match('/^\d{4}-\d{2}-\d{2}\s\d{2}:\d{2}$/', $s)) {
        $s .= ':00';
    }
    return $s;
}

if ($tableOk && $_SERVER['REQUEST_METHOD'] === 'POST') {
    if (isset($_POST['delete_id'])) {
        $id = (int) $_POST['delete_id'];
        $stmt = $conn->prepare('SELECT file_path FROM banners WHERE id = ?');
        $stmt->bind_param('i', $id);
        $stmt->execute();
        $res = $stmt->get_result();
        if ($row = $res->fetch_assoc()) {
            $fp = __DIR__ . '/' . ltrim($row['file_path'], '/');
            if (is_file($fp)) {
                @unlink($fp);
            }
        }
        $stmt->close();
        $del = $conn->prepare('DELETE FROM banners WHERE id = ?');
        $del->bind_param('i', $id);
        if ($del->execute()) {
            $_SESSION['banner_success'] = 'Banner deleted.';
        } else {
            $_SESSION['banner_error'] = 'Could not delete banner.';
        }
        $del->close();
        header('Location: banners-manage.php');
        exit;
    } elseif (isset($_POST['save_banner'])) {
        $title = trim($_POST['title'] ?? '');
        $starts = banner_normalize_datetime($_POST['starts_at'] ?? '');
        $ends = banner_normalize_datetime($_POST['ends_at'] ?? '');
        $sort_order = (int) ($_POST['sort_order'] ?? 0);
        $status = ($_POST['status'] ?? 'Active') === 'Inactive' ? 'Inactive' : 'Active';

        if ($title === '') {
            $_SESSION['banner_error'] = 'Title is required.';
            header('Location: banners-manage.php');
            exit;
        } elseif (!preg_match('/^\d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}$/', $starts) || !preg_match('/^\d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}$/', $ends)) {
            $_SESSION['banner_error'] = 'Start and end date/time are invalid. Use the date pickers.';
            header('Location: banners-manage.php');
            exit;
        } elseif (strtotime($ends) <= strtotime($starts)) {
            $_SESSION['banner_error'] = 'End time must be after start time.';
            header('Location: banners-manage.php');
            exit;
        } elseif (!isset($_FILES['banner_file']) || $_FILES['banner_file']['error'] !== UPLOAD_ERR_OK) {
            $_SESSION['banner_error'] = 'Please choose a file to upload.';
            header('Location: banners-manage.php');
            exit;
        } else {
            $ext = strtolower(pathinfo($_FILES['banner_file']['name'], PATHINFO_EXTENSION));
            if (!in_array($ext, $allowedExt, true)) {
                $_SESSION['banner_error'] = 'File type not allowed. Allowed: ' . implode(', ', $allowedExt);
                header('Location: banners-manage.php');
                exit;
            } elseif ($_FILES['banner_file']['size'] > $maxBytes) {
                $_SESSION['banner_error'] = 'File is too large (max 100 MB).';
                header('Location: banners-manage.php');
                exit;
            } else {
                $dir = __DIR__ . '/uploads/banners/';
                if (!is_dir($dir)) {
                    mkdir($dir, 0755, true);
                }
                $safe = 'banner_' . time() . '_' . bin2hex(random_bytes(4)) . '.' . $ext;
                $dest = $dir . $safe;
                if (!move_uploaded_file($_FILES['banner_file']['tmp_name'], $dest)) {
                    $_SESSION['banner_error'] = 'Failed to save uploaded file.';
                    header('Location: banners-manage.php');
                    exit;
                } else {
                    $rel = 'uploads/banners/' . $safe;
                    $mime = $_FILES['banner_file']['type'] ?? '';
                    $orig = $_FILES['banner_file']['name'];
                    $ins = $conn->prepare('INSERT INTO banners (title, file_path, original_filename, mime_type, starts_at, ends_at, sort_order, status) VALUES (?,?,?,?,?,?,?,?)');
                    $ins->bind_param('ssssssis', $title, $rel, $orig, $mime, $starts, $ends, $sort_order, $status);
                    if ($ins->execute()) {
                        $_SESSION['banner_success'] = 'Banner created successfully.';
                    } else {
                        $_SESSION['banner_error'] = 'Database error: ' . htmlspecialchars($conn->error);
                        @unlink($dest);
                    }
                    $ins->close();
                    header('Location: banners-manage.php');
                    exit;
                }
            }
        }
    } elseif (isset($_POST['toggle_id'], $_POST['toggle_status'])) {
        $tid = (int) $_POST['toggle_id'];
        $st = $_POST['toggle_status'] === 'Inactive' ? 'Inactive' : 'Active';
        $t = $conn->prepare('UPDATE banners SET status = ? WHERE id = ?');
        $t->bind_param('si', $st, $tid);
        $t->execute();
        $t->close();
        $_SESSION['banner_success'] = 'Banner status updated.';
        header('Location: banners-manage.php');
        exit;
    } elseif (isset($_POST['edit_banner'], $_POST['edit_id'])) {
        $editId = (int) $_POST['edit_id'];
        $title = trim($_POST['title'] ?? '');
        $starts = banner_normalize_datetime($_POST['starts_at'] ?? '');
        $ends = banner_normalize_datetime($_POST['ends_at'] ?? '');
        $sort_order = (int) ($_POST['sort_order'] ?? 0);
        $status = ($_POST['status'] ?? 'Active') === 'Inactive' ? 'Inactive' : 'Active';

        if ($title === '') {
            $_SESSION['banner_error'] = 'Title is required.';
            header('Location: banners-manage.php');
            exit;
        } elseif (!preg_match('/^\d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}$/', $starts) || !preg_match('/^\d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}$/', $ends)) {
            $_SESSION['banner_error'] = 'Start and end date/time are invalid. Use the date pickers.';
            header('Location: banners-manage.php');
            exit;
        } elseif (strtotime($ends) <= strtotime($starts)) {
            $_SESSION['banner_error'] = 'End time must be after start time.';
            header('Location: banners-manage.php');
            exit;
        } else {
            // Check if new file uploaded
            if (isset($_FILES['banner_file']) && $_FILES['banner_file']['error'] === UPLOAD_ERR_OK) {
                $ext = strtolower(pathinfo($_FILES['banner_file']['name'], PATHINFO_EXTENSION));
                if (!in_array($ext, $allowedExt, true)) {
                    $_SESSION['banner_error'] = 'File type not allowed. Allowed: ' . implode(', ', $allowedExt);
                    header('Location: banners-manage.php');
                    exit;
                } elseif ($_FILES['banner_file']['size'] > $maxBytes) {
                    $_SESSION['banner_error'] = 'File is too large (max 100 MB).';
                    header('Location: banners-manage.php');
                    exit;
                } else {
                    $dir = __DIR__ . '/uploads/banners/';
                    if (!is_dir($dir)) {
                        mkdir($dir, 0755, true);
                    }
                    $safe = 'banner_' . time() . '_' . bin2hex(random_bytes(4)) . '.' . $ext;
                    $dest = $dir . $safe;
                    if (move_uploaded_file($_FILES['banner_file']['tmp_name'], $dest)) {
                        // Get old file to delete
                        $stmt = $conn->prepare('SELECT file_path FROM banners WHERE id = ?');
                        $stmt->bind_param('i', $editId);
                        $stmt->execute();
                        $res = $stmt->get_result();
                        if ($row = $res->fetch_assoc()) {
                            $fp = __DIR__ . '/' . ltrim($row['file_path'], '/');
                            if (is_file($fp)) {
                                @unlink($fp);
                            }
                        }
                        $stmt->close();

                        $rel = 'uploads/banners/' . $safe;
                        $mime = $_FILES['banner_file']['type'] ?? '';
                        $orig = $_FILES['banner_file']['name'];
                        $upd = $conn->prepare('UPDATE banners SET title=?, file_path=?, original_filename=?, mime_type=?, starts_at=?, ends_at=?, sort_order=?, status=? WHERE id=?');
                        $upd->bind_param('ssssssisi', $title, $rel, $orig, $mime, $starts, $ends, $sort_order, $status, $editId);
                        if ($upd->execute()) {
                            $_SESSION['banner_success'] = 'Banner updated successfully.';
                        } else {
                            $_SESSION['banner_error'] = 'Database error: ' . htmlspecialchars($conn->error);
                            @unlink($dest);
                        }
                        $upd->close();
                        header('Location: banners-manage.php');
                        exit;
                    } else {
                        $_SESSION['banner_error'] = 'Failed to save uploaded file.';
                        header('Location: banners-manage.php');
                        exit;
                    }
                }
            } else {
                // Update without file change
                $upd = $conn->prepare('UPDATE banners SET title=?, starts_at=?, ends_at=?, sort_order=?, status=? WHERE id=?');
                $upd->bind_param('sssisi', $title, $starts, $ends, $sort_order, $status, $editId);
                if ($upd->execute()) {
                    $_SESSION['banner_success'] = 'Banner updated successfully.';
                } else {
                    $_SESSION['banner_error'] = 'Database error: ' . htmlspecialchars($conn->error);
                }
                $upd->close();
                header('Location: banners-manage.php');
                exit;
            }
        }
    }
}

$banners = [];
if ($tableOk) {
    $bq = $conn->query('SELECT * FROM banners ORDER BY sort_order ASC, id DESC');
    if ($bq) {
        while ($row = $bq->fetch_assoc()) {
            $banners[] = $row;
        }
    }
}

include './partials/layouts/layoutTop.php';

$defaultStart = date('Y-m-d\TH:i');
$defaultEnd = date('Y-m-d\TH:i', strtotime('+7 days'));
?>

<div class="dashboard-main-body">
    <div class="d-flex flex-wrap align-items-center justify-content-between gap-3 mb-24">
        <h6 class="fw-semibold mb-0">Banners</h6>
        <ul class="d-flex align-items-center gap-2">
            <li class="fw-medium">
                <a href="index.php" class="d-flex align-items-center gap-1 hover-text-primary">
                    <iconify-icon icon="solar:home-smile-angle-outline" class="icon text-lg"></iconify-icon>
                    Dashboard
                </a>
            </li>
            <li>-</li>
            <li class="fw-medium">Banners</li>
        </ul>
    </div>

    <?php if (!$tableOk): ?>
        <div class="alert alert-warning">
            The <code>banners</code> table is missing. Run the SQL in
            <code>sql/banners_table.sql</code> on your database, then refresh this page.
        </div>
    <?php else: ?>
        <?php if ($success): ?><div class="alert alert-success"><?php echo htmlspecialchars($success); ?></div><?php endif; ?>
        <?php if ($error): ?><div class="alert alert-danger"><?php echo htmlspecialchars($error); ?></div><?php endif; ?>

        <div class="row gy-4">
            <div class="col-xxl-5 col-xl-6">
                <div class="card h-100 p-0 radius-12">
                    <div class="card-header border-bottom py-16 px-24">
                        <span class="fw-semibold">Add banner</span>
                        <p class="text-secondary-light text-sm mb-0 mt-4">Upload image, video, audio, or other file; set title and the exact window when it should appear (countdown uses end time).</p>
                    </div>
                    <div class="card-body p-24">
                        <form method="post" enctype="multipart/form-data" class="row g-3">
                            <input type="hidden" name="save_banner" value="1">
                            <div class="col-12">
                                <label class="form-label fw-semibold text-primary-light text-sm mb-8">Title</label>
                                <input type="text" name="title" class="form-control radius-8" required maxlength="255"
                                       placeholder="e.g. Easter celebration">
                            </div>
                            <div class="col-12">
                                <label class="form-label fw-semibold text-primary-light text-sm mb-8">Media file</label>
                                <input type="file" name="banner_file" class="form-control radius-8" required>
                                <small class="text-muted">Images, GIF, SVG, video (mp4, webm…), audio (mp3, wav…), PDF — max 100 MB</small>
                            </div>
                            <div class="col-md-6">
                                <label class="form-label fw-semibold text-primary-light text-sm mb-8">Show from</label>
                                <input type="datetime-local" name="starts_at" class="form-control radius-8"
                                       value="<?php echo htmlspecialchars($defaultStart); ?>" required>
                            </div>
                            <div class="col-md-6">
                                <label class="form-label fw-semibold text-primary-light text-sm mb-8">Show until</label>
                                <input type="datetime-local" name="ends_at" class="form-control radius-8"
                                       value="<?php echo htmlspecialchars($defaultEnd); ?>" required>
                            </div>
                            <div class="col-md-6">
                                <label class="form-label fw-semibold text-primary-light text-sm mb-8">Sort order</label>
                                <input type="number" name="sort_order" class="form-control radius-8" value="0">
                            </div>
                            <div class="col-md-6">
                                <label class="form-label fw-semibold text-primary-light text-sm mb-8">Status</label>
                                <select name="status" class="form-select radius-8">
                                    <option value="Active">Active</option>
                                    <option value="Inactive">Inactive</option>
                                </select>
                            </div>
                            <div class="col-12">
                                <button type="submit" class="btn btn-primary radius-8">Save banner</button>
                            </div>
                        </form>
                    </div>
                </div>
            </div>
            <div class="col-xxl-7 col-xl-6">
                <div class="card h-100 p-0 radius-12">
                    <div class="card-header border-bottom py-16 px-24">
                        <span class="fw-semibold">Scheduled banners</span>
                    </div>
                    <div class="card-body p-24">
                        <div class="table-responsive">
                            <table class="table bordered-table sm-table mb-0">
                                <thead>
                                    <tr>
                                        <th>Preview</th>
                                        <th>Title</th>
                                        <th>Window</th>
                                        <th>Countdown</th>
                                        <th>Status</th>
                                        <th class="text-center">Actions</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <?php if (empty($banners)): ?>
                                        <tr><td colspan="6" class="text-center text-secondary-light py-32">No banners yet.</td></tr>
                                    <?php else: ?>
                                        <?php foreach ($banners as $b): ?>
                                            <?php
                                            $mime = strtolower((string) ($b['mime_type'] ?? ''));
                                            $ext = strtolower(pathinfo($b['file_path'], PATHINFO_EXTENSION));
                                            $isImg = (strpos($mime, 'image/') === 0) || in_array($ext, ['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg', 'bmp'], true);
                                            $isVid = (strpos($mime, 'video/') === 0) || in_array($ext, ['mp4', 'webm', 'mov', 'avi', 'mkv'], true);
                                            $isAud = (strpos($mime, 'audio/') === 0) || in_array($ext, ['mp3', 'wav', 'ogg', 'm4a', 'aac', 'flac'], true);
                                            ?>
                                            <tr data-end="<?php echo htmlspecialchars(date('c', strtotime($b['ends_at']))); ?>"
                                                data-start="<?php echo htmlspecialchars(date('c', strtotime($b['starts_at']))); ?>">
                                                <td style="width:100px;">
                                                    <?php if ($isImg): ?>
                                                        <img src="<?php echo htmlspecialchars($b['file_path']); ?>" alt="" class="radius-8 w-100" style="max-height:64px;object-fit:cover;">
                                                    <?php elseif ($isVid): ?>
                                                        <video src="<?php echo htmlspecialchars($b['file_path']); ?>" class="w-100 radius-8" muted playsinline style="max-height:64px;"></video>
                                                    <?php elseif ($isAud): ?>
                                                        <audio controls src="<?php echo htmlspecialchars($b['file_path']); ?>" class="w-100" style="max-height:40px;"></audio>
                                                    <?php else: ?>
                                                        <a href="<?php echo htmlspecialchars($b['file_path']); ?>" target="_blank" rel="noopener" class="text-sm">Open file</a>
                                                    <?php endif; ?>
                                                </td>
                                                <td>
                                                    <div class="fw-medium"><?php echo htmlspecialchars($b['title']); ?></div>
                                                    <small class="text-muted text-xs"><?php echo htmlspecialchars($b['original_filename'] ?? ''); ?></small>
                                                </td>
                                                <td>
                                                    <small class="d-block"><?php echo htmlspecialchars($b['starts_at']); ?></small>
                                                    <small class="d-block">→ <?php echo htmlspecialchars($b['ends_at']); ?></small>
                                                </td>
                                                <td><span class="banner-countdown text-sm fw-medium">—</span></td>
                                                <td>
                                                    <?php if ($b['status'] === 'Active'): ?>
                                                        <span class="bg-success-focus text-success-600 border border-success-main px-12 py-4 radius-4 text-sm">Active</span>
                                                    <?php else: ?>
                                                        <span class="bg-neutral-200 text-secondary-light px-12 py-4 radius-4 text-sm">Inactive</span>
                                                    <?php endif; ?>
                                                </td>
                                                <td class="text-center">
                                                    <form method="post" class="d-inline" onsubmit="return confirm('Delete this banner?');">
                                                        <input type="hidden" name="delete_id" value="<?php echo (int) $b['id']; ?>">
                                                        <button type="submit" class="btn btn-sm btn-danger-200 text-danger-600 radius-8">Delete</button>
                                                    </form>
                                                    <button type="button" class="btn btn-sm btn-primary radius-8 ms-8" data-bs-toggle="modal" data-bs-target="#editModal<?php echo $b['id']; ?>">Edit</button>
                                                    <form method="post" class="d-inline ms-8">
                                                        <input type="hidden" name="toggle_id" value="<?php echo (int) $b['id']; ?>">
                                                        <input type="hidden" name="toggle_status" value="<?php echo $b['status'] === 'Active' ? 'Inactive' : 'Active'; ?>">
                                                        <button type="submit" class="btn btn-sm btn-secondary radius-8"><?php echo $b['status'] === 'Active' ? 'Deactivate' : 'Activate'; ?></button>
                                                    </form>
                                                </td>
                                            </tr>
                                            <!-- Edit Modal for banner <?php echo $b['id']; ?> -->
                                            <div class="modal fade" id="editModal<?php echo $b['id']; ?>" tabindex="-1" aria-hidden="true">
                                                <div class="modal-dialog modal-lg">
                                                    <div class="modal-content radius-12">
                                                        <div class="modal-header border-bottom py-16 px-24">
                                                            <h6 class="modal-title fw-semibold">Edit Banner</h6>
                                                            <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                                                        </div>
                                                        <div class="modal-body p-24">
                                                            <form method="post" enctype="multipart/form-data" class="row g-3">
                                                                <input type="hidden" name="edit_banner" value="1">
                                                                <input type="hidden" name="edit_id" value="<?php echo (int) $b['id']; ?>">
                                                                <div class="col-12">
                                                                    <label class="form-label fw-semibold text-primary-light text-sm mb-8">Title</label>
                                                                    <input type="text" name="title" class="form-control radius-8" required maxlength="255" value="<?php echo htmlspecialchars($b['title']); ?>">
                                                                </div>
                                                                <div class="col-12">
                                                                    <label class="form-label fw-semibold text-primary-light text-sm mb-8">Current File</label>
                                                                    <div class="mb-8">
                                                                        <?php if ($isImg): ?>
                                                                            <img src="<?php echo htmlspecialchars($b['file_path']); ?>" alt="" class="radius-8" style="max-height:100px;max-width:200px;object-fit:cover;">
                                                                        <?php elseif ($isVid): ?>
                                                                            <video src="<?php echo htmlspecialchars($b['file_path']); ?>" class="radius-8" muted playsinline style="max-height:100px;max-width:200px;"></video>
                                                                        <?php elseif ($isAud): ?>
                                                                            <audio controls src="<?php echo htmlspecialchars($b['file_path']); ?>" style="max-height:40px;"></audio>
                                                                        <?php else: ?>
                                                                            <a href="<?php echo htmlspecialchars($b['file_path']); ?>" target="_blank" rel="noopener"><?php echo htmlspecialchars($b['original_filename'] ?? 'View file'); ?></a>
                                                                        <?php endif; ?>
                                                                    </div>
                                                                    <label class="form-label fw-semibold text-primary-light text-sm mb-8">Replace Media File (optional)</label>
                                                                    <input type="file" name="banner_file" class="form-control radius-8">
                                                                    <small class="text-muted">Leave empty to keep current file. Allowed: images, video, audio, PDF — max 100 MB</small>
                                                                </div>
                                                                <div class="col-md-6">
                                                                    <label class="form-label fw-semibold text-primary-light text-sm mb-8">Show from</label>
                                                                    <input type="datetime-local" name="starts_at" class="form-control radius-8" required value="<?php echo htmlspecialchars(date('Y-m-d\TH:i', strtotime($b['starts_at']))); ?>">
                                                                </div>
                                                                <div class="col-md-6">
                                                                    <label class="form-label fw-semibold text-primary-light text-sm mb-8">Show until</label>
                                                                    <input type="datetime-local" name="ends_at" class="form-control radius-8" required value="<?php echo htmlspecialchars(date('Y-m-d\TH:i', strtotime($b['ends_at']))); ?>">
                                                                </div>
                                                                <div class="col-md-6">
                                                                    <label class="form-label fw-semibold text-primary-light text-sm mb-8">Sort order</label>
                                                                    <input type="number" name="sort_order" class="form-control radius-8" value="<?php echo (int) $b['sort_order']; ?>">
                                                                </div>
                                                                <div class="col-md-6">
                                                                    <label class="form-label fw-semibold text-primary-light text-sm mb-8">Status</label>
                                                                    <select name="status" class="form-select radius-8">
                                                                        <option value="Active" <?php echo $b['status'] === 'Active' ? 'selected' : ''; ?>>Active</option>
                                                                        <option value="Inactive" <?php echo $b['status'] === 'Inactive' ? 'selected' : ''; ?>>Inactive</option>
                                                                    </select>
                                                                </div>
                                                                <div class="col-12">
                                                                    <button type="submit" class="btn btn-primary radius-8">Update banner</button>
                                                                    <button type="button" class="btn btn-secondary radius-8 ms-8" data-bs-dismiss="modal">Cancel</button>
                                                                </div>
                                                            </form>
                                                        </div>
                                                    </div>
                                                </div>
                                            </div>
                                        <?php endforeach; ?>
                                    <?php endif; ?>
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    <?php endif; ?>
</div>

<script>
(function () {
    function fmt(ms) {
        if (ms <= 0) return 'Ended';
        var s = Math.floor(ms / 1000);
        var d = Math.floor(s / 86400);
        s -= d * 86400;
        var h = Math.floor(s / 3600);
        s -= h * 3600;
        var m = Math.floor(s / 60);
        var parts = [];
        if (d) parts.push(d + 'd');
        if (h || d) parts.push(h + 'h');
        parts.push(m + 'm');
        return parts.join(' ') + ' left';
    }
    function fmtStart(ms) {
        if (ms <= 0) return 'Started';
        var s = Math.floor(ms / 1000);
        var d = Math.floor(s / 86400);
        s -= d * 86400;
        var h = Math.floor(s / 3600);
        s -= h * 3600;
        var m = Math.floor(s / 60);
        var parts = [];
        if (d) parts.push(d + 'd');
        if (h || d) parts.push(h + 'h');
        parts.push(m + 'm');
        return 'Starts in ' + parts.join(' ');
    }
    function tick() {
        var now = Date.now();
        document.querySelectorAll('tr[data-end]').forEach(function (tr) {
            var end = Date.parse(tr.getAttribute('data-end'));
            var start = Date.parse(tr.getAttribute('data-start'));
            var el = tr.querySelector('.banner-countdown');
            if (!el || isNaN(end) || isNaN(start)) return;
            if (now < start) {
                el.textContent = fmtStart(start - now);
            } else if (now <= end) {
                el.textContent = fmt(end - now);
            } else {
                el.textContent = 'Ended';
                el.classList.add('text-secondary-light');
            }
        });
    }
    tick();
    setInterval(tick, 30000);
})();
</script>

<?php include './partials/layouts/layoutBottom.php'; ?>
