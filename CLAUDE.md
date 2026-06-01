# CLAUDE.md

## 项目概述

- **项目名称**：SKIIS — Claude Code Session Context Manager
- **项目类型**：Claude Code 技能 / 工具
- **技术栈**：Markdown + Bash（纯配置文件）
- **包管理器**：无
- **构建工具**：无

## 代码结构

```
.claude/
├── commands/
│   └── context-sync.md          # /project:context-sync  同步架构文档
└── skills/
    └── session-context/
        ├── SKILL.md              # 技能主文件
        └── commands/
            ├── session-load.md   # /project:session-load   加载上下文
            ├── session-save.md   # /project:session-save   保存上下文
            ├── session-end.md    # /project:session-end    结束会话
            └── context-check.md  # /project:context-check  健康检查
```

## 关键约定

- 所有上下文文件存储在 `docs/ai-context/` 下
- `current-task.md` 覆盖更新，`decisions.md` 和 `pitfalls.md` 追加更新
- 命令文件使用中文编写
- 尽量让 AI 自驱动，减少用户手动操作

---

## 自动上下文管理规则

以下规则在每次对话中自动生效，无需用户手动触发。你必须遵守：

### 规则 1：启动时自动加载上下文

每次新对话开始时，如果用户没有提供明确的任务指令，立即执行：

1. 检查 `docs/ai-context/current-task.md` 是否存在
2. 如果存在，读取并呈现上下文摘要：
   - 当前任务进度（已完成 / 进行中 / 待完成）
   - 最近 5 条技术决策
   - 最近 5 条踩坑记录
3. 向用户呈现摘要后，询问："准备就绪，请告诉我需要做什么？"

如果 `docs/ai-context/` 目录不存在，主动说：

> 检测到项目尚未初始化上下文管理系统。是否需要我帮你初始化？我将自动扫描项目结构并生成所有上下文文件。

### 规则 2：架构变化时自动提醒

当对话中出现以下情况时，主动提醒用户：

| 触发条件 | 提醒内容 |
|---------|---------|
| 新增或删除了顶层目录 | "检测到项目结构变化，建议运行 `/project:context-sync` 同步架构文档" |
| 安装了新的核心依赖 | "检测到新依赖加入，建议运行 `/project:context-sync --deps` 更新依赖信息" |
| 切换了技术方案（状态管理、样式框架等） | "检测到技术方案变更，建议将此决策记录到 `docs/ai-context/decisions.md`" |

### 规则 3：对话疲劳自动预警

- 当对话超过 **15 轮**时，主动提醒：
  > 当前对话已进行约 N 轮，建议运行 `/project:session-save` 保存进度。超过 25 轮后建议开新会话。

- 当发现自身回复存在以下情况时，主动警告：
  - 前后回复出现矛盾
  - 对变量名、文件路径不确定
  - 开始重复之前的建议

  > ⚠️ 检测到上下文可能不完整。建议保存当前进度后开新会话，以获得更好的响应质量。

### 规则 4：工作产出自动归档提示

当完成以下操作后，主动提醒：

| 操作 | 提醒内容 |
|------|---------|
| 修复了一个 bug | "是否将根因和解决方案记录到 `pitfalls.md`？" |
| 做了一个技术决策 | "是否将此决策追加到 `decisions.md`？" |
| 完成了一个功能模块 | "是否更新 `current-task.md` 的任务进度？" |

### 规则 5：新项目自动初始化

当检测到同时满足以下条件时：
- `docs/ai-context/` 目录不存在
- 项目包含源代码文件

自动执行：
1. 告知用户项目尚未建立上下文管理系统
2. 扫描项目结构（配置文件、目录、源码）
3. 生成 `CLAUDE.md`（如果还不存在）
4. 创建 `docs/ai-context/` 目录及所有模板文件
5. 运行 `/project:context-sync` 生成架构文档

---

## 上下文管理规范

1. 每次新对话开始时，自动加载上下文（见规则 1）
2. 对话超过 15 轮时，主动提醒保存（见规则 3）
3. 项目结构或依赖变化时，提醒同步（见规则 2）
4. 重要决策做出后，提醒记录（见规则 4）

---

## 技能命令速查

| 命令 | 功能 |
|------|------|
| `/project:session-load` | 加载已保存的上下文 |
| `/project:session-save` | 保存当前进度 |
| `/project:session-end` | 结束会话（健康检查 + 保存） |
| `/project:context-check` | 上下文健康度诊断 |
| `/project:context-sync` | 同步项目架构文档 |
