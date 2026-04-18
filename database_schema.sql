-- ==========================================================
-- LinkUp - MySQL Database Schema
-- Run this in PHPMyAdmin or your hosting's database manager
-- ==========================================================

-- 1. USERS TABLE
CREATE TABLE `users` (
    `id` VARCHAR(50) PRIMARY KEY, -- Firebase UID or custom UUID
    `name` VARCHAR(100) NOT NULL,
    `email` VARCHAR(150) UNIQUE NOT NULL,
    `avatar` VARCHAR(255) NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. USER FOLLOWERS INTERSECTION TABLE
CREATE TABLE `user_follows` (
    `follower_id` VARCHAR(50),
    `following_id` VARCHAR(50),
    PRIMARY KEY (`follower_id`, `following_id`),
    FOREIGN KEY (`follower_id`) REFERENCES `users`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`following_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
);

-- 3. RESOURCES TABLE
CREATE TABLE `resources` (
    `id` VARCHAR(50) PRIMARY KEY,
    `uploader_id` VARCHAR(50) NOT NULL,
    `title` VARCHAR(255) NOT NULL,
    `subject` VARCHAR(100) NOT NULL,
    `description` TEXT,
    `file_url` VARCHAR(255) NOT NULL, -- The URL from your upload.php
    `file_type` VARCHAR(20) DEFAULT 'pdf',
    `downloads` INT DEFAULT 0,
    `rating` DECIMAL(3,1) DEFAULT 3.0,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`uploader_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
);

-- 4. RESOURCE VOTES TABLE (To track who upvoted/downvoted)
CREATE TABLE `resource_votes` (
    `resource_id` VARCHAR(50),
    `user_id` VARCHAR(50),
    `vote_type` ENUM('upvote', 'downvote') NOT NULL,
    PRIMARY KEY (`resource_id`, `user_id`),
    FOREIGN KEY (`resource_id`) REFERENCES `resources`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
);

-- 5. RESOURCE COMMENTS TABLE
CREATE TABLE `comments` (
    `id` VARCHAR(50) PRIMARY KEY,
    `resource_id` VARCHAR(50) NOT NULL,
    `user_id` VARCHAR(50) NOT NULL,
    `parent_id` VARCHAR(50) NULL, -- Identifies if this is a reply to another comment
    `text` TEXT NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`resource_id`) REFERENCES `resources`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`parent_id`) REFERENCES `comments`(`id`) ON DELETE CASCADE
);

-- 6. RESOURCE BOOKMARKS TABLE
CREATE TABLE `bookmarks` (
    `user_id` VARCHAR(50),
    `resource_id` VARCHAR(50),
    PRIMARY KEY (`user_id`, `resource_id`),
    FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`resource_id`) REFERENCES `resources`(`id`) ON DELETE CASCADE
);

-- 7. FORUM POSTS TABLE
CREATE TABLE `forum_posts` (
    `id` VARCHAR(50) PRIMARY KEY,
    `user_id` VARCHAR(50) NOT NULL,
    `title` VARCHAR(255) NOT NULL,
    `description` TEXT NOT NULL,
    `upvotes` INT DEFAULT 0,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
);

-- 8. FORUM REPLIES TABLE
CREATE TABLE `forum_replies` (
    `id` VARCHAR(50) PRIMARY KEY,
    `post_id` VARCHAR(50) NOT NULL,
    `user_id` VARCHAR(50) NOT NULL,
    `text` TEXT NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`post_id`) REFERENCES `forum_posts`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
);

-- 9. STUDY GROUPS TABLE
CREATE TABLE `study_groups` (
    `id` VARCHAR(50) PRIMARY KEY,
    `name` VARCHAR(100) NOT NULL,
    `description` TEXT,
    `admin_id` VARCHAR(50) NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`admin_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
);

-- 10. GROUP MEMBERS OVERLAP TABLE
CREATE TABLE `group_members` (
    `group_id` VARCHAR(50),
    `user_id` VARCHAR(50),
    PRIMARY KEY (`group_id`, `user_id`),
    FOREIGN KEY (`group_id`) REFERENCES `study_groups`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
);

-- 11. GROUP MESSAGES (CHAT) TABLE
CREATE TABLE `group_messages` (
    `id` VARCHAR(50) PRIMARY KEY,
    `group_id` VARCHAR(50) NOT NULL,
    `user_id` VARCHAR(50) NOT NULL,
    `text` TEXT NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`group_id`) REFERENCES `study_groups`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
);

-- 12. NOTIFICATIONS TABLE
CREATE TABLE `notifications` (
    `id` VARCHAR(50) PRIMARY KEY,
    `user_id` VARCHAR(50) NOT NULL,
    `type` VARCHAR(30) NOT NULL, -- e.g., 'comment', 'upvote', 'reply', 'follow'
    `message` TEXT NOT NULL,
    `is_read` BOOLEAN DEFAULT FALSE,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
);
