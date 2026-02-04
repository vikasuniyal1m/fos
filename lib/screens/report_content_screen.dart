import 'package:flutter/material.dart';
import 'dart:developer';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../services/report_service.dart';
import '../widgets/custom_button.dart';

/// Screen to report inappropriate content
class ReportContentScreen extends StatefulWidget {
  final String contentType;
  final int contentId;

  const ReportContentScreen({
    super.key,
    required this.contentType,
    required this.contentId,
  });

  @override
  State<ReportContentScreen> createState() => _ReportContentScreenState();
}

class _ReportContentScreenState extends State<ReportContentScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  String? _selectedReason;
  bool _isSubmitting = false;
  bool _isCheckingReportStatus = true;

  final List<String> _reasons = [
    'Inappropriate language',
    'Spam or misleading',
    'Hate speech',
    'Harassment',
    'Sexual content',
    'Violence',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    // Skip the report status check since the backend doesn't support the check_report endpoint
    // This avoids unnecessary network requests and errors
    setState(() {
      _isCheckingReportStatus = false;
    });
  }

  Future<void> _submitReport() async {
    if (_selectedReason == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please select a reason for reporting'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final success = await ReportService.reportContent(
        contentType: widget.contentType,
        contentId: widget.contentId,
        reason: _selectedReason!,
        description: _descriptionController.text,
      );

      if (success && mounted) {
        // Show snackbar and then pop the screen after a delay
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Thank you for reporting. Our moderation team will review this content shortly.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        // Use a timer to pop the screen after the snackbar has been visible for a short time
        // This ensures the snackbar has enough time to appear before the screen is removed
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      }
    } catch (e) {
      String errorMessage = 'Failed to submit report. Please try again later.';
      
      // Check if it's a backend database error
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('unknown column') || errorStr.contains('fatal error')) {
        errorMessage = 'Report feature is temporarily unavailable. Our team has been notified and will fix this soon.';
      } else if (errorStr.contains('content already reported')) {
        errorMessage = 'Content already reported. Thank you for your feedback.';
      } else if (errorStr.contains('exception:')) {
        errorMessage = e.toString().replaceAll('Exception: ', '');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
        // Navigate back to previous page after error
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Content'),
        elevation: 0,
      ),
      body: _isCheckingReportStatus
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(20.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Why are you reporting this?',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Text(
                    'Help us maintain a safe community by reporting content that violates our community standards.',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 20.h),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _reasons.length,
                    itemBuilder: (context, index) {
                      final reason = _reasons[index];
                      return RadioListTile<String>(
                        title: Text(reason),
                        value: reason,
                        groupValue: _selectedReason,
                        onChanged: (value) {
                          setState(() => _selectedReason = value);
                        },
                        contentPadding: EdgeInsets.zero,
                      );
                    },
                  ),
                  SizedBox(height: 20.h),
                  Text(
                    'Additional details (Optional)',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Provide more information to help our moderation team...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),
                  SizedBox(height: 40.h),
                  CustomButton(
                    text: 'Submit Report',
                    onPressed: _submitReport,
                    isLoading: _isSubmitting,
                    color: Colors.red,
                  ),
                  SizedBox(height: 20.h),
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
