# API Services Documentation

## 📁 Service Files Created

### 1. **API Configuration** (`config/api_config.dart`)
- Base URL configuration
- API endpoints constants
- Request headers
- Timeout settings

### 2. **Base API Service** (`services/api_service.dart`)
- Common API operations (GET, POST, DELETE)
- Multipart file upload support
- Error handling
- Network exception handling

### 3. **Authentication Service** (`services/auth_service.dart`)
- `login()` - User login
- `register()` - User registration
- `forgotPassword()` - Send OTP
- `verifyOtpAndResetPassword()` - Reset password

### 4. **Fruits Service** (`services/fruits_service.dart`)
- `getAllFruits()` - Get all fruits
- `getUserFruits()` - Get user's selected fruits
- `addFruitToUser()` - Add fruit to user
- `removeFruitFromUser()` - Remove fruit from user

### 5. **Prayers Service** (`services/prayers_service.dart`)
- `getPrayers()` - Get prayer requests list
- `getPrayerDetails()` - Get single prayer with responses
- `createPrayerRequest()` - Create new prayer request

### 6. **Blogs Service** (`services/blogs_service.dart`)
- `getBlogs()` - Get blogs list
- `getBlogDetails()` - Get single blog with comments/likes
- `createBlog()` - Create blog (bloggers only, with image upload)

### 7. **Comments Service** (`services/comments_service.dart`)
- `getComments()` - Get comments for a post
- `addComment()` - Add comment
- `toggleBlogLike()` - Like/Unlike blog

### 8. **Videos Service** (`services/videos_service.dart`)
- `getVideos()` - Get videos list
- `getVideoDetails()` - Get single video with comments
- `uploadVideo()` - Upload video (multipart)
- `getLiveVideos()` - Get live videos

### 9. **Gallery Service** (`services/gallery_service.dart`)
- `getPhotos()` - Get photos list
- `getPhotoDetails()` - Get single photo with comments
- `uploadPhoto()` - Upload photo with testimony (multipart)

### 10. **Emojis Service** (`services/emojis_service.dart`)
- `getEmojis()` - Get emojis list
- `useEmoji()` - Use emoji (track usage)

### 11. **Groups Service** (`services/groups_service.dart`)
- `getGroups()` - Get groups list
- `getGroupDetails()` - Get single group details
- `createGroup()` - Create group (with image upload)
- `joinGroup()` - Join group
- `leaveGroup()` - Leave group
- `getGroupMembers()` - Get group members

### 12. **Notifications Service** (`services/notifications_service.dart`)
- `getNotifications()` - Get user notifications
- `markAsRead()` - Mark notification as read
- `getUnreadCount()` - Get unread count

### 13. **Profile Service** (`services/profile_service.dart`)
- `getProfile()` - Get user profile with stats
- `updateProfile()` - Update profile (with photo upload)

### 14. **User Storage** (`services/user_storage.dart`)
- `saveUser()` - Save user data
- `getUser()` - Get user data
- `getUserId()` - Get user ID
- `isLoggedIn()` - Check login status
- `clearUser()` - Logout
- `updateUser()` - Update user data

---

## 🚀 Usage Examples

### Login Example:
```dart
import 'package:fruitsofspirit/services/auth_service.dart';
import 'package:fruitsofspirit/services/user_storage.dart';

try {
  final user = await AuthService.login(
    email: 'user@example.com',
    password: 'password123',
  );
  await UserStorage.saveUser(user);
  // Navigate to home
} catch (e) {
  // Show error
}
```

### Get Fruits Example:
```dart
import 'package:fruitsofspirit/services/fruits_service.dart';

try {
  final fruits = await FruitsService.getAllFruits();
  // Display fruits
} catch (e) {
  // Show error
}
```

### Create Prayer Example:
```dart
import 'package:fruitsofspirit/services/prayers_service.dart';
import 'package:fruitsofspirit/services/user_storage.dart';

try {
  final userId = await UserStorage.getUserId();
  final prayerId = await PrayersService.createPrayerRequest(
    userId: userId!,
    category: 'Healing',
    content: 'Please pray for my family',
  );
  // Show success
} catch (e) {
  // Show error
}
```

### Upload Photo Example:
```dart
import 'dart:io';
import 'package:fruitsofspirit/services/gallery_service.dart';
import 'package:fruitsofspirit/services/user_storage.dart';
import 'package:image_picker/image_picker.dart';

final picker = ImagePicker();
final image = await picker.pickImage(source: ImageSource.gallery);

if (image != null) {
  try {
    final userId = await UserStorage.getUserId();
    final result = await GalleryService.uploadPhoto(
      userId: userId!,
      photoFile: File(image.path),
      fruitTag: 'Love',
      testimony: 'This is my testimony',
    );
    // Show success
  } catch (e) {
    // Show error
  }
}
```

---

## ✅ All Services Ready!

All services have been created and are ready to use. You can now integrate them into your screens!

