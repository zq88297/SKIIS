# 任务并行执行

你是任务执行器。根据 `/task:plan` 生成的计划，为可并行任务启动独立的 Claude Code 会话。

## Step 1：确认计划

如果还没运行 `/task:plan`，先运行它生成执行计划。

向用户确认：
1. 当前会话继续执行哪个任务？
2. 哪些任务需要启动并行会话？

## Step 2：认领任务（防冲突）

对每个要执行的任务，**先检查认领锁**：

1. 检查 `.claude/context/tasks/claims/{task-id}.claim` 是否存在
2. 不存在 → 创建 claim 文件：
   ```
   任务: {标题}
   会话: {当前会话标识}
   开始: {datetime}
   文件: {涉及的文件列表}
   ```
3. 已被认领（< 24h）→ 跳过，提示用户
4. 僵尸锁（> 24h）→ 询问用户是否接管

## Step 3：生成任务 Prompt

为每个要并行执行的任务，生成一个**自包含的任务描述文件**。

保存到 `.claude/context/tasks/async/` 目录（不和其他任务混淆）：

```markdown
# 异步任务：{任务标题}

> 派发时间：{datetime}
> 来源会话：{当前项目路径}
> 预计耗时：{估算}

## 任务描述
{具体的任务内容}

## 涉及文件
{文件列表和路径}

## 前置条件
{开始前需满足的条件——全部已满足或已完成}

## 完成标准
- [ ] {验收条件1}
- [ ] {验收条件2}

## 完成后
1. 将本文件移到 `../async-done/`
2. 在来源项目的 `.claude/context/current-task.md` 中更新状态
```

## Step 4：按并发限制启动会话

**最多同时 3 个并行会话。** 按执行计划的分组顺序启动：

1. 计数当前活跃的 claim 文件（`.claude/context/tasks/claims/*.claim`，排除 `done/`）
2. 活跃数 < 3 → 启动下一组中依赖已满足的任务
3. 活跃数 = 3 → 剩余任务排队，写入 `.claude/context/tasks/queue/`

启动命令（后台自动执行）：
```bash
# 注意：prompt 中需包含"完成后自动接续"的指令
claude -p "你的任务是执行 .claude/context/tasks/async/{task-file}.md。
完成后：
1. 将结果写入任务文件末尾
2. 将任务文件移到 async-done/
3. 将 claim 移到 claims/done/
4. 检查 .claude/context/tasks/queue/ 是否有排队任务
5. 如果有且依赖已满足，自动开始执行
6. 如果有但依赖未满足，告知用户等待哪个任务"
```

## Step 5：排队和接续

剩余任务写入 `.claude/context/tasks/queue/`：

```markdown
# 排队任务：{任务标题}
- 排队时间：{datetime}
- 依赖任务：{Task-X, Task-Y}
- 状态：等待 {Task-X} 完成
```

每个会话完成当前任务后，**自动检查队列**：

```
当前任务完成
  │
  ├─ 检查队列中第一个任务
  │     ├─ 依赖全部满足 → 认领 + 启动
  │     └─ 依赖未满足 → 跳过，检查下一个
  │
  └─ 告知用户：
        "✅ Task-A 已完成。下一个可执行任务：Task-D。
         ⏳ Task-E 仍需等待 Task-B（预计在会话2 中）。"
```

## Step 6：平台启动命令

如果平台不支持后台自动执行，使用新终端窗口：

```bash
# Windows
start "Task" cmd /k "cd /d {dir} && claude"

# macOS  
osascript -e 'tell app "Terminal" to do script "cd {dir} && claude"'

# Linux
gnome-terminal -- bash -c "cd {dir} && claude; exec bash"
```

## Step 4：跟踪状态

在当前会话的 `current-task.md` 中记录并行任务状态：

```markdown
## 异步任务跟踪

| 任务 | 状态 | 启动时间 | 会话 |
|------|------|---------|------|
| Task-2: 更新密钥文档 | 🔄 执行中 | 14:30 | 终端窗口 2 |
| Task-4: 日志模块 | ⏳ 等待启动 | - | - |
| 跨模块: IPsec排查 | 🔄 执行中 | 14:31 | 新窗口 ike-key-exchange |
```

## Step 5：汇合

当异步任务完成后（用户告知或检查 `async-done/` 目录）：

1. 从 `async-done/` 读取完成结果
2. 更新 `current-task.md` 的 Completed 和 Pending
3. 如果当前任务也完成了，检查是否可以启动下一组任务

