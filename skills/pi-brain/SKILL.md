---
name: pi-brain
description: "Use when operating the Pi Brain Obsidian vault as three-layer memory. Provides bootstrap ritual, live capture protocol, vault-first search discipline, and metadata schema for the Pi Brain memory system. Load at session start and when writing decisions, plans, findings, or corrections to the vault."
---

# Pi Brain — Three-Layer Memory System

## Overview

The Pi Brain is an Obsidian vault that serves as the agent's persistent, compounding memory. It implements a three-layer cascade — Working → Episodic → Semantic — with the vault as the source of truth. Session lifecycle hooks create and close Working notes automatically. A heartbeat (run via cron in Hermes) distills session transcripts into episodic notes and promotes durable knowledge to semantic notes, all off-session.

The vault lives at the path stored in the `PI_BRAIN_VAULT_PATH` environment variable. File tools do not expand shell variables — resolve the path first and pass the absolute path to every file operation.

Design doc: `PI_BRAIN_VAULT_PATH/Pi Brain Design.md` (the evolving schema/convention file).

## Vault Path Resolution

At the start of every session, resolve the vault path:

```bash
# Check env var first
echo $PI_BRAIN_VAULT_PATH

# Fallback: symlink at ~/.hermes/pi-brain-vault
ls -la ~/.hermes/pi-brain-vault
```

If `PI_BRAIN_VAULT_PATH` is unset, fall back to the symlink at `~/.hermes/pi-brain-vault` (points to the local git repo clone of the vault). Every file path passed to `Read`, `Write`, `Edit`, `Grep`, or `Glob` must be the full absolute path under this vault root. Never pass `$PI_BRAIN_VAULT_PATH` to a file tool — it will not expand.

## When to Use

- **Every session start**: run the bootstrap ritual (below).
- **During sessions**: when a decision is made, a plan committed, a finding landed, a correction received — write a live note.
- **Before web search or terminal research**: check the vault first (vault-first discipline).
- **When asked "what did we decide about X"**: search the vault, not just session memory.
- **Don't use for**: throwaway calculations, single-command lookups, or anything where the answer is already in context.

## Bootstrap Ritual (automatic, every session)

The `SessionStart` hook creates a Working note automatically and injects a context reminder. On seeing the injected context, load this skill and read the vault entry points.

1. **Tier 1 (zero tool calls):** If vault path and recent context are already in your context window (injected by the hook), skip to work.
2. **Tier 2 (two reads):**
   - Read `PI_BRAIN_VAULT_PATH/index.md` — the master catalog. One file, map of everything in the vault with one-line summaries + wikilinks.
   - Read the latest file in `PI_BRAIN_VAULT_PATH/Daily/` (sort by name, newest first) — what happened recently, open threads, contradictions.
3. **Tier 3 (on demand):** When the user asks something, search the vault or follow wikilinks from `index.md` to read relevant notes.

**Do NOT** read all episodic notes, all semantic notes, or the full `log.md` at session start. They're too large and not needed unless the question touches them.

## Vault-First Search Discipline

Before using `WebSearch`, `WebFetch`, or `Bash` for research to answer a question:

1. Check if the answer is already in your context (free, no tool call).
2. If not, search the vault with `Grep` (content search) or check `index.md` for a relevant note.
3. If found, read the note(s) and answer from the vault.
4. Only if the vault doesn't have it (or it's stale), reach for external tools.

This is the core token-saving mechanism: make the first LLM call cheap, not absent.

## Live Capture Protocol

During sessions, write small notes at meaningful boundaries — NOT full transcripts. Write a note when:

### Decisions
When a decision is made with rationale:
- Create `Semantic/Decisions/<Decision Name>.md` using the decision template.
- One-line decision + rationale + wikilink to context.
- Set `confidence: low` (single-episode evidence; heartbeat may raise it later).

### Plans
When a plan is committed:
- Create `Plans/<Plan Name>.md` using the plan template.
- Goal, steps, related decisions/todos.
- Status: `committed` once agreed, `executing` when work starts.

### Todos
When a todo is committed:
- Create `Todos/<Todo Name>.md` using the todo template.
- One-line task + parent plan + due date.

### Research Findings
When a research thread lands a conclusion:
- Create or update `Research/<Finding Name>.md` using the research template.
- One-paragraph summary + source links + confidence.
- If updating an existing note, use `Edit` — don't overwrite prior findings.

### Corrections
When the user corrects you:
- Create `Semantic/Preferences/<Correction Name>.md` using the preference template.
- This is high-value — it's future semantic memory that prevents repeating the mistake.
- Set `confidence: low` (single-episode; heartbeat may corroborate later).

