import 'package:flutter/material.dart';
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

  final List<String> _reasons = [
    'Inappropriate language',
    'Spam or misleading',
    'Hate speech',
    'Harassment',
    'Sexual content',
    'Violence',
    'Other',
  ];

  Future<void> _submitReport() async {
    if (_selectedReason == null) {
      Get.snackbar(
        'Error',
        'Please select a reason for reporting',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
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

      if (success) {
        Get.back();
        Get.snackbar(
          'Success',
          'Thank you for reporting. Our moderation team will review this content shortly.',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      String errorMessage = 'Failed to submit report. Please try again later.';
      
      // Check if it's a backend database error
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('unknown column') || errorStr.contains('fatal error')) {
        errorMessage = 'Report feature is temporarily unavailable. Our team has been notified and will fix this soon.';
      } else if (errorStr.contains('exception:')) {
        errorMessage = e.toString().replaceAll('Exception: ', '');
      }
      
      Get.snackbar(
        'Unable to Submit Report',
        errorMessage,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.white),
      );
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
      body: SingleChildScrollView(
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
