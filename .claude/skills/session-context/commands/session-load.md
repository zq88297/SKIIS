# Session Context Load

You are the context recovery agent. Your job is to rapidly restore project
awareness at the start of a new session by reading persisted context files
and presenting a structured summary to the user.

## Step 1: Discover context files

Check for the existence of each of these files and note their status:

| File | Location |
|------|----------|
| Project fundamentals | `CLAUDE.md` |
| Current task | `.claude/context/current-task.md` |
| Technical decisions | `.claude/context/decisions.md` |
| Pitfalls | `.claude/context/pitfalls.md` |
| Architecture | `.claude/context/architecture.md` |
| Cross-project tasks | `.claude/context/tasks/*.md` |

## Step 2: Load in priority order

Read the files that exist, in this order (most critical first):

1. **tasks/*.md** — Cross-project tasks from other projects (check FIRST — these explain WHY we're here)
2. **CLAUDE.md** — Project identity, conventions, build commands
3. **current-task.md** — Where we left off
4. **decisions.md** — What was decided and why
5. **pitfalls.md** — What went wrong and how to avoid it
6. **architecture.md** — System structure

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

🔜 **下次继续（最重要）**
[From current-task.md's "下次继续" section — display FIRST]
  • 第一步：打开 xxx 文件，定位到 yyy 函数，做 zzz
  • 当前状态：{编译/运行状态}

📂 **关键文件清单**
[From current-task.md's "关键文件清单" section — LOAD FIRST]
  • 直接打开清单中列出的文件（已指定行号范围）
  • 跳过"已排除"的文件 — 不需要重新探索
  • 读"当前排查结论" — 秒懂问题状态
  • 阻塞项：{如有}

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

## Step 4: Initialize if nothing exists（自动执行，不询问）

If none of the context files exist, **do NOT ask — directly execute**:

1. Tell the user: "检测到项目尚未初始化上下文系统，正在自动初始化..."
2. Scan project structure: config files, top-level directories, source files
3. Create `.claude/context/` directory
4. Generate template files:
   - `current-task.md` — empty task template with current date
   - `decisions.md` — empty decisions log
   - `pitfalls.md` — empty pitfalls log
5. If `CLAUDE.md` doesn't exist, create a minimal one with project name and basic conventions
6. **Auto-install hooks**: if `.claude/hooks.json` doesn't exist, create it along with `.claude/hooks/check-context.sh` and `.claude/hooks/on-file-change.sh`. Use the exact content from SKILL.md's "Hooks 配置" section.
7. If project has source code, auto-run `/context-sync` to generate `architecture.md`
8. Report what was created
9. Ask: "准备就绪，请告诉我需要做什么？"

