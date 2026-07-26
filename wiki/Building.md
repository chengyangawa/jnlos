# 构建指南

## 概述

本指南介绍如何从源代码构建 JNL OS ISO 镜像。

## 系统要求

| 项目 | 要求 |
|------|------|
| 操作系统 | Arch Linux 或基于 Arch 的发行版 |
| 内存 | 8GB 以上 |
| 磁盘空间 | 50GB 以上 |
| 网络 | 稳定的网络连接 |

## 安装依赖

```bash
# 安装 archiso
sudo pacman -S archiso

# 安装其他依赖
sudo pacman -S git rsync wget
```

## 获取源代码

```bash
# 克隆仓库
git clone https://github.com/chengyangawa/jnlos.git
cd jnlos/source

# 查看分支
git branch -a

# 切换到开发分支（如有）
git checkout dev
```

## 构建 ISO

### 基本构建命令

```bash
cd src/archiso-profile

# 构建 ISO（使用 LZ4 压缩）
mkarchiso -v -w /tmp/archiso-tmp -o ../out .
```

### 构建参数

```bash
# 指定工作目录
mkarchiso -w /path/to/workdir

# 指定输出目录
mkarchiso -o /path/to/output

# 启用调试模式
mkarchiso -d

# 详细输出
mkarchiso -v
```

### 构建时间

构建时间取决于：

- 网络速度（下载软件包）
- CPU 性能
- 内存大小

通常需要 15-30 分钟。

## ISO 文件位置

构建完成后，ISO 文件位于：

```
../out/jnl-os-<version>-x86_64.iso
```

## 构建流程

1. **初始化工作目录**：创建临时工作目录
2. **复制配置文件**：复制 archiso 配置
3. **安装基础系统**：使用 pacstrap 安装基础系统
4. **复制 Airootfs**：复制自定义文件系统
5. **配置系统**：设置 locale、时区、用户等
6. **安装软件包**：安装桌面环境、主题、播放器等
7. **生成 initramfs**：生成启动镜像
8. **创建 ISO**：使用 xorriso 创建 ISO 镜像

## 自定义构建

### 添加软件包

编辑 `src/archiso-profile/packages.x86_64` 文件，添加需要的软件包：

```
# 额外软件包
vim
git
neovim
```

### 修改配置

编辑 `src/archiso-profile/airootfs/etc/` 下的配置文件：

- `locale.conf` - 语言配置
- `timezone` - 时区配置
- `hostname` - 主机名

### 修改启动脚本

编辑 `src/archiso-profile/airootfs/usr/bin/jnl-installer-worker` 修改安装逻辑。

## 测试 ISO

### 在虚拟机中测试

```bash
# 使用 QEMU 测试
qemu-system-x86_64 -m 4096 -cdrom jnl-os-<version>-x86_64.iso

# 使用 VirtualBox
# 新建虚拟机，选择 ISO 文件作为启动盘
```

### 在真实硬件上测试

1. 将 ISO 写入 U 盘
2. 从 U 盘启动
3. 测试安装流程和系统功能

## 构建故障排除

### 网络问题

- 检查网络连接
- 更换镜像源：编辑 `src/archiso-profile/pacman.conf`
- 使用代理：设置 `http_proxy` 环境变量

### 磁盘空间不足

- 清理临时文件：`rm -rf /tmp/archiso-tmp`
- 扩大磁盘空间

### 软件包安装失败

- 检查软件包名称是否正确
- 更新软件包数据库：`sudo pacman -Sy`
- 检查依赖关系

### 构建超时

- 增加内存
- 使用更快的 CPU
- 优化镜像源

## 发布构建

### 创建 Release

```bash
# 登录 GitHub CLI
gh auth login

# 创建 Release
gh release create v1.0.33 \
  --title "Release 1.0.33" \
  --notes "New features and bug fixes"

# 上传文件
gh release upload v1.0.33 jnl-os-1-0-33-1.0.33-x86_64.iso
```

### 分卷上传

对于大文件，需要分卷上传：

```bash
# 分割文件（每 1GB 一个分卷）
split -b 1G jnl-os-1-0-33-1.0.33-x86_64.iso jnl-os-1-0-33-1.0.33-x86_64.iso.part

# 上传所有分卷
gh release upload v1.0.33 jnl-os-1-0-33-1.0.33-x86_64.iso.part*
```

## CI/CD

项目支持 GitHub Actions 自动构建：

```yaml
name: Build ISO

on:
  push:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    - name: Build ISO
      run: |
        cd src/archiso-profile
        mkarchiso -v -w /tmp/archiso-tmp -o ../out .
    - name: Upload to Release
      uses: softprops/action-gh-release@v1
      with:
        files: out/*.iso
```

## 版本管理

版本号格式：`超大版本.大版本.小版本`

- 超大版本：alpha → beta → class → release
- 大版本：1.0 → 2.0
- 小版本：每次编译递增

示例：`alpha1.0.32`
