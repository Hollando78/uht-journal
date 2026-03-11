#!/usr/bin/env bash
set -euo pipefail

LOOP_DIR="/opt/uht-loop"
JOURNAL_DIR="$LOOP_DIR/journal"
POSTS_DIR="$JOURNAL_DIR/src/content/posts"
SERVE_DIR="/var/www/journal.universalhex.org"
LOG_FILE="/var/log/uht-loop/sessions.log"
OUTPUT_FILE="/tmp/uht-session-output.md"
LOCK_FILE="/tmp/uht-loop.lock"

# --- Logging helper ---
log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" >> "$LOG_FILE"
}

# --- Source credentials ---
if [ -f "$LOOP_DIR/.env" ]; then
  set -a
  source "$LOOP_DIR/.env"
  set +a
else
  echo "ERROR: .env not found at $LOOP_DIR/.env" >&2
  exit 1
fi

# --- Lockfile (prevent concurrent sessions) ---
exec 200>"$LOCK_FILE"
if ! flock -n 200; then
  log "SKIPPED: another session is already running"
  exit 0
fi

# --- Check for PAUSE directive ---
PAUSE_CHECK=$(uht-substrate facts query --predicate PENDING_DIRECTIVE 2>/dev/null || echo '{"facts":[]}')
PAUSE_VAL=$(echo "$PAUSE_CHECK" | jq -r '.facts[0].object // ""')
if [ "$PAUSE_VAL" = "PAUSE" ]; then
  log "PAUSED: session skipped by operator directive"
  exit 0
fi

# --- Send Telegram message (plain text, no Markdown) ---
send_telegram() {
  local message="$1"
  if [ -n "${TELEGRAM_BOT_TOKEN:-}" ] && [ -n "${TELEGRAM_CHAT_ID:-}" ]; then
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
      -d chat_id="$TELEGRAM_CHAT_ID" \
      --data-urlencode "text=$message" > /dev/null 2>&1 || true
  fi
}

# --- Record session start ---
SESSION_START=$(date -u +%Y-%m-%dT%H:%M:%SZ)
export SESSION_START
log "SESSION START"

# --- Run Claude session ---
: > "$OUTPUT_FILE"

if claude -p "$(cat "$LOOP_DIR/session_protocol.md")" --allowedTools "Bash(*)" > "$OUTPUT_FILE" 2>> "$LOG_FILE"; then
  log "Claude session completed successfully"
else
  EXIT_CODE=$?
  log "ERROR: claude exited with code $EXIT_CODE"
  ELAPSED=$(( $(date +%s) - $(date -d "$SESSION_START" +%s 2>/dev/null || echo "0") ))
  send_telegram "$(printf 'UHT Loop — session failed\nExit code: %s\nElapsed: %sm\nCheck: /var/log/uht-loop/' "$EXIT_CODE" "$(( ELAPSED / 60 ))")"
  exit $EXIT_CODE
fi

# --- Extract journal entry ---
CLEANED_FILE="/tmp/uht-session-cleaned.md"
python3 << 'PYEOF' > "$CLEANED_FILE"
import re, sys

text = open("/tmp/uht-session-output.md").read()

# Strip code fences
text = re.sub(r'^```(?:yaml)?\s*$', '', text, flags=re.MULTILINE)

# Find the first front matter block that contains a title: field
m = re.search(r'^---\s*\n(title:.*?\n.*?)^---\s*\n(.*)', text, re.MULTILINE | re.DOTALL)
if not m:
    sys.exit(1)

front = m.group(1).rstrip()
body = m.group(2)

# Ensure date is quoted
front = re.sub(r'^(date:\s*)(\d{4}-\d{2}-\d{2})\s*$', r'\1"\2"', front, flags=re.MULTILINE)

# Ensure title is quoted
title_match = re.search(r'^title:\s*(.+)$', front, re.MULTILINE)
if title_match:
    raw = title_match.group(1).strip().strip('"').strip("'")
    front = re.sub(r'^title:\s*.+$', f'title: "{raw}"', front, flags=re.MULTILINE)

# Ensure status field exists
if not re.search(r'^status:', front, re.MULTILINE):
    front += '\nstatus: published'

# Inject time field from session start timestamp
import os
session_start = os.environ.get('SESSION_START', '')
if session_start and not re.search(r'^time:', front, re.MULTILINE):
    # Extract HH:MM from ISO timestamp
    tm = re.search(r'T(\d{2}:\d{2})', session_start)
    if tm:
        front += f'\ntime: "{tm.group(1)}"'

