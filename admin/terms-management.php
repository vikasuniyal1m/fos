<?php
include './includes/db.php';
include './includes/admin-auth.php';
include './partials/layouts/layoutTop.php';

// Fetch current terms
$current_terms = null;
$result = $conn->query("SELECT content, version, updated_at FROM terms_conditions ORDER BY id DESC LIMIT 1");
if ($result->num_rows > 0) {
    $current_terms = $result->fetch_assoc();
    // Fix the content by replacing rn with actual line breaks
    if ($current_terms['content']) {
        $current_terms['content'] = str_replace(['rn', '\r\n', '\n'], "\n", $current_terms['content']);
    }
}

// Handle form submission
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $content = $_POST['content']; // Get raw content
    $version = $conn->real_escape_string($_POST['version']);
    
    // Check if terms already exist
    $check = $conn->query("SELECT id FROM terms_conditions ORDER BY id DESC LIMIT 1");
    
    if ($check->num_rows > 0) {
        // Update existing terms
        $existing = $check->fetch_assoc();
        $stmt = $conn->prepare("UPDATE terms_conditions SET content = ?, version = ?, updated_at = NOW() WHERE id = ?");
        $stmt->bind_param("ssi", $content, $version, $existing['id']);
    } else {
        // Insert new terms
        $stmt = $conn->prepare("INSERT INTO terms_conditions (content, version) VALUES (?, ?)");
        $stmt->bind_param("ss", $content, $version);
    }
    
    if ($stmt->execute()) {
        $success = "Terms & Conditions updated successfully!";
        // Refresh current terms
        $result = $conn->query("SELECT content, version, updated_at FROM terms_conditions ORDER BY id DESC LIMIT 1");
        if ($result->num_rows > 0) {
            $current_terms = $result->fetch_assoc();
            $current_terms['content'] = str_replace(['rn', '\r\n', '\n'], "\n", $current_terms['content']);
        }
    } else {
        $error = "Error updating terms: " . $stmt->error;
    }
}
?>

<div class="dashboard-main-body">
    <div class="d-flex flex-wrap align-items-center justify-content-between gap-3 mb-24">
        <div>
            <h6 class="fw-semibold mb-1">Terms & Conditions Management</h6>
            <p class="text-muted mb-0">Manage your application's legal terms and conditions</p>
        </div>
        <ul class="d-flex align-items-center gap-2">
            <li class="fw-medium">
                <a href="index.php" class="d-flex align-items-center gap-1 hover-text-primary">
                    <iconify-icon icon="solar:home-smile-angle-outline" class="icon text-lg"></iconify-icon>
                    Dashboard
                </a>
            </li>
            <li>-</li>
            <li class="fw-medium">System Settings</li>
            <li>-</li>
            <li class="fw-medium">Terms & Conditions</li>
        </ul>
    </div>

    <?php if (isset($error)): ?>
        <div class="alert alert-danger d-flex align-items-center gap-2">
            <iconify-icon icon="mdi:alert-circle" class="icon-lg"></iconify-icon>
            <?php echo $error; ?>
        </div>
    <?php endif; ?>
    
    <?php if (isset($success)): ?>
        <div class="alert alert-success d-flex align-items-center gap-2">
            <iconify-icon icon="mdi:check-circle" class="icon-lg"></iconify-icon>
            <?php echo $success; ?>
        </div>
    <?php endif; ?>

    <div class="row">
        <!-- Edit Form -->
        <div class="col-lg-8">
            <div class="card border-0 shadow-sm">
                <div class="card-header bg-dark text-white py-16 px-24">
                    <div class="d-flex align-items-center justify-content-between">
                        <div>
                            <h6 class="fw-semibold mb-1 text-white">Edit Terms & Conditions</h6>
                            <p class="text-light mb-0 opacity-75">Update your application's legal documentation</p>
                        </div>
                        <div class="bg-white bg-opacity-20 p-8 rounded-circle">
                            <iconify-icon icon="mdi:file-document-edit" class="text-white icon-lg"></iconify-icon>
                        </div>
                    </div>
                </div>
                <div class="card-body p-24 bg-white">
                    <form method="POST" id="termsForm">
                        <div class="row">
                            <div class="col-md-6">
                                <div class="mb-20">
                                    <label class="form-label fw-semibold text-dark text-sm mb-8">
                                        Version <span class="text-danger">*</span>
                                    </label>
                                    <div class="input-group">
                                        <span class="input-group-text bg-light border-gray-300">
                                            <iconify-icon icon="mdi:tag" class="text-dark"></iconify-icon>
                                        </span>
                                        <input type="text" class="form-control border-gray-300" name="version" 
                                               value="<?php echo $current_terms['version'] ?? '1.0'; ?>" 
                                               placeholder="e.g., 1.0, 1.1, 2.0" required>
                                    </div>
                                    <div class="form-text text-muted">
                                        Use semantic versioning for better tracking
                                    </div>
                                </div>
                            </div>
                            <div class="col-md-6">
                                <div class="mb-20">
                                    <label class="form-label fw-semibold text-dark text-sm mb-8">
                                        Last Updated
                                    </label>
                                    <div class="input-group">
                                        <span class="input-group-text bg-light border-gray-300">
                                            <iconify-icon icon="mdi:calendar-clock" class="text-dark"></iconify-icon>
                                        </span>
                                        <input type="text" class="form-control border-gray-300 bg-light" 
                                               value="<?php echo $current_terms ? date('M j, Y g:i A', strtotime($current_terms['updated_at'])) : 'Never updated'; ?>" 
                                               readonly>
                                    </div>
                                </div>
                            </div>
                        </div>

                        <div class="mb-20">
                            <div class="d-flex align-items-center justify-content-between mb-8">
                                <label class="form-label fw-semibold text-dark text-sm mb-0">
                                    Terms & Conditions Content <span class="text-danger">*</span>
                                </label>
                                <div class="text-end">
                                    <small class="text-muted">
                                        Characters: <span id="charCount" class="fw-bold">0</span>
                                    </small>
                                </div>
                            </div>
                            <div class="editor-container border border-gray-300 rounded-8">
                                <textarea class="form-control border-0" name="content" id="termsContent" rows="15" 
                                          placeholder="Enter your terms and conditions content here...
                                          
