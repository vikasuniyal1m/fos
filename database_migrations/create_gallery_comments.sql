-- =====================================================
-- Gallery Comments Table - Complete SQL
-- Run this file to create gallery_comments and gallery_comment_likes tables
-- =====================================================

-- Step 1: Create gallery_comments table
CREATE TABLE IF NOT EXISTS `gallery_comments` (
  `id` INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `photo_id` INT(11) NOT NULL,
  `user_id` INT(11) NOT NULL,
  `content` TEXT NOT NULL,
  `parent_comment_id` INT(11) NULL DEFAULT NULL,
  `like_count` INT(11) DEFAULT 0,
  `reply_count` INT(11) DEFAULT 0,
  `is_deleted` TINYINT(1) DEFAULT 0,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX `idx_photo_id` (`photo_id`),
  INDEX `idx_user_id` (`user_id`),
  INDEX `idx_parent_comment_id` (`parent_comment_id`),
  INDEX `idx_created_at` (`created_at`),
  INDEX `idx_is_deleted` (`is_deleted`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Step 2: Create gallery_comment_likes table
CREATE TABLE IF NOT EXISTS `gallery_comment_likes` (
  `id` INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `comment_id` INT(11) NOT NULL,
  `user_id` INT(11) NOT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY `unique_comment_like` (`comment_id`, `user_id`),
  INDEX `idx_comment_id` (`comment_id`),
  INDEX `idx_user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Done! Tables created successfully.

