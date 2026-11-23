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

DATETIME=$(TZ=America/Chicago date +%Y-%m-%dT%H:%M:%S%z)

# Appended only once. Claude Code can fire SessionEnd more than once for a single
# session (clear, then exit), and a note carrying three "Session End" stanzas reads
# like three sessions to anything parsing the vault.
if grep -q '^## Session End' "$NOTE_PATH" 2>/dev/null; then
  echo '{}'
  exit 0
fi

# Says "distillation" without naming the heartbeat: Hermes' heartbeat queries its
# own state.db for closed sessions, and a Claude Code session is not in there. These
# notes are distilled by scripts/distill.sh in this plugin instead.
cat >> "$NOTE_PATH" << EOF

## Session End — ${DATETIME}

Session ended. Ready for distillation.
EOF

# Output (empty JSON = no special action, just exit cleanly)
echo '{}'
