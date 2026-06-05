# SKIIS — 个人 Claude Code Skills 库

一套面向 AI 辅助编程的 Claude Code 全局技能集合，解决跨会话记忆丢失、任务调度低效、项目管理无序等痛点。

**跨 IDE 支持：** `.claude/`（Claude Code）+ `.cursor/rules/`（Cursor IDE）

---

## 包含的 Skills

### 1. session-context — 会话上下文管理

> 让 AI 拥有持久化记忆，跨会话无缝衔接工作进度。

**解决的问题：** 会话长了变笨、换会话丢上下文、新项目无从下手、排查跨模块问题缺上下文、大型项目加载慢。

**核心能力：**

- **智能加载** — 理解问题意图后按需加载上下文，简单项目直接加载，复杂项目先定位子模块
- **自动归档** — 修 bug → 记录到 pitfalls，做决策 → 追加到 decisions，完成模块 → 更新 current-task
- **健康监测** — 检测 token 用量、回复质量、路径错误，主动提醒开新会话
- **架构感知** — 目录增删、依赖变更时自动提醒同步架构文档
- **跨项目派发** — A 项目排查发现是 B 的问题？自动给 B 生成带完整上下文的排查任务
- **分层上下文** — 大型多模块项目按子目录分层，任意深度嵌套，进哪个目录只加载哪层
- **分支隔离** — Git 分支自动创建独立上下文，SVN 按目录隔离

**命令：**

| 命令 | 用途 |
| ---- | ---- |
| `/session-load` | 加载上下文 / 新项目自动初始化 |
| `/session-save` | 保存当前进度（含具体下一步） |
| `/session-end` | 会话收尾（健康评估 + 总结 + 持久化） |
| `/context-check` | 上下文健康度诊断（token / 完整性 / 幻觉风险 / 外部记忆） |
| `/context-sync` | 同步项目架构文档（支持 `--quick` `--deps` `--structure` `--force`） |
| `/task-send <路径>` | 向目标项目/模块派发排查任务 |

---

### 2. task-orchestrator — 任务并行调度

> 分析任务依赖，自动识别可并行的工作，管理多会话并发执行。

**解决的问题：** 多步骤任务只能串行执行浪费时间、并行开发容易冲突、任务状态难以追踪。

**核心能力：**

- **自动分析** — 生成 2+ 步计划时自动分析依赖关系，识别可并行的任务组
- **冲突检测** — 同文件修改、输出依赖 → 串行；不同模块/只读操作 → 并行
- **并发控制** — 最多 3 个并行会话，通过 claim lock 防止任务冲突（24 小时过期）
- **结果合并** — 各任务独立写结果文件，主会话统一合并
- **自动续接** — 任务完成后自动检查队列，执行下一个可用任务

**命令：**

| 命令 | 用途 |
| ---- | ---- |
| `/task:plan` | 分析依赖，生成并行/串行执行计划 |
| `/task:run` | 启动并行会话执行任务 |

---

### 3. project-workflow — 项目全生命周期管理

> 从需求到验收，结构化管理项目开发全流程。

**解决的问题：** 需求→设计→实现→测试各阶段缺乏结构化管理、文档与代码脱节、项目收尾无数据支撑。

**核心能力：**

- **五阶段流程** — 需求分析 → 方案设计 → 代码实现 → 测试 → 验收，每阶段有明确产出
- **快速通道** — 已有需求/设计文档时，自动校验一致性后跳到实现阶段
- **需求深挖** — 先问参考文件，再深度提问，产出结构化需求文档
- **实现护栏** — 先写单例测试再实现，偏差时暂停；bug 修复按根因聚类，单次最多 3 文件 30 行
- **验收校验** — 需求 vs 设计 vs 代码一致性检查，项目数据自动整理（阶段耗时、功能统计、错误热点、技术债务）

**命令：**

| 命令 | 用途 |
| ---- | ---- |
| `/workflow:start` | 启动项目管理流程（从需求分析开始） |
| `/workflow:status` | 查看当前项目工作流进度 |
| `/workflow:review` | 项目收尾复盘（一致性检查 + 数据整理） |

---

## 安装

### Claude Code（全局安装，推荐）

```bash
# GitHub
git clone https://github.com/zq88297/SKIIS.git

# Gitee（国内更快）
git clone https://gitee.com/zhang-baishui/skills.git

cd SKIIS

# macOS / Linux / Git Bash
bash install.sh --global

# Windows PowerShell
.\install.ps1 -Global
```

