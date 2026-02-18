# Using Your Existing content_reports Table

## ✅ What Was Updated

Since you already have a `content_reports` table, I've updated the implementation to work with your existing structure!

### Your Current Table Structure
```
content_reports:
- id
- user_id (instead of reporter_user_id)
- content_type
- content_id
- reason
- description
- status (currently 'Pending')
- created_at
```

---

## 🔧 Database Migration - Use This File!

**Run this SQL file instead:**
```
database_migrations/update_existing_content_reports.sql
```

This file will:
- ✅ Add missing columns to your `content_reports` table
- ✅ Add performance indexes
- ✅ Create `user_blocks` table (new)
- ✅ Create `moderation_keywords` table (new)
- ✅ Create `eula_acceptance` table (new)
- ✅ Add moderation columns to all content tables
- ✅ Insert default keywords
- ✅ **Won't touch your existing data!**

### How to Run:

**Option 1: Via phpMyAdmin**
1. Open phpMyAdmin
2. Select your database
3. Click "SQL" tab
4. Paste the contents of `update_existing_content_reports.sql`
5. Click "Go"

**Option 2: Via Command Line**
```bash
mysql -u your_username -p your_database < database_migrations/update_existing_content_reports.sql
```

---

## 📝 Updated API Files

The following files have been updated to use `content_reports` (your table name):

### report.php
**Changes:**
- Uses `content_reports` table instead of `reports`
- Uses `user_id` column instead of `reporter_user_id`
- Status values match yours: `'Pending'` (capitalized)

**What This Means:**
Your existing reports (id: 2 and 3) will still work! New reports will be added alongside them.

---

## 🎯 Table Mapping

| API Code | Your Database Table |
|----------|-------------------|
| Reports API | `content_reports` |
| User Blocking | `user_blocks` (new) |
| Keywords Filter | `moderation_keywords` (new) |
| EULA Tracking | `eula_acceptance` (new) |

---

## ✅ What's Compatible

### Your Existing Data
The 2 existing reports in your database:
```
ID 2: User 37 reported comment 258
ID 3: User 37 reported comment 260
```

These will continue to work perfectly! The API will:
- ✅ Read them correctly
- ✅ Not create duplicates
- ✅ Show them in the app

### Your Table Structure
All fields are compatible:
- ✅ `id` - Works
- ✅ `user_id` - API uses this
- ✅ `content_type` - API uses this
- ✅ `content_id` - API uses this
- ✅ `reason` - API uses this
- ✅ `description` - API uses this
- ✅ `status` - API respects 'Pending'
- ✅ `created_at` - API uses this

### New Columns Added (Optional but Recommended)
- `admin_notes` - For admin to add notes
- `reviewed_by` - Which admin reviewed it
- `reviewed_at` - When it was reviewed

---

## 🚀 Quick Test

After running the migration, test the Report API:

```bash
# Submit a new report
curl -X POST https://your-domain.com/api/report.php \
  -d "action=report" \
  -d "user_id=37" \
  -d "content_type=prayer" \
  -d "content_id=1" \
  -d "reason=spam" \
  -d "description=Test report"

# Get user's reports
curl "https://your-domain.com/api/report.php?user_id=37"
```

Expected: You'll see your 2 existing reports PLUS any new ones!

---

## 📊 Status Values

Your database uses: `'Pending'` (capitalized)

The system now supports:
- `'Pending'` - New report, needs review
- `'Reviewed'` - Admin has seen it
- `'Action_Taken'` - Admin took action (deleted content, warned user, etc.)
- `'Dismissed'` - Admin decided no action needed

---

## 🔍 Verify Everything Works

1. **Check Tables Created:**
```sql
SHOW TABLES LIKE '%block%';
SHOW TABLES LIKE '%moderation%';
SHOW TABLES LIKE '%eula%';
```

2. **Check Your Existing Reports:**
```sql
SELECT * FROM content_reports;
```
Expected: Should show your 2 existing reports

3. **Check New Columns:**
```sql
DESCRIBE content_reports;
```
Expected: Should show admin_notes, reviewed_by, reviewed_at

4. **Check Keywords:**
```sql
SELECT COUNT(*) FROM moderation_keywords;
```
Expected: Should show 14 keywords

---

## ⚠️ Important Notes

### 1. Existing Data is Safe
All your existing reports are preserved. The migration only ADDS columns, never removes or changes data.

### 2. Table Name Difference
- Your table: `content_reports`
- Original design: `reports`
- **Solution:** API updated to use `content_reports`

### 3. Column Name Difference
- Your column: `user_id`
- Original design: `reporter_user_id`
- **Solution:** API updated to use `user_id`

### 4. Status Format
- Your format: `'Pending'` (capitalized)
- Original design: `'pending'` (lowercase)
- **Solution:** API updated to use `'Pending'`

---

## 🎉 Summary

✅ **Your existing `content_reports` table works perfectly!**  
✅ **Your 2 existing reports are preserved**  
✅ **API updated to match your structure**  
✅ **New tables created alongside yours**  
✅ **No breaking changes**  

Just run `update_existing_content_reports.sql` and you're good to go!

---

## 🆘 Troubleshooting

### Error: "Column already exists"
**Solution:** Ignore it! The migration uses `IF NOT EXISTS`, so it's safe.

### Error: "Table 'user_blocks' already exists"
**Solution:** That's good! It means it's already created.

### Can't see new columns in phpMyAdmin
**Solution:** Refresh the page or clear your browser cache.

### Existing reports not showing in app
**Solution:** Check that report.php is uploaded to your server.

---

**You're all set! Your existing data + new moderation system = Perfect! 🎯**
