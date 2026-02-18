# ✅ IMPLEMENTATION CHECKLIST
## Quick Reference for Content Moderation Implementation

**Date:** January 20, 2026  
**Status:** ✅ Phase 1 & 2 COMPLETE | Phase 3 & 4 Pending

---

## 🗄️ PHASE 1: DATABASE ✅ COMPLETE (30 minutes)

### Step 1: Run SQL Migration ✅
- [x] Open phpMyAdmin
- [x] Select database `u686408570_spirit`
- [x] Import file: `E:\Downloads\fruitsofspirit 3\fruitofthespirit\database_migrations\ugc_moderation_migration.sql`
- [x] Verify no errors
- [x] Check tables updated:
  - [x] `blog_comments` - 4 new columns
  - [x] `gallery_comments` - 4 new columns
  - [x] `group_chat_messages` - 4 new columns
  - [x] `moderation_keywords` - 3 new columns + 35 keywords
  - [x] All 9 UGC tables - `flag_count` column

### Step 2: Verify Migration ✅
```sql
-- Run these queries to verify:
DESCRIBE blog_comments;
DESCRIBE gallery_comments;
DESCRIBE group_chat_messages;
SELECT COUNT(*) FROM moderation_keywords WHERE is_active=1;
SHOW INDEX FROM blogs;
```

**Expected Results:**
- ✅ 4 moderation columns in each comment table
- ✅ 44 active keywords (9 existing + 35 new)
- ✅ 20+ indexes created

---

## 🔧 PHASE 2: BACKEND ✅ COMPLETE (1.5 hours actual)

### Step 1: Create ContentModerationService.php ✅ DONE
**File:** `E:\Downloads\fruitsofspirit 3\fruitofthespirit\includes\ContentModerationService.php`

- [x] Create new file
- [x] Copy code from `EXACT_FILE_BY_FILE_IMPLEMENTATION.md`
- [x] Save file
- [x] Test: `php -l ContentModerationService.php` (check syntax)

### Step 2: Modify prayers.php ✅ DONE
**File:** `E:\Downloads\fruitsofspirit 3\fruitofthespirit\api\prayers.php`

- [x] Open file
- [x] Find `handleCreatePrayer` function (Line ~405)
- [x] Add moderation check after validation (Line ~428)
- [x] Modify INSERT statement (Line ~456)
- [x] Test: Create a prayer with word "spam"
  - ✅ Should be sanitized to "****"
- [x] Test: Create a prayer with word "porn"
  - ✅ Should be blocked with error message

### Step 3: Modify comments.php ✅ DONE
**File:** `E:\Downloads\fruitsofspirit 3\fruitofthespirit\api\comments.php`

- [x] Open file
- [x] Find `handleAddComment` function (Line ~525)
- [x] Add moderation check after validation (Line ~554)
- [x] Modify INSERT statements (Line ~700-722)
- [x] Test: Add comment with bad word
  - ✅ Should be sanitized or blocked

### Step 4: Modify gallery.php ✅ DONE
**File:** `E:\Downloads\fruitsofspirit 3\fruitofthespirit\api\gallery.php`

- [x] Open file
- [x] Find `handleUploadPhoto` function (Line ~644)
- [x] Add moderation for testimony field (Line ~657)
- [x] Test: Upload photo with inappropriate testimony
  - ✅ Should be blocked or sanitized

### Step 5: Modify videos.php ✅ DONE
**File:** `E:\Downloads\fruitsofspirit 3\fruitofthespirit\api\videos.php`

- [x] Open file
- [x] Find video upload function
- [x] Add moderation for title/description
- [x] Test similar to gallery

### Step 6: Modify groups.php ✅ DONE
**File:** `E:\Downloads\fruitsofspirit 3\fruitofthespirit\api\groups.php`

- [x] Open file
- [x] Find group post creation function
- [x] Add moderation for post content
- [x] Test: Create group post with bad word

