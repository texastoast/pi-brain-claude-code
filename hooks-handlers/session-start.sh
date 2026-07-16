#!/usr/bin/env bash
# Pi Brain — SessionStart hook
# Creates a Working note in the vault for this session.
# Reads JSON event from stdin (Claude Code hook protocol).
# Silently no-ops if vault is not configured.

set -euo pipefail

# Read the event JSON from stdin
EVENT=$(cat)

# Resolve vault path
VAULT="${PI_BRAIN_VAULT_PATH:-}"

# Fallback: check symlink
if [ -z "$VAULT" ] || [ ! -d "$VAULT" ]; then
  SYMLINK="$HOME/.hermes/pi-brain-vault"
  if [ -L "$SYMLINK" ] && [ -d "$SYMLINK" ]; then
    VAULT=$(readlink -f "$SYMLINK" 2>/dev/null || echo "$SYMLINK")
  fi
fi

# No vault? Silent no-op.
if [ -z "$VAULT" ] || [ ! -d "$VAULT" ]; then
  exit 0
fi

# Extract session ID from event JSON
# Claude Code provides session_id in the event
SESSION_ID=$(echo "$EVENT" | jq -r '.session_id // empty' 2>/dev/null || echo "")

if [ -z "$SESSION_ID" ]; then
  # Generate a fallback ID from timestamp
  SESSION_ID="claude_$(date -u +%Y%m%d_%H%M%S)"
fi

# Skip cron-like sessions (shouldn't happen in Claude Code, but be safe)
case "$SESSION_ID" in
  cron_*) exit 0 ;;
esac

WORKING_DIR="$VAULT/Working"
mkdir -p "$WORKING_DIR"

NOTE_PATH="$WORKING_DIR/${SESSION_ID}.md"

# Already exists? Don't overwrite.
if [ -f "$NOTE_PATH" ]; then
  exit 0
fi

DATE=$(date -u +%Y-%m-%d)
DATETIME=$(date -u +%Y-%m-%dT%H:%M:%S)

cat > "$NOTE_PATH" << EOF
---
type: working
created: ${DATE}
last-reviewed: ${DATE}
status: active
tags: [pi-brain/working]
agent-written: true
session-id: ${SESSION_ID}
session-start: ${DATETIME}
---

# Working — ${DATE}

## Active Focus

<!-- What we're working on right now -->

## Recent Decisions (this session)

- <!-- one-line decisions -->

## Open Threads

- [ ] Thread 1
- [ ] Thread 2

## Live Capture

<!-- Decisions, plans, findings, corrections written as they happen this session -->
EOF

# Output JSON to inject context into Claude's first turn
jq -n --arg vault "$VAULT" --arg sid "$SESSION_ID" '{
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    context: ("[Pi Brain] You have a three-layer memory vault at: \($vault)\nLoad the pi-brain skill and run the bootstrap ritual: read index.md and the latest Daily briefing from the vault.\nBefore using web_search or terminal for research, always check the vault first.\nA working note has been created for this session (\($sid)) in Working/."),
    tag: "pi-brain-session-start"
  }
}'
