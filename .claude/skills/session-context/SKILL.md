---
name: session-context
description: "MUST trigger on EVERY conversation in a dev project. Auto-loads context (task progress, decisions, pitfalls). Trigger on: any code-related request (修改, 排查, debug, fix, change, investigate, generate, create, how to, 帮我, 实现, 开发, 优化, 重构, 测试, 部署, 编译, 运行, 报错, 失败, 问题), /project:session-*, 保存上下文, 加载上下文, 继续工作, 任何对话的第一句话."
---

# Session Context Management

你是一个**全局上下文管理器**。以下规则在任何项目中**自动生效**，无需用户手动触发任何命令。

---

## 上下文存储位置

**默认路径：`.claude/context/`**（在项目 `.claude/` 目录下，通常已被 gitignore/svn:ignore）。

**向后兼容：** 如果项目已有 `.claude/context/` 目录，优先用它。如果没有，就用 `.claude/context/`。

**为什么不用 `.claude/context/`：**
- `.claude/` 通常已在 `.gitignore` 中，不会误提交
- 上下文文件是本地工作记录，不应该上传到代码仓库
- 初始化时自动将 `.claude/context/` 加入 `.gitignore`（Git）或设置 `svn:ignore`（SVN）

**以下文档中所有 `.claude/context/` 路径，实际操作时根据上述规则自动选择正确路径。**

---

## 自动规则（全局生效，无需用户操作）

### 规则 0：智能加载（最高优先级）

**不要先加载再理解问题，要先理解问题再加载。** 加载时机取决于项目类型，流程如下：

```
用户提问
  │
  ├─ 步骤 0：用户提到 bug/修复/fix/debug/问题/报错？
  │     │
  │     ├─ 是 → 立即执行 ls .bugs/（不要先读其他文件）
  │     │     ├─ .bugs/ 有文件 → 直接开始处理（解压/解析/修复）
  │     │     └─ .bugs/ 为空 → 走正常流程，告诉用户放入 Bug 文件
  │     │
  │     └─ 否 → 继续步骤 1
  │
  ├─ 步骤 1：快速判断项目类型（仅 ls 顶层目录，1 秒）
  │
  ├─ 项目是简单结构？
  │     ├─ 是（根目录直接就是源码，无子模块目录）
  │     │     └─ 直接加载当前目录的 .claude/context/
  │     │        ├─ 有 → 读上下文 → 回答用户
  │     │        └─ 无 → 初始化 → 回答用户
  │     │
  │     └─ 否（根目录下有多个子功能目录）
  │           │
  │           ├─ 步骤 2：根据用户问题，判断涉及哪个子模块
  │           │    用户："IPsec 隧道协商超时"
  │           │    AI：涉及 ike-module/ + key-exchange/
  │           │
  │           ├─ 步骤 3：检查涉及子模块的分支
  │           │    ├─ 模块只有单目录/单分支 → 直接加载
  │           │    ├─ 模块有多个分支 → 列出分支，让用户选
  │           │    │
  │           │    │    "ike-module 有以下分支：
  │           │    │       trunk/  |  feature-ipv6/  |  bugfix-retry/
  │           │    │     排查哪个？"
  │           │    │
  │           │    └─ 用户指定分支 → 只加载该分支上下文
  │           │
  │           └─ 步骤 4：加载目标上下文 → 回答用户
  │
  └─ 其他子模块的上下文，不碰。
```

**加载上下文后，必须执行：将当前任务写入 `current-task.md`**

无论用户说了什么，加载完上下文后**立即**将用户的请求写入 `current-task.md`：

```
读取 current-task.md
  │
  ├─ 文件存在 → 检查是否有未完成任务
  │     ├─ 有未完成任务 → 在"进行中"追加新任务
  │     └─ 全部完成 → 清空旧任务，写入新任务
  │
  └─ 文件不存在 → 创建并写入新任务

写入格式：
  ## 已完成
  暂无

  ## 进行中
  - [ ] {用户请求的具体任务描述}

  ## 待完成
  暂无

  ## 关键上下文
  - {与任务相关的模块、文件、约束}
```

