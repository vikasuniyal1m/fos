# 🎯 EXACT FILE-BY-FILE IMPLEMENTATION GUIDE
## Backend + Frontend Changes with Line Numbers

**Backend Path:** `E:\Downloads\fruitsofspirit 3\fruitofthespirit`  
**Frontend Path:** `E:\Downloads\fruitsofspirit 3\fruitsofspirit`  
**Date:** January 20, 2026

---

## 📁 PART 1: BACKEND CHANGES

### Step 1: Create New File - ContentModerationService.php

**Location:** `E:\Downloads\fruitsofspirit 3\fruitofthespirit\includes\ContentModerationService.php`

**Status:** ❌ NEW FILE (Create this)

**Purpose:** Central moderation logic for all content

**Complete Code:**
```php
<?php
/**
 * Content Moderation Service
 * Handles keyword filtering, content sanitization, and moderation actions
 */

class ContentModerationService {
    
    /**
     * Check content against moderation keywords
     * @param string $content - Content to check
     * @param mysqli $conn - Database connection
     * @return array ['action' => 'allow|warn|quarantine|block', 'sanitized_content' => string, 'matched_keywords' => array]
     */
    public static function checkContent($content, $conn) {
        // Get active keywords from database
        $keywords_query = "SELECT keyword, severity, action FROM moderation_keywords WHERE is_active = 1";
        $result = $conn->query($keywords_query);
        
        $matched_keywords = [];
        $highest_severity = 'allow';
        $highest_action = 'allow';
        
        $severity_order = ['allow' => 0, 'warn' => 1, 'quarantine' => 2, 'block' => 3];
        
        while ($row = $result->fetch_assoc()) {
            $keyword = $row['keyword'];
            $pattern = '/\b' . preg_quote($keyword, '/') . '\b/i';
            
            if (preg_match($pattern, $content)) {
                $matched_keywords[] = [
                    'keyword' => $keyword,
                    'severity' => $row['severity'],
                    'action' => $row['action']
                ];
                
                // Track highest severity action
                if ($severity_order[$row['action']] > $severity_order[$highest_action]) {
                    $highest_action = $row['action'];
                    $highest_severity = $row['severity'];
                }
            }
        }
        
        return [
            'action' => $highest_action,
            'severity' => $highest_severity,
            'matched_keywords' => $matched_keywords,
            'sanitized_content' => self::sanitizeContent($content, $matched_keywords)
        ];
    }
    
    /**
     * Sanitize content by replacing bad words with asterisks
     * @param string $content - Original content
     * @param array $matched_keywords - Keywords to sanitize
     * @return string - Sanitized content
     */
    public static function sanitizeContent($content, $matched_keywords) {
        foreach ($matched_keywords as $match) {
            if ($match['action'] === 'warn' || $match['action'] === 'quarantine') {
                $keyword = $match['keyword'];
                $replacement = str_repeat('*', strlen($keyword));
                $pattern = '/\b' . preg_quote($keyword, '/') . '\b/i';
                $content = preg_replace($pattern, $replacement, $content);
            }
        }
        return $content;
    }
    
    /**
     * Update moderation status in database
     * @param string $table - Table name
     * @param int $id - Content ID
     * @param string $status - Moderation status
     * @param string $notes - Moderation notes
     * @param mysqli $conn - Database connection
     */
    public static function updateModerationStatus($table, $id, $status, $notes, $conn) {
        $status_column = ($table === 'comments') ? 'status' : 'moderation_status';
        
        $sql = "UPDATE {$table} 
                SET {$status_column} = ?, 
                    moderation_notes = ?, 
                    moderated_at = NOW() 
                WHERE id = ?";
        
        $stmt = $conn->prepare($sql);
        $stmt->bind_param("ssi", $status, $notes, $id);
        $stmt->execute();
    }
    
    /**
     * Increment flag count
     * @param string $table - Table name
     * @param int $id - Content ID
     * @param mysqli $conn - Database connection
     */
    public static function incrementFlagCount($table, $id, $conn) {
        $sql = "UPDATE {$table} SET flag_count = flag_count + 1 WHERE id = ?";
        $stmt = $conn->prepare($sql);
        $stmt->bind_param("i", $id);
        $stmt->execute();
    }
    
    /**
     * Notify admins about flagged content
     * @param string $content_type - Type of content
     * @param int $content_id - Content ID
     * @param string $reason - Reason for flagging
     */
    public static function notifyAdmins($content_type, $content_id, $reason) {
        // Log to error log
        error_log("MODERATION ALERT: {$content_type} ID {$content_id} - Reason: {$reason}");
        
        // TODO: Send email to admin (optional)
        // mail('admin@fruitofthespirit.com', 'Content Flagged', $message);
    }
}
?>
```

