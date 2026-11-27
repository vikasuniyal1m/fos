<?php
/**
 * IAP premium helpers — one email pays once (Android / iOS shared).
 * iap_purchase_type: 'test' (sandbox) | 'production' (real).
 */

function fos_normalize_email($email) {
    return strtolower(trim((string) $email));
}

/** @return 'test'|'production' */
function fos_iap_purchase_type_from_sandbox($isSandbox) {
    return $isSandbox ? 'test' : 'production';
}

function fos_ensure_premium_columns($conn) {
    $conn->set_charset('utf8mb4');
    $cols = [
        'is_lifetime_premium' => 'TINYINT(1) DEFAULT 0',
        'lifetime_purchase_date' => 'DATETIME NULL',
        'apple_transaction_id' => 'VARCHAR(255) NULL',
        'apple_product_id' => 'VARCHAR(255) NULL',
        'google_purchase_token' => 'VARCHAR(512) NULL',
        'google_product_id' => 'VARCHAR(255) NULL',
        'google_order_id' => 'VARCHAR(255) NULL',
        'iap_platform' => "VARCHAR(16) NULL COMMENT 'apple|google'",
        'iap_purchase_type' => "VARCHAR(16) NULL DEFAULT NULL COMMENT 'test|production'",
    ];
    foreach ($cols as $name => $def) {
        $chk = @$conn->query("SHOW COLUMNS FROM users LIKE '$name'");
        if (!$chk || $chk->num_rows === 0) {
            @$conn->query("ALTER TABLE users ADD COLUMN $name $def");
        }
    }
}

function fos_get_user_row($conn, $userId) {
    $uid = (int) $userId;
    if ($uid <= 0) {
        return null;
    }
    $stmt = $conn->prepare(
        'SELECT id, email, is_lifetime_premium, lifetime_purchase_date, iap_purchase_type FROM users WHERE id = ? LIMIT 1'
    );
    if (!$stmt) {
        return null;
    }
    $stmt->bind_param('i', $uid);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    return $row ?: null;
}

function fos_email_has_premium($conn, $email) {
    $email = fos_normalize_email($email);
    if ($email === '') {
        return false;
    }
    fos_ensure_premium_columns($conn);
    $stmt = $conn->prepare(
        'SELECT id FROM users WHERE LOWER(TRIM(email)) = ? AND is_lifetime_premium = 1 LIMIT 1'
    );
    if (!$stmt) {
        return false;
    }
    $stmt->bind_param('s', $email);
    $stmt->execute();
    $found = $stmt->get_result()->num_rows > 0;
    $stmt->close();
    return $found;
}

function fos_sync_premium_by_email($conn, $userId) {
    fos_ensure_premium_columns($conn);
    $user = fos_get_user_row($conn, $userId);
    if (!$user) {
        return false;
    }

    if (!empty($user['is_lifetime_premium'])) {
        return true;
    }

    $email = fos_normalize_email($user['email'] ?? '');
    if ($email === '') {
        return false;
    }

    $stmt = $conn->prepare(
        'SELECT lifetime_purchase_date, iap_purchase_type FROM users WHERE LOWER(TRIM(email)) = ? AND is_lifetime_premium = 1 ORDER BY lifetime_purchase_date ASC LIMIT 1'
    );
    if (!$stmt) {
        return false;
    }
    $stmt->bind_param('s', $email);
    $stmt->execute();
    $paid = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$paid) {
        return false;
    }

    $purchaseDate = $paid['lifetime_purchase_date'] ?? null;
    $purchaseType = $paid['iap_purchase_type'] ?? null;
    $uid = (int) $userId;

    if ($purchaseDate && $purchaseType) {
        $upd = $conn->prepare(
            'UPDATE users SET is_lifetime_premium = 1, lifetime_purchase_date = ?, iap_purchase_type = ? WHERE id = ?'
        );
        if ($upd) {
            $upd->bind_param('ssi', $purchaseDate, $purchaseType, $uid);
            $upd->execute();
            $upd->close();
        }
    } elseif ($purchaseDate) {
        $upd = $conn->prepare(
            'UPDATE users SET is_lifetime_premium = 1, lifetime_purchase_date = ? WHERE id = ?'
        );
        if ($upd) {
            $upd->bind_param('si', $purchaseDate, $uid);
            $upd->execute();
            $upd->close();
        }
    } else {
        $upd = $conn->prepare(
            'UPDATE users SET is_lifetime_premium = 1, lifetime_purchase_date = NOW() WHERE id = ?'
        );
        if ($upd) {
            $upd->bind_param('i', $uid);
            $upd->execute();
            $upd->close();
        }
    }

    error_log("IAP: Synced premium to user $uid via email $email");
    return true;
}

