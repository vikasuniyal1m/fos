# 📱 Complete Screen Sizes Reference Guide

This document provides comprehensive lists of all iPhone and Android device screen sizes with brand names, along with guidelines for creating responsive UI in Flutter.

## 📋 Table of Contents
1. [iPhone Screen Sizes](#iphone-screen-sizes)
2. [Android Screen Sizes](#android-screen-sizes)
3. [Measuring Screen Sizes](#measuring-screen-sizes)
4. [Responsive UI Implementation](#responsive-ui-implementation)
5. [Breakpoints & Device Categories](#breakpoints--device-categories)
6. [Testing Checklist](#testing-checklist)

---

## 📱 iPhone Screen Sizes

### iPhone Models (Portrait Orientation)

| Device Name | Screen Size (Points) | Physical Resolution | Pixel Density | Release Year | Category |
|------------|---------------------|---------------------|---------------|--------------|----------|
| **iPhone SE (1st gen)** | 320 × 568 | 640 × 1136 | @2x | 2016 | Small Phone |
| **iPhone SE (2nd gen)** | 375 × 667 | 750 × 1334 | @2x | 2020 | Small Phone |
| **iPhone SE (3rd gen)** | 375 × 667 | 750 × 1334 | @2x | 2022 | Small Phone |
| **iPhone 6** | 375 × 667 | 750 × 1334 | @2x | 2014 | Medium Phone |
| **iPhone 6 Plus** | 414 × 736 | 1080 × 1920 | @3x | 2014 | Large Phone |
| **iPhone 6s** | 375 × 667 | 750 × 1334 | @2x | 2015 | Medium Phone |
| **iPhone 6s Plus** | 414 × 736 | 1080 × 1920 | @3x | 2015 | Large Phone |
| **iPhone 7** | 375 × 667 | 750 × 1334 | @2x | 2016 | Medium Phone |
| **iPhone 7 Plus** | 414 × 736 | 1080 × 1920 | @3x | 2016 | Large Phone |
| **iPhone 8** | 375 × 667 | 750 × 1334 | @2x | 2017 | Medium Phone |
| **iPhone 8 Plus** | 414 × 736 | 1080 × 1920 | @3x | 2017 | Large Phone |
| **iPhone X** | 375 × 812 | 1125 × 2436 | @3x | 2017 | Medium Phone |
| **iPhone XS** | 375 × 812 | 1125 × 2436 | @3x | 2018 | Medium Phone |
| **iPhone XS Max** | 414 × 896 | 1242 × 2688 | @3x | 2018 | Large Phone |
| **iPhone XR** | 414 × 896 | 828 × 1792 | @2x | 2018 | Large Phone |
| **iPhone 11** | 414 × 896 | 828 × 1792 | @2x | 2019 | Large Phone |
| **iPhone 11 Pro** | 375 × 812 | 1125 × 2436 | @3x | 2019 | Medium Phone |
| **iPhone 11 Pro Max** | 414 × 896 | 1242 × 2688 | @3x | 2019 | Large Phone |
| **iPhone 12 mini** | 375 × 812 | 1080 × 2340 | @3x | 2020 | Medium Phone |
| **iPhone 12** | 390 × 844 | 1170 × 2532 | @3x | 2020 | Medium Phone |
| **iPhone 12 Pro** | 390 × 844 | 1170 × 2532 | @3x | 2020 | Medium Phone |
| **iPhone 12 Pro Max** | 428 × 926 | 1284 × 2778 | @3x | 2020 | Large Phone |
| **iPhone 13 mini** | 375 × 812 | 1080 × 2340 | @3x | 2021 | Medium Phone |
| **iPhone 13** | 390 × 844 | 1170 × 2532 | @3x | 2021 | Medium Phone |
| **iPhone 13 Pro** | 390 × 844 | 1170 × 2532 | @3x | 2021 | Medium Phone |
| **iPhone 13 Pro Max** | 428 × 926 | 1284 × 2778 | @3x | 2021 | Large Phone |
| **iPhone 14** | 390 × 844 | 1170 × 2532 | @3x | 2022 | Medium Phone |
| **iPhone 14 Plus** | 428 × 926 | 1284 × 2778 | @3x | 2022 | Large Phone |
| **iPhone 14 Pro** | 393 × 852 | 1179 × 2556 | @3x | 2022 | Medium Phone |
| **iPhone 14 Pro Max** | 430 × 932 | 1290 × 2796 | @3x | 2022 | Large Phone |
| **iPhone 15** | 393 × 852 | 1179 × 2556 | @3x | 2023 | Medium Phone |
| **iPhone 15 Plus** | 430 × 932 | 1290 × 2796 | @3x | 2023 | Large Phone |
| **iPhone 15 Pro** | 393 × 852 | 1179 × 2556 | @3x | 2023 | Medium Phone |
| **iPhone 15 Pro Max** | 430 × 932 | 1290 × 2796 | @3x | 2023 | Large Phone |
| **iPhone 16** | 393 × 852 | 1179 × 2556 | @3x | 2024 | Medium Phone |
| **iPhone 16 Plus** | 430 × 932 | 1290 × 2796 | @3x | 2024 | Large Phone |
| **iPhone 16 Pro** | 402 × 873 | 1206 × 2619 | @3x | 2024 | Medium Phone |
| **iPhone 16 Pro Max** | 442 × 960 | 1326 × 2880 | @3x | 2024 | Large Phone |

### iPad Models (Tablets)

| Device Name | Screen Size (Points) | Physical Resolution | Pixel Density | Release Year | Category |
|------------|---------------------|---------------------|---------------|--------------|----------|
| **iPad Mini (1st-5th gen)** | 768 × 1024 | 768 × 1024 | @1x/@2x | 2012-2021 | Small Tablet |
| **iPad Mini (6th gen)** | 744 × 1133 | 1488 × 2266 | @2x | 2021 | Small Tablet |
| **iPad (1st-9th gen)** | 768 × 1024 | 768 × 1024 | @1x/@2x | 2010-2021 | Small Tablet |
| **iPad (10th gen)** | 820 × 1180 | 1640 × 2360 | @2x | 2022 | Small Tablet |
| **iPad Air (1st-4th gen)** | 768 × 1024 | 1536 × 2048 | @2x | 2013-2020 | Small Tablet |
| **iPad Air (5th gen)** | 820 × 1180 | 1640 × 2360 | @2x | 2022 | Small Tablet |
| **iPad Pro 9.7"** | 768 × 1024 | 1536 × 2048 | @2x | 2016 | Small Tablet |
| **iPad Pro 10.5"** | 834 × 1112 | 1668 × 2224 | @2x | 2017 | Small Tablet |
| **iPad Pro 11" (1st-4th gen)** | 834 × 1194 | 1668 × 2388 | @2x | 2018-2022 | Small Tablet |
| **iPad Pro 12.9" (1st-6th gen)** | 1024 × 1366 | 2048 × 2732 | @2x | 2015-2022 | Large Tablet |
| **iPad Pro 12.9" (M4)** | 1024 × 1378 | 2048 × 2756 | @2x | 2024 | Large Tablet |

### iPhone Screen Size Categories

#### Small Phones (< 360px width)
- iPhone SE (1st gen): 320 × 568
- iPhone SE (2nd gen): 375 × 667
- iPhone SE (3rd gen): 375 × 667

#### Medium Phones (360-414px width)
- iPhone 6, 6s, 7, 8: 375 × 667
- iPhone X, XS, 11 Pro: 375 × 812
- iPhone 12 mini, 13 mini: 375 × 812
- iPhone 12, 12 Pro, 13, 13 Pro: 390 × 844
- iPhone 14, 15: 393 × 852
- iPhone 14 Pro, 15 Pro: 393 × 852
- iPhone 16 Pro: 402 × 873

#### Large Phones (414-600px width)
- iPhone 6 Plus, 6s Plus, 7 Plus, 8 Plus: 414 × 736
- iPhone XR, 11: 414 × 896
- iPhone XS Max, 11 Pro Max: 414 × 896
- iPhone 12 Pro Max, 13 Pro Max: 428 × 926
- iPhone 14 Plus, 15 Plus: 428 × 926
- iPhone 14 Pro Max, 15 Pro Max: 430 × 932
- iPhone 16 Plus: 430 × 932
- iPhone 16 Pro Max: 442 × 960

---

## 🤖 Android Screen Sizes

### Popular Android Phones (Portrait Orientation)

| Device Name | Screen Size (dp) | Physical Resolution | DPI | Release Year | Category |
|------------|-----------------|---------------------|-----|--------------|----------|
| **Samsung Galaxy S6** | 360 × 640 | 1440 × 2560 | 577 | 2015 | Medium Phone |
| **Samsung Galaxy S7** | 360 × 640 | 1440 × 2560 | 577 | 2016 | Medium Phone |
| **Samsung Galaxy S8** | 360 × 740 | 1440 × 2960 | 568 | 2017 | Medium Phone |
| **Samsung Galaxy S9** | 360 × 740 | 1440 × 2960 | 568 | 2018 | Medium Phone |
| **Samsung Galaxy S10** | 360 × 760 | 1440 × 3040 | 550 | 2019 | Medium Phone |
| **Samsung Galaxy S10+** | 411 × 846 | 1440 × 3040 | 526 | 2019 | Large Phone |
| **Samsung Galaxy S20** | 360 × 800 | 1440 × 3200 | 563 | 2020 | Medium Phone |
| **Samsung Galaxy S20+** | 384 × 854 | 1440 × 3200 | 525 | 2020 | Large Phone |
| **Samsung Galaxy S20 Ultra** | 412 × 915 | 1440 × 3200 | 511 | 2020 | Large Phone |
| **Samsung Galaxy S21** | 360 × 800 | 1080 × 2400 | 421 | 2021 | Medium Phone |
| **Samsung Galaxy S21+** | 384 × 854 | 1080 × 2400 | 394 | 2021 | Large Phone |
| **Samsung Galaxy S21 Ultra** | 412 × 915 | 1440 × 3200 | 515 | 2021 | Large Phone |
| **Samsung Galaxy S22** | 360 × 780 | 1080 × 2340 | 425 | 2022 | Medium Phone |
| **Samsung Galaxy S22+** | 384 × 854 | 1080 × 2340 | 393 | 2022 | Large Phone |
| **Samsung Galaxy S22 Ultra** | 412 × 915 | 1440 × 3088 | 501 | 2022 | Large Phone |
| **Samsung Galaxy S23** | 360 × 780 | 1080 × 2340 | 425 | 2023 | Medium Phone |
| **Samsung Galaxy S23+** | 384 × 854 | 1080 × 2340 | 393 | 2023 | Large Phone |
| **Samsung Galaxy S23 Ultra** | 412 × 915 | 1440 × 3088 | 501 | 2023 | Large Phone |
| **Samsung Galaxy S24** | 360 × 780 | 1080 × 2340 | 425 | 2024 | Medium Phone |
| **Samsung Galaxy S24+** | 384 × 854 | 1080 × 2340 | 393 | 2024 | Large Phone |
| **Samsung Galaxy S24 Ultra** | 412 × 915 | 1440 × 3120 | 501 | 2024 | Large Phone |
| **Samsung Galaxy S25** | 360 × 780 | 1080 × 2340 | 425 | 2025 | Medium Phone |
| **Samsung Galaxy S25+** | 384 × 854 | 1080 × 2340 | 393 | 2025 | Large Phone |
| **Samsung Galaxy S25 Ultra** | 412 × 915 | 1440 × 3120 | 501 | 2025 | Large Phone |
| **Samsung Galaxy Note 8** | 411 × 823 | 1440 × 2960 | 521 | 2017 | Large Phone |
| **Samsung Galaxy Note 9** | 411 × 846 | 1440 × 2960 | 516 | 2018 | Large Phone |
| **Samsung Galaxy Note 10** | 360 × 760 | 1080 × 2280 | 400 | 2019 | Medium Phone |
| **Samsung Galaxy Note 10+** | 412 × 869 | 1440 × 3040 | 498 | 2019 | Large Phone |
| **Samsung Galaxy Note 20** | 412 × 915 | 1080 × 2400 | 393 | 2020 | Large Phone |
| **Samsung Galaxy Note 20 Ultra** | 412 × 915 | 1440 × 3088 | 501 | 2020 | Large Phone |
| **Google Pixel 2** | 411 × 731 | 1080 × 1920 | 420 | 2017 | Large Phone |
| **Google Pixel 2 XL** | 411 × 823 | 1440 × 2560 | 538 | 2017 | Large Phone |
| **Google Pixel 3** | 393 × 786 | 1080 × 2160 | 443 | 2018 | Medium Phone |
| **Google Pixel 3 XL** | 412 × 846 | 1440 × 2960 | 523 | 2018 | Large Phone |
| **Google Pixel 4** | 393 × 851 | 1080 × 2280 | 444 | 2019 | Medium Phone |
| **Google Pixel 4 XL** | 412 × 869 | 1440 × 3040 | 537 | 2019 | Large Phone |
| **Google Pixel 5** | 393 × 851 | 1080 × 2340 | 432 | 2020 | Medium Phone |
| **Google Pixel 6** | 412 × 915 | 1080 × 2400 | 411 | 2021 | Large Phone |
| **Google Pixel 6 Pro** | 412 × 915 | 1440 × 3120 | 512 | 2021 | Large Phone |
| **Google Pixel 7** | 412 × 915 | 1080 × 2400 | 411 | 2022 | Large Phone |
| **Google Pixel 7 Pro** | 412 × 915 | 1440 × 3120 | 512 | 2022 | Large Phone |
| **Google Pixel 8** | 412 × 915 | 1080 × 2400 | 428 | 2023 | Large Phone |
| **Google Pixel 8 Pro** | 412 × 915 | 1344 × 2992 | 489 | 2023 | Large Phone |
| **Google Pixel 9** | 412 × 915 | 1080 × 2400 | 428 | 2024 | Large Phone |
| **Google Pixel 9 Pro** | 412 × 915 | 1344 × 2992 | 489 | 2024 | Large Phone |
| **OnePlus 5** | 411 × 731 | 1080 × 1920 | 401 | 2017 | Large Phone |
| **OnePlus 5T** | 411 × 823 | 1080 × 2160 | 401 | 2017 | Large Phone |
| **OnePlus 6** | 411 × 823 | 1080 × 2280 | 402 | 2018 | Large Phone |
| **OnePlus 6T** | 411 × 823 | 1080 × 2340 | 402 | 2018 | Large Phone |
| **OnePlus 7** | 412 × 892 | 1080 × 2400 | 402 | 2019 | Large Phone |
| **OnePlus 7 Pro** | 412 × 892 | 1440 × 3120 | 516 | 2019 | Large Phone |
| **OnePlus 8** | 412 × 915 | 1080 × 2400 | 402 | 2020 | Large Phone |
| **OnePlus 8 Pro** | 412 × 915 | 1440 × 3168 | 525 | 2020 | Large Phone |
| **OnePlus 9** | 412 × 915 | 1080 × 2400 | 402 | 2021 | Large Phone |
| **OnePlus 9 Pro** | 412 × 915 | 1440 × 3216 | 525 | 2021 | Large Phone |
| **OnePlus 10 Pro** | 412 × 915 | 1440 × 3216 | 525 | 2022 | Large Phone |
| **OnePlus 11** | 412 × 915 | 1440 × 3216 | 525 | 2023 | Large Phone |
| **OnePlus 12** | 412 × 915 | 1440 × 3168 | 510 | 2024 | Large Phone |
| **Xiaomi Mi 9** | 393 × 851 | 1080 × 2340 | 403 | 2019 | Medium Phone |
| **Xiaomi Mi 10** | 393 × 851 | 1080 × 2340 | 403 | 2020 | Medium Phone |
| **Xiaomi Mi 11** | 393 × 851 | 1440 × 3200 | 515 | 2021 | Medium Phone |
| **Xiaomi Mi 12** | 393 × 851 | 1080 × 2400 | 419 | 2022 | Medium Phone |
| **Xiaomi Mi 13** | 393 × 851 | 1080 × 2400 | 419 | 2023 | Medium Phone |
| **Xiaomi Mi 14** | 393 × 851 | 1200 × 2670 | 460 | 2024 | Medium Phone |
| **Huawei P20** | 360 × 748 | 1080 × 2244 | 428 | 2018 | Medium Phone |
| **Huawei P30** | 360 × 780 | 1080 × 2340 | 422 | 2019 | Medium Phone |
| **Huawei P40** | 360 × 780 | 1080 × 2340 | 422 | 2020 | Medium Phone |
| **Huawei P50** | 360 × 780 | 1224 × 2700 | 456 | 2021 | Medium Phone |
| **Huawei P60** | 360 × 780 | 1224 × 2700 | 456 | 2023 | Medium Phone |
| **Oppo Find X** | 375 × 812 | 1080 × 2340 | 401 | 2018 | Medium Phone |
| **Oppo Find X2** | 412 × 915 | 1440 × 3168 | 525 | 2020 | Large Phone |
| **Oppo Find X3** | 412 × 915 | 1440 × 3216 | 525 | 2021 | Large Phone |
| **Oppo Find X5** | 412 × 915 | 1440 × 3216 | 525 | 2022 | Large Phone |
| **Vivo X50** | 360 × 800 | 1080 × 2376 | 398 | 2020 | Medium Phone |
| **Vivo X60** | 360 × 800 | 1080 × 2376 | 398 | 2021 | Medium Phone |
| **Vivo X70** | 360 × 800 | 1080 × 2376 | 398 | 2021 | Medium Phone |
| **Vivo X80** | 360 × 800 | 1080 × 2400 | 398 | 2022 | Medium Phone |
| **Vivo X90** | 360 × 800 | 1260 × 2800 | 453 | 2023 | Medium Phone |
| **Motorola Moto G** | 360 × 640 | 720 × 1280 | 294 | 2013 | Medium Phone |
| **Motorola Moto X** | 360 × 640 | 720 × 1280 | 312 | 2013 | Medium Phone |
| **Motorola Edge** | 360 × 800 | 1080 × 2340 | 385 | 2020 | Medium Phone |
| **Motorola Edge+** | 412 × 915 | 1080 × 2340 | 385 | 2020 | Large Phone |
| **Sony Xperia 1** | 411 × 823 | 1644 × 3840 | 643 | 2019 | Large Phone |
| **Sony Xperia 5** | 360 × 800 | 1080 × 2520 | 449 | 2019 | Medium Phone |
| **Sony Xperia 10** | 360 × 800 | 1080 × 2520 | 457 | 2019 | Medium Phone |

### Android Tablets

| Device Name | Screen Size (dp) | Physical Resolution | DPI | Release Year | Category |
|------------|-----------------|---------------------|-----|--------------|----------|
| **Samsung Galaxy Tab S6** | 800 × 1280 | 1600 × 2560 | 287 | 2019 | Small Tablet |
| **Samsung Galaxy Tab S7** | 800 × 1280 | 1600 × 2560 | 287 | 2020 | Small Tablet |
| **Samsung Galaxy Tab S8** | 800 × 1280 | 1600 × 2560 | 287 | 2022 | Small Tablet |
| **Samsung Galaxy Tab S9** | 800 × 1280 | 1600 × 2560 | 287 | 2023 | Small Tablet |
| **Samsung Galaxy Tab S7+** | 1024 × 1366 | 1752 × 2800 | 266 | 2020 | Large Tablet |
| **Samsung Galaxy Tab S8+** | 1024 × 1366 | 1752 × 2800 | 266 | 2022 | Large Tablet |
| **Samsung Galaxy Tab S9+** | 1024 × 1366 | 1752 × 2800 | 266 | 2023 | Large Tablet |
| **Samsung Galaxy Tab S9 Ultra** | 1024 × 1366 | 1848 × 2960 | 280 | 2023 | Large Tablet |
| **Google Pixel Tablet** | 1024 × 1366 | 1600 × 2560 | 240 | 2023 | Large Tablet |
| **Lenovo Tab P11** | 800 × 1280 | 1200 × 2000 | 213 | 2021 | Small Tablet |
| **Lenovo Tab P12** | 1024 × 1366 | 1600 × 2560 | 240 | 2022 | Large Tablet |
| **Xiaomi Pad 5** | 800 × 1280 | 1600 × 2560 | 275 | 2021 | Small Tablet |
| **Xiaomi Pad 6** | 800 × 1280 | 1800 × 2880 | 309 | 2023 | Small Tablet |

### Android Screen Size Categories

#### Small Phones (< 360px width)
- Older budget Android phones: 320 × 480, 320 × 533, 360 × 640

#### Medium Phones (360-414px width)
- Most standard Android phones: 360 × 640, 360 × 720, 360 × 780, 360 × 800
- Samsung Galaxy S series (standard): 360 × 800
- Google Pixel (standard): 393 × 851
- Xiaomi Mi series: 393 × 851
- Huawei P series: 360 × 780

#### Large Phones (414-600px width)
- Samsung Galaxy S series (Plus/Ultra): 384 × 854, 412 × 915
- Samsung Galaxy Note series: 411 × 823, 412 × 915
- Google Pixel (XL/Pro): 412 × 915
- OnePlus series: 411 × 823, 412 × 915
- Oppo Find X series: 412 × 915

#### Small Tablets (600-768px width)
- Most Android tablets: 600 × 960, 800 × 1280
- Samsung Galaxy Tab S (standard): 800 × 1280
- Xiaomi Pad: 800 × 1280

#### Large Tablets (768px+ width)
- Samsung Galaxy Tab S (Plus/Ultra): 1024 × 1366
- Google Pixel Tablet: 1024 × 1366
- Large Android tablets: 1024 × 1366, 1200 × 1920

---

## 📏 Measuring Screen Sizes

### In Flutter

#### Method 1: Using MediaQuery
```dart
import 'package:flutter/material.dart';

void getScreenSize(BuildContext context) {
  final mediaQuery = MediaQuery.of(context);
  final screenWidth = mediaQuery.size.width;
  final screenHeight = mediaQuery.size.height;
  final devicePixelRatio = mediaQuery.devicePixelRatio;
  
  print('Screen Width: $screenWidth');
  print('Screen Height: $screenHeight');
  print('Device Pixel Ratio: $devicePixelRatio');
  print('Physical Width: ${screenWidth * devicePixelRatio}');
  print('Physical Height: ${screenHeight * devicePixelRatio}');
}
```

#### Method 2: Using ScreenSize Utility (Already Implemented)
```dart
import 'utils/screen_size.dart';

// Initialize in your widget
@override
Widget build(BuildContext context) {
  ScreenSize.init(context);
  
  // Access screen dimensions
  print('Width: ${ScreenSize.screenWidth}');
  print('Height: ${ScreenSize.screenHeight}');
  print('Device Type: ${ScreenSize.deviceCategory}');
}
```

#### Method 3: Using ScreenUtil (Already Implemented)
```dart
import 'package:flutter_screenutil/flutter_screenutil.dart';

// Access responsive sizes
double width = 200.w;  // Responsive width
double height = 100.h; // Responsive height
double fontSize = 16.sp; // Responsive font size
double radius = 8.r;     // Responsive radius
```

### Device Preview (Development)
```dart
// Already configured in main.dart
// In debug mode, Device Preview is automatically enabled
// You can test on different device sizes without physical devices
```

### Physical Device Testing
1. Connect device via USB
2. Run `flutter run` in terminal
3. Check logs for screen dimensions
4. Use Flutter DevTools to inspect layout

---

## 🎨 Responsive UI Implementation

### Current Implementation

Your app already uses a comprehensive responsive system:

#### 1. ScreenSize Utility (`lib/utils/screen_size.dart`)
- Automatic device type detection
- Responsive text sizes
- Responsive spacing
- Grid configurations
- Safe area handling

#### 2. ScreenUtil Integration
- Design size: 375 × 812 (iPhone X standard)
- Automatic scaling based on device size
- Responsive units: `.w`, `.h`, `.sp`, `.r`

### Best Practices

#### 1. Use ScreenSize for All Sizing
```dart
// ✅ Good
Container(
  padding: EdgeInsets.all(ScreenSize.paddingMedium),
  child: Text(
    'Hello',
    style: TextStyle(fontSize: ScreenSize.textLarge),
  ),
)

// ❌ Bad
Container(
  padding: EdgeInsets.all(16), // Fixed size
  child: Text(
    'Hello',
    style: TextStyle(fontSize: 16), // Fixed size
  ),
)
```

#### 2. Prevent Text Overflow
```dart
// ✅ Good
Text(
  productName,
  maxLines: 2,
  overflow: TextOverflow.ellipsis,
  style: TextStyle(fontSize: ScreenSize.textMedium),
)

// ❌ Bad
Text(productName) // Can overflow
```

#### 3. Use Flexible Layouts
```dart
// ✅ Good
Row(
  children: [
    Flexible(
      child: Text(
        longText,
        overflow: TextOverflow.ellipsis,
      ),
    ),
    Icon(Icons.arrow_forward),
  ],
)

// ❌ Bad
Row(
  children: [
    Text(longText), // Can overflow
    Icon(Icons.arrow_forward),
  ],
)
```

#### 4. Responsive Grids
```dart
// ✅ Good
GridView.builder(
  crossAxisCount: ScreenSize.gridCrossAxisCount, // 2 on phone, 3 on tablet
  childAspectRatio: ScreenSize.productCardAspectRatio,
  crossAxisSpacing: ScreenSize.gridSpacing,
  mainAxisSpacing: ScreenSize.gridSpacing,
  // ...
)
```

#### 5. Safe Area Handling
```dart
// ✅ Good
SafeArea(
  child: Scaffold(
    body: YourContent(),
  ),
)
```

#### 6. Scrollable Content
```dart
// ✅ Good - For long content
SingleChildScrollView(
  child: Column(
    children: [
      // Your content
    ],
  ),
)
```

---

## 📊 Breakpoints & Device Categories

### Current Breakpoints (from ScreenSize utility)

| Category | Width Range | Examples |
|----------|------------|----------|
| **Small Phone** | < 360px | iPhone SE (1st gen), small Android phones |
| **Medium Phone** | 360-414px | iPhone 12, iPhone 13, Samsung Galaxy S21, Google Pixel |
| **Large Phone** | 414-600px | iPhone 14 Pro Max, Samsung Galaxy S24 Ultra, Google Pixel 8 Pro |
| **Small Tablet** | 600-768px | iPad Mini, Samsung Galaxy Tab S8 |
| **Large Tablet** | ≥ 768px | iPad Pro, Samsung Galaxy Tab S9 Ultra |

### Responsive Scale Factors

| Device Type | Text Scale | Spacing Scale |
|------------|-----------|---------------|
| Small Phone | 0.85 | 0.8 |
| Medium Phone | 0.95 | 0.9 |
| Large Phone | 1.0 | 1.0 |
| Tablet | 1.1 | 1.2 |

### Grid Configurations

| Device Type | Grid Columns | Grid Spacing |
|------------|--------------|--------------|
| Phone | 2 | 16.w |
| Tablet | 3 | 20.w |

---

## ✅ Testing Checklist

### Device Testing Priority

#### High Priority (Most Common)
- [ ] iPhone 12/13 (390 × 844) - Medium Phone
- [ ] iPhone 14 Pro Max (430 × 932) - Large Phone
- [ ] Samsung Galaxy S24 (360 × 780) - Medium Phone
- [ ] Samsung Galaxy S24 Ultra (412 × 915) - Large Phone
- [ ] Google Pixel 8 (412 × 915) - Large Phone

#### Medium Priority
- [ ] iPhone SE (375 × 667) - Small Phone
- [ ] iPhone 16 Pro Max (442 × 960) - Large Phone
- [ ] iPad Mini (744 × 1133) - Small Tablet
- [ ] iPad Pro 12.9" (1024 × 1366) - Large Tablet
- [ ] Samsung Galaxy Tab S9 (800 × 1280) - Small Tablet

#### Low Priority (Edge Cases)
- [ ] iPhone SE (1st gen) (320 × 568) - Smallest Phone
- [ ] Very large Android tablets (1024 × 1366+)

### Testing Scenarios

#### Portrait Orientation
- [ ] All screens render correctly
- [ ] No overflow errors
- [ ] Text is readable
- [ ] Buttons are tappable
- [ ] Images load correctly
- [ ] Navigation works smoothly

#### Landscape Orientation
- [ ] Layouts adapt properly
- [ ] Grids show more columns
- [ ] No overflow errors
- [ ] Content is accessible

#### Accessibility
- [ ] Text scaling works (system font size)
- [ ] Touch targets are large enough (44×44 minimum)
- [ ] Colors have sufficient contrast
- [ ] Screen readers work

### Device Preview Testing

Use Device Preview (already configured) to test on:
- iPhone SE (small phone)
- iPhone 12 (medium phone)
- iPhone 14 Pro Max (large phone)
- iPad Mini (small tablet)
- iPad Pro (large tablet)
- Pixel 5 (Android medium)
- Samsung Galaxy S21 (Android large)

---

## 🔧 Quick Reference

### Common Screen Sizes

#### iPhone (Most Common)
- **iPhone 12/13**: 390 × 844 (Medium)
- **iPhone 14 Pro Max**: 430 × 932 (Large)
- **iPhone 15 Pro**: 393 × 852 (Medium)
- **iPhone 16 Pro Max**: 442 × 960 (Large)

#### Android (Most Common)
- **Samsung Galaxy S24**: 360 × 780 (Medium)
- **Samsung Galaxy S24 Ultra**: 412 × 915 (Large)
- **Google Pixel 8**: 412 × 915 (Large)
- **OnePlus 12**: 412 × 915 (Large)

### Design Reference Size
- **Base Design Size**: 375 × 812 (iPhone X)
- This is the reference size used in `ScreenUtilInit`

### Code Snippets

#### Get Current Screen Size
```dart
ScreenSize.init(context);
print('Width: ${ScreenSize.screenWidth}');
print('Height: ${ScreenSize.screenHeight}');
print('Device: ${ScreenSize.deviceCategory}');
```

#### Responsive Container
```dart
Container(
  width: ScreenSize.widthPercent(90), // 90% of screen width
  height: ScreenSize.heightPercent(50), // 50% of screen height
  padding: EdgeInsets.all(ScreenSize.paddingMedium),
)
```

#### Responsive Text
```dart
Text(
  'Hello World',
  style: TextStyle(
    fontSize: ScreenSize.textLarge,
    fontWeight: FontWeight.w600,
  ),
)
```

#### Responsive Button
```dart
ElevatedButton(
  style: ElevatedButton.styleFrom(
    minimumSize: Size(
      double.infinity,
      ScreenSize.buttonHeightMedium,
    ),
    padding: EdgeInsets.symmetric(
      horizontal: ScreenSize.buttonPaddingHorizontal,
      vertical: ScreenSize.buttonPaddingVertical,
    ),
  ),
  onPressed: () {},
  child: Text('Button'),
)
```

---

## 📚 Additional Resources

### Flutter Documentation
- [Responsive Design](https://docs.flutter.dev/development/ui/layout/responsive)
- [MediaQuery](https://api.flutter.dev/flutter/widgets/MediaQuery-class.html)
- [LayoutBuilder](https://api.flutter.dev/flutter/widgets/LayoutBuilder-class.html)

### Package Documentation
- [flutter_screenutil](https://pub.dev/packages/flutter_screenutil)
- [device_preview](https://pub.dev/packages/device_preview)

### Tools
- Flutter DevTools - Layout Explorer
- Device Preview - Multi-device testing
- Android Studio - Layout Inspector
- Xcode - View Debugger

---

**Last Updated**: 2025-01-27  
**Version**: 1.0.0  
**Maintained By**: E-Commerce Development Team

#   f o s  
 #   f o s n e w  
 #   f r u i t s o f s p i r i t  
 