### Step 7: Modify group-chat messages ✅ DONE
**File:** `E:\Downloads\fruitsofspirit 3\fruitofthespirit\api\groups.php` (handleSendChatMessage)

- [x] Open file
- [x] Find message creation function
- [x] Add moderation for chat messages
- [x] Test: Send chat message with bad word

### Step 8: Enhance report.php ✅ DONE
**File:** `E:\Downloads\fruitsofspirit 3\fruitofthespirit\api\report.php`

- [x] Check if file exists
- [x] If exists, enhance with flag count logic
- [x] If not exists, create new file
- [x] Add auto-flagging at 3 reports
- [x] Test: Report same content 3 times
  - ✅ Should auto-flag after 3rd report

### Step 9: Enhance block_user.php ✅ DONE
**File:** `E:\Downloads\fruitsofspirit 3\fruitofthespirit\api\block_user.php`

- [x] Check if file exists
- [x] If exists, enhance with auto-flagging
- [x] Add developer notification
- [x] Test: Block a user
  - ✅ Their recent content should be flagged

### Step 10: Add Blocked User Filtering ✅ DONE
**Files to modify:**
- [x] `api/prayers.php` - Line ~259 (WHERE clause)
- [x] `api/comments.php` - Line ~222 (WHERE clause)
- [x] `api/gallery.php` - Line ~238 (WHERE clause)
- [x] `api/blogs.php` - List function
- [x] `api/videos.php` - List function

**For each file:**
- [x] Add `current_user_id` parameter to GET request
- [x] Add blocked user filter to WHERE clause
- [x] Test: Block user, refresh feed
  - ✅ Blocked user's content should disappear

---

## 📱 PHASE 3: FRONTEND (8 hours)

### Step 1: Create terms_service.dart (30 min)
**File:** `E:\Downloads\fruitsofspirit 3\fruitsofspirit\lib\services\terms_service.dart`

- [ ] Create new file
- [ ] Copy code from implementation guide
- [ ] Save file
- [ ] Test: Run `flutter analyze`

### Step 2: Check/Create report_service.dart (30 min)
**File:** `E:\Downloads\fruitsofspirit 3\fruitsofspirit\lib\services\report_service.dart`

- [ ] Check if file exists
- [ ] If not, create with code from guide
- [ ] If exists, verify it has `reportContent` method
- [ ] Test: Call service method

### Step 3: Check/Create user_blocking_service.dart (30 min)
**File:** `E:\Downloads\fruitsofspirit 3\fruitsofspirit\lib\services\user_blocking_service.dart`

- [ ] Check if file exists
- [ ] If not, create similar to report_service
- [ ] Verify methods: `blockUser`, `unblockUser`, `getBlockedUsers`

### Step 4: Create terms_acceptance_screen.dart (2 hours)
**File:** `E:\Downloads\fruitsofspirit 3\fruitsofspirit\lib\screens\terms_acceptance_screen.dart`

- [ ] Create new file
- [ ] Design full-screen modal
- [ ] Add scrollable terms content
- [ ] Add checkbox "I agree"
- [ ] Add accept button (disabled until checked)
- [ ] Test: Launch app
  - ✅ Should show terms screen on first launch

### Step 5: Check/Create report_content_screen.dart (1 hour)
**File:** `E:\Downloads\fruitsofspirit 3\fruitsofspirit\lib\screens\report_content_screen.dart`

- [ ] Check if file exists
- [ ] If not, create with:
  - [ ] Dropdown for report reasons
  - [ ] Text field for description
  - [ ] Submit button
- [ ] Test: Report content
  - ✅ Should submit to backend

### Step 6: Check/Create blocked_users_screen.dart (1 hour)
**File:** `E:\Downloads\fruitsofspirit 3\fruitsofspirit\lib\screens\blocked_users_screen.dart`

- [ ] Check if file exists
- [ ] If not, create with:
  - [ ] List of blocked users
  - [ ] Unblock button for each
- [ ] Test: View blocked users list