**这一步是强制的——每次对话加载上下文后都必须执行，不需要用户手动触发。**

**加载后检查：任务是否已全部完成？**

读取 `current-task.md` 后，检查状态：

```
已完成 全部打勾 ✅ 且 进行中 为空 且 待完成 为空？
  │
  ├─ 是 → 项目处于"干净"状态
  │      "✅ 上次的任务已全部完成。清空任务记录，开始新任务？"
  │
  │      用户确认后，**分类处理，不简单丢弃**：
  │
  │      ├─ 提取 "## 关键上下文" 段落
  │      │     → 保存到 .claude/context/reference/context-{日期}.md
  │      │       （协议格式、接口端点、调试环境、配置值——这些都是技术资产）
  │      │
  │      ├─ 提取任务中涉及的技术决策 → 追加到 decisions.md
  │      ├─ 提取任务中遇到的踩坑 → 追加到 pitfalls.md
  │      │
  │      ├─ 清空 current-task.md（任务部分重置，关键上下文部分重置为空）
  │      │
  │      └─ 在新 current-task.md 的 "关键上下文" 部分引用已保存的文件：
  │            "📚 历史参考：见 .claude/context/reference/"
  │
  └─ 否 → 有未完成任务，正常加载
```

**清理后的目录结构：**
```
.claude/context/
├── current-task.md           ← 新任务（干净）
├── reference/                ← 永久保留的技术参考
│   ├── context-2026-03-15.md ← 协议格式、API端点、调试环境...
│   └── context-2026-06-01.md
├── decisions.md              ← 历史决策（追加累积）
└── pitfalls.md               ← 历史踩坑（追加累积）
```

**关键原则：**
- 任务全完成 = 新起点，不应继续加载旧的任务清单
- **但技术参考不能丢** — 协议格式、调试环境、API端点、配置值等是永久资产
- decisions.md 和 pitfalls.md 不清理 — 历史决策和踩坑仍有价值
- 简单项目 → 直接加载，立即回答
- 复杂项目 → 先定位目标，再加载，再回答

#### 对话中途涉及新模块

同样的流程：先检查分支 → 多分支则问 → 单分支直接加载。

这项规则**不需要用户输入任何命令**。

### 规则 1：启动时自动加载上下文

此项已被规则 0 替代。`/session-load` 命令仅作为手动补充手段。

### 规则 2：架构变化时自动提醒

当对话中出现以下情况，主动提醒：

| 触发条件 | 提醒内容 |
|---------|---------|
| 新增或删除顶层目录 | "检测到项目结构变化，是否需要运行 `/context-sync` 更新架构文档？" |
| 安装了新的核心依赖 | "检测到新依赖加入，是否需要运行 `/context-sync --deps` 更新依赖信息？" |
| 切换了技术方案 | "检测到技术方案变更，是否需要记录到 `.claude/context/decisions.md`？" |

### 规则 3：上下文健康自诊断（自动触发，无需用户操作）

AI 在对话中持续自监控，发现异常时**主动汇报健康报告**，不等用户输入 `/context-check`。

**触发条件（以实际上下文状态为准，而非简单数轮数）：**

| 信号 | 严重度 | 说明 |
|------|-------|------|
| 系统注入了 `conversation summary`（对话摘要） | 🟡 | 上下文窗口已满，早期对话被压缩。此时应立即提醒 |
| AI 无法回忆起本轮之前讨论过的细节 | 🔴 | 早期对话已被挤出窗口，强烈建议新会话 |
| 回复质量明显下降（回答变短、变模糊、缺少细节） | 🟡 | 上下文接近饱和 |
| AI 开始重复读取之前已读过的文件 | 🟡 | 文件内容被挤出，需要重新加载 |
| 对文件路径、变量名、函数名不确定 | 🔴 | 关键上下文已丢失 |
| 用户纠正 AI 超过 2 次 | 🔴 | 上下文已不完整，继续产出错误 |
| 一次读入了大量代码/日志（单轮 > 20K tokens） | 🟡 | 大量内容进入窗口，挤掉了早期的对话 |
| 从上次保存后工作跨度很大（多个文件/模块） | 🟡 | 提示保存 checkpoint |

