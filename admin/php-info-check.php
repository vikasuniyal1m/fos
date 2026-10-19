<?php
include './includes/db.php';
include './partials/layouts/layoutTop.php';
?>

<div class="dashboard-main-body">
    <div class="d-flex flex-wrap align-items-center justify-content-between gap-3 mb-24">
        <h6 class="fw-semibold mb-0">PHP Upload Configuration Check</h6>
    </div>

    <div class="card">
        <div class="card-body">
            <h6 class="text-danger">Critical Upload Settings:</h6>
            <table class="table table-bordered">
                <tr>
                    <td><strong>file_uploads</strong></td>
                    <td><?php echo ini_get('file_uploads'); ?></td>
                    <td><?php echo ini_get('file_uploads') ? '✅ OK' : '❌ DISABLED - This is the problem!'; ?></td>
                </tr>
                <tr>
                    <td><strong>upload_max_filesize</strong></td>
                    <td><?php echo ini_get('upload_max_filesize'); ?></td>
                    <td><?php echo (intval(ini_get('upload_max_filesize')) >= 2) ? '✅ OK' : '❌ Too small'; ?></td>
                </tr>
                <tr>
                    <td><strong>post_max_size</strong></td>
                    <td><?php echo ini_get('post_max_size'); ?></td>
                    <td><?php echo (intval(ini_get('post_max_size')) >= 8) ? '✅ OK' : '❌ Too small'; ?></td>
                </tr>
                <tr>
                    <td><strong>max_file_uploads</strong></td>
                    <td><?php echo ini_get('max_file_uploads'); ?></td>
                    <td><?php echo (ini_get('max_file_uploads') >= 20) ? '✅ OK' : '⚠️ Low'; ?></td>
                </tr>
                <tr>
                    <td><strong>upload_tmp_dir</strong></td>
                    <td><?php echo ini_get('upload_tmp_dir') ?: 'Not set (using system default)'; ?></td>
                    <td><?php echo is_writable(ini_get('upload_tmp_dir') ?: sys_get_temp_dir()) ? '✅ Writable' : '❌ Not writable'; ?></td>
                </tr>
            </table>

            <h6 class="mt-4">Test Direct File Upload:</h6>
            <form method="POST" enctype="multipart/form-data">
                <div class="mb-3">
                    <input type="file" name="test_file" class="form-control" required>
                </div>
                <button type="submit" class="btn btn-primary">Test File Upload</button>
            </form>

            <?php
            if ($_SERVER['REQUEST_METHOD'] === 'POST') {
                echo "<div class='mt-4 p-3 border rounded'>";
                echo "<h6>Upload Test Results:</h6>";
                
                echo "<p><strong>Content-Type:</strong> " . ($_SERVER['CONTENT_TYPE'] ?? 'Not set') . "</p>";
                echo "<p><strong>POST data count:</strong> " . count($_POST) . "</p>";
                echo "<p><strong>FILES data count:</strong> " . count($_FILES) . "</p>";
                
                if (empty($_FILES)) {
                    echo "<p class='text-danger'><strong>❌ CRITICAL: \$_FILES array is completely empty!</strong></p>";
                    echo "<p>This means PHP file uploads are disabled on your server.</p>";
                } else {
                    echo "<pre>FILES data: " . print_r($_FILES, true) . "</pre>";
                }
                
                echo "</div>";
            }
            ?>

            <div class="mt-4 alert alert-info">
                <h6>Solution:</h6>
                <p>If <strong>file_uploads</strong> is Off, you need to:</p>
                <ol>
                    <li>Contact your hosting provider to enable file uploads</li>
                    <li>Or create a <code>.user.ini</code> or <code>php.ini</code> file in your root directory with:
                        <pre class="mt-2">file_uploads = On
upload_max_filesize = 10M
post_max_size = 10M
max_file_uploads = 20</pre>
                    </li>
                </ol>
            </div>
        </div>
    </div>
</div>

<?php include './partials/layouts/layoutBottom.php'; ?>