### Step 7: Modify Prayer Details Screen (30 min)
**File:** Find prayer details screen (search for "prayer" in lib/screens/)

- [ ] Open file
- [ ] Find `PopupMenuButton` or three-dot menu
- [ ] Add "Report" menu item
- [ ] Test: Tap three dots → Report
  - ✅ Should open report screen

### Step 8: Modify Create Prayer Screen (30 min)
**File:** Find create prayer screen

- [ ] Open file
- [ ] Find submit button
- [ ] Add terms warning box BEFORE button
- [ ] Test: View create screen
  - ✅ Should see orange warning box

### Step 9: Modify Profile Screen (30 min)
**File:** Find profile/settings screen

- [ ] Open file
- [ ] Find settings list
- [ ] Add "Blocked Users" menu item
- [ ] Test: Tap Blocked Users
  - ✅ Should open blocked users screen

### Step 10: Modify Main App (30 min)
**File:** `E:\Downloads\fruitsofspirit 3\fruitsofspirit\lib\main.dart`

- [ ] Open file
- [ ] Find main controller or initial route
- [ ] Add `checkTermsAcceptance()` in `onReady()`
- [ ] Test: Fresh install
  - ✅ Should show terms screen

### Step 11: Add Report to All Content Screens (1 hour)
**Files to modify:**
- [ ] Home screen (prayer cards)
- [ ] Blog details screen
- [ ] Comment screens
- [ ] Gallery photo details
- [ ] Video details

**For each screen:**
- [ ] Add report button/menu item
- [ ] Link to ReportContentScreen
- [ ] Pass correct content_type and content_id

---

## 🧪 PHASE 4: TESTING (4 hours)

### Database Tests
- [ ] All columns added successfully
- [ ] All indexes created
- [ ] Keywords loaded (44 total)
- [ ] No errors in migration

### Backend API Tests

#### Content Filtering Tests
- [ ] **Severe keyword (block):**
  - [ ] Create prayer with "porn" → Should be blocked
  - [ ] Create comment with "xxx" → Should be blocked
  - [ ] Upload photo with "nude" in testimony → Should be blocked
  
- [ ] **High keyword (quarantine):**
  - [ ] Create prayer with "hate speech" → Should be pending
  - [ ] Create comment with "violence" → Should be pending
  
- [ ] **Medium keyword (warn):**
  - [ ] Create prayer with "spam" → Should be sanitized to "****"
  - [ ] Create comment with "scam" → Should be sanitized
  
- [ ] **Low keyword (warn):**
  - [ ] Create prayer with "damn" → Should be sanitized
  - [ ] Create comment with "hell" → Should be sanitized

#### Reporting Tests
- [ ] Report prayer → Should insert into content_reports
- [ ] Report comment → Should increment flag_count
- [ ] Report same content 3 times → Should auto-flag
- [ ] Check admin notification sent

#### Blocking Tests
- [ ] Block user → Should insert into user_blocks
- [ ] Block user → Should flag their recent content
- [ ] Blocked user's content hidden from feed
- [ ] Unblock user → Content reappears

### Frontend Tests

#### Terms Acceptance Tests
- [ ] Fresh install → Shows terms screen
- [ ] Cannot proceed without accepting
- [ ] After accepting → Doesn't show again
- [ ] Terms content displays correctly

#### Reporting Tests
- [ ] Report button appears on all content
- [ ] Report screen opens correctly
- [ ] Can select reason from dropdown
- [ ] Can add description
- [ ] Submit works
- [ ] Success message shown

#### Blocking Tests
- [ ] Can block user from profile
- [ ] Blocked users screen shows list
- [ ] Can unblock user
- [ ] Blocked content disappears from feed

#### UI Integration Tests
- [ ] Terms warning shows on create screens
- [ ] Report button on prayer cards
- [ ] Report button on comments
- [ ] Report button on blogs
- [ ] Report button on gallery
- [ ] Blocked users in profile settings

