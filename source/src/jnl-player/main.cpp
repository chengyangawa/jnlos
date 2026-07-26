#include <QApplication>
#include <QMainWindow>
#include <QMediaPlayer>
#include <QMediaPlaylist>
#include <QVideoWidget>
#include <QWidget>
#include <QHBoxLayout>
#include <QVBoxLayout>
#include <QPushButton>
#include <QSlider>
#include <QLabel>
#include <QListWidget>
#include <QFileDialog>
#include <QMenuBar>
#include <QMenu>
#include <QAction>
#include <QTimer>
#include <QStyle>
#include <QPalette>
#include <QLinearGradient>
#include <QPainter>
#include <QMouseEvent>
#include <QShortcut>

class JNLPlayer : public QMainWindow {
    Q_OBJECT

public:
    JNLPlayer(QWidget *parent = nullptr) : QMainWindow(parent) {
        setWindowTitle("JNL Player");
        setMinimumSize(900, 600);
        setStyleSheet(R"(
            QMainWindow {
                background: linear-gradient(135deg, #0a0a1a 0%, #1a1a2e 50%, #16213e 100%);
            }
            QWidget {
                color: #e0e0e0;
                font-family: 'Noto Sans CJK SC', sans-serif;
            }
            QPushButton {
                background: transparent;
                border: none;
                color: #00d4ff;
                font-size: 24px;
                padding: 8px 16px;
            }
            QPushButton:hover {
                background: rgba(0, 212, 255, 0.1);
                border-radius: 8px;
            }
            QPushButton:pressed {
                background: rgba(0, 212, 255, 0.2);
            }
            QSlider::groove:horizontal {
                height: 6px;
                background: rgba(255, 255, 255, 0.2);
                border-radius: 3px;
            }
            QSlider::handle:horizontal {
                width: 16px;
                height: 16px;
                background: #00d4ff;
                border-radius: 50%;
                margin: -5px 0;
            }
            QSlider::groove:vertical {
                width: 6px;
                background: rgba(255, 255, 255, 0.2);
                border-radius: 3px;
            }
            QSlider::handle:vertical {
                width: 16px;
                height: 16px;
                background: #00d4ff;
                border-radius: 50%;
                margin: 0 -5px;
            }
            QListWidget {
                background: rgba(0, 0, 0, 0.3);
                border: 1px solid rgba(0, 212, 255, 0.2);
                border-radius: 8px;
                padding: 8px;
            }
            QListWidget::item {
                padding: 8px;
                border-radius: 4px;
            }
            QListWidget::item:hover {
                background: rgba(0, 212, 255, 0.1);
            }
            QListWidget::item:selected {
                background: rgba(0, 212, 255, 0.3);
            }
            QLabel {
                color: #00d4ff;
                font-size: 14px;
            }
        )");

        player = new QMediaPlayer(this);
        playlist = new QMediaPlaylist(this);
        player->setPlaylist(playlist);

        videoWidget = new QVideoWidget(this);
        videoWidget->setStyleSheet("background: #000000; border-radius: 8px;");
        player->setVideoOutput(videoWidget);

        playlistView = new QListWidget(this);
        playlistView->setMaximumWidth(250);

        playBtn = new QPushButton(this);
        playBtn->setIcon(style()->standardIcon(QStyle::SP_MediaPlay));
        pauseBtn = new QPushButton(this);
        pauseBtn->setIcon(style()->standardIcon(QStyle::SP_MediaPause));
        stopBtn = new QPushButton(this);
        stopBtn->setIcon(style()->standardIcon(QStyle::SP_MediaStop));
        prevBtn = new QPushButton(this);
        prevBtn->setIcon(style()->standardIcon(QStyle::SP_MediaSkipBackward));
        nextBtn = new QPushButton(this);
        nextBtn->setIcon(style()->standardIcon(QStyle::SP_MediaSkipForward));

        volumeSlider = new QSlider(Qt::Vertical, this);
        volumeSlider->setRange(0, 100);
        volumeSlider->setValue(80);
        volumeSlider->setMaximumWidth(30);
        player->setVolume(80);

        progressSlider = new QSlider(Qt::Horizontal, this);
        progressSlider->setRange(0, 1000);

        timeLabel = new QLabel("00:00 / 00:00", this);

        QHBoxLayout *controlLayout = new QHBoxLayout;
        controlLayout->addWidget(prevBtn);
        controlLayout->addWidget(playBtn);
        controlLayout->addWidget(pauseBtn);
        controlLayout->addWidget(nextBtn);
        controlLayout->addWidget(stopBtn);
        controlLayout->addStretch();
        controlLayout->addWidget(timeLabel);

        QVBoxLayout *rightLayout = new QVBoxLayout;
        rightLayout->addWidget(playlistView);

        QHBoxLayout *mainLayout = new QHBoxLayout;
        mainLayout->addWidget(videoWidget, 1);
        mainLayout->addLayout(rightLayout);
        mainLayout->addWidget(volumeSlider);

        QVBoxLayout *centralLayout = new QVBoxLayout;
        centralLayout->addLayout(mainLayout, 1);
        centralLayout->addWidget(progressSlider);
        centralLayout->addLayout(controlLayout);

        QWidget *centralWidget = new QWidget(this);
        centralWidget->setLayout(centralLayout);
        setCentralWidget(centralWidget);

        QMenuBar *menuBar = new QMenuBar(this);
        QMenu *fileMenu = new QMenu("文件", this);
        QAction *openAction = new QAction("打开文件", this);
        QAction *openFolderAction = new QAction("打开文件夹", this);
        QAction *exitAction = new QAction("退出", this);
        fileMenu->addAction(openAction);
        fileMenu->addAction(openFolderAction);
        fileMenu->addSeparator();
        fileMenu->addAction(exitAction);
        menuBar->addMenu(fileMenu);

        QMenu *playMenu = new QMenu("播放", this);
        QAction *playAction = new QAction("播放", this);
        QAction *pauseAction = new QAction("暂停", this);
        QAction *stopAction = new QAction("停止", this);
        QAction *prevAction = new QAction("上一首", this);
        QAction *nextAction = new QAction("下一首", this);
        playMenu->addAction(playAction);
        playMenu->addAction(pauseAction);
        playMenu->addAction(stopAction);
        playMenu->addSeparator();
        playMenu->addAction(prevAction);
        playMenu->addAction(nextAction);
        menuBar->addMenu(playMenu);

        setMenuBar(menuBar);

        connect(playBtn, &QPushButton::clicked, player, &QMediaPlayer::play);
        connect(pauseBtn, &QPushButton::clicked, player, &QMediaPlayer::pause);
        connect(stopBtn, &QPushButton::clicked, player, &QMediaPlayer::stop);
        connect(prevBtn, &QPushButton::clicked, playlist, &QMediaPlaylist::previous);
        connect(nextBtn, &QPushButton::clicked, playlist, &QMediaPlaylist::next);

        connect(volumeSlider, &QSlider::valueChanged, player, &QMediaPlayer::setVolume);

        connect(player, &QMediaPlayer::positionChanged, this, &JNLPlayer::updateProgress);
        connect(player, &QMediaPlayer::durationChanged, this, &JNLPlayer::updateDuration);
        connect(progressSlider, &QSlider::sliderMoved, this, &JNLPlayer::seek);

        connect(playlistView, &QListWidget::itemDoubleClicked, this, &JNLPlayer::playSelected);

        connect(openAction, &QAction::triggered, this, &JNLPlayer::openFile);
        connect(openFolderAction, &QAction::triggered, this, &JNLPlayer::openFolder);
        connect(exitAction, &QAction::triggered, qApp, &QApplication::quit);

        connect(playAction, &QAction::triggered, player, &QMediaPlayer::play);
        connect(pauseAction, &QAction::triggered, player, &QMediaPlayer::pause);
        connect(stopAction, &QAction::triggered, player, &QMediaPlayer::stop);
        connect(prevAction, &QAction::triggered, playlist, &QMediaPlaylist::previous);
        connect(nextAction, &QAction::triggered, playlist, &QMediaPlaylist::next);

        QShortcut *playShortcut = new QShortcut(QKeySequence("Space"), this);
        connect(playShortcut, &QShortcut::activated, this, &JNLPlayer::togglePlay);

        QShortcut *prevShortcut = new QShortcut(QKeySequence(Qt::Key_Left), this);
        connect(prevShortcut, &QShortcut::activated, playlist, &QMediaPlaylist::previous);

        QShortcut *nextShortcut = new QShortcut(QKeySequence(Qt::Key_Right), this);
        connect(nextShortcut, &QShortcut::activated, playlist, &QMediaPlaylist::next);

        playlist->setPlaybackMode(QMediaPlaylist::Loop);
    }

private slots:
    void updateProgress(qint64 pos) {
        progressSlider->setValue(pos / 1000);
        int minutes = pos / 60000;
        int seconds = (pos % 60000) / 1000;
        QString current = QString("%1:%2").arg(minutes, 2, 10, QChar('0')).arg(seconds, 2, 10, QChar('0'));
        timeLabel->setText(current + " / " + durationStr);
    }

    void updateDuration(qint64 dur) {
        progressSlider->setRange(0, dur / 1000);
        int minutes = dur / 60000;
        int seconds = (dur % 60000) / 1000;
        durationStr = QString("%1:%2").arg(minutes, 2, 10, QChar('0')).arg(seconds, 2, 10, QChar('0'));
    }

    void seek(int pos) {
        player->setPosition(pos * 1000);
    }

    void playSelected(QListWidgetItem *item) {
        int index = playlistView->row(item);
        playlist->setCurrentIndex(index);
        player->play();
    }

    void openFile() {
        QStringList files = QFileDialog::getOpenFileNames(this, "选择媒体文件", "",
            "视频文件 (*.mp4 *.mkv *.avi *.mov *.flv *.wmv);;音频文件 (*.mp3 *.wav *.ogg *.flac *.m4a);;所有文件 (*.*)");
        addFiles(files);
    }

    void openFolder() {
        QString folder = QFileDialog::getExistingDirectory(this, "选择文件夹");
        if (!folder.isEmpty()) {
            QStringList files = QDir(folder).entryList(QStringList() << "*.mp4" << "*.mkv" << "*.avi" << "*.mov" << "*.flv" << "*.wmv" << "*.mp3" << "*.wav" << "*.ogg" << "*.flac" << "*.m4a", QDir::Files);
            for (QString file : files) {
                files.replace(files.indexOf(file), folder + "/" + file);
            }
            addFiles(files);
        }
    }

    void addFiles(QStringList files) {
        for (QString file : files) {
            QUrl url = QUrl::fromLocalFile(file);
            playlist->addMedia(url);
            QString fileName = QFileInfo(file).fileName();
            playlistView->addItem(fileName);
        }
        if (playlist->mediaCount() > 0 && player->state() == QMediaPlayer::StoppedState) {
            playlist->setCurrentIndex(0);
            player->play();
        }
    }

    void togglePlay() {
        if (player->state() == QMediaPlayer::PlayingState) {
            player->pause();
        } else {
            player->play();
        }
    }

private:
    QMediaPlayer *player;
    QMediaPlaylist *playlist;
    QVideoWidget *videoWidget;
    QListWidget *playlistView;
    QPushButton *playBtn, *pauseBtn, *stopBtn, *prevBtn, *nextBtn;
    QSlider *volumeSlider, *progressSlider;
    QLabel *timeLabel;
    QString durationStr = "00:00";
};

int main(int argc, char *argv[]) {
    QApplication app(argc, argv);
    JNLPlayer player;
    player.show();
    return app.exec();
}

#include "main.moc"