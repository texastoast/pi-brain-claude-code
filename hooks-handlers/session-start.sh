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

# Central, not UTC. The shell exports TZ=UTC, so `date -u` filed any note written
# after 7pm Central under tomorrow's date — which misdates the note and breaks the
# link to that day's briefing. Every other piece of Dan's tooling is explicit about
# Central; this now matches.
DATE=$(TZ=America/Chicago date +%Y-%m-%d)
DATETIME=$(TZ=America/Chicago date +%Y-%m-%dT%H:%M:%S%z)

# `client` exists because four harnesses share this vault — three Hermes and this
# one. It is what lets Claude Code's own distillation find its own notes and leave
# every Hermes note strictly alone. It is additive: Hermes reads `session-id` from
# Episodic frontmatter and ignores unknown keys.
cat > "$NOTE_PATH" << EOF
---
type: working
created: ${DATE}
last-reviewed: ${DATE}
status: active
tags: [pi-brain/working]
agent-written: true
client: claude-code
session-id: ${SESSION_ID}
session-start: ${DATETIME}
---

# Working — ${DATE}

## Active Focus

<!-- What we're working on right now -->

## Recent Decisions (this session)

<!-- Decisions made during this session -->

## Open Threads

<!-- Threads to track -->

## Live Capture

<!-- Decisions, plans, findings, corrections written as they happen this session -->
EOF

# Any of this client's earlier sessions ended without being distilled? Hermes'
# heartbeat cannot do it for us — it reads closed sessions out of Hermes' own
# state.db and a Claude Code session was never in there. So the cascade's third
# layer is triggered here, in a session that is already loaded, rather than by yet
# another scheduled job. Never fatal: no pending notes means no extra instruction.
PENDING_NOTE=""
PENDING=$(PI_BRAIN_VAULT_PATH="$VAULT" bash "$(dirname "$0")/../scripts/distill.sh" 2>/dev/null || true)
if [ -n "$PENDING" ]; then
  COUNT=$(printf '%s' "$PENDING" | jq 'length' 2>/dev/null || echo "")
  if [ -n "$COUNT" ] && [ "$COUNT" != "0" ]; then
    PENDING_NOTE=$(printf '\n%s of this client'"'"'s earlier sessions ended without being distilled. Run scripts/distill.sh, read each Working note it lists, and write an Episodic note for it per the skill. Distil ONLY what that script returns — the other harnesses own their own notes.' "$COUNT")
  fi
fi

# Output JSON to inject context into Claude's first turn
jq -n --arg vault "$VAULT" --arg sid "$SESSION_ID" --arg pending "$PENDING_NOTE" '{
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    context: ("[Pi Brain] You have a three-layer memory vault at: \($vault)\nLoad the pi-brain skill and run the bootstrap ritual: read index.md and the latest Daily briefing from the vault.\nBefore using web_search or terminal for research, always check the vault first.\nA working note has been created for this session (\($sid)) in Working/. Capture decisions, findings and corrections into its Live Capture section as they happen — an empty working note is the failure mode this system has already had." + $pending),
    tag: "pi-brain-session-start"
  }
}'
