# SKIIS 一键安装脚本 (Windows PowerShell)
# 用法:
#   项目安装:  .\install.ps1 [目标项目路径]
#   全局安装:  .\install.ps1 -Global
#
# 示例:
#   .\install.ps1 .                 # 安装到当前项目
#   .\install.ps1 C:\my-project     # 安装到指定项目
#   .\install.ps1 -Global           # 全局安装（所有项目可用）

param(
    [string]$Target = ".",
    [switch]$Global
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

if ($Global) {
    # 全局安装：安装到用户目录 ~/.claude/
    $targetDir = "$env:USERPROFILE\.claude"
    $isGlobal = $true
}
else {
    $targetDir = (Resolve-Path $Target).Path
    $isGlobal = $false
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  SKIIS — Claude Code 上下文管理技能" -ForegroundColor Cyan
if ($isGlobal) {
    Write-Host "  全局安装（所有项目可用）" -ForegroundColor Magenta
}
else {
    Write-Host "  项目安装" -ForegroundColor Cyan
}
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "安装目录: $targetDir"
Write-Host ""

# ============================================
# 1. 复制命令文件 (.claude/commands/project/)
#    目录名 "project" 对应 /project:xxx 前缀
# ============================================
Write-Host "[1/5] 安装命令文件..." -ForegroundColor Yellow

$commandsDir = "$targetDir\commands\project"
New-Item -ItemType Directory -Force -Path $commandsDir | Out-Null

$sourceCommands = "$scriptDir\.claude\commands\project\"
if (Test-Path $sourceCommands) {
    Copy-Item -Path "$sourceCommands*" -Destination $commandsDir -Force
    Write-Host "  ✅ 5 个命令已安装 (/project:session-load 等)" -ForegroundColor Green
}
else {
    Write-Host "  ⚠️  未找到命令源文件，请确认从完整仓库运行" -ForegroundColor Magenta
}

# ============================================
# 2. 复制技能文件 (.claude/skills/)
# ============================================
Write-Host "[2/5] 安装技能文件..." -ForegroundColor Yellow

$skillsDir = "$targetDir\skills\session-context"
New-Item -ItemType Directory -Force -Path $skillsDir | Out-Null

$sourceSkills = "$scriptDir\.claude\skills\session-context\"
if (Test-Path $sourceSkills) {
    Copy-Item -Path "$sourceSkills*" -Destination $skillsDir -Recurse -Force
    Write-Host "  ✅ session-context 技能已安装" -ForegroundColor Green
}

# ============================================
# 3. hooks.json（仅项目安装）
# ============================================
Write-Host "[3/5] 配置 Hooks..." -ForegroundColor Yellow

if ($isGlobal) {
    Write-Host "  ⏭️  全局安装跳过 hooks（hooks 属于项目级配置）" -ForegroundColor Gray
}
else {
    $hooksFile = "$targetDir\hooks.json"
    $skuusMarker = "SKIIS"

    $skuusHooks = @{
        "description" = "SKIIS 上下文管理自动检查"
        "hooks" = @{
            "PostToolUse" = @(
                @{
                    "matcher" = "Write|Edit"
                    "command" = "bash `${CLAUDE_PROJECT_DIR}/.claude/hooks/on-file-change.sh`"
                }
            )
            "PreToolUse" = @(
                @{
                    "matcher" = "Bash"
                    "command" = "bash `${CLAUDE_PROJECT_DIR}/.claude/hooks/check-context.sh`"
                }
            )
        }
    }

    New-Item -ItemType Directory -Force -Path (Split-Path $hooksFile) | Out-Null

    if (Test-Path $hooksFile) {
        $existingContent = Get-Content $hooksFile -Raw -Encoding UTF8 | Out-String
        if ($existingContent -match "SKIIS") {
            Write-Host "  ⏭️  hooks.json 已包含 SKIIS 配置，跳过" -ForegroundColor Gray
        }
        else {
            try {
                $existing = Get-Content $hooksFile -Raw -Encoding UTF8 | ConvertFrom-Json
                if (-not $existing.hooks) { $existing | Add-Member -NotePropertyName "hooks" -NotePropertyValue @{} -Force }
                if (-not $existing.hooks.PostToolUse) { $existing.hooks | Add-Member -NotePropertyName "PostToolUse" -NotePropertyValue @() -Force }
                $existing.hooks.PostToolUse += $skuusHooks.hooks.PostToolUse[0]
                if (-not $existing.hooks.PreToolUse) { $existing.hooks | Add-Member -NotePropertyName "PreToolUse" -NotePropertyValue @() -Force }
                $existing.hooks.PreToolUse += $skuusHooks.hooks.PreToolUse[0]
                if ($existing.description -notmatch "SKIIS") { $existing.description = $existing.description + " + SKIIS" }
                $existing | ConvertTo-Json -Depth 10 | Set-Content $hooksFile -Encoding UTF8
                Write-Host "  ✅ hooks.json 已合并（保留原有配置）" -ForegroundColor Green
            }
            catch {
                Copy-Item $hooksFile "$hooksFile.bak" -Force
                $skuusHooks | ConvertTo-Json -Depth 10 | Set-Content $hooksFile -Encoding UTF8
                Write-Host "  ✅ hooks.json 已安装（旧文件备份为 .bak）" -ForegroundColor Green
            }
        }
    }
    else {
        $skuusHooks | ConvertTo-Json -Depth 10 | Set-Content $hooksFile -Encoding UTF8
        Write-Host "  ✅ hooks.json 已创建" -ForegroundColor Green
    }
}

# ============================================
# 4. hooks 脚本（仅项目安装）
# ============================================
Write-Host "[4/5] 安装 Hooks 脚本..." -ForegroundColor Yellow

if ($isGlobal) {
    Write-Host "  ⏭️  全局安装跳过 hooks 脚本" -ForegroundColor Gray
}
else {
    $hooksScriptDir = "$targetDir\hooks"
    New-Item -ItemType Directory -Force -Path $hooksScriptDir | Out-Null
    $sourceHooks = "$scriptDir\.claude\hooks\"
    if (Test-Path $sourceHooks) {
        Copy-Item -Path "$sourceHooks*.sh" -Destination $hooksScriptDir -Force
        Write-Host "  ✅ hooks 脚本已安装" -ForegroundColor Green
    }
}

# ============================================
# 5. CLAUDE.md（仅项目安装）
# ============================================
Write-Host "[5/5] 配置 CLAUDE.md..." -ForegroundColor Yellow

if ($isGlobal) {
    Write-Host "  ⏭️  全局安装跳过 CLAUDE.md（属于项目文件）" -ForegroundColor Gray
}
else {
    $claudeFile = "$targetDir\CLAUDE.md"
    $skuusSectionMarker = "## 自动上下文管理规则"

    $skuusSection = @'

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
'@

    if (Test-Path $claudeFile) {
        $existingClaude = Get-Content $claudeFile -Raw -Encoding UTF8 | Out-String
        if ($existingClaude -match [regex]::Escape($skuusSectionMarker)) {
            Write-Host "  ⏭️  CLAUDE.md 已包含 SKIIS 规则，跳过" -ForegroundColor Gray
        }
        else {
            Add-Content $claudeFile -Value $skuusSection -Encoding UTF8
            Write-Host "  ✅ CLAUDE.md 已追加 SKIIS 规则（保留原有内容）" -ForegroundColor Green
        }
    }
    else {
        Set-Content $claudeFile -Value $skuusSection -Encoding UTF8
        Write-Host "  ✅ CLAUDE.md 已创建" -ForegroundColor Green
    }
}

# ============================================
# 6. 初始化 docs/ai-context/（仅项目安装 + 首次）
# ============================================
Write-Host ""

if ($isGlobal) {
    Write-Host "📂 全局安装完成（仅命令和技能，项目级文件需在项目中单独初始化）" -ForegroundColor Gray
}
else {
    $contextDir = "$targetDir\docs\ai-context"
    if (-not (Test-Path $contextDir)) {
        Write-Host "🔍 首次安装，初始化上下文目录..." -ForegroundColor Cyan
        New-Item -ItemType Directory -Force -Path $contextDir | Out-Null

        Set-Content "$contextDir\current-task.md" -Value @"
> 最后更新: $(Get-Date -Format 'yyyy-MM-dd HH:mm')

# 当前任务

## 已完成
暂无

## 进行中
暂无

## 待完成
暂无

## 关键上下文
暂无
"@ -Encoding UTF8

        Set-Content "$contextDir\decisions.md" -Value @"
# 技术决策记录

记录项目中的关键技术选择及原因。每条决策包含：编号、日期、背景、选项、选择、原因。
"@ -Encoding UTF8

        Set-Content "$contextDir\pitfalls.md" -Value @"
# 踩坑记录

记录遇到的问题和解决方案，避免重复踩坑。
"@ -Encoding UTF8

        Write-Host "  ✅ docs/ai-context/ 已初始化" -ForegroundColor Green
    }
    else {
        Write-Host "📂 docs/ai-context/ 已存在，保留用户数据" -ForegroundColor Gray
    }
}

# ============================================
# 完成
# ============================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
if ($isGlobal) {
    Write-Host "  SKIIS 全局安装完成！" -ForegroundColor Green
}
else {
    Write-Host "  SKIIS 安装完成！" -ForegroundColor Green
}
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "已安装:" -ForegroundColor White
Write-Host "  ✅ /project:session-load, session-save, session-end"
Write-Host "  ✅ /project:context-check, context-sync"
if (-not $isGlobal) {
    Write-Host "  ✅ hooks.json (智能合并)"
    Write-Host "  ✅ hooks 脚本"
    Write-Host "  ✅ CLAUDE.md (智能合并)"
}
Write-Host ""

if ($isGlobal) {
    Write-Host "任何项目中都可以直接使用 /project:xxx 命令了" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "💡 在具体项目中运行" -ForegroundColor White
    Write-Host "   .\install.ps1 .    （安装项目级 hooks、CLAUDE.md、上下文目录）" -ForegroundColor Gray
}
else {
    Write-Host "重启 Claude Code，输入:" -ForegroundColor White
    Write-Host "  /project:session-load" -ForegroundColor Cyan
}
Write-Host ""
