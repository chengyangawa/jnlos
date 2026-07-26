#!/usr/bin/env bash
# 生成科技感/Windows 11 风格的 SVG 图标集
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ICON_DIR="$SCRIPT_DIR/icons"

for cat in apps places categories devices mimetypes status actions; do
  mkdir -p "$ICON_DIR/scalable/$cat"
  for sz in 16 24 32 48 64 128 256; do
    mkdir -p "$ICON_DIR/${sz}x${sz}/$cat"
  done
done

PRIMARY="#0078D4"
PRIMARY_LIGHT="#40A0FF"
PRIMARY_DARK="#005A9E"
ACCENT="#FFB900"
BG_DARK="#202020"
BG_MID="#2D2D2D"
FG_LIGHT="#FFFFFF"
FG_MUTED="#B0B0B0"

svg_header() {
    local size="${1:-48}"
    cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 48 48">
  <defs>
    <linearGradient id="bgGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#3A3A3A"/>
      <stop offset="100%" style="stop-color:#202020"/>
    </linearGradient>
    <linearGradient id="accentGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#40A0FF"/>
      <stop offset="100%" style="stop-color:#0078D4"/>
    </linearGradient>
    <filter id="glow">
      <feGaussianBlur stdDeviation="0.5" result="coloredBlur"/>
      <feMerge>
        <feMergeNode in="coloredBlur"/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>
  </defs>
EOF
}

svg_footer() {
    echo "</svg>"
}

make_icon() {
    local name="$1"
    local content="$2"
    for sz in 16 24 32 48 64 128 256; do
        echo "$content" | sed "s/{SIZE}/$sz/g" > "$ICON_DIR/${sz}x${sz}/apps/${name}.svg"
    done
    echo "$content" > "$ICON_DIR/scalable/apps/${name}.svg"
}

# --- JNL OS Logo ---
make_logo_icon() {
    local name="$1"
    local content
    content=$(cat <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48">
  <defs>
    <linearGradient id="ringGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#40A0FF"/>
      <stop offset="50%" style="stop-color:#0078D4"/>
      <stop offset="100%" style="stop-color:#5B2C8F"/>
    </linearGradient>
    <linearGradient id="coreGrad" x1="0%" y1="100%" x2="0%" y2="0%">
      <stop offset="0%" style="stop-color:#0A0A0A"/>
      <stop offset="100%" style="stop-color:#1E1E1E"/>
    </linearGradient>
    <filter id="outerGlow">
      <feGaussianBlur stdDeviation="1" result="coloredBlur"/>
      <feMerge>
        <feMergeNode in="coloredBlur"/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>
  </defs>
  <circle cx="24" cy="24" r="22" fill="url(#ringGrad)" filter="url(#outerGlow)"/>
  <circle cx="24" cy="24" r="18" fill="url(#coreGrad)"/>
  <path d="M24 8 L24 40 M8 24 L40 24" stroke="url(#ringGrad)" stroke-width="1.5" opacity="0.6"/>
  <circle cx="24" cy="24" r="12" fill="none" stroke="url(#ringGrad)" stroke-width="1" opacity="0.8"/>
  <text x="24" y="29" text-anchor="middle" font-family="Consolas, monospace" font-size="11" font-weight="bold" fill="#40A0FF">JNL</text>
  <circle cx="24" cy="24" r="3" fill="#40A0FF" opacity="0.9">
    <animate attributeName="r" values="2.5;3.5;2.5" dur="2s" repeatCount="indefinite"/>
    <animate attributeName="opacity" values="0.9;0.5;0.9" dur="2s" repeatCount="indefinite"/>
  </circle>
</svg>
EOF
    )
    for sz in 16 24 32 48 64 128 256; do
        echo "$content" > "$ICON_DIR/${sz}x${sz}/apps/${name}.svg"
    done
    echo "$content" > "$ICON_DIR/scalable/apps/${name}.svg"
}

