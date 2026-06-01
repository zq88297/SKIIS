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

**触发条件（满足任一即触发）：**

| 触发方式 | 示例 |
|---------|------|
| 用户主动请求 | "这个问题可能和 B 项目有关，帮我生成排查任务"、"给 B 派个任务"、"/project:task-send /path/to/B" |
| AI 主动检测 | 当排查中发现根因指向另一个项目时，主动问："这个问题可能和 B 项目（/path/to/B）有关，是否需要我生成排查任务？" |

**触发后自动执行：**

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

**规则 4.7 与规则 5 的组合：**

跨项目 + 跨多层 + 目标未初始化，全自动处理：

```
程序A/子系统/子模块A1 中排查
  │
  ├─ 发现根因在 程序B/子系统/子模块B2（另一个程序，另一个层级）
  ├─ 用户说："给 B/子系统/子模块B2 派个排查任务"
  │
  ├─ 规则 4.7 触发 → 确认目标路径
  ├─ 目标目录没有 docs/ai-context/ → 规则 5 自动触发
  │     ├─ 初始化 B/子系统/子模块B2 的上下文
  │     └─ 安装 hooks
  ├─ 规则 4.7 继续 → 生成 task 文件
  │     ├─ 来源：程序A/子系统/子模块A1
  │     ├─ 问题：{从A的排查中总结}
  │     ├─ 交互：A→B 的调用链
  │     └─ 排查清单
  │
  ▼
打开 B/子系统/子模块B2 → /project:session-load
  └─ 优先展示：📨 来自「程序A/子系统/子模块A1」的排查任务
```

**不需要提前在目标目录做任何配置。规则 5 保证目标目录自动初始化，规则 4.7 保证任务文件生成。任意程序、任意层级、任意深度，都能直接派发。**

### 规则 4.8：分层上下文（大型多模块项目）

当项目根目录下有多个独立子功能目录时，使用**分层上下文**，避免每次在根目录 load 都扫描整个项目。

**子模块识别标准（自动扫描时使用）：**

一个目录被判定为"子模块"（值得创建独立上下文），需要满足以下条件：

**✅ 自动识别信号（满足越多越确定）：**

| 优先级 | 信号 | 示例 |
|-------|------|------|
| 🟢 确定 | 有独立构建配置 | `Makefile`、`CMakeLists.txt`、`package.json`、`Cargo.toml` |
| 🟢 确定 | 有 main 入口文件 | `main.c`、`main.py`、`index.ts`、`main.go` |
| 🟡 可能 | 目录名暗示独立功能 | `ike-module/`、`key-exchange/`、`log-collector/` |
| 🟡 可能 | 有独立的 include/lib 子目录 | `src/`、`lib/`、`include/` 在该目录下 |

**❌ 排除规则（永远不会被识别为子模块）：**

| 目录 | 原因 |
|------|------|
| `src/`、`lib/`、`include/`、`tests/`、`docs/`、`examples/` | 通用代码组织目录 |
| `node_modules/`、`dist/`、`build/`、`target/`、`__pycache__/` | 构建产物 |
| `.git/`、`.svn/`、`.vscode/`、`.idea/` | 工具配置目录 |
| `assets/`、`static/`、`public/`、`resources/` | 静态资源目录 |

**用户确认环节：**

自动扫描完成后，列出识别结果让用户确认：

```
检测到以下子模块（含判断依据）：

✅ ike-module/         — CMakeLists.txt + main.c
✅ key-exchange/       — Makefile + main.c
⚠️  utils/             — 只有 .c 文件，无构建配置
❌ src/                — 通用目录，已跳过
❌ tests/              — 通用目录，已跳过

请确认：
- 是否将 utils/ 也作为子模块？
- 是否有其他需要创建上下文的目录？
```

用户确认后的增减结果记录到根目录的 `architecture.md` 中，之后不再重复询问。

**初始化流程（根目录，只做一次）：**

```
/project:session-load（根目录，首次）
  │
  ├─ 完整扫描所有子目录，生成 architecture.md（含子模块清单）
  ├─ 询问："检测到以下子模块：A/B/C...，是否为它们也创建独立上下文？"
  │
  └─ 用户确认后，为每个子目录自动执行 mini-init：
       ├── 子目录A/docs/ai-context/current-task.md
       ├── 子目录A/docs/ai-context/decisions.md
       ├── 子目录A/docs/ai-context/pitfalls.md
       └── 子目录A/CLAUDE.md（精简版：只写本目录职责和接口）
```

**嵌套支持：**

分层上下文**天然支持任意深度**。因为 `session-load` 只检查当前目录的 `docs/ai-context/`，规则 5 也只在当前目录创建文件。

```
大型项目/
├── docs/ai-context/           # 项目级上下文
├── 子系统/
│   ├── docs/ai-context/       # 子系统级上下文
│   ├── 子模块A/
│   │   ├── docs/ai-context/   # 模块级上下文
│   │   └── 子模块A1/
│   │       └── docs/ai-context/  # 子模块级上下文（任意深）
│   └── 子模块B/
```

每层独立运作。在哪层跑 `/project:session-load` 就加载哪层的上下文。任务可以在任意两层之间派发（根→最深子模块，同级子模块互发）。

**日常使用：**

| 场景 | 操作 | 加载范围 |
|------|------|---------|
| 进入根目录 | `/project:session-load` | 只读 architecture.md 的模块清单 + 全局 decisions |
| 进入子目录 A | `/project:session-load` | 只加载子目录 A 的上下文（秒级） |
| 进入 A/A1（更深） | `/project:session-load` | 只加载 A1 的上下文 |
| 在根目录排查，定位到 A1 | "把问题派给 A1" | 自动给 A1 生成 task |
| 在 A1 排查，需要查 B | "给 B 生成排查任务" | 跨子目录派发 |

**子目录 CLAUDE.md 模板（极简版）：**

```markdown
# {子模块名称}
- **所属项目**：{根项目名称}
- **功能职责**：{一句话描述}
- **对外接口**：{供哪些模块调用 / 调用哪些模块}
- **关键文件**：{核心代码文件列表}
```

**规则 4.7 无需修改** — 跨项目任务派发天然支持根→子、子→子、子→根。只需确认目标路径即可。

**子模块增删自动检测：**

每次在根目录运行 `/project:session-load` 或 `/project:context-sync` 时，对比当前目录结构和 `architecture.md` 中缓存的子模块清单：

| 检测到的情况 | 自动处理 |
|-------------|---------|
| 新增目录，匹配子模块识别标准 | "检测到新模块 `xxx/`，是否需要创建独立上下文？" → 用户确认后自动初始化 + 更新 architecture.md |
| 新增目录，不匹配识别标准 | 忽略，不询问 |
| 缓存的子模块目录已不存在 | "检测到 `yyy/` 模块已删除，是否从架构文档中移除？" → 用户确认后更新 architecture.md，其 `docs/ai-context/` 保留不动（手动删除） |
| 缓存的子模块目录还在，但内部结构大变 | "检测到 `zzz/` 模块结构有较大变化，是否需要更新上下文？" |

这样无论用户何时新增或删除功能模块，下一次 load 或 sync 时自动感知变化。

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
