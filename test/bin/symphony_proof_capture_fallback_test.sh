#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=bin/symphony-proof.sh
. "$repo_root/bin/symphony-proof.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir" /tmp/symphony-capture.out /tmp/symphony-capture.err' EXIT
cd "$tmpdir"
mkdir -p recordings

PLAYWRIGHT_PROOF_REQUIRE_UPLOAD=0
export PLAYWRIGHT_PROOF_REQUIRE_UPLOAD

if symphony_ensure_playwright_proof STO-77 >/tmp/symphony-capture.out 2>/tmp/symphony-capture.err; then
  echo "expected missing capture command/default script to fail" >&2
  exit 1
fi
if ! grep -q 'No ticket-specific Playwright WebM proof found' /tmp/symphony-capture.err; then
  echo "expected missing proof diagnostic" >&2
  cat /tmp/symphony-capture.err >&2
  exit 1
fi

PLAYWRIGHT_PROOF_CAPTURE_CMD='mkdir -p recordings; printf video > "recordings/${PLAYWRIGHT_PROOF_TICKET}-proof.webm"'
export PLAYWRIGHT_PROOF_CAPTURE_CMD
if ! symphony_ensure_playwright_proof STO-77 >/tmp/symphony-capture.out 2>/tmp/symphony-capture.err; then
  echo "expected capture fallback to satisfy proof" >&2
  cat /tmp/symphony-capture.err >&2
  exit 1
fi
if ! grep -q 'Local artifact: `recordings/STO-77-proof.webm`' /tmp/symphony-capture.out; then
  echo "expected markdown for captured artifact" >&2
  cat /tmp/symphony-capture.out >&2
  exit 1
fi

rm -f recordings/STO-77-proof.webm
PLAYWRIGHT_PROOF_CAPTURE_CMD='echo capture-ran >&2; exit 42'
export PLAYWRIGHT_PROOF_CAPTURE_CMD
if symphony_ensure_playwright_proof STO-77 >/tmp/symphony-capture.out 2>/tmp/symphony-capture.err; then
  echo "expected failed capture command to fail proof" >&2
  exit 1
fi
if ! grep -q 'Playwright proof capture failed' /tmp/symphony-capture.err; then
  echo "expected failed capture diagnostic" >&2
  cat /tmp/symphony-capture.err >&2
  exit 1
fi
