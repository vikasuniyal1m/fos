import 'package:get/get.dart';
// Controllers
import 'package:fruitsofspirit/controllers/home_controller.dart';
import 'package:fruitsofspirit/controllers/forgot_password_controller.dart';
import 'package:fruitsofspirit/controllers/fruits_controller.dart';
import 'package:fruitsofspirit/controllers/prayers_controller.dart';
import 'package:fruitsofspirit/controllers/videos_controller.dart';
import 'package:fruitsofspirit/controllers/blogs_controller.dart';
import 'package:fruitsofspirit/controllers/gallery_controller.dart';
import 'package:fruitsofspirit/controllers/groups_controller.dart';
import 'package:fruitsofspirit/controllers/group_posts_controller.dart';
import 'package:fruitsofspirit/controllers/profile_controller.dart';
import 'package:fruitsofspirit/controllers/notifications_controller.dart';
import 'package:fruitsofspirit/controllers/prayer_reminders_controller.dart';
// Screens
import 'package:fruitsofspirit/screens/splash_screen.dart';
import 'package:fruitsofspirit/screens/home_screen.dart';
import 'package:fruitsofspirit/screens/onboarding_screen.dart';
import 'package:fruitsofspirit/screens/login_screen.dart';
import 'package:fruitsofspirit/screens/create_account_screen.dart';
import 'package:fruitsofspirit/screens/phone_auth_screen.dart';
import 'package:fruitsofspirit/screens/forgot_password_screen.dart';
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

part 'app_routes.dart';

class AppPages {
  AppPages._();

  static const INITIAL = Routes.SPLASH;