# --- JNL Player 图标 ---
make_player_icon() {
    local name="$1"
    local content
    content=$(cat <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48">
  <defs>
    <linearGradient id="pbg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#2D2D2D"/>
      <stop offset="100%" style="stop-color:#1A1A1A"/>
    </linearGradient>
    <linearGradient id="pacc" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#40A0FF"/>
      <stop offset="100%" style="stop-color:#5B2C8F"/>
    </linearGradient>
    <filter id="pglow">
      <feGaussianBlur stdDeviation="0.8" result="b"/>
      <feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>
    </filter>
  </defs>
  <rect x="4" y="6" width="40" height="36" rx="5" fill="url(#pbg)" stroke="#3D3D3D" stroke-width="1"/>
  <rect x="6" y="8" width="36" height="20" rx="3" fill="#0D0D0D" stroke="#2A2A2A" stroke-width="0.5"/>
  <path d="M12 18 L15 16 L15 20 Z" fill="#40A0FF" filter="url(#pglow)"/>
  <path d="M17 20 L20 15 L20 25 Z" fill="#5B2C8F" opacity="0.8"/>
  <path d="M22 17 L25 15.5 L25 22.5 Z" fill="#40A0FF" opacity="0.6"/>
  <rect x="8" y="32" width="32" height="3" rx="1.5" fill="#1A1A1A"/>
  <rect x="8" y="32" width="18" height="3" rx="1.5" fill="url(#pacc)"/>
  <circle cx="34" cy="38" r="3" fill="url(#pacc)" filter="url(#pglow)"/>
  <path d="M33 36.5 L33 39.5 L36 38 Z" fill="#0D0D0D"/>
</svg>
EOF
    )
    for sz in 16 24 32 48 64 128 256; do
        echo "$content" > "$ICON_DIR/${sz}x${sz}/apps/${name}.svg"
    done
    echo "$content" > "$ICON_DIR/scalable/apps/${name}.svg"
}

# --- 文件夹图标（places） ---
make_folder_icon() {
    local name="$1"
    local color1="${2:-#40A0FF}"
    local color2="${3:-#0078D4}"
    local content
    content=$(cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48">
  <defs>
    <linearGradient id="fgrd" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" style="stop-color:${color1}"/>
      <stop offset="100%" style="stop-color:${color2}"/>
    </linearGradient>
    <filter id="fshadow">
      <feDropShadow dx="0" dy="1" stdDeviation="1" flood-color="#000000" flood-opacity="0.3"/>
    </filter>
  </defs>
  <path d="M4 14 L4 40 Q4 44 8 44 L40 44 Q44 44 44 40 L44 18 Q44 14 40 14 L22 14 L18 10 L8 10 Q4 10 4 14 Z"
        fill="url(#fgrd)" filter="url(#fshadow)"/>
  <path d="M4 18 L44 18 L44 20 L4 20 Z" fill="#FFFFFF" opacity="0.1"/>
  <path d="M8 10 L18 10 L22 14 L8 14 Z" fill="${color1}" opacity="0.8"/>
</svg>
EOF
    )
    for sz in 16 24 32 48 64 128 256; do
        echo "$content" > "$ICON_DIR/${sz}x${sz}/places/${name}.svg"
    done
    echo "$content" > "$ICON_DIR/scalable/places/${name}.svg"
}