---

### Step 2: Modify API Files

#### 2.1: prayers.php

**Location:** `E:\Downloads\fruitsofspirit 3\fruitofthespirit\api\prayers.php`

**Line to Modify:** ~405 (in `handleCreatePrayer` function, BEFORE database insert)

**Changes:**
```php
// EXISTING CODE (Line ~405-428):
function handleCreatePrayer($conn) {
    $user_id = intval($_POST['user_id'] ?? 0);
    $category = trim($_POST['category'] ?? '');
    $content = trim($_POST['content'] ?? '');
    // ... other fields ...
    
    if (!$user_id) {
        http_response_code(400);
        echo jsonResponse(false, 'user_id is required');
        ob_end_flush();
        return;
    }
    
    if (empty($content)) {
        http_response_code(400);
        echo jsonResponse(false, 'Content is required');
        ob_end_flush();
        return;
    }

// ADD THIS CODE HERE (After validation, before user verification):
    
    // ===== CONTENT MODERATION START =====
    require_once '../includes/ContentModerationService.php';
    
    $moderation_result = ContentModerationService::checkContent($content, $conn);
    
    // Handle moderation action
    switch ($moderation_result['action']) {
        case 'block':
            http_response_code(400);
            echo jsonResponse(false, 'Content violates community guidelines. Please review our Terms & Conditions.');
            ob_end_flush();
            return;
            
        case 'quarantine':
            // Will be saved with moderation_status='pending' for manual review
            $moderation_status = 'pending';
            $content = $moderation_result['sanitized_content'];
            $moderation_notes = 'Auto-flagged: ' . implode(', ', array_column($moderation_result['matched_keywords'], 'keyword'));
            break;
            
        case 'warn':
            // Sanitize content but allow posting
            $content = $moderation_result['sanitized_content'];
            $moderation_status = 'approved';
            $moderation_notes = 'Auto-sanitized: ' . implode(', ', array_column($moderation_result['matched_keywords'], 'keyword'));
            break;
            
        case 'allow':
        default:
            $moderation_status = 'approved';
            $moderation_notes = null;
            break;
    }
    // ===== CONTENT MODERATION END =====
    
    // CONTINUE WITH EXISTING CODE (User verification, etc.)
    $user_stmt = $conn->prepare("SELECT id, status FROM users WHERE id = ?");
    // ... rest of the function ...
}

// ALSO MODIFY THE INSERT STATEMENT (Line ~456-466):
// CHANGE FROM:
$stmt = $conn->prepare("INSERT INTO prayer_requests (user_id, category, content, prayer_for, allow_encouragement, is_anonymous, shared_with, tagged_user_id, tagged_group_id, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'Pending')");

// CHANGE TO:
$stmt = $conn->prepare("INSERT INTO prayer_requests (user_id, category, content, prayer_for, allow_encouragement, is_anonymous, shared_with, tagged_user_id, tagged_group_id, status, moderation_status, moderation_notes) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'Pending', ?, ?)");
$stmt->bind_param("issiissiiss", $user_id, $category, $content, $prayer_for, $allow_encouragement, $is_anonymous, $shared_with, $tagged_user_id, $tagged_group_id, $moderation_status, $moderation_notes);
```

**Summary:**
- ✅ Add moderation check after validation (Line ~428)
- ✅ Modify INSERT statement to include moderation fields (Line ~456)

---

#### 2.2: comments.php

**Location:** `E:\Downloads\fruitsofspirit 3\fruitofthespirit\api\comments.php`

**Line to Modify:** ~525 (in `handleAddComment` function)

