import 'package:flutter/material.dart';
import '../services/report_service.dart';
import '../screens/report_content_screen.dart';

/// Utility functions for handling content reporting
class ReportUtils {
  /// Handle report button tap
  /// 
  /// This function checks if the content is already reported before navigating
  /// to the report screen. If it is already reported, it shows a snackbar message.
  /// 
  /// [context]: Build context for navigation and snackbar
  /// [contentType]: Type of content being reported
  /// [contentId]: ID of the content being reported
  static Future<void> handleReportButtonTap({
    required BuildContext context,
    required String contentType,
    required int contentId,
  }) async {
    try {
      // Check if content is already reported
      final isAlreadyReported = await ReportService.isContentAlreadyReported(
        contentType: contentType,
        contentId: contentId,
      );
      
      if (isAlreadyReported) {
        // Show message that content is already reported and navigate back
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Content already reported. Thank you for your feedback.'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
          // Navigate back to the previous page
          Navigator.pop(context);
        }
      } else {
        // Navigate to report screen if content is not already reported
        if (context.mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ReportContentScreen(
                contentType: contentType,
                contentId: contentId,
              ),
            ),
          );
        }
      }
    } catch (e) {
      // If check fails, allow user to proceed with reporting
      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ReportContentScreen(
              contentType: contentType,
              contentId: contentId,
            ),
          ),
        );
      }
    }
  }
}