# --- 设置图标 ---
make_settings_icon() {
    local name="$1"
    local content
    content=$(cat <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48">
  <defs>
    <linearGradient id="sgrd" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#40A0FF"/>
      <stop offset="100%" style="stop-color:#5B2C8F"/>
    </linearGradient>
    <filter id="sglow">
      <feGaussianBlur stdDeviation="0.5" result="b"/>
      <feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>
    </filter>
  </defs>
  <g filter="url(#sglow)">
    <path d="M24 4 L26.5 10 L33 8 L34 14.5 L40 15 L38 21 L44 24 L38 27 L40 33 L34 33.5 L33 40 L26.5 38 L24 44 L21.5 38 L15 40 L14 33.5 L8 33 L10 27 L4 24 L10 21 L8 15 L14 14.5 L15 8 L21.5 10 Z"
          fill="none" stroke="url(#sgrd)" stroke-width="2" stroke-linejoin="round"/>
    <circle cx="24" cy="24" r="8" fill="none" stroke="url(#sgrd)" stroke-width="2"/>
    <circle cx="24" cy="24" r="3" fill="url(#sgrd)"/>
  </g>
</svg>
EOF
    )
    for sz in 16 24 32 48 64 128 256; do
        echo "$content" > "$ICON_DIR/${sz}x${sz}/apps/${name}.svg"
    done
    echo "$content" > "$ICON_DIR/scalable/apps/${name}.svg"
}

# --- 终端图标 ---
make_terminal_icon() {
    local name="$1"
    local content
    content=$(cat <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48">
  <defs>
    <linearGradient id="tbg" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" style="stop-color:#1A1A1A"/>
      <stop offset="100%" style="stop-color:#0D0D0D"/>
    </linearGradient>
  </defs>
  <rect x="3" y="6" width="42" height="36" rx="4" fill="url(#tbg)" stroke="#3D3D3D" stroke-width="1"/>
  <rect x="3" y="6" width="42" height="6" rx="4" fill="#2D2D2D"/>
  <circle cx="8" cy="9" r="1.5" fill="#FF5F57"/>
  <circle cx="13" cy="9" r="1.5" fill="#FEBC2E"/>
  <circle cx="18" cy="9" r="1.5" fill="#28C840"/>
  <path d="M8 22 L14 17 L14 27 Z" fill="#40A0FF"/>
  <rect x="17" y="26" width="14" height="2" rx="1" fill="#5B2C8F" opacity="0.8"/>
  <rect x="17" y="30" width="20" height="2" rx="1" fill="#40A0FF" opacity="0.6"/>
  <rect x="17" y="34" width="12" height="2" rx="1" fill="#5B2C8F" opacity="0.4"/>
</svg>
EOF
    )
    for sz in 16 24 32 48 64 128 256; do
        echo "$content" > "$ICON_DIR/${sz}x${sz}/apps/${name}.svg"
    done
    echo "$content" > "$ICON_DIR/scalable/apps/${name}.svg"
}

# --- 浏览器图标 ---
make_browser_icon() {
    local name="$1"
    local content
    content=$(cat <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48">
  <defs>
    <linearGradient id="brgrd" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#FF8C00"/>
      <stop offset="50%" style="stop-color:#FFB900"/>
      <stop offset="100%" style="stop-color:#0078D4"/>
    </linearGradient>
    <filter id="brglow">
      <feGaussianBlur stdDeviation="0.8" result="b"/>
      <feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>
    </filter>
  </defs>
  <circle cx="24" cy="24" r="21" fill="none" stroke="url(#brgrd)" stroke-width="4" filter="url(#brglow)"/>
  <ellipse cx="24" cy="24" rx="14" ry="9" fill="none" stroke="#40A0FF" stroke-width="2" transform="rotate(-25 24 24)"/>
  <ellipse cx="24" cy="24" rx="14" ry="9" fill="none" stroke="#FFB900" stroke-width="2" transform="rotate(25 24 24)"/>
  <circle cx="24" cy="24" r="5" fill="#0078D4"/>
  <circle cx="24" cy="24" r="2" fill="#FFFFFF"/>
</svg>
EOF
    )
    for sz in 16 24 32 48 64 128 256; do
        echo "$content" > "$ICON_DIR/${sz}x${sz}/apps/${name}.svg"
    done
    echo "$content" > "$ICON_DIR/scalable/apps/${name}.svg"
}

