import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/utils/app_theme.dart';
import 'package:fruitsofspirit/services/user_blocking_service.dart';
import 'package:fruitsofspirit/services/user_storage.dart';
import 'package:fruitsofspirit/config/image_config.dart';

/// Blocked Users Screen
/// Shows list of users that the current user has blocked
/// Complies with Apple App Store Guideline 1.2
class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({Key? key}) : super(key: key);

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  List<Map<String, dynamic>> blockedUsers = [];
  bool isLoading = true;
  int? currentUserId;

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    setState(() {
      isLoading = true;
    });

    try {
      currentUserId = await UserStorage.getUserId();
      
      if (currentUserId == null) {
        Get.snackbar(
          'Error',
          'Please login to view blocked users',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        Get.back();
        return;
      }

      final users = await UserBlockingService.getBlockedUsers();

      setState(() {
        blockedUsers = users;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      
      Get.snackbar(
        'Error',
        'Failed to load blocked users: ${e.toString().replaceAll('Exception: ', '')}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _unblockUser(int blockedUserId, String userName) async {
    // Show confirmation dialog
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Unblock User'),
        content: Text('Are you sure you want to unblock $userName?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B4CE6),
            ),
            child: const Text('Unblock'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await UserBlockingService.unblockUser(blockedUserId);

      Get.snackbar(
        'Success',
        '$userName has been unblocked',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      // Reload the list
      _loadBlockedUsers();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to unblock user: ${e.toString().replaceAll('Exception: ', '')}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blocked Users'),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
      ),
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryColor,
              ),
            )
          : blockedUsers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.block_outlined,
                        size: AppTheme.spacingXXL,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(height: AppTheme.spacingMD),
                      Text(
                        'No Blocked Users',
                        style: AppTheme.heading3(context).copyWith(color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: AppTheme.spacingSM),
                      Text(
                        'You haven\'t blocked anyone yet',
                        style: AppTheme.bodyMedium(context).copyWith(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadBlockedUsers,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppTheme.spacingMD),
                    itemCount: blockedUsers.length,
                    separatorBuilder: (context, index) => const SizedBox(height: AppTheme.spacingMD),
                    itemBuilder: (context, index) {
                      final user = blockedUsers[index];
                      final userName = user['blocked_user_name'] as String? ?? 'Unknown User';
                      final profilePhoto = user['profile_photo'] as String?;
                      final blockedAt = user['created_at'] as String?;

                      String? profilePhotoUrl;
                      if (profilePhoto != null && profilePhoto.isNotEmpty) {
                        if (profilePhoto.startsWith('http://') || profilePhoto.startsWith('https://')) {
                          profilePhotoUrl = profilePhoto;
                        } else {
                          profilePhotoUrl = '${ImageConfig.baseUrl}/$profilePhoto';
                        }
                      }

                      return Container(
                        decoration: AppTheme.cardDecoration(
                          color: AppTheme.backgroundColor,
                          borderRadius: AppTheme.radiusMD,
                          elevated: true,
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMD, vertical: AppTheme.spacingSM),
                          leading: CircleAvatar(
                            radius: 28,
                            backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                            backgroundImage: profilePhotoUrl != null
                                ? NetworkImage(profilePhotoUrl)
                                : null,
                            child: profilePhotoUrl == null
                                ? Text(
                                    userName[0].toUpperCase(),
                                    style: AppTheme.heading3(context).copyWith(color: AppTheme.primaryColor),
                                  )
                                : null,
                          ),
                          title: Text(
                            userName,
                            style: AppTheme.bodyLarge(context).copyWith(fontWeight: FontWeight.w600),
                          ),
                          subtitle: blockedAt != null
                              ? Text(
                                  'Blocked on ${_formatDate(blockedAt)}',
                                  style: AppTheme.bodySmall(context).copyWith(color: AppTheme.textSecondary),
                                )
                              : null,
                          trailing: ElevatedButton(
                            onPressed: () => _unblockUser(
                              user['blocked_user_id'] as int,
                              userName,
                            ),
                            style: AppTheme.secondaryButtonStyle(
                              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMD, vertical: AppTheme.spacingSM),
                              borderRadius: AppTheme.radiusSM,
                            ),
                            child: const Text('Unblock'),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 30) {
        return '${date.day}/${date.month}/${date.year}';
      } else if (difference.inDays > 0) {
        return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
      } else {
        return 'Today';
      }
    } catch (e) {
      return dateString;
    }
  }
}
