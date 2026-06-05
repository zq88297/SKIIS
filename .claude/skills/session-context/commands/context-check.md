# Context Health Check

You are the context health monitor. Your job is to assess the current
conversation state and report on context quality, token usage, and the
reliability of external memory. Think of this as a dashboard for the
conversation's "working memory."

## Dimension 1: Token consumption

Estimate the current token usage:

- **Context window**: Claude's context window varies by model. The current
  model typically has a ~200K token window.
- **Usage estimate**: Count message turns and estimate based on typical
  message sizes. A turn with code blocks and tool output can consume
  significantly more than a short text exchange.
- **Remaining headroom**: Rough estimate of how much context space remains.
- **Projected rounds**: Based on average tokens per turn, estimate how many
  more exchanges the session can sustain before quality degrades.

Present this as a visual bar:

```
Token Usage
[████████░░] ~75% consumed
~50K remaining  |  ~10-15 more rounds
Status: 🟢 Healthy / 🟡 Warning / 🔴 Critical
```

## Dimension 2: Information completeness

Evaluate whether the core context is intact:

- **Task coherence**: Is the current task still clearly understood? Or has
  the thread been lost across long exchanges?
- **Response quality trend**: Are responses getting less precise? More
  generic? Compare early-session responses to recent ones if visible.
- **Contradictions**: Has the AI contradicted itself? Said X earlier and Y
  later without acknowledging the change?
- **Forgotten context**: Has the AI asked about something that was already
  established earlier in the conversation?

```
Information Quality
Core task understanding:  ✅ Clear / ⚠️ Fading / ❌ Lost
Response precision:       ✅ Sharp / ⚠️ Softening / ❌ Generic
Consistency:              ✅ Consistent / ⚠️ Minor conflicts / ❌ Contradicting
```

## Dimension 3: Hallucination risk

Assess the risk that the AI is generating incorrect information:

- **Fabricated identifiers**: Check if recently mentioned function names,
  variable names, file paths, or API endpoints actually exist. Look at the
  conversation history — did the AI invent a name that was never in the
  codebase or earlier discussion?
- **Overturned decisions**: Has the AI reversed a previously confirmed
  technical decision without the user initiating that change?
- **Style drift**: Is the AI suggesting code patterns that don't match the
  project's established conventions (as documented in CLAUDE.md or visible
  in existing code)?

```
Hallucination Risk
Identifier accuracy:  ✅ Verified / ⚠️ Some unverified / ❌ Fabrications detected
Decision stability:   ✅ Stable / ⚠️ Wavering / ❌ Reversing
Style consistency:    ✅ Matches project / ⚠️ Drifting / ❌ Inconsistent
Overall risk:         🟢 Low / 🟡 Medium / 🔴 High
```

## Dimension 4: External memory state

Check the persisted context files:

- **File existence**: Do `.claude/context/` files exist?
- **Freshness**: When was `current-task.md` last updated? Compare the
  timestamp to the current conversation — is it stale?
- **Consistency**: Does the content of the persisted files match what the
  conversation says? If the file says "implementing auth" but the
  conversation has moved on to "fixing database queries," the external
  memory is out of sync.

```
External Memory
.claude/context/current-task.md:  ✅ Exists / ⚠️ Stale (last updated: date) / ❌ Missing
.claude/context/decisions.md:     ✅ Exists / ❌ Missing
.claude/context/pitfalls.md:      ✅ Exists / ❌ Missing
Sync status:  ✅ In sync / ⚠️ Stale / ❌ Out of sync
```

## Output: Combined health report

```
📊 Context Health Report
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🪙 Token Status
[████████░░] ~75% consumed | ~50K remaining | ~10-15 more rounds
Status: 🟡 Warning

🧠 Information Quality
• Task clarity:     ✅ Clear
• Response quality: ⚠️ Softening
• Consistency:      ✅ Consistent

🎯 Hallucination Risk
• Identifiers:  ✅ Verified
• Decisions:    ✅ Stable
• Style match:  ✅ Consistent
Overall: 🟢 Low

💾 External Memory
• current-task.md: ⚠️ Stale (last updated 3 hours ago)
• decisions.md:    ✅ In sync
• pitfalls.md:     ✅ In sync

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

💡 Recommendations
[Based on the findings, give 1-3 specific, actionable recommendations]

• If token pressure is high: Run /session-save now as a checkpoint,
  then consider /session-end.
• If external memory is stale: Run /session-save to sync.
• If hallucination risk is elevated: This is a strong signal to end the
  session and start fresh with /session-load.
• If all clear: Keep working — context is healthy.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Decision matrix

| Token | Info Quality | Hallucination | Memory | Action |
|-------|-------------|---------------|--------|--------|
| 🟢 | ✅ | 🟢 | ✅ | Keep working |
| 🟡 | ✅ | 🟢 | ✅ | Consider saving soon |
| 🟡 | ⚠️ | 🟡 | ⚠️ | Save now, end session soon |
| 🔴 | ⚠️ | 🟡 | ⚠️ | Save immediately, end session |
| 🔴 | ❌ | 🔴 | ❌ | End session NOW, fresh start needed |
| Any | Any | 🔴 | Any | Strongly recommend fresh session |

After presenting the report, ask the user what they'd like to do — the
decision is theirs, but your recommendation should be clear and honest.

