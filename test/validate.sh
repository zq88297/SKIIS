#!/bin/bash
# SKIIS 技能验证测试
# 用法: bash test/validate.sh
# 验证所有 SKILL.md YAML、命令文件引用、描述完整性

PASS=0
FAIL=0
SKIIS_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

green() { echo -e "\033[32m✅ $1\033[0m"; ((PASS++)); }
red()   { echo -e "\033[31m❌ $1\033[0m"; ((FAIL++)); }
info()  { echo -e "\033[36m📋 $1\033[0m"; }

cd "$SKIIS_ROOT"

# ============================================
# 1. YAML 前端验证
# ============================================
info "1. SKILL.md YAML 前端验证"

for skill_md in .claude/skills/*/SKILL.md; do
    skill_name=$(basename "$(dirname "$skill_md")")

    # 检查 YAML 分隔符（跳过 BOM）
    first_line=$(head -1 "$skill_md" | sed 's/\xef\xbb\xbf//')
    if echo "$first_line" | grep -q "^---$"; then
        green "$skill_name: 开头 YAML 分隔符正确"
    else
        red "$skill_name: 缺少开头 YAML 分隔符"
    fi

    # 检查 name 字段（在前 5 行内）
    head -5 "$skill_md" | grep -q "name:" && \
        green "$skill_name: name 字段存在" || \
        red "$skill_name: 缺少 name 字段"

    # 检查 description 字段（在前 5 行内）
    head -5 "$skill_md" | grep -q "description:" && \
        green "$skill_name: description 字段存在" || \
        red "$skill_name: 缺少 description 字段"

    # description 不为空
    desc=$(head -5 "$skill_md" | grep "description:" | head -1)
    if echo "$desc" | grep -q 'description: ""'; then
        red "$skill_name: description 为空"
    elif echo "$desc" | grep -q 'description:'; then
        green "$skill_name: description 不为空"
    else
        red "$skill_name: description 格式异常"
    fi
done

# ============================================
# 2. 命令文件验证
# ============================================
info "2. 命令文件验证"

# 检查 .claude/commands/ 下的所有命令
find .claude/commands -name "*.md" | while read cmd; do
    cmd_name=$(basename "$cmd" .md)
    cmd_dir=$(dirname "$cmd" | sed 's|.claude/commands/||')

    # 检查文件非空
    if [ -s "$cmd" ]; then
        green "$cmd: 文件非空 ($(wc -l < "$cmd") 行)"
    else
        red "$cmd: 文件为空"
    fi

    # 检查有标题
    head -5 "$cmd" | grep -q "^#" && \
        green "$cmd: 有标题" || \
        red "$cmd: 缺少标题"
done

# 检查 skill 内部的 commands/ 与外部同步
info "2.5 命令文件同步检查"
for skill_cmd in .claude/skills/session-context/commands/*.md; do
    cmd_name=$(basename "$skill_cmd")
    ext_cmd=".claude/commands/$cmd_name"

    if [ -f "$ext_cmd" ]; then
        if diff -q "$skill_cmd" "$ext_cmd" > /dev/null 2>&1; then
            green "commands/$cmd_name: skill 内部与外部同步"
        else
            red "commands/$cmd_name: skill 内部与外部不一致！需要同步"
        fi
    else
        # 检查 task/ 子目录
        ext_cmd=".claude/commands/task/$cmd_name"
        if [ -f "$ext_cmd" ]; then
            if diff -q "$skill_cmd" "$ext_cmd" > /dev/null 2>&1; then
                green "commands/task/$cmd_name: skill 内部与外部同步"
            else
                red "commands/task/$cmd_name: skill 内部与外部不一致！需要同步"
            fi
        else
            red "commands/$cmd_name: 外部命令文件缺失"
        fi
    fi
done

# ============================================
# 3. 引用完整性验证
# ============================================
info "3. 引用完整性"

# SKILL.md 中引用的命令文件是否存在
for skill_md in .claude/skills/*/SKILL.md; do
    skill_dir=$(dirname "$skill_md")
    grep -o '\[.*\]([^)]*\.md)' "$skill_md" | sed 's/.*(//;s/)//' | while read ref; do
        if [ -f "$skill_dir/$ref" ]; then
            green "$(basename $skill_dir): 引用 $ref 存在"
        else
            red "$(basename $skill_dir): 引用 $ref 不存在"
        fi
    done
done

# ============================================
# 4. Cursor 规则文件验证
# ============================================
info "4. .cursor/rules/ 文件验证"

for mdc in .cursor/rules/*.mdc; do
    mdc_name=$(basename "$mdc")

    # 检查 YAML 前端
    head -1 "$mdc" | grep -q "^---$" && \
        green "$mdc_name: YAML 前端正确" || \
        red "$mdc_name: 缺少 YAML 前端"

    # 检查 description
    grep -q "^description:" "$mdc" && \
        green "$mdc_name: description 存在" || \
        red "$mdc_name: 缺少 description"
done

# ============================================
# 5. 安装脚本语法检查
# ============================================
info "5. 安装脚本语法检查"

bash -n install.sh 2>/dev/null && \
    green "install.sh: 语法正确" || \
    red "install.sh: 语法错误"

# PowerShell 语法检查（如果 pwsh 可用）
if command -v pwsh &>/dev/null; then
    pwsh -NoProfile -Command "Get-Command -Syntax 'f:/AICode/SKIIS/install.ps1'" 2>/dev/null && \
        green "install.ps1: 语法正确" || \
        red "install.ps1: 语法错误"
else
    info "  跳过 install.ps1（pwsh 不可用）"
fi

# ============================================
# 6. Hooks 脚本语法检查
# ============================================
info "6. Hooks 脚本语法检查"

bash -n .claude/hooks/check-context.sh 2>/dev/null && \
    green "check-context.sh: 语法正确" || \
    red "check-context.sh: 语法错误"

bash -n .claude/hooks/on-file-change.sh 2>/dev/null && \
    green "on-file-change.sh: 语法正确" || \
    red "on-file-change.sh: 语法错误"

# ============================================
# 结果
# ============================================
echo ""
echo "=============================="
echo "  测试结果: $PASS 通过, $FAIL 失败"
echo "=============================="

if [ $FAIL -gt 0 ]; then
    exit 1
fi