安装后重启 Claude Code，所有 skill 自动生效。

### Cursor IDE

```bash
git clone https://github.com/zq88297/SKIIS.git
cp -r SKIIS/.cursor/rules/ 你的项目/.cursor/rules/
mkdir -p 你的项目/.claude/context/
```

### 更新

```bash
cd ~/SKIIS && git pull && bash install.sh --global
```

### 安全性

重复安装完全安全，智能合并策略：

| 文件 | 策略 |
| ---- | ---- |
| `.claude/commands/*.md` | 覆盖更新 |
| `.claude/skills/` | 覆盖更新 |
| `.claude/hooks.json` | 智能合并（已有则追加，已有 SKIIS 则跳过） |
| `CLAUDE.md` | 智能追加（已有 SKIIS 引用则跳过） |
| `.claude/context/` | 仅首次创建，绝不覆盖用户数据 |

---

## 使用示例

### 日常开发 — session-context

```
打开项目 → 说句话 → 自动加载上下文 → 开始工作
                   │
                   ├─ 有上次进度 → 展示 🔜 继续点，接续工作
                   ├─ 全部完成 → 提示清空，开始新任务
                   └─ 新项目 → 自动初始化（扫描结构 + 创建模板 + 安装 hooks）
```

### 保存与恢复 — session-context

```
下班前: "保存进度"
  → AI 写入 current-task.md（含下一步、关键文件清单、当前状态）

第二天: "继续"
  → AI 读取上下文，展示 🔜 继续点，直接定位到文件和行号
```

### 多任务并行 — task-orchestrator

```
AI: "这个计划有 3 个任务可以并行，要启动吗？"
你: "启动"
  → 3 个 Claude Code 会话在后台并行执行，互不干扰
  → 完成后主会话自动合并结果
```

### 跨项目排查 — session-context + task-orchestrator

```
项目 A 排查中 → 发现根因在项目 B
  → /task-send /path/to/project-B
  → B 自动生成排查任务（含问题背景、交互方式、排查清单）

打开项目 B → /session-load
  → 优先展示来自 A 的排查任务
```

### 项目全流程管理 — project-workflow

```
新项目启动 → /workflow:start
  → 需求分析 → 方案设计 → 代码实现 → 测试 → 验收
  → 每阶段有明确产出，状态自动保存到 workflow-state.md

中途查看进度 → /workflow:status
项目收尾 → /workflow:review（一致性检查 + 数据整理）
```

---

## 项目结构

```
.claude/
├── commands/                  # 斜杠命令（安装后复制到用户环境）
│   ├── session-load.md        # session-context 命令
│   ├── session-save.md
│   ├── session-end.md
│   ├── context-check.md
│   ├── context-sync.md
│   ├── task-send.md
│   ├── task/                  # task-orchestrator 命令
│   │   ├── plan.md
│   │   └── run.md
│   └── workflow/              # project-workflow 命令
│       ├── start.md
│       ├── status.md
│       └── review.md
├── hooks.json                 # Hook 配置
├── hooks/                     # Hook 脚本
│   ├── check-context.sh       # PreToolUse: 检查上下文是否初始化
│   └── on-file-change.sh      # PostToolUse: 检测依赖/构建配置变化
└── skills/
    ├── session-context/       # 会话上下文管理 skill
    ├── task-orchestrator/     # 任务并行调度 skill
    └── project-workflow/      # 项目全生命周期管理 skill

.cursor/rules/                 # Cursor IDE 规则文件
```

---

## 上下文文件系统

所有上下文存储在 `.claude/context/`，自动加入 `.gitignore`：

```
.claude/context/
├── current-task.md          # 任务进度（checkbox 跟踪，覆盖更新）
├── decisions.md             # 技术决策（追加更新）
├── pitfalls.md              # 踩坑记录（追加更新）
├── architecture.md          # 项目架构（context-sync 生成）
├── workflow-state.md        # 工作流阶段状态（project-workflow）
├── requirements.md          # 需求文档（project-workflow）
├── design.md                # 方案设计（project-workflow）
├── reference/               # 历史技术参考
└── tasks/                   # 跨项目/跨模块排查任务
```

---

## 扩展

本仓库是个人 skill 集合，可以按需添加新 skill：

1. 在 `.claude/skills/` 下创建新目录
2. 编写 `SKILL.md` 定义 skill 行为规则
3. 在 `.claude/commands/` 下添加对应的斜杠命令
4. 运行安装脚本同步到全局环境

---

## 许可

MIT License — 随便用，随便改，随便分享。
