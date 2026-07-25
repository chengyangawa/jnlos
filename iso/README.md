# JNL OS ISO 镜像下载

## 最新版本：1.0.32

ISO 文件大小：8.1 GB，已分割为 9 个分卷上传到 GitHub Release。

### 下载方法

1. 前往 [Release 页面](https://github.com/chengyangawa/jnlos/releases/tag/v1.0.32)
2. 下载所有 9 个分卷文件：
   - `jnl-os-1-0-32-1.0.32-x86_64.iso.part00` (1.0 GB)
   - `jnl-os-1-0-32-1.0.32-x86_64.iso.part01` (1.0 GB)
   - `jnl-os-1-0-32-1.0.32-x86_64.iso.part02` (1.0 GB)
   - `jnl-os-1-0-32-1.0.32-x86_64.iso.part03` (1.0 GB)
   - `jnl-os-1-0-32-1.0.32-x86_64.iso.part04` (1.0 GB)
   - `jnl-os-1-0-32-1.0.32-x86_64.iso.part05` (1.0 GB)
   - `jnl-os-1-0-32-1.0.32-x86_64.iso.part06` (1.0 GB)
   - `jnl-os-1-0-32-1.0.32-x86_64.iso.part07` (1.0 GB)
   - `jnl-os-1-0-32-1.0.32-x86_64.iso.part08` (238 MB)

### 合并方法

将所有分卷文件放在同一目录下，然后执行：

**Linux / macOS：**
```bash
cat jnl-os-1-0-32-1.0.32-x86_64.iso.part* > jnl-os-1-0-32-1.0.32-x86_64.iso
```

**Windows (PowerShell)：**
```powershell
# 方法1：使用 Get-Content（较慢）
Get-Content jnl-os-1-0-32-1.0.32-x86_64.iso.part* -Encoding Byte -ReadCount 0 | Set-Content jnl-os-1-0-32-1.0.32-x86_64.iso -Encoding Byte

# 方法2：使用 cmd copy（推荐，更快）
cmd /c "copy /b jnl-os-1-0-32-1.0.32-x86_64.iso.part00+jnl-os-1-0-32-1.0.32-x86_64.iso.part01+jnl-os-1-0-32-1.0.32-x86_64.iso.part02+jnl-os-1-0-32-1.0.32-x86_64.iso.part03+jnl-os-1-0-32-1.0.32-x86_64.iso.part04+jnl-os-1-0-32-1.0.32-x86_64.iso.part05+jnl-os-1-0-32-1.0.32-x86_64.iso.part06+jnl-os-1-0-32-1.0.32-x86_64.iso.part07+jnl-os-1-0-32-1.0.32-x86_64.iso.part08 jnl-os-1-0-32-1.0.32-x86_64.iso"
```

### 验证完整性

合并后可验证 SHA256 校验和：
```bash
sha256sum jnl-os-1-0-32-1.0.32-x86_64.iso
```

### 写入 U 盘

**Linux：**
```bash
sudo dd if=jnl-os-1-0-32-1.0.32-x86_64.iso of=/dev/sdX bs=4M status=progress
```

**Windows：**
使用 [Rufus](https://rufus.ie/) 或 [balenaEtcher](https://etcher.balena.io/) 将 ISO 写入 U 盘。