# --- 文件管理器图标 ---
make_files_icon() {
    local name="$1"
    local content
    content=$(cat <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48">
  <defs>
    <linearGradient id="figrd" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" style="stop-color:#FFD700"/>
      <stop offset="100%" style="stop-color:#FFA500"/>
    </linearGradient>
    <filter id="fishadow">
      <feDropShadow dx="0" dy="2" stdDeviation="1.5" flood-color="#000000" flood-opacity="0.3"/>
    </filter>
  </defs>
  <path d="M4 14 L4 40 Q4 44 8 44 L40 44 Q44 44 44 40 L44 18 Q44 14 40 14 L22 14 L18 10 L8 10 Q4 10 4 14 Z"
        fill="url(#figrd)" filter="url(#fishadow)"/>
  <path d="M4 19 L44 19 L44 21 L4 21 Z" fill="#FFFFFF" opacity="0.15"/>
  <path d="M8 10 L18 10 L22 14 L8 14 Z" fill="#FFE066"/>
  <rect x="10" y="25" width="28" height="2" rx="1" fill="#FFFFFF" opacity="0.3"/>
  <rect x="10" y="30" width="20" height="2" rx="1" fill="#FFFFFF" opacity="0.2"/>
  <rect x="10" y="35" width="24" height="2" rx="1" fill="#FFFFFF" opacity="0.15"/>
</svg>
EOF
    )
    for sz in 16 24 32 48 64 128 256; do
        echo "$content" > "$ICON_DIR/${sz}x${sz}/apps/${name}.svg"
    done
    echo "$content" > "$ICON_DIR/scalable/apps/${name}.svg"
}

# --- 生成图标 ---
echo "生成 JNL OS 图标集..."

make_logo_icon "jnl-os"
make_player_icon "jnl-player"
make_settings_icon "jnl-settings"
make_terminal_icon "jnl-terminal"
make_browser_icon "jnl-browser"
make_files_icon "jnl-files"

make_folder_icon "folder" "#40A0FF" "#0078D4"
make_folder_icon "folder-home" "#5B2C8F" "#3A1F6B"
make_folder_icon "folder-documents" "#FFB900" "#D49800"
make_folder_icon "folder-downloads" "#28C840" "#1EA830"
make_folder_icon "folder-music" "#FF6B9D" "#E0457E"
make_folder_icon "folder-pictures" "#40A0FF" "#0078D4"
make_folder_icon "folder-videos" "#FF5F57" "#D93A32"

# index.theme
cat > "$ICON_DIR/index.theme" <<EOF
[Icon Theme]
Name=JNL OS Tech
Comment=JNL OS technology-themed icon set
Inherits=Adwaita
Directories=scalable/apps,scalable/places,scalable/categories,scalable/devices,scalable/mimetypes,scalable/status,scalable/actions,48x48/apps,256x256/apps,128x128/apps,64x64/apps,32x32/apps,24x24/apps,16x16/apps

[scalable/apps]
Size=48
Type=Scalable
Context=Applications

[scalable/places]
Size=48
Type=Scalable
Context=Places

[scalable/categories]
Size=48
Type=Scalable
Context=Categories

[scalable/devices]
Size=48
Type=Scalable
Context=Devices

[scalable/mimetypes]
Size=48
Type=Scalable
Context=MimeTypes

[scalable/status]
Size=48
Type=Scalable
Context=Status

[scalable/actions]
Size=48
Type=Scalable
Context=Actions

[48x48/apps]
Size=48
Type=Fixed
Context=Applications

[256x256/apps]
Size=256
Type=Fixed
Context=Applications

[128x128/apps]
Size=128
Type=Fixed
Context=Applications

[64x64/apps]
Size=64
Type=Fixed
Context=Applications

[32x32/apps]
Size=32
Type=Fixed
Context=Applications

[24x24/apps]
Size=24
Type=Fixed
Context=Applications

[16x16/apps]
Size=16
Type=Fixed
Context=Applications
EOF

echo "完成！图标已生成到 $ICON_DIR"
