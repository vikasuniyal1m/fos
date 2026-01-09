-- =====================================================
-- Fix Emoji Usage Table and Home Page Update Issues
-- =====================================================
-- 
-- This script fixes two main issues:
-- 1. Data not being saved to emoji_usage table
-- 2. Emoji not updating on home page
--
-- Run these queries one by one to diagnose and fix issues
-- =====================================================

-- =====================================================
-- STEP 1: Check if table exists
-- =====================================================
SHOW TABLES LIKE 'emoji_usage';

-- If table doesn't exist, create it:
CREATE TABLE IF NOT EXISTS `emoji_usage` (
  `id` INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `user_id` INT(11) NOT NULL,
  `emoji` VARCHAR(255) NOT NULL,
  `post_type` VARCHAR(50) NULL DEFAULT NULL,
  `post_id` INT(11) NULL DEFAULT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE,
  INDEX `idx_user_id` (`user_id`),
  INDEX `idx_created_at` (`created_at`),
  INDEX `idx_user_feeling` (`user_id`, `post_type`, `post_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- =====================================================
-- STEP 2: Check table structure
-- =====================================================
DESCRIBE emoji_usage;

-- =====================================================
-- STEP 3: Check if there's any data
-- =====================================================
SELECT COUNT(*) as total_records FROM emoji_usage;

-- Check all records
SELECT * FROM emoji_usage ORDER BY created_at DESC LIMIT 50;

-- =====================================================
-- STEP 4: Check for specific user (replace 37 with your user_id)
-- =====================================================
-- Replace 37 with your actual user_id
SELECT * FROM emoji_usage 
WHERE user_id = 37
ORDER BY created_at DESC;

-- Check general feelings for specific user
SELECT * FROM emoji_usage 
WHERE user_id = 37
  AND post_type IS NULL 
  AND post_id IS NULL
ORDER BY created_at DESC;

-- =====================================================
-- STEP 5: Check for duplicate general feelings
-- =====================================================
-- This query finds users with multiple general feelings (should only have ONE)
SELECT user_id, COUNT(*) as feeling_count
FROM emoji_usage
WHERE post_type IS NULL AND post_id IS NULL
GROUP BY user_id
HAVING feeling_count > 1
ORDER BY feeling_count DESC;

-- =====================================================
-- STEP 6: Fix duplicate general feelings (keep only the latest)
-- =====================================================
-- This will keep only the most recent feeling for each user
-- and delete older duplicate feelings

-- First, see what will be deleted (SAFE CHECK):
SELECT e1.*
FROM emoji_usage e1
INNER JOIN (
    SELECT user_id, MAX(created_at) as max_created_at
    FROM emoji_usage
    WHERE post_type IS NULL AND post_id IS NULL
    GROUP BY user_id
    HAVING COUNT(*) > 1
) e2 ON e1.user_id = e2.user_id 
    AND e1.post_type IS NULL 
    AND e1.post_id IS NULL
    AND e1.created_at < e2.max_created_at;

-- If the above shows records that should be deleted, run this:
-- DELETE e1 FROM emoji_usage e1
-- INNER JOIN (
--     SELECT user_id, MAX(created_at) as max_created_at
--     FROM emoji_usage
--     WHERE post_type IS NULL AND post_id IS NULL
--     GROUP BY user_id
--     HAVING COUNT(*) > 1
-- ) e2 ON e1.user_id = e2.user_id 
--     AND e1.post_type IS NULL 
--     AND e1.post_id IS NULL
--     AND e1.created_at < e2.max_created_at;

-- =====================================================
-- STEP 7: Test INSERT (to verify table is working)
-- =====================================================
-- Uncomment and run this to test if INSERT works:
-- Replace 37 with your actual user_id
-- 
-- INSERT INTO emoji_usage (user_id, emoji, post_type, post_id)
-- VALUES (37, 'test_emoji_joy_pineapple_02', NULL, NULL);
-- 
-- Then check:
-- SELECT * FROM emoji_usage WHERE emoji = 'test_emoji_joy_pineapple_02';
-- 
-- If it appears, table is working. Delete test record:
-- DELETE FROM emoji_usage WHERE emoji = 'test_emoji_joy_pineapple_02';

-- =====================================================
-- STEP 8: Check recent insertions (last 24 hours)
-- =====================================================
SELECT * FROM emoji_usage 
WHERE created_at >= DATE_SUB(NOW(), INTERVAL 24 HOUR)
ORDER BY created_at DESC;

-- =====================================================
-- STEP 9: Verify backend API is working
-- =====================================================
-- Check if there are any records created in the last hour
SELECT 
    'Last Hour' as period,
    COUNT(*) as count
FROM emoji_usage
WHERE created_at >= DATE_SUB(NOW(), INTERVAL 1 HOUR)
UNION ALL
SELECT 
    'Last 24 Hours',
    COUNT(*)
FROM emoji_usage
WHERE created_at >= DATE_SUB(NOW(), INTERVAL 24 HOUR)
UNION ALL
SELECT 
    'Last 7 Days',
    COUNT(*)
FROM emoji_usage
WHERE created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY);

-- =====================================================
-- STEP 10: Manual UPDATE test (for specific user)
-- =====================================================
-- Replace 37 with your actual user_id and 'joy_pineapple_02' with actual emoji code
-- 
-- First check if feeling exists:
-- SELECT * FROM emoji_usage 
-- WHERE user_id = 37 
--   AND post_type IS NULL 
--   AND post_id IS NULL 
-- ORDER BY created_at DESC 
-- LIMIT 1;
--
-- If exists, update it:
-- UPDATE emoji_usage 
-- SET emoji = 'joy_pineapple_02', 
--     updated_at = NOW()
-- WHERE user_id = 37 
--   AND post_type IS NULL 
--   AND post_id IS NULL
-- ORDER BY created_at DESC
-- LIMIT 1;
--
-- If not exists, insert it:
-- INSERT INTO emoji_usage (user_id, emoji, post_type, post_id)
-- VALUES (37, 'joy_pineapple_02', NULL, NULL);

-- =====================================================
-- Common Issues and Solutions
-- =====================================================
-- 
-- Issue 1: Table doesn't exist
-- Solution: Run CREATE TABLE query above (STEP 1)
--
-- Issue 2: Table exists but no data
-- Solution: 
--   a) Check backend API (emojis.php) - it might not be inserting data
--   b) Check backend API logs for errors
--   c) Verify API endpoint is accessible: https://fruitofthespirit.templateforwebsites.com/api/emojis.php
--   d) Test INSERT manually (STEP 7)
--
-- Issue 3: Data exists but not showing for specific user
-- Solution: 
--   a) Check user_id in query - might be wrong user_id
--   b) Check if data exists for that user (STEP 4)
--   c) Verify API is returning data correctly
--
-- Issue 4: Multiple records for same user (general feeling)
-- Solution: 
--   a) Backend should UPDATE instead of INSERT (see update_emoji_usage_replace_feeling.sql)
--   b) Clean up duplicates using STEP 6
--
-- Issue 5: Data in table but app not showing
-- Solution: 
--   a) Check API endpoint - might not be returning data correctly
--   b) Check Flutter app logs for API errors
--   c) Verify API response format matches expected format
--   d) Check if emoji_details are being populated correctly
--
-- Issue 6: Home page not updating
-- Solution:
--   a) Check if Obx is properly watching userFeeling observable
--   b) Verify userFeeling.value is being updated with new Map reference
--   c) Check Flutter app logs for "Obx rebuild triggered" messages
--   d) Ensure userFeeling.refresh() is being called after updates

-- =====================================================
-- Backend API Requirements (for emojis.php)
-- =====================================================
-- 
-- The backend API should:
-- 1. When post_type and post_id are NULL (general feeling):
--    - Check if user already has a feeling (post_type IS NULL AND post_id IS NULL)
--    - If exists: UPDATE the existing record
--    - If not exists: INSERT new record
--
-- 2. When post_type and post_id are provided (post reaction):
--    - INSERT new record (allow multiple reactions per post)
--
-- See DATABASE_TABLE_STRUCTURE.md for full PHP implementation example