**刻意不用的指标：对话轮数。** 一轮轻量问答和一轮读取数万行代码，对上下文消耗天差地别。

**自动汇报格式（精简版，不阻塞对话）：**

```
📊 上下文健康自检

🪙 窗口状态: ⚠️ 检测到对话摘要注入 → 早期内容已被压缩
🧠 回复质量: ✅ 正常
🎯 准确性: 🟢 无错误
💾 外部记忆: ✅ 已同步（上次保存 30 分钟前）

💡 建议：继续工作，暂时安全。
```

**严重时输出完整报告：**

```
🔴 上下文健康警告

🪙 窗口状态: ❌ 对话摘要已注入 2 次 + 出现路径记忆错误
🧠 回复质量: ❌ 最近回复明显变短、失去细节
🎯 准确性: 🔴 已被纠正 2 次（变量名错误、文件路径错误）
💾 外部记忆: ⚠️ 未同步（上次保存 2 小时前）

🚨 强烈建议：立即 /session-save → 结束会话 → 开新会话 /session-load
   继续在当前会话工作将导致回复质量显著下降。早期讨论的内容已不可恢复。
```

**`/context-check` 命令保留**，作为用户手动触发时的完整诊断（含外部记忆文件状态检查）。规则 3 是 AI 自驱动的轻量版。

### 规则 4：工作产出自动归档提示

| 操作 | 提醒 |
|------|------|
| 修复了一个 bug | "是否将根因和解决方案记录到 `pitfalls.md`？" |
| 做了一个技术决策 | "是否将此决策追加到 `decisions.md`？" |
| 完成了一个功能模块 | "是否更新 `current-task.md` 的任务进度？" |

### 规则 4.01：Bug 修复请求自动响应

当用户提到"bug"、"修复"、"fix"、"debug"、"问题"、"报错"等关键词时，**立即检查项目根目录是否存在 `.bugs/` 目录**：

```
用户提到 bug 相关关键词
  │
  ├─ 检查 .bugs/ 目录
  │     │
  │     ├─ 存在且有文件 → 立即开始处理：
  │     │     1. 扫描 .bugs/ 中的文件
  │     │     2. 解压压缩包（zip/rar/7z）
  │     │     3. 解析 PDF 文档
  │     │     4. 读取文本文件
  │     │     5. 提取 Bug 列表
  │     │     6. 按根因聚类
  │     │     7. 开始逐个修复
  │     │
  │     │     不需要用户说"开始修 bug"，直接开始。
  │     │
  │     └─ 不存在或为空 → 告知用户：
  │           "项目中还没有 Bug 文件。请将 Bug 报告放入 `.bugs/` 目录，
  │            或直接描述你遇到的问题。"
  │
  └─ 不要反问"具体是哪个 bug"——如果 .bugs/ 有文件就直接处理
```

**关键：不要问"具体是哪个 bug"。** 如果 `.bugs/` 有文件，直接处理；如果没有，才让用户描述或放入文件。

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

无需用户手动运行 `/session-save`，计划自动归档。

### 规则 4.51：新任务自动捕获（会话内任务切换）

当用户在会话中完成当前任务后提出新任务时，**自动更新 `current-task.md`**：

**触发条件：**
- `current-task.md` 中所有 checkbox 已打勾（任务完成）
- 用户提出了新的需求/问题/任务
- 用户说"继续"、"还有"、"另外"、"接下来"、"再帮我"等衔接词

**自动执行：**

