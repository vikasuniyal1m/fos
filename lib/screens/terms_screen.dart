import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/services/terms_service.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';
import 'package:fruitsofspirit/services/api_service.dart';

/// Terms & Conditions Screen
/// Displays terms content from backend
class TermsScreen extends StatefulWidget {
  const TermsScreen({Key? key}) : super(key: key);

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  bool _isLoading = true;
  String _content = '';
  String _version = '';
  String _updatedAt = '';
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
        _content = terms['content'] ?? 'Terms & Conditions content will be available soon.';
        _version = terms['version'] ?? '1.0';
        _updatedAt = terms['updated_at'] ?? '';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5DC),
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(
          ResponsiveHelper.appBarHeight(context),
        ),
        child: AppBar(
          backgroundColor: const Color(0xFFF5F5DC),
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: const Color(0xFF8B4513),
              size: ResponsiveHelper.iconSize(context, mobile: 24, tablet: 28, desktop: 32),
            ),
            onPressed: () => Get.back(),
          ),
          title: Text(
            'Terms & Conditions',
            style: ResponsiveHelper.textStyle(
              context,
              fontSize: ResponsiveHelper.fontSize(context, mobile: 20, tablet: 24, desktop: 28),
              fontWeight: FontWeight.bold,
              color: const Color(0xFF8B4513),
            ),
          ),
          centerTitle: true,
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: const Color(0xFF8B4513),
              ),
            )
          : _error.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red[300],
                      ),
                      SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                      Text(
                        'Error loading terms',
                        style: ResponsiveHelper.textStyle(
                          context,
                          fontSize: ResponsiveHelper.fontSize(context, mobile: 18),
                          fontWeight: FontWeight.bold,
                          color: Colors.red[700],
                        ),
                      ),
                      SizedBox(height: ResponsiveHelper.spacing(context, 8)),
                      Text(
                        _error,
                        style: ResponsiveHelper.textStyle(
                          context,
                          fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: ResponsiveHelper.spacing(context, 24)),
                      ElevatedButton(
                        onPressed: _loadTerms,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B4513),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: ResponsiveHelper.spacing(context, 24),
                            vertical: ResponsiveHelper.spacing(context, 12),
                          ),
                        ),
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Version and Updated Date
                      if (_version.isNotEmpty || _updatedAt.isNotEmpty)
                        Container(
                          padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 12)),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(
                              ResponsiveHelper.borderRadius(context, mobile: 8),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: ResponsiveHelper.iconSize(context, mobile: 20),
                                color: Colors.grey[600],
                              ),
                              SizedBox(width: ResponsiveHelper.spacing(context, 8)),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (_version.isNotEmpty)
                                      Text(
                                        'Version: $_version',
                                        style: ResponsiveHelper.textStyle(
                                          context,
                                          fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    if (_updatedAt.isNotEmpty)
                                      Text(
                                        'Last Updated: ${_formatDate(_updatedAt)}',
                                        style: ResponsiveHelper.textStyle(
                                          context,
                                          fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      SizedBox(height: ResponsiveHelper.spacing(context, 20)),
                      // Terms Content
                      Container(
                        padding: EdgeInsets.all(ResponsiveHelper.spacing(context, 16)),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(
                            ResponsiveHelper.borderRadius(context, mobile: 12),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 3,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          _content,
                          style: ResponsiveHelper.textStyle(
                            context,
                            fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                            color: Colors.black87,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day} ${_getMonthName(date.month)} ${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return months[month - 1];
  }
}