### New Facts (environment/tooling/user)
When a stable fact is established:
- Create the appropriate semantic note (`Facts/`, `Preferences/`, `Decisions/`).
- One-line fact + evidence wikilink.

### Working Notes
A working note is **automatically created by the `SessionStart` hook** when a new session begins — no agent action needed. The `SessionEnd` hook appends a session-end marker so the heartbeat knows it's ready for distillation.

## Note Size Rule

Notes must be **under 200 lines**. If a topic needs more:
- Create an **index note** that links to separate shorter sub-notes.

## Metadata Schema

### Common Frontmatter (all notes)

```yaml
---
type: <type>              # structural: working|episodic|decision|preference|fact|pattern|plan|todo|research|daily|index|log|design|archive
created: YYYY-MM-DD
last-reviewed: YYYY-MM-DD
status: active             # active|stale|archived
tags: [pi-brain/<type>]    # topical: domain, project, theme — nested with /
agent-written: true|false  # trust calibration
---
```

### Per-Type Extensions

**Semantic notes (decisions/preferences/facts/patterns) + research:**
```yaml
confidence: low|medium|high   # low=single-episode, medium=2 corroborating, high=3+ or user-confirmed
evidence: ["[[Episodic/session]]"]  # wikilinks to supporting episodes
topic: <topic-name>
```

**Plans:** `status` (draft|committed|executing|done|abandoned), `related-decisions: []`, `related-todos: []`.
**Todos:** `status` (open|done|cancelled), `parent-plan: [[Plans/name]]`, `due: YYYY-MM-DD`.
**Research:** `sources: [urls]`, `source-count: N`, `topic`, `confidence`.
**Episodic:** `session-id`, `session-date`, `summary`, `promoted-to: []`.
**Working:** `session-id`, `session-start: YYYY-MM-DDTHH:mm:ss`.
**Daily:** `date: YYYY-MM-DD`.

### Wikilink Conventions

- `[[Note Name]]` — human-readable names, not slugged.
- Frontmatter wikilink lists: `evidence: ["[[Note 1]]", "[[Note 2]]"]`.
- Body links inline: `[[Note Name]]` or `[[Note Name|display text]]`.

## Folder Topology

```
Pi Brain/
├── index.md          # master catalog — read first
├── log.md            # append-only chronological record
├── Pi Brain Design.md  # the schema/convention file
├── Working/          # Layer 1: session-scoped
├── Episodic/         # Layer 2: timestamped session logs
├── Semantic/         # Layer 3: distilled knowledge
│   ├── Decisions/
│   ├── Preferences/
│   ├── Facts/
│   └── Patterns/
├── Plans/            # committed plans
├── Todos/            # committed todos
├── Research/         # research findings + source digests
├── Daily/            # heartbeat daily briefings
├── Templates/        # note templates for each type
└── Archive/          # pruned notes (archive, never delete)
```

## Common Pitfalls

1. **Passing `$PI_BRAIN_VAULT_PATH` to file tools.** They don't expand shell variables. Resolve the path first, pass the absolute path.
2. **Writing full transcripts live.** Don't. Live capture is for high-signal items only.
3. **Forgetting to update `index.md`.** When you create a new note, add it to the relevant section in `index.md`.
4. **Overwriting contradictory notes.** If a new finding contradicts an existing note, do NOT overwrite. Flag the contradiction in both notes.
5. **Writing secrets to the vault.** Never. The vault syncs across environments and is a git repo. Redact to `[REDACTED]`.
6. **Creating notes >200 lines.** Split into sub-notes + an index note.
7. **Not searching the vault before researching.** Always check `index.md` and `Grep` before external tools.
8. **Using slugged note names.** Use human-readable names: `[[Three Layer Memory Decision]]` not `[[three-layer-memory-decision]]`.

## Verification Checklist

- [ ] `PI_BRAIN_VAULT_PATH` env var is set or symlink resolves
- [ ] Bootstrap ritual runs at session start (read index.md + latest daily briefing)
- [ ] Vault-first discipline: check vault before external tools
- [ ] Live capture: decisions/plans/todos/findings/corrections written at meaningful boundaries
- [ ] Notes under 200 lines; index notes for overflow
- [ ] Frontmatter matches the schema for each note type
- [ ] Wikilinks use `[[Human Readable Name]]` format
- [ ] No secrets in the vault — redact to `[REDACTED]`
- [ ] `index.md` updated when new notes are created
