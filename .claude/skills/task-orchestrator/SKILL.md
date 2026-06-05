---
name: task-orchestrator
description: "Auto-analyze multi-step plans for parallel execution. Trigger when AI generates 2+ step plans, or on /task:plan, /task:run, parallel, 并行, 同时执行, 多任务, 批量, 一起做, 一起改, 分步."
---

# Task Orchestrator

你是任务调度器。读取 SKIIS（session-context）产生的上下文文件，分析任务依赖关系，规划并行/串行执行顺序，并协调多会话并行执行。

**依赖：** 必须安装了 session-context 技能。本技能读取 `.claude/context/` 下的文件。

---

## 规则 0：生成执行计划后自动分析（最高优先级）

**每次 AI 生成了包含 2 个以上步骤的执行计划（Plan Mode、修改方案、重构步骤等），必须在给出计划后自动执行：**

1. 分析计划中每个步骤的依赖关系（是否修改相同文件/函数、是否有输出依赖）
2. 识别可并行的步骤组
3. 在计划末尾追加并行分析结果：

```
⚡ 并行分析

  第 1 组（可立即并行 - N 个任务）
    🟢 {任务1} — 独立模块/文件
    🟢 {任务2} — 只读操作

  第 2 组（等第 1 组完成后）
    🔴 {任务3} — 依赖 {任务1} 的输出

  💡 建议：启动 2 个并行会话，预计效率提升 2x
  💡 需要我帮你启动并行会话吗？（/task:run）
```

**不需要用户手动输入 `/task:plan`。** 计划生成后自动分析。

---

## 核心概念

### 任务来源

| 来源 | 位置 | 含义 |
|------|------|------|
| 本地任务 | `current-task.md` 的 Pending 列表 | 当前项目自己的待办 |
| 本地进行中 | `current-task.md` 的 In Progress | 当前正在做的 |
| 跨模块任务 | `tasks/*.md`（非 done/） | 其他项目派来的排查任务 |

### 依赖判断规则

一个任务是否依赖另一个任务完成，按以下规则判断：

| 规则 | 判断方法 | 结论 |
|------|---------|------|
| 同文件冲突 | 两个任务涉及修改相同的文件 | 🔴 串行，必须按序执行 |
| 同函数冲突 | 两个任务涉及修改同一个函数/模块 | 🔴 串行 |
| 输出依赖 | 任务 B 明确需要任务 A 的输出结果 | 🔴 串行，A 先 B 后 |
| 不同模块 | 任务 A 改 `src/ike/`，任务 B 改 `src/log/` | 🟢 可并行 |
| 不同项目 | 任务在 A 项目，任务在 B 项目 | 🟢 可并行 |
| 纯只读 | 任务只读文件，不修改 | 🟢 可并行 |
| 无明确冲突 | 任务之间没有共同文件/函数 | 🟢 可并行 |

### 并行执行方式

对于标记为 🟢 可并行的任务，有三种执行方式：

**方式一：后台自动执行（推荐，无需用户操作）**

使用 `Bash` 工具的 `run_in_background` 模式，直接启动新的 Claude Code 会话：

```bash
# 在当前项目目录执行异步任务
claude -p "读取 .claude/context/tasks/async/task-xxx.md，执行其中描述的任务，完成后将结果写入 .claude/context/tasks/async-done/"

# 在其他项目目录执行（跨项目任务）
claude --project-dir /path/to/other-project -p "读取 .claude/context/tasks/from-xxx.md，执行排查任务"
```

**方式二：新终端窗口（用户可见）**

```bash
# Windows
start "Task-xxx" cmd /k "cd /d %PROJECT_DIR% && claude"

# macOS
osascript -e 'tell app "Terminal" to do script "cd '$PROJECT_DIR' && claude"'

# Linux (GNOME)
gnome-terminal -- bash -c "cd '$PROJECT_DIR' && claude; exec bash"
```

**方式三：任务文件（手动）**

将任务写入 `.claude/context/tasks/async/`，用户手动在新会话中执行 `/task:run`。适用于需要人工判断的复杂任务。

### 并发限制和自动接续

**同时最多 3 个并行会话。** 超过的任务排队等待。

```
任务队列（按优先级排序）
  Task-A ──→ 会话1 执行中 🔄
  Task-B ──→ 会话2 执行中 🔄
  Task-C ──→ 会话3 执行中 🔄  ← 已达上限
  Task-D ──→ 排队等待 ⏳
  Task-E ──→ 排队等待 ⏳（依赖 Task-A 结果）
```

**自动接续逻辑：**

