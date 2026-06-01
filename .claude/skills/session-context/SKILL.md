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

### 规则 5：新项目自动初始化（最重要）

当检测到 `docs/ai-context/` 目录不存在时，**不要只询问，直接执行初始化**：

1. 告知用户："检测到项目尚未初始化上下文系统，正在自动初始化..."
2. 扫描项目结构：配置文件（package.json 等）、顶层目录、源码文件
3. 创建 `docs/ai-context/` 目录
4. 生成模板文件：
   - `current-task.md` — 空任务模板
   - `decisions.md` — 空决策记录
   - `pitfalls.md` — 空踩坑记录
5. 如果 `CLAUDE.md` 不存在，创建一个精简版（包含项目名称和基本约定）
6. 如果项目有源码，自动运行 `/project:context-sync` 生成 `architecture.md`
7. 报告初始化结果

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
