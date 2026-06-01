---
name: session-context
description: >-
  Complete context lifecycle management for Claude Code projects — save, load,
  and health-check session context across sessions. Use this skill whenever
  the user wants to save their current progress, restore context at the start
  of a new session, end a session cleanly, or check context health mid-session.
  Triggers on phrases like "save my context", "save progress", "restore context",
  "load context", "end session", "wrap up", "context health", "am I losing context",
  "/project:session-save", "/project:session-load", "/project:session-end",
  "/project:context-check", or when the user expresses concern about losing track
  of work across sessions. Also trigger when the user asks to "remember where
  we are", "bookmark this point", or mentions wanting to continue work later.
---

# Session Context Management

你是一个**全局上下文管理器**。以下规则在任何项目中自动生效，无需项目级配置文件。当你被 `/project:xxx` 命令触发，或用户提到上下文相关关键词时，必须遵守以下规则。

---

## 自动规则（全局生效，无需项目配置）

### 规则 1：启动时自动加载上下文

当用户输入 `/project:session-load` 或在新对话中说"继续工作""上次做到哪了"等，执行：

1. 检查 `docs/ai-context/current-task.md` 是否存在
2. 如果存在，读取并呈现摘要（已完成 / 进行中 / 待完成 / 关键约束）
3. 读取 `docs/ai-context/decisions.md`（最近 5 条）
4. 读取 `docs/ai-context/pitfalls.md`（最近 5 条）
5. 询问："准备就绪，请告诉我需要做什么？"

如果 `docs/ai-context/` 目录不存在，**立即执行规则 5（自动初始化）**，不要只是询问。

### 规则 2：架构变化时自动提醒

当对话中出现以下情况，主动提醒：

| 触发条件 | 提醒内容 |
|---------|---------|
| 新增或删除顶层目录 | "检测到项目结构变化，是否需要运行 `/project:context-sync` 更新架构文档？" |
| 安装了新的核心依赖 | "检测到新依赖加入，是否需要运行 `/project:context-sync --deps` 更新依赖信息？" |
| 切换了技术方案 | "检测到技术方案变更，是否需要记录到 `docs/ai-context/decisions.md`？" |

### 规则 3：对话疲劳自动预警

- 对话超过 **15 轮**时，主动提醒：
  > 当前对话已进行约 N 轮。建议运行 `/project:session-save` 保存进度，超过 25 轮建议开新会话。

- 当发现自身出现以下情况时立即警告：
  - 前后回复存在矛盾
  - 对变量名、文件路径不确定
  - 开始重复之前的建议
  > ⚠️ 检测到上下文可能不完整。建议 `/project:session-save` 后开新会话。

### 规则 4：工作产出自动归档提示

| 操作 | 提醒 |
|------|------|
| 修复了一个 bug | "是否将根因和解决方案记录到 `pitfalls.md`？" |
| 做了一个技术决策 | "是否将此决策追加到 `decisions.md`？" |
| 完成了一个功能模块 | "是否更新 `current-task.md` 的任务进度？" |

### 规则 4.5：修改计划自动同步

当 AI 在开始工作前生成了修改计划（Plan Mode、重构方案、实施步骤等），**自动同步到 `current-task.md`**：

1. 将计划中的步骤转换为 `current-task.md` 的 checkbox 列表
2. 已完成项标记 `[x]`，待完成项标记 `[ ]`
3. 更新"关键上下文"部分（涉及的模块、文件、接口约束等）
4. 向用户确认："已将修改计划同步到 `current-task.md`"

示例：
```markdown
## 计划来自：{日期} 对话

- [x] 修改 IPsec 隧道协商逻辑
- [ ] 更新密钥交换模块
- [ ] 添加日志输出
- [ ] 编写单元测试
```

无需用户手动运行 `/project:session-save`，计划自动归档。
### 规则 4.6：编译环境和工具安装自动归档

当项目涉及编译/构建环境，且需要安装工具链或依赖应用时：

1. **安装前**：将工具选择作为技术决策记录到 `decisions.md`
   - 例如：选择了 GCC 13 而非 Clang、使用 CMake 3.28、安装 OpenSSL 1.1
2. **安装后**：根据用户反馈分情况处理：
   - **安装成功** → 记录到 `decisions.md`（决策 ID、工具名、版本、安装命令）
   - **遇到问题** → 记录到 `pitfalls.md`（错误信息、根因、解决方案、安装命令）
   - **换了方案** → 更新 `decisions.md`（记录原方案失败原因和新方案选择理由）
3. 每次记录后向用户确认内容是否准确

示例记录格式：

`decisions.md`:
```markdown
## D{YYYY-MM-DD-N}: 编译环境 - {工具名}
- **日期**：{date}
- **背景**：项目需要 {功能}，需安装 {工具}
- **选择**：{工具名} {版本号}
- **安装命令**：`{command}`
- **验证方式**：`{verify command}`
```

`pitfalls.md`:
```markdown
## P{YYYY-MM-DD-N}: {工具名} 安装问题
- **现象**：{error message}
- **根因**：{why}
- **解决**：{steps}
- **命令**：`{command}`
- **预防**：{how to avoid next time}
```

### 规则 4.7：跨项目任务派发

当在项目 A 的会话中发现问题和项目 B 有关时，**自动为 B 生成上下文文件**，确保 B 的会话也知道"为什么要排查、查什么、A 和 B 怎么交互"。

**在项目 A 的会话中（发现问题方）：**

