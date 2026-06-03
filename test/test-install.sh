#!/bin/bash
# SKIIS 安装功能测试
# 用法: bash test/test-install.sh
# 在临时目录中测试全局安装和项目安装

PASS=0
FAIL=0
SKIIS_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMPDIR="/tmp/skiis-test-$$"

green() { echo -e "\033[32m✅ $1\033[0m"; ((PASS++)); }
red()   { echo -e "\033[31m❌ $1\033[0m"; ((FAIL++)); }
info()  { echo -e "\033[36m📋 $1\033[0m"; }

cleanup() {
    rm -rf "$TMPDIR"
    # 清理全局安装测试痕迹
    rm -rf "$HOME/.claude/commands" 2>/dev/null || true
    rm -rf "$HOME/.claude/skills/session-context" 2>/dev/null || true
    rm -rf "$HOME/.claude/skills/task-orchestrator" 2>/dev/null || true
}
trap cleanup EXIT

cd "$SKIIS_ROOT"

# ============================================
# 测试 1：全局安装
# ============================================
info "测试 1：全局安装"

bash install.sh --global 2>&1 | tail -3

# 验证命令文件
if [ -d "$HOME/.claude/commands" ]; then
    count=$(find "$HOME/.claude/commands" -name "*.md" | wc -l)
    if [ "$count" -ge 7 ]; then
        green "全局安装: 命令文件数量正确 ($count 个)"
    else
        red "全局安装: 命令文件数量不足 (期望 >=7, 实际 $count)"
    fi
else
    red "全局安装: commands 目录不存在"
fi

# 验证技能文件
if [ -f "$HOME/.claude/skills/session-context/SKILL.md" ]; then
    green "全局安装: session-context 技能已安装"
else
    red "全局安装: session-context 技能未安装"
fi

if [ -f "$HOME/.claude/skills/task-orchestrator/SKILL.md" ]; then
    green "全局安装: task-orchestrator 技能已安装"
else
    red "全局安装: task-orchestrator 技能未安装"
fi

# ============================================
# 测试 2：项目安装
# ============================================
info "测试 2：项目安装"

mkdir -p "$TMPDIR/test-project/src"
cd "$TMPDIR/test-project"
git init --quiet 2>/dev/null || true
echo "int main() { return 0; }" > src/main.c

bash "$SKIIS_ROOT/install.sh" "$(pwd)"

# 验证 .claude/ 目录结构（使用绝对路径）
PROJ_DIR="$(pwd)"
[ -d "$PROJ_DIR/.claude/commands" ] && green "项目安装: commands 目录" || red "项目安装: 缺少 commands"
[ -d "$PROJ_DIR/.claude/skills/session-context" ] && green "项目安装: session-context 技能" || red "项目安装: 缺少 session-context"
[ -f "$PROJ_DIR/.claude/hooks.json" ] && green "项目安装: hooks.json" || red "项目安装: 缺少 hooks.json"
[ -d "$PROJ_DIR/.claude/hooks" ] && green "项目安装: hooks 脚本" || red "项目安装: 缺少 hooks 脚本"

# 验证上下文目录
if [ -d "$PROJ_DIR/.claude/context" ]; then
    green "项目安装: 上下文目录 (.claude/context/)"
    [ -f "$PROJ_DIR/.claude/context/current-task.md" ] && green "项目安装: current-task.md" || red "项目安装: 缺少 current-task.md"
    [ -f "$PROJ_DIR/.claude/context/decisions.md" ] && green "项目安装: decisions.md" || red "项目安装: 缺少 decisions.md"
    [ -f "$PROJ_DIR/.claude/context/pitfalls.md" ] && green "项目安装: pitfalls.md" || red "项目安装: 缺少 pitfalls.md"
elif [ -d "$PROJ_DIR/docs/ai-context" ]; then
    green "项目安装: 上下文目录 (docs/ai-context/ 兼容)"
else
    red "项目安装: 上下文目录未创建"
fi

# 验证 gitignore
grep -q ".claude/context" "$PROJ_DIR/.gitignore" 2>/dev/null && \
    green "项目安装: .gitignore 已添加" || \
    red "项目安装: .gitignore 未添加 .claude/context/"

# ============================================
# 测试 3：重复安装安全
# ============================================
info "测试 3：重复安装"

bash "$SKIIS_ROOT/install.sh" "$PROJ_DIR" 2>&1 | tail -2

[ -f "$PROJ_DIR/.claude/context/current-task.md" ] && \
    green "重复安装: 上下文文件未丢失" || \
    red "重复安装: 上下文文件丢失"

# ============================================
# 测试 4：hooks.json 合并
# ============================================
info "测试 4：hooks.json 智能合并"

# 在已有 hooks 上再装一次
echo '{"existing": true}' > "$PROJ_DIR/.claude/hooks.json"
bash "$SKIIS_ROOT/install.sh" "$PROJ_DIR" 2>&1 | tail -1
grep -q "existing" "$PROJ_DIR/.claude/hooks.json" 2>/dev/null && \
    green "hooks 合并: 原有内容保留" || \
    red "hooks 合并: 原有内容丢失"

# 再次安装，不应该重复添加 SKIIS hooks
before=$(wc -l < "$PROJ_DIR/.claude/hooks.json")
bash "$SKIIS_ROOT/install.sh" "$PROJ_DIR" 2>&1 | tail -1
after=$(wc -l < "$PROJ_DIR/.claude/hooks.json")
if [ "$before" -eq "$after" ]; then
    green "hooks 去重: 未重复添加 ($before 行)"
else
    red "hooks 去重: 行数变化 $before → $after"
fi

# ============================================
# 结果
# ============================================
echo ""
echo "=============================="
echo "  安装测试: $PASS 通过, $FAIL 失败"
echo "=============================="

if [ $FAIL -gt 0 ]; then
    exit 1
fi
