#!/bin/bash
# SKIIS 一键安装脚本 (macOS / Linux / Git Bash)
# 用法: ./install.sh [目标项目路径]
# 示例: ./install.sh .
#       ./install.sh ~/my-project
#       curl -sL https://raw.githubusercontent.com/zq88297/SKIIS/master/install.sh | bash

set -e

TARGET="${1:-.}"
TARGET="$(cd "$TARGET" 2>/dev/null && pwd || echo "$TARGET")"

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m'

section() { echo -e "${YELLOW}[$1]${NC} ${2}"; }
ok()     { echo -e "  ${GREEN}✅${NC} ${1}"; }
skip()   { echo -e "  ${GRAY}⏭️${NC}  ${1}"; }
warn()   { echo -e "  ${RED}⚠️${NC}  ${1}"; }

echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  SKIIS — Claude Code 上下文管理技能${NC}"
echo -e "${CYAN}  安装脚本${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""
echo "目标项目: $TARGET"
echo ""

# ============================================
# 1. 安装命令文件
# ============================================
section "1/5" "安装命令文件..."

mkdir -p "$TARGET/.claude/commands"

if [ -d "$SCRIPT_DIR/.claude/commands" ]; then
    cp -f "$SCRIPT_DIR/.claude/commands/"*.md "$TARGET/.claude/commands/" 2>/dev/null || true
    ok "命令文件已安装"
fi

# ============================================
# 2. 安装技能文件
# ============================================
section "2/5" "安装技能文件..."

SKILLS_DIR="$TARGET/.claude/skills/session-context"
mkdir -p "$SKILLS_DIR/commands"

if [ -d "$SCRIPT_DIR/.claude/skills/session-context" ]; then
    cp -rf "$SCRIPT_DIR/.claude/skills/session-context/"* "$SKILLS_DIR/" 2>/dev/null || true
    ok "session-context 技能已安装"
fi

# ============================================
# 3. 智能合并 hooks.json
# ============================================
section "3/5" "配置 Hooks（智能合并）..."

HOOKS_FILE="$TARGET/.claude/hooks.json"
SKIIS_MARKER="SKIIS"

if [ -f "$HOOKS_FILE" ]; then
    if grep -q "$SKIIS_MARKER" "$HOOKS_FILE" 2>/dev/null; then
        skip "hooks.json 已包含 SKIIS 配置，跳过"
    else
        # 尝试用 Python 合并，失败则用备份策略
        if command -v python3 &>/dev/null; then
            python3 -c "
import json, sys
try:
    with open('$HOOKS_FILE', 'r') as f:
        existing = json.load(f)
except:
    # 解析失败，备份后覆盖
    import shutil
    shutil.copy('$HOOKS_FILE', '$HOOKS_FILE.bak')
    print('BACKUP')
    sys.exit(0)

# 确保 hooks 键存在
if 'hooks' not in existing:
    existing['hooks'] = {}

# 合并 PostToolUse
if 'PostToolUse' not in existing['hooks']:
    existing['hooks']['PostToolUse'] = []
existing['hooks']['PostToolUse'].append({
    'matcher': 'Write|Edit',
    'command': 'bash \${CLAUDE_PROJECT_DIR}/.claude/hooks/on-file-change.sh'
})

# 合并 PreToolUse
if 'PreToolUse' not in existing['hooks']:
    existing['hooks']['PreToolUse'] = []
existing['hooks']['PreToolUse'].append({
    'matcher': 'Bash',
    'command': 'bash \${CLAUDE_PROJECT_DIR}/.claude/hooks/check-context.sh'
})

# 更新 description
if 'SKIIS' not in existing.get('description', ''):
    existing['description'] = existing.get('description', '') + ' + SKIIS'

with open('$HOOKS_FILE', 'w') as f:
    json.dump(existing, f, indent=2, ensure_ascii=False)
print('MERGED')
" 2>&1
            merge_result=$?
            if [ $merge_result -eq 0 ]; then
                ok "hooks.json 已合并（保留原有配置）"
            fi
        else
            # 无 Python，备份后覆盖
            cp "$HOOKS_FILE" "$HOOKS_FILE.bak"
            warn "无 Python 环境，hooks.json 已备份为 .bak 后覆盖"
        fi
    fi
else
    mkdir -p "$TARGET/.claude"
    cat > "$HOOKS_FILE" << 'HOOKSEOF'
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
HOOKSEOF
    ok "hooks.json 已创建"
fi

# ============================================
# 4. 安装 hooks 脚本
# ============================================
section "4/5" "安装 Hooks 脚本..."

mkdir -p "$TARGET/.claude/hooks"

