# SKIIS 安装脚本 (Windows PowerShell)
# 用法（需先 git clone 仓库）:
#   git clone https://github.com/zq88297/SKIIS.git; cd SKIIS
#
#   项目安装:  .\install.ps1 [目标路径]
#   全局安装:  .\install.ps1 -Global
#
# 示例:
#   .\install.ps1 .                 # 安装到当前项目
#   .\install.ps1 C:\my-project     # 安装到指定项目
#   .\install.ps1 -Global           # 全局安装（skill 放到 ~/.claude/skills/）

param(
    [string]$Target = ".",
    [switch]$Global
)

# 兼容 bash 风格 --Global 参数（PowerShell 只认 -Global）
if ($Target -eq "--Global" -or $Target -eq "--global") {
    $Global = $true
    $Target = "."
}

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# 检查源文件是否完整（防止单独下载脚本运行导致找不到源文件）
if (-not (Test-Path "$scriptDir\.claude\commands") -or -not (Test-Path "$scriptDir\.claude\skills\session-context")) {
    Write-Host "🔍 检测到脚本不在完整仓库中，正在自动克隆..." -ForegroundColor Yellow
    $tempRepo = "$env:TEMP\skiiis-repo-$PID"
    git clone --depth 1 https://github.com/zq88297/SKIIS.git $tempRepo 2>$null
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $tempRepo)) {
        Write-Host "❌ 克隆失败，请手动运行:" -ForegroundColor Red
        Write-Host "  git clone https://github.com/zq88297/SKIIS.git && cd SKIIS && .\install.ps1 -Global"
        exit 1
    }
    $scriptDir = $tempRepo
    $cleanupTemp = $true
}

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
# 1. 复制命令文件 (.claude/commands/)
#    目录名 "project" 对应 /project:xxx 前缀
# ============================================
Write-Host "[1/6] 安装命令文件..." -ForegroundColor Yellow

$commandsDir = "$targetDir\commands"
New-Item -ItemType Directory -Force -Path $commandsDir | Out-Null

$sourceCommands = "$scriptDir\.claude\commands\"
if (Test-Path $sourceCommands) {
    Copy-Item -Path "$sourceCommands*" -Destination $commandsDir -Force
    Write-Host "  ✅ 5 个命令已安装 (/session-load 等)" -ForegroundColor Green
}
else {
    Write-Host "  ⚠️  未找到命令源文件，请确认从完整仓库运行" -ForegroundColor Magenta
}

# ============================================
# 2. 复制技能文件 (.claude/skills/)
# ============================================
# .cursor/rules/（Cursor IDE 支持）
$cursorDir = "$targetDir\.cursor\rules"
New-Item -ItemType Directory -Force -Path $cursorDir | Out-Null
$sourceCursor = "$scriptDir\.cursor\rules\"
if (Test-Path $sourceCursor) {
    Copy-Item -Path "$sourceCursor*" -Destination $cursorDir -Force
    Write-Host "  ✅ Cursor 规则已安装 (.cursor/rules/*.mdc)" -ForegroundColor Green
}

Write-Host "[2/6] 安装技能文件..." -ForegroundColor Yellow

# session-context
$skillsDir = "$targetDir\skills\session-context"
New-Item -ItemType Directory -Force -Path $skillsDir | Out-Null
$sourceSkills = "$scriptDir\.claude\skills\session-context\"
if (Test-Path $sourceSkills) {
    Copy-Item -Path "$sourceSkills*" -Destination $skillsDir -Recurse -Force
    Write-Host "  ✅ session-context 技能已安装" -ForegroundColor Green
}

# task-orchestrator
$orchDir = "$targetDir\skills\task-orchestrator"
New-Item -ItemType Directory -Force -Path $orchDir | Out-Null
$sourceOrch = "$scriptDir\.claude\skills\task-orchestrator\"
if (Test-Path $sourceOrch) {
    Copy-Item -Path "$sourceOrch*" -Destination $orchDir -Recurse -Force
    Write-Host "  ✅ task-orchestrator 技能已安装" -ForegroundColor Green
}

# project-workflow
$wfDir = "$targetDir\skills\project-workflow"
New-Item -ItemType Directory -Force -Path $wfDir | Out-Null
$sourceWf = "$scriptDir\.claude\skills\project-workflow\"
if (Test-Path $sourceWf) {
    Copy-Item -Path "$sourceWf*" -Destination $wfDir -Recurse -Force
    Write-Host "  ✅ project-workflow 技能已安装" -ForegroundColor Green
}

