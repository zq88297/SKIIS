#!/bin/bash
# SKIIS 安装脚本 (macOS / Linux / Git Bash)
#
# 用法（需先 git clone 仓库）:
#   git clone https://github.com/zq88297/SKIIS.git && cd SKIIS
#
#   项目安装:  bash install.sh [目标路径]
#   全局安装:  bash install.sh --global
#
# 示例:
#   bash install.sh .                 # 安装到当前项目
#   bash install.sh ~/my-project      # 安装到指定项目
#   bash install.sh --global          # 全局安装（skill 放到 ~/.claude/skills/）
#
# 注意：不要使用 curl|bash 管道方式，脚本需要从仓库目录读取源文件。

set -e

# 注意：不要使用 curl|bash 管道方式，请先 git clone 再运行。
# git clone https://github.com/zq88297/SKIIS.git && cd SKIIS && bash install.sh --global

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
MAGENTA='\033[0;35m'
NC='\033[0m'

section() { echo -e "${YELLOW}[$1]${NC} ${2}"; }
ok()     { echo -e "  ${GREEN}✅${NC} ${1}"; }
skip()   { echo -e "  ${GRAY}⏭️${NC}  ${1}"; }
warn()   { echo -e "  ${RED}⚠️${NC}  ${1}"; }

# 检查参数
IS_GLOBAL=false
TARGET="."

for arg in "$@"; do
    case "$arg" in
        --global|-g)
            IS_GLOBAL=true
            ;;
        *)
            TARGET="$arg"
            ;;
    esac
done

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 检查源文件是否完整（防止单独下载脚本运行导致找不到源文件）
if [ ! -d "$SCRIPT_DIR/.claude/commands" ] || [ ! -d "$SCRIPT_DIR/.claude/skills/session-context" ]; then
    echo -e "${YELLOW}🔍 检测到脚本不在完整仓库中，正在自动克隆...${NC}"
    TEMP_REPO="/tmp/skiis-repo-$$"
    git clone --depth 1 https://github.com/zq88297/SKIIS.git "$TEMP_REPO" 2>/dev/null || {
        echo -e "${RED}❌ 克隆失败，请手动运行:${NC}"
        echo "  git clone https://github.com/zq88297/SKIIS.git && cd SKIIS && bash install.sh --global"
        exit 1
    }
    SCRIPT_DIR="$TEMP_REPO"
    CLEANUP_TEMP=true
fi

if $IS_GLOBAL; then
    TARGET_DIR="$HOME/.claude"
else
    TARGET_DIR="$(cd "$TARGET" 2>/dev/null && pwd || echo "$TARGET")"
fi

echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  SKIIS — Claude Code 上下文管理技能${NC}"
if $IS_GLOBAL; then
    echo -e "${MAGENTA}  全局安装（所有项目可用）${NC}"
else
    echo -e "${CYAN}  项目安装${NC}"
fi
echo -e "${CYAN}========================================${NC}"
echo ""
echo "安装目录: $TARGET_DIR"
echo ""

# ============================================
# 1. 安装命令文件 (.claude/commands/)
# ============================================
section "1/5" "安装命令文件..."

mkdir -p "$TARGET_DIR/commands/task"

if [ -d "$SCRIPT_DIR/.claude/commands" ]; then
    cp -f "$SCRIPT_DIR/.claude/commands/"*.md "$TARGET_DIR/commands/" 2>/dev/null || true
    cp -f "$SCRIPT_DIR/.claude/commands/task/"*.md "$TARGET_DIR/commands/task/" 2>/dev/null || true
    ok "命令已安装 (/session-load, /context-sync, /task-send, /task:plan, /task:run 等)"
else
    warn "未找到命令源文件，请确认从完整仓库运行"
fi

# ============================================
# 2. 安装技能文件
# ============================================
# .cursor/rules/（Cursor IDE 支持）
mkdir -p "$TARGET_DIR/.cursor/rules"
if [ -d "$SCRIPT_DIR/.cursor/rules" ]; then
    cp -f "$SCRIPT_DIR/.cursor/rules/"*.mdc "$TARGET_DIR/.cursor/rules/" 2>/dev/null || true
    ok "Cursor 规则已安装 (.cursor/rules/*.mdc)"
fi

section "2/6" "安装技能文件..."

