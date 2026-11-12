#!/usr/bin/env bash
# deploy-web.sh — build Flutter web release and deploy to Cloudflare Pages (loratone-app).
# Usage: ./bin/deploy-web.sh [branch]   (default: main = production; any other name = preview)
# First time: npx wrangler login
set -euo pipefail

cd "$(dirname "$0")/.."

BRANCH="${1:-main}"

flutter build web --release
npx wrangler pages deploy build/web --project-name=loratone-app --branch="$BRANCH"