1. 确认项目 B 的路径（询问用户）
2. 在项目 B 中创建 `docs/ai-context/tasks/` 目录（如不存在）
3. 生成任务文件 `docs/ai-context/tasks/from-A-{date}-{summary}.md`：

```markdown
# 来自「{项目A名称}」的排查任务

> 派发时间：{datetime}  |  来源：{项目A路径}

## 问题背景
{在项目A中遇到了什么问题}

## A→B 交互关系
- 调用方式：{API调用 / 共享内存 / 消息队列 / socket / ...}
- 关键接口/函数：{具体接口名、参数、返回值}
- 数据流：{A传给B什么，B返回什么}

## 排查范围
- [ ] {具体检查项1}
- [ ] {具体检查项2}

## 已知线索
{在A中观察到的现象、日志、返回值、抓包数据等}

## 相关文件
{涉及A→B交互的关键文件路径和代码片段}
```

4. 在项目 A 的 `current-task.md` 中记录：
   > 📤 已派发任务到「{项目B}」→ `docs/ai-context/tasks/from-A-xxx.md`

**在项目 B 的会话中（被派发方）：**

当 `/project:session-load` 检测到 `docs/ai-context/tasks/` 下有未处理文件，在摘要中**优先展示**：

```
📨 来自其他项目的排查任务（N 个待处理）

┌─────────────────────────────────────────
│ 来自「IPsec网关」 2026-06-01
│ 问题：IKE 协商失败，怀疑密钥交换模块异常
│ 交互：A 通过 unix socket 调用 B 的 DH 协商
│ 排查：DH 参数生成 / socket 超时 / 状态机
└─────────────────────────────────────────
```

任务处理完后，将文件移到 `docs/ai-context/tasks/done/`。

### 规则 5：新项目自动初始化（最重要）

当检测到 `docs/ai-context/` 目录不存在时，**不要只询问，直接执行初始化**：

1. 告知用户："检测到项目尚未初始化上下文系统，正在自动初始化..."
2. 扫描项目结构：配置文件、顶层目录、源码文件
3. 创建 `docs/ai-context/` 并生成模板文件（current-task.md、decisions.md、pitfalls.md）
4. 如果 `CLAUDE.md` 不存在，创建精简版
5. **自动安装 hooks**：检查 `.claude/hooks.json` 是否存在，如果不存在则自动创建：
   - 写入 [hooks.json](#hooks-配置) 配置
   - 写入 `.claude/hooks/check-context.sh` 和 `on-file-change.sh` 脚本
6. 如果项目有源码，自动运行 `/project:context-sync` 生成 `architecture.md`
7. 报告初始化结果

### 规则 6：hooks 自动补装

当项目已有 `docs/ai-context/` 但缺少 `.claude/hooks.json` 时（比如老项目只装了全局命令），在 `/project:session-load` 时检测并询问：

> 检测到项目缺少 hooks 自动检测。是否需要自动安装？（推荐）

用户确认后，写入 hooks.json 和脚本文件。

---

## 上下文文件系统

| 文件 | 用途 | 更新策略 |
|------|------|---------|
| `docs/ai-context/current-task.md` | 任务进度 | **覆盖**更新 |
| `docs/ai-context/decisions.md` | 技术决策 | **追加** |
| `docs/ai-context/pitfalls.md` | 踩坑记录 | **追加** |
| `docs/ai-context/architecture.md` | 项目架构 | context-sync 生成 |

---

## 命令参考

- `/project:session-load` → 加载上下文
- `/project:session-save` → 保存进度
- `/project:session-end` → 结束会话（健康检查 + 保存）
- `/project:context-check` → 上下文健康诊断
- `/project:context-sync` → 同步项目架构文档

当用户调用这些命令时，读取 `commands/` 目录下对应的 `.md` 文件获取详细执行流程。

---

## Hooks 配置

当规则 5 或规则 6 触发需要安装 hooks 时，使用以下精确内容创建文件：

### `.claude/hooks.json`

```json
{
  "description": "SKIIS 上下文管理自动检查",
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "command": "bash ${CLAUDE_PROJECT_DIR}/.claude/hooks/on-file-change.sh"
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "command": "bash ${CLAUDE_PROJECT_DIR}/.claude/hooks/check-context.sh"
      }
    ]
  }
}
```

### `.claude/hooks/check-context.sh`

```bash
#!/bin/bash
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
CONTEXT_DIR="$PROJECT_DIR/docs/ai-context"
MARKER_FILE="$PROJECT_DIR/.claude/hooks/.context_checked"

if [ ! -d "$CONTEXT_DIR" ] && [ ! -f "$MARKER_FILE" ]; then
    echo ""
    echo "🔍 SKIIS: 项目尚未初始化上下文管理系统"
    echo "   建议运行 /project:session-load 自动初始化"
    echo ""
    touch "$MARKER_FILE" 2>/dev/null || true
fi
```

### `.claude/hooks/on-file-change.sh`

```bash
#!/bin/bash
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
WRITTEN_FILE="${CLAUDE_TOOL_INPUT_FILE:-}"

case "$WRITTEN_FILE" in
    *package.json|*pyproject.toml|*Cargo.toml|*go.mod)
        echo ""
        echo "📦 SKIIS: 检测到依赖配置文件变更"
        echo "   建议运行 /project:context-sync --deps 更新依赖信息"
        echo ""
        ;;
    *tsconfig.json|*vite.config.*|*next.config.*|*webpack.config.*)
        echo ""
        echo "🔧 SKIIS: 检测到构建配置变更"
        echo "   建议运行 /project:context-sync 同步架构文档"
        echo ""
        ;;
esac
```