Use numbered sections for organization:
1. Section Title
   - Bullet points
   - More details

Use clear, simple language that users can easily understand..." required><?php echo isset($current_terms['content']) ? htmlspecialchars($current_terms['content']) : ''; ?></textarea>
                            </div>
                            <div class="form-text text-muted mt-8">
                                <iconify-icon icon="mdi:information" class="me-1"></iconify-icon>
                                Use numbered sections and bullet points for better readability
                            </div>
                        </div>

                        <div class="d-flex align-items-center justify-content-between gap-3 pt-20 border-top">
                            <div class="d-flex gap-2">
                                <button type="button" class="btn btn-outline-dark btn-sm d-flex align-items-center gap-2" onclick="previewTerms()">
                                    <iconify-icon icon="mdi:eye-outline"></iconify-icon>
                                    Preview
                                </button>
                                <button type="button" class="btn btn-outline-secondary btn-sm d-flex align-items-center gap-2" onclick="insertDefaultTemplate()">
                                    <iconify-icon icon="mdi:file-restore"></iconify-icon>
                                    Use Template
                                </button>
                            </div>
                            <div class="d-flex align-items-center gap-3">
                                <a href="system-settings.php" class="btn btn-outline-dark px-40 py-10 d-flex align-items-center gap-2">
                                    <iconify-icon icon="mdi:close"></iconify-icon>
                                    Cancel
                                </a>
                                <button type="submit" class="btn btn-dark px-40 py-10 d-flex align-items-center gap-2">
                                    <iconify-icon icon="mdi:content-save-check"></iconify-icon>
                                    Update Terms
                                </button>
                            </div>
                        </div>
                    </form>
                </div>
            </div>
        </div>

        <!-- Preview & Information -->
        <div class="col-lg-4">
            <!-- Current Version Info -->
            <div class="card border-0 shadow-sm mb-24">
                <div class="card-header bg-gray-800 text-white py-12 px-20">
                    <h6 class="fw-semibold mb-0 text-white">Current Version</h6>
                </div>
                <div class="card-body p-20 bg-white">
                    <div class="text-center mb-16">
                        <div class="bg-gray-100 p-12 rounded-12 d-inline-block">
                            <iconify-icon icon="mdi:file-document-check" class="icon-xl text-dark"></iconify-icon>
                        </div>
                    </div>
                    <div class="space-y-12">
                        <div class="d-flex justify-content-between align-items-center">
                            <span class="text-muted">Version:</span>
                            <span class="fw-semibold text-dark"><?php echo $current_terms['version'] ?? '1.0'; ?></span>
                        </div>
                        <div class="d-flex justify-content-between align-items-center">
                            <span class="text-muted">Last Updated:</span>
                            <span class="fw-medium text-dark"><?php echo $current_terms ? date('M j, Y', strtotime($current_terms['updated_at'])) : 'Never'; ?></span>
                        </div>
                        <div class="d-flex justify-content-between align-items-center">
                            <span class="text-muted">Status:</span>
                            <span class="badge bg-success text-white border-0">Active</span>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Quick Tips -->
            <div class="card border-0 shadow-sm mb-24">
                <div class="card-header bg-gray-800 text-white py-12 px-20">
                    <h6 class="fw-semibold mb-0 text-white">Writing Guidelines</h6>
                </div>
                <div class="card-body p-20 bg-white">
                    <div class="space-y-12">
                        <div class="d-flex align-items-start gap-3">
                            <div class="bg-gray-100 p-6 rounded-8 mt-1">
                                <iconify-icon icon="mdi:format-list-numbered" class="text-dark"></iconify-icon>
                            </div>
                            <div>
                                <small class="fw-semibold d-block text-dark">Structured Sections</small>
                                <small class="text-muted">Use numbered sections with clear headings</small>
                            </div>
                        </div>
                        <div class="d-flex align-items-start gap-3">
                            <div class="bg-gray-100 p-6 rounded-8 mt-1">
                                <iconify-icon icon="mdi:text-short" class="text-dark"></iconify-icon>
                            </div>
                            <div>
                                <small class="fw-semibold d-block text-dark">Clear Language</small>
                                <small class="text-muted">Avoid legal jargon, use plain English</small>
                            </div>
                        </div>
                        <div class="d-flex align-items-start gap-3">
                            <div class="bg-gray-100 p-6 rounded-8 mt-1">
                                <iconify-icon icon="mdi:shield-account" class="text-dark"></iconify-icon>
                            </div>
                            <div>
                                <small class="fw-semibold d-block text-dark">Legal Compliance</small>
                                <small class="text-muted">Ensure compliance with regulations</small>
                            </div>
                        </div>
                        <div class="d-flex align-items-start gap-3">
                            <div class="bg-gray-100 p-6 rounded-8 mt-1">
                                <iconify-icon icon="mdi:update" class="text-dark"></iconify-icon>
                            </div>
                            <div>
                                <small class="fw-semibold d-block text-dark">Regular Updates</small>
                                <small class="text-muted">Review and update terms regularly</small>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Quick Actions -->
            <div class="card border-0 shadow-sm">
                <div class="card-header bg-gray-800 text-white py-12 px-20">
                    <h6 class="fw-semibold mb-0 text-white">Quick Actions</h6>
                </div>
                <div class="card-body p-20 bg-white">
                    <div class="d-grid gap-10">
                        <a href="../api/terms.php" target="_blank" class="btn btn-outline-dark btn-sm d-flex align-items-center gap-2 justify-content-center">
                            <iconify-icon icon="mdi:api"></iconify-icon>
                            View API Response
                        </a>
                        <button type="button" class="btn btn-outline-dark btn-sm d-flex align-items-center gap-2 justify-content-center" onclick="clearContent()">
                            <iconify-icon icon="mdi:format-clear"></iconify-icon>
                            Clear Content
                        </button>
                    </div>
                </div>
            </div>
        </div>
    </div>
