# SKIIS — AI 编程助手会话上下文管理技能

让 AI（Claude Code / Cursor）拥有持久化记忆，跨会话无缝衔接工作进度。

**跨 IDE 支持：** `.claude/`（Claude Code）+ `.cursor/rules/`（Cursor IDE）

## 这是什么？

SKIIS 是一套 Claude Code 全局技能，解决 AI 辅助编程中最头疼的问题：

- **会话长了变笨** → 自动预警，提醒保存后开新会话
- **换会话丢上下文** → `/session-load` 一键恢复
- **新项目无从下手** → 自动扫描结构、初始化上下文
- **排查跨模块问题** → 自动给下游项目生成排查任务，带完整输入条件
- **大型项目加载慢** → 分层上下文，子目录只加载自己的部分

**全局安装一次，所有项目自动生效。**

---

## 安装

### Claude Code（全局安装，一次所有项目生效）

```bash
# GitHub（国外用户）
git clone https://github.com/zq88297/SKIIS.git

# Gitee（国内用户，更快）
git clone https://gitee.com/zhang-baishui/skills.git

cd SKIIS

# macOS / Linux
bash install.sh --global

# Windows PowerShell
.\install.ps1 -Global
```

安装后重启 Claude Code，skill 自动触发（支持 skill + 斜杠命令 + hooks）。

### Cursor IDE（复制规则文件到项目）

```bash
# GitHub: git clone https://github.com/zq88297/SKIIS.git
# Gitee:  git clone https://gitee.com/zhang-baishui/skills.git

# 把 Cursor 规则复制到你的项目
cp -r SKIIS/.cursor/rules/ 你的项目/.cursor/rules/

# 初始化上下文目录（可选，也可以让 AI 自动初始化）
mkdir -p 你的项目/.claude/context/
```

安装后重启 Cursor，规则自动生效（支持自治规则 + 关键词触发，不需要斜杠命令）。

> 上下文文件存储在 `.claude/context/`，自动加入 `.gitignore`，不会误提交到代码仓库。

**这就够了。** 之后在任何项目打开 Claude Code，输入 `/session-load` 即可。

### 更新

```bash
cd ~/SKIIS && git pull && bash install.sh --global
```

---

## 六个命令

| 命令 | 用途 |
| ---- | ---- |
| `/session-load` | 加载上下文 / 新项目自动初始化 |
| `/session-save` | 保存当前进度（含具体下一步） |
| `/session-end` | 收尾：排查过程、新增依赖、部署方法、下一步 |
| `/context-check` | 上下文健康度诊断 |
| `/context-sync` | 同步项目架构文档 |
| `/task-send <路径>` | 向目标项目/模块派发排查任务 |
| `/task:plan` | 分析任务依赖，生成并行/串行执行计划 |
| `/task:run` | 启动并行会话执行异步任务 |
| `/workflow:start` | 启动项目管理流程（需求→方案→代码→测试→验收） |
| `/workflow:status` | 查看当前项目工作流进度 |
| `/workflow:review` | 项目收尾复盘，一致性检查 + 数据整理 |
| 自然语言 | "启动项目管理流程"、"查看项目进度"、"项目复盘" |

---

## 自动规则（全局 skill 内置，无需配置）

### 📋 规则 1：启动自动加载

新对话中 `/session-load` 自动恢复任务进度、决策记录、踩坑预警。

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

**触发方式**：直接说"给 B 派个排查任务"、"/task-send /path/to/B"，或 AI 检测到跨项目关联时主动询问。

### 📦 规则 4.8：分层上下文（大型多模块项目，支持任意深度嵌套）

根目录首次 load 时完整扫描，为所有子模块自动创建独立上下文。之后进任意层级子目录只加载该层的上下文（秒级）。支持递归嵌套——子模块里再有子模块同样适用。

```
大型项目/
├── .claude/context/               # 项目级（自动 gitignore）
├── 子系统/
│   ├── .claude/context/           # 子系统级
│   └── 子模块A/
│       ├── .claude/context/       # 模块级
│       └── 子模块A1/
│           └── .claude/context/   # 子模块级（任意深度）
```

任务可以在任意两层之间派发。

### 🚀 规则 5：新项目自动初始化

检测到 `.claude/context/` 不存在时直接初始化：扫描项目结构、创建模板文件、安装 hooks、生成架构文档。全程自动，不需要确认。

### 🪝 规则 6：Hooks 自动补装

老项目已有上下文但缺少 hooks 时，自动检测并询问是否补装。

---

## 使用场景示例

### 日常开发

```
打开项目 → /session-load → 看到上次的进度 → 继续工作
                                             │
                              改 bug → AI 提醒："记录到 pitfalls？"
                              做决策 → AI 提醒："追加到 decisions？"
                              15 轮了 → AI 提醒："该保存了"
                              下班了 → /session-end → 一键收尾
```

### 跨项目排查

```
项目 A 会话中排查问题
  │
  ├─ 发现根因在项目 B
  ├─ 对 AI 说："给 B 派个排查任务"
  │
  ├─ AI 自动在 B 生成 .claude/context/tasks/from-A-xxx.md
  │   包含：问题背景 / A→B 交互方式 / 排查清单 / 日志线索
  │
  ├─ A 的 current-task.md 记录："📤 已派发到 B"
  │
  ▼
打开项目 B → /session-load
  │
  ├─ 优先展示："📨 来自「项目A」的排查任务"
  ├─ B 的 AI 知道：为什么查、查什么、怎么交互
  │
  ▼
排查完成 → 任务移到 tasks/done/ → 结果反馈给 A
```

### 大型多模块项目

