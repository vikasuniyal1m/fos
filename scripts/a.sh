#!/usr/bin/env bash
# =============================================================================
# FOS — iOS archive (short script)
#   pubspec version as-is • shrink/obfuscate • pod install • flutter build ipa
#
# Usage (from project root):
#   ./scripts/a.sh
#
# Optional env:
#   SKIP_CLEAN=1     skip flutter clean
#   POD_UPDATE=1     pod install --repo-update
#   OPEN_XCODE=1     open Runner.xcworkspace after archive
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
step() { echo -e "\n${CYAN}▶ $*${NC}"; }
ok()   { echo -e "${GREEN}✔ $*${NC}"; }
fail() { echo -e "${RED}✖ $*${NC}"; exit 1; }

[[ "$(uname -s)" == "Darwin" ]] || fail "iOS archive needs macOS"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_DIR}"

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

DIST_DIR="${PROJECT_DIR}/build/dist"
DEBUG_INFO_DIR="${PROJECT_DIR}/build/debug-info"
ARCHIVE_PATH="${PROJECT_DIR}/build/ios/archive/Runner.xcarchive"
EXPORT_PLIST="${PROJECT_DIR}/ios/ExportOptions.plist"
WORKSPACE="${PROJECT_DIR}/ios/Runner.xcworkspace"

VERSION_LINE="$(grep '^version:' pubspec.yaml | head -1 | awk '{print $2}')"
BUILD_NAME="${VERSION_LINE%+*}"
BUILD_NUMBER="${VERSION_LINE#*+}"

BUILD_FLAGS=(
  --release
  --obfuscate
  --split-debug-info="${DEBUG_INFO_DIR}"
  --tree-shake-icons
  --dart-define=FLUTTER_APP_ENV=production
  --build-name="${BUILD_NAME}"
  --build-number="${BUILD_NUMBER}"
  --export-options-plist="${EXPORT_PLIST}"
)

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

step "FOS iOS archive v${VERSION_LINE}"
command -v flutter >/dev/null 2>&1 || fail "flutter not in PATH"
command -v pod >/dev/null 2>&1 || fail "pod not found — gem install cocoapods"
[[ -f "${EXPORT_PLIST}" ]] || fail "missing ios/ExportOptions.plist"

mkdir -p "${DIST_DIR}" "${DEBUG_INFO_DIR}"
ensure_flutterignore

if [[ "${SKIP_CLEAN:-0}" != "1" ]]; then
  step "flutter clean"
  flutter clean
fi

step "flutter pub get"
flutter pub get

step "flutter precache --ios"
flutter precache --ios

step "pod install"
pushd ios >/dev/null
if [[ "${POD_UPDATE:-0}" == "1" ]]; then
  pod install --repo-update
else
  pod install
fi
popd >/dev/null

step "flutter build ipa (archive + export)"
flutter build ipa "${BUILD_FLAGS[@]}"

IPA_SRC="$(ls -t "${PROJECT_DIR}"/build/ios/ipa/*.ipa 2>/dev/null | head -1)"
[[ -n "${IPA_SRC}" && -f "${IPA_SRC}" ]] || fail "IPA not found under build/ios/ipa/"

IPA_OUT="${DIST_DIR}/fos-${VERSION_LINE}.ipa"
cp "${IPA_SRC}" "${IPA_OUT}"

ok "Version : ${BUILD_NAME} (${BUILD_NUMBER})"
ok "Archive : ${ARCHIVE_PATH}"
ok "IPA     : ${IPA_OUT} ($(du -h "${IPA_OUT}" | awk '{print $1}'))"

echo ""
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo -e "${GREEN}  iOS ARCHIVE READY${NC}"
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo "  Xcode → Window → Organizer → Distribute"
echo "  Or upload IPA from: ${IPA_OUT}"
echo ""

[[ -d "${ARCHIVE_PATH}" ]] && open "${ARCHIVE_PATH}" || true
[[ "${OPEN_XCODE:-0}" == "1" && -d "${WORKSPACE}" ]] && open "${WORKSPACE}" || true

ok "Done."
