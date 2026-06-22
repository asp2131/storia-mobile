#!/usr/bin/env bash
set -euo pipefail

loopany_home="${LOOPANY_HOME:-$HOME/.loopany/storia-mobile}"

if ! command -v loopany >/dev/null 2>&1; then
  cat >&2 <<'EOF'
[loopany-storia] loopany is not installed or not on PATH.
Install it with the upstream flow:
  git clone https://github.com/superdesigndev/loopany.git ~/loopany-src
  export PATH="$HOME/.bun/bin:$PATH"
  cd ~/loopany-src && bun install && bun link
If needed, add `export PATH="$HOME/.bun/bin:$PATH"` to ~/.zshrc and source it.
EOF
  exit 1
fi

mkdir -p "$loopany_home"
export LOOPANY_HOME="$loopany_home"

exec loopany "$@"