```
用户提出新任务
  │
  ├─ 当前任务全部完成？
  │     │
  │     ├─ 是 → 自动将已完成任务归档：
  │     │     ├─ 提取关键技术决策 → 追加到 decisions.md
  │     │     ├─ 提取踩坑记录 → 追加到 pitfalls.md
  │     │     ├─ 提取关键上下文 → 移到 reference/
  │     │     └─ 清空 current-task.md 的任务部分
  │     │
  │     │     然后写入新任务：
  │     │     ├─ 将用户新需求写入 current-task.md
  │     │     ├─ 更新"关键上下文"部分
  │     │     └─ 向用户确认："已归档上个任务，新任务已记录到 current-task.md"
  │     │
  │     └─ 否 → 在现有任务列表末尾追加新任务
  │
  └─ 不需要用户手动运行 /session-save
```

**示例：**

上个任务完成后 `current-task.md`：
```markdown
## 已完成
- [x] 修复登录超时问题
- [x] 添加重试机制

## 进行中
暂无

## 待完成
暂无
```

用户说"还有个问题，首页加载很慢"，自动更新为：
```markdown
## 已完成
暂无

## 进行中
- [ ] 优化首页加载性能

## 待完成
暂无

## 关键上下文
- 上个任务：登录超时已修复，重试机制已添加（详见 reference/）
- 当前任务：首页加载慢，需排查性能瓶颈
```

### 规则 4.55：关键文件清单（跨会话上下文接力）

当上下文即将耗尽需要开新会话时，在 `current-task.md` 的 `## 🔜 下次继续` 段落后追加 `## 📂 关键文件清单`：

```markdown
## 📂 关键文件清单（新会话直接加载，无需重新探索）

### 问题定位相关
- src/ike/negotiate.c:240-350  ← SA 协商主逻辑，handle_timeout() 在这里
- src/ike/sa.h:45-78          ← SA 状态枚举定义
- include/ike/ike_types.h     ← 数据结构定义

### 已排除的文件（不需要再看）
- src/ike/crypto.c            ← 加密模块，已验证正常
- src/log/logger.c            ← 日志模块，与问题无关

### 当前排查结论
- SA 状态机在超时后未正确重置 → handle_timeout() 缺少互斥锁
- 已确认不是加密模块的问题
- 下一步：给 handle_timeout() 加互斥锁，验证死锁是否解决
```

**新会话 load 时：**
1. 读 `📂 关键文件清单` → 直接打开列出的文件（指定了行号范围）
2. 跳过"已排除"的文件
3. 读"当前排查结论" → 秒懂问题状态
4. **不需要重新探索项目结构、不需要重读无关代码**

这样新会话 30 秒内就能接续工作，不需要把 Session A 发现的文件路径再找一遍。

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

### 规则 4.65：远程设备调试凭据管理

当用户需要调试远程设备（SSH、串口、telnet、远程桌面等）时：

**记录阶段：**
1. 用户提供远程信息时，记录到 `current-task.md` 的 `## 关键上下文` 段落：
   ```markdown
   ## 🔐 远程调试（仅本次任务，完成后删除）
   - 方式：SSH
   - 地址：192.168.1.100:22
   - 账号：admin
   - 密码：xxxxxx
   - 备注：生产环境，只读操作
   ```
2. **这些信息只在 `current-task.md` 中记录**——绝不写入 `decisions.md`（会被持久化）或 `architecture.md`

**使用阶段：**
- 任务期间每次远程操作都从 `current-task.md` 读取凭据
- 不需要用户反复提供

**清理阶段：**
- 任务完成后（所有 checkbox 打勾），在清空任务记录时：
  1. **从 `current-task.md` 中删除远程凭据**
  2. 只保留非敏感信息到 `reference/`：设备类型、网络拓扑、调试方式（不含账号密码）
  3. 确认用户："远程调试凭据已从上下文文件中删除"

**重要：绝不将账号密码写入 decisions.md、pitfalls.md、architecture.md 这些持久化文件。**

### 规则 4.7：跨项目任务派发

**触发条件：**

| 触发方式 | 精度 | 说明 |
|---------|------|------|
| `/task-send <路径>` | 🟢 精确 | **推荐。** 直接指定目标路径，跳过 AI 猜测 |
| 自然语言 | 🟡 模糊 | "给 B 派个任务"，AI 需要推断目标路径 |
| AI 主动检测 | 🟡 模糊 | AI 发现跨项目关联时主动询问 |

