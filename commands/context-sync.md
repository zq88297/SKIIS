# 项目上下文自动同步

你是项目上下文同步器。通过扫描项目文件和代码结构，自动更新项目概述文件，确保 `.claude/context/architecture.md` 始终反映项目真实状态。首次运行时会自动初始化完整的上下文文件结构。

## 参数说明

`$ARGUMENTS` 支持以下模式：
- 无参数：全量同步
- `--quick`：仅同步项目结构和依赖变化
- `--deps`：仅同步依赖变化
- `--structure`：仅同步目录结构
- `--force`：强制重新生成，忽略已有的 architecture.md

## 执行流程

### Phase 0：首次运行检测

检查 `.claude/context/` 目录是否存在。

**检测逻辑：**

使用 Glob 或 Bash 检查：
- `.claude/context/` 目录是否存在
- `CLAUDE.md` 是否存在

根据检测结果分支处理：

**分支 A：目录不存在（首次运行）→ 跳转到「首次初始化」**

向用户确认：

```
🔍 检测到项目尚未初始化上下文管理系统

是否需要初始化？
- 将创建 .claude/context/ 目录
- 将创建 CLAUDE.md 项目概述
- 将创建完整的架构文档
```

用户确认后执行首次初始化（见下方独立章节），然后跳转到 Phase 4 输出报告。

**分支 B：目录存在但 architecture.md 不存在 → 增量初始化**

```
📄 检测到上下文目录已存在，但缺少 architecture.md
将补建架构文档。
```

跳转到 Phase 2 正常生成流程。

**分支 C：所有文件正常 → 正常同步**

跳转到 Phase 1 继续原有流程。

---

### 首次初始化（分支 A 执行）

按顺序执行以下步骤：

#### 步骤 1：创建目录结构

```bash
mkdir -p .claude/context
```

#### 步骤 2：采集项目基础信息

读取以下文件（存在就读，不存在跳过）：

- `package.json` — 项目名、描述、依赖、脚本
- `pyproject.toml` — Python 项目
- `Cargo.toml` — Rust 项目
- `go.mod` — Go 项目
- `pom.xml` — Java Maven
- `build.gradle` — Java Gradle

如果以上文件全部不存在，检查是否为空目录：

```bash
# 列出当前目录所有文件
ls -la
# 检查是否有源码文件
find . -maxdepth 3 -type f \
  \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" \
  -o -name "*.py" -o -name "*.go" -o -name "*.rs" \
  -o -name "*.java" -o -name "*.vue" -o -name "*.svelte" \) \
  2>/dev/null | head -50
```

根据采集结果自动判断：

| 检测结果 | 项目类型 | 技术栈 |
| --------- | --------- | -------- |
| 有 package.json + tsconfig.json | TypeScript 前端/Node | 读取框架特征继续判断 |
| 有 package.json + src/app/ | Next.js App Router | React + Next.js |
| 有 package.json + src/views/ | Vue 项目 | Vue 3 + Vite |
| 有 pyproject.toml | Python 项目 | 读取依赖判断框架 |
| 有 Cargo.toml | Rust 项目 | Rust |
| 有 go.mod | Go 项目 | Go |
| 全部都没有 | 空项目 / 未知 | 待补充 |

#### 步骤 3：生成 CLAUDE.md

```markdown
# CLAUDE.md

## 项目概述
- **项目名称**：{从配置文件读取，没有则询问用户}
- **项目类型**：{自动判断}
- **技术栈**：{自动判断}
- **当前状态**：新项目，刚初始化

## 代码结构
{基于扫描到的目录生成，如果目录为空则提示用户后续补充}

## 关键约定
{从 .eslintrc / .prettierrc 等读取，没有则留空待补充}

## 上下文管理规范

1. 每次新对话开始时，运行 /session-load 加载上下文
2. 项目结构发生较大变化时，运行 /context-sync 同步架构文档
3. 对话超过 20 轮时，主动提醒保存上下文
4. 重要决策做出后，记录到 .claude/context/decisions.md
```

#### 步骤 4：生成 context-template.md（项目骨架模板）

对于新项目，额外生成一份可编辑的骨架模板：

```markdown
# 项目规划模板

> 此文件为新项目初始化时生成的规划模板。
> 请根据实际需求编辑后，信息会反映到 architecture.md 中。

## 预计目录结构

```
src/
├── components/    # UI 组件
├── pages/         # 页面
├── hooks/         # 自定义 Hooks
├── api/           # 接口请求
├── store/         # 状态管理
├── utils/         # 工具函数
└── types/         # 类型定义
```

## 技术选型

| 类别 | 选择 | 备选方案 | 选择原因 |
| ------ | ------ | --------- | --------- |
| 框架 | {自动填入} | | |
| 状态管理 | 待定 | Zustand / Pinia / Redux | |
| 样式方案 | 待定 | Tailwind / CSS Modules | |
| 数据请求 | 待定 | Axios / SWR / TanStack Query | |
| 测试 | 待定 | Vitest / Jest | |

## 开发计划

- [ ] 项目初始化
- [ ] 基础目录搭建
- [ ] 核心模块开发
- [ ] 测试编写
- [ ] 部署配置
```

