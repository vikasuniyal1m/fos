# Content Moderation Implementation Plan
## Apple App Store Guideline 1.2 Compliance

**Project:** Fruits of Spirit App  
**Backend:** `E:\Downloads\fruitsofspirit 3\fruitofthespirit` (PHP/MySQL)  
**Frontend:** `E:\Downloads\fruitsofspirit 3\fruitsofspirit` (Flutter/Dart)  
**Date:** January 20, 2026  
**Status:** Planning Phase

---

## 📋 Executive Summary

This document outlines a comprehensive plan to implement User-Generated Content (UGC) moderation features to comply with Apple App Store Guideline 1.2. The implementation will add four critical components without disrupting existing functionality or UI:

1. **EULA/Terms with Zero-Tolerance Policy**
2. **Automated Content Filtering**
3. **User Reporting Mechanism**
4. **User Blocking with Instant Content Removal**

---

## 🎯 Requirements Analysis

### Apple Guideline 1.2 Mandates

| Requirement | Description | Impact |
|------------|-------------|--------|
| **EULA Agreement** | Users must agree to terms prohibiting objectionable content | Backend + Frontend |
| **Content Filtering** | Automated system to filter objectionable content | Backend |
| **User Reporting** | Mechanism for users to flag inappropriate content | Backend + Frontend |
| **User Blocking** | Users can block others + notify developers | Backend + Frontend |
| **Instant Removal** | Blocked users' content removed from feed immediately | Backend + Frontend |

### Current Project Structure

#### Backend (PHP)
- **Location:** `E:\Downloads\fruitsofspirit 3\fruitofthespirit`
- **Database:** MySQL (accessed via `includes/db.php`)
- **API Files:**
  - `api/prayers.php` - Prayer requests
  - `api/comments.php` - Comments system
  - `api/gallery.php` - Photo uploads
  - `api/videos.php` - Video uploads
  - `api/blogs.php` - Blog posts
  - `api/groups.php` - Group posts
  - `api/terms.php` - Terms & Conditions (exists)

#### Frontend (Flutter)
- **Location:** `E:\Downloads\fruitsofspirit 3\fruitsofspirit`
- **Architecture:** GetX for state management
- **Key Directories:**
  - `lib/services/` - API services
  - `lib/screens/` - UI screens
  - `lib/controllers/` - GetX controllers
  - `lib/config/` - Configuration files

#### Existing Moderation Infrastructure
✅ **Already Implemented** (from `UGC_MODERATION_IMPLEMENTATION_GUIDE.md`):
- Report service (`lib/services/report_service.dart`)
- User blocking service (`lib/services/user_blocking_service.dart`)
- Report content screen (`lib/screens/report_content_screen.dart`)
- Blocked users screen (`lib/screens/blocked_users_screen.dart`)
- Backend APIs (`api/report.php`, `api/block_user.php`)
- Content moderation service (`includes/ContentModerationService.php`)

---

## 🗄️ Database Schema Analysis

### Tables Requiring Moderation Columns

Based on code analysis, these tables handle user-generated content:

| Table | Current Status | Moderation Needed |
|-------|---------------|-------------------|
| `prayers` / `prayer_requests` | ✅ Exists | Add moderation columns |
| `comments` | ✅ Exists | Add moderation columns |
| `blog_comments` | ✅ Exists | Add moderation columns |
| `blogs` | ✅ Exists | Add moderation columns |
| `media_items` (photos/videos) | ✅ Exists | Add moderation columns |
| `gallery_comments` | ✅ Exists | Add moderation columns |
| `group_posts` | ✅ Exists | Add moderation columns |
| `group_chat_messages` | ✅ Exists (has status) | Enhance moderation |
| `stories` | Likely exists | Add moderation columns |

### New Tables Required

| Table | Purpose | Status |
|-------|---------|--------|
| `reports` | Store user reports | ⚠️ May exist |
| `user_blocks` | Track blocked users | ⚠️ May exist |
| `moderation_keywords` | Objectionable keywords | ⚠️ May exist |
| `eula_acceptance` | Track EULA acceptances | ❌ New |
| `terms_conditions` | Store terms versions | ✅ Exists (from `api/terms.php`) |

