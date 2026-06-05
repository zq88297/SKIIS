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
│   └── context-sync.md          # /context-sync  同步架构文档
└── skills/
    └── session-context/
        ├── SKILL.md              # 技能主文件
        └── commands/
            ├── session-load.md   # /session-load   加载上下文
            ├── session-save.md   # /session-save   保存上下文
            ├── session-end.md    # /session-end    结束会话
            └── context-check.md  # /context-check  健康检查
```

## 关键约定

- 上下文文件存储在 `.claude/context/`（新）或 `.claude/context/`（旧，向后兼容）
- `current-task.md` 覆盖更新，`decisions.md` 和 `pitfalls.md` 追加更新
- 命令文件使用中文编写
- 尽量让 AI 自驱动，减少用户手动操作

---

## 自动上下文管理规则

所有规则已内置在全局 skill 的 [SKILL.md](.claude/skills/session-context/SKILL.md) 中。
全局安装后自动生效，无需在此文件重复配置。

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
| `/session-load` | 加载已保存的上下文 |
| `/session-save` | 保存当前进度 |
| `/session-end` | 结束会话（健康检查 + 保存） |
| `/context-check` | 上下文健康度诊断 |
| `/context-sync` | 同步项目架构文档 |

