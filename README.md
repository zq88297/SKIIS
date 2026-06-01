# SKIIS — Claude Code 会话上下文管理技能

让 Claude Code 拥有持久化记忆，跨会话无缝衔接工作进度。

## 这是什么？

SKIIS 是一套 Claude Code 全局技能，解决 AI 辅助编程中最头疼的问题：

- **会话长了变笨** → 自动预警，提醒保存后开新会话
- **换会话丢上下文** → `/project:session-load` 一键恢复
- **新项目无从下手** → 自动扫描结构、初始化上下文
- **排查跨模块问题** → 自动给下游项目生成排查任务，带完整输入条件
- **大型项目加载慢** → 分层上下文，子目录只加载自己的部分

**全局安装一次，所有项目自动生效。**

---

## 安装

### 全局安装（一次，所有项目生效）

```bash
git clone https://github.com/zq88297/SKIIS.git
cd SKIIS

# macOS / Linux
bash install.sh --global

# Windows PowerShell
.\install.ps1 -Global
```

**这就够了。** 之后在任何项目打开 Claude Code，输入 `/project:session-load` 即可。

### 更新

```bash
cd ~/SKIIS && git pull && bash install.sh --global
```

---

## 六个命令

| 命令 | 用途 |
| ---- | ---- |
| `/project:session-load` | 加载上下文 / 新项目自动初始化 |
| `/project:session-save` | 保存当前进度 |
| `/project:session-end` | 结束会话（健康检查 + 保存） |
| `/project:context-check` | 上下文健康度诊断 |
| `/project:context-sync` | 同步项目架构文档 |
| `/project:task-send <路径>` | 向目标项目/模块派发排查任务 |

---

## 自动规则（全局 skill 内置，无需配置）

### 📋 规则 1：启动自动加载

新对话中 `/project:session-load` 自动恢复任务进度、决策记录、踩坑预警。

### 🔍 规则 2：架构变化自动提醒

监测到目录增删、依赖变更、技术方案切换时主动提醒同步。

### ⚠️ 规则 3：对话疲劳自动预警

超过 15 轮提醒保存，检测到回复矛盾或重复时建议开新会话。

### 💾 规则 4：工作产出自动归档

修复 bug → 提示记录到 pitfalls。技术决策 → 提示追加到 decisions。完成模块 → 提示更新 current-task。

### 📝 规则 4.5：修改计划自动同步

AI 生成修改计划时，自动转为 `current-task.md` 的 checkbox 清单，无需手动保存。

### 🔧 规则 4.6：编译环境自动归档

安装工具链/依赖时，自动记录技术选型到 decisions，安装问题到 pitfalls。成功失败都有记录。

### 🔗 规则 4.7：跨项目任务派发

排查 A 项目发现问题在 B 项目时，自动给 B 生成排查任务。包含：问题背景、交互方式、排查清单、已知线索。下次 B 项目的会话打开就能看到完整输入条件。

**触发方式**：直接说"给 B 派个排查任务"、"/project:task-send /path/to/B"，或 AI 检测到跨项目关联时主动询问。

### 📦 规则 4.8：分层上下文（大型多模块项目，支持任意深度嵌套）

根目录首次 load 时完整扫描，为所有子模块自动创建独立上下文。之后进任意层级子目录只加载该层的上下文（秒级）。支持递归嵌套——子模块里再有子模块同样适用。

```
大型项目/
├── docs/ai-context/               # 项目级
├── 子系统/
│   ├── docs/ai-context/           # 子系统级
│   └── 子模块A/
│       ├── docs/ai-context/       # 模块级
│       └── 子模块A1/
│           └── docs/ai-context/   # 子模块级（任意深度）
```

任务可以在任意两层之间派发。

### 🚀 规则 5：新项目自动初始化

检测到 `docs/ai-context/` 不存在时直接初始化：扫描项目结构、创建模板文件、安装 hooks、生成架构文档。全程自动，不需要确认。

### 🪝 规则 6：Hooks 自动补装

老项目已有上下文但缺少 hooks 时，自动检测并询问是否补装。

---

## 使用场景示例

### 日常开发

```
打开项目 → /project:session-load → 看到上次的进度 → 继续工作
                                             │
                              改 bug → AI 提醒："记录到 pitfalls？"
                              做决策 → AI 提醒："追加到 decisions？"
                              15 轮了 → AI 提醒："该保存了"
                              下班了 → /project:session-end → 一键收尾
```

### 跨项目排查

```
项目 A 会话中排查问题
  │
  ├─ 发现根因在项目 B
  ├─ 对 AI 说："给 B 派个排查任务"
  │
  ├─ AI 自动在 B 生成 docs/ai-context/tasks/from-A-xxx.md
  │   包含：问题背景 / A→B 交互方式 / 排查清单 / 日志线索
  │
  ├─ A 的 current-task.md 记录："📤 已派发到 B"
  │
  ▼
打开项目 B → /project:session-load
  │
  ├─ 优先展示："📨 来自「项目A」的排查任务"
  ├─ B 的 AI 知道：为什么查、查什么、怎么交互
  │
  ▼
排查完成 → 任务移到 tasks/done/ → 结果反馈给 A
```

### 大型多模块项目

```
首次进根目录 → /project:session-load
  ├─ 扫描出 8 个子模块
  ├─ 为每个子模块创建独立上下文
  └─ 生成项目全景架构文档

之后进子模块A/ → /project:session-load
  └─ 秒级加载，只看 A 的任务和决策

排查时发现是子模块C的问题
  └─ "把问题派给子模块C" → 自动生成排查任务
```

---

## 上下文文件系统

```
docs/ai-context/
├── current-task.md          # 任务进度（checkbox 跟踪）
├── decisions.md             # 技术决策（追加不覆盖）
├── pitfalls.md              # 踩坑记录（追加不覆盖）
├── architecture.md          # 项目架构（context-sync 生成）
└── tasks/                   # 跨项目/跨模块排查任务
    ├── from-IPsec网关-0601.md  # 其他项目派来的任务
    └── done/                   # 已处理的归档
```

---

## 重复安装安全

**完全安全，可以反复运行。** 智能合并策略：

| 文件 | 策略 |
| ---- | ---- |
| `.claude/commands/project/*.md` | 覆盖更新 |
| `.claude/skills/session-context/` | 覆盖更新 |
| `.claude/hooks.json` | 智能合并（已有则追加，已有 SKIIS 则跳过） |
| `CLAUDE.md` | 智能追加（已有 SKIIS 引用则跳过） |
| `docs/ai-context/` | 仅首次创建，绝不覆盖用户数据 |

---

## 系统要求

- Claude Code（最新版）
- Git

## 许可

MIT License — 随便用，随便改，随便分享。
