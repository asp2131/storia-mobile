#!/usr/bin/env bash
# bootstrap.sh — one-shot dev env setup for storia-mobile.
# Used by Symphony's after_create hook and by humans on a fresh clone.
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

echo "[bootstrap] repo: $repo_root"

if ! command -v flutter >/dev/null 2>&1; then
  echo "[bootstrap] flutter not on PATH. Install Flutter or expose it in PATH." >&2
  exit 1
fi

echo "[bootstrap] flutter pub get"
flutter pub get

if [ -f .env.example ] && [ ! -f .env ]; then
  echo "[bootstrap] .env missing — copying .env.example to .env. Fill required values."
  cp .env.example .env
fi

if [ "$(uname -s)" = "Darwin" ] && [ -f ios/Podfile ]; then
  if command -v pod >/dev/null 2>&1; then
    echo "[bootstrap] pod install (ios/)"
    (cd ios && pod install)
  else
    echo "[bootstrap] cocoapods not found, skipping pod install. brew install cocoapods to enable iOS."
  fi
fi

echo "[bootstrap] done"
