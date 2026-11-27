# Performance Baseline & Side-by-Side Testing

**Use this BEFORE and AFTER every refactor task.**  
Pair with `AUDIT_CHECKLIST.md` — tick **Tested** only when baseline numbers improve or stay same + features work.

**Device:** _______________ (model, iOS/Android)  
**Build:** _______________ (debug / profile / release)  
**Date:** _______________  
**Network:** _______________ (Wi‑Fi / 4G / throttled)

---

## Rule: 3 runs, median value

Har test **3 baar** chalao, beech wala number likho. Ek run se decide mat karo.

---

## Phase 0 — Baseline (koi code change NAHI)

> **Splash se optimize mat shuru karo pehle.**  
> Pehle numbers record karo, phir chote fixes (Search → Cache → Home).

### A. Startup timeline (stopwatch / screen recording)

| Checkpoint | What you see | Baseline (sec) | After fix (sec) |
|------------|--------------|----------------|-----------------|
| T0 | App icon tap | — | — |
| T1 | Splash image visible | | |
| T2 | Dashboard / Home first paint (content ya spinner) | | |
| T3 | Home feeds populated (fruit + 1 carousel with data) | | |
| **T2−T0** | **Time to interactive** | | |
| **T3−T0** | **Time to full home data** | | |

**Notes:**
- First launch = extra ~3s scripture delay (`splash_screen.dart`) — alag row likho.
- Logged-in repeat launch = real user experience.

### B. Flutter DevTools (profile mode build)

```bash
flutter run --profile
```

Open **DevTools → Performance → Record** during:

1. Cold start → home
2. Home scroll 10 seconds
3. Open Search → type fast 5 seconds

| Metric | Baseline | After fix |
|--------|----------|-----------|
| Home scroll: missed frames / jank | | |
| Home scroll: avg frame time (ms) | | |
| Search: UI rebuild count (if visible) | | |

### C. Network (DevTools → Network, or Charles/Proxyman)

| API call | When | Baseline size/time | After fix |
|----------|------|-------------------|-----------|
| `loadAllHomeData` (9 parallel) | After splash | | |
| `search.php` | One search | | |
| `blogs.php` | Blogger zone | | |

### D. Feature smoke (same as AUDIT regression)

| Pass? | Test |
|-------|------|
| [ ] | Login → dashboard |
| [ ] | Home carousels scroll |
| [ ] | Search works |
| [ ] | Blog + prayer detail open |

---

## Where slowness actually lives (your app)

```
main.dart _initializeDependencies()     ← Hive, Intro, Jingle, i18n, push, deep link
        ↓
splash_screen.dart                    ← 1.2s anim + optional 3s first launch (INTENTIONAL)
        ↓
DataLoadingService (9 APIs parallel)  ← BIGGEST data wait
        ↓
InitialBinding (permanent controllers)  ← memory + onInit work
        ↓
home_screen.dart (8000+ lines)        ← BIGGEST UI jank
```

| Area | Optimize when? | Priority |
|------|----------------|----------|
| Splash animation/delay | Only if product allows shorter scripture time | P2 |
| `main.dart` init | After baseline; defer non-critical services | P1 |
| `DataLoadingService` + dual cache | Week 2 (A6, C2.3) | P0 |
| `home_screen` Obx split | Week 2–3 (C2.1) | P0 |
| **Search stale guard** | **Week 1 pilot (C11.1)** | P0 — safest first **code** change |

---

## Phase 1 — First code change: Search only (C11.1)

**Before:** Run Phase 0 tables once → save as "Baseline v1".

**Change:** `lib/screens/search_screen.dart` — request generation guard.

**After:** Re-run only:

| Test | Baseline | After C11.1 | Better? |
|------|----------|-------------|---------|
| Fast type "j"→"jo"→"john" — final result correct | pass/fail | | |
| Wrong stale results seen? | yes/no | | |
| Home cold start (T3−T0) | sec | sec | should be **same** |
| Regression smoke (D) | | | all pass |

> Search fix se startup faster **nahi** hoga — ye correctness + race fix hai. Startup ke liye Phase 2.

---

## Phase 2 — Startup & cache (after Search passes)

Order:

1. **A6 / C2.3** — single Hive cache (no dual prefs+Hieve)
2. **C2.1** — split home `Obx`
3. **main.dart** — defer `JingleService` / analytics / push after first frame (measure T2 again)

Re-measure **T2−T0** and **T3−T0** after each phase.

---

## Phase 3 — Backend (parallel)

When frontend baseline done:

- B1 `blogs.php`, B2 `search.php`, B3 `gallery.php`

Re-measure API times in table C.

---

## Side-by-side testing tips

1. **Same device, same network** every run.
2. **Profile mode** for FPS; **release** for final sign-off.
3. **Kill app** between cold-start tests (swipe away, not hot restart).
4. Screenshot baseline table → after each PR, nayi column "After fix".
5. Agar number same but bug fix (Search stale) → still ship; note "correctness fix, perf unchanged".

---

## Quick command reference

```bash
# Profile (performance testing)
flutter run --profile

# Release (final validation)
flutter run --release

# Clear app data (fresh cache test)
# Android: Settings → Apps → FOS → Clear storage
# iOS: Delete app, reinstall
```

---

## Log template (copy per session)

```
=== Session: _______
Task ID: _______ (e.g. C11.1)
Build: profile / release

T2−T0: ___s → ___s
T3−T0: ___s → ___s
Search stale bug: yes/no → yes/no
Regression: pass/fail
Notes:
```

---

## Suggested start order (summary)

| Step | Action | Code? |
|------|--------|-------|
| **0** | Fill Phase 0 baseline in this file | No |
| **1** | C11.1 Search fix | Yes — 1 file |
| **2** | Re-test Phase 1 table + regression | No |
| **3** | A6 + C2.3 cache unify | Yes |
| **4** | Re-measure T2, T3 | No |
| **5** | C2.1 home Obx split | Yes |
| **6** | Splash / main init (only if baseline proves bottleneck) | Yes |

**Splash se mat shuru karo — pehle baseline, phir Search pilot.**