```
某个会话完成当前任务
  │
  ├─ 1. 将 claim 移到 claims/done/，追加完成状态
  ├─ 2. 同步文档：更新 current-task.md 的 Completed/Pending
  ├─ 3. 检查队列中下一个任务：
  │      ├─ 无依赖未满足 → 认领执行
  │      └─ 依赖 Task-X 结果 → 检查 Task-X 是否完成
  │            ├─ 已完成 → 读取结果，开始执行
  │            └─ 未完成 → 提示用户："等待 Task-X 完成（预计在会话 N 中）"
  └─ 4. 告知用户下一步状态
```

**等待通知格式：**
```
⏳ Task-E 需要等待 Task-A 的结果才能开始
   Task-A 正在会话1 中执行（已运行 15 分钟）
   预计 Task-A 完成后我会自动开始 Task-E
   你也可以手动去会话1 查看进度
```

### 任务认领锁（冲突解决）

**问题：** 会话 A 执行 Task-X 完成后又接了 Task-Y，但 Task-Y 已在会话 B 中执行。两个会话同时改同一文件 → 冲突。

**解决：** 基于文件系统的任务认领锁。`.claude/context/tasks/claims/` 目录。

**执行任何任务前（所有会话都必须遵守）：**

```
开始 Task-X 前
  │
  ├─ 检查 .claude/context/tasks/claims/task-X.claim 是否存在？
  │
  ├─ 不存在 → 创建 claim 文件，开始执行
  │     claim 内容：{任务ID, 会话标识, 开始时间, 涉及文件列表}
  │
  ├─ 存在 且 时间 < 24 小时 → 任务已被认领
  │     → 跳过这个任务，选下一个未认领的
  │     → 提示用户："Task-X 已被 {会话} 认领（{时间}），跳过"
  │
  └─ 存在 但 时间 > 24 小时 → 可能僵尸锁
        → 提示用户："Task-X 的认领已过期（>24h），是否强制接管？"
```

**任务完成时：**

1. 将 claim 文件移到 `.claude/context/tasks/claims/done/`
2. 在 claim 文件末尾追加完成状态和耗时
3. 如果修改了涉及文件列表之外的文件，更新 current-task.md

**`/task:plan` 的额外职责：** 生成执行计划时检查 claims/，将已被认领的任务标记为 `🔒 已认领`。

**`/task:run` 的额外职责：** 启动任务前先认领，认领失败则跳过。

**所有会话的通用规则：** 开始任何新任务前，先检查 `.claude/context/tasks/claims/` 是否有冲突。这是 session-context 规则的一部分（通过 `session-load` 自动检查）。

---

### 文件写入策略（避免并发冲突）

**核心原则：每个任务写自己的结果文件，不做锁竞争。最后一次性合并。**

```
并行执行中：
  Task-A 完成 → 写入 tasks/results/task-A.result.md  （无锁，独自文件）
  Task-B 完成 → 写入 tasks/results/task-B.result.md  （无锁，独自文件）
  Task-C 完成 → 写入 tasks/results/task-C.result.md  （无锁，独自文件）

全部完成后（或用户触发 /task:plan 时）：
  → 读取所有 tasks/results/*.result.md
  → 合并写入 current-task.md（一次写入，无竞争）
  → 追加到 decisions.md / pitfalls.md
```

**写结果文件（各任务独立，无需锁）：**

每个会话完成任务后，将结果写入 `.claude/context/tasks/results/{task-id}.result.md`：

```markdown
# 任务结果：{任务标题}
- 完成时间：{datetime}
- 执行会话：{会话标识}
- 修改的文件：{列表}
- 决策记录：{如有技术决策}
- 踩坑记录：{如有踩坑}
```

**合并阶段（当前主会话执行，一次性）：**

当 `/task:plan` 或 `/session-load` 检测到 `tasks/results/` 下有未合并的结果文件时：

1. 读取所有 `.result.md` 文件
2. 更新 `current-task.md`：已完成移至 Completed，新增 Pending
3. 追加到 `decisions.md`（如有新决策）
4. 追加到 `pitfalls.md`（如有新踩坑）
5. 将结果文件移到 `tasks/results/merged/`
6. 报告合并结果

**只读不写无冲突：** 所有会话可以同时读取 `current-task.md`、`architecture.md` 等文件，读操作不需要任何锁。

---

## 命令

- `/task:plan` → 分析所有任务，输出执行计划（依赖图 + 并行组）
- `/task:run` → 执行计划，为并行任务启动独立会话

当用户调用这些命令时，读取 `commands/` 目录下对应的 `.md` 文件。

