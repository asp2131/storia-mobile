#!/usr/bin/env bash
# Syntax-check Pi extensions without requiring Pi runtime deps locally.
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if ! command -v bun >/dev/null 2>&1; then
  echo "[extensions] bun not on PATH; skipping extension syntax check" >&2
  exit 0
fi

out_dir="${TMPDIR:-/tmp}/storia-extension-check"
rm -rf "$out_dir"
mkdir -p "$out_dir"

externals=(
  --external @mariozechner/pi-coding-agent
  --external @mariozechner/pi-tui
  --external @mariozechner/pi-ai
  --external @sinclair/typebox
  --external yaml
)

for file in extensions/*.ts; do
  echo "[extensions] check $file"
  bun build "$file" --outdir "$out_dir" --target node "${externals[@]}" >/dev/null
done

echo "[extensions] ✓ passed"
