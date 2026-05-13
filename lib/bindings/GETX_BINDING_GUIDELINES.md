# GetX Binding Guidelines - Standardized Patterns

## Overview
This document outlines the standardized binding patterns for GetX controllers and services to prevent lazy loading issues and ensure consistent initialization across the application.

## Core Principles

### 1. Single Source of Truth
- **InitialBinding.dart** is the ONLY place where controllers should be registered
- Never use `Get.put()` in screens or widgets unless absolutely necessary
- Always use `Get.find()` to access controllers that should already be registered

### 2. Binding Strategy

#### Core Controllers (Always Available)
```dart
// Use Get.put() with permanent: true for core controllers
if (!Get.isRegistered<HomeController>()) {
  Get.put(HomeController(), permanent: true);
}
```

#### Feature Controllers (Lazy Loaded)
```dart
// Use Get.lazyPut() with fenix: true for feature controllers
if (!Get.isRegistered<FeatureController>()) {
  Get.lazyPut(() => FeatureController(), fenix: true);
}
```

#### Services
```dart
// Use Get.put() with permanent: true for services
if (!Get.isRegistered<Service>()) {
  Get.put(Service(), permanent: true);
}
```

## Binding Categories

### 1. Core Controllers (permanent: true)
- HomeController
- MainDashboardController  
- ProfileController
- BannersController

### 2. Feature Controllers (lazyPut + fenix: true)
- NotificationsController
- PrayersController
- PrayerRemindersController
- GroupsController
- GroupChatController
- GroupPostsController
- FruitController
- BlogsController
- VideosController
- GalleryController
- OnboardingController
- PhoneAuthController
- ForgotPasswordController
- ResetPasswordController
- ChurchLocatorController
- DenominationsController
- LiveStreamController

### 3. Services (permanent: true)
- JingleService
- IAPService

## Usage Patterns

### ✅ CORRECT: Accessing Controllers
```dart
// In screens and widgets
final controller = Get.find<ControllerName>();
```

### ❌ INCORRECT: Manual Registration
```dart
// NEVER do this in screens
if (!Get.isRegistered<ControllerName>()) {
  Get.put(ControllerName());
}
```

### ❌ INCORRECT: Direct Get.put
```dart
// NEVER do this
final controller = Get.put(ControllerName());
```

## Special Cases

### 1. Error Handling
```dart
try {
  final controller = Get.find<ControllerName>();
  // Use controller
} catch (e) {
  // Controller not found - this indicates a binding configuration issue
  debugPrint('Controller not found: $e');
  // Consider if this controller should be in InitialBinding
}
```

### 2. Service Initialization with Error Handling
```dart
// Only for services that require special initialization
try {
  if (Get.isRegistered<IAPService>()) {
    _iapService = Get.find<IAPService>();
  } else {
    _iapService = Get.put(IAPService(), permanent: true);
    await _iapService!.initialize();
  }
} catch (e) {
  // Fallback initialization
}
```

## Migration Checklist

### For Existing Code:
1. Remove all `Get.put()` calls from screens
2. Replace with `Get.find()` calls
3. Ensure controller is registered in InitialBinding
4. Use appropriate binding strategy (put vs lazyPut)

### For New Code:
1. Add controller to appropriate section in InitialBinding
2. Use `Get.find()` to access in screens
3. Follow naming conventions
4. Document controller purpose

## Benefits

1. **Performance**: Lazy loading prevents unnecessary initialization
2. **Memory Management**: fenix:true enables auto-recreation
3. **Consistency**: Single source of truth for all bindings
4. **Maintainability**: Easy to track and manage dependencies
5. **Debugging**: Centralized binding configuration

## Troubleshooting

### Common Issues:
1. **Controller not found**: Add to InitialBinding
2. **Performance issues**: Check if using lazyPut appropriately
3. **Memory leaks**: Ensure proper fenix: true usage
4. **Duplicate registration**: Remove manual Get.put calls

### Debug Commands:
```dart
// Check if controller is registered
print(Get.isRegistered<ControllerName>());

// List all registered controllers
print(Get.getAllControllerTypes());
```

## Best Practices

1. **Always** use `Get.isRegistered()` check in InitialBinding
2. **Never** use `Get.put()` in screens/widgets
3. **Always** prefer `Get.lazyPut()` for feature controllers
4. **Always** use `fenix: true` for lazy controllers that need auto-recreation
5. **Always** use `permanent: true` for core controllers and services
6. **Always** handle exceptions when using `Get.find()`

## File Structure

```
lib/bindings/
├── InitialBinding.dart          # Main binding configuration
├── GETX_BINDING_GUIDELINES.md   # This document
└── [specific_bindings].dart     # Route-specific bindings (if needed)
```

## Review Process

1. Code review should check for manual Get.put calls
2. Ensure new controllers are added to InitialBinding
3. Verify appropriate binding strategy is used
4. Test controller lifecycle and memory management
