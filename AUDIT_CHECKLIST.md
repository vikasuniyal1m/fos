# Fruits of the Spirit — Refactor & Audit Checklist

**Repo:** `fos`  
**Frontend:** `lib/`  
**Backend:** `admin/api/`

**Rules**

- Har task ke baad **Tested** check karo — feature pehle jaisa kaam kare.
- Ek PR = 1–3 related rows; merge se pehle **Regression** section.
- `[ ]` = pending · `[x]` = done

**Status:** Last updated: 2026-06-08 — **Blogs module complete + user tested.** Next: Notifications (C12.1) → Stories (C8.1) → Groups (C9)  
**Owner:** ___________

### Pilot progress (module-by-module)

| Module | Status | What shipped |
|--------|--------|--------------|
| **Search** | Done + Tested | Stale-request guard, single `type=all` API, 5-min cache, tab = client filter, session cache on re-open, blog carousel `CachedImage` |
| **Blogs** | Done + Tested | Prayer pattern: Hive list/detail, silent sync, pagination, create (compress upload), delete, share, comments, B1 backend |
| **Gallery** | Done + Tested | Same pattern; `seedFromHomeIfEmpty`, tab switch silent refresh, filter reset on open |
| **Prayers** | Done + Tested | List + detail silent sync, comment add/delete instant, emoji/sticker cache, submit/delete fast |
| **Videos** | Done + Tested | Same pattern; thumbnails fixed via `video_thumbnail` package |
| **Group chat polling** | Done — test karo | C9.1/C9.2: adaptive poll 5–15s, `after_id` incremental, stop on leave/background |
| **Groups** | Done — test karo | C9.3: silent sync, home seed, `navigateToGroups` |
| **Stories** | Done — test karo | C8.1: `StoriesController`, Hive cache, `navigateToStories` |
| **Group posts** | Done — test karo | silent sync, home seed on open |
| **Home cache unify** | Done — test karo | A6 / C2.3: Hive only, prefs migrate, list trim |
| **Notifications** | Done — test karo | C12.1: Hive cache, instant open, optimistic read, live badge count |

---

## How to use

| Column | Meaning |
|--------|---------|
| **Done** | Implementation complete |
| **Tested** | Manual/automated test pass; no regression |
| **Notes** | PR link, date, blocker |

---

## Regression (har PR ke baad — sab tick karo)

| Done | Tested | Test |
|------|--------|------|
| [ ] | [ ] | Cold start → home / dashboard loads |
| [ ] | [ ] | Login → logout → login |
| [ ] | [ ] | Register (email / phone / social if used) |
| [ ] | [ ] | Home feeds visible (fruit, prayers, blogs, videos) |
| [ ] | [x] | Open blog → comment → back |
| [ ] | [x] | Blogger zone: 2nd open instant; create blog; delete own pending post |
| [ ] | [x] | Open prayer list from home/tab (instant, no full reload) |
| [x] | [x] | Open prayer detail → comment → back (instant + silent sync) |
| [ ] | [ ] | Open photo/video detail |
| [ ] | [x] | Search: type fast → correct final results |
| [ ] | [ ] | Group chat: send → receive → leave screen (no background poll) |
| [ ] | [ ] | Upload photo |
| [ ] | [ ] | Upload video |
| [ ] | [ ] | Premium / IAP gate (if changed) |
| [ ] | [ ] | Profile edit + save |
| [ ] | [ ] | Offline: cached content still shows |

---

# A — Global infrastructure

| ID | Done | Tested | Priority | Task | Files | Testing (feature must work) |
|----|------|--------|----------|------|-------|-------------------------------|
| A1 | [ ] | [ ] | P0 | DB credentials → env; remove from repo | `admin/includes/db.php` | All APIs still connect |
| A2 | [ ] | [ ] | P0 | JWT → flutter_secure_storage + migration | `lib/services/auth_token_storage.dart` | Login, API calls, logout |
| A3 | [ ] | [ ] | P1 | Shared Dio/ApiClient (replace http gradually) | `lib/services/api_service.dart`, services | All main API calls OK |
| A4 | [ ] | [ ] | P1 | 401 refresh + request queue | interceptor, `admin/api/auth.php` | Token expiry → auto retry or login |
| A5 | [x] | [x] | P0 | Search/filter cancel or request-id | search, blogs, gallery, prayers (+ church locator pending) | Fast filter → no stale UI |
| A6 | [x] | [ ] | P0 | Single cache layer (Hive); prefs = flags only | cache + hive + data_loading | Cold start + refresh data correct |
| A7 | [ ] | [ ] | P1 | Large JSON → isolate parse | `lib/services/api_service.dart` | Home load, big lists |
| A8 | [ ] | [ ] | P1 | Firebase Crashlytics | `lib/main.dart` | App launches; test crash in debug |
| A9 | [ ] | [ ] | P2 | Remove/guard debug print | `lib/` | No behavior change |
| A10 | [ ] | [ ] | P1 | Review InitialBinding permanent controllers | `lib/bindings/InitialBinding.dart` | Tab switch, memory acceptable |

