// === JNL OS Music Tool - Content Script ===
// 注入到 y.qq.com 页面，提供下载工具
(function() {
  'use strict';

  const TOOL_CONTAINER_ID = 'jnl-tool-container';
  let currentSong = null;

  // 创建工具按钮
  function createToolButton() {
    if (document.getElementById(TOOL_CONTAINER_ID)) return;

    const container = document.createElement('div');
    container.id = TOOL_CONTAINER_ID;
    container.innerHTML = `
      <button id="jnl-tool-btn" class="jnl-tool-button" title="JNL工具">
        ⚙️ Tool
      </button>
      <div id="jnl-tool-menu" class="jnl-tool-menu" style="display:none;">
        <div class="jnl-menu-item" id="jnl-add-music">
          🎵 添加指定音乐到桌面音乐
        </div>
        <div class="jnl-menu-item" id="jnl-show-status">
          📊 显示当前歌曲信息
        </div>
      </div>
    `;
    document.body.appendChild(container);

    // 绑定事件
    const btn = document.getElementById('jnl-tool-btn');
    const menu = document.getElementById('jnl-tool-menu');
    btn.addEventListener('click', (e) => {
      e.stopPropagation();
      menu.style.display = menu.style.display === 'none' ? 'block' : 'none';
    });

    document.addEventListener('click', () => {
      menu.style.display = 'none';
    });

    document.getElementById('jnl-add-music').addEventListener('click', addCurrentMusicToLibrary);
    document.getElementById('jnl-show-status').addEventListener('click', showCurrentSongInfo);

    // 开始监听播放器
    startSongMonitor();
  }

  // 监听当前播放的歌曲
  function startSongMonitor() {
    setInterval(updateCurrentSong, 1000);
  }

  function updateCurrentSong() {
    // QQ音乐播放器通常有 audio 元素或特定的播放器结构
    const audio = document.querySelector('audio');
    if (audio && audio.src) {
      // 从页面提取歌曲信息
      const titleEl = document.querySelector(
        '.player__title, .song_name, .player_title, .song-info__name, .songlist__name a, .songlist__songname a'
      );
      const artistEl = document.querySelector(
        '.player__singer, .singer_name, .player_singer, .song-info__singer, .songlist__singer a'
      );
      const coverEl = document.querySelector(
        '.player__cover img, .song_cover img, .player_cover img, .songlist__pic img, .album__img img'
      );

      const title = titleEl ? titleEl.textContent.trim() : '';
      const artist = artistEl ? artistEl.textContent.trim() : '';

      // 优先使用 MediaSession API（音乐站点通常较准确）
      const ms = navigator.mediaSession;
      const msMeta = ms && ms.metadata ? ms.metadata : null;

      currentSong = {
        audioUrl: audio.src,
        title: title || (msMeta && msMeta.title) || 'Unknown',
        artist: artist || (msMeta && msMeta.artist) || 'Unknown',
        coverUrl: coverEl ? coverEl.src : (msMeta && msMeta.artwork && msMeta.artwork[0] ? msMeta.artwork[0].src : ''),
        duration: audio.duration || 0,
        sourceUrl: window.location.href,
        sourcePlatform: 'qqmusic'
      };
    }
  }

  // 添加当前音乐到桌面音乐库
  function addCurrentMusicToLibrary() {
    if (!currentSong) {
      showNotification('未检测到正在播放的音乐', 'error');
      return;
    }

    showNotification(`正在下载: ${currentSong.title} - ${currentSong.artist}`, 'info');
    showProgressDialog();

    // 发送给background处理
    chrome.runtime.sendMessage(
      { action: 'downloadAndPack', song: currentSong },
      (response) => {
        hideProgressDialog();
        if (chrome.runtime.lastError) {
          showNotification(`下载失败: ${chrome.runtime.lastError.message}`, 'error');
          return;
        }
        if (response && response.success) {
          showNotification(`已保存到桌面音乐库: ${response.filePath}`, 'success');
        } else {
          showNotification(`下载失败: ${response && response.error ? response.error : '未知错误'}`, 'error');
        }
      }
    );
  }

  function showCurrentSongInfo() {
    if (!currentSong) {
      showNotification('未检测到正在播放的音乐', 'info');
      return;
    }
    alert(
      `当前歌曲:\n标题: ${currentSong.title}\n艺术家: ${currentSong.artist}` +
      `\n时长: ${Math.floor(currentSong.duration)}秒\n音频URL: ${currentSong.audioUrl}`
    );
  }

  function showNotification(message, type) {
    type = type || 'info';
    const notif = document.createElement('div');
    notif.className = `jnl-notification jnl-notif-${type}`;
    notif.textContent = message;
    document.body.appendChild(notif);
    setTimeout(() => notif.remove(), 3000);
  }

  function showProgressDialog() {
    const existing = document.getElementById('jnl-progress-dialog');
    if (existing) existing.remove();

    const dialog = document.createElement('div');
    dialog.id = 'jnl-progress-dialog';
    dialog.className = 'jnl-progress-dialog';
    dialog.innerHTML = `
      <div class="jnl-progress-content">
        <h3>JNL 音乐下载</h3>
        <div class="jnl-progress-bar">
          <div class="jnl-progress-fill" id="jnl-progress-fill" style="width:0%"></div>
        </div>
        <div class="jnl-progress-text" id="jnl-progress-text">准备下载...</div>
      </div>
    `;
    document.body.appendChild(dialog);
  }

  function updateProgress(percent, text) {
    const fill = document.getElementById('jnl-progress-fill');
    const txt = document.getElementById('jnl-progress-text');
    if (fill) fill.style.width = `${percent}%`;
    if (txt) txt.textContent = text;
  }

  function hideProgressDialog() {
    const dialog = document.getElementById('jnl-progress-dialog');
    if (dialog) dialog.remove();
  }

  // 接收来自 background.js 的进度更新消息
  chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
    if (message.action === 'updateProgress') {
      updateProgress(message.percent, message.text);
    }
    return false;
  });

  // 暴露给外部（方便测试）
  window.JNLTool = {
    getCurrentSong: () => currentSong,
    updateProgress: updateProgress
  };

  // 等待页面加载完成
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', createToolButton);
  } else {
    createToolButton();
  }
})();
