# 主题系统

## 概述

JNL OS 集成 12 套精美主题，覆盖多种风格。每套主题包含：

- GTK3 主题
- GTK4 主题
- GNOME Shell 主题
- 图标主题
- 壁纸

## 主题列表

### 深色主题

| 主题名称 | 风格描述 |
|----------|----------|
| Deep Space | 深空蓝调，宁静深邃 |
| Lava Flow | 岩浆红黑，热情奔放 |
| Aurora Night | 极光夜色，神秘梦幻 |
| Carbon Black | 碳黑极简，商务沉稳 |

### 浅色主题

| 主题名称 | 风格描述 |
|----------|----------|
| Pure White | 纯白纯净，清新明亮 |
| Ocean Breeze | 海洋微风，清爽宜人 |
| Sunny Day | 阳光明媚，活力四射 |
| Mint Fresh | 薄荷清新，自然舒适 |

### 混合主题

| 主题名称 | 风格描述 |
|----------|----------|
| Rose Gold | 玫瑰金粉，优雅高贵 |
| Cyberpunk | 赛博朋克，科技感十足 |
| Forest Green | 森林绿意，自然和谐 |
| Purple Rain | 紫色浪漫，神秘优雅 |

## 切换主题

### 方法一：使用主题选择器

1. 打开系统设置 → 外观
2. 在主题选项卡中选择喜欢的主题
3. 点击应用，主题将自动切换

### 方法二：使用命令行

```bash
# 列出所有可用主题
jnl-theme list

# 应用指定主题
jnl-theme apply "Deep Space"

# 应用上一个主题
jnl-theme prev

# 应用下一个主题
jnl-theme next
```

## 自定义主题

### 创建自定义主题

1. 复制现有主题目录：

```bash
cp -r /usr/share/themes/Deep\ Space ~/.themes/MyTheme
```

2. 修改主题文件：
   - `gtk-3.0/gtk.css` - GTK3 样式
   - `gtk-4.0/gtk.css` - GTK4 样式
   - `gnome-shell/gnome-shell.css` - GNOME Shell 样式

3. 应用自定义主题：

```bash
jnl-theme apply "MyTheme"
```

### 主题目录结构

```
theme-name/
├── gtk-3.0/
│   └── gtk.css
├── gtk-4.0/
│   └── gtk.css
├── gnome-shell/
│   └── gnome-shell.css
└── wallpaper.png
```

## 图标主题

JNL OS 使用 Papirus-Dark 图标主题，也支持其他图标主题：

```bash
# 安装其他图标主题
sudo pacman -S papirus-icon-theme arc-icon-theme
```

## 光标主题

默认使用 Breeze_Snow 白色光标主题（Windows 风格）。

## 壁纸

主题配套壁纸存储在 `/usr/share/backgrounds/jnl/` 目录下。
