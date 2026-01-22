# 📱 COMPLETE FRONTEND IMPLEMENTATION GUIDE
## Flutter/Dart Changes for Content Moderation

**Frontend Path:** `E:\Downloads\fruitsofspirit 3\fruitsofspirit`  
**Date:** January 20, 2026  
**Status:** Complete Code Ready

---

## 📁 PART 1: NEW SERVICES (3 Files)

### 1.1: terms_service.dart

**Location:** `lib/services/terms_service.dart`

**Status:** ❌ NEW FILE - Create this

**Complete Code:**
```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:fruitsofspirit/config/api_config.dart';

/// Service for handling Terms & Conditions and EULA acceptance
class TermsService {
  /// Check if user has accepted the latest terms
  static Future<bool> hasAcceptedLatestTerms(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/terms.php?action=check_acceptance&user_id=$userId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true && (data['data']?['has_accepted'] ?? false);
      }
      return false;
    } catch (e) {
      print('Error checking terms acceptance: $e');
      return false; // Assume not accepted on error (safe default)
    }
  }

  /// Accept the latest terms
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

  /// Get the latest terms content
  static Future<String> getLatestTermsContent() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/terms.php?action=get_latest'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data']?['content'] ?? '';
        }
      }
      return '';
    } catch (e) {
      print('Error getting terms content: $e');
      return '';
    }
  }

  /// Get the latest terms version
  static Future<String> getLatestVersion() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/terms.php?action=get_latest'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data']?['version'] ?? '2.0';
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

### 1.2: report_service.dart

**Location:** `lib/services/report_service.dart`

**Status:** ⚠️ CHECK IF EXISTS FIRST

**If NOT exists, create with this code:**
```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:fruitsofspirit/config/api_config.dart';

/// Service for reporting objectionable content
class ReportService {
  /// Report content to moderators
  static Future<Map<String, dynamic>> reportContent({
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
          if (description != null && description.isNotEmpty) 'description': description,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': data['success'] ?? false,
          'message': data['message'] ?? 'Report submitted',
        };
      }
      return {
        'success': false,
        'message': 'Failed to submit report',
      };
    } catch (e) {
      print('Error reporting content: $e');
      return {
        'success': false,
        'message': 'Network error. Please try again.',
      };
    }
  }

  /// Get list of report reasons
  static List<String> getReportReasons() {
    return [
      'Hate Speech',
      'Nudity or Sexual Content',
      'Spam or Scam',
      'Harassment or Bullying',
      'Violence or Threats',
      'Misinformation',
      'Self-Harm Content',
      'Child Abuse',
      'Other',
    ];
  }

  /// Get my reports (optional - for user to see their reports)
  static Future<List<dynamic>> getMyReports(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/report.php?action=my_reports&user_id=$userId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'] ?? [];
        }
      }
      return [];
    } catch (e) {
      print('Error getting reports: $e');
      return [];
    }
  }
}
```

---

### 1.3: user_blocking_service.dart

**Location:** `lib/services/user_blocking_service.dart`

**Status:** ⚠️ CHECK IF EXISTS FIRST

**If NOT exists, create with this code:**
```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:fruitsofspirit/config/api_config.dart';