**Notes (A):**

---

# B — Backend (`admin/api/`)

| ID | Done | Tested | Priority | Task | File | Testing |
|----|------|--------|----------|------|------|---------|
| B1 | [x] | [x] | P0 | Blog list: COUNT subqueries → JOIN aggregates | `blogs.php` | Blog list + counts match |
| B2 | [ ] | [ ] | P0 | Search optimize + indexes | `search.php` | Search all types |
| B3 | [ ] | [ ] | P0 | Gallery list query + indexes | `gallery.php` | Gallery load |
| B4 | [ ] | [ ] | P1 | Prayers list optimize | `prayers.php` | Prayer list |
| B5 | [ ] | [ ] | P1 | Videos list optimize | `videos.php` | Video list |
| B6 | [ ] | [ ] | P1 | Stories list optimize | `stories.php` | Stories list |
| B7 | [x] | [x] | P1 | Comments: soft-delete filter on GET | `comments.php` | Delete comment stays gone on reload |
| B8 | [ ] | [ ] | P1 | groups.php query review / split | `groups.php` | Groups list + detail |
| B9 | [ ] | [ ] | P0 | Chat: `since_id` / incremental messages | `group-chat.php` | Chat sync, no duplicates |
| B10 | [ ] | [ ] | P1 | ETag on static feeds | emojis, banners, denominations, prayer_types, calendar | Faster repeat load |
| B11 | [ ] | [ ] | P1 | auth refresh action (backward compatible) | `auth.php` | Login + refresh |
| B12 | [ ] | [ ] | P2 | analytics batch/async | `analytics.php` | Events still recorded |
| B13 | [ ] | [ ] | P0 | Disable test APIs in production | test*.php | No public test endpoints |
| B14 | [ ] | [ ] | P1 | Emoji image cache headers | `get-emoji-image.php` | Emojis on home/fruit |
| B15 | [ ] | [ ] | P1 | Live viewer count idempotency | `live_streaming/*` | Live start/stop/viewers |
| B16 | [ ] | [ ] | P0 | IAP verify security audit | verify-iap, iap-verify, check_premium | Purchase + premium |
| B17 | [ ] | [ ] | P1 | Stripe payment endpoints review | `payment/*` | Payment flow if used |
| B18 | [ ] | [ ] | P0 | profile/block auth on mutations | profile, block_user | Profile edit, block user |

**Notes (B):**

---

# C1 — Auth & profile

| ID | Done | Tested | Priority | Task | Files | Testing |
|----|------|--------|----------|------|-------|---------|
| C1.1 | [ ] | [ ] | P2 | Split login/create_account widgets | login, create_account | Register + login |
| C1.2 | [ ] | [ ] | P2 | Unify API exceptions | auth, otp, api_service | Error messages OK |
| C1.3 | [ ] | [ ] | P1 | Profile narrow Obx + cache | profile_* | Profile load/edit |
| C1.4 | [ ] | [ ] | P1 | Edit profile upload timeout | edit_profile | Photo upload profile |
| C1.5 | [ ] | [ ] | P2 | Blocked users list builder | blocked_users | Block list |
| C1.6 | [ ] | [ ] | P1 | OTP / forgot / reset flows | phone_auth, forgot, reset | Full password recovery |

---

# C2 — Home

| ID | Done | Tested | Priority | Task | Files | Testing |
|----|------|--------|----------|------|-------|---------|
| C2.1 | [ ] | [ ] | P0 | Split home Obx by section | `lib/screens/home_screen.dart` | Home scroll, all carousels |
| C2.2 | [ ] | [ ] | P1 | Split home_controller domains | `lib/controllers/home_controller.dart` | Feeling, fruit, feeds |
| C2.3 | [x] | [ ] | P0 | data_loading → single Hive cache | `lib/services/data_loading_service.dart` | Fast cold start |
| C2.4 | [ ] | [ ] | P2 | Optional bundled home API (PHP) | new endpoint | Same home content |
| C2.5 | [ ] | [ ] | P1 | Image URL normalize once; RepaintBoundary | cached_image, home | Images sharp, no flicker |

