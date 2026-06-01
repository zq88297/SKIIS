---
name: task-orchestrator
description: >-
  Intelligent task scheduler that reads SKIIS context files and orchestrates
  parallel vs sequential task execution. Use when the user wants to "speed up
  tasks", "run tasks in parallel", "plan execution order", "orchestrate work",
  or asks "which tasks can run at the same time". Also triggers on /task:plan
  and /task:run. Requires session-context skill to be installed.
---

# Task Orchestrator

你是任务调度器。读取 SKIIS（session-context）产生的上下文文件，分析任务依赖关系，规划并行/串行执行顺序，并协调多会话并行执行。

**依赖：** 必须安装了 session-context 技能。本技能读取 `docs/ai-context/` 下的文件。

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

对于标记为 🟢 可并行的任务，有两种执行方式：

1. **新终端窗口**：`claude -p "任务描述"` 在新终端中运行
2. **后台任务文件**：将任务写入独立 prompt 文件，用户手动在新会话中执行

### 任务认领锁（冲突解决）

**问题：** 会话 A 执行 Task-X 完成后又接了 Task-Y，但 Task-Y 已在会话 B 中执行。两个会话同时改同一文件 → 冲突。

**解决：** 基于文件系统的任务认领锁。`docs/ai-context/tasks/claims/` 目录。

**执行任何任务前（所有会话都必须遵守）：**

```
开始 Task-X 前
  │
  ├─ 检查 docs/ai-context/tasks/claims/task-X.claim 是否存在？
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

1. 将 claim 文件移到 `docs/ai-context/tasks/claims/done/`
2. 在 claim 文件末尾追加完成状态和耗时
3. 如果修改了涉及文件列表之外的文件，更新 current-task.md

**`/task:plan` 的额外职责：** 生成执行计划时检查 claims/，将已被认领的任务标记为 `🔒 已认领`。

**`/task:run` 的额外职责：** 启动任务前先认领，认领失败则跳过。

**所有会话的通用规则：** 开始任何新任务前，先检查 `docs/ai-context/tasks/claims/` 是否有冲突。这是 session-context 规则的一部分（通过 `session-load` 自动检查）。

---

## 命令

- `/task:plan` → 分析所有任务，输出执行计划（依赖图 + 并行组）
- `/task:run` → 执行计划，为并行任务启动独立会话

当用户调用这些命令时，读取 `commands/` 目录下对应的 `.md` 文件。