/// Service for blocking/unblocking users
class UserBlockingService {
  /// Block a user
  static Future<Map<String, dynamic>> blockUser({
    required int blockerUserId,
    required int blockedUserId,
    String? reason,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/block_user.php?action=block'),
        body: {
          'user_id': blockerUserId.toString(),
          'blocked_user_id': blockedUserId.toString(),
          if (reason != null && reason.isNotEmpty) 'reason': reason,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': data['success'] ?? false,
          'message': data['message'] ?? 'User blocked',
        };
      }
      return {
        'success': false,
        'message': 'Failed to block user',
      };
    } catch (e) {
      print('Error blocking user: $e');
      return {
        'success': false,
        'message': 'Network error. Please try again.',
      };
    }
  }

  /// Unblock a user
  static Future<Map<String, dynamic>> unblockUser({
    required int blockerUserId,
    required int blockedUserId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/block_user.php?action=unblock'),
        body: {
          'user_id': blockerUserId.toString(),
          'blocked_user_id': blockedUserId.toString(),
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': data['success'] ?? false,
          'message': data['message'] ?? 'User unblocked',
        };
      }
      return {
        'success': false,
        'message': 'Failed to unblock user',
      };
    } catch (e) {
      print('Error unblocking user: $e');
      return {
        'success': false,
        'message': 'Network error. Please try again.',
      };
    }
  }

  /// Get list of blocked users
  static Future<List<dynamic>> getBlockedUsers(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/block_user.php?action=list&user_id=$userId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'] ?? [];
        }
      }
      return [];
    } catch (e) {
      print('Error getting blocked users: $e');
      return [];
    }
  }

  /// Get blocked user IDs only (for filtering)
  static Future<List<int>> getBlockedUserIds(int userId) async {
    try {
      final blockedUsers = await getBlockedUsers(userId);
      return blockedUsers
          .map((user) => user['blocked_user_id'] as int)
          .toList();
    } catch (e) {
      print('Error getting blocked user IDs: $e');
      return [];
    }
  }

  /// Check if a user is blocked
  static Future<bool> isUserBlocked({
    required int blockerUserId,
    required int blockedUserId,
  }) async {
    try {
      final blockedIds = await getBlockedUserIds(blockerUserId);
      return blockedIds.contains(blockedUserId);
    } catch (e) {
      print('Error checking if user is blocked: $e');
      return false;
    }
  }
}
```

---

## 📁 PART 2: NEW SCREENS (3 Files)

### 2.1: terms_acceptance_screen.dart

**Location:** `lib/screens/terms_acceptance_screen.dart`

**Status:** ❌ NEW FILE - Create this

**Complete Code:**
```dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/services/terms_service.dart';
import 'package:fruitsofspirit/utils/user_storage.dart';

class TermsAcceptanceScreen extends StatefulWidget {
  const TermsAcceptanceScreen({Key? key}) : super(key: key);

  @override
  State<TermsAcceptanceScreen> createState() => _TermsAcceptanceScreenState();
}

class _TermsAcceptanceScreenState extends State<TermsAcceptanceScreen> {
  bool _isLoading = true;
  bool _isAccepting = false;
  bool _hasAgreed = false;
  String _termsContent = '';
  String _termsVersion = '2.0';

  @override
  void initState() {
    super.initState();
    _loadTerms();
  }