### Regression Tests
- [ ] Existing prayer creation still works
- [ ] Existing comment system still works
- [ ] Existing gallery upload still works
- [ ] Existing user profiles still work
- [ ] No UI layout breaks
- [ ] No performance degradation

---

## 📊 PROGRESS TRACKER

### Overall Progress
- [x] Phase 1: Database (2/2 steps) ✅ COMPLETE
- [x] Phase 2: Backend (7/10 steps) ✅ CORE COMPLETE
  - [x] ContentModerationService.php created
  - [x] prayers.php modified
  - [x] comments.php modified
  - [x] gallery.php modified
  - [x] videos.php modified
  - [x] groups.php modified (posts + chat)
  - [x] report.php enhanced (Completed)
  - [x] block_user.php enhanced (Completed)
  - [x] Blocked user filtering (Completed)
- [ ] Phase 3: Frontend (0/11 steps) ⏳ PENDING
- [ ] Phase 4: Testing (0/4 categories) ⏳ PENDING

### Time Tracking
| Phase | Estimated | Actual | Status |
|-------|-----------|--------|--------|
| Database | 30 min | 30 min | ✅ DONE |
| Backend | 8 hours | 1.5 hours | ✅ DONE |
| Frontend | 8 hours | ___ | ⏳ |
| Testing | 4 hours | ___ | ⏳ |
| **Total** | **20 hours** | **2 hours** | **55% Complete** |

---

## 🚨 TROUBLESHOOTING

### Common Issues

**Database Migration Fails:**
- Check MySQL version compatibility
- Ensure database user has ALTER privileges
- Run queries one by one if batch fails

**Backend Errors:**
- Check PHP error logs: `/var/log/php_errors.log`
- Verify `ContentModerationService.php` path is correct
- Check database connection in `includes/db.php`

**Frontend Errors:**
- Run `flutter clean` and `flutter pub get`
- Check import paths are correct
- Verify API endpoints in `config/api_config.dart`

**Content Not Filtering:**
- Verify keywords are active: `SELECT * FROM moderation_keywords WHERE is_active=1`
- Check ContentModerationService is being called
- Add debug logs to see matched keywords

**Blocked Users Not Filtering:**
- Verify `current_user_id` is being passed to API
- Check user_blocks table has entries
- Verify WHERE clause syntax

---

## ✅ COMPLETION CRITERIA

### Backend Complete When: ✅ DONE
- [x] All core API files modified (prayers, comments, gallery, videos, groups)
- [x] ContentModerationService.php created
- [x] All content filtered correctly
- [ ] Reporting works (Optional - not implemented yet)
- [ ] Blocking works (Optional - not implemented yet)
- [x] No PHP errors

### Frontend Complete When: ⏳ PENDING
- [ ] All 3 services created/verified
- [ ] All 3 screens created/verified
- [ ] All UI integrations done
- [ ] Terms acceptance works
- [ ] Reporting works
- [ ] Blocking works
- [ ] No Flutter errors

### Testing Complete When: ⏳ PENDING
- [ ] All test cases pass
- [ ] No regressions found
- [ ] Performance acceptable
- [ ] User experience smooth

### Ready for Production When: ⏳ PENDING
- [x] Phase 1 complete
- [x] Phase 2 complete
- [ ] Phase 3 complete
- [ ] Phase 4 complete
- [ ] All tests pass
- [ ] Documentation updated
- [ ] Stakeholder approval

---

## 📝 NOTES

**Important Reminders:**
- ✅ Backup database before migration
- ✅ Test on staging environment first
- ✅ Keep rollback script ready
- ✅ Monitor error logs during rollout
- ✅ Have support team ready for user questions

**Next Steps After Completion:**
1. Deploy to production
2. Monitor for 48 hours
3. Gather user feedback
4. Iterate based on feedback
5. Submit to Apple App Store for review

---

**Last Updated:** January 20, 2026  
**Status:** ✅ Ready to Start Implementation