**推荐使用命令 `/task-send` 而不是自然语言**，确保目标路径准确无误。

**触发后自动执行：**

1. 确认项目 B 的路径（询问用户）
2. 在项目 B 中创建 `.claude/context/tasks/` 目录（如不存在）
3. 生成任务文件 `.claude/context/tasks/from-A-{date}-{summary}.md`：

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
   > 📤 已派发任务到「{项目B}」→ `.claude/context/tasks/from-A-xxx.md`

**在项目 B 的会话中（被派发方）：**

当 `/session-load` 检测到 `.claude/context/tasks/` 下有未处理文件，在摘要中**优先展示**：

```
📨 来自其他项目的排查任务（N 个待处理）

┌─────────────────────────────────────────
│ 来自「IPsec网关」 2026-06-01
│ 问题：IKE 协商失败，怀疑密钥交换模块异常
│ 交互：A 通过 unix socket 调用 B 的 DH 协商
│ 排查：DH 参数生成 / socket 超时 / 状态机
└─────────────────────────────────────────
```

任务处理完后，将文件移到 `.claude/context/tasks/done/`。

**规则 4.7 与规则 5 的组合：**

跨项目 + 跨多层 + 目标未初始化，全自动处理：

```
程序A/子系统/子模块A1 中排查
  │
  ├─ 发现根因在 程序B/子系统/子模块B2（另一个程序，另一个层级）
  ├─ 用户说："给 B/子系统/子模块B2 派个排查任务"
  │
  ├─ 规则 4.7 触发 → 确认目标路径
  ├─ 目标目录没有 .claude/context/ → 规则 5 自动触发
  │     ├─ 初始化 B/子系统/子模块B2 的上下文
  │     └─ 安装 hooks
  ├─ 规则 4.7 继续 → 生成 task 文件
  │     ├─ 来源：程序A/子系统/子模块A1
  │     ├─ 问题：{从A的排查中总结}
  │     ├─ 交互：A→B 的调用链
  │     └─ 排查清单
  │
  ▼
打开 B/子系统/子模块B2 → /session-load
  └─ 优先展示：📨 来自「程序A/子系统/子模块A1」的排查任务
```

**不需要提前在目标目录做任何配置。规则 5 保证目标目录自动初始化，规则 4.7 保证任务文件生成。任意程序、任意层级、任意深度，都能直接派发。**

**A 不需要维护 B 的文件。** A 只做两件事（一次性）：
1. Write 任务文件到 B 的 `.claude/context/tasks/`（写完不管）
2. 在 A 自己的 `current-task.md` 追加一行：`📤 已派发到 B — from-A-xxx.md`

之后 A 正常继续自己的工作。需要知道进度时，`/session-load` 自动检查 B 的 `tasks/done/`，是"等待中"还是"已解决"。**A 和 B 各自维护各自的上下文，互不干扰。**

**如果 A 直接帮 B 排查（不开 B 的会话）：**

无论是否有结论，**都必须回写 B 的任务文件**，防止 B 开会话时看到未处理任务又重复排查：

1. **有结论** → 更新 B 的 `current-task.md` 追加排查结果
2. **发现了 bug** → 追加到 B 的 `pitfalls.md`
3. **做了技术决策** → 追加到 B 的 `decisions.md`
4. **任务完成** → 将 B 的 `tasks/from-A-xxx.md` 移到 `tasks/done/`，末尾追加结论
5. **没结论但排查过** → **不要留空任务**。在 B 的 task 文件末尾追加排查记录：
   ```markdown
   ## 排查记录（来自 A 的会话，{日期}）
   - 已排查范围：{查了哪些文件和函数}
   - 排除的可能性：{排除了什么}
   - 剩余疑点：{还有什么不确定}
   - 建议：{给后续排查者的建议}
   ```
   同时在 A 的 `current-task.md` 记录："已部分排查 B，详情见 B/tasks/from-A-xxx.md"

这样 B 打开会话时看到的是"有人查过了，还剩这些疑点"，而不是"一个没动过的任务"。**避免重复做工。**

