// === JNL OS Music Tool - Background Service Worker ===

// 监听来自content script的消息
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message.action === 'downloadAndPack') {
    downloadAndPack(message.song, sender.tab.id)
      .then((result) => sendResponse({ success: true, filePath: result.filePath }))
      .catch((err) => sendResponse({ success: false, error: err.message }));
    return true; // 保持消息通道开启（异步响应）
  }
  // 忽略 updateProgress 等其他消息（progress 由 tabs.sendMessage 直接发给页面）
});

async function downloadAndPack(song, tabId) {
  try {
    // 1. 下载音频文件
    updateProgress(tabId, 10, '下载音频中...');
    const audioBlob = await downloadFile(song.audioUrl);

    updateProgress(tabId, 40, '下载封面中...');
    // 2. 下载封面（如果有）
    let coverBlob = null;
    if (song.coverUrl) {
      try {
        coverBlob = await downloadFile(song.coverUrl);
      } catch (e) {
        console.warn('封面下载失败:', e);
      }
    }

    updateProgress(tabId, 60, '打包中...');

    // duration 必须为正整数（符合 meta.json schema 最小值 1）
    const duration = Math.max(1, Math.floor(Number(song.duration) || 0));

    // 3. 构造meta.json
    const meta = {
      format_version: '1.0',
      title: song.title || 'Unknown',
      artist: song.artist || 'Unknown',
      album: '',
      duration: duration,
      source_url: song.sourceUrl,
      source_platform: song.sourcePlatform || 'qqmusic',
      audio_codec: 'mp3',
      audio_bitrate: 0,
      created_at: new Date().toISOString(),
      tags: ['qqmusic']
    };

    // 4. 通过Native Messaging发送给jnl-bridge打包
    updateProgress(tabId, 80, '保存到音乐库...');
    const result = await sendToNativeHost({
      action: 'pack',
      audio: arrayBufferToBase64(await audioBlob.arrayBuffer()),
      cover: coverBlob ? arrayBufferToBase64(await coverBlob.arrayBuffer()) : null,
      meta: meta,
      filename: `${sanitize(song.artist)} - ${sanitize(song.title)}.jnl`
    });

    updateProgress(tabId, 100, '完成');
    return { filePath: result.filePath };
  } catch (err) {
    console.error('下载打包失败:', err);
    throw err;
  }
}

async function downloadFile(url) {
  // credentials: 'include' 以携带 QQ 音乐站点的登录 Cookie，
  // 多数音频流需要鉴权才能访问。
  const response = await fetch(url, { credentials: 'include' });
  if (!response.ok) throw new Error(`下载失败: HTTP ${response.status}`);
  return await response.blob();
}

function arrayBufferToBase64(buffer) {
  const bytes = new Uint8Array(buffer);
  let binary = '';
  const chunk = 0x8000;
  for (let i = 0; i < bytes.length; i += chunk) {
    binary += String.fromCharCode.apply(null, bytes.subarray(i, i + chunk));
  }
  return btoa(binary);
}

function sanitize(s) {
  return String(s || '').replace(/[\\/:*?"<>|]/g, '_').trim() || 'unknown';
}

function updateProgress(tabId, percent, text) {
  chrome.tabs
    .sendMessage(tabId, { action: 'updateProgress', percent: percent, text: text })
    .catch(() => {}); // 忽略发送失败（页面可能已关闭）
}

// 通过Native Messaging发送消息给jnl-bridge.py
function sendToNativeHost(message) {
  return new Promise((resolve, reject) => {
    let settled = false;
    try {
      const port = chrome.runtime.connectNative('jnl_bridge');

      port.onMessage.addListener((response) => {
        settled = true;
        if (response && response.success) {
          resolve(response);
        } else {
          reject(new Error((response && response.error) || 'Native host返回失败'));
        }
        port.disconnect();
      });

      port.onDisconnect.addListener(() => {
        if (!settled) {
          reject(new Error('Native host连接断开（请确认已执行 native-host/install.sh 且 jnlc 已安装）'));
        }
      });

      port.postMessage(message);
    } catch (err) {
      reject(err);
    }
  });
}

// 扩展安装事件
chrome.runtime.onInstalled.addListener(() => {
  console.log('JNL OS Music Tool 已安装');
});