# ============================================
# 3. hooks.json（仅项目安装）
# ============================================
Write-Host "[3/6] 配置 Hooks..." -ForegroundColor Yellow

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
                    "command" = "bash `${CLAUDE_PROJECT_DIR}/.claude/hooks/on-file-change.sh"
                }
            )
            "PreToolUse" = @(
                @{
                    "matcher" = "Bash"
                    "command" = "bash `${CLAUDE_PROJECT_DIR}/.claude/hooks/check-context.sh"
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
Write-Host "[4/6] 安装 Hooks 脚本..." -ForegroundColor Yellow

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
# 5. CLAUDE.md（仅项目安装，精简版）
#   自动规则已在全局 SKILL.md 中，CLAUDE.md 只需引用
# ============================================
Write-Host "[5/6] 配置 CLAUDE.md..." -ForegroundColor Yellow

if ($isGlobal) {
    Write-Host "  ⏭️  全局安装跳过（自动规则已在全局 skill 中生效）" -ForegroundColor Gray
}
else {
    $claudeFile = "$targetDir\CLAUDE.md"
    $skuusMarker = "session-context"

    $skuusLine = @'

## 上下文管理

本项目使用 SKIIS 上下文管理系统（已全局安装）。可用命令：
`/session-load` `/session-save` `/session-end` `/context-check` `/context-sync`
'@

    if (Test-Path $claudeFile) {
        $existingClaude = Get-Content $claudeFile -Raw -Encoding UTF8 | Out-String
        if ($existingClaude -match $skuusMarker) {
            Write-Host "  ⏭️  CLAUDE.md 已包含 SKIIS 引用，跳过" -ForegroundColor Gray
        }
        else {
            Add-Content $claudeFile -Value $skuusLine -Encoding UTF8
            Write-Host "  ✅ CLAUDE.md 已追加 SKIIS 引用" -ForegroundColor Green
        }
    }
    else {
        Set-Content $claudeFile -Value $skuusLine -Encoding UTF8
        Write-Host "  ✅ CLAUDE.md 已创建" -ForegroundColor Green
    }
}

# ============================================
# 6. 初始化上下文目录（仅项目安装 + 首次）
#    新路径：.claude/context/（防误提交），兼容旧路径 docs/ai-context/
# ============================================
Write-Host ""

if ($isGlobal) {
    Write-Host "📂 全局安装完成（仅命令和技能，项目级文件需在项目中单独初始化）" -ForegroundColor Gray
}
else {
    # 优先新路径，兼容旧路径
    if (Test-Path "$targetDir\docs\ai-context") {
        $contextDir = "$targetDir\docs\ai-context"
        Write-Host "📂 检测到旧路径 docs/ai-context/，继续使用" -ForegroundColor Gray
    }
    else {
        $contextDir = "$targetDir\.claude\context"
    }

    if (-not (Test-Path $contextDir)) {
        Write-Host "🔍 首次安装，初始化上下文目录..." -ForegroundColor Cyan
        New-Item -ItemType Directory -Force -Path $contextDir | Out-Null
        New-Item -ItemType Directory -Force -Path "$contextDir\reference" | Out-Null
        New-Item -ItemType Directory -Force -Path "$contextDir\tasks" | Out-Null

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

        # 自动加入 .gitignore
        if (Test-Path "$targetDir\.git") {
            $gitignore = "$targetDir\.gitignore"
            $line = ".claude/context/"
            if (-not (Test-Path $gitignore) -or -not ((Get-Content $gitignore -Raw) -match [regex]::Escape($line))) {
                Add-Content $gitignore "`n# SKIIS 上下文文件（本地工作记录，不提交）"
                Add-Content $gitignore $line
                Write-Host "  ✅ 已自动将 .claude/context/ 加入 .gitignore" -ForegroundColor Green
            }
        }

        # 自动设置 svn:ignore
        if (Test-Path "$targetDir\.svn") {
            svn propset svn:ignore ".claude/context" "$targetDir\.claude\" 2>$null
            Write-Host "  ✅ 已自动设置 svn:ignore" -ForegroundColor Green
        }

        Write-Host "  ✅ 上下文目录已初始化 ($contextDir)" -ForegroundColor Green
    }
    else {
        Write-Host "📂 上下文目录已存在，保留用户数据" -ForegroundColor Gray
    }
}

# ============================================
# 清理临时仓库
# ============================================
if ($cleanupTemp -and (Test-Path $tempRepo)) {
    Remove-Item -Recurse -Force $tempRepo -ErrorAction SilentlyContinue
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
Write-Host "  ✅ /session-load, session-save, session-end"
Write-Host "  ✅ /context-check, context-sync"
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
    Write-Host "  /session-load" -ForegroundColor Cyan
}
Write-Host ""
