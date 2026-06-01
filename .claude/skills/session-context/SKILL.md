---
name: session-context
description: >-
  Complete context lifecycle management for Claude Code projects — save, load,
  and health-check session context across sessions. Use this skill whenever
  the user wants to save their current progress, restore context at the start
  of a new session, end a session cleanly, or check context health mid-session.
  Triggers on phrases like "save my context", "save progress", "restore context",
  "load context", "end session", "wrap up", "context health", "am I losing context",
  "/project:session-save", "/project:session-load", "/project:session-end",
  "/project:context-check", or when the user expresses concern about losing track
  of work across sessions. Also trigger when the user asks to "remember where
  we are", "bookmark this point", or mentions wanting to continue work later.
---

# Session Context Management

Manage project context across Claude Code sessions using a structured set of
persistent markdown files in `docs/ai-context/`. This skill provides four
slash commands that together form a complete context lifecycle:
**save → load → health-check → end**.

## Context file system

All context lives under `docs/ai-context/` in the project root:

| File | Purpose | Update strategy |
|------|---------|-----------------|
| `current-task.md` | Task progress with checkboxes | **Overwritten** each save |
| `decisions.md` | Technical decision log | **Appended** (never overwritten) |
| `pitfalls.md` | Lessons learned / gotchas | **Appended** (never overwritten) |
| `architecture.md` | Project architecture reference | Created once, manually curated |

Additionally, `CLAUDE.md` at the project root holds project fundamentals and
the context management convention (see Integration below).

## Commands

This skill exposes four slash commands. When the user invokes one, read the
corresponding file from `commands/` and follow its instructions:

- `/project:session-save` → [commands/session-save.md](commands/session-save.md)
- `/project:session-load` → [commands/session-load.md](commands/session-load.md)
- `/project:session-end` → [commands/session-end.md](commands/session-end.md)
- `/project:context-check` → [commands/context-check.md](commands/context-check.md)

## When to use which command

| Situation | Command |
|-----------|---------|
| Starting a new session | `/project:session-load` |
| Work milestone reached, want to checkpoint | `/project:session-save` |
| Finishing work for the day / switching tasks | `/project:session-end` |
| AI seems forgetful, repeating, or making errors | `/project:context-check` |
| User says "let's stop here" | `/project:session-end` |
| User says "remind me where we are" | `/project:session-load` |

## Proactive reminders

During long sessions, watch for these signals and suggest the appropriate
command before the user has to ask:

- **~20 exchanges**: Suggest `/project:session-save` as a checkpoint
- **~30+ exchanges**: Suggest `/project:context-check` — fatigue may be setting in
- **User correcting the same thing twice**: Strong signal for `/project:context-check`
- **User says "I need to go" or "let's pause"**: Offer `/project:session-end`

## Integration with CLAUDE.md

For maximum effectiveness, add this section to the project's `CLAUDE.md`:

```markdown
## Context Management

This project uses the session-context skill for context lifecycle management.

1. Each new session starts with `/project:session-load` — the user will run
   this, and you should cooperate by reading the referenced files.
2. When conversation exceeds ~20 exchanges without a save, gently remind the
   user to run `/project:session-save`.
3. When you notice context inconsistency (repeated corrections, forgotten
   decisions), suggest `/project:context-check`.
4. After important technical decisions are made, ask the user if they want to
   record it via `/project:session-save`.
```
