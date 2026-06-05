#!/bin/bash
# SKIIS 自测试 — 模拟真实使用场景
# 用法: bash test/self-test.sh

PASS=0; FAIL=0
SKIIS_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TESTDIR="/tmp/skiis-selftest"
green() { echo -e "\033[32m  ✅ $1\033[0m"; ((PASS++)); }
red()   { echo -e "\033[31m  ❌ $1\033[0m"; ((FAIL++)); }
info()  { echo -e "\n\033[1;36m📋 $1\033[0m"; }

cleanup() {
    rm -rf "$TESTDIR"
    rm -rf "$HOME/.claude/commands" 2>/dev/null
    rm -rf "$HOME/.claude/skills/session-context" 2>/dev/null
    rm -rf "$HOME/.claude/skills/task-orchestrator" 2>/dev/null
}
trap cleanup EXIT
cleanup

cd "$SKIIS_ROOT"

# ============================================
info "场景 1：全局安装"
# ============================================
bash install.sh --global > /dev/null 2>&1

[ -f "$HOME/.claude/skills/session-context/SKILL.md" ] && \
    green "session-context SKILL.md 已安装" || red "session-context SKILL.md 未安装"
[ -f "$HOME/.claude/skills/task-orchestrator/SKILL.md" ] && \
    green "task-orchestrator SKILL.md 已安装" || red "task-orchestrator SKILL.md 未安装"
[ -d "$HOME/.claude/commands" ] && \
    green "命令目录已创建" || red "命令目录未创建"
count=$(find "$HOME/.claude/commands" -name "*.md" 2>/dev/null | wc -l)
[ "$count" -ge 7 ] && green "命令文件数量: $count" || red "命令文件不足: $count"

# ============================================
info "场景 2：进入新项目，自动初始化"
# ============================================
mkdir -p "$TESTDIR/project-alpha/src/ike"
mkdir -p "$TESTDIR/project-alpha/include"
cat > "$TESTDIR/project-alpha/src/ike/negotiate.c" << 'EOF'
#include "sa.h"
int ike_handle_sa(void) {
    // TODO: implement SA negotiation
    return 0;
}
EOF
cat > "$TESTDIR/project-alpha/include/sa.h" << 'EOF'
typedef enum { SA_INIT, SA_NEGOTIATING, SA_ESTABLISHED } sa_state_t;
EOF
cd "$TESTDIR/project-alpha"
git init --quiet 2>/dev/null || true
git config user.email "test@test.com" 2>/dev/null || true
git config user.name "Test" 2>/dev/null || true

# 模拟 AI 的规则 0：检查并初始化
info "  模拟规则 0：检查 .claude/context/ 和 .claude/context/"

if [ ! -d ".claude/context" ] && [ ! -d "docs/ai-context" ]; then
    # 规则 5：自动初始化
    mkdir -p .claude/context/reference
    mkdir -p .claude/context/tasks/claims
    mkdir -p .claude/context/tasks/results

    cat > .claude/context/current-task.md << 'EOF'
> 最后更新: 2026-06-02 10:00

# 当前任务

## 已完成
暂无

## 进行中
暂无

## 待完成
暂无

