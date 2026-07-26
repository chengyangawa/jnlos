#ifndef QQMUSICDOWNLOADER_H
#define QQMUSICDOWNLOADER_H

#include <QDialog>
#include <QLineEdit>
#include <QPushButton>
#include <QListWidget>
#include <QProgressBar>
#include <QLabel>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QJsonObject>
#include <QJsonArray>

struct MusicInfo {
    QString songId;
    QString name;
    QString artist;
    QString album;
    int duration;
    QString cover;
    QString downloadUrl;
    QString format;
};

class QQMusicDownloader : public QDialog
{
    Q_OBJECT

public:
    explicit QQMusicDownloader(QWidget *parent = nullptr);
    ~QQMusicDownloader();

private slots:
    void onSearchClicked();
    void onDownloadClicked();
    void onSearchFinished(QNetworkReply *reply);

private:
    void setupUI();
    void parseSearchResults(const QByteArray &data);
    void downloadSong(const MusicInfo &info);

    QLineEdit *m_searchBox;
    QPushButton *m_searchButton;
    QListWidget *m_resultList;
    QPushButton *m_downloadButton;
    QLabel *m_statusLabel;
    QNetworkAccessManager *m_networkManager;
    QList<MusicInfo> m_searchResults;
    QString m_downloadPath;
};

#endif
