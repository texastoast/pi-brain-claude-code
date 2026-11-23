#!/bin/bash
# Tests for session-start.sh — the hook output Claude Code reads.
#
# Claude Code injects a SessionStart hook's message only from
# hookSpecificOutput.additionalContext. Any other key is silently dropped, which
# leaves Working notes created but never filled in.

HOOK="$(cd "$(dirname "$0")/../hooks-handlers" && pwd)/session-start.sh"
PASS=0
FAIL=0

check() {
  if [ "$2" = "$3" ]; then PASS=$((PASS+1)); printf '  ok   %s\n' "$1"
  else FAIL=$((FAIL+1)); printf '  FAIL %s\n       expected: %s\n       actual:   %s\n' "$1" "$2" "$3"; fi
}

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
V="$TMP/vault"
mkdir -p "$V/Working" "$V/Episodic"

OUT=$(echo '{"session_id":"test-session"}' | PI_BRAIN_VAULT_PATH="$V" bash "$HOOK")

echo "== it speaks Claude Code's SessionStart schema =="
check "event name is SessionStart" "SessionStart" "$(echo "$OUT" | jq -r '.hookSpecificOutput.hookEventName')"
check "message is in additionalContext" "true" "$(echo "$OUT" | jq -r '.hookSpecificOutput.additionalContext | startswith("[Pi Brain]")')"
check "no keys Claude Code does not read" "additionalContext,hookEventName" "$(echo "$OUT" | jq -r '.hookSpecificOutput | keys | join(",")')"
check "working note is created" "yes" "$([ -f "$V/Working/test-session.md" ] && echo yes || echo no)"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
