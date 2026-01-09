-- =====================================================
-- COMPREHENSIVE TABLE CHECK - All Related Tables
-- =====================================================
-- Run these queries in phpMyAdmin to check all tables and data

-- =====================================================
-- 1. CHECK ALL TABLES EXIST
-- =====================================================
SHOW TABLES;

-- =====================================================
-- 2. CHECK emoji_usage TABLE
-- =====================================================
-- Check if table exists
SHOW TABLES LIKE 'emoji_usage';

-- Check table structure
DESCRIBE emoji_usage;
-- OR
SHOW CREATE TABLE emoji_usage;

-- Check total records
SELECT COUNT(*) as total_records FROM emoji_usage;

-- Check all records (first 100)
SELECT * FROM emoji_usage 
ORDER BY created_at DESC 
LIMIT 100;

-- Check records by user (replace 37 with actual user_id)
SELECT * FROM emoji_usage 
WHERE user_id = 37
ORDER BY created_at DESC;

-- Check general feelings (post_type IS NULL, post_id IS NULL)
SELECT * FROM emoji_usage 
WHERE post_type IS NULL 
  AND post_id IS NULL
ORDER BY created_at DESC;

-- Check post-specific reactions
SELECT * FROM emoji_usage 
WHERE post_type IS NOT NULL 
  OR post_id IS NOT NULL
ORDER BY created_at DESC;

-- =====================================================
-- 3. CHECK emojis TABLE (for emoji details)
-- =====================================================
-- Check if table exists
SHOW TABLES LIKE 'emojis';

-- Check table structure
DESCRIBE emojis;

-- Check total emojis
SELECT COUNT(*) as total_emojis FROM emojis;

-- Check sample emojis
SELECT id, name, code, emoji_char, image_url, status 
FROM emojis 
ORDER BY id 
LIMIT 20;

-- =====================================================
-- 4. CHECK comments TABLE
-- =====================================================
-- Check if table exists
SHOW TABLES LIKE 'comments';

-- Check table structure
DESCRIBE comments;

-- Check total comments
SELECT COUNT(*) as total_comments FROM comments;

-- Check comments with emoji reactions (short content)
SELECT id, user_id, post_type, post_id, content, created_at 
FROM comments 
WHERE LENGTH(content) <= 20
ORDER BY created_at DESC 
LIMIT 50;

-- Check comments for photos (post_type = 'photo' or 'gallery')
SELECT id, user_id, post_type, post_id, content, created_at 
FROM comments 
WHERE post_type IN ('photo', 'gallery')
ORDER BY created_at DESC 
LIMIT 50;

-- =====================================================
-- 5. CHECK gallery_comments TABLE
-- =====================================================
-- Check if table exists
SHOW TABLES LIKE 'gallery_comments';

-- Check table structure
DESCRIBE gallery_comments;

-- Check total gallery comments
SELECT COUNT(*) as total_gallery_comments FROM gallery_comments;

-- Check all gallery comments
SELECT * FROM gallery_comments 
ORDER BY created_at DESC 
LIMIT 50;

-- Check gallery comments with emoji reactions (short content)
SELECT id, photo_id, user_id, content, created_at 
FROM gallery_comments 
WHERE LENGTH(content) <= 20
ORDER BY created_at DESC 
LIMIT 50;

-- =====================================================
-- 6. CHECK users TABLE (to verify user_id exists)
-- =====================================================
-- Check if table exists
SHOW TABLES LIKE 'users';

-- Check table structure
DESCRIBE users;

-- Check total users
SELECT COUNT(*) as total_users FROM users;

-- Check specific user (replace 37 with actual user_id)
SELECT id, name, email, status 
FROM users 
WHERE id = 37;

-- =====================================================
-- 7. CHECK media_items TABLE (for gallery photos)
-- =====================================================
-- Check if table exists
SHOW TABLES LIKE 'media_items';

-- Check table structure
DESCRIBE media_items;

-- Check total photos
SELECT COUNT(*) as total_photos FROM media_items WHERE type = 'photo';

-- Check sample photos
SELECT id, user_id, type, file_path, status, created_at 
FROM media_items 
WHERE type = 'photo'
ORDER BY created_at DESC 
LIMIT 20;

