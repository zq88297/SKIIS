# SKIIS — Claude Code 会话上下文管理技能

让 Claude Code 拥有持久化记忆，跨会话无缝衔接工作进度。

## 这是什么？

SKIIS 是一套 Claude Code 自定义技能，解决 AI 辅助编程中最头疼的问题——**会话长了会变笨、换新会话丢失上下文**。它提供完整的上下文生命周期管理：加载 → 工作 → 保存 → 健康检查 → 结束。

## 安装

### 全局安装（推荐，一次安装所有项目可用）

**Windows：**
```powershell
irm https://raw.githubusercontent.com/zq88297/SKIIS/master/install.ps1 | iex -Args '-Global'
```

**macOS / Linux：**
```bash
curl -sLo /tmp/skiis-install.sh https://raw.githubusercontent.com/zq88297/SKIIS/master/install.sh && bash /tmp/skiis-install.sh --global && rm /tmp/skiis-install.sh
```

安装后任何项目都能直接使用 `/project:xxx` 命令。

### 项目安装（安装完整三件套：命令 + hooks + CLAUDE.md）

进入项目目录运行：

**Windows：**
```powershell
cd 你的项目
irm https://raw.githubusercontent.com/zq88297/SKIIS/master/install.ps1 | iex
```

**macOS / Linux：**
```bash
cd 你的项目
curl -sLo /tmp/skiis-install.sh https://raw.githubusercontent.com/zq88297/SKIIS/master/install.sh && bash /tmp/skiis-install.sh && rm /tmp/skiis-install.sh
```

### 克隆后运行

```bash
git clone https://github.com/zq88297/SKIIS.git
cd SKIIS

# 全局安装
./install.sh --global          # macOS/Linux
.\install.ps1 -Global           # Windows

# 项目安装
./install.sh ~/my-project      # macOS/Linux
.\install.ps1 C:\my-project    # Windows
```

### 两种安装的区别

| 功能 | 全局安装 | 项目安装 |
| ---- | -------- | -------- |
| `/project:xxx` 命令 | ✅ 所有项目可用 | ✅ 当前项目可用 |
| hooks 自动检查 | ❌ | ✅ |
| CLAUDE.md 自动规则 | ❌ | ✅ |
| docs/ai-context/ | ❌ | ✅ |
| 适用场景 | 所有项目都能用命令 | 需要完整自动化体验 |

### 重复安装安全吗？

**完全安全，可以反复运行。** 脚本使用智能合并策略：

| 文件 | 策略 | 说明 |
| ---- | ---- | ---- |
| `.claude/commands/*.md` | 覆盖 | 命令文件本身，始终更新到最新版 |
| `.claude/skills/session-context/` | 覆盖 | 技能文件本身，始终更新到最新版 |
| `.claude/hooks.json` | **智能合并** | 已有则追加 SKIIS hooks，已有 SKIIS 则跳过 |
| `.claude/hooks/*.sh` | 覆盖 | 始终更新到最新版 |
| `CLAUDE.md` | **智能追加** | 已有则追加规则段落，已有 SKIIS 段落则跳过 |
| `docs/ai-context/` | **仅创建** | 已存在则完全保留，绝不覆盖用户数据 |

再装一次不会产生重复配置，也不会覆盖你已有的 hooks 和 CLAUDE.md 内容。

## 六个命令一览

| 命令 | 用途 | 使用时机 |
| ---- | ---- | ---- |
| `/project:session-load` | 恢复项目上下文 | 每次新对话开头 |
| `/project:session-save` | 保存当前进度 | 完成阶段性工作时 |
| `/project:session-end` | 完整收尾流程 | 下班/切换任务前 |
| `/project:context-check` | 健康诊断 | AI 开始变笨、重复、出错时 |
| `/project:context-sync` | 同步架构文档 | 依赖变更、目录结构调整后 |

## 安装后自动获得

安装脚本除了命令文件外，还会自动配置：

- **CLAUDE.md** — 5 条自动行为规则：启动加载、变化提醒、疲劳预警、归档提示、新项目初始化
- **hooks.json** — 事件触发：文件写入时检查依赖变化、命令执行时检查初始化状态
- **docs/ai-context/** — 上下文存储目录，模板文件自动创建

安装后打开 Claude Code，AI 会自动遵守 CLAUDE.md 中的规则，无需手动触发任何命令。

## 验证安装

一行命令检查所有文件：

```powershell
@(".claude/commands/project/session-load.md",".claude/commands/project/session-save.md",".claude/commands/project/session-end.md",".claude/commands/project/context-check.md",".claude/commands/project/context-sync.md",".claude/skills/session-context/SKILL.md",".claude/hooks.json","CLAUDE.md","docs/ai-context/current-task.md") | ForEach-Object { if (Test-Path $_) { "✅ $_" } else { "❌ $_ 缺失" } }
```

最关键的一步：**重启 Claude Code**，输入 `/project:session-load`，看到上下文摘要即安装成功。

## 上下文文件系统

```
docs/ai-context/
├── current-task.md      # 任务进度（checkbox 跟踪，覆盖更新）
├── decisions.md         # 技术决策日志（追加不覆盖）
├── pitfalls.md          # 踩坑记录（追加不覆盖）
└── architecture.md      # 项目架构（context-sync 自动生成）
```

## 三层自动化架构

```
CLAUDE.md（常驻规则层）   → AI 自动遵守，启动加载、变化提醒、疲劳预警
.claude/commands/（手动层） → 用户手动 /project:xxx 精确控制
.claude/hooks.json（事件层）→ 文件变化时自动触发轻量检查
```

## 系统要求

- Claude Code（最新版）
- Git（可选，用于版本控制上下文文件）

## 许可

MIT License — 随便用，随便改，随便分享。