**Changes:**
```php
// EXISTING CODE (Line ~525-554):
function handleAddComment($conn) {
    $user_id = intval($_POST['user_id'] ?? 0);
    $post_type = trim($_POST['post_type'] ?? '');
    $post_id = intval($_POST['post_id'] ?? 0);
    $content = trim($_POST['content'] ?? '');
    $parent_comment_id = !empty($_POST['parent_comment_id']) ? intval($_POST['parent_comment_id']) : null;
    
    // ... validation code ...
    
    if (empty($content)) {
        error_log("❌ Validation failed: content is empty");
        http_response_code(400);
        echo jsonResponse(false, 'Comment content is required');
        return;
    }

// ADD THIS CODE HERE (After validation):
    
    // ===== CONTENT MODERATION START =====
    require_once '../includes/ContentModerationService.php';
    
    $moderation_result = ContentModerationService::checkContent($content, $conn);
    
    switch ($moderation_result['action']) {
        case 'block':
            http_response_code(400);
            echo jsonResponse(false, 'Comment violates community guidelines.');
            return;
            
        case 'quarantine':
            $comment_status = 'pending';
            $content = $moderation_result['sanitized_content'];
            $moderation_notes = 'Auto-flagged: ' . implode(', ', array_column($moderation_result['matched_keywords'], 'keyword'));
            break;
            
        case 'warn':
            $content = $moderation_result['sanitized_content'];
            $comment_status = 'approved';
            $moderation_notes = 'Auto-sanitized';
            break;
            
        case 'allow':
        default:
            $comment_status = 'approved';
            $moderation_notes = null;
            break;
    }
    // ===== CONTENT MODERATION END =====
    
    // CONTINUE WITH EXISTING CODE...
}

// MODIFY INSERT STATEMENTS (Line ~700-722):
// For non-blog comments, CHANGE FROM:
$stmt = $conn->prepare("INSERT INTO comments (post_type, post_id, user_id, content, status) VALUES (?, ?, ?, ?, 'approved')");

// CHANGE TO:
$stmt = $conn->prepare("INSERT INTO comments (post_type, post_id, user_id, content, status, moderation_notes) VALUES (?, ?, ?, ?, ?, ?)");
$stmt->bind_param("siiss", $post_type, $post_id, $user_id, $content, $comment_status, $moderation_notes);
```

**Summary:**
- ✅ Add moderation check after validation (Line ~554)
- ✅ Modify INSERT statements (Line ~700-722)

---

#### 2.3: gallery.php

**Location:** `E:\Downloads\fruitsofspirit 3\fruitofthespirit\api\gallery.php`

**Line to Modify:** ~644 (in `handleUploadPhoto` function)

**Changes:**
```php
// EXISTING CODE (Line ~654-657):
$testimony = trim($_POST['testimony'] ?? $_REQUEST['testimony'] ?? ''); // Story/testimony behind the image
$feeling_tags = trim($_POST['feeling_tags'] ?? $_REQUEST['feeling_tags'] ?? '');

// ADD THIS CODE HERE (After getting testimony):

// ===== CONTENT MODERATION FOR TESTIMONY =====
if (!empty($testimony)) {
    require_once '../includes/ContentModerationService.php';
    
    $moderation_result = ContentModerationService::checkContent($testimony, $conn);
    
    switch ($moderation_result['action']) {
        case 'block':
            http_response_code(400);
            echo jsonResponse(false, 'Photo description violates community guidelines.');
            return;
            
        case 'quarantine':
            $moderation_status = 'pending';
            $testimony = $moderation_result['sanitized_content'];
            break;
            
        case 'warn':
            $testimony = $moderation_result['sanitized_content'];
            $moderation_status = 'approved';
            break;
            
        case 'allow':
        default:
            $moderation_status = 'approved';
            break;
    }
} else {
    $moderation_status = 'approved';
}
// ===== CONTENT MODERATION END =====
```

**Summary:**
- ✅ Add moderation check for testimony/description (Line ~657)

---

#### 2.4: videos.php

**Location:** `E:\Downloads\fruitsofspirit 3\fruitofthespirit\api\videos.php`

**Similar changes as gallery.php** - Add moderation for video title and description

---

#### 2.5: groups.php

**Location:** `E:\Downloads\fruitsofspirit 3\fruitofthespirit\api\groups.php`

