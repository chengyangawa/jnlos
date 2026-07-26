// extension.js - JNL Music Control GNOME Shell 扩展
// 顶栏音乐控件，通过 DBus 与 jnlp 播放器通信
//
// 依赖服务：
//   总线名：org.jnl_os.Player
//   对象路径：/org/jnl_os/Player
//   接口名：org.jnl_os.Player

import Clutter from 'gi://Clutter';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import GObject from 'gi://GObject';
import St from 'gi://St';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';
import * as Slider from 'resource:///org/gnome/shell/ui/slider.js';

// ============================================================================
// DBus 接口定义
// ============================================================================
const JNL_PLAYER_BUS_NAME = 'org.jnl_os.Player';
const JNL_PLAYER_OBJECT_PATH = '/org/jnl_os/Player';

const JNL_PLAYER_INTERFACE = `<node>
  <interface name='org.jnl_os.Player'>
    <method name='Play'/>
    <method name='Pause'/>
    <method name='Next'/>
    <method name='Previous'/>
    <method name='Stop'/>
    <method name='PlayTrack'>
      <arg type='i' name='index' direction='in'/>
    </method>
    <method name='GetStatus'>
      <arg type='s' name='status' direction='out'/>
    </method>
    <method name='GetSongInfo'>
      <arg type='s' name='title' direction='out'/>
      <arg type='s' name='artist' direction='out'/>
    </method>
    <method name='SetVolume'>
      <arg type='d' name='volume' direction='in'/>
    </method>
    <method name='GetVolume'>
      <arg type='d' name='volume' direction='out'/>
    </method>
    <signal name='SongChanged'>
      <arg type='s' name='title'/>
      <arg type='s' name='artist'/>
    </signal>
    <signal name='StatusChanged'>
      <arg type='s' name='status'/>
    </signal>
  </interface>
</node>`;

// 音乐库目录：~/.local/share/jnl-os/music/
const MUSIC_DIR = GLib.build_filenamev([
    GLib.get_home_dir(), '.local', 'share', 'jnl-os', 'music']);