```
首次进根目录 → /session-load
  ├─ 扫描出 8 个子模块
  ├─ 为每个子模块创建独立上下文
  └─ 生成项目全景架构文档

之后进子模块A/ → /session-load
  └─ 秒级加载，只看 A 的任务和决策

排查时发现是子模块C的问题
  └─ "把问题派给子模块C" → 自动生成排查任务
```

---

## 上下文文件系统

```
.claude/context/              ← 自动加入 .gitignore，不会误提交
├── current-task.md          # 任务进度（checkbox 跟踪）
├── decisions.md             # 技术决策（追加不覆盖）
├── pitfalls.md              # 踩坑记录（追加不覆盖）
├── architecture.md          # 项目架构（context-sync 生成）
├── reference/               # 历史技术参考（协议格式、环境信息等）
└── tasks/                   # 跨项目/跨模块排查任务
    ├── from-IPsec网关-0601.md  # 其他项目派来的任务
    └── done/                   # 已处理的归档
```

---

## 重复安装安全

**完全安全，可以反复运行。** 智能合并策略：

| 文件 | 策略 |
| ---- | ---- |
| `.claude/commands/*.md` | 覆盖更新 |
| `.claude/skills/session-context/` | 覆盖更新 |
| `.claude/hooks.json` | 智能合并（已有则追加，已有 SKIIS 则跳过） |
| `CLAUDE.md` | 智能追加（已有 SKIIS 引用则跳过） |
| `.claude/context/` | 仅首次创建，绝不覆盖用户数据。自动 gitignore |

---

## 使用指南

### 日常开发

```
打开项目 → 说句话 → 自动加载上下文 → 开始工作
                   │
                   ├─ 有上次进度 → 展示 🔜 下次继续，接续工作
                   ├─ 全部完成了 → 提示清空，开始新任务
                   └─ 新项目 → 自动初始化
```

不需要记命令，AI 自动处理。

### 保存进度

做到一半要下班了，说：

> "保存进度"

AI 自动写入 `current-task.md`，包含：
- 完成了什么
- 接下来第一步该做什么（具体到文件和函数）
- 当前编译/运行状态
- 有什么阻塞

### 继续上次的工作

第二天打开项目，说：

> "继续"

AI 自动读取上次的上下文，展示：
- 🔜 上次写到哪了
- 第一步该做什么
- 当前状态和阻塞项

### 多人/多模块协作

当你排查项目 A 时发现可能是项目 B 的问题：

```bash
/task-send /path/to/project-B
```

AI 自动给 B 生成排查任务，包含：
- 问题背景
- A 和 B 的交互方式
- 已知线索
- 排查清单

B 项目下次打开时自动展示这个任务。

### 多任务并行

AI 生成多步骤计划后，自动分析哪些可以同时做：

> AI: "这个计划有 3 个任务可以并行。要我启动并行会话吗？"
> 你: "启动"
> AI: 自动在后台启动 3 个 Claude Code 会话，互不干扰

### 对话太长了怎么办

超过 15 轮 AI 会自动提醒保存。你也可以随时说：

> "检查一下上下文健康度"

AI 会诊断 token 用量、回复质量、是否该开新会话。

### 从零开始的新项目

首次进入新项目，AI 会自动：
1. 扫描项目结构
2. 创建 `.claude/context/`（防误提交的上下文目录）
3. 生成 `architecture.md`
4. 安装 hooks（文件变化自动检测）
5. 一切就绪后告诉你："上下文系统已初始化，开始工作吧"

### 切换分支

**Git：** `git checkout` 后下次对话 AI 自动识别新分支，创建该分支的上下文。

**SVN：** 在哪个分支目录工作就自动在哪创建上下文，不会误扫描其他分支。

---

## IDE 使用示例

### Claude Code

```bash
# 1. 全局安装（一次）
git clone https://github.com/zq88297/SKIIS.git && cd SKIIS && bash install.sh --global

# 2. 打开任何项目，开始对话
$ claude
> 帮我排查 IKE 协商超时的问题

# AI 自动加载上下文，判断项目结构，定位相关模块
# 排查过程中发现涉及 key-exchange 模块
> 给 ../key-exchange 派个排查任务
# AI 自动在 key-exchange 生成任务文件

# 做到一半下班了
> 保存进度
# AI 写入 current-task.md（含继续计划、关键文件清单、新增依赖）

# 第二天继续
$ claude
> 继续
# AI 读取 🔜 下次继续，直接打开对应文件和行号
```

### Cursor

```bash
# 1. 复制规则文件到项目（一次）
git clone https://github.com/zq88297/SKIIS.git
cp -r SKIIS/.cursor/rules/ 你的项目/.cursor/rules/

# 2. 打开 Cursor，正常使用
# 说 "排查 IPsec 隧道协商超时"
# AI 自动：扫描项目 → 定位模块 → 确认分支 → 开始工作

# 3. 规则触发词（无需斜杠命令）
"继续"、"保存进度"、"同步架构"、"给 B 派个任务"、"并行执行"
```

### CodeX

CodeX 插件暂无现成文件，但可以用 `SKILL-DESIGN.md` 自动生成：

```bash
# 1. 将设计文档发给 CodeX
# 2. 让 CodeX 按自己的格式生成等价的 skill
"读取 SKILL-DESIGN.md，理解这个上下文管理系统的完整设计，
然后用 CodeX 支持的格式重新生成等价的 skill 文件。"
```

`SKILL-DESIGN.md` 包含了：核心目标、三层架构、7 个上下文文件格式、全部规则的触发条件和执行逻辑、跨项目任务派发、并行调度、分支隔离等完整设计。

---

## 系统要求

- Claude Code（最新版）
- Git

## 许可

MIT License — 随便用，随便改，随便分享。
