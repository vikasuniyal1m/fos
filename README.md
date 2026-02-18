# Fruit of the Spirit App

## Project Overview
The Fruit of the Spirit app is a comprehensive mobile application built with Flutter, designed to foster spiritual growth and community interaction. It provides features for user authentication, content consumption (blogs, videos, gallery, stories), community engagement (prayer requests, groups, comments), and various utilities to enhance the user experience.

## Features

*   **User Authentication & Profiles:** Secure login, registration, and comprehensive user profile management.
*   **Content Management:** Access to spiritual "Fruits" (categories), engaging blog posts, inspiring videos, a rich image gallery, and personal stories.
*   **Community & Interaction:** Submit and view prayer requests, join and manage user groups, engage through comments, and express with emojis.
*   **Notifications & Reminders:** Stay updated with notifications and set personalized prayer reminders.
*   **Multimedia Experience:** Seamless video playback, easy image and video picking/cropping, and audio playback.
*   **Video Conferencing:** Integrated video conferencing capabilities using Agora RTC Engine.
*   **Offline Support:** Robust offline data storage powered by Hive.
*   **Responsive Design:** Optimized user interface for various screen sizes using Flutter ScreenUtil.
*   **Deep Linking & Sharing:** Effortless deep linking and content sharing functionalities.
*   **Internationalization:** Multi-language support for a global audience.
*   **Search Functionality:** Efficient search to find content and users.
*   **Analytics:** Integrated analytics to understand user engagement.
*   **E-commerce:** Future-proofed with e-commerce capabilities.
*   **Third-Party Integrations:** Firebase for backend services, Sign in with Apple, and Google Sign In for convenient authentication.

## Installation/Setup

### Prerequisites
*   Flutter SDK (version ^3.9.0 or higher)
*   Dart SDK (compatible with Flutter SDK)
*   A code editor like VS Code or Android Studio
*   Firebase project setup (for authentication and other services)
*   Agora.io account (for video conferencing features)

### Steps

1.  **Clone the repository:**
    ```bash
    git clone [repository_url]
    cd fruitsofspirit
    ```
2.  **Install dependencies:**
    ```bash
    flutter pub get
    ```
3.  **Configure Firebase:**
    *   Follow the official FlutterFire documentation to set up Firebase for your Android and iOS projects.
    *   Place your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) files in the respective project directories.
4.  **Configure Agora:**
    *   Obtain your App ID from the Agora.io console and configure it within the application (refer to `lib/config/agora_config.dart` if it exists, or relevant service files).
5.  **Run the application:**
    ```bash
    flutter run
    ```

## Usage
The app is designed for intuitive navigation. Upon launching, users can register or log in. The main dashboard provides access to various sections like Home, Fruits, Prayer Requests, Videos, and Gallery.

## Technologies Used

*   **Framework:** Flutter (version ^3.9.0)
*   **State Management:** GetX
*   **Local Storage:** Hive, Shared Preferences
*   **Networking:** `http` package
*   **Authentication:** Firebase Auth, Google Sign In, Sign in with Apple
*   **Multimedia:** `video_player`, `image_picker`, `image_cropper`, `audioplayers`
*   **Video Conferencing:** Agora RTC Engine
*   **UI/UX:** `flutter_screenutil`, `lottie` (for animations)
*   **Internationalization:** `easy_localization`
*   **Deep Linking:** `app_links`
*   **Sharing:** `share_plus`
*   **Other:** `permission_handler`, `cached_network_image`, `url_launcher`, `icons_plus`, `bootstrap_icons`

## Contributing
Contributions are welcome! Please follow these steps:
1.  Fork the repository.
2.  Create a new branch (`git checkout -b feature/your-feature-name`).
3.  Make your changes.
4.  Commit your changes (`git commit -m 'Add new feature'`).
5.  Push to the branch (`git push origin feature/your-feature-name`).
6.  Open a Pull Request.

## License
[Specify your license here, e.g., MIT License]

## Contact
For any inquiries or support, please contact [Your Email Address or Contact Information].

