# 构建说明

本文档说明如何在 Windows 上构建 Java Net Lava OS 的 ISO 镜像。

## 前置条件

1. **安装 WSL2**：以管理员身份运行 PowerShell，执行 `wsl --install`。
2. **安装 Arch Linux WSL**：
   - 推荐 [ArchWSL](https://github.com/yuk7/ArchWSL)
   - 安装后将发行版名称注册为 `ArchLinux`
   - 首次启动后建议执行 `sudo pacman -Syu` 更新系统

## 自动构建（推荐）

在 PowerShell 中执行：

```powershell
cd "g:\FEPT\FEPT\A_industry code\Code\OS\Java Net Lava OS"
.\build\build.ps1
```

`build.ps1` 会自动完成：
1. 检测 WSL2 与 Arch Linux 发行版
2. 调用 WSL 中的 `build.sh` 执行完整构建流程
3. 将 ISO 输出到 `out/` 目录

等待构建完成后，ISO 镜像位于：

```
g:\FEPT\FEPT\A_industry code\Code\OS\Java Net Lava OS\out\
```

同时会生成对应的 `.iso.sha256sum` 校验文件。

## 手动构建步骤

如需逐步调试，可手动进入 WSL 执行各脚本：

```bash
# 1. 进入 WSL Arch Linux
wsl -d ArchLinux

# 2. 进入工程 build 目录（需先将工程源码同步到 WSL）
cd ~/jnl-os-build/build/

# 3. 准备 WSL Arch 环境（安装依赖、创建工作目录）
bash wsl-setup.sh

# 4. 同步源码到 WSL 工作目录
bash sync-to-wsl.sh

# 5. 执行构建
bash build.sh
```

## 脚本说明

| 脚本 | 运行环境 | 作用 |
| --- | --- | --- |
| `build.ps1` | Windows PowerShell | 构建入口，调用 WSL 执行构建 |
| `wsl-setup.sh` | WSL (bash) | 检测 Arch 发行版、安装构建依赖、创建工作目录 |
| `sync-to-wsl.sh` | WSL (bash) | 将源码同步到 WSL 工作目录 |
| `build.sh` | WSL (bash) | 调用 mkarchiso 构建 ISO 并输出到 `out/` |

## 构建产物

- `out/jnl-os-*.iso`：可启动的 ISO 镜像
- `out/jnl-os-*.iso.sha256sum`：ISO 的 SHA256 校验值

## 故障排查

- **WSL 未检测到 Arch**：确认已通过 `wsl -l -q` 列出 ArchLinux 发行版。
- **pacman 安装失败**：检查网络连接，或更换镜像源（编辑 `/etc/pacman.d/mirrorlist`）。
- **mkarchiso 报错**：确保 `src/archiso-profile/` 中存在有效的 archiso profile（`profiledef.sh` 与 `airootfs/`）。
- **ISO 未输出到 out/**：确认 G 盘已正确挂载到 WSL 的 `/mnt/g`。
