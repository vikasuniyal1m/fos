-- =====================================================
-- Migration: Add 'photo' post_type support to Existing Comments Table
-- Date: 2024
-- Description: Adds support for 'photo' post_type in existing comments table
--              to enable comments on gallery photos
-- =====================================================

-- Step 1: Check current post_type column type
-- Run this first to see current structure:
-- DESCRIBE `comments`;
-- SHOW CREATE TABLE `comments`;

-- Step 2: Update comments table to support 'photo' post_type
-- The backend API should validate these post_types:
-- 'prayer', 'blog', 'video', 'photo', 'story', 'gallery'

-- If using ENUM, alter the column to add 'photo':
ALTER TABLE `comments` 
MODIFY COLUMN `post_type` ENUM('prayer', 'blog', 'video', 'photo', 'story', 'gallery') NULL DEFAULT NULL;

-- OR if using VARCHAR (recommended for flexibility), no change needed:
-- VARCHAR already accepts any string value, so 'photo' will work automatically
-- Just ensure backend validation allows it

-- Step 3: Add index for better query performance (if not exists)
CREATE INDEX IF NOT EXISTS `idx_post_type_post_id` ON `comments` (`post_type`, `post_id`);

-- Step 4: Verify the structure
-- DESCRIBE `comments`;

-- =====================================================
-- Expected Comments Table Structure (Reference):
-- =====================================================
-- Your existing comments table should have these columns:
-- - id (INT, PRIMARY KEY, AUTO_INCREMENT)
-- - user_id (INT, FOREIGN KEY to users table)
-- - post_type (VARCHAR or ENUM - needs to accept 'photo')
-- - post_id (INT)
-- - content (TEXT)
-- - parent_comment_id (INT, NULL for top-level comments)
-- - like_count (INT, default 0)
-- - reply_count (INT, default 0)
-- - is_deleted (TINYINT, default 0)
-- - created_at (TIMESTAMP)
-- - updated_at (TIMESTAMP)
--
-- If your table structure differs, adjust the ALTER statement above accordingly

-- =====================================================
-- Supported post_type values:
-- =====================================================
-- 'prayer' - Prayer requests
-- 'blog' - Blog posts
-- 'video' - Video posts
-- 'photo' - Gallery photos (NEW - needs backend support)
-- 'story' - Stories
-- 'gallery' - Gallery (alternative name, if preferred)

-- =====================================================
-- Backend API Changes Required:
-- =====================================================
-- 1. Update comments.php API to accept 'photo' as valid post_type
-- 2. Update validation logic to include 'photo' in allowed post_types
-- 3. Ensure comments can be fetched and created for post_type='photo'
-- 4. Update emojis.php to accept 'photo' for emoji reactions on photos

-- Example validation in PHP:
-- $allowed_post_types = ['prayer', 'blog', 'video', 'photo', 'story', 'gallery'];
-- if (!in_array($post_type, $allowed_post_types)) {
--     throw new Exception('Invalid post_type');
-- }

