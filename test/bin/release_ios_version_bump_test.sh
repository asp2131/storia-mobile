#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/bin" "$tmpdir/stubs"
cp "$repo_root/bin/release-ios.sh" "$tmpdir/bin/"
printf '#!/bin/sh\nexit 0\n' > "$tmpdir/bin/verify.sh"
printf '#!/bin/sh\nmkdir -p build/ios/ipa && touch build/ios/ipa/Loratone.ipa\n' > "$tmpdir/stubs/flutter"
chmod +x "$tmpdir/bin/verify.sh" "$tmpdir/stubs/flutter"
PATH="$tmpdir/stubs:$PATH"

check() { # <start version> <bump> <expected version>
  printf 'name: storia\nversion: %s\n' "$1" > "$tmpdir/pubspec.yaml"
  "$tmpdir/bin/release-ios.sh" "$2" >/dev/null
  actual="$(sed -n 's/^version: *//p' "$tmpdir/pubspec.yaml")"
  if [ "$actual" != "$3" ]; then
    echo "$1 $2: expected $3, got $actual" >&2
    exit 1
  fi
}

check 3.3.0 patch 3.3.1+1
check 3.3.1+1 build 3.3.1+2
check 3.3.1+2 minor 3.4.0+3
check 3.4.0+3 major 4.0.0+4

printf 'version: 3.3.0\n' > "$tmpdir/pubspec.yaml"
if "$tmpdir/bin/release-ios.sh" build >/dev/null 2>&1; then
  echo "expected build bump without +BUILD to fail" >&2
  exit 1
fi
if "$tmpdir/bin/release-ios.sh" bogus >/dev/null 2>&1; then
  echo "expected unknown bump to fail" >&2
  exit 1
fi

echo "release_ios_version_bump_test: ok"