</div>

<!-- Preview Modal -->
<div class="modal fade" id="previewModal" tabindex="-1">
    <div class="modal-dialog modal-lg">
        <div class="modal-content border-0 shadow-lg">
            <div class="modal-header bg-dark text-white py-16 px-24">
                <h5 class="modal-title fw-semibold mb-0 text-white">Terms & Conditions Preview</h5>
                <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>
            </div>
            <div class="modal-body p-0">
                <div class="preview-content p-24 bg-white" style="max-height: 60vh; overflow-y: auto;">
                    <div id="previewContent">
                        <!-- Preview content will be inserted here -->
                    </div>
                </div>
            </div>
            <div class="modal-footer bg-light py-16 px-24">
                <button type="button" class="btn btn-dark" data-bs-dismiss="modal">Close Preview</button>
            </div>
        </div>
    </div>
</div>

<?php include './partials/layouts/layoutBottom.php'; ?>

<script>
document.addEventListener('DOMContentLoaded', function() {
    const contentTextarea = document.getElementById('termsContent');
    const charCount = document.getElementById('charCount');
    
    // Update character count
    function updateCharCount() {
        const count = contentTextarea.value.length;
        charCount.textContent = count.toLocaleString();
        
        if (count > 10000) {
            charCount.classList.add('text-warning');
        } else {
            charCount.classList.remove('text-warning');
        }
    }
    
    contentTextarea.addEventListener('input', updateCharCount);
    updateCharCount(); // Initial count
    
    // Form validation
    document.getElementById('termsForm').addEventListener('submit', function(e) {
        const content = contentTextarea.value.trim();
        const version = document.querySelector('input[name="version"]').value.trim();
        
        if (!version) {
            e.preventDefault();
            showAlert('Please enter a version number.', 'error');
            return;
        }
        
        if (!content) {
            e.preventDefault();
            showAlert('Please enter terms and conditions content.', 'error');
            return;
        }
        
        if (content.length < 50) {
            e.preventDefault();
            showAlert('Terms content seems too short. Please provide more detailed terms.', 'warning');
            return;
        }
    });
});

