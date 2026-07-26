@echo off
chcp 65001 >nul
echo ================================================
echo    Java Net Lava OS 构建脚本（Windows 入口）
echo ================================================
echo.

set "PROJECT_ROOT=%~dp0.."
set "OUT_DIR=%PROJECT_ROOT%\out"

echo [INFO] 项目根目录：%PROJECT_ROOT%
echo [INFO] 输出目录：%OUT_DIR%
echo.

echo [INFO] 检测 WSL 安装状态...
wsl --help >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERR]  未检测到 WSL。请先安装 WSL2 与 Arch Linux。
    echo        安装命令（管理员 PowerShell）：wsl --install
    echo        Arch Linux WSL：https://github.com/yuk7/ArchWSL
    pause
    exit /b 1
)
echo [OK]   WSL 已安装

echo.
echo [INFO] 列出可用 WSL 发行版：
wsl -l -q

echo.
echo [INFO] 检测 Arch Linux 发行版...
set "ARCH_DISTRO="
for /f "tokens=*" %%d in ('wsl -l -q') do (
    for /f "tokens=*" %%i in ('wsl -d "%%d" -- bash -c "grep ''^ID='' /etc/os-release 2>/dev/null | cut -d= -f2"') do (
        if "%%i"=="arch" set "ARCH_DISTRO=%%d"
    )
)

if not defined ARCH_DISTRO (
    echo [ERR]  未找到 Arch Linux WSL 发行版
    echo        请安装 Arch Linux 到 WSL
    pause
    exit /b 1
)
echo [OK]   使用 WSL 发行版：%ARCH_DISTRO%

echo.
echo [INFO] 获取 WSL 用户名...
for /f "tokens=*" %%u in ('wsl -d "%ARCH_DISTRO%" -- whoami') do set "WSL_USER=%%u"
echo [INFO] WSL 用户：%WSL_USER%

echo.
echo [INFO] 同步 build 脚本到 WSL...
wsl -d "%ARCH_DISTRO%" -- bash -c "mkdir -p ~/jnl-os-build/build"
set "WIN_BUILD_DIR=%~dp0"
wsl -d "%ARCH_DISTRO%" -- bash -c "cp -r '%WIN_BUILD_DIR:\=/%'* ~/jnl-os-build/build/"
wsl -d "%ARCH_DISTRO%" -- bash -c "chmod 755 ~/jnl-os-build/build/*.sh"
echo [OK]   build 脚本已同步到 WSL

echo.
echo [INFO] 启动构建（在 WSL Arch Linux 中执行）...
echo ================================================
echo.

wsl -d "%ARCH_DISTRO%" -- bash -c "cd ~ && bash ~/jnl-os-build/build/build.sh"
set "EXIT_CODE=%errorlevel%"

echo.
echo ================================================
if %EXIT_CODE% equ 0 (
    echo [OK]   构建成功！
    echo.
    echo [INFO] ISO 输出位置：%OUT_DIR%
    dir "%OUT_DIR%\*.iso" /b 2>nul
) else (
    echo [ERR]  构建失败，退出码：%EXIT_CODE%
)
pause
