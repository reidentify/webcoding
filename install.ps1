# Webcoding 一键安装脚本 (Windows PowerShell)
# 用法 (在 PowerShell 中运行):
#   irm https://raw.githubusercontent.com/HsMirage/webcoding/main/install.ps1 | iex
# 或指定安装目录:
#   $env:WEBCODING_DIR = "C:\webcoding"; irm https://raw.githubusercontent.com/HsMirage/webcoding/main/install.ps1 | iex

$ErrorActionPreference = 'Stop'

$REPO        = 'https://github.com/HsMirage/webcoding.git'
$INSTALL_DIR = if ($env:WEBCODING_DIR) { $env:WEBCODING_DIR } else { Join-Path $HOME 'webcoding' }

function Write-Info    { param($msg) Write-Host "[Webcoding] $msg" -ForegroundColor Cyan   }
function Write-Success { param($msg) Write-Host "[Webcoding] $msg" -ForegroundColor Green  }
function Write-Warn    { param($msg) Write-Host "[Webcoding] $msg" -ForegroundColor Yellow }
function Write-Err     { param($msg) Write-Host "[Webcoding] ERROR: $msg" -ForegroundColor Red; exit 1 }

# ── 检查依赖 ──────────────────────────────────────────────────
Write-Info '检查依赖环境...'

if (-not (Get-Command git  -ErrorAction SilentlyContinue)) { Write-Err '未找到 git。请先安装 git: https://git-scm.com/' }
if (-not (Get-Command node -ErrorAction SilentlyContinue)) { Write-Err '未找到 Node.js。请先安装 Node.js >= 18: https://nodejs.org/' }
if (-not (Get-Command npm  -ErrorAction SilentlyContinue)) { Write-Err '未找到 npm，请确认 Node.js 安装完整。' }

$nodeVer = (node -e 'process.stdout.write(process.versions.node.split(".")[0])' 2>$null)
if ([int]$nodeVer -lt 18) {
    Write-Err "Node.js 版本过低 (当前: $(node -v))，需要 >= 18。请升级: https://nodejs.org/"
}

Write-Success "Node.js $(node -v)  npm $(npm -v)  git $(git --version) — 全部就绪"

# ── 安装 / 更新 ────────────────────────────────────────────────
if (Test-Path (Join-Path $INSTALL_DIR '.git')) {
    Write-Warn "检测到已有安装目录: $INSTALL_DIR"
    $yn = Read-Host '是否拉取最新代码进行更新? (y/N)'
    if ($yn -match '^[Yy]') {
        Write-Info '拉取最新代码...'
        git -C $INSTALL_DIR pull --ff-only
    } else {
        Write-Info '跳过更新，使用现有安装目录继续。'
    }
} elseif (Test-Path $INSTALL_DIR) {
    Write-Err "目录已存在但不是 git 仓库: $INSTALL_DIR`n请手动删除后重试: Remove-Item -Recurse -Force '$INSTALL_DIR'"
} else {
    Write-Info "克隆仓库到 $INSTALL_DIR ..."
    git clone --depth 1 $REPO $INSTALL_DIR
}

Set-Location $INSTALL_DIR

Write-Info '安装 Node.js 依赖...'
npm install --omit=dev

# ── 写入快捷启动脚本 ───────────────────────────────────────────
$launcherDir = $INSTALL_DIR
$launcherPath = Join-Path $launcherDir 'webcoding.cmd'

@"
@echo off
node ""$INSTALL_DIR\server.js"" %*
"@ | Set-Content -Encoding ASCII $launcherPath

# 尝试将安装目录加入用户 PATH
$userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
if ($userPath -notlike "*$INSTALL_DIR*") {
    [Environment]::SetEnvironmentVariable('PATH', "$userPath;$INSTALL_DIR", 'User')
    Write-Warn "已将 $INSTALL_DIR 加入用户 PATH，重新打开终端后生效。"
}

# ── 完成提示 ───────────────────────────────────────────────────
Write-Host ''
Write-Success '================================================'
Write-Success ' Webcoding 安装完成！'
Write-Success '================================================'
Write-Host ''
Write-Host "  启动命令 : webcoding"                      -ForegroundColor White
Write-Host "  或双击   : $INSTALL_DIR\webcoding.cmd"      -ForegroundColor White
Write-Host "  或直接   : node $INSTALL_DIR\server.js"     -ForegroundColor White
Write-Host "  访问地址 : http://localhost:8001"            -ForegroundColor White
Write-Host ''
Write-Info '首次启动时会自动生成登录密码并打印在控制台。'
Write-Host ''

$startNow = Read-Host '现在立即启动 Webcoding? (Y/n)'
if ($startNow -notmatch '^[Nn]') {
    node "$INSTALL_DIR\server.js"
} else {
    Write-Info "安装完成，稍后运行 'webcoding' 或双击 webcoding.cmd 启动。"
}