### Columns to Add to Existing Tables

```sql
-- Add to all UGC tables
ALTER TABLE `table_name` ADD COLUMN IF NOT EXISTS:
- `moderation_status` ENUM('pending', 'approved', 'rejected', 'flagged') DEFAULT 'pending'
- `moderation_notes` TEXT NULL
- `moderated_by` INT NULL
- `moderated_at` TIMESTAMP NULL
- `is_flagged` TINYINT(1) DEFAULT 0
- `flag_count` INT DEFAULT 0
```

---

## 🔧 Implementation Strategy

### Phase 1: Database Setup (No UI Impact)

**Objective:** Create all necessary database tables and columns without affecting existing functionality.

#### Step 1.1: Create New Tables
```sql
-- Location: Create new file database_migrations/ugc_moderation_complete.sql

-- 1. Reports table
CREATE TABLE IF NOT EXISTS `reports` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `reporter_user_id` INT NOT NULL,
    `content_type` ENUM('prayer', 'comment', 'blog', 'video', 'photo', 'group_post', 'story') NOT NULL,
    `content_id` INT NOT NULL,
    `reason` VARCHAR(100) NOT NULL,
    `description` TEXT NULL,
    `status` ENUM('pending', 'reviewed', 'dismissed') DEFAULT 'pending',
    `reviewed_by` INT NULL,
    `reviewed_at` TIMESTAMP NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_content` (`content_type`, `content_id`),
    INDEX `idx_reporter` (`reporter_user_id`),
    INDEX `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 2. User blocks table
CREATE TABLE IF NOT EXISTS `user_blocks` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `blocker_user_id` INT NOT NULL,
    `blocked_user_id` INT NOT NULL,
    `reason` TEXT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY `unique_block` (`blocker_user_id`, `blocked_user_id`),
    INDEX `idx_blocker` (`blocker_user_id`),
    INDEX `idx_blocked` (`blocked_user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 3. Moderation keywords table
