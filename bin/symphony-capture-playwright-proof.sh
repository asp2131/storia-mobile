#!/usr/bin/env bash
# Capture the canonical Storia App Review browser proof for Symphony handoff.
# This script is intentionally dependency-light and Bash 3.2 compatible.

set -euo pipefail

: "${PLAYWRIGHT_PROOF_TICKET:?Set PLAYWRIGHT_PROOF_TICKET, e.g. STO-11.}"

TICKET="$PLAYWRIGHT_PROOF_TICKET"
BIRTH_YEAR="${PLAYWRIGHT_PROOF_PARENT_BIRTH_YEAR:-1980}"
CHILD_NICKNAME="${PLAYWRIGHT_PROOF_CHILD_NICKNAME:-Milo}"
WEB_PORT="${PLAYWRIGHT_PROOF_WEB_PORT:-0}"
FLUTTER_DEVICE="${PLAYWRIGHT_PROOF_FLUTTER_DEVICE:-web-server}"
START_TIMEOUT_S="${PLAYWRIGHT_PROOF_START_TIMEOUT_S:-120}"
FLOW_TIMEOUT_MS="${PLAYWRIGHT_PROOF_FLOW_TIMEOUT_MS:-90000}"
RECORDINGS_DIR="${PLAYWRIGHT_PROOF_RECORDINGS_DIR:-recordings}"
RECORDING="$RECORDINGS_DIR/$TICKET-proof.webm"
TRACE_FILE="$RECORDINGS_DIR/$TICKET-trace.zip"
FLUTTER_LOG="$RECORDINGS_DIR/$TICKET-flutter-run.log"
FLOW_LOG="$RECORDINGS_DIR/$TICKET-playwright-flow.log"

log() { printf '[symphony-proof-capture] %s\n' "$*" >&2; }

if [ "${PLAYWRIGHT_PROOF_CAPTURE_DRY_RUN:-0}" = "1" ]; then
  mkdir -p "$RECORDINGS_DIR"
  printf 'dry-run placeholder for %s\n' "$TICKET" > "$RECORDING"
  log "dry run wrote $RECORDING (not valid PR evidence)"
  exit 0
fi

for bin in flutter playwright-cli; do
  command -v "$bin" >/dev/null || { log "missing dependency: $bin"; exit 127; }
done

mkdir -p "$RECORDINGS_DIR"
rm -f "$RECORDING" "$TRACE_FILE" "$FLUTTER_LOG"

flutter_pid=""
video_started=0
trace_started=0
created_web_dir=0

cleanup() {
  status=$?
  if [ "$video_started" = "1" ]; then
    playwright-cli video-stop --filename="$RECORDING" >/dev/null 2>&1 || true
  fi
  if [ "$trace_started" = "1" ]; then
    playwright-cli tracing-stop --filename="$TRACE_FILE" >/dev/null 2>&1 || playwright-cli tracing-stop >/dev/null 2>&1 || true
  fi
  playwright-cli close >/dev/null 2>&1 || true
  if [ -n "$flutter_pid" ] && kill -0 "$flutter_pid" 2>/dev/null; then
    kill "$flutter_pid" >/dev/null 2>&1 || true
    wait "$flutter_pid" >/dev/null 2>&1 || true
  fi
  if [ "$created_web_dir" = "1" ]; then
    rm -rf web
  fi
  exit "$status"
}
trap cleanup EXIT INT TERM

if [ ! -e web ]; then
  log "creating temporary Flutter web scaffold for proof capture"
  mkdir -p web
  created_web_dir=1
  cat > web/index.html <<'EOF_INDEX'
<!DOCTYPE html>
<html>
<head>
  <base href="$FLUTTER_BASE_HREF">
  <meta charset="UTF-8">
  <meta content="IE=Edge" http-equiv="X-UA-Compatible">
  <meta name="description" content="Storia proof capture">
  <meta name="mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="black">
  <meta name="apple-mobile-web-app-title" content="Storia">
  <title>Storia</title>
  <link rel="manifest" href="manifest.json">
</head>
<body>
  <script src="flutter_bootstrap.js" async></script>
</body>
</html>
EOF_INDEX
  cat > web/manifest.json <<'EOF_MANIFEST'
{
  "name": "Storia",
  "short_name": "Storia",
  "start_url": ".",
  "display": "standalone",
  "background_color": "#FAF3E8",
  "theme_color": "#2C3358",
  "description": "Storia proof capture",
  "orientation": "portrait-primary",
  "prefer_related_applications": false,
  "icons": []
}
EOF_MANIFEST
elif [ ! -f web/index.html ]; then
  log "web/ exists but web/index.html is missing; cannot create temporary scaffold safely"
  exit 1
fi

url="http://localhost:$WEB_PORT"
log "starting Flutter web ($FLUTTER_DEVICE) at $url"
flutter run -d "$FLUTTER_DEVICE" --web-hostname 127.0.0.1 --web-port "$WEB_PORT" >"$FLUTTER_LOG" 2>&1 &
flutter_pid=$!

