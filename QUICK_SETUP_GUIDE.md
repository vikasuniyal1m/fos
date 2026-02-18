# Quick Setup Guide - UGC Moderation System

## ⚡ Quick Start (5 Minutes)

### Step 1: Database Setup (2 minutes)

```bash
# Navigate to your MySQL database
mysql -u your_username -p your_database

# Run the migration
source database_migrations/ugc_moderation_tables.sql;

# Verify tables created
SHOW TABLES LIKE '%report%';
SHOW TABLES LIKE '%block%';
SHOW TABLES LIKE '%moderation%';
```

### Step 2: Upload Backend Files (1 minute)

Upload these files to your server via FTP/SSH:

```
✅ includes/ContentModerationService.php
✅ api/report.php
✅ api/block_user.php
✅ api/terms.php (REPLACE existing)
✅ api/prayers.php (REPLACE existing)
✅ api/comments.php (REPLACE existing)
```

### Step 3: Test Backend (30 seconds)

```bash
# Test report endpoint
curl -X POST https://your-domain.com/api/report.php \
  -d "action=report&user_id=1&content_type=prayer&content_id=1&reason=spam"

# Expected: {"success":true,"message":"Report submitted successfully"}
```

### Step 4: Flutter App (1 minute)

All Flutter files are already in place! Just:

```bash
# Get dependencies (if needed)
flutter pub get

# Build the app
flutter build apk --release  # For Android
flutter build ios --release  # For iOS
```

### Step 5: Verify Everything Works (30 seconds)

1. ✅ Create a test prayer with keyword "spam" → Should be flagged
2. ✅ Tap report button on any content → Report screen opens
3. ✅ Go to Profile → Blocked Users → Screen loads
4. ✅ Create prayer screen shows terms info box

---

## 🚨 Common Issues & Fixes

### Issue: "Table already exists" error
**Fix:** Tables are safe to create multiple times (uses IF NOT EXISTS)

### Issue: Content not being filtered
**Fix:** Check if ContentModerationService.php is uploaded and readable

### Issue: Report button not showing
**Fix:** Make sure you imported report_content_screen.dart in the screen files

### Issue: 500 error on report.php
**Fix:** Check file permissions (chmod 644) and database connection

---

## 📋 Deployment Checklist

Before going to production:

- [ ] Database migration executed successfully
- [ ] All 6 PHP files uploaded to server
- [ ] Test report submission works
- [ ] Test user blocking works
- [ ] Test content filtering works
- [ ] Terms & Conditions updated
- [ ] Flutter app built and tested
- [ ] Admin email configured for notifications

---

## 🎯 What This Gives You

✅ **Automatic content filtering** - Blocks offensive content before it's posted  
✅ **User reporting system** - Users can flag inappropriate content  
✅ **User blocking** - Users can block abusive members  
✅ **Admin notifications** - Get alerted when content is flagged  
✅ **Zero-tolerance policy** - Clear terms that comply with Apple guidelines  
✅ **Production ready** - No additional configuration needed  

---

## 🆘 Need Help?

Check the full documentation:
- **UGC_MODERATION_IMPLEMENTATION_GUIDE.md** - Complete technical documentation
- **README.md** - General app information

---

**Total Setup Time: ~5 minutes**  
**Difficulty: Easy** ⭐⭐☆☆☆