  static final routes = [
    GetPage(
      name: _Paths.SPLASH,
      page: () => const SplashScreen(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: _Paths.HOME,
      page: () => const HomeScreen(),
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
      binding: BindingsBuilder(() {
        Get.lazyPut<HomeController>(() => HomeController());
      }),
      middlewares: [
        // AuthMiddleware(), // Uncomment if you want route-level auth check
      ],
    ),
    GetPage(
      name: _Paths.ONBOARDING, // Define the route for onboarding
      page: () => const OnboardingScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: _Paths.LOGIN, // Define the route for login
      page: () => const LoginScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: _Paths.CREATE_ACCOUNT, // Define the route for create account
      page: () => const CreateAccountScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),

    GetPage(
      name: _Paths.PHONE_AUTH, // Define the route for phone authentication
      page: () => const PhoneAuthScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: _Paths.FORGOT_PASSWORD,
      page: () => const ForgotPasswordScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
      binding: BindingsBuilder(() {
        Get.lazyPut<ForgotPasswordController>(() => ForgotPasswordController());
      }),
    ),
    
    // Feature Routes
    GetPage(
      name: _Paths.FRUITS,
      page: () => const FruitsScreen(),
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
      binding: BindingsBuilder(() {
        Get.lazyPut<FruitsController>(() => FruitsController());
      }),
    ),
    GetPage(
      name: _Paths.PRAYER_REQUESTS,
      page: () => const PrayerRequestsScreen(),
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
      binding: BindingsBuilder(() {
        Get.lazyPut<PrayersController>(() => PrayersController());
      }),
    ),
    GetPage(
      name: _Paths.CREATE_PRAYER,
      page: () => const CreatePrayerScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
      binding: BindingsBuilder(() {
        Get.lazyPut<PrayersController>(() => PrayersController());
        Get.lazyPut<GroupsController>(() => GroupsController());
      }),
    ),
    GetPage(
      name: _Paths.PRAYER_DETAILS,
      page: () => const PrayerDetailsScreen(),
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
      binding: BindingsBuilder(() {
        Get.lazyPut<PrayersController>(() => PrayersController());
      }),
    ),
    GetPage(
      name: _Paths.VIDEOS,
      page: () => const VideosScreen(),
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
      binding: BindingsBuilder(() {
        Get.lazyPut<VideosController>(() => VideosController());
      }),
    ),
    GetPage(
      name: _Paths.VIDEO_DETAILS,
      page: () => const VideoDetailsScreen(),
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
      binding: BindingsBuilder(() {
        Get.lazyPut<VideosController>(() => VideosController());
      }),
    ),
    GetPage(
      name: _Paths.UPLOAD_VIDEO,
      page: () => const UploadVideoScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
      binding: BindingsBuilder(() {
        Get.lazyPut<VideosController>(() => VideosController());
      }),
    ),
    GetPage(
      name: _Paths.BLOGS,
      page: () => const BlogsScreen(),
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
      binding: BindingsBuilder(() {
        Get.lazyPut<BlogsController>(() => BlogsController());
      }),
    ),
    GetPage(
      name: _Paths.BLOGGER_ZONE,
      page: () => const BloggerZoneScreen(),
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
      binding: BindingsBuilder(() {
        Get.lazyPut<BlogsController>(() => BlogsController());
      }),
    ),
    GetPage(
      name: _Paths.BLOG_DETAILS,
      page: () => const BlogDetailsScreen(),
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
      binding: BindingsBuilder(() {
        Get.lazyPut<BlogsController>(() => BlogsController());
      }),
    ),
    GetPage(
      name: _Paths.CREATE_BLOG,
      page: () => const CreateBlogScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
      binding: BindingsBuilder(() {
        Get.lazyPut<BlogsController>(() => BlogsController());
      }),
    ),
    GetPage(
      name: _Paths.GALLERY,
      page: () =>  GalleryScreen(),
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
      binding: BindingsBuilder(() {
        Get.lazyPut<GalleryController>(() => GalleryController());
      }),
    ),
    GetPage(
      name: _Paths.PHOTO_DETAILS,
      page: () => const PhotoDetailsScreen(),
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
      binding: BindingsBuilder(() {
        Get.lazyPut<GalleryController>(() => GalleryController());
      }),
    ),
    GetPage(
      name: _Paths.UPLOAD_PHOTO,
      page: () => const UploadPhotoScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
      binding: BindingsBuilder(() {
        Get.lazyPut<GalleryController>(() => GalleryController());
      }),
    ),
    GetPage(
      name: _Paths.GROUPS,
      page: () => const GroupsScreen(),
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
      binding: BindingsBuilder(() {
        Get.lazyPut<GroupsController>(() => GroupsController());
      }),
    ),
    GetPage(
      name: _Paths.GROUP_DETAILS,
      page: () => const GroupDetailsScreen(),
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
      binding: BindingsBuilder(() {
        Get.lazyPut<GroupsController>(() => GroupsController());
      }),
    ),
    GetPage(
      name: _Paths.GROUP_CHAT,
      page: () {
        final groupId = Get.arguments as int? ?? 0;
        return GroupChatScreen(groupId: groupId);
      },
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
      binding: BindingsBuilder(() {
        Get.lazyPut<GroupPostsController>(() => GroupPostsController());
        Get.lazyPut<GroupsController>(() => GroupsController());
      }),
    ),
    GetPage(
      name: _Paths.CREATE_GROUP,
      page: () => const CreateGroupScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
      binding: BindingsBuilder(() {
        Get.lazyPut<GroupsController>(() => GroupsController());
      }),
    ),
    GetPage(
      name: _Paths.PROFILE,
      page: () => const ProfileScreen(),
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
      binding: BindingsBuilder(() {
        Get.lazyPut<ProfileController>(() => ProfileController());
      }),
    ),
    GetPage(
      name: _Paths.EDIT_PROFILE,
      page: () => const EditProfileScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
      binding: BindingsBuilder(() {
        Get.lazyPut<ProfileController>(() => ProfileController());
      }),
    ),
    GetPage(
      name: _Paths.STORIES,
      page: () => const StoriesScreen(),
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: _Paths.CREATE_STORY,
      page: () => const CreateStoryScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: _Paths.STORY_DETAILS,
      page: () => const StoryDetailsScreen(),
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: _Paths.SEARCH,
      page: () => const SearchScreen(),
      transition: Transition.downToUp,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: _Paths.NOTIFICATIONS,
      page: () => const NotificationsScreen(),
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
      binding: BindingsBuilder(() {
        Get.lazyPut<NotificationsController>(() => NotificationsController());
      }),
    ),
    GetPage(
      name: _Paths.SAVED_CONTENT,
      page: () => const SavedContentScreen(),
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: _Paths.TERMS,
      page: () => const TermsScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: _Paths.FRUIT_DETAILS,
      page: () => const FruitDetailsScreen(),
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    GetPage(
      name: _Paths.FRUITS_VARIANT_01,
      page: () => const FruitsVariant01Screen(),
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
      binding: BindingsBuilder(() {
        Get.lazyPut<FruitsController>(() => FruitsController());
      }),
    ),
    GetPage(
      name: _Paths.PRAYER_REMINDERS,
      page: () => const PrayerRemindersScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
      binding: BindingsBuilder(() {
        Get.lazyPut<PrayerRemindersController>(() => PrayerRemindersController());
      }),
    ),
  ];
}