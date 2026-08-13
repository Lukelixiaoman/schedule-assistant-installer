# ============================================================
# 日程助手 - Windows 安装脚本 (PowerShell, 无需 Python)
# ============================================================
$ErrorActionPreference = "Stop"
Write-Host "=============================================="
Write-Host "  日程助手 一键安装 (Windows)"
Write-Host "=============================================="
Write-Host ""

# ---------- 1. 定位 current-space.json ----------
$currentSpace = $null
$candidates = @(
    "$env:USERPROFILE\.accio\state\current-space.json",
    "$env:APPDATA\accio\state\current-space.json",
    "$env:APPDATA\Accio\state\current-space.json",
    "$env:APPDATA\Accio Work\state\current-space.json"
)
foreach ($c in $candidates) {
    if (Test-Path $c) { $currentSpace = $c; break }
}

if (-not $currentSpace) {
    # 全局兜底搜索
    try {
        $currentSpace = Get-ChildItem -Path $env:USERPROFILE -Filter "current-space.json" -Recurse -ErrorAction SilentlyContinue -Force |
            Where-Object { $_.FullName -notmatch "\\Trash\\|\\AppData\\Local\\Temp\\" } |
            Select-Object -First 1 -ExpandProperty FullName
    } catch { }
}

if (-not $currentSpace) {
    Write-Host "[错误] 未找到 Accio Work 登录状态文件 (current-space.json)。" -ForegroundColor Red
    Write-Host "       请先登录 Accio Work 桌面端再运行本脚本。"
    Read-Host "按回车退出..."
    exit 1
}
Write-Host "[1/5] 已定位登录状态: $currentSpace"

# ---------- 2. 反推 accio 根目录 ----------
$accioRoot = $null
if ($currentSpace -like "*\.accio\*") {
    $accioRoot = Join-Path $env:USERPROFILE ".accio"
} elseif ($currentSpace -like "*Accio Work*") {
    $accioRoot = Join-Path $env:APPDATA "Accio Work"
} elseif ($currentSpace -like "*Accio*") {
    $accioRoot = Join-Path $env:APPDATA "Accio"
} else {
    $accioRoot = Split-Path (Split-Path (Split-Path $currentSpace))
}
Write-Host "[2/5] Accio 根目录: $accioRoot"

# ---------- 3. 读取 accountId (自动剥离 BOM) ----------
Write-Host "[3/5] 读取账号信息..."
$spaceText = [System.IO.File]::ReadAllText($currentSpace)
$space = $spaceText | ConvertFrom-Json
$accountId = [string]$space.accountId

if (-not $accountId) {
    Write-Host "[错误] current-space.json 中未找到 accountId" -ForegroundColor Red
    Read-Host "按回车退出..."
    exit 1
}

$agentsRoot = Join-Path $accioRoot ("accounts\" + $accountId + "\agents")
if (-not (Test-Path $agentsRoot)) { New-Item -ItemType Directory -Path $agentsRoot -Force | Out-Null }

# ---------- 4. 生成新 Agent ID ----------
$agentId = "MID-" + [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() + "-" + ([guid]::NewGuid().ToString("N").Substring(0,8)).ToUpper()
$agentDir = Join-Path $agentsRoot $agentId
$agentCore = Join-Path $agentDir "agent-core"
New-Item -ItemType Directory -Path (Join-Path $agentCore "skills") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $agentDir "permissions") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $agentDir "runtime") -Force | Out-Null

# ---------- 5. 复制 agent-core 文件 ----------
$srcCore = Join-Path (Split-Path $MyInvocation.MyCommand.Path) "agent-core"
if (-not (Test-Path $srcCore)) {
    Write-Host "[错误] 未找到 agent-core 目录: $srcCore" -ForegroundColor Red
    Read-Host "按回车退出..."
    exit 1
}

