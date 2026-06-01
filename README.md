# SKIIS — Claude Code 会话上下文管理技能

让 Claude Code 拥有持久化记忆，跨会话无缝衔接工作进度。

## 这是什么？

SKIIS 是一套 Claude Code 自定义技能，解决 AI 辅助编程中最头疼的问题——**会话长了会变笨、换新会话丢失上下文**。它提供完整的上下文生命周期管理：加载 → 工作 → 保存 → 健康检查 → 结束。

## 六个命令一览

| 命令 | 用途 | 使用时机 |
|------|------|----------|
| `/project:session-load` | 恢复项目上下文 | 每次新对话开头 |
| `/project:session-save` | 保存当前进度 | 完成阶段性工作时 |
| `/project:session-end` | 完整收尾流程 | 下班/切换任务前 |
| `/project:context-check` | 健康诊断 | AI 开始变笨、重复、出错时 |
| `/project:context-sync` | 同步架构文档 | 依赖变更、目录结构调整后 |
| `/project:init-project` | 初始化新项目 | 从零开始搭建项目时 |

## 安装方式

### 方式一：克隆仓库（推荐）

```bash
# 1. 克隆到本地
git clone https://github.com/zq88297/SKIIS.git

# 2. 复制到你项目的 .claude 目录
cp -r SKIIS/.claude/* 你的项目/.claude/

# 3. 在 Claude Code 中打开你的项目，输入 /project:session-load 即可开始
```

### 方式二：安装 .skill 包

```bash
# 下载 .skill 文件后
claude skills install session-context.skill

# 然后手动复制命令文件
cp SKIIS/.claude/commands/context-sync.md 你的项目/.claude/commands/
```

### 方式三：手动复制命令文件

只需要核心功能的话，直接把 `.claude/commands/` 下的 `.md` 文件复制到你项目的对应目录即可。

## 上下文文件系统

安装后会在你项目的 `docs/ai-context/` 下自动创建：

```
docs/ai-context/
├── current-task.md      # 任务进度（checkbox 跟踪）
├── decisions.md         # 技术决策日志（追加不覆盖）
├── pitfalls.md          # 踩坑记录（追加不覆盖）
└── architecture.md      # 项目架构（自动生成）
```

## 完整工作流

```
新项目                     已有项目
  │                          │
  ▼                          ▼
context-sync              session-load    ← 恢复上下文
  │                          │
  └──────────┬───────────────┘
             ▼
          开始工作
             │
      ┌──────┼──────┐
      ▼      │      ▼
context-sync  │  session-save    ← 保存进度
(结构变化时)  │      │
             │      ▼
             │  context-check    ← 感觉变慢时诊断
             │      │
             ▼      ▼
         session-end             ← 完整收尾
             │
             ▼
         下次 session-load       ← 循环
```

## 配合 CLAUDE.md

在项目的 `CLAUDE.md` 中加一段，让 AI 主动提醒你：

```markdown
## 上下文管理规范

1. 每次新对话开始时运行 /project:session-load
2. 对话超过 20 轮时提醒保存上下文
3. 发现上下文不一致时建议 /project:context-check
4. 重要决策做出后询问是否记录到 decisions.md
5. 依赖或目录变化时提醒 /project:context-sync
```

## 系统要求

- Claude Code（最新版）
- Git（可选，用于版本控制上下文文件）

## 许可

MIT License — 随便用，随便改，随便分享。