start_epoch=$(date +%s)
while :; do
  if ! kill -0 "$flutter_pid" 2>/dev/null; then
    log "flutter run exited before serving; log follows"
    cat "$FLUTTER_LOG" >&2 || true
    exit 1
  fi
  if grep -Eq 'http://(localhost|127\.0\.0\.1):[0-9]+' "$FLUTTER_LOG" 2>/dev/null; then
    url="$(grep -Eo 'http://(localhost|127\.0\.0\.1):[0-9]+' "$FLUTTER_LOG" | tail -1)"
    break
  fi
  now=$(date +%s)
  if [ $((now - start_epoch)) -ge "$START_TIMEOUT_S" ]; then
    log "timed out waiting for Flutter web URL; log follows"
    cat "$FLUTTER_LOG" >&2 || true
    exit 1
  fi
  sleep 1
done

log "opening Playwright at $url"
playwright-cli open "$url"
playwright-cli resize 1440 1000 >/dev/null 2>&1 || true
if [ "${PLAYWRIGHT_PROOF_CAPTURE_TRACE:-0}" = "1" ]; then
  playwright-cli tracing-start >/dev/null 2>&1 && trace_started=1 || true
fi
playwright-cli video-start
video_started=1

flow_code="$(cat <<'EOF_JS'
async page => {
  const birthYear = '__PLAYWRIGHT_PROOF_PARENT_BIRTH_YEAR__';
  const nickname = '__PLAYWRIGHT_PROOF_CHILD_NICKNAME__';
  const flowTimeout = Number('__PLAYWRIGHT_PROOF_FLOW_TIMEOUT_MS__');
  page.setDefaultTimeout(Math.min(flowTimeout, 20000));

  const sleep = ms => page.waitForTimeout(ms);
  const log = message => console.log(`[symphony-proof-flow] ${message}`);
  const escapeRe = value => value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

  function appRoute(path) {
    const parts = page.url().split('/');
    return `${parts[0]}//${parts[2]}${path}`;
  }

  async function tryAction(label, action) {
    try {
      await action();
      log(label);
      await sleep(700);
      return true;
    } catch (error) {
      log(`${label} skipped: ${error.message}`);
      return false;
    }
  }

  async function clickText(patterns) {
    for (const pattern of patterns) {
      const locator = page.getByText(new RegExp(pattern, 'i')).first();
      if (await tryAction(`click text /${pattern}/`, () => locator.click({timeout: 7000}))) {
        return true;
      }
    }
    return false;
  }

  async function fillByLabelOrInput(labelPatterns, value, inputIndex = 0) {
    for (const pattern of labelPatterns) {
      const label = new RegExp(pattern, 'i');
      if (await tryAction(`fill label /${pattern}/`, () => page.getByLabel(label).first().fill(value, {timeout: 5000}))) {
        return true;
      }
      if (await tryAction(`fill placeholder /${pattern}/`, () => page.getByPlaceholder(label).first().fill(value, {timeout: 5000}))) {
        return true;
      }
    }
    const inputs = page.locator('input, textarea, [contenteditable="true"]');
    if (await tryAction(`fill input #${inputIndex}`, () => inputs.nth(inputIndex).fill(value, {timeout: 5000}))) {
      return true;
    }
    if (await tryAction(`keyboard type ${value}`, async () => {
      await page.keyboard.type(value);
    })) {
      return true;
    }
    return false;
  }

  const numberWords = {
    zero: 0, one: 1, two: 2, three: 3, four: 4, five: 5, six: 6, seven: 7,
    eight: 8, nine: 9, ten: 10, eleven: 11, twelve: 12, thirteen: 13,
    fourteen: 14, fifteen: 15, sixteen: 16, seventeen: 17, eighteen: 18,
    nineteen: 19, twenty: 20, thirty: 30, forty: 40, fifty: 50, sixty: 60,
    seventy: 70, eighty: 80, ninety: 90
  };

  function wordToNumber(source) {
    const normalized = source.toLowerCase().replace(/[^a-z-]/g, '');
    if (Object.prototype.hasOwnProperty.call(numberWords, normalized)) {
      return numberWords[normalized];
    }
    if (normalized.includes('-')) {
      return normalized.split('-').reduce((sum, part) => sum + (numberWords[part] || 0), 0);
    }
    return Number.NaN;
  }

  async function visibleText() {
    return await page.evaluate(() => document.body?.innerText || document.body?.textContent || '');
  }

  async function solveParentGateIfPresent() {
    const text = await visibleText();
    const match = text.match(/What is\s+([a-z-]+)\s+plus\s+([a-z-]+)\?/i);
    if (!match) {
      log('parent gate question not found in DOM text');
      return false;
    }
    const answer = wordToNumber(match[1]) + wordToNumber(match[2]);
    if (!Number.isFinite(answer)) {
      log(`could not parse parent gate question: ${match[0]}`);
      return false;
    }
    await fillByLabelOrInput(['\?\?\?', 'answer'], String(answer), 0);
    await clickText(['^Continue$']);
    return true;
  }

  async function seedAppReviewStorage(stage) {
    await page.evaluate(({birthYear, nickname, stage}) => {
      const prefix = 'flutter.';
      window.localStorage.setItem(`${prefix}app_review_bypass_email`, JSON.stringify('app-review@storia.kids'));
      if (stage === 'birthYear' || stage === 'onboarding' || stage === 'complete') {
        window.localStorage.setItem(`${prefix}app_review_parent_birth_year`, JSON.stringify(Number(birthYear)));
      }
      if (stage === 'onboarding' || stage === 'complete') {
        const profile = {
          childNickname: nickname,
          childAgeRange: 'age7to9',
          parentBirthYear: Number(birthYear),
          parentGoal: 'improveReading'
        };
        window.localStorage.setItem(`${prefix}app_review_onboarding_profile`, JSON.stringify(JSON.stringify(profile)));
      }
    }, {birthYear, nickname, stage});
  }

  await page.waitForLoadState('domcontentloaded');
  await sleep(2500);

  await tryAction('start journey from intro', async () => {
    await clickText(['Start your journey']);
  });

  await tryAction('navigate to sign-up if needed', async () => {
    if (!page.url().includes('/sign-up')) await page.goto(appRoute('/sign-up'));
  });
  await fillByLabelOrInput(['Parent.*Email', 'Email', 'hello@example.com'], 'app-review@storia.kids', 0);
  await clickText(['Create Account with Magic Link', 'Create Account', 'Continue']);
  await sleep(1500);

  if (!page.url().includes('/parent-birth-year')) {
    await seedAppReviewStorage('bypass');
    await page.goto(appRoute('/parent-birth-year'));
    await sleep(1500);
  }

  const solved = await solveParentGateIfPresent();
  if (!solved) {
    await seedAppReviewStorage('birthYear');
    await page.goto(appRoute('/onboarding'));
  } else {
    await fillByLabelOrInput(['year of birth', 'birth year'], birthYear, 0);
    await clickText(['^Continue$']);
  }
  await sleep(1500);

  if (!page.url().includes('/onboarding')) {
    await seedAppReviewStorage('birthYear');
    await page.goto(appRoute('/onboarding'));
    await sleep(1500);
  }

  const onboardingDone = await tryAction('complete onboarding by UI', async () => {
    await fillByLabelOrInput(["Child.*Nickname", 'Milo'], nickname, 0);
    await clickText(['4-6', '7-9', '10-12']);
    await clickText([escapeRe("Improve my child's reading level"), 'reading level', 'already love reading']);
    await clickText(['Continue to Library']);
  });
  if (!onboardingDone) {
    await seedAppReviewStorage('complete');
    await page.goto(appRoute('/library'));
  }

  await sleep(3000);
  if (!page.url().includes('/library')) {
    await seedAppReviewStorage('complete');
    await page.goto(appRoute('/library'));
  }
  await sleep(5000);
  log(`finished at ${page.url()}`);
}
EOF_JS
)"

