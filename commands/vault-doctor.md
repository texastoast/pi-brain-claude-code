---
description: "Run full Pi Brain vault diagnostic — env, symlink, structure, templates, activity"
---

# Pi Brain Vault Doctor

Run a full diagnostic of the Pi Brain vault. Check every required component and report issues.

Use Bash to check each of these:

1. **Environment**: Is `PI_BRAIN_VAULT_PATH` set? Does the directory exist?
2. **Symlink**: Does `~/.hermes/pi-brain-vault` exist and point to the vault?
3. **Core files**: index.md, log.md, Pi Brain Design.md — all present?
4. **Folder structure**: Working/, Episodic/, Semantic/Decisions/, Semantic/Preferences/, Semantic/Facts/, Semantic/Patterns/, Plans/, Todos/, Research/, Daily/, Templates/, Archive/ — all present?
5. **Templates**: Are the template files in Templates/?
6. **Recent activity**: Latest daily briefing date, any stale working notes (>48h)?

Report each check with ✓/✗ and list any issues found at the end.
