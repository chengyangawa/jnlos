<#
.SYNOPSIS
    Java Net Lava OS ISO 构建脚本（Windows 入口）

.DESCRIPTION
    在 Windows PowerShell 中调用此脚本，将自动：
      1. 检测 WSL 是否已安装
      2. 检测 WSL 中的 Arch Linux 发行版
      3. 同步 build/ 脚本到 WSL 工作目录
      4. 在 WSL Arch 中执行 build.sh
      5. ISO 输出到 Windows 项目目录的 out\ 子目录

.EXAMPLE
    .\build.ps1
    直接执行构建

.EXAMPLE
    .\build.ps1 -DistroName ArchLinux
    指定 WSL 发行版名称执行构建

.NOTES
    依赖：Windows 10 1809+、WSL2、Arch Linux WSL 发行版
#>

# ============================================================================
# 严格模式与参数定义
# ============================================================================
[CmdletBinding()]
param(
    # 可选：显式指定 WSL Arch Linux 发行版名称
    # 若未指定，则自动检测 /etc/os-release 中 ID=arch 的发行版
    [string]$DistroName
)

# 遇到错误即停止
$ErrorActionPreference = "Stop"

# ============================================================================
# 辅助函数：Windows 路径转 WSL 路径
# ----------------------------------------------------------------------------
# 将 Windows 路径（如 G:\FEPT\...\Java Net Lava OS\build）
# 转换为 WSL 可访问路径（如 /mnt/g/FEPT/.../Java Net Lava OS/build）
# 规则：
#   - 盘符 G: -> /mnt/g/
#   - 反斜杠 \ -> 正斜杠 /
# 必须在使用前定义（PowerShell 要求函数先定义后调用）
# ============================================================================
function Convert-WindowsPathToWsl {
    param([string]$WinPath)
    if (-not $WinPath -or $WinPath.Length -lt 2) { return $WinPath }
    # 取盘符（如 G）
    $drive = $WinPath.Substring(0, 1).ToLower()
    # 去掉 "X:" 前缀，剩余部分反斜杠转正斜杠
    $rest = $WinPath.Substring(2) -replace '\\', '/'
    return "/mnt/$drive$rest"
}

