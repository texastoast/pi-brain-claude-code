#!/usr/bin/env bash
# Pi Brain — SessionEnd hook
# Marks the session's Working note as ended so the heartbeat knows it's
# ready for distillation. Reads JSON event from stdin. Silent no-op if
# vault or working note not found.

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
SESSION_ID=$(echo "$EVENT" | jq -r '.session_id // empty' 2>/dev/null || echo "")

if [ -z "$SESSION_ID" ]; then
  exit 0
fi

NOTE_PATH="$VAULT/Working/${SESSION_ID}.md"

# No working note? Nothing to mark.
if [ ! -f "$NOTE_PATH" ]; then
  exit 0
fi

DATETIME=$(date -u +%Y-%m-%dT%H:%M:%S)

# Append session-end marker
cat >> "$NOTE_PATH" << EOF

## Session End — ${DATETIME}

Session ended. Ready for heartbeat distillation.
EOF

# Output (empty JSON = no special action, just exit cleanly)
echo '{}'
