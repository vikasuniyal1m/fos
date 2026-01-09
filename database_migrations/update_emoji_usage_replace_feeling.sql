-- =====================================================
-- SQL Queries for Testing and Understanding
-- =====================================================
-- IMPORTANT: Replace 37 with your actual user_id before running

-- 1. Check if table exists
SHOW TABLES LIKE 'emoji_usage';

-- 2. Check table structure
DESCRIBE emoji_usage;

-- 3. Check ALL data in table (to see if anything is being saved)
SELECT * FROM emoji_usage ORDER BY created_at DESC LIMIT 50;

-- 4. Check if user has existing feeling (replace 37 with actual user_id)
SELECT * FROM emoji_usage 
WHERE user_id = 37 
  AND post_type IS NULL 
  AND post_id IS NULL 
ORDER BY created_at DESC 
LIMIT 1;

-- 5. Check ALL feelings for user (replace 37 with actual user_id)
SELECT * FROM emoji_usage 
WHERE user_id = 37
ORDER BY created_at DESC;

-- 2. Update existing feeling (replace ? with actual user_id and emoji value)
UPDATE emoji_usage 
SET emoji = 'joy_pineapple_02', 
    updated_at = NOW()
WHERE user_id = 37 
  AND post_type IS NULL 
  AND post_id IS NULL
ORDER BY created_at DESC
LIMIT 1;

-- 3. Check how many feelings exist for a user (general feelings only)
SELECT COUNT(*) as total_feelings 
FROM emoji_usage 
WHERE user_id = 37 
  AND post_type IS NULL 
  AND post_id IS NULL;

-- 4. Get all feelings for a user (to see history)
SELECT * FROM emoji_usage 
WHERE user_id = 37 
  AND post_type IS NULL 
  AND post_id IS NULL
ORDER BY created_at DESC;

-- =====================================================
-- Backend PHP Logic (for emojis.php)
-- =====================================================
-- 
-- When post_type and post_id are NULL (general feeling):
-- 1. Check if user already has a feeling (post_type IS NULL AND post_id IS NULL)
-- 2. If exists: UPDATE the existing record
-- 3. If not exists: INSERT new record
--
-- PHP Code:
-- 
-- $user_id = intval($_POST['user_id']);
-- $emoji = trim($_POST['emoji']);
-- $post_type = isset($_POST['post_type']) ? $_POST['post_type'] : null;
-- $post_id = isset($_POST['post_id']) ? intval($_POST['post_id']) : null;
--
-- // If this is a general feeling (How are you feeling)
-- if ($post_type === null && $post_id === null) {
--     // Check if existing feeling exists
--     $check = $conn->prepare("
--         SELECT id FROM emoji_usage 
--         WHERE user_id = ? 
--           AND post_type IS NULL 
--           AND post_id IS NULL 
--         ORDER BY created_at DESC 
--         LIMIT 1
--     ");
--     $check->bind_param("i", $user_id);
--     $check->execute();
--     $result = $check->get_result();
--     
--     if ($result->num_rows > 0) {
--         // UPDATE existing feeling
--         $row = $result->fetch_assoc();
--         $update = $conn->prepare("
--             UPDATE emoji_usage 
--             SET emoji = ?, updated_at = NOW() 
--             WHERE id = ?
--         ");
--         $update->bind_param("si", $emoji, $row['id']);
--         $update->execute();
--         echo json_encode(['success' => true, 'message' => 'Feeling updated successfully']);
--     } else {
--         // INSERT new feeling
--         $insert = $conn->prepare("
--             INSERT INTO emoji_usage (user_id, emoji, post_type, post_id) 
--             VALUES (?, ?, NULL, NULL)
--         ");
--         $insert->bind_param("is", $user_id, $emoji);
--         $insert->execute();
--         echo json_encode(['success' => true, 'message' => 'Feeling saved successfully']);
--     }
-- } else {
--     // For post-specific reactions, just INSERT (allow multiple reactions)
--     $insert = $conn->prepare("
--         INSERT INTO emoji_usage (user_id, emoji, post_type, post_id) 
--         VALUES (?, ?, ?, ?)
--     ");
--     $insert->bind_param("issi", $user_id, $emoji, $post_type, $post_id);
--     $insert->execute();
--     echo json_encode(['success' => true, 'message' => 'Reaction saved successfully']);
-- }

