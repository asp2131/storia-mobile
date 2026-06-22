#!/usr/bin/env bash
# verify.sh — pre-handoff check. Symphony agents run this before moving a Linear ticket to Human Review.
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if ! command -v flutter >/dev/null 2>&1; then
  echo "[verify] flutter not on PATH" >&2
  exit 1
fi

echo "[verify] architecture guardrails"
supabase_violations="$(
  grep -RIn "Supabase\.instance" lib --include='*.dart' \
    | grep -Ev '^(lib/src/data/|lib/src/.*/data/|lib/src/.*repository.*\.dart:)' \
    || true
)"
if [[ -n "$supabase_violations" ]]; then
  echo "[verify] Supabase.instance is only allowed in data/repository files:" >&2
  echo "$supabase_violations" >&2
  exit 1
fi

echo "[verify] extensions"
./bin/check-extensions.sh

echo "[verify] flutter analyze"
flutter analyze

echo "[verify] flutter test"
flutter test

echo "[verify] ✓ passed"
