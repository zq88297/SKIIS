# Session Context Save

You are the context persistence manager. Your job is to extract key information
from the current conversation and write it to structured files so a fresh
session can pick up where this one left off.

## Step 1: Determine save scope

Check `$ARGUMENTS` for scope hints from the user (e.g. "only current task",
"save everything", "just the decisions"). If no scope is specified, ask the
user what they want to save:

- **Current task progress** — what's done, in progress, and pending
- **Technical decisions** — choices made and why
- **Problems & pitfalls** — issues encountered and their solutions
- **All of the above** (default)

If the user gave a scope in `$ARGUMENTS`, honor it without asking.

## Step 2: Read existing context files

Check for and read these files (if they exist):

1. `docs/ai-context/current-task.md`
2. `docs/ai-context/decisions.md`
3. `docs/ai-context/pitfalls.md`
4. `docs/ai-context/architecture.md`

Also read `CLAUDE.md` if it exists, to understand project conventions.

## Step 3: Analyze the conversation

Review the current conversation and extract:

### Task progress (for `current-task.md`)

- **Completed**: What has been finished — be specific: files created/modified,
  functions written, bugs fixed. Use past tense.
- **In progress**: What is actively being worked on right now, including its
  current state and any blockers.
- **Pending**: What still needs to be done, in priority order.
- **Key context**: Interface formats, configuration values, special constraints,
  environment details, port numbers, API endpoints — anything that would be
  painful to reconstruct from scratch.

Use `- [x]` for completed items, `- [ ]` for pending items.

### Technical decisions (for `decisions.md`)

For each meaningful decision made in this conversation, capture:

- **Decision ID**: `YYYY-MM-DD-N` (e.g. `2026-06-01-1`)
- **Context**: What problem were we solving?
- **Options considered**: What alternatives were on the table?
- **Choice**: What did we pick?
- **Rationale**: Why this option over the others?
- **Explicitly rejected**: What did we decide NOT to use, and why?
- **Trade-offs**: What are we giving up with this choice?

Append new decisions to the existing file — never overwrite old decisions.

### Pitfalls (for `pitfalls.md`)

For each problem encountered:

- **Problem**: What happened? (symptoms)
- **Root cause**: Why did it happen?
- **Solution**: How was it fixed?
- **Prevention**: How to avoid this in the future?

Append new pitfalls to the existing file — never overwrite old ones.

## Step 4: Write the files

Create the `docs/ai-context/` directory if it doesn't exist. Then:

- **`current-task.md`**: Overwrite with the updated task progress. Use a clear
  structure with `## Completed`, `## In Progress`, `## Pending`, and
  `## Key Context` sections. Include a `> Last updated: YYYY-MM-DD HH:MM`
  blockquote at the top.
- **`decisions.md`**: Append new decisions. If the file doesn't exist, create
  it with a `# Technical Decisions` heading and an intro sentence.
- **`pitfalls.md`**: Append new pitfalls. If the file doesn't exist, create it
  with a `# Pitfalls & Lessons Learned` heading and an intro sentence.

## Step 5: Report

Summarize what was saved:

```
✅ Context saved

| File | Action | Content |
|------|--------|---------|
| current-task.md | Updated | N completed, M pending tasks |
| decisions.md | +N new | Decision YYYY-MM-DD-N: <summary> |
| pitfalls.md | +N new | <problem summary> |

💡 Next session, run /project:session-load to restore.
```
