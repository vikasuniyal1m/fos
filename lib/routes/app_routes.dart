part of 'app_pages.dart';

// Export Routes class for external use
// Routes can be accessed via app_pages.dart import

abstract class Routes {
  Routes._();
  // Auth Routes
  static const SPLASH = _Paths.SPLASH;
  static const HOME = _Paths.HOME;
  static const ONBOARDING = _Paths.ONBOARDING;
  static const LOGIN = _Paths.LOGIN;
  static const CREATE_ACCOUNT = _Paths.CREATE_ACCOUNT;
  static const PHONE_AUTH = _Paths.PHONE_AUTH;
  static const FORGOT_PASSWORD = _Paths.FORGOT_PASSWORD;
  
  // Feature Routes
  static const FRUITS = _Paths.FRUITS;
  static const PRAYER_REQUESTS = _Paths.PRAYER_REQUESTS;
  static const CREATE_PRAYER = _Paths.CREATE_PRAYER;
  static const PRAYER_DETAILS = _Paths.PRAYER_DETAILS;
  static const VIDEOS = _Paths.VIDEOS;
  static const VIDEO_DETAILS = _Paths.VIDEO_DETAILS;
  static const UPLOAD_VIDEO = _Paths.UPLOAD_VIDEO;
  static const BLOGS = _Paths.BLOGS;
  static const BLOGGER_ZONE = _Paths.BLOGGER_ZONE;
  static const BLOG_DETAILS = _Paths.BLOG_DETAILS;
  static const CREATE_BLOG = _Paths.CREATE_BLOG;
  static const GALLERY = _Paths.GALLERY;
  static const PHOTO_DETAILS = _Paths.PHOTO_DETAILS;
  static const UPLOAD_PHOTO = _Paths.UPLOAD_PHOTO;
  static const GROUPS = _Paths.GROUPS;
  static const GROUP_DETAILS = _Paths.GROUP_DETAILS;
  static const GROUP_CHAT = _Paths.GROUP_CHAT;
  static const CREATE_GROUP = _Paths.CREATE_GROUP;
  static const PROFILE = _Paths.PROFILE;
  static const EDIT_PROFILE = _Paths.EDIT_PROFILE;
  static const STORIES = _Paths.STORIES;
  static const CREATE_STORY = _Paths.CREATE_STORY;
  static const STORY_DETAILS = _Paths.STORY_DETAILS;
  static const SEARCH = _Paths.SEARCH;
  static const NOTIFICATIONS = _Paths.NOTIFICATIONS;
  static const SAVED_CONTENT = _Paths.SAVED_CONTENT;
  static const TERMS = _Paths.TERMS;
  static const FRUIT_DETAILS = _Paths.FRUIT_DETAILS;
  static const FRUITS_VARIANT_01 = _Paths.FRUITS_VARIANT_01;
  static const PRAYER_REMINDERS = _Paths.PRAYER_REMINDERS;
}

abstract class _Paths {
  _Paths._();
  // Auth Paths
  static const SPLASH = '/splash';
  static const HOME = '/home';
  static const ONBOARDING = '/onboarding';
  static const LOGIN = '/login';
  static const CREATE_ACCOUNT = '/create-account';
  static const PHONE_AUTH = '/phone-auth';
  static const FORGOT_PASSWORD = '/forgot-password';
  
  // Feature Paths
  static const FRUITS = '/fruits';
  static const PRAYER_REQUESTS = '/prayer-requests';
  static const CREATE_PRAYER = '/create-prayer';
  static const PRAYER_DETAILS = '/prayer-details';
  static const VIDEOS = '/videos';
  static const VIDEO_DETAILS = '/video-details';
  static const UPLOAD_VIDEO = '/upload-video';
  static const BLOGS = '/blogs';
  static const BLOGGER_ZONE = '/blogger-zone';
  static const BLOG_DETAILS = '/blog-details';
  static const CREATE_BLOG = '/create-blog';
  static const GALLERY = '/gallery';
  static const PHOTO_DETAILS = '/photo-details';
  static const UPLOAD_PHOTO = '/upload-photo';
  static const GROUPS = '/groups';
  static const GROUP_DETAILS = '/group-details';
  static const GROUP_CHAT = '/group-chat';
  static const CREATE_GROUP = '/create-group';
  static const PROFILE = '/profile';
  static const EDIT_PROFILE = '/edit-profile';
  static const STORIES = '/stories';
  static const CREATE_STORY = '/create-story';
  static const STORY_DETAILS = '/story-details';
  static const SEARCH = '/search';
  static const NOTIFICATIONS = '/notifications';
  static const SAVED_CONTENT = '/saved-content';
  static const TERMS = '/terms';
  static const FRUIT_DETAILS = '/fruit-details';
  static const FRUITS_VARIANT_01 = '/fruits-variant-01';
  static const PRAYER_REMINDERS = '/prayer-reminders';
}