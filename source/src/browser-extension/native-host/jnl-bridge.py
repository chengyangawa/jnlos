#!/usr/bin/env python3
"""
jnl-bridge.py - JNL OS 浏览器扩展 Native Messaging 主机
接收来自浏览器的下载请求，调用 jnlc 打包为 .jnl 文件。

Native Messaging 协议：
  - 消息帧：4 字节长度前缀（native 字节序，无符号）+ JSON UTF-8 正文
  - 通过 stdin 读取请求，stdout 返回响应

依赖：
  - Python 3 标准库（json / struct / sys / base64 / tempfile / subprocess / pathlib）
  - 系统已安装 jnlc（路径 /usr/bin/jnlc 或在 PATH 中）

打包流程：
  1. 解码 base64 音频 / 封面
  2. 写入临时目录（audio.mp3 / cover.jpg / meta.json）
  3. 调用 `jnlc pack <dir> <output.jnl>`
  4. .jnl 保存到 ~/.local/share/jnl-os/music/
"""
import base64
import json
import os
import struct
import subprocess
import sys
import tempfile
from pathlib import Path

MUSIC_DIR = Path.home() / '.local' / 'share' / 'jnl-os' / 'music'


def read_message():
    """从 stdin 读取一条 Native Messaging 消息。

    帧格式：4 字节 native-endian 长度 + JSON 正文。
    stdin 关闭或读取不足时返回 None。
    """
    raw_length = sys.stdin.buffer.read(4)
    if not raw_length or len(raw_length) < 4:
        return None
    length = struct.unpack('=I', raw_length)[0]
    if length == 0:
        return None
    data = sys.stdin.buffer.read(length)
    if not data or len(data) < length:
        return None
    return json.loads(data.decode('utf-8'))


def send_message(msg):
    """向 stdout 发送一条 Native Messaging 消息。"""
    data = json.dumps(msg).encode('utf-8')
    sys.stdout.buffer.write(struct.pack('=I', len(data)))
    sys.stdout.buffer.write(data)
    sys.stdout.buffer.flush()


def handle_pack(msg):
    """处理打包请求：解码音频/封面，写入临时目录，调用 jnlc 打包。"""
    audio_b64 = msg.get('audio')
    cover_b64 = msg.get('cover')
    meta = msg.get('meta', {}) or {}
    filename = msg.get('filename', 'unknown.jnl')

    if not audio_b64:
        return {'success': False, 'error': '缺少音频数据'}

    # duration 必须为正整数（meta.json schema 要求 minimum 1）
    try:
        duration = int(meta.get('duration', 0))
    except (TypeError, ValueError):
        duration = 0
    meta['duration'] = max(1, duration)

    # 确保音乐目录存在
    MUSIC_DIR.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory(prefix='jnl-bridge-') as tmpdir:
        tmp = Path(tmpdir)

        # 写入音频（统一为 audio.mp3，符合 .jnl 规范固定命名）
        audio_data = base64.b64decode(audio_b64)
        audio_path = tmp / 'audio.mp3'
        audio_path.write_bytes(audio_data)

        # 写入封面（可选）
        if cover_b64:
            cover_data = base64.b64decode(cover_b64)
            (tmp / 'cover.jpg').write_bytes(cover_data)

        # 写入 meta.json（UTF-8，无 BOM，缩进 2）
        (tmp / 'meta.json').write_text(
            json.dumps(meta, ensure_ascii=False, indent=2), encoding='utf-8')

        # 调用 jnlc 打包
        output_path = MUSIC_DIR / filename
        try:
            result = subprocess.run(
                ['jnlc', 'pack', str(tmp), str(output_path)],
                capture_output=True, text=True, check=True)
            return {
                'success': True,
                'filePath': str(output_path),
                'message': result.stdout
            }
        except subprocess.CalledProcessError as e:
            return {
                'success': False,
                'error': f'jnlc执行失败: {e.stderr}',
                'stdout': e.stdout,
                'stderr': e.stderr
            }
        except FileNotFoundError:
            return {
                'success': False,
                'error': 'jnlc未安装，请安装jnlc到/usr/bin/jnlc'
            }


def main():
    while True:
        msg = read_message()
        if msg is None:
            break

        action = msg.get('action')
        if action == 'pack':
            send_message(handle_pack(msg))
        else:
            send_message({'success': False, 'error': f'未知action: {action}'})


if __name__ == '__main__':
    try:
        main()
    except Exception as e:
        send_message({'success': False, 'error': str(e)})