---

# C3 — Fruit / emoji

| ID | Done | Tested | Priority | Task | Files | Testing |
|----|------|--------|----------|------|-------|---------|
| C3.0 | [x] | [ ] | P0 | Home feeling: Hive cache-first + optimistic update | `home_controller.dart`, `fruit_screen.dart`, `home_screen.dart` | Pick fruit → instant home, no loader/delay |
| C3.1 | [ ] | [ ] | P1 | Thin fruit screens + cache | fruit_* | Fruit picker, details |
| C3.2 | [ ] | [ ] | P1 | CachedImage: no build-time regex | `lib/widgets/cached_image.dart` | Emoji/images everywhere |
| C3.3 | [ ] | [ ] | P1 | Client respects emoji HTTP cache | emojis + get-emoji-image | Fruit/emojis load |

---

# C4 — Prayers

| ID | Done | Tested | Priority | Task | Files | Testing |
|----|------|--------|----------|------|-------|---------|
| C4.1 | [x] | [x] | P1 | prayers list + detail: silent sync, home/Hive seed | `prayers_controller.dart`, `prayer_details_screen.dart`, `home_screen.dart` | List + detail instant, comment add/delete, emoji picker |
| C4.2 | [ ] | [ ] | P1 | Split prayer_details_screen | `lib/screens/prayer_details_screen.dart` | View, comment, react |
| C4.3 | [ ] | [ ] | P1 | create_prayer upload/compress | `lib/screens/create_prayer_screen.dart` | New prayer posts |
| C4.4 | [ ] | [ ] | P2 | prayer_reminders sync | prayer_reminders_* | Reminders fire |

---

# C5 — Blogs

| ID | Done | Tested | Priority | Task | Files | Testing |
|----|------|--------|----------|------|-------|---------|
| C5.1 | [x] | [x] | P0 | blogs list + detail: cache, silent sync, fast comments | `blogs_controller.dart`, `blog_details_screen.dart`, `home_screen.dart`, `blogger_zone_screen.dart` | Open blog instant, add/delete comment fast |
| C5.2 | [x] | [x] | P1 | Pagination strategy (20/page + load more) | blogs_controller, blogs_screen, blogger_zone | List + load more |
| C5.3 | [x] | [x] | P1 | _allBlogs → Hive keyed cache (`blogs_list`, `blog_detail_{id}`) | blogs_controller | Blogger zone instant |
| C5.4 | [ ] | [ ] | P1 | Split blog_details_screen | `lib/screens/blog_details_screen.dart` | Read, comment, like |
| C5.5 | [x] | [x] | P1 | blogger_zone Obx + silent sync | `lib/screens/blogger_zone_screen.dart` | Zone loads, no repeat spinner |
| C5.6 | [x] | [x] | P0 | Backend B1 done | `admin/api/blogs.php` | Counts correct |
| C5.7 | [x] | [x] | P0 | Create blog: no duplicate submit, keyboard dismiss, image compress | `create_blog_screen.dart`, `blogs_service.dart` | Fast publish |
| C5.8 | [x] | [x] | P0 | Delete blog: optimistic local remove + home/zone sync | `blogs_controller.dart`, `blog_details_screen.dart` | Own pending post deletes |
| C5.9 | [x] | [x] | P1 | Share clean URL + image | `share_helper.dart`, `admin/api/share/` | `fosmessenger.com/share/blog/{id}` |
| C5.10 | [x] | [x] | P1 | blogs_screen silent sync (profile filter) | `blogs_screen.dart` | No blocking reload |

---

# C6 — Videos

| ID | Done | Tested | Priority | Task | Files | Testing |
|----|------|--------|----------|------|-------|---------|
| C6.1 | [x] | [ ] | P1 | videos_controller: cancel + silent sync + home seed | `lib/controllers/videos_controller.dart`, `home_screen.dart`, `videos_screen.dart` | Video tab, Home→Videos instant |
| C6.2 | [ ] | [ ] | P1 | Split video_details_screen | `lib/screens/video_details_screen.dart` | Play, comment |
| C6.3 | [ ] | [ ] | P1 | upload_video background compress | `lib/screens/upload_video_screen.dart` | Upload works |
| C6.4 | [ ] | [ ] | P1 | Backend B5 | `admin/api/videos.php` | List OK |

---

# C7 — Gallery

