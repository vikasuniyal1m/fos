<?php
include './includes/db.php';
include './partials/layouts/layoutTop.php';

$current_user_id = $_SESSION['user_id'] ?? 0; // Assuming user_id is stored in session

$group_id = isset($_GET['id']) ? intval($_GET['id']) : 0;

// Get group details
$group_stmt = $conn->prepare("
    SELECT g.*, u.name as created_by_name 
    FROM `groups` g 
    LEFT JOIN users u ON g.created_by = u.id 
    WHERE g.id = ?
");
$group_stmt->bind_param("i", $group_id);
$group_stmt->execute();
$group_result = $group_stmt->get_result();
$group = $group_result->fetch_assoc();

if (!$group) {
    die("Group not found");
}

// Check if current admin is a moderator or super admin
$is_moderator = false;
$admin_id = $_SESSION['admin_id'] ?? 0;

$admin_check = $conn->query("SELECT id FROM admin_users WHERE id = $admin_id");
if ($admin_check->num_rows > 0) {
    $is_moderator = true;
}

// Get group statistics
$stats_stmt = $conn->prepare("
    SELECT 
        COUNT(*) as total_messages,
        COUNT(CASE WHEN status = 'active' THEN 1 END) as active_messages,
        COUNT(CASE WHEN status = 'blocked' THEN 1 END) as blocked_messages,
        COUNT(DISTINCT user_id) as active_users,
        MAX(created_at) as last_activity
    FROM group_chat_messages 
    WHERE group_id = ? AND status != 'deleted'
");
$stats_stmt->bind_param("i", $group_id);
$stats_stmt->execute();
$stats_result = $stats_stmt->get_result();
$stats = $stats_result->fetch_assoc();

// Get group chat messages with pagination
$page = isset($_GET['page']) ? max(1, intval($_GET['page'])) : 1;
$limit = 50;
$offset = ($page - 1) * $limit;

$messages_stmt = $conn->prepare("
    SELECT m.*, u.name as user_name, u.profile_photo,
           a.name as blocked_by_name
    FROM group_chat_messages m
    LEFT JOIN users u ON m.user_id = u.id
    LEFT JOIN admin_users a ON m.blocked_by = a.id
    WHERE m.group_id = ? AND m.status != 'deleted'
    ORDER BY m.created_at DESC
    LIMIT ? OFFSET ?
");
$messages_stmt->bind_param("iii", $group_id, $limit, $offset);
$messages_stmt->execute();
$messages_result = $messages_stmt->get_result();
?>

<div class="dashboard-main-body">
    <!-- Header Section -->
    <div class="d-flex flex-wrap align-items-center justify-content-between gap-3 mb-24">
        <div>
            <h6 class="fw-semibold mb-1">Group Chat Monitor</h6>
            <p class="text-muted mb-0">Monitor and moderate group conversations</p>
        </div>
        <ul class="d-flex align-items-center gap-2">
            <li class="fw-medium">
                <a href="index.php" class="d-flex align-items-center gap-1 hover-text-primary">
                    <iconify-icon icon="solar:home-smile-angle-outline" class="icon text-lg"></iconify-icon>
                    Dashboard
                </a>
            </li>
            <li>-</li>
            <li class="fw-medium">
                <a href="groups.php" class="hover-text-primary">Groups</a>
            </li>
            <li>-</li>
            <li class="fw-medium">Chat Monitor</li>
        </ul>
    </div>

    <div class="row">
        <!-- Statistics Cards -->
        <div class="col-12 mb-24">
            <div class="row g-3">
                <div class="col-md-3 col-6">
                    <div class="card bg-primary bg-opacity-10 border-0 h-100">
                        <div class="card-body p-20">
                            <div class="d-flex align-items-center gap-3">
                                <div class="bg-primary bg-opacity-20 p-12 rounded-circle">
                                    <iconify-icon icon="mdi:message-text" class="text-primary icon-xl"></iconify-icon>
                                </div>
                                <div>
                                    <h4 class="fw-bold mb-0"><?php echo $stats['total_messages'] ?? 0; ?></h4>
                                    <small class="text-muted">Total Messages</small>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
                <div class="col-md-3 col-6">
                    <div class="card bg-success bg-opacity-10 border-0 h-100">
                        <div class="card-body p-20">
                            <div class="d-flex align-items-center gap-3">
                                <div class="bg-success bg-opacity-20 p-12 rounded-circle">
                                    <iconify-icon icon="mdi:check-circle" class="text-success icon-xl"></iconify-icon>
                                </div>
                                <div>
                                    <h4 class="fw-bold mb-0"><?php echo $stats['active_messages'] ?? 0; ?></h4>
                                    <small class="text-muted">Active Messages</small>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
                <div class="col-md-3 col-6">
                    <div class="card bg-danger bg-opacity-10 border-0 h-100">
                        <div class="card-body p-20">
                            <div class="d-flex align-items-center gap-3">
                                <div class="bg-danger bg-opacity-20 p-12 rounded-circle">
                                    <iconify-icon icon="mdi:block-helper" class="text-danger icon-xl"></iconify-icon>
                                </div>
                                <div>
                                    <h4 class="fw-bold mb-0"><?php echo $stats['blocked_messages'] ?? 0; ?></h4>
                                    <small class="text-muted">Blocked Messages</small>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
                <div class="col-md-3 col-6">
                    <div class="card bg-info bg-opacity-10 border-0 h-100">
                        <div class="card-body p-20">
                            <div class="d-flex align-items-center gap-3">
                                <div class="bg-info bg-opacity-20 p-12 rounded-circle">
                                    <iconify-icon icon="mdi:account-group" class="text-info icon-xl"></iconify-icon>
                                </div>
                                <div>
                                    <h4 class="fw-bold mb-0"><?php echo $stats['active_users'] ?? 0; ?></h4>
                                    <small class="text-muted">Active Users</small>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- Main Chat Container -->
        <div class="col-12">
            <div class="card h-100 p-0 radius-12 shadow-sm">
                <!-- Group Header -->
                <div class="card-header border-bottom bg-white py-16 px-24">
                    <div class="d-flex align-items-center justify-content-between">
                        <div class="d-flex align-items-center gap-3">
                            <div class="position-relative">
                                <?php if (!empty($group['group_image'])): ?>
                                    <img src="<?php echo $group['group_image']; ?>" class="w-50-px h-50-px rounded-circle">
                                <?php else: ?>
                                    <div class="w-50-px h-50-px rounded-circle bg-primary d-flex align-items-center justify-content-center text-white fw-bold">
                                        <?php echo strtoupper(substr($group['name'], 0, 1)); ?>
                                    </div>
                                <?php endif; ?>
                                <span class="position-absolute bottom-0 end-0 bg-<?php echo $group['status'] == 'Active' ? 'success' : 'danger'; ?> border border-2 border-white rounded-circle" style="width: 12px; height: 12px;"></span>
                            </div>
                            <div>
                                <h6 class="mb-1 fw-semibold"><?php echo htmlspecialchars($group['name']); ?></h6>
                                <div class="d-flex align-items-center gap-2">
                                    <span class="badge bg-primary"><?php echo $group['category']; ?></span>
                                    <span class="badge bg-<?php echo $group['status'] == 'Active' ? 'success' : 'danger'; ?>">
                                        <?php echo $group['status']; ?>
                                    </span>
                                    <small class="text-muted">Created by <?php echo htmlspecialchars($group['created_by_name']); ?></small>
                                </div>
                            </div>
                        </div>
                        <div class="d-flex align-items-center gap-2">
                            <button class="btn btn-outline-primary btn-sm d-flex align-items-center gap-2" onclick="refreshChat()">
                                <iconify-icon icon="mdi:refresh"></iconify-icon>
                                Refresh
                            </button>
                            <a href="groups.php" class="btn btn-outline-secondary btn-sm d-flex align-items-center gap-2">
                                <iconify-icon icon="mdi:arrow-left"></iconify-icon>
                                Back to Groups
                            </a>
                        </div>
                    </div>
                </div>

                <!-- Chat Messages -->
                <div class="card-body p-0">
                    <div class="chat-container" style="height: 65vh; overflow-y: auto; padding: 20px;" id="chat-messages">
                        <?php
                            $last_displayed_date = null;
                            while ($message = $messages_result->fetch_assoc()):
                                $message_date = date('Y-m-d', strtotime($message['created_at']));
                                $today = date('Y-m-d');
                                $yesterday = date('Y-m-d', strtotime('-1 day'));

                                if ($message_date != $last_displayed_date) {
                                    echo '<div class="text-center my-3">';
                                    echo '<span class="badge bg-secondary text-white px-3 py-2 rounded-pill">';
                                    if ($message_date == $today) {
                                        echo 'Today';
                                    } elseif ($message_date == $yesterday) {
                                        echo 'Yesterday';
                                    } else {
                                        echo date('M j, Y', strtotime($message['created_at']));
                                    }
                                    echo '</span>';
                                    echo '</div>';
                                    $last_displayed_date = $message_date;
                                }
                            ?>
                            <div class="chat-single-message <?php echo ($message['user_id'] == $current_user_id) ? 'right' : 'left'; ?>">
                                <?php if ($message['user_id'] != $current_user_id): // Display avatar only for received messages ?>
                                    <div class="chat-avatar">
                                        <div class="position-relative">
                                            <?php if (!empty($message['profile_photo'])): ?>
                                                <img src="<?php echo $message['profile_photo']; ?>" class="w-40-px h-40-px rounded-circle">
                                            <?php else: ?>
                                                <div class="w-40-px h-40-px rounded-circle bg-secondary d-flex align-items-center justify-content-center text-white fw-medium">
                                                    <?php echo strtoupper(substr($message['user_name'], 0, 1)); ?>
                                                </div>
                                            <?php endif; ?>
                                            <?php if ($message['status'] == 'blocked'): ?>
                                                <span class="position-absolute top-0 start-100 translate-middle bg-danger rounded-circle" style="width: 8px; height: 8px;"></span>
                                            <?php endif; ?>
                                        </div>
                                    </div>
                                <?php endif; ?>
                                <div class="chat-message-content <?php echo $message['status'] == 'blocked' ? 'blocked-message' : 'normal-message'; ?>" 
                                     data-message-id="<?php echo $message['id']; ?>">
                                    <div class="d-flex justify-content-between align-items-start mb-2">
                                        <div class="d-flex align-items-center gap-2">
                                            <?php if ($message['user_id'] != $current_user_id): ?>
                                                <strong class="text-dark"><?php echo htmlspecialchars($message['user_name']); ?></strong>
                                            <?php endif; ?>
                                            <?php if ($message['status'] == 'blocked'): ?>
                                                <span class="badge bg-danger bg-opacity-20 text-danger border-0">
                                                    <iconify-icon icon="mdi:block-helper" class="icon-sm"></iconify-icon>
                                                    Blocked
                                                </span>
                                            <?php endif; ?>
                                        </div>
                                        
                                        <?php if ($is_moderator): ?>
                                            <div class="dropdown">
                                                <button class="btn btn-sm btn-outline-secondary dropdown-toggle" type="button" data-bs-toggle="dropdown" aria-expanded="false">
                                                    <iconify-icon icon="mdi:cog"></iconify-icon>
                                                </button>
                                                <ul class="dropdown-menu">
                                                    <?php if ($message['status'] == 'active'): ?>
                                                        <li>
                                                            <a class="dropdown-item text-warning block-message" href="#" 
                                                               data-id="<?php echo $message['id']; ?>">
                                                                <iconify-icon icon="mdi:block-helper"></iconify-icon>
                                                                Block Message
                                                            </a>
                                                        </li>
                                                    <?php else: ?>
                                                        <li>
                                                            <a class="dropdown-item text-success unblock-message" href="#" 
                                                               data-id="<?php echo $message['id']; ?>">
                                                                <iconify-icon icon="mdi:check"></iconify-icon>
                                                                Unblock Message
                                                            </a>
                                                        </li>
                                                        <li><hr class="dropdown-divider"></li>
                                                        <li>
                                                            <small class="dropdown-item text-muted">
                                                                <div>Blocked by: <strong><?php echo htmlspecialchars($message['blocked_by_name']); ?></strong></div>
                                                                <div>Reason: <?php echo htmlspecialchars($message['block_reason']); ?></div>
                                                            </small>
                                                        </li>
                                                    <?php endif; ?>
                                                    <li><hr class="dropdown-divider"></li>
                                                    <li>
                                                        <a class="dropdown-item text-danger delete-message" href="#" 
                                                           data-id="<?php echo $message['id']; ?>">
                                                            <iconify-icon icon="fluent:delete-24-regular"></iconify-icon>
                                                            Delete Message
                                                        </a>
                                                    </li>
                                                </ul>
                                            </div>
                                        <?php endif; ?>
                                    </div>
                                    
                                    <div class="message-content">
                                        <?php if ($message['status'] == 'blocked'): ?>
                                            <div class="alert alert-warning alert-sm py-2 mb-2 d-flex align-items-center gap-2">
                                                <iconify-icon icon="mdi:alert-circle" class="text-warning"></iconify-icon>
                                                <small class="flex-grow-1">This message has been blocked by admin</small>
                                            </div>
                                        <?php endif; ?>
                                        
                                        <?php if ($message['message_type'] == 'text'): ?>
                                            <p class="mb-0 message-text <?php echo $message['status'] == 'blocked' ? 'text-muted text-decoration-line-through' : 'text-dark'; ?>">
                                                <?php echo htmlspecialchars($message['message']); ?>
                                            </p>
                                        <?php elseif ($message['message_type'] == 'image'): ?>
                                            <div class="message-image">
                                                <img src="<?php echo $message['file_path']; ?>" class="img-thumbnail rounded" style="max-height: 200px;">
                                            </div>
                                        <?php else: ?>
                                            <div class="message-file">
                                                <a href="<?php echo $message['file_path']; ?>" class="btn btn-sm btn-outline-primary d-inline-flex align-items-center gap-2" download>
                                                    <iconify-icon icon="mdi:download"></iconify-icon>
                                                    Download File
                                                </a>
                                            </div>
                                        <?php endif; ?>
                                    </div>
                                    <small class="chat-time text-muted">
                                        <?php echo date('g:i A', strtotime($message['created_at'])); ?>
                                    </small>
                                </div>
                            </div>
                            <?php endwhile; ?>
                        <?php
                        if ($messages_result->num_rows === 0):
                        ?>
                            <div class="text-center text-muted py-5">
                                <div class="mb-3">
                                    <iconify-icon icon="mdi:chat-outline" class="icon-4x text-light"></iconify-icon>
                                </div>
                                <h5 class="text-muted">No messages yet</h5>
                                <p class="mb-0">This group doesn't have any chat messages yet.</p>
                            </div>
                        <?php endif; ?>
                    </div>
                </div>

                <!-- Footer with Pagination -->
                <div class="card-footer bg-white border-top py-16 px-24">
                    <div class="d-flex justify-content-between align-items-center">
                        <small class="text-muted">
                            Showing <?php echo $messages_result->num_rows; ?> messages
                            <?php if ($stats['total_messages'] > $limit): ?>
                                (Page <?php echo $page; ?> of <?php echo ceil($stats['total_messages'] / $limit); ?>)
                            <?php endif; ?>
                        </small>
                        
                        <?php if ($stats['total_messages'] > $limit): ?>
                            <div class="d-flex gap-2">
                                <?php if ($page > 1): ?>
                                    <a href="?id=<?php echo $group_id; ?>&page=<?php echo $page - 1; ?>" class="btn btn-outline-primary btn-sm">
                                        <iconify-icon icon="mdi:chevron-left"></iconify-icon>
                                        Previous
                                    </a>
                                <?php endif; ?>
                                
                                <?php if ($page < ceil($stats['total_messages'] / $limit)): ?>
                                    <a href="?id=<?php echo $group_id; ?>&page=<?php echo $page + 1; ?>" class="btn btn-outline-primary btn-sm">
                                        Next
                                        <iconify-icon icon="mdi:chevron-right"></iconify-icon>
                                    </a>
                                <?php endif; ?>
                            </div>
                        <?php endif; ?>
                    </div>
                </div>
            </div>
        </div>
    </div>
</div>

<!-- Block Message Modal -->
<div class="modal fade" id="blockMessageModal" tabindex="-1">
    <div class="modal-dialog">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title">Block Message</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
            </div>
            <div class="modal-body">
                <form id="blockMessageForm">
                    <input type="hidden" id="block_message_id" name="message_id">
                    <div class="mb-3">
                        <label for="block_reason" class="form-label">Reason for blocking</label>
                        <textarea class="form-control" id="block_reason" name="block_reason" rows="3" 
                                  placeholder="Enter reason for blocking this message..." required></textarea>
                        <div class="form-text">This reason will be visible to other moderators.</div>
                    </div>
                </form>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                <button type="button" class="btn btn-warning" id="confirmBlock">
                    <iconify-icon icon="mdi:block-helper"></iconify-icon>
                    Block Message
                </button>
            </div>
        </div>
    </div>
</div>

<?php include './partials/layouts/layoutBottom.php'; ?>

<script>
$(document).ready(function() {
    // Auto scroll to bottom of chat
    $('#chat-messages').scrollTop($('#chat-messages')[0].scrollHeight);

    // Block message
    $(document).on('click', '.block-message', function(e) {
        e.preventDefault();
        const messageId = $(this).data('id');
        $('#block_message_id').val(messageId);
        $('#block_reason').val('');
        $('#blockMessageModal').modal('show');
    });

    // Confirm block message
    $('#confirmBlock').on('click', function() {
        const messageId = $('#block_message_id').val();
        const blockReason = $('#block_reason').val();

        if (!blockReason.trim()) {
            alert('Please enter a reason for blocking this message.');
            return;
        }

        $.post('group-chat-action.php', {
            action: 'block_message',
            message_id: messageId,
            block_reason: blockReason
        }, function(response) {
            if (response.success) {
                $('#blockMessageModal').modal('hide');
                showToast('Message blocked successfully', 'success');
                setTimeout(() => location.reload(), 1000);
            } else {
                showToast(response.message || 'Failed to block message', 'error');
            }
        }, 'json').fail(function() {
            showToast('Request failed. Please try again.', 'error');
        });
    });

    // Unblock message
    $(document).on('click', '.unblock-message', function(e) {
        e.preventDefault();
        const messageId = $(this).data('id');

        if (confirm('Are you sure you want to unblock this message?')) {
            $.post('group-chat-action.php', {
                action: 'unblock_message',
                message_id: messageId
            }, function(response) {
                if (response.success) {
                    showToast('Message unblocked successfully', 'success');
                    setTimeout(() => location.reload(), 1000);
                } else {
                    showToast(response.message || 'Failed to unblock message', 'error');
                }
            }, 'json');
        }
    });

    // Delete message
    $(document).on('click', '.delete-message', function(e) {
        e.preventDefault();
        const messageId = $(this).data('id');

        if (confirm('Are you sure you want to delete this message? This action cannot be undone.')) {
            $.post('group-chat-action.php', {
                action: 'delete_message',
                message_id: messageId
            }, function(response) {
                if (response.success) {
                    showToast('Message deleted successfully', 'success');
                    setTimeout(() => location.reload(), 1000);
                } else {
                    showToast(response.message || 'Failed to delete message', 'error');
                }
            }, 'json');
        }
    });
});

function refreshChat() {
    showToast('Refreshing chat...', 'info');
    location.reload();
}

function showToast(message, type = 'info') {
    // Simple toast notification
    const toast = document.createElement('div');
    toast.className = `alert alert-${type} alert-dismissible fade show position-fixed`;
    toast.style.cssText = 'top: 20px; right: 20px; z-index: 9999; min-width: 300px;';
    toast.innerHTML = `
        ${message}
        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    `;
    document.body.appendChild(toast);
    
    // Auto remove after 3 seconds
    setTimeout(() => {
        toast.remove();
    }, 3000);
}
</script>

<style>
.chat-container {
    background: linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%);
}

.chat-message {
    transition: all 0.3s ease;
    border: 1px solid transparent;
    background: white;
}

.chat-message:hover {
    border-color: #007bff;
    box-shadow: 0 2px 8px rgba(0, 123, 255, 0.1);
}

.normal-message {
    border-left: 4px solid #28a745;
}

.blocked-message {
    border-left: 4px solid #dc3545;
    background: #fff5f5;
}

.message-text {
    line-height: 1.5;
    word-wrap: break-word;
}

.alert-sm {
    padding: 0.5rem 0.75rem;
    font-size: 0.875rem;
}

.icon-xl {
    font-size: 1.5rem;
}

.icon-4x {
    font-size: 4rem;
}

.w-40-px { width: 40px; }
.h-40-px { height: 40px; }
.w-50-px { width: 50px; }
.h-50-px { height: 50px; }

/* Custom scrollbar */
.chat-container::-webkit-scrollbar {
    width: 6px;
}

.chat-container::-webkit-scrollbar-track {
    background: #f1f1f1;
    border-radius: 3px;
}

.chat-container::-webkit-scrollbar-thumb {
    background: #c1c1c1;
    border-radius: 3px;
}

.chat-container::-webkit-scrollbar-thumb:hover {
    background: #a8a8a8;
}

/* Dropdown menu improvements */
.dropdown-menu {
    box-shadow: 0 0.5rem 1rem rgba(0, 0, 0, 0.15);
    border: 1px solid rgba(0, 0, 0, 0.1);
}

/* Badge improvements */
.badge {
    font-size: 0.7em;
    padding: 0.35em 0.65em;
}

/* Card hover effects */
.card {
    transition: transform 0.2s ease, box-shadow 0.2s ease;
}

.card:hover {
    transform: translateY(-2px);
    box-shadow: 0 0.5rem 1rem rgba(0, 0, 0, 0.15) !important;
}
</style>