-- =====================================================
-- 8. CROSS-CHECK: Verify data relationships
-- =====================================================

-- Check if emoji_usage has valid user_ids
SELECT e.*, u.name as user_name
FROM emoji_usage e
LEFT JOIN users u ON e.user_id = u.id
WHERE u.id IS NULL
LIMIT 10;
-- If this returns rows, there are orphaned records (user doesn't exist)

-- Check emoji_usage with emoji details
SELECT e.*, em.name as emoji_name, em.code as emoji_code, em.image_url as emoji_image
FROM emoji_usage e
LEFT JOIN emojis em ON (e.emoji = em.code OR e.emoji = em.emoji_char OR e.emoji = em.image_url)
ORDER BY e.created_at DESC
LIMIT 20;

-- Check comments with user details
SELECT c.*, u.name as user_name
FROM comments c
LEFT JOIN users u ON c.user_id = u.id
ORDER BY c.created_at DESC
LIMIT 20;

-- =====================================================
-- 9. SUMMARY QUERY - Get overview of all data
-- =====================================================
SELECT 
    'emoji_usage' as table_name,
    COUNT(*) as total_records,
    COUNT(DISTINCT user_id) as unique_users,
    COUNT(CASE WHEN post_type IS NULL AND post_id IS NULL THEN 1 END) as general_feelings,
    COUNT(CASE WHEN post_type IS NOT NULL OR post_id IS NOT NULL THEN 1 END) as post_reactions
FROM emoji_usage
UNION ALL
SELECT 
    'comments' as table_name,
    COUNT(*) as total_records,
    COUNT(DISTINCT user_id) as unique_users,
    COUNT(CASE WHEN post_type IN ('photo', 'gallery') THEN 1 END) as photo_comments,
    COUNT(CASE WHEN post_type NOT IN ('photo', 'gallery') THEN 1 END) as other_comments
FROM comments
UNION ALL
SELECT 
    'gallery_comments' as table_name,
    COUNT(*) as total_records,
    COUNT(DISTINCT user_id) as unique_users,
    COUNT(*) as gallery_comments,
    0 as other_comments
FROM gallery_comments;

-- =====================================================
-- 10. TEST INSERT (to verify table is working)
-- =====================================================
-- Uncomment to test if INSERT works:
-- 
-- INSERT INTO emoji_usage (user_id, emoji, post_type, post_id)
-- VALUES (37, 'test_emoji_check_123', NULL, NULL);
-- 
-- Then check:
-- SELECT * FROM emoji_usage WHERE emoji = 'test_emoji_check_123';
-- 
-- If it appears, table is working. Delete test record:
-- DELETE FROM emoji_usage WHERE emoji = 'test_emoji_check_123';

-- =====================================================
-- 11. CHECK FOR RECENT DATA (last 24 hours)
-- =====================================================
-- Recent emoji_usage
SELECT * FROM emoji_usage 
WHERE created_at >= DATE_SUB(NOW(), INTERVAL 24 HOUR)
ORDER BY created_at DESC;

-- Recent comments
SELECT * FROM comments 
WHERE created_at >= DATE_SUB(NOW(), INTERVAL 24 HOUR)
ORDER BY created_at DESC
LIMIT 50;

-- Recent gallery_comments
SELECT * FROM gallery_comments 
WHERE created_at >= DATE_SUB(NOW(), INTERVAL 24 HOUR)
ORDER BY created_at DESC;

-- =====================================================
-- 12. CHECK FOR DATA ISSUES
-- =====================================================
-- Check for empty/null emoji values
SELECT * FROM emoji_usage 
WHERE emoji IS NULL OR emoji = ''
LIMIT 10;

-- Check for invalid user_ids
SELECT e.* 
FROM emoji_usage e
LEFT JOIN users u ON e.user_id = u.id
WHERE u.id IS NULL
LIMIT 10;

-- Check for duplicate general feelings (should be only 1 per user)
SELECT user_id, COUNT(*) as feeling_count
FROM emoji_usage
WHERE post_type IS NULL AND post_id IS NULL
GROUP BY user_id
HAVING feeling_count > 1
ORDER BY feeling_count DESC;



