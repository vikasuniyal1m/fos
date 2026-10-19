#!/usr/bin/env bash
# =============================================================================
# FOS Messenger — ONE command release build
#   • Android APK  (phone test + IAP)
#   • Android AAB  (Play Store upload)
#   • iOS Runner   (you Archive in Xcode → TestFlight)
#
# Usage:
#   cd /path/to/fos
#   ./scripts/build_for_store.sh
#
# Optional: SKIP_IOS=1 | SKIP_ANDROID=1 | SKIP_CLEAN=1 | SKIP_ANALYZE=1
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
step() { echo -e "\n${CYAN}▶ $*${NC}"; }
ok()   { echo -e "${GREEN}✔ $*${NC}"; }
warn() { echo -e "${YELLOW}⚠ $*${NC}"; }
fail() { echo -e "${RED}✖ $*${NC}"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_DIR}"

DEBUG_INFO_DIR="${PROJECT_DIR}/build/debug-info"
DIST_DIR="${PROJECT_DIR}/build/dist"
IOS_WORKSPACE="${PROJECT_DIR}/ios/Runner.xcworkspace"

BUILD_FLAGS=(
  --release
  --obfuscate
  --split-debug-info="${DEBUG_INFO_DIR}"
  --tree-shake-icons
  --dart-define=FLUTTER_APP_ENV=production
)

# ── Helpers ───────────────────────────────────────────────────────────────────
ensure_flutterignore() {
  [[ -f .flutterignore ]] && return 0
  cat > .flutterignore <<'IGN'
admin/
vendor/
**/*.md
README*
**/*.zip
docs/
.git/
.github/
IGN
}

verify_pubspec_no_admin() {
  if grep -qiE 'admin/|\.zip' pubspec.yaml 2>/dev/null; then
    fail "pubspec.yaml must not list admin/ or .zip assets."
  fi
  ok "pubspec.yaml clean (no admin/zip assets)"
}

scrub_dist_junk() {
  rm -rf "${DIST_DIR}/admin" 2>/dev/null || true
  find "${DIST_DIR}" -maxdepth 3 -type f \( -iname '*.md' -o -iname '*.zip' \) -delete 2>/dev/null || true
}

verify_iap_ready() {
  step "IAP release checks"
  grep -q 'com.android.vending.BILLING' android/app/src/main/AndroidManifest.xml || \
    fail "Missing BILLING permission in AndroidManifest.xml"
  grep -q 'com.fruitsofspirit.android.premium' lib/services/iap_service.dart || \
    fail "Android IAP product id not found in iap_service.dart"
  grep -q 'com.fruitsofspirit.ios.fosproductions' lib/services/iap_service.dart || \
    fail "iOS IAP product id not found in iap_service.dart"
  ok "IAP product IDs + BILLING permission OK"
}

verify_android_signing() {
  [[ -f android/key.properties ]] || \
    fail "android/key.properties missing — release APK/AAB cannot sign. Create keystore first."
  ok "Android signing config found"
}

verify_apk_clean() {
  local apk="$1"
  [[ -f "${apk}" ]] || return 0
  command -v unzip >/dev/null 2>&1 || return 0
  if unzip -l "${apk}" 2>/dev/null | grep -qiE 'admin/|\.md$|\.zip$'; then
    fail "APK contains excluded admin/md/zip: ${apk}"
  fi
  ok "APK clean (no admin/README/zip)"
}

# ══════════════════════════════════════════════════════════════════════════════
# START
# ══════════════════════════════════════════════════════════════════════════════
step "FOS Messenger — release build (IAP + APK + AAB + iOS)"
command -v flutter >/dev/null 2>&1 || fail "flutter not in PATH"

[[ "$(uname -s)" != "Darwin" ]] && SKIP_IOS=1

APP_VERSION="$(grep '^version:' pubspec.yaml | head -1 | awk '{print $2}')"
ok "Version: ${APP_VERSION}"

mkdir -p "${DIST_DIR}" "${DEBUG_INFO_DIR}"

step "Exclude admin / README / zip from app bundle"
ensure_flutterignore
verify_pubspec_no_admin
scrub_dist_junk

if [[ "${SKIP_CLEAN:-0}" != "1" ]]; then
  step "flutter clean"
  flutter clean
fi

step "flutter pub get"
flutter pub get

verify_iap_ready

if [[ "${SKIP_ANALYZE:-0}" != "1" ]]; then
  step "flutter analyze"
  flutter analyze || warn "Analyze warnings — fix if possible"
fi

# ── iOS (TestFlight — manual Archive) ────────────────────────────────────────
if [[ "${SKIP_IOS:-0}" != "1" ]]; then
  command -v pod >/dev/null 2>&1 || fail "pod not found — run: sudo gem install cocoapods"

  step "iOS: precache + pod install"
  flutter precache --ios
  pushd ios >/dev/null
  pod install --repo-update
  popd >/dev/null

  step "iOS: flutter build ios --release --no-codesign"
  flutter build ios --release --no-codesign "${BUILD_FLAGS[@]}"
  ok "iOS Runner.app ready — Archive in Xcode"
fi

# ── Android (APK + AAB with IAP) ─────────────────────────────────────────────
if [[ "${SKIP_ANDROID:-0}" != "1" ]]; then
  verify_android_signing

  step "Android: release APK (arm64 — install on phone, test IAP)"
  flutter build apk --split-per-abi "${BUILD_FLAGS[@]}"

  step "Android: release AAB (upload to Play Console)"
  flutter build appbundle "${BUILD_FLAGS[@]}"

  scrub_dist_junk

  APK_SRC="build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
  AAB_SRC="build/app/outputs/bundle/release/app-release.aab"
  APK_OUT="${DIST_DIR}/fos-${APP_VERSION}-release.apk"
  AAB_OUT="${DIST_DIR}/fos-${APP_VERSION}-release.aab"

  [[ -f "${APK_SRC}" ]] || fail "APK build failed — ${APK_SRC} not found"
  [[ -f "${AAB_SRC}" ]] || fail "AAB build failed — ${AAB_SRC} not found"

  cp "${APK_SRC}" "${APK_OUT}"
  cp "${AAB_SRC}" "${AAB_OUT}"

  verify_apk_clean "${APK_OUT}"
  ok "APK : ${APK_OUT} ($(du -h "${APK_OUT}" | awk '{print $1}'))"
  ok "AAB : ${AAB_OUT} ($(du -h "${AAB_OUT}" | awk '{print $1}'))"
fi

scrub_dist_junk

# ── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  BUILD COMPLETE${NC}"
echo -e "${GREEN}══════════════════════════════════════════════════════════${NC}"
[[ "${SKIP_ANDROID:-0}" != "1" ]] && echo "  📱 APK (test IAP on phone): build/dist/fos-${APP_VERSION}-release.apk"
[[ "${SKIP_ANDROID:-0}" != "1" ]] && echo "  📦 AAB (Play Store):        build/dist/fos-${APP_VERSION}-release.aab"
[[ "${SKIP_IOS:-0}" != "1" ]]     && echo "  🍎 iOS: Xcode → Product → Archive → TestFlight"
echo ""
echo "  IAP test (Android):"
echo "    • Upload AAB to Play Internal Testing"
echo "    • Add Gmail as License Tester"
echo "    • Install from Play Store link (sideload debug APK won't show products)"
echo ""

[[ "${SKIP_IOS:-0}" != "1" && -d "${IOS_WORKSPACE}" ]] && open "${IOS_WORKSPACE}"

ok "All done."