| ID | Done | Tested | Priority | Task | Files | Testing |
|----|------|--------|----------|------|-------|---------|
| C7.1 | [x] | [x] | P1 | gallery_controller: cancel + silent sync + home seed | `lib/controllers/gallery_controller.dart`, `home_screen.dart`, `main_dashboard_controller.dart` | Gallery grid, Home→Gallery instant |
| C7.2 | [ ] | [ ] | P1 | Split photo_details_screen | `lib/screens/photo_details_screen.dart` | Photo view, comments |
| C7.3 | [ ] | [ ] | P1 | upload_photo size cap | `lib/screens/upload_photo_screen.dart` | Upload works |
| C7.4 | [ ] | [ ] | P0 | Backend B3 | `admin/api/gallery.php` | Gallery API |

---

# C8 — Stories

| ID | Done | Tested | Priority | Task | Files | Testing |
|----|------|--------|----------|------|-------|---------|
| C8.1 | [x] | [ ] | P1 | Stories controller + cache + silent sync | `stories_controller.dart`, `stories_screen.dart` | Story list instant |
| C8.2 | [ ] | [ ] | P1 | Backend B6 | `admin/api/stories.php` | Stories API |

---

# C9 — Groups & chat

| ID | Done | Tested | Priority | Task | Files | Testing |
|----|------|--------|----------|------|-------|---------|
| C9.1 | [x] | [ ] | P0 | Adaptive polling + incremental after_id | `lib/controllers/group_chat_controller.dart` | New messages, order OK |
| C9.2 | [x] | [ ] | P0 | Stop poll on leave + app background | `lib/screens/real_group_chat_screen.dart` | No API after leave |
| C9.3 | [x] | [ ] | P1 | groups/posts silent sync + home seed | `groups_controller.dart`, `group_posts_controller.dart` | Groups list, posts |
| C9.4 | [ ] | [ ] | P0 | Backend B8 + B9 | groups, group-chat | Chat + groups |

---

# C10 — Live (Agora)

| ID | Done | Tested | Priority | Task | Files | Testing |
|----|------|--------|----------|------|-------|---------|
| C10.1 | [ ] | [ ] | P1 | agora_live: reduce setState → Rx | `lib/screens/agora_live_screen.dart` | Go live, watch |
| C10.2 | [ ] | [ ] | P1 | live_stream cleanup on end | `lib/controllers/live_stream_controller.dart` | Stream ends cleanly |
| C10.3 | [ ] | [ ] | P1 | Backend B15 | `admin/api/live_streaming/*` | Viewers, comments |

---

# C11 — Search

| ID | Done | Tested | Priority | Task | Files | Testing |
|----|------|--------|----------|------|-------|---------|
| C11.1 | [x] | [x] | P0 | Search: stale guard + cache + session re-open | `lib/screens/search_screen.dart` | Fast typing, tab filter, re-open instant, blog carousel images |
| C11.2 | [ ] | [ ] | P0 | Backend B2 | `admin/api/search.php` | All content types |

---

# C12 — Notifications

| ID | Done | Tested | Priority | Task | Files | Testing |
|----|------|--------|----------|------|-------|---------|
| C12.1 | [x] | [ ] | P2 | Notifications: cache, silent sync, optimistic read, badge | `notifications_controller.dart`, `standard_app_bar.dart` | Bell badge, instant list, tap marks read |
| C12.2 | [ ] | [ ] | P1 | Push token refresh | `lib/services/push_notification_service.dart` | Push receive |

---

# C13 — Church locator

| ID | Done | Tested | Priority | Task | Files | Testing |
|----|------|--------|----------|------|-------|---------|
| C13.1 | [ ] | [ ] | P0 | Throttle 2s navigation timer | `lib/controllers/church_locator_controller.dart` | Map + navigation |
| C13.2 | [ ] | [ ] | P1 | Split church locator controller | church_locator_* | Search churches |
| C13.3 | [ ] | [ ] | P0 | Places search debounce + cancel | `lib/services/places_service.dart` | Search no stale markers |

---

# C14 — Payments / IAP

| ID | Done | Tested | Priority | Task | Files | Testing |
|----|------|--------|----------|------|-------|---------|
| C14.1 | [ ] | [ ] | P0 | IAP backend sync idempotent | `lib/services/iap_service.dart` | Buy + restore |
| C14.2 | [ ] | [ ] | P1 | payment_gate single premium source | `lib/services/payment_gate.dart` | Gated routes work |
| C14.3 | [ ] | [ ] | P0 | Backend B16 | IAP PHP | Premium status |

