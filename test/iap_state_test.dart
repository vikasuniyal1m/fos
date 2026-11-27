// import 'package:flutter_test/flutter_test.dart';
// import 'package:get/get.dart';
// import 'package:fruitsofspirit/services/iap_service.dart';
//
// void main() {
//   group('IAP State Management Tests', () {
//     late IAPService iapService;
//
//     setUp(() {
//       // Initialize GetX for testing
//       Get.testMode = true;
//       iapService = IAPService();
//     });
//
//     tearDown(() {
//       Get.resetTestMode();
//     });
//
//     test('should not show loading and error simultaneously', () {
//       // Test that state validation prevents conflicting states
//       expect(iapService._canShowError, isFalse); // Initially idle
//       expect(iapService._canShowLoading, isFalse); // Initially idle
//
//       // When loading, should not show error
//       iapService._setLoadingState();
//       expect(iapService._canShowLoading, isTrue);
//       expect(iapService._canShowError, isFalse);
//
//       // When in error state, should not show loading
//       iapService._setStateWithError('Test error', IAPState.error);
//       expect(iapService._canShowError, isTrue);
//       expect(iapService._canShowLoading, isFalse);
//     });
//
//     test('should validate state transitions correctly', () {
//       // Test valid transitions
//       expect(iapService._isValidStateTransition(IAPState.idle, IAPState.loading), isTrue);
//       expect(iapService._isValidStateTransition(IAPState.loading, IAPState.ready), isTrue);
//       expect(iapService._isValidStateTransition(IAPState.ready, IAPState.error), isTrue);
//       expect(iapService._isValidStateTransition(IAPState.error, IAPState.idle), isTrue);
//
//       // Test invalid transitions
//       expect(iapService._isValidStateTransition(IAPState.loading, IAPState.loading), isFalse);
//       expect(iapService._isValidStateTransition(IAPState.error, IAPState.loading), isTrue); // Error to loading is allowed
//     });
//
//     test('should provide correct state descriptions', () {
//       iapService._safeSetState(IAPState.idle);
//       expect(iapService.currentStateDescription, equals('Ready to initialize'));
//
//       iapService._safeSetState(IAPState.loading);
//       expect(iapService.currentStateDescription, equals('Loading App Store products...'));
//
//       iapService._safeSetState(IAPState.ready);
//       expect(iapService.currentStateDescription, equals('App Store ready'));
//
//       iapService._safeSetState(IAPState.error, error: 'Test error');
//       expect(iapService.currentStateDescription, equals('Test error'));
//
//       iapService._safeSetState(IAPState.unavailable);
//       expect(iapService.currentStateDescription, equals('App Store unavailable'));
//     });
//
//     test('should clear error and retry correctly', () {
//       // Set error state
//       iapService._setStateWithError('Test error', IAPState.error);
//       expect(iapService.state.value, equals(IAPState.error));
//       expect(iapService.errorMessage.value, equals('Test error'));
//
//       // Clear error and retry should reset to idle and clear error
//       iapService.clearErrorAndRetry();
//       expect(iapService.state.value, equals(IAPState.idle));
//       expect(iapService.errorMessage.value, isEmpty);
//     });
//
//     test('should identify stable states correctly', () {
//       iapService._safeSetState(IAPState.idle);
//       expect(iapService.isInStableState, isTrue);
//
//       iapService._safeSetState(IAPState.ready);
//       expect(iapService.isInStableState, isTrue);
//
//       iapService._safeSetState(IAPState.loading);
//       expect(iapService.isInStableState, isFalse);
//
//       iapService._safeSetState(IAPState.error);
//       expect(iapService.isInStableState, isFalse);
//
//       iapService._safeSetState(IAPState.unavailable);
//       expect(iapService.isInStableState, isFalse);
//     });
//
//     test('should handle safe state transitions', () {
//       // Valid transition should work
//       iapService._safeSetState(IAPState.loading);
//       expect(iapService.state.value, equals(IAPState.loading));
//       expect(iapService.errorMessage.value, isEmpty);
//
//       // Transition with error should set error message
//       iapService._safeSetState(IAPState.error, error: 'Test error');
//       expect(iapService.state.value, equals(IAPState.error));
//       expect(iapService.errorMessage.value, equals('Test error'));
//
//       // Ready state should clear error
//       iapService._safeSetState(IAPState.ready);
//       expect(iapService.state.value, equals(IAPState.ready));
//       expect(iapService.errorMessage.value, isEmpty);
//     });
//   });
// }