6. **查完发现不是 B 的问题** → 将 B 的 task 移到 tasks/done/，末尾写排查结论（确认 B 无问题、排除原因、下一步怀疑谁）。追加到 B 的 decisions.md 记录排除结论。A 的 current-task.md 更新：B 已排除，问题转向 X。后续排查不会再怀疑 B。

这样 B 打开会话时有三种可能：已解决 / 部分进展 / 非本模块。**无论哪种都不会重复做工。**

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
/session-load（根目录，首次）
  │
  ├─ 完整扫描所有子目录，生成 architecture.md（含子模块清单）
  ├─ 询问："检测到以下子模块：A/B/C...，是否为它们也创建独立上下文？"
  │
  └─ 用户确认后，为每个子目录自动执行 mini-init：
       ├── 子目录A/.claude/context/current-task.md
       ├── 子目录A/.claude/context/decisions.md
       ├── 子目录A/.claude/context/pitfalls.md
       └── 子目录A/CLAUDE.md（精简版：只写本目录职责和接口）
```

**嵌套支持：**

分层上下文**天然支持任意深度**。因为 `session-load` 只检查当前目录的 `.claude/context/`，规则 5 也只在当前目录创建文件。

```
大型项目/
├── .claude/context/           # 项目级上下文
├── 子系统/
│   ├── .claude/context/       # 子系统级上下文
│   ├── 子模块A/
│   │   ├── .claude/context/   # 模块级上下文
│   │   └── 子模块A1/
│   │       └── .claude/context/  # 子模块级上下文（任意深）
│   └── 子模块B/
```

每层独立运作。在哪层跑 `/session-load` 就加载哪层的上下文。任务可以在任意两层之间派发（根→最深子模块，同级子模块互发）。

**首次 vs 后续加载（根目录）：**

| | 首次 | 后续 |
|--|------|------|
| 做什么 | 全量扫描：读所有配置文件 + 目录树 + 识别子模块 | 只读缓存 + 快速 diff |
| 读什么 | 每个一级子目录的构建文件、入口文件 | 只 `ls` 一级目录名，对比 architecture.md 缓存 |
| 耗时 | 10-30 秒（取决于项目大小） | 1-2 秒 |
| 产出 | 生成完整 architecture.md + 子模块上下文 | 只输出变更（如有新增/删除的目录） |

**后续 load 的具体操作：**
1. 读取 `architecture.md` 中缓存的子模块清单
2. `ls` 根目录，对比是否有新增或消失的一级目录
3. 有变化 → 按子模块增删检测流程处理
4. 无变化 → 直接呈现摘要（1-2 秒完成）

**不会做的事情：**
- 不会重新扫描子模块内部的代码结构
- 不会重新读取子模块的 `.claude/context/`
- 不会递归进入子目录

**日常使用：**

| 场景 | 操作 | 耗时 | 加载内容 |
|------|------|------|---------|
| 根目录（非首次） | `/session-load` | 1-2 秒 | architecture.md 清单 + 目录 diff + 全局 decisions |
| 子目录 A | `/session-load` | 秒级 | A 的 current-task + decisions + pitfalls |
| A/A1（更深） | `/session-load` | 秒级 | A1 的上下文 |
| 要更新全量架构 | `/context-sync` | 10-30 秒 | 主动触发完整重扫 |

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

每次在根目录运行 `/session-load` 或 `/context-sync` 时，对比当前目录结构和 `architecture.md` 中缓存的子模块清单：

| 检测到的情况 | 自动处理 |
|-------------|---------|
| 新增目录，匹配子模块识别标准 | "检测到新模块 `xxx/`，是否需要创建独立上下文？" → 用户确认后自动初始化 + 更新 architecture.md |
| 新增目录，不匹配识别标准 | 忽略，不询问 |
| 缓存的子模块目录已不存在 | "检测到 `yyy/` 模块已删除，是否从架构文档中移除？" → 用户确认后更新 architecture.md，其 `.claude/context/` 保留不动（手动删除） |
| 缓存的子模块目录还在，但内部结构大变 | "检测到 `zzz/` 模块结构有较大变化，是否需要更新上下文？" |

这样无论用户何时新增或删除功能模块，下一次 load 或 sync 时自动感知变化。

### 规则 5：新项目自动初始化（最重要）

当检测到 `.claude/context/` 目录不存在时，**不要只询问，直接执行初始化**：

1. 告知用户："检测到项目尚未初始化上下文系统，正在自动初始化..."
2. 扫描项目结构：配置文件、顶层目录、源码文件
3. 创建 `.claude/context/` 并生成模板文件（current-task.md、decisions.md、pitfalls.md）
4. 如果 `CLAUDE.md` 不存在，创建精简版
5. **自动安装 hooks**：检查 `.claude/hooks.json` 是否存在，如果不存在则自动创建：
   - 写入 [hooks.json](#hooks-配置) 配置
   - 写入 `.claude/hooks/check-context.sh` 和 `on-file-change.sh` 脚本
6. 如果项目有源码，自动运行 `/context-sync` 生成 `architecture.md`
7. 报告初始化结果

### 规则 6：hooks 自动补装

当项目已有 `.claude/context/` 但缺少 `.claude/hooks.json` 时，在 session-load 时检测并询问，用户确认后写入。

### 规则 6.5：上下文文件瘦身（防止负载膨胀）

`decisions.md` 和 `pitfalls.md` 持续追加会越来越长，load 时占用越来越多上下文。

**瘦身规则：**

| 条件 | 操作 |
|------|------|
| 文件超过 200 行 | 下次 load 时提示："上下文文件已积累较多记录，是否归档旧条目？" |
| 条目超过 6 个月 | 自动移到 `decisions-archive.md` / `pitfalls-archive.md` |
| 用户说"归档" | 手动触发归档 |

**load 时的读取策略（减少上下文占用）：**

| 文件 | 读取方式 | 原因 |
|------|---------|------|
| `current-task.md` | 完整读取 | 覆盖更新，不会膨胀 |
| `decisions.md` | 只读最近 **10 条** | 旧决策基本不会再查 |
| `pitfalls.md` | 只读最近 **10 条** | 旧踩坑已内化为共识 |
| `architecture.md` | 完整读取 | 不会频繁更新，大小稳定 |

读取时如果文件很大，用 `tail -50` 取末尾而不是读全文。

**归档后的结构：**
```
.claude/context/
├── decisions.md              ← 最近 10 条（load 时只读这个）
├── decisions-archive.md      ← 历史决策（需要时可手动查阅）
├── pitfalls.md               ← 最近 10 条
└── pitfalls-archive.md       ← 历史踩坑
```

### 规则 7：分支上下文隔离（支持 SVN 和 Git）

**上下文跟随分支，互不干扰。**

#### SVN 项目（分支是独立目录）

SVN 的每个分支是物理目录副本。**上下文直接在当前工作目录创建。**

```
程序/
├── trunk/
│   └── .claude/context/          ← 只在 trunk 工作才读
├── branches/
│   ├── feature-A/
│   │   └── .claude/context/      ← 切换到 feature-A 才读
│   └── feature-B/                ← 不开就不碰
```

**SVN 规则：**
1. 上下文放在 `$(pwd)/.claude/context/`，只在当前目录
2. 不向上/横向扫描其他分支
3. 跨分支任务 → `/task-send ../branches/feature-A`

#### Git 项目（分支共享工作目录）

Git 的所有分支共享同一个工作目录，需要用分支名隔离上下文文件。

**目录结构：**

```
程序/
├── docs/
│   └── ai-context/               ← 上下文根目录（建议 gitignore）
│       ├── main/                 ← main 分支的上下文
│       │   ├── current-task.md
│       │   ├── decisions.md
│       │   └── pitfalls.md
│       ├── feature-A/            ← feature-A 分支的上下文
│       │   ├── current-task.md
│       │   └── ...
│       └── feature-B/
│
├── .gitignore                    ← 添加 .claude/context/
```

**Git 规则：**

1. **自动检测当前分支** — 每次操作前，用 `git rev-parse --abbrev-ref HEAD` 获取当前分支名
2. **分支子目录** — 上下文文件实际路径为 `.claude/context/{分支名}/current-task.md`
3. **自动切换** — 切换分支后 session-load 自动读取新分支的上下文，无需手动操作
4. **首次进入新分支** — 如果 `.claude/context/{分支名}/` 不存在，自动初始化（不用扫全项目）
5. **gitignore** — 建议把 `.claude/context/` 加入 `.gitignore`，上下文是本地工作记录，不应提交到仓库
6. **架构文档共享** — `architecture.md` 是项目级文件，放在 `.claude/context/` 根层，所有分支共享
7. **跨分支任务派发** — "给 feature-A 分支派个排查任务"，目标路径自动为 `.claude/context/feature-A/`

**自动初始化的智能判断：**

```
/session-load
  │
  ├─ 检测到 .git/ 存在 → Git 项目
  │     └─ git rev-parse --abbrev-ref HEAD → "feature-A"
  │           └─ 上下文路径：.claude/context/feature-A/
  │
  ├─ 检测到 .svn/ 或 trunk/branches/tags → SVN 项目
  │     └─ 上下文路径：$(pwd)/.claude/context/
  │
  └─ 都没有 → 普通目录
        └─ 上下文路径：.claude/context/