$copied = 0
Get-ChildItem -Path $srcCore -Recurse -File -Force | ForEach-Object {
    $name = $_.Name
    if ($name -eq ".DS_Store" -or $name -eq "skills.jsonc" -or $name -eq "USER.md" -or $name -eq "MEMORY.md") { return }
    $rel = $_.FullName.Substring($srcCore.Length).TrimStart("\")
    $dst = Join-Path $agentCore $rel
    New-Item -ItemType Directory -Path (Split-Path $dst) -Force | Out-Null
    Copy-Item -Path $_.FullName -Destination $dst -Force
    $copied++
}

# ---------- 6. 生成 profile.jsonc (手动拼 JSON, 规避 ConvertTo-Json) ----------
$profile = @"
// Accio Agent 配置，可由 UI 或 API 修改

{
  "id": "$agentId",
  "accountId": "$accountId",
  "name": "日程助手",
  "description": "帮我搭建日程看板和提醒",
  "vibe": "professional",
  "model": {
    "provider": "auto",
    "name": "auto"
  },
  "runtime": "local",
  "toolInclude": [
    "list",
    "read",
    "grep",
    "glob",
    "write",
    "edit",
    "web_search",
    "web_fetch",
    "bash",
    "process",
    "cron",
    "image_generate",
    "image_edit",
    "get_time",
    "ask_user",
    "present_files",
    "skill",
    "plugin",
    "memory_search",
    "memory_get",
    "task_create",
    "task_get",
    "task_update",
    "task_list",
    "sessions_spawn",
    "video_generate_submit"
  ],
  "creator": "user",
  "agentType": "default",
  "pluginIds": [
    "documents",
    "presentations",
    "spreadsheets",
    "okki-crm",
    "wecom-assistant"
  ],
  "localMemoryIndex": true,
  "skillHarvestMode": "auto"
}
"@
$profilePath = Join-Path $agentDir "profile.jsonc"
[System.IO.File]::WriteAllText($profilePath, $profile, (New-Object System.Text.UTF8Encoding($true)))

# ---------- 7. 生成 skills.jsonc ----------
$skillFiles = Get-ChildItem -Path (Join-Path $agentCore "skills") -Filter "SKILL.md" -Recurse -File -Force
$skillEntries = @()
foreach ($sf in $skillFiles) {
    $skillDir = $sf.DirectoryName
    $skillId = Split-Path $skillDir -Leaf
    $entryRel = $skillDir.Substring((Join-Path $agentCore "skills").Length).TrimStart("\")
    $desc = ""
    $head = [System.IO.File]::ReadAllText($sf.FullName, [System.Text.Encoding]::UTF8)
    foreach ($line in ($head -split "`r?`n")) {
        if ($line.StartsWith("description:")) {
            $desc = $line.Substring("description:".Length).Trim().TrimStart(">").Trim()
            break
        }
    }
    $escId = $skillId.Replace("\", "\\").Replace('"', '\"')
    $escDesc = $desc.Replace("\", "\\").Replace('"', '\"')
    $installPath = $skillDir.Replace("\", "\\")
    $entryJson = "`n    {`n      ""id"": ""$escId"",`n      ""name"": ""$escId"",`n      ""version"": """",`n      ""enabled"": true,`n      ""kind"": ""directory"",`n      ""entryName"": ""$entryRel"",`n      ""description"": ""$escDesc"",`n      ""installPath"": ""$installPath""`n    }"
    $skillEntries += $entryJson
}
$skillsJson = "{`n  ""skills"": [" + ($skillEntries -join ",") + "`n  ]`n}"
$skillsPath = Join-Path $agentCore "skills\skills.jsonc"
[System.IO.File]::WriteAllText($skillsPath, $skillsJson, (New-Object System.Text.UTF8Encoding($true)))

Write-Host "[4/5] 已安装 Agent: $agentId"
Write-Host "       目录: $agentDir"
Write-Host "       复制文件数: $copied | 技能数: $($skillEntries.Count)"

Write-Host ""
Write-Host "=============================================="
Write-Host "  安装完成！"
Write-Host "=============================================="
Write-Host "  接下来："
Write-Host "  1. 完全退出 Accio Work（不是最小化）"
Write-Host "  2. 重新打开 Accio Work"
Write-Host "  3. 在智能体列表中找到「日程助手」"
Write-Host ""
Read-Host "按回车退出..."