print("---")
print(front)
print("---")
print(body)
PYEOF

# --- Validate front matter fields ---
validate_frontmatter() {
  local file="$1"
  local missing=""
  for field in title date session session_type task_class status; do
    if ! grep -q "^${field}:" "$file"; then
      missing="$missing $field"
    fi
  done
  echo "$missing"
}

if [ ! -s "$CLEANED_FILE" ]; then
  log "WARNING: no journal front matter found in output"
  ELAPSED=$(( $(date +%s) - $(date -d "$SESSION_START" +%s 2>/dev/null || echo "0") ))
  send_telegram "$(printf 'UHT Loop — session %s completed but produced no journal entry\nElapsed: %sm' "$(date +%H:%M)" "$(( ELAPSED / 60 ))")"
else
  MISSING=$(validate_frontmatter "$CLEANED_FILE")
  if [ -n "$MISSING" ]; then
    QUARANTINE="/var/log/uht-loop/quarantine/$(date +%Y%m%d-%H%M%S).md"
    mkdir -p "$(dirname "$QUARANTINE")"
    cp "$CLEANED_FILE" "$QUARANTINE"
    log "QUARANTINE: missing fields:$MISSING — saved to $QUARANTINE"
    send_telegram "$(printf 'UHT Loop — entry quarantined\nMissing:%s\nSaved: %s' "$MISSING" "$QUARANTINE")"
  else
    # Extract fields
    TITLE=$(grep "^title:" "$CLEANED_FILE" | head -1 | sed 's/^title:\s*"//;s/"$//')
    TASK_CLASS=$(grep "^task_class:" "$CLEANED_FILE" | head -1 | sed 's/^task_class:\s*//' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    SESSION_NUM=$(grep "^session:" "$CLEANED_FILE" | head -1 | sed 's/^session:\s*//' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    SESSION_N=$(echo "$SESSION_NUM" | grep -oP '\d+' || echo "0")

    # Derive slug
    SLUG=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//')

    DATE=$(date +%Y-%m-%d)
    FILENAME="${DATE}-${SESSION_N}-${SLUG}.md"
    FILEPATH="$POSTS_DIR/$FILENAME"

    echo "$(cat "$CLEANED_FILE")" > "$FILEPATH"
    log "Journal entry written to $FILEPATH"

    # --- Build Astro site ---
    if (cd "$JOURNAL_DIR" && npm run build) >> "$LOG_FILE" 2>&1; then
      log "Astro build succeeded"
      cp -r "$JOURNAL_DIR/dist/"* "$SERVE_DIR/"
      log "Site deployed to $SERVE_DIR"

      ENTRY_URL="https://journal.universalhex.org/posts/${FILENAME%.md}/"
      ELAPSED=$(( $(date +%s) - $(date -d "$SESSION_START" +%s 2>/dev/null || echo "0") ))

      # Single completion message — plain text, no Markdown escaping issues
      send_telegram "$(printf 'UHT Loop #%s complete\n\n%s\n\nTask: %s\nTime: %sm\n\n%s' \
        "$SESSION_N" "$TITLE" "${TASK_CLASS:-unknown}" "$(( ELAPSED / 60 ))" "$ENTRY_URL")"
    else
      log "ERROR: Astro build failed"
      send_telegram "UHT Loop — journal entry written but site build failed"
    fi
  fi
fi

# --- Check for pending findings notification ---
NOTIFY_JSON=$(uht-substrate facts query --predicate PENDING_NOTIFICATION 2>/dev/null || echo '{"facts":[]}')
NOTIFY_MSG=$(echo "$NOTIFY_JSON" | jq -r '.facts[0].object // ""')
NOTIFY_ID=$(echo "$NOTIFY_JSON" | jq -r '.facts[0].uuid // ""')

if [ -n "$NOTIFY_MSG" ] && [ "$NOTIFY_MSG" != "null" ]; then
  send_telegram "$(printf 'UHT Loop — finding flagged\n\n%s' "$NOTIFY_MSG")"
  if [ -n "$NOTIFY_ID" ] && [ "$NOTIFY_ID" != "null" ]; then
    uht-substrate facts delete "$NOTIFY_ID" 2>/dev/null || true
  fi
  log "Telegram notification sent: $NOTIFY_MSG"
fi

# --- Record session end ---
SESSION_END=$(date -u +%Y-%m-%dT%H:%M:%SZ)
log "SESSION END (started: $SESSION_START, ended: $SESSION_END)"