**Find:** Group post creation function

**Add:** Same moderation logic for group post content

---

#### 2.6: group-chat.php

**Location:** `E:\Downloads\fruitsofspirit 3\fruitofthespirit\api\group-chat.php`

**Find:** Message creation function

**Add:** Moderation for chat messages

---

### Step 3: Enhance Existing APIs

#### 3.1: report.php

**Location:** `E:\Downloads\fruitsofspirit 3\fruitofthespirit\api\report.php`

**Check if exists:** ⚠️ May already exist

**If exists, enhance with:**
```php
// After inserting report into content_reports table
// Add this code:

// Increment flag count
$table_map = [
    'prayer' => 'prayer_requests',
    'comment' => 'comments',
    'blog' => 'blogs',
    'video' => 'media_items',
    'photo' => 'media_items',
    'group_post' => 'group_posts',
];

$table = $table_map[$content_type] ?? null;

if ($table) {
    require_once '../includes/ContentModerationService.php';
    ContentModerationService::incrementFlagCount($table, $content_id, $conn);
    
    // Check if threshold reached
    $check_sql = "SELECT flag_count FROM {$table} WHERE id = ?";
    $check_stmt = $conn->prepare($check_sql);
    $check_stmt->bind_param("i", $content_id);
    $check_stmt->execute();
    $result = $check_stmt->get_result()->fetch_assoc();
    
    if ($result['flag_count'] >= 3) {
        // Auto-flag content
        ContentModerationService::updateModerationStatus(
            $table, 
            $content_id, 
            'flagged', 
            'Auto-flagged: Multiple user reports',
            $conn
        );
        
        // Notify admins
        ContentModerationService::notifyAdmins($content_type, $content_id, 'Multiple reports');
    }
}
```

---

#### 3.2: block_user.php

**Location:** `E:\Downloads\fruitsofspirit 3\fruitofthespirit\api\block_user.php`

**Check if exists:** ⚠️ May already exist

**If exists, enhance with:**
```php
// After inserting into user_blocks table
// Add this code:

// Auto-flag recent content from blocked user
$tables = ['blogs', 'comments', 'prayer_requests', 'media_items', 'group_posts', 'group_chat_messages'];

foreach ($tables as $table) {
    $status_column = ($table === 'comments') ? 'status' : 'moderation_status';
    
    $sql = "UPDATE {$table} 
            SET {$status_column} = 'flagged', 
                moderation_notes = CONCAT(COALESCE(moderation_notes, ''), ' | User blocked'),
                flag_count = flag_count + 1
            WHERE user_id = ? 
            AND created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)";
    
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("i", $blocked_user_id);
    $stmt->execute();
}

// Notify developers
ContentModerationService::notifyAdmins('user_block', $blocked_user_id, "User blocked by user ID: $blocker_user_id");
```

---

#### 3.3: Filter Blocked Users in List APIs

**Files to modify:**
1. `api/prayers.php` - Line ~259 (WHERE clause)
2. `api/comments.php` - Line ~222 (WHERE clause)
3. `api/gallery.php` - Line ~238 (WHERE clause)
4. `api/blogs.php` - List function WHERE clause
5. `api/videos.php` - List function WHERE clause

**Add to WHERE clause:**
```php
// Add this to the WHERE clause of list queries
AND table.user_id NOT IN (
    SELECT blocked_user_id 
    FROM user_blocks 
    WHERE user_id = ?
)
```

**Example for prayers.php (Line ~259):**
```php
// CHANGE FROM:
$sql = "SELECT pr.*, u.name as user_name, u.profile_photo,
               (SELECT COUNT(*) FROM comments WHERE $response_count_where) as response_count
        FROM prayer_requests pr
        JOIN users u ON pr.user_id = u.id AND u.status != 'Deleted'
        WHERE pr.status != 'Deleted'";

// CHANGE TO:
$current_user_id = intval($_GET['current_user_id'] ?? 0);

$sql = "SELECT pr.*, u.name as user_name, u.profile_photo,
               (SELECT COUNT(*) FROM comments WHERE $response_count_where) as response_count
        FROM prayer_requests pr
        JOIN users u ON pr.user_id = u.id AND u.status != 'Deleted'
        WHERE pr.status != 'Deleted'";

if ($current_user_id > 0) {
    $sql .= " AND pr.user_id NOT IN (
                SELECT blocked_user_id 
                FROM user_blocks 
                WHERE user_id = ?
              )";
    // Add $current_user_id to bind_param
}
```

