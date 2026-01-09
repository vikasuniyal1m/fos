-- =====================================================
-- Debug Queries: Check emoji_usage Table Data
-- =====================================================

-- 1. Check if table exists
SHOW TABLES LIKE 'emoji_usage';

-- 2. Check table structure
DESCRIBE emoji_usage;
-- OR
SHOW CREATE TABLE emoji_usage;

-- 3. Check total records in table
SELECT COUNT(*) as total_records FROM emoji_usage;

-- 4. Check all records (first 50)
SELECT * FROM emoji_usage 
ORDER BY created_at DESC 
LIMIT 50;

-- 5. Check records for specific user (replace 37 with your user_id)
SELECT * FROM emoji_usage 
WHERE user_id = 37
ORDER BY created_at DESC;

-- 6. Check general feelings only (post_type IS NULL, post_id IS NULL)
SELECT * FROM emoji_usage 
WHERE post_type IS NULL 
  AND post_id IS NULL
ORDER BY created_at DESC;

-- 7. Check general feelings for specific user (replace 37 with your user_id)
SELECT * FROM emoji_usage 
WHERE user_id = 37
  AND post_type IS NULL 
  AND post_id IS NULL
ORDER BY created_at DESC;

-- 8. Check post-specific reactions (not general feelings)
SELECT * FROM emoji_usage 
WHERE post_type IS NOT NULL 
  OR post_id IS NOT NULL
ORDER BY created_at DESC;

-- 9. Count feelings by user
SELECT user_id, COUNT(*) as feeling_count
FROM emoji_usage
WHERE post_type IS NULL AND post_id IS NULL
GROUP BY user_id
ORDER BY feeling_count DESC;

-- 10. Check latest feeling for each user
SELECT e1.*
FROM emoji_usage e1
INNER JOIN (
    SELECT user_id, MAX(created_at) as max_created_at
    FROM emoji_usage
    WHERE post_type IS NULL AND post_id IS NULL
    GROUP BY user_id
) e2 ON e1.user_id = e2.user_id 
    AND e1.created_at = e2.max_created_at
    AND e1.post_type IS NULL 
    AND e1.post_id IS NULL
ORDER BY e1.created_at DESC;

-- 11. Check if there are any NULL values in critical columns
SELECT 
    COUNT(*) as total,
    SUM(CASE WHEN user_id IS NULL THEN 1 ELSE 0 END) as null_user_id,
    SUM(CASE WHEN emoji IS NULL OR emoji = '' THEN 1 ELSE 0 END) as null_emoji,
    SUM(CASE WHEN post_type IS NULL THEN 1 ELSE 0 END) as null_post_type,
    SUM(CASE WHEN post_id IS NULL THEN 1 ELSE 0 END) as null_post_id
FROM emoji_usage;

-- 12. Check recent insertions (last 24 hours)
SELECT * FROM emoji_usage 
WHERE created_at >= DATE_SUB(NOW(), INTERVAL 24 HOUR)
ORDER BY created_at DESC;

-- 13. Check if table has any data at all
SELECT 
    'Total Records' as check_type,
    COUNT(*) as count
FROM emoji_usage
UNION ALL
SELECT 
    'General Feelings',
    COUNT(*)
FROM emoji_usage
WHERE post_type IS NULL AND post_id IS NULL
UNION ALL
SELECT 
    'Post Reactions',
    COUNT(*)
FROM emoji_usage
WHERE post_type IS NOT NULL OR post_id IS NOT NULL;

-- =====================================================
-- Test INSERT (to verify table is working)
-- =====================================================
-- Uncomment and run this to test if INSERT works:
-- 
-- INSERT INTO emoji_usage (user_id, emoji, post_type, post_id)
-- VALUES (37, 'test_emoji', NULL, NULL);
-- 
-- Then check:
-- SELECT * FROM emoji_usage WHERE emoji = 'test_emoji';
-- 
-- If it appears, table is working. Delete test record:
-- DELETE FROM emoji_usage WHERE emoji = 'test_emoji';

-- =====================================================
-- Common Issues and Solutions
-- =====================================================
-- 
-- Issue 1: Table doesn't exist
-- Solution: Run CREATE TABLE query from DATABASE_TABLE_STRUCTURE.md
--
-- Issue 2: Table exists but no data
-- Solution: Check backend API (emojis.php) - it might not be inserting data
--
-- Issue 3: Data exists but not showing for specific user
-- Solution: Check user_id in query - might be wrong user_id
--
-- Issue 4: Multiple records for same user (general feeling)
-- Solution: Backend should UPDATE instead of INSERT (see update_emoji_usage_replace_feeling.sql)
--
-- Issue 5: Data in table but app not showing
-- Solution: Check API endpoint - might not be returning data correctly