function previewTerms() {
    const content = document.getElementById('termsContent').value;
    const previewContent = document.getElementById('previewContent');
    
    if (!content.trim()) {
        showAlert('Please enter some content to preview.', 'warning');
        return;
    }
    
    // Clean the content first
    let cleanedContent = content
        .replace(/rn/g, '\n')
        .replace(/\\r\\n/g, '\n')
        .replace(/\\n/g, '\n');
    
    // Get the first line for intro (but don't include it in main content)
    const firstLine = cleanedContent.split('\n')[0];
    
    // Remove the first line from the main content to avoid duplication
    const mainContent = cleanedContent.split('\n').slice(1).join('\n');
    
    // Now format the main content line by line
    let formattedContent = mainContent
        .split('\n')
        .map(line => {
            line = line.trim();
            
            if (!line) return '<div class="mb-8"></div>';
            
            // Handle numbered sections
            if (/^\d+\.\s+.+/.test(line)) {
                return `<div class="section-title mb-12 pt-4">
                    <h6 class="fw-semibold text-dark mb-2">${line}</h6>
                </div>`;
            }
            
            // Handle bullet points
            if (/^\s*-\s+.+/.test(line)) {
                return `<div class="bullet-point mb-2 ms-3 ps-2">
                    <span class="text-dark me-2">•</span>
                    <span class="text-dark" style="font-size: 0.9rem;">${line.replace(/^\s*-\s*/, '')}</span>
                </div>`;
            }
            
            // Handle regular paragraphs
            return `<div class="paragraph mb-3">
                <p class="text-dark mb-0" style="font-size: 0.9rem; line-height: 1.5;">${line}</p>
            </div>`;
        })
        .join('');
    
    // Handle the last updated section
    formattedContent = formattedContent.replace(/(Last Updated:.*)/, 
        `<div class="last-updated mt-4 pt-3 border-top">
            <div class="bg-light p-3 rounded">
                <p class="text-dark fw-medium mb-0" style="font-size: 0.85rem;">$1</p>
            </div>
        </div>`
    );
    
    previewContent.innerHTML = `
        <div class="terms-preview" style="font-family: 'Inter', Arial, sans-serif;">
            <div class="text-center mb-4 border-bottom pb-3">
                <h5 class="fw-semibold text-dark mb-2">Terms & Conditions</h5>
                <p class="text-muted mb-0" style="font-size: 0.9rem;">Please read these terms carefully before using our application</p>
            </div>
            <div class="intro-text mb-3">
                <p class="text-dark mb-0" style="font-size: 0.9rem; line-height: 1.5;">${firstLine}</p>
            </div>
            <div class="terms-content">
                ${formattedContent}
            </div>
        </div>
    `;
    
    const previewModal = new bootstrap.Modal(document.getElementById('previewModal'));
    previewModal.show();
}