---

## 📁 PART 2: FRONTEND CHANGES

### Step 1: Create New Services

#### 1.1: terms_service.dart

**Location:** `E:\Downloads\fruitsofspirit 3\fruitsofspirit\lib\services\terms_service.dart`

**Status:** ❌ NEW FILE

**Complete Code:**
```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:fruitsofspirit/config/api_config.dart';

class TermsService {
  /// Check if user has accepted latest terms
  static Future<bool> hasAcceptedLatestTerms(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/terms.php?action=check_acceptance&user_id=$userId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true && data['data']['has_accepted'] == true;
      }
      return false;
    } catch (e) {
      print('Error checking terms acceptance: $e');
      return false; // Assume not accepted on error
    }
  }

  /// Accept terms
  static Future<bool> acceptTerms(int userId, String version) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/terms.php?action=accept'),
        body: {
          'user_id': userId.toString(),
          'eula_version': version,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('Error accepting terms: $e');
      return false;
    }
  }

  /// Get latest terms content
  static Future<String> getLatestTermsContent() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/terms.php?action=get_latest'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data']['content'] ?? '';
        }
      }
      return '';
    } catch (e) {
      print('Error getting terms content: $e');
      return '';
    }
  }

  /// Get latest terms version
  static Future<String> getLatestVersion() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/terms.php?action=get_latest'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data']['version'] ?? '2.0';
        }
      }
      return '2.0';
    } catch (e) {
      print('Error getting terms version: $e');
      return '2.0';
    }
  }
}
```

---

#### 1.2: Check if report_service.dart exists

**Location:** `E:\Downloads\fruitsofspirit 3\fruitsofspirit\lib\services\report_service.dart`

**Action:** Check if file exists first

**If NOT exists, create with:**
```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:fruitsofspirit/config/api_config.dart';

class ReportService {
  static Future<bool> reportContent({
    required int userId,
    required String contentType,
    required int contentId,
    required String reason,
    String? description,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/report.php'),
        body: {
          'user_id': userId.toString(),
          'content_type': contentType,
          'content_id': contentId.toString(),
          'reason': reason,
          if (description != null) 'description': description,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('Error reporting content: $e');
      return false;
    }
  }

  static List<String> getReportReasons() {
    return [
      'Hate Speech',
      'Nudity or Sexual Content',
      'Spam',
      'Harassment or Bullying',
      'Misinformation',
      'Violence or Threats',
      'Other',
    ];
  }
}
```

---

#### 1.3: Check if user_blocking_service.dart exists

**Location:** `E:\Downloads\fruitsofspirit 3\fruitsofspirit\lib\services\user_blocking_service.dart`

**Action:** Check if file exists first

**If NOT exists, create similar to report_service.dart**

---

### Step 2: Create New Screens

#### 2.1: terms_acceptance_screen.dart

**Location:** `E:\Downloads\fruitsofspirit 3\fruitsofspirit\lib\screens\terms_acceptance_screen.dart`

**Status:** ❌ NEW FILE

**Purpose:** Full-screen modal for terms acceptance on first launch

---

#### 2.2: Check if report_content_screen.dart exists

**Location:** `E:\Downloads\fruitsofspirit 3\fruitsofspirit\lib\screens\report_content_screen.dart`

**Action:** Check if file exists

---

#### 2.3: Check if blocked_users_screen.dart exists

**Location:** `E:\Downloads\fruitsofspirit 3\fruitsofspirit\lib\screens\blocked_users_screen.dart`

**Action:** Check if file exists

---

### Step 3: Modify Existing Screens

#### 3.1: Prayer Details Screen

**Location:** Find prayer details screen (likely `lib/screens/prayer_details_screen.dart` or similar)

**Search for:** `PopupMenuButton` or three-dot menu

**Add:** Report menu item