#### 步骤 5：生成空模板文件

创建以下文件：

- `.claude/context/current-task.md`:
  ```markdown
  # 当前任务

  > 暂无进行中的任务
  ```

- `.claude/context/decisions.md`:
  ```markdown
  # 技术决策记录

  > 记录项目中的关键技术选择及原因
  ```

- `.claude/context/pitfalls.md`:
  ```markdown
  # 踩坑记录

  > 记录遇到的问题和解决方案
  ```

#### 步骤 6：生成 architecture.md

基于采集到的信息，按 Phase 2 的模板生成。
如果项目为空，生成占位版本：

```markdown
# 项目概述

> 此文件由 /context-sync 自动生成
> 最后更新：{日期}

## 基本信息

- **项目名称**：{name}
- **项目类型**：待补充
- **技术栈**：待补充
- **当前状态**：新项目初始化

## 目录结构

（项目暂无源码文件，目录结构将在首次提交代码后自动更新）

## 模块划分

| 目录 | 职责 | 状态 |
|------|------|------|
| 待创建 | 待补充 | ⏳ |

## 核心依赖

{从配置文件读取，如果也没有则显示"待补充"}

## 架构模式

- **组件模式**：待确定
- **状态管理**：待确定
- **样式方案**：待确定

## 待办事项

- [ ] 确定项目目录结构
- [ ] 确定核心依赖
- [ ] 编写 CLAUDE.md 详细约定
- [ ] 首次运行 /context-sync 同步架构
```

---

### Phase 1：项目信息采集

#### 1.1 读取项目配置文件

按优先级依次读取以下文件（存在就读）：

**包管理与构建：**
- `package.json` — 依赖、脚本、项目名
- `pnpm-workspace.yaml` — monorepo 配置
- `lerna.json` — monorepo 配置
- `pyproject.toml` — Python 项目配置
- `Cargo.toml` — Rust 项目配置
- `go.mod` — Go 项目配置

**TypeScript/JavaScript：**
- `tsconfig.json` — TS 配置、路径别名
- `tsconfig.paths.json` — 额外路径映射
- `vite.config.ts` — Vite 配置
- `next.config.js` — Next.js 配置
- `webpack.config.js` — Webpack 配置

**代码规范：**
- `.eslintrc.*` — Lint 规则
- `.prettierrc.*` — 格式化规则
- `tailwind.config.*` — CSS 框架配置

**CI/CD：**
- `.github/workflows/*.yml` — GitHub Actions
- `.gitlab-ci.yml` — GitLab CI
- `Dockerfile` — 容器化配置

**现有上下文文件：**
- `.claude/context/architecture.md` — 已有的项目概述
- `.claude/context/current-task.md` — 当前任务

#### 1.2 扫描目录结构

使用 Glob 工具获取项目结构（排除 `node_modules`、`dist`、`.git` 等目录），获取前 3 层深度。

使用 Glob 获取源码文件统计（`*.ts`、`*.tsx`、`*.js`、`*.jsx`、`*.vue`、`*.py`、`*.go` 等）。

#### 1.3 识别技术栈特征

分析代码中的关键模式：

**框架识别 — 查找特征文件：**
- `src/app/` → Next.js App Router
- `src/pages/` → Next.js Pages Router 或 Nuxt
- `src/views/` → Vue 项目
- `src/main.ts` → Vue/React 标准入口
- `app.py` / `main.py` → Python 项目
- `cmd/` → Go 项目

**状态管理识别：**
- `*store*` → Vuex / Pinia / Zustand / Redux
- `*context*` → React Context
- `*atom*` → Jotai
- `*recoil*` → Recoil

**样式方案识别：**
- `*.module.css` → CSS Modules
- `*.module.scss` → SCSS Modules
- `tailwind.config.*` → Tailwind CSS
- `styled.*` → Styled Components / Emotion
- `*.scss` → SCSS
- `*.less` → Less

**API 层识别：**
- `src/api/` → API 封装层
- `src/services/` → 服务层
- `src/repositories/` → 数据访问层

**测试识别：**
- `*.test.ts` → 单元测试
- `*.spec.ts` → 单元测试
- `__tests__/` → 测试目录
- `e2e/` → E2E 测试

---

### Phase 2：生成/更新架构文档

读取已有的 `.claude/context/architecture.md`（如果存在），基于采集到的信息生成更新版本。

**文档模板（覆盖写入）：**