if [ -d "$SCRIPT_DIR/.claude/hooks" ]; then
    cp -f "$SCRIPT_DIR/.claude/hooks/"*.sh "$TARGET/.claude/hooks/" 2>/dev/null || true
    chmod +x "$TARGET/.claude/hooks/"*.sh 2>/dev/null || true
    ok "hooks 脚本已安装"
fi

# ============================================
# 5. 智能合并 CLAUDE.md
# ============================================
section "5/5" "配置 CLAUDE.md（智能合并）..."

CLAUDE_FILE="$TARGET/CLAUDE.md"
SECTION_MARKER="## 自动上下文管理规则"

SKIIS_SECTION='
---

## 自动上下文管理规则

以下规则在每次对话中自动生效，无需用户手动触发：

### 规则 1：启动时自动加载上下文
每次新对话开始时，如果用户没有提供明确任务，立即执行：
1. 检查并读取 docs/ai-context/current-task.md
2. 读取 docs/ai-context/decisions.md（最近 5 条）
3. 读取 docs/ai-context/pitfalls.md（最近 5 条）
4. 向用户呈现上下文摘要，询问"请告诉我需要做什么"

如果上述文件不存在，主动提示用户初始化。

### 规则 2：架构变化时自动提醒
- 新增/删除顶层目录 → 提醒运行 /project:context-sync
- 安装新核心依赖 → 提醒运行 /project:context-sync --deps
- 切换技术方案 → 提醒记录到 decisions.md

### 规则 3：对话疲劳自动预警
- 超过 15 轮对话 → 提醒保存进度
- AI 发现自身回复矛盾或不确定 → 警告并建议新会话

### 规则 4：工作产出自动归档提示
- 修复 bug → 提示记录到 pitfalls.md
- 技术决策 → 提示追加到 decisions.md
- 完成功能模块 → 提示更新 current-task.md

### 规则 5：新项目自动初始化
检测到 docs/ai-context/ 不存在且项目有源码时，自动扫描并初始化上下文管理系统。

## 上下文管理规范

1. 每次新对话自动加载上下文（见规则 1）
2. 对话超过 15 轮主动提醒保存（见规则 3）
3. 项目结构变化时提醒同步（见规则 2）
4. 重要决策后提醒记录（见规则 4）

## 可用命令

| 命令 | 用途 |
|------|------|
| `/project:session-load` | 加载已保存的上下文 |
| `/project:session-save` | 保存当前进度 |
| `/project:session-end` | 结束会话（健康检查 + 保存） |
| `/project:context-check` | 上下文健康度诊断 |
| `/project:context-sync` | 同步项目架构文档 |
'

if [ -f "$CLAUDE_FILE" ]; then
    if grep -qF "$SECTION_MARKER" "$CLAUDE_FILE" 2>/dev/null; then
        skip "CLAUDE.md 已包含 SKIIS 规则，跳过"
    else
        echo "$SKIIS_SECTION" >> "$CLAUDE_FILE"
        ok "CLAUDE.md 已追加 SKIIS 规则（保留原有内容）"
    fi
else
    echo "$SKIIS_SECTION" > "$CLAUDE_FILE"
    ok "CLAUDE.md 已创建"
fi

# ============================================
# 6. 初始化 docs/ai-context/（仅首次）
# ============================================
echo ""

CONTEXT_DIR="$TARGET/docs/ai-context"
if [ ! -d "$CONTEXT_DIR" ]; then
    echo -e "${CYAN}🔍 首次安装，初始化上下文目录...${NC}"
    mkdir -p "$CONTEXT_DIR"

    cat > "$CONTEXT_DIR/current-task.md" << EOF
> 最后更新: $(date '+%Y-%m-%d %H:%M')

# 当前任务

## 已完成
暂无

## 进行中
暂无

## 待完成
暂无

## 关键上下文
暂无
EOF

    cat > "$CONTEXT_DIR/decisions.md" << EOF
# 技术决策记录

记录项目中的关键技术选择及原因。每条决策包含：编号、日期、背景、选项、选择、原因。
EOF

    cat > "$CONTEXT_DIR/pitfalls.md" << EOF
# 踩坑记录

记录遇到的问题和解决方案，避免重复踩坑。
EOF

    ok "docs/ai-context/ 已初始化"
else
    echo -e "${GRAY}📂 docs/ai-context/ 已存在，保留用户数据${NC}"
fi

# ============================================
# 完成
# ============================================
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  SKIIS 安装完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "已安装:"
echo "  ✅ 5 个命令: /project:session-{load,save,end} /project:context-{check,sync}"
echo "  ✅ hooks.json (智能合并)"
echo "  ✅ hooks 脚本"
echo "  ✅ CLAUDE.md (智能合并)"
[ -d "$CONTEXT_DIR" ] && echo "  ✅ docs/ai-context/"
echo ""
echo "下次启动 Claude Code 时输入:"
echo -e "  ${CYAN}/project:session-load${NC}"
echo ""
