#include "qqmusicdownloader.h"
#include <QVBoxLayout>
#include <QHBoxLayout>
#include <QStandardPaths>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QMessageBox>
#include <QJsonDocument>
#include <QJsonValue>
#include <QEventLoop>
#include <QTimer>
#include <QUrlQuery>
#include <QRegularExpression>

QQMusicDownloader::QQMusicDownloader(QWidget *parent)
    : QDialog(parent)
{
    setWindowTitle("QQ 音乐下载 - JNL Browser");
    resize(700, 500);
    setStyleSheet(R"(
        QDialog {
            background-color: #1e1e1e;
            color: white;
        }
        QLineEdit {
            background-color: #2a2a2a;
            border: 1px solid #3a3a3a;
            border-radius: 6px;
            padding: 8px 12px;
            color: white;
            font-size: 14px;
        }
        QLineEdit:focus {
            border-color: #0078d4;
        }
        QPushButton {
            background-color: #0078d4;
            color: white;
            border: none;
            border-radius: 6px;
            padding: 8px 16px;
            font-size: 14px;
        }
        QPushButton:hover {
            background-color: #00a8e8;
        }
        QPushButton:pressed {
            background-color: #005a9e;
        }
        QListWidget {
            background-color: #2a2a2a;
            border: 1px solid #3a3a3a;
            border-radius: 6px;
            color: white;
            font-size: 13px;
            outline: none;
        }
        QListWidget::item {
            padding: 10px;
            border-bottom: 1px solid #3a3a3a;
        }
        QListWidget::item:selected {
            background-color: #0078d4;
        }
        QListWidget::item:hover:!selected {
            background-color: #3a3a3a;
        }
        QLabel {
            color: #aaa;
            font-size: 12px;
        }
    )");

    m_networkManager = new QNetworkAccessManager(this);
    connect(m_networkManager, &QNetworkAccessManager::finished,
            this, &QQMusicDownloader::onSearchFinished);
    
    m_downloadPath = QStandardPaths::writableLocation(QStandardPaths::MusicLocation) + "/JNL Browser";
    QDir().mkpath(m_downloadPath);
    
    setupUI();
}

QQMusicDownloader::~QQMusicDownloader()
{
}

void QQMusicDownloader::setupUI()
{
    QVBoxLayout *mainLayout = new QVBoxLayout(this);
    mainLayout->setContentsMargins(20, 20, 20, 20);
    mainLayout->setSpacing(12);

    QLabel *title = new QLabel("QQ 音乐下载器", this);
    title->setStyleSheet("color: white; font-size: 20px; font-weight: bold;");
    mainLayout->addWidget(title);

    QHBoxLayout *searchLayout = new QHBoxLayout();
    m_searchBox = new QLineEdit(this);
    m_searchBox->setPlaceholderText("输入歌曲名或歌手...");
    searchLayout->addWidget(m_searchBox, 1);
    
    m_searchButton = new QPushButton("搜索", this);
    searchLayout->addWidget(m_searchButton);
    mainLayout->addLayout(searchLayout);

    m_resultList = new QListWidget(this);
    mainLayout->addWidget(m_resultList, 1);

    QHBoxLayout *bottomLayout = new QHBoxLayout();
    m_statusLabel = new QLabel(QString("下载目录: %1").arg(m_downloadPath), this);
    bottomLayout->addWidget(m_statusLabel, 1);
    
    m_downloadButton = new QPushButton("下载选中歌曲", this);
    m_downloadButton->setEnabled(false);
    bottomLayout->addWidget(m_downloadButton);
    mainLayout->addLayout(bottomLayout);

    connect(m_searchButton, &QPushButton::clicked, this, &QQMusicDownloader::onSearchClicked);
    connect(m_downloadButton, &QPushButton::clicked, this, &QQMusicDownloader::onDownloadClicked);
    connect(m_resultList, &QListWidget::itemSelectionChanged, [this]() {
        m_downloadButton->setEnabled(m_resultList->currentRow() >= 0);
    });
}

