#!/usr/bin/env bash
# Shared Playwright proof helpers for Storia Symphony runners.
# Source from pi/opencode runners; run `./bin/symphony-proof.sh --self-test`
# for local validation without Linear/GitHub network calls.

# Policy knobs:
#   PLAYWRIGHT_PROOF_MODE=auto|always|off   default: auto
#   PLAYWRIGHT_PROOF_UPLOAD_CMD='<command>' optional; receives env vars:
#       PLAYWRIGHT_PROOF_FILE, PLAYWRIGHT_PROOF_TICKET
#     and must print a shareable URL to stdout.
#   PLAYWRIGHT_PROOF_REQUIRE_UPLOAD=0|1     default: 1 (upload/link required)

symphony_playwright_proof_mode() {
  printf '%s' "${PLAYWRIGHT_PROOF_MODE:-auto}"
}

symphony_playwright_require_upload() {
  printf '%s' "${PLAYWRIGHT_PROOF_REQUIRE_UPLOAD:-1}"
}

symphony_changed_files() {
  local base_ref="${1:-origin/main}"

  git diff --name-only "$base_ref"...HEAD 2>/dev/null || true
  git diff --name-only --cached 2>/dev/null || true
  git diff --name-only 2>/dev/null || true
  git ls-files --others --exclude-standard 2>/dev/null || true
}

symphony_requires_playwright_proof() {
  # $1 = title, $2 = description, $3 = base ref
  local title="${1:-}" desc="${2:-}" base_ref="${3:-origin/main}" mode text files
  mode="$(symphony_playwright_proof_mode)"
  text="$(printf '%s\n%s' "$title" "$desc" | tr '[:upper:]' '[:lower:]')"

  case "$mode" in
    off|never|0|false) return 1 ;;
    always|required|1|true) return 0 ;;
    auto|"") ;;
    *)
      echo "Unknown PLAYWRIGHT_PROOF_MODE='$mode' (expected auto|always|off)." >&2
      return 2
      ;;
  esac

  if printf '%s' "$text" | grep -Eq '\[(no-playwright-proof|no-ui-proof|skip-playwright-proof)\]'; then
    return 1
  fi

  if printf '%s' "$text" | grep -Eq '\[(playwright-proof|ui-proof|visual-proof)\]|browser-verifiable|visual proof|video proof|ui-relevant'; then
    return 0
  fi

  files="$(symphony_changed_files "$base_ref" | sort -u)"
  [ -n "$files" ] || return 1

  printf '%s\n' "$files" | grep -Eq '^(lib/src/features/.*/presentation/|lib/src/features/(auth|onboarding|library|reader)/|lib/src/core/(widgets|theme)/|lib/src/routing/app_router\.dart|assets/(images|svgs|gifs|tiles)/)'
}

symphony_find_playwright_recordings() {
  # $1 = ticket identifier, $2 = recordings dir
  local ticket="${1:-}" dir="${2:-recordings}" all
  [ -d "$dir" ] || return 0

  all="$(find "$dir" -type f -name '*.webm' -size +0 -print | sort)"
  [ -n "$all" ] || return 0
  if [ -n "$ticket" ]; then
    printf '%s\n' "$all" | grep -E "^${dir}/${ticket}(-|\.).*\.webm$" || true
  else
    printf '%s\n' "$all"
  fi
}

symphony_upload_playwright_recording() {
  # $1 = file path, $2 = ticket identifier
  local file="$1" ticket="$2" cmd="${PLAYWRIGHT_PROOF_UPLOAD_CMD:-}" url
  [ -n "$cmd" ] || return 2

  url="$(PLAYWRIGHT_PROOF_FILE="$file" PLAYWRIGHT_PROOF_TICKET="$ticket" bash -lc "$cmd")"
  url="$(printf '%s' "$url" | tail -n 1 | tr -d '\r')"
  [ -n "$url" ] || return 3
  printf '%s' "$url"
}

