#!/usr/bin/env bash
# symphony-tail.sh — pretty-prints opencode-symphony JSON logs.
# Usage:
#   ./bin/symphony-tail.sh STO-8           # follow tail
#   ./bin/symphony-tail.sh STO-8 --all     # entire log
#   ./bin/symphony-tail.sh STO-8 --raw     # also show raw JSON
#   ./bin/symphony-tail.sh STO-8 --max 400 # truncate long fields (default 200)

set -euo pipefail

ticket="${1:-}"
if [ -z "$ticket" ]; then
  echo "usage: $0 <TICKET-ID> [--all] [--raw] [--max N]" >&2
  exit 1
fi
shift

mode="follow"
export RAW=0
export MAXLEN=200
while [ $# -gt 0 ]; do
  case "$1" in
    --all)  mode="all" ;;
    --raw)  RAW=1 ;;
    --max)  shift; MAXLEN="$1" ;;
    *) echo "unknown flag: $1" >&2; exit 1 ;;
  esac
  shift
done

logf="$HOME/code/storia-mobile-symphony-workspaces/.logs/${ticket}.log"
[ -f "$logf" ] || { echo "no log: $logf" >&2; exit 1; }

PY_SCRIPT=$(cat <<'PYEOF'
import sys, json, os, re

RAW = os.environ.get("RAW") == "1"
MAX = int(os.environ.get("MAXLEN", "200"))

C = {
  "dim":    "\033[2m",
  "reset":  "\033[0m",
  "bold":   "\033[1m",
  "blue":   "\033[34m",
  "cyan":   "\033[36m",
  "green":  "\033[32m",
  "yellow": "\033[33m",
  "red":    "\033[31m",
  "mag":    "\033[35m",
}
RST = C["reset"]

def col(name, s):
    return C[name] + str(s) + RST

def truncate(s, n=None):
    if n is None:
        n = MAX
    s = re.sub(r"\s+", " ", str(s)).strip()
    if len(s) <= n:
        return s
    return s[:n] + "…"

def fmt_ts(ms):
    try:
        import datetime as dt
        return dt.datetime.fromtimestamp(int(ms) / 1000).strftime("%H:%M:%S")
    except Exception:
        return ""

def render(evt):
    t = evt.get("type", "")
    ts = fmt_ts(evt.get("timestamp", 0))
    prefix = col("dim", ts)

    if t in ("step_start", "step-start"):
        return None
    if t in ("step_finish", "step-finish"):
        p = evt.get("part", {})
        reason = p.get("reason", "")
        if reason != "stop":
            return None
        tok = p.get("tokens", {})
        cost = p.get("cost", 0) or 0
        meta = "in={} out={} ${:.4f}".format(
            tok.get("input", 0), tok.get("output", 0), cost
        )
        return "{} {} {}".format(
            prefix, col("mag", "⏹  step done"), col("dim", meta)
        )

    if t == "text":
        p = evt.get("part", {})
        txt = (p.get("text") or "").strip()
        if not txt:
            return None
        head = col("cyan", "💬 text")
        body = "\n".join("   " + line for line in txt.splitlines())
        return "{} {}\n{}".format(prefix, head, body)

    if t == "tool_use":
        p = evt.get("part", {})
        tool = p.get("tool", "?")
        state = p.get("state", {}) or {}
        status = state.get("status", "")
        inp = state.get("input", {}) or {}
        out = state.get("output", "") or ""
        err = state.get("error", "") or ""

        if tool == "skill":
            detail = inp.get("name", "")
            icon = "🧩"
        elif tool == "bash":
            detail = inp.get("command") or inp.get("description", "")
            icon = "🖥 "
        elif tool == "read":
            detail = inp.get("filePath") or inp.get("file_path", "")
            icon = "📖"
        elif tool in ("write", "edit"):
            detail = inp.get("filePath") or inp.get("file_path", "")
            icon = "✏️ "
        elif tool == "todowrite":
            todos = inp.get("todos", []) or []
            detail = "{} todos".format(len(todos))
            icon = "✅"
        elif tool == "grep":
            detail = inp.get("pattern", "")
            icon = "🔎"
        else:
            try:
                detail = json.dumps(inp)[:80]
            except Exception:
                detail = ""
            icon = "🔧"

        color = "green" if status == "completed" else ("red" if status == "error" else "yellow")
        head = "{} {} {} {}".format(
            icon, col(color, tool), col("dim", status), truncate(detail)
        )
        line = "{} {}".format(prefix, head)
        if err:
            line += "\n   " + col("red", truncate(err))
        elif status == "error" and out:
            line += "\n   " + col("red", truncate(out))
        return line

    return None


for raw_line in sys.stdin:
    line = raw_line.rstrip("\n")
    if not line:
        continue
    if not line.startswith("{"):
        print(col("blue", line))
        sys.stdout.flush()
        continue
    try:
        evt = json.loads(line)
    except json.JSONDecodeError:
        print(col("dim", line[:200]))
        sys.stdout.flush()
        continue
    rendered = render(evt)
    if rendered:
        print(rendered)
    if RAW:
        print(col("dim", "  raw: " + truncate(line, 300)))
    sys.stdout.flush()
PYEOF
)

if [ "$mode" = "follow" ]; then
  tail -n 200 -F "$logf" | python3 -u -c "$PY_SCRIPT"
else
  cat "$logf" | python3 -u -c "$PY_SCRIPT"
fi