# ============================================================================
# 颜色输出辅助函数
# ============================================================================
function Write-Info($msg) { Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "[OK]   $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Err($msg)  { Write-Host "[ERR]  $msg" -ForegroundColor Red }

# ============================================================================
# 项目路径定义
# ----------------------------------------------------------------------------
# ScriptDir   - 本脚本所在目录（build\）
# ProjectRoot - 项目根目录（Java Net Lava OS\）
# OutDir      - ISO 输出目录（out\）
# ============================================================================
$ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$OutDir      = Join-Path $ProjectRoot "out"

# ============================================================================
# 输出构建起始信息
# ============================================================================
Write-Host "================================================" -ForegroundColor Blue
Write-Host "   Java Net Lava OS 构建脚本（Windows 入口）" -ForegroundColor Blue
Write-Host "================================================" -ForegroundColor Blue
Write-Host
Write-Info "项目根目录：$ProjectRoot"
Write-Info "输出目录：$OutDir"
Write-Host

# ============================================================================
# 步骤 1：检测 WSL 是否已安装
# ----------------------------------------------------------------------------
# 通过 Get-Command 检查 wsl.exe 是否存在于 PATH 中
# 若未安装，提示用户安装 WSL2
# ============================================================================
Write-Info "检测 WSL 安装状态..."

$wslExe = Get-Command wsl -ErrorAction SilentlyContinue
if (-not $wslExe) {
    Write-Err "未检测到 WSL。请先安装 WSL2 与 Arch Linux。"
    Write-Host "  安装命令（管理员 PowerShell）：wsl --install"
    Write-Host "  Arch Linux WSL 发行版：https://github.com/yuk7/ArchWSL"
    exit 1
}
Write-Ok "WSL 已安装"

# ============================================================================
# 步骤 2：列出可用 WSL 发行版
# ----------------------------------------------------------------------------
# wsl -l -q 输出可能使用 UTF-16 编码，需要处理空字符与空行
# ============================================================================
Write-Info "可用 WSL 发行版："

# 获取发行版列表（去除 UTF-16 BOM 与空行）
$distrosRaw = wsl -l -q 2>$null
$distros = @()
foreach ($line in $distrosRaw) {
    # 去除 NULL 字符（UTF-16 转 ASCII 残留）与首尾空白
    $clean = ($line -replace "`0", "").Trim()
    if ($clean) { $distros += $clean }
}

if ($distros.Count -eq 0) {
    Write-Err "未找到任何 WSL 发行版"
    Write-Host "  请先安装 Arch Linux WSL 发行版："
    Write-Host "    方式1：从 https://github.com/yuk7/ArchWSL 下载"
    Write-Host "    方式2：使用 Microsoft Store 中的 ArchWSL"
    exit 1
}
foreach ($d in $distros) {
    Write-Host "  - $d" -ForegroundColor White
}

# ============================================================================
# 步骤 3：检测 Arch Linux 发行版
# ----------------------------------------------------------------------------
# 若用户未通过 -DistroName 指定，则遍历所有发行版，
# 通过读取 /etc/os-release 中的 ID= 字段判断是否为 Arch
# ============================================================================
if ($DistroName) {
    # 用户显式指定了发行版名称
    Write-Info "使用指定的 WSL 发行版：$DistroName"
    $archDistro = $DistroName
    # 校验指定的发行版是否存在
    if ($distros -notcontains $archDistro) {
        Write-Err "指定的发行版 '$archDistro' 不在可用列表中"
        exit 1
    }
} else {
    # 自动检测 Arch Linux 发行版
    Write-Info "检测 Arch Linux 发行版..."
    $archDistro = $null
    foreach ($d in $distros) {
        # 读取 /etc/os-release 中的 ID= 字段
        $osId = wsl -d $d -- bash -c "grep '^ID=' /etc/os-release 2>/dev/null | cut -d= -f2" 2>$null
        if ($osId) {
            $osId = ($osId -replace "`0", "").Trim()
            if ($osId -eq "arch") {
                $archDistro = $d
                break
            }
        }
    }

    if (-not $archDistro) {
        Write-Err "未找到 Arch Linux WSL 发行版"
        Write-Host "  请安装 Arch Linux 到 WSL："
        Write-Host "    方式1：从 https://github.com/yuk7/ArchWSL 下载"
        Write-Host "    方式2：使用 archlinux 官方 WSL 镜像"
        exit 1
    }
}
Write-Ok "使用 WSL 发行版：$archDistro"

# ============================================================================
# 步骤 4：获取 WSL 用户名与同步 build 脚本
# ----------------------------------------------------------------------------
# 通过 wsl -- whoami 获取 WSL 中的默认用户名，
# 然后通过 \\wsl$\<distro>\home\<user>\jnl-os-build\build\ 路径访问 WSL 文件系统
# ============================================================================
Write-Info "同步 build 脚本到 WSL..."

# 获取 WSL 默认用户名
$wslUser = (wsl -d $archDistro -- whoami 2>$null) -replace "`0", ""
$wslUser = $wslUser.Trim()
if (-not $wslUser) {
    Write-Err "无法获取 WSL 用户名"
    exit 1
}
Write-Info "WSL 用户：$wslUser"

# 在 WSL 中创建工作目录
wsl -d $archDistro -- bash -c "mkdir -p ~/jnl-os-build/build" 2>$null | Out-Null

# 通过 \\wsl$\ UNC 路径访问 WSL 文件系统并同步 build 脚本
$wslBuildPath = "\\wsl$\$archDistro\home\$wslUser\jnl-os-build\build"
if (Test-Path $wslBuildPath) {
    try {
        # 复制 build\ 下所有文件到 WSL（保留子目录结构）
        Copy-Item -Path "$ScriptDir\*" -Destination $wslBuildPath -Recurse -Force
        Write-Ok "build 脚本已同步到 WSL"
    } catch {
        Write-Warn "通过 UNC 路径同步失败：$_"
        Write-Info "尝试通过 wsl 命令传输..."
        # 兜底方案：通过 wsl 命令读取 Windows 文件系统复制
        $wslScriptPath = Convert-WindowsPathToWsl -WinPath $ScriptDir
        wsl -d $archDistro -- bash -c "cp -r '$wslScriptPath/'* ~/jnl-os-build/build/ 2>/dev/null || true"
    }
} else {
    Write-Warn "无法访问 WSL 文件系统路径：$wslBuildPath"
    Write-Info "尝试通过 wsl 命令传输..."
    $wslScriptPath = Convert-WindowsPathToWsl -WinPath $ScriptDir
    wsl -d $archDistro -- bash -c "cp -r '$wslScriptPath/'* ~/jnl-os-build/build/ 2>/dev/null || true"
}

# 设置脚本可执行权限（WSL 中复制后可能丢失）
wsl -d $archDistro -- bash -c "chmod 755 ~/jnl-os-build/build/*.sh 2>/dev/null || true" 2>$null | Out-Null

# ============================================================================
# 步骤 5：在 WSL 中执行 build.sh
# ----------------------------------------------------------------------------
# build.sh 会自动完成：环境检查、源码同步、主题注入、mkarchiso 构建、
# ISO 复制到 Windows 输出目录、SHA256 校验生成
# ============================================================================
Write-Host
Write-Info "启动构建（在 WSL Arch Linux 中执行 build.sh）..."
Write-Host

# 执行 build.sh（保持 stdin 连接以便 sudo 提示密码）
$result = wsl -d $archDistro -- bash -c "cd ~ && bash ~/jnl-os-build/build/build.sh"
$exitCode = $LASTEXITCODE

# ============================================================================
# 步骤 6：构建结果输出
# ============================================================================
Write-Host
if ($exitCode -eq 0) {
    Write-Ok "构建成功！"
    Write-Host
    Write-Host "ISO 输出位置：$OutDir" -ForegroundColor White
    Write-Host

    # 列出输出目录中的 ISO 与校验文件
    if (Test-Path $OutDir) {
        $isoFiles = Get-ChildItem "$OutDir\*.iso" -ErrorAction SilentlyContinue
        if ($isoFiles) {
            Write-Host "ISO 文件：" -ForegroundColor White
            $isoFiles | Format-Table Name, @{N='Size(MB)';E={[math]::Round($_.Length/1MB,2)}}, LastWriteTime -AutoSize
        }
        $shaFiles = Get-ChildItem "$OutDir\*.sha256sum" -ErrorAction SilentlyContinue
        if ($shaFiles) {
            Write-Host "校验文件：" -ForegroundColor White
            $shaFiles | Format-Table Name, LastWriteTime -AutoSize
        }
    } else {
        Write-Warn "输出目录不存在：$OutDir"
    }

    Write-Host
    Write-Host "下一步：" -ForegroundColor White
    Write-Host "  1. 使用 Rufus 或 balenaEtcher 将 ISO 写入 U 盘"
    Write-Host "  2. 从 U 盘启动进入 Java Net Lava OS"
    Write-Host "  3. 在桌面双击 '安装 Java Net Lava OS' 进行系统安装"
} else {
    Write-Err "构建失败，退出码：$exitCode"
    Write-Host "  请查看上方 WSL 输出日志中的错误信息。" -ForegroundColor White
    Write-Host "  常见问题：" -ForegroundColor White
    Write-Host "    - pacman 安装失败：检查网络或更换镜像源"
    Write-Host "    - mkarchiso 报错：确认 archiso-profile 配置完整"
    Write-Host "    - ISO 未输出：确认 G 盘已挂载到 /mnt/g"
    exit $exitCode
}