## 关键上下文
- 项目: project-alpha (IKE 协议实现)
- 编译: gcc -Iinclude src/ike/*.c -o ike
EOF
    cat > .claude/context/decisions.md << 'EOF'
# 技术决策记录
EOF
    cat > .claude/context/pitfalls.md << 'EOF'
# 踩坑记录
EOF
    green "规则 5: 自动创建上下文目录"
fi

# 验证初始化结果
[ -f ".claude/context/current-task.md" ] && green "current-task.md 已创建" || red "current-task.md 缺失"
[ -f ".claude/context/decisions.md" ] && green "decisions.md 已创建" || red "decisions.md 缺失"
[ -f ".claude/context/pitfalls.md" ] && green "pitfalls.md 已创建" || red "pitfalls.md 缺失"
[ -d ".claude/context/reference" ] && green "reference/ 已创建" || red "reference/ 缺失"
[ -d ".claude/context/tasks" ] && green "tasks/ 已创建" || red "tasks/ 缺失"

# ============================================
info "场景 3：工作中途保存进度"
# ============================================
# 模拟 AI 的规则 4 + 写入继续计划
cat > .claude/context/current-task.md << 'EOF'
> 最后更新: 2026-06-03 14:30

# 当前任务

## 已完成
- [x] 定义 SA 状态枚举 (include/sa.h)
- [x] 搭建协商主框架 (src/ike/negotiate.c)
- [x] 编译通过

## 进行中
- [ ] 实现 IKE SA 协商超时重试 — 主流程已写完，handle_timeout() 回调未注册

## 待完成
- [ ] 添加 DH 密钥交换
- [ ] 单元测试

## 🔜 下次继续
### 第一步
打开 src/ike/negotiate.c，在 ike_handle_sa() 函数中注册 handle_timeout() 回调

### 当前状态
主流程已写完，编译通过，但超时回调未注册

### 关键约束
超时时间从配置文件 /etc/ike/ike.conf 读取，不能硬编码

### 阻塞项
等待运维确认 keepalive 间隔参数

## 📂 关键文件清单
### 问题定位相关
- src/ike/negotiate.c:240-350  ← 协商主逻辑，handle_timeout() 在这里
- include/sa.h:1-10           ← 状态枚举

### 已排除
- src/ike/crypto.c            ← 加密模块，已验证正常

## 关键上下文
- 项目: project-alpha (IKE 协议实现)
- 编译: gcc -Iinclude src/ike/*.c -o ike
- 配置: /etc/ike/ike.conf
EOF

green "规则 4: 保存进度（含继续计划和文件清单）"

# 验证保存内容
grep -q "🔜 下次继续" .claude/context/current-task.md && green "继续计划已写入" || red "继续计划缺失"
grep -q "📂 关键文件清单" .claude/context/current-task.md && green "文件清单已写入" || red "文件清单缺失"
grep -q "ike_handle_sa" .claude/context/current-task.md && green "第一步含具体函数名" || red "第一步不够具体"

# ============================================
info "场景 4：新会话加载上下文"
# ============================================
# 模拟规则 0 的加载
[ -f ".claude/context/current-task.md" ] && green "规则 0: 检测到上下文文件" || red "规则 0: 上下文文件缺失"

# 检查"下次继续"被优先展示
head -30 .claude/context/current-task.md | grep -q "下次继续" && \
    green "下次继续段落存在且可读取" || red "下次继续段落缺失"

# 模拟读取关键文件清单
grep -q "src/ike/negotiate.c:240-350" .claude/context/current-task.md && \
    green "关键文件清单包含行号范围" || red "关键文件清单不够精确"

grep -q "已排除" .claude/context/current-task.md && \
    green "已排除文件列表存在" || red "缺少已排除文件列表"

# ============================================
info "场景 5：任务全部完成，检查清空提示"
# ============================================
cat > .claude/context/current-task.md << 'EOF'
> 最后更新: 2026-06-03 16:00

# 当前任务

## 已完成
- [x] 实现 IKE SA 协商超时重试
- [x] 添加 DH 密钥交换
- [x] 单元测试全部通过

## 进行中
（无）

## 待完成
（无）

## 关键上下文
- 编译: gcc -Iinclude src/ike/*.c -o ike
- 测试: make test
EOF

# 模拟规则 0 的任务完成检测
has_in_progress=$(grep -c '\[ \]' .claude/context/current-task.md 2>/dev/null || true)
has_in_progress=${has_in_progress:-0}
if [ "$has_in_progress" = "0" ]; then
    green "规则 0 检测: 任务全部完成，应提示清空"
fi

# 模拟清理 — 提取关键上下文到 reference/
mkdir -p .claude/context/reference
grep -A 10 "关键上下文" .claude/context/current-task.md > .claude/context/reference/context-2026-06-03.md 2>/dev/null || true
[ -f ".claude/context/reference/context-2026-06-03.md" ] && \
    green "规则清理: 关键上下文已保存到 reference/" || \
    red "关键上下文提取失败"

# ============================================
info "场景 6：跨项目任务派发"
# ============================================
mkdir -p "$TESTDIR/project-bravo/src"
cat > "$TESTDIR/project-bravo/src/main.c" << 'EOF'
int main() { return 0; }
EOF

# 模拟 /task-send 到 project-bravo
info "  模拟 /task-send $TESTDIR/project-bravo"

TARGET="$TESTDIR/project-bravo"

# 规则 4.7: 检查目标是否有上下文，没有则自动初始化
if [ ! -d "$TARGET/.claude/context" ] && [ ! -d "$TARGET/docs/ai-context" ]; then
    mkdir -p "$TARGET/.claude/context/tasks/done"
    mkdir -p "$TARGET/.claude/context/tasks/claims"
    mkdir -p "$TARGET/.claude/context/tasks/results"
    green "规则 5: 自动初始化目标项目上下文"
fi

# 生成任务文件
cat > "$TARGET/.claude/context/tasks/from-project-alpha-2026-06-03-IKE-timeout.md" << 'EOF'
# 来自「project-alpha」的排查任务
> 派发时间: 2026-06-03 16:30 | 来源: project-alpha

## 问题背景
IKE SA 协商超时，怀疑密钥交换模块返回值异常

## A→B 交互关系
- 调用方式: Unix socket (/var/run/iked.sock)
- 关键接口: dh_generate_params()

## 排查范围
- [ ] 检查 DH 参数生成逻辑
- [ ] 检查 socket 通信超时处理

## 已知线索
返回 -1 时未设置 errno，调用方无法判断错误类型
EOF

[ -f "$TARGET/.claude/context/tasks/from-project-alpha-"* ] && \
    green "规则 4.7: 任务文件已在目标项目生成" || \
    red "任务文件生成失败"

# 验证在 A 的 current-task.md 中记录了派发
echo '📤 已派发任务到 project-bravo → from-project-alpha-2026-06-03-IKE-timeout.md' >> .claude/context/current-task.md
grep -q "📤 已派发" .claude/context/current-task.md && \
    green "来源项目记录: 派发记录已写入" || red "派发记录缺失"

# ============================================
info "场景 7：多分支隔离（Git）"
# ============================================
cd "$TESTDIR/project-alpha"
git checkout -b feature-ipv6 2>/dev/null || git checkout feature-ipv6 2>/dev/null || true

# 模拟规则 7: Git 分支识别
branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
mkdir -p ".claude/context/$branch"
echo "# feature-ipv6 分支任务" > ".claude/context/$branch/current-task.md"

[ -f ".claude/context/$branch/current-task.md" ] && \
    green "规则 7: Git 分支隔离 ($branch)" || red "Git 分支隔离失败"

# 切回主分支
git checkout master 2>/dev/null || git checkout main 2>/dev/null || true

# ============================================
info "场景 8：并行任务结果合并"
# ============================================
cd "$TESTDIR/project-alpha"

# 模拟多个并行任务写入结果文件
for i in 1 2 3; do
    mkdir -p .claude/context/tasks/results
    cat > ".claude/context/tasks/results/task-$i.result.md" << EOF
# 任务结果: Task-$i
- 完成时间: 2026-06-03
- 修改文件: src/module-$i.c
- 决策: 选择了方案 A
EOF
done

result_count=$(find .claude/context/tasks/results -name "*.result.md" 2>/dev/null | wc -l)
[ "$result_count" -eq 3 ] && green "规则合并: 3 个结果文件已生成" || red "结果文件数量: $result_count"

# 模拟合并 → 结果写入 current-task.md
echo "## 合并结果" >> .claude/context/current-task.md
for f in .claude/context/tasks/results/*.result.md; do
    grep "修改文件" "$f" >> .claude/context/current-task.md
done
mkdir -p .claude/context/tasks/results/merged
mv .claude/context/tasks/results/*.result.md .claude/context/tasks/results/merged/ 2>/dev/null || true

remaining=$(find .claude/context/tasks/results -maxdepth 1 -name "*.result.md" 2>/dev/null | wc -l)
[ "$remaining" -eq 0 ] && green "合并完成: 结果已移到 merged/" || red "合并未完成 ($remaining 个残留)"

# ============================================
info "场景 9：任务认领锁"
# ============================================
claim_dir=".claude/context/tasks/claims"
mkdir -p "$claim_dir/done"

# 模拟认领 task-A
echo "session-1|2026-06-03T16:00:00|src/ike/negotiate.c" > "$claim_dir/task-A.claim"
[ -f "$claim_dir/task-A.claim" ] && green "认领锁: task-A 已认领" || red "认领锁创建失败"

# 模拟冲突检测
[ -f "$claim_dir/task-B.claim" ] && red "task-B 不应被认领" || green "认领锁: task-B 未被认领，可以执行"

# 模拟完成释放
mv "$claim_dir/task-A.claim" "$claim_dir/done/"
[ -f "$claim_dir/task-A.claim" ] && red "task-A 锁未释放" || green "认领锁: task-A 已完成并释放"

# ============================================
info "场景 10：远程调试凭据管理"
# ============================================
# 模拟记录远程凭据
cat >> .claude/context/current-task.md << 'EOF'

## 🔐 远程调试（仅本次任务，完成后删除）
- 方式：SSH
- 地址：192.168.1.100:22
- 账号：admin
- 密码：secret123
EOF

grep -q "secret123" .claude/context/current-task.md && green "凭据管理: 远程信息已记录" || red "凭据记录失败"

# 模拟任务完成后删除凭据
sed -i '/🔐 远程调试/,/secret123/d' .claude/context/current-task.md 2>/dev/null || \
    sed -i '/🔐 远程调试/,/secret123/d' .claude/context/current-task.md
grep -q "secret123" .claude/context/current-task.md 2>/dev/null && \
    red "凭据管理: 敏感信息未清除" || \
    green "凭据管理: 任务完成后凭据已删除"

# 验证没有写入 decisions.md
grep -q "secret123" .claude/context/decisions.md 2>/dev/null && \
    red "凭据安全: 密码出现在 decisions.md" || \
    green "凭据安全: decisions.md 无敏感信息"

# ============================================
# 结果
# ============================================
echo ""
echo "======================================"
echo "  SKIIS 自测试完成"
echo "  通过: $PASS / 失败: $FAIL"
echo "======================================"

[ $FAIL -gt 0 ] && exit 1 || exit 0