CREATE TABLE IF NOT EXISTS `moderation_keywords` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `keyword` VARCHAR(255) NOT NULL,
    `severity` ENUM('low', 'medium', 'high', 'severe') DEFAULT 'medium',
    `action` ENUM('allow', 'warn', 'quarantine', 'block') DEFAULT 'warn',
    `is_active` TINYINT(1) DEFAULT 1,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY `unique_keyword` (`keyword`),
    INDEX `idx_severity` (`severity`),
    INDEX `idx_active` (`is_active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 4. EULA acceptance tracking
CREATE TABLE IF NOT EXISTS `eula_acceptance` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `user_id` INT NOT NULL,
    `terms_version` VARCHAR(50) NOT NULL,
    `accepted_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `ip_address` VARCHAR(45) NULL,
    `user_agent` TEXT NULL,
    INDEX `idx_user` (`user_id`),
    INDEX `idx_version` (`terms_version`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

#### Step 1.2: Add Moderation Columns to Existing Tables
```sql
-- Add to prayer_requests
ALTER TABLE `prayer_requests` 
ADD COLUMN IF NOT EXISTS `moderation_status` ENUM('pending', 'approved', 'rejected', 'flagged') DEFAULT 'approved',
ADD COLUMN IF NOT EXISTS `moderation_notes` TEXT NULL,
ADD COLUMN IF NOT EXISTS `moderated_by` INT NULL,
ADD COLUMN IF NOT EXISTS `moderated_at` TIMESTAMP NULL,
ADD COLUMN IF NOT EXISTS `is_flagged` TINYINT(1) DEFAULT 0,
ADD COLUMN IF NOT EXISTS `flag_count` INT DEFAULT 0;

-- Repeat for: comments, blog_comments, blogs, media_items, gallery_comments, 
-- group_posts, group_chat_messages, stories
```

#### Step 1.3: Populate Default Keywords
```sql
-- Insert common objectionable keywords
INSERT INTO `moderation_keywords` (`keyword`, `severity`, `action`) VALUES
-- Severe (block immediately)
('porn', 'severe', 'block'),
('xxx', 'severe', 'block'),
('nude', 'severe', 'block'),
('sex', 'severe', 'block'),
-- High (quarantine for review)
('hate', 'high', 'quarantine'),
('kill', 'high', 'quarantine'),
('spam', 'high', 'quarantine'),
-- Medium (warn and sanitize)
('damn', 'medium', 'warn'),
('hell', 'medium', 'warn');
-- Add more as needed
```

**Impact:** ✅ Zero impact on existing functionality. All columns have defaults.

---

### Phase 2: Backend Implementation (API Layer)

**Objective:** Implement content filtering, reporting, and blocking APIs without breaking existing endpoints.

#### Step 2.1: Create Content Moderation Service

**File:** `includes/ContentModerationService.php` (may already exist)

**Functionality:**
- Keyword matching and filtering
- Severity-based actions (allow, warn, quarantine, block)
- Content sanitization (replace bad words with ***)
- Admin notifications

**Key Methods:**
```php
class ContentModerationService {
    public static function checkContent($content)
    public static function sanitizeContent($content)
    public static function updateModerationStatus($table, $id, $status, $notes)
    public static function notifyAdmins($contentType, $contentId, $reason)
}
```

**Integration Points:**
- `api/prayers.php` → `handleCreatePrayer()`
- `api/comments.php` → `handleAddComment()`
- `api/blogs.php` → Blog creation
- `api/gallery.php` → `handleUploadPhoto()`
- `api/videos.php` → Video upload
- `api/groups.php` → Group post creation

**Implementation Approach:**
```php
// In handleCreatePrayer() - BEFORE database insert
require_once '../includes/ContentModerationService.php';

$moderationResult = ContentModerationService::checkContent($content);

switch ($moderationResult['action']) {
    case 'block':
        http_response_code(400);
        echo jsonResponse(false, 'Content violates community guidelines');
        return;
    
    case 'quarantine':
        $status = 'Pending'; // Set to pending for manual review
        $content = $moderationResult['sanitized_content'];
        break;
    
    case 'warn':
        $content = $moderationResult['sanitized_content'];
        break;
    
    case 'allow':
    default:
        // Continue normally
        break;
}

// Continue with existing database insert logic
```

**Impact:** ✅ Minimal. Existing content creation flows enhanced with filtering.

---

#### Step 2.2: Reporting API

**File:** `api/report.php` (may already exist)

**Endpoints:**
- `POST /api/report.php` - Submit report
- `GET /api/report.php?user_id=X` - Get user's reports

**Request Format:**
```json
{
    "user_id": 123,
    "content_type": "prayer",
    "content_id": 456,
    "reason": "spam",
    "description": "Optional details"
}
```

**Response:**
```json
{
    "success": true,
    "message": "Content reported successfully",
    "data": {
        "report_id": 789
    }
}
```

**Actions:**
1. Validate user and content exist
2. Check for duplicate reports
3. Insert into `reports` table
4. Flag content (`is_flagged=1`, increment `flag_count`)
5. Notify admins if threshold reached (e.g., 3 reports)

**Impact:** ✅ New endpoint, no changes to existing APIs.

---

#### Step 2.3: User Blocking API

**File:** `api/block_user.php` (may already exist)

**Endpoints:**
- `POST /api/block_user.php?action=block` - Block user
- `POST /api/block_user.php?action=unblock` - Unblock user
- `GET /api/block_user.php?user_id=X` - Get blocked users list

**Request Format (Block):**
```json
{
    "blocker_user_id": 123,
    "blocked_user_id": 456,
    "reason": "Harassment"
}
```

**Actions:**
1. Prevent self-blocking
2. Insert into `user_blocks` table
3. Notify developers via email/log
4. Auto-flag recent content from blocked user

**Impact:** ✅ New endpoint, no changes to existing APIs.

---

#### Step 2.4: Content Filtering in List APIs

**Objective:** Filter out blocked users' content from feeds.

**Files to Modify:**
- `api/prayers.php` → `handleGetPrayers()`
- `api/comments.php` → `handleGetComments()`
- `api/gallery.php` → `handleGetGallery()`
- `api/videos.php` → Video listing
- `api/blogs.php` → Blog listing

**Implementation:**
```php
// Add to WHERE clause
WHERE ... 
AND pr.user_id NOT IN (
    SELECT blocked_user_id 
    FROM user_blocks 
    WHERE blocker_user_id = ?
)
```

**Impact:** ⚠️ Moderate. Requires SQL query modifications but doesn't break existing functionality.

---

#### Step 2.5: Terms & Conditions API Enhancement

**File:** `api/terms.php` (already exists)

**Enhancements Needed:**
1. Add EULA acceptance endpoint
2. Update terms content with zero-tolerance policy
3. Version management

**New Endpoint:**
```php
// POST /api/terms.php?action=accept
{
    "user_id": 123,
    "terms_version": "1.2",
    "ip_address": "192.168.1.1",
    "user_agent": "..."
}
```

**Updated Terms Content:**
```
Zero-Tolerance Policy for Objectionable Content

We do not tolerate:
- Hate speech or discrimination
- Nudity or sexual content
- Spam or misleading content
- Harassment or bullying
- Violence or threats
- Misinformation

Violations will result in:
- Immediate content removal
- Account suspension
- Permanent ban for severe violations

User Safety Tools:
- Report objectionable content
- Block abusive users
- Content filtering system
```

**Impact:** ✅ Enhancement to existing API, backward compatible.

---

### Phase 3: Frontend Implementation (Flutter)

**Objective:** Add UI components for reporting, blocking, and terms acceptance without disrupting existing screens.

#### Step 3.1: Services Layer

**Files to Check/Create:**
- `lib/services/report_service.dart` (may exist)
- `lib/services/user_blocking_service.dart` (may exist)
- `lib/services/terms_service.dart` (new)

**New Service: `terms_service.dart`**
```dart
class TermsService {
  static Future<bool> hasAcceptedLatestTerms(int userId);
  static Future<void> acceptTerms(int userId, String version);
  static Future<String> getLatestTermsContent();
}
```

**Impact:** ✅ New files, no changes to existing services.

---

#### Step 3.2: UI Screens

**Files to Check/Create:**
- `lib/screens/report_content_screen.dart` (may exist)
- `lib/screens/blocked_users_screen.dart` (may exist)
- `lib/screens/terms_acceptance_screen.dart` (new)

**New Screen: Terms Acceptance**
- Full-screen modal on first launch
- Checkbox: "I agree to Terms & Conditions"
- Link to view full terms
- Cannot proceed without acceptance
- Stored in local storage + backend

**Impact:** ✅ New screen, shown only on first launch.

---

#### Step 3.3: Integration into Existing Screens

**Approach:** Add menu items and buttons without changing existing layouts.

##### 3.3.1: Prayer Screens
**Files:**
- `lib/screens/prayer_details_screen.dart`
- `lib/screens/home_screen.dart` (prayer cards)

**Changes:**
```dart
// Add to three-dot menu (PopupMenuButton)
PopupMenuItem(
  child: Text('Report as spam'),
  onTap: () => Get.to(() => ReportContentScreen(
    contentType: 'prayer',
    contentId: prayer.id,
    contentPreview: prayer.content,
  )),
),
```

**Impact:** ✅ Minimal. Adds menu item to existing dropdown.

---

##### 3.3.2: Create Prayer Screen
**File:** `lib/screens/create_prayer_screen.dart`

**Changes:**
```dart
// Add info box before submit button
Container(
  padding: EdgeInsets.all(12),
  decoration: BoxDecoration(
    color: Colors.orange.shade50,
    borderRadius: BorderRadius.circular(8),
  ),
  child: Row(
    children: [
      Icon(Icons.info_outline, color: Colors.orange),
      SizedBox(width: 8),
      Expanded(
        child: Text(
          'Content violating our terms will be removed immediately.',
          style: TextStyle(fontSize: 12),
        ),
      ),
      TextButton(
        child: Text('Terms'),
        onTap: () => Get.to(() => TermsScreen()),
      ),
    ],
  ),
),
```

**Impact:** ✅ Minimal. Adds informational widget above submit button.

---

##### 3.3.3: Profile Screen
**File:** `lib/screens/profile_screen.dart`

**Changes:**
```dart
// Add to settings list
ListTile(
  leading: Icon(Icons.block),
  title: Text('Blocked Users'),
  trailing: Icon(Icons.chevron_right),
  onTap: () => Get.to(() => BlockedUsersScreen()),
),
```

**Impact:** ✅ Minimal. Adds new menu item to settings.

---

##### 3.3.4: User Profile View
**File:** `lib/screens/view_profile.dart` (or similar)

**Changes:**
```dart
// Add block button to user profile
IconButton(
  icon: Icon(Icons.block),
  onPressed: () async {
    await UserBlockingService.blockUser(
      blockerUserId: currentUserId,
      blockedUserId: profileUserId,
    );
    Get.back(); // Return to previous screen
  },
),
```

**Impact:** ✅ Minimal. Adds icon button to profile header.

---

#### Step 3.4: App Initialization Flow

**File:** `lib/main.dart` or initial route controller

**Changes:**
```dart
// Check terms acceptance on app start
Future<void> checkTermsAcceptance() async {
  final userId = await UserStorage.getUserId();
  final hasAccepted = await TermsService.hasAcceptedLatestTerms(userId);
  
  if (!hasAccepted) {
    Get.to(() => TermsAcceptanceScreen(), preventDuplicates: false);
  }
}

// Call in initState or onReady
@override
void onReady() {
  super.onReady();
  checkTermsAcceptance();
}
```

**Impact:** ⚠️ Moderate. Adds check on app launch, but only shows screen if needed.

---

### Phase 4: Content Filtering Integration

**Objective:** Automatically filter blocked users' content from all feeds.

#### Step 4.1: Controller-Level Filtering

**Files to Modify:**
- `lib/controllers/prayers_controller.dart`
- `lib/controllers/gallery_controller.dart`
- `lib/controllers/videos_controller.dart`
- `lib/controllers/blogs_controller.dart`

**Implementation:**
```dart
// In loadPrayers() or similar methods
Future<void> loadPrayers() async {
  final blockedUserIds = await UserBlockingService.getBlockedUserIds();
  
  // Pass to API
  final response = await http.get(
    '${ApiConfig.prayers}?blocked_users=${blockedUserIds.join(',')}',
  );
  
  // Or filter client-side
  final prayers = prayersFromJson(response.body);
  final filteredPrayers = prayers.where(
    (p) => !blockedUserIds.contains(p.userId)
  ).toList();
  
  this.prayers.value = filteredPrayers;
}
```

**Impact:** ⚠️ Moderate. Modifies data loading logic but doesn't change UI.

---

### Phase 5: Testing & Validation

**Objective:** Ensure all features work without breaking existing functionality.

#### Test Cases

##### 5.1: Database Tests
- [ ] All new tables created successfully
- [ ] All moderation columns added to existing tables
- [ ] Default values work correctly
- [ ] Indexes created for performance

##### 5.2: Backend API Tests
- [ ] Content filtering blocks severe keywords
- [ ] Content filtering sanitizes medium keywords
- [ ] Reporting API creates reports
- [ ] Blocking API blocks users
- [ ] Blocked users' content filtered from feeds
- [ ] Terms acceptance API works

##### 5.3: Frontend Tests
- [ ] Terms acceptance screen shows on first launch
- [ ] Report button appears in all content screens
- [ ] Block button appears in user profiles
- [ ] Blocked users screen shows blocked users
- [ ] Unblock functionality works
- [ ] Blocked content disappears from feeds

##### 5.4: Integration Tests
- [ ] Create prayer with bad words → blocked
- [ ] Create prayer with mild words → sanitized
- [ ] Report content → appears in reports table
- [ ] Block user → content disappears from feed
- [ ] Unblock user → content reappears

##### 5.5: Regression Tests
- [ ] Existing prayer creation still works
- [ ] Existing comment system still works
- [ ] Existing gallery upload still works
- [ ] Existing user profiles still work
- [ ] No UI layout breaks

---

## 📊 Implementation Timeline

| Phase | Duration | Dependencies | Risk Level |
|-------|----------|--------------|------------|
| **Phase 1: Database** | 2-3 hours | None | Low |
| **Phase 2: Backend APIs** | 1-2 days | Phase 1 | Medium |
| **Phase 3: Frontend UI** | 2-3 days | Phase 2 | Medium |
| **Phase 4: Filtering** | 1 day | Phase 2, 3 | High |
| **Phase 5: Testing** | 2-3 days | All phases | Low |
| **Total** | 7-10 days | - | - |

---

## 🚨 Risk Assessment

### High Risk Areas

1. **SQL Query Modifications** (Phase 2.4, 4.1)
   - **Risk:** Breaking existing list APIs
   - **Mitigation:** 
     - Test thoroughly with existing data
     - Use optional parameters (backward compatible)
     - Add feature flags to enable/disable filtering

2. **Content Filtering Logic** (Phase 2.1)
   - **Risk:** False positives blocking legitimate content
   - **Mitigation:**
     - Start with conservative keyword list
     - Use quarantine (manual review) for medium severity
     - Only auto-block severe violations
     - Admin dashboard to review flagged content

3. **App Initialization Flow** (Phase 3.4)
   - **Risk:** Blocking users from accessing app
   - **Mitigation:**
     - Cache terms acceptance locally
     - Only check on major version updates
     - Provide skip option for existing users

### Medium Risk Areas

1. **Database Migrations**
   - **Risk:** Column additions failing on production
   - **Mitigation:**
     - Use `IF NOT EXISTS` clauses
     - Test on staging database first
     - Have rollback scripts ready

2. **API Backward Compatibility**
   - **Risk:** Breaking mobile apps in production
   - **Mitigation:**
     - Make all new parameters optional
     - Maintain existing response formats
     - Version APIs if needed

### Low Risk Areas

1. **New Screens** - No impact on existing functionality
2. **New Services** - Isolated from existing code
3. **Menu Items** - Additive changes only

---

## 🛡️ Safety Measures

### 1. Feature Flags
```php
// config.php
define('ENABLE_CONTENT_FILTERING', true);
define('ENABLE_USER_BLOCKING', true);
define('ENABLE_REPORTING', true);

// In APIs
if (ENABLE_CONTENT_FILTERING) {
    $moderationResult = ContentModerationService::checkContent($content);
    // ...
}
```

### 2. Gradual Rollout
1. Deploy database changes first (no impact)
2. Deploy backend APIs (feature flagged off)
3. Test APIs manually
4. Enable feature flags
5. Deploy frontend updates
6. Monitor for issues

### 3. Rollback Plan
```sql
-- Rollback script
ALTER TABLE `prayer_requests` 
DROP COLUMN IF EXISTS `moderation_status`,
DROP COLUMN IF EXISTS `moderation_notes`,
DROP COLUMN IF EXISTS `moderated_by`,
DROP COLUMN IF EXISTS `moderated_at`,
DROP COLUMN IF EXISTS `is_flagged`,
DROP COLUMN IF EXISTS `flag_count`;

DROP TABLE IF EXISTS `reports`;
DROP TABLE IF EXISTS `user_blocks`;
DROP TABLE IF EXISTS `moderation_keywords`;
DROP TABLE IF EXISTS `eula_acceptance`;
```

### 4. Monitoring
- Log all moderation actions
- Track false positive rate
- Monitor API response times
- Alert on high report volumes

---

## 📁 File Structure

### Backend Files

```
fruitofthespirit/
├── api/
│   ├── report.php                    [NEW or MODIFY]
│   ├── block_user.php                [NEW or MODIFY]
│   ├── terms.php                     [MODIFY]
│   ├── prayers.php                   [MODIFY]
│   ├── comments.php                  [MODIFY]
│   ├── gallery.php                   [MODIFY]
│   ├── videos.php                    [MODIFY]
│   └── blogs.php                     [MODIFY]
├── includes/
│   ├── ContentModerationService.php  [NEW or MODIFY]
│   └── db.php                        [NO CHANGE]
└── database_migrations/
    └── ugc_moderation_complete.sql   [NEW]
```

### Frontend Files

```
fruitsofspirit/
├── lib/
│   ├── services/
│   │   ├── report_service.dart              [NEW or VERIFY]
│   │   ├── user_blocking_service.dart       [NEW or VERIFY]
│   │   └── terms_service.dart               [NEW]
│   ├── screens/
│   │   ├── report_content_screen.dart       [NEW or VERIFY]
│   │   ├── blocked_users_screen.dart        [NEW or VERIFY]
│   │   ├── terms_acceptance_screen.dart     [NEW]
│   │   ├── create_prayer_screen.dart        [MODIFY]
│   │   ├── prayer_details_screen.dart       [MODIFY]
│   │   ├── home_screen.dart                 [MODIFY]
│   │   └── profile_screen.dart              [MODIFY]
│   ├── controllers/
│   │   ├── prayers_controller.dart          [MODIFY]
│   │   ├── gallery_controller.dart          [MODIFY]
│   │   └── videos_controller.dart           [MODIFY]
│   ├── config/
│   │   └── api_config.dart                  [MODIFY]
│   └── main.dart                            [MODIFY]
└── CONTENT_MODERATION_IMPLEMENTATION_PLAN.md [THIS FILE]
```

---

## 🎯 Success Criteria

### Functional Requirements
- [ ] Users can report objectionable content
- [ ] Users can block other users
- [ ] Blocked users' content is hidden from feeds
- [ ] Severe content is auto-blocked
- [ ] Moderate content is sanitized
- [ ] Terms acceptance required on first launch
- [ ] Admin notifications for flagged content

### Non-Functional Requirements
- [ ] No existing functionality broken
- [ ] No UI layout changes (except new screens)
- [ ] API response times unchanged (<10% degradation)
- [ ] Database queries optimized (indexes added)
- [ ] All changes backward compatible
- [ ] Rollback possible within 5 minutes

### Compliance Requirements
- [ ] EULA with zero-tolerance policy ✅
- [ ] Automated content filtering ✅
- [ ] User reporting mechanism ✅
- [ ] User blocking with instant removal ✅
- [ ] Developer notifications ✅

---

## 📞 Support & Documentation

### For Developers
- **Backend:** All filtering logic in `ContentModerationService.php`
- **Frontend:** Services in `lib/services/`
- **Database:** Migration script in `database_migrations/`

### For Administrators
- **Reports:** Check `reports` table in database
- **Blocked Users:** Check `user_blocks` table
- **Flagged Content:** Query tables with `is_flagged=1`
- **Keywords:** Manage in `moderation_keywords` table

### For Users
- **Report:** Three-dot menu on any content
- **Block:** User profile → Block button
- **Unblock:** Profile → Blocked Users → Unblock
- **Terms:** Settings → Terms & Conditions

---

## 🔄 Next Steps

1. **Review this plan** with development team
2. **Verify existing implementation** (check if files from `UGC_MODERATION_IMPLEMENTATION_GUIDE.md` exist)
3. **Create database migration script** (Phase 1)
4. **Test on staging environment**
5. **Implement backend APIs** (Phase 2)
6. **Implement frontend UI** (Phase 3)
7. **Integration testing** (Phase 4)
8. **Production deployment** (Phase 5)

---

## 📝 Notes

- This plan assumes MySQL database (based on code analysis)
- All SQL uses `IF NOT EXISTS` for safety
- Feature flags allow gradual rollout
- Backward compatibility maintained throughout
- No breaking changes to existing APIs
- UI changes are additive only (new menu items, buttons)
- Existing screens remain unchanged in layout

---

**Status:** ✅ Plan Complete - Ready for Implementation  
**Last Updated:** January 20, 2026  
**Version:** 1.0
