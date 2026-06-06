# CLAUDE.md

## 项目概述

- **项目名称**：SKIIS — Claude Code Session Context Manager
- **项目类型**：Claude Code 技能 / 工具
- **技术栈**：Markdown + Bash（纯配置文件）
- **包管理器**：无
- **构建工具**：无

## 代码结构

```text
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

## ⚠️ 强制自动规则（必须执行，无需用户触发）

以下是**必须自动执行**的规则，AI 不应等待用户手动调用 `/session-save`：

### 规则 0：加载上下文后立即写入任务

- **触发时机**：每次对话加载上下文后
- **执行动作**：将用户的请求写入 `current-task.md` 的 `## 进行中` 部分
- **格式**：

  ```markdown
  ## 已完成
  暂无

  ## 进行中
  - [ ] {用户请求的具体任务描述}

  ## 待完成
  暂无

  ## 关键上下文
  - {与任务相关的模块、文件、约束}
  ```

### 规则 4.5：修改计划自动同步

- **触发时机**：AI 生成修改计划（Plan Mode、重构方案、实施步骤）后
- **执行动作**：将计划步骤转换为 `current-task.md` 的 checkbox 列表
- **完成后通知用户**："已将修改计划同步到 `current-task.md`"

### 规则 4.51：新任务自动捕获

- **触发时机**：当前任务完成后，用户提出新任务
- **执行动作**：
  1. 将已完成任务归档（提取决策到 decisions.md，提取踩坑到 pitfalls.md）
  2. 清空 `current-task.md` 的任务部分
  3. 写入新任务到 `current-task.md`
- **完成后通知用户**："已归档上个任务，新任务已记录到 current-task.md"

### 规则 4.52：Bug 修复后自动添加单元测试

- **触发时机**：AI 完成 bug 修复的代码修改后
- **前提条件**：项目存在测试框架（jest/vitest/pytest 等）
- **执行动作**：
  1. 分析 bug 修复内容（根因、修复方案）
  2. 生成对应的单元测试用例
  3. 写入测试文件（命名：`{源文件名}.test.{扩展名}`）
  4. 运行测试验证修复
- **完成后通知用户**："已创建单元测试并验证通过"

---

## 上下文管理规范

1. 每次新对话开始时，自动加载上下文（见规则 0）
2. 对话超过 15 轮时，主动提醒保存（见规则 3）
3. 项目结构或依赖变化时，提醒同步（见规则 2）
4. 重要决策做出后，提醒记录（见规则 4）
5. **不要等待用户调用 `/session-save`，任务信息应自动同步到文档**

---

## 技能命令速查

| 命令 | 功能 |
| ------ | ------ |
| `/session-load` | 加载已保存的上下文 |
| `/session-save` | 保存当前进度 |
| `/session-end` | 结束会话（健康检查 + 保存） |
| `/context-check` | 上下文健康度诊断 |
| `/context-sync` | 同步项目架构文档 |
