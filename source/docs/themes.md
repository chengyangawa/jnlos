# 12 套主题说明

> Java Net Lava OS 内置 12 套原创桌面主题，覆盖深色/浅色/极光/岩浆/玫瑰等风格，
> 每套主题均包含 GTK3、GTK4、GNOME Shell、图标与壁纸的完整资源。

---

## 1. 主题列表

| # | 主题键 | 主题名 | 显示名 | 风格 | 主色 | 背景 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `default` | JNL-Default | JNL Default | 深色（蓝紫） | `#89b4fa` | `#1e1e2e` |
| 2 | `arctic` | JNL-Arctic | JNL Arctic | 浅色（北极白） | `#3b9eff` | `#d8e0e8` |
| 3 | `aurora` | JNL-Aurora | JNL Aurora | 深色（极光渐变） | `#7affc8` | `#0a1e2e` |
| 4 | `forest` | JNL-Forest | JNL Forest | 深色（森林绿） | `#5fd97a` | `#1a2820` |
| 5 | `gold` | JNL-Gold | JNL Gold | 深色（金色） | `#f5c842` | `#2e2818` |
| 6 | `lavender` | JNL-Lavender | JNL Lavender | 深色（薰衣草紫） | `#b888f5` | `#2a2438` |
| 7 | `light` | JNL-Light | JNL Light | 浅色（蓝色） | `#1e66f5` | `#dce0e8` |
| 8 | `magma` | JNL-Magma | JNL Magma | 深色（岩浆红黑） | `#ff3c3c` | `#1a0e0e` |
| 9 | `midnight` | JNL-Midnight | JNL Midnight | 深色（午夜黑） | `#5a7aff` | `#0a0a0f` |
| 10 | `ocean` | JNL-Ocean | JNL Ocean | 深色（海洋蓝） | `#4cc4e6` | `#0f1e2e` |
| 11 | `rose` | JNL-Rose | JNL Rose | 深色（玫瑰红） | `#f55a8c` | `#2e1e28` |
| 12 | `sunset` | JNL-Sunset | JNL Sunset | 深色（日落橙红） | `#ff8c5a` | `#2e1a1e` |

> 主题键用于 `switch-theme.sh` 命令行参数与 `colors/*.sh` 配色文件名；
> 主题名（JNL-Default 等）用于 `gsettings` 中 GTK/Shell 主题与图标主题标识。

---

## 2. 主题包含内容

每套主题为一个目录，位于 `/usr/share/themes/<主题名>/`，包含：

```
/usr/share/themes/JNL-Default/
├── gtk-3.0/
│   ├── gtk.css              # GTK3 主题样式表
│   └── assets/             # GTK3 控件素材（按钮、滚动条等）
├── gtk-4.0/
│   ├── gtk.css              # GTK4 主题样式表
│   └── assets/             # GTK4 控件素材
├── gnome-shell/
│   ├── gnome-shell.css      # GNOME Shell 主题样式（顶栏、概览、消息通知）
│   ├── gnome-shell-theme.gresource.xml   # Shell 资源描述
│   └── pad-osd.css          # 屏幕键盘 OSD 样式
├── icons/
│   ├── index.theme          # 图标主题索引
│   └── scalable/            # SVG 图标（actions/apps/categories/devices/...）
└── wallpaper.svg            # 主题配套壁纸（渐变 SVG）
```

### 各部分作用

| 部分 | 作用 |
| --- | --- |
| **GTK3 (`gtk-3.0/`)** | 影响 GTK3 应用窗口控件（按钮、输入框、菜单等） |
| **GTK4 (`gtk-4.0/`)** | 影响 GTK4 / libadwaita 应用（通过 `color-scheme` 与用户 CSS） |
| **GNOME Shell (`gnome-shell/`)** | 影响顶栏、活动概览、消息通知、窗口列表等 Shell UI |
| **图标 (`icons/`)** | 应用图标、文件夹图标、状态图标、操作图标等 |
| **壁纸 (`wallpaper.svg`)** | 桌面背景与锁屏背景，自动随主题切换 |

---

## 3. 主题切换方法

### 方式 1：桌面快捷方式（推荐）

1. 在桌面双击 **"主题切换"** 图标
2. 弹出 zenity 主题列表对话框
3. 选择目标主题，点击确定
4. 系统自动应用 GTK3 / GTK4 / 图标 / Shell / 壁纸