## UGC Moderation Workflow and Roadmap

This section outlines the necessary steps to implement robust User-Generated Content (UGC) moderation features in the Fruit of the Spirit app, addressing App Review Guideline 1.2.

**Core Requirements:**
1.  **EULA Acceptance:** Users must explicitly agree to Terms & Conditions (EULA) that clearly state a zero-tolerance policy for objectionable content.
2.  **Content Filtering:** A mechanism to filter objectionable content.
3.  **Content Flagging:** Users can flag objectionable content.
4.  **User Blocking:** Users can block abusive users, with developer notification and instant content removal from the blocker's feed.

---

### **Phase 1: EULA (End User License Agreement) Implementation**

**Objective:** Ensure all users explicitly agree to the app's Terms & Conditions before using the app.

**Frontend (Flutter) Modifications:**

*   **`lib/screens/onboarding_screen.dart` / `lib/routes/app_pages.dart`:**
    *   **Logic:** On first app launch or after a significant EULA update, redirect users to a dedicated EULA acceptance screen.
    *   **Implementation:**
        *   Check `UserStorage.hasAcceptedEula()` (already implemented, needs integration into the app's initial flow).
        *   If `false`, navigate to `EulaScreen`.
*   **`lib/screens/eula_screen.dart` (Already created, needs integration):**
    *   **UI:** Display the full Terms & Conditions content (fetched from `TermsService`).
    *   **Interaction:** Include a prominent checkbox "I agree to the Terms & Conditions" and an "Accept and Continue" button. The button should only be enabled when the checkbox is ticked.
    *   **Logic:** Upon acceptance, call `UserStorage.setEulaAccepted(true)` and then navigate the user to the main app (e.g., `Routes.LOGIN` or `Routes.HOME`).
*   **`lib/services/user_storage.dart` (Already modified):**
    *   **Logic:** `setEulaAccepted(bool accepted)` and `hasAcceptedEula()` methods are already in place using Hive to store acceptance status locally.
*   **`lib/screens/profile_screen.dart` / `lib/screens/settings_screen.dart`:**
    *   **UI:** Add an option for users to view the current Terms & Conditions at any time.

**Backend (PHP) Modifications:**

*   **`terms.php` (Existing):**
    *   **Content:** Ensure the terms content explicitly includes clauses about acceptable behavior, UGC guidelines, and a zero-tolerance policy for objectionable/abusive content. This is crucial for legal compliance.
*   **(Optional) New Endpoint: `eula_acceptance.php`:**
    *   **Purpose:** To record server-side confirmation of EULA acceptance for each user. This provides a robust audit trail.
    *   **Functionality:** Accepts `user_id` and `eula_version` (from `terms.php`) to log acceptance.

---

### **Phase 2: Content Filtering**

**Objective:** Prevent objectionable content from being posted and ensure a safe environment.

**Frontend (Flutter) Modifications:**

*   **`lib/screens/create_prayer_screen.dart` (and other UGC submission screens):**
    *   **Pre-submission Check (Optional but Recommended):** Implement a basic client-side profanity filter. This provides immediate feedback to the user but is not a substitute for server-side filtering.
    *   **Implementation:**
        *   Before calling `prayersController.createPrayer()`, add a function to check `contentController.text.trim()` against a local list of common objectionable words.
        *   If objectionable content is detected, show a `Get.snackbar` warning and prevent submission.
*   **`lib/controllers/prayers_controller.dart` (and other content controllers):**
    *   **Integration:** Ensure all content submission methods pass the content through a server-side filtering process.

**Backend (PHP) Modifications:**

*   **New Service/Function: `ContentModerationService.php`:**
    *   **Purpose:** Centralized logic for filtering all UGC.
    *   **Functionality:**
        *   **Keyword/Phrase Filtering:** Maintain a dynamic list of objectionable keywords and phrases (e.g., profanity, hate speech, sexually explicit terms). This list should be configurable by administrators.
        *   **AI/ML Integration (Advanced):** Consider integrating with third-party content moderation APIs (e.g., Google Cloud Content Moderation, Azure Content Moderator) for more sophisticated analysis, including image/video content, sentiment analysis, and context-aware filtering.
        *   **Action:**
            *   **Block:** If content is clearly and severely objectionable, block the submission entirely and return an error to the client.
            *   **Quarantine:** For borderline or suspicious content, mark it for manual review by an administrator. The content should not be visible to other users until approved.
            *   **Sanitize:** Automatically replace or censor certain words (e.g., `****`) if appropriate for less severe violations.
*   **`prayers.php`, `blogs.php`, `comments.php`, `stories.php` (and other UGC endpoints):**
    *   **Integration:** Before inserting any new UGC into the database, pass the content through `ContentModerationService.php`.
    *   **Database Schema Update:** Add a `moderation_status` column (e.g., `pending`, `approved`, `rejected`, `flagged`) and `moderation_notes` to relevant UGC tables.

---

### **Phase 3: User Flagging Mechanism**

**Objective:** Empower users to report objectionable content.

**Frontend (Flutter) Modifications:**

*   **UI Integration:**
    *   **`lib/widgets/prayer_card.dart` (and similar widgets for blogs, videos, comments):** Add a "Report" or "Flag" icon/button (e.g., in a three-dot menu) next to each piece of UGC.
    *   **`lib/screens/comment_list_screen.dart`:** Add a "Report" option for individual comments.
*   **Report Flow:**
    *   **`lib/screens/report_content_screen.dart` (New Screen):**
        *   **UI:** When a user taps "Report," navigate to this screen.
        *   **Options:** Provide a list of clear reporting categories (e.g., "Hate Speech," "Nudity," "Spam," "Harassment," "Misinformation").
        *   **Input:** (Optional) Allow users to add a brief text description for their report.
        *   **Confirmation:** A confirmation dialog before sending the report.
    *   **`lib/services/report_service.dart` (New Service):**
        *   **Functionality:** A new service to handle sending report data to the backend.
        *   **Method:** `reportContent({String contentType, int contentId, String reason, String? description})`.
    *   **User Feedback:** Display a success message (e.g., `Get.snackbar`) after a report is submitted.

**Backend (PHP) Modifications:**

*   **New Endpoint: `report.php`:**
    *   **Purpose:** Receives and processes user reports.
    *   **Input:** `user_id` (reporter), `content_type` (e.g., 'prayer', 'comment', 'blog'), `content_id`, `reason`, `description` (optional).
    *   **Database Schema Update:** Create a new `reports` table:
        *   `id` (PK)
        *   `reporter_user_id` (FK to users table)
        *   `content_type`
        *   `content_id`
        *   `reason`
        *   `description`
        *   `status` (e.g., `pending`, `reviewed`, `action_taken`)
        *   `created_at`
        *   `updated_at`
    *   **Logic:**
        *   Store the report in the `reports` table.
        *   **Admin Notification:** Implement a system to notify administrators (e.g., email, internal dashboard alert) about new reports.
        *   **Content Status Update:** Optionally, automatically change the `moderation_status` of the reported content to `flagged` or `pending_review` in its respective table.

---

### **Phase 4: User Blocking Mechanism**

**Objective:** Allow users to block abusive individuals and notify developers.

**Frontend (Flutter) Modifications:**

*   **UI Integration:**
    *   **User Profile Screens (`lib/screens/profile_screen.dart`):** Add a "Block User" button.
    *   **Comment/Group Interactions:** Add a "Block User" option in context menus where user interactions occur.
*   **Blocking Flow:**
    *   **Confirmation:** A confirmation dialog asking "Are you sure you want to block this user? You will no longer see their content, and they will not be able to interact with you."
    *   **`lib/services/user_blocking_service.dart` (New Service):**
        *   **Functionality:** A new service to handle sending block requests to the backend.
        *   **Method:** `blockUser({int blockedUserId})`.
    *   **Immediate UI Update:** Upon successful blocking, immediately hide all content from the blocked user within the blocker's app view. This can be achieved by filtering local data or refreshing relevant feeds.
    *   **User Feedback:** Display a success message (e.g., `Get.snackbar`).

**Backend (PHP) Modifications:**

*   **New Endpoint: `block_user.php`:**
    *   **Purpose:** Handles user blocking requests.
    *   **Input:** `blocker_user_id`, `blocked_user_id`.
    *   **Database Schema Update:** Create a new `user_blocks` table:
        *   `id` (PK)
        *   `blocker_user_id` (FK to users table)
        *   `blocked_user_id` (FK to users table)
        *   `created_at`
    *   **Logic:**
        *   Record the block relationship in the `user_blocks` table.
        *   **Content Filtering:** Modify all content retrieval queries (for prayers, comments, groups, etc.) to exclude content from `blocked_user_id` when requested by `blocker_user_id`.
        *   **Developer Notification:** **Crucial:** When a user is blocked, automatically generate an internal notification or report to administrators/developers. This should include `blocker_user_id`, `blocked_user_id`, and potentially a link to the `blocked_user_id`'s profile for review. This fulfills the "notify the developer of the inappropriate content" requirement.
        *   **Automated Content Review:** Consider automatically flagging or quarantining all recent UGC from the `blocked_user_id` for administrator review.

---

### **Phase 5: Administrator Tools (Backend/Admin Panel)**

**Objective:** Provide administrators with the tools to manage UGC and users effectively.

**Backend (PHP) / Admin Panel (Separate Application):**

*   **Admin Dashboard:** A dedicated web interface for administrators.
*   **Report Management:**
    *   View all pending reports.
    *   Review reported content and user profiles.
    *   Take action: approve, reject, delete content, warn user, suspend user, ban user.
    *   Mark reports as reviewed.
*   **User Management:**
    *   View user profiles, including their UGC history.
    *   Ability to suspend or ban users.
    *   View user blocking relationships.
*   **Content Filtering Configuration:**
    *   Manage the list of objectionable keywords/phrases for the content filter.
    *   Configure sensitivity levels for automated filtering.
*   **EULA Management:**
    *   View current EULA version.
    *   (Optional) Upload new EULA versions, which would trigger re-acceptance for all users.

---

### **Module-Specific Emoji Handling Roadmap**

This section outlines a comprehensive roadmap for implementing module-specific emoji handling, addressing the user's request to save "how are you feeling" data to the database without affecting other components and resolving non-visible updates.

**Objective:** Implement a flexible and efficient system for users to express feelings (general) and react to specific content (posts, comments) using emojis, ensuring data integrity, performance, and real-time visibility.

**Note on Compatibility:** Based on a thorough analysis of the `mysqldatabasetablewithdata` file, the proposed changes to the `emoji_usage` table (adding a composite index) and the `emojis.php` API (enhancing existing endpoints and adding new ones) are designed to be **non-breaking**. Existing functionalities will remain unaffected, and the implementation will ensure smooth operation.

---

### **Phase 1: Database Preparation**

**Objective:** Optimize the `emoji_usage` table for module-specific emoji reactions and general feeling tracking.

*   **`database_migrations/update_emoji_usage_replace_feeling.sql`:**
    *   **Action:** Add a composite index to the `emoji_usage` table to improve query performance for module-specific lookups.
    *   **SQL:**
        ```sql
        -- Add a composite index for efficient lookups by post_type and post_id
        CREATE INDEX idx_emoji_usage_post_type_post_id ON emoji_usage (post_type, post_id);
        ```
    *   **Rationale:** This index will significantly speed up queries when fetching emojis for a specific post type and ID, or when querying for general feelings (where `post_type` and `post_id` are `NULL`).

---

### **Phase 2: Backend API Enhancement (PHP)**

**Objective:** Extend the `emojis.php` API to support saving, retrieving, and managing module-specific emoji reactions and general user feelings.

*   **`api/emojis.php`:**
    *   **Action 1: Enhance `saveEmojiReaction` (or similar existing endpoint):**
        *   **Functionality:** Modify the existing endpoint (or create a new one) to accept `post_type` and `post_id` as optional parameters.
        *   **Logic:**
            *   If `post_type` and `post_id` are provided, save the emoji as a reaction to that specific content.
            *   If `post_type` and `post_id` are `NULL`, save the emoji as a general "how are you feeling" entry.
            *   Ensure that for general feelings, only the latest entry for a user is considered active (i.e., update existing or insert new).
        *   **Example Request (General Feeling):**
            ```
            POST /api/emojis.php
            {
                "user_id": 37,
                "emoji": "joy_pineapple_02",
                "post_type": null,
                "post_id": null
            }
            ```
        *   **Example Request (Post Reaction):**
            ```
            POST /api/emojis.php
            {
                "user_id": 37,
                "emoji": "love_strawberry_01",
                "post_type": "blog",
                "post_id": 123
            }
            ```
    *   **Action 2: Implement `getEmojiReactions` Endpoint:**
        *   **Functionality:** A new endpoint to fetch all emoji reactions for a specific `post_type` and `post_id`.
        *   **Example Request:**
            ```
            GET /api/emojis.php?action=get_reactions&post_type=blog&post_id=123
            ```
        *   **Response:** A list of emojis and their counts, or detailed user reactions.
    *   **Action 3: Implement `getUserFeeling` Endpoint:**
        *   **Functionality:** A new endpoint to fetch the latest general "how are you feeling" emoji for a specific user.
        *   **Logic:** Query `emoji_usage` where `user_id` matches, and `post_type` and `post_id` are `NULL`, ordered by `created_at` DESC, limit 1.
        *   **Example Request:**
            ```
            GET /api/emojis.php?action=get_user_feeling&user_id=37
            ```
        *   **Response:** The latest feeling emoji object for the user, or `null` if none exists.

---

### **Phase 3: Flutter Frontend Integration**

**Objective:** Integrate the new API endpoints into the Flutter application, update UI components, and manage local caching for real-time updates.

*   **`lib/services/api_service.dart`:**
    *   **Action 1: Add `saveEmojiReaction` Method:**
        *   **Signature:**
            ```dart
            Future<ApiResponse> saveEmojiReaction({
              required int userId,
              required String emoji,
              String? postType,
              int? postId,
            });
            ```
        *   **Logic:** Call the backend `emojis.php` endpoint with the appropriate parameters.
    *   **Action 2: Add `getEmojiReactions` Method:**
        *   **Signature:**
            ```dart
            Future<ApiResponse<List<Map<String, dynamic>>>> getEmojiReactions({
              required String postType,
              required int postId,
            });
            ```
        *   **Logic:** Call the backend `emojis.php` endpoint to fetch reactions for a specific post.
    *   **Action 3: Add `getUserFeeling` Method:**
        *   **Signature:**
            ```dart
            Future<ApiResponse<Map<String, dynamic>?>> getUserFeeling({
              required int userId,
            });
            ```
        *   **Logic:** Call the backend `emojis.php` endpoint to fetch the user's latest general feeling.

*   **`lib/screens/fruits_screen.dart` (or relevant "How are you feeling" UI component):**
    *   **Action 1: Display Current Feeling:**
        *   **Logic:** On `initState`, call `ApiService.getUserFeeling()` to fetch and display the user's current feeling.
    *   **Action 2: Update Feeling:**
        *   **Logic:** When a user selects a new "how are you feeling" emoji:
            1.  Call `ApiService.saveEmojiReaction()` with `postType: null` and `postId: null`.
            2.  **Crucially, invalidate the local Hive cache for `fruits_screen_emojis` and `fruits_screen_all_variants` immediately after a successful update.** This will force `_loadFruitEmojis()` to fetch fresh data from the API, resolving the "non-visible updates" issue.
            3.  Refresh the UI to reflect the new feeling.
    *   **Action 3: Cache Management:**
        *   **Logic:** Ensure that `_loadFruitEmojis()` always prioritizes fresh data from the API after a feeling update, and only uses cache for initial, instant display. Implement a mechanism to clear relevant cache entries when data is updated.

*   **`lib/controllers/gallery_controller.dart`, `lib/controllers/blogs_controller.dart` (and other content-specific controllers):**
    *   **Action:** Modify existing emoji reaction logic to use `ApiService.saveEmojiReaction()` with `postType` and `postId` parameters.
    *   **Action:** Implement `ApiService.getEmojiReactions()` to display reactions for specific posts.

---

### **Phase 4: Testing and Validation**

**Objective:** Ensure all new functionalities work as expected, are performant, and do not introduce regressions.

*   **Unit Tests:**
    *   Write unit tests for `ApiService` methods (`saveEmojiReaction`, `getEmojiReactions`, `getUserFeeling`).
    *   Test `emojis.php` backend endpoints for various scenarios (valid/invalid input, general feeling, post reactions).
*   **Integration Tests:**
    *   Test the end-to-end flow of saving and retrieving general user feelings.
    *   Test the end-to-end flow of saving and retrieving post-specific emoji reactions.
    *   Verify that updating a feeling immediately reflects on the UI (cache invalidation working).
*   **Performance Testing:**
    *   Monitor database query performance with the new index.
    *   Assess API response times for emoji-related endpoints.
*   **User Acceptance Testing (UAT):**
    *   Have users test the "how are you feeling" feature and post reactions to ensure an intuitive and bug-free experience.
    *   Verify that no other components are negatively affected.

---

### **Summary of Key Modification Areas for Emoji Handling:**

*   **Database:** `emoji_usage` table (add composite index).
*   **Backend (PHP):** `api/emojis.php` (enhance existing or add new endpoints for saving/getting general feelings and module-specific reactions).
*   **Frontend (Flutter):**
    *   `lib/services/api_service.dart` (add new methods for emoji API calls).
    *   `lib/screens/fruits_screen.dart` (or "How are you feeling" UI): Integrate API calls, implement cache invalidation, update UI display logic.
    *   `lib/controllers/gallery_controller.dart`, `lib/controllers/blogs_controller.dart` (and other content controllers): Update emoji reaction logic.
    *   `lib/services/hive_cache_service.dart` (or similar): Ensure cache invalidation mechanisms are robust.


---

### **Summary of Key Modification Areas:**

*   **Frontend (Flutter):**
    *   `lib/screens/onboarding_screen.dart`: EULA redirection logic.
    *   `lib/screens/eula_screen.dart`: EULA display and acceptance UI/logic.
    *   `lib/services/user_storage.2.dart`: EULA acceptance status (already done).
    *   `lib/screens/create_prayer_screen.dart` (and other UGC submission screens): Client-side content filtering (optional), integration with server-side filtering.
    *   `lib/widgets/prayer_card.dart` (and similar content display widgets): "Report" button/menu.
    *   `lib/screens/report_content_screen.dart` (New): UI for reporting content.
    *   `lib/services/report_service.dart` (New): Logic for sending reports.
    *   User Profile/Interaction screens: "Block User" button/menu.
    *   `lib/services/user_blocking_service.dart` (New): Logic for blocking users.
    *   Content display logic: Filter out blocked users' content.
*   **Backend (PHP):**
    *   `terms.php`: Update EULA content with moderation clauses.
    *   `ContentModerationService.php` (New): Centralized content filtering logic.
    *   `prayers.php`, `blogs.php`, `comments.php`, `stories.php`: Integrate content filtering before saving UGC.
    *   `report.php` (New): Endpoint for receiving user reports.
    *   `block_user.php` (New): Endpoint for handling user blocks.
    *   Database Schema: New tables for `reports` and `user_blocks`. Add `moderation_status` to UGC tables.
    *   Admin Notification System: For new reports and user blocks.
    *   (Optional) `eula_acceptance.php` (New): Endpoint to record server-side EULA acceptance.
    *   (Optional) Admin Panel: A separate web application for moderation.