# session-context
SKILLS_DIR="$TARGET_DIR/skills/session-context"
mkdir -p "$SKILLS_DIR/commands"
if [ -d "$SCRIPT_DIR/.claude/skills/session-context" ]; then
    cp -rf "$SCRIPT_DIR/.claude/skills/session-context/"* "$SKILLS_DIR/" 2>/dev/null || true
    ok "session-context 技能已安装"
fi

# task-orchestrator
ORCH_DIR="$TARGET_DIR/skills/task-orchestrator"
mkdir -p "$ORCH_DIR/commands"
if [ -d "$SCRIPT_DIR/.claude/skills/task-orchestrator" ]; then
    cp -rf "$SCRIPT_DIR/.claude/skills/task-orchestrator/"* "$ORCH_DIR/" 2>/dev/null || true
    ok "task-orchestrator 技能已安装"
fi

# project-workflow
PW_DIR="$TARGET_DIR/skills/project-workflow"
mkdir -p "$PW_DIR/commands"
if [ -d "$SCRIPT_DIR/.claude/skills/project-workflow" ]; then
    cp -rf "$SCRIPT_DIR/.claude/skills/project-workflow/"* "$PW_DIR/" 2>/dev/null || true
    ok "project-workflow 技能已安装"
fi

# ============================================
# 3. hooks.json（仅项目安装）
# ============================================
section "3/6" "配置 Hooks..."

if $IS_GLOBAL; then
    skip "全局安装跳过 hooks（hooks 属于项目级配置）"
else
    HOOKS_FILE="$TARGET_DIR/hooks.json"
    SKIIS_MARKER="SKIIS"

    if [ -f "$HOOKS_FILE" ]; then
        if grep -q "$SKIIS_MARKER" "$HOOKS_FILE" 2>/dev/null; then
            skip "hooks.json 已包含 SKIIS 配置，跳过"
        else
            if command -v python3 &>/dev/null; then
                python3 -c "
import json
with open('$HOOKS_FILE', 'r') as f:
    existing = json.load(f)
if 'hooks' not in existing:
    existing['hooks'] = {}
if 'PostToolUse' not in existing['hooks']:
    existing['hooks']['PostToolUse'] = []
existing['hooks']['PostToolUse'].append({
    'matcher': 'Write|Edit',
    'command': 'bash \${CLAUDE_PROJECT_DIR}/.claude/hooks/on-file-change.sh'
})
if 'PreToolUse' not in existing['hooks']:
    existing['hooks']['PreToolUse'] = []
existing['hooks']['PreToolUse'].append({
    'matcher': 'Bash',
    'command': 'bash \${CLAUDE_PROJECT_DIR}/.claude/hooks/check-context.sh'
})
if 'SKIIS' not in existing.get('description', ''):
    existing['description'] = existing.get('description', '') + ' + SKIIS'
with open('$HOOKS_FILE', 'w') as f:
    json.dump(existing, f, indent=2, ensure_ascii=False)
" 2>/dev/null && ok "hooks.json 已合并（保留原有配置）" || {
                    cp "$HOOKS_FILE" "$HOOKS_FILE.bak"
                    warn "Python 不可用，hooks.json 已备份为 .bak"
                }
            else
                cp "$HOOKS_FILE" "$HOOKS_FILE.bak"
                warn "无 Python，hooks.json 已备份为 .bak"
            fi
        fi
    else
        mkdir -p "$(dirname "$HOOKS_FILE")"
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
fi

# ============================================
# 4. hooks 脚本（仅项目安装）
# ============================================
section "4/6" "安装 Hooks 脚本..."

if $IS_GLOBAL; then
    skip "全局安装跳过 hooks 脚本"
else
    mkdir -p "$TARGET_DIR/hooks"
    if [ -d "$SCRIPT_DIR/.claude/hooks" ]; then
        cp -f "$SCRIPT_DIR/.claude/hooks/"*.sh "$TARGET_DIR/hooks/" 2>/dev/null || true
        chmod +x "$TARGET_DIR/hooks/"*.sh 2>/dev/null || true
        ok "hooks 脚本已安装"
    fi
fi

# ============================================
# 5. CLAUDE.md（仅项目安装，精简版）
#   自动规则已在全局 SKILL.md 中，CLAUDE.md 只需引用
# ============================================
section "5/6" "配置 CLAUDE.md..."

if $IS_GLOBAL; then
    skip "全局安装跳过（自动规则已在全局 skill 中生效）"
else
    CLAUDE_FILE="$TARGET_DIR/CLAUDE.md"
    SKIIS_MARKER="session-context"

    SKIIS_LINE='
## 上下文管理