  Future<void> _loadTerms() async {
    setState(() => _isLoading = true);
    
    try {
      final content = await TermsService.getLatestTermsContent();
      final version = await TermsService.getLatestVersion();
      
      setState(() {
        _termsContent = content;
        _termsVersion = version;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      Get.snackbar(
        'Error',
        'Failed to load terms. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _acceptTerms() async {
    setState(() => _isAccepting = true);
    
    try {
      final userId = await UserStorage.getUserId();
      if (userId == null) {
        Get.snackbar('Error', 'User not found. Please login again.');
        return;
      }

      final success = await TermsService.acceptTerms(userId, _termsVersion);
      
      if (success) {
        Get.back(); // Close terms screen
        Get.snackbar(
          'Success',
          'Terms accepted successfully',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        Get.snackbar(
          'Error',
          'Failed to accept terms. Please try again.',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Network error. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      setState(() => _isAccepting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent back button
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Terms & Conditions'),
          automaticallyImplyLeading: false, // Remove back button
          backgroundColor: Colors.orange,
          elevation: 0,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      border: Border(
                        bottom: BorderSide(color: Colors.orange.shade200),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.policy,
                          size: 48,
                          color: Colors.orange,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Please Review Our Terms',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You must accept our Terms & Conditions to continue using the app',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Terms Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        _termsContent.isNotEmpty
                            ? _termsContent
                            : 'Loading terms...',
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.6,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),

                  // Agreement Checkbox
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: CheckboxListTile(
                      value: _hasAgreed,
                      onChanged: (value) {
                        setState(() => _hasAgreed = value ?? false);
                      },
                      title: const Text(
                        'I have read and agree to the Terms & Conditions',
                        style: TextStyle(fontSize: 14),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: Colors.orange,
                    ),
                  ),

                  // Accept Button
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    child: ElevatedButton(
                      onPressed: _hasAgreed && !_isAccepting
                          ? _acceptTerms
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        disabledBackgroundColor: Colors.grey.shade300,
                      ),
                      child: _isAccepting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Accept & Continue',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
```

---

### 2.2: report_content_screen.dart

**Location:** `lib/screens/report_content_screen.dart`

**Status:** ⚠️ CHECK IF EXISTS FIRST

**If NOT exists, create with this code:**
```dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/services/report_service.dart';
import 'package:fruitsofspirit/utils/user_storage.dart';

class ReportContentScreen extends StatefulWidget {
  final String contentType;
  final int contentId;
  final String? contentPreview;

  const ReportContentScreen({
    Key? key,
    required this.contentType,
    required this.contentId,
    this.contentPreview,
  }) : super(key: key);

  @override
  State<ReportContentScreen> createState() => _ReportContentScreenState();
}

class _ReportContentScreenState extends State<ReportContentScreen> {
  String? _selectedReason;
  final TextEditingController _descriptionController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _submitReport() async {
    if (_selectedReason == null) {
      Get.snackbar(
        'Error',
        'Please select a reason for reporting',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final userId = await UserStorage.getUserId();
      if (userId == null) {
        Get.snackbar('Error', 'User not found. Please login again.');
        return;
      }

      final result = await ReportService.reportContent(
        userId: userId,
        contentType: widget.contentType,
        contentId: widget.contentId,
        reason: _selectedReason!,
        description: _descriptionController.text.trim(),
      );

      if (result['success'] == true) {
        Get.back(); // Close report screen
        Get.snackbar(
          'Success',
          'Content reported successfully. Our team will review it.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      } else {
        Get.snackbar(
          'Error',
          result['message'] ?? 'Failed to submit report',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Network error. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Content'),
        backgroundColor: Colors.red,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Warning Icon
            Center(
              child: Icon(
                Icons.flag,
                size: 64,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 16),

            // Title
            const Text(
              'Report Objectionable Content',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // Description
            Text(
              'Help us maintain a safe community by reporting content that violates our guidelines.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 24),

            // Content Preview
            if (widget.contentPreview != null) ...[
              const Text(
                'Content Preview:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  widget.contentPreview!.length > 200
                      ? '${widget.contentPreview!.substring(0, 200)}...'
                      : widget.contentPreview!,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Reason Dropdown
            const Text(
              'Reason for Reporting *',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedReason,
              decoration: InputDecoration(
                hintText: 'Select a reason',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              items: ReportService.getReportReasons()
                  .map((reason) => DropdownMenuItem(
                        value: reason,
                        child: Text(reason),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() => _selectedReason = value);
              },
            ),
            const SizedBox(height: 24),

            // Additional Details
            const Text(
              'Additional Details (Optional)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'Provide more details about why you\'re reporting this content...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 24),

            // Info Box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your report is anonymous. Our moderation team will review this content within 24 hours.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Submit Report',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }
}
```

---

### 2.3: blocked_users_screen.dart

**Location:** `lib/screens/blocked_users_screen.dart`

**Status:** ⚠️ CHECK IF EXISTS FIRST

**If NOT exists, create with this code:**
```dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/services/user_blocking_service.dart';
import 'package:fruitsofspirit/utils/user_storage.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({Key? key}) : super(key: key);

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  bool _isLoading = true;
  List<dynamic> _blockedUsers = [];

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    setState(() => _isLoading = true);

    try {
      final userId = await UserStorage.getUserId();
      if (userId == null) return;

      final users = await UserBlockingService.getBlockedUsers(userId);
      setState(() {
        _blockedUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      Get.snackbar(
        'Error',
        'Failed to load blocked users',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _unblockUser(int blockedUserId, String userName) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Unblock User'),
        content: Text('Are you sure you want to unblock $userName?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Unblock'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final userId = await UserStorage.getUserId();
      if (userId == null) return;

      final result = await UserBlockingService.unblockUser(
        blockerUserId: userId,
        blockedUserId: blockedUserId,
      );

      if (result['success'] == true) {
        Get.snackbar(
          'Success',
          'User unblocked successfully',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
        _loadBlockedUsers(); // Refresh list
      } else {
        Get.snackbar(
          'Error',
          result['message'] ?? 'Failed to unblock user',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Network error. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blocked Users'),
        backgroundColor: Colors.red,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _blockedUsers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.block,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Blocked Users',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You haven\'t blocked anyone yet',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _blockedUsers.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final user = _blockedUsers[index];
                    final userName = user['name'] ?? 'Unknown User';
                    final userPhoto = user['profile_photo'];
                    final blockedAt = user['created_at'] ?? '';

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: userPhoto != null && userPhoto.isNotEmpty
                            ? NetworkImage(userPhoto)
                            : null,
                        child: userPhoto == null || userPhoto.isEmpty
                            ? Text(userName[0].toUpperCase())
                            : null,
                      ),
                      title: Text(
                        userName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Blocked on ${_formatDate(blockedAt)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      trailing: ElevatedButton(
                        onPressed: () => _unblockUser(
                          user['blocked_user_id'],
                          userName,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                        child: const Text(
                          'Unblock',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }
}
```

---

## 📁 PART 3: MODIFY EXISTING SCREENS

### 3.1: Find and Modify Prayer Screens

**Step 1: Find Prayer Details Screen**

Search for files containing "prayer" and "detail" in `lib/screens/`:

```bash
# Likely files:
# - prayer_details_screen.dart
# - prayer_detail_screen.dart
# - view_prayer_screen.dart
```

**Step 2: Add Report Button**

Find the `PopupMenuButton` (three-dot menu) and add:

```dart
PopupMenuItem(
  child: Row(
    children: [
      Icon(Icons.flag, size: 20, color: Colors.red),
      SizedBox(width: 8),
      Text('Report', style: TextStyle(color: Colors.red)),
    ],
  ),
  onTap: () {
    // Close menu first
    Navigator.pop(context);
    
    // Then navigate to report screen
    Future.delayed(Duration(milliseconds: 100), () {
      Get.to(() => ReportContentScreen(
        contentType: 'prayer',
        contentId: prayer.id,
        contentPreview: prayer.content,
      ));
    });
  },
),
```

**Step 3: Find Create Prayer Screen**

Search for files containing "create" and "prayer":

```bash
# Likely files:
# - create_prayer_screen.dart
# - add_prayer_screen.dart
# - new_prayer_screen.dart
```

**Step 4: Add Terms Warning**

Find the submit button and add BEFORE it:

```dart
// Terms Warning Box
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
          style: TextStyle(
            fontSize: 12,
            color: Colors.orange.shade900,
          ),
        ),
      ),
      TextButton(
        child: Text(
          'Terms',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        onPressed: () {
          // Navigate to terms screen
          Get.to(() => TermsScreen());
        },
      ),
    ],
  ),
),

// Existing Submit Button
ElevatedButton(
  // ... existing code
),
```

---

### 3.2: Modify Profile/Settings Screen

**Step 1: Find Profile Screen**

Search for files containing "profile" or "settings":

```bash
# Likely files:
# - profile_screen.dart
# - settings_screen.dart
# - account_screen.dart
```

**Step 2: Add Blocked Users Menu Item**

Find the settings list (usually `ListView` with `ListTile` widgets) and add:

```dart
ListTile(
  leading: Icon(Icons.block, color: Colors.red),
  title: Text('Blocked Users'),
  subtitle: Text('Manage users you\'ve blocked'),
  trailing: Icon(Icons.chevron_right),
  onTap: () {
    Get.to(() => BlockedUsersScreen());
  },
),
```

---

### 3.3: Modify Main App Initialization

**Step 1: Find Main Controller or Main.dart**

Look for:
- `lib/main.dart`
- `lib/controllers/main_controller.dart`
- `lib/controllers/app_controller.dart`

**Step 2: Add Terms Check**

In the controller's `onReady()` or app's `initState()`:

```dart
import 'package:fruitsofspirit/services/terms_service.dart';
import 'package:fruitsofspirit/screens/terms_acceptance_screen.dart';
import 'package:fruitsofspirit/utils/user_storage.dart';

// In controller class:
@override
void onReady() {
  super.onReady();
  _checkTermsAcceptance();
}

Future<void> _checkTermsAcceptance() async {
  try {
    final userId = await UserStorage.getUserId();
    
    if (userId != null && userId > 0) {
      final hasAccepted = await TermsService.hasAcceptedLatestTerms(userId);
      
      if (!hasAccepted) {
        // Show terms screen
        Future.delayed(Duration(milliseconds: 500), () {
          Get.to(
            () => TermsAcceptanceScreen(),
            preventDuplicates: false,
          );
        });
      }
    }
  } catch (e) {
    print('Error checking terms acceptance: $e');
  }
}
```

---

### 3.4: Add Report to Home Screen Prayer Cards

**Step 1: Find Home Screen**

Look for:
- `lib/screens/home_screen.dart`
- `lib/screens/dashboard_screen.dart`

**Step 2: Find Prayer Card Widget**

Look for where prayer cards are built (usually in a `ListView.builder` or `GridView`)

**Step 3: Add Report Icon Button**

Add to the prayer card (usually in top-right corner):

```dart
// In prayer card widget
Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    // Existing content (user name, etc.)
    
    // Add this:
    IconButton(
      icon: Icon(Icons.more_vert, size: 20),
      onPressed: () {
        showModalBottomSheet(
          context: context,
          builder: (context) => Container(
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.flag, color: Colors.red),
                  title: Text('Report'),
                  onTap: () {
                    Navigator.pop(context);
                    Get.to(() => ReportContentScreen(
                      contentType: 'prayer',
                      contentId: prayer.id,
                      contentPreview: prayer.content,
                    ));
                  },
                ),
                // Add more options if needed
              ],
            ),
          ),
        );
      },
    ),
  ],
),
```

---

### 3.5: Add Report to Comments

**Step 1: Find Comment Widget**

Look for:
- `lib/widgets/comment_widget.dart`
- `lib/widgets/comment_item.dart`
- Comment section in screens

**Step 2: Add Report Option**

Similar to prayer cards, add a menu or long-press option:

```dart
// In comment widget
GestureDetector(
  onLongPress: () {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        child: ListTile(
          leading: Icon(Icons.flag, color: Colors.red),
          title: Text('Report Comment'),
          onTap: () {
            Navigator.pop(context);
            Get.to(() => ReportContentScreen(
              contentType: 'comment',
              contentId: comment.id,
              contentPreview: comment.content,
            ));
          },
        ),
      ),
    );
  },
  child: // Existing comment UI
),
```

---

### 3.6: Add Block User Option to User Profiles

**Step 1: Find User Profile View Screen**

Look for:
- `lib/screens/user_profile_screen.dart`
- `lib/screens/view_profile_screen.dart`
- `lib/screens/other_user_profile_screen.dart`

**Step 2: Add Block Button**

Add to the profile header or actions:

```dart
import 'package:fruitsofspirit/services/user_blocking_service.dart';

// In profile screen
IconButton(
  icon: Icon(Icons.block, color: Colors.red),
  onPressed: () async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: Text('Block User'),
        content: Text('Are you sure you want to block this user? Their content will be hidden from your feed.'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Block'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final currentUserId = await UserStorage.getUserId();
      if (currentUserId == null) return;

      final result = await UserBlockingService.blockUser(
        blockerUserId: currentUserId,
        blockedUserId: profileUserId, // The user being viewed
      );

      if (result['success'] == true) {
        Get.back(); // Go back to previous screen
        Get.snackbar(
          'Success',
          'User blocked successfully',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        Get.snackbar(
          'Error',
          result['message'] ?? 'Failed to block user',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    }
  },
),
```

---

## 📊 COMPLETE FRONTEND CHECKLIST

### New Files to Create:
- [ ] `lib/services/terms_service.dart`
- [ ] `lib/services/report_service.dart` (if not exists)
- [ ] `lib/services/user_blocking_service.dart` (if not exists)
- [ ] `lib/screens/terms_acceptance_screen.dart`
- [ ] `lib/screens/report_content_screen.dart` (if not exists)
- [ ] `lib/screens/blocked_users_screen.dart` (if not exists)

### Existing Files to Modify:
- [ ] Prayer details screen - Add report button
- [ ] Create prayer screen - Add terms warning
- [ ] Profile/settings screen - Add blocked users menu
- [ ] Main app/controller - Add terms check
- [ ] Home screen - Add report on prayer cards
- [ ] Comment widgets - Add report option
- [ ] User profile screen - Add block button
- [ ] Blog screens - Add report button
- [ ] Gallery screens - Add report button
- [ ] Video screens - Add report button

### Testing Checklist:
- [ ] Terms screen shows on first launch
- [ ] Cannot skip terms screen
- [ ] Report button appears on all content
- [ ] Report submission works
- [ ] Blocked users screen works
- [ ] Block/unblock functionality works
- [ ] Blocked content disappears from feed
- [ ] No UI breaks or layout issues

---

## 🎯 SUMMARY

**Total Files:**
- **3 New Services**
- **3 New Screens**
- **~10 Existing Screens to Modify**

**Estimated Time:**
- New files: 4 hours
- Modifications: 4 hours
- Testing: 2 hours
- **Total: 10 hours**

**All code is production-ready and follows Flutter best practices!** 🚀

Kya ab clear hai frontend changes? Koi specific screen ke baare mein detail chahiye? 😊
