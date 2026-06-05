#!/usr/bin/env bash
set -euo pipefail

PORT="${PORT:-9222}"
PROFILE_DIR="${CHROME_DEBUG_PROFILE:-$HOME/.chrome-devtools-mcp-profile}"
START_URL="${CHROME_START_URL:-about:blank}"
LOG_FILE="${CHROME_DEBUG_LOG:-/tmp/chrome-devtools-mcp.log}"

if curl -sf "http://127.0.0.1:${PORT}/json/version" >/dev/null 2>&1; then
  echo "Chrome DevTools endpoint already available: http://127.0.0.1:${PORT}"
  curl -sf "http://127.0.0.1:${PORT}/json/version"
  exit 0
fi

if [[ -n "${CHROME_BIN:-}" ]]; then
  CHROME="$CHROME_BIN"
elif [[ "$OSTYPE" == darwin* && -x "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" ]]; then
  CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
elif command -v google-chrome >/dev/null 2>&1; then
  CHROME="$(command -v google-chrome)"
elif command -v chromium >/dev/null 2>&1; then
  CHROME="$(command -v chromium)"
elif command -v chromium-browser >/dev/null 2>&1; then
  CHROME="$(command -v chromium-browser)"
else
  echo "Could not find Chrome/Chromium. Set CHROME_BIN=/path/to/chrome." >&2
  exit 1
fi

mkdir -p "$PROFILE_DIR"

args=(
  "--remote-debugging-port=${PORT}"
  "--user-data-dir=${PROFILE_DIR}"
  "--no-first-run"
  "--no-default-browser-check"
)

if [[ "${HEADLESS:-0}" == "1" || "${HEADLESS:-}" == "true" ]]; then
  args+=("--headless=new" "--disable-gpu")
fi

"$CHROME" "${args[@]}" "$START_URL" >"$LOG_FILE" 2>&1 &
pid=$!

echo "Launched Chrome PID ${pid}"
echo "Profile: ${PROFILE_DIR}"
echo "Log: ${LOG_FILE}"
echo "DevTools endpoint: http://127.0.0.1:${PORT}"

for _ in {1..50}; do
  if curl -sf "http://127.0.0.1:${PORT}/json/version" >/dev/null 2>&1; then
    curl -sf "http://127.0.0.1:${PORT}/json/version"
    exit 0
  fi
  sleep 0.1
done

echo "Chrome launched but DevTools endpoint did not become ready. See ${LOG_FILE}." >&2
exit 1
