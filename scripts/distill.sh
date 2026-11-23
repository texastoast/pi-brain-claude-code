#!/usr/bin/env bash
# Pi Brain — find Claude Code Working notes ready for distillation.
#
# Prints a JSON array of {session_id, path, created} for every Working note that
# Claude Code wrote, whose session has ended, and which has no Episodic note yet.
# Prints NOTHING when there is nothing to do, so callers can test for empty output.
# Always exits 0: this runs inside a SessionStart hook and must never break a
# session.
#
# WHY THIS EXISTS AT ALL: Hermes distils its own sessions via
# ~/.hermes/plugins/pi-brain/scripts/pi-brain-heartbeat.py, which queries Hermes'
# state.db for closed sessions. A Claude Code session is not in that database, so
# without this the Working notes this client writes would pile up in a shared vault
# forever and the third layer of the cascade would never run for us.
#
# THE HARD RULE: select only notes carrying `client: claude-code`. Three Hermes
# harnesses share this vault and their notes belong to their own distiller. A note
# with no client key is a Hermes note that predates the marker — it is NOT ours.
# Every ambiguous case resolves to "not mine".

set -uo pipefail

VAULT="${PI_BRAIN_VAULT_PATH:-}"

if [ -z "$VAULT" ] || [ ! -d "$VAULT" ]; then
  SYMLINK="$HOME/.hermes/pi-brain-vault"
  if [ -L "$SYMLINK" ] && [ -d "$SYMLINK" ]; then
    VAULT=$(readlink -f "$SYMLINK" 2>/dev/null || echo "$SYMLINK")
  fi
fi

[ -z "$VAULT" ] || [ ! -d "$VAULT/Working" ] && exit 0

VAULT="$VAULT" python3 <<'PY' 2>/dev/null || exit 0
import json, os, re, sys

vault = os.environ["VAULT"]
working, episodic = os.path.join(vault, "Working"), os.path.join(vault, "Episodic")

def frontmatter(text):
    if not text.startswith("---"):
        return {}
    end = text.find("\n---", 3)
    if end == -1:
        return {}
    out = {}
    for line in text[3:end].strip().split("\n"):
        if ":" in line:
            k, _, v = line.partition(":")
            out[k.strip()] = v.strip()
    return out

# session-ids that already have an Episodic note, whoever wrote it
done = set()
if os.path.isdir(episodic):
    for name in os.listdir(episodic):
        if not name.endswith(".md"):
            continue
        try:
            with open(os.path.join(episodic, name)) as fh:
                sid = frontmatter(fh.read()).get("session-id")
        except OSError:
            continue
        if sid:
            done.add(sid)

def captured_nothing(text):
    body = text.split("\n---", 1)[1] if text.startswith("---") else text
    body = re.sub(r"<!--.*?-->", "", body, flags=re.S)
    return all(
        not line.strip() or line.startswith("#") or line.startswith("Session ended.")
        for line in body.split("\n")[1:]
    )

ready = []
for name in sorted(os.listdir(working)):
    if not name.endswith(".md"):
        continue
    path = os.path.join(working, name)
    try:
        with open(path) as fh:
            text = fh.read()
    except OSError:
        continue
    fm = frontmatter(text)
    # The hard rule. Absent or different client => not ours, leave it alone.
    if fm.get("client") != "claude-code":
        continue
    if not re.search(r"^## Session End", text, re.M):
        continue  # still live
    sid = fm.get("session-id") or name[:-3]
    if sid in done or captured_nothing(text):
        continue
    ready.append({"session_id": sid, "path": path, "created": fm.get("created", "")})

if ready:
    print(json.dumps(ready))
PY
exit 0
