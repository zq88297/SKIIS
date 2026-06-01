#!/bin/bash
# SKIIS 一键安装脚本 (macOS / Linux / Git Bash)
# 用法:
#   项目安装:  ./install.sh [目标项目路径]
#   全局安装:  ./install.sh --global
#
# 示例:
#   ./install.sh .                 # 安装到当前项目
#   ./install.sh ~/my-project      # 安装到指定项目
#   ./install.sh --global          # 全局安装（所有项目可用）
#
# 远程安装:
#   curl -sLo /tmp/skiis-install.sh https://raw.githubusercontent.com/zq88297/SKIIS/master/install.sh && bash /tmp/skiis-install.sh --global && rm /tmp/skiis-install.sh
#
# 注意：不要使用 curl | bash 管道方式，stdin 冲突会导致卡死。

set -e

# 防护：检测 stdin 是否被管道占用
if [ ! -t 0 ]; then
    echo "⚠️  检测到 stdin 来自管道（如 curl | bash），这种方式可能导致脚本卡死。"
    echo ""
    echo "请改用："
    echo "  curl -sLo /tmp/skiis-install.sh https://raw.githubusercontent.com/zq88297/SKIIS/master/install.sh"
    echo "  bash /tmp/skiis-install.sh --global"
    echo "  rm /tmp/skiis-install.sh"
    echo ""
    exit 1
fi

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
# 1. 安装命令文件 (.claude/commands/project/)
# ============================================
section "1/5" "安装命令文件..."

mkdir -p "$TARGET_DIR/commands/project"

if [ -d "$SCRIPT_DIR/.claude/commands/project" ]; then
    cp -f "$SCRIPT_DIR/.claude/commands/project/"*.md "$TARGET_DIR/commands/project/" 2>/dev/null || true
    ok "5 个命令已安装 (/project:session-load 等)"
else
    warn "未找到命令源文件，请确认从完整仓库运行"
fi

# ============================================
# 2. 安装技能文件
# ============================================
section "2/5" "安装技能文件..."

SKILLS_DIR="$TARGET_DIR/skills/session-context"
mkdir -p "$SKILLS_DIR/commands"

if [ -d "$SCRIPT_DIR/.claude/skills/session-context" ]; then
    cp -rf "$SCRIPT_DIR/.claude/skills/session-context/"* "$SKILLS_DIR/" 2>/dev/null || true
    ok "session-context 技能已安装"
fi

# ============================================
# 3. hooks.json（仅项目安装）
# ============================================
section "3/5" "配置 Hooks..."

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
section "4/5" "安装 Hooks 脚本..."

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
# 5. CLAUDE.md（仅项目安装）
# ============================================
section "5/5" "配置 CLAUDE.md..."

if $IS_GLOBAL; then
    skip "全局安装跳过 CLAUDE.md（属于项目文件）"
else
    CLAUDE_FILE="$TARGET_DIR/CLAUDE.md"
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
fi

# ============================================
# 6. 初始化 docs/ai-context/（仅项目安装 + 首次）
# ============================================
echo ""

if $IS_GLOBAL; then
    echo -e "${GRAY}📂 全局安装完成（仅命令和技能，项目级文件需在项目中单独初始化）${NC}"
else
    CONTEXT_DIR="$TARGET_DIR/docs/ai-context"
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
echo "  ✅ /project:session-load, session-save, session-end"
echo "  ✅ /project:context-check, context-sync"
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
    echo -e "  ${CYAN}/project:session-load${NC}"
fi
echo ""