```dart
PopupMenuItem(
  child: Row(
    children: [
      Icon(Icons.flag, size: 20, color: Colors.red),
      SizedBox(width: 8),
      Text('Report'),
    ],
  ),
  onTap: () {
    Get.to(() => ReportContentScreen(
      contentType: 'prayer',
      contentId: prayer.id,
      contentPreview: prayer.content,
    ));
  },
),
```

---

#### 3.2: Create Prayer Screen

**Location:** Find create prayer screen

**Search for:** Submit button

**Add BEFORE submit button:**
```dart
Container(
  margin: EdgeInsets.only(bottom: 16),
  padding: EdgeInsets.all(12),
  decoration: BoxDecoration(
    color: Colors.orange.shade50,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: Colors.orange.shade200),
  ),
  child: Row(
    children: [
      Icon(Icons.info_outline, color: Colors.orange, size: 20),
      SizedBox(width: 8),
      Expanded(
        child: Text(
          'Content violating our terms will be removed immediately.',
          style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
        ),
      ),
      TextButton(
        child: Text('Terms', style: TextStyle(fontSize: 12)),
        onPressed: () => Get.to(() => TermsScreen()),
      ),
    ],
  ),
),
```

---

#### 3.3: Profile Screen

**Location:** Find profile/settings screen

**Search for:** Settings list or menu items

**Add:**
```dart
ListTile(
  leading: Icon(Icons.block, color: Colors.red),
  title: Text('Blocked Users'),
  trailing: Icon(Icons.chevron_right),
  onTap: () => Get.to(() => BlockedUsersScreen()),
),
```

---

#### 3.4: Main App Initialization

**Location:** `lib/main.dart` or main controller

**Search for:** `onReady()` or `initState()`

**Add:**
```dart
@override
void onReady() {
  super.onReady();
  checkTermsAcceptance();
}

Future<void> checkTermsAcceptance() async {
  final userId = await UserStorage.getUserId();
  if (userId != null && userId > 0) {
    final hasAccepted = await TermsService.hasAcceptedLatestTerms(userId);
    
    if (!hasAccepted) {
      Get.to(() => TermsAcceptanceScreen(), preventDuplicates: false);
    }
  }
}
```

---

## 📊 COMPLETE CHECKLIST

### Backend Files:

- [ ] **NEW:** `includes/ContentModerationService.php`
- [ ] **MODIFY:** `api/prayers.php` (Line ~428, ~456)
- [ ] **MODIFY:** `api/comments.php` (Line ~554, ~700)
- [ ] **MODIFY:** `api/gallery.php` (Line ~657)
- [ ] **MODIFY:** `api/videos.php` (Similar to gallery)
- [ ] **MODIFY:** `api/groups.php` (Group post creation)
- [ ] **MODIFY:** `api/group-chat.php` (Message creation)
- [ ] **CHECK/ENHANCE:** `api/report.php`
- [ ] **CHECK/ENHANCE:** `api/block_user.php`
- [ ] **MODIFY:** All list APIs (prayers, comments, gallery, blogs, videos)

### Frontend Files:

- [ ] **NEW:** `lib/services/terms_service.dart`
- [ ] **CHECK:** `lib/services/report_service.dart`
- [ ] **CHECK:** `lib/services/user_blocking_service.dart`
- [ ] **NEW:** `lib/screens/terms_acceptance_screen.dart`
- [ ] **CHECK:** `lib/screens/report_content_screen.dart`
- [ ] **CHECK:** `lib/screens/blocked_users_screen.dart`
- [ ] **MODIFY:** Prayer details screen (Add report button)
- [ ] **MODIFY:** Create prayer screen (Add terms warning)
- [ ] **MODIFY:** Profile screen (Add blocked users)
- [ ] **MODIFY:** Main app (Add terms check)
- [ ] **MODIFY:** Home screen prayer cards (Add report)
- [ ] **MODIFY:** Comment screens (Add report)
- [ ] **MODIFY:** Blog screens (Add report)
- [ ] **MODIFY:** Gallery screens (Add report)

---

## 🎯 SUMMARY

**Backend:** 10 files to create/modify  
**Frontend:** 13 files to create/modify  
**Total:** 23 files

**Estimated Time:**
- Backend: 8 hours
- Frontend: 8 hours
- Testing: 4 hours
- **Total: 20 hours**

**Ready to start implementation?** 🚀
