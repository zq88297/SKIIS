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

### a) 排查过程（最重要）
如果本次会话涉及问题排查，详细记录排查路径：
- 初始现象：看到什么异常
- 排查步骤：先查了哪里 → 排除了什么 → 定位到哪个模块
- 关键发现：每个排查步骤的结论（"不是 A 的问题"也是重要结论）
- 最终根因：真正的 bug/问题是什么

### b) 解决方案
- 怎么修的（代码改动、配置调整、流程变更）
- 为什么这么修（是否有替代方案）
- 验证方式（怎么确认修好了）

### c) 新增依赖 ⚠️ 重要
**如果本次会话新增了依赖库、工具、SDK 等，必须记录：**
| 依赖名 | 版本 | 用途 | 安装方式 |
|--------|------|------|---------|
| libssl | 3.0 | TLS 支持 | apt install libssl-dev |
| ... | ... | ... | ... |

这一条对重建编译环境至关重要。没有它，换一台机器后编译必然失败。

### d) 部署方法（如涉及）
**如果本次会话涉及程序部署/更新，必须写明：**
- 目标设备/服务器（IP、系统架构）
- 部署方式（scp、rsync、烧写、包管理）
- 部署命令（完整的命令行）
- 重启服务/进程的命令
- 验证部署成功的检查方法

示例：
```bash
# 部署到 192.168.1.100
scp build/ike-gateway root@192.168.1.100:/usr/local/bin/
ssh root@192.168.1.100 "systemctl restart ike-gateway && systemctl status ike-gateway"
```

### e) 成果
- 修改了哪些文件（不列举具体文件——通常较多）
- Bug 修复（含根因）
- 新增功能

### f) 技术决策
- 选择了什么，为什么
- 明确拒绝了什么替代方案

### g) 下一步
- 第一个操作的具体步骤（文件 + 函数）
- 需要预先安装的依赖
- 待确认的事项（如有）

> `/session-end` 意味着任务已收尾，不应有"遗留问题"。如有未完成的工作，就是下一步的起点。

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

- **`.claude/context/current-task.md`** — **Overwrite** with updated task
  progress. Move completed items to the Completed section, keep in-progress
  items accurate, and update pending items. Include the next steps from the
  summary.

- **`.claude/context/decisions.md`** — **Append** any new decisions from this
  session. Each decision gets a dated entry following the same format as
  session-save.

- **`.claude/context/pitfalls.md`** — **Append** any new pitfalls encountered
  in this session.

## Step 5: Output the end-of-session checklist

```
✅ Session End Checklist

□ Task progress saved   → .claude/context/current-task.md
□ Decisions recorded     → .claude/context/decisions.md (+N new)
□ Pitfalls archived      → .claude/context/pitfalls.md (+N new)

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

