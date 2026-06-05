#!/bin/bash
# check-context.sh
# 在 Bash 工具执行前检查上下文文件是否初始化
# 由 .claude/hooks.json 中的 PreToolUse hook 触发

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
# 优先新路径，兼容旧路径
if [ -d "$PROJECT_DIR/.claude/context" ]; then
    CONTEXT_DIR="$PROJECT_DIR/.claude/context"
elif [ -d "$PROJECT_DIR/docs/ai-context" ]; then
    CONTEXT_DIR="$PROJECT_DIR/docs/ai-context"
else
    CONTEXT_DIR="$PROJECT_DIR/.claude/context"
fi

# 静默检查，只在首次发现缺失时输出
MARKER_FILE="$PROJECT_DIR/.claude/hooks/.context_checked"

if [ ! -d "$CONTEXT_DIR" ] && [ ! -f "$MARKER_FILE" ]; then
    echo ""
    echo "🔍 SKIIS: 项目尚未初始化上下文管理系统"
    echo "   建议运行 /context-sync 自动初始化"
    echo ""
    touch "$MARKER_FILE" 2>/dev/null || true
fi