function fos_grant_google_premium($conn, $uid, $purchaseToken, $productId, $orderId = '', $purchaseType = 'production') {
    fos_ensure_premium_columns($conn);
    $uid = (int) $uid;
    $purchaseType = in_array($purchaseType, ['test', 'production'], true) ? $purchaseType : 'production';
    $stmt = $conn->prepare(
        'UPDATE users SET is_lifetime_premium = 1, lifetime_purchase_date = NOW(), google_purchase_token = ?, google_product_id = ?, google_order_id = ?, iap_platform = ?, iap_purchase_type = ? WHERE id = ?'
    );
    if (!$stmt) {
        return false;
    }
    $platform = 'google';
    $stmt->bind_param('sssssi', $purchaseToken, $productId, $orderId, $platform, $purchaseType, $uid);
    $ok = $stmt->execute();
    $stmt->close();
    if ($ok) {
        fos_propagate_premium_by_email($conn, $uid);
    }
    return $ok;
}

function fos_grant_apple_premium($conn, $uid, $transactionId, $productId, $purchaseType = 'production') {
    fos_ensure_premium_columns($conn);
    $uid = (int) $uid;
    $purchaseType = in_array($purchaseType, ['test', 'production'], true) ? $purchaseType : 'production';
    $stmt = $conn->prepare(
        'UPDATE users SET is_lifetime_premium = 1, lifetime_purchase_date = NOW(), apple_transaction_id = ?, apple_product_id = ?, iap_platform = ?, iap_purchase_type = ? WHERE id = ?'
    );
    if (!$stmt) {
        return false;
    }
    $platform = 'apple';
    $stmt->bind_param('ssssi', $transactionId, $productId, $platform, $purchaseType, $uid);
    $ok = $stmt->execute();
    $stmt->close();
    if ($ok) {
        fos_propagate_premium_by_email($conn, $uid);
    }
    return $ok;
}

function fos_propagate_premium_by_email($conn, $userId) {
    $user = fos_get_user_row($conn, $userId);
    if (!$user) {
        return;
    }
    $email = fos_normalize_email($user['email'] ?? '');
    if ($email === '') {
        return;
    }
    $purchaseDate = $user['lifetime_purchase_date'] ?? null;
    $purchaseType = $user['iap_purchase_type'] ?? null;
    $uid = (int) $userId;

    if ($purchaseDate && $purchaseType) {
        $stmt = $conn->prepare(
            'UPDATE users SET is_lifetime_premium = 1, lifetime_purchase_date = ?, iap_purchase_type = ? WHERE LOWER(TRIM(email)) = ? AND id != ?'
        );
        if ($stmt) {
            $stmt->bind_param('sssi', $purchaseDate, $purchaseType, $email, $uid);
            $stmt->execute();
            $stmt->close();
        }
        return;
    }

    if ($purchaseDate) {
        $stmt = $conn->prepare(
            'UPDATE users SET is_lifetime_premium = 1, lifetime_purchase_date = ? WHERE LOWER(TRIM(email)) = ? AND id != ?'
        );
        if ($stmt) {
            $stmt->bind_param('ssi', $purchaseDate, $email, $uid);
            $stmt->execute();
            $stmt->close();
        }
        return;
    }

    $stmt = $conn->prepare(
        'UPDATE users SET is_lifetime_premium = 1, lifetime_purchase_date = NOW() WHERE LOWER(TRIM(email)) = ? AND (is_lifetime_premium = 0 OR is_lifetime_premium IS NULL)'
    );
    if ($stmt) {
        $stmt->bind_param('s', $email);
        $stmt->execute();
        $stmt->close();
    }
}
