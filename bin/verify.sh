#!/usr/bin/env bash
# verify.sh — pre-handoff check. Symphony agents run this before moving a Linear ticket to Human Review.
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if ! command -v flutter >/dev/null 2>&1; then
  echo "[verify] flutter not on PATH" >&2
  exit 1
fi

echo "[verify] flutter analyze"
flutter analyze

echo "[verify] flutter test"
flutter test

echo "[verify] ✓ passed"
