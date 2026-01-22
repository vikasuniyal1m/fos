import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../services/terms_service.dart';
import '../widgets/custom_button.dart';

/// Screen for users to accept UGC guidelines before posting
class TermsAcceptanceScreen extends StatefulWidget {
  final VoidCallback onAccepted;

  const TermsAcceptanceScreen({
    super.key,
    required this.onAccepted,
  });

  @override
  State<TermsAcceptanceScreen> createState() => _TermsAcceptanceScreenState();
}

class _TermsAcceptanceScreenState extends State<TermsAcceptanceScreen> {
  bool _isLoading = true;
  String _content = '';
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadTerms();
  }

  Future<void> _loadTerms() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final terms = await TermsService.getTerms();
      setState(() {
        _content = terms['content'] ?? 'User Generated Content guidelines and community standards apply.';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _handleAccept() async {
    await TermsService.acceptTerms();
    widget.onAccepted();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Guidelines'),
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      SizedBox(height: 16.h),
                      Text('Failed to load guidelines', style: TextStyle(fontSize: 16.sp)),
                      TextButton(onPressed: _loadTerms, child: const Text('Retry')),
                    ],
                  ),
                )
              : SafeArea(
                  child: Padding(
                    padding: EdgeInsets.all(20.w),
                    child: Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Respectful Community',
                                  style: TextStyle(
                                    fontSize: 20.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 15.h),
                                Text(
                                  'By using our community features, you agree to follow our guidelines. We have zero tolerance for objectionable content or abusive users.',
                                  style: TextStyle(
                                    fontSize: 15.sp,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.blueGrey,
                                  ),
                                ),
                                SizedBox(height: 20.h),
                                Text(
                                  _content,
                                  style: TextStyle(fontSize: 14.sp, height: 1.5),
                                ),
                                SizedBox(height: 20.h),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 20.h),
                        CustomButton(
                          text: 'I Agree & Continue',
                          onPressed: _handleAccept,
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