// ============================================================================
// 主指示器类：顶栏按钮 + 下拉面板
// ============================================================================
const JnlMusicIndicator = GObject.registerClass(
class JnlMusicIndicator extends PanelMenu.Button {
    _init() {
        super._init(0.0, 'JNL Music Control', false);

        // 顶栏图标
        const icon = new St.Icon({
            icon_name: 'audio-x-generic',
            style_class: 'system-status-icon',
        });
        this.add_child(icon);

        this._playerProxy = null;
        this._signalIds = [];
        this._volumeUpdating = false;

        this._buildPanel();
        this._initDBus();
        this._refreshTrackList();
    }

    // ========================================================================
    // 构建下拉面板
    // ========================================================================
    _buildPanel() {
        // --- 标题 ---
        const headerItem = new PopupMenu.PopupMenuItem('JNL Music Control', {
            reactive: false,
            style_class: 'jnl-music-header',
        });
        this.menu.addMenuItem(headerItem);

        // --- 当前歌曲信息 ---
        const infoBox = new St.BoxLayout({
            vertical: true,
            style_class: 'jnl-music-info',
        });
        this._titleLabel = new St.Label({
            text: '未播放',
            style_class: 'jnl-music-title',
        });
        this._artistLabel = new St.Label({
            text: '',
            style_class: 'jnl-music-artist',
        });
        infoBox.add_child(this._titleLabel);
        infoBox.add_child(this._artistLabel);

        const infoItem = new PopupMenu.PopupBaseMenuItem({
            reactive: false,
            can_focus: false,
        });
        infoItem.add_child(infoBox);
        this.menu.addMenuItem(infoItem);

        // --- 分隔线 ---
        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

        // --- 进度条 ---
        const progressItem = new PopupMenu.PopupBaseMenuItem({
            reactive: false,
            can_focus: false,
        });
        this._progressBar = new St.Widget({
            style_class: 'jnl-music-progress',
            layout_manager: new Clutter.BinLayout(),
        });
        this._progressFill = new St.Widget({
            style_class: 'jnl-music-progress-fill',
            width: 0,
        });
        this._progressBar.add_child(this._progressFill);
        progressItem.add_child(this._progressBar);
        this.menu.addMenuItem(progressItem);

        // --- 控制按钮 ---
        const ctrlBox = new St.BoxLayout({
            style_class: 'jnl-music-controls',
            homogeneous: true,
        });
        const prevBtn = this._createButton(
            'media-skip-backward-symbolic', '上一首',
            () => this._call('Previous'));
        this._playButton = this._createButton(
            'media-playback-start-symbolic', '播放/暂停',
            () => this._togglePlay());
        const nextBtn = this._createButton(
            'media-skip-forward-symbolic', '下一首',
            () => this._call('Next'));
        const stopBtn = this._createButton(
            'media-playback-stop-symbolic', '停止',
            () => this._call('Stop'));
        ctrlBox.add_child(prevBtn);
        ctrlBox.add_child(this._playButton);
        ctrlBox.add_child(nextBtn);
        ctrlBox.add_child(stopBtn);

        const ctrlItem = new PopupMenu.PopupBaseMenuItem({
            reactive: false,
            can_focus: false,
        });
        ctrlItem.add_child(ctrlBox);
        this.menu.addMenuItem(ctrlItem);

        // --- 音量滑块 ---
        const volItem = new PopupMenu.PopupBaseMenuItem({
            reactive: false,
            can_focus: false,
        });
        const volBox = new St.BoxLayout({
            style_class: 'jnl-music-volume',
        });
        volBox.add_child(new St.Icon({
            icon_name: 'audio-volume-low-symbolic',
            icon_size: 16,
        }));
        this._volumeSlider = new Slider.Slider(0.8);
        this._volumeSlider.connect('notify::value', (slider) => {
            if (this._volumeUpdating)
                return;
            this._callMethod('SetVolume',
                GLib.Variant.new_tuple(
                    [GLib.Variant.new_double(slider.value)]));
        });
        volBox.add_child(this._volumeSlider);
        volItem.add_child(volBox);
        this.menu.addMenuItem(volItem);

        // --- 分隔线 ---
        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

        // --- 歌曲列表 ---
        const listHeader = new PopupMenu.PopupMenuItem('歌单', {
            reactive: false,
            style_class: 'jnl-music-list-header',
        });
        this.menu.addMenuItem(listHeader);

        this._trackList = new PopupMenu.PopupMenuSection();
        this.menu.addMenuItem(this._trackList);

        // --- 分隔线 ---
        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

        // --- 打开播放器 ---
        const openPlayerItem = new PopupMenu.PopupMenuItem('打开播放器');
        openPlayerItem.connect('activate', () => {
            try {
                GLib.spawn_command_line_async('jnlp');
            } catch (e) {
                log('JNL: 启动 jnlp 失败: ' + e);
            }
        });
        this.menu.addMenuItem(openPlayerItem);

        // --- 刷新歌单 ---
        const refreshItem = new PopupMenu.PopupMenuItem('刷新歌单');
        refreshItem.connect('activate', () => this._refreshTrackList());
        this.menu.addMenuItem(refreshItem);
    }

    // ========================================================================
    // 创建控制按钮
    // ========================================================================
    _createButton(iconName, tooltip, callback) {
        const btn = new St.Button({
            style_class: 'jnl-music-button',
            can_focus: true,
            child: new St.Icon({icon_name: iconName, icon_size: 20}),
        });
        btn.connect('clicked', callback);
        return btn;
    }

    // ========================================================================
    // 播放/暂停切换：先查询状态再决定调用 Play 还是 Pause
    // ========================================================================
    _togglePlay() {
        this._callMethod('GetStatus', null, (proxy, result) => {
            try {
                const variant = proxy.call_finish(result);
                const [status] = variant.deep_unpack();
                if (status === 'playing') {
                    this._call('Pause');
                } else {
                    this._call('Play');
                }
            } catch (e) {
                log('JNL: GetStatus 失败: ' + e);
            }
        });
    }

    // ========================================================================
    // 初始化 DBus 代理并监听信号
    // ========================================================================
    _initDBus() {
        const dbusProxy = Gio.DBusProxy.makeProxyWrapper(JNL_PLAYER_INTERFACE);
        this._playerProxy = new dbusProxy(
            Gio.DBus.session,
            JNL_PLAYER_BUS_NAME,
            JNL_PLAYER_OBJECT_PATH);

        // 监听 SongChanged 信号
        const songChangedId = this._playerProxy.connectSignal(
            'SongChanged', (proxy, sender, params) => {
                const [title, artist] = params.deep_unpack();
                this._titleLabel.set_text(title || '未知曲目');
                this._artistLabel.set_text(artist || '');
            });
        this._signalIds.push(songChangedId);

        // 监听 StatusChanged 信号
        const statusChangedId = this._playerProxy.connectSignal(
            'StatusChanged', (proxy, sender, params) => {
                const [status] = params.deep_unpack();
                this._updatePlayButton(status);
            });
        this._signalIds.push(statusChangedId);

        // 初始查询播放状态
        this._callMethod('GetStatus', null, (proxy, result) => {
            try {
                const variant = proxy.call_finish(result);
                const [status] = variant.deep_unpack();
                this._updatePlayButton(status);
            } catch (e) {
                log('JNL: 初始 GetStatus 失败: ' + e);
            }
        });

        // 初始查询歌曲信息
        this._callMethod('GetSongInfo', null, (proxy, result) => {
            try {
                const variant = proxy.call_finish(result);
                const [title, artist] = variant.deep_unpack();
                this._titleLabel.set_text(title || '未播放');
                this._artistLabel.set_text(artist || '');
            } catch (e) {
                log('JNL: 初始 GetSongInfo 失败: ' + e);
            }
        });

        // 初始查询音量
        this._callMethod('GetVolume', null, (proxy, result) => {
            try {
                const variant = proxy.call_finish(result);
                const [volume] = variant.deep_unpack();
                this._updateVolume(volume);
            } catch (e) {
                log('JNL: 初始 GetVolume 失败: ' + e);
            }
        });
    }

    // ========================================================================
    // 更新音量滑块（设置标志位以避免回调触发 SetVolume）
    // ========================================================================
    _updateVolume(volume) {
        this._volumeUpdating = true;
        this._volumeSlider.value = Math.max(0, Math.min(1, volume));
        this._volumeUpdating = false;
    }

    // ========================================================================
    // 调用 DBus 方法（无参数、无回调）
    // ========================================================================
    _call(method) {
        this._playerProxy.call(
            method, null, Gio.DBusCallFlags.NONE, -1, null, null);
    }

    // ========================================================================
    // 调用 DBus 方法（可带参数和回调）
    // ========================================================================
    _callMethod(method, params, callback) {
        this._playerProxy.call(
            method, params, Gio.DBusCallFlags.NONE, -1, null, callback);
    }

    // ========================================================================
    // 根据播放状态更新播放按钮图标
    // ========================================================================
    _updatePlayButton(status) {
        const iconName = status === 'playing'
            ? 'media-playback-pause-symbolic'
            : 'media-playback-start-symbolic';
        this._playButton.get_child().set_icon_name(iconName);
    }

    // ========================================================================
    // 刷新歌曲列表（读取 ~/.local/share/jnl-os/music/*.jnl）
    // ========================================================================
    _refreshTrackList() {
        this._trackList.removeAll();

        try {
            const dir = Gio.File.new_for_path(MUSIC_DIR);
            if (!dir.query_exists(null)) {
                dir.make_directory_with_parents(null);
            }

            const enumerator = dir.enumerate_children(
                'standard::name',
                Gio.FileQueryInfoFlags.NONE,
                null);

            let info;
            let index = 0;
            while ((info = enumerator.next_file(null)) !== null) {
                const name = info.get_name();
                if (name.endsWith('.jnl')) {
                    const item = new PopupMenu.PopupMenuItem(name);
                    const idx = index;
                    item.connect('activate', () => {
                        this._callMethod('PlayTrack',
                            GLib.Variant.new_tuple([
                                GLib.Variant.new_int32(idx),
                            ]));
                    });
                    this._trackList.addMenuItem(item);
                    index++;
                }
            }

            if (index === 0) {
                this._trackList.addMenuItem(
                    new PopupMenu.PopupMenuItem('（无音乐文件）', {
                        reactive: false,
                        style_class: 'jnl-music-empty',
                    }));
            }
        } catch (e) {
            log('JNL: 读取音乐列表失败: ' + e);
            this._trackList.addMenuItem(
                new PopupMenu.PopupMenuItem('（读取失败）', {
                    reactive: false,
                    style_class: 'jnl-music-empty',
                }));
        }
    }

    // ========================================================================
    // 清理资源
    // ========================================================================
    destroy() {
        if (this._playerProxy) {
            for (const id of this._signalIds) {
                this._playerProxy.disconnectSignal(id);
            }
            this._signalIds = [];
            this._playerProxy = null;
        }
        super.destroy();
    }
});

// ============================================================================
// 扩展入口
// ============================================================================
export default class JnlMusicExtension {
    enable() {
        this._indicator = new JnlMusicIndicator();
        Main.panel.addToStatusArea('jnl-music', this._indicator);
    }

    disable() {
        if (this._indicator) {
            this._indicator.destroy();
            this._indicator = null;
        }
    }
}