本项目使用 SKIIS 上下文管理系统（已全局安装）。可用命令：
`/session-load` `/session-save` `/session-end` `/context-check` `/context-sync`
'

    if [ -f "$CLAUDE_FILE" ]; then
        if grep -qF "$SKIIS_MARKER" "$CLAUDE_FILE" 2>/dev/null; then
            skip "CLAUDE.md 已包含 SKIIS 引用，跳过"
        else
            echo "$SKIIS_LINE" >> "$CLAUDE_FILE"
            ok "CLAUDE.md 已追加 SKIIS 引用"
        fi
    else
        echo "$SKIIS_LINE" > "$CLAUDE_FILE"
        ok "CLAUDE.md 已创建"
    fi
fi

# ============================================
# 6. 初始化上下文目录（仅项目安装 + 首次）
#    新路径：.claude/context/（防误提交），兼容旧路径 docs/ai-context/
# ============================================
echo ""

if $IS_GLOBAL; then
    echo -e "${GRAY}📂 全局安装完成（仅命令和技能，项目级文件需在项目中单独初始化）${NC}"
else
    # 优先新路径，兼容旧路径
    if [ -d "$TARGET_DIR/docs/ai-context" ]; then
        CONTEXT_DIR="$TARGET_DIR/docs/ai-context"
        echo -e "${GRAY}📂 检测到旧路径 docs/ai-context/，继续使用${NC}"
    else
        CONTEXT_DIR="$TARGET_DIR/.claude/context"
    fi

    if [ ! -d "$CONTEXT_DIR" ]; then
        echo -e "${CYAN}🔍 首次安装，初始化上下文目录...${NC}"
        mkdir -p "$CONTEXT_DIR"
        mkdir -p "$CONTEXT_DIR/reference"
        mkdir -p "$CONTEXT_DIR/tasks"

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

        # 自动加入 .gitignore（Git 项目）
        if [ -d "$TARGET_DIR/.git" ]; then
            if ! grep -q ".claude/context" "$TARGET_DIR/.gitignore" 2>/dev/null; then
                echo "" >> "$TARGET_DIR/.gitignore" 2>/dev/null || true
                echo "# SKIIS 上下文文件（本地工作记录，不提交）" >> "$TARGET_DIR/.gitignore" 2>/dev/null || true
                echo ".claude/context/" >> "$TARGET_DIR/.gitignore" 2>/dev/null || true
                echo ".claude/context/*" >> "$TARGET_DIR/.gitignore" 2>/dev/null || true
                ok "已自动将 .claude/context/ 加入 .gitignore"
            fi
        fi

        # 自动设置 svn:ignore（SVN 项目）
        if [ -d "$TARGET_DIR/.svn" ]; then
            svn propset svn:ignore ".claude/context" "$TARGET_DIR/.claude/" 2>/dev/null || true
            ok "已自动设置 svn:ignore"
        fi

        ok "上下文目录已初始化 ($CONTEXT_DIR)"
    else
        echo -e "${GRAY}📂 上下文目录已存在，保留用户数据${NC}"
    fi
fi

# ============================================
# 清理临时仓库
# ============================================
if [ "$CLEANUP_TEMP" = "true" ] && [ -d "$TEMP_REPO" ]; then
    rm -rf "$TEMP_REPO"
fi

# ============================================
# 完成
# ============================================
echo ""
echo -e "${GREEN}========================================${NC}"
if $IS_GLOBAL; then
    echo -e "${GREEN}  SKIIS 全局安装完成！${NC}"
else
    echo -e "${GREEN}  SKIIS 安装完成！${NC}"
fi
echo -e "${GREEN}========================================${NC}"
echo ""
echo "已安装:"
echo "  ✅ /session-load, session-save, session-end"
echo "  ✅ /context-check, context-sync"
if ! $IS_GLOBAL; then
    echo "  ✅ hooks.json (智能合并)"
    echo "  ✅ hooks 脚本"
    echo "  ✅ CLAUDE.md (智能合并)"
fi
echo ""

if $IS_GLOBAL; then
    echo -e "${CYAN}任何项目中都可以直接使用 /project:xxx 命令了${NC}"
    echo ""
    echo -e "${YELLOW}💡 在具体项目中运行${NC}"
    echo -e "   ./install.sh .    （安装项目级 hooks、CLAUDE.md、上下文目录）"
else
    echo "重启 Claude Code，输入:"
    echo -e "  ${CYAN}/session-load${NC}"
fi
echo ""
