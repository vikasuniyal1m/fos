/// Quick Test Runner
/// Run this file directly to execute tests
/// 
/// Usage:
/// 1. Temporarily use this file instead of main.dart
/// 2. Or import this file in main.dart and call it

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fruitsofspirit/testing/comprehensive_test.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('\n🚀 Starting Comprehensive Tests...\n');
  
  // Run all tests
  final results = await ComprehensiveTest.runAllTests();
  
  // Display results summary
  print('\n📊 ============================================');
  print('📊 FINAL RESULTS SUMMARY');
  print('📊 ============================================');
  print('✅ Success: ${results['summary']['total_success']}');
  print('⚠️  Warnings: ${results['summary']['total_warnings']}');
  print('❌ Issues: ${results['summary']['total_issues']}');
  print('📊 ============================================\n');
  
  // If you want to see the app after tests, uncomment below:
  // runApp(MyApp());
  
  // Or just exit after showing results
  exit(0);
}

