/// Test Runner
/// Run this file to execute all tests
/// Usage: Call ComprehensiveTest.runAllTests() from your app

import 'package:flutter/material.dart';
import 'comprehensive_test.dart';

/// Test Runner Widget
/// Add this to your app to run tests
class TestRunner extends StatefulWidget {
  const TestRunner({Key? key}) : super(key: key);

  @override
  State<TestRunner> createState() => _TestRunnerState();
}

class _TestRunnerState extends State<TestRunner> {
  bool _isRunning = false;
  Map<String, dynamic>? _results;

  Future<void> _runTests() async {
    setState(() {
      _isRunning = true;
      _results = null;
    });

    final results = await ComprehensiveTest.runAllTests();

    setState(() {
      _isRunning = false;
      _results = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comprehensive Testing'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: _isRunning ? null : _runTests,
              child: _isRunning
                  ? const CircularProgressIndicator()
                  : const Text('Run All Tests'),
            ),
            const SizedBox(height: 20),
            if (_results != null) ...[
              _buildSummary(),
              const SizedBox(height: 20),
              _buildIssues(),
              const SizedBox(height: 20),
              _buildWarnings(),
              const SizedBox(height: 20),
              _buildSuccess(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummary() {
    final summary = _results!['summary'] as Map<String, dynamic>;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Test Summary',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text('✅ Success: ${summary['total_success']}'),
            Text('⚠️  Warnings: ${summary['total_warnings']}'),
            Text('❌ Issues: ${summary['total_issues']}'),
          ],
        ),
      ),
    );
  }

  Widget _buildIssues() {
    final issues = _results!['issues'] as List<String>;
    if (issues.isEmpty) return const SizedBox.shrink();

    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Issues (${issues.length})',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 10),
            ...issues.map((issue) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(issue, style: const TextStyle(color: Colors.red)),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildWarnings() {
    final warnings = _results!['warnings'] as List<String>;
    if (warnings.isEmpty) return const SizedBox.shrink();

    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Warnings (${warnings.length})',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 10),
            ...warnings.map((warning) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(warning, style: const TextStyle(color: Colors.orange)),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    final success = _results!['success'] as List<String>;
    if (success.isEmpty) return const SizedBox.shrink();

    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Success (${success.length})',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 10),
            ...success.take(20).map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(s, style: const TextStyle(color: Colors.green)),
                )),
            if (success.length > 20)
              Text('... and ${success.length - 20} more'),
          ],
        ),
      ),
    );
  }
}

