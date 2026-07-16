---
description: "Check Pi Brain vault status — env var, vault path, index, briefings, working notes"
---

# Pi Brain Vault Status

Check the Pi Brain vault status. Run the vault status script and report:

1. Whether `PI_BRAIN_VAULT_PATH` is set and points to an existing directory
2. Whether the vault structure is intact (key files: index.md, log.md, Pi Brain Design.md)
3. How many daily briefings exist and which is the latest
4. How many working notes are active
5. How many episodic and semantic notes exist

Use Bash to run:
```
echo "PI_BRAIN_VAULT_PATH=$PI_BRAIN_VAULT_PATH"
ls -la "$PI_BRAIN_VAULT_PATH/index.md" 2>/dev/null
ls "$PI_BRAIN_VAULT_PATH/Daily/" | tail -5
ls "$PI_BRAIN_VAULT_PATH/Working/" | wc -l
ls "$PI_BRAIN_VAULT_PATH/Episodic/" | wc -l
find "$PI_BRAIN_VAULT_PATH/Semantic/" -name "*.md" | wc -l
```

Report the results clearly with ✓/✗ markers.
