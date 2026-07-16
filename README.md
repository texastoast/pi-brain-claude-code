# pi-brain-claude-code

A Claude Code plugin that turns an Obsidian vault into the agent's persistent, compounding memory. Implements a three-layer cascade — Working → Episodic → Semantic — with the vault as the source of truth.

This is the Claude Code port of the [Hermes pi-brain plugin](https://github.com/texastoast/pi-brain-plugin). Both plugins share the same vault and schema.

## What It Does

- **SessionStart hook**: Creates a `Working/<session-id>.md` note in the vault and injects context telling Claude to run the bootstrap ritual.
- **SessionEnd hook**: Appends a session-end marker so the heartbeat knows the note is ready for distillation.
- **pi-brain skill**: Full protocol — bootstrap ritual (read `index.md` + latest daily briefing), vault-first search discipline, live capture protocol, metadata schema, folder topology, and pitfalls.
- **Slash commands**: `/vault-status` and `/vault-doctor` for quick diagnostics.
- **Templates**: 10 Obsidian note templates (decision, daily, episodic, fact, pattern, plan, preference, research, todo, working).

## Prerequisites

- **Claude Code** v2.1+ (`npm install -g @anthropic-ai/claude-code`)
- **An Obsidian vault** with the Pi Brain folder structure (or run the Hermes plugin's `hermes pi-brain setup` to initialize one)
- **`PI_BRAIN_VAULT_PATH`** environment variable pointing to the vault directory
- **`jq`** installed (used by hook scripts for JSON processing)
- **`bash`** (macOS/Linux — the hook scripts are bash)

## Install

### From this repo (skills-dir plugin)

```bash
# Clone into your Claude Code skills directory
git clone https://github.com/texastoast/pi-brain-claude-code.git ~/.claude/skills/pi-brain
```

The plugin auto-loads as `pi-brain@skills-dir` on the next Claude Code session. Run `/reload-plugins` inside Claude Code to load it immediately.

### Verify installation

```bash
claude plugin validate ~/.claude/skills/pi-brain
claude plugin details pi-brain@skills-dir
```

## Configuration

Set the `PI_BRAIN_VAULT_PATH` environment variable to point to your Obsidian vault:

```bash
# In your shell profile (~/.zshrc, ~/.bashrc, etc.)
export PI_BRAIN_VAULT_PATH="/path/to/vault/Pi Brain"
```

Or if you also use the Hermes pi-brain plugin, it's already set in `~/.hermes/.env`.

### Fallback: symlink

If `PI_BRAIN_VAULT_PATH` is not set, the hooks check for a symlink at `~/.hermes/pi-brain-vault` (created by the Hermes plugin's setup).

## Vault Structure

```
Pi Brain/
├── index.md          # master catalog — read first
├── log.md            # append-only chronological record
├── Pi Brain Design.md  # the schema/convention file
├── Working/          # Layer 1: session-scoped (auto-created by hooks)
├── Episodic/         # Layer 2: timestamped session logs (heartbeat)
├── Semantic/         # Layer 3: distilled knowledge (heartbeat)
│   ├── Decisions/
│   ├── Preferences/
│   ├── Facts/
│   └── Patterns/
├── Plans/
├── Todos/
├── Research/
├── Daily/            # heartbeat daily briefings
├── Templates/        # note templates
└── Archive/          # pruned notes (archive, never delete)
```

## How It Works

### Session Start
1. The `SessionStart` hook fires and creates `Working/<session-id>.md` with the working note template.
2. It injects a `[Pi Brain]` context message telling Claude to load the skill and run the bootstrap ritual.
3. Claude reads `index.md` (master catalog) and the latest daily briefing from `Daily/`.

### During the Session
- Claude follows **vault-first search discipline**: check the vault before reaching for web search or terminal research.
- At meaningful boundaries (decisions, plans, findings, corrections), Claude writes live notes to the appropriate vault folders.
- All notes use the Pi Brain metadata schema with proper frontmatter.

### Session End
1. The `SessionEnd` hook appends a `## Session End` marker to the working note.
2. This signals the heartbeat (run via cron in Hermes) that the note is ready for distillation into an episodic note.

## Sharing with Hermes

Both plugins use the same `PI_BRAIN_VAULT_PATH` and the same vault. They can run on the same machine without conflict. The Hermes plugin's heartbeat cron handles distillation and promotion for both.

## Token Cost

Per `claude plugin details`:
- **Always-on**: ~201 tokens per session
- **On-invoke (pi-brain skill)**: ~3.6k tokens
- **On-invoke (slash commands)**: ~310-320 tokens each

## License

MIT