function insertDefaultTemplate() {
    if (confirm('This will replace your current content with a default template. Continue?')) {
        const defaultTemplate = `By using this application, you agree to the following terms and conditions:

1. Acceptance of Terms
   - By accessing and using this application, you accept and agree to be bound by these terms and conditions.

2. User Conduct
   - You agree to use this application in a respectful and appropriate manner.
   - You will not post inappropriate, offensive, or harmful content.
   - You will respect other users' privacy and rights.

3. Content Guidelines
   - All content must be appropriate and aligned with the spiritual purpose of this application.
   - Content that is offensive, discriminatory, or violates any laws is prohibited.

4. Privacy
   - Your personal information will be handled according to our Privacy Policy.
   - We respect your privacy and will not share your information without consent.

5. Account Responsibility
   - You are responsible for maintaining the confidentiality of your account.
   - You are responsible for all activities that occur under your account.

6. Intellectual Property
   - All content in this application is protected by copyright and other intellectual property laws.
   - You may not reproduce, distribute, or create derivative works without permission.

7. Modifications
   - We reserve the right to modify these terms at any time.
   - Continued use of the application after changes constitutes acceptance of new terms.

8. Termination
   - We reserve the right to terminate or suspend accounts that violate these terms.

9. Disclaimer
   - This application is provided "as is" without warranties of any kind.
   - We are not responsible for any damages resulting from use of this application.

10. Contact
    - For questions about these terms, please contact our support team.

Last Updated: ${new Date().toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' })}`;

        document.getElementById('termsContent').value = defaultTemplate;
        document.querySelector('input[name="version"]').value = '1.1';
        
        document.getElementById('termsContent').dispatchEvent(new Event('input'));
        showAlert('Default template inserted successfully!', 'success');
    }
}

function clearContent() {
    if (confirm('Are you sure you want to clear all content?')) {
        document.getElementById('termsContent').value = '';
        document.getElementById('termsContent').dispatchEvent(new Event('input'));
        showAlert('Content cleared successfully!', 'info');
    }
}

function showAlert(message, type = 'info') {
    const alert = document.createElement('div');
    alert.className = `alert alert-${type === 'error' ? 'danger' : type === 'warning' ? 'warning' : 'success'} alert-dismissible fade show position-fixed`;
    alert.style.cssText = 'top: 20px; right: 20px; z-index: 9999; min-width: 300px;';
    alert.innerHTML = `
        <div class="d-flex align-items-center gap-2">
            <iconify-icon icon="mdi:${type === 'error' ? 'alert-circle' : type === 'warning' ? 'alert' : 'check-circle'}"></iconify-icon>
            ${message}
        </div>
        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    `;
    document.body.appendChild(alert);
    
    setTimeout(() => {
        if (alert.parentNode) {
            alert.remove();
        }
    }, 5000);
}
</script>

<style>
.editor-container textarea {
    font-family: 'Inter', 'Segoe UI', sans-serif;
    font-size: 0.9rem;
    line-height: 1.5;
    white-space: pre-wrap;
    resize: vertical;
    min-height: 400px;
}

.preview-content {
    font-family: 'Inter', Arial, sans-serif;
    line-height: 1.5;
    color: #374151;
    font-size: 0.9rem;
}

.section-title h6 {
    color: #1f2937;
    font-size: 1rem;
    font-weight: 600;
}

.bullet-point {
    display: flex;
    align-items: flex-start;
}

.paragraph p {
    line-height: 1.5;
}

.last-updated {
    border-color: #e5e7eb !important;
}

.card {
    border: 1px solid #e5e7eb;
}

.bg-light {
    background-color: #f8f9fa !important;
}

.bg-gray-800 {
    background-color: #1f2937 !important;
}

.bg-gray-100 {
    background-color: #f3f4f6 !important;
}

.border-gray-300 {
    border-color: #d1d5db !important;
}

.space-y-12 > * + * {
    margin-top: 12px;
}

.mb-8 {
    margin-bottom: 8px;
}

.mb-12 {
    margin-bottom: 12px;
}

.ms-3 {
    margin-left: 12px;
}

.ps-2 {
    padding-left: 8px;
}

.pt-4 {
    padding-top: 16px;
}

.p-6 {
    padding: 6px;
}

.p-12 {
    padding: 12px;
}

.rounded-8 {
    border-radius: 8px;
}

.icon-xl {
    font-size: 2rem;
}

.shadow-sm {
    box-shadow: 0 1px 3px 0 rgba(0, 0, 0, 0.1), 0 1px 2px 0 rgba(0, 0, 0, 0.06) !important;
}

.shadow-lg {
    box-shadow: 0 10px 25px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05) !important;
}

/* Custom scrollbar */
.preview-content::-webkit-scrollbar {
    width: 6px;
}

.preview-content::-webkit-scrollbar-track {
    background: #f1f5f9;
    border-radius: 3px;
}

.preview-content::-webkit-scrollbar-thumb {
    background: #cbd5e1;
    border-radius: 3px;
}

.preview-content::-webkit-scrollbar-thumb:hover {
    background: #94a3b8;
}
</style>