```

**首次进入分支的体验：**

```
用户 git checkout -b feature-payment
输入问题

AI（规则 0 自动执行）：
  → git rev-parse → feature-payment
  → .claude/context/feature-payment/ 不存在
  → 规则 5 触发："检测到新分支 feature-payment，正在初始化上下文..."
  → 创建 .claude/context/feature-payment/ 下的模板文件
  → 提示：上下文已就绪，可以开始工作了
```

**无论多少分支，每次只读当前分支的上下文。切换分支自动切换上下文。**

| 文件 | 用途 | 更新策略 |
|------|------|---------|
| `.claude/context/current-task.md` | 任务进度 | **覆盖**更新 |
| `.claude/context/decisions.md` | 技术决策 | **追加** |
| `.claude/context/pitfalls.md` | 踩坑记录 | **追加** |
| `.claude/context/architecture.md` | 项目架构 | context-sync 生成 |

**并发写入安全：** 多会话并行时，每个任务写入独立的 `tasks/results/{task-id}.result.md`，互不冲突。主会话在 `/session-load` 时一次性合并所有结果到共享文件。详见 task-orchestrator 技能。

---

## 命令参考

- `/session-load` → 加载上下文 / 新项目初始化
- `/session-save` → 保存进度
- `/session-end` → 结束会话（健康检查 + 保存）
- `/context-check` → 上下文健康诊断
- `/context-sync` → 同步项目架构文档
- `/task-send <路径>` → 向目标项目/模块派发排查任务（精确模式）

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
# 优先新路径，兼容旧路径
if [ -d "$PROJECT_DIR/.claude/context" ]; then
    CONTEXT_DIR="$PROJECT_DIR/.claude/context"
elif [ -d "$PROJECT_DIR/docs/ai-context" ]; then
    CONTEXT_DIR="$PROJECT_DIR/docs/ai-context"
else
    CONTEXT_DIR="$PROJECT_DIR/.claude/context"
fi
MARKER_FILE="$PROJECT_DIR/.claude/hooks/.context_checked"

if [ ! -d "$CONTEXT_DIR" ] && [ ! -f "$MARKER_FILE" ]; then
    echo ""
    echo "🔍 SKIIS: 项目尚未初始化上下文管理系统"
    echo "   建议运行 /session-load 自动初始化"
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
        echo "   建议运行 /context-sync --deps 更新依赖信息"
        echo ""
        ;;
    *tsconfig.json|*vite.config.*|*next.config.*|*webpack.config.*)
        echo ""
        echo "🔧 SKIIS: 检测到构建配置变更"
        echo "   建议运行 /context-sync 同步架构文档"
        echo ""
        ;;
esac
```