---

# C15 — Misc

| ID | Done | Tested | Priority | Task | Files | Testing |
|----|------|--------|----------|------|-------|---------|
| C15.1 | [ ] | [ ] | P2 | Translation cache | `lib/services/translate_service.dart` | Translate UI |
| C15.2 | [ ] | [ ] | P1 | Analytics + Crashlytics | analytics, main | Events + crashes |
| C15.3 | [ ] | [ ] | P2 | Deep links | `lib/services/deep_link_service.dart` | Open shared link |
| C15.4 | [ ] | [ ] | P2 | ETag client for banners/calendar | widgets, services | Banners, calendar |
| C15.5 | [ ] | [ ] | P2 | Content moderation review | `lib/services/content_moderation_service.dart` | Post still works |

---

# Progress summary

| Phase | Total | Done | Tested |
|-------|-------|------|--------|
| P0 | 31 | 8 | 8 |
| P1 | 56 | 12 | 12 |
| P2 | 18 | 0 | 0 |
| **All** | 105 | 20 | 20 |

_Pilot scope: A5, A6, C4.1, **C5 complete**, C7.1, C11.1 (+ Home nav). Prayer + Blogs modules complete._

---

# Suggested order (Week 1 → 4)

```
Done:  A5, A6, C2.3, C4.1 ✓, C5 ✓ (full), C6.1, C7.1, C8.1, C9.1–C9.3, C11.1, B1, B7
Next:  C12.1 Notifications (test) → C8.1 Stories (test) → C9 Groups (test)
Then:  A2, B13, B16, B2, B3, B9 (backend/security)
Later: C4.2 split prayer_details_screen, C5.4 split blog_details_screen, C7.2, …
```

---

# PR log

| Date | PR / branch | IDs completed | Tester | Regression all pass? |
|------|-------------|---------------|--------|----------------------|
| 2026-06-08 | local | C11.1 Search: stale guard, cache, tabs, session re-open | user | [x] |
| 2026-06-08 | local | C5.1 Blogs + `navigateToBloggerZone` fast open | user | [x] |
| 2026-06-08 | local | C7.1 Gallery + `navigateToGallery`, tab silent sync | user | [x] |
| 2026-06-08 | local | C11.1 Search blog carousel: `CachedImage` + `cacheExtent` | user | [x] |
| 2026-06-08 | local | C4.1 Prayers list + `navigateToPrayerRequests`, tab silent sync | user | [x] |
| 2026-06-08 | local | C4.1 Prayer detail: `preparePrayerDetails`, Hive seed, silent sync | user | [x] |
| 2026-06-08 | local | C4.1 Prayer: optimistic comment add/delete, emoji/sticker cache, submit/delete fast | user | [x] |
| 2026-06-08 | local | B7 comments.php: filter `is_deleted` on GET | user | [x] |
| 2026-06-08 | local | C6.1 Videos + `navigateToVideos`, tab/screen silent sync | user | [x] |
| 2026-06-08 | local | C9.1/C9.2 Group chat adaptive polling + stop on leave | — | [ ] |
| 2026-06-08 | local | A6/C2.3 Hive-only cache, prefs migration, list trim | — | [ ] |
| 2026-06-08 | local | C8.1 Stories + C9.3 Groups/posts silent sync | — | [ ] |
| 2026-06-08 | local | C11.1 Search initial load fix (home/Hive seed) | user | [x] |
| 2026-06-08 | local | C12.1 Notifications: optimistic read, badge count, resume silent sync | user | [x] |
| 2026-06-08 | local | C5.2/C5.3/C5.5/C5.6: pagination, Hive list, blogs_screen silent sync, blogs.php JOIN counts | user | [x] |
| 2026-06-08 | local | C5.1 Blogs: prepareBlogDetails, Hive, optimistic comments, navigateToBlogDetail | user | [x] |
| 2026-06-08 | local | C5.7 Create blog: duplicate guard, keyboard dismiss, image compress, fast redirect | user | [x] |
| 2026-06-08 | local | C5.8 Delete blog: optimistic remove, home + zone UI sync | user | [x] |
| 2026-06-08 | local | C5.9 Share: clean URL `fosmessenger.com/share/blog/{id}` + image | user | [x] |
| 2026-06-08 | local | B1 blogs.php: COUNT subqueries → JOIN aggregates | user | [x] |

---

# Blockers

| ID | Blocker | Owner |
|----|---------|-------|
| | | |
