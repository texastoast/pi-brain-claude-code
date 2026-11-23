#!/bin/bash
# Tests for distill.sh — finds Claude Code Working notes ready for distillation.
#
# THE RULE THIS FILE EXISTS TO ENFORCE: four harnesses share this vault, three of
# them Hermes, and Hermes distils its own notes from its own state.db. This finder
# must therefore select ONLY notes it can prove Claude Code wrote — `client:
# claude-code` in the frontmatter. Selecting a Hermes note would hand it to a
# distiller that is not its owner and could double-distil or mangle it. Every
# ambiguous case must resolve to "not mine".
#
# Injectable:
#   PI_BRAIN_VAULT_PATH  — the vault to scan

DISTILL="$(cd "$(dirname "$0")/../scripts" && pwd)/distill.sh"
PASS=0
FAIL=0
export TZ=UTC

check() {
  if [ "$2" = "$3" ]; then PASS=$((PASS+1)); printf '  ok   %s\n' "$1"
  else FAIL=$((FAIL+1)); printf '  FAIL %s\n       expected: %s\n       actual:   %s\n' "$1" "$2" "$3"; fi
}

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
V="$TMP/vault"
mkdir -p "$V/Working" "$V/Episodic"

# note <name> <client-line> <ended?>
note() {
  local f="$V/Working/$1.md"
  {
    echo "---"
    echo "type: working"
    echo "created: 2026-08-01"
    [ -n "$2" ] && echo "$2"
    echo "session-id: $1"
    echo "---"
    echo
    echo "# Working"
    echo "Some real captured content."
    [ "$3" = "ended" ] && { echo; echo "## Session End — 2026-08-01T17:00:00-0500"; }
  } > "$f"
}

ids() { PI_BRAIN_VAULT_PATH="$V" "$DISTILL" 2>/dev/null | python3 -c "
import json,sys
s=sys.stdin.read().strip()
print(','.join(sorted(x['session_id'] for x in json.loads(s))) if s else '')
"; }

echo "== it selects its own ended notes =="
note mine-ended   "client: claude-code" ended
check "an ended claude-code note is ready to distil" "mine-ended" "$(ids)"

echo "== it leaves Hermes notes strictly alone =="
# The prime directive. A Hermes note has no client key at all (they predate it).
note hermes-old   ""                    ended
note hermes-named "client: hermes"      ended
check "a note with no client key is not claimed" "mine-ended" "$(ids)"
check "a note explicitly owned by hermes is not claimed" "mine-ended" "$(ids)"

echo "== an active session is not ready =="
note mine-active  "client: claude-code" active
check "a note with no Session End marker is skipped" "mine-ended" "$(ids)"

echo "== already distilled means done =="
cat > "$V/Episodic/2026-08-01 Something.md" <<'EOF'
---
type: episodic
session-id: mine-ended
---
EOF
check "a note whose Episodic note exists is skipped" "" "$(ids)"

echo "== an untouched template has nothing to distil =="
cat > "$V/Working/mine-empty.md" <<'EOF'
---
type: working
client: claude-code
session-id: mine-empty
---

# Working — 2026-08-01

## Live Capture

<!-- Decisions, plans, findings, corrections written as they happen this session -->

## Session End — 2026-08-01T17:00:00-0500

Session ended. Ready for distillation.
EOF
check "an ended note with only headings and comments is skipped" "" "$(ids)"
rm -f "$V/Working/mine-empty.md"

echo "== several at once, in order =="
rm -f "$V/Episodic"/*.md
note mine-b "client: claude-code" ended
note mine-a "client: claude-code" ended
check "all ready notes are returned" "mine-a,mine-b,mine-ended" "$(ids)"

echo "== silence when there is nothing to do =="
rm -f "$V/Working"/*.md
out=$(PI_BRAIN_VAULT_PATH="$V" "$DISTILL" 2>/dev/null)
check "empty vault produces empty stdout, not '[]'" "" "$out"
check "and still exits 0" "0" "$?"

echo "== it never breaks the caller =="
PI_BRAIN_VAULT_PATH="/nope/nope/nope" "$DISTILL" >/dev/null 2>&1
check "a missing vault exits 0 and says nothing" "0" "$?"
PI_BRAIN_VAULT_PATH="" "$DISTILL" >/dev/null 2>&1
check "an unset vault exits 0 and says nothing" "0" "$?"
rm -rf "$V/Working"
PI_BRAIN_VAULT_PATH="$V" "$DISTILL" >/dev/null 2>&1
check "a vault with no Working dir exits 0" "0" "$?"

echo "== output shape =="
mkdir -p "$V/Working"
note shape "client: claude-code" ended
PI_BRAIN_VAULT_PATH="$V" "$DISTILL" | python3 -c "
import json,sys
d=json.loads(sys.stdin.read())
r=d[0]
ok = all(k in r for k in ('session_id','path','created')) and r['path'].endswith('shape.md')
print('ok' if ok else 'bad: '+json.dumps(r))
" > "$TMP/shape"
check "each entry carries session_id, path and created" "ok" "$(cat "$TMP/shape")"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
