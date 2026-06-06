# SKIIS 调试总结

> 最后更新: 2026-06-03

---

## 一、`/session-end` 功能说明

结束会话时执行完整收尾流程：

1. **健康评估** — 检测上下文信号（摘要注入、回复质量、路径错误），输出 🟢/🟡/🔴 等级
2. **生成会话摘要** — 成果、决策、遗留问题、下一步
3. **用户确认** — 展示摘要，确认后写入
4. **持久化写入** — `current-task.md` 覆盖更新（含 `🔜 下次继续`），`decisions.md` 和 `pitfalls.md` 追加
5. **输出结束清单** — 健康等级 + 下次恢复命令 `/session-load`

---

## 二、完整规则体系（最终状态）

| 规则 | 名称 | 核心行为 |
| ------ | ------ | --------- |
| 0 | 智能加载 | 先理解问题再加载，简单项目直接加载，复杂项目先定位 |
| 1 | 自动加载 | 已被规则 0 替代，命令保留作为手动补充 |
| 2 | 架构变化提醒 | 目录/依赖变化时提醒同步 |
| 3 | 健康自诊断 | AI 主动检测上下文信号（非轮数），自动汇报 |
| 4 | 工作归档提示 | bug→pitfalls，决策→decisions，模块→current-task |
| 4.5 | 计划自动同步 | AI 生成计划时自动转为 checkbox 清单 |
| 4.51 | 新任务自动捕获 | 任务完成后自动切换到新任务 |
| 4.52 | Bug 修复后自动测试 | 修复 bug 后自动创建单元测试 |
| 4.55 | 关键文件清单 | 保存时记录文件路径+行号，新会话直接定位 |
| 4.6 | 编译环境归档 | 工具安装成功/失败自动记录 |
| 4.65 | 远程凭据管理 | 任务期间记录，完成后删除账号密码 |
| 4.7 | 跨项目任务派发 | A→B 任务传递，含回写和防重复机制 |
| 4.8 | 分层上下文 | 大型项目子模块独立上下文，任意深度 |
| 5 | 新项目自动初始化 | 不询问，直接创建上下文 |
| 6 | hooks 自动补装 | 检测缺失则安装 |
| 6.5 | 文件瘦身 | 归档旧条目，只读最近 10 条 |
| 7 | 分支隔离 | Git 按分支名子目录，SVN 按物理目录 |

---

## 三、调试过程

### 遇到的问题及解决

| # | 问题 | 根因 | 解决 |
| --- | ------ | ------ | ------ |
| 1 | 输入 `/project:session-load` 提示命令不存在 | 命令目录错误，应在 `.claude/commands/project/` | 修正目录结构 |
| 2 | 全局安装后命令不生效 | Claude Code 不支持全局 `commands/`？已支持 | 多次测试确认后修复 |
| 3 | `curl \| bash` 管道安装卡住 | stdin 冲突 + 网络问题 | 改为 `git clone` 方式 |
| 4 | 第一次安装卡住，第二次成功 | raw.githubusercontent.com 国内 DNS 不稳定 | 添加超时+重试，增加 Gitee 镜像 |
| 5 | 测试时 install.sh 被 tty 检测拦截 | 检测逻辑太激进 | 移除 `[ ! -t 0 ]` 检测 |
| 6 | SKILL.md description 解析为 "---" | YAML `>-` 多行折叠语法不兼容 | 改为单行 `"..."` 格式 |
| 7 | 多分支项目上下文混乱 | 缺少分支隔离机制 | 添加规则 7 |
| 8 | 上下文文件被误提交到代码仓库 | 放在 `docs/` 下太显眼 | 移到 `.claude/context/` + 自动 gitignore |
| 9 | 对话健康检测只靠轮数 | 轮数不能反映实际上下文消耗 | 改为检测实际信号（摘要注入、质量衰减等） |
| 10 | 任务全完成后还加载旧任务记录 | 缺少完成检测 | 规则 0 增加任务完成检测，提取关键上下文到 reference/ |
| 11 | Bug 修复后没有自动测试 | 缺少自动测试规则 | 添加规则 4.52：Bug 修复后自动创建单元测试 |

### 未解决/待优化

- install.sh 的 `[1/5]` 与 `[2/6]` 编号不一致（不影响功能）
- task-orchestrator 并行会话启动依赖平台终端命令
- 全局命令在部分环境可能需要重启 Claude Code 才生效

---

## 四、文件结构（最终状态）

```
SKIIS/
├── CLAUDE.md                       # 项目约定
├── README.md                       # 安装和使用说明
├── SKILL-DESIGN.md                 # 技能设计文档（给 CodeX 用）
├── DEBUG-SUMMARY.md                # 本文件
├── install.sh / install.ps1        # 安装脚本
├── session-context.skill           # 技能打包文件
├── test/
│   ├── validate.sh                 # 静态验证（24 项）
│   ├── test-install.sh             # 安装功能测试
│   └── self-test.sh                # 场景自测试（10 场景）
├── .claude/
│   ├── commands/
│   │   ├── context-check.md        # /context-check
│   │   ├── context-sync.md         # /context-sync
│   │   ├── session-end.md          # /session-end
│   │   ├── session-load.md         # /session-load
│   │   ├── session-save.md         # /session-save
│   │   ├── task-send.md            # /task-send
│   │   └── task/
│   │       ├── plan.md             # /task:plan
│   │       └── run.md              # /task:run
│   ├── skills/
│   │   ├── session-context/
│   │   │   ├── SKILL.md            # 主规则（15 条规则）
│   │   │   └── commands/           # 技能内部命令副本
│   │   └── task-orchestrator/
│   │       ├── SKILL.md            # 任务调度规则
│   │       └── commands/
│   ├── hooks.json
│   └── hooks/
│       ├── check-context.sh
│       └── on-file-change.sh
└── .cursor/
    └── rules/                       # Cursor IDE 支持
        ├── context-system.mdc
        ├── context-sync.mdc
        ├── task-delegation.mdc
        └── task-orchestrator.mdc
```

---

## 五、分发

| 平台 | 地址 | 用途 |
| ------ | ------ | ------ |
| GitHub | `github.com/zq88297/SKIIS` | 主仓库 |
| Gitee | `gitee.com/zhang-baishui/skills` | 国内镜像 |

每次 `git push` 自动同步两个平台。
