#!/bin/bash
# on-file-change.sh
# 在文件写入/编辑后检查是否需要更新上下文
# 由 .claude/hooks.json 中的 PostToolUse hook 触发

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

# 获取被写入的文件路径（从 hook 环境变量中）
WRITTEN_FILE="${CLAUDE_TOOL_INPUT_FILE:-}"

# 如果写入的是依赖配置文件，提醒同步
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