底层调用 `/usr/local/bin/switch-theme-gui.sh`，它再调用
`/usr/local/bin/switch-theme.sh <主题名>`。

### 方式 2：命令行

```bash
# 切换到 ocean 主题
switch-theme.sh ocean

# 切换到 forest 主题
switch-theme.sh forest

# 切换到默认主题
switch-theme.sh default

# 查看可用主题
switch-theme.sh
```

`switch-theme.sh` 会自动应用以下设置：

- `org.gnome.desktop.interface gtk-theme` → 主题名（如 `JNL-Ocean`）
- `org.gnome.desktop.interface icon-theme` → 主题名 + `-Icons`（如 `JNL-Ocean-Icons`）
- `org.gnome.desktop.interface color-scheme` → `prefer-dark` 或 `prefer-light`
- `org.gnome.shell.extensions.user-theme name` → 主题名（GNOME Shell 外观）
- `org.gnome.desktop.background picture-uri` → 主题壁纸路径
- 复制 GTK4 用户 CSS 到 `~/.config/gtk-4.0/gtk.css`

### 方式 3：GNOME 调整（图形界面）

1. 打开 **"调整"**（gnome-tweaks）
2. 进入 **"外观"** 标签
3. 在 **"应用程序**" 下拉选择 GTK 主题（如 JNL-Ocean）
4. 在 **"图标**" 下拉选择图标主题（如 JNL-Ocean-Icons）
5. 在 **"Shell**" 下拉选择 Shell 主题（需先启用 user-theme 扩展）

### GDM 登录界面主题

GDM 运行于 `gdm` 用户，无法通过普通 gsettings 切换。如需同步 GDM 主题：

```bash
# 1. 将 Shell 主题资源复制到系统目录
sudo cp -r /usr/share/themes/JNL-Ocean/gnome-shell /usr/share/themes/JNL-Ocean/

# 2. 在 gdm 用户下设置
sudo -u gdm dbus-launch gsettings set org.gnome.shell.extensions.user-theme name JNL-Ocean

# 3. 重启 GDM
sudo systemctl restart gdm
```

---

## 4. 自定义主题方法

### 4.1 添加新主题配色

在 `src/themes/colors/` 下创建新的 `.sh` 配色文件，例如 `grape.sh`：

```bash
#!/usr/bin/env bash
# JNL Grape 主题配色（葡萄紫）
export THEME_NAME="JNL-Grape"
export THEME_DISPLAY="JNL Grape"
export BG_DARK="#1e1424"
export BG_MID="#28202e"
export BG_LIGHT="#322c3a"
export FG_DARK="#e8d8f0"
export FG_MID="#d0c0e0"
export FG_LIGHT="#b8a8c8"
export ACCENT="#9050d0"
export ACCENT_HOVER="#a060e0"
export WARNING="#ffd166"
export ERROR="#ef476f"
export SUCCESS="#a6e3a1"
export SHELL_BG="#1e1424"
export SHELL_FG="#e8d8f0"
export WALLPAPER_COLORS="#1e1424 #9050d0 #b888f5"
```

### 配色变量说明

| 变量 | 作用 |
| --- | --- |
| `THEME_NAME` | 主题标识，必须以 `JNL-` 开头（如 `JNL-Grape`） |
| `THEME_DISPLAY` | 显示名（zenity 列表与终端输出用） |
| `BG_DARK` / `BG_MID` / `BG_LIGHT` | 背景三级灰度（深/中/浅） |
| `FG_DARK` / `FG_MID` / `FG_LIGHT` | 前景文字三级灰度 |
| `ACCENT` | 主强调色（按钮、链接、选中状态） |
| `ACCENT_HOVER` | 主色悬停状态 |
| `WARNING` / `ERROR` / `SUCCESS` | 警告/错误/成功状态色 |
| `SHELL_BG` / `SHELL_FG` | GNOME Shell 顶栏背景与前景 |
| `WALLPAPER_COLORS` | 壁纸生成用的渐变色（空格分隔） |

### 4.2 运行主题生成器

```bash
cd src/themes/
bash generate-themes.sh
```

`generate-themes.sh` 会：

