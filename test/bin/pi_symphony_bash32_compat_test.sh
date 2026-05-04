#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
script="$repo_root/bin/pi-symphony.sh"

if grep -nE '\$\{[^}]+,,[^}]*\}' "$script"; then
  echo "pi-symphony.sh must run on macOS bash 3.2; avoid Bash 4 lowercase expansion" >&2
  exit 1
fi