escape_replacement() {
  printf '%s' "$1" | sed 's/[\\&|]/\\&/g'
}
flow_code="$(printf '%s' "$flow_code" |
  sed "s|__PLAYWRIGHT_PROOF_PARENT_BIRTH_YEAR__|$(escape_replacement "$BIRTH_YEAR")|g" |
  sed "s|__PLAYWRIGHT_PROOF_CHILD_NICKNAME__|$(escape_replacement "$CHILD_NICKNAME")|g" |
  sed "s|__PLAYWRIGHT_PROOF_FLOW_TIMEOUT_MS__|$(escape_replacement "$FLOW_TIMEOUT_MS")|g")"

log "performing app-review onboarding proof flow"
if ! playwright-cli run-code "$flow_code" >"$FLOW_LOG" 2>&1; then
  cat "$FLOW_LOG" >&2 || true
  exit 1
fi
cat "$FLOW_LOG" >&2 || true
if grep -q '^### Error' "$FLOW_LOG"; then
  log "Playwright flow reported an error"
  exit 1
fi

log "saving video to $RECORDING"
playwright-cli video-stop --filename="$RECORDING"
video_started=0
if [ "$trace_started" = "1" ]; then
  playwright-cli tracing-stop --filename="$TRACE_FILE" >/dev/null 2>&1 || playwright-cli tracing-stop >/dev/null 2>&1 || true
  trace_started=0
fi
playwright-cli close >/dev/null 2>&1 || true

if [ ! -s "$RECORDING" ]; then
  log "recording was not created or is empty: $RECORDING"
  exit 1
fi

log "captured $RECORDING"