1. 读取 `colors/*.sh` 下所有配色文件
2. 复制 `_template/` 模板到 `generated/<主题名>/`
3. 用 `sed` 将 CSS 中的 `var(--xxx)` 占位符替换为实际颜色值
4. 调用 `wallpapers/generate-wallpapers.sh` 生成配套壁纸
5. 在 `generated/` 下输出每套主题的完整目录

### 4.3 模板结构

`src/themes/_template/` 是主题模板，所有 CSS 文件中使用 `var(--xxx)` 形式的占位符：

```css
/* gtk-3.0/gtk.css 片段 */
@define-color theme_bg_color var(--bg-dark);
@define-color theme_fg_color var(--fg-dark);
@define-color theme_selected_bg_color var(--accent);
@define-color warning_color var(--warning);
@define-color error_color var(--error);
@define-color success_color var(--success);

button {
    background: var(--bg-mid);
    color: var(--fg-dark);
    border: 1px solid var(--bg-light);
}

button:hover {
    background: var(--accent);
    color: var(--fg-light);
}
```

`generate-themes.sh` 中的 `replace_css_vars()` 函数会依次替换：

- `var(--accent-hover)` （先于 accent，避免误伤）
- `var(--accent)`
- `var(--bg-dark)` / `var(--bg-mid)` / `var(--bg-light)`
- `var(--fg-dark)` / `var(--fg-mid)` / `var(--fg-light)`
- `var(--warning)` / `var(--error)` / `var(--success)`
- `var(--shell-bg)` / `var(--shell-fg)`

### 4.4 测试主题

```bash
# 1. 生成主题
cd src/themes/
bash generate-themes.sh

# 2. 安装到系统目录
sudo cp -r generated/JNL-Grape /usr/share/themes/
sudo cp -r generated/JNL-Grape/icons /usr/share/icons/

# 3. 安装壁纸
sudo cp generated/JNL-Grape/wallpaper.svg /usr/share/backgrounds/jnl-os/JNL-Grape.svg

# 4. 切换到新主题
switch-theme.sh grape
```

### 4.5 主题生效说明

| 主题部分 | 是否需重启 |
| --- | --- |
| GTK3 主题 | 即时生效 |
| GTK4 color-scheme | 即时生效 |
| GTK4 用户 CSS | 需重启 GTK4 应用 |
| 图标主题 | 即时生效 |
| GNOME Shell 主题 | X11：Alt+F2 输入 `r` 重启 Shell；Wayland：需重新登录 |
| 壁纸 | 即时生效 |

---

## 5. 主题目录结构（源码）

```
src/themes/
├── _template/                  # 主题模板
│   ├── gtk-3.0/
│   │   ├── gtk.css             # 含 var(--xxx) 占位符
│   │   └── assets/             # 控件素材
│   ├── gtk-4.0/
│   │   ├── gtk.css
│   │   └── assets/
│   ├── gnome-shell/
│   │   ├── gnome-shell-theme.gresource.xml
│   │   ├── gnome-shell.css
│   │   └── pad-osd.css
│   └── icons/
│       ├── index.theme         # 含 __THEME_NAME__ 占位符
│       └── scalable/           # 各类 SVG 图标
├── colors/                     # 12 套配色变量文件
│   ├── default.sh
│   ├── arctic.sh
│   ├── aurora.sh
│   ├── forest.sh
│   ├── gold.sh
│   ├── lavender.sh
│   ├── light.sh
│   ├── magma.sh
│   ├── midnight.sh
│   ├── ocean.sh
│   ├── rose.sh
│   └── sunset.sh
├── wallpapers/
│   ├── generate-wallpapers.sh  # 壁纸生成脚本
│   └── *.svg                   # 生成的壁纸文件
├── generated/                  # 主题生成器产物（构建时生成，已 gitignore）
├── generate-themes.sh          # 主题批量生成器
└── switch-theme.sh             # 主题切换脚本
```

---

## 6. 相关文档与脚本

- [src/themes/generate-themes.sh](../src/themes/generate-themes.sh) — 主题生成器
- [src/themes/switch-theme.sh](../src/themes/switch-theme.sh) — 主题切换脚本
- [src/themes/_template/](../src/themes/_template/) — 主题模板目录
- [src/themes/colors/](../src/themes/colors/) — 12 套配色变量文件
- [src/archiso-profile/airootfs/root/customize_airootfs.sh](../src/archiso-profile/airootfs/root/customize_airootfs.sh) — 系统定制脚本（主题安装部分）