```markdown
# 项目概述

> 此文件由 /context-sync 自动生成，请勿手动修改。
> 最后更新：{当前日期时间}

## 基本信息

- **项目名称**：{从 package.json / pyproject.toml 等读取}
- **项目类型**：{前端/后端/全栈/CLI 工具/库}
- **技术栈**：{主要语言和框架}
- **包管理器**：{pnpm / npm / yarn / pip / cargo}
- **构建工具**：{Vite / Webpack / Next.js / esbuild / Cargo}

## 目录结构

{生成的目录树，只保留前 3 层深度}

## 模块划分

| 目录 | 职责 | 关键文件数 |
| ------ | ------ | ----------- |
| src/components/ | 通用 UI 组件 | {N} 个文件 |
| src/pages/ | 页面组件 | {N} 个文件 |
| ... | ... | ... |

## 核心依赖

### 运行时依赖

| 依赖 | 版本 | 用途 |
| ------ | ------ | ------ |
| react | ^18.x | UI 框架 |
| zustand | ^4.x | 状态管理 |
| ... | ... | ... |

### 开发依赖（仅列出关键工具）

| 依赖 | 用途 |
| ------ | ------ |
| typescript | 类型系统 |
| vite | 构建工具 |
| vitest | 单元测试 |
| eslint | 代码规范 |

## 架构模式

{基于代码分析识别出的模式，例如：}

- **组件模式**：{函数式组件 + Hooks / Class 组件 / Composition API}
- **状态管理**：{Zustand / Redux / Pinia / 无全局状态}
- **数据流**：{单向数据流 / 响应式 / 状态机}
- **样式方案**：{Tailwind CSS / CSS Modules / Styled Components}
- **API 层**：{REST / GraphQL / tRPC / 无后端}
- **路由方案**：{React Router / Next.js App Router / 文件路由}
- **测试策略**：{Jest / Vitest / pytest / 无测试}

## 代码规范

- **格式化工具**：{Prettier / Black}
- **Linter**：{ESLint 规则集 / Ruff}
- **Git 规范**：{conventional commits / 无特殊要求}

## 环境变量

{从 .env.example 或代码中识别出的关键环境变量}

| 变量名 | 用途 | 必填 |
| -------- | ------ | ------ |
| API_BASE_URL | 后端 API 地址 | 是 |
| ... | ... | ... |

## 脚本命令

{从 package.json scripts 或 Makefile 中读取}

| 命令 | 用途 |
| ------ | ------ |
| pnpm dev | 启动开发服务器 |
| pnpm build | 构建生产版本 |
| pnpm test | 运行测试 |
| ... | ... |
```

---

### Phase 3：变更对比

对比已有文档和新生成的内容，突出变更：

```
📝 architecture.md 更新内容

## 变更摘要
- 技术栈：[无变化 / 新增 XXX]
- 目录结构：[无变化 / 新增/删除了以下目录]
  - ➕ src/features/user/ （新增）
  - ➕ src/features/order/ （新增）
- 依赖变化：
  - ➕ zustand 4.5.0 （新增）
  - 🔄 react 18.2.0 → 18.3.0 （升级）
  - ➖ moment （已移除）
- 模式变化：[无变化 / 例如：状态管理从 Redux 切换到 Zustand]

确认写入？
```

等待用户确认后，写入 `.claude/context/architecture.md`。

---

### Phase 4：交叉更新

如果检测到架构变化影响了其他上下文文件，提示用户：

```
⚠️ 以下文件可能需要同步更新：

1. decisions.md
   - 检测到状态管理方案变更，是否需要记录决策？

2. current-task.md
   - 检测到新增模块目录，是否需要更新任务进度？

3. CLAUDE.md
   - 检测到技术栈变化，是否需要更新项目概述？
```

---

### Phase 5：输出最终报告

```
✅ 项目上下文同步完成

📄 已更新
- .claude/context/architecture.md

📊 项目快照
- 语言：TypeScript
- 框架：React 18 + Vite
- 模块数：12
- 源码文件：87 个
- 依赖数：23 个运行时 / 15 个开发

⏭️ 可选下一步
- 运行 /context-check 检查整体上下文健康度
- 运行 /session-save 保存当前任务状态
```

---

## 使用方式

```bash
# 全量同步（推荐）
/context-sync

# 只同步依赖变化（比如刚装了新包）
/context-sync --deps

# 只同步目录结构
/context-sync --structure

# 快速同步
/context-sync --quick

# 强制重新生成
/context-sync --force
```

## 自动触发建议

在 CLAUDE.md 中添加以下规则，让 Claude 在关键节点自动提醒用户同步：

```markdown
## 自动提醒规则

在以下时机，主动提醒用户运行 /context-sync：
- 新增或删除了顶层目录
- 安装或卸载了核心依赖
- 切换了技术方案（如状态管理、样式框架）
- 完成了一个大的功能模块后
```

