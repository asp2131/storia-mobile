#!/usr/bin/env bash
# release-ios.sh — bump pubspec version, run verify.sh, build a signed App Store IPA.
# Usage: ./bin/release-ios.sh [patch|minor|major|build]   (default: patch)
# Stops before upload — drag the IPA into Transporter yourself.
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

bump="${1:-patch}"
case "$bump" in
  patch|minor|major|build) ;;
  *) echo "usage: $0 [patch|minor|major|build]" >&2; exit 1 ;;
esac

current="$(sed -n 's/^version: *//p' pubspec.yaml)"
name="${current%%+*}"
build=""
case "$current" in *+*) build="${current#*+}" ;; esac
IFS=. read -r major minor patch <<< "$name"

# Pre-3.3.1 builds shipped with no +BUILD (CFBundleVersion = "3.3.0"), so a
# same-version rebuild starting at 1 would be rejected by App Store Connect.
if [ "$bump" = build ] && [ -z "$build" ]; then
  echo "[release-ios] pubspec has no +BUILD yet; run with patch|minor|major once" >&2
  exit 1
fi

case "$bump" in
  major) major=$((major + 1)); minor=0; patch=0 ;;
  minor) minor=$((minor + 1)); patch=0 ;;
  patch) patch=$((patch + 1)) ;;
esac
# Build number never resets: Android versionCode reads the same value and must only go up.
next="$major.$minor.$patch+$((${build:-0} + 1))"

./bin/verify.sh

echo "[release-ios] version $current -> $next"
sed -i '' "s/^version: .*/version: $next/" pubspec.yaml

# Explicit export plist pins the Sign in with Apple profile; flutter's default export picks the wrong one.
rm -rf build/ios/ipa
flutter build ipa --export-options-plist=ios/ExportOptions.plist

echo "[release-ios] ✓ $(ls build/ios/ipa/*.ipa)"
echo "[release-ios] upload via Transporter, then commit pubspec.yaml"