void QQMusicDownloader::onSearchClicked()
{
    QString query = m_searchBox->text().trimmed();
    if (query.isEmpty()) return;

    m_statusLabel->setText("搜索中...");
    m_resultList->clear();
    m_searchResults.clear();

    QUrl url("https://c.y.qq.com/soso/fcgi-bin/client_search_cp");
    QUrlQuery params;
    params.addQueryItem("w", query);
    params.addQueryItem("n", "20");
    params.addQueryItem("format", "json");
    params.addQueryItem("inCharset", "utf-8");
    params.addQueryItem("outCharset", "utf-8");
    url.setQuery(params);

    QNetworkRequest req(url);
    req.setHeader(QNetworkRequest::UserAgentHeader,
                  "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36");
    req.setRawHeader("Referer", "https://y.qq.com/");
    
    m_networkManager->get(req);
}

void QQMusicDownloader::onSearchFinished(QNetworkReply *reply)
{
    if (reply->error() != QNetworkReply::NoError) {
        m_statusLabel->setText(QString("搜索失败: %1").arg(reply->errorString()));
        reply->deleteLater();
        return;
    }
    
    QByteArray data = reply->readAll();
    reply->deleteLater();
    parseSearchResults(data);
}

void QQMusicDownloader::parseSearchResults(const QByteArray &data)
{
    QJsonDocument doc = QJsonDocument::fromJson(data);
    if (!doc.isObject()) {
        m_statusLabel->setText("解析失败");
        return;
    }
    
    QJsonObject root = doc.object();
    QJsonObject dataObj = root.value("data").toObject();
    QJsonObject songObj = dataObj.value("song").toObject();
    QJsonArray list = songObj.value("list").toArray();
    
    int count = 0;
    for (const QJsonValue &val : list) {
        QJsonObject song = val.toObject();
        MusicInfo info;
        info.songId = song.value("songid").toVariant().toString();
        info.name = song.value("songname").toString();
        info.album = song.value("albumname").toString();
        info.duration = song.value("interval").toInt();
        info.format = "mp3";
        
        QJsonArray singers = song.value("singer").toArray();
        QStringList artistNames;
        for (const QJsonValue &s : singers) {
            artistNames << s.toObject().value("name").toString();
        }
        info.artist = artistNames.join(", ");
        
        m_searchResults.append(info);
        
        QString display = QString("%1 - %2  [%3秒]")
            .arg(info.name)
            .arg(info.artist)
            .arg(info.duration);
        m_resultList->addItem(display);
        count++;
    }
    
    m_statusLabel->setText(QString("找到 %1 首歌曲").arg(count));
}

void QQMusicDownloader::onDownloadClicked()
{
    int row = m_resultList->currentRow();
    if (row < 0 || row >= m_searchResults.size()) return;
    
    MusicInfo info = m_searchResults[row];
    m_statusLabel->setText(QString("正在下载: %1 - %2").arg(info.name).arg(info.artist));
    downloadSong(info);
}

void QQMusicDownloader::downloadSong(const MusicInfo &info)
{
    QFileInfo checkFile(m_downloadPath);
    if (!checkFile.exists()) {
        QDir().mkpath(m_downloadPath);
    }
    
    QString safeName = QString("%1 - %2.%3")
        .arg(info.name)
        .arg(info.artist)
        .arg(info.format);
    safeName.replace(QRegularExpression("[\\\\/:*?\"<>|]"), "_");
    
    QString filePath = m_downloadPath + "/" + safeName;
    QFile file(filePath);
    
    QString content = QString("JNL Music File\nSong: %1\nArtist: %2\nAlbum: %3\nDuration: %4 sec\nSongId: %5\nDownloaded by: JNL Browser\n")
        .arg(info.name)
        .arg(info.artist)
        .arg(info.album)
        .arg(info.duration)
        .arg(info.songId);
    
    if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        QTextStream out(&file);
        out << content;
        file.close();
        m_statusLabel->setText(QString("已下载: %1 (%2)").arg(info.name).arg(safeName));
        QMessageBox::information(this, "下载完成",
            QString("已下载到:\n%1\n\n注: 实际音频文件需要从 QQ 音乐官方接口获取,\n当前下载的是元数据信息文件.").arg(filePath));
    } else {
        m_statusLabel->setText("下载失败");
    }
}
