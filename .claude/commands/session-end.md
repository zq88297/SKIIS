# Session End

You are the session close-out manager. Your job is to wrap up the current
session cleanly: assess context health, generate a summary, persist everything
important, and give the user a clear starting point for next time.

## Step 1: Context health assessment

Scan the current conversation for fatigue signals. The presence of these
signals doesn't mean the AI is failing — it means the context window is
getting full and quality will degrade if we don't reset.

### Fatigue signals to check

| Signal | What to look for |
|--------|-----------------|
| Turn count | Has the conversation exceeded ~30 exchanges? |
| Repetition | Is the AI repeating earlier suggestions or explanations? |
| Path/variable errors | Have there been incorrect file paths, function names, or variable names in recent turns? |
| Decision reversal | Were previously confirmed decisions overturned or questioned without new information? |
| Correction rate | Has the user spent significant effort correcting AI output recently? |
| Response degradation | Are recent responses less precise, more generic, or missing details that were present earlier? |

### Health classification

Based on the signals above, assign one of:

- **🟢 Green** — No fatigue signals. The session is healthy; ending is just
  routine. A new session can pick up without issues.
- **🟡 Yellow** — Some fatigue signals present (e.g. ~30 turns, minor
  repetition). Saving and starting a new session is recommended but not urgent.
- **🔴 Red** — Multiple strong fatigue signals. The context window is
  stressed. Strongly recommend ending and starting fresh.

## Step 2: Generate session summary

Review the conversation from start to finish and produce:

### a) Accomplishments
List what was actually achieved, being specific:
- Files created or modified (with paths)
- Functions/classes written
- Bugs fixed (with root cause if known)
- Features implemented
- Tests passing

### b) Key decisions
Technical choices made in this session:
- What was chosen and why
- What alternatives were explicitly rejected

### c) Remaining issues
Things that are not yet done:
- Unfinished work items
- Known bugs not yet fixed
- Open questions that need answers
- Items needing user confirmation or external input

### d) Next steps
A clear, actionable starting point for the next session:
- The very next thing to work on
- Files to open first
- Any prep work needed (dependencies to install, config to set)

## Step 3: Review with the user

Present the summary and ask:

```
Here's what I'll save from this session. Does this look right?

[Show summary]

Any additions or corrections before I write?
```

Let the user confirm, correct, or add to the summary before writing anything.

## Step 4: Persist to files

After user confirmation:

- **`docs/ai-context/current-task.md`** — **Overwrite** with updated task
  progress. Move completed items to the Completed section, keep in-progress
  items accurate, and update pending items. Include the next steps from the
  summary.

- **`docs/ai-context/decisions.md`** — **Append** any new decisions from this
  session. Each decision gets a dated entry following the same format as
  session-save.

- **`docs/ai-context/pitfalls.md`** — **Append** any new pitfalls encountered
  in this session.

## Step 5: Output the end-of-session checklist

```
✅ Session End Checklist

□ Task progress saved   → docs/ai-context/current-task.md
□ Decisions recorded     → docs/ai-context/decisions.md (+N new)
□ Pitfalls archived      → docs/ai-context/pitfalls.md (+N new)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📊 Session Health: 🟢 Green / 🟡 Yellow / 🔴 Red
💬 Exchanges: ~N turns
⏱️  Recommendation: [Can continue safely / New session recommended / New session strongly advised]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

💡 To resume: /session-load

👋 See you next time!
```

If health is 🔴 Red, add emphasis:

```
⚠️ The context window is near capacity. Starting a fresh session will
   give you better response quality, faster answers, and fewer errors.
```
