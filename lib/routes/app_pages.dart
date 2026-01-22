import 'package:get/get.dart';
import 'package:fruitsofspirit/screens/main_dashboard_screen.dart';
import 'package:fruitsofspirit/controllers/main_dashboard_controller.dart';
import 'package:fruitsofspirit/screens/splash_screen.dart';
import 'package:fruitsofspirit/screens/onboarding_screen.dart';
import 'package:fruitsofspirit/screens/login_screen.dart';
import 'package:fruitsofspirit/screens/create_account_screen.dart';
import 'package:fruitsofspirit/screens/phone_auth_screen.dart';
import 'package:fruitsofspirit/screens/forgot_password_screen.dart';
import 'package:fruitsofspirit/screens/home_screen.dart';
import 'package:fruitsofspirit/screens/fruits_screen.dart';
import 'package:fruitsofspirit/screens/prayer_requests_screen.dart';
import 'package:fruitsofspirit/screens/create_prayer_screen.dart';
import 'package:fruitsofspirit/screens/prayer_details_screen.dart';
import 'package:fruitsofspirit/screens/videos_screen.dart';
import 'package:fruitsofspirit/screens/video_details_screen.dart';
import 'package:fruitsofspirit/screens/upload_video_screen.dart';
import 'package:fruitsofspirit/screens/blogs_screen.dart';
import 'package:fruitsofspirit/screens/blogger_zone_screen.dart';
import 'package:fruitsofspirit/screens/blog_details_screen.dart';
import 'package:fruitsofspirit/screens/create_blog_screen.dart';
import 'package:fruitsofspirit/screens/gallery_screen.dart';
import 'package:fruitsofspirit/screens/photo_details_screen.dart';
import 'package:fruitsofspirit/screens/upload_photo_screen.dart';
import 'package:fruitsofspirit/screens/groups_screen.dart';
import 'package:fruitsofspirit/screens/group_details_screen.dart';
import 'package:fruitsofspirit/screens/group_chat_screen.dart';
import 'package:fruitsofspirit/screens/create_group_screen.dart';
import 'package:fruitsofspirit/screens/profile_screen.dart';
import 'package:fruitsofspirit/bindings/profile_binding.dart';
import 'package:fruitsofspirit/screens/edit_profile_screen.dart';
import 'package:fruitsofspirit/screens/stories_screen.dart';
import 'package:fruitsofspirit/screens/create_story_screen.dart';
import 'package:fruitsofspirit/screens/story_details_screen.dart';
import 'package:fruitsofspirit/screens/search_screen.dart';
import 'package:fruitsofspirit/screens/notifications_screen.dart';
import 'package:fruitsofspirit/screens/saved_content_screen.dart';
import 'package:fruitsofspirit/screens/terms_screen.dart';
import 'package:fruitsofspirit/screens/fruit_details_screen.dart';
import 'package:fruitsofspirit/screens/fruits_variant_01_screen.dart';
import 'package:fruitsofspirit/screens/prayer_reminders_screen.dart';
import 'package:fruitsofspirit/screens/live_screen.dart';

part 'app_routes.dart';

class AppPages {
  AppPages._();

  static const INITIAL = Routes.SPLASH;

  static final routes = [
    GetPage(
      name: Routes.SPLASH,
      page: () => const SplashScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.DASHBOARD,
      page: () => const MainDashboardScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.ONBOARDING,
      page: () => const OnboardingScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.LOGIN,
      page: () => const LoginScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.CREATE_ACCOUNT,
      page: () => const CreateAccountScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.PHONE_AUTH,
      page: () => const PhoneAuthScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.FORGOT_PASSWORD,
      page: () => const ForgotPasswordScreen(),
      transition: Transition.fadeIn,
    ),

    GetPage(
      name: Routes.HOME,
      page: () => const HomeScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.FRUITS,
      page: () => const FruitsScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.PRAYER_REQUESTS,
      page: () => const PrayerRequestsScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.CREATE_PRAYER,
      page: () => const CreatePrayerScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.PRAYER_DETAILS,
      page: () => const PrayerDetailsScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.VIDEOS,
      page: () => const VideosScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.VIDEO_DETAILS,
      page: () => const VideoDetailsScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.UPLOAD_VIDEO,
      page: () => const UploadVideoScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.BLOGS,
      page: () => const BlogsScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.BLOGGER_ZONE,
      page: () => const BloggerZoneScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.BLOG_DETAILS,
      page: () => const BlogDetailsScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.CREATE_BLOG,
      page: () => const CreateBlogScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.GALLERY,
      page: () => const GalleryScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.PHOTO_DETAILS,
      page: () => const PhotoDetailsScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.UPLOAD_PHOTO,
      page: () => const UploadPhotoScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.GROUPS,
      page: () => const GroupsScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.GROUP_DETAILS,
      page: () {
        final groupId = Get.arguments as int?;
        return GroupDetailsScreen(groupId: groupId);
      },
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.GROUP_CHAT,
      page: () {
        final groupId = Get.arguments as int? ?? 0;
        return GroupChatScreen(groupId: groupId);
      },
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.CREATE_GROUP,
      page: () => const CreateGroupScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.PROFILE,
      page: () => const ProfileScreen(),
      binding: ProfileBinding(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.EDIT_PROFILE,
      page: () => const EditProfileScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.STORIES,
      page: () => const StoriesScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.CREATE_STORY,
      page: () => const CreateStoryScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.STORY_DETAILS,
      page: () => const StoryDetailsScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.SEARCH,
      page: () => const SearchScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.NOTIFICATIONS,
      page: () => const NotificationsScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.SAVED_CONTENT,
      page: () => const SavedContentScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.TERMS,
      page: () => const TermsScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.FRUIT_DETAILS,
      page: () => const FruitDetailsScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.FRUITS_VARIANT_01,
      page: () => const FruitsVariant01Screen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.PRAYER_REMINDERS,
      page: () => const PrayerRemindersScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.LIVE,
      page: () => const LiveScreen(),
      transition: Transition.fadeIn,
    ),
  ];
}
