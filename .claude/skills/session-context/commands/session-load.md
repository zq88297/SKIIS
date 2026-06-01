# Session Context Load

You are the context recovery agent. Your job is to rapidly restore project
awareness at the start of a new session by reading persisted context files
and presenting a structured summary to the user.

## Step 1: Discover context files

Check for the existence of each of these files and note their status:

| File | Location |
|------|----------|
| Project fundamentals | `CLAUDE.md` |
| Current task | `docs/ai-context/current-task.md` |
| Technical decisions | `docs/ai-context/decisions.md` |
| Pitfalls | `docs/ai-context/pitfalls.md` |
| Architecture | `docs/ai-context/architecture.md` |

## Step 2: Load in priority order

Read the files that exist, in this order (most critical first):

1. **CLAUDE.md** — Project identity, conventions, build commands
2. **current-task.md** — Where we left off (the most important file)
3. **decisions.md** — What was decided and why
4. **pitfalls.md** — What went wrong and how to avoid it
5. **architecture.md** — System structure

If the user specified a narrower scope in `$ARGUMENTS` (e.g. "just the task
progress"), honor that and skip the rest.

## Step 3: Present the summary

Format the recovered context clearly:

```
📋 Project Context Loaded

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📌 Project
[From CLAUDE.md: project name, type, tech stack, key conventions]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔄 Current Task Progress
[From current-task.md]

✅ Completed:
  • item 1
  • item 2

🚧 In Progress:
  • item 3 — [current state, blockers if any]

📋 Pending:
  • item 4
  • item 5

🔑 Key Context:
  [Important constraints, config values, API details, ports, etc.]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⚡ Recent Decisions (last 5)
[From decisions.md — show ID, date, and one-line summary]

  2026-06-01-1: Chose X over Y because Z
  2026-05-30-1: Decided to use pattern A for module B

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⚠️ Pitfall Warnings
[From pitfalls.md — show recent issues and prevention tips]

  • Problem: <brief description> → Avoid by: <prevention tip>

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ Ready. What should we work on?
```

Keep each section concise. The goal is to give the user (and you) enough
context to continue working without re-reading entire conversation histories.

## Step 4: Initialize if nothing exists

If none of the context files exist, respond with:

```
⚠️ No context files found.

This project doesn't have persisted session context yet.

I can initialize the context system now:
  • Create docs/ai-context/ directory
  • Create template files for current-task.md, decisions.md, pitfalls.md
  • Optionally scaffold architecture.md

Would you like me to set this up?
```

If the user says yes, create the directory and template files:

- `docs/ai-context/current-task.md`:
  ```markdown
  > Last updated: [today's date]

  # Current Task

  ## Completed
  [No tasks recorded yet]

  ## In Progress
  [No tasks in progress]

  ## Pending
  [No pending tasks]

  ## Key Context
  [No context recorded yet]
  ```

- `docs/ai-context/decisions.md`:
  ```markdown
  # Technical Decisions

  Record of significant technical choices made during development.
  Each decision includes context, options considered, rationale, and trade-offs.
  ```

- `docs/ai-context/pitfalls.md`:
  ```markdown
  # Pitfalls & Lessons Learned

  Problems encountered and their solutions. Read before repeating mistakes.
  ```