symphony_build_playwright_proof_markdown() {
  # $1 = ticket identifier. Prints markdown on success; prints failure details on
  # stderr and returns non-zero when required evidence is missing.
  local ticket="$1" require_upload recordings file url any=0
  require_upload="$(symphony_playwright_require_upload)"
  recordings="$(symphony_find_playwright_recordings "$ticket" recordings)"

  if [ -z "$recordings" ]; then
    echo "No ticket-specific Playwright WebM proof found under recordings/${ticket}-*.webm." >&2
    echo "Expected flow: Intro → Start your journey → app-review@storia.kids → parent birth year → onboarding → library → feature smoke." >&2
    return 1
  fi

  echo "### Playwright video proof"
  echo
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    any=1
    if [ -n "${PLAYWRIGHT_PROOF_UPLOAD_CMD:-}" ]; then
      if url="$(symphony_upload_playwright_recording "$file" "$ticket")"; then
        echo "- [$file]($url)"
      else
        echo "Upload command failed for $file." >&2
        return 1
      fi
    else
      if [ "$require_upload" = "1" ]; then
        echo "PLAYWRIGHT_PROOF_UPLOAD_CMD is required to upload/link $file." >&2
        echo "Set PLAYWRIGHT_PROOF_UPLOAD_CMD to a command that prints a shareable URL, or set PLAYWRIGHT_PROOF_REQUIRE_UPLOAD=0 for local-path-only evidence." >&2
        return 1
      fi
      echo "- Local artifact: \`$file\`"
    fi
  done <<EOF_RECORDINGS
$recordings
EOF_RECORDINGS

  [ "$any" = "1" ]
}

symphony_proof_self_test() {
  local tmp status
  tmp="$(mktemp -d)"
  status=0
  (
    set -euo pipefail
    unset PLAYWRIGHT_PROOF_MODE PLAYWRIGHT_PROOF_REQUIRE_UPLOAD PLAYWRIGHT_PROOF_UPLOAD_CMD
    cd "$tmp"
    git init -q
    git config user.email test@example.com
    git config user.name Test
    mkdir -p lib/src/features/library recordings
    printf 'base\n' > README.md
    git add README.md
    git commit -q -m base
    git branch -M main

    printf 'ui\n' > lib/src/features/library/library_screen.dart
    if ! symphony_requires_playwright_proof "Plain ticket" "" HEAD; then
      echo "expected UI file change to require proof" >&2
      exit 1
    fi

    PLAYWRIGHT_PROOF_MODE=off
    export PLAYWRIGHT_PROOF_MODE
    if symphony_requires_playwright_proof "Plain ticket" "" HEAD; then
      echo "expected proof mode off to skip proof" >&2
      exit 1
    fi
    unset PLAYWRIGHT_PROOF_MODE

    printf 'old video' > recordings/OTHER-proof.webm
    if symphony_build_playwright_proof_markdown STO-TEST >/tmp/symphony-proof-self-test.out 2>/tmp/symphony-proof-self-test.err; then
      echo "expected unrelated recordings not to satisfy ticket proof" >&2
      exit 1
    fi

    printf 'video' > recordings/STO-TEST-proof.webm
    if symphony_build_playwright_proof_markdown STO-TEST >/tmp/symphony-proof-self-test.out 2>/tmp/symphony-proof-self-test.err; then
      echo "expected upload-required default to fail without upload command" >&2
      exit 1
    fi

    PLAYWRIGHT_PROOF_UPLOAD_CMD='printf "https://artifacts.example/%s/%s\\n" "$PLAYWRIGHT_PROOF_TICKET" "$(basename "$PLAYWRIGHT_PROOF_FILE")"'
    export PLAYWRIGHT_PROOF_UPLOAD_CMD
    symphony_build_playwright_proof_markdown STO-TEST | grep -q 'https://artifacts.example/STO-TEST/STO-TEST-proof.webm'
    unset PLAYWRIGHT_PROOF_UPLOAD_CMD

    PLAYWRIGHT_PROOF_REQUIRE_UPLOAD=0
    export PLAYWRIGHT_PROOF_REQUIRE_UPLOAD
    if ! symphony_build_playwright_proof_markdown STO-TEST | grep -q 'Local artifact'; then
      echo "expected local artifact evidence when upload requirement is disabled" >&2
      exit 1
    fi
  ) || status=$?
  rm -rf "$tmp"
  rm -f /tmp/symphony-proof-self-test.out /tmp/symphony-proof-self-test.err
  return "$status"
}

if [ "${1:-}" = "--self-test" ]; then
  symphony_proof_self_test
  echo "symphony-proof self-test passed"
fi
