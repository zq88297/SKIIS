# 任务并行执行

你是任务执行器。根据 `/task:plan` 生成的计划，为可并行任务启动独立的 Claude Code 会话。

## Step 1：确认计划

如果还没运行 `/task:plan`，先运行它生成执行计划。

向用户确认：
1. 当前会话继续执行哪个任务？
2. 哪些任务需要启动并行会话？

## Step 2：认领任务（防冲突）

对每个要执行的任务，**先检查认领锁**：

1. 检查 `docs/ai-context/tasks/claims/{task-id}.claim` 是否存在
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

保存到 `docs/ai-context/tasks/async/` 目录（不和其他任务混淆）：

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
2. 在来源项目的 `docs/ai-context/current-task.md` 中更新状态
```

## Step 3：启动并行会话

对每个 async task，提供启动命令：

```bash
# 方式一：新终端窗口
claude -p "$(cat docs/ai-context/tasks/async/task-xxx.md)"

# 方式二：新 Claude Code 窗口打开项目
cd /path/to/project && claude
# 然后输入：读取 docs/ai-context/tasks/async/task-xxx.md 并执行
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
