<?php
include './includes/db.php';
include './partials/layouts/layoutTop.php';

$lang = $_GET['lang'] ?? 'en';

// Handle translation updates
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $key = $conn->real_escape_string($_POST['key']);
    $value = $conn->real_escape_string($_POST['value']);
    
    $sql = "INSERT INTO translations (language_code, translation_key, translation_value) 
            VALUES ('$lang', '$key', '$value')
            ON DUPLICATE KEY UPDATE translation_value = '$value'";
    
    if ($conn->query($sql)) {
        $success = "Translation updated successfully!";
    } else {
        $error = "Error: " . $conn->error;
    }
}

// Get translations for selected language
$translations = $conn->query("
    SELECT * FROM translations 
    WHERE language_code = '$lang' 
    ORDER BY translation_key
");
?>

<div class="dashboard-main-body">
    <div class="d-flex flex-wrap align-items-center justify-content-between gap-3 mb-24">
        <h6 class="fw-semibold mb-0">Translations Management</h6>
        <ul class="d-flex align-items-center gap-2">
            <li class="fw-medium">
                <a href="languages-list.php" class="d-flex align-items-center gap-1 hover-text-primary">
                    <iconify-icon icon="solar:home-smile-angle-outline" class="icon text-lg"></iconify-icon>
                    Languages
                </a>
            </li>
            <li>-</li>
            <li class="fw-medium">Translations</li>
        </ul>
    </div>

    <?php if (isset($error)): ?>
        <div class="alert alert-danger"><?php echo $error; ?></div>
    <?php endif; ?>
    <?php if (isset($success)): ?>
        <div class="alert alert-success"><?php echo $success; ?></div>
    <?php endif; ?>

    <div class="card h-100 p-0 radius-12">
        <div class="card-header border-bottom bg-base py-16 px-24 d-flex align-items-center flex-wrap gap-3 justify-content-between">
            <div class="d-flex align-items-center flex-wrap gap-3">
                <span class="text-md fw-medium text-secondary-light mb-0">Language:</span>
                <select id="language-select" class="form-select form-select-sm w-auto ps-12 py-6 radius-12 h-40-px">
                    <?php
                    $languages = $conn->query("SELECT * FROM languages ORDER BY name");
                    while ($language = $languages->fetch_assoc()): ?>
                        <option value="<?php echo $language['code']; ?>" <?php echo $lang == $language['code'] ? 'selected' : ''; ?>>
                            <?php echo htmlspecialchars($language['name']); ?>
                        </option>
                    <?php endwhile; ?>
                </select>
            </div>
            <button type="button" class="btn btn-primary text-sm btn-sm px-12 py-12 radius-8 d-flex align-items-center gap-2" data-bs-toggle="modal" data-bs-target="#addTranslationModal">
                <iconify-icon icon="ic:baseline-plus" class="icon text-xl line-height-1"></iconify-icon>
                Add Translation
            </button>
        </div>

        <div class="card-body p-24">
            <div class="table-responsive scroll-sm">
                <table class="table bordered-table sm-table mb-0">
                    <thead>
                        <tr>
                            <th>Key</th>
                            <th>Translation</th>
                            <th class="text-center">Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php if ($translations->num_rows > 0): ?>
                            <?php while ($translation = $translations->fetch_assoc()): ?>
                                <tr>
                                    <td><code><?php echo htmlspecialchars($translation['translation_key']); ?></code></td>
                                    <td><?php echo htmlspecialchars($translation['translation_value']); ?></td>
                                    <td class="text-center">
                                        <div class="d-flex align-items-center gap-10 justify-content-center">
                                            <button type="button" class="edit-translation bg-primary-focus bg-hover-primary-200 text-primary-600 fw-medium w-40-px h-40-px d-flex justify-content-center align-items-center rounded-circle"
                                                    data-key="<?php echo $translation['translation_key']; ?>"
                                                    data-value="<?php echo htmlspecialchars($translation['translation_value']); ?>">
                                                <iconify-icon icon="mdi:pencil-outline" class="icon text-xl"></iconify-icon>
                                            </button>
                                        </div>
                                    </td>
                                </tr>
                            <?php endwhile; ?>
                        <?php else: ?>
                            <tr>
                                <td colspan="3" class="text-center">No translations found for this language.</td>
                            </tr>
                        <?php endif; ?>
                    </tbody>
                </table>
            </div>
        </div>
    </div>
</div>

<!-- Add Translation Modal -->
<div class="modal fade" id="addTranslationModal" tabindex="-1">
    <div class="modal-dialog">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title">Add Translation</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
            </div>
            <div class="modal-body">
                <form method="POST" id="translationForm">
                    <div class="mb-3">
                        <label class="form-label">Key</label>
                        <input type="text" class="form-control" name="key" required>
                    </div>
                    <div class="mb-3">
                        <label class="form-label">Translation</label>
                        <textarea class="form-control" name="value" rows="3" required></textarea>
                    </div>
                </form>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                <button type="submit" form="translationForm" class="btn btn-primary">Save Translation</button>
            </div>
        </div>
    </div>
</div>

<script>
$(document).ready(function() {
    // Language selector
    $("#language-select").on("change", function() {
        window.location.href = "translations.php?lang=" + $(this).val();
    });

    // Edit translation
    $(document).on("click", ".edit-translation", function() {
        var key = $(this).data('key');
        var value = $(this).data('value');
        
        $("input[name='key']").val(key).prop('readonly', true);
        $("textarea[name='value']").val(value);
        
        $("#addTranslationModal .modal-title").text("Edit Translation");
        $("#addTranslationModal").modal('show');
    });

    // Reset form when modal is hidden
    $("#addTranslationModal").on('hidden.bs.modal', function() {
        $("input[name='key']").val('').prop('readonly', false);
        $("textarea[name='value']").val('');
        $("#addTranslationModal .modal-title").text("Add Translation");
    });
});
</script>

<?php include './partials/layouts/layoutBottom.php'; ?>